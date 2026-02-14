// MultiLayerDelegationTests.swift
// Tests for B-MLT multi-layer delegation features:
// - Delegation depth cap (B-MLT1)
// - Request-approve gate (B-MLT2)
// - Task deduplication registry (B-MLT3)
// - Result cache with TTL (B-MLT4)
// - Resource budgets per layer (B-MLT5)

import Foundation
import XCTest

// MARK: - Mirrored Types

/// Mirrors TheaAgentState
private enum TestAgentState: String, CaseIterable {
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

/// Mirrors SpecializedAgentType
private enum TestSpecializedAgentType: String, CaseIterable {
    case explore, plan, generalPurpose, bash, research
    case database, security, performance, api, testing
    case documentation, refactoring, review, debug, deployment
}

/// Mirrors TheaContextPressure
private enum TestContextPressure: String, Comparable {
    case nominal, elevated, critical, exceeded

    static func < (lhs: TestContextPressure, rhs: TestContextPressure) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .nominal: 0
        case .elevated: 1
        case .critical: 2
        case .exceeded: 3
        }
    }

    static func from(usage: Double) -> TestContextPressure {
        switch usage {
        case ..<0.6: .nominal
        case ..<0.8: .elevated
        case ..<0.95: .critical
        default: .exceeded
        }
    }
}

/// Mirrors TheaAgentSession with delegation hierarchy
private final class TestAgentSession: Identifiable {
    let id: UUID
    let agentType: TestSpecializedAgentType
    var name: String
    var taskDescription: String
    let parentConversationID: UUID
    var state: TestAgentState = .idle
    var tokensUsed: Int = 0
    var tokenBudget: Int = 8192
    var contextPressure: TestContextPressure = .nominal

    // B-MLT1: Delegation hierarchy
    let delegationDepth: Int
    let parentSessionID: UUID?
    var canDelegate: Bool { delegationDepth < 2 }

    init(
        id: UUID = UUID(),
        agentType: TestSpecializedAgentType = .generalPurpose,
        name: String = "Test Agent",
        taskDescription: String = "",
        parentConversationID: UUID = UUID(),
        tokenBudget: Int = 8192,
        delegationDepth: Int = 1,
        parentSessionID: UUID? = nil
    ) {
        self.id = id
        self.agentType = agentType
        self.name = name
        self.taskDescription = taskDescription
        self.parentConversationID = parentConversationID
        self.tokenBudget = tokenBudget
        self.delegationDepth = delegationDepth
        self.parentSessionID = parentSessionID
    }
}

/// Mirrors DelegationDecision
private enum TestDelegationDecision {
    case approve(UUID)
    case reuseExisting(UUID)
    case returnCached(String)
    case deny(reason: String)
}

/// Mirrors CachedTaskResult
private struct TestCachedTaskResult {
    let result: String
    let completedAt: Date
    let agentType: TestSpecializedAgentType
    let tokensUsed: Int

    init(result: String, completedAt: Date = Date(), agentType: TestSpecializedAgentType, tokensUsed: Int) {
        self.result = result
        self.completedAt = completedAt
        self.agentType = agentType
        self.tokensUsed = tokensUsed
    }
}

/// Mirrors task hash computation
private func computeTaskHash(_ task: String) -> String {
    let normalized = task.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return String(normalized.hashValue, radix: 16)
}

/// Mirrors depth-aware budget allocation
private func defaultBudget(for agentType: TestSpecializedAgentType, depth: Int = 1) -> Int {
    let baseBudget: Int
    switch agentType {
    case .research, .documentation: baseBudget = 16384
    case .plan, .review: baseBudget = 12288
    case .explore, .debug: baseBudget = 8192
    default: baseBudget = 8192
    }
    return depth >= 2 ? baseBudget / 2 : baseBudget
}

/// Mirrors max concurrent workers per depth
private func maxConcurrentWorkers(for session: TestAgentSession) -> Int {
    switch session.delegationDepth {
    case 0: return 5
    case 1: return 3
    default: return 0
    }
}

// MARK: - B-MLT1: Delegation Depth Cap

final class DelegationDepthTests: XCTestCase {

    func testDepth0CanDelegate() {
        let session = TestAgentSession(delegationDepth: 0)
        XCTAssertTrue(session.canDelegate, "Meta-AI (depth 0) should be able to delegate")
    }

    func testDepth1CanDelegate() {
        let session = TestAgentSession(delegationDepth: 1)
        XCTAssertTrue(session.canDelegate, "Sub-agent (depth 1) should be able to delegate")
    }

    func testDepth2CannotDelegate() {
        let session = TestAgentSession(delegationDepth: 2)
        XCTAssertFalse(session.canDelegate, "Worker (depth 2) should NOT be able to delegate")
    }

    func testDepth3CannotDelegate() {
        let session = TestAgentSession(delegationDepth: 3)
        XCTAssertFalse(session.canDelegate, "Depth 3 should never be allowed to delegate")
    }

    func testParentSessionIDTracking() {
        let parentID = UUID()
        let child = TestAgentSession(parentSessionID: parentID)
        XCTAssertEqual(child.parentSessionID, parentID)
    }

    func testParentSessionIDNilForTopLevel() {
        let session = TestAgentSession()
        XCTAssertNil(session.parentSessionID)
    }

    func testDelegationDepthDefaultIs1() {
        let session = TestAgentSession()
        XCTAssertEqual(session.delegationDepth, 1)
    }

    func testDelegationHierarchyChain() {
        // Meta-AI (0) -> SubAgent (1) -> Worker (2)
        let metaAI = TestAgentSession(delegationDepth: 0)
        let subAgent = TestAgentSession(delegationDepth: 1, parentSessionID: metaAI.id)
        let worker = TestAgentSession(delegationDepth: 2, parentSessionID: subAgent.id)

        XCTAssertTrue(metaAI.canDelegate)
        XCTAssertTrue(subAgent.canDelegate)
        XCTAssertFalse(worker.canDelegate)
        XCTAssertNil(metaAI.parentSessionID)
        XCTAssertEqual(subAgent.parentSessionID, metaAI.id)
        XCTAssertEqual(worker.parentSessionID, subAgent.id)
    }
}

// MARK: - B-MLT2: Request-Approve Gate

final class RequestApproveGateTests: XCTestCase {

    func testDenyWhenDepthExceeded() {
        let worker = TestAgentSession(delegationDepth: 2)
        XCTAssertFalse(worker.canDelegate)
        // A requestDelegation from this agent should be denied
    }

    func testApproveWhenWithinDepth() {
        let subAgent = TestAgentSession(delegationDepth: 1)
        XCTAssertTrue(subAgent.canDelegate)
    }

    func testDenyWhenMaxWorkersReached() {
        let parent = TestAgentSession(delegationDepth: 1)
        let maxWorkers = maxConcurrentWorkers(for: parent)
        XCTAssertEqual(maxWorkers, 3, "Depth-1 agent should allow 3 workers")

        // Simulate 3 active workers
        var activeCount = 3
        XCTAssertFalse(activeCount < maxWorkers, "Should deny when at worker limit")
    }

    func testApproveWhenBelowWorkerLimit() {
        let parent = TestAgentSession(delegationDepth: 1)
        var activeCount = 2
        let maxWorkers = maxConcurrentWorkers(for: parent)
        XCTAssertTrue(activeCount < maxWorkers, "Should approve when below limit")
    }

    func testDelegationDecisionApprove() {
        let sessionID = UUID()
        let decision: TestDelegationDecision = .approve(sessionID)
        if case .approve(let id) = decision {
            XCTAssertEqual(id, sessionID)
        } else {
            XCTFail("Expected approve decision")
        }
    }

    func testDelegationDecisionReuseExisting() {
        let sessionID = UUID()
        let decision: TestDelegationDecision = .reuseExisting(sessionID)
        if case .reuseExisting(let id) = decision {
            XCTAssertEqual(id, sessionID)
        } else {
            XCTFail("Expected reuseExisting decision")
        }
    }

    func testDelegationDecisionReturnCached() {
        let decision: TestDelegationDecision = .returnCached("cached result")
        if case .returnCached(let result) = decision {
            XCTAssertEqual(result, "cached result")
        } else {
            XCTFail("Expected returnCached decision")
        }
    }

    func testDelegationDecisionDeny() {
        let decision: TestDelegationDecision = .deny(reason: "budget exhausted")
        if case .deny(let reason) = decision {
            XCTAssertEqual(reason, "budget exhausted")
        } else {
            XCTFail("Expected deny decision")
        }
    }
}

// MARK: - B-MLT3: Task Deduplication

final class TaskDeduplicationTests: XCTestCase {

    func testIdenticalTasksProduceSameHash() {
        let hash1 = computeTaskHash("analyze user model")
        let hash2 = computeTaskHash("analyze user model")
        XCTAssertEqual(hash1, hash2)
    }

    func testCaseInsensitiveDedup() {
        let hash1 = computeTaskHash("Analyze User Model")
        let hash2 = computeTaskHash("analyze user model")
        XCTAssertEqual(hash1, hash2, "Hashing should be case-insensitive")
    }

    func testWhitespaceTrimming() {
        let hash1 = computeTaskHash("  analyze user model  ")
        let hash2 = computeTaskHash("analyze user model")
        XCTAssertEqual(hash1, hash2, "Hashing should trim whitespace")
    }

    func testDifferentTasksProduceDifferentHashes() {
        let hash1 = computeTaskHash("analyze user model")
        let hash2 = computeTaskHash("refactor authentication")
        XCTAssertNotEqual(hash1, hash2)
    }

    func testEmptyTaskHash() {
        let hash = computeTaskHash("")
        XCTAssertFalse(hash.isEmpty, "Empty task should still produce a hash")
    }

    func testLongTaskHash() {
        let longTask = String(repeating: "a", count: 10_000)
        let hash = computeTaskHash(longTask)
        XCTAssertFalse(hash.isEmpty, "Long task should produce a hash")
    }

    func testTaskRegistryDedup() {
        // Simulate registry behavior
        var taskRegistry: [String: UUID] = [:]
        let taskHash = computeTaskHash("analyze user model")
        let sessionID = UUID()
        taskRegistry[taskHash] = sessionID

        // Second request for same task should find existing
        let existing = taskRegistry[taskHash]
        XCTAssertEqual(existing, sessionID)
    }

    func testTaskSubscribers() {
        var taskSubscribers: [String: [UUID]] = [:]
        let taskHash = computeTaskHash("analyze user model")
        let subscriber1 = UUID()
        let subscriber2 = UUID()

        taskSubscribers[taskHash, default: []].append(subscriber1)
        taskSubscribers[taskHash, default: []].append(subscriber2)

        XCTAssertEqual(taskSubscribers[taskHash]?.count, 2)
        XCTAssertTrue(taskSubscribers[taskHash]?.contains(subscriber1) ?? false)
        XCTAssertTrue(taskSubscribers[taskHash]?.contains(subscriber2) ?? false)
    }

    func testPublishClearsSubscribers() {
        var taskSubscribers: [String: [UUID]] = [:]
        let taskHash = computeTaskHash("analyze user model")
        taskSubscribers[taskHash] = [UUID(), UUID()]
        XCTAssertEqual(taskSubscribers[taskHash]?.count, 2)

        // Publish clears subscribers
        taskSubscribers.removeValue(forKey: taskHash)
        XCTAssertNil(taskSubscribers[taskHash])
    }

    func testDiamondDependencyDedup() {
        // Sub-agent A and B both request "analyze User model"
        var taskRegistry: [String: UUID] = [:]
        var taskSubscribers: [String: [UUID]] = [:]
        let taskHash = computeTaskHash("analyze User model")

        let agentA = UUID()
        let agentB = UUID()
        let workerC = UUID()

        // Agent A requests first → worker C spawned
        taskRegistry[taskHash] = workerC

        // Agent B requests same task → reuse existing
        let existingWorker = taskRegistry[taskHash]
        XCTAssertEqual(existingWorker, workerC, "Should find existing worker")
        taskSubscribers[taskHash, default: []].append(agentB)

        // Worker C completes → result delivered to both A and B
        let subscribers = taskSubscribers[taskHash] ?? []
        XCTAssertEqual(subscribers.count, 1, "Agent B should be subscriber")
        XCTAssertTrue(subscribers.contains(agentB))
    }
}

// MARK: - B-MLT4: Result Cache with TTL

final class ResultCacheTests: XCTestCase {

    func testCacheStoresResult() {
        var cache: [String: TestCachedTaskResult] = [:]
        let hash = computeTaskHash("analyze user model")
        let result = TestCachedTaskResult(result: "analysis complete", agentType: .research, tokensUsed: 500)
        cache[hash] = result

        XCTAssertNotNil(cache[hash])
        XCTAssertEqual(cache[hash]?.result, "analysis complete")
    }

    func testCacheReturnsNilForMissingKey() {
        let cache: [String: TestCachedTaskResult] = [:]
        XCTAssertNil(cache["nonexistent"])
    }

    func testCacheTTLExpiration() {
        let cacheTTL: TimeInterval = 300  // 5 minutes
        let now = Date()

        // Fresh result (1 minute old)
        let fresh = TestCachedTaskResult(
            result: "fresh",
            completedAt: now.addingTimeInterval(-60),
            agentType: .research, tokensUsed: 100
        )
        XCTAssertTrue(now.timeIntervalSince(fresh.completedAt) < cacheTTL, "Fresh result should not be expired")

        // Stale result (10 minutes old)
        let stale = TestCachedTaskResult(
            result: "stale",
            completedAt: now.addingTimeInterval(-600),
            agentType: .research, tokensUsed: 100
        )
        XCTAssertTrue(now.timeIntervalSince(stale.completedAt) >= cacheTTL, "Stale result should be expired")
    }

    func testCachePurgeExpired() {
        var cache: [String: TestCachedTaskResult] = [:]
        let cacheTTL: TimeInterval = 300
        let now = Date()

        // Add fresh and stale entries
        cache["fresh"] = TestCachedTaskResult(result: "fresh", completedAt: now.addingTimeInterval(-60), agentType: .explore, tokensUsed: 50)
        cache["stale"] = TestCachedTaskResult(result: "stale", completedAt: now.addingTimeInterval(-600), agentType: .explore, tokensUsed: 50)

        // Purge expired
        cache = cache.filter { now.timeIntervalSince($0.value.completedAt) < cacheTTL }

        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache["fresh"])
        XCTAssertNil(cache["stale"])
    }

    func testCachedTaskResultProperties() {
        let result = TestCachedTaskResult(result: "done", agentType: .documentation, tokensUsed: 1234)
        XCTAssertEqual(result.result, "done")
        XCTAssertEqual(result.agentType, .documentation)
        XCTAssertEqual(result.tokensUsed, 1234)
        XCTAssertNotNil(result.completedAt)
    }

    func testCacheOverwrite() {
        var cache: [String: TestCachedTaskResult] = [:]
        let hash = "test_hash"

        cache[hash] = TestCachedTaskResult(result: "v1", agentType: .explore, tokensUsed: 100)
        cache[hash] = TestCachedTaskResult(result: "v2", agentType: .explore, tokensUsed: 200)

        XCTAssertEqual(cache[hash]?.result, "v2")
        XCTAssertEqual(cache[hash]?.tokensUsed, 200)
    }

    func testCacheTTLBoundary() {
        let cacheTTL: TimeInterval = 300
        let now = Date()

        // Exactly at TTL boundary (should be expired)
        let atBoundary = TestCachedTaskResult(
            result: "boundary",
            completedAt: now.addingTimeInterval(-300),
            agentType: .explore, tokensUsed: 50
        )
        XCTAssertTrue(now.timeIntervalSince(atBoundary.completedAt) >= cacheTTL, "At boundary should be expired")

        // Just under TTL (should be fresh)
        let justUnder = TestCachedTaskResult(
            result: "just under",
            completedAt: now.addingTimeInterval(-299),
            agentType: .explore, tokensUsed: 50
        )
        XCTAssertTrue(now.timeIntervalSince(justUnder.completedAt) < cacheTTL, "Just under should be fresh")
    }
}

// MARK: - B-MLT5: Resource Budgets Per Layer

final class ResourceBudgetPerLayerTests: XCTestCase {

    // Budget per agent type at depth 1 (sub-agent)
    func testResearchBudgetDepth1() {
        XCTAssertEqual(defaultBudget(for: .research, depth: 1), 16384)
    }

    func testDocumentationBudgetDepth1() {
        XCTAssertEqual(defaultBudget(for: .documentation, depth: 1), 16384)
    }

    func testPlanBudgetDepth1() {
        XCTAssertEqual(defaultBudget(for: .plan, depth: 1), 12288)
    }

    func testReviewBudgetDepth1() {
        XCTAssertEqual(defaultBudget(for: .review, depth: 1), 12288)
    }

    func testExploreBudgetDepth1() {
        XCTAssertEqual(defaultBudget(for: .explore, depth: 1), 8192)
    }

    func testDebugBudgetDepth1() {
        XCTAssertEqual(defaultBudget(for: .debug, depth: 1), 8192)
    }

    func testDefaultBudgetDepth1() {
        XCTAssertEqual(defaultBudget(for: .generalPurpose, depth: 1), 8192)
    }

    // Budget at depth 2 (worker) — half of base
    func testResearchBudgetDepth2() {
        XCTAssertEqual(defaultBudget(for: .research, depth: 2), 8192)
    }

    func testPlanBudgetDepth2() {
        XCTAssertEqual(defaultBudget(for: .plan, depth: 2), 6144)
    }

    func testExploreBudgetDepth2() {
        XCTAssertEqual(defaultBudget(for: .explore, depth: 2), 4096)
    }

    func testDefaultBudgetDepth2() {
        XCTAssertEqual(defaultBudget(for: .generalPurpose, depth: 2), 4096)
    }

    // Depth 2 is always half of depth 1
    func testDepth2IsHalfOfDepth1() {
        for agentType in TestSpecializedAgentType.allCases {
            let d1 = defaultBudget(for: agentType, depth: 1)
            let d2 = defaultBudget(for: agentType, depth: 2)
            XCTAssertEqual(d2, d1 / 2, "Depth 2 should be half of depth 1 for \(agentType.rawValue)")
        }
    }

    // Max concurrent workers per depth
    func testMetaAIMaxWorkers() {
        let metaAI = TestAgentSession(delegationDepth: 0)
        XCTAssertEqual(maxConcurrentWorkers(for: metaAI), 5)
    }

    func testSubAgentMaxWorkers() {
        let subAgent = TestAgentSession(delegationDepth: 1)
        XCTAssertEqual(maxConcurrentWorkers(for: subAgent), 3)
    }

    func testWorkerMaxWorkers() {
        let worker = TestAgentSession(delegationDepth: 2)
        XCTAssertEqual(maxConcurrentWorkers(for: worker), 0)
    }

    func testDepth3MaxWorkers() {
        let deep = TestAgentSession(delegationDepth: 3)
        XCTAssertEqual(maxConcurrentWorkers(for: deep), 0)
    }

    // Total agent capacity
    func testMaxTotalAgents() {
        // 5 sub-agents × 3 workers each = 15 max concurrent + 5 sub-agents = 20
        let maxSubAgents = 5
        let maxWorkersPerSubAgent = 3
        let totalMax = maxSubAgents + maxSubAgents * maxWorkersPerSubAgent
        XCTAssertEqual(totalMax, 20)
    }

    // Budget hierarchy makes sense
    func testBudgetDecreasesByDepth() {
        for agentType in TestSpecializedAgentType.allCases {
            let d1 = defaultBudget(for: agentType, depth: 1)
            let d2 = defaultBudget(for: agentType, depth: 2)
            XCTAssertGreaterThan(d1, d2, "Depth 1 should have larger budget than depth 2 for \(agentType.rawValue)")
        }
    }
}

// MARK: - Integration: Multi-Layer Orchestration Logic

final class MultiLayerOrchestrationTests: XCTestCase {

    func testFullDelegationChain() {
        // Simulate: Meta-AI -> Sub-agent -> Worker
        let convID = UUID()
        let metaAI = TestAgentSession(delegationDepth: 0, parentSessionID: nil)
        let subAgent = TestAgentSession(
            agentType: .research, name: "Research Agent #1",
            taskDescription: "Analyze auth module",
            parentConversationID: convID,
            tokenBudget: defaultBudget(for: .research, depth: 1),
            delegationDepth: 1, parentSessionID: metaAI.id
        )
        let worker = TestAgentSession(
            agentType: .explore, name: "Explore Worker #1",
            taskDescription: "Read all auth files",
            parentConversationID: convID,
            tokenBudget: defaultBudget(for: .explore, depth: 2),
            delegationDepth: 2, parentSessionID: subAgent.id
        )

        // Verify hierarchy
        XCTAssertTrue(metaAI.canDelegate)
        XCTAssertTrue(subAgent.canDelegate)
        XCTAssertFalse(worker.canDelegate)

        // Verify budget allocation
        XCTAssertEqual(subAgent.tokenBudget, 16384)  // research at depth 1
        XCTAssertEqual(worker.tokenBudget, 4096)     // explore at depth 2

        // Verify parent chain
        XCTAssertEqual(subAgent.parentSessionID, metaAI.id)
        XCTAssertEqual(worker.parentSessionID, subAgent.id)
    }

    func testRequestDelegationSimulation() {
        // Simulate the request-approve gate logic
        var taskRegistry: [String: UUID] = [:]
        var resultCache: [String: TestCachedTaskResult] = [:]
        let cacheTTL: TimeInterval = 300

        let parent = TestAgentSession(delegationDepth: 1)
        let task = "analyze User model"
        let taskHash = computeTaskHash(task)

        // Step 1: Check depth
        guard parent.canDelegate else {
            XCTFail("Parent should be able to delegate")
            return
        }

        // Step 2: Check cache
        let cached = resultCache[taskHash]
        XCTAssertNil(cached, "No cached result should exist")

        // Step 3: Check registry
        let existing = taskRegistry[taskHash]
        XCTAssertNil(existing, "No existing worker should exist")

        // Step 4: Approve
        let workerID = UUID()
        taskRegistry[taskHash] = workerID
        XCTAssertEqual(taskRegistry[taskHash], workerID)

        // Step 5: After completion, cache result
        let result = TestCachedTaskResult(result: "User model analysis done", agentType: .explore, tokensUsed: 500)
        resultCache[taskHash] = result

        // Step 6: Second request for same task -> cached
        let secondCached = resultCache[taskHash]
        XCTAssertNotNil(secondCached)
        XCTAssertEqual(secondCached?.result, "User model analysis done")
    }

    func testChildSessionTracking() {
        let parentID = UUID()
        let sessions: [TestAgentSession] = [
            TestAgentSession(agentType: .explore, parentSessionID: parentID),
            TestAgentSession(agentType: .debug, parentSessionID: parentID),
            TestAgentSession(agentType: .research, parentSessionID: UUID()),  // Different parent
            TestAgentSession(agentType: .plan, parentSessionID: nil),         // Top level
        ]

        let children = sessions.filter { $0.parentSessionID == parentID }
        XCTAssertEqual(children.count, 2)
    }

    func testWorkerCountEnforcement() {
        let parent = TestAgentSession(delegationDepth: 1)
        let max = maxConcurrentWorkers(for: parent)  // 3

        var sessions: [TestAgentSession] = []
        // Spawn 3 active workers
        for i in 0..<3 {
            let worker = TestAgentSession(delegationDepth: 2, parentSessionID: parent.id)
            worker.state = .working
            sessions.append(worker)
        }

        let activeChildren = sessions.filter { $0.parentSessionID == parent.id && $0.state.isActive }
        XCTAssertFalse(activeChildren.count < max, "Should not be able to spawn more workers")

        // Complete one worker
        sessions[0].state = .completed
        let activeAfterCompletion = sessions.filter { $0.parentSessionID == parent.id && $0.state.isActive }
        XCTAssertTrue(activeAfterCompletion.count < max, "Should be able to spawn after completion")
    }

    func testBudgetReallocationWithHierarchy() {
        let totalPool = 500_000

        // Create hierarchy: 2 sub-agents, each with 1 worker
        var sessions: [TestAgentSession] = [
            TestAgentSession(tokenBudget: 16384, delegationDepth: 1),  // sub-agent 1
            TestAgentSession(tokenBudget: 4096, delegationDepth: 2),   // worker 1a
            TestAgentSession(tokenBudget: 12288, delegationDepth: 1),  // sub-agent 2
            TestAgentSession(tokenBudget: 4096, delegationDepth: 2),   // worker 2a
        ]

        let allocated = sessions.map(\.tokenBudget).reduce(0, +)
        let free = totalPool - allocated
        XCTAssertEqual(allocated, 36864)
        XCTAssertEqual(free, 463136)

        // Complete worker 1a
        sessions[1].state = .completed
        sessions[1].tokensUsed = 2000

        // Reclaim from completed
        for session in sessions where session.state.isTerminal {
            session.tokenBudget = session.tokensUsed
        }

        let newAllocated = sessions.map(\.tokenBudget).reduce(0, +)
        XCTAssertEqual(newAllocated, 34768)  // 36864 - 2096 reclaimed
    }
}
