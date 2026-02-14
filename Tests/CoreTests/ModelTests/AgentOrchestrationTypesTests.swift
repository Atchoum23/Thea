// AgentOrchestrationTypesTests.swift
// Tests for agent orchestration value types: TheaAgentActivity, SpecializedAgentType,
// and runner helpers (tokens, confidence, artifacts).
// Orchestrator logic tests moved to AgentOrchestratorLogicTests.swift.

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

