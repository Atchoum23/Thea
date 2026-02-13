// TestGeneratorTypes.swift
// Thea V2
//
// Types supporting AI-powered test generation

import Foundation

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
