//
//  PredictivePreloader+SequenceAnalysis.swift
//  Thea
//
//  Sequence detection and pattern matching for PredictivePreloader.
//  Uses sliding-window analysis over task history to discover recurring
//  multi-step workflows the user follows repeatedly.
//
//  Split from PredictivePreloader.swift for single-responsibility clarity.
//

import Foundation

// MARK: - Sequence Analysis

extension PredictivePreloader {

    /// Detect common task sequences using sliding-window analysis over the task history.
    ///
    /// Scans the recent task history for repeating sub-sequences of length `minLength`
    /// through `maxLength`. Only sequences occurring at least 3 times are returned.
    ///
    /// - Parameters:
    ///   - minLength: Minimum number of tasks in a sequence. Defaults to 2.
    ///   - maxLength: Maximum number of tasks in a sequence. Defaults to 4.
    /// - Returns: An array of ``TaskSequence`` sorted by occurrence count (descending).
    func detectCommonSequences(minLength: Int = 2, maxLength: Int = 4) -> [TaskSequence] {
        guard recentTasks.count >= minLength else { return [] }

        var sequences: [String: Int] = [:] // sequence_key -> count

        // Sliding window to find sequences
        for length in minLength...maxLength {
            for i in 0...(recentTasks.count - length) {
                let sequence = Array(recentTasks[i..<(i + length)]).map { $0.taskType }
                let key = sequence.map { $0.rawValue }.joined(separator: "->")
                sequences[key, default: 0] += 1
            }
        }

        // Filter for sequences that occur multiple times
        var result: [TaskSequence] = []
        for (key, count) in sequences where count >= 3 {
            let taskNames = key.split(separator: "->").map(String.init)
            let tasks = taskNames.compactMap { TaskType(rawValue: $0) }
            if tasks.count == taskNames.count {
                result.append(TaskSequence(
                    tasks: tasks,
                    occurrences: count,
                    probability: Double(count) / Double(recentTasks.count - tasks.count + 1)
                ))
            }
        }

        result.sort { $0.occurrences > $1.occurrences }
        return result
    }

    /// Check if the most recent tasks match the beginning of a known sequence.
    ///
    /// Compares the last few tasks against all detected common sequences. If the
    /// recent history matches the prefix of a longer sequence, that sequence is
    /// returned — enabling the caller to predict what comes next.
    ///
    /// - Returns: The matching ``TaskSequence`` if found, or `nil` if no match.
    func matchesSequenceStart() -> TaskSequence? {
        let sequences = detectCommonSequences()
        let recentTaskTypes = recentTasks.suffix(3).map { $0.taskType }

        for sequence in sequences {
            if sequence.tasks.count > recentTaskTypes.count {
                let prefix = Array(sequence.tasks.prefix(recentTaskTypes.count))
                if prefix == recentTaskTypes {
                    return sequence
                }
            }
        }
        return nil
    }
}
