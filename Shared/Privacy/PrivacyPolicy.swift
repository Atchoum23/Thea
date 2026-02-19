// PrivacyPolicy.swift
// Thea — Outbound Privacy Policies
//
// Defines what data is allowed to leave the device per channel.
// Each outbound channel (API, messaging, MCP, web) uses a policy.

import Foundation

// MARK: - Privacy Policy Protocol

/// Defines privacy constraints for a specific outbound channel
protocol PrivacyPolicy: Sendable {
    /// Human-readable name for this policy
    var name: String { get }

    /// Strictness level governing default behavior
    var strictnessLevel: StrictnessLevel { get }

    /// Whether PII (names, emails, phone numbers) may pass through
    var allowPII: Bool { get }

    /// Whether local file paths may appear in outbound content
    var allowFilePaths: Bool { get }

    /// Whether code snippets may be sent
    var allowCodeSnippets: Bool { get }

    /// Whether health/medical data may be sent
    var allowHealthData: Bool { get }

    /// Whether financial data may be sent
    var allowFinancialData: Bool { get }

    /// Keywords that trigger blocking (case-insensitive)
    var blockedKeywords: Set<String> { get }

// periphery:ignore - Reserved: allowCodeSnippets property reserved for future feature activation

    /// Topic allowlist — if non-nil, only these topics may be discussed
    // periphery:ignore - Reserved: allowHealthData property reserved for future feature activation
    var allowedTopics: Set<String>? { get }

    // periphery:ignore - Reserved: allowFinancialData property reserved for future feature activation
    /// Maximum outbound message length (0 = unlimited)
    var maxContentLength: Int { get }
}

// MARK: - Strictness Levels

enum StrictnessLevel: String, Codable, Sendable, Comparable {
    case permissive  // Minimal filtering — trusted channels
    case standard    // Balanced — redact obvious PII, allow context
    case strict      // Aggressive — no PII, limited context
    case paranoid    // Maximum — only approved topics, no personal data

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

// MARK: - Sanitization Result

enum SanitizationOutcome: Sendable {
    /// Content passed all checks unmodified
    case clean(String)

    /// Content was modified — redactions applied
    case redacted(String, redactions: [Redaction])

    /// Content was blocked entirely
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

// periphery:ignore - Reserved: isAllowed property reserved for future feature activation

// MARK: - Redaction Record

struct Redaction: Sendable {
    let type: RedactionType
    let originalLength: Int
    let replacement: String
    let reason: String
}

// periphery:ignore - Reserved: type property reserved for future feature activation
// periphery:ignore - Reserved: originalLength property reserved for future feature activation
// periphery:ignore - Reserved: replacement property reserved for future feature activation
// periphery:ignore - Reserved: reason property reserved for future feature activation
enum RedactionType: String, Codable, Sendable {
    case pii           // Personal identifiable information
    case apiKey         // API keys, tokens, secrets
    case filePath       // Local file system paths
    case credential     // Passwords, auth tokens
    case healthData     // Medical/health information
    case financialData  // Financial account info
    case codeSnippet    // Source code
    case blockedKeyword // Matched a blocked keyword
    case topicViolation // Outside allowed topics
    case lengthTruncation // Exceeded max length
}

// MARK: - Audit Entry

struct PrivacyAuditEntry: Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let channel: String
    let policyName: String
    let outcome: AuditOutcome
    // periphery:ignore - Reserved: policyName property reserved for future feature activation
    let redactionCount: Int
    let originalLength: Int
    // periphery:ignore - Reserved: originalLength property reserved for future feature activation
    // periphery:ignore - Reserved: sanitizedLength property reserved for future feature activation
    let sanitizedLength: Int

    enum AuditOutcome: String, Codable, Sendable {
        case passed
        case redacted
        case blocked
    }
}
