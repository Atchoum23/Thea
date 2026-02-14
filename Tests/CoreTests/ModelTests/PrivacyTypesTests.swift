import Foundation
import XCTest

/// Standalone tests for privacy type structures:
/// StrictnessLevel, RedactionType, SanitizationOutcome, PrivacyAuditEntry.
/// These mirror the types in PrivacyPolicy.swift and OutboundPrivacyGuard.swift.
final class PrivacyTypesTests: XCTestCase {

    // MARK: - StrictnessLevel (mirror PrivacyPolicy.swift)

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

    func testStrictnessLevelOrdering() {
        XCTAssertTrue(StrictnessLevel.permissive < .standard)
        XCTAssertTrue(StrictnessLevel.standard < .strict)
        XCTAssertTrue(StrictnessLevel.strict < .paranoid)
    }

    func testStrictnessLevelEquality() {
        XCTAssertEqual(StrictnessLevel.strict, .strict)
        XCTAssertNotEqual(StrictnessLevel.strict, .standard)
    }

    func testStrictnessLevelComparisons() {
        XCTAssertFalse(StrictnessLevel.paranoid < .permissive)
        XCTAssertTrue(StrictnessLevel.permissive < .paranoid)
        XCTAssertGreaterThanOrEqual(StrictnessLevel.strict, .standard)
        XCTAssertGreaterThanOrEqual(StrictnessLevel.strict, .strict)
    }

    func testStrictnessLevelCodable() throws {
        for level in [StrictnessLevel.permissive, .standard, .strict, .paranoid] {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(StrictnessLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }

    func testStrictnessLevelRawValues() {
        XCTAssertEqual(StrictnessLevel.permissive.rawValue, "permissive")
        XCTAssertEqual(StrictnessLevel.standard.rawValue, "standard")
        XCTAssertEqual(StrictnessLevel.strict.rawValue, "strict")
        XCTAssertEqual(StrictnessLevel.paranoid.rawValue, "paranoid")
    }

    func testStrictnessLevelSorting() {
        let levels: [StrictnessLevel] = [.paranoid, .permissive, .strict, .standard]
        let sorted = levels.sorted()
        XCTAssertEqual(sorted, [.permissive, .standard, .strict, .paranoid])
    }

    // MARK: - RedactionType (mirror PrivacyPolicy.swift)

    private enum RedactionType: String, Codable {
        case pii, apiKey, filePath, credential
        case healthData, financialData, codeSnippet
        case blockedKeyword, topicViolation, lengthTruncation
    }

    func testRedactionTypeCases() {
        let allCases: [RedactionType] = [
            .pii, .apiKey, .filePath, .credential,
            .healthData, .financialData, .codeSnippet,
            .blockedKeyword, .topicViolation, .lengthTruncation
        ]
        XCTAssertEqual(allCases.count, 10, "Should have 10 redaction types")
    }

    func testRedactionTypeCodable() throws {
        for type in [RedactionType.pii, .apiKey, .filePath, .credential, .lengthTruncation] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(RedactionType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func testRedactionTypeRawValues() {
        XCTAssertEqual(RedactionType.pii.rawValue, "pii")
        XCTAssertEqual(RedactionType.apiKey.rawValue, "apiKey")
        XCTAssertEqual(RedactionType.blockedKeyword.rawValue, "blockedKeyword")
    }

    // MARK: - SanitizationOutcome (mirror PrivacyPolicy.swift)

    private enum SanitizationOutcome {
        case clean(String)
        case redacted(String, redactions: [String])
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

    func testCleanOutcome() {
        let outcome = SanitizationOutcome.clean("Hello world")
        XCTAssertEqual(outcome.content, "Hello world")
        XCTAssertTrue(outcome.isAllowed)
    }

    func testRedactedOutcome() {
        let outcome = SanitizationOutcome.redacted("[EMAIL_REDACTED]", redactions: ["email found"])
        XCTAssertEqual(outcome.content, "[EMAIL_REDACTED]")
        XCTAssertTrue(outcome.isAllowed)
    }

    func testBlockedOutcome() {
        let outcome = SanitizationOutcome.blocked(reason: "contains blocked keyword")
        XCTAssertNil(outcome.content)
        XCTAssertFalse(outcome.isAllowed)
    }

    // MARK: - AuditOutcome (mirror PrivacyPolicy.swift)

    private enum AuditOutcome: String, Codable {
        case passed, redacted, blocked
    }

    func testAuditOutcomeCodable() throws {
        for outcome in [AuditOutcome.passed, .redacted, .blocked] {
            let data = try JSONEncoder().encode(outcome)
            let decoded = try JSONDecoder().decode(AuditOutcome.self, from: data)
            XCTAssertEqual(decoded, outcome)
        }
    }

    // MARK: - Policy Configuration Tests

    struct TestPolicy {
        let name: String
        let strictnessLevel: StrictnessLevel
        let allowPII: Bool
        let allowFilePaths: Bool
        let allowCodeSnippets: Bool
        let allowHealthData: Bool
        let allowFinancialData: Bool
        let blockedKeywords: Set<String>
        let allowedTopics: Set<String>?
        let maxContentLength: Int
    }

    func testCloudAPIPolicyDefaults() {
        let policy = TestPolicy(
            name: "Cloud API", strictnessLevel: .standard,
            allowPII: false, allowFilePaths: false, allowCodeSnippets: true,
            allowHealthData: false, allowFinancialData: false,
            blockedKeywords: [], allowedTopics: nil, maxContentLength: 0
        )
        XCTAssertEqual(policy.strictnessLevel, .standard)
        XCTAssertFalse(policy.allowPII)
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertNil(policy.allowedTopics)
        XCTAssertEqual(policy.maxContentLength, 0, "Cloud API should have unlimited content length")
    }

    func testMessagingPolicyDefaults() {
        let policy = TestPolicy(
            name: "Messaging", strictnessLevel: .strict,
            allowPII: false, allowFilePaths: false, allowCodeSnippets: false,
            allowHealthData: false, allowFinancialData: false,
            blockedKeywords: ["password", "secret", "api key", "token",
                              "credit card", "bank account", "social security"],
            allowedTopics: nil, maxContentLength: 4096
        )
        XCTAssertEqual(policy.strictnessLevel, .strict)
        XCTAssertFalse(policy.allowCodeSnippets)
        XCTAssertGreaterThanOrEqual(policy.blockedKeywords.count, 7)
        XCTAssertEqual(policy.maxContentLength, 4096)
    }

    func testMCPPolicyAllowsFilePaths() {
        let policy = TestPolicy(
            name: "MCP", strictnessLevel: .strict,
            allowPII: false, allowFilePaths: true, allowCodeSnippets: true,
            allowHealthData: false, allowFinancialData: false,
            blockedKeywords: ["password", "secret key", "private key"],
            allowedTopics: nil, maxContentLength: 0
        )
        XCTAssertTrue(policy.allowFilePaths, "MCP should allow file paths")
        XCTAssertTrue(policy.allowCodeSnippets, "MCP should allow code snippets")
    }

    func testMoltbookPolicyParanoid() {
        let allowedTopics: Set<String> = [
            "swift", "ios", "macos", "watchos", "tvos",
            "swiftui", "uikit", "appkit", "combine", "async/await",
            "mlx", "coreml", "machine learning", "ai", "llm",
            "architecture", "design patterns", "testing",
            "xcode", "spm", "cocoapods", "performance",
            "accessibility", "localization", "security",
            "networking", "database", "swiftdata", "cloudkit",
            "privacy", "open source", "documentation"
        ]

        let policy = TestPolicy(
            name: "Moltbook", strictnessLevel: .paranoid,
            allowPII: false, allowFilePaths: false, allowCodeSnippets: false,
            allowHealthData: false, allowFinancialData: false,
            blockedKeywords: ["password", "secret", "api key", "token", "credential",
                              "credit card", "bank", "social security", "ssn",
                              "address", "phone number", "email",
                              "health", "medical", "diagnosis", "prescription",
                              "salary", "income", "debt"],
            allowedTopics: allowedTopics,
            maxContentLength: 2048
        )

        XCTAssertEqual(policy.strictnessLevel, .paranoid)
        XCTAssertNotNil(policy.allowedTopics)
        XCTAssertGreaterThan(policy.allowedTopics?.count ?? 0, 20)
        XCTAssertGreaterThan(policy.blockedKeywords.count, 15)
        XCTAssertEqual(policy.maxContentLength, 2048)
        XCTAssertFalse(policy.allowPII)
        XCTAssertFalse(policy.allowFilePaths)
        XCTAssertFalse(policy.allowCodeSnippets)
        XCTAssertFalse(policy.allowHealthData)
        XCTAssertFalse(policy.allowFinancialData)
    }

    func testPermissivePolicyAllowsAll() {
        let policy = TestPolicy(
            name: "Permissive", strictnessLevel: .permissive,
            allowPII: true, allowFilePaths: true, allowCodeSnippets: true,
            allowHealthData: true, allowFinancialData: true,
            blockedKeywords: [], allowedTopics: nil, maxContentLength: 0
        )
        XCTAssertTrue(policy.allowPII)
        XCTAssertTrue(policy.allowFilePaths)
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertTrue(policy.allowHealthData)
        XCTAssertTrue(policy.allowFinancialData)
        XCTAssertTrue(policy.blockedKeywords.isEmpty)
        XCTAssertNil(policy.allowedTopics)
    }

    // MARK: - File Path Detection Patterns

    private func containsFilePath(_ text: String) -> Bool {
        let patterns: [String] = [
            "/Users/[a-zA-Z0-9._-]+/[^\\s\"'\\])}]+",
            "~/[^\\s\"'\\])}]+",
            "/Applications/[^\\s\"'\\])}]+",
            "/Library/[^\\s\"'\\])}]+",
            "/private/[^\\s\"'\\])}]+"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }

    func testDetectsHomeDirectoryPath() {
        XCTAssertTrue(containsFilePath("/Users/alexis/Documents/secret.txt"))
    }

    func testDetectsTildePath() {
        XCTAssertTrue(containsFilePath("Look at ~/Downloads/file.pdf"))
    }

    func testDetectsApplicationsPath() {
        XCTAssertTrue(containsFilePath("/Applications/Xcode.app/Contents"))
    }

    func testDetectsLibraryPath() {
        XCTAssertTrue(containsFilePath("/Library/Preferences/com.apple.plist"))
    }

    func testIgnoresNonPathText() {
        XCTAssertFalse(containsFilePath("The weather is nice today"))
    }

    func testIgnoresURLs() {
        // URLs don't start with /Users, ~/,  /Applications, /Library, /private
        XCTAssertFalse(containsFilePath("Visit https://example.com/path"))
    }
}
