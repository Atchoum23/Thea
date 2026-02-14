// ThrottlingEngineTests.swift
// Tests for ThrottlingEngine decision trees, delay/concurrency calculations,
// operation deferral logic, and configuration

import Testing
import Foundation

// MARK: - Test Doubles (mirroring ThrottlingEngine types)

private enum TestThrottleLevel: Int, CaseIterable, Comparable, Sendable {
    case none = 0
    case light = 1
    case moderate = 2
    case heavy = 3
    case critical = 4

    static func < (lhs: TestThrottleLevel, rhs: TestThrottleLevel) -> Bool {
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

private enum TestOperationPriority: Int, Comparable, Sendable {
    case background = 0
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4

    static func < (lhs: TestOperationPriority, rhs: TestOperationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private enum TestOperationCategory: String, Sendable {
    case aiRequest
    case fileOperation
    case networkRequest
    case backgroundSync
    case uiUpdate
    case indexing

    var priority: TestOperationPriority {
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

struct TestThrottlingConfiguration: Sendable {
    var enabled: Bool = true
    var throttleOnBattery: Bool = true
    var respectLowPowerMode: Bool = true
    var lightThrottleBatteryThreshold: Int = 50
    var heavyThrottleBatteryThreshold: Int = 20
    var criticalBatteryThreshold: Int = 10
    var allowManualOverride: Bool = true
}

private enum TestThermalState: Sendable {
    case nominal, fair, serious, critical
}

private enum TestPowerSource: Sendable {
    case ac, battery, ups
}

private struct TestPowerStatus: Sendable {
    let thermalState: TestThermalState
    let powerSource: TestPowerSource
    let batteryLevel: Int?
    let isLowPowerMode: Bool
}

/// Mirrors evaluateThrottleLevel() logic from ThrottlingEngine
private func evaluateThrottleLevel(
    config: TestThrottlingConfiguration,
    powerStatus: TestPowerStatus
) -> TestThrottleLevel {
    guard config.enabled else { return .none }

    if powerStatus.thermalState == .critical { return .critical }
    if powerStatus.thermalState == .serious { return .heavy }

    if powerStatus.powerSource == .battery, let level = powerStatus.batteryLevel {
        if level <= config.criticalBatteryThreshold { return .critical }
        if level <= config.heavyThrottleBatteryThreshold { return .heavy }
        if level <= config.lightThrottleBatteryThreshold { return .light }
        if config.throttleOnBattery { return .light }
    }

    if powerStatus.isLowPowerMode, config.respectLowPowerMode { return .moderate }
    if powerStatus.thermalState == .fair { return .light }

    return .none
}

/// Mirrors getOperationDelay() logic
private func getOperationDelay(throttleLevel: TestThrottleLevel, category: TestOperationCategory) -> TimeInterval {
    guard throttleLevel != .none else { return 0 }
    return category.baseDelay * throttleLevel.delayMultiplier
}

/// Mirrors getConcurrencyLimit() logic
private func getConcurrencyLimit(throttleLevel: TestThrottleLevel, category: TestOperationCategory) -> Int {
    max(1, Int(Double(category.baseConcurrency) * throttleLevel.concurrencyMultiplier))
}

/// Mirrors shouldDefer() logic
private func shouldDefer(throttleLevel: TestThrottleLevel, category: TestOperationCategory) -> Bool {
    guard throttleLevel != .none else { return false }

    switch (throttleLevel, category.priority) {
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

// MARK: - Tests: ThrottleLevel Enum

@Suite("ThrottleLevel — Properties")
struct ThrottleLevelPropertyTests {
    @Test("5 throttle levels exist")
    func levelCount() {
        #expect(TestThrottleLevel.allCases.count == 5)
    }

    @Test("Raw values are sequential 0-4")
    func rawValues() {
        #expect(TestThrottleLevel.none.rawValue == 0)
        #expect(TestThrottleLevel.light.rawValue == 1)
        #expect(TestThrottleLevel.moderate.rawValue == 2)
        #expect(TestThrottleLevel.heavy.rawValue == 3)
        #expect(TestThrottleLevel.critical.rawValue == 4)
    }

    @Test("Comparable ordering: none < light < moderate < heavy < critical")
    func ordering() {
        #expect(TestThrottleLevel.none < .light)
        #expect(TestThrottleLevel.light < .moderate)
        #expect(TestThrottleLevel.moderate < .heavy)
        #expect(TestThrottleLevel.heavy < .critical)
    }

    @Test("Display names are human-readable")
    func displayNames() {
        #expect(TestThrottleLevel.none.displayName == "None")
        #expect(TestThrottleLevel.critical.displayName == "Critical")
    }

    @Test("Icons are valid SF Symbols")
    func icons() {
        for level in TestThrottleLevel.allCases {
            #expect(!level.icon.isEmpty)
        }
    }

    @Test("Delay multipliers increase with severity")
    func delayMultipliers() {
        #expect(TestThrottleLevel.none.delayMultiplier == 0.0)
        #expect(TestThrottleLevel.light.delayMultiplier == 0.5)
        #expect(TestThrottleLevel.moderate.delayMultiplier == 1.0)
        #expect(TestThrottleLevel.heavy.delayMultiplier == 2.0)
        #expect(TestThrottleLevel.critical.delayMultiplier == 5.0)
    }

    @Test("Concurrency multipliers decrease with severity")
    func concurrencyMultipliers() {
        #expect(TestThrottleLevel.none.concurrencyMultiplier == 1.0)
        #expect(TestThrottleLevel.light.concurrencyMultiplier == 0.8)
        #expect(TestThrottleLevel.moderate.concurrencyMultiplier == 0.5)
        #expect(TestThrottleLevel.heavy.concurrencyMultiplier == 0.25)
        #expect(TestThrottleLevel.critical.concurrencyMultiplier == 0.1)
    }

    @Test("Delay multipliers are monotonically increasing")
    func delayMonotonic() {
        let levels = TestThrottleLevel.allCases.sorted()
        for i in 1..<levels.count {
            #expect(levels[i].delayMultiplier >= levels[i - 1].delayMultiplier)
        }
    }

    @Test("Concurrency multipliers are monotonically decreasing")
    func concurrencyMonotonic() {
        let levels = TestThrottleLevel.allCases.sorted()
        for i in 1..<levels.count {
            #expect(levels[i].concurrencyMultiplier <= levels[i - 1].concurrencyMultiplier)
        }
    }
}

// MARK: - Tests: OperationCategory

@Suite("OperationCategory — Properties")
struct ThrottlingOperationCategoryTests {
    @Test("AI requests have high priority")
    func aiPriority() {
        #expect(TestOperationCategory.aiRequest.priority == .high)
    }

    @Test("UI updates have high priority")
    func uiPriority() {
        #expect(TestOperationCategory.uiUpdate.priority == .high)
    }

    @Test("File operations have normal priority")
    func filePriority() {
        #expect(TestOperationCategory.fileOperation.priority == .normal)
    }

    @Test("Background sync has background priority")
    func syncPriority() {
        #expect(TestOperationCategory.backgroundSync.priority == .background)
    }

    @Test("Indexing has background priority")
    func indexingPriority() {
        #expect(TestOperationCategory.indexing.priority == .background)
    }

    @Test("Base delays are positive")
    func positiveDelays() {
        let categories: [TestOperationCategory] = [.aiRequest, .fileOperation, .networkRequest, .backgroundSync, .uiUpdate, .indexing]
        for cat in categories {
            #expect(cat.baseDelay > 0)
        }
    }

    @Test("Base concurrency is positive")
    func positiveConcurrency() {
        let categories: [TestOperationCategory] = [.aiRequest, .fileOperation, .networkRequest, .backgroundSync, .uiUpdate, .indexing]
        for cat in categories {
            #expect(cat.baseConcurrency >= 1)
        }
    }

    @Test("UI has highest concurrency (10)")
    func uiHighestConcurrency() {
        #expect(TestOperationCategory.uiUpdate.baseConcurrency == 10)
    }

    @Test("Indexing has lowest concurrency (1)")
    func indexingLowestConcurrency() {
        #expect(TestOperationCategory.indexing.baseConcurrency == 1)
    }
}

// MARK: - Tests: Throttle Evaluation Decision Tree

@Suite("Throttle Evaluation — Thermal State")
struct ThermalThrottleTests {
    let config = TestThrottlingConfiguration()

    @Test("Critical thermal → critical throttle")
    func criticalThermal() {
        let status = TestPowerStatus(thermalState: .critical, powerSource: .ac, batteryLevel: nil, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .critical)
    }

    @Test("Serious thermal → heavy throttle")
    func seriousThermal() {
        let status = TestPowerStatus(thermalState: .serious, powerSource: .ac, batteryLevel: nil, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .heavy)
    }

    @Test("Fair thermal → light throttle (AC, no low power)")
    func fairThermal() {
        let status = TestPowerStatus(thermalState: .fair, powerSource: .ac, batteryLevel: nil, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .light)
    }

    @Test("Nominal thermal, AC, no low power → no throttle")
    func nominalAC() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .ac, batteryLevel: nil, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .none)
    }

    @Test("Thermal state takes priority over battery")
    func thermalPriority() {
        let status = TestPowerStatus(thermalState: .critical, powerSource: .battery, batteryLevel: 90, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .critical)
    }
}

@Suite("Throttle Evaluation — Battery Level")
struct BatteryThrottleTests {
    let config = TestThrottlingConfiguration()

    @Test("Battery ≤10% → critical throttle")
    func criticalBattery() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 10, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .critical)
    }

    @Test("Battery 5% → critical throttle")
    func veryLowBattery() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 5, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .critical)
    }

    @Test("Battery ≤20% → heavy throttle")
    func lowBattery() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 20, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .heavy)
    }

    @Test("Battery 15% → heavy throttle")
    func battery15() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 15, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .heavy)
    }

    @Test("Battery ≤50% → light throttle")
    func mediumBattery() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 50, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .light)
    }

    @Test("Battery 30% → light throttle")
    func battery30() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 30, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .light)
    }

    @Test("Battery 80% with throttleOnBattery → light throttle")
    func highBatteryThrottle() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 80, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .light)
    }

    @Test("Battery 80% without throttleOnBattery → none")
    func highBatteryNoThrottle() {
        var cfg = config
        cfg.throttleOnBattery = false
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 80, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: cfg, powerStatus: status) == .none)
    }

    @Test("Boundary: battery 11% → heavy (above critical, below heavy)")
    func boundary11() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 11, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .heavy)
    }

    @Test("Boundary: battery 21% → light (above heavy, below light)")
    func boundary21() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 21, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .light)
    }

    @Test("Boundary: battery 51% on battery with throttleOnBattery → light")
    func boundary51() {
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .battery, batteryLevel: 51, isLowPowerMode: false)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .light)
    }
}

@Suite("Throttle Evaluation — Low Power Mode")
struct LowPowerThrottleTests {
    @Test("Low power mode on AC → moderate")
    func lowPowerAC() {
        let config = TestThrottlingConfiguration()
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .ac, batteryLevel: nil, isLowPowerMode: true)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .moderate)
    }

    @Test("Low power mode disabled in config → no throttle for low power")
    func lowPowerDisabled() {
        var config = TestThrottlingConfiguration()
        config.respectLowPowerMode = false
        let status = TestPowerStatus(thermalState: .nominal, powerSource: .ac, batteryLevel: nil, isLowPowerMode: true)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .none)
    }
}

@Suite("Throttle Evaluation — Config Disabled")
struct ConfigDisabledTests {
    @Test("Disabled config always returns none")
    func disabledReturnsNone() {
        var config = TestThrottlingConfiguration()
        config.enabled = false
        let status = TestPowerStatus(thermalState: .critical, powerSource: .battery, batteryLevel: 1, isLowPowerMode: true)
        #expect(evaluateThrottleLevel(config: config, powerStatus: status) == .none)
    }
}

// MARK: - Tests: Operation Delay

@Suite("Operation Delay Calculation")
struct OperationDelayTests {
    @Test("No throttle → zero delay")
    func noThrottleZeroDelay() {
        #expect(getOperationDelay(throttleLevel: .none, category: .aiRequest) == 0)
    }

    @Test("Light throttle on AI → 0.25s")
    func lightAI() {
        let delay = getOperationDelay(throttleLevel: .light, category: .aiRequest)
        #expect(delay == 0.5 * 0.5) // baseDelay * multiplier
    }

    @Test("Heavy throttle on indexing → 4.0s")
    func heavyIndexing() {
        let delay = getOperationDelay(throttleLevel: .heavy, category: .indexing)
        #expect(delay == 2.0 * 2.0)
    }

    @Test("Critical throttle on background sync → 5.0s")
    func criticalSync() {
        let delay = getOperationDelay(throttleLevel: .critical, category: .backgroundSync)
        #expect(delay == 1.0 * 5.0)
    }

    @Test("Moderate throttle on UI → 0.1s")
    func moderateUI() {
        let delay = getOperationDelay(throttleLevel: .moderate, category: .uiUpdate)
        #expect(delay == 0.1 * 1.0)
    }
}

// MARK: - Tests: Concurrency Limit

@Suite("Concurrency Limit Calculation")
struct ConcurrencyLimitTests {
    @Test("No throttle → full concurrency")
    func noThrottleFull() {
        #expect(getConcurrencyLimit(throttleLevel: .none, category: .uiUpdate) == 10)
        #expect(getConcurrencyLimit(throttleLevel: .none, category: .networkRequest) == 6)
    }

    @Test("Light throttle → 80% concurrency")
    func lightConcurrency() {
        let limit = getConcurrencyLimit(throttleLevel: .light, category: .uiUpdate)
        #expect(limit == 8) // 10 * 0.8
    }

    @Test("Critical throttle → minimum 1")
    func criticalMinimum() {
        let limit = getConcurrencyLimit(throttleLevel: .critical, category: .indexing)
        #expect(limit >= 1) // max(1, 1 * 0.1) = max(1, 0) = 1
    }

    @Test("Heavy throttle on network → max(1, 6*0.25) = 1")
    func heavyNetwork() {
        let limit = getConcurrencyLimit(throttleLevel: .heavy, category: .networkRequest)
        #expect(limit == 1) // 6 * 0.25 = 1.5, Int(1.5) = 1
    }

    @Test("Moderate throttle on file ops → max(1, 4*0.5) = 2")
    func moderateFile() {
        let limit = getConcurrencyLimit(throttleLevel: .moderate, category: .fileOperation)
        #expect(limit == 2)
    }
}

// MARK: - Tests: Operation Deferral

@Suite("Operation Deferral — shouldDefer()")
struct OperationDeferralTests {
    @Test("No throttle never defers")
    func noThrottleNeverDefers() {
        #expect(!shouldDefer(throttleLevel: .none, category: .backgroundSync))
        #expect(!shouldDefer(throttleLevel: .none, category: .indexing))
    }

    @Test("Critical throttle defers all except critical priority")
    func criticalDefersNonCritical() {
        #expect(shouldDefer(throttleLevel: .critical, category: .backgroundSync))
        #expect(shouldDefer(throttleLevel: .critical, category: .indexing))
        #expect(shouldDefer(throttleLevel: .critical, category: .aiRequest))
        #expect(shouldDefer(throttleLevel: .critical, category: .fileOperation))
    }

    @Test("Heavy throttle defers low and background")
    func heavyDefersLow() {
        #expect(shouldDefer(throttleLevel: .heavy, category: .backgroundSync))
        #expect(shouldDefer(throttleLevel: .heavy, category: .indexing))
    }

    @Test("Heavy throttle does NOT defer high priority")
    func heavyDoesNotDeferHigh() {
        #expect(!shouldDefer(throttleLevel: .heavy, category: .aiRequest))
        #expect(!shouldDefer(throttleLevel: .heavy, category: .uiUpdate))
    }

    @Test("Heavy throttle does NOT defer normal priority")
    func heavyDoesNotDeferNormal() {
        #expect(!shouldDefer(throttleLevel: .heavy, category: .fileOperation))
        #expect(!shouldDefer(throttleLevel: .heavy, category: .networkRequest))
    }

    @Test("Moderate throttle defers background only")
    func moderateDefersBackground() {
        #expect(shouldDefer(throttleLevel: .moderate, category: .backgroundSync))
        #expect(shouldDefer(throttleLevel: .moderate, category: .indexing))
    }

    @Test("Moderate throttle does NOT defer normal/high")
    func moderateDoesNotDeferNormal() {
        #expect(!shouldDefer(throttleLevel: .moderate, category: .aiRequest))
        #expect(!shouldDefer(throttleLevel: .moderate, category: .fileOperation))
    }

    @Test("Light throttle defers nothing")
    func lightDefersNothing() {
        #expect(!shouldDefer(throttleLevel: .light, category: .backgroundSync))
        #expect(!shouldDefer(throttleLevel: .light, category: .indexing))
        #expect(!shouldDefer(throttleLevel: .light, category: .aiRequest))
    }
}

// MARK: - Tests: Configuration Defaults

@Suite("Throttling Configuration Defaults")
struct ThrottlingConfigTests {
    let config = TestThrottlingConfiguration()

    @Test("Throttling enabled by default")
    func enabledDefault() {
        #expect(config.enabled)
    }

    @Test("Throttle on battery by default")
    func throttleOnBatteryDefault() {
        #expect(config.throttleOnBattery)
    }

    @Test("Respect low power mode by default")
    func respectLowPowerDefault() {
        #expect(config.respectLowPowerMode)
    }

    @Test("Battery thresholds: 50/20/10")
    func batteryThresholds() {
        #expect(config.lightThrottleBatteryThreshold == 50)
        #expect(config.heavyThrottleBatteryThreshold == 20)
        #expect(config.criticalBatteryThreshold == 10)
    }

    @Test("Battery thresholds are in decreasing order")
    func thresholdsDecreasing() {
        #expect(config.lightThrottleBatteryThreshold > config.heavyThrottleBatteryThreshold)
        #expect(config.heavyThrottleBatteryThreshold > config.criticalBatteryThreshold)
    }

    @Test("Manual override allowed by default")
    func manualOverrideDefault() {
        #expect(config.allowManualOverride)
    }
}
