import Foundation

// MARK: - AnyCodable (type-erased Codable for opaque JSON fields)

struct AnyCodable: Codable, Sendable {
    let value: AnyCodableValue

    init(value: Any) {
        self.value = AnyCodableValue(value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = .null
        } else if let bool = try? container.decode(Bool.self) {
            value = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            value = .int(int)
        } else if let double = try? container.decode(Double.self) {
            value = .double(double)
        } else if let string = try? container.decode(String.self) {
            value = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            value = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = .dictionary(dict)
        } else {
            value = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .dictionary(let v): try container.encode(v)
        }
    }
}

enum AnyCodableValue: Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case dictionary([String: AnyCodable])

    init(_ any: Any) {
        switch any {
        case let v as Bool: self = .bool(v)
        case let v as Int: self = .int(v)
        case let v as Double: self = .double(v)
        case let v as String: self = .string(v)
        case let v as [Any]: self = .array(v.map { AnyCodable(value: $0) })
        case let v as [String: Any]: self = .dictionary(v.mapValues { AnyCodable(value: $0) })
        default: self = .null
        }
    }
}

// MARK: - Container List / Inspect Models

/// Top-level entry from `container list --all --format json` or `container inspect <id>`
struct ContainerEntry: Codable, Identifiable, Sendable {
    let configuration: ContainerConfiguration
    let networks: [AnyCodable]
    let status: ContainerStatus

    private enum CodingKeys: String, CodingKey { case configuration, networks, status }
    private struct StatusPayload: Decodable { let state: ContainerStatus; let networks: [AnyCodable] }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try c.decode(ContainerConfiguration.self, forKey: .configuration)
        if let legacy = try? c.decode(ContainerStatus.self, forKey: .status) {
            status = legacy
            networks = try c.decodeIfPresent([AnyCodable].self, forKey: .networks) ?? []
        } else {
            let current = try c.decode(StatusPayload.self, forKey: .status)
            status = current.state
            networks = current.networks
        }
    }

    var id: String { configuration.id }
}

enum ContainerStatus: String, Codable, Sendable {
    case running
    case stopped
    case stopping
    case unknown
}

struct ContainerConfiguration: Codable, Sendable {
    let id: String
    let image: ContainerImageRef
    let resources: ContainerResources
    let publishedPorts: [PublishedPort]
    let publishedSockets: [AnyCodable]
    let mounts: [ContainerMount]
    let dns: ContainerDNS
    let networks: [ContainerNetworkConfig]
    let initProcess: InitProcess
    let platform: Platform
    let runtimeHandler: String
    let ssh: Bool
    let rosetta: Bool
    let virtualization: Bool
    let sysctls: [String: String]
    let labels: [String: String]
    private enum CodingKeys: String, CodingKey { case id, image, resources, publishedPorts, publishedSockets, mounts, dns, networks, initProcess, platform, runtimeHandler, ssh, rosetta, virtualization, sysctls, labels }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        image = try c.decode(ContainerImageRef.self, forKey: .image)
        resources = try c.decode(ContainerResources.self, forKey: .resources)
        publishedPorts = try c.decodeIfPresent([PublishedPort].self, forKey: .publishedPorts) ?? []
        publishedSockets = try c.decodeIfPresent([AnyCodable].self, forKey: .publishedSockets) ?? []
        mounts = try c.decodeIfPresent([ContainerMount].self, forKey: .mounts) ?? []
        dns = try c.decodeIfPresent(ContainerDNS.self, forKey: .dns) ?? ContainerDNS(nameservers: [], searchDomains: [], options: [], domain: nil)
        networks = try c.decodeIfPresent([ContainerNetworkConfig].self, forKey: .networks) ?? []
        initProcess = try c.decode(InitProcess.self, forKey: .initProcess)
        platform = try c.decode(Platform.self, forKey: .platform)
        runtimeHandler = try c.decodeIfPresent(String.self, forKey: .runtimeHandler) ?? "container-runtime-linux"
        ssh = try c.decodeIfPresent(Bool.self, forKey: .ssh) ?? false
        rosetta = try c.decodeIfPresent(Bool.self, forKey: .rosetta) ?? false
        virtualization = try c.decodeIfPresent(Bool.self, forKey: .virtualization) ?? false
        sysctls = try c.decodeIfPresent([String: String].self, forKey: .sysctls) ?? [:]
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
    }

}

struct ContainerImageRef: Codable, Sendable {
    let reference: String
    let descriptor: ImageDescriptor
}

struct ImageDescriptor: Codable, Sendable {
    let digest: String
    let size: Int64
    let mediaType: String
    let annotations: [String: String]?
}

struct ContainerResources: Codable, Sendable {
    let cpus: Int
    let memoryInBytes: Int64

    var memoryFormatted: String {
        ByteFormatter.format(memoryInBytes)
    }
}

struct PublishedPort: Codable, Identifiable, Sendable {
    let hostPort: Int
    let containerPort: Int
    let hostAddress: String
    let proto: String
    let count: Int

    var id: String { "\(hostAddress):\(hostPort):\(containerPort)/\(proto)" }

    var displayString: String {
        "\(hostAddress):\(hostPort) → \(containerPort)/\(proto)"
    }
}

struct ContainerMount: Codable, Identifiable, Sendable {
    let type: MountType
    let source: String
    let destination: String
    let options: [String]

    var id: String { destination }
}

// MARK: - MountType (polymorphic: {"virtiofs":{}}, {"tmpfs":{}}, {"volume":{...}})

enum MountType: Codable, Sendable {
    case virtiofs
    case tmpfs
    case volume(VolumeMountInfo)
    case unknown(String)

    struct VolumeMountInfo: Codable, Sendable {
        let name: String
        let format: String?
        let cache: AnyCodable?
        let sync: AnyCodable?
    }

    /// Dynamic CodingKey for JSON objects whose keys aren't known at compile time.
    private struct DynamicKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        if container.contains(DynamicKey("virtiofs")) {
            self = .virtiofs
        } else if container.contains(DynamicKey("tmpfs")) {
            self = .tmpfs
        } else if container.contains(DynamicKey("volume")) {
            let info = try container.decode(VolumeMountInfo.self, forKey: DynamicKey("volume"))
            self = .volume(info)
        } else {
            self = .unknown(container.allKeys.first?.stringValue ?? "unknown")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        switch self {
        case .virtiofs:
            try container.encode([String: String](), forKey: DynamicKey("virtiofs"))
        case .tmpfs:
            try container.encode([String: String](), forKey: DynamicKey("tmpfs"))
        case .volume(let info):
            try container.encode(info, forKey: DynamicKey("volume"))
        case .unknown(let key):
            try container.encode([String: String](), forKey: DynamicKey(key))
        }
    }

    var displayName: String {
        switch self {
        case .virtiofs: return "Bind Mount"
        case .tmpfs: return "tmpfs"
        case .volume(let info): return "Volume (\(info.name))"
        case .unknown(let key): return key
        }
    }
}

struct ContainerDNS: Codable, Sendable {
    let nameservers: [String]
    let searchDomains: [String]
    let options: [String]
    let domain: String?
}

struct ContainerNetworkConfig: Codable, Sendable {
    let network: String
    let options: NetworkOptions

    struct NetworkOptions: Codable, Sendable {
        let hostname: String?
    }
}

// MARK: - InitProcess and ProcessUser

struct InitProcess: Codable, Sendable {
    let executable: String
    let arguments: [String]
    let environment: [String]
    let workingDirectory: String
    let terminal: Bool
    let user: ProcessUser
    let supplementalGroups: [Int]
    let rlimits: [AnyCodable]
}

/// Two variants: {"raw":{"userString":"root"}} or {"id":{"uid":0,"gid":0}}
enum ProcessUser: Codable, Sendable {
    case raw(userString: String)
    case id(uid: Int, gid: Int)

    private enum CodingKeys: String, CodingKey {
        case raw, id
    }

    struct RawUser: Codable, Sendable { let userString: String }
    struct IDUser: Codable, Sendable { let uid: Int; let gid: Int }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = try? container.decode(RawUser.self, forKey: .raw) {
            self = .raw(userString: raw.userString)
        } else if let idUser = try? container.decode(IDUser.self, forKey: .id) {
            self = .id(uid: idUser.uid, gid: idUser.gid)
        } else {
            self = .raw(userString: "unknown")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .raw(let userString):
            try container.encode(RawUser(userString: userString), forKey: .raw)
        case .id(let uid, let gid):
            try container.encode(IDUser(uid: uid, gid: gid), forKey: .id)
        }
    }

    var displayString: String {
        switch self {
        case .raw(let s): return s
        case .id(let uid, let gid): return "\(uid):\(gid)"
        }
    }
}

struct Platform: Codable, Sendable {
    let os: String
    let architecture: String
    let variant: String?
}

// MARK: - Byte Formatter Utility

enum ByteFormatter {
    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
