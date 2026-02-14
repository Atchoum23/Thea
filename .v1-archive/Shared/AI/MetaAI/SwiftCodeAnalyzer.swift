// SwiftCodeAnalyzer.swift
// Semantic analysis of Swift code using AI-powered analysis with pattern matching fallback

import Foundation
import OSLog

/// Analyzes Swift source code for semantic understanding.
/// Uses AI-powered semantic analysis with pattern matching fallback.
@MainActor
public final class SwiftCodeAnalyzer {
    public static let shared = SwiftCodeAnalyzer()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "SwiftCodeAnalyzer")

    /// Enable AI-powered semantic analysis (vs pattern-based)
    public var useAIAnalysis: Bool = true

    private init() {}

    // MARK: - Analysis Results

    public struct AnalysisResult: Sendable {
        public let filePath: String
        public let imports: [Import]
        public let types: [TypeDeclaration]
        public let functions: [FunctionDeclaration]
        public let properties: [PropertyDeclaration]
        public let diagnostics: [Diagnostic]
        public let complexity: CodeComplexity
        public let aiAnalysis: AICodeAnalysis?

        public var summary: String {
            var text = """
            File: \(filePath)
            Imports: \(imports.count)
            Types: \(types.count) (\(types.filter { $0.kind == .class }.count) classes, \(types.filter { $0.kind == .struct }.count) structs, \(types.filter { $0.kind == .protocol }.count) protocols)
            Functions: \(functions.count)
            Properties: \(properties.count)
            Complexity: \(complexity.description)
            Diagnostics: \(diagnostics.count) issues
            """

            if let ai = aiAnalysis {
                text += """

                AI Analysis:
                - Intent: \(ai.intent)
                - Issues: \(ai.issues.count) (semantic)
                - Suggestions: \(ai.suggestions.count)
                """
            }

            return text
        }

        /// Combined issues from both pattern-based and AI analysis
        public var allIssues: [UnifiedIssue] {
            var issues: [UnifiedIssue] = []

            // Add compiler diagnostics
            for diag in diagnostics {
                issues.append(UnifiedIssue(
                    source: .compiler,
                    severity: diag.severity == .error ? .critical : (diag.severity == .warning ? .medium : .low),
                    line: diag.line,
                    message: diag.message,
                    suggestion: nil,
                    confidence: 1.0
                ))
            }

            // Add AI-detected issues
            if let ai = aiAnalysis {
                for issue in ai.issues {
                    let severity: UnifiedIssue.Severity
                    switch issue.severity {
                    case .critical: severity = .critical
                    case .high: severity = .high
                    case .medium: severity = .medium
                    case .low: severity = .low
                    }

                    issues.append(UnifiedIssue(
                        source: .ai,
                        severity: severity,
                        line: issue.line,
                        message: issue.description,
                        suggestion: issue.suggestion,
                        confidence: issue.confidence
                    ))
                }
            }

            return issues.sorted { $0.severity.rawValue < $1.severity.rawValue }
        }
    }

    public struct UnifiedIssue: Sendable {
        public enum Source: String, Sendable {
            case compiler, pattern, ai
        }

        public enum Severity: Int, Sendable {
            case critical = 0, high = 1, medium = 2, low = 3
        }

        public let source: Source
        public let severity: Severity
        public let line: Int
        public let message: String
        public let suggestion: String?
        public let confidence: Double
    }

    public struct Import: Sendable {
        public let moduleName: String
        public let line: Int
        public let isPreconcurrency: Bool
    }

    public struct TypeDeclaration: Sendable {
        public let name: String
        public let kind: TypeKind
        public let line: Int
        public let inheritedTypes: [String]
        public let attributes: [String]
        public let isPublic: Bool
        public let isFinal: Bool

        public enum TypeKind: String, Sendable {
            case `class`, `struct`, `enum`, `protocol`, actor, `extension`
        }
    }

    public struct FunctionDeclaration: Sendable {
        public let name: String
        public let line: Int
        public let parameters: [Parameter]
        public let returnType: String?
        public let isAsync: Bool
        public let isThrowing: Bool
        public let isPublic: Bool
        public let isStatic: Bool
        public let attributes: [String]

        public struct Parameter: Sendable {
            public let label: String?
            public let name: String
            public let type: String
        }
    }

    public struct PropertyDeclaration: Sendable {
        public let name: String
        public let line: Int
        public let type: String?
        public let isLet: Bool
        public let isPublic: Bool
        public let isStatic: Bool
        public let attributes: [String]
    }

    public struct Diagnostic: Sendable {
        public let severity: Severity
        public let message: String
        public let line: Int
        public let column: Int

        public enum Severity: String, Sendable {
            case error, warning, note
        }
    }

    public struct CodeComplexity: Sendable {
        public let linesOfCode: Int
        public let cyclomaticComplexity: Int
        public let nestingDepth: Int
        public let cognitiveComplexity: Int

        public var description: String {
            let level: String
            if cyclomaticComplexity <= 5 {
                level = "Low"
            } else if cyclomaticComplexity <= 10 {
                level = "Moderate"
            } else if cyclomaticComplexity <= 20 {
                level = "High"
            } else {
                level = "Very High"
            }
            return "\(level) (CC:\(cyclomaticComplexity), Nesting:\(nestingDepth))"
        }
    }

    // MARK: - Analysis Methods

    /// Analyze a Swift source file
    public func analyze(filePath: String) async throws -> AnalysisResult {
        let content = try String(contentsOfFile: filePath, encoding: .utf8)
        return try await analyze(content: content, filePath: filePath)
    }

    /// Analyze Swift source code content
    /// Uses AI-powered semantic analysis when enabled, with pattern-matching fallback
    public func analyze(content: String, filePath: String = "<memory>") async throws -> AnalysisResult {
        logger.info("Analyzing Swift code: \(filePath) (AI: \(self.useAIAnalysis))")

        let lines = content.components(separatedBy: .newlines)

        // Parse basic structure (always pattern-based for consistency)
        let imports = parseImports(lines)
        let types = parseTypes(lines)
        let functions = parseFunctions(lines)
        let properties = parseProperties(lines)
        let complexity = calculateComplexity(content: content, lines: lines)
        let diagnostics = await getCompilerDiagnostics(content: content, filePath: filePath)

        // Build base result
        var result = AnalysisResult(
            filePath: filePath,
            imports: imports,
            types: types,
            functions: functions,
            properties: properties,
            diagnostics: diagnostics,
            complexity: complexity,
            aiAnalysis: nil
        )

        // Enhance with AI-powered semantic analysis if enabled
        if useAIAnalysis {
            do {
                let aiAnalysis = try await AIIntelligence.shared.analyzeCode(
                    content,
                    context: CodeContext(filePath: filePath)
                )
                result = AnalysisResult(
                    filePath: filePath,
                    imports: imports,
                    types: types,
                    functions: functions,
                    properties: properties,
                    diagnostics: diagnostics,
                    complexity: complexity,
                    aiAnalysis: aiAnalysis
                )
                logger.info("AI analysis complete: \(aiAnalysis.issues.count) issues, \(aiAnalysis.suggestions.count) suggestions")
            } catch {
                logger.warning("AI analysis failed, using pattern-based only: \(error.localizedDescription)")
            }
        }

        return result
    }

    // MARK: - Parsing Methods

    private func parseImports(_ lines: [String]) -> [Import] {
        var imports: [Import] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Match import statements
            if let match = trimmed.range(of: #"^(@preconcurrency\s+)?import\s+(\w+)"#, options: .regularExpression) {
                let matchedText = String(trimmed[match])
                let isPreconcurrency = matchedText.contains("@preconcurrency")

                // Extract module name
                if let moduleMatch = matchedText.range(of: #"import\s+(\w+)"#, options: .regularExpression) {
                    let moduleText = String(matchedText[moduleMatch])
                    let moduleName = moduleText.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespaces)

                    imports.append(Import(
                        moduleName: moduleName,
                        line: index + 1,
                        isPreconcurrency: isPreconcurrency
                    ))
                }
            }
        }

        return imports
    }

    private func parseTypes(_ lines: [String]) -> [TypeDeclaration] {
        var types: [TypeDeclaration] = []
        let typePattern = #"^(\s*)(public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(final\s+)?(@\w+\s+)*(class|struct|enum|protocol|actor|extension)\s+(\w+)"#

        for (index, line) in lines.enumerated() {
            if let match = line.range(of: typePattern, options: .regularExpression) {
                let matchedText = String(line[match])

                // Determine type kind
                var kind: TypeDeclaration.TypeKind = .class
                for typeKind in ["class", "struct", "enum", "protocol", "actor", "extension"] {
                    if matchedText.contains(" \(typeKind) ") || matchedText.contains("\t\(typeKind) ") {
                        kind = TypeDeclaration.TypeKind(rawValue: typeKind) ?? .class
                        break
                    }
                }

                // Extract name
                if let nameMatch = matchedText.range(of: #"(class|struct|enum|protocol|actor|extension)\s+(\w+)"#, options: .regularExpression) {
                    let nameText = String(matchedText[nameMatch])
                    let parts = nameText.split(separator: " ")
                    if parts.count >= 2 {
                        let name = String(parts[1])

                        // Check for inheritance
                        var inheritedTypes: [String] = []
                        if let colonIndex = line.firstIndex(of: ":") {
                            let inheritanceText = String(line[colonIndex...])
                                .replacingOccurrences(of: ":", with: "")
                                .replacingOccurrences(of: "{", with: "")
                                .trimmingCharacters(in: .whitespaces)

                            inheritedTypes = inheritanceText
                                .components(separatedBy: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                        }

                        // Extract attributes
                        var attributes: [String] = []
                        let attrPattern = #"@\w+"#
                        let attrRegex = try? NSRegularExpression(pattern: attrPattern)
                        if let matches = attrRegex?.matches(in: matchedText, range: NSRange(matchedText.startIndex..., in: matchedText)) {
                            for match in matches {
                                if let range = Range(match.range, in: matchedText) {
                                    attributes.append(String(matchedText[range]))
                                }
                            }
                        }

                        types.append(TypeDeclaration(
                            name: name,
                            kind: kind,
                            line: index + 1,
                            inheritedTypes: inheritedTypes,
                            attributes: attributes,
                            isPublic: matchedText.contains("public ") || matchedText.contains("open "),
                            isFinal: matchedText.contains("final ")
                        ))
                    }
                }
            }
        }

        return types
    }

    private func parseFunctions(_ lines: [String]) -> [FunctionDeclaration] {
        var functions: [FunctionDeclaration] = []
        let funcPattern = #"^\s*(public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(static\s+)?(@\w+\s+)*func\s+(\w+)"#

        for (index, line) in lines.enumerated() {
            if let match = line.range(of: funcPattern, options: .regularExpression) {
                let matchedText = String(line[match])

                // Extract function name
                if let nameMatch = matchedText.range(of: #"func\s+(\w+)"#, options: .regularExpression) {
                    let nameText = String(matchedText[nameMatch])
                    let name = nameText.replacingOccurrences(of: "func ", with: "")

                    // Parse parameters (simplified)
                    var parameters: [FunctionDeclaration.Parameter] = []
                    if let parenStart = line.firstIndex(of: "("),
                       let parenEnd = line.lastIndex(of: ")")
                    {
                        let paramText = String(line[line.index(after: parenStart) ..< parenEnd])
                        if !paramText.isEmpty {
                            let paramParts = paramText.components(separatedBy: ",")
                            for part in paramParts {
                                let trimmed = part.trimmingCharacters(in: .whitespaces)
                                if trimmed.isEmpty { continue }

                                // Parse parameter: "label name: Type" or "name: Type" or "_ name: Type"
                                let colonParts = trimmed.components(separatedBy: ":")
                                if colonParts.count >= 2 {
                                    let labelPart = colonParts[0].trimmingCharacters(in: .whitespaces)
                                    let typePart = colonParts[1].trimmingCharacters(in: .whitespaces)

                                    let nameParts = labelPart.split(separator: " ")
                                    let paramName: String
                                    let label: String?

                                    if nameParts.count >= 2 {
                                        label = String(nameParts[0])
                                        paramName = String(nameParts[1])
                                    } else {
                                        label = nil
                                        paramName = labelPart
                                    }

                                    parameters.append(FunctionDeclaration.Parameter(
                                        label: label == "_" ? nil : label,
                                        name: paramName,
                                        type: typePart
                                    ))
                                }
                            }
                        }
                    }

                    // Determine return type
                    var returnType: String?
                    if let arrowIndex = line.range(of: "->") {
                        var retText = String(line[arrowIndex.upperBound...])
                        retText = retText.replacingOccurrences(of: "{", with: "")
                        retText = retText.replacingOccurrences(of: "where", with: "")
                        returnType = retText.trimmingCharacters(in: .whitespaces)
                        if returnType?.isEmpty == true { returnType = nil }
                    }

                    // Extract attributes
                    var attributes: [String] = []
                    let attrPattern = #"@\w+"#
                    let attrRegex = try? NSRegularExpression(pattern: attrPattern)
                    if let matches = attrRegex?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                        for match in matches {
                            if let range = Range(match.range, in: line) {
                                attributes.append(String(line[range]))
                            }
                        }
                    }

                    functions.append(FunctionDeclaration(
                        name: name,
                        line: index + 1,
                        parameters: parameters,
                        returnType: returnType,
                        isAsync: line.contains(" async ") || line.contains(" async\n"),
                        isThrowing: line.contains(" throws ") || line.contains(" throws\n") || line.contains("throws {"),
                        isPublic: matchedText.contains("public ") || matchedText.contains("open "),
                        isStatic: matchedText.contains("static "),
                        attributes: attributes
                    ))
                }
            }
        }

        return functions
    }

    private func parseProperties(_ lines: [String]) -> [PropertyDeclaration] {
        var properties: [PropertyDeclaration] = []
        let propPattern = #"^\s*(public\s+|private\s+|internal\s+|fileprivate\s+)?(static\s+)?(@\w+\s+)*(let|var)\s+(\w+)"#

        for (index, line) in lines.enumerated() {
            // Skip function parameters and local variables (lines inside function bodies have more indentation)
            if line.contains("func ") || line.contains("= {") || line.contains("in {") {
                continue
            }

            if let match = line.range(of: propPattern, options: .regularExpression) {
                let matchedText = String(line[match])

                // Skip if this looks like a local variable inside a function
                let leadingSpaces = line.prefix { $0 == " " || $0 == "\t" }.count
                if leadingSpaces > 8 { continue } // Likely inside a function

                // Extract property name
                if let nameMatch = matchedText.range(of: #"(let|var)\s+(\w+)"#, options: .regularExpression) {
                    let nameText = String(matchedText[nameMatch])
                    let parts = nameText.split(separator: " ")
                    if parts.count >= 2 {
                        let isLet = parts[0] == "let"
                        let name = String(parts[1])

                        // Determine type
                        var type: String?
                        if let colonIndex = line.range(of: ": ") {
                            var typeText = String(line[colonIndex.upperBound...])
                            // Clean up type text
                            if let eqIndex = typeText.firstIndex(of: "=") {
                                typeText = String(typeText[..<eqIndex])
                            }
                            if let braceIndex = typeText.firstIndex(of: "{") {
                                typeText = String(typeText[..<braceIndex])
                            }
                            type = typeText.trimmingCharacters(in: .whitespaces)
                            if type?.isEmpty == true { type = nil }
                        }

                        // Extract attributes
                        var attributes: [String] = []
                        let attrPattern = #"@\w+"#
                        let attrRegex = try? NSRegularExpression(pattern: attrPattern)
                        if let matches = attrRegex?.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                            for match in matches {
                                if let range = Range(match.range, in: line) {
                                    attributes.append(String(line[range]))
                                }
                            }
                        }

                        properties.append(PropertyDeclaration(
                            name: name,
                            line: index + 1,
                            type: type,
                            isLet: isLet,
                            isPublic: matchedText.contains("public "),
                            isStatic: matchedText.contains("static "),
                            attributes: attributes
                        ))
                    }
                }
            }
        }

        return properties
    }

    // MARK: - Complexity Calculation

    private func calculateComplexity(content: String, lines: [String]) -> CodeComplexity {
        let linesOfCode = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*")
        }.count

        // Calculate cyclomatic complexity (simplified)
        // Count decision points: if, else, for, while, switch case, catch, guard, &&, ||
        var cyclomaticComplexity = 1 // Base complexity

        let decisionKeywords = ["if ", "else ", "for ", "while ", "case ", "catch ", "guard "]
        let logicalOperators = ["&&", "||", "? "] // Ternary operator

        for line in lines {
            for keyword in decisionKeywords {
                if line.contains(keyword) {
                    cyclomaticComplexity += 1
                }
            }
            for op in logicalOperators {
                cyclomaticComplexity += line.components(separatedBy: op).count - 1
            }
        }

        // Calculate nesting depth
        var maxNesting = 0
        var currentNesting = 0

        for line in lines {
            currentNesting += line.filter { $0 == "{" }.count
            currentNesting -= line.filter { $0 == "}" }.count
            maxNesting = max(maxNesting, currentNesting)
        }

        // Cognitive complexity (simplified)
        let cognitiveComplexity = cyclomaticComplexity + maxNesting

        return CodeComplexity(
            linesOfCode: linesOfCode,
            cyclomaticComplexity: cyclomaticComplexity,
            nestingDepth: maxNesting,
            cognitiveComplexity: cognitiveComplexity
        )
    }

    // MARK: - Compiler Diagnostics

    private func getCompilerDiagnostics(content: String, filePath: String) async -> [Diagnostic] {
        // Write content to temp file if needed
        let tempFile: String
        if filePath == "<memory>" {
            tempFile = NSTemporaryDirectory() + "thea_analyze_\(UUID().uuidString).swift"
            do {
                try content.write(toFile: tempFile, atomically: true, encoding: .utf8)
            } catch {
                logger.warning("Failed to write temp file for analysis: \(error.localizedDescription)")
                return []
            }
        } else {
            tempFile = filePath
        }

        defer {
            if filePath == "<memory>" {
                try? FileManager.default.removeItem(atPath: tempFile)
            }
        }

        // Run swiftc -typecheck (macOS only)
        #if os(macOS)
        do {
            let result = try await TerminalService.shared.runShellScript(
                "swiftc -typecheck \"\(tempFile)\" 2>&1 || true",
                timeout: 30.0
            )

            return parseDiagnostics(result.stdout + result.stderr)
        } catch {
            logger.warning("Failed to get compiler diagnostics: \(error.localizedDescription)")
            return []
        }
        #else
        // Compiler diagnostics not available on iOS/watchOS/tvOS
        return []
        #endif
    }

    private func parseDiagnostics(_ output: String) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        let lines = output.components(separatedBy: .newlines)
        let pattern = #".*:(\d+):(\d+): (error|warning|note): (.+)"#

        for line in lines {
            if let match = line.range(of: pattern, options: .regularExpression) {
                let matchedText = String(line[match])

                // Extract components
                let components = matchedText.components(separatedBy: ":")
                if components.count >= 5 {
                    if let lineNum = Int(components[1].trimmingCharacters(in: .whitespaces)),
                       let colNum = Int(components[2].trimmingCharacters(in: .whitespaces))
                    {
                        let severityText = components[3].trimmingCharacters(in: .whitespaces)
                        let message = components[4...].joined(separator: ":").trimmingCharacters(in: .whitespaces)

                        let severity: Diagnostic.Severity
                        switch severityText {
                        case "error":
                            severity = .error
                        case "warning":
                            severity = .warning
                        default:
                            severity = .note
                        }

                        diagnostics.append(Diagnostic(
                            severity: severity,
                            message: message,
                            line: lineNum,
                            column: colNum
                        ))
                    }
                }
            }
        }

        return diagnostics
    }

    // MARK: - Code Quality Checks

    /// Check code quality and return issues
    /// Uses AI-powered semantic analysis when enabled, with pattern-based fallback
    public func checkQuality(_ content: String) async -> [QualityIssue] {
        var issues: [QualityIssue] = []
        let lines = content.components(separatedBy: .newlines)

        // Pattern-based checks (fast, always run)
        issues.append(contentsOf: patternBasedQualityChecks(lines: lines))

        // AI-powered semantic checks (deep understanding)
        if useAIAnalysis {
            do {
                let aiAnalysis = try await AIIntelligence.shared.analyzeCode(
                    content,
                    context: CodeContext(filePath: "<quality-check>")
                )

                // Convert AI issues to QualityIssues
                for aiIssue in aiAnalysis.issues {
                    let issueType: QualityIssue.IssueType
                    switch aiIssue.type {
                    case .bug: issueType = .semanticBug
                    case .antipattern: issueType = .antipattern
                    case .security: issueType = .securityRisk
                    case .performance: issueType = .performanceIssue
                    case .architecture: issueType = .architectureViolation
                    }

                    issues.append(QualityIssue(
                        type: issueType,
                        line: aiIssue.line,
                        message: aiIssue.description,
                        suggestion: aiIssue.suggestion,
                        confidence: aiIssue.confidence,
                        source: .ai
                    ))
                }

                logger.info("AI quality check found \(aiAnalysis.issues.count) semantic issues")
            } catch {
                logger.warning("AI quality check failed: \(error.localizedDescription)")
            }
        }

        // Check complexity (pattern-based)
        let complexity = calculateComplexity(content: content, lines: lines)
        if complexity.cyclomaticComplexity > 15 {
            issues.append(QualityIssue(
                type: .highComplexity,
                line: 0,
                message: "High cyclomatic complexity: \(complexity.cyclomaticComplexity)",
                suggestion: "Consider breaking this into smaller functions",
                confidence: 1.0,
                source: .pattern
            ))
        }

        if complexity.nestingDepth > 5 {
            issues.append(QualityIssue(
                type: .deepNesting,
                line: 0,
                message: "Deep nesting detected: \(complexity.nestingDepth) levels",
                suggestion: "Consider using early returns or extracting nested logic",
                confidence: 1.0,
                source: .pattern
            ))
        }

        return issues.sorted { ($0.confidence, $0.line) > ($1.confidence, $1.line) }
    }

    /// Pattern-based quality checks (fast, synchronous)
    private func patternBasedQualityChecks(lines: [String]) -> [QualityIssue] {
        var issues: [QualityIssue] = []

        for (index, line) in lines.enumerated() {
            // Check for force unwraps
            if line.contains("!") && !line.contains("!=") && !line.contains("//") {
                if line.contains(".!") || line.range(of: #"\w+!"#, options: .regularExpression) != nil {
                    issues.append(QualityIssue(
                        type: .forceUnwrap,
                        line: index + 1,
                        message: "Force unwrap detected",
                        suggestion: "Use optional binding (if let/guard let) or nil coalescing (??)",
                        confidence: 0.9,
                        source: .pattern
                    ))
                }
            }

            // Check for print statements (should use logger)
            if line.contains("print(") && !line.contains("//") {
                issues.append(QualityIssue(
                    type: .debugPrint,
                    line: index + 1,
                    message: "Debug print statement found",
                    suggestion: "Use OSLog/Logger for production code",
                    confidence: 0.8,
                    source: .pattern
                ))
            }

            // Check for long lines
            if line.count > 120 {
                issues.append(QualityIssue(
                    type: .lineTooLong,
                    line: index + 1,
                    message: "Line exceeds 120 characters (\(line.count))",
                    suggestion: "Break line into multiple lines for readability",
                    confidence: 1.0,
                    source: .pattern
                ))
            }

            // Check for TODO comments
            if line.uppercased().contains("TODO") {
                issues.append(QualityIssue(
                    type: .todoComment,
                    line: index + 1,
                    message: "TODO comment found",
                    suggestion: nil,
                    confidence: 1.0,
                    source: .pattern
                ))
            }

            // Check for FIXME comments
            if line.uppercased().contains("FIXME") {
                issues.append(QualityIssue(
                    type: .fixmeComment,
                    line: index + 1,
                    message: "FIXME comment found",
                    suggestion: nil,
                    confidence: 1.0,
                    source: .pattern
                ))
            }
        }

        return issues
    }

    public struct QualityIssue: Sendable {
        public let type: IssueType
        public let line: Int
        public let message: String
        public let suggestion: String?
        public let confidence: Double
        public let source: Source

        public enum IssueType: String, Sendable {
            // Pattern-based issues
            case forceUnwrap
            case debugPrint
            case lineTooLong
            case todoComment
            case fixmeComment
            case highComplexity
            case deepNesting

            // AI-detected semantic issues
            case semanticBug
            case antipattern
            case securityRisk
            case performanceIssue
            case architectureViolation
        }

        public enum Source: String, Sendable {
            case pattern  // Detected by regex/pattern matching
            case ai       // Detected by AI semantic analysis
        }

        public init(
            type: IssueType,
            line: Int,
            message: String,
            suggestion: String? = nil,
            confidence: Double = 1.0,
            source: Source = .pattern
        ) {
            self.type = type
            self.line = line
            self.message = message
            self.suggestion = suggestion
            self.confidence = confidence
            self.source = source
        }

        /// Human-readable description with suggestion
        public var fullDescription: String {
            var desc = "[\(source.rawValue.uppercased())] \(message)"
            if let sugg = suggestion {
                desc += "\n  → \(sugg)"
            }
            if confidence < 1.0 {
                desc += " (confidence: \(Int(confidence * 100))%)"
            }
            return desc
        }
    }
}
