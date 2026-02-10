// TestGenerator.swift
// Thea V2
//
// AI-powered test generation
// Generates unit tests, edge cases, and coverage gap analysis

import Foundation
import OSLog

// MARK: - Test Generation Request

/// Request for generating tests
public struct TestGenerationRequest: Sendable {
    public let sourceCode: String
    public let filePath: String
    public let language: ProgrammingLanguage
    public let framework: TestFramework?
    public let existingTests: String?
    public let focusAreas: [TestFocusArea]
    public let maxTests: Int

    public init(
        sourceCode: String,
        filePath: String,
        language: ProgrammingLanguage,
        framework: TestFramework? = nil,
        existingTests: String? = nil,
        focusAreas: [TestFocusArea] = [.unitTests, .edgeCases],
        maxTests: Int = 10
    ) {
        self.sourceCode = sourceCode
        self.filePath = filePath
        self.language = language
        self.framework = framework
        self.existingTests = existingTests
        self.focusAreas = focusAreas
        self.maxTests = maxTests
    }
}

/// Focus areas for test generation
public enum TestFocusArea: String, Codable, Sendable, CaseIterable {
    case unitTests = "Unit Tests"
    case edgeCases = "Edge Cases"
    case errorHandling = "Error Handling"
    case boundaryConditions = "Boundary Conditions"
    case nullSafety = "Null Safety"
    case concurrency = "Concurrency"
    case integration = "Integration"
    case performance = "Performance"
}

// MARK: - Generated Test

/// A generated test
public struct GeneratedTest: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let code: String
    public let focusArea: TestFocusArea
    public let targetFunction: String?
    public let confidence: Double
    public let explanation: String

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        code: String,
        focusArea: TestFocusArea,
        targetFunction: String? = nil,
        confidence: Double,
        explanation: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.code = code
        self.focusArea = focusArea
        self.targetFunction = targetFunction
        self.confidence = confidence
        self.explanation = explanation
    }
}

/// Result of test generation
public struct TestGenerationResult: Sendable {
    public let request: TestGenerationRequest
    public let generatedTests: [GeneratedTest]
    public let testFileContent: String
    public let suggestedFilePath: String
    public let coverageAnalysis: CoverageGapAnalysis?
    public let generationTime: TimeInterval

    public init(
        request: TestGenerationRequest,
        generatedTests: [GeneratedTest],
        testFileContent: String,
        suggestedFilePath: String,
        coverageAnalysis: CoverageGapAnalysis? = nil,
        generationTime: TimeInterval
    ) {
        self.request = request
        self.generatedTests = generatedTests
        self.testFileContent = testFileContent
        self.suggestedFilePath = suggestedFilePath
        self.coverageAnalysis = coverageAnalysis
        self.generationTime = generationTime
    }
}

/// Coverage gap analysis
public struct CoverageGapAnalysis: Sendable {
    public let untestedFunctions: [String]
    public let missingEdgeCases: [MissingEdgeCase]
    public let suggestedImprovements: [String]

    public struct MissingEdgeCase: Sendable {
        public let functionName: String
        public let caseDescription: String
        public let severity: Severity

        public enum Severity: String, Sendable {
            case low, medium, high, critical
        }
    }
}

// MARK: - Test Generator

/// AI-powered test generator
@MainActor
@Observable
public final class TestGenerator {
    public static let shared = TestGenerator()

    private let logger = Logger(subsystem: "com.thea.testing", category: "TestGenerator")

    // MARK: - State

    private(set) var isGenerating = false
    private(set) var recentGenerations: [TestGenerationResult] = []

    // MARK: - Configuration

    /// Preferred test style (BDD vs traditional)
    public var preferBDDStyle: Bool = true

    /// Include descriptive comments
    public var includeComments: Bool = true

    /// Generate mock objects when needed
    public var generateMocks: Bool = true

    private init() {}

    // MARK: - Test Generation

    /// Generate tests for source code
    public func generateTests(
        request: TestGenerationRequest,
        progressHandler: (@Sendable (TestGenerationProgress) -> Void)? = nil
    ) async throws -> TestGenerationResult {
        guard !isGenerating else {
            throw TestGeneratorError.alreadyGenerating
        }

        isGenerating = true
        defer { isGenerating = false }

        let startTime = Date()
        logger.info("Starting test generation for \(request.filePath)")

        progressHandler?(TestGenerationProgress(
            phase: .analyzing,
            message: "Analyzing source code",
            progress: 0.1
        ))

        // Get AI provider
        guard let provider = ProviderRegistry.shared.getDefaultProvider() ??
              ProviderRegistry.shared.configuredProviders.first else {
            throw TestGeneratorError.noProviderAvailable
        }

        // Analyze source code
        let analysis = analyzeSourceCode(request.sourceCode, language: request.language)

        progressHandler?(TestGenerationProgress(
            phase: .generating,
            message: "Generating tests with AI",
            progress: 0.3
        ))

        // Build prompt
        let prompt = buildTestGenerationPrompt(
            request: request,
            analysis: analysis
        )

        // Generate tests using AI - stream response and collect into string
        let userMessage = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: ""
        )
        let model = AppConfiguration.shared.providerConfig.defaultModel
        let stream = try await provider.chat(
            messages: [userMessage],
            model: model.isEmpty ? "gpt-4" : model,
            stream: true
        )
        var aiResponse = ""
        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                aiResponse += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        progressHandler?(TestGenerationProgress(
            phase: .parsing,
            message: "Parsing generated tests",
            progress: 0.7
        ))

        // Parse AI response
        let generatedTests = parseGeneratedTests(
            response: aiResponse,
            language: request.language,
            focusAreas: request.focusAreas
        )

        progressHandler?(TestGenerationProgress(
            phase: .formatting,
            message: "Formatting test file",
            progress: 0.9
        ))

        // Generate complete test file
        let testFileContent = generateTestFile(
            tests: generatedTests,
            request: request,
            analysis: analysis
        )

        // Generate coverage analysis
        let coverageAnalysis = analyzeCoverageGaps(
            sourceAnalysis: analysis,
            existingTests: request.existingTests,
            generatedTests: generatedTests
        )

        // Determine output path
        let suggestedFilePath = suggestTestFilePath(for: request.filePath, language: request.language)

        let result = TestGenerationResult(
            request: request,
            generatedTests: generatedTests,
            testFileContent: testFileContent,
            suggestedFilePath: suggestedFilePath,
            coverageAnalysis: coverageAnalysis,
            generationTime: Date().timeIntervalSince(startTime)
        )

        recentGenerations.insert(result, at: 0)
        if recentGenerations.count > 20 {
            recentGenerations.removeLast()
        }

        progressHandler?(TestGenerationProgress(
            phase: .completed,
            message: "Generated \(generatedTests.count) tests",
            progress: 1.0
        ))

        logger.info("Generated \(generatedTests.count) tests in \(String(format: "%.2f", result.generationTime))s")

        return result
    }

    /// Generate tests for a specific function
    public func generateTestsForFunction(
        function: String,
        sourceCode: String,
        language: ProgrammingLanguage
    ) async throws -> [GeneratedTest] {
        let request = TestGenerationRequest(
            sourceCode: sourceCode,
            filePath: "function_test",
            language: language,
            maxTests: 5
        )

        let result = try await generateTests(request: request)
        return result.generatedTests.filter { $0.targetFunction == function }
    }

    // MARK: - Source Analysis

    private struct SourceAnalysis {
        let functions: [FunctionInfo]
        let classes: [ClassInfo]
        let imports: [String]
        let hasAsyncCode: Bool
        let hasErrorHandling: Bool
        let complexity: Int
    }

    private struct FunctionInfo {
        let name: String
        let parameters: [(name: String, type: String)]
        let returnType: String?
        let isAsync: Bool
        let canThrow: Bool
        let visibility: String
        let lineNumber: Int
    }

    private struct ClassInfo {
        let name: String
        let methods: [FunctionInfo]
        let properties: [String]
        let protocols: [String]
    }

    private func analyzeSourceCode(_ code: String, language: ProgrammingLanguage) -> SourceAnalysis {
        var functions: [FunctionInfo] = []
        var classes: [ClassInfo] = []
        var imports: [String] = []
        var hasAsync = false
        var hasErrorHandling = false

        let lines = code.components(separatedBy: .newlines)

        switch language {
        case .swift:
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Detect imports
                if trimmed.hasPrefix("import ") {
                    imports.append(String(trimmed.dropFirst(7)))
                }

                // Detect functions
                if let funcMatch = trimmed.range(of: #"(public |private |internal |fileprivate )?(func |init)"#, options: .regularExpression) {
                    let funcName = extractFunctionName(from: trimmed, language: language)
                    let isAsync = trimmed.contains("async")
                    let canThrowError = trimmed.contains("throws")

                    if isAsync { hasAsync = true }
                    if canThrowError { hasErrorHandling = true }

                    functions.append(FunctionInfo(
                        name: funcName,
                        parameters: extractParameters(from: trimmed, language: language),
                        returnType: extractReturnType(from: trimmed, language: language),
                        isAsync: isAsync,
                        canThrow: canThrowError,
                        visibility: extractVisibility(from: trimmed),
                        lineNumber: index + 1
                    ))
                }

                // Detect classes/structs
                if trimmed.contains("class ") || trimmed.contains("struct ") {
                    let className = extractClassName(from: trimmed)
                    classes.append(ClassInfo(
                        name: className,
                        methods: [],
                        properties: [],
                        protocols: []
                    ))
                }
            }

        case .python:
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") {
                    imports.append(trimmed)
                }

                if trimmed.hasPrefix("def ") || trimmed.hasPrefix("async def ") {
                    let isAsync = trimmed.hasPrefix("async def ")
                    if isAsync { hasAsync = true }

                    let funcName = extractFunctionName(from: trimmed, language: language)
                    functions.append(FunctionInfo(
                        name: funcName,
                        parameters: extractParameters(from: trimmed, language: language),
                        returnType: extractReturnType(from: trimmed, language: language),
                        isAsync: isAsync,
                        canThrow: false,
                        visibility: funcName.hasPrefix("_") ? "private" : "public",
                        lineNumber: index + 1
                    ))
                }

                if trimmed.hasPrefix("class ") {
                    let className = extractClassName(from: trimmed)
                    classes.append(ClassInfo(
                        name: className,
                        methods: [],
                        properties: [],
                        protocols: []
                    ))
                }
            }

        case .javascript, .typescript:
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.contains("import ") || trimmed.contains("require(") {
                    imports.append(trimmed)
                }

                if trimmed.contains("function ") || trimmed.contains("async function ") ||
                   trimmed.contains("=> {") || trimmed.contains("=> (") {
                    let isAsync = trimmed.contains("async")
                    if isAsync { hasAsync = true }

                    let funcName = extractFunctionName(from: trimmed, language: language)
                    functions.append(FunctionInfo(
                        name: funcName,
                        parameters: extractParameters(from: trimmed, language: language),
                        returnType: nil,
                        isAsync: isAsync,
                        canThrow: false,
                        visibility: "public",
                        lineNumber: index + 1
                    ))
                }

                if trimmed.contains("class ") {
                    let className = extractClassName(from: trimmed)
                    classes.append(ClassInfo(
                        name: className,
                        methods: [],
                        properties: [],
                        protocols: []
                    ))
                }

                if trimmed.contains("try ") || trimmed.contains("catch ") {
                    hasErrorHandling = true
                }
            }

        default:
            break
        }

        return SourceAnalysis(
            functions: functions,
            classes: classes,
            imports: imports,
            hasAsyncCode: hasAsync,
            hasErrorHandling: hasErrorHandling,
            complexity: calculateComplexity(code)
        )
    }

    private func extractFunctionName(from line: String, language: ProgrammingLanguage) -> String {
        switch language {
        case .swift:
            if let match = line.firstMatch(of: /func\s+(\w+)/) {
                return String(match.1)
            }
            if line.contains("init") {
                return "init"
            }
        case .python:
            if let match = line.firstMatch(of: /def\s+(\w+)/) {
                return String(match.1)
            }
        case .javascript, .typescript:
            if let match = line.firstMatch(of: /function\s+(\w+)/) {
                return String(match.1)
            }
            if let match = line.firstMatch(of: /(\w+)\s*[=:]\s*(async\s+)?(\([^)]*\)|[^=])\s*=>/) {
                return String(match.1)
            }
        default:
            break
        }
        return "unknown"
    }

    private func extractParameters(from line: String, language: ProgrammingLanguage) -> [(name: String, type: String)] {
        // Simplified parameter extraction
        []
    }

    private func extractReturnType(from line: String, language: ProgrammingLanguage) -> String? {
        switch language {
        case .swift:
            if let match = line.firstMatch(of: /->\s*(\w+)/) {
                return String(match.1)
            }
        case .python:
            if let match = line.firstMatch(of: /->\s*(\w+)/) {
                return String(match.1)
            }
        default:
            break
        }
        return nil
    }

    private func extractVisibility(from line: String) -> String {
        if line.contains("public ") { return "public" }
        if line.contains("private ") { return "private" }
        if line.contains("internal ") { return "internal" }
        if line.contains("fileprivate ") { return "fileprivate" }
        return "internal"
    }

    private func extractClassName(from line: String) -> String {
        if let match = line.firstMatch(of: /(class|struct)\s+(\w+)/) {
            return String(match.2)
        }
        return "Unknown"
    }

    private func calculateComplexity(_ code: String) -> Int {
        var complexity = 1
        let controlFlow = ["if ", "else ", "for ", "while ", "switch ", "case ", "guard ", "catch "]
        for keyword in controlFlow {
            complexity += code.components(separatedBy: keyword).count - 1
        }
        return complexity
    }

    // MARK: - Prompt Building

    private func buildTestGenerationPrompt(
        request: TestGenerationRequest,
        analysis: SourceAnalysis
    ) -> String {
        let frameworkName = request.framework?.rawValue ?? defaultFramework(for: request.language).rawValue
        let focusAreasStr = request.focusAreas.map(\.rawValue).joined(separator: ", ")

        return """
        Generate comprehensive unit tests for the following \(request.language.rawValue) code.

        ## Source Code
        ```\(request.language.rawValue)
        \(request.sourceCode)
        ```

        ## Analysis
        - Functions found: \(analysis.functions.map(\.name).joined(separator: ", "))
        - Classes/Structs: \(analysis.classes.map(\.name).joined(separator: ", "))
        - Has async code: \(analysis.hasAsyncCode)
        - Has error handling: \(analysis.hasErrorHandling)
        - Complexity score: \(analysis.complexity)

        ## Requirements
        - Test framework: \(frameworkName)
        - Focus areas: \(focusAreasStr)
        - Maximum tests: \(request.maxTests)
        - Style: \(preferBDDStyle ? "BDD (describe/it)" : "Traditional (test functions)")

        ## Instructions
        1. Generate tests for each public function
        2. Include edge cases and boundary conditions
        3. Test error handling paths
        4. Include descriptive test names
        5. Add comments explaining what each test verifies

        \(analysis.hasAsyncCode ? "6. Use proper async/await test patterns" : "")

        ## Output Format
        For each test, provide:
        - Test name
        - Description of what it tests
        - The complete test code
        - Which function it targets
        - Confidence level (0.0-1.0)

        Generate the tests now:
        """
    }

    // MARK: - Response Parsing

    private func parseGeneratedTests(
        response: String,
        language: ProgrammingLanguage,
        focusAreas: [TestFocusArea]
    ) -> [GeneratedTest] {
        var tests: [GeneratedTest] = []

        // Extract code blocks
        let codeBlockPattern = "```(?:\(language.rawValue))?\\s*([\\s\\S]*?)```"
        let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [])
        let range = NSRange(response.startIndex..., in: response)

        regex?.enumerateMatches(in: response, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let codeRange = Range(match.range(at: 1), in: response) else { return }

            let code = String(response[codeRange])

            // Extract test name from code
            let testName = extractTestName(from: code, language: language)

            tests.append(GeneratedTest(
                name: testName,
                description: "Generated test for \(testName)",
                code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                focusArea: focusAreas.first ?? .unitTests,
                targetFunction: nil,
                confidence: 0.8,
                explanation: "AI-generated test"
            ))
        }

        // If no code blocks found, try to parse the entire response
        if tests.isEmpty && response.contains("func test") || response.contains("def test_") || response.contains("test(") {
            tests.append(GeneratedTest(
                name: "GeneratedTests",
                description: "AI-generated test suite",
                code: response,
                focusArea: focusAreas.first ?? .unitTests,
                confidence: 0.6,
                explanation: "Parsed from response"
            ))
        }

        return tests
    }

    private func extractTestName(from code: String, language: ProgrammingLanguage) -> String {
        switch language {
        case .swift:
            if let match = code.firstMatch(of: /func\s+(test\w+)/) {
                return String(match.1)
            }
        case .python:
            if let match = code.firstMatch(of: /def\s+(test_\w+)/) {
                return String(match.1)
            }
        case .javascript, .typescript:
            if let match = code.firstMatch(of: /(?:it|test)\s*\(\s*['"]([^'"]+)['"]/) {
                return String(match.1)
            }
        default:
            break
        }
        return "generatedTest"
    }

    // MARK: - Test File Generation

    private func generateTestFile(
        tests: [GeneratedTest],
        request: TestGenerationRequest,
        analysis: SourceAnalysis
    ) -> String {
        let framework = request.framework ?? defaultFramework(for: request.language)

        switch request.language {
        case .swift:
            return generateSwiftTestFile(tests: tests, framework: framework, analysis: analysis)
        case .python:
            return generatePythonTestFile(tests: tests, framework: framework)
        case .javascript, .typescript:
            return generateJSTestFile(tests: tests, framework: framework, isTS: request.language == .typescript)
        default:
            return tests.map(\.code).joined(separator: "\n\n")
        }
    }

    private func generateSwiftTestFile(
        tests: [GeneratedTest],
        framework: TestFramework,
        analysis: SourceAnalysis
    ) -> String {
        var content = """
        // Generated Tests
        // Auto-generated by Thea TestGenerator

        import XCTest
        @testable import \(extractModuleName(from: analysis))

        final class GeneratedTests: XCTestCase {

        """

        for test in tests {
            content += """
                /// \(test.description)
                \(test.code)

            """
        }

        content += "}\n"
        return content
    }

    private func generatePythonTestFile(tests: [GeneratedTest], framework: TestFramework) -> String {
        var content = """
        # Generated Tests
        # Auto-generated by Thea TestGenerator

        """

        if framework == .pytest {
            content += "import pytest\n\n"
        } else {
            content += "import unittest\n\n"
        }

        for test in tests {
            content += """
            # \(test.description)
            \(test.code)

            """
        }

        if framework == .unittest {
            content += """

            if __name__ == '__main__':
                unittest.main()
            """
        }

        return content
    }

    private func generateJSTestFile(tests: [GeneratedTest], framework: TestFramework, isTS: Bool) -> String {
        var content = """
        // Generated Tests
        // Auto-generated by Thea TestGenerator

        """

        if framework == .jest {
            content += "describe('Generated Tests', () => {\n"
        } else if framework == .mocha {
            content += "const { expect } = require('chai');\n\ndescribe('Generated Tests', function() {\n"
        }

        for test in tests {
            content += """
              // \(test.description)
              \(test.code)

            """
        }

        content += "});\n"
        return content
    }

    private func extractModuleName(from analysis: SourceAnalysis) -> String {
        // Try to extract from imports or return default
        for imp in analysis.imports where !imp.contains("Foundation") && !imp.contains("UIKit") {
            return imp
        }
        return "YourModule"
    }

    // MARK: - Coverage Analysis

    private func analyzeCoverageGaps(
        sourceAnalysis: SourceAnalysis,
        existingTests: String?,
        generatedTests: [GeneratedTest]
    ) -> CoverageGapAnalysis {
        var untestedFunctions: [String] = []
        var missingEdgeCases: [CoverageGapAnalysis.MissingEdgeCase] = []
        var suggestions: [String] = []

        // Find functions without tests
        let testedFunctions = Set(generatedTests.compactMap(\.targetFunction))
        for function in sourceAnalysis.functions {
            if !testedFunctions.contains(function.name) && function.visibility == "public" {
                untestedFunctions.append(function.name)
            }
        }

        // Suggest edge cases
        for function in sourceAnalysis.functions {
            if function.canThrow {
                missingEdgeCases.append(CoverageGapAnalysis.MissingEdgeCase(
                    functionName: function.name,
                    caseDescription: "Test error throwing path",
                    severity: .high
                ))
            }

            if function.isAsync {
                missingEdgeCases.append(CoverageGapAnalysis.MissingEdgeCase(
                    functionName: function.name,
                    caseDescription: "Test async cancellation",
                    severity: .medium
                ))
            }
        }

        // Generate suggestions
        if !untestedFunctions.isEmpty {
            suggestions.append("Add tests for: \(untestedFunctions.joined(separator: ", "))")
        }

        if sourceAnalysis.hasErrorHandling {
            suggestions.append("Consider adding more error handling tests")
        }

        if sourceAnalysis.complexity > 10 {
            suggestions.append("High complexity detected - consider adding more edge case tests")
        }

        return CoverageGapAnalysis(
            untestedFunctions: untestedFunctions,
            missingEdgeCases: missingEdgeCases,
            suggestedImprovements: suggestions
        )
    }

    // MARK: - Helper Methods

    private func defaultFramework(for language: ProgrammingLanguage) -> TestFramework {
        switch language {
        case .swift: return .swiftTesting
        case .python: return .pytest
        case .javascript, .typescript: return .jest
        case .go: return .goTest
        case .rust: return .rustCargo
        default: return .jest
        }
    }

    private func suggestTestFilePath(for sourcePath: String, language: ProgrammingLanguage) -> String {
        let directory = (sourcePath as NSString).deletingLastPathComponent
        let fileName = (sourcePath as NSString).lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension

        switch language {
        case .swift:
            return (directory as NSString).appendingPathComponent("\(baseName)Tests.swift")
        case .python:
            return (directory as NSString).appendingPathComponent("test_\(baseName).py")
        case .javascript:
            return (directory as NSString).appendingPathComponent("\(baseName).test.js")
        case .typescript:
            return (directory as NSString).appendingPathComponent("\(baseName).test.ts")
        default:
            return (directory as NSString).appendingPathComponent("\(baseName)_test")
        }
    }
}

// MARK: - Progress

public struct TestGenerationProgress: Sendable {
    public let phase: Phase
    public let message: String
    public let progress: Double

    public enum Phase: String, Sendable {
        case analyzing
        case generating
        case parsing
        case formatting
        case completed
    }
}

// MARK: - Errors

public enum TestGeneratorError: LocalizedError {
    case alreadyGenerating
    case noProviderAvailable
    case generationFailed(String)
    case parsingFailed

    public var errorDescription: String? {
        switch self {
        case .alreadyGenerating:
            "Test generator is already running"
        case .noProviderAvailable:
            "No AI provider available"
        case .generationFailed(let message):
            "Test generation failed: \(message)"
        case .parsingFailed:
            "Failed to parse generated tests"
        }
    }
}
