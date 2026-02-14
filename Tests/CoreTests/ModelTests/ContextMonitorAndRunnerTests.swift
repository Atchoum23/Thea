// ContextMonitorAndRunnerTests.swift
// Tests for TheaContextMonitor and TheaAgentRunner helper logic:
// token estimation, confidence scoring, artifact extraction,
// context pressure thresholds, summarization gating, distillation.

import Foundation
import XCTest

// MARK: - Mirrored: TheaContextPressure (from TheaAgentSession)

private enum TestContextPressure: Int, Comparable, CaseIterable {
    case nominal = 0
    case elevated = 1
    case critical = 2
    case exceeded = 3

    static func < (lhs: TestContextPressure, rhs: TestContextPressure) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func fromUsageRatio(_ ratio: Double) -> TestContextPressure {
        switch ratio {
        case ..<0.6: return .nominal
        case ..<0.8: return .elevated
        case ..<0.95: return .critical
        default: return .exceeded
        }
    }
}

// MARK: - Mirrored: TheaAgentMessage

private struct TestAgentMessage {
    enum Role: String { case system, user, agent }
    let role: Role
    let content: String
    let timestamp: Date

    init(role: Role, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Mirrored: TheaAgentArtifact

private struct TestArtifact: Identifiable {
    enum ArtifactType: String { case code, text, markdown, json, plan, summary }
    let id: UUID
    let title: String
    let type: ArtifactType
    let content: String
    let createdAt: Date

    init(title: String, type: ArtifactType, content: String) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.content = content
        self.createdAt = Date()
    }
}

// MARK: - Mirrored: Token estimation

private func estimateTokens(_ text: String) -> Int {
    text.count / 4
}

// MARK: - Mirrored: Confidence estimation

private func estimateConfidence(_ response: String) -> Float {
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

// MARK: - Mirrored: Artifact extraction

private func extractArtifacts(from response: String) -> [TestArtifact] {
    var artifacts: [TestArtifact] = []
    let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return artifacts }

    let nsResponse = response as NSString
    let matches = regex.matches(in: response, range: NSRange(location: 0, length: nsResponse.length))

    for (index, match) in matches.enumerated() {
        let language = match.range(at: 1).location != NSNotFound
            ? nsResponse.substring(with: match.range(at: 1))
            : "code"
        let code = nsResponse.substring(with: match.range(at: 2))

        artifacts.append(TestArtifact(
            title: "Code Block \(index + 1) (\(language))",
            type: .code,
            content: code
        ))
    }
    return artifacts
}

// MARK: - Mirrored: Summarization gating

private func shouldSummarize(lastSummarizedAt: Date?, messageCount: Int) -> Bool {
    if let last = lastSummarizedAt, Date().timeIntervalSince(last) < 10 { return false }
    if messageCount <= 3 { return false }
    return true
}

// MARK: - Mirrored: Distill and release

private func distill(
    agentType: String,
    messages: [TestAgentMessage],
    artifacts: [TestArtifact]
) -> String {
    let agentOutput = messages
        .filter { $0.role == .agent }
        .map(\.content)
        .joined(separator: "\n\n")

    let artifactSummary = artifacts.map { "\($0.type.rawValue): \($0.title)" }.joined(separator: ", ")

    var distilled = "[\(agentType)] \(agentOutput.prefix(1000))"
    if !artifactSummary.isEmpty {
        distilled += "\nArtifacts: \(artifactSummary)"
    }
    return distilled
}

// MARK: - Mirrored: Context session state

private class TestContextSession {
    var tokenBudget: Int
    var tokensUsed: Int = 0
    var contextPressure: TestContextPressure = .nominal
    var summarizationCount: Int = 0
    var lastSummarizedAt: Date?
    var messages: [TestAgentMessage] = []

    init(tokenBudget: Int = 8192) {
        self.tokenBudget = tokenBudget
    }

    func updateContextPressure() {
        guard tokenBudget > 0 else {
            contextPressure = .exceeded
            return
        }
        let ratio = Double(tokensUsed) / Double(tokenBudget)
        contextPressure = TestContextPressure.fromUsageRatio(ratio)
    }

    var usageRatio: Double {
        guard tokenBudget > 0 else { return 1.0 }
        return Double(tokensUsed) / Double(tokenBudget)
    }
}

// MARK: - Tests

final class ContextMonitorAndRunnerTests: XCTestCase {

    // MARK: - Token Estimation Tests

    func testEstimateTokensEmpty() {
        XCTAssertEqual(estimateTokens(""), 0)
    }

    func testEstimateTokensShortText() {
        XCTAssertEqual(estimateTokens("Hello"), 1)
    }

    func testEstimateTokensMediumText() {
        let text = String(repeating: "a", count: 400)
        XCTAssertEqual(estimateTokens(text), 100)
    }

    func testEstimateTokensLongText() {
        let text = String(repeating: "x", count: 4000)
        XCTAssertEqual(estimateTokens(text), 1000)
    }

    // MARK: - Confidence Estimation Tests

    func testConfidenceBaseline() {
        XCTAssertEqual(estimateConfidence("short"), 0.5)
    }

    func testConfidenceWithLength200() {
        let text = String(repeating: "word ", count: 50)  // >200 chars
        XCTAssertEqual(estimateConfidence(text), 0.6)
    }

    func testConfidenceWithLength500() {
        let text = String(repeating: "word ", count: 120)  // >500 chars
        XCTAssertEqual(estimateConfidence(text), 0.7)
    }

    func testConfidenceWithCodeBlocks() {
        let text = "Here is code:\n```swift\nprint(\"hello\")\n```"
        XCTAssertEqual(estimateConfidence(text), 0.6)  // 0.5 base + 0.1 code
    }

    func testConfidenceWithHeaders() {
        let text = "## Section\n**Bold text** here"
        XCTAssertEqual(estimateConfidence(text), 0.6)  // 0.5 base + 0.1 headers
    }

    func testConfidenceMaxCap() {
        // Long text with code blocks and headers
        let text = String(repeating: "word ", count: 120) + "\n```swift\ncode\n```\n## Header\n**bold**"
        let conf = estimateConfidence(text)
        XCTAssertLessThanOrEqual(conf, 1.0)
    }

    func testConfidenceAllBonuses() {
        // Long (>500) + code + headers = 0.5 + 0.1 + 0.1 + 0.1 + 0.1 = 0.9, capped at 0.9
        let text = String(repeating: "w ", count: 300) + "\n```python\nx\n```\n## Title\n**bold**"
        let conf = estimateConfidence(text)
        XCTAssertEqual(conf, 0.9)
    }

    // MARK: - Artifact Extraction Tests

    func testExtractNoArtifacts() {
        let text = "Just regular text without any code blocks."
        XCTAssertTrue(extractArtifacts(from: text).isEmpty)
    }

    func testExtractSingleCodeBlock() {
        let text = """
        Some text
        ```swift
        let x = 42
        ```
        More text
        """
        let artifacts = extractArtifacts(from: text)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertEqual(artifacts[0].title, "Code Block 1 (swift)")
        XCTAssertTrue(artifacts[0].content.contains("let x = 42"))
    }

    func testExtractMultipleCodeBlocks() {
        let text = """
        ```python
        print("hello")
        ```
        Some text
        ```javascript
        console.log("world")
        ```
        """
        let artifacts = extractArtifacts(from: text)
        XCTAssertEqual(artifacts.count, 2)
        XCTAssertEqual(artifacts[0].title, "Code Block 1 (python)")
        XCTAssertEqual(artifacts[1].title, "Code Block 2 (javascript)")
    }

    func testExtractCodeBlockNoLanguage() {
        let text = """
        ```
        generic code
        ```
        """
        let artifacts = extractArtifacts(from: text)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertEqual(artifacts[0].title, "Code Block 1 (code)")
    }

    func testArtifactTypeIsCode() {
        let text = "```rust\nfn main() {}\n```"
        let artifacts = extractArtifacts(from: text)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertEqual(artifacts[0].type, .code)
    }

    // MARK: - Context Pressure Tests

    func testPressureNominalBelow60() {
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.0), .nominal)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.3), .nominal)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.59), .nominal)
    }

    func testPressureElevated60to80() {
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.6), .elevated)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.7), .elevated)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.79), .elevated)
    }

    func testPressureCritical80to95() {
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.8), .critical)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.9), .critical)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.94), .critical)
    }

    func testPressureExceededAbove95() {
        XCTAssertEqual(TestContextPressure.fromUsageRatio(0.95), .exceeded)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(1.0), .exceeded)
        XCTAssertEqual(TestContextPressure.fromUsageRatio(1.5), .exceeded)
    }

    func testPressureComparable() {
        XCTAssertTrue(TestContextPressure.nominal < .elevated)
        XCTAssertTrue(TestContextPressure.elevated < .critical)
        XCTAssertTrue(TestContextPressure.critical < .exceeded)
    }

    func testPressureCaseCount() {
        XCTAssertEqual(TestContextPressure.allCases.count, 4)
    }

    // MARK: - Session Context State Tests

    func testSessionPressureNominal() {
        let session = TestContextSession(tokenBudget: 8192)
        session.tokensUsed = 1000
        session.updateContextPressure()
        XCTAssertEqual(session.contextPressure, .nominal)
    }

    func testSessionPressureElevated() {
        let session = TestContextSession(tokenBudget: 8192)
        session.tokensUsed = 5500  // ~67%
        session.updateContextPressure()
        XCTAssertEqual(session.contextPressure, .elevated)
    }

    func testSessionPressureCritical() {
        let session = TestContextSession(tokenBudget: 8192)
        session.tokensUsed = 7000  // ~85%
        session.updateContextPressure()
        XCTAssertEqual(session.contextPressure, .critical)
    }

    func testSessionPressureExceeded() {
        let session = TestContextSession(tokenBudget: 8192)
        session.tokensUsed = 8000  // ~97%
        session.updateContextPressure()
        XCTAssertEqual(session.contextPressure, .exceeded)
    }

    func testSessionPressureZeroBudget() {
        let session = TestContextSession(tokenBudget: 0)
        session.updateContextPressure()
        XCTAssertEqual(session.contextPressure, .exceeded)
    }

    func testSessionUsageRatio() {
        let session = TestContextSession(tokenBudget: 10000)
        session.tokensUsed = 5000
        XCTAssertEqual(session.usageRatio, 0.5)
    }

    func testSessionUsageRatioZeroBudget() {
        let session = TestContextSession(tokenBudget: 0)
        XCTAssertEqual(session.usageRatio, 1.0)
    }

    // MARK: - Summarization Gating Tests

    func testShouldSummarizeWithEnoughMessages() {
        XCTAssertTrue(shouldSummarize(lastSummarizedAt: nil, messageCount: 10))
    }

    func testShouldNotSummarizeTooFewMessages() {
        XCTAssertFalse(shouldSummarize(lastSummarizedAt: nil, messageCount: 2))
    }

    func testShouldNotSummarizeExactlyThreeMessages() {
        XCTAssertFalse(shouldSummarize(lastSummarizedAt: nil, messageCount: 3))
    }

    func testShouldNotSummarizeTooRecent() {
        let recent = Date().addingTimeInterval(-5)
        XCTAssertFalse(shouldSummarize(lastSummarizedAt: recent, messageCount: 20))
    }

    func testShouldSummarizeAfterCooldown() {
        let old = Date().addingTimeInterval(-30)
        XCTAssertTrue(shouldSummarize(lastSummarizedAt: old, messageCount: 20))
    }

    // MARK: - Distillation Tests

    func testDistillWithAgentMessages() {
        let messages = [
            TestAgentMessage(role: .user, content: "research X"),
            TestAgentMessage(role: .agent, content: "Found that X works by..."),
            TestAgentMessage(role: .agent, content: "In conclusion, X is effective.")
        ]
        let result = distill(agentType: "research", messages: messages, artifacts: [])
        XCTAssertTrue(result.hasPrefix("[research]"))
        XCTAssertTrue(result.contains("Found that X works by"))
        XCTAssertTrue(result.contains("In conclusion"))
    }

    func testDistillWithArtifacts() {
        let messages = [TestAgentMessage(role: .agent, content: "Here is the code")]
        let artifacts = [
            TestArtifact(title: "main.swift", type: .code, content: "print(1)"),
            TestArtifact(title: "README.md", type: .markdown, content: "# Readme")
        ]
        let result = distill(agentType: "bash", messages: messages, artifacts: artifacts)
        XCTAssertTrue(result.contains("Artifacts:"))
        XCTAssertTrue(result.contains("code: main.swift"))
        XCTAssertTrue(result.contains("markdown: README.md"))
    }

    func testDistillNoAgentMessages() {
        let messages = [TestAgentMessage(role: .user, content: "do something")]
        let result = distill(agentType: "plan", messages: messages, artifacts: [])
        XCTAssertTrue(result.hasPrefix("[plan]"))
        XCTAssertFalse(result.contains("Artifacts:"))
    }

    func testDistillTruncatesLongOutput() {
        let longContent = String(repeating: "x", count: 2000)
        let messages = [TestAgentMessage(role: .agent, content: longContent)]
        let result = distill(agentType: "research", messages: messages, artifacts: [])
        // Output should be truncated to prefix(1000) + type tag
        XCTAssertLessThan(result.count, 1100)
    }

    // MARK: - Context Budget Reallocation Tests

    func testBudgetReallocationFromCompleted() {
        let sessions = [
            TestContextSession(tokenBudget: 16384),  // completed, used 5000
            TestContextSession(tokenBudget: 8192)     // active, elevated
        ]
        sessions[0].tokensUsed = 5000
        sessions[1].tokensUsed = 6000
        sessions[1].updateContextPressure()

        // Simulate: shrink completed to actual usage
        let freed = sessions[0].tokenBudget - sessions[0].tokensUsed
        sessions[0].tokenBudget = sessions[0].tokensUsed

        // Give freed tokens to elevated session
        let elevated = sessions.filter { $0.contextPressure >= .elevated }
        if !elevated.isEmpty {
            let perAgent = freed / elevated.count
            for s in elevated {
                s.tokenBudget += perAgent
            }
        }

        XCTAssertEqual(sessions[0].tokenBudget, 5000)
        XCTAssertEqual(sessions[1].tokenBudget, 8192 + 11384)
        sessions[1].updateContextPressure()
        XCTAssertEqual(sessions[1].contextPressure, .nominal)
    }
}
