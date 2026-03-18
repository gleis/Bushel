import Foundation

struct NetworkService: Sendable {
    private let shell = ShellService.shared

    func list() async throws -> [NetworkEntry] {
        try await shell.runJSON(["network", "list", "--format", "json"], as: [NetworkEntry].self)
    }

    func create(name: String) async throws {
        try await shell.execute(["network", "create", name])
    }

    func delete(_ name: String) async throws {
        try await shell.execute(["network", "delete", name])
    }
}
