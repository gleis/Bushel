import Foundation

/// Configuration for running a new container via `container run`
struct RunContainerConfig {
    var image: String = ""
    var name: String?
    var memory: String?
    var cpus: Int?
    var ports: [String] = []
    var volumes: [String] = []
    var environment: [String] = []
    var networks: [String] = []
    var removeOnStop: Bool = false
    var arguments: [String] = []
}

struct ContainerService: Sendable {
    private let shell = ShellService.shared

    func listAll() async throws -> [ContainerEntry] {
        try await shell.runJSON(["list", "--all", "--format", "json"], as: [ContainerEntry].self)
    }

    func inspect(_ id: String) async throws -> ContainerEntry {
        let entries = try await shell.runJSON(["inspect", id], as: [ContainerEntry].self)
        guard let entry = entries.first else {
            throw ShellError.commandFailed(command: "inspect \(id)", exitCode: 1, stderr: "No result returned")
        }
        return entry
    }

    func start(_ id: String) async throws {
        try await shell.execute(["start", id])
    }

    func stop(_ id: String) async throws {
        try await shell.execute(["stop", id])
    }

    func kill(_ id: String) async throws {
        try await shell.execute(["kill", id])
    }

    func delete(_ id: String) async throws {
        try await shell.execute(["delete", id])
    }

    func restart(_ id: String) async throws {
        try await stop(id)
        try await start(id)
    }

    func logs(_ id: String, follow: Bool = false, lines: Int? = nil) -> (AsyncStream<String>, cancel: @Sendable () -> Void) {
        var args = ["logs"]
        if follow { args.append("--follow") }
        if let n = lines { args += ["-n", "\(n)"] }
        args.append(id)
        return shell.stream(args)
    }

    func exec(_ id: String, command: [String]) async throws -> String {
        let args = ["exec", id] + command
        return try await shell.run(args)
    }

    func run(config: RunContainerConfig) async throws -> String {
        var args = ["run", "-d"]
        if let name = config.name, !name.isEmpty { args += ["--name", name] }
        if let memory = config.memory, !memory.isEmpty { args += ["-m", memory] }
        if let cpus = config.cpus { args += ["-c", "\(cpus)"] }
        for port in config.ports where !port.isEmpty { args += ["-p", port] }
        for volume in config.volumes where !volume.isEmpty { args += ["-v", volume] }
        for env in config.environment where !env.isEmpty { args += ["-e", env] }
        for network in config.networks where !network.isEmpty { args += ["--network", network] }
        if config.removeOnStop { args.append("--rm") }
        args.append(config.image)
        args += config.arguments
        return try await shell.run(args)
    }
}
