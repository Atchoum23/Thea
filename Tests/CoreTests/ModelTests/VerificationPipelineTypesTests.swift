import Foundation
import XCTest

/// Standalone tests for Verification Pipeline types:
/// ConfidenceLevel, ConfidenceSource, ConfidenceDecomposition,
/// ConsensusResult logic, UserFeedback logic.
/// Mirrors types from Intelligence/Verification/*.swift.
final class VerificationPipelineTypesTests: XCTestCase {

    // MARK: - ConfidenceLevel (mirror ConfidenceSystem.swift)

    enum ConfidenceLevel: String, Sendable {
        case high       // 0.85–1.0
        case medium     // 0.60–0.85
        case low        // 0.30–0.60
        case unverified // < 0.30

        var actionRequired: Bool {
            switch self {
            case .high, .medium: false
            case .low, .unverified: true
            }
        }

        var icon: String {
            switch self {
            case .high: "checkmark.seal.fill"
            case .medium: "checkmark.circle"
            case .low: "exclamationmark.triangle"
            case .unverified: "questionmark.circle"
            }
        }

        init(from confidence: Double) {
            switch confidence {
            case 0.85...1.0: self = .high
            case 0.60..<0.85: self = .medium
            case 0.30..<0.60: self = .low
            default: self = .unverified
            }
        }
    }

    func testConfidenceLevelHighRange() {
        XCTAssertEqual(ConfidenceLevel(from: 1.0), .high)
        XCTAssertEqual(ConfidenceLevel(from: 0.95), .high)
        XCTAssertEqual(ConfidenceLevel(from: 0.85), .high)
    }

    func testConfidenceLevelMediumRange() {
        XCTAssertEqual(ConfidenceLevel(from: 0.84), .medium)
        XCTAssertEqual(ConfidenceLevel(from: 0.70), .medium)
        XCTAssertEqual(ConfidenceLevel(from: 0.60), .medium)
    }

    func testConfidenceLevelLowRange() {
        XCTAssertEqual(ConfidenceLevel(from: 0.59), .low)
        XCTAssertEqual(ConfidenceLevel(from: 0.45), .low)
        XCTAssertEqual(ConfidenceLevel(from: 0.30), .low)
    }

    func testConfidenceLevelUnverifiedRange() {
        XCTAssertEqual(ConfidenceLevel(from: 0.29), .unverified)
        XCTAssertEqual(ConfidenceLevel(from: 0.0), .unverified)
        XCTAssertEqual(ConfidenceLevel(from: -0.1), .unverified)
    }

    func testConfidenceLevelActionRequired() {
        XCTAssertFalse(ConfidenceLevel.high.actionRequired)
        XCTAssertFalse(ConfidenceLevel.medium.actionRequired)
        XCTAssertTrue(ConfidenceLevel.low.actionRequired)
        XCTAssertTrue(ConfidenceLevel.unverified.actionRequired)
    }

    func testConfidenceLevelIcons() {
        XCTAssertEqual(ConfidenceLevel.high.icon, "checkmark.seal.fill")
        XCTAssertEqual(ConfidenceLevel.medium.icon, "checkmark.circle")
        XCTAssertEqual(ConfidenceLevel.low.icon, "exclamationmark.triangle")
        XCTAssertEqual(ConfidenceLevel.unverified.icon, "questionmark.circle")
    }

    // MARK: - ConfidenceSource (mirror ConfidenceSystem.swift)

    enum SourceType: String, Sendable {
        case modelConsensus
        case webVerification
        case codeExecution
        case staticAnalysis
        case cachedKnowledge
        case userFeedback
        case patternMatch
        case semanticAnalysis
    }

    struct ConfidenceSource: Sendable, Identifiable {
        let id: UUID
        let type: SourceType
        let name: String
        let confidence: Double
        let weight: Double
        let details: String
        let verified: Bool

        var weightedConfidence: Double { confidence * weight }
    }

    func testConfidenceSourceWeightedConfidence() {
        let source = ConfidenceSource(
            id: UUID(), type: .modelConsensus, name: "GPT-4o",
            confidence: 0.9, weight: 0.4, details: "Agreed",
            verified: true
        )
        XCTAssertEqual(source.weightedConfidence, 0.36, accuracy: 0.001)
    }

    func testConfidenceSourceZeroWeight() {
        let source = ConfidenceSource(
            id: UUID(), type: .cachedKnowledge, name: "Cache",
            confidence: 0.8, weight: 0.0, details: "N/A",
            verified: false
        )
        XCTAssertEqual(source.weightedConfidence, 0.0, accuracy: 0.001)
    }

    func testConfidenceSourceFullWeight() {
        let source = ConfidenceSource(
            id: UUID(), type: .userFeedback, name: "User",
            confidence: 1.0, weight: 1.0, details: "Confirmed",
            verified: true
        )
        XCTAssertEqual(source.weightedConfidence, 1.0, accuracy: 0.001)
    }

    // MARK: - Weighted Average Calculation (mirror ConfidenceSystem.swift)

    func calculateOverallConfidence(from sources: [ConfidenceSource]) -> Double {
        let sourceWeights: [SourceType: Double] = [
            .modelConsensus: 0.30,
            .webVerification: 0.25,
            .codeExecution: 0.20,
            .staticAnalysis: 0.10,
            .cachedKnowledge: 0.05,
            .userFeedback: 0.05,
            .patternMatch: 0.03,
            .semanticAnalysis: 0.02
        ]

        var totalWeight = 0.0
        var weightedSum = 0.0

        for source in sources {
            let weight = sourceWeights[source.type] ?? 0.0
            totalWeight += weight
            weightedSum += source.confidence * weight
        }

        guard totalWeight > 0 else { return 0 }
        return weightedSum / totalWeight
    }

    func testCalculateOverallConfidenceSingleSource() {
        let sources = [
            ConfidenceSource(
                id: UUID(), type: .modelConsensus, name: "Test",
                confidence: 0.9, weight: 0.3, details: "", verified: true
            )
        ]
        let result = calculateOverallConfidence(from: sources)
        XCTAssertEqual(result, 0.9, accuracy: 0.001)
    }

    func testCalculateOverallConfidenceMultipleSources() {
        let sources = [
            ConfidenceSource(
                id: UUID(), type: .modelConsensus, name: "Model",
                confidence: 0.9, weight: 0.3, details: "", verified: true
            ),
            ConfidenceSource(
                id: UUID(), type: .webVerification, name: "Web",
                confidence: 0.7, weight: 0.25, details: "", verified: true
            ),
        ]
        let result = calculateOverallConfidence(from: sources)
        // (0.9 * 0.30 + 0.7 * 0.25) / (0.30 + 0.25) = (0.27 + 0.175) / 0.55 = 0.809
        XCTAssertEqual(result, 0.809, accuracy: 0.01)
    }

    func testCalculateOverallConfidenceEmpty() {
        let result = calculateOverallConfidence(from: [])
        XCTAssertEqual(result, 0.0)
    }

    // MARK: - Consensus Calculation (mirror MultiModelConsensus.swift)

    struct ModelResponse {
        let modelId: String
        let agrees: Bool
        let accuracy: Double
        let quality: Double
    }

    func calculateConsensus(responses: [ModelResponse]) -> Double {
        guard !responses.isEmpty else { return 0 }
        let agreementRate = Double(responses.filter(\.agrees).count) / Double(responses.count)
        let avgAccuracy = responses.map(\.accuracy).reduce(0, +) / Double(responses.count)
        let avgQuality = responses.map(\.quality).reduce(0, +) / Double(responses.count)
        return agreementRate * 0.4 + avgAccuracy * 0.3 + avgQuality * 0.3
    }

    func testConsensusAllAgree() {
        let responses = [
            ModelResponse(modelId: "m1", agrees: true, accuracy: 0.9, quality: 0.9),
            ModelResponse(modelId: "m2", agrees: true, accuracy: 0.8, quality: 0.85),
        ]
        let consensus = calculateConsensus(responses: responses)
        // agreement=1.0, avgAccuracy=0.85, avgQuality=0.875
        // 1.0*0.4 + 0.85*0.3 + 0.875*0.3 = 0.4 + 0.255 + 0.2625 = 0.9175
        XCTAssertEqual(consensus, 0.9175, accuracy: 0.01)
    }

    func testConsensusNoneAgree() {
        let responses = [
            ModelResponse(modelId: "m1", agrees: false, accuracy: 0.3, quality: 0.4),
            ModelResponse(modelId: "m2", agrees: false, accuracy: 0.2, quality: 0.3),
        ]
        let consensus = calculateConsensus(responses: responses)
        // agreement=0.0, avgAccuracy=0.25, avgQuality=0.35
        // 0.0*0.4 + 0.25*0.3 + 0.35*0.3 = 0 + 0.075 + 0.105 = 0.18
        XCTAssertEqual(consensus, 0.18, accuracy: 0.01)
    }

    func testConsensusMixed() {
        let responses = [
            ModelResponse(modelId: "m1", agrees: true, accuracy: 0.9, quality: 0.8),
            ModelResponse(modelId: "m2", agrees: false, accuracy: 0.5, quality: 0.6),
            ModelResponse(modelId: "m3", agrees: true, accuracy: 0.7, quality: 0.7),
        ]
        let consensus = calculateConsensus(responses: responses)
        // agreement=0.667, avgAccuracy=0.7, avgQuality=0.7
        // 0.667*0.4 + 0.7*0.3 + 0.7*0.3 = 0.267 + 0.21 + 0.21 = 0.687
        XCTAssertEqual(consensus, 0.687, accuracy: 0.02)
    }

    func testConsensusEmpty() {
        XCTAssertEqual(calculateConsensus(responses: []), 0.0)
    }

    // MARK: - Conflict Severity (mirror ConfidenceSystem.swift)

    enum ConflictSeverity: String {
        case minor
        case moderate
        case major
    }

    func conflictSeverity(agreementRate: Double) -> ConflictSeverity {
        if agreementRate < 0.5 { return .major }
        if agreementRate < 0.75 { return .moderate }
        return .minor
    }

    func testConflictSeverityMajor() {
        XCTAssertEqual(conflictSeverity(agreementRate: 0.0), .major)
        XCTAssertEqual(conflictSeverity(agreementRate: 0.3), .major)
        XCTAssertEqual(conflictSeverity(agreementRate: 0.49), .major)
    }

    func testConflictSeverityModerate() {
        XCTAssertEqual(conflictSeverity(agreementRate: 0.5), .moderate)
        XCTAssertEqual(conflictSeverity(agreementRate: 0.6), .moderate)
        XCTAssertEqual(conflictSeverity(agreementRate: 0.74), .moderate)
    }

    func testConflictSeverityMinor() {
        XCTAssertEqual(conflictSeverity(agreementRate: 0.75), .minor)
        XCTAssertEqual(conflictSeverity(agreementRate: 0.9), .minor)
        XCTAssertEqual(conflictSeverity(agreementRate: 1.0), .minor)
    }

    // MARK: - UserFeedback Success Rate (mirror UserFeedbackLearner.swift)

    struct FeedbackRecord: Sendable {
        let wasCorrect: Bool
        let timestamp: Date
    }

    func calculateSuccessRate(from history: [FeedbackRecord], decayFactor: Double = 0.99) -> Double {
        guard !history.isEmpty else { return 0.5 }
        let now = Date()
        var weightedSum = 0.0
        var totalWeight = 0.0
        for record in history {
            let ageInDays = now.timeIntervalSince(record.timestamp) / 86400
            let weight = pow(decayFactor, ageInDays)
            weightedSum += (record.wasCorrect ? 1.0 : 0.0) * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return 0.5 }
        return weightedSum / totalWeight
    }

    func testSuccessRateAllCorrect() {
        let now = Date()
        let records = (0..<10).map { i in
            FeedbackRecord(wasCorrect: true, timestamp: now.addingTimeInterval(-Double(i) * 3600))
        }
        let rate = calculateSuccessRate(from: records)
        XCTAssertGreaterThan(rate, 0.99)
    }

    func testSuccessRateAllIncorrect() {
        let now = Date()
        let records = (0..<10).map { i in
            FeedbackRecord(wasCorrect: false, timestamp: now.addingTimeInterval(-Double(i) * 3600))
        }
        let rate = calculateSuccessRate(from: records)
        XCTAssertLessThan(rate, 0.01)
    }

    func testSuccessRateFiftyFifty() {
        let now = Date()
        let records = (0..<10).map { i in
            FeedbackRecord(wasCorrect: i % 2 == 0, timestamp: now)
        }
        let rate = calculateSuccessRate(from: records)
        XCTAssertEqual(rate, 0.5, accuracy: 0.01)
    }

    func testSuccessRateEmptyDefault() {
        XCTAssertEqual(calculateSuccessRate(from: []), 0.5)
    }

    func testSuccessRateDecayWeightsRecentMore() {
        let now = Date()
        // Recent correct, old incorrect — should favor recent
        let recent = FeedbackRecord(wasCorrect: true, timestamp: now)
        let old = FeedbackRecord(wasCorrect: false, timestamp: now.addingTimeInterval(-365 * 86400))
        let rate = calculateSuccessRate(from: [recent, old])
        XCTAssertGreaterThan(rate, 0.5, "Recent correct should outweigh old incorrect")
    }

    // MARK: - Feedback Trend Detection (mirror UserFeedbackLearner.swift)

    enum FeedbackTrend: String {
        case improving
        case stable
        case declining
    }

    func detectTrend(recentAccuracy: Double, overallAccuracy: Double) -> FeedbackTrend {
        if recentAccuracy > overallAccuracy + 0.05 { return .improving }
        if recentAccuracy < overallAccuracy - 0.05 { return .declining }
        return .stable
    }

    func testTrendImproving() {
        XCTAssertEqual(detectTrend(recentAccuracy: 0.9, overallAccuracy: 0.7), .improving)
    }

    func testTrendDeclining() {
        XCTAssertEqual(detectTrend(recentAccuracy: 0.5, overallAccuracy: 0.8), .declining)
    }

    func testTrendStable() {
        XCTAssertEqual(detectTrend(recentAccuracy: 0.75, overallAccuracy: 0.73), .stable)
        XCTAssertEqual(detectTrend(recentAccuracy: 0.73, overallAccuracy: 0.75), .stable)
    }

    func testTrendBoundary() {
        // Exactly at threshold should be stable
        XCTAssertEqual(detectTrend(recentAccuracy: 0.75, overallAccuracy: 0.70), .stable)
        XCTAssertEqual(detectTrend(recentAccuracy: 0.70, overallAccuracy: 0.75), .stable)
    }

    // MARK: - Pattern Key Generation (mirror UserFeedbackLearner.swift)

    func generatePatternKey(taskType: String, response: String) -> String {
        let length: String
        if response.count < 200 { length = "short" }
        else if response.count < 1000 { length = "medium" }
        else { length = "long" }
        let hasCode = response.contains("```")
        return "\(taskType)_\(length)_\(hasCode)"
    }

    func testPatternKeyShortNoCode() {
        let key = generatePatternKey(taskType: "factual", response: "Hello world")
        XCTAssertEqual(key, "factual_short_false")
    }

    func testPatternKeyLongWithCode() {
        let code = String(repeating: "x", count: 1000) + "```swift\nlet x = 1\n```"
        let key = generatePatternKey(taskType: "codeGeneration", response: code)
        XCTAssertEqual(key, "codeGeneration_long_true")
    }

    func testPatternKeyMediumLength() {
        let text = String(repeating: "a", count: 500)
        let key = generatePatternKey(taskType: "analysis", response: text)
        XCTAssertEqual(key, "analysis_medium_false")
    }

    // MARK: - ValidationContext Presets (mirror ConfidenceSystem.swift)

    enum CodeLanguage: String, Sendable {
        case swift
        case javascript
        case python
        case unknown
    }

    struct ValidationContext {
        let allowMultiModel: Bool
        let allowWebSearch: Bool
        let allowCodeExecution: Bool
        let language: CodeLanguage
        let maxLatency: TimeInterval

        static let `default` = ValidationContext(
            allowMultiModel: true, allowWebSearch: true,
            allowCodeExecution: true, language: .unknown,
            maxLatency: 30.0
        )

        static let fast = ValidationContext(
            allowMultiModel: false, allowWebSearch: false,
            allowCodeExecution: false, language: .unknown,
            maxLatency: 5.0
        )
    }

    func testValidationContextDefault() {
        let ctx = ValidationContext.default
        XCTAssertTrue(ctx.allowMultiModel)
        XCTAssertTrue(ctx.allowWebSearch)
        XCTAssertTrue(ctx.allowCodeExecution)
        XCTAssertEqual(ctx.maxLatency, 30.0)
    }

    func testValidationContextFast() {
        let ctx = ValidationContext.fast
        XCTAssertFalse(ctx.allowMultiModel)
        XCTAssertFalse(ctx.allowWebSearch)
        XCTAssertFalse(ctx.allowCodeExecution)
        XCTAssertEqual(ctx.maxLatency, 5.0)
    }
}
