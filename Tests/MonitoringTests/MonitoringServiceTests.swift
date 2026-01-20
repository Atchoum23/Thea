//
//  MonitoringServiceTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

import XCTest
@testable import Thea

final class MonitoringServiceTests: XCTestCase {

    // MARK: - MonitorType Tests

    func testMonitorTypeIdentifiers() {
        XCTAssertEqual(MonitorType.appSwitch.rawValue, "appSwitch")
        XCTAssertEqual(MonitorType.idleTime.rawValue, "idleTime")
        XCTAssertEqual(MonitorType.focusMode.rawValue, "focusMode")
        XCTAssertEqual(MonitorType.screenTime.rawValue, "screenTime")
        XCTAssertEqual(MonitorType.inputActivity.rawValue, "inputActivity")
    }

    // MARK: - MonitorEvent Tests

    func testMonitorEventCreation() {
        let event = MonitorEvent(
            id: "event-1",
            type: .appSwitch,
            timestamp: Date(),
            data: ["app": "Safari"]
        )
        XCTAssertEqual(event.type, .appSwitch)
        XCTAssertNotNil(event.data["app"])
    }

    // MARK: - ActivityEntry Tests

    func testActivityEntryCreation() {
        let entry = ActivityEntry(
            id: "activity-1",
            timestamp: Date(),
            type: .appFocus,
            description: "Switched to Safari",
            metadata: ["bundleId": "com.apple.Safari"]
        )
        XCTAssertEqual(entry.type, .appFocus)
        XCTAssertEqual(entry.description, "Switched to Safari")
    }

    func testActivityTypeIcons() {
        XCTAssertEqual(ActivityType.appFocus.icon, "app")
        XCTAssertEqual(ActivityType.idle.icon, "moon")
        XCTAssertEqual(ActivityType.input.icon, "keyboard")
        XCTAssertEqual(ActivityType.screenTime.icon, "clock")
    }

    // MARK: - MonitoringConfiguration Tests

    func testDefaultMonitoringConfiguration() {
        let config = MonitoringConfiguration()
        XCTAssertTrue(config.enabledMonitors.contains(.appSwitch))
        XCTAssertTrue(config.enabledMonitors.contains(.idleTime))
    }

    func testCustomMonitoringConfiguration() {
        let config = MonitoringConfiguration(
            enabledMonitors: [.focusMode],
            idleThreshold: 600,
            logRetentionDays: 14
        )
        XCTAssertEqual(config.enabledMonitors.count, 1)
        XCTAssertEqual(config.idleThreshold, 600)
        XCTAssertEqual(config.logRetentionDays, 14)
    }

    // MARK: - MonitoringService Tests

    func testMonitoringServiceSingleton() async {
        let service1 = MonitoringService.shared
        let service2 = MonitoringService.shared
        let isMonitoring1 = await service1.isMonitoring
        let isMonitoring2 = await service2.isMonitoring
        XCTAssertEqual(isMonitoring1, isMonitoring2)
    }

    // MARK: - ActivityLogger Tests

    func testActivityLoggerSingleton() async {
        let logger1 = ActivityLogger.shared
        let logger2 = ActivityLogger.shared
        let enabled1 = await logger1.isLoggingEnabled
        let enabled2 = await logger2.isLoggingEnabled
        XCTAssertEqual(enabled1, enabled2)
    }

    // MARK: - ActivityStatistics Tests

    func testActivityStatisticsCreation() {
        let stats = ActivityStatistics(
            totalEntries: 100,
            entriesByType: [.appFocus: 50, .idle: 30, .input: 20],
            mostActiveHour: 14,
            averageIdleTime: 300
        )
        XCTAssertEqual(stats.totalEntries, 100)
        XCTAssertEqual(stats.mostActiveHour, 14)
        XCTAssertEqual(stats.averageIdleTime, 300)
    }

    // MARK: - PrivacyManager Tests

    func testPrivacyManagerSingleton() async {
        let manager = PrivacyManager.shared
        let permissions = await manager.checkAllPermissions()
        XCTAssertNotNil(permissions)
    }

    func testPrivacyPermissionTypes() {
        XCTAssertEqual(PrivacyPermission.accessibility.displayName, "Accessibility")
        XCTAssertEqual(PrivacyPermission.inputMonitoring.displayName, "Input Monitoring")
        XCTAssertEqual(PrivacyPermission.screenRecording.displayName, "Screen Recording")
        XCTAssertEqual(PrivacyPermission.fullDiskAccess.displayName, "Full Disk Access")
    }

    func testPrivacyPermissionIcons() {
        XCTAssertEqual(PrivacyPermission.accessibility.icon, "accessibility")
        XCTAssertEqual(PrivacyPermission.inputMonitoring.icon, "keyboard")
        XCTAssertEqual(PrivacyPermission.screenRecording.icon, "rectangle.on.rectangle")
        XCTAssertEqual(PrivacyPermission.fullDiskAccess.icon, "externaldrive")
    }
}
