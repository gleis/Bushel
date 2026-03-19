import Foundation

/// Resolve the Apple container CLI binary path from user preferences.
var containerBinaryPath: String {
    let path = UserDefaults.standard.string(forKey: "containerBinaryPath") ?? "/usr/local/bin/container"
    return path.isEmpty ? "/usr/local/bin/container" : path
}

enum ShellError: LocalizedError {
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case binaryNotFound(path: String)
    case decodingFailed(command: String, error: Error)

    var errorDescription: String? {
        switch self {
        case .commandFailed(_, _, let stderr):
            return stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        case .binaryNotFound(let path):
            return "Container CLI not found at \(path). Install it with: brew install container"
        case .decodingFailed(let cmd, let error):
            return "Failed to parse output of '\(cmd)': \(error.localizedDescription)"
        }
    }

    var isSystemNotRunning: Bool {
        switch self {
        case .commandFailed(_, _, let stderr):
            let text = stderr.lowercased()
            return text.contains("xpc connection") || text.contains("container system start")
        default:
            return false
        }
    }

    var isBinaryNotFound: Bool {
        switch self {
        case .binaryNotFound: return true
        default: return false
        }
    }

    static func isSystemNotRunningError(_ error: Error) -> Bool {
        if let shellError = error as? ShellError {
            return shellError.isSystemNotRunning
        }
        return error.localizedDescription.contains("XPC connection")
            || error.localizedDescription.contains("container system start")
    }

    static func isBinaryNotFoundError(_ error: Error) -> Bool {
        if let shellError = error as? ShellError {
            return shellError.isBinaryNotFound
        }
        return false
    }
}

actor ShellService {
    static let shared = ShellService()

    private var binaryPath: String { containerBinaryPath }

    /// Execute a command and return stdout as a String.
    func run(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: stdout)
                } else {
                    continuation.resume(throwing: ShellError.commandFailed(
                        command: "container \(arguments.joined(separator: " "))",
                        exitCode: process.terminationStatus,
                        stderr: stderr
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ShellError.binaryNotFound(path: binaryPath))
            }
        }
    }

    /// Execute a command and decode JSON output.
    func runJSON<T: Decodable>(_ arguments: [String], as type: T.Type) async throws -> T {
        let output = try await run(arguments)
        guard let data = output.data(using: .utf8) else {
            throw ShellError.decodingFailed(
                command: arguments.joined(separator: " "),
                error: DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Could not convert output to UTF-8 data"
                ))
            )
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ShellError.decodingFailed(
                command: arguments.joined(separator: " "),
                error: error
            )
        }
    }

    /// Execute a command and stream stdout line-by-line.
    /// Returns (stream, cancel). Call cancel() to terminate the process.
    nonisolated func stream(_ arguments: [String]) -> (AsyncStream<String>, cancel: @Sendable () -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: containerBinaryPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let stream = AsyncStream<String> { continuation in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    // EOF: nil ourselves before finishing so no further invocations fire.
                    handle.readabilityHandler = nil
                    continuation.finish()
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    let lines = text.components(separatedBy: .newlines)
                    for line in lines where !line.isEmpty {
                        continuation.yield(line)
                    }
                }
            }

            // Do NOT nil readabilityHandler here — doing so races with already-queued
            // handler invocations and can drop final output. The readabilityHandler
            // nils itself on EOF. This call is a fallback for processes that exit
            // without closing stdout. AsyncStream.Continuation.finish() is idempotent.
            process.terminationHandler = { _ in
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                if process.isRunning {
                    process.terminate()
                }
                pipe.fileHandleForReading.readabilityHandler = nil
            }

            do {
                try process.run()
            } catch {
                continuation.finish()
            }
        }

        let cancel: @Sendable () -> Void = {
            if process.isRunning {
                process.terminate()
            }
        }

        return (stream, cancel)
    }

    /// Execute a command, wait for completion, discard stdout.
    func execute(_ arguments: [String]) async throws {
        _ = try await run(arguments)
    }
}
