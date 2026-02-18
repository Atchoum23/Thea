//
//  PredictivePreloader.swift
//  Thea
//
//  Predicts upcoming model needs using learned Markov chains of user behavior
//  Enables proactive model loading before user requests
//
//  ALGORITHM:
//  1. Tracks task type transitions (what task follows what)
//  2. Builds probability matrix of task sequences
//  3. Uses time-of-day patterns for contextual prediction
//  4. Applies Exponential Moving Average for recency weighting
//
//  CREATED: February 5, 2026
//

import Foundation
import OSLog

// MARK: - Predictive Preloader

// @unchecked Sendable: mutable Markov chain state (transitionMatrix, timeOfDayPatterns) is owned
// by a single PredictiveModelManager instance and accessed on its serial DispatchQueue
/// Predicts upcoming model needs using learned behavior patterns
final class PredictivePreloader: @unchecked Sendable {
    let logger = Logger(subsystem: "ai.thea.app", category: "PredictivePreloader")

    // MARK: - State

    /// Markov chain transition matrix: [fromTask][toTask] = probability
    var transitionMatrix: [TaskType: [TaskType: Double]] = [:]

    /// Time-of-day task distribution
    var timeOfDayPatterns: [Int: [TaskType: Double]] = [:] // Hour -> TaskType -> Probability

    /// Recent task history (for recency weighting)
    var recentTasks: [TaskTypeTimestamp] = []

    /// EMA alpha for recency weighting (higher = more weight to recent)
    let emaAlpha: Double = 0.3

    /// Maximum history size
    let maxHistorySize = 500

    /// Persistence keys
    let transitionMatrixKey = "PredictivePreloader.transitionMatrix"
    let timeOfDayPatternsKey = "PredictivePreloader.timeOfDayPatterns"
    let recentTasksKey = "PredictivePreloader.recentTasks"

    // MARK: - Initialization

    init() {
        loadPersistedState()
    }

    // MARK: - Recording

    /// Record a task request for learning
    func recordTaskRequest(_ taskType: TaskType) {
        let timestamp = Date()
        let hour = Calendar.current.component(.hour, from: timestamp)

        // Record in history
        let record = TaskTypeTimestamp(taskType: taskType, timestamp: timestamp)
        recentTasks.append(record)

        // Trim history if needed
        if recentTasks.count > maxHistorySize {
            recentTasks.removeFirst(recentTasks.count - maxHistorySize)
        }

        // Update transition matrix with previous task
        if recentTasks.count >= 2 {
            let previousTask = recentTasks[recentTasks.count - 2].taskType
            updateTransitionMatrix(from: previousTask, to: taskType)
        }

        // Update time-of-day patterns
        updateTimeOfDayPattern(hour: hour, taskType: taskType)

        // Persist periodically
        if recentTasks.count % 10 == 0 {
            persistState()
        }

        logger.debug("Recorded task: \(taskType.rawValue) at hour \(hour)")
    }

    /// Update transition matrix with new observation
    private func updateTransitionMatrix(from: TaskType, to: TaskType) {
        // Initialize if needed
        if transitionMatrix[from] == nil {
            transitionMatrix[from] = [:]
        }

        // Get current count (we store counts, then normalize for probability)
        let currentCount = transitionMatrix[from]?[to] ?? 0

        // Apply EMA update: new_value = alpha * 1.0 + (1 - alpha) * old_value
        // Since we're counting occurrences, we increment and apply decay to others
        transitionMatrix[from]?[to] = currentCount + 1.0

        // Apply decay to other transitions from this state
        for otherTask in TaskType.allCases where otherTask != to {
            if let count = transitionMatrix[from]?[otherTask], count > 0 {
                transitionMatrix[from]?[otherTask] = count * (1 - emaAlpha * 0.1)
            }
        }
    }

    /// Update time-of-day patterns
    private func updateTimeOfDayPattern(hour: Int, taskType: TaskType) {
        if timeOfDayPatterns[hour] == nil {
            timeOfDayPatterns[hour] = [:]
        }

        let currentCount = timeOfDayPatterns[hour]?[taskType] ?? 0
        timeOfDayPatterns[hour]?[taskType] = currentCount + 1.0
    }

    // MARK: - Prediction

    /// Predict next likely tasks based on current state
    func predictNextTasks() -> [TaskPrediction] {
        let currentHour = Calendar.current.component(.hour, from: Date())
        var predictions: [TaskPrediction] = []

        // Get last task for Markov prediction
        let lastTask = recentTasks.last?.taskType

        // 1. Markov chain predictions (60% weight)
        var markovPredictions: [TaskType: Double] = [:]
        if let lastTask = lastTask, let transitions = transitionMatrix[lastTask] {
            let totalCount = transitions.values.reduce(0, +)
            if totalCount > 0 {
                for (task, count) in transitions {
                    markovPredictions[task] = count / totalCount
                }
            }
        }

        // 2. Time-of-day predictions (40% weight)
        var todPredictions: [TaskType: Double] = [:]
        if let hourPatterns = timeOfDayPatterns[currentHour] {
            let totalCount = hourPatterns.values.reduce(0, +)
            if totalCount > 0 {
                for (task, count) in hourPatterns {
                    todPredictions[task] = count / totalCount
                }
            }
        }

        // Combine predictions
        var combinedScores: [TaskType: Double] = [:]
        for task in TaskType.allCases {
            let markovScore = markovPredictions[task] ?? 0.0
            let todScore = todPredictions[task] ?? 0.0
            combinedScores[task] = (markovScore * 0.6) + (todScore * 0.4)
        }

        // Apply recency boost for recently used task types
        let recentTaskTypes = Set(recentTasks.suffix(5).map { $0.taskType })
        for task in recentTaskTypes {
            combinedScores[task] = (combinedScores[task] ?? 0) * 1.1
        }

        // Convert to predictions array
        for (task, score) in combinedScores where score > 0.05 {
            predictions.append(TaskPrediction(
                taskType: task,
                probability: min(1.0, score),
                source: determineSource(markov: markovPredictions[task], tod: todPredictions[task])
            ))
        }

        // Sort by probability
        predictions.sort { $0.probability > $1.probability }

        return predictions
    }

    /// Determine prediction source
    private func determineSource(markov: Double?, tod: Double?) -> PredictionSource {
        let m = markov ?? 0
        let t = tod ?? 0

        if m > t * 1.5 {
            return .markovChain
        } else if t > m * 1.5 {
            return .timeOfDay
        }
        return .combined
    }

    /// Get transition probability between two tasks
    func getTransitionProbability(from: TaskType, to: TaskType) -> Double {
        guard let transitions = transitionMatrix[from] else { return 0.0 }
        let totalCount = transitions.values.reduce(0, +)
        guard totalCount > 0 else { return 0.0 }
        return (transitions[to] ?? 0) / totalCount
    }

    /// Get most likely next task after a given task
    func getMostLikelyNextTask(after task: TaskType) -> TaskType? {
        guard let transitions = transitionMatrix[task] else { return nil }
        return transitions.max { $0.value < $1.value }?.key
    }

}
