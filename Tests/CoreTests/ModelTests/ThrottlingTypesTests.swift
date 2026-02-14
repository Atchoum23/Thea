// ThrottlingTypesTests.swift
// Tests for ThrottleLevel, OperationCategory, OperationPriority,
// ThrottlingConfiguration, and ThrottlingError types.
// Mirrors types from Shared/System/ThrottlingEngine.swift.

import Foundation
import XCTest

// MARK: - Mirror Types

private enum ThrottleLevel: Int, Codable, CaseIterable, Comparable {
    case none = 0, light = 1, moderate = 2, heavy = 3, critical = 4

    static func < (lhs: ThrottleLevel, rhs: ThrottleLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .none: "None"
        case .light: "Light"
        case .moderate: "Moderate"
        case .heavy: "Heavy"
        case .critical: "Critical"
        }
    }

    var icon: String {
        switch self {
        case .none: "bolt.fill"
        case .light: "bolt"
        case .moderate: "bolt.slash"
        case .heavy: "tortoise"
        case .critical: "tortoise.fill"
        }
    }

    var delayMultiplier: Double {
        switch self {
        case .none: 0.0
        case .light: 0.5
        case .moderate: 1.0
        case .heavy: 2.0
        case .critical: 5.0
        }
    }

    var concurrencyMultiplier: Double {
        switch self {
        case .none: 1.0
        case .light: 0.8
        case .moderate: 0.5
        case .heavy: 0.25
        case .critical: 0.1
        }
    }
}

private enum OperationPriority: Int, Codable, Comparable {
    case background = 0, low = 1, normal = 2, high = 3, critical = 4

    static func < (lhs: OperationPriority, rhs: OperationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private enum OperationCategory: String, Codable {
    case aiRequest, fileOperation, networkRequest, backgroundSync, uiUpdate, indexing

    var priority: OperationPriority {
        switch self {
        case .aiRequest: .high
        case .uiUpdate: .high
        case .fileOperation: .normal
        case .networkRequest: .normal
        case .backgroundSync: .background
        case .indexing: .background
        }
    }

    var baseDelay: TimeInterval {
        switch self {
        case .aiRequest: 0.5
        case .uiUpdate: 0.1
        case .fileOperation: 0.2
        case .networkRequest: 0.3
        case .backgroundSync: 1.0
        case .indexing: 2.0
        }
    }

    var baseConcurrency: Int {
        switch self {
        case .aiRequest: 2
        case .uiUpdate: 10
        case .fileOperation: 4
        case .networkRequest: 6
        case .backgroundSync: 2
        case .indexing: 1
        }
    }
}

private struct ThrottlingConfiguration: Codable, Equatable {
    var enabled: Bool = true
    var throttleOnBattery: Bool = true
    var respectLowPowerMode: Bool = true
    var lightThrottleBatteryThreshold: Int = 50
    var heavyThrottleBatteryThreshold: Int = 20
    var criticalBatteryThreshold: Int = 10
    var allowManualOverride: Bool = true
}

private enum ThrottlingError: Error, LocalizedError {
    case operationDeferred
    case throttlingDisabled

    var errorDescription: String? {
        switch self {
        case .operationDeferred: "Operation deferred due to throttling"
        case .throttlingDisabled: "Throttling is disabled"
        }
    }
}

// MARK: - ThrottleLevel Tests

final class ThrottleLevelTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ThrottleLevel.allCases.count, 5)
    }

    func testRawValues() {
        XCTAssertEqual(ThrottleLevel.none.rawValue, 0)
        XCTAssertEqual(ThrottleLevel.light.rawValue, 1)
        XCTAssertEqual(ThrottleLevel.moderate.rawValue, 2)
        XCTAssertEqual(ThrottleLevel.heavy.rawValue, 3)
        XCTAssertEqual(ThrottleLevel.critical.rawValue, 4)
    }

    func testComparison() {
        XCTAssertTrue(ThrottleLevel.none < .light)
        XCTAssertTrue(ThrottleLevel.light < .moderate)
        XCTAssertTrue(ThrottleLevel.moderate < .heavy)
        XCTAssertTrue(ThrottleLevel.heavy < .critical)
        XCTAssertFalse(ThrottleLevel.critical < .none)
    }

    func testSorting() {
        let shuffled: [ThrottleLevel] = [.critical, .none, .heavy, .light, .moderate]
        let sorted = shuffled.sorted()
        XCTAssertEqual(sorted, [.none, .light, .moderate, .heavy, .critical])
    }

    func testDisplayNames() {
        XCTAssertEqual(ThrottleLevel.none.displayName, "None")
        XCTAssertEqual(ThrottleLevel.light.displayName, "Light")
        XCTAssertEqual(ThrottleLevel.moderate.displayName, "Moderate")
        XCTAssertEqual(ThrottleLevel.heavy.displayName, "Heavy")
        XCTAssertEqual(ThrottleLevel.critical.displayName, "Critical")
    }

    func testAllDisplayNamesNonEmpty() {
        for level in ThrottleLevel.allCases {
            XCTAssertFalse(level.displayName.isEmpty)
        }
    }

    func testIcons() {
        XCTAssertEqual(ThrottleLevel.none.icon, "bolt.fill")
        XCTAssertEqual(ThrottleLevel.light.icon, "bolt")
        XCTAssertEqual(ThrottleLevel.moderate.icon, "bolt.slash")
        XCTAssertEqual(ThrottleLevel.heavy.icon, "tortoise")
        XCTAssertEqual(ThrottleLevel.critical.icon, "tortoise.fill")
    }

    func testDelayMultipliers() {
        XCTAssertEqual(ThrottleLevel.none.delayMultiplier, 0.0, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.light.delayMultiplier, 0.5, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.moderate.delayMultiplier, 1.0, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.heavy.delayMultiplier, 2.0, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.critical.delayMultiplier, 5.0, accuracy: 0.001)
    }

    func testDelayMultipliersIncrease() {
        let multipliers = ThrottleLevel.allCases.map(\.delayMultiplier)
        for i in 1..<multipliers.count {
            XCTAssertGreaterThan(multipliers[i], multipliers[i - 1],
                                 "\(ThrottleLevel.allCases[i]) delay should be > \(ThrottleLevel.allCases[i - 1])")
        }
    }

    func testConcurrencyMultipliers() {
        XCTAssertEqual(ThrottleLevel.none.concurrencyMultiplier, 1.0, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.light.concurrencyMultiplier, 0.8, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.moderate.concurrencyMultiplier, 0.5, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.heavy.concurrencyMultiplier, 0.25, accuracy: 0.001)
        XCTAssertEqual(ThrottleLevel.critical.concurrencyMultiplier, 0.1, accuracy: 0.001)
    }

    func testConcurrencyMultipliersDecrease() {
        let multipliers = ThrottleLevel.allCases.map(\.concurrencyMultiplier)
        for i in 1..<multipliers.count {
            XCTAssertLessThan(multipliers[i], multipliers[i - 1],
                              "\(ThrottleLevel.allCases[i]) concurrency should be < \(ThrottleLevel.allCases[i - 1])")
        }
    }

    func testConcurrencyMultipliersPositive() {
        for level in ThrottleLevel.allCases {
            XCTAssertGreaterThan(level.concurrencyMultiplier, 0.0)
        }
    }

    func testCodableRoundTrip() throws {
        for level in ThrottleLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(ThrottleLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }

    func testOperationDelay() {
        // delay = baseDelay * delayMultiplier
        let aiDelay = OperationCategory.aiRequest.baseDelay * ThrottleLevel.heavy.delayMultiplier
        XCTAssertEqual(aiDelay, 1.0, accuracy: 0.001) // 0.5 * 2.0
    }

    func testConcurrencyLimit() {
        // limit = max(1, Int(baseConcurrency * concurrencyMultiplier))
        let limit = max(1, Int(Double(OperationCategory.uiUpdate.baseConcurrency) * ThrottleLevel.critical.concurrencyMultiplier))
        XCTAssertEqual(limit, 1) // max(1, Int(10 * 0.1)) = max(1, 1)
    }
}

// MARK: - OperationPriority Tests

final class OperationPriorityTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(OperationPriority.background.rawValue, 0)
        XCTAssertEqual(OperationPriority.low.rawValue, 1)
        XCTAssertEqual(OperationPriority.normal.rawValue, 2)
        XCTAssertEqual(OperationPriority.high.rawValue, 3)
        XCTAssertEqual(OperationPriority.critical.rawValue, 4)
    }

    func testComparison() {
        XCTAssertTrue(OperationPriority.background < .low)
        XCTAssertTrue(OperationPriority.low < .normal)
        XCTAssertTrue(OperationPriority.normal < .high)
        XCTAssertTrue(OperationPriority.high < .critical)
    }

    func testSorting() {
        let shuffled: [OperationPriority] = [.high, .background, .critical, .normal, .low]
        let sorted = shuffled.sorted()
        XCTAssertEqual(sorted, [.background, .low, .normal, .high, .critical])
    }

    func testCodableRoundTrip() throws {
        let priorities: [OperationPriority] = [.background, .low, .normal, .high, .critical]
        for priority in priorities {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(OperationPriority.self, from: data)
            XCTAssertEqual(decoded, priority)
        }
    }
}

// MARK: - OperationCategory Tests

final class OperationCategoryTests: XCTestCase {

    func testAllCategories() {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        XCTAssertEqual(categories.count, 6)
    }

    func testPriorityMapping() {
        XCTAssertEqual(OperationCategory.aiRequest.priority, .high)
        XCTAssertEqual(OperationCategory.uiUpdate.priority, .high)
        XCTAssertEqual(OperationCategory.fileOperation.priority, .normal)
        XCTAssertEqual(OperationCategory.networkRequest.priority, .normal)
        XCTAssertEqual(OperationCategory.backgroundSync.priority, .background)
        XCTAssertEqual(OperationCategory.indexing.priority, .background)
    }

    func testBaseDelays() {
        XCTAssertEqual(OperationCategory.aiRequest.baseDelay, 0.5, accuracy: 0.001)
        XCTAssertEqual(OperationCategory.uiUpdate.baseDelay, 0.1, accuracy: 0.001)
        XCTAssertEqual(OperationCategory.fileOperation.baseDelay, 0.2, accuracy: 0.001)
        XCTAssertEqual(OperationCategory.networkRequest.baseDelay, 0.3, accuracy: 0.001)
        XCTAssertEqual(OperationCategory.backgroundSync.baseDelay, 1.0, accuracy: 0.001)
        XCTAssertEqual(OperationCategory.indexing.baseDelay, 2.0, accuracy: 0.001)
    }

    func testAllBaseDelaysPositive() {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        for cat in categories {
            XCTAssertGreaterThan(cat.baseDelay, 0.0, "\(cat) should have positive delay")
        }
    }

    func testBaseConcurrency() {
        XCTAssertEqual(OperationCategory.aiRequest.baseConcurrency, 2)
        XCTAssertEqual(OperationCategory.uiUpdate.baseConcurrency, 10)
        XCTAssertEqual(OperationCategory.fileOperation.baseConcurrency, 4)
        XCTAssertEqual(OperationCategory.networkRequest.baseConcurrency, 6)
        XCTAssertEqual(OperationCategory.backgroundSync.baseConcurrency, 2)
        XCTAssertEqual(OperationCategory.indexing.baseConcurrency, 1)
    }

    func testAllBaseConcurrencyPositive() {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        for cat in categories {
            XCTAssertGreaterThan(cat.baseConcurrency, 0, "\(cat) should have positive concurrency")
        }
    }

    func testUIUpdateHasLowestDelay() {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        let uiDelay = OperationCategory.uiUpdate.baseDelay
        for cat in categories where cat != .uiUpdate {
            XCTAssertGreaterThanOrEqual(cat.baseDelay, uiDelay,
                                        "uiUpdate should have lowest or equal delay")
        }
    }

    func testIndexingHasLowestConcurrency() {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        let indexConcurrency = OperationCategory.indexing.baseConcurrency
        for cat in categories where cat != .indexing {
            XCTAssertGreaterThanOrEqual(cat.baseConcurrency, indexConcurrency)
        }
    }

    func testCodableRoundTrip() throws {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        for cat in categories {
            let data = try JSONEncoder().encode(cat)
            let decoded = try JSONDecoder().decode(OperationCategory.self, from: data)
            XCTAssertEqual(decoded, cat)
        }
    }
}

// MARK: - ThrottlingConfiguration Tests

final class ThrottlingConfigurationTests: XCTestCase {

    func testDefaults() {
        let config = ThrottlingConfiguration()
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.throttleOnBattery)
        XCTAssertTrue(config.respectLowPowerMode)
        XCTAssertEqual(config.lightThrottleBatteryThreshold, 50)
        XCTAssertEqual(config.heavyThrottleBatteryThreshold, 20)
        XCTAssertEqual(config.criticalBatteryThreshold, 10)
        XCTAssertTrue(config.allowManualOverride)
    }

    func testThresholdOrdering() {
        let config = ThrottlingConfiguration()
        XCTAssertGreaterThan(config.lightThrottleBatteryThreshold, config.heavyThrottleBatteryThreshold)
        XCTAssertGreaterThan(config.heavyThrottleBatteryThreshold, config.criticalBatteryThreshold)
    }

    func testCodableRoundTrip() throws {
        var config = ThrottlingConfiguration()
        config.enabled = false
        config.criticalBatteryThreshold = 5
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ThrottlingConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testEquatable() {
        let config1 = ThrottlingConfiguration()
        var config2 = ThrottlingConfiguration()
        XCTAssertEqual(config1, config2)
        config2.enabled = false
        XCTAssertNotEqual(config1, config2)
    }

    func testMutation() {
        var config = ThrottlingConfiguration()
        config.lightThrottleBatteryThreshold = 70
        config.heavyThrottleBatteryThreshold = 30
        config.criticalBatteryThreshold = 15
        XCTAssertEqual(config.lightThrottleBatteryThreshold, 70)
        XCTAssertEqual(config.heavyThrottleBatteryThreshold, 30)
        XCTAssertEqual(config.criticalBatteryThreshold, 15)
    }
}

// MARK: - ThrottlingError Tests

final class ThrottlingErrorTests: XCTestCase {

    func testOperationDeferredDescription() {
        let error = ThrottlingError.operationDeferred
        XCTAssertEqual(error.errorDescription, "Operation deferred due to throttling")
    }

    func testThrottlingDisabledDescription() {
        let error = ThrottlingError.throttlingDisabled
        XCTAssertEqual(error.errorDescription, "Throttling is disabled")
    }

    func testDistinctDescriptions() {
        XCTAssertNotEqual(
            ThrottlingError.operationDeferred.errorDescription,
            ThrottlingError.throttlingDisabled.errorDescription
        )
    }
}

// MARK: - Deferral Logic Tests

final class DeferralLogicTests: XCTestCase {

    // Mirror the shouldDefer logic from ThrottlingEngine
    private func shouldDefer(level: ThrottleLevel, category: OperationCategory) -> Bool {
        guard level != .none else { return false }
        switch (level, category.priority) {
        case (.critical, _):
            return category.priority != .critical
        case (.heavy, .low), (.heavy, .background):
            return true
        case (.moderate, .background):
            return true
        default:
            return false
        }
    }

    func testNoDeferralWhenNone() {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        for cat in categories {
            XCTAssertFalse(shouldDefer(level: .none, category: cat))
        }
    }

    func testCriticalDefersEverythingExceptCritical() {
        XCTAssertTrue(shouldDefer(level: .critical, category: .aiRequest))
        XCTAssertTrue(shouldDefer(level: .critical, category: .backgroundSync))
        XCTAssertTrue(shouldDefer(level: .critical, category: .indexing))
        XCTAssertTrue(shouldDefer(level: .critical, category: .uiUpdate))
    }

    func testHeavyDefersLowAndBackground() {
        XCTAssertTrue(shouldDefer(level: .heavy, category: .backgroundSync))
        XCTAssertTrue(shouldDefer(level: .heavy, category: .indexing))
        XCTAssertFalse(shouldDefer(level: .heavy, category: .aiRequest))
        XCTAssertFalse(shouldDefer(level: .heavy, category: .uiUpdate))
    }

    func testModerateDefersOnlyBackground() {
        XCTAssertTrue(shouldDefer(level: .moderate, category: .backgroundSync))
        XCTAssertTrue(shouldDefer(level: .moderate, category: .indexing))
        XCTAssertFalse(shouldDefer(level: .moderate, category: .aiRequest))
        XCTAssertFalse(shouldDefer(level: .moderate, category: .fileOperation))
    }

    func testLightDefersNothing() {
        let categories: [OperationCategory] = [
            .aiRequest, .fileOperation, .networkRequest,
            .backgroundSync, .uiUpdate, .indexing
        ]
        for cat in categories {
            XCTAssertFalse(shouldDefer(level: .light, category: cat))
        }
    }
}
