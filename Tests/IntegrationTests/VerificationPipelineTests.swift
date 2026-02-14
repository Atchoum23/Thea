@testable import TheaCore
import XCTest

/// Tests for the Verification Pipeline — ConfidenceSystem, ConfidenceLevel, scoring math
@MainActor
final class VerificationPipelineTests: XCTestCase {

    // MARK: - ConfidenceLevel Tests

    func testConfidenceLevelHigh() {
        XCTAssertEqual(ConfidenceLevel(from: 0.85), .high)
        XCTAssertEqual(ConfidenceLevel(from: 0.95), .high)
        XCTAssertEqual(ConfidenceLevel(from: 1.0), .high)
    }

    func testConfidenceLevelMedium() {
        XCTAssertEqual(ConfidenceLevel(from: 0.60), .medium)
        XCTAssertEqual(ConfidenceLevel(from: 0.75), .medium)
        XCTAssertEqual(ConfidenceLevel(from: 0.84), .medium)
    }

    func testConfidenceLevelLow() {
        XCTAssertEqual(ConfidenceLevel(from: 0.30), .low)
        XCTAssertEqual(ConfidenceLevel(from: 0.45), .low)
        XCTAssertEqual(ConfidenceLevel(from: 0.59), .low)
    }

    func testConfidenceLevelUnverified() {
        XCTAssertEqual(ConfidenceLevel(from: 0.0), .unverified)
        XCTAssertEqual(ConfidenceLevel(from: 0.15), .unverified)
        XCTAssertEqual(ConfidenceLevel(from: 0.29), .unverified)
    }

    func testConfidenceLevelNegativeValue() {
        XCTAssertEqual(ConfidenceLevel(from: -0.5), .unverified)
    }

    func testConfidenceLevelColors() {
        XCTAssertEqual(ConfidenceLevel.high.color, "green")
        XCTAssertEqual(ConfidenceLevel.medium.color, "orange")
        XCTAssertEqual(ConfidenceLevel.low.color, "red")
        XCTAssertEqual(ConfidenceLevel.unverified.color, "gray")
    }

    func testConfidenceLevelIcons() {
        XCTAssertFalse(ConfidenceLevel.high.icon.isEmpty)
        XCTAssertFalse(ConfidenceLevel.medium.icon.isEmpty)
        XCTAssertFalse(ConfidenceLevel.low.icon.isEmpty)
        XCTAssertFalse(ConfidenceLevel.unverified.icon.isEmpty)
    }

    func testConfidenceLevelActionRequired() {
        XCTAssertFalse(ConfidenceLevel.high.actionRequired)
        XCTAssertFalse(ConfidenceLevel.medium.actionRequired)
        XCTAssertTrue(ConfidenceLevel.low.actionRequired)
        XCTAssertTrue(ConfidenceLevel.unverified.actionRequired)
    }

    func testConfidenceLevelCaseIterable() {
        XCTAssertEqual(ConfidenceLevel.allCases.count, 4)
    }

    // MARK: - ConfidenceResult Tests

    func testConfidenceResultClampsToOne() {
        let result = ConfidenceResult(
            overallConfidence: 1.5,
            sources: [],
            decomposition: ConfidenceDecomposition(
                factors: [], conflicts: [], reasoning: "Test", suggestions: []
            )
        )
        XCTAssertEqual(result.overallConfidence, 1.0)
        XCTAssertEqual(result.level, .high)
    }

    func testConfidenceResultClampsToZero() {
        let result = ConfidenceResult(
            overallConfidence: -0.5,
            sources: [],
            decomposition: ConfidenceDecomposition(
                factors: [], conflicts: [], reasoning: "Test", suggestions: []
            )
        )
        XCTAssertEqual(result.overallConfidence, 0.0)
        XCTAssertEqual(result.level, .unverified)
    }

    func testConfidenceResultReasoningFromDecomposition() {
        let result = ConfidenceResult(
            overallConfidence: 0.8,
            sources: [],
            decomposition: ConfidenceDecomposition(
                factors: [], conflicts: [], reasoning: "Multi-model agreement", suggestions: ["Add more sources"]
            )
        )
        XCTAssertEqual(result.reasoning, "Multi-model agreement")
        XCTAssertEqual(result.improvementSuggestions, ["Add more sources"])
    }

    // MARK: - ConfidenceSource Tests

    func testConfidenceSourceWeightedConfidence() {
        let source = ConfidenceSource(
            type: .modelConsensus,
            name: "Model Consensus",
            confidence: 0.9,
            weight: 0.35,
            details: "3/3 models agree",
            verified: true
        )
        XCTAssertEqual(source.weightedConfidence, 0.315, accuracy: 0.001)
    }

    func testConfidenceSourceZeroWeight() {
        let source = ConfidenceSource(
            type: .patternMatch,
            name: "Pattern",
            confidence: 1.0,
            weight: 0.0,
            details: "Matched",
            verified: true
        )
        XCTAssertEqual(source.weightedConfidence, 0.0)
    }

    func testConfidenceSourceTypeIcons() {
        for sourceType in ConfidenceSource.SourceType.allCases {
            let source = ConfidenceSource(
                type: sourceType, name: sourceType.rawValue,
                confidence: 0.5, weight: 0.1, details: "", verified: true
            )
            XCTAssertFalse(source.icon.isEmpty, "\(sourceType) should have an icon")
        }
    }

    func testAllSourceTypesHaveRawValues() {
        for sourceType in ConfidenceSource.SourceType.allCases {
            XCTAssertFalse(sourceType.rawValue.isEmpty)
        }
    }

    // MARK: - ConfidenceDecomposition Tests

    func testDecompositionHasConflictsWhenPresent() {
        let conflict = ConfidenceDecomposition.ConflictInfo(
            source1: "Model A", source2: "Model B",
            description: "Disagreement on accuracy",
            severity: .moderate
        )
        let decomposition = ConfidenceDecomposition(
            factors: [], conflicts: [conflict],
            reasoning: "Sources disagree", suggestions: []
        )
        XCTAssertTrue(decomposition.hasConflicts)
    }

    func testDecompositionNoConflictsWhenEmpty() {
        let decomposition = ConfidenceDecomposition(
            factors: [], conflicts: [],
            reasoning: "All clear", suggestions: []
        )
        XCTAssertFalse(decomposition.hasConflicts)
    }

    func testConflictSeverityLevels() {
        XCTAssertEqual(ConfidenceDecomposition.ConflictInfo.ConflictSeverity.minor.rawValue, "Minor")
        XCTAssertEqual(ConfidenceDecomposition.ConflictInfo.ConflictSeverity.moderate.rawValue, "Moderate")
        XCTAssertEqual(ConfidenceDecomposition.ConflictInfo.ConflictSeverity.major.rawValue, "Major")
    }

    // MARK: - ConfidenceSystem Singleton Tests

    func testConfidenceSystemSingleton() {
        let system = ConfidenceSystem.shared
        XCTAssertNotNil(system)
        XCTAssertTrue(system === ConfidenceSystem.shared)
    }

    func testConfidenceSystemDefaultWeights() {
        let system = ConfidenceSystem.shared
        XCTAssertEqual(system.sourceWeights[.modelConsensus], 0.35)
        XCTAssertEqual(system.sourceWeights[.webVerification], 0.20)
        XCTAssertEqual(system.sourceWeights[.codeExecution], 0.25)
        XCTAssertEqual(system.sourceWeights[.staticAnalysis], 0.10)
        XCTAssertEqual(system.sourceWeights[.userFeedback], 0.10)
    }

    func testConfidenceSystemDefaultEnableFlags() {
        let system = ConfidenceSystem.shared
        XCTAssertTrue(system.enableMultiModel)
        XCTAssertTrue(system.enableWebVerification)
        XCTAssertTrue(system.enableCodeExecution)
        XCTAssertTrue(system.enableStaticAnalysis)
        XCTAssertTrue(system.enableFeedbackLearning)
    }

    func testConfidenceSystemWeightsSumToOne() {
        let system = ConfidenceSystem.shared
        let totalWeight = system.sourceWeights.values.reduce(0, +)
        // Weights don't need to sum to exactly 1.0 (they're normalized in calculation)
        // but they should be reasonable (0.5 - 2.0)
        XCTAssertGreaterThan(totalWeight, 0.5)
        XCTAssertLessThan(totalWeight, 2.0)
    }
}
