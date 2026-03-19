import Foundation
import SwiftUI

@MainActor
@Observable
final class ContainerViewModel {
    var containers: [ContainerEntry] = []
    var selectedContainerID: String?
    var selectedDetailTab = "info"
    var isLoading = false
    var error: String?
    var showError = false
    var systemNotRunning = false

    // Log streaming
    var logLines: [(id: Int, text: String)] = []
    var isStreamingLogs = false
    @ObservationIgnored private var logCancelFn: (@Sendable () -> Void)?
    @ObservationIgnored private var nextLogLineID = 0

    // Exec
    var execOutput: String = ""
    var isExecuting = false

    // Periodic refresh
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    private let service = ContainerService()

    var selectedContainer: ContainerEntry? {
        containers.first { $0.id == selectedContainerID }
    }

    var runningCount: Int {
        containers.filter { $0.status == .running }.count
    }

    var stoppedCount: Int {
        containers.filter { $0.status == .stopped }.count
    }

    // MARK: - Container List

    func loadContainers() async {
        do {
            containers = try await service.listAll()
            systemNotRunning = false
        } catch {
            if ShellError.isSystemNotRunningError(error) {
                systemNotRunning = true
            } else {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    func initialLoad() async {
        isLoading = true
        await loadContainers()
        isLoading = false
    }

    // MARK: - Container Actions

    func start(_ id: String) async {
        do {
            try await service.start(id)
            await loadContainers()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func stop(_ id: String) async {
        do {
            try await service.stop(id)
            await loadContainers()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func restart(_ id: String) async {
        do {
            try await service.restart(id)
            await loadContainers()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func kill(_ id: String) async {
        do {
            try await service.kill(id)
            await loadContainers()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func delete(_ id: String) async {
        do {
            try await service.delete(id)
            if selectedContainerID == id { selectedContainerID = nil }
            await loadContainers()
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    /// Returns true on success, false if an error occurred (error is set on self).
    func runContainer(config: RunContainerConfig) async -> Bool {
        do {
            _ = try await service.run(config: config)
            await loadContainers()
            return true
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            return false
        }
    }

    // MARK: - Log Streaming

    func startLogStream(for id: String, lines: Int? = 200) {
        stopLogStream()
        logLines = []
        isStreamingLogs = true

        let (stream, cancel) = service.logs(id, follow: true, lines: lines)
        logCancelFn = cancel

        Task { @MainActor [weak self] in
            for await line in stream {
                guard let self else { return }
                self.logLines.append((id: self.nextLogLineID, text: line))
                self.nextLogLineID += 1
                if self.logLines.count > 10_000 {
                    self.logLines.removeFirst(self.logLines.count - 10_000)
                }
            }
            self?.isStreamingLogs = false
        }
    }

    func stopLogStream() {
        logCancelFn?()
        logCancelFn = nil
        isStreamingLogs = false
    }

    // MARK: - Exec

    func exec(_ id: String, command: String) async {
        isExecuting = true
        do {
            let args = shellSplit(command)
            let output = try await service.exec(id, command: args)
            execOutput += "$ \(command)\n\(output)\n"
        } catch {
            execOutput += "$ \(command)\nError: \(error.localizedDescription)\n"
        }
        isExecuting = false
    }

    func clearExecOutput() {
        execOutput = ""
    }

    // MARK: - Interactive Terminal

    var terminalSession: TerminalSession?
    var isTerminalOpen = false

    func toggleTerminal(_ id: String) {
        if isTerminalOpen {
            closeTerminal()
        } else {
            openTerminal(id)
        }
    }

    func openTerminal(_ id: String, shell: String = "/bin/sh") {
        closeTerminal()

        let session = TerminalSession(containerID: id)
        session.onExit = { [weak self] _ in
            Task { @MainActor [weak self] in
                // Brief delay so the user sees the prompt return before panel closes
                try? await Task.sleep(for: .seconds(0.5))
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.closeTerminal()
                }
            }
        }

        do {
            try session.start(shell: shell)
            self.terminalSession = session
            self.isTerminalOpen = true
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    func closeTerminal() {
        let session = terminalSession
        terminalSession = nil
        isTerminalOpen = false
        session?.stop()
    }

    // MARK: - Periodic Refresh

    func startPeriodicRefresh(interval: TimeInterval = 5.0) {
        stopPeriodicRefresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.loadContainers()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Helpers

    /// POSIX-style shell word tokenizer. Handles single/double quotes and backslash escapes.
    private func shellSplit(_ command: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var i = command.startIndex

        while i < command.endIndex {
            let ch = command[i]
            if inSingle {
                if ch == "'" { inSingle = false } else { current.append(ch) }
            } else if inDouble {
                if ch == "\\" {
                    let j = command.index(after: i)
                    if j < command.endIndex { current.append(command[j]); i = j }
                } else if ch == "\"" { inDouble = false
                } else { current.append(ch) }
            } else if ch == "'" { inSingle = true
            } else if ch == "\"" { inDouble = true
            } else if ch == "\\" {
                let j = command.index(after: i)
                if j < command.endIndex { current.append(command[j]); i = j }
            } else if ch.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else { current.append(ch) }
            i = command.index(after: i)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
