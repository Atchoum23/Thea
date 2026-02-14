@testable import TheaCore
import XCTest

/// Tests for OutboundPrivacyGuard, PrivacyPolicy, and built-in policies
@MainActor
final class OutboundPrivacyGuardTests: XCTestCase {

    // MARK: - StrictnessLevel Tests

    func testStrictnessLevelOrdering() {
        XCTAssertTrue(StrictnessLevel.permissive < .standard)
        XCTAssertTrue(StrictnessLevel.standard < .strict)
        XCTAssertTrue(StrictnessLevel.strict < .paranoid)
        XCTAssertTrue(StrictnessLevel.permissive < .paranoid)
    }

    func testStrictnessLevelEquality() {
        XCTAssertEqual(StrictnessLevel.standard, .standard)
        XCTAssertNotEqual(StrictnessLevel.strict, .standard)
    }

    func testStrictnessLevelRawValues() {
        XCTAssertEqual(StrictnessLevel.permissive.rawValue, "permissive")
        XCTAssertEqual(StrictnessLevel.standard.rawValue, "standard")
        XCTAssertEqual(StrictnessLevel.strict.rawValue, "strict")
        XCTAssertEqual(StrictnessLevel.paranoid.rawValue, "paranoid")
    }

    // MARK: - SanitizationOutcome Tests

    func testSanitizationOutcomeClean() {
        let outcome = SanitizationOutcome.clean("Hello world")
        XCTAssertEqual(outcome.content, "Hello world")
        XCTAssertTrue(outcome.isAllowed)
    }

    func testSanitizationOutcomeRedacted() {
        let redaction = Redaction(
            type: .pii, originalLength: 20,
            replacement: "[PII_REDACTED]", reason: "Email detected"
        )
        let outcome = SanitizationOutcome.redacted("Hello [PII_REDACTED]", redactions: [redaction])
        XCTAssertEqual(outcome.content, "Hello [PII_REDACTED]")
        XCTAssertTrue(outcome.isAllowed)
    }

    func testSanitizationOutcomeBlocked() {
        let outcome = SanitizationOutcome.blocked(reason: "Topic violation")
        XCTAssertNil(outcome.content)
        XCTAssertFalse(outcome.isAllowed)
    }

    // MARK: - RedactionType Tests

    func testRedactionTypeRawValues() {
        XCTAssertEqual(RedactionType.pii.rawValue, "pii")
        XCTAssertEqual(RedactionType.apiKey.rawValue, "apiKey")
        XCTAssertEqual(RedactionType.filePath.rawValue, "filePath")
        XCTAssertEqual(RedactionType.credential.rawValue, "credential")
        XCTAssertEqual(RedactionType.blockedKeyword.rawValue, "blockedKeyword")
    }

    func testRedactionTypeCodable() throws {
        let type = RedactionType.pii
        let data = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(RedactionType.self, from: data)
        XCTAssertEqual(decoded, .pii)
    }

    // MARK: - Built-in Policy Tests

    func testCloudAPIPolicyDefaults() {
        let policy = CloudAPIPolicy()
        XCTAssertEqual(policy.name, "Cloud API")
        XCTAssertEqual(policy.strictnessLevel, .standard)
        XCTAssertFalse(policy.allowPII)
        XCTAssertFalse(policy.allowFilePaths)
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertTrue(policy.blockedKeywords.isEmpty)
        XCTAssertNil(policy.allowedTopics)
        XCTAssertEqual(policy.maxContentLength, 0)
    }

    func testMessagingPolicyDefaults() {
        let policy = MessagingPolicy()
        XCTAssertEqual(policy.name, "Messaging")
        XCTAssertEqual(policy.strictnessLevel, .strict)
        XCTAssertFalse(policy.allowPII)
        XCTAssertFalse(policy.allowCodeSnippets)
        XCTAssertEqual(policy.maxContentLength, 4096)
        XCTAssertTrue(policy.blockedKeywords.contains("password"))
        XCTAssertTrue(policy.blockedKeywords.contains("credit card"))
    }

    func testMCPPolicyDefaults() {
        let policy = MCPPolicy()
        XCTAssertEqual(policy.name, "MCP")
        XCTAssertEqual(policy.strictnessLevel, .strict)
        XCTAssertTrue(policy.allowFilePaths) // MCP allows file paths
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertTrue(policy.blockedKeywords.contains("private key"))
    }

    func testMoltbookPolicyIsParanoid() {
        let policy = MoltbookPolicy()
        XCTAssertEqual(policy.name, "Moltbook")
        XCTAssertEqual(policy.strictnessLevel, .paranoid)
        XCTAssertFalse(policy.allowPII)
        XCTAssertFalse(policy.allowFilePaths)
        XCTAssertFalse(policy.allowCodeSnippets)
        XCTAssertNotNil(policy.allowedTopics) // Paranoid has topic allowlist
        XCTAssertTrue(policy.blockedKeywords.contains("salary"))
        XCTAssertTrue(policy.blockedKeywords.contains("medical"))
    }

    func testMoltbookPolicyAllowsDevTopics() {
        let policy = MoltbookPolicy()
        guard let topics = policy.allowedTopics else {
            XCTFail("Moltbook should have allowed topics")
            return
        }
        XCTAssertTrue(topics.contains("swift"))
        XCTAssertTrue(topics.contains("ios"))
        XCTAssertTrue(topics.contains("xcode"))
    }

    func testWebAPIPolicyDefaults() {
        let policy = WebAPIPolicy()
        XCTAssertEqual(policy.name, "Web API")
        XCTAssertEqual(policy.strictnessLevel, .standard)
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertTrue(policy.blockedKeywords.isEmpty)
    }

    // MARK: - AuditOutcome Tests

    func testAuditOutcomeRawValues() {
        XCTAssertEqual(PrivacyAuditEntry.AuditOutcome.passed.rawValue, "passed")
        XCTAssertEqual(PrivacyAuditEntry.AuditOutcome.redacted.rawValue, "redacted")
        XCTAssertEqual(PrivacyAuditEntry.AuditOutcome.blocked.rawValue, "blocked")
    }

    func testAuditOutcomeCodable() throws {
        let outcome = PrivacyAuditEntry.AuditOutcome.redacted
        let data = try JSONEncoder().encode(outcome)
        let decoded = try JSONDecoder().decode(PrivacyAuditEntry.AuditOutcome.self, from: data)
        XCTAssertEqual(decoded, .redacted)
    }

    // MARK: - OutboundPrivacyGuard Singleton

    func testOutboundPrivacyGuardExists() async {
        let guard_ = OutboundPrivacyGuard.shared
        let isEnabled = await guard_.isEnabled
        XCTAssertTrue(isEnabled) // Default should be enabled
    }
}
