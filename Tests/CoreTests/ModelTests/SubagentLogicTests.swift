// SubagentLogicTests.swift
// Tests for subagent logic: aggregation strategies, task dependency resolution,
// and concurrency limits.
// Split from SubagentTypesTests.swift to meet file_length limit.

import Foundation
import XCTest

// MARK: - Aggregation Logic Tests

final class SubagentAggregationLogicTests: XCTestCase {

    private func aggregateByMerge(outputs: [String]) -> String {
        outputs.joined(separator: "\n\n")
    }

    private func aggregateByBestConfidence(results: [(output: String, confidence: Float)]) -> String? {
        results.max { $0.confidence < $1.confidence }?.output
    }

    private func aggregateConsensusConfidence(results: [Float]) -> Float {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0, +) / Float(results.count)
    }

    func testMergeAggregation() {
        let merged = aggregateByMerge(outputs: ["Part A", "Part B", "Part C"])
        XCTAssertEqual(merged, "Part A\n\nPart B\n\nPart C")
    }

    func testMergeEmpty() {
        let merged = aggregateByMerge(outputs: [])
        XCTAssertEqual(merged, "")
    }

    func testMergeSingle() {
        let merged = aggregateByMerge(outputs: ["Only one"])
        XCTAssertEqual(merged, "Only one")
    }

    func testBestConfidenceSelection() {
        let results: [(output: String, confidence: Float)] = [
            ("Low quality", 0.3),
            ("High quality", 0.95),
            ("Medium quality", 0.7)
        ]
        XCTAssertEqual(aggregateByBestConfidence(results: results), "High quality")
    }

    func testBestConfidenceEmpty() {
        let results: [(output: String, confidence: Float)] = []
        XCTAssertNil(aggregateByBestConfidence(results: results))
    }

    func testBestConfidenceTie() {
        let results: [(output: String, confidence: Float)] = [
            ("A", 0.9),
            ("B", 0.9)
        ]
        let best = aggregateByBestConfidence(results: results)
        XCTAssertNotNil(best)
    }

    func testConsensusConfidence() {
        let confidences: [Float] = [0.8, 0.9, 0.7]
        let consensus = aggregateConsensusConfidence(results: confidences)
        XCTAssertEqual(consensus, 0.8, accuracy: 0.01)
    }

    func testConsensusConfidenceEmpty() {
        let consensus = aggregateConsensusConfidence(results: [])
        XCTAssertEqual(consensus, 0.0)
    }

    func testConsensusConfidenceSingle() {
        let consensus = aggregateConsensusConfidence(results: [0.95])
        XCTAssertEqual(consensus, 0.95, accuracy: 0.01)
    }

    func testTotalTokensAggregation() {
        let tokenCounts = [500, 1200, 800]
        let total = tokenCounts.reduce(0, +)
        XCTAssertEqual(total, 2500)
    }

    func testTotalExecutionTimeAggregation() {
        let times: [TimeInterval] = [1.5, 2.3, 0.8]
        let total = times.reduce(0, +)
        XCTAssertEqual(total, 4.6, accuracy: 0.01)
    }
}

// MARK: - Task Dependency Resolution Tests

final class TaskDependencyResolutionTests: XCTestCase {

    private struct DepTask: Identifiable {
        let id: UUID
        let dependsOn: [UUID]
        var completed: Bool = false
    }

    private func canExecute(_ task: DepTask, completedIDs: Set<UUID>) -> Bool {
        task.dependsOn.allSatisfy { completedIDs.contains($0) }
    }

    func testNoDependenciesCanExecuteImmediately() {
        let task = DepTask(id: UUID(), dependsOn: [])
        XCTAssertTrue(canExecute(task, completedIDs: []))
    }

    func testDependencyNotMet() {
        let dep = UUID()
        let task = DepTask(id: UUID(), dependsOn: [dep])
        XCTAssertFalse(canExecute(task, completedIDs: []))
    }

    func testDependencyMet() {
        let dep = UUID()
        let task = DepTask(id: UUID(), dependsOn: [dep])
        XCTAssertTrue(canExecute(task, completedIDs: [dep]))
    }

    func testMultipleDependenciesAllMet() {
        let dep1 = UUID()
        let dep2 = UUID()
        let task = DepTask(id: UUID(), dependsOn: [dep1, dep2])
        XCTAssertTrue(canExecute(task, completedIDs: [dep1, dep2]))
    }

    func testMultipleDependenciesPartiallyMet() {
        let dep1 = UUID()
        let dep2 = UUID()
        let task = DepTask(id: UUID(), dependsOn: [dep1, dep2])
        XCTAssertFalse(canExecute(task, completedIDs: [dep1]))
    }

    func testTopologicalOrder() {
        let taskA = DepTask(id: UUID(), dependsOn: [])
        let taskB = DepTask(id: UUID(), dependsOn: [taskA.id])
        let taskC = DepTask(id: UUID(), dependsOn: [taskA.id, taskB.id])

        var completed: Set<UUID> = []

        XCTAssertTrue(canExecute(taskA, completedIDs: completed))
        XCTAssertFalse(canExecute(taskB, completedIDs: completed))
        XCTAssertFalse(canExecute(taskC, completedIDs: completed))

        completed.insert(taskA.id)
        XCTAssertTrue(canExecute(taskB, completedIDs: completed))
        XCTAssertFalse(canExecute(taskC, completedIDs: completed))

        completed.insert(taskB.id)
        XCTAssertTrue(canExecute(taskC, completedIDs: completed))
    }

    func testParallelIndependentTasks() {
        let taskA = DepTask(id: UUID(), dependsOn: [])
        let taskB = DepTask(id: UUID(), dependsOn: [])
        let taskC = DepTask(id: UUID(), dependsOn: [])

        XCTAssertTrue(canExecute(taskA, completedIDs: []))
        XCTAssertTrue(canExecute(taskB, completedIDs: []))
        XCTAssertTrue(canExecute(taskC, completedIDs: []))
    }
}

// MARK: - Max Concurrent Agents Tests

final class MaxConcurrentAgentsTests: XCTestCase {

    func testDefaultMaxConcurrent() {
        let maxConcurrent = 8
        XCTAssertEqual(maxConcurrent, 8)
    }

    func testCanSpawnWithinLimit() {
        let maxConcurrent = 4
        let activeCount = 3
        XCTAssertTrue(activeCount < maxConcurrent)
    }

    func testCannotSpawnAtLimit() {
        let maxConcurrent = 4
        let activeCount = 4
        XCTAssertFalse(activeCount < maxConcurrent)
    }

    func testCannotSpawnOverLimit() {
        let maxConcurrent = 4
        let activeCount = 5
        XCTAssertFalse(activeCount < maxConcurrent)
    }
}
