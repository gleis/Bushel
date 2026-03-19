import Foundation
import Darwin

enum TerminalError: LocalizedError {
    case forkFailed(errno: Int32)
    case sessionAlreadyRunning
    case binaryNotFound(path: String)

    var errorDescription: String? {
        switch self {
        case .forkFailed(let errno):
            return "Failed to create terminal: \(String(cString: strerror(errno)))"
        case .sessionAlreadyRunning:
            return "A terminal session is already running"
        case .binaryNotFound(let path):
            return "Container binary not found at \(path)"
        }
    }
}

/// Manages a single PTY session connected to `container exec -it <id> /bin/sh`.
@Observable
final class TerminalSession {
    var isRunning = false
    var exitCode: Int32?

    @ObservationIgnored var onOutput: (@MainActor @Sendable (Data) -> Void)?
    @ObservationIgnored var onExit: (@Sendable (Int32) -> Void)?

    @ObservationIgnored private var masterFD: Int32 = -1
    @ObservationIgnored private var childPID: pid_t = 0
    @ObservationIgnored private var readTask: Task<Void, Never>?

    let containerID: String

    init(containerID: String) {
        self.containerID = containerID
    }

    deinit {
        stop()
    }

    /// Buffer for output received before a listener is attached.
    @ObservationIgnored private var pendingOutput: [Data] = []

    /// Fork a child process with a PTY running `container exec -it <containerID> <shell>`.
    func start(shell: String = "/bin/sh") throws {
        guard !isRunning else { throw TerminalError.sessionAlreadyRunning }

        let binary = containerBinaryPath
        guard FileManager.default.isExecutableFile(atPath: binary) else {
            throw TerminalError.binaryNotFound(path: binary)
        }

        var winSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
        var masterFD: Int32 = -1

        let pid = forkpty(&masterFD, nil, nil, &winSize)

        guard pid >= 0 else {
            throw TerminalError.forkFailed(errno: errno)
        }

        if pid == 0 {
            // Child process — exec into container
            // Build argv for execv: program name + args + nil terminator
            let args = ["container", "exec", "-it", containerID, shell]
            let cArgs = args.map { strdup($0) } + [nil]
            execv(binary, cArgs)
            // If we get here, execv failed
            _exit(127)
        }

        // Parent process
        self.masterFD = masterFD
        self.childPID = pid
        self.isRunning = true
        startReadLoop()
    }

    /// Flush any output that arrived before a listener was attached.
    func flushPendingOutput() {
        let buffered = pendingOutput
        pendingOutput = []
        for data in buffered {
            onOutput?(data)
        }
    }

    /// Send data (keystrokes) to the PTY.
    func write(_ data: Data) {
        guard isRunning, masterFD >= 0 else { return }
        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            Darwin.write(masterFD, baseAddress, ptr.count)
        }
    }

    /// Send a string to the PTY.
    func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        write(data)
    }

    /// Update the PTY window size (TIOCSWINSZ).
    func resize(cols: Int, rows: Int) {
        guard masterFD >= 0 else { return }
        var size = winsize(
            ws_row: UInt16(rows),
            ws_col: UInt16(cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFD, TIOCSWINSZ, &size)
    }

    /// Stop the session: kill child, close fd, cancel read loop.
    func stop() {
        guard masterFD >= 0 || childPID > 0 else {
            isRunning = false
            return
        }

        let pid = childPID
        let fd = masterFD
        childPID = 0
        masterFD = -1
        isRunning = false

        // Kill the child first — this will cause the PTY read to return
        if pid > 0 {
            Darwin.kill(pid, SIGHUP)
            Darwin.kill(pid, SIGTERM)
        }

        // Close the master fd — unblocks any pending read()
        if fd >= 0 {
            close(fd)
        }

        // Cancel the read task (read will have returned now that fd is closed)
        readTask?.cancel()
        readTask = nil

        // Give the process a moment to exit from SIGTERM, then force-kill.
        // The read loop is the sole owner of waitpid and will reap the child.
        if pid > 0 {
            DispatchQueue.global().async {
                usleep(100_000) // 100ms
                Darwin.kill(pid, SIGKILL) // no-op (ESRCH) if already exited
            }
        }
    }

    // MARK: - Private

    private func startReadLoop() {
        let fd = masterFD
        let childPID = self.childPID

        readTask = Task.detached { [weak self] in
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            while !Task.isCancelled {
                let bytesRead = read(fd, buffer, bufferSize)
                if bytesRead <= 0 {
                    // fd closed or error — session is ending
                    break
                }
                let data = Data(bytes: buffer, count: bytesRead)
                await MainActor.run { [weak self] in
                    if let callback = self?.onOutput {
                        callback(data)
                    } else {
                        self?.pendingOutput.append(data)
                    }
                }
            }

            // Block until the child exits — stop() sends SIGKILL if needed,
            // so this will return promptly. The read loop is the sole caller of
            // waitpid for this PID to avoid double-reap races.
            var status: Int32 = 0
            waitpid(childPID, &status, 0)
            let exited = (status & 0x7f) == 0
            let code: Int32 = exited ? (status >> 8) & 0xff : -1

            await MainActor.run { [weak self] in
                guard let self, self.exitCode == nil else { return }
                self.isRunning = false
                self.exitCode = code
                self.onExit?(code)
            }
        }
    }
}
