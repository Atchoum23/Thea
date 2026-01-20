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

    func testThrottlingLevelPriorities() {
        XCTAssertTrue(ThrottlingLevel.none.rawValue < ThrottlingLevel.light.rawValue)
        XCTAssertTrue(ThrottlingLevel.light.rawValue < ThrottlingLevel.moderate.rawValue)
        XCTAssertTrue(ThrottlingLevel.moderate.rawValue < ThrottlingLevel.aggressive.rawValue)
        XCTAssertTrue(ThrottlingLevel.aggressive.rawValue < ThrottlingLevel.maximum.rawValue)
    }

    func testThrottlingLevelResourceLimits() {
        XCTAssertGreaterThan(ThrottlingLevel.none.maxConcurrentTasks, ThrottlingLevel.light.maxConcurrentTasks)
        XCTAssertGreaterThan(ThrottlingLevel.light.maxConcurrentTasks, ThrottlingLevel.aggressive.maxConcurrentTasks)
        XCTAssertEqual(ThrottlingLevel.maximum.maxConcurrentTasks, 1)
    }

    func testThrottlingIntervals() {
        XCTAssertLessThan(ThrottlingLevel.none.networkPollInterval, ThrottlingLevel.maximum.networkPollInterval)
        XCTAssertGreaterThan(ThrottlingLevel.maximum.taskDelay, ThrottlingLevel.none.taskDelay)
    }

    // MARK: - BatteryOptimizer Tests

    func testOptimizationModeThresholds() {
        // Performance mode should have highest battery threshold
        XCTAssertEqual(OptimizationMode.performance.batteryThreshold, 50)

        // Balanced mode should have middle threshold
        XCTAssertEqual(OptimizationMode.balanced.batteryThreshold, 30)

        // Max saver should have low threshold
        XCTAssertEqual(OptimizationMode.maxSaver.batteryThreshold, 15)

        // Ultra saver should have lowest threshold
        XCTAssertEqual(OptimizationMode.ultraSaver.batteryThreshold, 5)
    }

    func testOptimizationModeDisplayNames() {
        XCTAssertEqual(OptimizationMode.performance.displayName, "Performance")
        XCTAssertEqual(OptimizationMode.balanced.displayName, "Balanced")
        XCTAssertEqual(OptimizationMode.maxSaver.displayName, "Max Battery Saver")
        XCTAssertEqual(OptimizationMode.ultraSaver.displayName, "Ultra Battery Saver")
    }

    // MARK: - PowerStateManager Tests

    func testPowerStateManagerSingleton() async {
        let manager1 = PowerStateManager.shared
        let manager2 = PowerStateManager.shared
        let id1 = await manager1.currentState.batteryLevel
        let id2 = await manager2.currentState.batteryLevel
        XCTAssertEqual(id1, id2, "Singleton should return same instance")
    }

    // MARK: - AssertionManager Tests

    func testAssertionTypeIdentifiers() {
        XCTAssertEqual(AssertionType.preventSleep.identifier, "PreventUserIdleSystemSleep")
        XCTAssertEqual(AssertionType.preventDisplaySleep.identifier, "PreventUserIdleDisplaySleep")
        XCTAssertEqual(AssertionType.preventDiskIdle.identifier, "PreventDiskIdle")
    }
}
