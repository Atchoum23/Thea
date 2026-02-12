// OutboundPrivacyGuard.swift
// Thea — System-Wide Outbound Privacy Layer
//
// Every piece of data leaving the device passes through this guard.
// Delegates PII detection to PIISanitizer, adds credential/secret/topic checks.
// Maintains a full audit log of all redactions and blocks.

import Foundation
import OSLog

// MARK: - Outbound Privacy Guard

actor OutboundPrivacyGuard {
    static let shared = OutboundPrivacyGuard()

    private let logger = Logger(subsystem: "com.thea.app", category: "OutboundPrivacyGuard")

    // MARK: - Configuration

    /// Whether the guard is active (kill switch)
    var isEnabled = true

    /// Default policies per channel type
    private var channelPolicies: [String: any PrivacyPolicy] = [
        "cloud_api": CloudAPIPolicy(),
        "messaging": MessagingPolicy(),
        "mcp": MCPPolicy(),
        "web_api": WebAPIPolicy(),
        "moltbook": MoltbookPolicy()
    ]

    /// Audit log (recent entries, capped)
    private var auditLog: [PrivacyAuditEntry] = []
    private let maxAuditEntries = 5000

    private init() {}

    // MARK: - Public API

    /// Sanitize content for a given channel.
    /// Returns `.clean`, `.redacted`, or `.blocked`.
    func sanitize(_ content: String, channel: String) async -> SanitizationOutcome {
        guard isEnabled else {
            return .clean(content)
        }

        let policy = channelPolicies[channel] ?? CloudAPIPolicy()
        let outcome = await applySanitization(content: content, policy: policy)

        // Audit
        let entry = PrivacyAuditEntry(
            id: UUID(),
            timestamp: Date(),
            channel: channel,
            policyName: policy.name,
            outcome: {
                switch outcome {
                case .clean: .passed
                case .redacted: .redacted
                case .blocked: .blocked
                }
            }(),
            redactionCount: {
                if case let .redacted(_, redactions) = outcome { return redactions.count }
                return 0
            }(),
            originalLength: content.count,
            sanitizedLength: outcome.content?.count ?? 0
        )
        appendAuditEntry(entry)

        return outcome
    }

    /// Sanitize an array of AI messages for a given channel.
    func sanitizeMessages(_ messages: [AIMessage], channel: String) async -> [AIMessage] {
        guard isEnabled else { return messages }

        var sanitized: [AIMessage] = []
        for message in messages {
            let text = message.content.textValue
            let outcome = await sanitize(text, channel: channel)
            switch outcome {
            case let .clean(cleanText):
                sanitized.append(message.withContent(.text(cleanText)))
            case let .redacted(redactedText, _):
                sanitized.append(message.withContent(.text(redactedText)))
            case .blocked:
                // Skip blocked messages entirely
                logger.warning("Blocked message for channel \(channel): \(message.id)")
            }
        }
        return sanitized
    }

    // MARK: - Policy Management

    func setPolicy(_ policy: any PrivacyPolicy, for channel: String) {
        channelPolicies[channel] = policy
    }

    func getPolicy(for channel: String) -> (any PrivacyPolicy)? {
        channelPolicies[channel]
    }

    // MARK: - Audit

    func getAuditLog(limit: Int = 100) -> [PrivacyAuditEntry] {
        Array(auditLog.suffix(limit))
    }

    func clearAuditLog() {
        auditLog.removeAll()
    }

    func getPrivacyAuditStatistics() -> PrivacyAuditStatistics {
        let total = auditLog.count
        let passed = auditLog.filter { $0.outcome == .passed }.count
        let redacted = auditLog.filter { $0.outcome == .redacted }.count
        let blocked = auditLog.filter { $0.outcome == .blocked }.count
        let totalRedactions = auditLog.reduce(0) { $0 + $1.redactionCount }

        return PrivacyAuditStatistics(
            totalChecks: total,
            passed: passed,
            redacted: redacted,
            blocked: blocked,
            totalRedactions: totalRedactions
        )
    }

    // MARK: - Core Sanitization Engine

    private func applySanitization(content: String, policy: any PrivacyPolicy) async -> SanitizationOutcome {
        var text = content
        var redactions: [Redaction] = []

        // Layer 1: Length enforcement
        if policy.maxContentLength > 0, text.count > policy.maxContentLength {
            let truncated = String(text.prefix(policy.maxContentLength))
            redactions.append(Redaction(
                type: .lengthTruncation,
                originalLength: text.count,
                replacement: "[truncated]",
                reason: "Exceeded max length \(policy.maxContentLength)"
            ))
            text = truncated
        }

        // Layer 2: Topic allowlist (paranoid mode)
        if let allowedTopics = policy.allowedTopics {
            let lower = text.lowercased()
            let matchesAnyTopic = allowedTopics.contains { lower.contains($0) }
            if !matchesAnyTopic {
                return .blocked(reason: "Content does not match allowed topics for \(policy.name)")
            }
        }

        // Layer 3: Blocked keywords
        let lower = text.lowercased()
        for keyword in policy.blockedKeywords {
            if lower.contains(keyword.lowercased()) {
                if policy.strictnessLevel >= .strict {
                    return .blocked(reason: "Blocked keyword detected: \(keyword)")
                }
                // At standard level, redact instead of blocking
                text = text.replacingOccurrences(
                    of: keyword,
                    with: "[REDACTED]",
                    options: .caseInsensitive
                )
                redactions.append(Redaction(
                    type: .blockedKeyword,
                    originalLength: keyword.count,
                    replacement: "[REDACTED]",
                    reason: "Blocked keyword: \(keyword)"
                ))
            }
        }

        // Layer 4: API key / credential detection
        let credentialResult = redactCredentials(in: text)
        if credentialResult.modified {
            text = credentialResult.text
            redactions.append(contentsOf: credentialResult.redactions)
        }

        // Layer 5: PII detection (delegates to PIISanitizer)
        if !policy.allowPII {
            let piiResult = await redactPII(in: text)
            if piiResult.modified {
                text = piiResult.text
                redactions.append(contentsOf: piiResult.redactions)
            }
        }

        // Layer 6: File path detection
        if !policy.allowFilePaths {
            let pathResult = redactFilePaths(in: text)
            if pathResult.modified {
                text = pathResult.text
                redactions.append(contentsOf: pathResult.redactions)
            }
        }

        if redactions.isEmpty {
            return .clean(text)
        } else {
            return .redacted(text, redactions: redactions)
        }
    }

    // MARK: - Detection Layers

    private struct LayerResult {
        let text: String
        let redactions: [Redaction]
        var modified: Bool { !redactions.isEmpty }
    }

    /// Detect and redact API keys, tokens, and secrets
    private func redactCredentials(in text: String) -> LayerResult {
        var result = text
        var redactions: [Redaction] = []

        let patterns: [(String, String)] = [
            // API keys
            ("sk-[a-zA-Z0-9]{20,}", "API key (sk-)"),
            ("key-[a-zA-Z0-9]{20,}", "API key (key-)"),
            ("anthropic-[a-zA-Z0-9]{20,}", "Anthropic key"),
            ("AIza[a-zA-Z0-9_-]{35}", "Google API key"),
            ("ghp_[a-zA-Z0-9]{36}", "GitHub token"),
            ("gho_[a-zA-Z0-9]{36}", "GitHub OAuth token"),
            ("xoxb-[a-zA-Z0-9-]+", "Slack bot token"),
            ("xoxp-[a-zA-Z0-9-]+", "Slack user token"),
            // Bearer tokens
            ("Bearer [a-zA-Z0-9_\\-.~+/]+=*", "Bearer token"),
            // Base64 secrets (long base64 strings that look like keys)
            ("(?<![a-zA-Z0-9/+])[A-Za-z0-9+/]{40,}={0,2}(?![a-zA-Z0-9/+=])", "Base64 secret"),
            // AWS keys
            ("AKIA[0-9A-Z]{16}", "AWS access key"),
            // Generic secret patterns
            ("(?i)(?:secret|password|passwd|pwd)\\s*[:=]\\s*[\"']?[^\\s\"']{8,}", "Secret value")
        ]

        for (pattern, description) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = regex.matches(in: result, range: range)

            // Process in reverse to maintain range validity
            for match in matches.reversed() {
                guard let swiftRange = Range(match.range, in: result) else { continue }
                let original = String(result[swiftRange])
                let replacement = "[REDACTED_CREDENTIAL]"
                result.replaceSubrange(swiftRange, with: replacement)
                redactions.append(Redaction(
                    type: .credential,
                    originalLength: original.count,
                    replacement: replacement,
                    reason: description
                ))
            }
        }

        return LayerResult(text: result, redactions: redactions)
    }

    /// Delegate PII detection to PIISanitizer
    @MainActor
    private func redactPII(in text: String) -> LayerResult {
        let sanitizer = PIISanitizer.shared
        let piiResult = sanitizer.sanitize(text)

        guard piiResult.wasModified else {
            return LayerResult(text: text, redactions: [])
        }

        let redactions = piiResult.detections.map { detection in
            Redaction(
                type: .pii,
                originalLength: detection.originalLength,
                replacement: "[PII_REDACTED]",
                reason: "PII detected: \(detection.type.rawValue)"
            )
        }

        return LayerResult(text: piiResult.sanitizedText, redactions: redactions)
    }

    /// Detect and redact local file system paths
    private func redactFilePaths(in text: String) -> LayerResult {
        var result = text
        var redactions: [Redaction] = []

        let patterns: [String] = [
            // macOS/Unix absolute paths
            "/Users/[a-zA-Z0-9._-]+/[^\\s\"'\\])}]+",
            // Home directory references
            "~/[^\\s\"'\\])}]+",
            // Common macOS paths
            "/Applications/[^\\s\"'\\])}]+",
            "/Library/[^\\s\"'\\])}]+",
            "/private/[^\\s\"'\\])}]+"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = regex.matches(in: result, range: range)

            for match in matches.reversed() {
                guard let swiftRange = Range(match.range, in: result) else { continue }
                let original = String(result[swiftRange])
                let replacement = "[PATH_REDACTED]"
                result.replaceSubrange(swiftRange, with: replacement)
                redactions.append(Redaction(
                    type: .filePath,
                    originalLength: original.count,
                    replacement: replacement,
                    reason: "Local file path"
                ))
            }
        }

        return LayerResult(text: result, redactions: redactions)
    }

    // MARK: - Audit Log Management

    private func appendAuditEntry(_ entry: PrivacyAuditEntry) {
        auditLog.append(entry)
        if auditLog.count > maxAuditEntries {
            auditLog.removeFirst(auditLog.count - maxAuditEntries)
        }
    }
}

// MARK: - Audit Statistics

struct PrivacyAuditStatistics: Sendable {
    let totalChecks: Int
    let passed: Int
    let redacted: Int
    let blocked: Int
    let totalRedactions: Int
}

// MARK: - AIMessage Extension

extension AIMessage {
    /// Create a copy of this message with different content
    func withContent(_ newContent: MessageContent) -> AIMessage {
        AIMessage(
            id: id,
            conversationID: conversationID,
            role: role,
            content: newContent,
            timestamp: timestamp,
            model: model,
            tokenCount: tokenCount,
            metadata: metadata
        )
    }
}
