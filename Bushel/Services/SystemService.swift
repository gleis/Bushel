import Foundation

struct SystemService: Sendable {
    private let shell = ShellService.shared

    func status() async throws -> SystemStatus {
        do {
            let output = try await shell.run(["system", "status"])
            return parseStatus(output)
        } catch is ShellError {
            // "system status" exits with code 1 when the system is stopped;
            // treat any failure as "not running"
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
