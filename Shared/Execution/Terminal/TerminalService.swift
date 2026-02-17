import Foundation
import OSLog

// MARK: - TerminalService

// Hardened terminal execution service for running shell commands and build tools

public actor TerminalService {
    public static let shared = TerminalService()

    private let logger = Logger(subsystem: "com.thea.system", category: "TerminalService")

    private init() {}

    // MARK: - Public Types

    public struct TerminalResult: Sendable {
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
    ) async throws -> TerminalResult {
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
            try await Task.sleep(for: .seconds(timeout))
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

        return TerminalResult(
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
    ) async throws -> TerminalResult {
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
            try await Task.sleep(for: .seconds(timeout))
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

        return TerminalResult(
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
    ) async throws -> TerminalResult {
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
    ) async throws -> TerminalResult {
        try await run(
            command: "/usr/bin/git",
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )
    }

    // MARK: - Test Execution

    /// Run Swift package tests
    public func runSwiftTests(
        workingDirectory: String? = nil,
        filter: String? = nil,
        timeout: TimeInterval = 300.0
    ) async throws -> TestResult {
        var arguments = ["test"]

        if let filter {
            arguments.append(contentsOf: ["--filter", filter])
        }

        let result = try await swift(
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )

        return parseTestResult(result)
    }

    /// Run Xcode tests for a specific scheme
    public func runXcodeTests(
        scheme: String,
        destination: String = "platform=macOS",
        workingDirectory: String? = nil,
        timeout: TimeInterval = 600.0
    ) async throws -> TestResult {
        let script = """
        xcodebuild test \
            -scheme "\(scheme)" \
            -destination "\(destination)" \
            -quiet \
            2>&1
        """

        let result = try await runShellScript(
            script,
            workingDirectory: workingDirectory,
            timeout: timeout
        )

        return parseXcodeTestResult(result)
    }

    /// Parse swift test output into structured result
    private func parseTestResult(_ result: TerminalResult) -> TestResult {
        let output = result.stdout + result.stderr

        // Count passed and failed tests
        var passed = 0
        var failed = 0
        var skipped = 0
        var failedTests: [String] = []

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.contains("passed") && line.contains("Executed") {
                // Parse "Executed X tests, with Y failures"
                if let executedMatch = line.range(of: #"Executed (\d+) tests?, with (\d+) failures?"#, options: .regularExpression) {
                    let matchedText = String(line[executedMatch])
                    let numbers = matchedText.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                    if numbers.count >= 2 {
                        let total = Int(numbers[0]) ?? 0
                        failed = Int(numbers[1]) ?? 0
                        passed = total - failed
                    }
                }
            } else if line.contains("Test Case") && line.contains("failed") {
                // Extract failed test name
                if let nameRange = line.range(of: #"'[^']+'"#, options: .regularExpression) {
                    let testName = String(line[nameRange]).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                    failedTests.append(testName)
                }
            } else if line.contains("skipped") {
                skipped += 1
            }
        }

        return TestResult(
            success: result.isSuccess && failed == 0,
            totalTests: passed + failed + skipped,
            passed: passed,
            failed: failed,
            skipped: skipped,
            failedTests: failedTests,
            duration: result.duration,
            output: output
        )
    }

    /// Parse xcodebuild test output
    private func parseXcodeTestResult(_ result: TerminalResult) -> TestResult {
        let output = result.stdout + result.stderr

        var passed = 0
        var failed = 0
        let skipped = 0
        var failedTests: [String] = []

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.contains("Test Suite") && line.contains("passed") {
                // Parse final summary
                if let executedMatch = line.range(of: #"Executed (\d+) tests?, with (\d+) failures?"#, options: .regularExpression) {
                    let matchedText = String(line[executedMatch])
                    let numbers = matchedText.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                    if numbers.count >= 2 {
                        let total = Int(numbers[0]) ?? 0
                        let failures = Int(numbers[1]) ?? 0
                        passed = total - failures
                        failed = failures
                    }
                }
            } else if line.contains("** TEST FAILED **") || line.contains("Failing tests:") {
                // Mark as failed
                if line.contains("-[") {
                    failedTests.append(line.trimmingCharacters(in: .whitespaces))
                }
            }
        }

        return TestResult(
            success: result.isSuccess && failed == 0,
            totalTests: passed + failed + skipped,
            passed: passed,
            failed: failed,
            skipped: skipped,
            failedTests: failedTests,
            duration: result.duration,
            output: output
        )
    }

    /// Structured test result
    public struct TestResult: Sendable {
        public let success: Bool
        public let totalTests: Int
        public let passed: Int
        public let failed: Int
        public let skipped: Int
        public let failedTests: [String]
        public let duration: TimeInterval
        public let output: String

        public var summary: String {
            if success {
                return "✅ All \(totalTests) tests passed in \(String(format: "%.2f", duration))s"
            } else {
                return "❌ \(failed)/\(totalTests) tests failed:\n" + failedTests.joined(separator: "\n")
            }
        }
    }

    // MARK: - Git Automation

    /// Create a new branch
    public func gitCreateBranch(
        name: String,
        workingDirectory: String? = nil
    ) async throws -> TerminalResult {
        try await git(
            arguments: ["checkout", "-b", name],
            workingDirectory: workingDirectory
        )
    }

    /// Commit all changes with a message
    public func gitCommitAll(
        message: String,
        workingDirectory: String? = nil
    ) async throws -> TerminalResult {
        // Stage all changes
        _ = try await git(
            arguments: ["add", "-A"],
            workingDirectory: workingDirectory
        )

        // Commit
        return try await git(
            arguments: ["commit", "-m", message],
            workingDirectory: workingDirectory
        )
    }

    /// Get current branch name
    public func gitCurrentBranch(
        workingDirectory: String? = nil
    ) async throws -> String {
        let result = try await git(
            arguments: ["branch", "--show-current"],
            workingDirectory: workingDirectory
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get status summary
    public func gitStatus(
        workingDirectory: String? = nil
    ) async throws -> GitStatus {
        let result = try await git(
            arguments: ["status", "--porcelain"],
            workingDirectory: workingDirectory
        )

        var modified = 0
        var added = 0
        var deleted = 0
        var untracked = 0

        for line in result.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            let status = String(line.prefix(2))
            switch status.trimmingCharacters(in: .whitespaces) {
            case "M", "MM", "AM":
                modified += 1
            case "A":
                added += 1
            case "D":
                deleted += 1
            case "??":
                untracked += 1
            default:
                break
            }
        }

        return GitStatus(
            modified: modified,
            added: added,
            deleted: deleted,
            untracked: untracked,
            hasChanges: modified + added + deleted + untracked > 0
        )
    }

    /// Structured git status
    public struct GitStatus: Sendable {
        public let modified: Int
        public let added: Int
        public let deleted: Int
        public let untracked: Int
        public let hasChanges: Bool

        public var summary: String {
            if !hasChanges {
                return "Clean working directory"
            }
            var parts: [String] = []
            if modified > 0 { parts.append("\(modified) modified") }
            if added > 0 { parts.append("\(added) added") }
            if deleted > 0 { parts.append("\(deleted) deleted") }
            if untracked > 0 { parts.append("\(untracked) untracked") }
            return parts.joined(separator: ", ")
        }
    }
}
