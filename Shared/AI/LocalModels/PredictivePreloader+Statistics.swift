//
//  PredictivePreloader+Statistics.swift
//  Thea
//
//  Prediction statistics, state persistence, and reset for PredictivePreloader.
//  Handles UserDefaults serialization of the Markov matrix, time-of-day patterns,
//  and task history.
//
//  Split from PredictivePreloader.swift for single-responsibility clarity.
//

import Foundation

// MARK: - Statistics

extension PredictivePreloader {

    /// Compute aggregate statistics about the prediction engine's learned state.
    ///
    /// Includes task counts, transition diversity, data coverage by hour, and
    /// Shannon entropy as a measure of user behavior predictability.
    ///
    /// - Returns: A ``PredictionStats`` snapshot of the current state.
    func getPredictionStats() -> PredictionStats {
        var taskCounts: [TaskType: Int] = [:]
        for record in recentTasks {
            taskCounts[record.taskType, default: 0] += 1
        }

        let totalTasks = recentTasks.count
        let uniqueTransitions = transitionMatrix.values.reduce(0) { $0 + $1.count }
        let hoursWithData = timeOfDayPatterns.count

        // Calculate entropy (uncertainty measure)
        var entropy: Double = 0
        if totalTasks > 0 {
            for (_, count) in taskCounts {
                let p = Double(count) / Double(totalTasks)
                if p > 0 {
                    entropy -= p * log2(p)
                }
            }
        }

        return PredictionStats(
            totalTasksRecorded: totalTasks,
            uniqueTaskTypes: taskCounts.count,
            uniqueTransitions: uniqueTransitions,
            hoursWithData: hoursWithData,
            entropy: entropy,
            mostFrequentTask: taskCounts.max { $0.value < $1.value }?.key
        )
    }
}

// MARK: - Persistence

extension PredictivePreloader {

    /// Load previously persisted state from UserDefaults.
    ///
    /// Restores the transition matrix, time-of-day patterns, and recent task history.
    /// Called during `init()` to resume learning across app launches.
    func loadPersistedState() {
        // Load transition matrix
        if let data = UserDefaults.standard.data(forKey: transitionMatrixKey),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) { // Safe: corrupt cache → start with empty Markov matrix; learns from scratch
            // Convert string keys back to TaskType
            for (fromKey, toDict) in decoded {
                if let fromTask = TaskType(rawValue: fromKey) {
                    transitionMatrix[fromTask] = [:]
                    for (toKey, value) in toDict {
                        if let toTask = TaskType(rawValue: toKey) {
                            transitionMatrix[fromTask]?[toTask] = value
                        }
                    }
                }
            }
        }

        // Load time-of-day patterns
        if let data = UserDefaults.standard.data(forKey: timeOfDayPatternsKey),
           let decoded = try? JSONDecoder().decode([Int: [String: Double]].self, from: data) { // Safe: corrupt cache → start with empty time-of-day patterns; learns from scratch
            for (hour, taskDict) in decoded {
                timeOfDayPatterns[hour] = [:]
                for (taskKey, value) in taskDict {
                    if let task = TaskType(rawValue: taskKey) {
                        timeOfDayPatterns[hour]?[task] = value
                    }
                }
            }
        }

        // Load recent tasks
        if let data = UserDefaults.standard.data(forKey: recentTasksKey),
           let decoded = try? JSONDecoder().decode([TaskTypeTimestamp].self, from: data) { // Safe: corrupt cache → start with empty task history; learns from current session
            recentTasks = decoded
        }

        logger.debug("Loaded prediction state: \(self.recentTasks.count) tasks, \(self.transitionMatrix.count) transition states")
    }

    /// Persist current state to UserDefaults.
    ///
    /// Serializes the transition matrix, time-of-day patterns, and recent task history
    /// using JSON encoding with string keys (since `TaskType` is not directly JSON-key-codable).
    /// Called periodically (every 10 task recordings) and on reset.
    func persistState() {
        // Convert transition matrix to string keys for JSON encoding
        var encodableMatrix: [String: [String: Double]] = [:]
        for (fromTask, toDict) in transitionMatrix {
            encodableMatrix[fromTask.rawValue] = [:]
            for (toTask, value) in toDict {
                encodableMatrix[fromTask.rawValue]?[toTask.rawValue] = value
            }
        }
        if let data = try? JSONEncoder().encode(encodableMatrix) { // Safe: encode failure → matrix not persisted this cycle; in-memory learning continues
            UserDefaults.standard.set(data, forKey: transitionMatrixKey)
        }

        // Convert time-of-day patterns
        var encodableToD: [Int: [String: Double]] = [:]
        for (hour, taskDict) in timeOfDayPatterns {
            encodableToD[hour] = [:]
            for (task, value) in taskDict {
                encodableToD[hour]?[task.rawValue] = value
            }
        }
        if let data = try? JSONEncoder().encode(encodableToD) { // Safe: encode failure → time-of-day patterns not persisted; in-memory learning continues
            UserDefaults.standard.set(data, forKey: timeOfDayPatternsKey)
        }

        // Save recent tasks
        if let data = try? JSONEncoder().encode(recentTasks) { // Safe: encode failure → recent task history not persisted; in-memory queue intact
            UserDefaults.standard.set(data, forKey: recentTasksKey)
        }
    }

    /// Clear all learned data and persist the empty state.
    ///
    /// Removes the transition matrix, time-of-day patterns, and task history.
    /// The engine will begin learning from scratch after this call.
    func reset() {
        transitionMatrix.removeAll()
        timeOfDayPatterns.removeAll()
        recentTasks.removeAll()
        persistState()
        logger.info("Prediction data reset")
    }
}
