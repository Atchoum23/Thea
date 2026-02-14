// AgentOrchestratorLogicTests.swift
// Tests for orchestrator logic: synthesize, budget reallocation, error handling,
// default budgets, session pruning, and token usage ratios.
// Split from AgentOrchestrationTypesTests.swift to meet file_length limit.

import Foundation
import XCTest

// MARK: - Mirrored: SpecializedAgentType (for budget tests)

private enum TestAgentType: String, Codable, CaseIterable {
    case explore, plan, generalPurpose, bash, research
    case database, security, performance, api, testing
    case documentation, refactoring, review, debug, deployment
}

// MARK: - Mirrored: Orchestrator Synthesize Logic

private enum OrchestratorLogic {
    struct MockSession {
        let name: String
        let agentType: String
        let state: String
        let agentMessages: [String]
        let artifactDescriptions: [String]
    }

    static func synthesizeResults(from sessions: [MockSession]) -> String {
        let completed = sessions.filter { $0.state == "completed" }
        guard !completed.isEmpty else {
            return "No agent results available yet."
        }

        var parts: [String] = []
        for session in completed {
            let output = session.agentMessages.joined(separator: "\n")
            let artifactSummary = session.artifactDescriptions.joined(separator: ", ")
            var sessionSummary = "**\(session.name)** (\(session.agentType)):\n\(output.prefix(500))"
            if !artifactSummary.isEmpty {
                sessionSummary += "\nArtifacts: \(artifactSummary)"
            }
            parts.append(sessionSummary)
        }

        return parts.joined(separator: "\n\n---\n\n")
    }
}

// MARK: - Mirrored: Budget Logic

private enum BudgetLogic {
    struct BudgetSession {
        var tokenBudget: Int
        var tokensUsed: Int
        var isTerminal: Bool
        var isActive: Bool
        var contextPressure: String
    }

    static func reallocate(
        sessions: inout [BudgetSession],
        totalPool: Int
    ) {
        let allocated = sessions.map(\.tokenBudget).reduce(0, +)
        var freeTokens = totalPool - allocated

        for idx in sessions.indices where sessions[idx].isTerminal {
            let freed = sessions[idx].tokenBudget - sessions[idx].tokensUsed
            sessions[idx].tokenBudget = sessions[idx].tokensUsed
            freeTokens += freed
        }

        let needyIndices = sessions.indices.filter {
            sessions[$0].isActive && sessions[$0].contextPressure != "nominal"
        }
        if !needyIndices.isEmpty && freeTokens > 0 {
            let perAgent = freeTokens / needyIndices.count
            for idx in needyIndices {
                sessions[idx].tokenBudget += perAgent
            }
        }
    }
}

// MARK: - Mirrored: ErrorLogger

private enum TestErrorLogger {
    enum TestError: Error, LocalizedError {
        case sampleError
        case detailedError(String)

        var errorDescription: String? {
            switch self {
            case .sampleError: "Sample error"
            case .detailedError(let msg): msg
            }
        }
    }

    static func tryOrNil<T>(
        _ body: () throws -> T
    ) -> T? {
        do {
            return try body()
        } catch {
            return nil
        }
    }

    static func tryOrDefault<T>(
        _ defaultValue: T,
        _ body: () throws -> T
    ) -> T {
        do {
            return try body()
        } catch {
            return defaultValue
        }
    }
}

// MARK: - Orchestrator Synthesize Tests

final class OrchestratorSynthesizeTests: XCTestCase {

    func testSynthesizeNoSessions() {
        let result = OrchestratorLogic.synthesizeResults(from: [])
        XCTAssertEqual(result, "No agent results available yet.")
    }

    func testSynthesizeOnlyWorkingSessions() {
        let sessions = [
            OrchestratorLogic.MockSession(
                name: "Agent #1", agentType: "research",
                state: "working", agentMessages: ["In progress..."],
                artifactDescriptions: []
            )
        ]
        let result = OrchestratorLogic.synthesizeResults(from: sessions)
        XCTAssertEqual(result, "No agent results available yet.")
    }

    func testSynthesizeSingleCompleted() {
        let sessions = [
            OrchestratorLogic.MockSession(
                name: "Research Agent #1", agentType: "research",
                state: "completed", agentMessages: ["Found X", "Also found Y"],
                artifactDescriptions: []
            )
        ]
        let result = OrchestratorLogic.synthesizeResults(from: sessions)
        XCTAssertTrue(result.contains("**Research Agent #1**"))
        XCTAssertTrue(result.contains("(research)"))
        XCTAssertTrue(result.contains("Found X"))
        XCTAssertTrue(result.contains("Also found Y"))
    }

    func testSynthesizeMultipleCompleted() {
        let sessions = [
            OrchestratorLogic.MockSession(
                name: "Agent #1", agentType: "research",
                state: "completed", agentMessages: ["Result A"],
                artifactDescriptions: []
            ),
            OrchestratorLogic.MockSession(
                name: "Agent #2", agentType: "plan",
                state: "completed", agentMessages: ["Result B"],
                artifactDescriptions: []
            )
        ]
        let result = OrchestratorLogic.synthesizeResults(from: sessions)
        XCTAssertTrue(result.contains("---"))
        XCTAssertTrue(result.contains("Agent #1"))
        XCTAssertTrue(result.contains("Agent #2"))
    }

    func testSynthesizeWithArtifacts() {
        let sessions = [
            OrchestratorLogic.MockSession(
                name: "Code Agent", agentType: "testing",
                state: "completed", agentMessages: ["Generated tests"],
                artifactDescriptions: ["[code: Test File]", "[text: Summary]"]
            )
        ]
        let result = OrchestratorLogic.synthesizeResults(from: sessions)
        XCTAssertTrue(result.contains("Artifacts:"))
        XCTAssertTrue(result.contains("[code: Test File]"))
    }

    func testSynthesizeMixedStates() {
        let sessions = [
            OrchestratorLogic.MockSession(
                name: "A", agentType: "research",
                state: "completed", agentMessages: ["Done"],
                artifactDescriptions: []
            ),
            OrchestratorLogic.MockSession(
                name: "B", agentType: "plan",
                state: "working", agentMessages: ["Still going"],
                artifactDescriptions: []
            ),
            OrchestratorLogic.MockSession(
                name: "C", agentType: "debug",
                state: "failed", agentMessages: ["Error"],
                artifactDescriptions: []
            )
        ]
        let result = OrchestratorLogic.synthesizeResults(from: sessions)
        XCTAssertTrue(result.contains("**A**"))
        XCTAssertFalse(result.contains("**B**"), "Working sessions should not be synthesized")
        XCTAssertFalse(result.contains("**C**"), "Failed sessions should not be synthesized")
    }

    func testSynthesizeTruncatesLongOutput() {
        let longMessage = String(repeating: "x", count: 1000)
        let sessions = [
            OrchestratorLogic.MockSession(
                name: "A", agentType: "research",
                state: "completed", agentMessages: [longMessage],
                artifactDescriptions: []
            )
        ]
        let result = OrchestratorLogic.synthesizeResults(from: sessions)
        let outputPart = result.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
        XCTAssertLessThanOrEqual(outputPart.count, 501)
    }
}

// MARK: - Budget Reallocation Tests

final class BudgetReallocationTests: XCTestCase {

    func testReclaimFromCompleted() {
        var sessions = [
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 3000, isTerminal: true, isActive: false, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 5000, isTerminal: false, isActive: true, contextPressure: "elevated")
        ]
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)

        XCTAssertEqual(sessions[0].tokenBudget, 3000)
        XCTAssertGreaterThan(sessions[1].tokenBudget, 8192)
    }

    func testNoReallocationWhenAllNominal() {
        var sessions = [
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 2000, isTerminal: false, isActive: true, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 1000, isTerminal: false, isActive: true, contextPressure: "nominal")
        ]
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)

        XCTAssertEqual(sessions[0].tokenBudget, 8192)
        XCTAssertEqual(sessions[1].tokenBudget, 8192)
    }

    func testMultipleCompletedFreeTokens() {
        var sessions = [
            BudgetLogic.BudgetSession(tokenBudget: 16384, tokensUsed: 1000, isTerminal: true, isActive: false, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 16384, tokensUsed: 2000, isTerminal: true, isActive: false, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 7000, isTerminal: false, isActive: true, contextPressure: "critical")
        ]
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)

        XCTAssertEqual(sessions[0].tokenBudget, 1000)
        XCTAssertEqual(sessions[1].tokenBudget, 2000)
        XCTAssertGreaterThan(sessions[2].tokenBudget, 8192)
    }

    func testEvenDistributionAmongNeedy() {
        var sessions = [
            BudgetLogic.BudgetSession(tokenBudget: 100_000, tokensUsed: 10_000, isTerminal: true, isActive: false, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 7000, isTerminal: false, isActive: true, contextPressure: "elevated"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 7500, isTerminal: false, isActive: true, contextPressure: "critical")
        ]
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)

        let increase1 = sessions[1].tokenBudget - 8192
        let increase2 = sessions[2].tokenBudget - 8192
        XCTAssertEqual(increase1, increase2, "Even distribution")
    }

    func testEmptySessions() {
        var sessions: [BudgetLogic.BudgetSession] = []
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)
        XCTAssertTrue(sessions.isEmpty)
    }

    func testAllTerminal() {
        var sessions = [
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 5000, isTerminal: true, isActive: false, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 3000, isTerminal: true, isActive: false, contextPressure: "nominal")
        ]
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)
        XCTAssertEqual(sessions[0].tokenBudget, 5000)
        XCTAssertEqual(sessions[1].tokenBudget, 3000)
    }
}

// MARK: - ErrorLogger Tests

final class ErrorLoggerTests: XCTestCase {

    func testTryOrNilSuccess() {
        let result = TestErrorLogger.tryOrNil { 42 }
        XCTAssertEqual(result, 42)
    }

    func testTryOrNilFailure() {
        let result: Int? = TestErrorLogger.tryOrNil { throw TestErrorLogger.TestError.sampleError }
        XCTAssertNil(result)
    }

    func testTryOrNilPreservesType() {
        let result = TestErrorLogger.tryOrNil { "hello" }
        XCTAssertEqual(result, "hello")
    }

    func testTryOrNilWithComplexType() {
        struct Item { let value: Int }
        let result = TestErrorLogger.tryOrNil { Item(value: 99) }
        XCTAssertEqual(result?.value, 99)
    }

    func testTryOrDefaultSuccess() {
        let result = TestErrorLogger.tryOrDefault(0) { 42 }
        XCTAssertEqual(result, 42)
    }

    func testTryOrDefaultFailure() {
        let result = TestErrorLogger.tryOrDefault(-1) { throw TestErrorLogger.TestError.sampleError }
        XCTAssertEqual(result, -1)
    }

    func testTryOrDefaultWithString() {
        let result = TestErrorLogger.tryOrDefault("fallback") { throw TestErrorLogger.TestError.sampleError }
        XCTAssertEqual(result, "fallback")
    }

    func testTryOrDefaultWithArray() {
        let result = TestErrorLogger.tryOrDefault([Int]()) {
            throw TestErrorLogger.TestError.detailedError("fail")
        }
        XCTAssertTrue(result.isEmpty)
    }

    func testErrorDescription() {
        let error = TestErrorLogger.TestError.sampleError
        XCTAssertEqual(error.localizedDescription, "Sample error")
    }

    func testDetailedErrorDescription() {
        let error = TestErrorLogger.TestError.detailedError("Custom message")
        XCTAssertEqual(error.localizedDescription, "Custom message")
    }
}

// MARK: - Default Budget Tests

final class DefaultBudgetTests: XCTestCase {

    private func defaultBudget(for agentType: TestAgentType) -> Int {
        switch agentType {
        case .research, .documentation: 16384
        case .plan, .review: 12288
        case .explore, .debug: 8192
        default: 8192
        }
    }

    func testResearchBudget() {
        XCTAssertEqual(defaultBudget(for: .research), 16384)
    }

    func testDocumentationBudget() {
        XCTAssertEqual(defaultBudget(for: .documentation), 16384)
    }

    func testPlanBudget() {
        XCTAssertEqual(defaultBudget(for: .plan), 12288)
    }

    func testReviewBudget() {
        XCTAssertEqual(defaultBudget(for: .review), 12288)
    }

    func testExploreBudget() {
        XCTAssertEqual(defaultBudget(for: .explore), 8192)
    }

    func testDebugBudget() {
        XCTAssertEqual(defaultBudget(for: .debug), 8192)
    }

    func testDefaultBudget() {
        let defaultTypes: [TestAgentType] = [
            .generalPurpose, .bash, .database, .security,
            .performance, .api, .testing, .refactoring, .deployment
        ]
        for agentType in defaultTypes {
            XCTAssertEqual(
                defaultBudget(for: agentType), 8192,
                "\(agentType.rawValue) should have default budget"
            )
        }
    }

    func testResearchHasHighestBudget() {
        let allBudgets = TestAgentType.allCases.map { defaultBudget(for: $0) }
        XCTAssertEqual(allBudgets.max(), 16384)
    }

    func testBudgetTierCount() {
        let uniqueBudgets = Set(TestAgentType.allCases.map { defaultBudget(for: $0) })
        XCTAssertEqual(uniqueBudgets.count, 3, "Should have 3 budget tiers: 8192, 12288, 16384")
    }
}

// MARK: - Prune Sessions Tests

final class PruneSessionsTests: XCTestCase {

    private struct MockPruneSession {
        let isTerminal: Bool
        let completedAt: Date?
        let startedAt: Date
    }

    func testPruneRemovesOldTerminal() {
        let old = Date().addingTimeInterval(-7200)
        let recent = Date().addingTimeInterval(-300)
        var sessions = [
            MockPruneSession(isTerminal: true, completedAt: old, startedAt: old),
            MockPruneSession(isTerminal: true, completedAt: recent, startedAt: recent),
            MockPruneSession(isTerminal: false, completedAt: nil, startedAt: old)
        ]

        let cutoff = Date().addingTimeInterval(-3600)
        sessions.removeAll { session in
            session.isTerminal && (session.completedAt ?? session.startedAt) < cutoff
        }

        XCTAssertEqual(sessions.count, 2)
    }

    func testPruneKeepsAllActive() {
        let old = Date().addingTimeInterval(-7200)
        var sessions = [
            MockPruneSession(isTerminal: false, completedAt: nil, startedAt: old),
            MockPruneSession(isTerminal: false, completedAt: nil, startedAt: old)
        ]

        let cutoff = Date().addingTimeInterval(-3600)
        sessions.removeAll { session in
            session.isTerminal && (session.completedAt ?? session.startedAt) < cutoff
        }

        XCTAssertEqual(sessions.count, 2)
    }

    func testPruneEmptyList() {
        var sessions: [MockPruneSession] = []
        let cutoff = Date().addingTimeInterval(-3600)
        sessions.removeAll { session in
            session.isTerminal && (session.completedAt ?? session.startedAt) < cutoff
        }
        XCTAssertTrue(sessions.isEmpty)
    }
}

// MARK: - Token Usage Ratio Tests

final class TokenUsageRatioTests: XCTestCase {

    private func tokenUsageRatio(used: Int, budget: Int) -> Double {
        guard budget > 0 else { return 0 }
        return Double(used) / Double(budget)
    }

    func testZeroUsage() {
        XCTAssertEqual(tokenUsageRatio(used: 0, budget: 8192), 0.0, accuracy: 0.001)
    }

    func testFullUsage() {
        XCTAssertEqual(tokenUsageRatio(used: 8192, budget: 8192), 1.0, accuracy: 0.001)
    }

    func testHalfUsage() {
        XCTAssertEqual(tokenUsageRatio(used: 4096, budget: 8192), 0.5, accuracy: 0.001)
    }

    func testOverUsage() {
        XCTAssertGreaterThan(tokenUsageRatio(used: 10000, budget: 8192), 1.0)
    }

    func testZeroBudget() {
        XCTAssertEqual(tokenUsageRatio(used: 100, budget: 0), 0.0)
    }

    func testPressureThresholds() {
        let nominal = tokenUsageRatio(used: 4000, budget: 8192)
        XCTAssertLessThan(nominal, 0.6)

        let elevated = tokenUsageRatio(used: 5500, budget: 8192)
        XCTAssertGreaterThanOrEqual(elevated, 0.6)
        XCTAssertLessThan(elevated, 0.8)

        let critical = tokenUsageRatio(used: 7200, budget: 8192)
        XCTAssertGreaterThanOrEqual(critical, 0.8)
        XCTAssertLessThan(critical, 0.95)

        let exceeded = tokenUsageRatio(used: 7900, budget: 8192)
        XCTAssertGreaterThanOrEqual(exceeded, 0.95)
    }
}
