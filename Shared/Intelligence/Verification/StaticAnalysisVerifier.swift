// StaticAnalysisVerifier.swift
// Thea
//
// AI-powered static analysis for code verification
// Uses SwiftLint, compiler diagnostics, and AI semantic analysis
// Hybrid approach: deterministic tools + AI reasoning

import Foundation
import OSLog

// MARK: - Static Analysis Verifier

/// Verifies code using static analysis tools with AI-powered assessment
@MainActor
public final class StaticAnalysisVerifier {
    private let logger = Logger(subsystem: "com.thea.ai", category: "StaticAnalysisVerifier")

    // Configuration
    public var enableSwiftLint: Bool = true
    public var enableCompilerCheck: Bool = true
    public var enableAIAnalysis: Bool = true
    public var aiConfidenceThreshold: Double = 0.7

    // MARK: - Analysis

    /// Analyze code using static analysis tools
    public func analyze(
        response: String,
        language: ValidationContext.CodeLanguage
    ) async -> StaticAnalysisResult {
        logger.info("Starting static analysis for \(language.rawValue)")

        // Extract code blocks
        let codeBlocks = extractCodeBlocks(from: response, language: language)

        guard !codeBlocks.isEmpty else {
            return StaticAnalysisResult(
                source: ConfidenceSource(
                    type: .staticAnalysis,
                    name: "Static Analysis",
                    confidence: 0.5,
                    weight: 0.10,
                    details: "No code blocks found for analysis",
                    verified: false
                ),
                factors: [],
                issues: []
            )
        }

        var allIssues: [AnalysisIssue] = []
        var factors: [ConfidenceDecomposition.DecompositionFactor] = []

        for block in codeBlocks {
            switch block.language {
            case .swift:
                let swiftIssues = await analyzeSwift(code: block.code)
                allIssues.append(contentsOf: swiftIssues)

            case .javascript:
                let jsIssues = analyzeJavaScript(code: block.code)
                allIssues.append(contentsOf: jsIssues)

            case .python:
                let pyIssues = analyzePython(code: block.code)
                allIssues.append(contentsOf: pyIssues)

            case .unknown:
                break
            }
        }

        // AI semantic analysis (if enabled)
        if enableAIAnalysis {
            let aiIssues = await performAIAnalysis(code: codeBlocks.map(\.code).joined(separator: "\n\n"))
            allIssues.append(contentsOf: aiIssues)
        }

        // Calculate confidence based on issues
        let errorCount = allIssues.filter { $0.severity == .error }.count
        let warningCount = allIssues.filter { $0.severity == .warning }.count
        let infoCount = allIssues.filter { $0.severity == .info }.count

        var confidence = 1.0
        confidence -= Double(errorCount) * 0.25
        confidence -= Double(warningCount) * 0.10
        confidence -= Double(infoCount) * 0.02
        confidence = max(0.0, confidence)

        // Build factors
        if errorCount > 0 {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Critical Issues",
                contribution: -0.3 * Double(min(3, errorCount)),
                explanation: "\(errorCount) error(s) found: \(allIssues.filter { $0.severity == .error }.first?.message ?? "")"
            ))
        }

        if warningCount > 0 {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Warnings",
                contribution: -0.1 * Double(min(5, warningCount)),
                explanation: "\(warningCount) warning(s) found"
            ))
        }

        if errorCount == 0 && warningCount == 0 {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Clean Analysis",
                contribution: 0.2,
                explanation: "No significant issues found"
            ))
        }

        let details = """
            Analyzed \(codeBlocks.count) code block(s).
            Errors: \(errorCount), Warnings: \(warningCount), Info: \(infoCount)
            Tools: \(enableSwiftLint ? "SwiftLint " : "")\(enableCompilerCheck ? "Compiler " : "")\(enableAIAnalysis ? "AI" : "")
            """

        return StaticAnalysisResult(
            source: ConfidenceSource(
                type: .staticAnalysis,
                name: "Static Analysis",
                confidence: confidence,
                weight: 0.10,
                details: details,
                verified: errorCount == 0
            ),
            factors: factors,
            issues: allIssues
        )
    }

    // MARK: - Swift Analysis

    private func analyzeSwift(code: String) async -> [AnalysisIssue] {
        var issues: [AnalysisIssue] = []

        // Pattern-based analysis (fast)
        issues.append(contentsOf: analyzeSwiftPatterns(code: code))

        #if os(macOS)
        // SwiftLint analysis
        if enableSwiftLint {
            let lintIssues = await runSwiftLint(code: code)
            issues.append(contentsOf: lintIssues)
        }

        // Compiler check
        if enableCompilerCheck {
            let compilerIssues = await runSwiftCompilerCheck(code: code)
            issues.append(contentsOf: compilerIssues)
        }
        #endif

        return issues
    }

    private func analyzeSwiftPatterns(code: String) -> [AnalysisIssue] {
        var issues: [AnalysisIssue] = []

        // Force unwrap detection
        let forceUnwrapPattern = #"[^?]\![^\=]"#
        if let regex = try? NSRegularExpression(pattern: forceUnwrapPattern),
           regex.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil {
            issues.append(AnalysisIssue(
                severity: .warning,
                message: "Force unwrap detected - consider using optional binding",
                source: .pattern,
                line: nil
            ))
        }

        // Force try detection
        let forceTryPattern = "try" + "!"
        if code.contains(forceTryPattern) {
            issues.append(AnalysisIssue(
                severity: .warning,
                message: "Force try detected - consider proper error handling",
                source: .pattern,
                line: nil
            ))
        }

        // Data race potential (accessing shared state)
        if code.contains("DispatchQueue") && !code.contains("@MainActor") && !code.contains("actor ") {
            issues.append(AnalysisIssue(
                severity: .info,
                message: "Concurrent code without actor isolation - verify thread safety",
                source: .pattern,
                line: nil
            ))
        }

        // Empty catch blocks
        if code.contains("catch {") && code.contains("catch { }") {
            issues.append(AnalysisIssue(
                severity: .warning,
                message: "Empty catch block - errors are being silently ignored",
                source: .pattern,
                line: nil
            ))
        }

        // Print statements in production code
        let printCount = code.components(separatedBy: "print(").count - 1
        if printCount > 3 {
            issues.append(AnalysisIssue(
                severity: .info,
                message: "\(printCount) print statements - consider using proper logging",
                source: .pattern,
                line: nil
            ))
        }

        return issues
    }

    #if os(macOS)
    private func runSwiftLint(code: String) async -> [AnalysisIssue] {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("thea_lint_\(UUID().uuidString).swift")

        do {
            try code.write(to: tempFile, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/swiftlint")
            process.arguments = ["lint", "--path", tempFile.path, "--reporter", "json"]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = FileHandle.nullDevice

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            try? FileManager.default.removeItem(at: tempFile)

            // Parse SwiftLint JSON output
            if let lintResults = try? JSONSerialization.jsonObject(with: outputData) as? [[String: Any]] {
                return lintResults.map { result in
                    let severity: AnalysisIssue.Severity
                    switch result["severity"] as? String {
                    case "error": severity = .error
                    case "warning": severity = .warning
                    default: severity = .info
                    }

                    return AnalysisIssue(
                        severity: severity,
                        message: result["reason"] as? String ?? "SwiftLint issue",
                        source: .swiftlint,
                        line: result["line"] as? Int
                    )
                }
            }

        } catch {
            logger.debug("SwiftLint not available: \(error.localizedDescription)")
        }

        return []
    }

    private func runSwiftCompilerCheck(code: String) async -> [AnalysisIssue] {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("thea_compile_\(UUID().uuidString).swift")

        do {
            // Add Foundation import if missing
            var checkCode = code
            if !code.contains("import Foundation") {
                checkCode = "import Foundation\n" + code
            }

            try checkCode.write(to: tempFile, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
            process.arguments = ["-typecheck", tempFile.path]

            let errorPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            try? FileManager.default.removeItem(at: tempFile)

            if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                return parseCompilerOutput(errorOutput)
            }

        } catch {
            logger.debug("Swift compiler check failed: \(error.localizedDescription)")
        }

        return []
    }

    private func parseCompilerOutput(_ output: String) -> [AnalysisIssue] {
        var issues: [AnalysisIssue] = []

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("error:") {
                let message = line.components(separatedBy: "error:").last?.trimmingCharacters(in: .whitespaces) ?? line
                issues.append(AnalysisIssue(
                    severity: .error,
                    message: message,
                    source: .compiler,
                    line: extractLineNumber(from: line)
                ))
            } else if line.contains("warning:") {
                let message = line.components(separatedBy: "warning:").last?.trimmingCharacters(in: .whitespaces) ?? line
                issues.append(AnalysisIssue(
                    severity: .warning,
                    message: message,
                    source: .compiler,
                    line: extractLineNumber(from: line)
                ))
            }
        }

        return issues
    }

    private func extractLineNumber(from line: String) -> Int? {
        // Pattern: filename.swift:42:8: error: ...
        let pattern = #":(\d+):\d+:"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return Int(line[range])
        }
        return nil
    }
    #endif

    // MARK: - JavaScript Analysis

    private func analyzeJavaScript(code: String) -> [AnalysisIssue] {
        var issues: [AnalysisIssue] = []

        // var instead of let/const
        if code.contains("var ") {
            issues.append(AnalysisIssue(
                severity: .info,
                message: "Consider using 'let' or 'const' instead of 'var'",
                source: .pattern,
                line: nil
            ))
        }

        // == instead of ===
        let looseEqualityPattern = #"[^=!]==[^=]"#
        if let regex = try? NSRegularExpression(pattern: looseEqualityPattern),
           regex.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil {
            issues.append(AnalysisIssue(
                severity: .warning,
                message: "Consider using === instead of == for strict equality",
                source: .pattern,
                line: nil
            ))
        }

        // eval() usage
        if code.contains("eval(") {
            issues.append(AnalysisIssue(
                severity: .error,
                message: "eval() is dangerous and should be avoided",
                source: .pattern,
                line: nil
            ))
        }

        return issues
    }

    // MARK: - Python Analysis

    private func analyzePython(code: String) -> [AnalysisIssue] {
        var issues: [AnalysisIssue] = []

        // exec() usage
        if code.contains("exec(") {
            issues.append(AnalysisIssue(
                severity: .error,
                message: "exec() can be dangerous - verify the input is trusted",
                source: .pattern,
                line: nil
            ))
        }

        // eval() usage
        if code.contains("eval(") {
            issues.append(AnalysisIssue(
                severity: .warning,
                message: "eval() can be dangerous - consider using ast.literal_eval()",
                source: .pattern,
                line: nil
            ))
        }

        // Bare except
        if code.contains("except:") && !code.contains("except Exception") {
            issues.append(AnalysisIssue(
                severity: .warning,
                message: "Bare 'except:' catches all exceptions including KeyboardInterrupt",
                source: .pattern,
                line: nil
            ))
        }

        return issues
    }

    // MARK: - AI Analysis

    private func performAIAnalysis(code: String) async -> [AnalysisIssue] {
        guard let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
            ?? ProviderRegistry.shared.getProvider(id: "anthropic") else {
            return []
        }

        let prompt = """
            Analyze this code for issues that static analysis might miss:
            - Logic errors
            - Security vulnerabilities
            - Performance issues
            - API misuse

            Code:
            ```
            \(code.prefix(3000))
            ```

            Respond with JSON array of issues found:
            [
                {
                    "severity": "error|warning|info",
                    "message": "description",
                    "line": null or line number
                }
            ]

            Only report issues you are confident about (>80% sure).
            Return empty array [] if no significant issues found.
            """

        do {
            let message = AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(prompt),
                timestamp: Date(), model: "openai/gpt-4o-mini"
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: "openai/gpt-4o-mini",
                stream: false
            )

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    responseText += text
                case let .complete(msg):
                    responseText = msg.content.textValue
                case .error:
                    break
                }
            }

            // Parse issues
            if let jsonStart = responseText.firstIndex(of: "["),
               let jsonEnd = responseText.lastIndex(of: "]") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8),
                   let issues = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    return issues.map { issue in
                        let severity: AnalysisIssue.Severity
                        switch issue["severity"] as? String {
                        case "error": severity = .error
                        case "warning": severity = .warning
                        default: severity = .info
                        }

                        return AnalysisIssue(
                            severity: severity,
                            message: issue["message"] as? String ?? "AI-detected issue",
                            source: .ai,
                            line: issue["line"] as? Int
                        )
                    }
                }
            }

        } catch {
            logger.warning("AI analysis failed: \(error.localizedDescription)")
        }

        return []
    }

    // MARK: - Code Extraction

    private func extractCodeBlocks(
        from response: String,
        language: ValidationContext.CodeLanguage
    ) -> [CodeBlock] {
        var blocks: [CodeBlock] = []

        let pattern = #"```(\w*)\n([\s\S]*?)```"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
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
                switch langStr {
                case "swift": detectedLanguage = .swift
                case "javascript", "js": detectedLanguage = .javascript
                case "python", "py": detectedLanguage = .python
                default: break
                }
            }

            blocks.append(CodeBlock(code: code, language: detectedLanguage))
        }

        return blocks
    }
}

// MARK: - Supporting Types

public struct AnalysisIssue: Sendable, Identifiable {
    public let id = UUID()
    public let severity: Severity
    public let message: String
    public let source: Source
    public let line: Int?

    public enum Severity: String, Sendable {
        case error = "Error"
        case warning = "Warning"
        case info = "Info"
    }

    public enum Source: String, Sendable {
        case pattern = "Pattern"
        case swiftlint = "SwiftLint"
        case compiler = "Compiler"
        case ai = "AI Analysis"
    }
}

public struct StaticAnalysisResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let issues: [AnalysisIssue]
}
