import Foundation
import OSLog

// MARK: - XcodeBuildRunner
// Reliable xcodebuild execution with structured error parsing

public actor XcodeBuildRunner {
    public static let shared = XcodeBuildRunner()

    private let logger = Logger(subsystem: "com.thea.system", category: "XcodeBuildRunner")

    private init() {}

    // MARK: - Public Types

    public struct BuildResult: Sendable {
        public let success: Bool
        public let stdout: String
        public let stderr: String
        public let errors: [CompilerError]
        public let warnings: [CompilerWarning]
        public let duration: TimeInterval

        public init(
            success: Bool,
            stdout: String,
            stderr: String,
            errors: [CompilerError],
            warnings: [CompilerWarning],
            duration: TimeInterval
        ) {
            self.success = success
            self.stdout = stdout
            self.stderr = stderr
            self.errors = errors
            self.warnings = warnings
            self.duration = duration
        }
    }

    public struct CompilerError: Sendable, Codable, Identifiable {
        public let id: UUID
        public let file: String
        public let line: Int
        public let column: Int
        public let message: String
        public let errorType: ErrorType

        public init(
            file: String,
            line: Int,
            column: Int,
            message: String,
            errorType: ErrorType
        ) {
            self.id = UUID()
            self.file = file
            self.line = line
            self.column = column
            self.message = message
            self.errorType = errorType
        }
    }

    public struct CompilerWarning: Sendable, Codable, Identifiable {
        public let id: UUID
        public let file: String
        public let line: Int
        public let column: Int
        public let message: String

        public init(
            file: String,
            line: Int,
            column: Int,
            message: String
        ) {
            self.id = UUID()
            self.file = file
            self.line = line
            self.column = column
            self.message = message
        }
    }

    public enum ErrorType: String, Codable, Sendable {
        case error
        case warning
        case note
    }

    public enum BuildError: LocalizedError, Sendable {
        case buildFailed(String)
        case processError(String)
        case invalidProjectPath
        case timeout

        public var errorDescription: String? {
            switch self {
            case .buildFailed(let message):
                return "Build failed: \(message)"
            case .processError(let message):
                return "Process error: \(message)"
            case .invalidProjectPath:
                return "Invalid project path"
            case .timeout:
                return "Build timed out"
            }
        }
    }

    // MARK: - Build Execution

    public func build(
        scheme: String = "TheamacOS",
        configuration: String = "Debug",
        projectPath: String = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development",
        timeout: TimeInterval = 300.0
    ) async throws -> BuildResult {
        logger.info("Starting build - scheme: \(scheme), configuration: \(configuration)")

        let startTime = Date()

        // Verify project path exists
        guard FileManager.default.fileExists(atPath: projectPath) else {
            throw BuildError.invalidProjectPath
        }

        // Set up Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = [
            "-scheme", scheme,
            "-configuration", configuration,
            "build"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        // Set up pipes for output capture
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Launch process
        do {
            try process.run()
        } catch {
            throw BuildError.processError(error.localizedDescription)
        }

        // Set up timeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if process.isRunning {
                logger.warning("Build timeout reached, terminating process")
                process.terminate()
            }
        }

        // Wait for completion
        process.waitUntilExit()
        timeoutTask.cancel()

        // Check if timed out
        if !Task.isCancelled && process.terminationReason == .exit && process.terminationStatus == 15 {
            throw BuildError.timeout
        }

        // Capture output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        let duration = Date().timeIntervalSince(startTime)

        // Parse errors and warnings
        let combinedOutput = stdout + "\n" + stderr
        let errors = parseErrors(from: combinedOutput)
        let warnings = parseWarnings(from: combinedOutput)

        let success = process.terminationStatus == 0

        if success {
            logger.info("✅ Build succeeded in \(String(format: "%.2f", duration))s")
        } else {
            logger.error("❌ Build failed with \(errors.count) errors, \(warnings.count) warnings in \(String(format: "%.2f", duration))s")
            let displayList = errors.deduplicated().sortedByLocation().map { "  • \($0.compactDisplayString)" }.joined(separator: "\n")
            if !displayList.isEmpty {
                logger.error("\nCompiler issues:\n\(displayList)")
            }
        }

        return BuildResult(
            success: success,
            stdout: stdout,
            stderr: stderr,
            errors: errors,
            warnings: warnings,
            duration: duration
        )
    }

    // MARK: - Error Parsing

    private func parseErrors(from output: String) -> [CompilerError] {
        var errors: [CompilerError] = []

        // Parse Xcode error format:
        // /path/to/file.swift:123:45: error: message
        // /path/to/file.swift:123:45: note: additional info

        let errorPattern = #"^(.+?):(\d+):(\d+):\s*(error|note):\s*(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: errorPattern, options: .anchorsMatchLines) else {
            return []
        }

        let nsString = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard match.numberOfRanges == 6 else { continue }

            let file = nsString.substring(with: match.range(at: 1))
            let lineStr = nsString.substring(with: match.range(at: 2))
            let columnStr = nsString.substring(with: match.range(at: 3))
            let typeStr = nsString.substring(with: match.range(at: 4))
            let message = nsString.substring(with: match.range(at: 5))

            guard let line = Int(lineStr),
                  let column = Int(columnStr),
                  let errorType = ErrorType(rawValue: typeStr) else {
                continue
            }

            let error = CompilerError(
                file: file,
                line: line,
                column: column,
                message: message,
                errorType: errorType
            )

            errors.append(error)
        }

        return errors
    }

    private func parseWarnings(from output: String) -> [CompilerWarning] {
        var warnings: [CompilerWarning] = []

        // Parse Xcode warning format:
        // /path/to/file.swift:123:45: warning: message

        let warningPattern = #"^(.+?):(\d+):(\d+):\s*warning:\s*(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: warningPattern, options: .anchorsMatchLines) else {
            return []
        }

        let nsString = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard match.numberOfRanges == 5 else { continue }

            let file = nsString.substring(with: match.range(at: 1))
            let lineStr = nsString.substring(with: match.range(at: 2))
            let columnStr = nsString.substring(with: match.range(at: 3))
            let message = nsString.substring(with: match.range(at: 4))

            guard let line = Int(lineStr),
                  let column = Int(columnStr) else {
                continue
            }

            let warning = CompilerWarning(
                file: file,
                line: line,
                column: column,
                message: message
            )

            warnings.append(warning)
        }

        return warnings
    }
}
// Helper extensions likely needed for the added logging:

private extension Array where Element == XcodeBuildRunner.CompilerError {
    func deduplicated() -> [XcodeBuildRunner.CompilerError] {
        var seen = Set<UUID>()
        return self.filter { error in
            if seen.contains(error.id) {
                return false
            } else {
                seen.insert(error.id)
                return true
            }
        }
    }
    func sortedByLocation() -> [XcodeBuildRunner.CompilerError] {
        self.sorted {
            if $0.file != $1.file {
                return $0.file < $1.file
            }
            if $0.line != $1.line {
                return $0.line < $1.line
            }
            return $0.column < $1.column
        }
    }
}

private extension XcodeBuildRunner.CompilerError {
    var compactDisplayString: String {
        "\(file):\(line):\(column): \(message)"
    }
}

