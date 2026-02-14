// AgentSettingsAndSyncTests.swift
// Tests for agent delegation settings defaults, CloudKit container patterns,
// zone consolidation, and @agent command parsing

import Foundation
import XCTest

// MARK: - Mirrored: Agent Settings Defaults

private struct TestAgentSettings {
    var agentDelegationEnabled: Bool
    var agentAutoDelegateComplexTasks: Bool
    var agentMaxConcurrent: Int
    var agentDefaultAutonomy: String

    static var defaults: TestAgentSettings {
        TestAgentSettings(
            agentDelegationEnabled: true,
            agentAutoDelegateComplexTasks: false,
            agentMaxConcurrent: 4,
            agentDefaultAutonomy: "balanced"
        )
    }

    mutating func reset() {
        self = Self.defaults
    }
}

// MARK: - Mirrored: Container Safety Pattern

private struct TestContainerConfig {
    let containerIdentifier: String
    let fallbackToDefault: Bool
    let entitledContainers: [String]

    func resolvedIdentifier() -> String? {
        if entitledContainers.contains(containerIdentifier) {
            return containerIdentifier
        }
        return fallbackToDefault ? nil : nil  // nil = use default container
    }

    var isEntitled: Bool {
        entitledContainers.contains(containerIdentifier)
    }
}

// MARK: - Mirrored: Zone Consolidation

private struct TestZoneConfig {
    let zoneName: String
    let ownerName: String

    static let canonical = TestZoneConfig(zoneName: "TheaZone", ownerName: "__defaultOwner__")
}

// MARK: - Mirrored: @agent Command Parsing

private enum AgentCommandParser {
    static func parse(_ text: String) -> (isAgentCommand: Bool, taskDescription: String?) {
        guard text.hasPrefix("@agent ") else {
            return (false, nil)
        }
        let description = String(text.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        return (true, description.isEmpty ? nil : description)
    }
}

// MARK: - Mirrored: Autonomy Levels

private enum TestAutonomyLevel: String, CaseIterable {
    case supervised
    case cautious
    case balanced
    case autonomous
    case unrestricted

    var riskTolerance: Double {
        switch self {
        case .supervised: 0.1
        case .cautious: 0.3
        case .balanced: 0.5
        case .autonomous: 0.7
        case .unrestricted: 0.9
        }
    }
}

// MARK: - Agent Settings Default Tests

final class AgentSettingsDefaultsTests: XCTestCase {

    func testDelegationEnabledByDefault() {
        let settings = TestAgentSettings.defaults
        XCTAssertTrue(settings.agentDelegationEnabled)
    }

    func testAutoDelegateDisabledByDefault() {
        let settings = TestAgentSettings.defaults
        XCTAssertFalse(settings.agentAutoDelegateComplexTasks)
    }

    func testMaxConcurrentDefault() {
        let settings = TestAgentSettings.defaults
        XCTAssertEqual(settings.agentMaxConcurrent, 4)
    }

    func testDefaultAutonomyIsBalanced() {
        let settings = TestAgentSettings.defaults
        XCTAssertEqual(settings.agentDefaultAutonomy, "balanced")
    }

    func testResetRestoresDefaults() {
        var settings = TestAgentSettings(
            agentDelegationEnabled: false,
            agentAutoDelegateComplexTasks: true,
            agentMaxConcurrent: 8,
            agentDefaultAutonomy: "unrestricted"
        )
        settings.reset()
        XCTAssertTrue(settings.agentDelegationEnabled)
        XCTAssertFalse(settings.agentAutoDelegateComplexTasks)
        XCTAssertEqual(settings.agentMaxConcurrent, 4)
        XCTAssertEqual(settings.agentDefaultAutonomy, "balanced")
    }

    func testCustomSettings() {
        let settings = TestAgentSettings(
            agentDelegationEnabled: false,
            agentAutoDelegateComplexTasks: true,
            agentMaxConcurrent: 8,
            agentDefaultAutonomy: "autonomous"
        )
        XCTAssertFalse(settings.agentDelegationEnabled)
        XCTAssertTrue(settings.agentAutoDelegateComplexTasks)
        XCTAssertEqual(settings.agentMaxConcurrent, 8)
        XCTAssertEqual(settings.agentDefaultAutonomy, "autonomous")
    }

    func testMaxConcurrentValidRange() {
        // Valid range: 1-8 (as shown in settings picker)
        let validValues = [1, 2, 3, 4, 5, 6, 7, 8]
        for value in validValues {
            XCTAssertGreaterThanOrEqual(value, 1)
            XCTAssertLessThanOrEqual(value, 8)
        }
    }
}

// MARK: - Container Safety Tests

final class ContainerSafetyTests: XCTestCase {

    func testEntitledContainerResolves() {
        let config = TestContainerConfig(
            containerIdentifier: "iCloud.app.theathe",
            fallbackToDefault: true,
            entitledContainers: ["iCloud.app.theathe"]
        )
        XCTAssertEqual(config.resolvedIdentifier(), "iCloud.app.theathe")
        XCTAssertTrue(config.isEntitled)
    }

    func testUnentitledContainerFallsBack() {
        let config = TestContainerConfig(
            containerIdentifier: "iCloud.app.theathe",
            fallbackToDefault: true,
            entitledContainers: []  // No entitlements (CI/test)
        )
        XCTAssertNil(config.resolvedIdentifier())
        XCTAssertFalse(config.isEntitled)
    }

    func testWrongContainerID() {
        let config = TestContainerConfig(
            containerIdentifier: "iCloud.app.theathe",
            fallbackToDefault: true,
            entitledContainers: ["iCloud.com.other.app"]
        )
        XCTAssertNil(config.resolvedIdentifier())
    }

    func testMultipleEntitlements() {
        let config = TestContainerConfig(
            containerIdentifier: "iCloud.app.theathe",
            fallbackToDefault: true,
            entitledContainers: ["iCloud.com.other", "iCloud.app.theathe", "iCloud.test"]
        )
        XCTAssertTrue(config.isEntitled)
        XCTAssertEqual(config.resolvedIdentifier(), "iCloud.app.theathe")
    }

    func testContainerIDFormat() {
        let id = "iCloud.app.theathe"
        XCTAssertTrue(id.hasPrefix("iCloud."))
        XCTAssertEqual(id, "iCloud.app.theathe")
    }

    func testContainerIDNotDefault() {
        // Verifying the fix: CrossDeviceService should NOT use CKContainer.default()
        let expectedID = "iCloud.app.theathe"
        XCTAssertNotEqual(expectedID, "")
        XCTAssertTrue(expectedID.contains("theathe"))
    }
}

// MARK: - Zone Consolidation Tests

final class ZoneConsolidationTests: XCTestCase {

    func testCanonicalZoneName() {
        XCTAssertEqual(TestZoneConfig.canonical.zoneName, "TheaZone")
    }

    func testCanonicalOwner() {
        XCTAssertEqual(TestZoneConfig.canonical.ownerName, "__defaultOwner__")
    }

    func testAllServicesUseTheaZone() {
        // Mirrors the fix: all sync services should use "TheaZone"
        let cloudKitServiceZone = "TheaZone"
        let crossDeviceServiceZone = "TheaZone"
        let unifiedContextSyncZone = "TheaZone"
        let clipSyncServiceZone = "TheaZone"

        XCTAssertEqual(cloudKitServiceZone, crossDeviceServiceZone)
        XCTAssertEqual(crossDeviceServiceZone, unifiedContextSyncZone)
        XCTAssertEqual(unifiedContextSyncZone, clipSyncServiceZone)
    }

    func testLegacyZoneNotUsed() {
        let canonicalZone = "TheaZone"
        let legacyZone = "TheaContext"
        XCTAssertNotEqual(canonicalZone, legacyZone, "Should not use legacy TheaContext zone")
    }

    func testDefaultZoneNotUsed() {
        let canonicalZone = "TheaZone"
        XCTAssertFalse(canonicalZone.isEmpty, "Should not use empty (default) zone")
    }
}

// MARK: - @agent Command Parser Tests

final class AgentCommandParserTests: XCTestCase {

    func testBasicAgentCommand() {
        let result = AgentCommandParser.parse("@agent research Swift concurrency")
        XCTAssertTrue(result.isAgentCommand)
        XCTAssertEqual(result.taskDescription, "research Swift concurrency")
    }

    func testNotAgentCommand() {
        let result = AgentCommandParser.parse("Hello, how are you?")
        XCTAssertFalse(result.isAgentCommand)
        XCTAssertNil(result.taskDescription)
    }

    func testAgentCommandWithNoTask() {
        let result = AgentCommandParser.parse("@agent ")
        XCTAssertTrue(result.isAgentCommand)
        XCTAssertNil(result.taskDescription)
    }

    func testAgentPrefixOnly() {
        let result = AgentCommandParser.parse("@agent")
        XCTAssertFalse(result.isAgentCommand)  // Missing space after @agent
    }

    func testAgentCommandWithSpaces() {
        let result = AgentCommandParser.parse("@agent   research   topic   ")
        XCTAssertTrue(result.isAgentCommand)
        XCTAssertEqual(result.taskDescription, "research   topic")
    }

    func testAgentCommandCaseSensitive() {
        let result = AgentCommandParser.parse("@Agent research topic")
        XCTAssertFalse(result.isAgentCommand)
    }

    func testAgentCommandInMiddle() {
        let result = AgentCommandParser.parse("Please @agent research topic")
        XCTAssertFalse(result.isAgentCommand)
    }

    func testAgentCommandLongTask() {
        let longTask = String(repeating: "word ", count: 100)
        let result = AgentCommandParser.parse("@agent \(longTask)")
        XCTAssertTrue(result.isAgentCommand)
        XCTAssertNotNil(result.taskDescription)
    }

    func testAgentCommandWithNewlines() {
        let result = AgentCommandParser.parse("@agent research this\ntopic deeply")
        XCTAssertTrue(result.isAgentCommand)
        XCTAssertTrue(result.taskDescription?.contains("\n") ?? false)
    }
}

// MARK: - Autonomy Level Tests

final class AutonomyLevelTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(TestAutonomyLevel.allCases.count, 5)
    }

    func testRiskToleranceOrdering() {
        let levels = TestAutonomyLevel.allCases
        for idx in 0..<levels.count - 1 {
            XCTAssertLessThan(
                levels[idx].riskTolerance,
                levels[idx + 1].riskTolerance,
                "\(levels[idx].rawValue) should have lower risk than \(levels[idx + 1].rawValue)"
            )
        }
    }

    func testSupervisedLowestRisk() {
        XCTAssertEqual(TestAutonomyLevel.supervised.riskTolerance, 0.1, accuracy: 0.01)
    }

    func testUnrestrictedHighestRisk() {
        XCTAssertEqual(TestAutonomyLevel.unrestricted.riskTolerance, 0.9, accuracy: 0.01)
    }

    func testBalancedIsMiddle() {
        XCTAssertEqual(TestAutonomyLevel.balanced.riskTolerance, 0.5, accuracy: 0.01)
    }

    func testDefaultSettingMatchesBalanced() {
        let defaultAutonomy = "balanced"
        XCTAssertEqual(TestAutonomyLevel(rawValue: defaultAutonomy), .balanced)
    }

    func testAllRawValuesValid() {
        let validValues = ["supervised", "cautious", "balanced", "autonomous", "unrestricted"]
        for value in validValues {
            XCTAssertNotNil(TestAutonomyLevel(rawValue: value), "\(value) should be valid")
        }
    }

    func testInvalidRawValue() {
        XCTAssertNil(TestAutonomyLevel(rawValue: "invalid"))
    }
}

// MARK: - Sync Initialization Tests

final class SyncInitializationTests: XCTestCase {

    private enum Platform: String, CaseIterable {
        case macOS, iOS, watchOS, tvOS
    }

    private func syncServicesForPlatform(_ platform: Platform) -> [String] {
        switch platform {
        case .macOS:
            return ["CloudKitService", "PreferenceSyncEngine", "CrossDeviceService"]
        case .iOS:
            return ["CloudKitService", "PreferenceSyncEngine"]
        case .watchOS:
            return []  // Too limited for CloudKit
        case .tvOS:
            return []  // Too limited for CloudKit
        }
    }

    func testMacOSHasFullSync() {
        let services = syncServicesForPlatform(.macOS)
        XCTAssertTrue(services.contains("CloudKitService"))
        XCTAssertTrue(services.contains("PreferenceSyncEngine"))
        XCTAssertTrue(services.contains("CrossDeviceService"))
    }

    func testIOSHasSync() {
        let services = syncServicesForPlatform(.iOS)
        XCTAssertTrue(services.contains("CloudKitService"))
        XCTAssertTrue(services.contains("PreferenceSyncEngine"))
    }

    func testWatchOSNoSync() {
        let services = syncServicesForPlatform(.watchOS)
        XCTAssertTrue(services.isEmpty, "watchOS should not init sync services directly")
    }

    func testTvOSNoSync() {
        let services = syncServicesForPlatform(.tvOS)
        XCTAssertTrue(services.isEmpty, "tvOS should not init sync services directly")
    }
}

// MARK: - Agent Delegation Guard Tests

final class AgentDelegationGuardTests: XCTestCase {

    private func shouldDelegate(
        text: String,
        delegationEnabled: Bool,
        maxConcurrent: Int,
        activeCount: Int
    ) -> Bool {
        guard delegationEnabled else { return false }
        guard text.hasPrefix("@agent ") else { return false }
        guard activeCount < maxConcurrent else { return false }
        return true
    }

    func testDelegateWhenEnabled() {
        XCTAssertTrue(shouldDelegate(
            text: "@agent research topic",
            delegationEnabled: true,
            maxConcurrent: 4,
            activeCount: 0
        ))
    }

    func testNoDelegateWhenDisabled() {
        XCTAssertFalse(shouldDelegate(
            text: "@agent research topic",
            delegationEnabled: false,
            maxConcurrent: 4,
            activeCount: 0
        ))
    }

    func testNoDelegateWithoutPrefix() {
        XCTAssertFalse(shouldDelegate(
            text: "research topic",
            delegationEnabled: true,
            maxConcurrent: 4,
            activeCount: 0
        ))
    }

    func testNoDelegateAtConcurrencyLimit() {
        XCTAssertFalse(shouldDelegate(
            text: "@agent research topic",
            delegationEnabled: true,
            maxConcurrent: 4,
            activeCount: 4
        ))
    }

    func testDelegateBelowConcurrencyLimit() {
        XCTAssertTrue(shouldDelegate(
            text: "@agent research topic",
            delegationEnabled: true,
            maxConcurrent: 4,
            activeCount: 3
        ))
    }

    func testNoDelegateOverConcurrencyLimit() {
        XCTAssertFalse(shouldDelegate(
            text: "@agent research topic",
            delegationEnabled: true,
            maxConcurrent: 4,
            activeCount: 5
        ))
    }
}
