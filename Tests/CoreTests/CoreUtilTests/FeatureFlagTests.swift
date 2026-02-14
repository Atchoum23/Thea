@testable import TheaCore
import XCTest

@MainActor
final class FeatureFlagTests: XCTestCase {
    // MARK: - FeatureFlag Model

    func testFeatureFlagCreation() {
        let flag = FeatureFlag(
            key: "test.feature",
            isEnabled: true,
            source: .local,
            lastUpdated: Date()
        )

        XCTAssertEqual(flag.key, "test.feature")
        XCTAssertTrue(flag.isEnabled)
        XCTAssertEqual(flag.source, .local)
        XCTAssertNil(flag.description)
        XCTAssertNil(flag.rolloutPercentage)
    }

    func testFeatureFlagWithOptionals() {
        var flag = FeatureFlag(
            key: "rollout.feature",
            isEnabled: false,
            source: .abTest,
            lastUpdated: Date()
        )
        flag.description = "A/B test for new UI"
        flag.rolloutPercentage = 0.5

        XCTAssertEqual(flag.description, "A/B test for new UI")
        XCTAssertEqual(flag.rolloutPercentage, 0.5)
    }

    func testFeatureFlagCodable() throws {
        var original = FeatureFlag(
            key: "codable.test",
            isEnabled: true,
            source: .remote,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
        original.description = "Test flag"
        original.rolloutPercentage = 0.75

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FeatureFlag.self, from: data)

        XCTAssertEqual(decoded.key, "codable.test")
        XCTAssertTrue(decoded.isEnabled)
        XCTAssertEqual(decoded.source, .remote)
        XCTAssertEqual(decoded.description, "Test flag")
        XCTAssertEqual(decoded.rolloutPercentage, 0.75)
    }

    // MARK: - FeatureFlagSource

    func testFeatureFlagSourceRawValues() {
        XCTAssertEqual(FeatureFlagSource.local.rawValue, "local")
        XCTAssertEqual(FeatureFlagSource.remote.rawValue, "remote")
        XCTAssertEqual(FeatureFlagSource.override.rawValue, "override")
        XCTAssertEqual(FeatureFlagSource.abTest.rawValue, "ab_test")
    }

    func testFeatureFlagSourceCodable() throws {
        let sources: [FeatureFlagSource] = [.local, .remote, .override, .abTest]
        let data = try JSONEncoder().encode(sources)
        let decoded = try JSONDecoder().decode([FeatureFlagSource].self, from: data)
        XCTAssertEqual(decoded, sources)
    }

    // MARK: - FeatureFlags Manager — isEnabled

    func testIsEnabledDefaultFalse() {
        let flags = FeatureFlags.shared
        // Unknown key with no default returns false
        XCTAssertFalse(flags.isEnabled("nonexistent.key"))
    }

    func testIsEnabledWithDefaultTrue() {
        let flags = FeatureFlags.shared
        // Unknown key with explicit default returns the default
        XCTAssertTrue(flags.isEnabled("nonexistent.key", default: true))
    }

    func testSetAndReadFlag() {
        let flags = FeatureFlags.shared
        let key = "test.set_read_\(UUID().uuidString.prefix(8))"

        flags.setFlag(key, enabled: true, source: .local)
        XCTAssertTrue(flags.isEnabled(key))

        flags.setFlag(key, enabled: false, source: .local)
        XCTAssertFalse(flags.isEnabled(key))

        // Clean up
        flags.flags.removeValue(forKey: key)
    }

    func testSetFlagRecordsSource() {
        let flags = FeatureFlags.shared
        let key = "test.source_\(UUID().uuidString.prefix(8))"

        flags.setFlag(key, enabled: true, source: .override)
        XCTAssertEqual(flags.flags[key]?.source, .override)

        flags.setFlag(key, enabled: true, source: .remote)
        XCTAssertEqual(flags.flags[key]?.source, .remote)

        // Clean up
        flags.flags.removeValue(forKey: key)
    }

    func testSetFlagRecordsTimestamp() {
        let flags = FeatureFlags.shared
        let key = "test.timestamp_\(UUID().uuidString.prefix(8))"
        let before = Date()

        flags.setFlag(key, enabled: true)

        let after = Date()
        if let flag = flags.flags[key] {
            XCTAssertGreaterThanOrEqual(flag.lastUpdated, before)
            XCTAssertLessThanOrEqual(flag.lastUpdated, after)
        } else {
            XCTFail("Flag not found after setting")
        }

        // Clean up
        flags.flags.removeValue(forKey: key)
    }

    // MARK: - Core Feature Flag Accessors

    func testAgentSecStrictModeDefault() {
        // Default is true per implementation
        let flags = FeatureFlags.shared
        // If no override set, should return default
        let val = flags.isEnabled("agentsec.strict_mode", default: true)
        XCTAssertTrue(val)
    }

    func testBrowserAutomationDefaultOff() {
        // browserAutomation defaults to false
        let flags = FeatureFlags.shared
        let val = flags.isEnabled("automation.browser", default: false)
        XCTAssertFalse(val)
    }

    func testCodeExecutionSandboxDefaultOff() {
        let flags = FeatureFlags.shared
        let val = flags.isEnabled("ai.code_execution", default: false)
        XCTAssertFalse(val)
    }

    // MARK: - Integration Module Flags

    func testIntegrationFlagGetterSetter() {
        let flags = FeatureFlags.shared

        // Save original value
        let originalHealth = flags.flags["integration.health"]

        flags.healthEnabled = false
        XCTAssertFalse(flags.healthEnabled)

        flags.healthEnabled = true
        XCTAssertTrue(flags.healthEnabled)

        // Restore
        if let original = originalHealth {
            flags.flags["integration.health"] = original
        } else {
            flags.flags.removeValue(forKey: "integration.health")
        }
    }

    // MARK: - Flag Dictionary Codable Round-Trip

    func testFlagDictionaryCodable() throws {
        let flagDict: [String: FeatureFlag] = [
            "feature.a": FeatureFlag(key: "feature.a", isEnabled: true, source: .local, lastUpdated: Date()),
            "feature.b": FeatureFlag(key: "feature.b", isEnabled: false, source: .remote, lastUpdated: Date()),
        ]

        let data = try JSONEncoder().encode(flagDict)
        let decoded = try JSONDecoder().decode([String: FeatureFlag].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertTrue(decoded["feature.a"]!.isEnabled)
        XCTAssertFalse(decoded["feature.b"]!.isEnabled)
        XCTAssertEqual(decoded["feature.a"]!.source, .local)
        XCTAssertEqual(decoded["feature.b"]!.source, .remote)
    }
}
