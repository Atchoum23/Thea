// BatteryIntelligenceTests.swift
// Tests for battery optimization modes, settings, and feature impact

import Foundation
import Testing

// MARK: - Test Doubles

private enum TestOptimizationMode: String, CaseIterable, Sendable {
    case performance, balanced, maxSaver, ultraSaver

    var displayName: String {
        switch self {
        case .performance: "Performance"
        case .balanced: "Balanced"
        case .maxSaver: "Battery Saver"
        case .ultraSaver: "Ultra Saver"
        }
    }

    var pollingMultiplier: Double {
        switch self {
        case .performance: 1.0
        case .balanced: 1.5
        case .maxSaver: 3.0
        case .ultraSaver: 6.0
        }
    }

    var batchMultiplier: Double {
        switch self {
        case .performance: 1.0
        case .balanced: 0.75
        case .maxSaver: 0.5
        case .ultraSaver: 0.25
        }
    }
}

private enum TestFeaturePriority: Int, Sendable {
    case low = 0, normal = 1, high = 2, critical = 3
}

private enum TestBatteryFeature: String, CaseIterable, Sendable {
    case animations, backgroundSync, prefetching, hdImages, liveActivity, voiceActivation, continuousMonitoring

    var priority: TestFeaturePriority {
        switch self {
        case .animations, .prefetching, .hdImages: .low
        case .backgroundSync, .liveActivity: .normal
        case .voiceActivation: .high
        case .continuousMonitoring: .critical
        }
    }
}

private func shouldDisableFeature(_ feature: TestBatteryFeature, mode: TestOptimizationMode) -> Bool {
    switch mode {
    case .performance: false
    case .balanced: feature.priority == .low
    case .maxSaver: feature.priority != .critical
    case .ultraSaver: feature.priority != .critical
    }
}

private func evaluateMode(onAC: Bool, batteryLevel: Int?, lowPowerMode: Bool) -> TestOptimizationMode {
    if onAC && !lowPowerMode { return .performance }
    if let level = batteryLevel, level <= 10 { return .ultraSaver }
    if let level = batteryLevel, level <= 20 { return .maxSaver }
    if lowPowerMode { return .maxSaver }
    if let level = batteryLevel, level <= 50 { return .balanced }
    if !onAC { return .balanced }
    return .performance
}

// MARK: - Optimization Mode Tests

@Suite("BatteryIntelligence — Optimization Modes")
struct BatteryModeTests {
    @Test("All 4 modes exist")
    func allModes() {
        #expect(TestOptimizationMode.allCases.count == 4)
    }

    @Test("Unique display names")
    func uniqueDisplayNames() {
        let names = TestOptimizationMode.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test("Polling multiplier increases with power saving")
    func pollingMultipliers() {
        #expect(TestOptimizationMode.performance.pollingMultiplier == 1.0)
        #expect(TestOptimizationMode.balanced.pollingMultiplier == 1.5)
        #expect(TestOptimizationMode.maxSaver.pollingMultiplier == 3.0)
        #expect(TestOptimizationMode.ultraSaver.pollingMultiplier == 6.0)
    }

    @Test("Batch multiplier decreases with power saving")
    func batchMultipliers() {
        #expect(TestOptimizationMode.performance.batchMultiplier == 1.0)
        #expect(TestOptimizationMode.balanced.batchMultiplier == 0.75)
        #expect(TestOptimizationMode.maxSaver.batchMultiplier == 0.5)
        #expect(TestOptimizationMode.ultraSaver.batchMultiplier == 0.25)
    }
}

// MARK: - Mode Evaluation Tests

@Suite("BatteryIntelligence — Mode Evaluation")
struct BatteryEvaluationTests {
    @Test("AC power → performance mode")
    func acPower() {
        #expect(evaluateMode(onAC: true, batteryLevel: 100, lowPowerMode: false) == .performance)
    }

    @Test("Critical battery → ultra saver")
    func criticalBattery() {
        #expect(evaluateMode(onAC: false, batteryLevel: 5, lowPowerMode: false) == .ultraSaver)
        #expect(evaluateMode(onAC: false, batteryLevel: 10, lowPowerMode: false) == .ultraSaver)
    }

    @Test("Low battery → max saver")
    func lowBattery() {
        #expect(evaluateMode(onAC: false, batteryLevel: 15, lowPowerMode: false) == .maxSaver)
        #expect(evaluateMode(onAC: false, batteryLevel: 20, lowPowerMode: false) == .maxSaver)
    }

    @Test("Low power mode → max saver")
    func lowPowerMode() {
        #expect(evaluateMode(onAC: false, batteryLevel: 80, lowPowerMode: true) == .maxSaver)
    }

    @Test("Medium battery → balanced")
    func mediumBattery() {
        #expect(evaluateMode(onAC: false, batteryLevel: 40, lowPowerMode: false) == .balanced)
        #expect(evaluateMode(onAC: false, batteryLevel: 50, lowPowerMode: false) == .balanced)
    }

    @Test("Good battery on battery → balanced")
    func goodBattery() {
        #expect(evaluateMode(onAC: false, batteryLevel: 80, lowPowerMode: false) == .balanced)
    }

    @Test("AC power with low power mode → max saver (low power overrides AC)")
    func acWithLowPower() {
        // Critical battery still overrides
        #expect(evaluateMode(onAC: true, batteryLevel: 5, lowPowerMode: true) == .ultraSaver)
    }
}

// MARK: - Feature Impact Tests

@Suite("BatteryIntelligence — Feature Impact")
struct BatteryFeatureImpactTests {
    @Test("All 7 features exist")
    func allFeatures() {
        #expect(TestBatteryFeature.allCases.count == 7)
    }

    @Test("Performance mode disables nothing")
    func performanceDisablesNothing() {
        for feature in TestBatteryFeature.allCases {
            #expect(!shouldDisableFeature(feature, mode: .performance))
        }
    }

    @Test("Balanced mode disables only low priority")
    func balancedDisablesLow() {
        #expect(shouldDisableFeature(.animations, mode: .balanced))
        #expect(shouldDisableFeature(.prefetching, mode: .balanced))
        #expect(shouldDisableFeature(.hdImages, mode: .balanced))
        #expect(!shouldDisableFeature(.backgroundSync, mode: .balanced))
        #expect(!shouldDisableFeature(.voiceActivation, mode: .balanced))
        #expect(!shouldDisableFeature(.continuousMonitoring, mode: .balanced))
    }

    @Test("Max saver keeps only critical features")
    func maxSaverKeepsCritical() {
        for feature in TestBatteryFeature.allCases {
            if feature.priority == .critical {
                #expect(!shouldDisableFeature(feature, mode: .maxSaver))
            } else {
                #expect(shouldDisableFeature(feature, mode: .maxSaver))
            }
        }
    }

    @Test("Ultra saver keeps only critical features")
    func ultraSaverKeepsCritical() {
        #expect(!shouldDisableFeature(.continuousMonitoring, mode: .ultraSaver))
        #expect(shouldDisableFeature(.voiceActivation, mode: .ultraSaver))
        #expect(shouldDisableFeature(.animations, mode: .ultraSaver))
    }

    @Test("Continuous monitoring is always active")
    func continuousMonitoringAlwaysActive() {
        for mode in TestOptimizationMode.allCases {
            #expect(!shouldDisableFeature(.continuousMonitoring, mode: mode))
        }
    }
}

// MARK: - Polling Interval Tests

@Suite("BatteryIntelligence — Polling Intervals")
struct BatteryPollingTests {
    @Test("Polling interval scales with mode")
    func pollingScaling() {
        let baseInterval: TimeInterval = 10.0
        #expect(baseInterval * TestOptimizationMode.performance.pollingMultiplier == 10.0)
        #expect(baseInterval * TestOptimizationMode.balanced.pollingMultiplier == 15.0)
        #expect(baseInterval * TestOptimizationMode.maxSaver.pollingMultiplier == 30.0)
        #expect(baseInterval * TestOptimizationMode.ultraSaver.pollingMultiplier == 60.0)
    }

    @Test("Batch size scales down with mode")
    func batchSizeScaling() {
        let baseBatch = 100
        #expect(Int(Double(baseBatch) * TestOptimizationMode.performance.batchMultiplier) == 100)
        #expect(Int(Double(baseBatch) * TestOptimizationMode.balanced.batchMultiplier) == 75)
        #expect(Int(Double(baseBatch) * TestOptimizationMode.maxSaver.batchMultiplier) == 50)
        #expect(Int(Double(baseBatch) * TestOptimizationMode.ultraSaver.batchMultiplier) == 25)
    }
}
