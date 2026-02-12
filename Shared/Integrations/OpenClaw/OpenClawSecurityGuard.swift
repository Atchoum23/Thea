import Foundation
import OSLog

// MARK: - OpenClaw Security Guard
// Protects Thea from prompt injection and malicious content via messaging bridges
// All inbound messages pass through here before reaching AI

actor OpenClawSecurityGuard {
    static let shared = OpenClawSecurityGuard()

    private let logger = Logger(subsystem: "com.thea.app", category: "OpenClawSecurity")

    // MARK: - Configuration

    /// Maximum message length (truncate beyond this)
    var maxMessageLength = 4096

    /// Whether to enable prompt injection detection
    var detectPromptInjection = true

    /// Contact allowlist (empty = allow all)
    var allowedContacts: Set<String> = []

    /// Blocked keywords (messages containing these are rejected)
    var blockedKeywords: Set<String> = [
        "ignore previous instructions",
        "ignore all instructions",
        "disregard your system prompt",
        "you are now",
        "act as",
        "pretend you are",
        "new instructions:",
        "override:"
    ]

    private init() {}

    // MARK: - Validation

    /// Validate and sanitize an incoming message
    func validate(_ message: OpenClawMessage) -> SecurityResult {
        // Check contact allowlist
        if !allowedContacts.isEmpty, !allowedContacts.contains(message.senderID) {
            return .blocked(reason: "Sender not in allowlist")
        }

        // Check message length
        if message.content.count > maxMessageLength {
            let truncated = String(message.content.prefix(maxMessageLength))
            return .sanitized(content: truncated, warnings: ["Message truncated to \(maxMessageLength) chars"])
        }

        // Check for prompt injection patterns
        if detectPromptInjection {
            let injectionResult = checkPromptInjection(message.content)
            if injectionResult.detected {
                logger.warning("Prompt injection detected from \(message.senderID): \(injectionResult.pattern ?? "unknown")")
                return .blocked(reason: "Potential prompt injection detected")
            }
        }

        // Check blocked keywords
        let lower = message.content.lowercased()
        for keyword in blockedKeywords {
            if lower.contains(keyword) {
                return .blocked(reason: "Blocked keyword: \(keyword)")
            }
        }

        return .clean
    }

    // MARK: - Prompt Injection Detection

    private func checkPromptInjection(_ content: String) -> InjectionCheckResult {
        let lower = content.lowercased()

        let patterns: [(String, String)] = [
            // Role injection
            ("\\bsystem\\s*:", "system role injection"),
            ("\\[\\s*system\\s*\\]", "bracketed system injection"),
            ("```\\s*system", "code block system injection"),
            ("\\bhuman\\s*:", "role confusion"),
            ("\\bassistant\\s*:", "role confusion"),
            ("\\buser\\s*:", "role confusion"),
            // Chat template injection
            ("<\\|im_start\\|>", "chat template injection"),
            ("<\\|im_end\\|>", "chat template injection"),
            ("<\\|system\\|>", "chat template injection"),
            ("<\\|assistant\\|>", "chat template injection"),
            // Template injection
            ("\\{\\{.*system.*\\}\\}", "template injection"),
            ("\\{%.*system.*%\\}", "Jinja template injection"),
            // Instruction override
            ("\\bsystem\\s+prompt", "system prompt reference"),
            ("\\bsystem\\s+instructions", "system instructions reference"),
            ("\\bsystem\\s+message", "system message reference"),
            // XML injection
            ("<system>", "XML system tag injection"),
            ("</system>", "XML system tag injection"),
            ("<instructions>", "XML instructions tag injection"),
            // Separator injection
            ("---+\\s*system", "separator-based injection"),
            ("={3,}", "separator-based injection")
        ]

        for (pattern, description) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
                if regex.firstMatch(in: lower, range: range) != nil {
                    return InjectionCheckResult(detected: true, pattern: description)
                }
            }
        }

        return InjectionCheckResult(detected: false, pattern: nil)
    }
}

// MARK: - Types

enum SecurityResult: Sendable {
    case clean
    case sanitized(content: String, warnings: [String])
    case blocked(reason: String)

    var isAllowed: Bool {
        switch self {
        case .clean, .sanitized: true
        case .blocked: false
        }
    }
}

struct InjectionCheckResult: Sendable {
    let detected: Bool
    let pattern: String?
}
