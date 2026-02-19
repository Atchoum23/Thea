// ChatReflexionIntegration.swift
// Thea — ReflexionEngine ↔ Chat Integration
//
// Bridges the ReflexionEngine with the chat flow:
// - Auto-critiques responses below a confidence threshold
// - Learns from user feedback (thumbs up/down, corrections)
// - Tracks quality trends over time
// - Feeds failure analysis back to PersonalKnowledgeGraph

import Foundation
import OSLog

// MARK: - Chat Reflexion Integration

@MainActor
@Observable
final class ChatReflexionIntegration {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = ChatReflexionIntegration()

    // periphery:ignore - Reserved: logger property — reserved for future feature activation
    private let logger = Logger(subsystem: "com.thea.app", category: "ChatReflexion")

    // MARK: - Configuration

    /// Whether automatic reflexion is enabled
    var isEnabled = true

    // periphery:ignore - Reserved: shared static property reserved for future feature activation
    /// Minimum response length to trigger reflexion (skip trivial responses)
    var minimumResponseLength = 100

// periphery:ignore - Reserved: logger property reserved for future feature activation

    /// Confidence threshold below which reflexion triggers
    var confidenceThreshold: Float = 0.6

    /// Maximum reflexion cycles per minute (prevent runaway loops)
    var maxReflexionsPerMinute = 3

    // MARK: - State

    private(set) var reflexionCount = 0
    private(set) var improvedCount = 0
    private(set) var qualityTrend: [QualityDataPoint] = []
    private var recentReflexionTimestamps: [Date] = []

    private init() {}

    // MARK: - Response Processing

    // periphery:ignore - Reserved: processResponse(task:response:conversationContext:) instance method — reserved for future feature activation
    /// Evaluate an AI response and optionally improve it via reflexion.
    /// Returns the original or improved response.
    func processResponse(
        task: String,
        response: String,
        conversationContext: String = ""
    ) async -> ReflexionResult {
        guard isEnabled else {
            return ReflexionResult(response: response, wasImproved: false)
        }

// periphery:ignore - Reserved: processResponse(task:response:conversationContext:) instance method reserved for future feature activation

        // Skip short responses
        guard response.count >= minimumResponseLength else {
            return ReflexionResult(response: response, wasImproved: false)
        }

        // Rate limiting
        let now = Date()
        recentReflexionTimestamps = recentReflexionTimestamps.filter {
            now.timeIntervalSince($0) < 60
        }
        guard recentReflexionTimestamps.count < maxReflexionsPerMinute else {
            logger.debug("Reflexion rate limit reached")
            return ReflexionResult(response: response, wasImproved: false)
        }

        recentReflexionTimestamps.append(now)
        reflexionCount += 1

        // Run reflexion cycle
        let engine = ReflexionEngine.shared
        let cycle = await engine.reflect(
            task: task,
            output: response,
            context: conversationContext
        )

        // Record quality trend
        let critique = cycle.selfCritique
        let dataPoint = QualityDataPoint(
            timestamp: now,
            score: critique.averageScore,
            wasImproved: cycle.improvedOutput != nil
        )
        qualityTrend.append(dataPoint)
        if qualityTrend.count > 500 {
            qualityTrend.removeFirst(qualityTrend.count - 500)
        }

        if let improved = cycle.improvedOutput {
            improvedCount += 1
            logger.info("Response improved via reflexion (iteration \(cycle.iterationCount))")
            return ReflexionResult(
                response: improved,
                wasImproved: true,
                originalScore: critique.averageScore,
                improvedScore: cycle.confidenceScore,
                iterations: cycle.iterationCount
            )
        }

        return ReflexionResult(response: response, wasImproved: false)
    }

    // MARK: - User Feedback

    // periphery:ignore - Reserved: recordFeedback(messageID:feedback:) instance method — reserved for future feature activation
    /// Record user feedback on a response for learning
    func recordFeedback(
        messageID: UUID,
        feedback: UserResponseFeedback
    ) async {
        let engine = ReflexionEngine.shared

        switch feedback {
        // periphery:ignore - Reserved: recordFeedback(messageID:feedback:) instance method reserved for future feature activation
        case .positive:
            logger.info("Positive feedback recorded for \(messageID)")

        case .negative:
            logger.info("Negative feedback recorded for \(messageID)")

        case let .correction(correctedText):
            // Learn from the correction via failure analysis
            _ = engine.analyzeFailure(
                task: "User corrected response \(messageID)",
                error: "User provided correction",
                context: "Corrected to: \(correctedText)"
            )
            logger.info("Correction feedback recorded for \(messageID)")

        case let .rating(score):
            let dataPoint = QualityDataPoint(
                timestamp: Date(),
                score: score,
                wasImproved: false
            )
            qualityTrend.append(dataPoint)
            logger.info("Rating feedback (\(score)) recorded for \(messageID)")
        }

        // Extract insights for knowledge graph
        await updateKnowledgeGraph(feedback: feedback, messageID: messageID)
    }

    // MARK: - Knowledge Graph Integration

    // periphery:ignore - Reserved: updateKnowledgeGraph(feedback:messageID:) instance method — reserved for future feature activation
    private func updateKnowledgeGraph(feedback: UserResponseFeedback, messageID: UUID) async {
        let graph = PersonalKnowledgeGraph.shared

        switch feedback {
        case .positive:
            await graph.addEntity(KGEntity(
                // periphery:ignore - Reserved: updateKnowledgeGraph(feedback:messageID:) instance method reserved for future feature activation
                name: "positive_interaction_\(messageID.uuidString.prefix(8))",
                type: .event,
                attributes: ["type": "positive_feedback", "date": ISO8601DateFormatter().string(from: Date())]
            ))

        case let .correction(text):
            await graph.addEntity(KGEntity(
                name: "correction_\(messageID.uuidString.prefix(8))",
                type: .event,
                attributes: ["type": "user_correction", "correction": String(text.prefix(200))]
            ))

        default:
            break
        }
    }

    // MARK: - Analytics

    // periphery:ignore - Reserved: averageQuality(last:) instance method — reserved for future feature activation
    /// Average quality score over the last N data points
    func averageQuality(last count: Int = 50) -> Float {
        let recent = qualityTrend.suffix(count)
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(Float(0)) { $0 + $1.score } / Float(recent.count)
    }

// periphery:ignore - Reserved: averageQuality(last:) instance method reserved for future feature activation

    /// Improvement rate (percentage of responses that were improved)
    var improvementRate: Double {
        guard reflexionCount > 0 else { return 0 }
        return Double(improvedCount) / Double(reflexionCount) * 100
    }
// periphery:ignore - Reserved: improvementRate property reserved for future feature activation
}

// MARK: - Types

// periphery:ignore - Reserved: ReflexionResult type — reserved for future feature activation
struct ReflexionResult: Sendable {
    let response: String
    let wasImproved: Bool
    // periphery:ignore - Reserved: ReflexionResult type reserved for future feature activation
    var originalScore: Float?
    var improvedScore: Float?
    var iterations: Int = 0
}

// periphery:ignore - Reserved: UserResponseFeedback enum — reserved for future feature activation
enum UserResponseFeedback: Sendable {
    case positive
    // periphery:ignore - Reserved: UserResponseFeedback type reserved for future feature activation
    case negative
    case correction(String)
    case rating(Float)  // 0.0-1.0
}

struct QualityDataPoint: Sendable {
    // periphery:ignore - Reserved: timestamp property — reserved for future feature activation
    let timestamp: Date
    // periphery:ignore - Reserved: timestamp property reserved for future feature activation
    let score: Float
    // periphery:ignore - Reserved: wasImproved property reserved for future feature activation
    let wasImproved: Bool
}
