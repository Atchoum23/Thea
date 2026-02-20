// ClassificationOutcome.swift
// Thea
//
// D3: Persists classification + confidence outcomes for long-term learning.
// Used by ChatManager+Tools to improve SmartModelRouter routing over time.

import Foundation
import SwiftData

/// Persisted record of a task classification and its AI response confidence score.
/// Accumulates over time to enable learning-based model routing.
@Model
final class ClassificationOutcome: Sendable {
    var query: String
    var taskType: String
    var modelId: String
    var confidenceScore: Double
    var userFeedback: Int?   // +1 = thumbs up, -1 = thumbs down, nil = no feedback
    var timestamp: Date

    init(
        query: String,
        taskType: String,
        modelId: String,
        confidenceScore: Double,
        userFeedback: Int? = nil
    ) {
        self.query = query
        self.taskType = taskType
        self.modelId = modelId
        self.confidenceScore = confidenceScore
        self.userFeedback = userFeedback
        self.timestamp = Date()
    }

    /// Average confidence for a model + task type combination.
    static func averageConfidence(
        for modelId: String,
        taskType: String,
        in outcomes: [ClassificationOutcome]
    ) -> Double? {
        let relevant = outcomes.filter { $0.modelId == modelId && $0.taskType == taskType }
        guard !relevant.isEmpty else { return nil }
        return relevant.reduce(0.0) { $0 + $1.confidenceScore } / Double(relevant.count)
    }
}
