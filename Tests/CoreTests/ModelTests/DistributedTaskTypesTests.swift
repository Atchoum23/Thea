// DistributedTaskTypesTests.swift
// Tests for DistributedTaskExecutor types — task status, routing, progress

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestTaskStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case queued
    case running
    case paused
    case completed
    case failed
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }

    var isActive: Bool {
        switch self {
        case .running, .paused: true
        default: false
        }
    }
}

private struct TestDistributedTask: Identifiable, Sendable {
    let id: String
    var status: TestTaskStatus
    var progress: Double
    var targetDeviceId: String?
    var routingScore: Double?
    var priority: TestDistributedPriority
    var retryCount: Int
    let maxRetries: Int
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var errorMessage: String?

    init(
        id: String = UUID().uuidString,
        status: TestTaskStatus = .pending,
        progress: Double = 0,
        targetDeviceId: String? = nil,
        routingScore: Double? = nil,
        priority: TestDistributedPriority = .normal,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.progress = progress
        self.targetDeviceId = targetDeviceId
        self.routingScore = routingScore
        self.priority = priority
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.createdAt = createdAt
    }

    var canRetry: Bool {
        retryCount < maxRetries && status == .failed
    }

    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    mutating func markRunning() {
        status = .running
        startedAt = Date()
    }

    mutating func markCompleted() {
        status = .completed
        completedAt = Date()
        progress = 1.0
    }

    mutating func markFailed(error: String) {
        status = .failed
        errorMessage = error
        completedAt = Date()
    }

    mutating func retry() {
        guard canRetry else { return }
        retryCount += 1
        status = .pending
        errorMessage = nil
        completedAt = nil
    }
}

private enum TestDistributedPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case low = 0
    case normal = 50
    case high = 75
    case critical = 100

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct TestTaskResult: Sendable {
    let output: String
    let metadata: [String: String]
    let executionTime: TimeInterval
    let deviceId: String

    init(output: String, metadata: [String: String] = [:],
         executionTime: TimeInterval = 0, deviceId: String = "") {
        self.output = output
        self.metadata = metadata
        self.executionTime = executionTime
        self.deviceId = deviceId
    }
}

/// Mirrors progress tracking logic
private struct TestProgressTracker {
    private var milestones: [(Double, String)] = []

    mutating func addMilestone(progress: Double, message: String) {
        milestones.append((progress, message))
    }

    var currentProgress: Double {
        milestones.last?.0 ?? 0
    }

    var currentMessage: String? {
        milestones.last?.1
    }

    var milestoneCount: Int {
        milestones.count
    }

    var isComplete: Bool {
        currentProgress >= 1.0
    }
}

// MARK: - Tests: Task Status

@Suite("Distributed Task Status")
struct DistributedTaskStatusTests {
    @Test("All 7 status cases exist")
    func allCases() {
        #expect(TestTaskStatus.allCases.count == 7)
    }

    @Test("Terminal statuses are correct")
    func terminalStatuses() {
        #expect(TestTaskStatus.completed.isTerminal)
        #expect(TestTaskStatus.failed.isTerminal)
        #expect(TestTaskStatus.cancelled.isTerminal)
        #expect(!TestTaskStatus.running.isTerminal)
        #expect(!TestTaskStatus.pending.isTerminal)
        #expect(!TestTaskStatus.queued.isTerminal)
        #expect(!TestTaskStatus.paused.isTerminal)
    }

    @Test("Active statuses are correct")
    func activeStatuses() {
        #expect(TestTaskStatus.running.isActive)
        #expect(TestTaskStatus.paused.isActive)
        #expect(!TestTaskStatus.pending.isActive)
        #expect(!TestTaskStatus.completed.isActive)
        #expect(!TestTaskStatus.failed.isActive)
    }

    @Test("All statuses have unique raw values")
    func uniqueRawValues() {
        let rawValues = TestTaskStatus.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for status in TestTaskStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TestTaskStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Tests: Task Priority

@Suite("Distributed Task Priority")
struct DistributedTaskPriorityTests {
    @Test("Priority ordering")
    func ordering() {
        #expect(TestDistributedPriority.low < .normal)
        #expect(TestDistributedPriority.normal < .high)
        #expect(TestDistributedPriority.high < .critical)
    }

    @Test("Raw values")
    func rawValues() {
        #expect(TestDistributedPriority.low.rawValue == 0)
        #expect(TestDistributedPriority.normal.rawValue == 50)
        #expect(TestDistributedPriority.high.rawValue == 75)
        #expect(TestDistributedPriority.critical.rawValue == 100)
    }

    @Test("Sorting by priority")
    func sorting() {
        let priorities: [TestDistributedPriority] = [.normal, .critical, .low, .high]
        let sorted = priorities.sorted()
        #expect(sorted == [.low, .normal, .high, .critical])
    }

    @Test("All 4 cases exist")
    func allCases() {
        #expect(TestDistributedPriority.allCases.count == 4)
    }
}

// MARK: - Tests: Distributed Task Lifecycle

@Suite("Distributed Task Lifecycle")
struct DistributedTaskLifecycleTests {
    @Test("Default task starts pending")
    func defaultStatus() {
        let task = TestDistributedTask()
        #expect(task.status == .pending)
        #expect(task.progress == 0)
        #expect(task.targetDeviceId == nil)
        #expect(task.retryCount == 0)
    }

    @Test("Mark running updates status and start time")
    func markRunning() {
        var task = TestDistributedTask()
        task.markRunning()
        #expect(task.status == .running)
        #expect(task.startedAt != nil)
    }

    @Test("Mark completed sets progress to 1.0")
    func markCompleted() {
        var task = TestDistributedTask()
        task.markRunning()
        task.markCompleted()
        #expect(task.status == .completed)
        #expect(task.progress == 1.0)
        #expect(task.completedAt != nil)
    }

    @Test("Mark failed stores error message")
    func markFailed() {
        var task = TestDistributedTask()
        task.markRunning()
        task.markFailed(error: "Network timeout")
        #expect(task.status == .failed)
        #expect(task.errorMessage == "Network timeout")
        #expect(task.completedAt != nil)
    }

    @Test("Duration calculation")
    func durationCalculation() {
        var task = TestDistributedTask()
        task.startedAt = Date().addingTimeInterval(-10)
        task.completedAt = Date()
        let duration = task.duration
        #expect(duration != nil)
        #expect(duration! >= 9.9)
        #expect(duration! <= 10.1)
    }

    @Test("Duration is nil when not started")
    func noDuration() {
        let task = TestDistributedTask()
        #expect(task.duration == nil)
    }
}

// MARK: - Tests: Retry Logic

@Suite("Distributed Task Retry")
struct DistributedTaskRetryTests {
    @Test("Can retry when failed and under max")
    func canRetryWhenFailed() {
        var task = TestDistributedTask(maxRetries: 3)
        task.status = .failed
        task.retryCount = 0
        #expect(task.canRetry)
    }

    @Test("Cannot retry when at max retries")
    func cannotRetryAtMax() {
        var task = TestDistributedTask(maxRetries: 3)
        task.status = .failed
        task.retryCount = 3
        #expect(!task.canRetry)
    }

    @Test("Cannot retry when not failed")
    func cannotRetryWhenRunning() {
        var task = TestDistributedTask(maxRetries: 3)
        task.status = .running
        task.retryCount = 0
        #expect(!task.canRetry)
    }

    @Test("Retry increments count and resets status")
    func retryResetsStatus() {
        var task = TestDistributedTask(maxRetries: 3)
        task.markRunning()
        task.markFailed(error: "timeout")
        task.retry()
        #expect(task.status == .pending)
        #expect(task.retryCount == 1)
        #expect(task.errorMessage == nil)
        #expect(task.completedAt == nil)
    }

    @Test("Multiple retries until max")
    func multipleRetries() {
        var task = TestDistributedTask(maxRetries: 2)
        // First attempt
        task.markRunning()
        task.markFailed(error: "error1")
        #expect(task.canRetry)
        task.retry()
        #expect(task.retryCount == 1)

        // Second attempt
        task.markRunning()
        task.markFailed(error: "error2")
        #expect(task.canRetry)
        task.retry()
        #expect(task.retryCount == 2)

        // Third attempt fails — no more retries
        task.markRunning()
        task.markFailed(error: "error3")
        #expect(!task.canRetry)
    }

    @Test("Retry does nothing when canRetry is false")
    func retryDoesNothingWhenNotAllowed() {
        var task = TestDistributedTask(maxRetries: 0)
        task.status = .failed
        let beforeCount = task.retryCount
        task.retry()
        #expect(task.retryCount == beforeCount) // Unchanged
        #expect(task.status == .failed) // Still failed
    }
}

// MARK: - Tests: Task Routing

@Suite("Task Routing Assignment")
struct TaskRoutingTests {
    @Test("Task assigned to device")
    func assignToDevice() {
        var task = TestDistributedTask()
        task.targetDeviceId = "mac-studio-1"
        task.routingScore = 0.95
        #expect(task.targetDeviceId == "mac-studio-1")
        #expect(task.routingScore == 0.95)
    }

    @Test("Unrouted task has nil target")
    func unrouted() {
        let task = TestDistributedTask()
        #expect(task.targetDeviceId == nil)
        #expect(task.routingScore == nil)
    }
}

// MARK: - Tests: Task Result

@Suite("Task Result")
struct TaskResultTests {
    @Test("Basic result creation")
    func basicCreation() {
        let result = TestTaskResult(output: "Success")
        #expect(result.output == "Success")
        #expect(result.metadata.isEmpty)
        #expect(result.executionTime == 0)
    }

    @Test("Result with metadata")
    func withMetadata() {
        let result = TestTaskResult(
            output: "Done",
            metadata: ["model": "claude-sonnet-4-20250514", "tokens": "1500"],
            executionTime: 2.5,
            deviceId: "mac1"
        )
        #expect(result.metadata["model"] == "claude-sonnet-4-20250514")
        #expect(result.metadata["tokens"] == "1500")
        #expect(result.executionTime == 2.5)
        #expect(result.deviceId == "mac1")
    }
}

// MARK: - Tests: Progress Tracking

@Suite("Progress Tracking")
struct ProgressTrackingTests {
    @Test("Initial progress is 0")
    func initialProgress() {
        let tracker = TestProgressTracker()
        #expect(tracker.currentProgress == 0)
        #expect(tracker.currentMessage == nil)
        #expect(tracker.milestoneCount == 0)
        #expect(!tracker.isComplete)
    }

    @Test("Adding milestones updates progress")
    func addMilestones() {
        var tracker = TestProgressTracker()
        tracker.addMilestone(progress: 0.25, message: "Loading")
        #expect(tracker.currentProgress == 0.25)
        #expect(tracker.currentMessage == "Loading")
        #expect(tracker.milestoneCount == 1)
    }

    @Test("Progress reaches 100%")
    func complete() {
        var tracker = TestProgressTracker()
        tracker.addMilestone(progress: 0.5, message: "Processing")
        tracker.addMilestone(progress: 1.0, message: "Done")
        #expect(tracker.isComplete)
        #expect(tracker.milestoneCount == 2)
    }

    @Test("Progress history preserved")
    func historyPreserved() {
        var tracker = TestProgressTracker()
        tracker.addMilestone(progress: 0.1, message: "Start")
        tracker.addMilestone(progress: 0.5, message: "Middle")
        tracker.addMilestone(progress: 0.9, message: "Almost")
        #expect(tracker.milestoneCount == 3)
        #expect(tracker.currentProgress == 0.9)
        #expect(tracker.currentMessage == "Almost")
    }
}

// MARK: - Tests: Task Priority Queue

@Suite("Priority Queue Ordering")
struct PriorityQueueTests {
    @Test("Tasks sorted by priority descending")
    func sortedByPriority() {
        let tasks = [
            TestDistributedTask(id: "low", priority: .low),
            TestDistributedTask(id: "critical", priority: .critical),
            TestDistributedTask(id: "normal", priority: .normal),
            TestDistributedTask(id: "high", priority: .high)
        ]
        let sorted = tasks.sorted { $0.priority > $1.priority }
        #expect(sorted[0].id == "critical")
        #expect(sorted[1].id == "high")
        #expect(sorted[2].id == "normal")
        #expect(sorted[3].id == "low")
    }

    @Test("Same priority ordered by creation time")
    func samePriorityByTime() {
        let now = Date()
        let tasks = [
            TestDistributedTask(id: "newer", priority: .normal, createdAt: now),
            TestDistributedTask(id: "older", priority: .normal, createdAt: now.addingTimeInterval(-100))
        ]
        let sorted = tasks.sorted {
            if $0.priority == $1.priority {
                return $0.createdAt < $1.createdAt // FIFO for same priority
            }
            return $0.priority > $1.priority
        }
        #expect(sorted[0].id == "older") // Older first (FIFO)
    }
}

// MARK: - Tests: Active Task Filtering

@Suite("Active Task Filtering")
struct ActiveTaskFilteringTests {
    @Test("Filter active tasks")
    func filterActive() {
        var tasks = [
            TestDistributedTask(id: "a", status: .running),
            TestDistributedTask(id: "b", status: .completed),
            TestDistributedTask(id: "c", status: .paused),
            TestDistributedTask(id: "d", status: .failed),
            TestDistributedTask(id: "e", status: .pending)
        ]
        // Directly set status for convenience
        tasks[0].status = .running
        tasks[1].status = .completed
        tasks[2].status = .paused
        tasks[3].status = .failed
        tasks[4].status = .pending

        let active = tasks.filter { $0.status.isActive }
        #expect(active.count == 2)

        let terminal = tasks.filter { $0.status.isTerminal }
        #expect(terminal.count == 2)

        let pending = tasks.filter { $0.status == .pending }
        #expect(pending.count == 1)
    }
}
