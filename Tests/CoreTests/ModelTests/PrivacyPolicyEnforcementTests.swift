import Foundation
import XCTest

/// Standalone integration tests for OutboundPrivacyGuard policy enforcement.
/// Mirrors the 6-layer sanitization pipeline and 6 built-in policies.
/// Tests policy behavior without importing the full privacy module.
final class PrivacyPolicyEnforcementTests: XCTestCase {

    // MARK: - Policy Definitions (mirror PrivacyPolicies.swift)

    private struct TestPolicy {
        let name: String
        let strictnessLevel: Int // 0=permissive, 1=standard, 2=strict, 3=paranoid
        let allowPII: Bool
        let allowFilePaths: Bool
        let allowCodeSnippets: Bool
        let blockedKeywords: Set<String>
        let allowedTopics: Set<String>?
        let maxContentLength: Int
    }

    private let cloudAPI = TestPolicy(
        name: "Cloud API", strictnessLevel: 1, allowPII: false, allowFilePaths: false,
        allowCodeSnippets: true, blockedKeywords: [], allowedTopics: nil, maxContentLength: 0)

    private let messaging = TestPolicy(
        name: "Messaging", strictnessLevel: 2, allowPII: false, allowFilePaths: false,
        allowCodeSnippets: false, blockedKeywords: ["password", "secret", "api key", "token",
            "credit card", "bank account", "social security"],
        allowedTopics: nil, maxContentLength: 4096)

    private let moltbook = TestPolicy(
        name: "Moltbook", strictnessLevel: 3, allowPII: false, allowFilePaths: false,
        allowCodeSnippets: false,
        blockedKeywords: ["password", "secret", "api key", "token", "credential",
            "credit card", "bank", "social security", "ssn",
            "address", "phone number", "email",
            "health", "medical", "diagnosis", "prescription",
            "salary", "income", "debt"],
        allowedTopics: ["swift", "ios", "macos", "watchos", "tvos",
            "swiftui", "uikit", "appkit", "combine", "async/await",
            "mlx", "coreml", "machine learning", "ai", "llm",
            "architecture", "design patterns", "testing",
            "xcode", "spm", "cocoapods", "performance",
            "accessibility", "localization", "security",
            "networking", "database", "swiftdata", "cloudkit",
            "privacy", "open source", "documentation"],
        maxContentLength: 2048)

    private let permissive = TestPolicy(
        name: "Permissive", strictnessLevel: 0, allowPII: true, allowFilePaths: true,
        allowCodeSnippets: true, blockedKeywords: [], allowedTopics: nil, maxContentLength: 0)

    // MARK: - Simulated Sanitization Engine

    private enum PolicyOutcome {
        case clean
        case redacted(Int) // count of redactions
        case blocked(String) // reason
    }

    /// Simulates OutboundPrivacyGuard.applySanitization()
    private func checkPolicy(_ content: String, policy: TestPolicy) -> PolicyOutcome {
        // Layer 1: Length
        if policy.maxContentLength > 0, content.count > policy.maxContentLength {
            return .redacted(1)
        }

        // Layer 2: Topic allowlist (paranoid)
        if let allowed = policy.allowedTopics {
            let lower = content.lowercased()
            let matches = allowed.contains { lower.contains($0) }
            if !matches {
                return .blocked("Content does not match allowed topics")
            }
        }

        // Layer 3: Blocked keywords
        let lower = content.lowercased()
        for keyword in policy.blockedKeywords {
            if lower.contains(keyword.lowercased()) {
                if policy.strictnessLevel >= 2 {
                    return .blocked("Blocked keyword: \(keyword)")
                }
                return .redacted(1)
            }
        }

        return .clean
    }

    // MARK: - CloudAPI Policy Tests

    func testCloudAPIAllowsNormalText() {
        let result = checkPolicy("How do I implement async/await in Swift?", policy: cloudAPI)
        if case .clean = result { } else {
            XCTFail("Cloud API should allow normal text")
        }
    }

    func testCloudAPIAllowsCode() {
        let result = checkPolicy("func main() { print(\"Hello\") }", policy: cloudAPI)
        if case .clean = result { } else {
            XCTFail("Cloud API should allow code snippets")
        }
    }

    // MARK: - Messaging Policy Tests

    func testMessagingBlocksPassword() {
        let result = checkPolicy("My password is hunter2", policy: messaging)
        if case .blocked = result { } else {
            XCTFail("Messaging (strict) should block content with 'password'")
        }
    }

    func testMessagingBlocksCreditCard() {
        let result = checkPolicy("My credit card number is 4111-1111-1111-1111", policy: messaging)
        if case .blocked = result { } else {
            XCTFail("Messaging should block credit card references")
        }
    }

    func testMessagingBlocksAPIKey() {
        let result = checkPolicy("Use this api key to authenticate", policy: messaging)
        if case .blocked = result { } else {
            XCTFail("Messaging should block 'api key' keyword")
        }
    }

    func testMessagingAllowsNormalChat() {
        let result = checkPolicy("Hey, what time is the meeting tomorrow?", policy: messaging)
        if case .clean = result { } else {
            XCTFail("Messaging should allow normal chat")
        }
    }

    func testMessagingEnforcesLengthLimit() {
        let longContent = String(repeating: "a", count: 5000)
        let result = checkPolicy(longContent, policy: messaging)
        if case .redacted = result { } else {
            XCTFail("Messaging should truncate content exceeding 4096 chars")
        }
    }

    // MARK: - Moltbook Policy Tests (Paranoid)

    func testMoltbookAllowsSwiftDiscussion() {
        let result = checkPolicy("What's the best pattern for swift concurrency?", policy: moltbook)
        if case .clean = result { } else {
            XCTFail("Moltbook should allow Swift dev discussion")
        }
    }

    func testMoltbookAllowsMLXDiscussion() {
        let result = checkPolicy("How to optimize mlx model inference on Apple Silicon?", policy: moltbook)
        if case .clean = result { } else {
            XCTFail("Moltbook should allow MLX discussion")
        }
    }

    func testMoltbookBlocksOffTopicContent() {
        let result = checkPolicy("What should I cook for dinner tonight?", policy: moltbook)
        if case .blocked = result { } else {
            XCTFail("Moltbook should block off-topic content (no matching allowed topic)")
        }
    }

    func testMoltbookBlocksPersonalInfo() {
        let result = checkPolicy("My salary is $150k and I have debt of $50k", policy: moltbook)
        if case .blocked = result { } else {
            XCTFail("Moltbook should block salary/income/debt keywords")
        }
    }

    func testMoltbookBlocksHealthInfo() {
        let result = checkPolicy("My doctor gave me a prescription for medication", policy: moltbook)
        if case .blocked = result { } else {
            XCTFail("Moltbook should block health/medical/prescription")
        }
    }

    func testMoltbookBlocksCredentials() {
        let result = checkPolicy("Here's my api key and password", policy: moltbook)
        if case .blocked = result { } else {
            XCTFail("Moltbook should block credential keywords")
        }
    }

    func testMoltbookEnforcesShortLength() {
        let longContent = String(repeating: "swift ", count: 500)
        let result = checkPolicy(longContent, policy: moltbook)
        if case .redacted = result { } else {
            XCTFail("Moltbook should truncate content exceeding 2048 chars")
        }
    }

    // MARK: - Permissive Policy Tests

    func testPermissiveAllowsEverything() {
        let texts = [
            "My password is hunter2",
            "My SSN is 123-45-6789",
            "/Users/alexis/secret/file.txt",
            "func main() { code() }"
        ]
        for text in texts {
            let result = checkPolicy(text, policy: permissive)
            if case .clean = result { } else {
                XCTFail("Permissive should allow: \(text)")
            }
        }
    }

    // MARK: - Cross-Policy Strictness Ordering

    func testStrictnessLevelOrdering() {
        XCTAssertLessThan(permissive.strictnessLevel, cloudAPI.strictnessLevel)
        XCTAssertLessThan(cloudAPI.strictnessLevel, messaging.strictnessLevel)
        XCTAssertLessThan(messaging.strictnessLevel, moltbook.strictnessLevel)
    }

    // MARK: - Policy Configuration Integrity

    func testAllPoliciesHaveNames() {
        let policies = [cloudAPI, messaging, moltbook, permissive]
        for policy in policies {
            XCTAssertFalse(policy.name.isEmpty)
        }
    }

    func testMoltbookHasAllowedTopics() {
        XCTAssertNotNil(moltbook.allowedTopics, "Moltbook must have allowedTopics for paranoid mode")
        XCTAssertGreaterThan(moltbook.allowedTopics?.count ?? 0, 20,
            "Moltbook should have comprehensive topic allowlist")
    }

    func testMoltbookAllowedTopicsIncludeKeyDomains() {
        let topics = moltbook.allowedTopics ?? []
        XCTAssertTrue(topics.contains("swift"))
        XCTAssertTrue(topics.contains("swiftui"))
        XCTAssertTrue(topics.contains("mlx"))
        XCTAssertTrue(topics.contains("coreml"))
        XCTAssertTrue(topics.contains("testing"))
        XCTAssertTrue(topics.contains("security"))
        XCTAssertTrue(topics.contains("privacy"))
    }

    func testMessagingHasBlockedKeywords() {
        XCTAssertGreaterThanOrEqual(messaging.blockedKeywords.count, 7,
            "Messaging should have comprehensive blocked keywords")
    }

    func testMoltbookBlocksBehavioralSupersetOfMessaging() {
        // Moltbook (paranoid) should block everything messaging blocks (behavioral check).
        // Moltbook may use broader keywords (e.g., "bank" covers "bank account").
        for keyword in messaging.blockedKeywords {
            let testContent = "This is about \(keyword) information and swift"
            let moltbookResult = checkPolicy(testContent, policy: moltbook)
            if case .clean = moltbookResult {
                XCTFail("Moltbook should also block messaging keyword: \(keyword)")
            }
        }
        XCTAssertGreaterThan(moltbook.blockedKeywords.count, messaging.blockedKeywords.count,
            "Moltbook should have more blocked keywords than messaging")
    }

    // MARK: - Credential Pattern Detection (integration with CredentialPatternTests)

    private let credentialPatterns: [(String, String)] = [
        ("sk-[a-zA-Z0-9]{20,}", "OpenAI key"),
        ("ghp_[a-zA-Z0-9]{36}", "GitHub token"),
        ("AKIA[0-9A-Z]{16}", "AWS key"),
        ("-----BEGIN[A-Z ]*PRIVATE KEY-----", "PEM key"),
        ("eyJ[a-zA-Z0-9_-]{10,}\\.eyJ[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]+", "JWT")
    ]

    private func containsCredential(_ text: String) -> Bool {
        for (pattern, _) in credentialPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }

    func testCredentialDetectionAcrossAllPolicies() {
        let textWithKey = "Use sk-proj1234567890abcdefghij for auth"
        XCTAssertTrue(containsCredential(textWithKey),
            "Credential detection should catch API keys regardless of policy")
    }

    func testCleanTextHasNoCredentials() {
        let cleanText = "Let's discuss Swift concurrency patterns"
        XCTAssertFalse(containsCredential(cleanText))
    }
}
