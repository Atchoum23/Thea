// IntentAnticipator.swift
// Thea V2 - Intent Anticipation
//
// Predicts user intent using multi-signal fusion
// Combines temporal, contextual, and behavioral signals

import Foundation
import OSLog

// MARK: - Intent Anticipator

/// Predicts user intent using multi-signal fusion
@MainActor
@Observable
public final class IntentAnticipator {

    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "IntentAnticipator")

    // MARK: - Signal Weights

    /// Weight for temporal patterns
    public var temporalWeight: Double = 0.30

    /// Weight for mental model
    public var mentalModelWeight: Double = 0.25

    /// Weight for sequence patterns
    public var sequenceWeight: Double = 0.25

    /// Weight for context signals
    public var contextWeight: Double = 0.20

    // MARK: - State

    /// Recent actions for sequence prediction
    private var recentActions: [UserAction] = []

    /// Prediction accuracy history
    private var accuracyHistory: [PredictionAccuracyRecord] = []

    /// Overall prediction accuracy
    public private(set) var overallAccuracy: Double = 0.5

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Record a user action
    public func recordAction(_ action: UserAction) {
        recentActions.append(action)

        // Keep last 50 actions
        if recentActions.count > 50 {
            recentActions.removeFirst()
        }
    }

    /// Predict intents based on available signals
    public func predictIntents(
        context: AmbientContext,
        patterns: [TemporalPattern]
    ) async -> [PredictedUserIntent] {
        var intents: [WeightedIntentCandidate] = []

        // Temporal signal
        let temporalIntents = predictFromPatterns(patterns)
        intents.append(contentsOf: temporalIntents.map { intent in
            WeightedIntentCandidate(intent: intent, weight: temporalWeight)
        })

        // Sequence signal
        let sequenceIntents = predictFromSequence()
        intents.append(contentsOf: sequenceIntents.map { intent in
            WeightedIntentCandidate(intent: intent, weight: sequenceWeight)
        })

        // Context signal
        let contextIntents = predictFromContext(context)
        intents.append(contentsOf: contextIntents.map { intent in
            WeightedIntentCandidate(intent: intent, weight: contextWeight)
        })

        // Fuse signals
        let fusedIntents = fuseIntents(intents)

        return fusedIntents
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { $0 }
    }

    /// Learn from feedback
    public func learnFromFeedback(_ feedback: AnticipationFeedback) {
        let record = PredictionAccuracyRecord(
            timestamp: feedback.timestamp,
            wasCorrect: feedback.wasAccepted
        )
        accuracyHistory.append(record)

        // Update overall accuracy
        let recentRecords = accuracyHistory.suffix(100)
        let correctCount = recentRecords.filter(\.wasCorrect).count
        overallAccuracy = Double(correctCount) / Double(recentRecords.count)

        logger.info("Updated prediction accuracy: \(self.overallAccuracy)")
    }

    // MARK: - Private Methods

    private func predictFromPatterns(_ patterns: [TemporalPattern]) -> [PredictedUserIntent] {
        patterns.map { pattern in
            PredictedUserIntent(
                actionType: pattern.actionType,
                description: "Based on temporal pattern: \(pattern.description)",
                confidence: pattern.confidence
            )
        }
    }

    private func predictFromSequence() -> [PredictedUserIntent] {
        guard recentActions.count >= 2 else { return [] }

        // Simple n-gram prediction
        let lastActions = recentActions.suffix(3).map(\.type)

        // Find common follow-up actions (simplified)
        var predictions: [PredictedUserIntent] = []

        if lastActions.contains("search") {
            predictions.append(PredictedUserIntent(
                actionType: "view_result",
                description: "User likely to view search results",
                confidence: 0.7
            ))
        }

        if lastActions.contains("open_file") {
            predictions.append(PredictedUserIntent(
                actionType: "edit",
                description: "User likely to edit opened file",
                confidence: 0.6
            ))
        }

        return predictions
    }

    private func predictFromContext(_ context: AmbientContext) -> [PredictedUserIntent] {
        var predictions: [PredictedUserIntent] = []

        let hour = Calendar.current.component(.hour, from: Date())
        if (9...17).contains(hour) {
            predictions.append(PredictedUserIntent(
                actionType: "work_task",
                description: "Work-related activity expected",
                confidence: 0.5
            ))
        }

        if context.recentActivityTypes.contains("code") {
            predictions.append(PredictedUserIntent(
                actionType: "code_action",
                description: "Coding activity expected",
                confidence: 0.6
            ))
        }

        return predictions
    }

    private func fuseIntents(_ candidates: [WeightedIntentCandidate]) -> [PredictedUserIntent] {
        // Group by action type
        let grouped = Dictionary(grouping: candidates) { $0.intent.actionType }

        return grouped.map { actionType, candidates in
            // Weighted average of confidence
            let totalWeight = candidates.reduce(0.0) { $0 + $1.weight }
            let weightedConfidence = candidates.reduce(0.0) { sum, candidate in
                sum + candidate.intent.confidence * candidate.weight
            } / totalWeight

            return PredictedUserIntent(
                actionType: actionType,
                description: candidates.first?.intent.description ?? "",
                confidence: weightedConfidence
            )
        }
    }
}

// MARK: - Supporting Types

private struct WeightedIntentCandidate {
    let intent: PredictedUserIntent
    let weight: Double
}

private struct PredictionAccuracyRecord {
    let timestamp: Date
    let wasCorrect: Bool
}
