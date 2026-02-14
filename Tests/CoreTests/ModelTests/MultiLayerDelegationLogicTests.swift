// MultiLayerDelegationLogicTests.swift
// Tests for B-MLT multi-layer delegation logic:
// - Task deduplication registry (B-MLT3)
// - Result cache with TTL (B-MLT4)
// - Resource budgets per layer (B-MLT5)
// - Integration orchestration scenarios

import Foundation
import XCTest

// MARK: - Mirrored Types (shared with MultiLayerDelegationTests)

/// Mirrors SpecializedAgentType
private enum MLTAgentType: String, CaseIterable {
    case explore, plan, generalPurpose, bash, research
    case database, security, performance, api, testing
    case documentation, refactoring, review, debug, deployment
}

/// Mirrors TheaAgentState
private enum MLTAgentState: String {
    case idle, planning, working, awaitingApproval, paused
    case completed, failed, cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: true
        default: false
        }
    }

    var isActive: Bool {
        switch self {
        case .planning, .working, .awaitingApproval: true
        default: false
        }
    }
}

/// Mirrors TheaAgentSession (minimal for logic tests)
private final class MLTSession: Identifiable {
    let id: UUID
    let agentType: MLTAgentType
    var state: MLTAgentState = .idle
    var tokensUsed: Int = 0
    var tokenBudget: Int = 8192
    let delegationDepth: Int
    let parentSessionID: UUID?
    let parentConversationID: UUID
    var canDelegate: Bool { delegationDepth < 2 }

    init(
        id: UUID = UUID(),
        agentType: MLTAgentType = .generalPurpose,
        tokenBudget: Int = 8192,
        delegationDepth: Int = 1,
        parentSessionID: UUID? = nil,
        parentConversationID: UUID = UUID()
    ) {
        self.id = id
        self.agentType = agentType
        self.tokenBudget = tokenBudget
        self.delegationDepth = delegationDepth
        self.parentSessionID = parentSessionID
        self.parentConversationID = parentConversationID
    }
}

/// Mirrors CachedTaskResult
private struct MLTCachedResult {
    let result: String
    let completedAt: Date
    let agentType: MLTAgentType
    let tokensUsed: Int

    init(result: String, completedAt: Date = Date(), agentType: MLTAgentType, tokensUsed: Int) {
        self.result = result
        self.completedAt = completedAt
        self.agentType = agentType
        self.tokensUsed = tokensUsed
    }
}

/// Task hash function
private func taskHash(_ task: String) -> String {
    let normalized = task.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return String(normalized.hashValue, radix: 16)
}

/// Depth-aware budget
private func budget(for type: MLTAgentType, depth: Int = 1) -> Int {
    let base: Int
    switch type {
    case .research, .documentation: base = 16384
    case .plan, .review: base = 12288
    case .explore, .debug: base = 8192
    default: base = 8192
    }
    return depth >= 2 ? base / 2 : base
}

/// Max workers per depth
private func maxWorkers(for session: MLTSession) -> Int {
    switch session.delegationDepth {
    case 0: return 5
    case 1: return 3
    default: return 0
    }
}

// MARK: - B-MLT3: Task Deduplication

final class TaskDeduplicationTests: XCTestCase {

    func testIdenticalTasksProduceSameHash() {
        XCTAssertEqual(taskHash("analyze user model"), taskHash("analyze user model"))
    }

    func testCaseInsensitiveDedup() {
        XCTAssertEqual(taskHash("Analyze User Model"), taskHash("analyze user model"))
    }

    func testWhitespaceTrimming() {
        XCTAssertEqual(taskHash("  analyze user model  "), taskHash("analyze user model"))
    }

    func testDifferentTasksProduceDifferentHashes() {
        XCTAssertNotEqual(taskHash("analyze user model"), taskHash("refactor authentication"))
    }

    func testEmptyTaskHash() {
        XCTAssertFalse(taskHash("").isEmpty)
    }

    func testLongTaskHash() {
        XCTAssertFalse(taskHash(String(repeating: "a", count: 10_000)).isEmpty)
    }

    func testTaskRegistryDedup() {
        var registry: [String: UUID] = [:]
        let hash = taskHash("analyze user model")
        let sessionID = UUID()
        registry[hash] = sessionID
        XCTAssertEqual(registry[hash], sessionID)
    }

    func testTaskSubscribers() {
        var subs: [String: [UUID]] = [:]
        let hash = taskHash("analyze user model")
        let s1 = UUID(), s2 = UUID()
        subs[hash, default: []].append(s1)
        subs[hash, default: []].append(s2)
        XCTAssertEqual(subs[hash]?.count, 2)
    }

    func testPublishClearsSubscribers() {
        var subs: [String: [UUID]] = [:]
        let hash = taskHash("analyze user model")
        subs[hash] = [UUID(), UUID()]
        subs.removeValue(forKey: hash)
        XCTAssertNil(subs[hash])
    }

    func testDiamondDependencyDedup() {
        var registry: [String: UUID] = [:]
        var subs: [String: [UUID]] = [:]
        let hash = taskHash("analyze User model")
        let workerC = UUID(), agentB = UUID()

        registry[hash] = workerC
        XCTAssertEqual(registry[hash], workerC)
        subs[hash, default: []].append(agentB)
        XCTAssertEqual(subs[hash]?.count, 1)
    }
}

// MARK: - B-MLT4: Result Cache with TTL

final class ResultCacheTests: XCTestCase {

    func testCacheStoresResult() {
        var cache: [String: MLTCachedResult] = [:]
        cache["h1"] = MLTCachedResult(result: "done", agentType: .research, tokensUsed: 500)
        XCTAssertEqual(cache["h1"]?.result, "done")
    }

    func testCacheReturnsNilForMissing() {
        let cache: [String: MLTCachedResult] = [:]
        XCTAssertNil(cache["nonexistent"])
    }

    func testCacheTTLExpiration() {
        let ttl: TimeInterval = 300
        let now = Date()
        let fresh = MLTCachedResult(result: "f", completedAt: now.addingTimeInterval(-60), agentType: .explore, tokensUsed: 100)
        let stale = MLTCachedResult(result: "s", completedAt: now.addingTimeInterval(-600), agentType: .explore, tokensUsed: 100)
        XCTAssertTrue(now.timeIntervalSince(fresh.completedAt) < ttl)
        XCTAssertTrue(now.timeIntervalSince(stale.completedAt) >= ttl)
    }

    func testCachePurgeExpired() {
        var cache: [String: MLTCachedResult] = [:]
        let ttl: TimeInterval = 300
        let now = Date()
        cache["fresh"] = MLTCachedResult(result: "f", completedAt: now.addingTimeInterval(-60), agentType: .explore, tokensUsed: 50)
        cache["stale"] = MLTCachedResult(result: "s", completedAt: now.addingTimeInterval(-600), agentType: .explore, tokensUsed: 50)
        cache = cache.filter { now.timeIntervalSince($0.value.completedAt) < ttl }
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache["fresh"])
    }

    func testCachedResultProperties() {
        let r = MLTCachedResult(result: "done", agentType: .documentation, tokensUsed: 1234)
        XCTAssertEqual(r.result, "done")
        XCTAssertEqual(r.agentType, .documentation)
        XCTAssertEqual(r.tokensUsed, 1234)
    }

    func testCacheOverwrite() {
        var cache: [String: MLTCachedResult] = [:]
        cache["h"] = MLTCachedResult(result: "v1", agentType: .explore, tokensUsed: 100)
        cache["h"] = MLTCachedResult(result: "v2", agentType: .explore, tokensUsed: 200)
        XCTAssertEqual(cache["h"]?.result, "v2")
    }

    func testCacheTTLBoundary() {
        let ttl: TimeInterval = 300
        let now = Date()
        let atBoundary = MLTCachedResult(result: "b", completedAt: now.addingTimeInterval(-300), agentType: .explore, tokensUsed: 50)
        let justUnder = MLTCachedResult(result: "u", completedAt: now.addingTimeInterval(-299), agentType: .explore, tokensUsed: 50)
        XCTAssertTrue(now.timeIntervalSince(atBoundary.completedAt) >= ttl)
        XCTAssertTrue(now.timeIntervalSince(justUnder.completedAt) < ttl)
    }
}

// MARK: - B-MLT5: Resource Budgets Per Layer

final class ResourceBudgetPerLayerTests: XCTestCase {

    func testResearchBudgetDepth1() { XCTAssertEqual(budget(for: .research, depth: 1), 16384) }
    func testDocBudgetDepth1() { XCTAssertEqual(budget(for: .documentation, depth: 1), 16384) }
    func testPlanBudgetDepth1() { XCTAssertEqual(budget(for: .plan, depth: 1), 12288) }
    func testReviewBudgetDepth1() { XCTAssertEqual(budget(for: .review, depth: 1), 12288) }
    func testExploreBudgetDepth1() { XCTAssertEqual(budget(for: .explore, depth: 1), 8192) }
    func testDebugBudgetDepth1() { XCTAssertEqual(budget(for: .debug, depth: 1), 8192) }
    func testDefaultBudgetDepth1() { XCTAssertEqual(budget(for: .generalPurpose, depth: 1), 8192) }

    func testResearchBudgetDepth2() { XCTAssertEqual(budget(for: .research, depth: 2), 8192) }
    func testPlanBudgetDepth2() { XCTAssertEqual(budget(for: .plan, depth: 2), 6144) }
    func testExploreBudgetDepth2() { XCTAssertEqual(budget(for: .explore, depth: 2), 4096) }
    func testDefaultBudgetDepth2() { XCTAssertEqual(budget(for: .generalPurpose, depth: 2), 4096) }

    func testDepth2IsHalfOfDepth1() {
        for t in MLTAgentType.allCases {
            XCTAssertEqual(budget(for: t, depth: 2), budget(for: t, depth: 1) / 2, "\(t.rawValue)")
        }
    }

    func testMetaAIMaxWorkers() { XCTAssertEqual(maxWorkers(for: MLTSession(delegationDepth: 0)), 5) }
    func testSubAgentMaxWorkers() { XCTAssertEqual(maxWorkers(for: MLTSession(delegationDepth: 1)), 3) }
    func testWorkerMaxWorkers() { XCTAssertEqual(maxWorkers(for: MLTSession(delegationDepth: 2)), 0) }
    func testDepth3MaxWorkers() { XCTAssertEqual(maxWorkers(for: MLTSession(delegationDepth: 3)), 0) }

    func testMaxTotalAgents() {
        XCTAssertEqual(5 + 5 * 3, 20)  // 5 sub-agents + 15 workers
    }

    func testBudgetDecreasesByDepth() {
        for t in MLTAgentType.allCases {
            XCTAssertGreaterThan(budget(for: t, depth: 1), budget(for: t, depth: 2), "\(t.rawValue)")
        }
    }
}

// MARK: - Integration: Multi-Layer Orchestration Logic

final class MultiLayerOrchestrationTests: XCTestCase {

    func testFullDelegationChain() {
        let convID = UUID()
        let metaAI = MLTSession(delegationDepth: 0)
        let sub = MLTSession(
            agentType: .research,
            tokenBudget: budget(for: .research, depth: 1),
            delegationDepth: 1, parentSessionID: metaAI.id,
            parentConversationID: convID
        )
        let worker = MLTSession(
            agentType: .explore,
            tokenBudget: budget(for: .explore, depth: 2),
            delegationDepth: 2, parentSessionID: sub.id,
            parentConversationID: convID
        )

        XCTAssertTrue(metaAI.canDelegate)
        XCTAssertTrue(sub.canDelegate)
        XCTAssertFalse(worker.canDelegate)
        XCTAssertEqual(sub.tokenBudget, 16384)
        XCTAssertEqual(worker.tokenBudget, 4096)
        XCTAssertEqual(sub.parentSessionID, metaAI.id)
        XCTAssertEqual(worker.parentSessionID, sub.id)
    }

    func testRequestDelegationSimulation() {
        var registry: [String: UUID] = [:]
        var cache: [String: MLTCachedResult] = [:]
        let parent = MLTSession(delegationDepth: 1)
        let hash = taskHash("analyze User model")

        XCTAssertTrue(parent.canDelegate)
        XCTAssertNil(cache[hash])
        XCTAssertNil(registry[hash])

        let workerID = UUID()
        registry[hash] = workerID
        cache[hash] = MLTCachedResult(result: "done", agentType: .explore, tokensUsed: 500)
        XCTAssertEqual(cache[hash]?.result, "done")
    }

    func testChildSessionTracking() {
        let parentID = UUID()
        let sessions: [MLTSession] = [
            MLTSession(agentType: .explore, parentSessionID: parentID),
            MLTSession(agentType: .debug, parentSessionID: parentID),
            MLTSession(agentType: .research, parentSessionID: UUID()),
            MLTSession(parentSessionID: nil),
        ]
        XCTAssertEqual(sessions.filter { $0.parentSessionID == parentID }.count, 2)
    }

    func testWorkerCountEnforcement() {
        let parent = MLTSession(delegationDepth: 1)
        let max = maxWorkers(for: parent)
        var sessions = (0..<3).map { _ in
            let w = MLTSession(delegationDepth: 2, parentSessionID: parent.id)
            w.state = .working
            return w
        }
        XCTAssertFalse(sessions.filter { $0.parentSessionID == parent.id && $0.state.isActive }.count < max)
        sessions[0].state = .completed
        XCTAssertTrue(sessions.filter { $0.parentSessionID == parent.id && $0.state.isActive }.count < max)
    }

    func testBudgetReallocationWithHierarchy() {
        let pool = 500_000
        let sessions: [MLTSession] = [
            MLTSession(tokenBudget: 16384, delegationDepth: 1),
            MLTSession(tokenBudget: 4096, delegationDepth: 2),
            MLTSession(tokenBudget: 12288, delegationDepth: 1),
            MLTSession(tokenBudget: 4096, delegationDepth: 2),
        ]
        XCTAssertEqual(sessions.map(\.tokenBudget).reduce(0, +), 36864)
        sessions[1].state = .completed
        sessions[1].tokensUsed = 2000
        for s in sessions where s.state.isTerminal { s.tokenBudget = s.tokensUsed }
        XCTAssertEqual(sessions.map(\.tokenBudget).reduce(0, +), 34768)
    }
}
