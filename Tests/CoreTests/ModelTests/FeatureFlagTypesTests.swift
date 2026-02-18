// FeatureFlagTypesTests.swift
// Tests for FeatureFlags system types and logic

import Testing
import Foundation

// MARK: - Test Doubles (Mirror production types for pure logic testing)

private enum TestFeatureFlagSource: String, Codable, Sendable {
    case local
    case remote
    case override
    case abTest = "ab_test"
}

private struct TestFeatureFlag: Codable, Sendable {
    let key: String
    var isEnabled: Bool
    let source: TestFeatureFlagSource
    let lastUpdated: Date
    var description: String?
    var rolloutPercentage: Double?
}

/// Mirrors the isEnabled logic from FeatureFlags.swift
private func testIsEnabled(
    _ key: String,
    flags: [String: TestFeatureFlag],
    default defaultValue: Bool = false
) -> Bool {
    if let flag = flags[key] {
        return flag.isEnabled
    }
    return defaultValue
}

/// Mirrors the setFlag logic from FeatureFlags.swift
private func testSetFlag(
    _ key: String,
    enabled: Bool,
    source: TestFeatureFlagSource = .local,
    into flags: inout [String: TestFeatureFlag]
) {
    flags[key] = TestFeatureFlag(
        key: key,
        isEnabled: enabled,
        source: source,
        lastUpdated: Date()
    )
}

/// Mirrors the temperature logic from DynamicConfig.swift
private enum TestAITaskCategory: String, Codable, Sendable, CaseIterable {
    case codeGeneration, codeReview, bugFix
    case conversation, assistance
    case creative, brainstorming
    case analysis, classification
    case translation, correction
}

private func testTemperature(for task: TestAITaskCategory) -> Double {
    switch task {
    case .codeGeneration, .codeReview, .bugFix:
        return 0.1
    case .creative, .brainstorming:
        return 0.9
    case .conversation, .assistance:
        return 0.7
    case .analysis, .classification:
        return 0.3
    case .translation, .correction:
        return 0.2
    }
}

private func testMaxTokens(for task: TestAITaskCategory, inputLength: Int = 0) -> Int {
    switch task {
    case .codeGeneration:
        return 4000
    case .codeReview, .bugFix:
        return 2000
    case .conversation:
        return 1000
    case .analysis:
        return 1500
    case .creative, .brainstorming:
        return 3000
    case .translation, .correction:
        return max(inputLength * 2, 500)
    case .assistance:
        return 2000
    case .classification:
        return 100
    }
}

private func testDefaultModel(for task: TestAITaskCategory) -> String {
    switch task {
    case .codeGeneration, .codeReview, .bugFix, .creative, .analysis:
        return "gpt-4o"
    default:
        return "gpt-4o-mini"
    }
}

// MARK: - Cache Logic Test Double

private struct TestCachedValue {
    let value: Any
    let expiry: Date

    var isExpired: Bool {
        Date() > expiry
    }
}

// MARK: - Periodic Task Test Double

private enum TestPeriodicTask: String, Sendable, CaseIterable {
    case contextUpdate, insightGeneration, healthCheck
    case cacheCleanup, modelOptimization, selfImprovement
}

private func testDefaultInterval(for task: TestPeriodicTask) -> TimeInterval {
    switch task {
    case .contextUpdate: return 900
    case .insightGeneration: return 3600
    case .healthCheck: return 300
    case .cacheCleanup: return 7200
    case .modelOptimization: return 86400
    case .selfImprovement: return 43200
    }
}

// MARK: - Tests: FeatureFlagSource

@Suite("FeatureFlagSource")
struct FeatureFlagSourceTests {
    @Test("All cases have unique raw values")
    func uniqueRawValues() {
        let sources: [TestFeatureFlagSource] = [.local, .remote, .override, .abTest]
        let rawValues = sources.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("AB test has correct raw value")
    func abTestRawValue() {
        #expect(TestFeatureFlagSource.abTest.rawValue == "ab_test")
    }

    @Test("Codable roundtrip for all cases")
    func codableRoundtrip() throws {
        let sources: [TestFeatureFlagSource] = [.local, .remote, .override, .abTest]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for source in sources {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(TestFeatureFlagSource.self, from: data)
            #expect(decoded == source)
        }
    }

    @Test("Local is default source")
    func localIsDefault() {
        #expect(TestFeatureFlagSource.local.rawValue == "local")
    }
}

// MARK: - Tests: FeatureFlag

@Suite("FeatureFlag Model")
struct FeatureFlagModelTests {
    @Test("Creation with all properties")
    func creation() {
        let now = Date()
        let flag = TestFeatureFlag(
            key: "test.flag",
            isEnabled: true,
            source: .local,
            lastUpdated: now,
            description: "A test flag",
            rolloutPercentage: 0.5
        )
        #expect(flag.key == "test.flag")
        #expect(flag.isEnabled == true)
        #expect(flag.source == .local)
        #expect(flag.lastUpdated == now)
        #expect(flag.description == "A test flag")
        #expect(flag.rolloutPercentage == 0.5)
    }

    @Test("Optional properties default to nil")
    func optionalDefaults() {
        let flag = TestFeatureFlag(
            key: "simple",
            isEnabled: false,
            source: .remote,
            lastUpdated: Date()
        )
        #expect(flag.description == nil)
        #expect(flag.rolloutPercentage == nil)
    }

    @Test("Codable roundtrip with full properties")
    func codableRoundtripFull() throws {
        let flag = TestFeatureFlag(
            key: "ai.vision",
            isEnabled: true,
            source: .abTest,
            lastUpdated: Date(timeIntervalSince1970: 1000),
            description: "Vision feature",
            rolloutPercentage: 0.75
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(flag)
        let decoded = try decoder.decode(TestFeatureFlag.self, from: data)
        #expect(decoded.key == "ai.vision")
        #expect(decoded.isEnabled == true)
        #expect(decoded.source == .abTest)
        #expect(decoded.rolloutPercentage == 0.75)
    }

    @Test("Codable roundtrip with nil optionals")
    func codableRoundtripMinimal() throws {
        let flag = TestFeatureFlag(
            key: "min",
            isEnabled: false,
            source: .local,
            lastUpdated: Date(timeIntervalSince1970: 0)
        )
        let data = try JSONEncoder().encode(flag)
        let decoded = try JSONDecoder().decode(TestFeatureFlag.self, from: data)
        #expect(decoded.key == "min")
        #expect(decoded.isEnabled == false)
        #expect(decoded.description == nil)
        #expect(decoded.rolloutPercentage == nil)
    }
}

// MARK: - Tests: Flag Management Logic

@Suite("Feature Flag Management Logic")
struct FeatureFlagManagementTests {
    @Test("isEnabled returns true for enabled flag")
    func enabledFlag() {
        var flags: [String: TestFeatureFlag] = [:]
        testSetFlag("test.enabled", enabled: true, into: &flags)
        #expect(testIsEnabled("test.enabled", flags: flags) == true)
    }

    @Test("isEnabled returns false for disabled flag")
    func disabledFlag() {
        var flags: [String: TestFeatureFlag] = [:]
        testSetFlag("test.disabled", enabled: false, into: &flags)
        #expect(testIsEnabled("test.disabled", flags: flags) == false)
    }

    @Test("isEnabled returns default when flag not set")
    func defaultWhenMissing() {
        let flags: [String: TestFeatureFlag] = [:]
        #expect(testIsEnabled("nonexistent", flags: flags, default: true) == true)
        #expect(testIsEnabled("nonexistent", flags: flags, default: false) == false)
    }

    @Test("isEnabled uses false as default when no default specified")
    func defaultIsFalse() {
        let flags: [String: TestFeatureFlag] = [:]
        #expect(testIsEnabled("missing", flags: flags) == false)
    }

    @Test("setFlag overrides previous value")
    func overridePrevious() {
        var flags: [String: TestFeatureFlag] = [:]
        testSetFlag("toggle", enabled: true, into: &flags)
        #expect(testIsEnabled("toggle", flags: flags) == true)
        testSetFlag("toggle", enabled: false, into: &flags)
        #expect(testIsEnabled("toggle", flags: flags) == false)
    }

    @Test("setFlag preserves source")
    func preservesSource() {
        var flags: [String: TestFeatureFlag] = [:]
        testSetFlag("remote.flag", enabled: true, source: .remote, into: &flags)
        #expect(flags["remote.flag"]?.source == .remote)
    }

    @Test("Reset removes all flags")
    func resetClearsAll() {
        var flags: [String: TestFeatureFlag] = [:]
        testSetFlag("a", enabled: true, into: &flags)
        testSetFlag("b", enabled: false, into: &flags)
        testSetFlag("c", enabled: true, into: &flags)
        #expect(flags.count == 3)
        flags.removeAll()
        #expect(flags.isEmpty)
        #expect(testIsEnabled("a", flags: flags) == false)
    }

    @Test("Multiple flags are independent")
    func independentFlags() {
        var flags: [String: TestFeatureFlag] = [:]
        testSetFlag("ai.vision", enabled: true, into: &flags)
        testSetFlag("ai.speech", enabled: false, into: &flags)
        testSetFlag("automation.browser", enabled: true, into: &flags)

        #expect(testIsEnabled("ai.vision", flags: flags) == true)
        #expect(testIsEnabled("ai.speech", flags: flags) == false)
        #expect(testIsEnabled("automation.browser", flags: flags) == true)
    }

    @Test("Flag key convention with dots")
    func keyConvention() {
        var flags: [String: TestFeatureFlag] = [:]
        let keys = [
            "agentsec.strict_mode", "ai.vision", "ai.speech",
            "ui.live_activities", "ui.widgets", "automation.browser",
            "integration.spotlight", "tracking.health"
        ]
        for key in keys {
            testSetFlag(key, enabled: true, into: &flags)
        }
        #expect(flags.count == keys.count)
        for key in keys {
            #expect(testIsEnabled(key, flags: flags) == true)
        }
    }
}

// MARK: - Tests: Cache Logic

@Suite("Config Cache Logic")
struct ConfigCacheTests {
    @Test("Cached value not expired when in future")
    func notExpired() {
        let cached = TestCachedValue(
            value: "test",
            expiry: Date().addingTimeInterval(3600)
        )
        #expect(cached.isExpired == false)
    }

    @Test("Cached value expired when in past")
    func expired() {
        let cached = TestCachedValue(
            value: "test",
            expiry: Date().addingTimeInterval(-1)
        )
        #expect(cached.isExpired == true)
    }

    @Test("Cached value boundary — just expired")
    func boundaryExpired() {
        let cached = TestCachedValue(
            value: "test",
            expiry: Date().addingTimeInterval(-0.001)
        )
        #expect(cached.isExpired == true)
    }
}

// DynamicConfig tests moved to DynamicConfigTypesTests.swift

// MARK: - Tests: Flag Dictionary Serialization

@Suite("Feature Flag Dictionary Serialization")
struct FlagDictionarySerializationTests {
    @Test("Empty flags dictionary roundtrip")
    func emptyRoundtrip() throws {
        let flags: [String: TestFeatureFlag] = [:]
        let data = try JSONEncoder().encode(flags)
        let decoded = try JSONDecoder().decode([String: TestFeatureFlag].self, from: data)
        #expect(decoded.isEmpty)
    }

    @Test("Multiple flags dictionary roundtrip")
    func multipleRoundtrip() throws {
        var flags: [String: TestFeatureFlag] = [:]
        testSetFlag("a.b", enabled: true, source: .local, into: &flags)
        testSetFlag("c.d", enabled: false, source: .remote, into: &flags)
        testSetFlag("e.f", enabled: true, source: .abTest, into: &flags)

        let data = try JSONEncoder().encode(flags)
        let decoded = try JSONDecoder().decode([String: TestFeatureFlag].self, from: data)
        #expect(decoded.count == 3)
        #expect(decoded["a.b"]?.isEnabled == true)
        #expect(decoded["c.d"]?.isEnabled == false)
        #expect(decoded["e.f"]?.source == .abTest)
    }
}
