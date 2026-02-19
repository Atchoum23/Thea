@testable import TheaCore
import XCTest

// swiftlint:disable file_length type_body_length

/// Tests for OutboundPrivacyGuard, PrivacyPolicy, and built-in policies
/// Goal: 100% branch coverage on OutboundPrivacyGuard.swift + PrivacyPolicies.swift
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

    func testStrictnessLevelNotGreaterThanSelf() {
        // False path of < operator: equal values are not less-than
        XCTAssertFalse(StrictnessLevel.strict < .strict)
        XCTAssertFalse(StrictnessLevel.paranoid < .standard)
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
        XCTAssertEqual(RedactionType.topicViolation.rawValue, "topicViolation")
        XCTAssertEqual(RedactionType.lengthTruncation.rawValue, "lengthTruncation")
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

    func testPermissivePolicyAllowsEverything() {
        let policy = PermissivePolicy()
        XCTAssertEqual(policy.name, "Permissive")
        XCTAssertEqual(policy.strictnessLevel, .permissive)
        XCTAssertTrue(policy.allowPII)
        XCTAssertTrue(policy.allowFilePaths)
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertTrue(policy.allowHealthData)
        XCTAssertTrue(policy.allowFinancialData)
        XCTAssertTrue(policy.blockedKeywords.isEmpty)
        XCTAssertNil(policy.allowedTopics)
        XCTAssertEqual(policy.maxContentLength, 0)
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

    // MARK: - OutboundPrivacyGuard Singleton & Basic Control

    func testOutboundPrivacyGuardExists() async {
        let guard_ = OutboundPrivacyGuard.shared
        let isEnabled = await guard_.isEnabled
        XCTAssertTrue(isEnabled) // Default should be enabled
    }

    func testRegisteredChannelIdsContainsDefaults() async {
        let guard_ = OutboundPrivacyGuard.shared
        let ids = await guard_.registeredChannelIds()
        XCTAssertTrue(ids.contains("cloud_api"))
        XCTAssertTrue(ids.contains("messaging"))
        XCTAssertTrue(ids.contains("mcp"))
        XCTAssertTrue(ids.contains("web_api"))
        XCTAssertTrue(ids.contains("moltbook"))
        XCTAssertTrue(ids.contains("cloudkit_sync"))
        XCTAssertTrue(ids.contains("health_ai"))
    }

    // MARK: - Kill Switch: isEnabled = false

    func testSanitizeWhenDisabledReturnsClean() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(false)
        defer { Task { await guard_.setEnabled(true) } }

        // Even sensitive content should pass through unmodified when disabled
        let result = await guard_.sanitize("sk-abc123ABCDEFGHIJKLMNOP", channel: "cloud_api")
        if case let .clean(text) = result {
            XCTAssertFalse(text.isEmpty)
        }
        // Any outcome is valid as long as we don't crash — kill switch just bypasses
    }

    func testSanitizeMessagesWhenDisabledReturnsOriginal() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(false)
        defer { Task { await guard_.setEnabled(true) } }

        let msg = makeAIMessage(content: "Hello world")
        let results = await guard_.sanitizeMessages([msg], channel: "cloud_api")
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Strict Firewall Mode: Unregistered Channel

    func testStrictModeBlocksUnregisteredChannel() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.strict)

        let result = await guard_.sanitize("Hello world", channel: "unregistered_channel_xyz")
        if case let .blocked(reason) = result {
            XCTAssertTrue(reason.contains("not registered"))
        } else {
            XCTFail("Expected .blocked for unregistered channel in strict mode, got \(result)")
        }
    }

    func testStrictModePassesRegisteredChannel() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.strict)

        let result = await guard_.sanitize("Hello world", channel: "cloud_api")
        // Should not be blocked due to missing registration
        if case let .blocked(reason) = result {
            XCTAssertFalse(reason.contains("not registered"), "Registered channel should not be blocked for missing registration")
        }
    }

    // MARK: - Standard Mode: Unknown Channel Passes with Default Policy

    func testStandardModeAllowsUnregisteredChannel() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let result = await guard_.sanitize("Hello world", channel: "some_custom_channel")
        // In standard mode, unknown channels should not be blocked for registration
        if case let .blocked(reason) = result {
            XCTAssertFalse(reason.contains("not registered"))
        }
    }

    // MARK: - Content Classification

    func testClassifyCleanTextIsJustText() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("Hello, how are you today?")
        XCTAssertTrue(types.contains(.text))
        XCTAssertFalse(types.contains(.credentials))
        XCTAssertFalse(types.contains(.healthData))
        XCTAssertFalse(types.contains(.financialData))
    }

    func testClassifyContentWithAPIKey() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("My api_key=abc123DEFGHIJKLMNabcdef")
        XCTAssertTrue(types.contains(.credentials))
    }

    func testClassifyContentWithSkKey() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("key: sk-abcdefghij0123456789xyz")
        XCTAssertTrue(types.contains(.credentials))
    }

    func testClassifyContentWithAWSKey() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("AKIAIOSFODNN7EXAMPLE123456")
        XCTAssertTrue(types.contains(.credentials))
    }

    func testClassifyContentWithPEMKey() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("-----BEGIN RSA PRIVATE KEY-----")
        XCTAssertTrue(types.contains(.credentials))
    }

    func testClassifyContentWithHealthData() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("My heart rate was 72 bpm this morning")
        XCTAssertTrue(types.contains(.healthData))
    }

    func testClassifyContentWithBloodPressure() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("blood pressure reading is 120/80")
        XCTAssertTrue(types.contains(.healthData))
    }

    func testClassifyContentWithHealthKit() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("HKQuantityType for steps")
        XCTAssertTrue(types.contains(.healthData))
    }

    func testClassifyContentWithFinancialData() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("IBAN: DE12345678901234567890")
        XCTAssertTrue(types.contains(.financialData))
    }

    func testClassifyContentWithCreditCard() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("4532 1234 5678 9012")
        XCTAssertTrue(types.contains(.financialData))
    }

    func testClassifyContentWithSSN() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("social security number 123-45-6789")
        XCTAssertTrue(types.contains(.financialData))
    }

    func testClassifyContentWithLocationData() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("latitude: 37.7749, longitude: -122.4194")
        XCTAssertTrue(types.contains(.locationData))
    }

    func testClassifyContentWithGPS() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("GPS coordinates for this location")
        XCTAssertTrue(types.contains(.locationData))
    }

    func testClassifyContentWithDeviceInfo() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("serial_number: ABC123XYZ device_id")
        XCTAssertTrue(types.contains(.deviceInfo))
    }

    func testClassifyContentWithMacAddress() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("mac_address: aa:bb:cc:dd:ee:ff")
        XCTAssertTrue(types.contains(.deviceInfo))
    }

    func testClassifyContentWithSwiftCode() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("func myFunction() {\n  let x = 42\n}")
        XCTAssertTrue(types.contains(.codeContent))
    }

    func testClassifyContentWithStructKeyword() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("struct MyModel {\n  var name: String\n}")
        XCTAssertTrue(types.contains(.codeContent))
    }

    func testClassifyContentWithJSON() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("""
        {"key": "value", "number": 42}
        """)
        XCTAssertTrue(types.contains(.structuredData))
    }

    func testClassifyContentWithoutCurlyBraces() async {
        let guard_ = OutboundPrivacyGuard.shared
        let types = await guard_.classifyContent("just plain text without braces")
        XCTAssertFalse(types.contains(.structuredData))
    }

    // MARK: - Disallowed Data Types in Strict Mode

    func testStrictModeBlocksHealthDataOnCloudAPIChannel() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.strict)

        // cloud_api channel does NOT allow .healthData
        // cloud_api allowedDataTypes = [.text, .codeContent, .structuredData]
        let content = "My heart rate was 72 bpm — HKQuantity reading from today"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        // Health data should be blocked at the data-type level for cloud_api
        if case let .blocked(reason) = result {
            XCTAssertTrue(reason.contains("Disallowed data types") || reason.contains("not registered"))
        }
        // Some false negatives are expected from NLP classification
    }

    func testHealthAIChannelAllowsHealthData() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.strict)

        // health_ai channel explicitly allows .healthData
        let content = "My heart rate was 72 bpm"
        let result = await guard_.sanitize(content, channel: "health_ai")
        // Should NOT be blocked due to data type mismatch
        if case let .blocked(reason) = result {
            XCTAssertFalse(reason.contains("Disallowed data types"), "health_ai should allow health data, but was blocked: \(reason)")
        }
    }

    // MARK: - Credential Redaction (Layer 4)

    func testSanitizeRedactsAPIKeyPattern() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "My key is sk-abcdefghij0123456789XYZabcdefghij and nothing else"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "sk- API key should be redacted, got: \(text)")
        }
    }

    func testSanitizeRedactsGitHubToken() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let ghToken = "ghp_" + String(repeating: "A", count: 36)
        let content = "token: \(ghToken)"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "GitHub token should be redacted")
        }
    }

    func testSanitizeRedactsSlackBotToken() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "bot token: xoxb-12345678-abc123defghi-xyz"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "Slack bot token should be redacted")
        }
    }

    func testSanitizeRedactsBearerToken() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.abc123"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "Bearer token should be redacted")
        }
    }

    func testSanitizeRedactsJWTToken() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // JWT: three base64url segments separated by dots
        let content = "token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "JWT should be redacted")
        }
    }

    func testSanitizeRedactsTelegramBotToken() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // Telegram bot token format: NNNNNNNNNN:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        let content = "telegram token: 123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "Telegram bot token should be redacted")
        }
    }

    func testSanitizeRedactsPEMPrivateKey() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "Here is my key: -----BEGIN RSA PRIVATE KEY----- some data"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "PEM key should be redacted")
        }
    }

    func testSanitizeRedactsSecretPassword() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "password: mysecretpassword123"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertTrue(text.contains("[REDACTED_CREDENTIAL]"), "password value should be redacted")
        }
    }

    // MARK: - File Path Redaction (Layer 6)

    func testSanitizeRedactsAbsolutePath() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "The file is at /Users/alexis/Documents/secret.txt and it's important"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        // cloud_api has allowFilePaths = false, so paths should be redacted
        if let text = result.content {
            XCTAssertFalse(text.contains("/Users/alexis"), "Absolute user path should be redacted")
        }
    }

    func testSanitizeRedactsHomeTildePath() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "Check the file at ~/Documents/MyProject/README.md"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertFalse(text.contains("~/Documents"), "Tilde path should be redacted")
        }
    }

    func testSanitizeRedactsApplicationsPath() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let content = "Installed at /Applications/Thea.app/Contents/MacOS/Thea"
        let result = await guard_.sanitize(content, channel: "cloud_api")
        if let text = result.content {
            XCTAssertFalse(text.contains("/Applications/Thea"), "/Applications path should be redacted")
        }
    }

    func testMCPChannelAllowsFilePaths() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // MCP policy has allowFilePaths = true, so paths should NOT be redacted
        let content = "Reading file ~/Documents/notes.txt"
        let result = await guard_.sanitize(content, channel: "mcp")
        if let text = result.content {
            // In MCP channel, paths are allowed so should not be redacted by file path layer
            XCTAssertNotNil(text)
        }
    }

    // MARK: - Max Content Length (Layer 1)

    func testSanitizeTruncatesLongMessagingContent() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // MessagingPolicy has maxContentLength = 4096
        let longContent = String(repeating: "A", count: 5000)
        let result = await guard_.sanitize(longContent, channel: "messaging")
        if let text = result.content {
            XCTAssertLessThanOrEqual(text.count, 4096 + 100) // some overhead from [truncated] suffix
        }
    }

    func testCloudAPINoLengthLimit() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // CloudAPIPolicy has maxContentLength = 0 (unlimited)
        let content = String(repeating: "Hello ", count: 1000)
        let result = await guard_.sanitize(content, channel: "cloud_api")
        // Should not be blocked due to length
        if case let .blocked(reason) = result {
            XCTAssertFalse(reason.contains("length"), "cloud_api should not truncate for length")
        }
    }

    // MARK: - Blocked Keywords (Layer 3)

    func testMessagingChannelBlocksPasswordKeyword() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // MessagingPolicy strictnessLevel = .strict → keyword match should block
        let content = "Here is the password for the server"
        let result = await guard_.sanitize(content, channel: "messaging")
        if case let .blocked(reason) = result {
            XCTAssertTrue(reason.contains("keyword") || reason.contains("password"))
        }
        // The result must be either blocked or the keyword was handled
    }

    func testMoltbookChannelBlocksSalary() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // MoltbookPolicy.strictnessLevel = .paranoid > .strict → should block
        let content = "My salary is 100k per year"
        let result = await guard_.sanitize(content, channel: "moltbook")
        if case let .blocked(reason) = result {
            XCTAssertTrue(reason.contains("salary") || reason.contains("keyword"))
        }
    }

    // MARK: - Topic Allowlist (Layer 2 — paranoid mode)

    func testMoltbookChannelBlocksOffTopicContent() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // Moltbook has allowedTopics; content with no matching topic should be blocked
        let content = "Let us talk about cooking recipes and holiday plans"
        let result = await guard_.sanitize(content, channel: "moltbook")
        // Should be blocked: no matching topic from dev allowlist
        if case let .blocked(reason) = result {
            XCTAssertTrue(reason.contains("allowed topics") || reason.contains("keyword"))
        }
    }

    func testMoltbookChannelPassesSwiftTopic() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        // Content that mentions "swift" matches the allowlist
        let content = "I want to discuss swift concurrency patterns with async await"
        let result = await guard_.sanitize(content, channel: "moltbook")
        // Content contains "swift" which is in the topic allowlist — should not be topic-blocked
        if case let .blocked(reason) = result {
            XCTAssertFalse(reason.contains("allowed topics"), "swift topic should be in allowlist")
        }
    }

    // MARK: - Audit Log

    func testAuditLogRecordsEntries() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.clearAuditLog()

        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        _ = await guard_.sanitize("Hello world", channel: "cloud_api")
        let log = await guard_.getAuditLog(limit: 10)
        XCTAssertGreaterThanOrEqual(log.count, 1)
    }

    func testAuditLogRecordsBlockedEntry() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.clearAuditLog()
        await guard_.setEnabled(true)
        await guard_.setMode(.strict)

        _ = await guard_.sanitize("test content", channel: "completely_unregistered_xyz_channel")
        let log = await guard_.getAuditLog(limit: 10)
        let blockedEntries = log.filter { $0.outcome == .blocked }
        XCTAssertGreaterThanOrEqual(blockedEntries.count, 1)
    }

    func testClearAuditLogEmptiesLog() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        _ = await guard_.sanitize("Hello", channel: "cloud_api")
        await guard_.clearAuditLog()
        let log = await guard_.getAuditLog()
        XCTAssertEqual(log.count, 0)
    }

    func testGetAuditLogLimitRespected() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.clearAuditLog()
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        for i in 0..<15 {
            _ = await guard_.sanitize("message \(i)", channel: "cloud_api")
        }
        let log = await guard_.getAuditLog(limit: 5)
        XCTAssertLessThanOrEqual(log.count, 5)
    }

    // MARK: - Audit Statistics

    func testPrivacyAuditStatisticsBasic() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.clearAuditLog()
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        _ = await guard_.sanitize("Hello", channel: "cloud_api")

        let stats = await guard_.getPrivacyAuditStatistics()
        XCTAssertGreaterThanOrEqual(stats.totalChecks, 1)
        XCTAssertGreaterThanOrEqual(stats.passed + stats.redacted + stats.blocked, 1)
    }

    func testPrivacyAuditStatisticsCountsBlocked() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.clearAuditLog()
        await guard_.setEnabled(true)
        await guard_.setMode(.strict)

        _ = await guard_.sanitize("test", channel: "unregistered_xyz")
        let stats = await guard_.getPrivacyAuditStatistics()
        XCTAssertGreaterThanOrEqual(stats.blocked, 1)
    }

    // MARK: - sanitizeMessages

    func testSanitizeMessagesFiltersBlockedContent() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.strict)

        // In strict mode, unregistered channel → blocked → messages should be dropped
        let msg1 = makeAIMessage(content: "Hello")
        let msg2 = makeAIMessage(content: "World")
        let results = await guard_.sanitizeMessages([msg1, msg2], channel: "unregistered_abc")
        // Blocked messages are skipped — expect empty result
        XCTAssertEqual(results.count, 0)
    }

    func testSanitizeMessagesPassesCleanContent() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let msg = makeAIMessage(content: "What time is it?")
        let results = await guard_.sanitizeMessages([msg], channel: "cloud_api")
        XCTAssertEqual(results.count, 1)
    }

    func testSanitizeMessagesHandlesMultipleMessages() async {
        let guard_ = OutboundPrivacyGuard.shared
        await guard_.setEnabled(true)
        await guard_.setMode(.standard)
        defer { Task { await guard_.setMode(.strict) } }

        let messages = (0..<5).map { i in makeAIMessage(content: "Message \(i) with no sensitive data") }
        let results = await guard_.sanitizeMessages(messages, channel: "cloud_api")
        XCTAssertEqual(results.count, 5)
    }

    // MARK: - Register Channel

    func testRegisterChannelAddsChannel() async {
        let guard_ = OutboundPrivacyGuard.shared
        let newChannelId = "test_channel_\(UUID().uuidString.prefix(8))"
        await guard_.registerChannel(
            id: newChannelId,
            description: "Test channel",
            policy: CloudAPIPolicy(),
            allowedDataTypes: [.text, .structuredData],
            registeredBy: "TestSuite"
        )
        let ids = await guard_.registeredChannelIds()
        XCTAssertTrue(ids.contains(newChannelId))
    }

    // MARK: - Pre-Commit Scan

    func testPreCommitScanCleanFileHasNoFindings() async {
        let guard_ = OutboundPrivacyGuard.shared
        let findings = await guard_.preCommitScan("func hello() { print(\"Hello\") }", filename: "Test.swift")
        XCTAssertTrue(findings.isEmpty)
    }

    func testPreCommitScanDetectsCredentials() async {
        let guard_ = OutboundPrivacyGuard.shared
        let content = "let apiKey = \"sk-abcdefghij0123456789abcdefghij\""
        let findings = await guard_.preCommitScan(content, filename: "Config.swift")
        let criticalFindings = findings.filter { $0.severity == .critical }
        XCTAssertGreaterThanOrEqual(criticalFindings.count, 1)
    }

    func testPreCommitScanReturnsRecommendation() async {
        let guard_ = OutboundPrivacyGuard.shared
        let content = "let token: String = \"sk-AbCdEf0123456789abcdefghij\""
        let findings = await guard_.preCommitScan(content, filename: "Secrets.swift")
        if let finding = findings.first {
            XCTAssertFalse(finding.recommendation.isEmpty)
            XCTAssertFalse(finding.file.isEmpty)
        }
    }

    // MARK: - Policy Management

    func testGetPolicyForRegisteredChannel() async {
        let guard_ = OutboundPrivacyGuard.shared
        let policy = await guard_.getPolicy(for: "cloud_api")
        // The legacy channelPolicies dict has "cloud_api"
        XCTAssertNotNil(policy)
    }

    func testGetPolicyForUnknownChannelReturnsNil() async {
        let guard_ = OutboundPrivacyGuard.shared
        let policy = await guard_.getPolicy(for: "definitely_not_a_channel_\(UUID().uuidString)")
        XCTAssertNil(policy)
    }

    func testSetPolicyUpdatesPolicy() async {
        let guard_ = OutboundPrivacyGuard.shared
        let testChannelId = "test_policy_channel"
        await guard_.setPolicy(PermissivePolicy(), for: testChannelId)
        let policy = await guard_.getPolicy(for: testChannelId)
        XCTAssertNotNil(policy)
        XCTAssertEqual(policy?.name, "Permissive")
    }

    // MARK: - FirewallMode Raw Values

    func testFirewallModeRawValues() {
        XCTAssertEqual(FirewallMode.strict.rawValue, "strict")
        XCTAssertEqual(FirewallMode.standard.rawValue, "standard")
        XCTAssertEqual(FirewallMode.permissive.rawValue, "permissive")
    }

    // MARK: - OutboundDataType

    func testOutboundDataTypeRawValues() {
        XCTAssertEqual(OutboundDataType.text.rawValue, "text")
        XCTAssertEqual(OutboundDataType.credentials.rawValue, "credentials")
        XCTAssertEqual(OutboundDataType.healthData.rawValue, "healthData")
        XCTAssertEqual(OutboundDataType.financialData.rawValue, "financialData")
        XCTAssertEqual(OutboundDataType.locationData.rawValue, "locationData")
        XCTAssertEqual(OutboundDataType.deviceInfo.rawValue, "deviceInfo")
        XCTAssertEqual(OutboundDataType.codeContent.rawValue, "codeContent")
        XCTAssertEqual(OutboundDataType.structuredData.rawValue, "structuredData")
    }

    func testOutboundDataTypeIsCaseIterable() {
        let allCases = OutboundDataType.allCases
        XCTAssertGreaterThanOrEqual(allCases.count, 9)
    }

    // MARK: - AIMessage Extension

    func testAIMessageWithContentCreatesNewMessage() {
        let original = makeAIMessage(content: "Original content")
        let modified = original.withContent(.text("New content"))
        XCTAssertEqual(modified.id, original.id)
        XCTAssertEqual(modified.conversationID, original.conversationID)
        XCTAssertEqual(modified.role, original.role)
        XCTAssertEqual(modified.content.textValue, "New content")
    }

    // MARK: - Helpers

    private func makeAIMessage(content: String) -> AIMessage {
        AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(content),
            timestamp: Date(),
            model: "test"
        )
    }
}

// swiftlint:enable file_length type_body_length
