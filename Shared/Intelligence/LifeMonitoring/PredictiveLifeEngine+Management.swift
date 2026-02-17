// PredictiveLifeEngine+Management.swift
// Thea V2 - Prediction Management, Persistence & Public API
//
// Handles adding/updating/cleaning predictions, UserDefaults
// persistence, accuracy tracking, and the public query API.
// Split from PredictiveLifeEngine.swift for single-responsibility clarity.

import Foundation

// MARK: - Prediction Management

extension PredictiveLifeEngine {

    /// Adds a new prediction or updates an existing one of the same type.
    ///
    /// If an active prediction of the same type was created within the
    /// last 30 minutes, it is replaced rather than duplicated. Otherwise
    /// the prediction is appended. History is trimmed to 1000 entries.
    ///
    /// - Parameter prediction: The prediction to add or update.
    func addOrUpdatePrediction(_ prediction: LifePrediction) {
        // Check if similar prediction exists
        if let existingIndex = activePredictions.firstIndex(where: {
            $0.type == prediction.type &&
            abs($0.createdAt.timeIntervalSince(prediction.createdAt)) < 1800 // Within 30 min
        }) {
            // Update existing prediction
            activePredictions[existingIndex] = prediction
        } else {
            // Add new prediction
            activePredictions.append(prediction)
            predictionHistory.append(prediction)

            // Trim history
            if predictionHistory.count > 1000 {
                predictionHistory.removeFirst(100)
            }
        }
    }

    /// Checks whether an active prediction of the given type exists
    /// that was created within the specified time window.
    ///
    /// - Parameters:
    ///   - type: The prediction type to search for.
    ///   - seconds: Maximum age in seconds.
    /// - Returns: `true` if a matching prediction exists.
    func hasPrediction(ofType type: LifePredictionType, within seconds: TimeInterval) -> Bool {
        activePredictions.contains {
            $0.type == type && Date().timeIntervalSince($0.createdAt) < seconds
        }
    }

    /// Removes expired and stale predictions from the active list.
    ///
    /// A prediction is removed if:
    /// - It has an explicit ``expiresAt`` that has passed, or
    /// - It has no expiration and is older than 24 hours.
    func cleanupExpiredPredictions() {
        let now = Date()
        activePredictions.removeAll { prediction in
            if let expiresAt = prediction.expiresAt, expiresAt < now {
                return true
            }
            // Also remove old predictions that weren't explicitly given expiration
            return prediction.expiresAt == nil && now.timeIntervalSince(prediction.createdAt) > 86400 // 24 hours
        }
    }
}

// MARK: - Helpers

extension PredictiveLifeEngine {

    /// Calculates the relevance score based on how far in the future a prediction is.
    ///
    /// Closer predictions are more relevant: < 5 min = 1.0, < 30 min = 0.9,
    /// < 1 hr = 0.8, < 4 hr = 0.6, < 1 day = 0.4, beyond = 0.2.
    ///
    /// - Parameter horizon: Time interval in seconds until the predicted event.
    /// - Returns: A relevance score in the range [0.2, 1.0].
    func calculateRelevance(for horizon: TimeInterval) -> Double {
        if horizon < 300 { return 1.0 }          // < 5 min
        if horizon < 1800 { return 0.9 }         // < 30 min
        if horizon < 3600 { return 0.8 }         // < 1 hour
        if horizon < 14400 { return 0.6 }        // < 4 hours
        if horizon < 86400 { return 0.4 }        // < 1 day
        return 0.2
    }

    /// Formats a future date as a human-readable relative time string.
    ///
    /// - Parameter date: The future date.
    /// - Returns: A string like "in a few minutes", "in about 45 minutes",
    ///   "in about 3 hours", or "in about 2 days".
    func formatTimeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        if interval < 300 { return "in a few minutes" }
        if interval < 3600 { return "in about \(Int(interval / 60)) minutes" }
        if interval < 86400 { return "in about \(Int(interval / 3600)) hours" }
        return "in about \(Int(interval / 86400)) days"
    }
}

// MARK: - Persistence

extension PredictiveLifeEngine {

    private static let predictionHistoryKey = "PredictiveLifeEngine.history"
    private static let accuracyKey = "PredictiveLifeEngine.accuracy"

    /// Persists prediction history and accuracy to UserDefaults.
    ///
    /// Saves the most recent 500 predictions and the current accuracy score.
    func saveState() {
        if let historyData = try? JSONEncoder().encode(Array(predictionHistory.suffix(500))) {
            UserDefaults.standard.set(historyData, forKey: Self.predictionHistoryKey)
        }
        UserDefaults.standard.set(predictionAccuracy, forKey: Self.accuracyKey)
    }

    /// Loads prediction history and accuracy from UserDefaults.
    ///
    /// If no saved accuracy exists, defaults to 0.7.
    func loadState() {
        if let historyData = UserDefaults.standard.data(forKey: Self.predictionHistoryKey),
           let history = try? JSONDecoder().decode([LifePrediction].self, from: historyData) {
            predictionHistory = history
        }
        predictionAccuracy = UserDefaults.standard.double(forKey: Self.accuracyKey)
        if predictionAccuracy == 0 { predictionAccuracy = 0.7 } // Default
    }
}

// MARK: - Public API

extension PredictiveLifeEngine {

    /// Returns all active predictions of the specified type.
    ///
    /// - Parameter type: The ``LifePredictionType`` to filter by.
    /// - Returns: An array of matching predictions.
    public func predictions(ofType type: LifePredictionType) -> [LifePrediction] {
        activePredictions.filter { $0.type == type }
    }

    /// Returns all active predictions marked as urgent.
    ///
    /// - Returns: Predictions with ``Actionability/urgent`` actionability.
    public func urgentPredictions() -> [LifePrediction] {
        activePredictions.filter { $0.actionability == .urgent }
    }

    /// Returns all active predictions that Thea can handle automatically.
    ///
    /// - Returns: Predictions with ``Actionability/automatic`` actionability.
    public func automatablePredictions() -> [LifePrediction] {
        activePredictions.filter { $0.actionability == .automatic }
    }

    /// Records the outcome of a past prediction for accuracy learning.
    ///
    /// Updates the prediction in history with the outcome and recalculates
    /// the engine's overall ``predictionAccuracy``.
    ///
    /// - Parameters:
    ///   - predictionId: The UUID of the prediction to update.
    ///   - wasAccurate: Whether the prediction turned out to be correct.
    ///   - userTookAction: Whether the user acted on the prediction.
    ///   - feedback: Optional free-text feedback from the user.
    public func recordOutcome(for predictionId: UUID, wasAccurate: Bool, userTookAction: Bool, feedback: String? = nil) {
        guard let index = predictionHistory.firstIndex(where: { $0.id == predictionId }) else { return }

        let prediction = predictionHistory[index]
        let outcome = PredictionOutcome(
            wasAccurate: wasAccurate,
            userTookAction: userTookAction,
            feedback: feedback
        )

        predictionHistory[index] = LifePrediction(
            id: prediction.id,
            type: prediction.type,
            title: prediction.title,
            description: prediction.description,
            confidence: prediction.confidence,
            timeframe: prediction.timeframe,
            relevance: prediction.relevance,
            actionability: prediction.actionability,
            suggestedActions: prediction.suggestedActions,
            basedOn: prediction.basedOn,
            createdAt: prediction.createdAt,
            expiresAt: prediction.expiresAt,
            outcome: outcome
        )

        // Update accuracy
        updateAccuracy()

        logger.info("Recorded outcome for prediction \(predictionId): accurate=\(wasAccurate)")
    }

    /// Recalculates ``predictionAccuracy`` from all validated predictions in history.
    private func updateAccuracy() {
        let validatedPredictions = predictionHistory.filter { $0.outcome != nil }
        guard !validatedPredictions.isEmpty else { return }

        let accurateCount = validatedPredictions.filter { $0.outcome?.wasAccurate == true }.count
        predictionAccuracy = Double(accurateCount) / Double(validatedPredictions.count)
    }

    /// Manually triggers a full prediction cycle.
    ///
    /// Equivalent to waiting for the next scheduled cycle, but runs immediately.
    public func triggerPredictions() async {
        await runPredictionCycle()
    }
}
