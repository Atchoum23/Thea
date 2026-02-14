// OrchestratorDispatchTests.swift
// Tests for TheaAgentOrchestrator pure dispatch logic: task routing,
// session lifecycle, activity logging, budget management, and synthesis.

// Mirrored types and pure functions are in OrchestratorDispatchTestHelpers.swift

import Foundation
import XCTest

// MARK: - Agent Type Selection Tests

final class AgentTypeSelectionTests: XCTestCase {
    func testResearchTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Research the latest Swift concurrency patterns"), .research)
    }

    func testFindTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Find all uses of deprecated API"), .research)
    }

    func testCodeGenerationTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Write code for a new authentication module"), .codeGeneration)
    }

    func testImplementTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Implement the user profile page"), .codeGeneration)
    }

    func testCreateTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Create a new settings view"), .codeGeneration)
    }

    func testCodeReviewTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Review the changes in PR #42"), .codeReview)
    }

    func testDebugTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Debug the login crash"), .debugging)
    }

    func testFixTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Fix the bug in the payment flow"), .debugging)
    }

    func testDocumentationTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Document the API endpoints"), .documentation)
    }

    func testPlanningTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Plan the migration to SwiftUI"), .planning)
    }

    func testTestingTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Write tests for the ChatManager"), .testing)
    }

    func testExploreTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Explore the codebase architecture"), .explore)
    }

    func testRefactorTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Refactor the networking layer"), .refactor)
    }

    func testSecurityTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Audit security vulnerabilities"), .security)
    }

    func testPerformanceTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "Optimize database queries"), .performance)
    }

    func testGenericTask() {
        XCTAssertEqual(selectDispatchAgentType(for: "What is the meaning of life?"), .generalPurpose)
    }

    func testEmptyTask() {
        XCTAssertEqual(selectDispatchAgentType(for: ""), .generalPurpose)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(selectDispatchAgentType(for: "RESEARCH AI models"), .research)
    }
}

// MARK: - Synthesis Tests

final class DispatchSynthesisTests: XCTestCase {
    func testEmptySessions() {
        let result = synthesizeDispatchResults(from: [])
        XCTAssertEqual(result, "No completed agent results to synthesize.")
    }

    func testOnlyWorkingSessions() {
        let sessions = [
            DispatchAgentSession(agentType: .research, state: .working, output: "In progress...")
        ]
        let result = synthesizeDispatchResults(from: sessions)
        XCTAssertEqual(result, "No completed agent results to synthesize.")
    }

    func testSingleCompletedSession() {
        let sessions = [
            DispatchAgentSession(agentType: .research, state: .completed, output: "Found 5 relevant papers")
        ]
        let result = synthesizeDispatchResults(from: sessions)
        XCTAssertTrue(result.contains("Research"))
        XCTAssertTrue(result.contains("Found 5 relevant papers"))
    }

    func testMultipleCompletedSessions() {
        let sessions = [
            DispatchAgentSession(agentType: .research, state: .completed, output: "Research findings"),
            DispatchAgentSession(agentType: .codeGeneration, state: .completed, output: "Generated code"),
            DispatchAgentSession(agentType: .testing, state: .working, output: "Still testing...")
        ]
        let result = synthesizeDispatchResults(from: sessions)
        XCTAssertTrue(result.contains("Research"))
        XCTAssertTrue(result.contains("Code Generation"))
        XCTAssertFalse(result.contains("Testing"))
    }

    func testSessionWithArtifacts() {
        let sessions = [
            DispatchAgentSession(
                agentType: .codeGeneration, state: .completed,
                output: "Generated module", artifacts: ["auth.swift", "login.swift"]
            )
        ]
        let result = synthesizeDispatchResults(from: sessions)
        XCTAssertTrue(result.contains("Artifacts"))
        XCTAssertTrue(result.contains("auth.swift"))
        XCTAssertTrue(result.contains("login.swift"))
    }

    func testOutputTruncation() {
        let longOutput = String(repeating: "x", count: 1000)
        let sessions = [
            DispatchAgentSession(agentType: .research, state: .completed, output: longOutput)
        ]
        let result = synthesizeDispatchResults(from: sessions)
        // Output should be truncated to 500 chars
        XCTAssertTrue(result.count < 600)
    }

    func testMixedStates() {
        let sessions = [
            DispatchAgentSession(agentType: .research, state: .completed, output: "Done"),
            DispatchAgentSession(agentType: .debugging, state: .failed, output: "Error"),
            DispatchAgentSession(agentType: .testing, state: .cancelled, output: "Stopped"),
            DispatchAgentSession(agentType: .planning, state: .working, output: "Working")
        ]
        let result = synthesizeDispatchResults(from: sessions)
        XCTAssertTrue(result.contains("Research"))
        XCTAssertFalse(result.contains("Debugging")) // Failed, not completed
        XCTAssertFalse(result.contains("Testing")) // Cancelled
        XCTAssertFalse(result.contains("Planning")) // Working
    }
}

// MARK: - Budget Reallocation Tests

final class DispatchBudgetReallocationTests: XCTestCase {
    func testNoReallocationWhenAllActive() {
        var sessions = [
            DispatchAgentSession(agentType: .research, state: .working, tokenBudget: 16384, tokensUsed: 5000),
            DispatchAgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 3000)
        ]
        let originalBudgets = sessions.map(\.tokenBudget)
        reallocateDispatchContextBudget(sessions: &sessions)
        // No terminal sessions to reclaim from
        XCTAssertEqual(sessions[0].tokenBudget, originalBudgets[0])
        XCTAssertEqual(sessions[1].tokenBudget, originalBudgets[1])
    }

    func testReclaimFromCompletedSessions() {
        var sessions = [
            DispatchAgentSession(agentType: .research, state: .completed, tokenBudget: 16384, tokensUsed: 8000),
            DispatchAgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 6000)
        ]
        reallocateDispatchContextBudget(sessions: &sessions)
        // Completed session should have budget shrunk to actual usage
        XCTAssertEqual(sessions[0].tokenBudget, 8000)
        // Active session under pressure (73% usage) gets freed tokens
        XCTAssertTrue(sessions[1].tokenBudget > 8192)
    }

    func testNoReallocationWhenActiveNotUnderPressure() {
        var sessions = [
            DispatchAgentSession(agentType: .research, state: .completed, tokenBudget: 16384, tokensUsed: 8000),
            DispatchAgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 1000)
        ]
        reallocateDispatchContextBudget(sessions: &sessions)
        // Active session at 12% usage -- not under pressure
        XCTAssertEqual(sessions[0].tokenBudget, 8000) // Shrunk
        XCTAssertEqual(sessions[1].tokenBudget, 8192) // Unchanged -- not under pressure
    }

    func testEvenDistribution() {
        var sessions = [
            DispatchAgentSession(agentType: .research, state: .completed, tokenBudget: 100_000, tokensUsed: 10_000),
            DispatchAgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 6000),
            DispatchAgentSession(agentType: .testing, state: .working, tokenBudget: 8192, tokensUsed: 7000)
        ]
        reallocateDispatchContextBudget(sessions: &sessions)
        // Both active sessions should get approximately equal extra budget
        let budget1 = sessions[1].tokenBudget
        let budget2 = sessions[2].tokenBudget
        XCTAssertTrue(budget1 > 8192)
        XCTAssertTrue(budget2 > 8192)
    }
}

// MARK: - Session Pruning Tests

final class DispatchSessionPruningTests: XCTestCase {
    func testPruneOldCompletedSessions() {
        var sessions = [
            DispatchAgentSession(
                agentType: .research, state: .completed,
                startedAt: Date().addingTimeInterval(-7200),
                completedAt: Date().addingTimeInterval(-7200)
            ),
            DispatchAgentSession(agentType: .codeGeneration, state: .working)
        ]
        pruneOldDispatchSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].agentType, .codeGeneration)
    }

    func testKeepRecentCompletedSessions() {
        var sessions = [
            DispatchAgentSession(
                agentType: .research, state: .completed,
                completedAt: Date()
            )
        ]
        pruneOldDispatchSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertEqual(sessions.count, 1)
    }

    func testKeepActiveSessions() {
        var sessions = [
            DispatchAgentSession(
                agentType: .research, state: .working,
                startedAt: Date().addingTimeInterval(-7200)
            )
        ]
        pruneOldDispatchSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertEqual(sessions.count, 1) // Active, not pruned
    }

    func testPruneEmpty() {
        var sessions: [DispatchAgentSession] = []
        pruneOldDispatchSessions(sessions: &sessions)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testPruneFailedSessions() {
        var sessions = [
            DispatchAgentSession(
                agentType: .debugging, state: .failed,
                startedAt: Date().addingTimeInterval(-7200),
                completedAt: Date().addingTimeInterval(-7200)
            )
        ]
        pruneOldDispatchSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testPruneCancelledSessions() {
        var sessions = [
            DispatchAgentSession(
                agentType: .testing, state: .cancelled,
                startedAt: Date().addingTimeInterval(-7200),
                completedAt: Date().addingTimeInterval(-7200)
            )
        ]
        pruneOldDispatchSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertTrue(sessions.isEmpty)
    }
}

// MARK: - Activity Logging Tests

final class DispatchActivityLoggingTests: XCTestCase {
    func testActivityCreation() {
        let sessionID = UUID()
        let activity = DispatchActivity(
            sessionID: sessionID,
            event: "session_created",
            detail: "Research agent spawned"
        )
        XCTAssertEqual(activity.sessionID, sessionID)
        XCTAssertEqual(activity.event, "session_created")
        XCTAssertTrue(activity.detail.contains("Research"))
    }

    func testActivityWithoutSession() {
        let activity = DispatchActivity(event: "system_event", detail: "Budget reallocation")
        XCTAssertNil(activity.sessionID)
    }

    func testActivityIdentifiable() {
        let a = DispatchActivity(event: "a")
        let b = DispatchActivity(event: "b")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testActivityLogCapacity() {
        var log: [DispatchActivity] = []
        let maxCapacity = 500
        for i in 0 ..< 600 {
            log.append(DispatchActivity(event: "event_\(i)"))
            if log.count > maxCapacity {
                log.removeFirst(log.count - maxCapacity)
            }
        }
        XCTAssertEqual(log.count, maxCapacity)
        XCTAssertEqual(log.first?.event, "event_100")
    }
}

// MARK: - Default Budget Tests

final class DispatchDefaultBudgetTests: XCTestCase {
    func testResearchBudget() {
        XCTAssertEqual(DispatchAgentType.research.defaultBudget, 16384)
    }

    func testDocumentationBudget() {
        XCTAssertEqual(DispatchAgentType.documentation.defaultBudget, 16384)
    }

    func testPlanningBudget() {
        XCTAssertEqual(DispatchAgentType.planning.defaultBudget, 12288)
    }

    func testCodeReviewBudget() {
        XCTAssertEqual(DispatchAgentType.codeReview.defaultBudget, 12288)
    }

    func testDefaultBudget() {
        XCTAssertEqual(DispatchAgentType.generalPurpose.defaultBudget, 8192)
        XCTAssertEqual(DispatchAgentType.explore.defaultBudget, 8192)
        XCTAssertEqual(DispatchAgentType.debugging.defaultBudget, 8192)
    }

    func testAllBudgetsPositive() {
        for agentType in DispatchAgentType.allCases {
            XCTAssertTrue(agentType.defaultBudget > 0, "\(agentType)")
        }
    }

    func testBudgetTiers() {
        let budgets = Set(DispatchAgentType.allCases.map(\.defaultBudget))
        XCTAssertEqual(budgets.count, 3) // 3 tiers: 8192, 12288, 16384
    }
}

// MARK: - Token Usage Tests

final class DispatchTokenUsageTests: XCTestCase {
    func testZeroUsage() {
        let session = DispatchAgentSession(agentType: .research, tokensUsed: 0)
        XCTAssertEqual(session.tokenUsageRatio, 0.0, accuracy: 0.001)
    }

    func testHalfUsage() {
        let session = DispatchAgentSession(agentType: .research, tokenBudget: 1000, tokensUsed: 500)
        XCTAssertEqual(session.tokenUsageRatio, 0.5, accuracy: 0.001)
    }

    func testFullUsage() {
        let session = DispatchAgentSession(agentType: .research, tokenBudget: 1000, tokensUsed: 1000)
        XCTAssertEqual(session.tokenUsageRatio, 1.0, accuracy: 0.001)
    }

    func testOverUsage() {
        let session = DispatchAgentSession(agentType: .research, tokenBudget: 1000, tokensUsed: 1500)
        XCTAssertEqual(session.tokenUsageRatio, 1.5, accuracy: 0.001)
    }

    func testZeroBudget() {
        let session = DispatchAgentSession(agentType: .research, tokenBudget: 0, tokensUsed: 100)
        XCTAssertEqual(session.tokenUsageRatio, 0.0)
    }
}
