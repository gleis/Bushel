import Foundation

struct SystemService: Sendable {
    private let shell = ShellService.shared

    func status() async throws -> SystemStatus {
        do {
            do {
                let output = try await shell.run(["system", "status", "--format", "json"])
                return try Self.decodeStatus(Data(output.utf8))
            } catch let error as ShellError {
                if case .commandFailed(_, _, let stderr) = error,
                    stderr.contains("Unknown option") || stderr.contains("unknown option") {
                    return parseStatus(try await shell.run(["system", "status"]))
                }
                throw error
            }
        } catch let error as ShellError where error.isSystemNotRunning {
            // "system status" exits with code 1 when the system is stopped;
            // treat only the stopped-system diagnostic as "not running"
            return SystemStatus(isRunning: false, version: "", commit: "", dataRoot: "", installRoot: "")
        }
    }

    func diskUsage() async throws -> DiskUsage {
        try await shell.runJSON(["system", "df", "--format", "json"], as: DiskUsage.self)
    }

    func start() async throws {
        try await shell.execute(["system", "start"])
    }

    func stop() async throws {
        try await shell.execute(["system", "stop"])
    }

    static func decodeStatus(_ data: Data) throws -> SystemStatus {
        struct Version: Decodable { let version: String; let commit: String }
        struct Paths: Decodable { let appRoot: String; let installRoot: String }
        struct Payload: Decodable {
            let status: String
            let server: Version?
            let paths: Paths?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return SystemStatus(isRunning: payload.status == "running",
            version: payload.server?.version ?? "", commit: payload.server?.commit ?? "",
            dataRoot: payload.paths?.appRoot ?? "", installRoot: payload.paths?.installRoot ?? "")
    }

    private func parseStatus(_ text: String) -> SystemStatus {
        let lines = text.components(separatedBy: .newlines)
        let isRunning = lines.first?.contains("is running") ?? false

        func extract(_ prefix: String) -> String {
            lines.first(where: { $0.hasPrefix(prefix) })?
                .dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespaces) ?? ""
        }

        return SystemStatus(
            isRunning: isRunning,
            version: extract("container-apiserver version: "),
            commit: extract("container-apiserver commit: "),
            dataRoot: extract("application data root: "),
            installRoot: extract("application install root: ")
        )
    }
}
