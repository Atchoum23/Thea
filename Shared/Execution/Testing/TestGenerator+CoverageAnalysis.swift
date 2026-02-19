// TestGenerator+CoverageAnalysis.swift
// Thea V2
//
// Coverage gap analysis and helper methods

import Foundation

// MARK: - Coverage Analysis

extension TestGenerator {

    func analyzeCoverageGaps(
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

        // Suggest edge cases for throwing and async functions
        appendEdgeCases(
            for: sourceAnalysis.functions,
            to: &missingEdgeCases
        )

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

    private func appendEdgeCases(
        for functions: [FunctionInfo],
        to missingEdgeCases: inout [CoverageGapAnalysis.MissingEdgeCase]
    ) {
        for function in functions {
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
    }
}

// MARK: - Helper Methods

extension TestGenerator {

    func defaultFramework(for language: ProgrammingLanguage) -> TestFramework {
        switch language {
        case .swift: return .swiftTesting
        case .python: return .pytest
        case .javascript, .typescript: return .jest
        case .go: return .goTest
        case .rust: return .rustCargo
        default: return .jest
        }
    }

    func suggestTestFilePath(for sourcePath: String, language: ProgrammingLanguage) -> String {
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
