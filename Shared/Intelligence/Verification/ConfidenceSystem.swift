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

/// Qualitative confidence band derived from the overall confidence score.
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

        /// The verification system that produced this confidence source.
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

    /// A single factor contributing positively or negatively to the overall confidence.
    public struct DecompositionFactor: Sendable, Identifiable {
        public let id = UUID()
        public let name: String
        public let contribution: Double  // -1.0 to 1.0
        public let explanation: String
    }

    /// A detected conflict between two sources that reduces confidence.
    public struct ConflictInfo: Sendable, Identifiable {
        public let id = UUID()
        public let source1: String
        public let source2: String
        public let description: String
        public let severity: ConflictSeverity

        /// How significantly this conflict affects confidence.
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
/// Orchestrates multi-source confidence validation — combines model consensus, web verification, code execution, static analysis, and user feedback.
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

    // Weights for each source type
    public var sourceWeights: [ConfidenceSource.SourceType: Double] = [
        .modelConsensus: 0.35,
        .webVerification: 0.20,
        .codeExecution: 0.25,
        .staticAnalysis: 0.10,
        .userFeedback: 0.10,
        .cachedKnowledge: 0.05,
        .patternMatch: 0.05,
        .semanticAnalysis: 0.15
    ]

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

        // 1. Multi-model consensus
        if enableMultiModel && context.allowMultiModel {
            let consensusResult = await multiModelConsensus.validate(
                query: query,
                response: response,
                taskType: taskType
            )
            sources.append(consensusResult.source)
            factors.append(contentsOf: consensusResult.factors)
            conflicts.append(contentsOf: consensusResult.conflicts)
        }

        // 2. Web verification (for factual claims)
        if enableWebVerification && context.allowWebSearch && taskType.requiresFactualVerification {
            let webResult = await webVerifier.verify(response: response, query: query)
            sources.append(webResult.source)
            factors.append(contentsOf: webResult.factors)
        }

        // 3. Code execution (for code responses)
        if enableCodeExecution && context.allowCodeExecution && taskType.isCodeRelated {
            let execResult = await codeExecutor.verify(response: response, language: context.language)
            sources.append(execResult.source)
            factors.append(contentsOf: execResult.factors)
        }

        // 4. Static analysis (for code)
        if enableStaticAnalysis && taskType.isCodeRelated {
            let analysisResult = await staticAnalyzer.analyze(response: response, language: context.language)
            sources.append(analysisResult.source)
            factors.append(contentsOf: analysisResult.factors)
        }

        // 5. User feedback history
        if enableFeedbackLearning {
            let feedbackResult = await feedbackLearner.assessFromHistory(
                taskType: taskType,
                responsePattern: response
            )
            sources.append(feedbackResult.source)
            factors.append(contentsOf: feedbackResult.factors)
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


    /// Detect potential hallucinations in a response.
    ///
    /// Performs lightweight heuristic checks for common hallucination patterns:
    /// specific dates/statistics without citations, contradictions, or
    /// implausible claims. Returns an array of flag strings (empty = no flags).
    ///
    /// - Parameters:
    ///   - response: The AI response text to analyse.
    ///   - query: The original user query for context.
    /// - Returns: An array of hallucination flag descriptions.
    public func detectHallucinations(_ response: String, query: String) async -> [String] {
        var flags: [String] = []

        // Flag overly precise statistics without citation
        let statisticPattern = #"\b\d{1,3}(?:\.\d+)?\s*%"#
        // Safe: compile-time known pattern; invalid regex → skip statistics hallucination check
        if let regex = try? NSRegularExpression(pattern: statisticPattern),
           regex.numberOfMatches(in: response, range: NSRange(response.startIndex..., in: response)) > 2 {
            flags.append("Multiple precise statistics without citations")
        }

        // Flag contradictions with common knowledge (simple heuristic)
        let contradictoryPatterns = ["always", "never", "100%", "0%", "impossible", "guaranteed"]
        for pattern in contradictoryPatterns {
            if response.lowercased().contains(pattern) {
                flags.append("Absolute claim detected: '\(pattern)'")
                break
            }
        }

        // Flag responses that are much longer than expected for simple queries
        let queryWords = query.split(separator: " ").count
        let responseWords = response.split(separator: " ").count
        if queryWords < 5 && responseWords > 500 {
            flags.append("Response length disproportionate to query complexity")
        }

        return flags
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

/// Context passed to confidence validators describing the response being assessed.
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

    /// Messaging context: skip heavy verification (multi-model, web search) to keep latency < 2s.
    /// Applied when response is delivered via TheaMessagingGateway channels (Telegram, Discord, etc.).
    public static let messaging = ValidationContext(
        allowMultiModel: false,
        allowWebSearch: false,
        allowCodeExecution: false,
        language: .unknown,
        maxLatency: 2.0
    )

/// Programming language of the code being validated by the confidence system.
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
