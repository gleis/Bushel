import Foundation

struct ImageService: Sendable {
    private let shell = ShellService.shared

    func list() async throws -> [ImageListEntry] {
        try await shell.runJSON(["image", "list", "--format", "json"], as: [ImageListEntry].self)
    }

    func pull(_ reference: String) -> (AsyncStream<String>, cancel: @Sendable () -> Void) {
        shell.stream(["image", "pull", reference])
    }

    func pullAndWait(_ reference: String) async throws {
        try await shell.execute(["image", "pull", reference])
    }

    func delete(_ reference: String) async throws {
        try await shell.execute(["image", "delete", reference])
    }

    func tag(source: String, target: String) async throws {
        try await shell.execute(["image", "tag", source, target])
    }

    func prune(all: Bool = false) async throws {
        var args = ["image", "prune"]
        if all { args.append("--all") }
        try await shell.execute(args)
    }

    func build(tag: String, contextDir: String, dockerfile: String? = nil) -> (AsyncStream<String>, cancel: @Sendable () -> Void) {
        var args = ["build", "-t", tag, "--progress", "plain"]
        if let f = dockerfile { args += ["-f", f] }
        args.append(contextDir)
        return shell.stream(args)
    }
}
