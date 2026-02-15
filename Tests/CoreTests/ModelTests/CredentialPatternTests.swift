import Foundation
import XCTest

/// Standalone tests for credential detection regex patterns.
/// These patterns mirror the ones in OutboundPrivacyGuard.redactCredentials()
/// and can be tested without importing the full privacy module.
final class CredentialPatternTests: XCTestCase {

    // MARK: - Pattern Definitions

    /// Credential patterns from OutboundPrivacyGuard
    private let credentialPatterns: [(pattern: String, name: String)] = [
        ("sk-[a-zA-Z0-9]{20,}", "API key (sk-)"),
        ("key-[a-zA-Z0-9]{20,}", "API key (key-)"),
        ("anthropic-[a-zA-Z0-9]{20,}", "Anthropic key"),
        ("AIza[a-zA-Z0-9_-]{35}", "Google API key"),
        ("ghp_[a-zA-Z0-9]{36}", "GitHub token"),
        ("gho_[a-zA-Z0-9]{36}", "GitHub OAuth token"),
        ("xoxb-[a-zA-Z0-9-]+", "Slack bot token"),
        ("xoxp-[a-zA-Z0-9-]+", "Slack user token"),
        ("Bearer [a-zA-Z0-9_\\-.~+/]+=*", "Bearer token"),
        ("AKIA[0-9A-Z]{16}", "AWS access key"),
        ("ssh-rsa\\s+[A-Za-z0-9+/=]{100,}", "SSH public key"),
        ("ssh-ed25519\\s+[A-Za-z0-9+/=]{40,}", "SSH ED25519 key"),
        ("-----BEGIN[A-Z ]*PRIVATE KEY-----", "PEM private key"),
        ("eyJ[a-zA-Z0-9_-]{10,}\\.eyJ[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]+", "JWT token"),
        ("AIzaSy[a-zA-Z0-9_-]{33}", "Firebase API key")
    ]

    // MARK: - Helper

    private func matches(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private func anyPatternMatches(_ text: String) -> [String] {
        credentialPatterns.filter { matches(text, pattern: $0.pattern) }.map(\.name)
    }

    // MARK: - API Key Detection

    func testDetectsOpenAIKey() {
        let text = "My key is sk-proj1234567890abcdefgh"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("API key (sk-)"), "Should detect sk- API key")
    }

    func testDetectsAnthropicKey() {
        let text = "Use anthropic-sk1234567890abcdefghij for API calls"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("Anthropic key"), "Should detect Anthropic key")
    }

    func testDetectsGoogleAPIKey() {
        let text = "API_KEY=AIzaAbcdefghijklmnopqrstuvwxyz1234567890a"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("Google API key"), "Should detect Google API key")
    }

    func testDetectsGitHubToken() {
        let text = "GITHUB_TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("GitHub token"), "Should detect GitHub token")
    }

    func testDetectsAWSKey() {
        let text = "AWS_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("AWS access key"), "Should detect AWS key")
    }

    func testDetectsSlackToken() {
        let text = "SLACK_TOKEN=xoxb-123456789012-123456789012-abcdef"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("Slack bot token"), "Should detect Slack bot token")
    }

    func testDetectsBearerToken() {
        let text = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.signature"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("Bearer token"), "Should detect Bearer token")
    }

    // MARK: - Key Format Detection

    func testDetectsSSHKey() {
        let longBase64 = String(repeating: "AAAA", count: 30)
        let text = "ssh-rsa \(longBase64) user@host"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("SSH public key"), "Should detect SSH RSA key")
    }

    func testDetectsPEMKey() {
        let text = "-----BEGIN RSA PRIVATE KEY-----"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("PEM private key"), "Should detect PEM key")
    }

    func testDetectsJWT() {
        // Minimal valid JWT structure
        let text = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("JWT token"), "Should detect JWT token")
    }

    func testDetectsFirebaseKey() {
        let text = "FIREBASE_KEY=AIzaSyFAKE_TEST_KEY_NOT_REAL_00000000000"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("Firebase API key"), "Should detect Firebase key")
    }

    // MARK: - False Positive Prevention

    func testIgnoresNormalText() {
        let text = "The sky is blue and the grass is green."
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.isEmpty, "Normal text should not trigger: \(matched)")
    }

    func testIgnoresCodeSnippets() {
        let text = "func hello() { print(\"world\") }"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.isEmpty, "Code should not trigger: \(matched)")
    }

    func testIgnoresShortKeys() {
        let text = "sk-short"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.isEmpty, "Short sk- prefix should not trigger")
    }

    func testIgnoresPartialAWS() {
        let text = "AKIA is an AWS prefix"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.isEmpty, "Partial AWS prefix should not trigger")
    }

    // MARK: - Edge Cases

    func testDetectsKeyInMiddleOfText() {
        let text = "Please use this key: sk-12345678901234567890abcd for authentication"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("API key (sk-)"), "Should detect key embedded in text")
    }

    func testDetectsMultipleKeys() {
        let text = """
        OPENAI_KEY=sk-12345678901234567890abcd
        GITHUB_TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij
        AWS_KEY=AKIAIOSFODNN7EXAMPLE
        """
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.count >= 3, "Should detect all keys, found: \(matched)")
    }

    func testHandlesEmptyString() {
        let matched = anyPatternMatches("")
        XCTAssertTrue(matched.isEmpty)
    }

    func testHandlesUnicodeAroundKey() {
        let text = "🔑 sk-12345678901234567890abcd 🔑"
        let matched = anyPatternMatches(text)
        XCTAssertTrue(matched.contains("API key (sk-)"), "Should detect key with surrounding emoji")
    }

    // MARK: - Pattern Compilation

    func testAllPatternsCompile() {
        for (pattern, name) in credentialPatterns {
            let regex = try? NSRegularExpression(pattern: pattern)
            XCTAssertNotNil(regex, "Pattern '\(name)' (\(pattern)) should compile")
        }
    }
}
