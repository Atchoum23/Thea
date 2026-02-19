// TestGenerator+Templates.swift
// Thea V2
//
// Test file generation templates and prompt building

import Foundation

// MARK: - Prompt Building

extension TestGenerator {

    func buildTestGenerationPrompt(
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
}

// MARK: - Response Parsing

extension TestGenerator {

    func parseGeneratedTests(
        response: String,
        language: ProgrammingLanguage,
        focusAreas: [TestFocusArea]
    ) -> [GeneratedTest] {
        var tests: [GeneratedTest] = []

        // Extract code blocks
        let codeBlockPattern = "```(?:\(language.rawValue))?\\s*([\\s\\S]*?)```"
        // Safe: compile-time known markdown code fence pattern; invalid regex → nil, enumerateMatches is a no-op
        let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [])
        let range = NSRange(response.startIndex..., in: response)

        regex?.enumerateMatches(in: response, options: [], range: range) { match, _, _ in
            guard let match = match,
                  let codeRange = Range(match.range(at: 1), in: response) else { return }

            let code = String(response[codeRange])

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

    func extractTestName(from code: String, language: ProgrammingLanguage) -> String {
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
}

// MARK: - Test File Generation

extension TestGenerator {

    func generateTestFile(
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
        // periphery:ignore - Reserved: framework parameter kept for API compatibility
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

    // periphery:ignore - Reserved: isTS parameter kept for API compatibility
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

    func extractModuleName(from analysis: SourceAnalysis) -> String {
        for imp in analysis.imports where !imp.contains("Foundation") && !imp.contains("UIKit") {
            return imp
        }
        return "YourModule"
    }
}
