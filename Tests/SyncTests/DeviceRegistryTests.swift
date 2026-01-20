//
//  DeviceRegistryTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

import XCTest
@testable import Thea

final class DeviceRegistryTests: XCTestCase {

    // MARK: - DeviceType Tests

    func testDeviceTypeIcons() {
        XCTAssertEqual(DeviceType.iPhone.icon, "iphone")
        XCTAssertEqual(DeviceType.iPad.icon, "ipad")
        XCTAssertEqual(DeviceType.mac.icon, "laptopcomputer")
        XCTAssertEqual(DeviceType.watch.icon, "applewatch")
        XCTAssertEqual(DeviceType.tv.icon, "appletv")
        XCTAssertEqual(DeviceType.vision.icon, "visionpro")
    }

    func testDeviceTypeDisplayNames() {
        XCTAssertEqual(DeviceType.iPhone.displayName, "iPhone")
        XCTAssertEqual(DeviceType.iPad.displayName, "iPad")
        XCTAssertEqual(DeviceType.mac.displayName, "Mac")
        XCTAssertEqual(DeviceType.watch.displayName, "Apple Watch")
        XCTAssertEqual(DeviceType.tv.displayName, "Apple TV")
        XCTAssertEqual(DeviceType.vision.displayName, "Vision Pro")
    }

    // MARK: - DeviceCapabilities Tests

    func testDefaultCapabilities() {
        let capabilities = DeviceCapabilities()
        XCTAssertTrue(capabilities.canSync)
        XCTAssertTrue(capabilities.canReceiveNotifications)
        XCTAssertFalse(capabilities.canRunBackgroundTasks)
        XCTAssertFalse(capabilities.canAccessFiles)
        XCTAssertFalse(capabilities.canMakeVoiceCalls)
        XCTAssertFalse(capabilities.canControlHomeKit)
    }

    func testCustomCapabilities() {
        let capabilities = DeviceCapabilities(
            canSync: true,
            canReceiveNotifications: true,
            canRunBackgroundTasks: true,
            canAccessFiles: true,
            canMakeVoiceCalls: false,
            canControlHomeKit: true
        )
        XCTAssertTrue(capabilities.canRunBackgroundTasks)
        XCTAssertTrue(capabilities.canAccessFiles)
        XCTAssertTrue(capabilities.canControlHomeKit)
    }

    // MARK: - DeviceInfo Tests

    func testDeviceInfoCreation() {
        let device = DeviceInfo(
            id: "test-device-123",
            name: "Test Device",
            type: .mac,
            appVersion: "1.0.0",
            osVersion: "15.0",
            lastSeen: Date(),
            isOnline: true
        )

        XCTAssertEqual(device.id, "test-device-123")
        XCTAssertEqual(device.name, "Test Device")
        XCTAssertEqual(device.type, .mac)
        XCTAssertTrue(device.isOnline)
    }

    func testDeviceInfoFormattedLastSeen() {
        let now = Date()
        let device = DeviceInfo(
            id: "test",
            name: "Test",
            type: .iPhone,
            appVersion: "1.0",
            osVersion: "17.0",
            lastSeen: now,
            isOnline: false
        )

        // formattedLastSeen should return a non-empty string
        XCTAssertFalse(device.formattedLastSeen.isEmpty)
    }

    // MARK: - DeviceRegistry Tests

    func testDeviceRegistrySingleton() {
        let registry1 = DeviceRegistry.shared
        let registry2 = DeviceRegistry.shared
        XCTAssertTrue(registry1 === registry2, "Should be same instance")
    }

    func testCurrentDevice() {
        let registry = DeviceRegistry.shared
        let currentDevice = registry.currentDevice
        XCTAssertFalse(currentDevice.id.isEmpty, "Current device should have an ID")
        XCTAssertFalse(currentDevice.name.isEmpty, "Current device should have a name")
    }

    // MARK: - SyncStatus Tests

    func testSyncStatusProperties() {
        let status = SyncStatus(
            isEnabled: true,
            isReady: true,
            lastSyncTime: Date(),
            pendingChanges: 5
        )

        XCTAssertTrue(status.isEnabled)
        XCTAssertTrue(status.isReady)
        XCTAssertEqual(status.pendingChanges, 5)
    }

    func testSyncStatusDescriptions() {
        let enabledReady = SyncStatus(isEnabled: true, isReady: true, lastSyncTime: nil, pendingChanges: 0)
        XCTAssertEqual(enabledReady.statusDescription, "Synced")

        let enabledNotReady = SyncStatus(isEnabled: true, isReady: false, lastSyncTime: nil, pendingChanges: 0)
        XCTAssertEqual(enabledNotReady.statusDescription, "Syncing...")

        let disabled = SyncStatus(isEnabled: false, isReady: false, lastSyncTime: nil, pendingChanges: 0)
        XCTAssertEqual(disabled.statusDescription, "Sync Disabled")
    }

    // MARK: - SyncConfiguration Tests

    func testDefaultSyncConfiguration() {
        let config = SyncConfiguration()
        XCTAssertTrue(config.autoSyncEnabled)
        XCTAssertTrue(config.syncConversations)
        XCTAssertTrue(config.syncProjects)
        XCTAssertTrue(config.syncSettings)
        XCTAssertEqual(config.conflictResolution, .lastWriteWins)
    }

    func testConflictResolutionStrategies() {
        XCTAssertEqual(ConflictResolutionStrategy.allCases.count, 4)
        XCTAssertEqual(ConflictResolutionStrategy.lastWriteWins.displayName, "Most Recent Wins")
        XCTAssertEqual(ConflictResolutionStrategy.askUser.displayName, "Ask Me")
    }
}
