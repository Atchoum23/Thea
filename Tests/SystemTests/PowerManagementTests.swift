//
//  PowerManagementTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

import XCTest
@testable import Thea

final class PowerManagementTests: XCTestCase {

    // MARK: - ThrottlingEngine Tests

    func testThrottleLevelPriorities() {
        XCTAssertTrue(ThrottleLevel.none.rawValue < ThrottleLevel.light.rawValue)
        XCTAssertTrue(ThrottleLevel.light.rawValue < ThrottleLevel.moderate.rawValue)
        XCTAssertTrue(ThrottleLevel.moderate.rawValue < ThrottleLevel.heavy.rawValue)
        XCTAssertTrue(ThrottleLevel.heavy.rawValue < ThrottleLevel.critical.rawValue)
    }

    func testThrottleLevelDisplayNames() {
        XCTAssertEqual(ThrottleLevel.none.displayName, "None")
        XCTAssertEqual(ThrottleLevel.light.displayName, "Light")
        XCTAssertEqual(ThrottleLevel.moderate.displayName, "Moderate")
        XCTAssertEqual(ThrottleLevel.heavy.displayName, "Heavy")
        XCTAssertEqual(ThrottleLevel.critical.displayName, "Critical")
    }

    func testThrottleLevelIcons() {
        XCTAssertEqual(ThrottleLevel.none.icon, "bolt.fill")
        XCTAssertEqual(ThrottleLevel.light.icon, "bolt")
        XCTAssertEqual(ThrottleLevel.moderate.icon, "bolt.slash")
        XCTAssertEqual(ThrottleLevel.heavy.icon, "tortoise")
        XCTAssertEqual(ThrottleLevel.critical.icon, "tortoise.fill")
    }

    // MARK: - OptimizationMode Tests

    func testOptimizationModeDisplayNames() {
        XCTAssertEqual(OptimizationMode.performance.displayName, "Performance")
        XCTAssertEqual(OptimizationMode.balanced.displayName, "Balanced")
        XCTAssertEqual(OptimizationMode.maxSaver.displayName, "Battery Saver")
        XCTAssertEqual(OptimizationMode.ultraSaver.displayName, "Ultra Saver")
    }

    // MARK: - PowerStateManager Tests

    @MainActor
    func testPowerStateManagerSingleton() async {
        let manager1 = PowerStateManager.shared
        let manager2 = PowerStateManager.shared
        // Both should be the same instance
        XCTAssertTrue(manager1 === manager2, "Singleton should return same instance")
    }

    // MARK: - AssertionType Tests

    func testAssertionTypeRawValues() {
        XCTAssertEqual(AssertionType.preventUserIdleSystemSleep.rawValue, "preventUserIdleSystemSleep")
        XCTAssertEqual(AssertionType.preventUserIdleDisplaySleep.rawValue, "preventUserIdleDisplaySleep")
        XCTAssertEqual(AssertionType.preventSystemSleep.rawValue, "preventSystemSleep")
    }

    func testAssertionTypeDisplayNames() {
        XCTAssertEqual(AssertionType.preventUserIdleSystemSleep.displayName, "Prevent Idle Sleep")
        XCTAssertEqual(AssertionType.preventUserIdleDisplaySleep.displayName, "Prevent Display Sleep")
    }
}
