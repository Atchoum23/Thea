// AgentOrchestrationTypesTests.swift
// Tests for agent orchestration value types: TheaAgentActivity, SpecializedAgentType,
// orchestrator logic (synthesize, budget), runner helpers (tokens, confidence, artifacts)

import Foundation
import XCTest

// MARK: - Mirrored: TheaAgentActivity

private struct TestAgentActivity: Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionID: UUID?
    let event: String
    let detail: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionID: UUID? = nil,
        event: String,
        detail: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.event = event
        self.detail = detail
    }
}

// MARK: - Mirrored: SpecializedAgentType

private enum TestAgentType: String, Codable, CaseIterable {
    case explore, plan, generalPurpose, bash, research
    case database, security, performance, api, testing
    case documentation, refactoring, review, debug, deployment

    var displayName: String {
        switch self {
        case .explore: "Explorer"
        case .plan: "Planner"
        case .generalPurpose: "General Purpose"
        case .bash: "Command Executor"
        case .research: "Researcher"
        case .database: "Database Expert"
        case .security: "Security Analyst"
        case .performance: "Performance Engineer"
        case .api: "API Specialist"
        case .testing: "Test Engineer"
        case .documentation: "Documentation Writer"
        case .refactoring: "Refactoring Expert"
        case .review: "Code Reviewer"
        case .debug: "Debug Specialist"
        case .deployment: "DevOps Engineer"
        }
    }

    var sfSymbol: String {
        switch self {
        case .explore: "magnifyingglass"
        case .plan: "list.bullet.clipboard"
        case .generalPurpose: "cpu"
        case .bash: "terminal"
        case .research: "globe"
        case .database: "cylinder"
        case .security: "lock.shield"
        case .performance: "gauge.with.dots.needle.67percent"
        case .api: "arrow.left.arrow.right"
        case .testing: "checkmark.diamond"
        case .documentation: "doc.text"
        case .refactoring: "arrow.triangle.2.circlepath"
        case .review: "eye"
        case .debug: "ant"
        case .deployment: "shippingbox"
        }
    }

    var systemPrompt: String {
        switch self {
        case .explore: "You are a fast, read-only code exploration agent. Search and analyze code without making changes."
        case .plan: "You are a software architect. Design systems, plan implementations, and create technical specifications."
        case .generalPurpose: "You are a versatile AI assistant with access to all tools. Handle any task efficiently."
        case .bash: "You are a command-line specialist. Execute shell commands, manage files, and automate tasks."
        case .research: "You are a thorough researcher. Search the web, gather information, and synthesize findings."
        case .database: "You are a database expert. Design schemas, optimize queries, plan migrations, and ensure data integrity."
        case .security: "You are a security analyst. Identify vulnerabilities, review code for security issues, and recommend fixes."
        case .performance: "You are a performance engineer. Profile code, identify bottlenecks, and optimize for speed and efficiency."
        case .api: "You are an API specialist. Design RESTful and GraphQL APIs, document endpoints, and handle integrations."
        case .testing: "You are a test engineer. Generate comprehensive tests, analyze coverage, and ensure code reliability."
        case .documentation: "You are a technical writer. Create clear documentation, API docs, and user guides."
        case .refactoring: "You are a refactoring expert. Improve code structure while preserving functionality."
        case .review: "You are a code reviewer. Analyze code for quality, patterns, and potential issues."
        case .debug: "You are a debugging specialist. Analyze errors, trace issues, and identify root causes."
        case .deployment: "You are a DevOps engineer. Configure CI/CD, manage deployments, and automate infrastructure."
        }
    }

    var suggestedTools: [String] {
        switch self {
        case .explore: ["read", "search", "grep", "glob"]
        case .plan: ["read", "write", "search"]
        case .generalPurpose: ["*"]
        case .bash: ["bash", "read", "write"]
        case .research: ["web_search", "web_fetch", "read"]
        case .database: ["read", "write", "bash"]
        case .security: ["read", "search", "grep", "bash"]
        case .performance: ["read", "bash", "search"]
        case .api: ["read", "write", "web_fetch"]
        case .testing: ["read", "write", "bash"]
        case .documentation: ["read", "write"]
        case .refactoring: ["read", "write", "search"]
        case .review: ["read", "search", "grep"]
        case .debug: ["read", "bash", "search", "grep"]
        case .deployment: ["bash", "read", "write"]
        }
    }

    var preferredModel: String {
        switch self {
        case .plan, .security, .review: "claude-opus-4"
        case .explore, .bash, .debug: "claude-haiku-3.5"
        default: "claude-sonnet-4"
        }
    }
}

// MARK: - Mirrored: Runner Helpers

private enum RunnerHelpers {
    static func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }

    static func estimateConfidence(_ response: String) -> Float {
        let length = response.count
        let hasCodeBlocks = response.contains("```")
        let hasHeaders = response.contains("##") || response.contains("**")

        var score: Float = 0.5
        if length > 200 { score += 0.1 }
        if length > 500 { score += 0.1 }
        if hasCodeBlocks { score += 0.1 }
        if hasHeaders { score += 0.1 }
        return min(score, 1.0)
    }

    struct ExtractedArtifact {
        let language: String
        let code: String
    }

    static func extractArtifacts(from response: String) -> [ExtractedArtifact] {
        var artifacts: [ExtractedArtifact] = []
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return artifacts }

        let nsResponse = response as NSString
        let matches = regex.matches(in: response, range: NSRange(location: 0, length: nsResponse.length))

        for match in matches {
            let language = match.range(at: 1).location != NSNotFound
                ? nsResponse.substring(with: match.range(at: 1))
                : "code"
            let code = nsResponse.substring(with: match.range(at: 2))
            artifacts.append(ExtractedArtifact(language: language, code: code))
        }
        return artifacts
    }
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
        var contextPressure: String  // "nominal", "elevated", etc.
    }

    static func reallocate(
        sessions: inout [BudgetSession],
        totalPool: Int
    ) {
        let allocated = sessions.map(\.tokenBudget).reduce(0, +)
        var freeTokens = totalPool - allocated

        // Reclaim from completed
        for idx in sessions.indices where sessions[idx].isTerminal {
            let freed = sessions[idx].tokenBudget - sessions[idx].tokensUsed
            sessions[idx].tokenBudget = sessions[idx].tokensUsed
            freeTokens += freed
        }

        // Distribute to active under pressure
        let needyIndices = sessions.indices.filter { sessions[$0].isActive && sessions[$0].contextPressure != "nominal" }
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

// MARK: - TheaAgentActivity Tests

final class TheaAgentActivityTests: XCTestCase {

    func testDefaultInit() {
        let activity = TestAgentActivity(event: "delegated", detail: "Task started")
        XCTAssertFalse(activity.id.uuidString.isEmpty)
        XCTAssertNil(activity.sessionID)
        XCTAssertEqual(activity.event, "delegated")
        XCTAssertEqual(activity.detail, "Task started")
        XCTAssertTrue(activity.timestamp.timeIntervalSinceNow < 1)
    }

    func testWithSessionID() {
        let sessionID = UUID()
        let activity = TestAgentActivity(sessionID: sessionID, event: "completed", detail: "Done")
        XCTAssertEqual(activity.sessionID, sessionID)
    }

    func testCustomTimestamp() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let activity = TestAgentActivity(timestamp: date, event: "failed", detail: "Error")
        XCTAssertEqual(activity.timestamp, date)
    }

    func testIdentifiable() {
        let a1 = TestAgentActivity(event: "x", detail: "y")
        let a2 = TestAgentActivity(event: "x", detail: "y")
        XCTAssertNotEqual(a1.id, a2.id)
    }

    func testCustomID() {
        let id = UUID()
        let activity = TestAgentActivity(id: id, event: "test", detail: "detail")
        XCTAssertEqual(activity.id, id)
    }

    func testAllEventTypesNonEmpty() {
        let events = ["delegated", "delegated-parallel", "cancelled", "paused", "resumed",
                      "redirected", "completed", "failed", "budget-realloc"]
        for event in events {
            let activity = TestAgentActivity(event: event, detail: "test")
            XCTAssertFalse(activity.event.isEmpty)
        }
    }

    func testActivityLogCapacity() {
        // Mirrors orchestrator's 500-entry cap
        var log: [TestAgentActivity] = []
        for idx in 0..<600 {
            log.append(TestAgentActivity(event: "test-\(idx)", detail: "detail"))
        }
        if log.count > 500 {
            log.removeFirst(log.count - 500)
        }
        XCTAssertEqual(log.count, 500)
        XCTAssertEqual(log.first?.event, "test-100")
    }
}

// MARK: - SpecializedAgentType Tests

final class SpecializedAgentTypeTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TestAgentType.allCases.count, 15)
    }

    func testRawValuesUnique() {
        let rawValues = TestAgentType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "All raw values must be unique")
    }

    func testDisplayNamesNonEmpty() {
        for agentType in TestAgentType.allCases {
            XCTAssertFalse(agentType.displayName.isEmpty, "\(agentType.rawValue) must have displayName")
        }
    }

    func testDisplayNamesUnique() {
        let names = TestAgentType.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "All display names must be unique")
    }

    func testSFSymbolsNonEmpty() {
        for agentType in TestAgentType.allCases {
            XCTAssertFalse(agentType.sfSymbol.isEmpty, "\(agentType.rawValue) must have sfSymbol")
        }
    }

    func testSystemPromptsNonEmpty() {
        for agentType in TestAgentType.allCases {
            XCTAssertFalse(agentType.systemPrompt.isEmpty, "\(agentType.rawValue) must have systemPrompt")
            XCTAssertGreaterThan(agentType.systemPrompt.count, 20, "System prompt must be meaningful")
        }
    }

    func testSystemPromptsStartWithYou() {
        for agentType in TestAgentType.allCases {
            XCTAssertTrue(
                agentType.systemPrompt.hasPrefix("You are"),
                "\(agentType.rawValue) system prompt should start with 'You are'"
            )
        }
    }

    func testSuggestedToolsNonEmpty() {
        for agentType in TestAgentType.allCases {
            XCTAssertFalse(agentType.suggestedTools.isEmpty, "\(agentType.rawValue) must have suggested tools")
        }
    }

    func testGeneralPurposeHasWildcard() {
        XCTAssertEqual(TestAgentType.generalPurpose.suggestedTools, ["*"])
    }

    func testExploreHasReadOnly() {
        let tools = TestAgentType.explore.suggestedTools
        XCTAssertTrue(tools.contains("read"))
        XCTAssertTrue(tools.contains("search"))
        XCTAssertFalse(tools.contains("write"), "Explorer should be read-only")
    }

    func testPreferredModelCategories() {
        // Deep reasoning agents
        XCTAssertEqual(TestAgentType.plan.preferredModel, "claude-opus-4")
        XCTAssertEqual(TestAgentType.security.preferredModel, "claude-opus-4")
        XCTAssertEqual(TestAgentType.review.preferredModel, "claude-opus-4")

        // Fast agents
        XCTAssertEqual(TestAgentType.explore.preferredModel, "claude-haiku-3.5")
        XCTAssertEqual(TestAgentType.bash.preferredModel, "claude-haiku-3.5")
        XCTAssertEqual(TestAgentType.debug.preferredModel, "claude-haiku-3.5")

        // Balanced agents (everything else)
        let balanced: [TestAgentType] = [.generalPurpose, .research, .database,
                                         .performance, .api, .testing,
                                         .documentation, .refactoring, .deployment]
        for agent in balanced {
            XCTAssertEqual(agent.preferredModel, "claude-sonnet-4", "\(agent.rawValue) should use sonnet")
        }
    }

    func testCodableRoundTrip() throws {
        for agentType in TestAgentType.allCases {
            let data = try JSONEncoder().encode(agentType)
            let decoded = try JSONDecoder().decode(TestAgentType.self, from: data)
            XCTAssertEqual(decoded, agentType)
        }
    }

    func testDecodableFromString() throws {
        let json = Data("\"generalPurpose\"".utf8)
        let decoded = try JSONDecoder().decode(TestAgentType.self, from: json)
        XCTAssertEqual(decoded, .generalPurpose)
    }

    func testSpecificRawValues() {
        XCTAssertEqual(TestAgentType.explore.rawValue, "explore")
        XCTAssertEqual(TestAgentType.generalPurpose.rawValue, "generalPurpose")
        XCTAssertEqual(TestAgentType.deployment.rawValue, "deployment")
    }

    func testSpecificDisplayNames() {
        XCTAssertEqual(TestAgentType.explore.displayName, "Explorer")
        XCTAssertEqual(TestAgentType.plan.displayName, "Planner")
        XCTAssertEqual(TestAgentType.generalPurpose.displayName, "General Purpose")
        XCTAssertEqual(TestAgentType.security.displayName, "Security Analyst")
        XCTAssertEqual(TestAgentType.deployment.displayName, "DevOps Engineer")
    }

    func testSpecificSFSymbols() {
        XCTAssertEqual(TestAgentType.explore.sfSymbol, "magnifyingglass")
        XCTAssertEqual(TestAgentType.bash.sfSymbol, "terminal")
        XCTAssertEqual(TestAgentType.security.sfSymbol, "lock.shield")
        XCTAssertEqual(TestAgentType.debug.sfSymbol, "ant")
        XCTAssertEqual(TestAgentType.deployment.sfSymbol, "shippingbox")
    }
}

// MARK: - Runner Helpers Tests

final class RunnerHelpersTests: XCTestCase {

    // MARK: estimateTokens

    func testEstimateTokensEmpty() {
        XCTAssertEqual(RunnerHelpers.estimateTokens(""), 0)
    }

    func testEstimateTokensShort() {
        XCTAssertEqual(RunnerHelpers.estimateTokens("Hello"), 1)  // 5/4 = 1
    }

    func testEstimateTokensMedium() {
        let text = String(repeating: "a", count: 400)
        XCTAssertEqual(RunnerHelpers.estimateTokens(text), 100)  // 400/4
    }

    func testEstimateTokensLarge() {
        let text = String(repeating: "x", count: 10_000)
        XCTAssertEqual(RunnerHelpers.estimateTokens(text), 2500)
    }

    func testEstimateTokensSingleChar() {
        XCTAssertEqual(RunnerHelpers.estimateTokens("a"), 0)  // 1/4 = 0
    }

    func testEstimateTokensFourChars() {
        XCTAssertEqual(RunnerHelpers.estimateTokens("abcd"), 1)
    }

    // MARK: estimateConfidence

    func testEstimateConfidenceEmpty() {
        let conf = RunnerHelpers.estimateConfidence("")
        XCTAssertEqual(conf, 0.5, accuracy: 0.01)
    }

    func testEstimateConfidenceShortPlain() {
        let text = "Short response"
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertEqual(conf, 0.5, accuracy: 0.01)
    }

    func testEstimateConfidenceLongPlain() {
        let text = String(repeating: "word ", count: 60)  // 300 chars
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertEqual(conf, 0.6, accuracy: 0.01)  // base 0.5 + 0.1 for >200
    }

    func testEstimateConfidenceVeryLong() {
        let text = String(repeating: "w ", count: 300)  // 600 chars
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertEqual(conf, 0.7, accuracy: 0.01)  // 0.5 + 0.1 (>200) + 0.1 (>500)
    }

    func testEstimateConfidenceWithCode() {
        let text = String(repeating: "x", count: 100) + "\n```swift\nprint(1)\n```"
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertEqual(conf, 0.6, accuracy: 0.01)  // 0.5 + 0.1 (code blocks)
    }

    func testEstimateConfidenceWithHeaders() {
        let text = String(repeating: "x", count: 100) + "\n## Section"
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertEqual(conf, 0.6, accuracy: 0.01)  // 0.5 + 0.1 (headers)
    }

    func testEstimateConfidenceWithBoldHeaders() {
        let text = String(repeating: "x", count: 100) + "\n**Bold text**"
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertEqual(conf, 0.6, accuracy: 0.01)  // 0.5 + 0.1 (bold = headers)
    }

    func testEstimateConfidenceMaximum() {
        // Long + code + headers = all bonuses
        let text = String(repeating: "x", count: 600) + "\n```code\n```\n## H"
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertEqual(conf, 0.9, accuracy: 0.01)  // 0.5 + 0.1 + 0.1 + 0.1 + 0.1
    }

    func testEstimateConfidenceCappedAt1() {
        // Even with all bonuses, should not exceed 1.0
        let text = String(repeating: "x", count: 1000) + "```code```\n## **bold**"
        let conf = RunnerHelpers.estimateConfidence(text)
        XCTAssertLessThanOrEqual(conf, 1.0)
    }

    // MARK: extractArtifacts

    func testExtractArtifactsNone() {
        let result = RunnerHelpers.extractArtifacts(from: "No code here")
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractArtifactsSingle() {
        let response = """
        Here's some code:
        ```swift
        print("hello")
        ```
        """
        let result = RunnerHelpers.extractArtifacts(from: response)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].language, "swift")
        XCTAssertTrue(result[0].code.contains("print"))
    }

    func testExtractArtifactsMultiple() {
        let response = """
        First:
        ```python
        def hello():
            pass
        ```
        Second:
        ```javascript
        console.log('hi')
        ```
        """
        let result = RunnerHelpers.extractArtifacts(from: response)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].language, "python")
        XCTAssertEqual(result[1].language, "javascript")
    }

    func testExtractArtifactsNoLanguage() {
        let response = """
        Code:
        ```
        some code
        ```
        """
        let result = RunnerHelpers.extractArtifacts(from: response)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].language, "code")
    }

    func testExtractArtifactsEmpty() {
        let result = RunnerHelpers.extractArtifacts(from: "")
        XCTAssertTrue(result.isEmpty)
    }

    func testExtractArtifactsPreservesContent() {
        let codeContent = "let x = 42\nlet y = x * 2\nprint(y)"
        let response = "```swift\n\(codeContent)\n```"
        let result = RunnerHelpers.extractArtifacts(from: response)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].code, codeContent + "\n")
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
        // Output is truncated to prefix(500)
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

        // Completed session budget should shrink to actual usage
        XCTAssertEqual(sessions[0].tokenBudget, 3000)
        // Active elevated session should get freed tokens
        XCTAssertGreaterThan(sessions[1].tokenBudget, 8192)
    }

    func testNoReallocationWhenAllNominal() {
        var sessions = [
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 2000, isTerminal: false, isActive: true, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 1000, isTerminal: false, isActive: true, contextPressure: "nominal")
        ]
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)

        // No reallocation since all are nominal
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

        // Completed sessions shrunk
        XCTAssertEqual(sessions[0].tokenBudget, 1000)
        XCTAssertEqual(sessions[1].tokenBudget, 2000)
        // Active critical session gets the freed tokens
        XCTAssertGreaterThan(sessions[2].tokenBudget, 8192)
    }

    func testEvenDistributionAmongNeedy() {
        var sessions = [
            BudgetLogic.BudgetSession(tokenBudget: 100_000, tokensUsed: 10_000, isTerminal: true, isActive: false, contextPressure: "nominal"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 7000, isTerminal: false, isActive: true, contextPressure: "elevated"),
            BudgetLogic.BudgetSession(tokenBudget: 8192, tokensUsed: 7500, isTerminal: false, isActive: true, contextPressure: "critical")
        ]
        BudgetLogic.reallocate(sessions: &sessions, totalPool: 500_000)

        // Both active sessions should get equal share
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
        let defaultTypes: [TestAgentType] = [.generalPurpose, .bash, .database, .security,
                                             .performance, .api, .testing, .refactoring, .deployment]
        for agentType in defaultTypes {
            XCTAssertEqual(defaultBudget(for: agentType), 8192, "\(agentType.rawValue) should have default budget")
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
        let old = Date().addingTimeInterval(-7200)  // 2 hours ago
        let recent = Date().addingTimeInterval(-300)  // 5 min ago
        var sessions = [
            MockPruneSession(isTerminal: true, completedAt: old, startedAt: old),
            MockPruneSession(isTerminal: true, completedAt: recent, startedAt: recent),
            MockPruneSession(isTerminal: false, completedAt: nil, startedAt: old)
        ]

        let cutoff = Date().addingTimeInterval(-3600)
        sessions.removeAll { session in
            session.isTerminal && (session.completedAt ?? session.startedAt) < cutoff
        }

        XCTAssertEqual(sessions.count, 2)  // recent terminal + active
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
        // Nominal: <60%
        let nominal = tokenUsageRatio(used: 4000, budget: 8192)
        XCTAssertLessThan(nominal, 0.6)

        // Elevated: 60-80%
        let elevated = tokenUsageRatio(used: 5500, budget: 8192)
        XCTAssertGreaterThanOrEqual(elevated, 0.6)
        XCTAssertLessThan(elevated, 0.8)

        // Critical: 80-95%
        let critical = tokenUsageRatio(used: 7200, budget: 8192)
        XCTAssertGreaterThanOrEqual(critical, 0.8)
        XCTAssertLessThan(critical, 0.95)

        // Exceeded: >95%
        let exceeded = tokenUsageRatio(used: 7900, budget: 8192)
        XCTAssertGreaterThanOrEqual(exceeded, 0.95)
    }
}
