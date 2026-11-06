import Foundation

/// Legacy 1.2 and current 1.6 network resources.
struct NetworkEntry: Decodable, Identifiable, Sendable {
    let id: String
    let config: NetworkConfig
    let state: String
    let status: NetworkStatus
    private enum CodingKeys: String, CodingKey { case id, config, configuration, state, status }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        config = try c.decodeIfPresent(NetworkConfig.self, forKey: .configuration) ?? c.decode(NetworkConfig.self, forKey: .config)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? config.id
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? (c.contains(.status) ? "configured" : "unknown")
        status = try c.decodeIfPresent(NetworkStatus.self, forKey: .status) ?? NetworkStatus(gateway: "Unknown", address: "Unknown")
    }
}

struct NetworkConfig: Decodable, Sendable {
    let id: String
    let mode: String
    let labels: [String: String]
    let creationDate: TimeInterval
    private enum CodingKeys: String, CodingKey { case id, name, mode, labels, creationDate }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .name) ?? c.decode(String.self, forKey: .id)
        mode = try c.decode(String.self, forKey: .mode)
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        creationDate = try c.decodeIfPresent(TimeInterval.self, forKey: .creationDate) ?? 0
    }
    var createdDate: Date { Date(timeIntervalSinceReferenceDate: creationDate) }
}

struct NetworkStatus: Decodable, Sendable {
    let gateway: String
    let address: String
    private enum CodingKeys: String, CodingKey { case gateway, address, ipv4Gateway, ipv4Subnet }
    init(gateway: String, address: String) { self.gateway = gateway; self.address = address }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gateway = try c.decodeIfPresent(String.self, forKey: .ipv4Gateway) ?? c.decode(String.self, forKey: .gateway)
        address = try c.decodeIfPresent(String.self, forKey: .ipv4Subnet) ?? c.decode(String.self, forKey: .address)
    }
}
