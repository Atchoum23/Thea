// ProactivityEngine+IntentPrediction.swift
// Thea V2 - User Intent Prediction
//
// Predicts the user's next likely intent by combining time-based,
// query-sequence, and context-based pattern analysis.

import Foundation
import os.log

// MARK: - ProactivityEngine Intent Prediction

extension ProactivityEngine {

    // MARK: - Public API

    /// Predict the user's next likely intent based on patterns and context.
    ///
    /// Combines three signal sources — time-based patterns, query-sequence patterns,
    /// and contextual patterns — then aggregates confidence scores to produce the
    /// highest-probability prediction.
    ///
    /// - Parameters:
    ///   - currentContext: A snapshot of the user's current context (time, battery, etc.).
    ///   - recentQueries: An ordered list of the user's recent query strings.
    /// - Returns: A ``UserIntentPrediction`` if a prediction exceeds the confidence threshold, otherwise `nil`.
    public func predictNextIntent(
        currentContext: MemoryContextSnapshot,
        recentQueries: [String] = []
    ) async -> UserIntentPrediction? {
        // 1. Analyze time-based patterns
        let timePatterns = await getRelevantTimePatterns(for: currentContext)

        // 2. Analyze query sequence patterns
        let queryPatterns = await getQuerySequencePatterns(recentQueries: recentQueries)

        // 3. Analyze context-based patterns
        let contextPatterns = await getContextPatterns(context: currentContext)

        // 4. Combine predictions
        var predictions: [IntentCandidate] = []

        for pattern in timePatterns {
            predictions.append(IntentCandidate(
                intent: pattern.event,  // MemoryDetectedPattern uses .event
                confidence: pattern.confidence * 0.4,  // Time weight
                source: .timePattern
            ))
        }

        for pattern in queryPatterns {
            predictions.append(IntentCandidate(
                intent: pattern.intent,
                confidence: pattern.confidence * 0.35,  // Sequence weight
                source: .querySequence
            ))
        }

        for pattern in contextPatterns {
            predictions.append(IntentCandidate(
                intent: pattern.intent,
                confidence: pattern.confidence * 0.25,  // Context weight
                source: .contextMatch
            ))
        }

        // Aggregate by intent and find highest confidence
        let aggregated = Dictionary(grouping: predictions) { $0.intent }
            .mapValues { candidates in
                candidates.reduce(0.0) { $0 + $1.confidence }
            }

        guard let (topIntent, confidence) = aggregated.max(by: { $0.value < $1.value }),
              confidence >= predictionConfidenceThreshold else {
            return nil
        }

        let prediction = UserIntentPrediction(
            predictedIntent: topIntent,
            confidence: min(1.0, confidence),
            reasoning: generateReasoning(for: topIntent, predictions: predictions),
            suggestedPreparation: generatePreparation(for: topIntent)
        )

        lastPrediction = prediction
        logger.debug("Predicted intent: \(topIntent) (confidence: \(Int(confidence * 100))%)")

        return prediction
    }

    // MARK: - Time Pattern Analysis

    /// Retrieve patterns from the memory cache that match the current time context.
    ///
    /// Refreshes the pattern cache from ``MemoryManager`` if it is stale (older than 1 hour).
    ///
    /// - Parameter context: The current context snapshot containing time-of-day and day-of-week.
    /// - Returns: An array of ``MemoryDetectedPattern`` instances matching the time window.
    internal func getRelevantTimePatterns(for context: MemoryContextSnapshot) async -> [MemoryDetectedPattern] {
        // Refresh pattern cache if stale (older than 1 hour)
        if lastPatternAnalysis == nil ||
           Date().timeIntervalSince(lastPatternAnalysis!) > 3600 {
            patternCache = await MemoryManager.shared.detectPatterns(windowDays: 30)
            lastPatternAnalysis = Date()
        }

        // Filter patterns matching current time context
        return patternCache.filter { pattern in
            // Match hour (within 1 hour window)
            let hourMatch = abs(pattern.hourOfDay - context.timeOfDay) <= 1
            // Match day of week
            let dayMatch = pattern.dayOfWeek == context.dayOfWeek

            return hourMatch && dayMatch
        }
    }

    // MARK: - Query Sequence Analysis

    /// Analyze recent queries for common follow-up patterns.
    ///
    /// Uses a table of known trigger-to-followup pairs (e.g. "write code" -> "run tests")
    /// to predict the user's likely next action.
    ///
    /// - Parameter recentQueries: The user's recent query strings, in chronological order.
    /// - Returns: An array of ``IntentCandidate`` instances derived from query sequence patterns.
    internal func getQuerySequencePatterns(recentQueries: [String]) async -> [IntentCandidate] {
        guard recentQueries.count >= 2 else { return [] }

        // Look for common follow-up patterns
        // This is simplified - a real implementation would use sequence learning
        var candidates: [IntentCandidate] = []

        // Check if recent query pattern suggests next step
        let lastQuery = recentQueries.last ?? ""

        // Common follow-up patterns
        let followUpPatterns: [(trigger: String, followUp: String, confidence: Double)] = [
            ("write code", "run tests", 0.6),
            ("create file", "edit file", 0.5),
            ("search for", "read more about", 0.4),
            ("debug", "fix bug", 0.7),
            ("review", "suggest improvements", 0.5),
            ("summarize", "action items", 0.5),
            ("draft email", "send email", 0.6),
            ("schedule meeting", "prepare agenda", 0.5)
        ]

        for pattern in followUpPatterns {
            if lastQuery.lowercased().contains(pattern.trigger) {
                candidates.append(IntentCandidate(
                    intent: pattern.followUp,
                    confidence: pattern.confidence,
                    source: .querySequence
                ))
            }
        }

        return candidates
    }

    // MARK: - Context Pattern Analysis

    /// Derive intent candidates from the user's current environmental context.
    ///
    /// Evaluates conditions such as battery level and time-of-day to suggest
    /// context-appropriate actions.
    ///
    /// - Parameter context: The current context snapshot.
    /// - Returns: An array of ``IntentCandidate`` instances based on contextual signals.
    internal func getContextPatterns(context: MemoryContextSnapshot) async -> [IntentCandidate] {
        var candidates: [IntentCandidate] = []

        // Battery-based suggestions
        if let battery = context.batteryLevel, battery < 20 && context.isPluggedIn != true {
            candidates.append(IntentCandidate(
                intent: "switch to efficient mode",
                confidence: 0.8,
                source: .contextMatch
            ))
        }

        // Time-of-day based suggestions
        switch context.timeOfDay {
        case 8...9:
            candidates.append(IntentCandidate(
                intent: "morning briefing",
                confidence: 0.5,
                source: .contextMatch
            ))
        case 17...18:
            candidates.append(IntentCandidate(
                intent: "end of day summary",
                confidence: 0.5,
                source: .contextMatch
            ))
        default:
            break
        }

        return candidates
    }

    // MARK: - Reasoning & Preparation

    /// Generate a human-readable reasoning string explaining why an intent was predicted.
    ///
    /// - Parameters:
    ///   - intent: The predicted intent string.
    ///   - predictions: All ``IntentCandidate`` instances that contributed to the prediction.
    /// - Returns: A short sentence describing the signal sources (e.g. "Based on time patterns, current context").
    internal func generateReasoning(for intent: String, predictions: [IntentCandidate]) -> String {
        let sources = Set(predictions.filter { $0.intent == intent }.map(\.source))
        let sourceNames = sources.map(\.description).joined(separator: ", ")
        return "Based on \(sourceNames)"
    }

    /// Generate preparation actions for a predicted intent.
    ///
    /// For example, if the intent involves code, a model pre-warming action is included.
    ///
    /// - Parameter intent: The predicted intent string.
    /// - Returns: An array of ``PreparationAction`` steps to prepare for the predicted intent.
    internal func generatePreparation(for intent: String) -> [PreparationAction] {
        // Generate actions to prepare for predicted intent
        var actions: [PreparationAction] = []

        // Model pre-warming
        if intent.contains("code") {
            actions.append(.preWarmModel("code-specialized-model"))
        }

        // Context gathering
        actions.append(.gatherContext(intent))

        return actions
    }
}
