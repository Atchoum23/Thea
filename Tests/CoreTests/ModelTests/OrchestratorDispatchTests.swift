// OrchestratorDispatchTests.swift
// Tests for TheaAgentOrchestrator pure dispatch logic: task routing,
// session lifecycle, activity logging, budget management, and synthesis.

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum AgentType: String, CaseIterable, Codable, Sendable {
    case generalPurpose
    case research
    case codeGeneration
    case codeReview
    case debugging
    case documentation
    case planning
    case testing
    case explore
    case refactor
    case security
    case performance
    case design
    case data
    case devops

    var displayName: String {
        switch self {
        case .generalPurpose: "General Purpose"
        case .research: "Research"
        case .codeGeneration: "Code Generation"
        case .codeReview: "Code Review"
        case .debugging: "Debugging"
        case .documentation: "Documentation"
        case .planning: "Planning"
        case .testing: "Testing"
        case .explore: "Explore"
        case .refactor: "Refactor"
        case .security: "Security"
        case .performance: "Performance"
        case .design: "Design"
        case .data: "Data"
        case .devops: "DevOps"
        }
    }

    var defaultBudget: Int {
        switch self {
        case .research, .documentation: 16384
        case .planning, .codeReview: 12288
        default: 8192
        }
    }
}

private enum AgentState: String, CaseIterable, Codable, Sendable {
    case idle
    case planning
    case working
    case awaitingApproval
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
        case .planning, .working, .awaitingApproval: true
        default: false
        }
    }
}

private struct AgentSession: Identifiable, Sendable {
    let id: UUID
    let agentType: AgentType
    var state: AgentState
    var tokenBudget: Int
    var tokensUsed: Int
    var startedAt: Date
    var completedAt: Date?
    var output: String
    var artifacts: [String]

    init(
        id: UUID = UUID(),
        agentType: AgentType,
        state: AgentState = .idle,
        tokenBudget: Int? = nil,
        tokensUsed: Int = 0,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        output: String = "",
        artifacts: [String] = []
    ) {
        self.id = id
        self.agentType = agentType
        self.state = state
        self.tokenBudget = tokenBudget ?? agentType.defaultBudget
        self.tokensUsed = tokensUsed
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.output = output
        self.artifacts = artifacts
    }

    var tokenUsageRatio: Double {
        guard tokenBudget > 0 else { return 0 }
        return Double(tokensUsed) / Double(tokenBudget)
    }
}

private struct Activity: Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID?
    let event: String
    let detail: String
    let timestamp: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID? = nil,
        event: String,
        detail: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.event = event
        self.detail = detail
        self.timestamp = timestamp
    }
}

// MARK: - Pure Functions (mirrors TheaAgentOrchestrator)

private func selectAgentType(for taskDescription: String) -> AgentType {
    let lowered = taskDescription.lowercased()
    if lowered.contains("research") || lowered.contains("find") || lowered.contains("search") {
        return .research
    } else if lowered.contains("write code") || lowered.contains("implement") || lowered.contains("create") {
        return .codeGeneration
    } else if lowered.contains("review") || lowered.contains("check") {
        return .codeReview
    } else if lowered.contains("debug") || lowered.contains("fix") || lowered.contains("bug") {
        return .debugging
    } else if lowered.contains("document") || lowered.contains("docs") {
        return .documentation
    } else if lowered.contains("plan") || lowered.contains("design") {
        return .planning
    } else if lowered.contains("test") {
        return .testing
    } else if lowered.contains("explore") || lowered.contains("investigate") {
        return .explore
    } else if lowered.contains("refactor") || lowered.contains("clean") {
        return .refactor
    } else if lowered.contains("security") || lowered.contains("vulnerability") {
        return .security
    } else if lowered.contains("performance") || lowered.contains("optimize") {
        return .performance
    }
    return .generalPurpose
}

private func synthesizeResults(from sessions: [AgentSession]) -> String {
    let completed = sessions.filter { $0.state == .completed }
    guard !completed.isEmpty else { return "No completed agent results to synthesize." }

    var parts: [String] = []
    for session in completed {
        var section = "## \(session.agentType.displayName)\n"
        let outputPreview = session.output.prefix(500)
        section += String(outputPreview)
        if !session.artifacts.isEmpty {
            section += "\n\n### Artifacts\n"
            for artifact in session.artifacts {
                section += "- \(artifact)\n"
            }
        }
        parts.append(section)
    }
    return parts.joined(separator: "\n\n---\n\n")
}

private func reallocateContextBudget(
    sessions: inout [AgentSession],
    totalTokenPool: Int = 500_000
) {
    let completed = sessions.filter { $0.state.isTerminal }
    let active = sessions.filter { $0.state == .working && $0.tokenUsageRatio >= 0.6 }

    for i in sessions.indices where sessions[i].state.isTerminal {
        sessions[i].tokenBudget = sessions[i].tokensUsed
    }

    let allocatedTokens = sessions.map(\.tokenBudget).reduce(0, +)
    let freeTokens = totalTokenPool - allocatedTokens

    guard !active.isEmpty, freeTokens > 0, !completed.isEmpty else { return }

    let perAgent = freeTokens / active.count
    for i in sessions.indices where sessions[i].state == .working && sessions[i].tokenUsageRatio >= 0.6 {
        sessions[i].tokenBudget += perAgent
    }
}

private func pruneOldSessions(
    sessions: inout [AgentSession],
    olderThan interval: TimeInterval = 3600
) {
    let cutoff = Date().addingTimeInterval(-interval)
    sessions.removeAll { session in
        session.state.isTerminal
            && (session.completedAt ?? session.startedAt) < cutoff
    }
}

// MARK: - Agent Type Selection Tests

final class AgentTypeSelectionTests: XCTestCase {
    func testResearchTask() {
        XCTAssertEqual(selectAgentType(for: "Research the latest Swift concurrency patterns"), .research)
    }

    func testFindTask() {
        XCTAssertEqual(selectAgentType(for: "Find all uses of deprecated API"), .research)
    }

    func testCodeGenerationTask() {
        XCTAssertEqual(selectAgentType(for: "Write code for a new authentication module"), .codeGeneration)
    }

    func testImplementTask() {
        XCTAssertEqual(selectAgentType(for: "Implement the user profile page"), .codeGeneration)
    }

    func testCreateTask() {
        XCTAssertEqual(selectAgentType(for: "Create a new settings view"), .codeGeneration)
    }

    func testCodeReviewTask() {
        XCTAssertEqual(selectAgentType(for: "Review the changes in PR #42"), .codeReview)
    }

    func testDebugTask() {
        XCTAssertEqual(selectAgentType(for: "Debug the login crash"), .debugging)
    }

    func testFixTask() {
        XCTAssertEqual(selectAgentType(for: "Fix the bug in the payment flow"), .debugging)
    }

    func testDocumentationTask() {
        XCTAssertEqual(selectAgentType(for: "Document the API endpoints"), .documentation)
    }

    func testPlanningTask() {
        XCTAssertEqual(selectAgentType(for: "Plan the migration to SwiftUI"), .planning)
    }

    func testTestingTask() {
        XCTAssertEqual(selectAgentType(for: "Write tests for the ChatManager"), .testing)
    }

    func testExploreTask() {
        XCTAssertEqual(selectAgentType(for: "Explore the codebase architecture"), .explore)
    }

    func testRefactorTask() {
        XCTAssertEqual(selectAgentType(for: "Refactor the networking layer"), .refactor)
    }

    func testSecurityTask() {
        XCTAssertEqual(selectAgentType(for: "Audit security vulnerabilities"), .security)
    }

    func testPerformanceTask() {
        XCTAssertEqual(selectAgentType(for: "Optimize database queries"), .performance)
    }

    func testGenericTask() {
        XCTAssertEqual(selectAgentType(for: "What is the meaning of life?"), .generalPurpose)
    }

    func testEmptyTask() {
        XCTAssertEqual(selectAgentType(for: ""), .generalPurpose)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(selectAgentType(for: "RESEARCH AI models"), .research)
    }
}

// MARK: - Synthesis Tests

final class DispatchSynthesisTests: XCTestCase {
    func testEmptySessions() {
        let result = synthesizeResults(from: [])
        XCTAssertEqual(result, "No completed agent results to synthesize.")
    }

    func testOnlyWorkingSessions() {
        let sessions = [
            AgentSession(agentType: .research, state: .working, output: "In progress...")
        ]
        let result = synthesizeResults(from: sessions)
        XCTAssertEqual(result, "No completed agent results to synthesize.")
    }

    func testSingleCompletedSession() {
        let sessions = [
            AgentSession(agentType: .research, state: .completed, output: "Found 5 relevant papers")
        ]
        let result = synthesizeResults(from: sessions)
        XCTAssertTrue(result.contains("Research"))
        XCTAssertTrue(result.contains("Found 5 relevant papers"))
    }

    func testMultipleCompletedSessions() {
        let sessions = [
            AgentSession(agentType: .research, state: .completed, output: "Research findings"),
            AgentSession(agentType: .codeGeneration, state: .completed, output: "Generated code"),
            AgentSession(agentType: .testing, state: .working, output: "Still testing...")
        ]
        let result = synthesizeResults(from: sessions)
        XCTAssertTrue(result.contains("Research"))
        XCTAssertTrue(result.contains("Code Generation"))
        XCTAssertFalse(result.contains("Testing"))
    }

    func testSessionWithArtifacts() {
        let sessions = [
            AgentSession(
                agentType: .codeGeneration, state: .completed,
                output: "Generated module", artifacts: ["auth.swift", "login.swift"]
            )
        ]
        let result = synthesizeResults(from: sessions)
        XCTAssertTrue(result.contains("Artifacts"))
        XCTAssertTrue(result.contains("auth.swift"))
        XCTAssertTrue(result.contains("login.swift"))
    }

    func testOutputTruncation() {
        let longOutput = String(repeating: "x", count: 1000)
        let sessions = [
            AgentSession(agentType: .research, state: .completed, output: longOutput)
        ]
        let result = synthesizeResults(from: sessions)
        // Output should be truncated to 500 chars
        XCTAssertTrue(result.count < 600)
    }

    func testMixedStates() {
        let sessions = [
            AgentSession(agentType: .research, state: .completed, output: "Done"),
            AgentSession(agentType: .debugging, state: .failed, output: "Error"),
            AgentSession(agentType: .testing, state: .cancelled, output: "Stopped"),
            AgentSession(agentType: .planning, state: .working, output: "Working")
        ]
        let result = synthesizeResults(from: sessions)
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
            AgentSession(agentType: .research, state: .working, tokenBudget: 16384, tokensUsed: 5000),
            AgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 3000)
        ]
        let originalBudgets = sessions.map(\.tokenBudget)
        reallocateContextBudget(sessions: &sessions)
        // No terminal sessions to reclaim from
        XCTAssertEqual(sessions[0].tokenBudget, originalBudgets[0])
        XCTAssertEqual(sessions[1].tokenBudget, originalBudgets[1])
    }

    func testReclaimFromCompletedSessions() {
        var sessions = [
            AgentSession(agentType: .research, state: .completed, tokenBudget: 16384, tokensUsed: 8000),
            AgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 6000)
        ]
        reallocateContextBudget(sessions: &sessions)
        // Completed session should have budget shrunk to actual usage
        XCTAssertEqual(sessions[0].tokenBudget, 8000)
        // Active session under pressure (73% usage) gets freed tokens
        XCTAssertTrue(sessions[1].tokenBudget > 8192)
    }

    func testNoReallocationWhenActiveNotUnderPressure() {
        var sessions = [
            AgentSession(agentType: .research, state: .completed, tokenBudget: 16384, tokensUsed: 8000),
            AgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 1000)
        ]
        reallocateContextBudget(sessions: &sessions)
        // Active session at 12% usage — not under pressure
        XCTAssertEqual(sessions[0].tokenBudget, 8000) // Shrunk
        XCTAssertEqual(sessions[1].tokenBudget, 8192) // Unchanged — not under pressure
    }

    func testEvenDistribution() {
        var sessions = [
            AgentSession(agentType: .research, state: .completed, tokenBudget: 100_000, tokensUsed: 10_000),
            AgentSession(agentType: .codeGeneration, state: .working, tokenBudget: 8192, tokensUsed: 6000),
            AgentSession(agentType: .testing, state: .working, tokenBudget: 8192, tokensUsed: 7000)
        ]
        reallocateContextBudget(sessions: &sessions)
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
            AgentSession(
                agentType: .research, state: .completed,
                startedAt: Date().addingTimeInterval(-7200),
                completedAt: Date().addingTimeInterval(-7200)
            ),
            AgentSession(agentType: .codeGeneration, state: .working)
        ]
        pruneOldSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].agentType, .codeGeneration)
    }

    func testKeepRecentCompletedSessions() {
        var sessions = [
            AgentSession(
                agentType: .research, state: .completed,
                completedAt: Date()
            )
        ]
        pruneOldSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertEqual(sessions.count, 1)
    }

    func testKeepActiveSessions() {
        var sessions = [
            AgentSession(
                agentType: .research, state: .working,
                startedAt: Date().addingTimeInterval(-7200)
            )
        ]
        pruneOldSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertEqual(sessions.count, 1) // Active, not pruned
    }

    func testPruneEmpty() {
        var sessions: [AgentSession] = []
        pruneOldSessions(sessions: &sessions)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testPruneFailedSessions() {
        var sessions = [
            AgentSession(
                agentType: .debugging, state: .failed,
                startedAt: Date().addingTimeInterval(-7200),
                completedAt: Date().addingTimeInterval(-7200)
            )
        ]
        pruneOldSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testPruneCancelledSessions() {
        var sessions = [
            AgentSession(
                agentType: .testing, state: .cancelled,
                startedAt: Date().addingTimeInterval(-7200),
                completedAt: Date().addingTimeInterval(-7200)
            )
        ]
        pruneOldSessions(sessions: &sessions, olderThan: 3600)
        XCTAssertTrue(sessions.isEmpty)
    }
}

// MARK: - Activity Logging Tests

final class DispatchActivityLoggingTests: XCTestCase {
    func testActivityCreation() {
        let sessionID = UUID()
        let activity = Activity(
            sessionID: sessionID,
            event: "session_created",
            detail: "Research agent spawned"
        )
        XCTAssertEqual(activity.sessionID, sessionID)
        XCTAssertEqual(activity.event, "session_created")
        XCTAssertTrue(activity.detail.contains("Research"))
    }

    func testActivityWithoutSession() {
        let activity = Activity(event: "system_event", detail: "Budget reallocation")
        XCTAssertNil(activity.sessionID)
    }

    func testActivityIdentifiable() {
        let a = Activity(event: "a")
        let b = Activity(event: "b")
        XCTAssertNotEqual(a.id, b.id)
    }

    func testActivityLogCapacity() {
        var log: [Activity] = []
        let maxCapacity = 500
        for i in 0 ..< 600 {
            log.append(Activity(event: "event_\(i)"))
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
        XCTAssertEqual(AgentType.research.defaultBudget, 16384)
    }

    func testDocumentationBudget() {
        XCTAssertEqual(AgentType.documentation.defaultBudget, 16384)
    }

    func testPlanningBudget() {
        XCTAssertEqual(AgentType.planning.defaultBudget, 12288)
    }

    func testCodeReviewBudget() {
        XCTAssertEqual(AgentType.codeReview.defaultBudget, 12288)
    }

    func testDefaultBudget() {
        XCTAssertEqual(AgentType.generalPurpose.defaultBudget, 8192)
        XCTAssertEqual(AgentType.explore.defaultBudget, 8192)
        XCTAssertEqual(AgentType.debugging.defaultBudget, 8192)
    }

    func testAllBudgetsPositive() {
        for agentType in AgentType.allCases {
            XCTAssertTrue(agentType.defaultBudget > 0, "\(agentType)")
        }
    }

    func testBudgetTiers() {
        let budgets = Set(AgentType.allCases.map(\.defaultBudget))
        XCTAssertEqual(budgets.count, 3) // 3 tiers: 8192, 12288, 16384
    }
}

// MARK: - Token Usage Tests

final class DispatchTokenUsageTests: XCTestCase {
    func testZeroUsage() {
        let session = AgentSession(agentType: .research, tokensUsed: 0)
        XCTAssertEqual(session.tokenUsageRatio, 0.0, accuracy: 0.001)
    }

    func testHalfUsage() {
        let session = AgentSession(agentType: .research, tokenBudget: 1000, tokensUsed: 500)
        XCTAssertEqual(session.tokenUsageRatio, 0.5, accuracy: 0.001)
    }

    func testFullUsage() {
        let session = AgentSession(agentType: .research, tokenBudget: 1000, tokensUsed: 1000)
        XCTAssertEqual(session.tokenUsageRatio, 1.0, accuracy: 0.001)
    }

    func testOverUsage() {
        let session = AgentSession(agentType: .research, tokenBudget: 1000, tokensUsed: 1500)
        XCTAssertEqual(session.tokenUsageRatio, 1.5, accuracy: 0.001)
    }

    func testZeroBudget() {
        let session = AgentSession(agentType: .research, tokenBudget: 0, tokensUsed: 100)
        XCTAssertEqual(session.tokenUsageRatio, 0.0)
    }
}
