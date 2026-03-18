import Foundation

struct VolumeService: Sendable {
    private let shell = ShellService.shared

    func list() async throws -> [VolumeEntry] {
        try await shell.runJSON(["volume", "list", "--format", "json"], as: [VolumeEntry].self)
    }

    func create(name: String) async throws {
        try await shell.execute(["volume", "create", name])
    }

    func delete(_ name: String) async throws {
        try await shell.execute(["volume", "delete", name])
    }

    func prune() async throws {
        try await shell.execute(["volume", "prune"])
    }
}
