// CrossDeviceSyncTypesTests.swift
// Tests for CrossDeviceService pure logic: conflict merge, status composition,
// configuration persistence, and sync change types.

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum SyncChangeType: String, Codable, Sendable {
    case create
    case update
    case delete
}

private enum ConflictResolutionStrategy: String, Codable, Sendable, CaseIterable {
    case lastWriteWins
    case localWins
    case remoteWins
    case askUser

    var displayName: String {
        switch self {
        case .lastWriteWins: "Last Write Wins"
        case .localWins: "Local Always Wins"
        case .remoteWins: "Remote Always Wins"
        case .askUser: "Ask User"
        }
    }
}

private struct SyncChange: Sendable {
    let id: UUID
    let changeType: SyncChangeType
    let key: String
    let value: String?
    let timestamp: Date
    let deviceID: String

    init(
        id: UUID = UUID(),
        changeType: SyncChangeType,
        key: String,
        value: String? = nil,
        timestamp: Date = Date(),
        deviceID: String = "test-device"
    ) {
        self.id = id
        self.changeType = changeType
        self.key = key
        self.value = value
        self.timestamp = timestamp
        self.deviceID = deviceID
    }
}

private struct SyncConflict: Sendable {
    let localChange: SyncChange
    let remoteChange: SyncChange

    func merge(strategy: ConflictResolutionStrategy = .lastWriteWins) -> SyncChange {
        switch strategy {
        case .lastWriteWins:
            return localChange.timestamp > remoteChange.timestamp ? localChange : remoteChange
        case .localWins:
            return localChange
        case .remoteWins:
            return remoteChange
        case .askUser:
            return localChange
        }
    }
}

private struct SyncStatus: Sendable {
    let isInitialized: Bool
    let isEnabled: Bool
    let iCloudAvailable: Bool
    let lastSyncTime: Date?
    let pendingChanges: Int

    var isReady: Bool {
        isInitialized && isEnabled && iCloudAvailable
    }

    var statusDescription: String {
        if !isInitialized { return "Initializing..." }
        if !isEnabled { return "Sync disabled" }
        if !iCloudAvailable { return "iCloud unavailable" }
        if pendingChanges > 0 { return "\(pendingChanges) pending" }
        return "Ready"
    }
}

private struct CrossDeviceSyncConfiguration: Codable, Sendable {
    var autoSyncEnabled: Bool
    var syncIntervalSeconds: Int
    var maxBatchSize: Int
    var conflictStrategy: ConflictResolutionStrategy

    init(
        autoSyncEnabled: Bool = true,
        syncIntervalSeconds: Int = 300,
        maxBatchSize: Int = 50,
        conflictStrategy: ConflictResolutionStrategy = .lastWriteWins
    ) {
        self.autoSyncEnabled = autoSyncEnabled
        self.syncIntervalSeconds = syncIntervalSeconds
        self.maxBatchSize = maxBatchSize
        self.conflictStrategy = conflictStrategy
    }
}

// MARK: - SyncChangeType Tests

final class SyncChangeTypeTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(SyncChangeType.create.rawValue, "create")
        XCTAssertEqual(SyncChangeType.update.rawValue, "update")
        XCTAssertEqual(SyncChangeType.delete.rawValue, "delete")
    }

    func testCodableRoundTrip() throws {
        for ct in [SyncChangeType.create, .update, .delete] {
            let data = try JSONEncoder().encode(ct)
            let decoded = try JSONDecoder().decode(SyncChangeType.self, from: data)
            XCTAssertEqual(decoded, ct)
        }
    }
}

// MARK: - ConflictResolutionStrategy Tests

final class ConflictResolutionStrategyTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(ConflictResolutionStrategy.allCases.count, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(ConflictResolutionStrategy.lastWriteWins.displayName, "Last Write Wins")
        XCTAssertEqual(ConflictResolutionStrategy.localWins.displayName, "Local Always Wins")
        XCTAssertEqual(ConflictResolutionStrategy.remoteWins.displayName, "Remote Always Wins")
        XCTAssertEqual(ConflictResolutionStrategy.askUser.displayName, "Ask User")
    }

    func testCodableRoundTrip() throws {
        for strategy in ConflictResolutionStrategy.allCases {
            let data = try JSONEncoder().encode(strategy)
            let decoded = try JSONDecoder().decode(ConflictResolutionStrategy.self, from: data)
            XCTAssertEqual(decoded, strategy)
        }
    }

    func testUniqueRawValues() {
        let rawValues = ConflictResolutionStrategy.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }
}

// MARK: - SyncConflict Merge Tests

final class SyncConflictMergeTests: XCTestCase {
    let earlier = Date(timeIntervalSince1970: 1000)
    let later = Date(timeIntervalSince1970: 2000)

    func testLastWriteWinsLocalNewer() {
        let local = SyncChange(changeType: .update, key: "theme", value: "dark", timestamp: later, deviceID: "mac")
        let remote = SyncChange(changeType: .update, key: "theme", value: "light", timestamp: earlier, deviceID: "iphone")
        let conflict = SyncConflict(localChange: local, remoteChange: remote)
        let result = conflict.merge(strategy: .lastWriteWins)
        XCTAssertEqual(result.value, "dark")
        XCTAssertEqual(result.deviceID, "mac")
    }

    func testLastWriteWinsRemoteNewer() {
        let local = SyncChange(changeType: .update, key: "theme", value: "dark", timestamp: earlier, deviceID: "mac")
        let remote = SyncChange(changeType: .update, key: "theme", value: "light", timestamp: later, deviceID: "iphone")
        let conflict = SyncConflict(localChange: local, remoteChange: remote)
        let result = conflict.merge(strategy: .lastWriteWins)
        XCTAssertEqual(result.value, "light")
        XCTAssertEqual(result.deviceID, "iphone")
    }

    func testLastWriteWinsSameTimestamp() {
        let ts = Date()
        let local = SyncChange(changeType: .update, key: "k", value: "a", timestamp: ts, deviceID: "mac")
        let remote = SyncChange(changeType: .update, key: "k", value: "b", timestamp: ts, deviceID: "iphone")
        let conflict = SyncConflict(localChange: local, remoteChange: remote)
        let result = conflict.merge(strategy: .lastWriteWins)
        // When equal, remote wins (not >)
        XCTAssertEqual(result.value, "b")
    }

    func testLocalWinsAlways() {
        let local = SyncChange(changeType: .update, key: "k", value: "local", timestamp: earlier, deviceID: "mac")
        let remote = SyncChange(changeType: .update, key: "k", value: "remote", timestamp: later, deviceID: "iphone")
        let conflict = SyncConflict(localChange: local, remoteChange: remote)
        let result = conflict.merge(strategy: .localWins)
        XCTAssertEqual(result.value, "local")
    }

    func testRemoteWinsAlways() {
        let local = SyncChange(changeType: .update, key: "k", value: "local", timestamp: later, deviceID: "mac")
        let remote = SyncChange(changeType: .update, key: "k", value: "remote", timestamp: earlier, deviceID: "iphone")
        let conflict = SyncConflict(localChange: local, remoteChange: remote)
        let result = conflict.merge(strategy: .remoteWins)
        XCTAssertEqual(result.value, "remote")
    }

    func testAskUserDefaultsToLocal() {
        let local = SyncChange(changeType: .update, key: "k", value: "local", timestamp: earlier, deviceID: "mac")
        let remote = SyncChange(changeType: .update, key: "k", value: "remote", timestamp: later, deviceID: "iphone")
        let conflict = SyncConflict(localChange: local, remoteChange: remote)
        let result = conflict.merge(strategy: .askUser)
        XCTAssertEqual(result.value, "local")
    }

    func testDeleteConflict() {
        let local = SyncChange(changeType: .delete, key: "k", timestamp: later, deviceID: "mac")
        let remote = SyncChange(changeType: .update, key: "k", value: "updated", timestamp: earlier, deviceID: "iphone")
        let conflict = SyncConflict(localChange: local, remoteChange: remote)
        let result = conflict.merge(strategy: .lastWriteWins)
        XCTAssertEqual(result.changeType, .delete)
    }
}

// MARK: - SyncStatus Tests

final class SyncStatusTests: XCTestCase {
    func testIsReadyAllTrue() {
        let status = SyncStatus(
            isInitialized: true, isEnabled: true,
            iCloudAvailable: true, lastSyncTime: Date(), pendingChanges: 0
        )
        XCTAssertTrue(status.isReady)
    }

    func testNotReadyWhenNotInitialized() {
        let status = SyncStatus(
            isInitialized: false, isEnabled: true,
            iCloudAvailable: true, lastSyncTime: nil, pendingChanges: 0
        )
        XCTAssertFalse(status.isReady)
    }

    func testNotReadyWhenDisabled() {
        let status = SyncStatus(
            isInitialized: true, isEnabled: false,
            iCloudAvailable: true, lastSyncTime: nil, pendingChanges: 0
        )
        XCTAssertFalse(status.isReady)
    }

    func testNotReadyWheniCloudUnavailable() {
        let status = SyncStatus(
            isInitialized: true, isEnabled: true,
            iCloudAvailable: false, lastSyncTime: nil, pendingChanges: 0
        )
        XCTAssertFalse(status.isReady)
    }

    func testStatusDescriptionInitializing() {
        let status = SyncStatus(
            isInitialized: false, isEnabled: true,
            iCloudAvailable: true, lastSyncTime: nil, pendingChanges: 0
        )
        XCTAssertEqual(status.statusDescription, "Initializing...")
    }

    func testStatusDescriptionDisabled() {
        let status = SyncStatus(
            isInitialized: true, isEnabled: false,
            iCloudAvailable: true, lastSyncTime: nil, pendingChanges: 0
        )
        XCTAssertEqual(status.statusDescription, "Sync disabled")
    }

    func testStatusDescriptioniCloudUnavailable() {
        let status = SyncStatus(
            isInitialized: true, isEnabled: true,
            iCloudAvailable: false, lastSyncTime: nil, pendingChanges: 0
        )
        XCTAssertEqual(status.statusDescription, "iCloud unavailable")
    }

    func testStatusDescriptionPending() {
        let status = SyncStatus(
            isInitialized: true, isEnabled: true,
            iCloudAvailable: true, lastSyncTime: Date(), pendingChanges: 5
        )
        XCTAssertEqual(status.statusDescription, "5 pending")
    }

    func testStatusDescriptionReady() {
        let status = SyncStatus(
            isInitialized: true, isEnabled: true,
            iCloudAvailable: true, lastSyncTime: Date(), pendingChanges: 0
        )
        XCTAssertEqual(status.statusDescription, "Ready")
    }
}

// MARK: - Configuration Tests

final class CrossDeviceSyncConfigurationTests: XCTestCase {
    func testDefaults() {
        let config = CrossDeviceSyncConfiguration()
        XCTAssertTrue(config.autoSyncEnabled)
        XCTAssertEqual(config.syncIntervalSeconds, 300)
        XCTAssertEqual(config.maxBatchSize, 50)
        XCTAssertEqual(config.conflictStrategy, .lastWriteWins)
    }

    func testCustomValues() {
        let config = CrossDeviceSyncConfiguration(
            autoSyncEnabled: false,
            syncIntervalSeconds: 60,
            maxBatchSize: 100,
            conflictStrategy: .remoteWins
        )
        XCTAssertFalse(config.autoSyncEnabled)
        XCTAssertEqual(config.syncIntervalSeconds, 60)
        XCTAssertEqual(config.maxBatchSize, 100)
        XCTAssertEqual(config.conflictStrategy, .remoteWins)
    }

    func testCodableRoundTrip() throws {
        let original = CrossDeviceSyncConfiguration(
            autoSyncEnabled: false,
            syncIntervalSeconds: 120,
            maxBatchSize: 25,
            conflictStrategy: .askUser
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CrossDeviceSyncConfiguration.self, from: data)
        XCTAssertEqual(decoded.autoSyncEnabled, false)
        XCTAssertEqual(decoded.syncIntervalSeconds, 120)
        XCTAssertEqual(decoded.maxBatchSize, 25)
        XCTAssertEqual(decoded.conflictStrategy, .askUser)
    }
}
