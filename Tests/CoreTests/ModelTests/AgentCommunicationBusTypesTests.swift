// AgentCommunicationBusTypesTests.swift
// Tests for AgentCommunicationBus value types: BusAgentMessage, BusAgentMessageType,
// BusAgentMessagePayload, BusMessagePriority, BusAgentMessageFilter logic.

import Foundation
import XCTest

// MARK: - Mirrored: BusAgentMessageType

private enum TestBusMessageType: String, Codable, CaseIterable {
    case dataShare
    case requestHelp
    case provideHelp
    case statusUpdate
    case coordinationRequest
    case taskHandoff
    case errorNotification
    case completionSignal
    case dependencyMet
    case resourceRequest
    case resourceGrant
}

// MARK: - Mirrored: BusMessagePriority

private enum TestBusPriority: Int, Comparable, CaseIterable {
    case low = 0
    case normal = 50
    case high = 75
    case critical = 100

    static func < (lhs: TestBusPriority, rhs: TestBusPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Mirrored: AgentTaskResult

private struct TestAgentTaskResult {
    let taskId: UUID
    let output: String
    let success: Bool
    let metadata: [String: String]

    init(taskId: UUID, output: String, success: Bool, metadata: [String: String] = [:]) {
        self.taskId = taskId
        self.output = output
        self.success = success
        self.metadata = metadata
    }
}

// MARK: - Mirrored: AgentError

private struct TestAgentError {
    let code: String
    let message: String
    let isRecoverable: Bool

    init(code: String, message: String, isRecoverable: Bool = true) {
        self.code = code
        self.message = message
        self.isRecoverable = isRecoverable
    }
}

// MARK: - Mirrored: DependencyInfo

private struct TestDependencyInfo {
    let dependencyId: UUID
    let dependencyType: String
    let value: String?

    init(dependencyId: UUID, dependencyType: String, value: String? = nil) {
        self.dependencyId = dependencyId
        self.dependencyType = dependencyType
        self.value = value
    }
}

// MARK: - Mirrored: ResourceInfo

private struct TestResourceInfo {
    let resourceId: String
    let resourceType: String
    let status: String
}

// MARK: - Mirrored: BusAgentMessagePayload

private enum TestBusPayload {
    case text(String)
    case data([String: String])
    case result(TestAgentTaskResult)
    case error(TestAgentError)
    case dependency(TestDependencyInfo)
    case resource(TestResourceInfo)
}

// MARK: - Mirrored: BusAgentMessage

private struct TestBusMessage: Identifiable {
    let id: UUID
    let timestamp: Date
    let senderAgentId: UUID
    let recipientAgentId: UUID?
    let messageType: TestBusMessageType
    let payload: TestBusPayload
    let priority: TestBusPriority
    let correlationId: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        senderAgentId: UUID,
        recipientAgentId: UUID? = nil,
        messageType: TestBusMessageType,
        payload: TestBusPayload,
        priority: TestBusPriority = .normal,
        correlationId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.senderAgentId = senderAgentId
        self.recipientAgentId = recipientAgentId
        self.messageType = messageType
        self.payload = payload
        self.priority = priority
        self.correlationId = correlationId
    }

    var isBroadcast: Bool { recipientAgentId == nil }
    var isDirectMessage: Bool { recipientAgentId != nil }
}

// MARK: - Mirrored: BusAgentMessageFilter

private struct TestBusFilter {
    let messageTypes: Set<TestBusMessageType>?
    let priorities: Set<TestBusPriority>?
    let senderIds: Set<UUID>?
    let excludeSenderIds: Set<UUID>?

    init(
        messageTypes: Set<TestBusMessageType>? = nil,
        priorities: Set<TestBusPriority>? = nil,
        senderIds: Set<UUID>? = nil,
        excludeSenderIds: Set<UUID>? = nil
    ) {
        self.messageTypes = messageTypes
        self.priorities = priorities
        self.senderIds = senderIds
        self.excludeSenderIds = excludeSenderIds
    }

    static let all = TestBusFilter()

    static let highPriority = TestBusFilter(priorities: [.high, .critical])

    static let dataOnly = TestBusFilter(messageTypes: [.dataShare, .completionSignal])

    static let coordination = TestBusFilter(
        messageTypes: [.coordinationRequest, .taskHandoff, .dependencyMet, .resourceRequest, .resourceGrant]
    )

    func matches(_ message: TestBusMessage) -> Bool {
        if let types = messageTypes, !types.contains(message.messageType) {
            return false
        }
        if let priorities = priorities, !priorities.contains(message.priority) {
            return false
        }
        if let senders = senderIds, !senders.contains(message.senderAgentId) {
            return false
        }
        if let excludes = excludeSenderIds, excludes.contains(message.senderAgentId) {
            return false
        }
        return true
    }

    var description: String {
        var parts: [String] = []
        if let types = messageTypes {
            parts.append("types:\(types.map(\.rawValue).joined(separator: ","))")
        }
        if let priorities = priorities {
            parts.append("priorities:\(priorities.map { String($0.rawValue) }.joined(separator: ","))")
        }
        if senderIds != nil { parts.append("whitelist") }
        if excludeSenderIds != nil { parts.append("blacklist") }
        return parts.isEmpty ? "all" : parts.joined(separator: " ")
    }
}

// MARK: - Mirrored: Message History Manager

private class TestMessageHistory {
    private var messages: [TestBusMessage] = []
    private let maxSize: Int

    init(maxSize: Int = 1000) {
        self.maxSize = maxSize
    }

    func append(_ message: TestBusMessage) {
        messages.append(message)
        if messages.count > maxSize {
            messages.removeFirst(messages.count - maxSize)
        }
    }

    var count: Int { messages.count }

    func getRecent(filter: TestBusFilter = .all, limit: Int = 100) -> [TestBusMessage] {
        messages
            .filter { filter.matches($0) }
            .suffix(limit)
            .reversed()
    }
}

// MARK: - Mirrored: Correlation Group Tracker

private class TestCorrelationTracker {
    private var groups: [UUID: [TestBusMessage]] = [:]

    func track(_ message: TestBusMessage) {
        guard let correlationId = message.correlationId else { return }
        var group = groups[correlationId] ?? []
        group.append(message)
        groups[correlationId] = group
    }

    func getGroup(_ correlationId: UUID) -> [TestBusMessage] {
        groups[correlationId] ?? []
    }

    func cleanup(olderThan cutoff: Date) -> Int {
        var removed = 0
        var toRemove: [UUID] = []
        for (id, msgs) in groups {
            if let last = msgs.last, last.timestamp < cutoff {
                toRemove.append(id)
            }
        }
        for id in toRemove {
            groups.removeValue(forKey: id)
            removed += 1
        }
        return removed
    }

    var groupCount: Int { groups.count }
}

// MARK: - Mirrored: Pending Message Queue

private class TestPendingQueue {
    private var pending: [UUID: [TestBusMessage]] = [:]
    private let maxPerAgent: Int

    init(maxPerAgent: Int = 100) {
        self.maxPerAgent = maxPerAgent
    }

    func enqueue(_ message: TestBusMessage, for agentId: UUID) {
        var queue = pending[agentId] ?? []
        queue.append(message)
        if queue.count > maxPerAgent {
            queue.removeFirst(queue.count - maxPerAgent)
        }
        pending[agentId] = queue
    }

    func dequeue(for agentId: UUID) -> [TestBusMessage] {
        let msgs = pending[agentId] ?? []
        pending[agentId] = nil
        return msgs
    }

    func count(for agentId: UUID) -> Int {
        pending[agentId]?.count ?? 0
    }
}

// MARK: - Tests

final class AgentCommunicationBusTypesTests: XCTestCase {

    // MARK: - BusAgentMessageType Tests

    func testAllMessageTypesExist() {
        XCTAssertEqual(TestBusMessageType.allCases.count, 11)
    }

    func testMessageTypeRawValuesUnique() {
        let rawValues = TestBusMessageType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testMessageTypeCodableRoundtrip() throws {
        for messageType in TestBusMessageType.allCases {
            let data = try JSONEncoder().encode(messageType)
            let decoded = try JSONDecoder().decode(TestBusMessageType.self, from: data)
            XCTAssertEqual(decoded, messageType)
        }
    }

    // MARK: - BusMessagePriority Tests

    func testPriorityOrdering() {
        XCTAssertTrue(TestBusPriority.low < TestBusPriority.normal)
        XCTAssertTrue(TestBusPriority.normal < TestBusPriority.high)
        XCTAssertTrue(TestBusPriority.high < TestBusPriority.critical)
    }

    func testPrioritySorting() {
        let unsorted: [TestBusPriority] = [.high, .low, .critical, .normal]
        let sorted = unsorted.sorted()
        XCTAssertEqual(sorted, [.low, .normal, .high, .critical])
    }

    func testPriorityRawValues() {
        XCTAssertEqual(TestBusPriority.low.rawValue, 0)
        XCTAssertEqual(TestBusPriority.normal.rawValue, 50)
        XCTAssertEqual(TestBusPriority.high.rawValue, 75)
        XCTAssertEqual(TestBusPriority.critical.rawValue, 100)
    }

    func testPriorityCount() {
        XCTAssertEqual(TestBusPriority.allCases.count, 4)
    }

    // MARK: - BusAgentMessage Tests

    func testMessageCreationDefaults() {
        let sender = UUID()
        let msg = TestBusMessage(
            senderAgentId: sender,
            messageType: .statusUpdate,
            payload: .text("working")
        )
        XCTAssertEqual(msg.senderAgentId, sender)
        XCTAssertNil(msg.recipientAgentId)
        XCTAssertEqual(msg.priority, .normal)
        XCTAssertNil(msg.correlationId)
        XCTAssertTrue(msg.isBroadcast)
        XCTAssertFalse(msg.isDirectMessage)
    }

    func testDirectMessageHasRecipient() {
        let sender = UUID()
        let recipient = UUID()
        let msg = TestBusMessage(
            senderAgentId: sender,
            recipientAgentId: recipient,
            messageType: .requestHelp,
            payload: .text("need help")
        )
        XCTAssertFalse(msg.isBroadcast)
        XCTAssertTrue(msg.isDirectMessage)
        XCTAssertEqual(msg.recipientAgentId, recipient)
    }

    func testMessageIdentifiable() {
        let msg1 = TestBusMessage(
            senderAgentId: UUID(),
            messageType: .statusUpdate,
            payload: .text("a")
        )
        let msg2 = TestBusMessage(
            senderAgentId: UUID(),
            messageType: .statusUpdate,
            payload: .text("b")
        )
        XCTAssertNotEqual(msg1.id, msg2.id)
    }

    func testMessageWithCorrelation() {
        let correlationId = UUID()
        let msg = TestBusMessage(
            senderAgentId: UUID(),
            messageType: .dataShare,
            payload: .text("data"),
            correlationId: correlationId
        )
        XCTAssertEqual(msg.correlationId, correlationId)
    }

    // MARK: - Payload Tests

    func testTaskResultPayload() {
        let taskId = UUID()
        let result = TestAgentTaskResult(
            taskId: taskId,
            output: "done",
            success: true,
            metadata: ["key": "value"]
        )
        XCTAssertEqual(result.taskId, taskId)
        XCTAssertEqual(result.output, "done")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.metadata["key"], "value")
    }

    func testTaskResultDefaultMetadata() {
        let result = TestAgentTaskResult(taskId: UUID(), output: "x", success: false)
        XCTAssertTrue(result.metadata.isEmpty)
    }

    func testAgentErrorDefaults() {
        let error = TestAgentError(code: "E001", message: "bad thing")
        XCTAssertTrue(error.isRecoverable)
    }

    func testAgentErrorNonRecoverable() {
        let error = TestAgentError(code: "FATAL", message: "crash", isRecoverable: false)
        XCTAssertFalse(error.isRecoverable)
    }

    func testDependencyInfoDefaults() {
        let depId = UUID()
        let info = TestDependencyInfo(dependencyId: depId, dependencyType: "data")
        XCTAssertNil(info.value)
        XCTAssertEqual(info.dependencyType, "data")
    }

    func testDependencyInfoWithValue() {
        let info = TestDependencyInfo(dependencyId: UUID(), dependencyType: "file", value: "/tmp/result.json")
        XCTAssertEqual(info.value, "/tmp/result.json")
    }

    func testResourceInfo() {
        let info = TestResourceInfo(resourceId: "gpu-1", resourceType: "compute", status: "available")
        XCTAssertEqual(info.resourceId, "gpu-1")
        XCTAssertEqual(info.resourceType, "compute")
        XCTAssertEqual(info.status, "available")
    }

    // MARK: - Filter Tests

    func testAllFilterMatchesEverything() {
        let filter = TestBusFilter.all
        let msg = TestBusMessage(
            senderAgentId: UUID(),
            messageType: .errorNotification,
            payload: .text("err"),
            priority: .critical
        )
        XCTAssertTrue(filter.matches(msg))
    }

    func testHighPriorityFilterMatchesHighAndCritical() {
        let filter = TestBusFilter.highPriority
        let high = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x"), priority: .high
        )
        let critical = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x"), priority: .critical
        )
        let normal = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x"), priority: .normal
        )
        let low = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x"), priority: .low
        )
        XCTAssertTrue(filter.matches(high))
        XCTAssertTrue(filter.matches(critical))
        XCTAssertFalse(filter.matches(normal))
        XCTAssertFalse(filter.matches(low))
    }

    func testDataOnlyFilter() {
        let filter = TestBusFilter.dataOnly
        let dataShare = TestBusMessage(
            senderAgentId: UUID(), messageType: .dataShare,
            payload: .text("x")
        )
        let completion = TestBusMessage(
            senderAgentId: UUID(), messageType: .completionSignal,
            payload: .text("x")
        )
        let help = TestBusMessage(
            senderAgentId: UUID(), messageType: .requestHelp,
            payload: .text("x")
        )
        XCTAssertTrue(filter.matches(dataShare))
        XCTAssertTrue(filter.matches(completion))
        XCTAssertFalse(filter.matches(help))
    }

    func testCoordinationFilter() {
        let filter = TestBusFilter.coordination
        let coord = TestBusMessage(
            senderAgentId: UUID(), messageType: .coordinationRequest,
            payload: .text("x")
        )
        let handoff = TestBusMessage(
            senderAgentId: UUID(), messageType: .taskHandoff,
            payload: .text("x")
        )
        let status = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x")
        )
        XCTAssertTrue(filter.matches(coord))
        XCTAssertTrue(filter.matches(handoff))
        XCTAssertFalse(filter.matches(status))
    }

    func testSenderWhitelistFilter() {
        let allowed = UUID()
        let filter = TestBusFilter(senderIds: [allowed])
        let fromAllowed = TestBusMessage(
            senderAgentId: allowed, messageType: .statusUpdate,
            payload: .text("x")
        )
        let fromOther = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x")
        )
        XCTAssertTrue(filter.matches(fromAllowed))
        XCTAssertFalse(filter.matches(fromOther))
    }

    func testSenderBlacklistFilter() {
        let blocked = UUID()
        let filter = TestBusFilter(excludeSenderIds: [blocked])
        let fromBlocked = TestBusMessage(
            senderAgentId: blocked, messageType: .statusUpdate,
            payload: .text("x")
        )
        let fromOther = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x")
        )
        XCTAssertFalse(filter.matches(fromBlocked))
        XCTAssertTrue(filter.matches(fromOther))
    }

    func testCombinedFilter() {
        let allowed = UUID()
        let filter = TestBusFilter(
            messageTypes: [.statusUpdate, .dataShare],
            priorities: [.high, .critical],
            senderIds: [allowed]
        )
        // Matches: correct type, priority, sender
        let good = TestBusMessage(
            senderAgentId: allowed, messageType: .statusUpdate,
            payload: .text("x"), priority: .high
        )
        // Wrong type
        let wrongType = TestBusMessage(
            senderAgentId: allowed, messageType: .errorNotification,
            payload: .text("x"), priority: .high
        )
        // Wrong priority
        let wrongPriority = TestBusMessage(
            senderAgentId: allowed, messageType: .statusUpdate,
            payload: .text("x"), priority: .low
        )
        // Wrong sender
        let wrongSender = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x"), priority: .high
        )
        XCTAssertTrue(filter.matches(good))
        XCTAssertFalse(filter.matches(wrongType))
        XCTAssertFalse(filter.matches(wrongPriority))
        XCTAssertFalse(filter.matches(wrongSender))
    }

    func testFilterDescriptionAll() {
        XCTAssertEqual(TestBusFilter.all.description, "all")
    }

    func testFilterDescriptionWithTypes() {
        let filter = TestBusFilter(messageTypes: [.dataShare])
        XCTAssertTrue(filter.description.contains("types:"))
    }

    func testFilterDescriptionWithPriorities() {
        let filter = TestBusFilter(priorities: [.critical])
        XCTAssertTrue(filter.description.contains("priorities:"))
    }

    func testFilterDescriptionWithWhitelist() {
        let filter = TestBusFilter(senderIds: [UUID()])
        XCTAssertTrue(filter.description.contains("whitelist"))
    }

    func testFilterDescriptionWithBlacklist() {
        let filter = TestBusFilter(excludeSenderIds: [UUID()])
        XCTAssertTrue(filter.description.contains("blacklist"))
    }

    // MARK: - Message History Tests

    func testHistoryAppend() {
        let history = TestMessageHistory(maxSize: 5)
        for i in 0..<3 {
            history.append(TestBusMessage(
                senderAgentId: UUID(), messageType: .statusUpdate,
                payload: .text("msg \(i)")
            ))
        }
        XCTAssertEqual(history.count, 3)
    }

    func testHistoryBoundsAtMaxSize() {
        let history = TestMessageHistory(maxSize: 3)
        for i in 0..<10 {
            history.append(TestBusMessage(
                senderAgentId: UUID(), messageType: .statusUpdate,
                payload: .text("msg \(i)")
            ))
        }
        XCTAssertEqual(history.count, 3)
    }

    func testHistoryRecentWithFilter() {
        let history = TestMessageHistory()
        let sender = UUID()
        history.append(TestBusMessage(
            senderAgentId: sender, messageType: .dataShare,
            payload: .text("data"), priority: .high
        ))
        history.append(TestBusMessage(
            senderAgentId: sender, messageType: .statusUpdate,
            payload: .text("status"), priority: .low
        ))

        let highOnly = history.getRecent(filter: TestBusFilter.highPriority)
        XCTAssertEqual(highOnly.count, 1)
    }

    func testHistoryRecentLimit() {
        let history = TestMessageHistory()
        for i in 0..<50 {
            history.append(TestBusMessage(
                senderAgentId: UUID(), messageType: .statusUpdate,
                payload: .text("msg \(i)")
            ))
        }
        let recent = history.getRecent(limit: 10)
        XCTAssertEqual(recent.count, 10)
    }

    // MARK: - Correlation Group Tests

    func testCorrelationTracking() {
        let tracker = TestCorrelationTracker()
        let corrId = UUID()
        let msg1 = TestBusMessage(
            senderAgentId: UUID(), messageType: .dataShare,
            payload: .text("a"), correlationId: corrId
        )
        let msg2 = TestBusMessage(
            senderAgentId: UUID(), messageType: .completionSignal,
            payload: .text("b"), correlationId: corrId
        )
        tracker.track(msg1)
        tracker.track(msg2)
        XCTAssertEqual(tracker.getGroup(corrId).count, 2)
    }

    func testCorrelationNotTrackedWithoutId() {
        let tracker = TestCorrelationTracker()
        let msg = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("x")
        )
        tracker.track(msg)
        XCTAssertEqual(tracker.groupCount, 0)
    }

    func testCorrelationCleanupOld() {
        let tracker = TestCorrelationTracker()
        let oldCorr = UUID()
        let newCorr = UUID()
        let oldMsg = TestBusMessage(
            timestamp: Date().addingTimeInterval(-3600),
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("old"), correlationId: oldCorr
        )
        let newMsg = TestBusMessage(
            senderAgentId: UUID(), messageType: .statusUpdate,
            payload: .text("new"), correlationId: newCorr
        )
        tracker.track(oldMsg)
        tracker.track(newMsg)
        let removed = tracker.cleanup(olderThan: Date().addingTimeInterval(-1800))
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(tracker.groupCount, 1)
    }

    func testCorrelationEmptyGroup() {
        let tracker = TestCorrelationTracker()
        XCTAssertTrue(tracker.getGroup(UUID()).isEmpty)
    }

    // MARK: - Pending Queue Tests

    func testPendingEnqueueDequeue() {
        let queue = TestPendingQueue()
        let agentId = UUID()
        let msg = TestBusMessage(
            senderAgentId: UUID(), messageType: .dataShare,
            payload: .text("data")
        )
        queue.enqueue(msg, for: agentId)
        XCTAssertEqual(queue.count(for: agentId), 1)
        let dequeued = queue.dequeue(for: agentId)
        XCTAssertEqual(dequeued.count, 1)
        XCTAssertEqual(queue.count(for: agentId), 0)
    }

    func testPendingMaxPerAgent() {
        let queue = TestPendingQueue(maxPerAgent: 3)
        let agentId = UUID()
        for i in 0..<10 {
            queue.enqueue(TestBusMessage(
                senderAgentId: UUID(), messageType: .statusUpdate,
                payload: .text("msg \(i)")
            ), for: agentId)
        }
        XCTAssertEqual(queue.count(for: agentId), 3)
    }

    func testPendingCountForUnknownAgent() {
        let queue = TestPendingQueue()
        XCTAssertEqual(queue.count(for: UUID()), 0)
    }

    func testPendingDequeueEmptyAgent() {
        let queue = TestPendingQueue()
        XCTAssertTrue(queue.dequeue(for: UUID()).isEmpty)
    }
}
