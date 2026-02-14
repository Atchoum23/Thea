// VerificationOrchestrationTests.swift
// Tests for ConfidenceSystem orchestration logic: multi-verifier coordination,
// source weighting, conflict resolution, and latency-aware path selection.

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum ConfidenceLevel: String, CaseIterable, Codable, Sendable {
    case high
    case medium
    case low
    case unverified

    init(score: Double) {
        switch score {
        case 0.85...: self = .high
        case 0.60..<0.85: self = .medium
        case 0.30..<0.60: self = .low
        default: self = .unverified
        }
    }

    var actionRequired: Bool {
        switch self {
        case .high, .medium: false
        case .low, .unverified: true
        }
    }
}

private enum VerifierType: String, CaseIterable, Codable, Sendable {
    case multiModel
    case webSearch
    case staticAnalysis
    case codeExecution
    case userFeedback

    var displayName: String {
        switch self {
        case .multiModel: "Multi-Model Consensus"
        case .webSearch: "Web Search Verification"
        case .staticAnalysis: "Static Analysis"
        case .codeExecution: "Code Execution"
        case .userFeedback: "User Feedback"
        }
    }

    var defaultWeight: Double {
        switch self {
        case .multiModel: 0.30
        case .webSearch: 0.25
        case .staticAnalysis: 0.20
        case .codeExecution: 0.15
        case .userFeedback: 0.10
        }
    }

    var typicalLatencyMs: Int {
        switch self {
        case .multiModel: 5000
        case .webSearch: 3000
        case .staticAnalysis: 500
        case .codeExecution: 2000
        case .userFeedback: 0
        }
    }
}

private struct VerifierResult: Sendable {
    let verifier: VerifierType
    let confidence: Double
    let reasoning: String
    let latencyMs: Int
    let error: String?

    init(
        verifier: VerifierType,
        confidence: Double,
        reasoning: String = "",
        latencyMs: Int = 0,
        error: String? = nil
    ) {
        self.verifier = verifier
        self.confidence = confidence
        self.reasoning = reasoning
        self.latencyMs = latencyMs
        self.error = error
    }

    var isSuccessful: Bool {
        error == nil
    }
}

private struct ValidationConfig: Sendable {
    let enableMultiModel: Bool
    let enableWebSearch: Bool
    let enableStaticAnalysis: Bool
    let enableCodeExecution: Bool
    let enableUserFeedback: Bool
    let maxLatencyMs: Int

    static let `default` = ValidationConfig(
        enableMultiModel: true, enableWebSearch: true,
        enableStaticAnalysis: true, enableCodeExecution: true,
        enableUserFeedback: true, maxLatencyMs: 10_000
    )

    static let fast = ValidationConfig(
        enableMultiModel: false, enableWebSearch: false,
        enableStaticAnalysis: true, enableCodeExecution: false,
        enableUserFeedback: false, maxLatencyMs: 2000
    )

    static let thorough = ValidationConfig(
        enableMultiModel: true, enableWebSearch: true,
        enableStaticAnalysis: true, enableCodeExecution: true,
        enableUserFeedback: true, maxLatencyMs: 30_000
    )

    var enabledVerifiers: [VerifierType] {
        var result: [VerifierType] = []
        if enableMultiModel { result.append(.multiModel) }
        if enableWebSearch { result.append(.webSearch) }
        if enableStaticAnalysis { result.append(.staticAnalysis) }
        if enableCodeExecution { result.append(.codeExecution) }
        if enableUserFeedback { result.append(.userFeedback) }
        return result
    }
}

// MARK: - Pure Orchestration Functions

private func calculateWeightedConfidence(results: [VerifierResult]) -> Double {
    let successful = results.filter(\.isSuccessful)
    guard !successful.isEmpty else { return 0.0 }

    let totalWeight = successful.map { $0.verifier.defaultWeight }.reduce(0, +)
    guard totalWeight > 0 else { return 0.0 }

    let weightedSum = successful.map { $0.confidence * $0.verifier.defaultWeight }.reduce(0, +)
    return weightedSum / totalWeight
}

private func determineConflicts(results: [VerifierResult], threshold: Double = 0.3) -> [(VerifierResult, VerifierResult)] {
    var conflicts: [(VerifierResult, VerifierResult)] = []
    let successful = results.filter(\.isSuccessful)
    for i in 0 ..< successful.count {
        for j in (i + 1) ..< successful.count {
            if abs(successful[i].confidence - successful[j].confidence) > threshold {
                conflicts.append((successful[i], successful[j]))
            }
        }
    }
    return conflicts
}

private func selectVerifiers(
    config: ValidationConfig,
    responseContainsCode: Bool
) -> [VerifierType] {
    var verifiers = config.enabledVerifiers

    // If response contains code, prioritize code-relevant verifiers
    if responseContainsCode {
        // Ensure static analysis and code execution are included if enabled
        if config.enableStaticAnalysis && !verifiers.contains(.staticAnalysis) {
            verifiers.append(.staticAnalysis)
        }
        if config.enableCodeExecution && !verifiers.contains(.codeExecution) {
            verifiers.append(.codeExecution)
        }
    }

    // Filter by latency budget
    verifiers = verifiers.filter { $0.typicalLatencyMs <= config.maxLatencyMs }

    return verifiers
}

private func aggregateConfidence(
    results: [VerifierResult],
    minimumVerifiers: Int = 2
) -> (level: ConfidenceLevel, score: Double, sufficient: Bool) {
    let successful = results.filter(\.isSuccessful)
    let score = calculateWeightedConfidence(results: results)
    let level = ConfidenceLevel(score: score)
    let sufficient = successful.count >= minimumVerifiers
    return (level, score, sufficient)
}

// MARK: - VerifierType Tests

final class VerifierTypeTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(VerifierType.allCases.count, 5)
    }

    func testDisplayNamesNonEmpty() {
        for verifier in VerifierType.allCases {
            XCTAssertFalse(verifier.displayName.isEmpty, "\(verifier)")
        }
    }

    func testDefaultWeightsSumToOne() {
        let total = VerifierType.allCases.map(\.defaultWeight).reduce(0, +)
        XCTAssertEqual(total, 1.0, accuracy: 0.001)
    }

    func testMultiModelHasHighestWeight() {
        let maxWeight = VerifierType.allCases.max(by: { $0.defaultWeight < $1.defaultWeight })
        XCTAssertEqual(maxWeight, .multiModel)
    }

    func testUserFeedbackHasLowestWeight() {
        let minWeight = VerifierType.allCases.min(by: { $0.defaultWeight < $1.defaultWeight })
        XCTAssertEqual(minWeight, .userFeedback)
    }

    func testStaticAnalysisIsFastest() {
        let fastest = VerifierType.allCases
            .filter { $0 != .userFeedback }
            .min(by: { $0.typicalLatencyMs < $1.typicalLatencyMs })
        XCTAssertEqual(fastest, .staticAnalysis)
    }

    func testMultiModelIsSlowest() {
        let slowest = VerifierType.allCases.max(by: { $0.typicalLatencyMs < $1.typicalLatencyMs })
        XCTAssertEqual(slowest, .multiModel)
    }

    func testCodableRoundTrip() throws {
        for verifier in VerifierType.allCases {
            let data = try JSONEncoder().encode(verifier)
            let decoded = try JSONDecoder().decode(VerifierType.self, from: data)
            XCTAssertEqual(decoded, verifier)
        }
    }
}

// MARK: - Weighted Confidence Tests

final class WeightedConfidenceTests: XCTestCase {
    func testSingleVerifierResult() {
        let results = [VerifierResult(verifier: .multiModel, confidence: 0.9)]
        let score = calculateWeightedConfidence(results: results)
        XCTAssertEqual(score, 0.9, accuracy: 0.001)
    }

    func testMultipleVerifierResults() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.8)
        ]
        let score = calculateWeightedConfidence(results: results)
        // (0.9 * 0.30 + 0.8 * 0.25) / (0.30 + 0.25) = (0.27 + 0.20) / 0.55 = 0.854
        XCTAssertEqual(score, 0.854, accuracy: 0.01)
    }

    func testAllVerifiers() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.85),
            VerifierResult(verifier: .staticAnalysis, confidence: 0.95),
            VerifierResult(verifier: .codeExecution, confidence: 0.8),
            VerifierResult(verifier: .userFeedback, confidence: 0.7)
        ]
        let score = calculateWeightedConfidence(results: results)
        XCTAssertTrue(score > 0.8, "Expected high overall confidence")
        XCTAssertTrue(score < 1.0)
    }

    func testEmptyResults() {
        let score = calculateWeightedConfidence(results: [])
        XCTAssertEqual(score, 0.0)
    }

    func testFailedResultsExcluded() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.0, error: "Network failure")
        ]
        let score = calculateWeightedConfidence(results: results)
        XCTAssertEqual(score, 0.9, accuracy: 0.001) // Only multiModel counted
    }

    func testAllFailed() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.0, error: "Timeout"),
            VerifierResult(verifier: .webSearch, confidence: 0.0, error: "Timeout")
        ]
        let score = calculateWeightedConfidence(results: results)
        XCTAssertEqual(score, 0.0)
    }

    func testHighWeightDominates() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.1), // weight 0.30
            VerifierResult(verifier: .userFeedback, confidence: 0.9), // weight 0.10
        ]
        let score = calculateWeightedConfidence(results: results)
        // (0.1 * 0.30 + 0.9 * 0.10) / (0.30 + 0.10) = (0.03 + 0.09) / 0.40 = 0.30
        XCTAssertEqual(score, 0.30, accuracy: 0.01)
    }
}

// MARK: - Conflict Detection Tests

final class ConflictDetectionTests: XCTestCase {
    func testNoConflicts() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.85)
        ]
        let conflicts = determineConflicts(results: results)
        XCTAssertTrue(conflicts.isEmpty)
    }

    func testConflictDetected() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.3)
        ]
        let conflicts = determineConflicts(results: results)
        XCTAssertEqual(conflicts.count, 1)
    }

    func testBorderlineNoConflict() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.61)
        ]
        let conflicts = determineConflicts(results: results, threshold: 0.3)
        XCTAssertTrue(conflicts.isEmpty) // Difference is 0.29, below 0.3
    }

    func testBorderlineConflict() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.59)
        ]
        let conflicts = determineConflicts(results: results, threshold: 0.3)
        XCTAssertEqual(conflicts.count, 1) // Difference is 0.31, above 0.3
    }

    func testMultipleConflicts() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.95),
            VerifierResult(verifier: .webSearch, confidence: 0.4),
            VerifierResult(verifier: .staticAnalysis, confidence: 0.3)
        ]
        let conflicts = determineConflicts(results: results)
        XCTAssertEqual(conflicts.count, 2) // multiModel vs web, multiModel vs static
    }

    func testCustomThreshold() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.8)
        ]
        let conflicts = determineConflicts(results: results, threshold: 0.05)
        XCTAssertEqual(conflicts.count, 1) // 0.1 > 0.05
    }

    func testFailedResultsIgnored() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.1, error: "Failed")
        ]
        let conflicts = determineConflicts(results: results)
        XCTAssertTrue(conflicts.isEmpty) // Failed result excluded
    }
}

// MARK: - Verifier Selection Tests

final class VerifierSelectionTests: XCTestCase {
    func testDefaultConfigSelectsAll() {
        let verifiers = selectVerifiers(config: .default, responseContainsCode: false)
        XCTAssertEqual(verifiers.count, 5)
    }

    func testFastConfigSelectsOnlyStaticAnalysis() {
        let verifiers = selectVerifiers(config: .fast, responseContainsCode: false)
        XCTAssertEqual(verifiers.count, 1)
        XCTAssertTrue(verifiers.contains(.staticAnalysis))
    }

    func testFastConfigFiltersHighLatencyVerifiers() {
        let verifiers = selectVerifiers(config: .fast, responseContainsCode: true)
        // Static analysis (500ms) fits within 2000ms budget
        XCTAssertTrue(verifiers.contains(.staticAnalysis))
        // Multi-model (5000ms) exceeds 2000ms budget
        XCTAssertFalse(verifiers.contains(.multiModel))
    }

    func testCodeResponseIncludesCodeVerifiers() {
        let config = ValidationConfig(
            enableMultiModel: false, enableWebSearch: false,
            enableStaticAnalysis: true, enableCodeExecution: true,
            enableUserFeedback: false, maxLatencyMs: 10_000
        )
        let verifiers = selectVerifiers(config: config, responseContainsCode: true)
        XCTAssertTrue(verifiers.contains(.staticAnalysis))
        XCTAssertTrue(verifiers.contains(.codeExecution))
    }

    func testLatencyFilterRemovesSlowVerifiers() {
        let config = ValidationConfig(
            enableMultiModel: true, enableWebSearch: true,
            enableStaticAnalysis: true, enableCodeExecution: true,
            enableUserFeedback: true, maxLatencyMs: 1000
        )
        let verifiers = selectVerifiers(config: config, responseContainsCode: false)
        // Only staticAnalysis (500ms) and userFeedback (0ms) fit
        XCTAssertTrue(verifiers.contains(.staticAnalysis))
        XCTAssertTrue(verifiers.contains(.userFeedback))
        XCTAssertFalse(verifiers.contains(.multiModel))
        XCTAssertFalse(verifiers.contains(.webSearch))
        XCTAssertFalse(verifiers.contains(.codeExecution))
    }
}

// MARK: - Confidence Aggregation Tests

final class ConfidenceAggregationTests: XCTestCase {
    func testHighConfidence() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.95),
            VerifierResult(verifier: .webSearch, confidence: 0.90),
            VerifierResult(verifier: .staticAnalysis, confidence: 0.92)
        ]
        let (level, score, sufficient) = aggregateConfidence(results: results)
        XCTAssertEqual(level, .high)
        XCTAssertTrue(score >= 0.85)
        XCTAssertTrue(sufficient)
    }

    func testLowConfidence() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.3),
            VerifierResult(verifier: .webSearch, confidence: 0.4)
        ]
        let (level, _, sufficient) = aggregateConfidence(results: results)
        XCTAssertEqual(level, .low)
        XCTAssertTrue(sufficient)
    }

    func testInsufficientVerifiers() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.95)
        ]
        let (_, _, sufficient) = aggregateConfidence(results: results, minimumVerifiers: 2)
        XCTAssertFalse(sufficient)
    }

    func testSufficientVerifiers() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.9),
            VerifierResult(verifier: .webSearch, confidence: 0.8)
        ]
        let (_, _, sufficient) = aggregateConfidence(results: results, minimumVerifiers: 2)
        XCTAssertTrue(sufficient)
    }

    func testAllFailedResults() {
        let results = [
            VerifierResult(verifier: .multiModel, confidence: 0.0, error: "Timeout"),
            VerifierResult(verifier: .webSearch, confidence: 0.0, error: "Network")
        ]
        let (level, score, sufficient) = aggregateConfidence(results: results)
        XCTAssertEqual(level, .unverified)
        XCTAssertEqual(score, 0.0)
        XCTAssertFalse(sufficient)
    }

    func testEmptyResults() {
        let (level, score, sufficient) = aggregateConfidence(results: [])
        XCTAssertEqual(level, .unverified)
        XCTAssertEqual(score, 0.0)
        XCTAssertFalse(sufficient)
    }
}

// MARK: - ValidationConfig Tests

final class ValidationConfigTests: XCTestCase {
    func testDefaultEnablesAllVerifiers() {
        let config = ValidationConfig.default
        XCTAssertEqual(config.enabledVerifiers.count, 5)
    }

    func testFastDisablesMostVerifiers() {
        let config = ValidationConfig.fast
        XCTAssertEqual(config.enabledVerifiers.count, 1)
        XCTAssertTrue(config.enabledVerifiers.contains(.staticAnalysis))
    }

    func testThoroughEnablesAllWithHighLatency() {
        let config = ValidationConfig.thorough
        XCTAssertEqual(config.enabledVerifiers.count, 5)
        XCTAssertEqual(config.maxLatencyMs, 30_000)
    }

    func testDefaultLatencyBudget() {
        XCTAssertEqual(ValidationConfig.default.maxLatencyMs, 10_000)
    }

    func testFastLatencyBudget() {
        XCTAssertEqual(ValidationConfig.fast.maxLatencyMs, 2000)
    }
}
