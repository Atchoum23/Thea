// MobilePowerStateMonitor.swift
// Thea - Mobile Intelligence
//
// Monitors device power state for battery-aware inference decisions.
// Works on iOS/iPadOS and macOS (laptops).

import Foundation
import Observation

#if os(iOS)
import UIKit
#endif

// MARK: - Power State

/// Current power state of the device
public struct MobilePowerState: Sendable {
    public let batteryLevel: Float          // 0.0 - 1.0
    public let isCharging: Bool
    public let isLowPowerMode: Bool
    public let thermalState: ThermalState
    public let estimatedDrainRate: Float    // % per hour during inference

    public var batteryPercentage: Int {
        Int(batteryLevel * 100)
    }

    /// Whether we have enough power for local inference
    public var canDoLocalInference: Bool {
        guard !isLowPowerMode else { return false }
        guard batteryLevel > 0.15 else { return false }
        guard thermalState != .critical else { return false }
        return true
    }

    /// Whether we should prefer cloud over local
    public var shouldPreferCloud: Bool {
        isLowPowerMode || batteryLevel < 0.25 || thermalState == .serious
    }

    public enum ThermalState: String, Sendable {
        case nominal, fair, serious, critical

        #if os(iOS) || os(macOS)
        init(from processInfo: ProcessInfo.ThermalState) {
            switch processInfo {
            case .nominal: self = .nominal
            case .fair: self = .fair
            case .serious: self = .serious
            case .critical: self = .critical
            @unknown default: self = .nominal
            }
        }
        #endif
    }
}

// MARK: - Inference Budget

/// Recommended inference budget based on power state
public struct InferenceBudget: Sendable {
    public let maxTokensPerQuery: Int
    public let maxQueriesPerHour: Int
    public let preferredModelSize: ModelSizeCategory
    public let allowLocalInference: Bool
    public let allowRemoteMac: Bool
    public let allowCloud: Bool

    public enum ModelSizeCategory: String, Sendable {
        case tiny       // 0.5B - minimal power
        case small      // 1-3B - low power
        case medium     // 3-7B - moderate power
        case large      // 7B+ - high power
        case unlimited  // No restriction (plugged in)
    }

    /// Conservative budget for low battery
    public static let conservative = InferenceBudget(
        maxTokensPerQuery: 512,
        maxQueriesPerHour: 10,
        preferredModelSize: .tiny,
        allowLocalInference: false,
        allowRemoteMac: true,
        allowCloud: true
    )

    /// Normal budget for typical usage
    public static let normal = InferenceBudget(
        maxTokensPerQuery: 2048,
        maxQueriesPerHour: 50,
        preferredModelSize: .small,
        allowLocalInference: true,
        allowRemoteMac: true,
        allowCloud: true
    )

    /// Unlimited budget when plugged in
    public static let unlimited = InferenceBudget(
        maxTokensPerQuery: 8192,
        maxQueriesPerHour: 1000,
        preferredModelSize: .unlimited,
        allowLocalInference: true,
        allowRemoteMac: true,
        allowCloud: true
    )
}

// MARK: - Power State Monitor

/// Monitors device power state for intelligent inference decisions
@MainActor
@Observable
public final class MobilePowerStateMonitor {
    public static let shared = MobilePowerStateMonitor()

    // MARK: - State

    public private(set) var currentState: MobilePowerState
    public private(set) var currentBudget: InferenceBudget
    public private(set) var drainHistory: [DrainSample] = []

    /// Callbacks for power state changes
    public var onMobilePowerStateChanged: (@Sendable (MobilePowerState) -> Void)?
    public var onBudgetChanged: (@Sendable (InferenceBudget) -> Void)?

    // MARK: - Internal

    private var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?

    private init() {
        self.currentState = MobilePowerState(
            batteryLevel: 1.0,
            isCharging: true,
            isLowPowerMode: false,
            thermalState: .nominal,
            estimatedDrainRate: 0
        )
        self.currentBudget = .unlimited

        setupMonitoring()
    }

    // MARK: - Monitoring

    private func setupMonitoring() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMobilePowerState()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMobilePowerState()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMobilePowerState()
            }
        }
        #endif

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMobilePowerState()
            }
        }

        // Initial update
        updateMobilePowerState()

        // Start periodic monitoring
        startPeriodicMonitoring()
    }

    private func startPeriodicMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await self?.updateMobilePowerState()
                await self?.recordDrainSample()
            }
        }
    }

    private func updateMobilePowerState() {
        let newState = readCurrentMobilePowerState()
        let oldState = currentState
        currentState = newState

        // Update budget based on new state
        let newBudget = calculateBudget(for: newState)
        if newBudget.preferredModelSize != currentBudget.preferredModelSize {
            currentBudget = newBudget
            onBudgetChanged?(newBudget)
        }

        // Notify if significant change
        if significantChange(from: oldState, to: newState) {
            onMobilePowerStateChanged?(newState)
        }
    }

    private func readCurrentMobilePowerState() -> MobilePowerState {
        #if os(iOS)
        let device = UIDevice.current
        let batteryLevel = device.batteryLevel >= 0 ? device.batteryLevel : 1.0
        let isCharging = device.batteryState == .charging || device.batteryState == .full
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalState = MobilePowerState.ThermalState(from: ProcessInfo.processInfo.thermalState)

        return MobilePowerState(
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            isLowPowerMode: isLowPowerMode,
            thermalState: thermalState,
            estimatedDrainRate: calculateDrainRate()
        )
        #elseif os(macOS)
        // macOS laptop battery monitoring
        let thermalState = MobilePowerState.ThermalState(from: ProcessInfo.processInfo.thermalState)
        let (level, charging) = getMacOSBatteryInfo()

        return MobilePowerState(
            batteryLevel: level,
            isCharging: charging,
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: thermalState,
            estimatedDrainRate: calculateDrainRate()
        )
        #else
        return MobilePowerState(
            batteryLevel: 1.0,
            isCharging: true,
            isLowPowerMode: false,
            thermalState: .nominal,
            estimatedDrainRate: 0
        )
        #endif
    }

    #if os(macOS)
    private func getMacOSBatteryInfo() -> (Float, Bool) {
        // Use IOKit to get battery info on macOS
        // Simplified implementation - returns plugged in as default
        // Full implementation would use IOPSCopyPowerSourcesInfo
        (1.0, true)
    }
    #endif

    private func calculateBudget(for state: MobilePowerState) -> InferenceBudget {
        if state.isCharging {
            return .unlimited
        }

        if state.isLowPowerMode || state.batteryLevel < 0.20 {
            return .conservative
        }

        if state.batteryLevel < 0.50 || state.thermalState == .serious {
            return .normal
        }

        return .unlimited
    }

    private func significantChange(from old: MobilePowerState, to new: MobilePowerState) -> Bool {
        if old.isCharging != new.isCharging { return true }
        if old.isLowPowerMode != new.isLowPowerMode { return true }
        if old.thermalState != new.thermalState { return true }
        if abs(old.batteryLevel - new.batteryLevel) > 0.05 { return true }
        return false
    }

    // MARK: - Drain Tracking

    public struct DrainSample: Sendable {
        public let timestamp: Date
        public let batteryLevel: Float
        public let wasInferencing: Bool
    }

    private func recordDrainSample() {
        let sample = DrainSample(
            timestamp: Date(),
            batteryLevel: currentState.batteryLevel,
            wasInferencing: false // Would be updated by inference tracker
        )
        drainHistory.append(sample)

        // Keep last 60 samples (1 hour at 1-minute intervals)
        if drainHistory.count > 60 {
            drainHistory.removeFirst()
        }
    }

    private func calculateDrainRate() -> Float {
        guard drainHistory.count >= 5 else { return 0 }

        let recent = drainHistory.suffix(5)
        guard let first = recent.first, let last = recent.last else { return 0 }

        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeDelta > 0 else { return 0 }

        let levelDelta = first.batteryLevel - last.batteryLevel
        let hoursElapsed = Float(timeDelta / 3600)

        return levelDelta / hoursElapsed * 100 // % per hour
    }
}
