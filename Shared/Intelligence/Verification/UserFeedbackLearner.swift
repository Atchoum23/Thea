// UserFeedbackLearner.swift
// Thea
//
// AI-powered learning from user feedback and corrections
// Builds a feedback loop to improve confidence over time

import Foundation
import OSLog

// MARK: - User Feedback Learner

/// Learns from user feedback to improve confidence assessment over time
@MainActor
public final class UserFeedbackLearner {
    private let logger = Logger(subsystem: "com.thea.ai", category: "UserFeedbackLearner")

    // Storage
    private var feedbackHistory: [FeedbackRecord] = []
    private var patternAccuracy: [String: PatternAccuracy] = [:]

    // Configuration
    public var minSamplesForLearning: Int = 5
    public var maxHistorySize: Int = 10000
    public var decayFactor: Double = 0.95  // Older feedback counts less

    private let storageKey = "user_feedback_learnings"

    init() {
        Task { await loadHistory() }
    }

    // MARK: - Assessment

    /// Assess confidence based on historical feedback
    public func assessFromHistory(
        taskType: TaskType,
        responsePattern: String
    ) async -> FeedbackAssessment {
        let patternKey = generatePatternKey(taskType: taskType, response: responsePattern)

        // Check if we have learned patterns
        if let accuracy = patternAccuracy[patternKey], accuracy.sampleCount >= minSamplesForLearning {
            logger.debug("Using learned pattern for \(taskType.rawValue): \(accuracy.successRate)")

            let factors = [
                ConfidenceDecomposition.DecompositionFactor(
                    name: "Historical Accuracy",
                    contribution: (accuracy.successRate - 0.5) * 2,
                    explanation: "Based on \(accuracy.sampleCount) previous similar responses"
                )
            ]

            return FeedbackAssessment(
                source: ConfidenceSource(
                    type: .userFeedback,
                    name: "User Feedback Learning",
                    confidence: accuracy.successRate,
                    weight: 0.10,
                    details: "Based on \(accuracy.sampleCount) historical responses with \(String(format: "%.0f%%", accuracy.successRate * 100)) success rate",
                    verified: accuracy.sampleCount >= minSamplesForLearning
                ),
                factors: factors
            )
        }

        // Check task type historical accuracy
        let taskTypeHistory = feedbackHistory.filter { $0.taskType == taskType }
        if taskTypeHistory.count >= minSamplesForLearning {
            let successRate = calculateSuccessRate(from: taskTypeHistory)

            let factors = [
                ConfidenceDecomposition.DecompositionFactor(
                    name: "Task Type History",
                    contribution: (successRate - 0.5) * 2,
                    explanation: "Task type '\(taskType.displayName)' has \(String(format: "%.0f%%", successRate * 100)) historical accuracy"
                )
            ]

            return FeedbackAssessment(
                source: ConfidenceSource(
                    type: .userFeedback,
                    name: "User Feedback Learning",
                    confidence: successRate,
                    weight: 0.10,
                    details: "Based on \(taskTypeHistory.count) previous '\(taskType.displayName)' responses",
                    verified: true
                ),
                factors: factors
            )
        }

        // No learned data available
        return FeedbackAssessment(
            source: ConfidenceSource(
                type: .userFeedback,
                name: "User Feedback Learning",
                confidence: 0.5,
                weight: 0.05,  // Lower weight when no data
                details: "Insufficient historical data for this task type",
                verified: false
            ),
            factors: []
        )
    }

    // MARK: - Feedback Recording

    /// Record user feedback on a response
    public func recordFeedback(
        responseId: UUID,
        wasCorrect: Bool,
        userCorrection: String?,
        taskType: TaskType
    ) async {
        let record = FeedbackRecord(
            responseId: responseId,
            wasCorrect: wasCorrect,
            userCorrection: userCorrection,
            taskType: taskType,
            timestamp: Date()
        )

        feedbackHistory.append(record)

        // Update pattern accuracy
        let patternKey = taskType.rawValue
        let accuracy = patternAccuracy[patternKey] ?? PatternAccuracy(successRate: 0.5, sampleCount: 0)
        let newSampleCount = accuracy.sampleCount + 1
        let newSuccessRate = ((accuracy.successRate * Double(accuracy.sampleCount)) + (wasCorrect ? 1.0 : 0.0)) / Double(newSampleCount)
        patternAccuracy[patternKey] = PatternAccuracy(successRate: newSuccessRate, sampleCount: newSampleCount)

        // Trim history if needed
        if feedbackHistory.count > maxHistorySize {
            feedbackHistory = Array(feedbackHistory.suffix(maxHistorySize))
        }

        // Persist
        await saveHistory()

        logger.info("Recorded feedback: \(wasCorrect ? "correct" : "incorrect") for \(taskType.rawValue)")
    }

    // MARK: - Analytics

    /// Get overall accuracy statistics
    public func getStatistics() -> FeedbackStatistics {
        let totalCount = feedbackHistory.count
        let correctCount = feedbackHistory.filter { $0.wasCorrect }.count
        let overallAccuracy = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0.5

        var taskTypeAccuracy: [TaskType: Double] = [:]
        for taskType in TaskType.allCases {
            let typeHistory = feedbackHistory.filter { $0.taskType == taskType }
            if !typeHistory.isEmpty {
                taskTypeAccuracy[taskType] = calculateSuccessRate(from: typeHistory)
            }
        }

        // Recent trend (last 50 responses)
        let recent = Array(feedbackHistory.suffix(50))
        let recentCorrect = recent.filter { $0.wasCorrect }.count
        let recentAccuracy = recent.isEmpty ? 0.5 : Double(recentCorrect) / Double(recent.count)

        let trend: FeedbackStatistics.Trend
        if recentAccuracy > overallAccuracy + 0.05 {
            trend = .improving
        } else if recentAccuracy < overallAccuracy - 0.05 {
            trend = .declining
        } else {
            trend = .stable
        }

        return FeedbackStatistics(
            totalResponses: totalCount,
            correctResponses: correctCount,
            overallAccuracy: overallAccuracy,
            recentAccuracy: recentAccuracy,
            trend: trend,
            taskTypeAccuracy: taskTypeAccuracy,
            correctionsProvided: feedbackHistory.filter { $0.userCorrection != nil }.count
        )
    }

    /// Get common correction patterns
    public func getCommonCorrections(for taskType: TaskType) -> [CorrectionPattern] {
        let corrections = feedbackHistory
            .filter { $0.taskType == taskType && $0.userCorrection != nil }
            .compactMap { $0.userCorrection }

        // Group similar corrections (simplified - could use AI clustering)
        var patterns: [String: Int] = [:]
        for correction in corrections {
            let key = correction.prefix(50).lowercased()
            patterns[String(key), default: 0] += 1
        }

        return patterns
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { CorrectionPattern(pattern: $0.key, frequency: $0.value) }
    }

    // MARK: - Private Methods

    private func generatePatternKey(taskType: TaskType, response: String) -> String {
        // Simple key based on task type and response characteristics
        let responseLength = response.count < 500 ? "short" : (response.count < 2000 ? "medium" : "long")
        let hasCode = response.contains("```")
        return "\(taskType.rawValue)_\(responseLength)_\(hasCode ? "code" : "nocode")"
    }

    private func calculateSuccessRate(from history: [FeedbackRecord]) -> Double {
        guard !history.isEmpty else { return 0.5 }

        var weightedSum = 0.0
        var totalWeight = 0.0

        let now = Date()
        for record in history {
            // Apply time decay
            let ageInDays = now.timeIntervalSince(record.timestamp) / 86400
            let weight = pow(decayFactor, ageInDays)

            weightedSum += (record.wasCorrect ? 1.0 : 0.0) * weight
            totalWeight += weight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0.5
    }

    // MARK: - Persistence

    private func loadHistory() async {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let container = try JSONDecoder().decode(FeedbackContainer.self, from: data)
                feedbackHistory = container.history
                patternAccuracy = container.patterns
                logger.info("Loaded \(self.feedbackHistory.count) feedback records")
            } catch {
                logger.warning("Failed to load feedback history: \(error.localizedDescription)")
            }
        }
    }

    private func saveHistory() async {
        let container = FeedbackContainer(
            history: feedbackHistory,
            patterns: patternAccuracy
        )

        do {
            let data = try JSONEncoder().encode(container)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.warning("Failed to save feedback history: \(error.localizedDescription)")
        }
    }

    /// Clear all feedback history
    public func clearHistory() async {
        feedbackHistory.removeAll()
        patternAccuracy.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        logger.info("Cleared feedback history")
    }
}

// MARK: - Supporting Types

struct FeedbackRecord: Codable, Sendable {
    let responseId: UUID
    let wasCorrect: Bool
    let userCorrection: String?
    let taskType: TaskType
    let timestamp: Date
}

struct PatternAccuracy: Codable, Sendable {
    var successRate: Double
    var sampleCount: Int
}

struct FeedbackContainer: Codable, Sendable {
    let history: [FeedbackRecord]
    let patterns: [String: PatternAccuracy]
}

public struct FeedbackAssessment: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
}

public struct FeedbackStatistics: Sendable {
    public let totalResponses: Int
    public let correctResponses: Int
    public let overallAccuracy: Double
    public let recentAccuracy: Double
    public let trend: Trend
    public let taskTypeAccuracy: [TaskType: Double]
    public let correctionsProvided: Int

    public enum Trend: String, Sendable {
        case improving = "Improving"
        case stable = "Stable"
        case declining = "Declining"
    }
}

public struct CorrectionPattern: Sendable {
    public let pattern: String
    public let frequency: Int
}
