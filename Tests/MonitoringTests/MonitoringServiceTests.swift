//
//  MonitoringServiceTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

import XCTest
#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif

final class MonitoringServiceTests: XCTestCase {

    // MARK: - MonitorType Tests

    func testMonitorTypeIdentifiers() {
        XCTAssertEqual(MonitorType.appSwitch.rawValue, "appSwitch")
        XCTAssertEqual(MonitorType.idleTime.rawValue, "idleTime")
    }

    func testMonitorTypeDisplayNames() {
        XCTAssertEqual(MonitorType.appSwitch.displayName, "App Switching")
        XCTAssertEqual(MonitorType.idleTime.displayName, "Idle Time")
    }

    // MARK: - ActivityType Tests

    func testActivityTypeIcons() {
        XCTAssertEqual(ActivityType.appUsage.icon, "app")
        XCTAssertEqual(ActivityType.idleStart.icon, "moon.zzz")
        XCTAssertEqual(ActivityType.focusModeChange.icon, "moon")
    }

    // MARK: - ActivityLogEntry Tests

    func testActivityLogEntryCreation() {
        let entry = ActivityLogEntry(
            type: .appUsage,
            timestamp: Date(),
            duration: 300,
            metadata: ["app": "Safari"]
        )
        XCTAssertEqual(entry.type, .appUsage)
        XCTAssertEqual(entry.duration, 300)
    }

    // MARK: - MonitoringConfiguration Tests

    func testDefaultMonitoringConfiguration() {
        let config = MonitoringConfiguration()
        XCTAssertTrue(config.enabledMonitors.contains(.appSwitch))
        XCTAssertTrue(config.enabledMonitors.contains(.idleTime))
    }

    func testCustomMonitoringConfiguration() {
        let config = MonitoringConfiguration(
            enabledMonitors: [.appSwitch],
            samplingInterval: 120,
            idleThresholdMinutes: 10,
            retentionDays: 14
        )
        XCTAssertEqual(config.enabledMonitors.count, 1)
        XCTAssertEqual(config.samplingInterval, 120)
        XCTAssertEqual(config.idleThresholdMinutes, 10)
        XCTAssertEqual(config.retentionDays, 14)
    }

    // MARK: - MonitoringService Tests

    func testMonitoringServiceSingleton() async {
        let service1 = MonitoringService.shared
        let service2 = MonitoringService.shared
        // Both should be the same instance
        XCTAssertTrue(service1 === service2)
    }

    // MARK: - ActivityLogger Tests

    func testActivityLoggerSingleton() async {
        let logger1 = ActivityLogger.shared
        let logger2 = ActivityLogger.shared
        // Both should be the same instance
        XCTAssertTrue(logger1 === logger2)
    }

    // MARK: - PrivacyManager Tests

    func testPrivacyManagerSingleton() async {
        let manager = PrivacyManager.shared
        let hasPermissions = await manager.checkAllPermissions()
        XCTAssertNotNil(hasPermissions)
    }

    func testPrivacyPermissionTypes() {
        XCTAssertEqual(PrivacyPermission.accessibility.displayName, "Accessibility")
        XCTAssertEqual(PrivacyPermission.inputMonitoring.displayName, "Input Monitoring")
        XCTAssertEqual(PrivacyPermission.screenRecording.displayName, "Screen Recording")
    }

    func testPrivacyPermissionIcons() {
        XCTAssertEqual(PrivacyPermission.accessibility.icon, "accessibility")
        XCTAssertEqual(PrivacyPermission.inputMonitoring.icon, "keyboard")
        XCTAssertEqual(PrivacyPermission.screenRecording.icon, "rectangle.dashed.badge.record")
    }
}
