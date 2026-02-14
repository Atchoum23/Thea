import Foundation
import XCTest

/// Standalone tests for OutboundPrivacyGuard types and sanitization logic:
/// SanitizationOutcome, RedactionType, Redaction, AuditOutcome, AuditStatistics,
/// credential detection regexes, file path detection, PII detection patterns.
/// Mirrors types from Privacy/OutboundPrivacyGuard.swift.
final class OutboundPrivacyGuardTypesTests: XCTestCase {

    // MARK: - SanitizationOutcome (mirror OutboundPrivacyGuard.swift)

    enum SanitizationOutcome: Sendable {
        case clean(String)
        case redacted(String, redactions: [Redaction])
        case blocked(reason: String)

        var content: String? {
            switch self {
            case .clean(let text): text
            case .redacted(let text, _): text
            case .blocked: nil
            }
        }
    }

    enum RedactionType: String, Sendable {
        case lengthTruncation
        case blockedKeyword
        case credential
        case pii
        case filePath
    }

    struct Redaction: Sendable {
        let type: RedactionType
        let originalLength: Int
        let replacement: String
        let reason: String
    }

    func testSanitizationOutcomeClean() {
        let outcome = SanitizationOutcome.clean("Hello world")
        XCTAssertEqual(outcome.content, "Hello world")
    }

    func testSanitizationOutcomeRedacted() {
        let redaction = Redaction(type: .credential, originalLength: 40, replacement: "[REDACTED]", reason: "API key")
        let outcome = SanitizationOutcome.redacted("Safe text [REDACTED]", redactions: [redaction])
        XCTAssertEqual(outcome.content, "Safe text [REDACTED]")
    }

    func testSanitizationOutcomeBlocked() {
        let outcome = SanitizationOutcome.blocked(reason: "Blocked keyword found")
        XCTAssertNil(outcome.content)
    }

    // MARK: - AuditOutcome & AuditStatistics (mirror OutboundPrivacyGuard.swift)

    enum AuditOutcome: String, Codable {
        case passed
        case redacted
        case blocked
    }

    struct AuditStatistics {
        let totalChecks: Int
        let passed: Int
        let redacted: Int
        let blocked: Int
        let totalRedactions: Int
    }

    func testAuditStatisticsValues() {
        let stats = AuditStatistics(totalChecks: 100, passed: 80, redacted: 15, blocked: 5, totalRedactions: 25)
        XCTAssertEqual(stats.totalChecks, 100)
        XCTAssertEqual(stats.passed, 80)
        XCTAssertEqual(stats.redacted, 15)
        XCTAssertEqual(stats.blocked, 5)
        XCTAssertEqual(stats.totalRedactions, 25)
        XCTAssertEqual(stats.passed + stats.redacted + stats.blocked, stats.totalChecks)
    }

    // MARK: - Credential Detection Patterns (mirror OutboundPrivacyGuard.swift)

    let credentialPatterns: [(String, String)] = [
        ("sk-[a-zA-Z0-9]{20,}", "OpenAI key"),
        ("key-[a-zA-Z0-9]{20,}", "Generic API key"),
        ("anthropic-[a-zA-Z0-9]{20,}", "Anthropic key"),
        ("AIza[A-Za-z0-9_\\-]{35}", "Google AI key"),
        ("ghp_[a-zA-Z0-9]{36}", "GitHub PAT"),
        ("gho_[a-zA-Z0-9]{36}", "GitHub OAuth"),
        ("xoxb-[a-zA-Z0-9\\-]+", "Slack bot token"),
        ("xoxp-[a-zA-Z0-9\\-]+", "Slack user token"),
        ("Bearer [a-zA-Z0-9_\\-.~+/]+", "Bearer token"),
        ("AKIA[0-9A-Z]{16}", "AWS access key"),
        ("eyJ[a-zA-Z0-9_\\-]+\\.[a-zA-Z0-9_\\-]+\\.[a-zA-Z0-9_\\-]+", "JWT token"),
    ]

    func detectCredential(in text: String) -> Bool {
        for (pattern, _) in credentialPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }
        return false
    }

    func testDetectOpenAIKey() {
        XCTAssertTrue(detectCredential(in: "My key is sk-abcdefghijklmnopqrstuvwxyz1234"))
    }

    func testDetectAnthropicKey() {
        XCTAssertTrue(detectCredential(in: "anthropic-abcdefghijklmnopqrstuvwxyz"))
    }

    func testDetectGitHubPAT() {
        XCTAssertTrue(detectCredential(in: "ghp_abcdefghijklmnopqrstuvwxyz1234567890"))
    }

    func testDetectAWSKey() {
        XCTAssertTrue(detectCredential(in: "AKIAIOSFODNN7EXAMPLE"))
    }

    func testDetectBearerToken() {
        XCTAssertTrue(detectCredential(in: "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.test"))
    }

    func testDetectJWTToken() {
        XCTAssertTrue(detectCredential(in: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"))
    }

    func testDetectSlackBotToken() {
        XCTAssertTrue(detectCredential(in: "xoxb-123456789-abcdefghij"))
    }

    func testNoFalsePositiveOnNormalText() {
        XCTAssertFalse(detectCredential(in: "Hello, how are you today?"))
        XCTAssertFalse(detectCredential(in: "The key insight is that Swift is fast"))
        XCTAssertFalse(detectCredential(in: "func calculateSum() -> Int"))
    }

    func testNoFalsePositiveOnShortKeys() {
        XCTAssertFalse(detectCredential(in: "sk-short"))
        XCTAssertFalse(detectCredential(in: "key-abc"))
    }

    // MARK: - File Path Detection (mirror OutboundPrivacyGuard.swift)

    let filePathPatterns = [
        "/Users/[a-zA-Z0-9._-]+/[^\\s\"'\\\\)}]+",
        "~/[^\\s\"'\\\\)}]+",
        "/Applications/[^\\s\"'\\\\)}]+",
        "/Library/[^\\s\"'\\\\)}]+",
        "/private/[^\\s\"'\\\\)}]+"
    ]

    func detectFilePath(in text: String) -> Bool {
        for pattern in filePathPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }
        return false
    }

    func testDetectMacOSUserPath() {
        XCTAssertTrue(detectFilePath(in: "File at /Users/alexis/Documents/test.swift"))
    }

    func testDetectHomeTildePath() {
        XCTAssertTrue(detectFilePath(in: "Config in ~/Library/Preferences/com.app.plist"))
    }

    func testDetectApplicationsPath() {
        XCTAssertTrue(detectFilePath(in: "Installed at /Applications/Xcode.app"))
    }

    func testDetectLibraryPath() {
        XCTAssertTrue(detectFilePath(in: "Logs in /Library/Logs/DiagnosticReports/"))
    }

    func testDetectPrivatePath() {
        XCTAssertTrue(detectFilePath(in: "Temp at /private/var/folders/abc"))
    }

    func testNoFalsePositiveOnRegularPaths() {
        XCTAssertFalse(detectFilePath(in: "Hello world, no paths here"))
        XCTAssertFalse(detectFilePath(in: "The URL is https://example.com/path"))
    }

    // MARK: - Length Truncation Logic (mirror OutboundPrivacyGuard.swift)

    func truncateContent(_ content: String, maxLength: Int) -> SanitizationOutcome {
        guard content.count > maxLength else { return .clean(content) }
        let truncated = String(content.prefix(maxLength)) + " [truncated]"
        let redaction = Redaction(
            type: .lengthTruncation,
            originalLength: content.count,
            replacement: "[truncated]",
            reason: "Content exceeds maximum length of \(maxLength)"
        )
        return .redacted(truncated, redactions: [redaction])
    }

    func testTruncationUnderLimit() {
        let outcome = truncateContent("Short text", maxLength: 100)
        if case .clean(let text) = outcome {
            XCTAssertEqual(text, "Short text")
        } else {
            XCTFail("Expected clean outcome")
        }
    }

    func testTruncationOverLimit() {
        let longText = String(repeating: "a", count: 200)
        let outcome = truncateContent(longText, maxLength: 100)
        if case .redacted(let text, let redactions) = outcome {
            XCTAssertTrue(text.hasSuffix("[truncated]"))
            XCTAssertEqual(redactions.count, 1)
            XCTAssertEqual(redactions.first?.type, .lengthTruncation)
            XCTAssertEqual(redactions.first?.originalLength, 200)
        } else {
            XCTFail("Expected redacted outcome")
        }
    }

    func testTruncationExactLimit() {
        let exactText = String(repeating: "b", count: 50)
        let outcome = truncateContent(exactText, maxLength: 50)
        if case .clean = outcome {
            // Expected
        } else {
            XCTFail("Expected clean outcome at exact limit")
        }
    }

    // MARK: - Blocked Keyword Detection (mirror OutboundPrivacyGuard.swift)

    func checkBlockedKeywords(_ content: String, keywords: Set<String>, strict: Bool) -> SanitizationOutcome? {
        let lowerContent = content.lowercased()
        for keyword in keywords {
            if lowerContent.contains(keyword.lowercased()) {
                if strict {
                    return .blocked(reason: "Content contains blocked keyword: \(keyword)")
                } else {
                    let redacted = content.replacingOccurrences(of: keyword, with: "[REDACTED]",
                                                                options: .caseInsensitive)
                    let redaction = Redaction(type: .blockedKeyword, originalLength: keyword.count,
                                             replacement: "[REDACTED]", reason: "Blocked keyword")
                    return .redacted(redacted, redactions: [redaction])
                }
            }
        }
        return nil
    }

    func testBlockedKeywordStrictMode() {
        let result = checkBlockedKeywords("This has PASSWORD in it",
                                          keywords: ["password"], strict: true)
        if case .blocked(let reason) = result {
            XCTAssertTrue(reason.contains("password"))
        } else {
            XCTFail("Expected blocked outcome in strict mode")
        }
    }

    func testBlockedKeywordNonStrictMode() {
        let result = checkBlockedKeywords("My password is secret",
                                          keywords: ["password"], strict: false)
        if case .redacted(let text, _) = result {
            XCTAssertTrue(text.contains("[REDACTED]"))
            XCTAssertFalse(text.lowercased().contains("password"))
        } else {
            XCTFail("Expected redacted outcome in non-strict mode")
        }
    }

    func testNoBlockedKeywords() {
        let result = checkBlockedKeywords("Safe content here",
                                          keywords: ["password", "secret"], strict: true)
        XCTAssertNil(result, "No blocked keyword should return nil")
    }

    func testBlockedKeywordCaseInsensitive() {
        let result = checkBlockedKeywords("My PASSWORD is...",
                                          keywords: ["password"], strict: true)
        XCTAssertNotNil(result, "Case-insensitive match should detect PASSWORD")
    }

    // MARK: - Topic Allowlist (mirror OutboundPrivacyGuard.swift)

    func checkTopicAllowlist(_ content: String, allowedTopics: Set<String>?) -> SanitizationOutcome? {
        guard let topics = allowedTopics, !topics.isEmpty else { return nil }
        let lowerContent = content.lowercased()
        for topic in topics {
            if lowerContent.contains(topic.lowercased()) {
                return nil // Allowed
            }
        }
        return .blocked(reason: "Content does not match any allowed topic")
    }

    func testTopicAllowlistMatchesTopic() {
        let result = checkTopicAllowlist("Help me with Swift programming",
                                          allowedTopics: ["swift", "python"])
        XCTAssertNil(result, "Content matching allowed topic should pass")
    }

    func testTopicAllowlistNoMatch() {
        let result = checkTopicAllowlist("Tell me about cooking",
                                          allowedTopics: ["swift", "python"])
        if case .blocked = result {
            // Expected
        } else {
            XCTFail("Content not matching any topic should be blocked")
        }
    }

    func testTopicAllowlistNilTopics() {
        let result = checkTopicAllowlist("Anything goes", allowedTopics: nil)
        XCTAssertNil(result, "Nil topics should allow everything")
    }

    func testTopicAllowlistEmptyTopics() {
        let result = checkTopicAllowlist("Anything goes", allowedTopics: [])
        XCTAssertNil(result, "Empty topics should allow everything")
    }

    // MARK: - PII Pattern Detection

    func detectPII(in text: String) -> Bool {
        let piiPatterns = [
            "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",  // Email
            "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b",                // Phone (US)
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",                         // SSN
        ]
        for pattern in piiPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }
        return false
    }

    func testDetectEmail() {
        XCTAssertTrue(detectPII(in: "Contact me at user@example.com"))
    }

    func testDetectPhoneNumber() {
        XCTAssertTrue(detectPII(in: "Call me at 555-123-4567"))
    }

    func testDetectSSN() {
        XCTAssertTrue(detectPII(in: "SSN: 123-45-6789"))
    }

    func testNoPIIInCleanText() {
        XCTAssertFalse(detectPII(in: "Hello, how can I help you with Swift?"))
    }

    // MARK: - Multi-Layer Sanitization Pipeline

    func testFullSanitizationPipeline() {
        // Simulate the 6-layer pipeline
        let content = "My API key is sk-1234567890abcdefghijklmnop and email is user@example.com"

        // Layer 1: Length check (pass)
        let lengthOK = content.count <= 10000

        // Layer 4: Credential check
        let hasCredential = detectCredential(in: content)

        // Layer 5: PII check
        let hasPII = detectPII(in: content)

        XCTAssertTrue(lengthOK)
        XCTAssertTrue(hasCredential, "Should detect API key")
        XCTAssertTrue(hasPII, "Should detect email")
    }
}
