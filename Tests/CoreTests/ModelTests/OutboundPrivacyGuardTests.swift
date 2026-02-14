// OutboundPrivacyGuardTests.swift
// Tests for OutboundPrivacyGuard-specific logic: PrivacyPolicy implementations,
// PrivacyAuditStatistics, credential detection, file-path detection,
// and audit log trimming.
// Mirrors types from Shared/Privacy/PrivacyPolicy.swift,
// PrivacyPolicies.swift, and OutboundPrivacyGuard.swift.
// Basic type tests (StrictnessLevel, SanitizationOutcome, RedactionType,
// PrivacyAuditEntry) are in PrivacyPolicyTypesTests.swift.

import Foundation
import XCTest

// MARK: - Mirror Types

private enum StrictnessLevel: String, Codable, Comparable {
    case permissive, standard, strict, paranoid

    private var rank: Int {
        switch self {
        case .permissive: 0
        case .standard: 1
        case .strict: 2
        case .paranoid: 3
        }
    }

    static func < (lhs: StrictnessLevel, rhs: StrictnessLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

private enum RedactionType: String, Codable, CaseIterable {
    case pii, apiKey, filePath, credential, healthData
    case financialData, codeSnippet, blockedKeyword
    case topicViolation, lengthTruncation
}

private struct Redaction {
    let type: RedactionType
    let originalLength: Int
    let replacement: String
    let reason: String
}

private enum AuditOutcome: String, Codable {
    case passed, redacted, blocked
}

private struct PrivacyAuditEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let channel: String
    let policyName: String
    let outcome: AuditOutcome
    let redactionCount: Int
    let originalLength: Int
    let sanitizedLength: Int
}

private struct PrivacyAuditStatistics {
    let totalChecks: Int
    let passed: Int
    let redacted: Int
    let blocked: Int
    let totalRedactions: Int
}

private protocol PrivacyPolicy {
    var name: String { get }
    var strictnessLevel: StrictnessLevel { get }
    var allowPII: Bool { get }
    var allowFilePaths: Bool { get }
    var allowCodeSnippets: Bool { get }
    var blockedKeywords: Set<String> { get }
    var allowedTopics: Set<String>? { get }
    var maxContentLength: Int { get }
}

private struct CloudAPIPolicy: PrivacyPolicy {
    let name = "Cloud API"
    let strictnessLevel: StrictnessLevel = .standard
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = true
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}

private struct MessagingPolicy: PrivacyPolicy {
    let name = "Messaging"
    let strictnessLevel: StrictnessLevel = .strict
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = false
    let blockedKeywords: Set<String> = [
        "password", "secret", "api key", "token",
        "credit card", "bank account", "social security"
    ]
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 4096
}

private struct MoltbookPolicy: PrivacyPolicy {
    let name = "Moltbook"
    let strictnessLevel: StrictnessLevel = .paranoid
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = false
    let blockedKeywords: Set<String> = [
        "password", "secret", "api key", "token", "credential",
        "credit card", "bank", "social security", "ssn",
        "address", "phone number", "email",
        "health", "medical", "diagnosis", "prescription",
        "salary", "income", "debt"
    ]
    let allowedTopics: Set<String>? = [
        "swift", "ios", "macos", "swiftui", "testing",
        "architecture", "ai", "llm", "mlx"
    ]
    let maxContentLength = 2048
}

private struct PermissivePolicy: PrivacyPolicy {
    let name = "Permissive"
    let strictnessLevel: StrictnessLevel = .permissive
    let allowPII = true
    let allowFilePaths = true
    let allowCodeSnippets = true
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}

// MARK: - Credential Detection Helper

private func detectCredentials(in text: String) -> [Redaction] {
    var redactions: [Redaction] = []
    let patterns: [(String, String)] = [
        ("sk-[a-zA-Z0-9]{20,}", "API key (sk-)"),
        ("ghp_[a-zA-Z0-9]{36}", "GitHub token"),
        ("AKIA[0-9A-Z]{16}", "AWS access key"),
        ("-----BEGIN[A-Z ]*PRIVATE KEY-----", "PEM private key"),
        ("eyJ[a-zA-Z0-9_-]{10,}\\.eyJ[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]+", "JWT token")
    ]
    for (pattern, description) in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        for match in matches {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            redactions.append(Redaction(
                type: .credential,
                originalLength: text[swiftRange].count,
                replacement: "[REDACTED_CREDENTIAL]",
                reason: description
            ))
        }
    }
    return redactions
}

// MARK: - File Path Detection Helper

private func detectFilePaths(in text: String) -> [Redaction] {
    var redactions: [Redaction] = []
    let patterns = [
        "/Users/[a-zA-Z0-9._-]+/[^\\s\"'\\])}]+",
        "~/[^\\s\"'\\])}]+"
    ]
    for pattern in patterns {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        for match in matches {
            guard Range(match.range, in: text) != nil else { continue }
            redactions.append(Redaction(
                type: .filePath,
                originalLength: match.range.length,
                replacement: "[PATH_REDACTED]",
                reason: "Local file path"
            ))
        }
    }
    return redactions
}

// MARK: - PrivacyAuditStatistics Tests

final class PrivacyAuditStatisticsTests: XCTestCase {

    func testEmptyStatistics() {
        let stats = PrivacyAuditStatistics(
            totalChecks: 0, passed: 0, redacted: 0,
            blocked: 0, totalRedactions: 0
        )
        XCTAssertEqual(stats.totalChecks, 0)
    }

    func testStatisticsConsistency() {
        let stats = PrivacyAuditStatistics(
            totalChecks: 100, passed: 80, redacted: 15,
            blocked: 5, totalRedactions: 42
        )
        XCTAssertEqual(stats.passed + stats.redacted + stats.blocked, stats.totalChecks)
    }

    func testStatisticsWithRedactions() {
        let stats = PrivacyAuditStatistics(
            totalChecks: 50, passed: 30, redacted: 20,
            blocked: 0, totalRedactions: 75
        )
        XCTAssertGreaterThan(stats.totalRedactions, stats.redacted)
    }
}

// MARK: - Policy Tests

final class PrivacyPolicyTests: XCTestCase {

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

    func testMoltbookPolicyIsParanoid() {
        let policy = MoltbookPolicy()
        XCTAssertEqual(policy.strictnessLevel, .paranoid)
        XCTAssertNotNil(policy.allowedTopics)
        XCTAssertTrue(policy.allowedTopics!.contains("swift"))
        XCTAssertTrue(policy.allowedTopics!.contains("ai"))
        XCTAssertEqual(policy.maxContentLength, 2048)
    }

    func testMoltbookBlocksHealthFinanceKeywords() {
        let policy = MoltbookPolicy()
        XCTAssertTrue(policy.blockedKeywords.contains("health"))
        XCTAssertTrue(policy.blockedKeywords.contains("salary"))
        XCTAssertTrue(policy.blockedKeywords.contains("ssn"))
    }

    func testPermissivePolicyAllowsEverything() {
        let policy = PermissivePolicy()
        XCTAssertEqual(policy.strictnessLevel, .permissive)
        XCTAssertTrue(policy.allowPII)
        XCTAssertTrue(policy.allowFilePaths)
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertTrue(policy.blockedKeywords.isEmpty)
        XCTAssertNil(policy.allowedTopics)
        XCTAssertEqual(policy.maxContentLength, 0)
    }

    func testStrictnessOrdering() {
        let policies: [(any PrivacyPolicy, StrictnessLevel)] = [
            (PermissivePolicy(), .permissive),
            (CloudAPIPolicy(), .standard),
            (MessagingPolicy(), .strict),
            (MoltbookPolicy(), .paranoid)
        ]
        for (policy, expected) in policies {
            XCTAssertEqual(policy.strictnessLevel, expected)
        }
    }
}

// MARK: - Credential Detection Tests

final class CredentialDetectionTests: XCTestCase {

    func testDetectsOpenAIKey() {
        let text = "My key is sk-abcdefghijklmnopqrstuvwxyz12345678"
        let redactions = detectCredentials(in: text)
        XCTAssertFalse(redactions.isEmpty)
        XCTAssertEqual(redactions.first?.reason, "API key (sk-)")
    }

    func testDetectsGitHubToken() {
        let text = "Use ghp_abcdefghijklmnopqrstuvwxyz1234567890 for auth"
        let redactions = detectCredentials(in: text)
        XCTAssertFalse(redactions.isEmpty)
        XCTAssertEqual(redactions.first?.reason, "GitHub token")
    }

    func testDetectsAWSKey() {
        let text = "AWS key AKIAIOSFODNN7EXAMPLE"
        let redactions = detectCredentials(in: text)
        XCTAssertFalse(redactions.isEmpty)
        XCTAssertEqual(redactions.first?.reason, "AWS access key")
    }

    func testDetectsPEMKey() {
        let text = "-----BEGIN RSA PRIVATE KEY-----\nMIIE..."
        let redactions = detectCredentials(in: text)
        XCTAssertFalse(redactions.isEmpty)
        XCTAssertEqual(redactions.first?.reason, "PEM private key")
    }

    func testNoFalsePositiveOnSafeText() {
        let text = "This is a normal message about Swift programming."
        let redactions = detectCredentials(in: text)
        XCTAssertTrue(redactions.isEmpty)
    }

    func testDetectsMultipleCredentials() {
        let text = """
        API: sk-abcdefghijklmnopqrstuvwxyz12345678
        AWS: AKIAIOSFODNN7EXAMPLE
        """
        let redactions = detectCredentials(in: text)
        XCTAssertGreaterThanOrEqual(redactions.count, 2)
    }
}

// MARK: - File Path Detection Tests

final class FilePathDetectionTests: XCTestCase {

    func testDetectsAbsolutePath() {
        let text = "File at /Users/alexis/Documents/secret.txt"
        let redactions = detectFilePaths(in: text)
        XCTAssertFalse(redactions.isEmpty)
    }

    func testDetectsTildePath() {
        let text = "Check ~/Documents/config.json"
        let redactions = detectFilePaths(in: text)
        XCTAssertFalse(redactions.isEmpty)
    }

    func testNoFalsePositiveOnURL() {
        let text = "Visit https://example.com/path/to/page"
        let redactions = detectFilePaths(in: text)
        XCTAssertTrue(redactions.isEmpty)
    }

    func testNoFalsePositiveOnCleanText() {
        let text = "Let's discuss SwiftUI architecture patterns"
        let redactions = detectFilePaths(in: text)
        XCTAssertTrue(redactions.isEmpty)
    }
}

// MARK: - Audit Log Trimming Tests

final class AuditLogTrimmingTests: XCTestCase {

    func testTrimToMaxEntries() {
        var log: [PrivacyAuditEntry] = []
        let maxEntries = 5000
        for idx in 0..<5050 {
            log.append(PrivacyAuditEntry(
                id: UUID(), timestamp: Date(),
                channel: "test", policyName: "Test",
                outcome: idx % 10 == 0 ? .redacted : .passed,
                redactionCount: idx % 10 == 0 ? 1 : 0,
                originalLength: 100, sanitizedLength: 100
            ))
            if log.count > maxEntries {
                log.removeFirst(log.count - maxEntries)
            }
        }
        XCTAssertEqual(log.count, maxEntries)
    }

    func testAuditLogSuffix() {
        var log: [PrivacyAuditEntry] = []
        for idx in 0..<200 {
            log.append(PrivacyAuditEntry(
                id: UUID(), timestamp: Date(),
                channel: "ch_\(idx)", policyName: "Test",
                outcome: .passed, redactionCount: 0,
                originalLength: 10, sanitizedLength: 10
            ))
        }
        let recent = Array(log.suffix(100))
        XCTAssertEqual(recent.count, 100)
        XCTAssertEqual(recent.first?.channel, "ch_100")
    }
}
