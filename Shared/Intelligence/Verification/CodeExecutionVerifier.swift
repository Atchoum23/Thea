// CodeExecutionVerifier.swift
// Thea
//
// AI-powered code execution verification
// Supports Swift, JavaScript (JavaScriptCore), and Python
// Executes code to verify it actually works

import Foundation
import OSLog
import JavaScriptCore

// MARK: - Code Execution Verifier

/// Verifies code responses by actually executing them
@MainActor
public final class CodeExecutionVerifier {
    private let logger = Logger(subsystem: "com.thea.ai", category: "CodeExecutionVerifier")

    // Execution engines
    private let jsEngine = JavaScriptEngine()
    #if os(macOS)
    private let swiftEngine = SwiftExecutionEngine()
    private let pythonEngine = PythonExecutionEngine()
    #endif

    // Configuration
    public var executionTimeout: TimeInterval = 10.0
    public var maxOutputLength: Int = 10000
    public var sandboxEnabled: Bool = true

    // MARK: - Verification

    /// Verify code by executing it
    public func verify(
        response: String,
        language: ValidationContext.CodeLanguage
    ) async -> CodeVerificationResult {
        logger.info("Verifying code for language: \(language.rawValue)")

        // 1. Extract code blocks from response
        let codeBlocks = extractCodeBlocks(from: response, language: language)

        guard !codeBlocks.isEmpty else {
            return CodeVerificationResult(
                source: ConfidenceSource(
                    type: .codeExecution,
                    name: "Code Execution",
                    confidence: 0.5,
                    weight: 0.25,
                    details: "No executable code blocks found",
                    verified: false
                ),
                factors: [],
                executionResults: []
            )
        }

        // 2. Execute each code block
        var results: [CodeExecResult] = []

        for block in codeBlocks.prefix(3) {  // Limit to 3 blocks
            let result = await execute(code: block.code, language: block.language)
            results.append(result)
        }

        // 3. Calculate confidence based on execution results
        let successCount = results.filter { $0.success }.count
        let successRate = Double(successCount) / Double(results.count)

        var confidence = successRate * 0.8  // Base confidence from success rate

        // Bonus for clean execution (no warnings)
        let cleanCount = results.filter { $0.success && $0.warnings.isEmpty }.count
        if cleanCount == results.count {
            confidence += 0.1
        }

        // Penalty for errors
        let errorCount = results.filter { !$0.success }.count
        confidence -= Double(errorCount) * 0.15

        confidence = min(1.0, max(0.0, confidence))

        // 4. Build factors
        var factors: [ConfidenceDecomposition.DecompositionFactor] = []

        factors.append(ConfidenceDecomposition.DecompositionFactor(
            name: "Execution Success",
            contribution: (successRate - 0.5) * 2,
            explanation: "\(successCount)/\(results.count) code blocks executed successfully"
        ))

        let allErrors = results.flatMap(\.errors)
        if !allErrors.isEmpty {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Execution Errors",
                contribution: -0.3 * Double(min(3, allErrors.count)),
                explanation: "\(allErrors.count) execution error(s): \(allErrors.first ?? "")"
            ))
        }

        let allWarnings = results.flatMap(\.warnings)
        if !allWarnings.isEmpty {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Warnings",
                contribution: -0.1 * Double(min(5, allWarnings.count)),
                explanation: "\(allWarnings.count) warning(s) during execution"
            ))
        }

        let outputSamples = results.filter { $0.success }.compactMap { $0.output?.prefix(100) }
        let details = """
            Executed \(results.count) code block(s).
            Success: \(successCount), Failed: \(errorCount)
            Languages: \(Set(codeBlocks.map(\.language.rawValue)).joined(separator: ", "))
            \(outputSamples.isEmpty ? "" : "Sample output: \(outputSamples.first ?? "")")
            """

        return CodeVerificationResult(
            source: ConfidenceSource(
                type: .codeExecution,
                name: "Code Execution",
                confidence: confidence,
                weight: 0.25,
                details: details,
                verified: successRate >= 0.8
            ),
            factors: factors,
            executionResults: results
        )
    }

    // MARK: - Code Extraction

    private func extractCodeBlocks(
        from response: String,
        language: ValidationContext.CodeLanguage
    ) -> [CodeBlock] {
        var blocks: [CodeBlock] = []

        // Pattern: ```language\ncode\n```
        let pattern = #"```(\w*)\n([\s\S]*?)```"#

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            logger.debug("Could not compile code block regex: \(error.localizedDescription)")
            return blocks
        }

        let range = NSRange(response.startIndex..., in: response)
        let matches = regex.matches(in: response, range: range)

        for match in matches {
            guard let codeRange = Range(match.range(at: 2), in: response) else { continue }
            let code = String(response[codeRange])

            var detectedLanguage = language
            if let langRange = Range(match.range(at: 1), in: response) {
                let langStr = String(response[langRange]).lowercased()
                detectedLanguage = detectLanguage(from: langStr)
            }

            blocks.append(CodeBlock(code: code, language: detectedLanguage))
        }

        return blocks
    }

    private func detectLanguage(from hint: String) -> ValidationContext.CodeLanguage {
        switch hint.lowercased() {
        case "swift": return .swift
        case "javascript", "js", "node": return .javascript
        case "python", "py", "python3": return .python
        default: return .unknown
        }
    }

    // MARK: - Execution

    private func execute(
        code: String,
        language: ValidationContext.CodeLanguage
    ) async -> CodeExecResult {
        switch language {
        case .javascript:
            return await jsEngine.execute(code)

        case .swift:
            #if os(macOS)
            return await swiftEngine.execute(code)
            #else
            return CodeExecResult(
                success: false,
                output: nil,
                errors: ["Swift execution not available on this platform"],
                warnings: [],
                executionTime: 0
            )
            #endif

        case .python:
            #if os(macOS)
            return await pythonEngine.execute(code)
            #else
            return CodeExecResult(
                success: false,
                output: nil,
                errors: ["Python execution not available on this platform"],
                warnings: [],
                executionTime: 0
            )
            #endif

        case .unknown:
            return CodeExecResult(
                success: false,
                output: nil,
                errors: ["Unknown language - cannot execute"],
                warnings: [],
                executionTime: 0
            )
        }
    }
}

// MARK: - JavaScript Engine (JavaScriptCore)

// @unchecked Sendable: stateless engine — a fresh JSContext is created per execute() call on a
// background DispatchQueue; no shared mutable state between concurrent invocations
/// JavaScript execution using built-in JavaScriptCore
final class JavaScriptEngine: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.thea.ai", category: "JavaScriptEngine")

    func execute(_ code: String) async -> CodeExecResult {
        let startTime = Date()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let context = JSContext() else {
                    continuation.resume(returning: CodeExecResult(
                        success: false,
                        output: nil,
                        errors: ["Failed to create JavaScript context"],
                        warnings: [],
                        executionTime: Date().timeIntervalSince(startTime)
                    ))
                    return
                }

                var warnings: [String] = []
                var errors: [String] = []

                // Capture console.log
                var consoleOutput: [String] = []
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

                let output: String?
                if !consoleOutput.isEmpty {
                    output = consoleOutput.joined(separator: "\n")
                } else if let resultValue = result, !resultValue.isUndefined, !resultValue.isNull {
                    output = resultValue.toString()
                } else {
                    output = nil
                }

                // Check for warnings in output
                warnings = consoleOutput.filter { $0.contains("[WARN]") }

                continuation.resume(returning: CodeExecResult(
                    success: errors.isEmpty,
                    output: output,
                    errors: errors,
                    warnings: warnings,
                    executionTime: Date().timeIntervalSince(startTime)
                ))
            }
        }
    }
}

// MARK: - Swift Execution Engine (macOS only)

#if os(macOS)
// @unchecked Sendable: spawns a new Process per execute() call; logger is thread-safe;
// no shared mutable state — each invocation is fully isolated via Process API
/// Swift execution using swift command
final class SwiftExecutionEngine: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.thea.ai", category: "SwiftExecutionEngine")

    func execute(_ code: String) async -> CodeExecResult {
        let startTime = Date()

        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("thea_verify_\(UUID().uuidString).swift")

        do {
            // Wrap code to make it executable
            let executableCode = wrapForExecution(code)
            try executableCode.write(to: tempFile, atomically: true, encoding: .utf8)

            // Execute with swift
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            process.arguments = [tempFile.path]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            // Timeout handling
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
                if process.isRunning {
                    process.terminate()
                }
            }

            process.waitUntilExit()
            timeoutTask.cancel()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean up
            do { try FileManager.default.removeItem(at: tempFile) } catch { logger.debug("Could not remove temp file: \(error.localizedDescription)") }

            var errors: [String] = []
            var warnings: [String] = []

            if let errorOutput, !errorOutput.isEmpty {
                // Parse Swift compiler output
                let lines = errorOutput.components(separatedBy: "\n")
                for line in lines {
                    if line.contains("error:") {
                        errors.append(line)
                    } else if line.contains("warning:") {
                        warnings.append(line)
                    }
                }
            }

            return CodeExecResult(
                success: process.terminationStatus == 0 && errors.isEmpty,
                output: output,
                errors: errors,
                warnings: warnings,
                executionTime: Date().timeIntervalSince(startTime)
            )

        } catch {
            do { try FileManager.default.removeItem(at: tempFile) } catch { logger.debug("Could not remove temp file: \(error.localizedDescription)") }
            return CodeExecResult(
                success: false,
                output: nil,
                errors: [error.localizedDescription],
                warnings: [],
                executionTime: Date().timeIntervalSince(startTime)
            )
        }
    }

    private func wrapForExecution(_ code: String) -> String {
        // Check if code already has imports
        let hasFoundationImport = code.contains("import Foundation")

        var wrapped = ""
        if !hasFoundationImport {
            wrapped += "import Foundation\n"
        }

        wrapped += code

        return wrapped
    }
}

// MARK: - Python Execution Engine (macOS only)

/// Python execution using python3 command
final class PythonExecutionEngine: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.thea.ai", category: "PythonExecutionEngine")

    func execute(_ code: String) async -> CodeExecResult {
        let startTime = Date()

        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("thea_verify_\(UUID().uuidString).py")

        do {
            try code.write(to: tempFile, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [tempFile.path]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            // Timeout handling
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds
                if process.isRunning {
                    process.terminate()
                }
            }

            process.waitUntilExit()
            timeoutTask.cancel()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean up
            do { try FileManager.default.removeItem(at: tempFile) } catch { logger.debug("Could not remove temp file: \(error.localizedDescription)") }

            var errors: [String] = []
            if let errorOutput, !errorOutput.isEmpty {
                errors = [errorOutput]
            }

            return CodeExecResult(
                success: process.terminationStatus == 0,
                output: output,
                errors: errors,
                warnings: [],
                executionTime: Date().timeIntervalSince(startTime)
            )

        } catch {
            do { try FileManager.default.removeItem(at: tempFile) } catch { logger.debug("Could not remove temp file: \(error.localizedDescription)") }
            return CodeExecResult(
                success: false,
                output: nil,
                errors: [error.localizedDescription],
                warnings: [],
                executionTime: Date().timeIntervalSince(startTime)
            )
        }
    }
}
#endif

// MARK: - Supporting Types

struct CodeBlock: Sendable {
    let code: String
    let language: ValidationContext.CodeLanguage
}

public struct CodeExecResult: Sendable {
    public let success: Bool
    public let output: String?
    public let errors: [String]
    public let warnings: [String]
    public let executionTime: TimeInterval
}

public struct CodeVerificationResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let executionResults: [CodeExecResult]
}
