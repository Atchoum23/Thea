// SyncTypesExtendedTests.swift
// Tests for sync types: SyncStatus, SyncConflict, ConflictResolution, CrossDeviceSync, Handoff, AppUpdateInfo
// See also: SyncTypesTests.swift for DeviceClass, SyncScope, SyncCategory, PreferenceRegistry, DeviceProfile tests

import Testing
import Foundation

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
