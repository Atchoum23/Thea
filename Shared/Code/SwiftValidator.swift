import Foundation
import Observation

// MARK: - Swift Validator
// Validates Swift code using swiftc -typecheck for syntax and compilation errors

@MainActor
@Observable
final class SwiftValidator {
    static let shared = SwiftValidator()

    private(set) var isValidating: Bool = false
    private(set) var lastValidationResult: SwiftValidationResult?

    private init() {}

    // MARK: - Main Validation Methods

    /// Validates Swift syntax using swiftc -typecheck
    func validateSwiftSyntax(_ code: String) async throws -> SwiftValidationResult {
        isValidating = true
        defer { isValidating = false }

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("TempSwiftValidation_\(UUID().uuidString).swift")

        do {
            // Write code to temporary file
            try code.write(to: tempFile, atomically: true, encoding: .utf8)

            // Run swiftc -typecheck
            let result = try await runSwiftCompiler(on: tempFile)

            // Clean up
            try? FileManager.default.removeItem(at: tempFile)

            lastValidationResult = result
            return result
        } catch {
            // Clean up on error
            try? FileManager.default.removeItem(at: tempFile)
            throw error
        }
    }

    /// Validates Swift code with additional context (imports, frameworks)
    func validateWithContext(
        _ code: String,
        imports: [String] = [],
        framework: String? = nil
    ) async throws -> SwiftValidationResult {
        var fullCode = ""

        // Add imports
        for imp in imports {
            fullCode += "import \(imp)\n"
        }

        fullCode += "\n\(code)"

        return try await validateSwiftSyntax(fullCode)
    }

    // MARK: - Swift Compiler Integration

    private func runSwiftCompiler(on file: URL) async throws -> SwiftValidationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        process.arguments = [
            "-typecheck",
            file.path,
            "-sdk",
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            return .success
        } else {
            let errors = parseSwiftCompilerErrors(errorOutput)
            return .failure(errors: errors)
        }
    }

    // MARK: - Error Parsing

    private func parseSwiftCompilerErrors(_ output: String) -> [SwiftError] {
        var errors: [SwiftError] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            if let error = parseErrorLine(String(line)) {
                errors.append(error)
            }
        }

        return errors
    }

    private func parseErrorLine(_ line: String) -> SwiftError? {
        // Swift compiler error format: <file>:<line>:<column>: error: <message>
        // or: <file>:<line>:<column>: warning: <message>

        let pattern = #/(.+?):(\d+):(\d+):\s+(error|warning|note):\s+(.+)/#

        guard let match = line.firstMatch(of: pattern) else {
            return nil
        }

        let lineNumber = Int(match.2) ?? 0
        let column = Int(match.3) ?? 0
        let severityString = String(match.4)
        let message = String(match.5)

        let severity: SwiftError.Severity
        switch severityString {
        case "error":
            severity = .error
        case "warning":
            severity = .warning
        case "note":
            severity = .note
        default:
            severity = .error
        }

        let category = categorizeError(message)

        return SwiftError(
            message: message,
            line: lineNumber,
            column: column,
            severity: severity,
            category: category,
            suggestion: generateSuggestion(for: message, category: category)
        )
    }

    // MARK: - Error Categorization

    private func categorizeError(_ message: String) -> SwiftError.ErrorCategory {
        let lowercased = message.lowercased()

        // Syntax errors
        if lowercased.contains("expected") || lowercased.contains("unexpected") ||
           lowercased.contains("consecutive") || lowercased.contains("missing") {
            return .syntax
        }

        // Type errors
        if lowercased.contains("type") || lowercased.contains("cannot convert") ||
           lowercased.contains("incompatible") {
            return .type
        }

        // Undeclared errors
        if lowercased.contains("undeclared") || lowercased.contains("not found") ||
           lowercased.contains("undefined") || lowercased.contains("use of unresolved") {
            return .undeclared
        }

        // Access control errors
        if lowercased.contains("private") || lowercased.contains("internal") ||
           lowercased.contains("inaccessible") {
            return .access
        }

        // Concurrency errors
        if lowercased.contains("@mainactor") || lowercased.contains("@sendable") ||
           lowercased.contains("actor") || lowercased.contains("concurrency") ||
           lowercased.contains("async") || lowercased.contains("await") {
            return .concurrency
        }

        return .other
    }

    // MARK: - Error Suggestions

    private func generateSuggestion(for message: String, category: SwiftError.ErrorCategory) -> String? {
        let lowercased = message.lowercased()

        switch category {
        case .syntax:
            if lowercased.contains("expected '}'") {
                return "Add missing closing brace '}'"
            }
            if lowercased.contains("expected ')'") {
                return "Add missing closing parenthesis ')'"
            }
            if lowercased.contains("expected ']'") {
                return "Add missing closing bracket ']'"
            }

        case .type:
            if lowercased.contains("cannot convert value of type") {
                return "Ensure type compatibility or add explicit type conversion"
            }

        case .undeclared:
            if lowercased.contains("use of unresolved identifier") {
                return "Check spelling and import necessary modules"
            }

        case .concurrency:
            if lowercased.contains("@mainactor") {
                return "Add @MainActor annotation or call from @MainActor context"
            }
            if lowercased.contains("@sendable") {
                return "Ensure type conforms to Sendable protocol"
            }
            if lowercased.contains("await") {
                return "Add 'await' keyword for async function call"
            }

        case .access:
            if lowercased.contains("private") {
                return "Make property/method internal or public"
            }

        case .other:
            break
        }

        return nil
    }

    // MARK: - Quick Validation

    /// Quick syntax-only validation without writing to file
    func quickValidate(_ code: String) -> QuickValidationResult {
        var issues: [String] = []

        // Check basic syntax patterns
        let openBraces = code.filter { $0 == "{" }.count
        let closeBraces = code.filter { $0 == "}" }.count
        if openBraces != closeBraces {
            issues.append("Mismatched braces: \(openBraces) '{' vs \(closeBraces) '}'")
        }

        let openParens = code.filter { $0 == "(" }.count
        let closeParens = code.filter { $0 == ")" }.count
        if openParens != closeParens {
            issues.append("Mismatched parentheses: \(openParens) '(' vs \(closeParens) ')'")
        }

        let openBrackets = code.filter { $0 == "[" }.count
        let closeBrackets = code.filter { $0 == "]" }.count
        if openBrackets != closeBrackets {
            issues.append("Mismatched brackets: \(openBrackets) '[' vs \(closeBrackets) ']'")
        }

        // Check for common Swift keywords in correct context
        if code.contains("func") {
            // Basic function validation
            let funcPattern = #/func\s+\w+\s*\([^\)]*\)/#
            if code.firstMatch(of: funcPattern) == nil {
                issues.append("Malformed function declaration")
            }
        }

        return QuickValidationResult(
            isLikelyValid: issues.isEmpty,
            issues: issues
        )
    }

    // MARK: - Code Extraction

    /// Extracts Swift code from markdown code blocks
    func extractSwiftCode(from text: String) -> String? {
        // Match ```swift ... ``` or ``` ... ``` blocks
        let pattern = #/```(?:swift)?\n(.*?)```/#

        if let match = text.firstMatch(of: pattern) {
            return String(match.1)
        }

        return nil
    }

    /// Extracts all Swift code blocks from text
    func extractAllSwiftCode(from text: String) -> [String] {
        let pattern = #/```(?:swift)?\n(.*?)```/#
        var blocks: [String] = []

        for match in text.matches(of: pattern) {
            blocks.append(String(match.1))
        }

        return blocks
    }
}

// MARK: - Data Structures

enum SwiftValidationResult {
    case success
    case failure(errors: [SwiftError])

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var errors: [SwiftError] {
        if case .failure(let errors) = self {
            return errors
        }
        return []
    }
}

struct SwiftError: Identifiable {
    let id = UUID()
    let message: String
    let line: Int?
    let column: Int?
    let severity: Severity
    let category: ErrorCategory
    let suggestion: String?

    enum Severity {
        case error, warning, note
    }

    enum ErrorCategory {
        case syntax
        case type
        case undeclared
        case access
        case concurrency
        case other
    }

    var displayMessage: String {
        var msg = message
        if let line = line, let column = column {
            msg = "Line \(line):\(column): \(msg)"
        }
        if let suggestion = suggestion {
            msg += "\n💡 Suggestion: \(suggestion)"
        }
        return msg
    }
}

struct QuickValidationResult {
    let isLikelyValid: Bool
    let issues: [String]
}
