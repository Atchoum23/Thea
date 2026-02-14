// OutboundPrivacyGuard.swift
// Thea — System-Wide Outbound Privacy Firewall
//
// Every piece of data leaving the device passes through this guard.
// Default-deny in strict mode: only registered channels can transmit data.
// Delegates PII detection to PIISanitizer, adds credential/secret/topic checks.
// Maintains a full audit log of all redactions and blocks.

import Foundation
import OSLog

// MARK: - Firewall Mode

/// Controls how unregistered channels are handled
enum FirewallMode: String, Codable, Sendable {
    case strict     // Default-deny: only registered+allowed channels pass
    case standard   // Sanitize known channels, pass unknown with default policy
    case permissive // Log only, never block (debugging)
}

/// Categories of outbound data for fine-grained channel permissions
enum OutboundDataType: String, CaseIterable, Sendable, Codable {
    case text
    case structuredData   // JSON, plist
    case credentials      // API keys, tokens, passwords
    case personalInfo     // PII: name, email, phone, address
    case healthData       // HealthKit data
    case financialData    // Bank, tax, investment data
    case locationData     // GPS coordinates, addresses
    case deviceInfo       // Hardware IDs, OS version
    case codeContent      // Source code, configs
}

/// Registration for a specific outbound channel
struct ChannelRegistration: Sendable {
    let channelId: String
    let description: String
    let policy: any PrivacyPolicy
    let allowedDataTypes: Set<OutboundDataType>
    let registeredAt: Date
    let registeredBy: String
}

/// Finding from a security scan (used by pre-commit hook integration)
struct SecurityFinding: Sendable {
    enum Severity: String, Sendable { case critical, warning, info }
    let severity: Severity
    let file: String
    let description: String
    let recommendation: String
}

// MARK: - Outbound Privacy Guard

actor OutboundPrivacyGuard {
    static let shared = OutboundPrivacyGuard()

    private let logger = Logger(subsystem: "com.thea.app", category: "OutboundPrivacyGuard")

    // MARK: - Configuration

    /// Whether the guard is active (kill switch)
    var isEnabled = true

    /// Firewall operating mode (default: strict = default-deny)
    var mode: FirewallMode = .strict

    /// Registered outbound channels with allowed data types
    private var registeredChannels: [String: ChannelRegistration] = [:]

    /// Legacy fallback policies for standard mode
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

    private init() {
        // Register default channels inline (cannot call actor-isolated methods from init)
        let defaults: [(String, String, any PrivacyPolicy, Set<OutboundDataType>)] = [
            ("cloud_api", "AI model API calls", CloudAPIPolicy(), [.text, .codeContent, .structuredData]),
            ("messaging", "Messaging services", MessagingPolicy(), [.text]),
            ("mcp", "MCP tool calls", MCPPolicy(), [.text, .structuredData, .codeContent]),
            ("web_api", "Web API calls", WebAPIPolicy(), [.text, .structuredData]),
            ("moltbook", "Moltbook discussions", MoltbookPolicy(), [.text]),
            ("cloudkit_sync", "iCloud sync", CloudAPIPolicy(), [.text, .structuredData, .deviceInfo]),
            ("health_ai", "Health data to AI", CloudAPIPolicy(), [.text, .healthData])
        ]
        for (id, desc, policy, types) in defaults {
            registeredChannels[id] = ChannelRegistration(
                channelId: id, description: desc, policy: policy,
                allowedDataTypes: types, registeredAt: Date(), registeredBy: "OutboundPrivacyGuard"
            )
        }
    }

    // MARK: - Channel Registration

    /// Register a channel for outbound communication
    func registerChannel(
        id: String,
        description: String,
        policy: any PrivacyPolicy,
        allowedDataTypes: Set<OutboundDataType>,
        registeredBy: String
    ) {
        registeredChannels[id] = ChannelRegistration(
            channelId: id,
            description: description,
            policy: policy,
            allowedDataTypes: allowedDataTypes,
            registeredAt: Date(),
            registeredBy: registeredBy
        )
    }

    /// Get all registered channel IDs
    func registeredChannelIds() -> [String] {
        Array(registeredChannels.keys.sorted())
    }

    // MARK: - Public API

    /// Sanitize content for a given channel.
    /// In strict mode, unregistered channels are blocked.
    func sanitize(_ content: String, channel: String) async -> SanitizationOutcome {
        guard isEnabled else {
            return .clean(content)
        }

        // In strict mode, channel must be registered
        let registration = registeredChannels[channel]
        if mode == .strict && registration == nil {
            let entry = PrivacyAuditEntry(
                id: UUID(), timestamp: Date(), channel: channel, policyName: "FIREWALL",
                outcome: .blocked, redactionCount: 0,
                originalLength: content.count, sanitizedLength: 0
            )
            appendAuditEntry(entry)
            return .blocked(reason: "Channel '\(channel)' is not registered (strict firewall mode)")
        }

        // Check content against allowed data types (strict mode)
        if mode == .strict, let reg = registration {
            let detectedTypes = classifyContent(content)
            let disallowed = detectedTypes.subtracting(reg.allowedDataTypes)
            if !disallowed.isEmpty {
                let entry = PrivacyAuditEntry(
                    id: UUID(), timestamp: Date(), channel: channel, policyName: reg.policy.name,
                    outcome: .blocked, redactionCount: 0,
                    originalLength: content.count, sanitizedLength: 0
                )
                appendAuditEntry(entry)
                return .blocked(reason: "Disallowed data types for \(channel): \(disallowed.map(\.rawValue).joined(separator: ", "))")
            }
        }

        let policy = registration?.policy ?? channelPolicies[channel] ?? CloudAPIPolicy()
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
            // SSH keys
            ("ssh-rsa\\s+[A-Za-z0-9+/=]{100,}", "SSH public key"),
            ("ssh-ed25519\\s+[A-Za-z0-9+/=]{40,}", "SSH ED25519 key"),
            // PEM private keys
            ("-----BEGIN[A-Z ]*PRIVATE KEY-----", "PEM private key"),
            // JWT tokens
            ("eyJ[a-zA-Z0-9_-]{10,}\\.eyJ[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]+", "JWT token"),
            // Firebase keys
            ("AIzaSy[a-zA-Z0-9_-]{33}", "Firebase API key"),
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

    // MARK: - Content Classification

    /// Classify content to determine what data types it contains
    func classifyContent(_ content: String) -> Set<OutboundDataType> {
        var types: Set<OutboundDataType> = [.text]

        // Credentials
        let credentialPatterns = [
            "sk-[a-zA-Z0-9]{20,}", "ghp_[a-zA-Z0-9]{36}", "AKIA[0-9A-Z]{16}",
            "-----BEGIN[A-Z ]*PRIVATE KEY-----",
            "(?i)(api[_-]?key|token|secret|password|bearer)\\s*[:=]\\s*['\"]?[A-Za-z0-9+/=_-]{16,}"
        ]
        if matchesAny(content, patterns: credentialPatterns) { types.insert(.credentials) }

        // Health data
        let healthPatterns = ["(?i)(blood.?pressure|heart.?rate|bpm|glucose|cholesterol|bmi|steps|sleep.?duration|health.?kit|HKQuantity)"]
        if matchesAny(content, patterns: healthPatterns) { types.insert(.healthData) }

        // Financial data
        let financePatterns = ["(?i)(iban|swift|bic|account.?number|routing|tax.?id|ssn|social.?security|credit.?card|\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b)"]
        if matchesAny(content, patterns: financePatterns) { types.insert(.financialData) }

        // Location data
        let locationPatterns = ["(?i)(latitude|longitude|gps|geoloc)"]
        if matchesAny(content, patterns: locationPatterns) { types.insert(.locationData) }

        // Device info
        let devicePatterns = ["(?i)(serial.?number|udid|device.?id|mac.?address|[0-9a-f]{2}(:[0-9a-f]{2}){5})"]
        if matchesAny(content, patterns: devicePatterns) { types.insert(.deviceInfo) }

        // Code content
        let codePatterns = ["(?m)^(func |class |struct |import |let |var |if |for |while |switch |protocol |extension )"]
        if matchesAny(content, patterns: codePatterns) { types.insert(.codeContent) }

        // Structured data
        if content.contains("{") && content.contains("}") && content.contains("\"") {
            types.insert(.structuredData)
        }

        return types
    }

    private func matchesAny(_ text: String, patterns: [String]) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            if regex.firstMatch(in: text, range: range) != nil { return true }
        }
        return false
    }

    // MARK: - Pre-Commit Scan

    /// Scan content for credentials/secrets (used by git pre-commit hook integration)
    func preCommitScan(_ content: String, filename: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        let types = classifyContent(content)

        if types.contains(.credentials) {
            findings.append(SecurityFinding(
                severity: .critical, file: filename,
                description: "Potential credentials detected",
                recommendation: "Move to Keychain or .env file"
            ))
        }
        if types.contains(.personalInfo) {
            findings.append(SecurityFinding(
                severity: .warning, file: filename,
                description: "PII detected",
                recommendation: "Ensure this is test data, not real personal information"
            ))
        }
        return findings
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
