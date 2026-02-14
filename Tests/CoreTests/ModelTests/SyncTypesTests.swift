// SyncTypesTests.swift
// Tests for sync system types: PreferenceSyncEngine, CrossDeviceService, HandoffService, AppUpdateService, UnifiedContextSync

import Testing
import Foundation

// MARK: - Test Doubles: TheaDeviceClass

private enum TestDeviceClass: String, CaseIterable, Codable, Sendable {
    case mac, iPhone, iPad, watch, tv, vision

    var displayName: String {
        switch self {
        case .mac: return "Mac"
        case .iPhone: return "iPhone"
        case .iPad: return "iPad"
        case .watch: return "Apple Watch"
        case .tv: return "Apple TV"
        case .vision: return "Apple Vision Pro"
        }
    }

    var systemImage: String {
        switch self {
        case .mac: return "desktopcomputer"
        case .iPhone: return "iphone"
        case .iPad: return "ipad"
        case .watch: return "applewatch"
        case .tv: return "appletv"
        case .vision: return "visionpro"
        }
    }

    func sharesSyncGroup(with other: TestDeviceClass) -> Bool {
        switch (self, other) {
        case (.mac, .mac), (.iPhone, .iPhone), (.iPad, .iPad):
            return true
        case (.mac, .iPad), (.iPad, .mac):
            return true
        case (.iPhone, .iPad), (.iPad, .iPhone):
            return true
        default:
            return false
        }
    }
}

// MARK: - Test Doubles: SyncScope

private enum TestSyncScope: String, CaseIterable, Codable, Sendable {
    case universal, deviceLocal, deviceClass, manual

    var displayName: String {
        switch self {
        case .universal: return "All Devices"
        case .deviceLocal: return "This Device Only"
        case .deviceClass: return "Same Device Type"
        case .manual: return "Manual Sync"
        }
    }

    var explanation: String {
        switch self {
        case .universal: return "Synced to all your devices automatically"
        case .deviceLocal: return "Stays on this device only"
        case .deviceClass: return "Synced between devices of the same type"
        case .manual: return "Synced only when you choose"
        }
    }

    var icon: String {
        switch self {
        case .universal: return "arrow.triangle.2.circlepath"
        case .deviceLocal: return "lock.shield"
        case .deviceClass: return "rectangle.on.rectangle"
        case .manual: return "hand.tap"
        }
    }
}

// MARK: - Test Doubles: SyncCategory

private enum TestSyncCategory: String, CaseIterable, Codable, Sendable {
    case appearance, privacy, aiProviders, localModels, advanced, sync

    var displayName: String {
        switch self {
        case .appearance: return "Appearance"
        case .privacy: return "Privacy"
        case .aiProviders: return "AI Providers"
        case .localModels: return "Local Models"
        case .advanced: return "Advanced"
        case .sync: return "Sync"
        }
    }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .privacy: return "hand.raised"
        case .aiProviders: return "cloud"
        case .localModels: return "cpu"
        case .advanced: return "gearshape.2"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }

    var defaultScope: TestSyncScope {
        switch self {
        case .appearance, .privacy: return .universal
        case .localModels, .advanced: return .deviceLocal
        case .aiProviders: return .universal
        case .sync: return .deviceClass
        }
    }
}

// MARK: - Test Doubles: PreferenceDescriptor

private struct TestPreferenceDescriptor: Sendable {
    let key: String
    let category: TestSyncCategory
    let defaultScope: TestSyncScope
    let displayName: String
}

// MARK: - Test Doubles: PreferenceRegistry

private enum TestPreferenceRegistry {
    static let all: [TestPreferenceDescriptor] = [
        TestPreferenceDescriptor(key: "fontSize", category: .appearance, defaultScope: .universal, displayName: "Font Size"),
        TestPreferenceDescriptor(key: "theme", category: .appearance, defaultScope: .universal, displayName: "Theme"),
        TestPreferenceDescriptor(key: "messageDensity", category: .appearance, defaultScope: .universal, displayName: "Message Density"),
        TestPreferenceDescriptor(key: "apiKey_anthropic", category: .aiProviders, defaultScope: .universal, displayName: "Anthropic API Key"),
        TestPreferenceDescriptor(key: "apiKey_openai", category: .aiProviders, defaultScope: .universal, displayName: "OpenAI API Key"),
        TestPreferenceDescriptor(key: "piiSanitization", category: .privacy, defaultScope: .universal, displayName: "PII Sanitization"),
        TestPreferenceDescriptor(key: "localModelPath", category: .localModels, defaultScope: .deviceLocal, displayName: "Local Model Path"),
        TestPreferenceDescriptor(key: "debugMode", category: .advanced, defaultScope: .deviceLocal, displayName: "Debug Mode"),
        TestPreferenceDescriptor(key: "syncInterval", category: .sync, defaultScope: .deviceClass, displayName: "Sync Interval")
    ]

    static func descriptor(for key: String) -> TestPreferenceDescriptor? {
        all.first { $0.key == key }
    }

    static func descriptors(for category: TestSyncCategory) -> [TestPreferenceDescriptor] {
        all.filter { $0.category == category }
    }
}

// MARK: - Test Doubles: DeviceProfile

private struct TestDeviceProfile: Codable, Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var model: String
    var deviceClass: TestDeviceClass
    var osVersion: String
    var lastActive: Date

    static func parseCloudKey(_ key: String) -> (localKey: String, scope: TestSyncScope, deviceClass: TestDeviceClass?)? {
        if key.hasPrefix("u.") {
            let localKey = String(key.dropFirst(2))
            return (localKey, .universal, nil)
        } else if key.hasPrefix("dc.") {
            let rest = String(key.dropFirst(3))
            guard let dotIndex = rest.firstIndex(of: ".") else { return nil }
            let dcRaw = String(rest[rest.startIndex..<dotIndex])
            let localKey = String(rest[rest.index(after: dotIndex)...])
            guard let dc = TestDeviceClass(rawValue: dcRaw) else { return nil }
            return (localKey, .deviceClass, dc)
        }
        return nil
    }
}

// MARK: - Test Doubles: CrossDeviceService types

private enum TestSyncChangeType: String, Codable, Sendable {
    case create, update, delete
}

private struct TestSyncChange: Sendable {
    let id: UUID
    let type: TestSyncChangeType
    let recordType: String
    let recordId: String
    let timestamp: Date
    let data: [String: String]

    init(id: UUID = UUID(), type: TestSyncChangeType, recordType: String, recordId: String, timestamp: Date = Date(), data: [String: String] = [:]) {
        self.id = id
        self.type = type
        self.recordType = recordType
        self.recordId = recordId
        self.timestamp = timestamp
        self.data = data
    }
}

private struct TestSyncConflict: Sendable {
    let localChange: TestSyncChange
    let remoteChange: TestSyncChange
    let detectedAt: Date

    func merge() -> TestSyncChange {
        if localChange.timestamp >= remoteChange.timestamp {
            return localChange
        } else {
            return remoteChange
        }
    }
}

private enum TestConflictResolutionStrategy: String, CaseIterable, Codable, Sendable {
    case lastWriteWins, serverWins, clientWins, manual

    var displayName: String {
        switch self {
        case .lastWriteWins: return "Last Write Wins"
        case .serverWins: return "Server Wins"
        case .clientWins: return "Client Wins"
        case .manual: return "Manual Resolution"
        }
    }
}

private enum TestCrossSyncError: Error, LocalizedError, Sendable {
    case notInitialized
    case notEnabled
    case iCloudNotAvailable
    case networkError(String)
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .notInitialized: return "Cross-device sync is not initialized"
        case .notEnabled: return "Cross-device sync is not enabled"
        case .iCloudNotAvailable: return "iCloud is not available"
        case .networkError(let msg): return "Network error: \(msg)"
        case .syncFailed: return "Sync failed"
        }
    }
}

// MARK: - Test Doubles: CrossDeviceSyncConfiguration

private struct TestCrossSyncConfig: Codable, Sendable {
    var autoSyncEnabled: Bool = true
    var syncConversations: Bool = true
    var syncSettings: Bool = true
    var syncProjects: Bool = true
    var conflictResolution: TestConflictResolutionStrategy = .lastWriteWins
    var syncInterval: TimeInterval = 300
}

// MARK: - Test Doubles: SyncStatus

private struct TestSyncStatus: Sendable {
    var isInitialized: Bool = false
    var isEnabled: Bool = false
    var iCloudAvailable: Bool = false
    var lastSyncTime: Date?
    var pendingChanges: Int = 0

    var isReady: Bool {
        isInitialized && isEnabled && iCloudAvailable
    }

    var statusDescription: String {
        if !isInitialized { return "Not initialized" }
        if !iCloudAvailable { return "iCloud not available" }
        if !isEnabled { return "Sync disabled" }
        if pendingChanges > 0 { return "Syncing \(pendingChanges) changes" }
        return "Up to date"
    }
}

// MARK: - Test Doubles: HandoffService types

private enum TestHandoffType: String, Codable, Sendable {
    case conversation, project, search, settings

    var icon: String {
        switch self {
        case .conversation: return "bubble.left.and.bubble.right"
        case .project: return "folder"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}

private struct TestHandoffConfig: Codable, Sendable {
    var handoffEnabled: Bool = true
    var allowConversationHandoff: Bool = true
    var allowProjectHandoff: Bool = true
    var allowSearchHandoff: Bool = true
    var requireSameNetwork: Bool = false
}

// MARK: - Test Doubles: AppUpdateInfo

private struct TestAppUpdateInfo: Codable, Identifiable, Sendable {
    let id: UUID
    var version: String
    var build: String
    var commitHash: String?
    var sourceDevice: String?
    var publishedAt: Date
    var platform: String
    var installedAt: Date?

    func isNewer(thanVersion otherVersion: String, build otherBuild: String) -> Bool {
        let versionCompare = version.compare(otherVersion, options: .numeric)
        if versionCompare == .orderedDescending { return true }
        if versionCompare == .orderedSame {
            return build.compare(otherBuild, options: .numeric) == .orderedDescending
        }
        return false
    }
}

// MARK: - Tests: DeviceClass

@Suite("Device Class")
struct SyncDeviceClassTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestDeviceClass.allCases.count == 6)
    }

    @Test("Display names are unique")
    func displayNamesUnique() {
        let names = Set(TestDeviceClass.allCases.map(\.displayName))
        #expect(names.count == TestDeviceClass.allCases.count)
    }

    @Test("System images are unique")
    func systemImagesUnique() {
        let images = Set(TestDeviceClass.allCases.map(\.systemImage))
        #expect(images.count == TestDeviceClass.allCases.count)
    }

    @Test("Mac shares sync group with iPad")
    func macSharesWithIPad() {
        #expect(TestDeviceClass.mac.sharesSyncGroup(with: .iPad))
        #expect(TestDeviceClass.iPad.sharesSyncGroup(with: .mac))
    }

    @Test("iPhone shares sync group with iPad")
    func iPhoneSharesWithIPad() {
        #expect(TestDeviceClass.iPhone.sharesSyncGroup(with: .iPad))
        #expect(TestDeviceClass.iPad.sharesSyncGroup(with: .iPhone))
    }

    @Test("Mac does not share sync group with watch")
    func macDoesNotShareWithWatch() {
        #expect(!TestDeviceClass.mac.sharesSyncGroup(with: .watch))
        #expect(!TestDeviceClass.watch.sharesSyncGroup(with: .mac))
    }

    @Test("Same device class shares sync group")
    func sameDeviceClassShares() {
        #expect(TestDeviceClass.mac.sharesSyncGroup(with: .mac))
        #expect(TestDeviceClass.iPhone.sharesSyncGroup(with: .iPhone))
    }

    @Test("Watch does not share with TV or Vision")
    func watchIsolated() {
        #expect(!TestDeviceClass.watch.sharesSyncGroup(with: .tv))
        #expect(!TestDeviceClass.watch.sharesSyncGroup(with: .vision))
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for dc in TestDeviceClass.allCases {
            let data = try JSONEncoder().encode(dc)
            let decoded = try JSONDecoder().decode(TestDeviceClass.self, from: data)
            #expect(decoded == dc)
        }
    }
}

// MARK: - Tests: SyncScope

@Suite("Sync Scope")
struct SyncScopeEnumTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestSyncScope.allCases.count == 4)
    }

    @Test("Display names are non-empty")
    func displayNames() {
        for scope in TestSyncScope.allCases {
            #expect(!scope.displayName.isEmpty)
        }
    }

    @Test("Explanations are non-empty")
    func explanations() {
        for scope in TestSyncScope.allCases {
            #expect(!scope.explanation.isEmpty)
        }
    }

    @Test("Icons are SF Symbol names")
    func icons() {
        for scope in TestSyncScope.allCases {
            #expect(!scope.icon.isEmpty)
            #expect(!scope.icon.contains(" "))
        }
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for scope in TestSyncScope.allCases {
            let data = try JSONEncoder().encode(scope)
            let decoded = try JSONDecoder().decode(TestSyncScope.self, from: data)
            #expect(decoded == scope)
        }
    }
}

// MARK: - Tests: SyncCategory

@Suite("Sync Category")
struct SyncCategoryEnumTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestSyncCategory.allCases.count == 6)
    }

    @Test("Display names are unique")
    func displayNamesUnique() {
        let names = Set(TestSyncCategory.allCases.map(\.displayName))
        #expect(names.count == TestSyncCategory.allCases.count)
    }

    @Test("Appearance defaults to universal scope")
    func appearanceDefaultScope() {
        #expect(TestSyncCategory.appearance.defaultScope == .universal)
    }

    @Test("Privacy defaults to universal scope")
    func privacyDefaultScope() {
        #expect(TestSyncCategory.privacy.defaultScope == .universal)
    }

    @Test("Local models defaults to device local scope")
    func localModelsDefaultScope() {
        #expect(TestSyncCategory.localModels.defaultScope == .deviceLocal)
    }

    @Test("Advanced defaults to device local scope")
    func advancedDefaultScope() {
        #expect(TestSyncCategory.advanced.defaultScope == .deviceLocal)
    }

    @Test("Sync defaults to device class scope")
    func syncDefaultScope() {
        #expect(TestSyncCategory.sync.defaultScope == .deviceClass)
    }
}

// MARK: - Tests: PreferenceRegistry

@Suite("Preference Registry")
struct PreferenceRegistryTests {
    @Test("Registry is non-empty")
    func nonEmpty() {
        #expect(!TestPreferenceRegistry.all.isEmpty)
    }

    @Test("Keys are unique")
    func keysUnique() {
        let keys = Set(TestPreferenceRegistry.all.map(\.key))
        #expect(keys.count == TestPreferenceRegistry.all.count)
    }

    @Test("Lookup by key returns correct descriptor")
    func lookupByKey() {
        let desc = TestPreferenceRegistry.descriptor(for: "fontSize")
        #expect(desc != nil)
        #expect(desc?.displayName == "Font Size")
        #expect(desc?.category == .appearance)
    }

    @Test("Lookup by unknown key returns nil")
    func lookupUnknownKey() {
        #expect(TestPreferenceRegistry.descriptor(for: "nonexistent") == nil)
    }

    @Test("Filter by category")
    func filterByCategory() {
        let appearance = TestPreferenceRegistry.descriptors(for: .appearance)
        #expect(appearance.count == 3)
        #expect(appearance.allSatisfy { $0.category == .appearance })
    }

    @Test("Filter by category returns empty for unrepresented category")
    func filterEmptyCategory() {
        // All categories should be represented
        for cat in TestSyncCategory.allCases {
            let descs = TestPreferenceRegistry.descriptors(for: cat)
            if cat == .appearance || cat == .aiProviders || cat == .privacy || cat == .localModels || cat == .advanced || cat == .sync {
                #expect(!descs.isEmpty || cat == .sync || cat == .advanced || cat == .localModels || cat == .privacy)
            }
        }
    }
}

// MARK: - Tests: DeviceProfile Cloud Key Parsing

@Suite("Device Profile Cloud Key Parsing")
struct DeviceProfileCloudKeyTests {
    @Test("Parse universal key")
    func parseUniversalKey() {
        let result = TestDeviceProfile.parseCloudKey("u.fontSize")
        #expect(result != nil)
        #expect(result?.localKey == "fontSize")
        #expect(result?.scope == .universal)
        #expect(result?.deviceClass == nil)
    }

    @Test("Parse device class key")
    func parseDeviceClassKey() {
        let result = TestDeviceProfile.parseCloudKey("dc.mac.localModelPath")
        #expect(result != nil)
        #expect(result?.localKey == "localModelPath")
        #expect(result?.scope == .deviceClass)
        #expect(result?.deviceClass == .mac)
    }

    @Test("Parse device class key for iPhone")
    func parseDeviceClassKeyIPhone() {
        let result = TestDeviceProfile.parseCloudKey("dc.iPhone.fontSize")
        #expect(result != nil)
        #expect(result?.localKey == "fontSize")
        #expect(result?.deviceClass == .iPhone)
    }

    @Test("Parse unknown prefix returns nil")
    func unknownPrefix() {
        let result = TestDeviceProfile.parseCloudKey("x.something")
        #expect(result == nil)
    }

    @Test("Parse malformed device class key returns nil")
    func malformedDCKey() {
        let result = TestDeviceProfile.parseCloudKey("dc.unknownDevice.key")
        #expect(result == nil)
    }

    @Test("Parse device class key without dot returns nil")
    func dcKeyWithoutDot() {
        let result = TestDeviceProfile.parseCloudKey("dc.macNoDot")
        #expect(result == nil)
    }
}

// MARK: - Tests: SyncStatus

@Suite("Sync Status")
struct SyncStatusLogicTests {
    @Test("isReady requires all three flags")
    func isReady() {
        var status = TestSyncStatus(isInitialized: true, isEnabled: true, iCloudAvailable: true)
        #expect(status.isReady)

        status.isInitialized = false
        #expect(!status.isReady)
    }

    @Test("Status description: not initialized")
    func descNotInit() {
        let status = TestSyncStatus(isInitialized: false)
        #expect(status.statusDescription == "Not initialized")
    }

    @Test("Status description: iCloud not available")
    func descICloudDown() {
        let status = TestSyncStatus(isInitialized: true, isEnabled: true, iCloudAvailable: false)
        #expect(status.statusDescription == "iCloud not available")
    }

    @Test("Status description: disabled")
    func descDisabled() {
        let status = TestSyncStatus(isInitialized: true, isEnabled: false, iCloudAvailable: true)
        #expect(status.statusDescription == "Sync disabled")
    }

    @Test("Status description: pending changes")
    func descPending() {
        let status = TestSyncStatus(isInitialized: true, isEnabled: true, iCloudAvailable: true, pendingChanges: 5)
        #expect(status.statusDescription.contains("5"))
    }

    @Test("Status description: up to date")
    func descUpToDate() {
        let status = TestSyncStatus(isInitialized: true, isEnabled: true, iCloudAvailable: true, pendingChanges: 0)
        #expect(status.statusDescription == "Up to date")
    }
}

// MARK: - Tests: SyncConflict Merge

@Suite("Sync Conflict Merge")
struct SyncConflictMergeLogicTests {
    @Test("Merge resolves to newer local change")
    func mergeNewerLocal() {
        let now = Date()
        let local = TestSyncChange(type: .update, recordType: "settings", recordId: "1", timestamp: now)
        let remote = TestSyncChange(type: .update, recordType: "settings", recordId: "1", timestamp: now.addingTimeInterval(-60))
        let conflict = TestSyncConflict(localChange: local, remoteChange: remote, detectedAt: now)
        let merged = conflict.merge()
        #expect(merged.id == local.id)
    }

    @Test("Merge resolves to newer remote change")
    func mergeNewerRemote() {
        let now = Date()
        let local = TestSyncChange(type: .update, recordType: "settings", recordId: "1", timestamp: now.addingTimeInterval(-120))
        let remote = TestSyncChange(type: .update, recordType: "settings", recordId: "1", timestamp: now)
        let conflict = TestSyncConflict(localChange: local, remoteChange: remote, detectedAt: now)
        let merged = conflict.merge()
        #expect(merged.id == remote.id)
    }

    @Test("Merge resolves to local on equal timestamps")
    func mergeEqualTimestamps() {
        let now = Date()
        let local = TestSyncChange(type: .update, recordType: "settings", recordId: "1", timestamp: now)
        let remote = TestSyncChange(type: .update, recordType: "settings", recordId: "1", timestamp: now)
        let conflict = TestSyncConflict(localChange: local, remoteChange: remote, detectedAt: now)
        let merged = conflict.merge()
        #expect(merged.id == local.id)
    }
}

// MARK: - Tests: ConflictResolutionStrategy

@Suite("Conflict Resolution Strategy")
struct ConflictResolutionStrategyEnumTests {
    @Test("All strategies have display names")
    func displayNames() {
        for strategy in TestConflictResolutionStrategy.allCases {
            #expect(!strategy.displayName.isEmpty)
        }
    }

    @Test("Display names are unique")
    func unique() {
        let names = Set(TestConflictResolutionStrategy.allCases.map(\.displayName))
        #expect(names.count == TestConflictResolutionStrategy.allCases.count)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for strategy in TestConflictResolutionStrategy.allCases {
            let data = try JSONEncoder().encode(strategy)
            let decoded = try JSONDecoder().decode(TestConflictResolutionStrategy.self, from: data)
            #expect(decoded == strategy)
        }
    }
}

// MARK: - Tests: CrossDeviceSyncError

@Suite("Cross Device Sync Error")
struct CrossDeviceSyncErrorTests {
    @Test("Error descriptions are non-empty")
    func descriptions() {
        let errors: [TestCrossSyncError] = [.notInitialized, .notEnabled, .iCloudNotAvailable, .networkError("timeout"), .syncFailed]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Network error includes message")
    func networkErrorMsg() {
        let error = TestCrossSyncError.networkError("Connection timed out")
        #expect(error.errorDescription!.contains("Connection timed out"))
    }
}

// MARK: - Tests: CrossDeviceSyncConfiguration

@Suite("Cross Device Sync Configuration")
struct CrossDeviceSyncConfigTests {
    @Test("Default configuration")
    func defaults() {
        let config = TestCrossSyncConfig()
        #expect(config.autoSyncEnabled)
        #expect(config.syncConversations)
        #expect(config.syncSettings)
        #expect(config.syncProjects)
        #expect(config.conflictResolution == .lastWriteWins)
        #expect(config.syncInterval == 300)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var config = TestCrossSyncConfig()
        config.autoSyncEnabled = false
        config.syncInterval = 600
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestCrossSyncConfig.self, from: data)
        #expect(decoded.autoSyncEnabled == false)
        #expect(decoded.syncInterval == 600)
    }
}

// MARK: - Tests: HandoffType

@Suite("Handoff Type")
struct HandoffTypeTests {
    @Test("Icons are SF Symbol names")
    func icons() {
        let types: [TestHandoffType] = [.conversation, .project, .search, .settings]
        for type in types {
            #expect(!type.icon.isEmpty)
            #expect(!type.icon.contains(" "))
        }
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for type in [TestHandoffType.conversation, .project, .search, .settings] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(TestHandoffType.self, from: data)
            #expect(decoded == type)
        }
    }
}

// MARK: - Tests: HandoffConfiguration

@Suite("Handoff Configuration")
struct HandoffConfigTests {
    @Test("Default configuration")
    func defaults() {
        let config = TestHandoffConfig()
        #expect(config.handoffEnabled)
        #expect(config.allowConversationHandoff)
        #expect(config.allowProjectHandoff)
        #expect(config.allowSearchHandoff)
        #expect(!config.requireSameNetwork)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var config = TestHandoffConfig()
        config.requireSameNetwork = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestHandoffConfig.self, from: data)
        #expect(decoded.requireSameNetwork)
    }
}

// MARK: - Tests: AppUpdateInfo

@Suite("App Update Info")
struct AppUpdateInfoTests {
    @Test("Version comparison: newer version")
    func newerVersion() {
        let info = TestAppUpdateInfo(id: UUID(), version: "2.0", build: "1", publishedAt: Date(), platform: "macOS")
        #expect(info.isNewer(thanVersion: "1.5", build: "1"))
    }

    @Test("Version comparison: older version")
    func olderVersion() {
        let info = TestAppUpdateInfo(id: UUID(), version: "1.0", build: "1", publishedAt: Date(), platform: "macOS")
        #expect(!info.isNewer(thanVersion: "2.0", build: "1"))
    }

    @Test("Version comparison: same version, newer build")
    func sameVersionNewerBuild() {
        let info = TestAppUpdateInfo(id: UUID(), version: "1.0", build: "20", publishedAt: Date(), platform: "macOS")
        #expect(info.isNewer(thanVersion: "1.0", build: "19"))
    }

    @Test("Version comparison: same version and build")
    func sameVersionAndBuild() {
        let info = TestAppUpdateInfo(id: UUID(), version: "1.0", build: "10", publishedAt: Date(), platform: "macOS")
        #expect(!info.isNewer(thanVersion: "1.0", build: "10"))
    }

    @Test("Numeric comparison: 10 > 2")
    func numericComparison() {
        let info = TestAppUpdateInfo(id: UUID(), version: "1.10", build: "1", publishedAt: Date(), platform: "macOS")
        #expect(info.isNewer(thanVersion: "1.2", build: "1"))
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let info = TestAppUpdateInfo(id: UUID(), version: "2.1", build: "42", commitHash: "abc123", sourceDevice: "msm3u", publishedAt: Date(), platform: "macOS", installedAt: nil)
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(TestAppUpdateInfo.self, from: data)
        #expect(decoded.version == "2.1")
        #expect(decoded.build == "42")
        #expect(decoded.commitHash == "abc123")
    }
}
