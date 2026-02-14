// PrivacyPoliciesTests.swift
// Tests for built-in privacy policy configurations

import Foundation
import XCTest

// swiftlint:disable private_over_fileprivate

// MARK: - Mirrored Types

fileprivate enum StrictnessLevel: String, Codable, Comparable {
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

fileprivate protocol PrivacyPolicy {
    var name: String { get }
    var strictnessLevel: StrictnessLevel { get }
    var allowPII: Bool { get }
    var allowFilePaths: Bool { get }
    var allowCodeSnippets: Bool { get }
    var allowHealthData: Bool { get }
    var allowFinancialData: Bool { get }
    var blockedKeywords: Set<String> { get }
    var allowedTopics: Set<String>? { get }
    var maxContentLength: Int { get }
}

fileprivate struct CloudAPIPolicy: PrivacyPolicy {
    let name = "Cloud API"
    let strictnessLevel: StrictnessLevel = .standard
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = true
    let allowHealthData = false
    let allowFinancialData = false
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}

fileprivate struct MessagingPolicy: PrivacyPolicy {
    let name = "Messaging"
    let strictnessLevel: StrictnessLevel = .strict
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = false
    let allowHealthData = false
    let allowFinancialData = false
    let blockedKeywords: Set<String> = [
        "password", "secret", "api key", "token",
        "credit card", "bank account", "social security"
    ]
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 4096
}

fileprivate struct MCPPolicy: PrivacyPolicy {
    let name = "MCP"
    let strictnessLevel: StrictnessLevel = .strict
    let allowPII = false
    let allowFilePaths = true
    let allowCodeSnippets = true
    let allowHealthData = false
    let allowFinancialData = false
    let blockedKeywords: Set<String> = [
        "password", "secret key", "private key"
    ]
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}

fileprivate struct WebAPIPolicy: PrivacyPolicy {
    let name = "Web API"
    let strictnessLevel: StrictnessLevel = .standard
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = true
    let allowHealthData = false
    let allowFinancialData = false
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}

fileprivate struct MoltbookPolicy: PrivacyPolicy {
    let name = "Moltbook"
    let strictnessLevel: StrictnessLevel = .paranoid
    let allowPII = false
    let allowFilePaths = false
    let allowCodeSnippets = false
    let allowHealthData = false
    let allowFinancialData = false
    let blockedKeywords: Set<String> = [
        "password", "secret", "api key", "token", "credential",
        "credit card", "bank", "social security", "ssn",
        "address", "phone number", "email",
        "health", "medical", "diagnosis", "prescription",
        "salary", "income", "debt"
    ]
    let allowedTopics: Set<String>? = [
        "swift", "ios", "macos", "watchos", "tvos",
        "swiftui", "uikit", "appkit", "combine", "async/await",
        "mlx", "coreml", "machine learning", "ai", "llm",
        "architecture", "design patterns", "testing",
        "xcode", "spm", "cocoapods", "performance",
        "accessibility", "localization", "security",
        "networking", "database", "swiftdata", "cloudkit",
        "privacy", "open source", "documentation"
    ]
    let maxContentLength = 2048
}

fileprivate struct PermissivePolicy: PrivacyPolicy {
    let name = "Permissive"
    let strictnessLevel: StrictnessLevel = .permissive
    let allowPII = true
    let allowFilePaths = true
    let allowCodeSnippets = true
    let allowHealthData = true
    let allowFinancialData = true
    let blockedKeywords: Set<String> = []
    let allowedTopics: Set<String>? = nil
    let maxContentLength = 0
}

// MARK: - All Policies Tests

final class AllPoliciesTests: XCTestCase {

    private func allPolicies() -> [any PrivacyPolicy] {
        [
            CloudAPIPolicy(), MessagingPolicy(), MCPPolicy(),
            WebAPIPolicy(), MoltbookPolicy(), PermissivePolicy()
        ]
    }

    func testAllPoliciesHaveNames() {
        for policy in allPolicies() {
            XCTAssertFalse(
                policy.name.isEmpty,
                "Policy must have a name"
            )
        }
    }

    func testUniqueNames() {
        let names = allPolicies().map(\.name)
        XCTAssertEqual(
            names.count, Set(names).count,
            "All policy names must be unique"
        )
    }

    func testNoPolicyAllowsPIIExceptPermissive() {
        for policy in allPolicies() {
            if policy.name == "Permissive" {
                XCTAssertTrue(policy.allowPII)
            } else {
                XCTAssertFalse(
                    policy.allowPII,
                    "\(policy.name) should not allow PII"
                )
            }
        }
    }

    func testNoPolicyAllowsHealthDataExceptPermissive() {
        for policy in allPolicies() {
            if policy.name == "Permissive" {
                XCTAssertTrue(policy.allowHealthData)
            } else {
                XCTAssertFalse(
                    policy.allowHealthData,
                    "\(policy.name) should not allow health data"
                )
            }
        }
    }

    func testNoPolicyAllowsFinancialDataExceptPermissive() {
        for policy in allPolicies() {
            if policy.name == "Permissive" {
                XCTAssertTrue(policy.allowFinancialData)
            } else {
                XCTAssertFalse(
                    policy.allowFinancialData,
                    "\(policy.name) should not allow financial data"
                )
            }
        }
    }
}

// MARK: - MoltbookPolicy Tests

final class MoltbookPolicyTests: XCTestCase {

    fileprivate let policy = MoltbookPolicy()

    func testStrictnessIsParanoid() {
        XCTAssertEqual(policy.strictnessLevel, .paranoid)
    }

    func testBlocksAllPersonalKeywords() {
        let personalKeywords = [
            "password", "secret", "api key",
            "credit card", "ssn", "salary", "health"
        ]
        for keyword in personalKeywords {
            XCTAssertTrue(
                policy.blockedKeywords.contains(keyword),
                "Missing blocked keyword: \(keyword)"
            )
        }
    }

    func testAllowsOnlyDevTopics() {
        XCTAssertNotNil(policy.allowedTopics)
        let topics = policy.allowedTopics!
        XCTAssertTrue(topics.contains("swift"))
        XCTAssertTrue(topics.contains("swiftui"))
        XCTAssertTrue(topics.contains("machine learning"))
        XCTAssertTrue(topics.contains("architecture"))
        XCTAssertTrue(topics.contains("testing"))
    }

    func testTopicCountIsReasonable() {
        let topics = policy.allowedTopics!
        XCTAssertGreaterThan(topics.count, 20)
        XCTAssertLessThan(topics.count, 50)
    }

    func testContentLengthCapped() {
        XCTAssertEqual(policy.maxContentLength, 2048)
    }

    func testNoCodeSnippets() {
        XCTAssertFalse(policy.allowCodeSnippets)
    }

    func testNoFilePaths() {
        XCTAssertFalse(policy.allowFilePaths)
    }
}

// MARK: - MessagingPolicy Tests

final class MessagingPolicyTests: XCTestCase {

    fileprivate let policy = MessagingPolicy()

    func testStrictnessIsStrict() {
        XCTAssertEqual(policy.strictnessLevel, .strict)
    }

    func testBlocksSecurityKeywords() {
        XCTAssertTrue(policy.blockedKeywords.contains("password"))
        XCTAssertTrue(policy.blockedKeywords.contains("token"))
        XCTAssertTrue(
            policy.blockedKeywords.contains("social security")
        )
    }

    func testContentLengthCapped() {
        XCTAssertEqual(policy.maxContentLength, 4096)
    }

    func testNoCodeSnippets() {
        XCTAssertFalse(policy.allowCodeSnippets)
    }

    func testNoTopicRestriction() {
        XCTAssertNil(policy.allowedTopics)
    }
}

// MARK: - CloudAPIPolicy Tests

final class CloudAPIPolicyTests: XCTestCase {

    fileprivate let policy = CloudAPIPolicy()

    func testStrictnessIsStandard() {
        XCTAssertEqual(policy.strictnessLevel, .standard)
    }

    func testAllowsCodeSnippets() {
        XCTAssertTrue(policy.allowCodeSnippets)
    }

    func testNoBlockedKeywords() {
        XCTAssertTrue(policy.blockedKeywords.isEmpty)
    }

    func testUnlimitedContentLength() {
        XCTAssertEqual(policy.maxContentLength, 0)
    }

    func testNoTopicRestriction() {
        XCTAssertNil(policy.allowedTopics)
    }
}

// MARK: - MCPPolicy Tests

final class MCPPolicyTests: XCTestCase {

    fileprivate let policy = MCPPolicy()

    func testStrictnessIsStrict() {
        XCTAssertEqual(policy.strictnessLevel, .strict)
    }

    func testAllowsFilePaths() {
        // MCP tools often return file paths
        XCTAssertTrue(policy.allowFilePaths)
    }

    func testAllowsCodeSnippets() {
        XCTAssertTrue(policy.allowCodeSnippets)
    }

    func testBlocksSecrets() {
        XCTAssertTrue(policy.blockedKeywords.contains("password"))
        XCTAssertTrue(policy.blockedKeywords.contains("private key"))
    }
}

// MARK: - PermissivePolicy Tests

final class PermissivePolicyTests: XCTestCase {

    fileprivate let policy = PermissivePolicy()

    func testStrictnessIsPermissive() {
        XCTAssertEqual(policy.strictnessLevel, .permissive)
    }

    func testAllowsEverything() {
        XCTAssertTrue(policy.allowPII)
        XCTAssertTrue(policy.allowFilePaths)
        XCTAssertTrue(policy.allowCodeSnippets)
        XCTAssertTrue(policy.allowHealthData)
        XCTAssertTrue(policy.allowFinancialData)
    }

    func testNoRestrictions() {
        XCTAssertTrue(policy.blockedKeywords.isEmpty)
        XCTAssertNil(policy.allowedTopics)
        XCTAssertEqual(policy.maxContentLength, 0)
    }
}

// MARK: - StrictnessLevel Ordering Tests

final class PolicyStrictnessOrderingTests: XCTestCase {

    func testPoliciesOrderedByStrictness() {
        let policies: [(String, StrictnessLevel)] = [
            ("Permissive", PermissivePolicy().strictnessLevel),
            ("Cloud API", CloudAPIPolicy().strictnessLevel),
            ("Web API", WebAPIPolicy().strictnessLevel),
            ("Messaging", MessagingPolicy().strictnessLevel),
            ("MCP", MCPPolicy().strictnessLevel),
            ("Moltbook", MoltbookPolicy().strictnessLevel)
        ]

        // Permissive is least strict
        XCTAssertEqual(policies[0].1, .permissive)

        // Moltbook is most strict
        XCTAssertEqual(policies[5].1, .paranoid)

        // Standard < strict < paranoid
        XCTAssertTrue(policies[1].1 < policies[3].1)
        XCTAssertTrue(policies[3].1 < policies[5].1)
    }

    func testMessagingStricterThanCloudAPI() {
        let messaging = MessagingPolicy()
        let cloudAPI = CloudAPIPolicy()
        XCTAssertTrue(
            cloudAPI.strictnessLevel < messaging.strictnessLevel
        )
    }

    func testMoltbookStricterThanAll() {
        let moltbook = MoltbookPolicy()
        let others: [any PrivacyPolicy] = [
            CloudAPIPolicy(), MessagingPolicy(), MCPPolicy(),
            WebAPIPolicy(), PermissivePolicy()
        ]
        for other in others {
            XCTAssertTrue(
                other.strictnessLevel < moltbook.strictnessLevel
                || other.strictnessLevel == moltbook.strictnessLevel,
                "\(other.name) should not be stricter than Moltbook"
            )
        }
    }
}
