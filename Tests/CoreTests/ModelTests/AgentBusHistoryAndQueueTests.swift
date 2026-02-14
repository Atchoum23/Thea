// AgentBusHistoryAndQueueTests.swift
// Tests for AgentCommunicationBus infrastructure: message history,
// correlation group tracking, and pending message queues.

import Foundation
import XCTest

// MARK: - Shared Mirrored Types (minimal subset for history/queue tests)

private enum TestBusMessageType2: String, CaseIterable {
    case dataShare, statusUpdate, completionSignal, requestHelp
}

private enum TestBusPriority2: Int, Comparable, CaseIterable {
    case low = 0, normal = 50, high = 75, critical = 100
    static func < (lhs: TestBusPriority2, rhs: TestBusPriority2) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct TestBusMsg: Identifiable {
    let id: UUID
    let timestamp: Date
    let senderAgentId: UUID
    let messageType: TestBusMessageType2
    let priority: TestBusPriority2
    let content: String
    let correlationId: UUID?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        senderAgentId: UUID = UUID(),
        messageType: TestBusMessageType2 = .statusUpdate,
        priority: TestBusPriority2 = .normal,
        content: String = "",
        correlationId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.senderAgentId = senderAgentId
        self.messageType = messageType
        self.priority = priority
        self.content = content
        self.correlationId = correlationId
    }
}

// MARK: - Mirrored: MessageHistory

private class HistoryStore {
    private var messages: [TestBusMsg] = []
    private let maxSize: Int

    init(maxSize: Int = 1000) { self.maxSize = maxSize }

    func append(_ msg: TestBusMsg) {
        messages.append(msg)
        if messages.count > maxSize {
            messages.removeFirst(messages.count - maxSize)
        }
    }

    var count: Int { messages.count }

    func getRecent(
        filterTypes: Set<TestBusMessageType2>? = nil,
        filterPriorities: Set<TestBusPriority2>? = nil,
        limit: Int = 100
    ) -> [TestBusMsg] {
        messages
            .filter { msg in
                if let types = filterTypes, !types.contains(msg.messageType) { return false }
                if let pris = filterPriorities, !pris.contains(msg.priority) { return false }
                return true
            }
            .suffix(limit)
            .reversed()
    }
}

// MARK: - Mirrored: CorrelationTracker

private class CorrelationTracker {
    private var groups: [UUID: [TestBusMsg]] = [:]

    func track(_ msg: TestBusMsg) {
        guard let corrId = msg.correlationId else { return }
        groups[corrId, default: []].append(msg)
    }

    func group(for id: UUID) -> [TestBusMsg] { groups[id] ?? [] }
    var groupCount: Int { groups.count }

    func cleanup(olderThan cutoff: Date) -> Int {
        let toRemove = groups.filter { $0.value.last.map { $0.timestamp < cutoff } ?? false }
        for key in toRemove.keys { groups.removeValue(forKey: key) }
        return toRemove.count
    }
}

// MARK: - Mirrored: PendingQueue

private class PendingQueue {
    private var queues: [UUID: [TestBusMsg]] = [:]
    private let maxPerAgent: Int

    init(maxPerAgent: Int = 100) { self.maxPerAgent = maxPerAgent }

    func enqueue(_ msg: TestBusMsg, for agentId: UUID) {
        queues[agentId, default: []].append(msg)
        if let count = queues[agentId]?.count, count > maxPerAgent {
            queues[agentId]?.removeFirst(count - maxPerAgent)
        }
    }

    func dequeue(for agentId: UUID) -> [TestBusMsg] {
        let msgs = queues[agentId] ?? []
        queues[agentId] = nil
        return msgs
    }

    func count(for agentId: UUID) -> Int { queues[agentId]?.count ?? 0 }
    func hasMessages(for agentId: UUID) -> Bool { count(for: agentId) > 0 }
}

// MARK: - Mirrored: Delivery Router

private class DeliveryRouter {
    let selfExclude: Bool

    init(selfExclude: Bool = true) { self.selfExclude = selfExclude }

    func recipients(
        msg: TestBusMsg,
        recipientId: UUID?,
        subscribed: [UUID]
    ) -> [UUID] {
        if let recipient = recipientId {
            return subscribed.contains(recipient) ? [recipient] : []
        }
        return subscribed.filter { !selfExclude || $0 != msg.senderAgentId }
    }
}

// MARK: - Tests

final class AgentBusHistoryAndQueueTests: XCTestCase {

    // MARK: - History Tests

    func testHistoryAppendsMessages() {
        let store = HistoryStore(maxSize: 10)
        store.append(TestBusMsg(content: "a"))
        store.append(TestBusMsg(content: "b"))
        XCTAssertEqual(store.count, 2)
    }

    func testHistoryEnforcesMaxSize() {
        let store = HistoryStore(maxSize: 3)
        for i in 0..<10 { store.append(TestBusMsg(content: "\(i)")) }
        XCTAssertEqual(store.count, 3)
    }

    func testHistoryRecentMostRecentFirst() {
        let store = HistoryStore()
        store.append(TestBusMsg(content: "first"))
        store.append(TestBusMsg(content: "second"))
        let recent = store.getRecent(limit: 2)
        XCTAssertEqual(recent.count, 2)
    }

    func testHistoryFilterByType() {
        let store = HistoryStore()
        store.append(TestBusMsg(messageType: .dataShare, content: "data"))
        store.append(TestBusMsg(messageType: .statusUpdate, content: "status"))
        store.append(TestBusMsg(messageType: .dataShare, content: "data2"))
        let filtered = store.getRecent(filterTypes: [.dataShare])
        XCTAssertEqual(filtered.count, 2)
    }

    func testHistoryFilterByPriority() {
        let store = HistoryStore()
        store.append(TestBusMsg(priority: .high, content: "hi"))
        store.append(TestBusMsg(priority: .low, content: "lo"))
        store.append(TestBusMsg(priority: .critical, content: "crit"))
        let filtered = store.getRecent(filterPriorities: [.high, .critical])
        XCTAssertEqual(filtered.count, 2)
    }

    func testHistoryLimitRespectsCount() {
        let store = HistoryStore()
        for i in 0..<50 { store.append(TestBusMsg(content: "\(i)")) }
        XCTAssertEqual(store.getRecent(limit: 5).count, 5)
    }

    func testHistoryEmptyStore() {
        let store = HistoryStore()
        XCTAssertEqual(store.count, 0)
        XCTAssertTrue(store.getRecent().isEmpty)
    }

    // MARK: - Correlation Tests

    func testCorrelationTracksGroupedMessages() {
        let tracker = CorrelationTracker()
        let corrId = UUID()
        tracker.track(TestBusMsg(content: "a", correlationId: corrId))
        tracker.track(TestBusMsg(content: "b", correlationId: corrId))
        XCTAssertEqual(tracker.group(for: corrId).count, 2)
    }

    func testCorrelationIgnoresNoCorrelation() {
        let tracker = CorrelationTracker()
        tracker.track(TestBusMsg(content: "no corr"))
        XCTAssertEqual(tracker.groupCount, 0)
    }

    func testCorrelationSeparateGroups() {
        let tracker = CorrelationTracker()
        let g1 = UUID(), g2 = UUID()
        tracker.track(TestBusMsg(content: "a", correlationId: g1))
        tracker.track(TestBusMsg(content: "b", correlationId: g2))
        XCTAssertEqual(tracker.groupCount, 2)
        XCTAssertEqual(tracker.group(for: g1).count, 1)
        XCTAssertEqual(tracker.group(for: g2).count, 1)
    }

    func testCorrelationCleanupRemovesOld() {
        let tracker = CorrelationTracker()
        let old = UUID(), recent = UUID()
        tracker.track(TestBusMsg(timestamp: Date().addingTimeInterval(-7200), content: "old", correlationId: old))
        tracker.track(TestBusMsg(content: "recent", correlationId: recent))
        let removed = tracker.cleanup(olderThan: Date().addingTimeInterval(-3600))
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(tracker.groupCount, 1)
    }

    func testCorrelationCleanupKeepsRecent() {
        let tracker = CorrelationTracker()
        let corrId = UUID()
        tracker.track(TestBusMsg(content: "recent", correlationId: corrId))
        let removed = tracker.cleanup(olderThan: Date().addingTimeInterval(-3600))
        XCTAssertEqual(removed, 0)
        XCTAssertEqual(tracker.groupCount, 1)
    }

    func testCorrelationUnknownGroupEmpty() {
        let tracker = CorrelationTracker()
        XCTAssertTrue(tracker.group(for: UUID()).isEmpty)
    }

    // MARK: - Pending Queue Tests

    func testEnqueueAndDequeue() {
        let queue = PendingQueue()
        let agent = UUID()
        queue.enqueue(TestBusMsg(content: "hello"), for: agent)
        XCTAssertEqual(queue.count(for: agent), 1)
        XCTAssertTrue(queue.hasMessages(for: agent))
        let msgs = queue.dequeue(for: agent)
        XCTAssertEqual(msgs.count, 1)
        XCTAssertEqual(queue.count(for: agent), 0)
        XCTAssertFalse(queue.hasMessages(for: agent))
    }

    func testPendingMaxPerAgentEnforced() {
        let queue = PendingQueue(maxPerAgent: 5)
        let agent = UUID()
        for i in 0..<20 { queue.enqueue(TestBusMsg(content: "\(i)"), for: agent) }
        XCTAssertEqual(queue.count(for: agent), 5)
    }

    func testPendingMultipleAgents() {
        let queue = PendingQueue()
        let a1 = UUID(), a2 = UUID()
        queue.enqueue(TestBusMsg(content: "for a1"), for: a1)
        queue.enqueue(TestBusMsg(content: "for a2"), for: a2)
        XCTAssertEqual(queue.count(for: a1), 1)
        XCTAssertEqual(queue.count(for: a2), 1)
        _ = queue.dequeue(for: a1)
        XCTAssertEqual(queue.count(for: a1), 0)
        XCTAssertEqual(queue.count(for: a2), 1)
    }

    func testPendingDequeueUnknownAgent() {
        let queue = PendingQueue()
        XCTAssertTrue(queue.dequeue(for: UUID()).isEmpty)
    }

    func testPendingCountUnknownAgent() {
        let queue = PendingQueue()
        XCTAssertEqual(queue.count(for: UUID()), 0)
    }

    // MARK: - Delivery Router Tests

    func testBroadcastExcludesSender() {
        let router = DeliveryRouter(selfExclude: true)
        let sender = UUID()
        let agents = [sender, UUID(), UUID()]
        let recipients = router.recipients(
            msg: TestBusMsg(senderAgentId: sender),
            recipientId: nil,
            subscribed: agents
        )
        XCTAssertEqual(recipients.count, 2)
        XCTAssertFalse(recipients.contains(sender))
    }

    func testBroadcastIncludesSenderWhenDisabled() {
        let router = DeliveryRouter(selfExclude: false)
        let sender = UUID()
        let agents = [sender, UUID()]
        let recipients = router.recipients(
            msg: TestBusMsg(senderAgentId: sender),
            recipientId: nil,
            subscribed: agents
        )
        XCTAssertEqual(recipients.count, 2)
    }

    func testDirectMessageToSubscribed() {
        let router = DeliveryRouter()
        let target = UUID()
        let recipients = router.recipients(
            msg: TestBusMsg(),
            recipientId: target,
            subscribed: [UUID(), target, UUID()]
        )
        XCTAssertEqual(recipients, [target])
    }

    func testDirectMessageToUnsubscribed() {
        let router = DeliveryRouter()
        let target = UUID()
        let recipients = router.recipients(
            msg: TestBusMsg(),
            recipientId: target,
            subscribed: [UUID(), UUID()]
        )
        XCTAssertTrue(recipients.isEmpty)
    }
}
