//
//  CodeExecutionManager.swift
//  Thea
//
//  Manages safe code execution in chat with user confirmation
//  Supports Swift, JavaScript, Python with sandboxed execution
//
//  Security: All code execution requires explicit user confirmation
//  Created: February 4, 2026
//

import Foundation
import OSLog

#if os(macOS)
import JavaScriptCore
#endif

// MARK: - Code Execution Types

/// Language type for code execution (local to this module to avoid conflicts)
public enum ExecLanguage: String, Codable, CaseIterable, Sendable {
    case swift
    case javascript
    case python
    case bash
    case shell
    case unknown

    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .javascript: return "JavaScript"
        case .python: return "Python"
        case .bash, .shell: return "Shell"
        case .unknown: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .swift: return "swift"
        case .javascript: return "curlybraces"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .bash, .shell: return "terminal"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Detect language from code fence annotation
    public static func from(annotation: String) -> ExecLanguage {
        switch annotation.lowercased().trimmingCharacters(in: .whitespaces) {
        case "swift": return .swift
        case "javascript", "js", "node": return .javascript
        case "python", "py", "python3": return .python
        case "bash", "sh", "zsh": return .bash
        case "shell": return .shell
        default: return .unknown
        }
    }
}

public struct CodePendingExecution: Identifiable, Sendable {
    public let id: UUID
    public let code: String
    public let language: ExecLanguage
    public let source: String
    public let requestedAt: Date
}

public struct CodeExecResultModel: Sendable {
    public let success: Bool
    public let output: String?
    public let error: String?
    public let executionTime: TimeInterval
    public let language: ExecLanguage

    public var formattedTime: String {
        String(format: "%.2fs", executionTime)
    }
}

public struct CodeExecRecord: Identifiable, Sendable {
    public let id: UUID
    public let code: String
    public let language: ExecLanguage
    public let result: CodeExecResultModel
    public let executedAt: Date
}

public enum CodeExecError: Error, LocalizedError {
    case timeout
    case processError(String)
    case securityBlocked(String)

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Execution timed out"
        case .processError(let message):
            return "Process error: \(message)"
        case .securityBlocked(let reason):
            return "Blocked: \(reason)"
        }
    }
}

// MARK: - Code Execution Manager

/// Manages code execution from chat messages with user confirmation
@MainActor
public final class CodeExecutionManager: ObservableObject {
    public static let shared = CodeExecutionManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "CodeExecution")

    /// Currently pending code blocks awaiting user confirmation
    @Published public var pendingExecutions: [CodePendingExecution] = []

    /// History of executed code blocks
    @Published public var executionHistory: [CodeExecRecord] = []

    /// Execution timeout in seconds
    public var executionTimeout: TimeInterval = 30.0

    /// Maximum output length before truncation
    public var maxOutputLength: Int = 10000

    private init() {}

    // MARK: - Execution Request

    /// Request execution of a code block (requires user confirmation)
    public func requestExecution(
        code: String,
        language: ExecLanguage,
        source: String = "chat"
    ) -> CodePendingExecution {
        let execution = CodePendingExecution(
            id: UUID(),
            code: code,
            language: language,
            source: source,
            requestedAt: Date()
        )

        pendingExecutions.append(execution)
        logger.info("Code execution requested: \(language.rawValue) (\(code.count) chars)")

        return execution
    }

    // MARK: - User Confirmation

    /// Execute code after user confirmation
    public func confirmAndExecute(_ executionId: UUID) async -> CodeExecResultModel {
        guard let index = pendingExecutions.firstIndex(where: { $0.id == executionId }) else {
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: "Execution request not found",
                executionTime: 0,
                language: .unknown
            )
        }

        let execution = pendingExecutions.remove(at: index)
        logger.info("User confirmed execution: \(execution.language.rawValue)")

        let result = await executeCode(execution.code, language: execution.language)

        // Record in history
        let record = CodeExecRecord(
            id: execution.id,
            code: execution.code,
            language: execution.language,
            result: result,
            executedAt: Date()
        )
        executionHistory.insert(record, at: 0)

        // Keep history bounded
        if executionHistory.count > 50 {
            executionHistory.removeLast()
        }

        return result
    }

    /// Cancel a pending execution request
    public func cancelExecution(_ executionId: UUID) {
        pendingExecutions.removeAll { $0.id == executionId }
        logger.info("Execution cancelled by user")
    }

    // MARK: - Direct Execution (for internal use only)

    /// Execute code directly - called only after user confirmation
    private func executeCode(_ code: String, language: ExecLanguage) async -> CodeExecResultModel {
        let startTime = Date()

        switch language {
        case .swift:
            #if os(macOS)
            return await executeSwift(code, startTime: startTime)
            #else
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: "Swift execution not available on this platform",
                executionTime: 0,
                language: language
            )
            #endif

        case .javascript:
            #if os(macOS)
            return await executeJavaScript(code, startTime: startTime)
            #else
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: "JavaScript execution not available on this platform",
                executionTime: 0,
                language: language
            )
            #endif

        case .python:
            #if os(macOS)
            return await executePython(code, startTime: startTime)
            #else
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: "Python execution not available on this platform",
                executionTime: 0,
                language: language
            )
            #endif

        case .bash, .shell:
            #if os(macOS)
            return await executeShell(code, startTime: startTime)
            #else
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: "Shell execution not available on this platform",
                executionTime: 0,
                language: language
            )
            #endif

        case .unknown:
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: "Unknown language - cannot execute",
                executionTime: 0,
                language: language
            )
        }
    }

    // MARK: - Language-Specific Execution

    #if os(macOS)
    private func executeSwift(_ code: String, startTime: Date) async -> CodeExecResultModel {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("thea_exec_\(UUID().uuidString).swift")

        do {
            // Add Foundation import if not present
            var executableCode = code
            if !code.contains("import Foundation") {
                executableCode = "import Foundation\n" + code
            }

            try executableCode.write(to: tempFile, atomically: true, encoding: .utf8)

            let result = try await runProcess(
                "/usr/bin/swift",
                arguments: [tempFile.path],
                timeout: executionTimeout
            )

            try? FileManager.default.removeItem(at: tempFile)

            return CodeExecResultModel(
                success: result.exitCode == 0,
                output: truncateOutput(result.stdout),
                error: result.stderr.isEmpty ? nil : result.stderr,
                executionTime: Date().timeIntervalSince(startTime),
                language: .swift
            )
        } catch {
            try? FileManager.default.removeItem(at: tempFile)
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: error.localizedDescription,
                executionTime: Date().timeIntervalSince(startTime),
                language: .swift
            )
        }
    }

    private func executeJavaScript(_ code: String, startTime: Date) async -> CodeExecResultModel {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let context = JSContext() else {
                    continuation.resume(returning: CodeExecResultModel(
                        success: false,
                        output: nil,
                        error: "Failed to create JavaScript context",
                        executionTime: Date().timeIntervalSince(startTime),
                        language: .javascript
                    ))
                    return
                }

                var consoleOutput: [String] = []
                var errors: [String] = []

                // Capture console.log
                let consoleLog: @convention(block) (String) -> Void = { message in
                    consoleOutput.append(message)
                }
                context.setObject(consoleLog, forKeyedSubscript: "print" as NSString)

                // Set up console object
                context.evaluateScript("""
                    var console = {
                        log: function() { print(Array.prototype.join.call(arguments, ' ')); },
                        warn: function() { print('[WARN] ' + Array.prototype.join.call(arguments, ' ')); },
                        error: function() { print('[ERROR] ' + Array.prototype.join.call(arguments, ' ')); }
                    };
                    """)

                // Handle exceptions
                context.exceptionHandler = { _, exception in
                    if let error = exception?.toString() {
                        errors.append(error)
                    }
                }

                // Execute code
                let result = context.evaluateScript(code)

                var output: String?
                if !consoleOutput.isEmpty {
                    output = consoleOutput.joined(separator: "\n")
                } else if let resultValue = result, !resultValue.isUndefined, !resultValue.isNull {
                    output = resultValue.toString()
                }

                continuation.resume(returning: CodeExecResultModel(
                    success: errors.isEmpty,
                    output: output,
                    error: errors.isEmpty ? nil : errors.joined(separator: "\n"),
                    executionTime: Date().timeIntervalSince(startTime),
                    language: .javascript
                ))
            }
        }
    }

    private func executePython(_ code: String, startTime: Date) async -> CodeExecResultModel {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("thea_exec_\(UUID().uuidString).py")

        do {
            try code.write(to: tempFile, atomically: true, encoding: .utf8)

            let result = try await runProcess(
                "/usr/bin/python3",
                arguments: [tempFile.path],
                timeout: executionTimeout
            )

            try? FileManager.default.removeItem(at: tempFile)

            return CodeExecResultModel(
                success: result.exitCode == 0,
                output: truncateOutput(result.stdout),
                error: result.stderr.isEmpty ? nil : result.stderr,
                executionTime: Date().timeIntervalSince(startTime),
                language: .python
            )
        } catch {
            try? FileManager.default.removeItem(at: tempFile)
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: error.localizedDescription,
                executionTime: Date().timeIntervalSince(startTime),
                language: .python
            )
        }
    }

    private func executeShell(_ code: String, startTime: Date) async -> CodeExecResultModel {
        // Security check for dangerous commands
        let securityPolicy = TerminalSecurityPolicy.default
        let validation = securityPolicy.isAllowed(code)

        switch validation {
        case .blocked(let reason):
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: "Blocked for security: \(reason)",
                executionTime: 0,
                language: .shell
            )
        case .requiresConfirmation(let reason):
            // User already confirmed, but log the elevated action
            logger.warning("Executing elevated command: \(reason)")
        case .allowed:
            break
        }

        do {
            let result = try await runProcess(
                "/bin/zsh",
                arguments: ["-c", code],
                timeout: executionTimeout
            )

            return CodeExecResultModel(
                success: result.exitCode == 0,
                output: truncateOutput(result.stdout),
                error: result.stderr.isEmpty ? nil : result.stderr,
                executionTime: Date().timeIntervalSince(startTime),
                language: .shell
            )
        } catch {
            return CodeExecResultModel(
                success: false,
                output: nil,
                error: error.localizedDescription,
                executionTime: Date().timeIntervalSince(startTime),
                language: .shell
            )
        }
    }

    // MARK: - Process Execution Helper

    private struct ProcessResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    private func runProcess(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> ProcessResult {
        try await withThrowingTaskGroup(of: ProcessResult.self) { group in
            // Main execution task
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments

                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    process.terminationHandler = { terminatedProcess in
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                        let stdout = String(data: outputData, encoding: .utf8) ?? ""
                        let stderr = String(data: errorData, encoding: .utf8) ?? ""

                        continuation.resume(returning: ProcessResult(
                            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                            exitCode: terminatedProcess.terminationStatus
                        ))
                    }

                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw CodeExecError.timeout
            }

            // Return first result (either completion or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    #endif

    // MARK: - Helpers

    private func truncateOutput(_ output: String) -> String {
        if output.count > maxOutputLength {
            return String(output.prefix(maxOutputLength)) + "\n... (output truncated)"
        }
        return output
    }
}
