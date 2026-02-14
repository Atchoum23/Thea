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
    static let shared = ChatReflexionIntegration()

    private let logger = Logger(subsystem: "com.thea.app", category: "ChatReflexion")

    // MARK: - Configuration

    /// Whether automatic reflexion is enabled
    var isEnabled = true

    /// Minimum response length to trigger reflexion (skip trivial responses)
    var minimumResponseLength = 100

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

    /// Record user feedback on a response for learning
    func recordFeedback(
        messageID: UUID,
        feedback: UserResponseFeedback
    ) async {
        let engine = ReflexionEngine.shared

        switch feedback {
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

    private func updateKnowledgeGraph(feedback: UserResponseFeedback, messageID: UUID) async {
        let graph = PersonalKnowledgeGraph.shared

        switch feedback {
        case .positive:
            await graph.addEntity(KGEntity(
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

    /// Average quality score over the last N data points
    func averageQuality(last count: Int = 50) -> Float {
        let recent = qualityTrend.suffix(count)
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(Float(0)) { $0 + $1.score } / Float(recent.count)
    }

    /// Improvement rate (percentage of responses that were improved)
    var improvementRate: Double {
        guard reflexionCount > 0 else { return 0 }
        return Double(improvedCount) / Double(reflexionCount) * 100
    }
}

// MARK: - Types

struct ReflexionResult: Sendable {
    let response: String
    let wasImproved: Bool
    var originalScore: Float?
    var improvedScore: Float?
    var iterations: Int = 0
}

enum UserResponseFeedback: Sendable {
    case positive
    case negative
    case correction(String)
    case rating(Float)  // 0.0-1.0
}

struct QualityDataPoint: Sendable {
    let timestamp: Date
    let score: Float
    let wasImproved: Bool
}
