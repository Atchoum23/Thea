// PrivacyPolicyTypesTests.swift
// Tests for PrivacyPolicy types (StrictnessLevel, SanitizationOutcome, etc.)

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum StrictnessLevel: String, Codable, Sendable, Comparable {
    case permissive, standard, strict, paranoid

    private var rank: Int {
        switch self {
        case .permissive: 0
        case .standard: 1
        case .strict: 2
        case .paranoid: 3
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }
}

private enum RedactionType: String, Codable, Sendable {
    case pii, apiKey, filePath, credential
    case healthData, financialData, codeSnippet
    case blockedKeyword, topicViolation, lengthTruncation
}

private struct Redaction: Sendable {
    let type: RedactionType
    let originalLength: Int
    let replacement: String
    let reason: String
}

private enum SanitizationOutcome: Sendable {
    case clean(String)
    case redacted(String, redactions: [Redaction])
    case blocked(reason: String)

    var content: String? {
        switch self {
        case let .clean(text): text
        case let .redacted(text, _): text
        case .blocked: nil
        }
    }

    var isAllowed: Bool {
        switch self {
        case .clean, .redacted: true
        case .blocked: false
        }
    }
}

private enum AuditOutcome: String, Codable, Sendable {
    case passed, redacted, blocked
}

private struct PrivacyAuditEntry: Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let channel: String
    let policyName: String
    let outcome: AuditOutcome
    let redactionCount: Int
    let originalLength: Int
    let sanitizedLength: Int
}

// MARK: - StrictnessLevel Tests

final class StrictnessLevelTests: XCTestCase {

    func testComparable() {
        XCTAssertTrue(StrictnessLevel.permissive < .standard)
        XCTAssertTrue(StrictnessLevel.standard < .strict)
        XCTAssertTrue(StrictnessLevel.strict < .paranoid)
        XCTAssertFalse(StrictnessLevel.paranoid < .permissive)
    }

    func testOrdering() {
        let levels: [StrictnessLevel] = [
            .paranoid, .permissive, .strict, .standard
        ]
        let sorted = levels.sorted()
        XCTAssertEqual(
            sorted,
            [.permissive, .standard, .strict, .paranoid]
        )
    }

    func testRawValues() {
        XCTAssertEqual(StrictnessLevel.permissive.rawValue, "permissive")
        XCTAssertEqual(StrictnessLevel.standard.rawValue, "standard")
        XCTAssertEqual(StrictnessLevel.strict.rawValue, "strict")
        XCTAssertEqual(StrictnessLevel.paranoid.rawValue, "paranoid")
    }

    func testCodableRoundTrip() throws {
        for level in [
            StrictnessLevel.permissive, .standard, .strict, .paranoid
        ] {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(
                StrictnessLevel.self, from: data
            )
            XCTAssertEqual(decoded, level)
        }
    }

    func testEqualityNotLessThan() {
        XCTAssertFalse(StrictnessLevel.strict < .strict)
    }
}

// MARK: - SanitizationOutcome Tests

final class SanitizationOutcomeTests: XCTestCase {

    func testCleanContent() {
        let outcome = SanitizationOutcome.clean("Hello world")
        XCTAssertEqual(outcome.content, "Hello world")
        XCTAssertTrue(outcome.isAllowed)
    }

    func testRedactedContent() {
        let redaction = Redaction(
            type: .pii, originalLength: 15,
            replacement: "[REDACTED]", reason: "PII detected"
        )
        let outcome = SanitizationOutcome.redacted(
            "Hello [REDACTED]", redactions: [redaction]
        )
        XCTAssertEqual(outcome.content, "Hello [REDACTED]")
        XCTAssertTrue(outcome.isAllowed)
    }

    func testBlockedContent() {
        let outcome = SanitizationOutcome.blocked(
            reason: "Sensitive topic"
        )
        XCTAssertNil(outcome.content)
        XCTAssertFalse(outcome.isAllowed)
    }

    func testMultipleRedactions() {
        let redactions = [
            Redaction(
                type: .apiKey, originalLength: 40,
                replacement: "[API_KEY]", reason: "API key detected"
            ),
            Redaction(
                type: .filePath, originalLength: 25,
                replacement: "[PATH]", reason: "File path detected"
            )
        ]
        let outcome = SanitizationOutcome.redacted(
            "key=[API_KEY] path=[PATH]", redactions: redactions
        )
        XCTAssertTrue(outcome.isAllowed)
        XCTAssertNotNil(outcome.content)
    }
}

// MARK: - RedactionType Tests

final class RedactionTypeTests: XCTestCase {

    func testAllTypes() {
        let allTypes: [RedactionType] = [
            .pii, .apiKey, .filePath, .credential,
            .healthData, .financialData, .codeSnippet,
            .blockedKeyword, .topicViolation, .lengthTruncation
        ]
        XCTAssertEqual(allTypes.count, 10)
    }

    func testCodableRoundTrip() throws {
        for redType in [
            RedactionType.pii, .apiKey, .credential,
            .healthData, .topicViolation
        ] {
            let data = try JSONEncoder().encode(redType)
            let decoded = try JSONDecoder().decode(
                RedactionType.self, from: data
            )
            XCTAssertEqual(decoded, redType)
        }
    }

    func testRawValues() {
        XCTAssertEqual(RedactionType.pii.rawValue, "pii")
        XCTAssertEqual(RedactionType.apiKey.rawValue, "apiKey")
        XCTAssertEqual(RedactionType.filePath.rawValue, "filePath")
        XCTAssertEqual(RedactionType.credential.rawValue, "credential")
        XCTAssertEqual(
            RedactionType.lengthTruncation.rawValue, "lengthTruncation"
        )
    }
}

// MARK: - AuditOutcome Tests

final class AuditOutcomeTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(AuditOutcome.passed.rawValue, "passed")
        XCTAssertEqual(AuditOutcome.redacted.rawValue, "redacted")
        XCTAssertEqual(AuditOutcome.blocked.rawValue, "blocked")
    }

    func testCodableRoundTrip() throws {
        for outcome in [
            AuditOutcome.passed, .redacted, .blocked
        ] {
            let data = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(
                AuditOutcome.self, from: data
            )
            XCTAssertEqual(decoded, outcome)
        }
    }
}

// MARK: - PrivacyAuditEntry Tests

final class PrivacyAuditEntryTests: XCTestCase {

    func testInitialization() {
        let id = UUID()
        let now = Date()
        let entry = PrivacyAuditEntry(
            id: id, timestamp: now,
            channel: "anthropic_api",
            policyName: "CloudAPIPolicy",
            outcome: .redacted,
            redactionCount: 3,
            originalLength: 500,
            sanitizedLength: 420
        )
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.channel, "anthropic_api")
        XCTAssertEqual(entry.policyName, "CloudAPIPolicy")
        XCTAssertEqual(entry.outcome, .redacted)
        XCTAssertEqual(entry.redactionCount, 3)
        XCTAssertEqual(entry.originalLength, 500)
        XCTAssertEqual(entry.sanitizedLength, 420)
    }

    func testLengthReduction() {
        let entry = PrivacyAuditEntry(
            id: UUID(), timestamp: Date(),
            channel: "moltbook",
            policyName: "MoltbookPolicy",
            outcome: .redacted,
            redactionCount: 5,
            originalLength: 1000,
            sanitizedLength: 600
        )
        let reduction = entry.originalLength - entry.sanitizedLength
        XCTAssertEqual(reduction, 400)
    }

    func testBlockedEntry() {
        let entry = PrivacyAuditEntry(
            id: UUID(), timestamp: Date(),
            channel: "openclaw_whatsapp",
            policyName: "MessagingPolicy",
            outcome: .blocked,
            redactionCount: 0,
            originalLength: 200,
            sanitizedLength: 0
        )
        XCTAssertEqual(entry.outcome, .blocked)
        XCTAssertEqual(entry.sanitizedLength, 0)
    }
}
