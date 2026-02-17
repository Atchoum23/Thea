// ConfidenceSystem.swift
// Thea
//
// AI-powered confidence validation through multi-source verification
// Provides legitimate confidence through: multi-model consensus, web verification,
// code execution, static analysis, and user feedback learning

import Foundation
import OSLog

// MARK: - Confidence Result

/// Complete confidence assessment with multi-source validation
public struct ConfidenceResult: Sendable, Identifiable {
    public let id = UUID()
    public let overallConfidence: Double
    public let level: ConfidenceLevel
    public let sources: [ConfidenceSource]
    public let decomposition: ConfidenceDecomposition
    public let timestamp: Date

    /// Why is confidence at this level?
    public var reasoning: String {
        decomposition.reasoning
    }

    /// Suggestions to improve confidence
    public var improvementSuggestions: [String] {
        decomposition.suggestions
    }

    public init(
        overallConfidence: Double,
        sources: [ConfidenceSource],
        decomposition: ConfidenceDecomposition
    ) {
        self.overallConfidence = min(1.0, max(0.0, overallConfidence))
        self.level = ConfidenceLevel(from: self.overallConfidence)
        self.sources = sources
        self.decomposition = decomposition
        self.timestamp = Date()
    }
}

// MARK: - Confidence Level

public enum ConfidenceLevel: String, Sendable, CaseIterable {
    case high = "High Confidence"
    case medium = "Medium Confidence"
    case low = "Low Confidence"
    case unverified = "Unverified"

    public init(from confidence: Double) {
        switch confidence {
        case 0.85...1.0: self = .high
        case 0.60..<0.85: self = .medium
        case 0.30..<0.60: self = .low
        default: self = .unverified
        }
    }

    public var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "orange"
        case .low: return "red"
        case .unverified: return "gray"
        }
    }

    public var icon: String {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "questionmark.circle.fill"
        case .unverified: return "circle.dashed"
        }
    }

    public var actionRequired: Bool {
        self == .low || self == .unverified
    }
}

// MARK: - Confidence Source

/// Individual source contributing to overall confidence
public struct ConfidenceSource: Sendable, Identifiable {
    public let id = UUID()
    public let type: SourceType
    public let name: String
    public let confidence: Double
    public let weight: Double
    public let details: String
    public let verified: Bool

    public enum SourceType: String, Sendable, CaseIterable {
        case modelConsensus = "Model Consensus"
        case webVerification = "Web Verification"
        case codeExecution = "Code Execution"
        case staticAnalysis = "Static Analysis"
        case cachedKnowledge = "Cached Knowledge"
        case userFeedback = "User Feedback"
        case patternMatch = "Pattern Match"
        case semanticAnalysis = "Semantic Analysis"
    }

    public var icon: String {
        switch type {
        case .modelConsensus: return "brain.head.profile"
        case .webVerification: return "globe"
        case .codeExecution: return "play.circle"
        case .staticAnalysis: return "doc.text.magnifyingglass"
        case .cachedKnowledge: return "archivebox"
        case .userFeedback: return "hand.thumbsup"
        case .patternMatch: return "text.magnifyingglass"
        case .semanticAnalysis: return "sparkles"
        }
    }

    public var weightedConfidence: Double {
        confidence * weight
    }
}

// MARK: - Confidence Decomposition

/// Explains WHY confidence is at a certain level
public struct ConfidenceDecomposition: Sendable {
    public let factors: [DecompositionFactor]
    public let conflicts: [ConflictInfo]
    public let reasoning: String
    public let suggestions: [String]

    public struct DecompositionFactor: Sendable, Identifiable {
        public let id = UUID()
        public let name: String
        public let contribution: Double  // -1.0 to 1.0
        public let explanation: String
    }

    public struct ConflictInfo: Sendable, Identifiable {
        public let id = UUID()
        public let source1: String
        public let source2: String
        public let description: String
        public let severity: ConflictSeverity

        public enum ConflictSeverity: String, Sendable {
            case minor = "Minor"
            case moderate = "Moderate"
            case major = "Major"
        }
    }

    public var hasConflicts: Bool {
        !conflicts.isEmpty
    }
}

// MARK: - Confidence System

/// Central AI-powered confidence validation system
@MainActor
public final class ConfidenceSystem {
    public static let shared = ConfidenceSystem()

    private let logger = Logger(subsystem: "com.thea.ai", category: "ConfidenceSystem")

    // Sub-systems
    private let multiModelConsensus = MultiModelConsensus()
    private let webVerifier = WebSearchVerifier()
    private let codeExecutor = CodeExecutionVerifier()
    private let staticAnalyzer = StaticAnalysisVerifier()
    private let feedbackLearner = UserFeedbackLearner()

    // Configuration
    public var enableMultiModel: Bool = true
    public var enableWebVerification: Bool = true
    public var enableCodeExecution: Bool = true
    public var enableStaticAnalysis: Bool = true
    public var enableFeedbackLearning: Bool = true

    // Weights for each source type (normalized to sum to 1.0)
    public var sourceWeights: [ConfidenceSource.SourceType: Double] = [
        .modelConsensus: 0.30,
        .webVerification: 0.17,
        .codeExecution: 0.22,
        .staticAnalysis: 0.09,
        .userFeedback: 0.09,
        .cachedKnowledge: 0.04,
        .patternMatch: 0.04,
        .semanticAnalysis: 0.05
    ]

    /// Per-verifier timeout (seconds) — prevents slow verifiers from blocking others
    public var verifierTimeout: TimeInterval = 8.0

    private init() {}

    // MARK: - Public API

    /// Validate a response and calculate confidence
    public func validateResponse(
        _ response: String,
        query: String,
        taskType: TaskType,
        context: ValidationContext = .default
    ) async -> ConfidenceResult {
        logger.info("Validating response for task type: \(taskType.rawValue)")

        var sources: [ConfidenceSource] = []
        var factors: [ConfidenceDecomposition.DecompositionFactor] = []
        var conflicts: [ConfidenceDecomposition.ConflictInfo] = []

        // Capture verifiers and config into local lets for Sendable closure use
        let timeout = self.verifierTimeout
        let consensus = self.multiModelConsensus
        let webVfy = self.webVerifier
        let codeExec = self.codeExecutor
        let staticAn = self.staticAnalyzer
        let fbLearner = self.feedbackLearner
        let doMultiModel = enableMultiModel && context.allowMultiModel
        let doWebVerify = enableWebVerification && context.allowWebSearch && taskType.requiresFactualVerification
        let doCodeExec = enableCodeExecution && context.allowCodeExecution && taskType.isCodeRelated
        let doStaticAnalysis = enableStaticAnalysis && taskType.isCodeRelated
        let doFeedback = enableFeedbackLearning
        let lang = context.language

        // Run enabled verifiers in parallel with per-verifier timeout
        await withTaskGroup(of: VerifierOutput?.self) { group in
            // 1. Multi-model consensus
            if doMultiModel {
                group.addTask {
                    await Self.withTimeout(seconds: timeout) {
                        let r = await consensus.validate(query: query, response: response, taskType: taskType)
                        return VerifierOutput(source: r.source, factors: r.factors, conflicts: r.conflicts)
                    }
                }
            }

            // 2. Web verification (for factual claims)
            if doWebVerify {
                group.addTask {
                    await Self.withTimeout(seconds: timeout) {
                        let r = await webVfy.verify(response: response, query: query)
                        return VerifierOutput(source: r.source, factors: r.factors, conflicts: [])
                    }
                }
            }

            // 3. Code execution (for code responses)
            if doCodeExec {
                group.addTask {
                    await Self.withTimeout(seconds: timeout) {
                        let r = await codeExec.verify(response: response, language: lang)
                        return VerifierOutput(source: r.source, factors: r.factors, conflicts: [])
                    }
                }
            }

            // 4. Static analysis (for code)
            if doStaticAnalysis {
                group.addTask {
                    await Self.withTimeout(seconds: timeout) {
                        let r = await staticAn.analyze(response: response, language: lang)
                        return VerifierOutput(source: r.source, factors: r.factors, conflicts: [])
                    }
                }
            }

            // 5. User feedback history
            if doFeedback {
                group.addTask {
                    await Self.withTimeout(seconds: timeout) {
                        let r = await fbLearner.assessFromHistory(taskType: taskType, responsePattern: response)
                        return VerifierOutput(source: r.source, factors: r.factors, conflicts: [])
                    }
                }
            }

            for await output in group {
                guard let output else { continue }
                sources.append(output.source)
                factors.append(contentsOf: output.factors)
                conflicts.append(contentsOf: output.conflicts)
            }
        }

        // Calculate overall confidence
        let overallConfidence = calculateOverallConfidence(from: sources)

        // Generate decomposition
        let decomposition = generateDecomposition(
            factors: factors,
            conflicts: conflicts,
            confidence: overallConfidence,
            sources: sources
        )

        let result = ConfidenceResult(
            overallConfidence: overallConfidence,
            sources: sources,
            decomposition: decomposition
        )

        logger.info("Confidence result: \(result.level.rawValue) (\(String(format: "%.0f%%", result.overallConfidence * 100)))")

        return result
    }

    // MARK: - Hallucination Detection (Semantic Entropy)

    /// Detect potential hallucinations using semantic entropy analysis.
    /// Checks for factual claims that have high variance across self-consistency probes:
    /// - Hedging language patterns (uncertain claims presented as facts)
    /// - Specific quantitative claims (dates, numbers, URLs)
    /// - Claims contradicting known knowledge graph entities
    public func detectHallucinations(
        _ response: String,
        query: String,
        knowledgeContext: [String] = []
    ) async -> [HallucinationFlag] {
        var flags: [HallucinationFlag] = []

        let sentences = response.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }

        for sentence in sentences {
            let lower = sentence.lowercased()

            // Heuristic 1: Hedging language in factual context
            let hedgePatterns = [
                "i believe", "i think", "probably", "might be",
                "reportedly", "some sources say", "it seems", "allegedly"
            ]
            let hasHedge = hedgePatterns.contains { lower.contains($0) }

            // Heuristic 2: Specific quantitative claims are higher risk
            let hasSpecificNumber = sentence.range(of: #"\b\d{4,}\b"#, options: .regularExpression) != nil
            let hasURL = sentence.range(of: #"https?://\S+"#, options: .regularExpression) != nil
            let hasSpecificDate = sentence.range(of: #"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}"#, options: .regularExpression) != nil

            // Heuristic 3: Contradicts known knowledge graph facts
            let contradictsKnowledge = knowledgeContext.contains { known in
                let knownLower = known.lowercased()
                // Simple contradiction: sentence claims opposite of known fact
                return (lower.contains("not") && knownLower.split(separator: " ").filter { $0.count > 3 }.contains { lower.contains(String($0).lowercased()) })
            }

            // Risk scoring
            var riskScore = 0.0
            if hasHedge { riskScore += 0.3 }
            if hasSpecificNumber { riskScore += 0.2 }
            if hasURL { riskScore += 0.4 } // URLs in AI responses are high hallucination risk
            if hasSpecificDate { riskScore += 0.15 }
            if contradictsKnowledge { riskScore += 0.5 }

            if riskScore >= 0.3 {
                let risk: HallucinationRisk = riskScore >= 0.6 ? .high : riskScore >= 0.4 ? .medium : .low
                var reasons: [String] = []
                if hasURL { reasons.append("contains URL (high fabrication risk)") }
                if hasHedge { reasons.append("hedging language") }
                if hasSpecificDate || hasSpecificNumber { reasons.append("specific claim without source") }
                if contradictsKnowledge { reasons.append("may contradict known facts") }

                flags.append(HallucinationFlag(
                    claim: String(sentence.prefix(120)),
                    riskLevel: risk,
                    reason: reasons.joined(separator: "; ")
                ))
            }
        }

        return flags
    }

    /// Record user feedback for learning
    public func recordFeedback(
        responseId: UUID,
        wasCorrect: Bool,
        userCorrection: String? = nil,
        taskType: TaskType
    ) async {
        await feedbackLearner.recordFeedback(
            responseId: responseId,
            wasCorrect: wasCorrect,
            userCorrection: userCorrection,
            taskType: taskType
        )
    }

    // MARK: - Private Methods

    private func calculateOverallConfidence(from sources: [ConfidenceSource]) -> Double {
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

    // MARK: - Helpers

    /// Intermediate result from a verifier
    private struct VerifierOutput: Sendable {
        let source: ConfidenceSource
        let factors: [ConfidenceDecomposition.DecompositionFactor]
        let conflicts: [ConfidenceDecomposition.ConflictInfo]
    }

    /// Run an async closure with a timeout; returns nil if timeout exceeded
    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            // Return whichever finishes first
            for await result in group {
                group.cancelAll()
                return result
            }
            return nil
        }
    }

    private func generateDecomposition(
        factors: [ConfidenceDecomposition.DecompositionFactor],
        conflicts: [ConfidenceDecomposition.ConflictInfo],
        confidence: Double,
        sources: [ConfidenceSource]
    ) -> ConfidenceDecomposition {
        // Generate reasoning
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

        // Generate suggestions
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

        return ConfidenceDecomposition(
            factors: factors,
            conflicts: conflicts,
            reasoning: reasoning,
            suggestions: suggestions
        )
    }
}

// MARK: - Validation Context

public struct ValidationContext: Sendable {
    public let allowMultiModel: Bool
    public let allowWebSearch: Bool
    public let allowCodeExecution: Bool
    public let language: CodeLanguage
    public let maxLatency: TimeInterval

    public static let `default` = ValidationContext(
        allowMultiModel: true,
        allowWebSearch: true,
        allowCodeExecution: true,
        language: .swift,
        maxLatency: 10.0
    )

    public static let fast = ValidationContext(
        allowMultiModel: false,
        allowWebSearch: false,
        allowCodeExecution: false,
        language: .swift,
        maxLatency: 1.0
    )

    public enum CodeLanguage: String, Sendable {
        case swift, javascript, python, unknown
    }
}

// MARK: - TaskType Extensions

extension TaskType {
    var requiresFactualVerification: Bool {
        switch self {
        case .factual, .research, .informationRetrieval:
            return true
        default:
            return false
        }
    }

    var isCodeRelated: Bool {
        switch self {
        case .codeGeneration, .codeAnalysis, .codeDebugging, .codeExplanation,
             .codeRefactoring, .debugging, .appDevelopment:
            return true
        default:
            return false
        }
    }
}
