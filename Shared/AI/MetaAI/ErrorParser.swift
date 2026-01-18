#if os(macOS)
import Foundation
import OSLog

public typealias CompilerError = XcodeBuildRunner.CompilerError
// For explicit namespacing when importing both modules, refer to ErrorParser.CompilerError

// MARK: - ErrorParser
// Parses compiler errors and enriches them with context and suggested fixes

public actor ErrorParser {
    public static let shared = ErrorParser()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "ErrorParser")

    private init() {}

    // MARK: - Public Types

    public struct ParsedError: Sendable, Identifiable {
        public let id: UUID
        public let file: String
        public let line: Int
        public let column: Int
        public let message: String
        public let errorCode: String?
        public let category: ErrorCategory
        public let context: [String]
        public let suggestedFix: String?

        public init(
            file: String,
            line: Int,
            column: Int,
            message: String,
            errorCode: String?,
            category: ErrorCategory,
            context: [String],
            suggestedFix: String?
        ) {
            self.id = UUID()
            self.file = file
            self.line = line
            self.column = column
            self.message = message
            self.errorCode = errorCode
            self.category = category
            self.context = context
            self.suggestedFix = suggestedFix
        }
    }

    public enum ErrorCategory: String, Codable, Sendable {
        case sendable = "sendable"
        case mainActor = "main_actor"
        case visibility = "visibility"
        case missingImport = "missing_import"
        case typeNotFound = "type_not_found"
        case asyncAwait = "async_await"
        case missingInitializer = "missing_initializer"
        case dataConcurrency = "data_concurrency"
        case unknown = "unknown"
    }

    // MARK: - Parse Errors

    public func parse(_ errors: [CompilerError]) async -> [ParsedError] {
        logger.info("Parsing \(errors.count) compiler errors")

        var parsedErrors: [ParsedError] = []

        for error in errors {
            // Skip notes for now, focus on actual errors
            guard error.isError else { continue }

            // Categorize error
            let category = categorizeError(message: error.message)

            // Extract error code if present
            let errorCode = extractErrorCode(from: error.message)

            // Load context from file
            let context = await loadContext(file: error.file, line: error.line)

            // Query knowledge base for suggested fix
            let suggestedFix = await findSuggestedFix(
                message: error.message,
                category: category
            )

            let parsed = ParsedError(
                file: error.file,
                line: error.line,
                column: error.column,
                message: error.message,
                errorCode: errorCode,
                category: category,
                context: context,
                suggestedFix: suggestedFix
            )

            parsedErrors.append(parsed)
        }

        logger.info("Parsed \(parsedErrors.count) errors into structured format")
        return parsedErrors
    }

    // MARK: - Error Categorization

    private func categorizeError(message: String) -> ErrorCategory {
        let lowercased = message.lowercased()

        // Sendable errors
        if lowercased.contains("sendable") ||
           lowercased.contains("actor-isolated") ||
           lowercased.contains("non-sendable") {
            return .sendable
        }

        // MainActor errors
        if lowercased.contains("main actor") ||
           lowercased.contains("@mainactor") {
            return .mainActor
        }

        // Visibility errors
        if lowercased.contains("inaccessible") ||
           lowercased.contains("protection level") ||
           lowercased.contains("private") ||
           lowercased.contains("internal") {
            return .visibility
        }

        // Type not found
        if lowercased.contains("cannot find type") ||
           lowercased.contains("cannot find") && lowercased.contains("in scope") {
            return .typeNotFound
        }

        // Missing import
        if lowercased.contains("no such module") ||
           lowercased.contains("import") {
            return .missingImport
        }

        // Async/await errors
        if lowercased.contains("async") ||
           lowercased.contains("await") ||
           lowercased.contains("cannot call") && lowercased.contains("function") {
            return .asyncAwait
        }

        // Initializer errors
        if lowercased.contains("missing argument") ||
           lowercased.contains("initializer") {
            return .missingInitializer
        }

        // Data race / concurrency
        if lowercased.contains("data race") ||
           lowercased.contains("concurrent") ||
           lowercased.contains("isolation") {
            return .dataConcurrency
        }

        return .unknown
    }

    // MARK: - Error Code Extraction

    private func extractErrorCode(from message: String) -> String? {
        // Swift error codes often appear in brackets, e.g., [E0001]
        let pattern = #"\[([A-Z]\d+)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsString = message as NSString
        let matches = regex.matches(in: message, range: NSRange(location: 0, length: nsString.length))

        guard let match = matches.first, match.numberOfRanges > 1 else {
            return nil
        }

        return nsString.substring(with: match.range(at: 1))
    }

    // MARK: - Context Loading

    private func loadContext(file: String, line: Int, contextLines: Int = 5) async -> [String] {
        // Load surrounding lines from the file for context
        guard FileManager.default.fileExists(atPath: file) else {
            logger.warning("File not found: \(file)")
            return []
        }

        do {
            let contents = try String(contentsOfFile: file, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)

            // Get context around the error line
            let startLine = max(0, line - contextLines - 1)
            let endLine = min(lines.count, line + contextLines)

            guard startLine < lines.count else {
                return []
            }

            let contextSlice = Array(lines[startLine..<endLine])
            return contextSlice
        } catch {
            logger.error("Failed to load context from \(file): \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Suggested Fix Lookup

    private func findSuggestedFix(
        message: String,
        category: ErrorCategory
    ) async -> String? {
        // Query the knowledge base for a known fix
        // Note: Call uses type inference to work around duplicate ErrorKnowledgeBase files
        // The correct file is ErrorKnowledgeBase.swift (public actor with KnownFix type)
        // TODO: Remove ErrorKnowledgeBase 2.swift and ErrorKnowledgeBase 3.swift from project
        let knownFixResult = await ErrorKnowledgeBase.shared.findFix(
            forMessage: message,
            category: category
        )
        
        if let fix = knownFixResult {
            return fix.fixDescription
        }

        // Return category-based generic suggestion
        return genericSuggestion(for: category)
    }

    private func genericSuggestion(for category: ErrorCategory) -> String? {
        switch category {
        case .sendable:
            return "Add 'Sendable' conformance to the type"
        case .mainActor:
            return "Add '@MainActor' attribute to the declaration"
        case .visibility:
            return "Add 'public' modifier to make the symbol accessible"
        case .typeNotFound:
            return "Check if the type is imported or defined"
        case .missingImport:
            return "Add the required import statement"
        case .asyncAwait:
            return "Add 'async' to the function and use 'await' when calling"
        case .missingInitializer:
            return "Add missing parameters to the initializer"
        case .dataConcurrency:
            return "Review concurrency isolation and use proper synchronization"
        case .unknown:
            return nil
        }
    }

    // MARK: - Error Statistics

    public func analyzeErrors(_ errors: [ParsedError]) async -> ErrorStatistics {
        var categoryCounts: [ErrorCategory: Int] = [:]

        for error in errors {
            categoryCounts[error.category, default: 0] += 1
        }

        let totalWithFixes = errors.filter { $0.suggestedFix != nil }.count

        return ErrorStatistics(
            totalErrors: errors.count,
            categoryCounts: categoryCounts,
            errorsWithSuggestedFixes: totalWithFixes,
            fixCoverage: errors.isEmpty ? 0.0 : Double(totalWithFixes) / Double(errors.count)
        )
    }
}

// MARK: - Supporting Types

public struct ErrorStatistics: Sendable {
    public let totalErrors: Int
    public let categoryCounts: [ErrorParser.ErrorCategory: Int]
    public let errorsWithSuggestedFixes: Int
    public let fixCoverage: Double

    public init(
        totalErrors: Int,
        categoryCounts: [ErrorParser.ErrorCategory: Int],
        errorsWithSuggestedFixes: Int,
        fixCoverage: Double
    ) {
        self.totalErrors = totalErrors
        self.categoryCounts = categoryCounts
        self.errorsWithSuggestedFixes = errorsWithSuggestedFixes
        self.fixCoverage = fixCoverage
    }
}

#endif
