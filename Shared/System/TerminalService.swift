import Foundation
import OSLog

// MARK: - TerminalService

// Hardened terminal execution service for running shell commands and build tools

public actor TerminalService {
    public static let shared = TerminalService()

    private let logger = Logger(subsystem: "com.thea.system", category: "TerminalService")

    private init() {}

    // MARK: - Public Types

    public struct CommandResult: Sendable {
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String
        public let duration: TimeInterval

        public var isSuccess: Bool {
            exitCode == 0
        }

        public init(exitCode: Int32, stdout: String, stderr: String, duration: TimeInterval) {
            self.exitCode = exitCode
            self.stdout = stdout
            self.stderr = stderr
            self.duration = duration
        }
    }

    public enum TerminalError: LocalizedError, Sendable {
        case commandFailed(String)
        case processError(String)
        case timeout
        case invalidCommand

        public var errorDescription: String? {
            switch self {
            case let .commandFailed(message):
                "Command failed: \(message)"
            case let .processError(message):
                "Process error: \(message)"
            case .timeout:
                "Command timed out"
            case .invalidCommand:
                "Invalid command"
            }
        }
    }

    // MARK: - Xcode Build Integration

    public func runXcodeBuild(
        scheme: String = "TheamacOS",
        configuration: String = "Debug"
    ) async throws -> XcodeBuildRunner.BuildResult {
        logger.info("Running xcodebuild via XcodeBuildRunner")
        return try await XcodeBuildRunner.shared.build(
            scheme: scheme,
            configuration: configuration
        )
    }

    // MARK: - General Command Execution

    public func run(
        command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        timeout: TimeInterval = 60.0
    ) async throws -> CommandResult {
        logger.info("Running command: \(command) \(arguments.joined(separator: " "))")

        let startTime = Date()

        // Set up Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        // Set up pipes for output capture
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Launch process
        do {
            try process.run()
        } catch {
            throw TerminalError.processError(error.localizedDescription)
        }

        // Set up timeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                logger.warning("Command timeout reached, terminating process")
                process.terminate()
            }
        }

        // Wait for completion
        process.waitUntilExit()
        timeoutTask.cancel()

        // Check if timed out
        if !Task.isCancelled, process.terminationReason == .exit, process.terminationStatus == 15 {
            throw TerminalError.timeout
        }

        // Capture output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let duration = Date().timeIntervalSince(startTime)

        logger.info("Command completed with exit code \(process.terminationStatus) in \(String(format: "%.2f", duration))s")

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: duration
        )
    }

    // MARK: - Shell Script Execution

    public func runShellScript(
        _ script: String,
        workingDirectory: String? = nil,
        timeout: TimeInterval = 60.0
    ) async throws -> CommandResult {
        logger.info("Running shell script")

        let startTime = Date()

        // Set up Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]

        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        // Set up pipes for output capture
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Launch process
        do {
            try process.run()
        } catch {
            throw TerminalError.processError(error.localizedDescription)
        }

        // Set up timeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                logger.warning("Shell script timeout reached, terminating process")
                process.terminate()
            }
        }

        // Wait for completion
        process.waitUntilExit()
        timeoutTask.cancel()

        // Check if timed out
        if !Task.isCancelled, process.terminationReason == .exit, process.terminationStatus == 15 {
            throw TerminalError.timeout
        }

        // Capture output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let duration = Date().timeIntervalSince(startTime)

        logger.info("Shell script completed with exit code \(process.terminationStatus) in \(String(format: "%.2f", duration))s")

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: duration
        )
    }

    // MARK: - Convenience Methods

    public func swift(
        arguments: [String],
        workingDirectory: String? = nil,
        timeout: TimeInterval = 60.0
    ) async throws -> CommandResult {
        try await run(
            command: "/usr/bin/swift",
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )
    }

    public func git(
        arguments: [String],
        workingDirectory: String? = nil,
        timeout: TimeInterval = 60.0
    ) async throws -> CommandResult {
        try await run(
            command: "/usr/bin/git",
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )
    }
}
