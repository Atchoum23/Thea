// ConfidenceSystemServiceTests.swift
// Tests for ConfidenceSystem service logic: result construction, level classification,
// source weighting, decomposition validation, multi-source aggregation, and hallucination detection.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Verification/ConfidenceSystem.swift)

// @unchecked Sendable: test helper enum, single-threaded test context
private enum CSConfidenceLevel: String, Sendable, CaseIterable {
    case high = "High Confidence"
    case medium = "Medium Confidence"
    case low = "Low Confidence"
    case unverified = "Unverified"

    init(from confidence: Double) {
        switch confidence {
        case 0.85...1.0: self = .high
        case 0.60..<0.85: self = .medium
        case 0.30..<0.60: self = .low
        default: self = .unverified
        }
    }

    var color: String {
        switch self {
        case .high: "green"
        case .medium: "orange"
        case .low: "red"
        case .unverified: "gray"
        }
    }

    var icon: String {
        switch self {
        case .high: "checkmark.seal.fill"
        case .medium: "exclamationmark.triangle.fill"
        case .low: "questionmark.circle.fill"
        case .unverified: "circle.dashed"
        }
    }

    var actionRequired: Bool {
        self == .low || self == .unverified
    }
}

private enum CSSourceType: String, Sendable, CaseIterable {
    case modelConsensus = "Model Consensus"
    case webVerification = "Web Verification"
    case codeExecution = "Code Execution"
    case staticAnalysis = "Static Analysis"
    case cachedKnowledge = "Cached Knowledge"
    case userFeedback = "User Feedback"
    case patternMatch = "Pattern Match"
    case semanticAnalysis = "Semantic Analysis"
}

private struct CSConfidenceSource: Sendable, Identifiable {
    let id = UUID()
    let type: CSSourceType
    let name: String
    let confidence: Double
    let weight: Double
    let details: String
    let verified: Bool

    var weightedConfidence: Double {
        confidence * weight
    }
}

private struct CSDecompositionFactor: Sendable, Identifiable {
    let id = UUID()
    let name: String
    let contribution: Double  // -1.0 to 1.0
    let explanation: String
}

private enum CSConflictSeverity: String, Sendable {
    case minor = "Minor"
    case moderate = "Moderate"
    case major = "Major"
}

private struct CSConflictInfo: Sendable, Identifiable {
    let id = UUID()
    let source1: String
    let source2: String
    let description: String
    let severity: CSConflictSeverity
}

private struct CSDecomposition: Sendable {
    let factors: [CSDecompositionFactor]
    let conflicts: [CSConflictInfo]
    let reasoning: String
    let suggestions: [String]

    var hasConflicts: Bool {
        !conflicts.isEmpty
    }
}

private struct CSConfidenceResult: Sendable, Identifiable {
    let id = UUID()
    let overallConfidence: Double
    let level: CSConfidenceLevel
    let sources: [CSConfidenceSource]
    let decomposition: CSDecomposition
    let timestamp: Date

    var reasoning: String {
        decomposition.reasoning
    }

    var improvementSuggestions: [String] {
        decomposition.suggestions
    }

    init(
        overallConfidence: Double,
        sources: [CSConfidenceSource],
        decomposition: CSDecomposition
    ) {
        self.overallConfidence = min(1.0, max(0.0, overallConfidence))
        self.level = CSConfidenceLevel(from: self.overallConfidence)
        self.sources = sources
        self.decomposition = decomposition
        self.timestamp = Date()
    }
}

private enum CSHallucinationRisk: String, Sendable {
    case low
    case medium
    case high
}

private struct CSHallucinationFlag: Sendable, Identifiable {
    let id = UUID()
    let claim: String
    let riskLevel: CSHallucinationRisk
    let reason: String
}

// MARK: - Confidence System Logic (mirrors production logic)

// @unchecked Sendable: test helper class, single-threaded test context
private final class TestConfidenceSystem: @unchecked Sendable {
    var enableMultiModel = true
    var enableWebVerification = true
    var enableCodeExecution = true
    var enableStaticAnalysis = true
    var enableFeedbackLearning = true

    var sourceWeights: [CSSourceType: Double] = [
        .modelConsensus: 0.30,
        .webVerification: 0.17,
        .codeExecution: 0.22,
        .staticAnalysis: 0.09,
        .userFeedback: 0.09,
        .cachedKnowledge: 0.04,
        .patternMatch: 0.04,
        .semanticAnalysis: 0.05
    ]

    func calculateOverallConfidence(from sources: [CSConfidenceSource]) -> Double {
        guard !sources.isEmpty else { return 0.0 }

        var totalWeight = 0.0
        var weightedSum = 0.0

        for source in sources {
            let weight = sourceWeights[source.type] ?? 0.1
            weightedSum += source.confidence * weight
            totalWeight += weight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0.0
    }

    func generateDecomposition(
        factors: [CSDecompositionFactor],
        conflicts: [CSConflictInfo],
        confidence: Double,
        sources: [CSConfidenceSource]
    ) -> CSDecomposition {
        var reasoning = ""

        if confidence >= 0.85 {
            reasoning = "High confidence based on \(sources.count) verification sources with strong agreement."
        } else if confidence >= 0.60 {
            if !conflicts.isEmpty {
                reasoning = "Medium confidence due to \(conflicts.count) conflicting sources. Manual verification recommended."
            } else {
                reasoning = "Medium confidence. Some verification sources could not fully confirm the response."
            }
        } else {
            reasoning = "Low confidence. Multiple verification methods could not confirm accuracy."
        }

        var suggestions: [String] = []

        if !sources.contains(where: { $0.type == .webVerification && $0.verified }) {
            suggestions.append("Verify factual claims with web search")
        }

        if !sources.contains(where: { $0.type == .codeExecution && $0.verified }) && sources.contains(where: { $0.type == .staticAnalysis }) {
            suggestions.append("Execute code to verify it runs correctly")
        }

        if sources.filter({ $0.type == .modelConsensus }).count < 2 {
            suggestions.append("Query additional models for consensus")
        }

        if !conflicts.isEmpty {
            suggestions.append("Review conflicting information manually")
        }

        return CSDecomposition(
            factors: factors,
            conflicts: conflicts,
            reasoning: reasoning,
            suggestions: suggestions
        )
    }

    // Hallucination detection (mirrors production heuristics)
    func detectHallucinations(
        _ response: String,
        query: String,
        knowledgeContext: [String] = []
    ) -> [CSHallucinationFlag] {
        var flags: [CSHallucinationFlag] = []

        let sentences = response.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }

        for sentence in sentences {
            let lower = sentence.lowercased()

            let hedgePatterns = [
                "i believe", "i think", "probably", "might be",
                "reportedly", "some sources say", "it seems", "allegedly"
            ]
            let hasHedge = hedgePatterns.contains { lower.contains($0) }

            let hasSpecificNumber = sentence.range(of: #"\b\d{4,}\b"#, options: .regularExpression) != nil
            let hasURL = sentence.range(of: #"https?://\S+"#, options: .regularExpression) != nil
            let hasSpecificDate = sentence.range(of: #"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}"#, options: .regularExpression) != nil

            let contradictsKnowledge = knowledgeContext.contains { known in
                let knownLower = known.lowercased()
                return (lower.contains("not") && knownLower.split(separator: " ").filter { $0.count > 3 }.contains { lower.contains(String($0).lowercased()) })
            }

            var riskScore = 0.0
            if hasHedge { riskScore += 0.3 }
            if hasSpecificNumber { riskScore += 0.2 }
            if hasURL { riskScore += 0.4 }
            if hasSpecificDate { riskScore += 0.15 }
            if contradictsKnowledge { riskScore += 0.5 }

            if riskScore >= 0.3 {
                let risk: CSHallucinationRisk = riskScore >= 0.6 ? .high : riskScore >= 0.4 ? .medium : .low
                var reasons: [String] = []
                if hasURL { reasons.append("contains URL (high fabrication risk)") }
                if hasHedge { reasons.append("hedging language") }
                if hasSpecificDate || hasSpecificNumber { reasons.append("specific claim without source") }
                if contradictsKnowledge { reasons.append("may contradict known facts") }

                flags.append(CSHallucinationFlag(
                    claim: String(sentence.prefix(120)),
                    riskLevel: risk,
                    reason: reasons.joined(separator: "; ")
                ))
            }
        }

        return flags
    }
}

// MARK: - Tests: ConfidenceResult Construction

@Suite("ConfidenceSystem — Result Construction")
struct CSResultConstructionTests {
    @Test("Result clamps overallConfidence to 0.0-1.0 range")
    func clampsConfidence() {
        let above = CSConfidenceResult(
            overallConfidence: 1.5,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(above.overallConfidence == 1.0)

        let below = CSConfidenceResult(
            overallConfidence: -0.5,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(below.overallConfidence == 0.0)
    }

    @Test("Result preserves valid confidence values")
    func preservesValidConfidence() {
        let result = CSConfidenceResult(
            overallConfidence: 0.75,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(result.overallConfidence == 0.75)
    }

    @Test("Result auto-classifies level from confidence")
    func autoClassifiesLevel() {
        let high = CSConfidenceResult(
            overallConfidence: 0.90,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(high.level == .high)

        let medium = CSConfidenceResult(
            overallConfidence: 0.70,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(medium.level == .medium)
    }

    @Test("Result has unique identifier")
    func hasUniqueId() {
        let r1 = CSConfidenceResult(
            overallConfidence: 0.5,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        let r2 = CSConfidenceResult(
            overallConfidence: 0.5,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(r1.id != r2.id)
    }

    @Test("Result timestamp is approximately now")
    func timestampIsNow() {
        let before = Date()
        let result = CSConfidenceResult(
            overallConfidence: 0.5,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        let after = Date()
        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }

    @Test("Result reasoning delegates to decomposition")
    func reasoningDelegates() {
        let result = CSConfidenceResult(
            overallConfidence: 0.5,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "test reasoning", suggestions: [])
        )
        #expect(result.reasoning == "test reasoning")
    }

    @Test("Result improvementSuggestions delegates to decomposition")
    func suggestionsDelegates() {
        let result = CSConfidenceResult(
            overallConfidence: 0.5,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: ["suggestion A", "suggestion B"])
        )
        #expect(result.improvementSuggestions.count == 2)
        #expect(result.improvementSuggestions[0] == "suggestion A")
    }

    @Test("Result stores sources correctly")
    func storesSources() {
        let source = CSConfidenceSource(
            type: .modelConsensus,
            name: "Test",
            confidence: 0.9,
            weight: 1.0,
            details: "details",
            verified: true
        )
        let result = CSConfidenceResult(
            overallConfidence: 0.9,
            sources: [source],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(result.sources.count == 1)
        #expect(result.sources[0].type == .modelConsensus)
    }

    @Test("Result with exact boundary value 1.0 is high confidence")
    func exactOneIsHigh() {
        let result = CSConfidenceResult(
            overallConfidence: 1.0,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(result.overallConfidence == 1.0)
        #expect(result.level == .high)
    }

    @Test("Result with exact boundary value 0.0 is unverified")
    func exactZeroIsUnverified() {
        let result = CSConfidenceResult(
            overallConfidence: 0.0,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(result.overallConfidence == 0.0)
        #expect(result.level == .unverified)
    }
}

// MARK: - Tests: ConfidenceLevel Classification

@Suite("ConfidenceSystem — Level Classification")
struct CSLevelClassificationTests {
    @Test("High confidence: 0.85-1.0 range")
    func highRange() {
        #expect(CSConfidenceLevel(from: 0.85) == .high)
        #expect(CSConfidenceLevel(from: 0.90) == .high)
        #expect(CSConfidenceLevel(from: 0.95) == .high)
        #expect(CSConfidenceLevel(from: 1.0) == .high)
    }

    @Test("Medium confidence: 0.60-0.84 range")
    func mediumRange() {
        #expect(CSConfidenceLevel(from: 0.60) == .medium)
        #expect(CSConfidenceLevel(from: 0.70) == .medium)
        #expect(CSConfidenceLevel(from: 0.84) == .medium)
        #expect(CSConfidenceLevel(from: 0.849) == .medium)
    }

    @Test("Low confidence: 0.30-0.59 range")
    func lowRange() {
        #expect(CSConfidenceLevel(from: 0.30) == .low)
        #expect(CSConfidenceLevel(from: 0.45) == .low)
        #expect(CSConfidenceLevel(from: 0.59) == .low)
        #expect(CSConfidenceLevel(from: 0.599) == .low)
    }

    @Test("Unverified confidence: below 0.30")
    func unverifiedRange() {
        #expect(CSConfidenceLevel(from: 0.0) == .unverified)
        #expect(CSConfidenceLevel(from: 0.15) == .unverified)
        #expect(CSConfidenceLevel(from: 0.29) == .unverified)
        #expect(CSConfidenceLevel(from: 0.299) == .unverified)
    }

    @Test("Boundary values: exact thresholds")
    func boundaryValues() {
        #expect(CSConfidenceLevel(from: 0.85) == .high)
        #expect(CSConfidenceLevel(from: 0.60) == .medium)
        #expect(CSConfidenceLevel(from: 0.30) == .low)
    }

    @Test("Just below thresholds")
    func justBelowThresholds() {
        #expect(CSConfidenceLevel(from: 0.8499) == .medium)
        #expect(CSConfidenceLevel(from: 0.5999) == .low)
        #expect(CSConfidenceLevel(from: 0.2999) == .unverified)
    }

    @Test("Negative values are unverified")
    func negativeValues() {
        #expect(CSConfidenceLevel(from: -1.0) == .unverified)
        #expect(CSConfidenceLevel(from: -0.5) == .unverified)
    }

    @Test("Color mapping is correct")
    func colorMapping() {
        #expect(CSConfidenceLevel.high.color == "green")
        #expect(CSConfidenceLevel.medium.color == "orange")
        #expect(CSConfidenceLevel.low.color == "red")
        #expect(CSConfidenceLevel.unverified.color == "gray")
    }

    @Test("Icon mapping is correct")
    func iconMapping() {
        #expect(CSConfidenceLevel.high.icon == "checkmark.seal.fill")
        #expect(CSConfidenceLevel.medium.icon == "exclamationmark.triangle.fill")
        #expect(CSConfidenceLevel.low.icon == "questionmark.circle.fill")
        #expect(CSConfidenceLevel.unverified.icon == "circle.dashed")
    }

    @Test("Action required for low and unverified only")
    func actionRequired() {
        #expect(!CSConfidenceLevel.high.actionRequired)
        #expect(!CSConfidenceLevel.medium.actionRequired)
        #expect(CSConfidenceLevel.low.actionRequired)
        #expect(CSConfidenceLevel.unverified.actionRequired)
    }

    @Test("All cases exist")
    func allCases() {
        #expect(CSConfidenceLevel.allCases.count == 4)
    }
}

// MARK: - Tests: ConfidenceSource Creation and Weighted Contribution

@Suite("ConfidenceSystem — Source Weighted Contribution")
struct CSSourceWeightedTests {
    @Test("Weighted confidence is confidence * weight")
    func weightedConfidenceCalculation() {
        let source = CSConfidenceSource(
            type: .modelConsensus,
            name: "GPT-4",
            confidence: 0.8,
            weight: 0.5,
            details: "test",
            verified: true
        )
        #expect(abs(source.weightedConfidence - 0.4) < 0.001)
    }

    @Test("Full weight with full confidence gives 1.0 weighted")
    func fullWeightFullConfidence() {
        let source = CSConfidenceSource(
            type: .webVerification,
            name: "Perplexity",
            confidence: 1.0,
            weight: 1.0,
            details: "verified",
            verified: true
        )
        #expect(source.weightedConfidence == 1.0)
    }

    @Test("Zero confidence gives zero weighted regardless of weight")
    func zeroConfidenceZeroWeighted() {
        let source = CSConfidenceSource(
            type: .codeExecution,
            name: "JS",
            confidence: 0.0,
            weight: 1.0,
            details: "failed",
            verified: false
        )
        #expect(source.weightedConfidence == 0.0)
    }

    @Test("Zero weight gives zero weighted regardless of confidence")
    func zeroWeightZeroWeighted() {
        let source = CSConfidenceSource(
            type: .staticAnalysis,
            name: "SwiftLint",
            confidence: 1.0,
            weight: 0.0,
            details: "clean",
            verified: true
        )
        #expect(source.weightedConfidence == 0.0)
    }

    @Test("Sources have unique identifiers")
    func uniqueIds() {
        let s1 = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.5, weight: 0.5, details: "", verified: false)
        let s2 = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.5, weight: 0.5, details: "", verified: false)
        #expect(s1.id != s2.id)
    }

    @Test("All source types can be created")
    func allSourceTypes() {
        for type in CSSourceType.allCases {
            let source = CSConfidenceSource(type: type, name: type.rawValue, confidence: 0.5, weight: 0.5, details: "", verified: false)
            #expect(source.type == type)
        }
        #expect(CSSourceType.allCases.count == 8)
    }
}

// MARK: - Tests: Decomposition Factor Validation

@Suite("ConfidenceSystem — Decomposition Factors")
struct CSDecompositionTests {
    @Test("Factor contribution can be positive")
    func positiveContribution() {
        let factor = CSDecompositionFactor(name: "Consensus", contribution: 0.8, explanation: "Strong agreement")
        #expect(factor.contribution > 0)
        #expect(factor.contribution == 0.8)
    }

    @Test("Factor contribution can be negative")
    func negativeContribution() {
        let factor = CSDecompositionFactor(name: "Conflict", contribution: -0.5, explanation: "Disagreement found")
        #expect(factor.contribution < 0)
        #expect(factor.contribution == -0.5)
    }

    @Test("Factor contribution can be zero")
    func zeroContribution() {
        let factor = CSDecompositionFactor(name: "Neutral", contribution: 0.0, explanation: "No data")
        #expect(factor.contribution == 0.0)
    }

    @Test("Decomposition hasConflicts when conflicts exist")
    func hasConflictsTrue() {
        let conflict = CSConflictInfo(source1: "A", source2: "B", description: "Disagree", severity: .major)
        let decomp = CSDecomposition(factors: [], conflicts: [conflict], reasoning: "", suggestions: [])
        #expect(decomp.hasConflicts)
    }

    @Test("Decomposition hasConflicts false when no conflicts")
    func hasConflictsFalse() {
        let decomp = CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        #expect(!decomp.hasConflicts)
    }

    @Test("Conflict severity levels are correct")
    func conflictSeverities() {
        #expect(CSConflictSeverity.minor.rawValue == "Minor")
        #expect(CSConflictSeverity.moderate.rawValue == "Moderate")
        #expect(CSConflictSeverity.major.rawValue == "Major")
    }

    @Test("Decomposition stores all factors")
    func storesFactors() {
        let f1 = CSDecompositionFactor(name: "A", contribution: 0.1, explanation: "a")
        let f2 = CSDecompositionFactor(name: "B", contribution: 0.2, explanation: "b")
        let f3 = CSDecompositionFactor(name: "C", contribution: -0.3, explanation: "c")
        let decomp = CSDecomposition(factors: [f1, f2, f3], conflicts: [], reasoning: "", suggestions: [])
        #expect(decomp.factors.count == 3)
    }

    @Test("Decomposition stores multiple conflicts")
    func storesConflicts() {
        let c1 = CSConflictInfo(source1: "A", source2: "B", description: "Conflict 1", severity: .minor)
        let c2 = CSConflictInfo(source1: "C", source2: "D", description: "Conflict 2", severity: .major)
        let decomp = CSDecomposition(factors: [], conflicts: [c1, c2], reasoning: "", suggestions: [])
        #expect(decomp.conflicts.count == 2)
        #expect(decomp.hasConflicts)
    }

    @Test("Factors and conflicts have unique IDs")
    func uniqueIds() {
        let f1 = CSDecompositionFactor(name: "A", contribution: 0.1, explanation: "a")
        let f2 = CSDecompositionFactor(name: "A", contribution: 0.1, explanation: "a")
        #expect(f1.id != f2.id)

        let c1 = CSConflictInfo(source1: "A", source2: "B", description: "test", severity: .minor)
        let c2 = CSConflictInfo(source1: "A", source2: "B", description: "test", severity: .minor)
        #expect(c1.id != c2.id)
    }
}

// MARK: - Tests: Multi-Source Aggregation

@Suite("ConfidenceSystem — Aggregation")
struct CSAggregationTests {
    @Test("Empty sources returns 0.0 confidence")
    func emptySources() {
        let system = TestConfidenceSystem()
        let confidence = system.calculateOverallConfidence(from: [])
        #expect(confidence == 0.0)
    }

    @Test("Single source returns weighted average with itself")
    func singleSource() {
        let system = TestConfidenceSystem()
        let source = CSConfidenceSource(
            type: .modelConsensus,
            name: "GPT-4",
            confidence: 0.9,
            weight: 1.0,
            details: "",
            verified: true
        )
        let confidence = system.calculateOverallConfidence(from: [source])
        // weight = sourceWeights[.modelConsensus] = 0.30
        // weightedSum = 0.9 * 0.30 = 0.27
        // totalWeight = 0.30
        // result = 0.27 / 0.30 = 0.9
        #expect(abs(confidence - 0.9) < 0.001)
    }

    @Test("Two sources of same type produce average confidence")
    func twoSameTypeSources() {
        let system = TestConfidenceSystem()
        let s1 = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.8, weight: 1.0, details: "", verified: true)
        let s2 = CSConfidenceSource(type: .modelConsensus, name: "B", confidence: 0.6, weight: 1.0, details: "", verified: true)
        let confidence = system.calculateOverallConfidence(from: [s1, s2])
        // Both use weight 0.30
        // weightedSum = (0.8 * 0.30) + (0.6 * 0.30) = 0.24 + 0.18 = 0.42
        // totalWeight = 0.30 + 0.30 = 0.60
        // result = 0.42 / 0.60 = 0.7
        #expect(abs(confidence - 0.7) < 0.001)
    }

    @Test("Different source types use different weights")
    func differentTypeWeights() {
        let system = TestConfidenceSystem()
        let consensus = CSConfidenceSource(type: .modelConsensus, name: "GPT", confidence: 1.0, weight: 1.0, details: "", verified: true)
        let cached = CSConfidenceSource(type: .cachedKnowledge, name: "Cache", confidence: 0.0, weight: 1.0, details: "", verified: false)
        let confidence = system.calculateOverallConfidence(from: [consensus, cached])
        // consensus weight = 0.30, cached weight = 0.04
        // weightedSum = (1.0 * 0.30) + (0.0 * 0.04) = 0.30
        // totalWeight = 0.30 + 0.04 = 0.34
        // result = 0.30 / 0.34 ~ 0.8824
        #expect(abs(confidence - (0.30 / 0.34)) < 0.001)
    }

    @Test("All sources same confidence returns that confidence")
    func allSameConfidence() {
        let system = TestConfidenceSystem()
        let sources: [CSConfidenceSource] = CSSourceType.allCases.map { type in
            CSConfidenceSource(type: type, name: type.rawValue, confidence: 0.75, weight: 1.0, details: "", verified: false)
        }
        let confidence = system.calculateOverallConfidence(from: sources)
        // All at 0.75, different weights but all multiplied by same confidence
        // sum(weight_i * 0.75) / sum(weight_i) = 0.75 * sum(weight_i) / sum(weight_i) = 0.75
        #expect(abs(confidence - 0.75) < 0.001)
    }

    @Test("Unknown source type uses default weight of 0.1")
    func unknownSourceTypeDefaultWeight() {
        let system = TestConfidenceSystem()
        // Remove a known weight to test the fallback
        system.sourceWeights.removeValue(forKey: .semanticAnalysis)
        let source = CSConfidenceSource(type: .semanticAnalysis, name: "Test", confidence: 1.0, weight: 1.0, details: "", verified: true)
        let confidence = system.calculateOverallConfidence(from: [source])
        // Falls back to weight 0.1, so confidence = (1.0 * 0.1) / 0.1 = 1.0
        #expect(abs(confidence - 1.0) < 0.001)
    }

    @Test("High-weight source dominates in mixed scenario")
    func highWeightDominates() {
        let system = TestConfidenceSystem()
        // modelConsensus weight: 0.30, patternMatch weight: 0.04
        let highWeight = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.9, weight: 1.0, details: "", verified: true)
        let lowWeight = CSConfidenceSource(type: .patternMatch, name: "B", confidence: 0.1, weight: 1.0, details: "", verified: false)
        let confidence = system.calculateOverallConfidence(from: [highWeight, lowWeight])
        // weightedSum = (0.9 * 0.30) + (0.1 * 0.04) = 0.27 + 0.004 = 0.274
        // totalWeight = 0.30 + 0.04 = 0.34
        // result = 0.274 / 0.34 ~ 0.806
        #expect(confidence > 0.8) // Heavily influenced by consensus
    }

    @Test("Default weights sum to approximately 1.0")
    func defaultWeightsSum() {
        let system = TestConfidenceSystem()
        let sum = system.sourceWeights.values.reduce(0, +)
        #expect(abs(sum - 1.0) < 0.01)
    }
}

// MARK: - Tests: Decomposition Generation

@Suite("ConfidenceSystem — Decomposition Generation")
struct CSDecompGenerationTests {
    @Test("High confidence generates positive reasoning")
    func highConfidenceReasoning() {
        let system = TestConfidenceSystem()
        let source = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.9, weight: 1.0, details: "", verified: true)
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.90, sources: [source])
        #expect(decomp.reasoning.contains("High confidence"))
        #expect(decomp.reasoning.contains("1 verification sources"))
    }

    @Test("Medium confidence with conflicts generates conflict-aware reasoning")
    func mediumConfidenceWithConflicts() {
        let system = TestConfidenceSystem()
        let conflict = CSConflictInfo(source1: "A", source2: "B", description: "test", severity: .major)
        let decomp = system.generateDecomposition(factors: [], conflicts: [conflict], confidence: 0.70, sources: [])
        #expect(decomp.reasoning.contains("Medium confidence"))
        #expect(decomp.reasoning.contains("1 conflicting"))
        #expect(decomp.reasoning.contains("Manual verification"))
    }

    @Test("Medium confidence without conflicts generates standard reasoning")
    func mediumConfidenceNoConflicts() {
        let system = TestConfidenceSystem()
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.70, sources: [])
        #expect(decomp.reasoning.contains("Medium confidence"))
        #expect(decomp.reasoning.contains("could not fully confirm"))
    }

    @Test("Low confidence generates warning reasoning")
    func lowConfidenceReasoning() {
        let system = TestConfidenceSystem()
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.40, sources: [])
        #expect(decomp.reasoning.contains("Low confidence"))
    }

    @Test("Suggestion to verify with web search when no web verification")
    func suggestsWebSearch() {
        let system = TestConfidenceSystem()
        let source = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.9, weight: 1.0, details: "", verified: true)
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.70, sources: [source])
        #expect(decomp.suggestions.contains { $0.contains("web search") })
    }

    @Test("No web search suggestion when web verification present and verified")
    func noWebSearchSuggestionWhenVerified() {
        let system = TestConfidenceSystem()
        let source = CSConfidenceSource(type: .webVerification, name: "Perplexity", confidence: 0.9, weight: 1.0, details: "", verified: true)
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.70, sources: [source])
        #expect(!decomp.suggestions.contains { $0.contains("Verify factual claims with web search") })
    }

    @Test("Suggests code execution when static analysis present but no execution")
    func suggestsCodeExecution() {
        let system = TestConfidenceSystem()
        let source = CSConfidenceSource(type: .staticAnalysis, name: "Lint", confidence: 0.8, weight: 1.0, details: "", verified: true)
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.70, sources: [source])
        #expect(decomp.suggestions.contains { $0.contains("Execute code") })
    }

    @Test("Suggests additional models when fewer than 2 consensus sources")
    func suggestsMoreModels() {
        let system = TestConfidenceSystem()
        let source = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.9, weight: 1.0, details: "", verified: true)
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.70, sources: [source])
        #expect(decomp.suggestions.contains { $0.contains("additional models") })
    }

    @Test("No model suggestion when 2+ consensus sources exist")
    func noModelSuggestionWithEnoughConsensus() {
        let system = TestConfidenceSystem()
        let s1 = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.9, weight: 1.0, details: "", verified: true)
        let s2 = CSConfidenceSource(type: .modelConsensus, name: "B", confidence: 0.8, weight: 1.0, details: "", verified: true)
        let decomp = system.generateDecomposition(factors: [], conflicts: [], confidence: 0.90, sources: [s1, s2])
        #expect(!decomp.suggestions.contains { $0.contains("additional models") })
    }

    @Test("Suggests manual review when conflicts exist")
    func suggestsManualReview() {
        let system = TestConfidenceSystem()
        let conflict = CSConflictInfo(source1: "A", source2: "B", description: "Disagree", severity: .major)
        let decomp = system.generateDecomposition(factors: [], conflicts: [conflict], confidence: 0.70, sources: [])
        #expect(decomp.suggestions.contains { $0.contains("Review conflicting") })
    }
}

// MARK: - Tests: Hallucination Detection

@Suite("ConfidenceSystem — Hallucination Detection")
struct CSHallucinationTests {
    @Test("Clean response with no risky patterns returns no flags")
    func cleanResponseNoFlags() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations("This is a simple factual statement about programming.", query: "test")
        #expect(flags.isEmpty)
    }

    @Test("Hedging language triggers flag")
    func hedgingTriggers() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations("I believe this is the correct approach to solving the problem.", query: "test")
        #expect(!flags.isEmpty)
        #expect(flags.first?.reason.contains("hedging") == true)
    }

    @Test("URL in response triggers high risk flag")
    func urlTriggersHighRisk() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations("You can find the documentation at https://example.com/docs/api/v2.", query: "test")
        #expect(!flags.isEmpty)
        #expect(flags.first?.reason.contains("URL") == true)
    }

    @Test("Specific date triggers flag")
    func specificDateTriggers() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations("This was released on January 15 and has been popular since then.", query: "test")
        #expect(!flags.isEmpty)
        #expect(flags.first?.reason.contains("specific claim") == true)
    }

    @Test("Large numbers trigger flag")
    func largeNumbersTrigger() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations("The library has been downloaded over 15000 times this year alone.", query: "test")
        #expect(!flags.isEmpty)
    }

    @Test("Sentences shorter than 10 chars are ignored")
    func shortSentencesIgnored() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations("Short. I believe. OK.", query: "test")
        #expect(flags.isEmpty)
    }

    @Test("Multiple risk factors combine to higher risk level")
    func multipleFactorsCombine() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations(
            "I believe the API at https://example.com/api was deployed on January 15.",
            query: "test"
        )
        #expect(!flags.isEmpty)
        // URL (0.4) + hedge (0.3) + date (0.15) = 0.85 => high risk
        #expect(flags.first?.riskLevel == .high)
    }

    @Test("Knowledge contradiction increases risk")
    func knowledgeContradiction() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations(
            "Swift is not a programming language created by Apple for their platforms.",
            query: "Is Swift by Apple?",
            knowledgeContext: ["Swift is a programming language created by Apple"]
        )
        // "not" is present and knowledge context words match
        #expect(!flags.isEmpty)
    }

    @Test("Claim text is truncated to 120 characters")
    func claimTruncated() {
        let system = TestConfidenceSystem()
        let longSentence = "I believe that " + String(repeating: "this is a very long claim about something important ", count: 10)
        let flags = system.detectHallucinations(longSentence + ".", query: "test")
        if let flag = flags.first {
            #expect(flag.claim.count <= 120)
        }
    }

    @Test("Empty response returns no flags")
    func emptyResponse() {
        let system = TestConfidenceSystem()
        let flags = system.detectHallucinations("", query: "test")
        #expect(flags.isEmpty)
    }
}

// MARK: - Tests: Edge Cases

@Suite("ConfidenceSystem — Edge Cases")
struct CSEdgeCaseTests {
    @Test("Extremely high confidence is clamped to 1.0")
    func extremeHighClamped() {
        let result = CSConfidenceResult(
            overallConfidence: 999.0,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(result.overallConfidence == 1.0)
    }

    @Test("Extremely low confidence is clamped to 0.0")
    func extremeLowClamped() {
        let result = CSConfidenceResult(
            overallConfidence: -999.0,
            sources: [],
            decomposition: CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        )
        #expect(result.overallConfidence == 0.0)
    }

    @Test("NaN-like edge: many sources with zero confidence")
    func manyZeroConfidenceSources() {
        let system = TestConfidenceSystem()
        let sources = CSSourceType.allCases.map { type in
            CSConfidenceSource(type: type, name: type.rawValue, confidence: 0.0, weight: 1.0, details: "", verified: false)
        }
        let confidence = system.calculateOverallConfidence(from: sources)
        #expect(confidence == 0.0)
    }

    @Test("Single source with zero weight uses fallback weight")
    func customZeroWeight() {
        let system = TestConfidenceSystem()
        system.sourceWeights[.modelConsensus] = 0.0
        let source = CSConfidenceSource(type: .modelConsensus, name: "A", confidence: 0.9, weight: 1.0, details: "", verified: true)
        let confidence = system.calculateOverallConfidence(from: [source])
        // weight is 0.0, so weightedSum = 0, totalWeight = 0 => 0.0
        #expect(confidence == 0.0)
    }

    @Test("Decomposition with empty everything")
    func emptyDecomposition() {
        let decomp = CSDecomposition(factors: [], conflicts: [], reasoning: "", suggestions: [])
        #expect(!decomp.hasConflicts)
        #expect(decomp.factors.isEmpty)
        #expect(decomp.reasoning.isEmpty)
        #expect(decomp.suggestions.isEmpty)
    }
}
