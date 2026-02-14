// MultiLayerDelegationTests.swift
// Tests for B-MLT multi-layer delegation types:
// - Delegation depth cap (B-MLT1)
// - Request-approve gate decisions (B-MLT2)
// Logic tests in MultiLayerDelegationLogicTests.swift

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

/// Mirrors TheaAgentSession with delegation hierarchy
private final class TestAgentSession: Identifiable {
    let id: UUID
    var state: TestAgentState = .idle
    let delegationDepth: Int
    let parentSessionID: UUID?
    var canDelegate: Bool { delegationDepth < 2 }

    init(
        id: UUID = UUID(),
        delegationDepth: Int = 1,
        parentSessionID: UUID? = nil
    ) {
        self.id = id
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
    }

    func testApproveWhenWithinDepth() {
        let subAgent = TestAgentSession(delegationDepth: 1)
        XCTAssertTrue(subAgent.canDelegate)
    }

    func testDenyWhenMaxWorkersReached() {
        let parent = TestAgentSession(delegationDepth: 1)
        let max = maxConcurrentWorkers(for: parent)
        XCTAssertEqual(max, 3)
        let activeCount = 3
        XCTAssertFalse(activeCount < max, "Should deny when at worker limit")
    }

    func testApproveWhenBelowWorkerLimit() {
        let parent = TestAgentSession(delegationDepth: 1)
        let activeCount = 2
        let max = maxConcurrentWorkers(for: parent)
        XCTAssertTrue(activeCount < max, "Should approve when below limit")
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
