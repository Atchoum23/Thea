//
//  PredictivePreloader.swift
//  Thea
//
//  Predicts upcoming model needs using learned Markov chains of user behavior.
//  Enables proactive model loading before user requests.
//
//  ALGORITHM:
//  1. Tracks task type transitions (what task follows what)
//  2. Builds probability matrix of task sequences
//  3. Uses time-of-day patterns for contextual prediction
//  4. Applies Exponential Moving Average for recency weighting
//
//  LAYOUT (split across files for single-responsibility):
//  - PredictivePreloader.swift — core state, recording, prediction
//  - PredictivePreloader+SequenceAnalysis.swift — sequence detection & matching
//  - PredictivePreloader+Statistics.swift — stats, persistence, reset
//  - PredictivePreloader+UIConfiguration.swift — time-based UI config & time blocks
//  - PredictivePreloader+Types.swift — all supporting data types and enums
//
//  CREATED: February 5, 2026
//

import Foundation
import OSLog

// MARK: - Predictive Preloader

/// Predicts upcoming model needs using learned behavior patterns.
///
/// Maintains a Markov chain transition matrix of task-type sequences and
/// time-of-day usage patterns. Combines both signals (60/40 weighting) to
/// produce ranked predictions of what the user will request next.
///
/// State is persisted to `UserDefaults` and restored on init, so learning
/// accumulates across app launches.
// @unchecked Sendable: mutable state (transitionMatrix, hourlyDistribution) only accessed from single Task context
final class PredictivePreloader: @unchecked Sendable {
    let logger = Logger(subsystem: "ai.thea.app", category: "PredictivePreloader")

    // MARK: - State

    /// Markov chain transition matrix: `[fromTask][toTask] = count`.
    /// Counts are normalized to probabilities at query time.
    var transitionMatrix: [TaskType: [TaskType: Double]] = [:]

    /// Time-of-day task distribution: `[hour][taskType] = count`.
    var timeOfDayPatterns: [Int: [TaskType: Double]] = [:] // Hour -> TaskType -> Count

    /// Recent task history (for recency weighting and sequence analysis).
    var recentTasks: [TaskTypeTimestamp] = []

    /// EMA alpha for recency weighting (higher = more weight to recent observations).
    let emaAlpha: Double = 0.3

    /// Maximum number of tasks retained in history.
    let maxHistorySize = 500

    /// UserDefaults key for persisting the transition matrix.
    let transitionMatrixKey = "PredictivePreloader.transitionMatrix"
    /// UserDefaults key for persisting time-of-day patterns.
    let timeOfDayPatternsKey = "PredictivePreloader.timeOfDayPatterns"
    /// UserDefaults key for persisting recent task history.
    let recentTasksKey = "PredictivePreloader.recentTasks"

    // MARK: - Initialization

    init() {
        loadPersistedState()
    }

    // MARK: - Recording

    /// Record a task request for learning.
    ///
    /// Updates the Markov transition matrix, time-of-day patterns, and task history.
    /// Persistence is triggered every 10 recordings to balance durability with
    /// write frequency.
    ///
    /// - Parameter taskType: The type of task the user just requested.
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

    /// Update the transition matrix with a new from-to observation.
    ///
    /// Increments the count for the observed transition and applies EMA decay
    /// to other transitions from the same source state, ensuring recent patterns
    /// are weighted more heavily.
    ///
    /// - Parameters:
    ///   - from: The task type that preceded the current one.
    ///   - to: The task type just observed.
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

    /// Update time-of-day patterns with a new observation.
    ///
    /// - Parameters:
    ///   - hour: The hour (0-23) when the task was requested.
    ///   - taskType: The type of task requested.
    private func updateTimeOfDayPattern(hour: Int, taskType: TaskType) {
        if timeOfDayPatterns[hour] == nil {
            timeOfDayPatterns[hour] = [:]
        }

        let currentCount = timeOfDayPatterns[hour]?[taskType] ?? 0
        timeOfDayPatterns[hour]?[taskType] = currentCount + 1.0
    }

    // MARK: - Prediction

    /// Predict the next likely tasks based on current state.
    ///
    /// Combines Markov chain transition probabilities (60% weight) with
    /// time-of-day usage patterns (40% weight), applies a recency boost
    /// for recently-used task types, and filters out low-probability results.
    ///
    /// - Returns: An array of ``TaskPrediction`` sorted by probability (descending).
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

    /// Determine which prediction source contributed most to a result.
    ///
    /// - Parameters:
    ///   - markov: The Markov chain probability component, if any.
    ///   - tod: The time-of-day probability component, if any.
    /// - Returns: The dominant ``PredictionSource``.
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

    /// Get the transition probability between two specific task types.
    ///
    /// - Parameters:
    ///   - from: The source task type.
    ///   - to: The destination task type.
    /// - Returns: The normalized probability in the range `0.0...1.0`, or `0.0` if no data.
    func getTransitionProbability(from: TaskType, to: TaskType) -> Double {
        guard let transitions = transitionMatrix[from] else { return 0.0 }
        let totalCount = transitions.values.reduce(0, +)
        guard totalCount > 0 else { return 0.0 }
        return (transitions[to] ?? 0) / totalCount
    }

    /// Get the most likely next task after a given task type.
    ///
    /// - Parameter task: The task type to look up transitions from.
    /// - Returns: The task type with the highest transition count, or `nil` if no data.
    func getMostLikelyNextTask(after task: TaskType) -> TaskType? {
        guard let transitions = transitionMatrix[task] else { return nil }
        return transitions.max { $0.value < $1.value }?.key
    }
}
