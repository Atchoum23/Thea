//
//  PowerStateManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import Combine
#if os(macOS)
import AppKit
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
#else
import UIKit
#endif

// MARK: - Power State Manager

/// Monitors and manages system power state
@MainActor
@Observable
public final class PowerStateManager {
    public static let shared = PowerStateManager()

    // MARK: - State

    /// Current power source
    public private(set) var powerSource: PowerSource = .unknown

    /// Current battery level (0-100, nil if no battery)
    public private(set) var batteryLevel: Int?

    /// Whether the device is charging
    public private(set) var isCharging: Bool = false

    /// Whether low power mode is active
    public private(set) var isLowPowerMode: Bool = false

    /// Current thermal state
    public private(set) var thermalState: ThermalState = .nominal

    /// Whether the system is about to sleep
    public private(set) var isAboutToSleep: Bool = false

    /// Time remaining on battery (in minutes, nil if unknown)
    public private(set) var timeRemainingMinutes: Int?

    // MARK: - Publishers

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks

    /// Called when power source changes
    public var onPowerSourceChanged: ((PowerSource) -> Void)?

    /// Called when battery level changes significantly
    public var onBatteryLevelChanged: ((Int) -> Void)?

    /// Called when system is about to sleep
    public var onSystemWillSleep: (() -> Void)?

    /// Called when system woke from sleep
    public var onSystemDidWake: (() -> Void)?

    /// Called when thermal state changes
    public var onThermalStateChanged: ((ThermalState) -> Void)?

    // MARK: - Initialization

    private init() {
        setupMonitoring()
        updatePowerState()
    }

    // MARK: - Setup

    private func setupMonitoring() {
        #if os(macOS)
        setupMacOSMonitoring()
        #else
        setupIOSMonitoring()
        #endif

        // Monitor thermal state
        setupThermalMonitoring()
    }

    #if os(macOS)
    private func setupMacOSMonitoring() {
        // Monitor power source changes
        let runLoopSource = IOPSNotificationCreateRunLoopSource(
            { _ in
                Task { @MainActor in
                    PowerStateManager.shared.updatePowerState()
                }
            },
            nil
        ).takeRetainedValue()

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

        // Monitor sleep/wake notifications
        let notificationCenter = NSWorkspace.shared.notificationCenter

        notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.handleWillSleep()
            }
        }

        notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.handleDidWake()
            }
        }

        notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.handleScreensDidSleep()
            }
        }

        notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.handleScreensDidWake()
            }
        }
    }
    #else
    private func setupIOSMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.updatePowerState()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.updatePowerState()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.updatePowerState()
            }
        }
    }
    #endif

    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard self != nil else { return }
            Task { @MainActor [weak self] in
                self?.updateThermalState()
            }
        }
    }

    // MARK: - State Updates

    private func updatePowerState() {
        #if os(macOS)
        updateMacOSPowerState()
        #else
        updateIOSPowerState()
        #endif
    }

    #if os(macOS)
    private func updateMacOSPowerState() {
        guard let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSources = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef],
              !powerSources.isEmpty,
              let source = powerSources.first,
              let description = IOPSGetPowerSourceDescription(powerSourceInfo, source)?.takeUnretainedValue() as? [String: Any] else {
            powerSource = .ac
            batteryLevel = nil
            isCharging = false
            timeRemainingMinutes = nil
            return
        }

        // Determine power source
        if let powerSourceState = description[kIOPSPowerSourceStateKey] as? String {
            switch powerSourceState {
            case kIOPSACPowerValue:
                powerSource = .ac
                isCharging = true
            case kIOPSBatteryPowerValue:
                powerSource = .battery
                isCharging = false
            default:
                powerSource = .unknown
            }
        }

        // Get battery level
        if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int {
            let previousLevel = batteryLevel
            batteryLevel = currentCapacity

            if let previous = previousLevel, abs(previous - currentCapacity) >= 5 {
                onBatteryLevelChanged?(currentCapacity)
            }
        }

        // Get time remaining
        if let timeRemaining = description[kIOPSTimeToEmptyKey] as? Int, timeRemaining > 0 {
            timeRemainingMinutes = timeRemaining
        } else {
            timeRemainingMinutes = nil
        }

        // Check charging state
        if let isChargingValue = description[kIOPSIsChargingKey] as? Bool {
            isCharging = isChargingValue
        }
    }
    #else
    private func updateIOSPowerState() {
        let device = UIDevice.current

        // Determine power source and charging state
        switch device.batteryState {
        case .charging:
            powerSource = .ac
            isCharging = true
        case .full:
            powerSource = .ac
            isCharging = false
        case .unplugged:
            powerSource = .battery
            isCharging = false
        case .unknown:
            powerSource = .unknown
            isCharging = false
        @unknown default:
            powerSource = .unknown
            isCharging = false
        }

        // Get battery level
        let level = Int(device.batteryLevel * 100)
        if level >= 0 {
            let previousLevel = batteryLevel
            batteryLevel = level

            if let previous = previousLevel, abs(previous - level) >= 5 {
                onBatteryLevelChanged?(level)
            }
        }

        // Check low power mode
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    #endif

    private func updateThermalState() {
        let processInfoState = ProcessInfo.processInfo.thermalState

        let previousState = thermalState

        switch processInfoState {
        case .nominal:
            thermalState = .nominal
        case .fair:
            thermalState = .fair
        case .serious:
            thermalState = .serious
        case .critical:
            thermalState = .critical
        @unknown default:
            thermalState = .unknown
        }

        if thermalState != previousState {
            onThermalStateChanged?(thermalState)
        }
    }

    // MARK: - Event Handlers

    private func handleWillSleep() {
        isAboutToSleep = true
        onSystemWillSleep?()
    }

    private func handleDidWake() {
        isAboutToSleep = false
        updatePowerState()
        onSystemDidWake?()
    }

    private func handleScreensDidSleep() {
        // Screen dimmed/sleeping
    }

    private func handleScreensDidWake() {
        // Screen woke up
    }

    // MARK: - Power State Queries

    /// Check if we should conserve power
    public var shouldConservePower: Bool {
        // Conserve power if on battery with low charge
        if powerSource == .battery {
            if let level = batteryLevel, level < 30 {
                return true
            }
        }

        // Conserve power in low power mode
        if isLowPowerMode {
            return true
        }

        // Conserve power in thermal throttling
        if thermalState == .serious || thermalState == .critical {
            return true
        }

        return false
    }

    /// Get recommended polling interval based on power state
    public var recommendedPollingInterval: TimeInterval {
        if shouldConservePower {
            return 60.0 // 1 minute
        } else if powerSource == .battery {
            return 30.0 // 30 seconds
        } else {
            return 10.0 // 10 seconds
        }
    }

    /// Get current power status summary
    public var powerStatus: PowerStatus {
        PowerStatus(
            powerSource: powerSource,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            isLowPowerMode: isLowPowerMode,
            thermalState: thermalState,
            timeRemainingMinutes: timeRemainingMinutes,
            shouldConservePower: shouldConservePower
        )
    }
}

// MARK: - Power Source

public enum PowerSource: String, Codable, Sendable {
    case ac
    case battery
    case ups
    case unknown

    public var displayName: String {
        switch self {
        case .ac: return "Power Adapter"
        case .battery: return "Battery"
        case .ups: return "UPS"
        case .unknown: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .ac: return "powerplug"
        case .battery: return "battery.100"
        case .ups: return "battery.100.bolt"
        case .unknown: return "bolt.slash"
        }
    }
}

// MARK: - Thermal State

public enum ThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown

    public var displayName: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Elevated"
        case .serious: return "High"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .nominal: return "thermometer.medium"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "thermometer.sun"
        case .unknown: return "thermometer"
        }
    }

    public var shouldThrottle: Bool {
        self == .serious || self == .critical
    }
}

// MARK: - Power Status

public struct PowerStatus: Sendable {
    public let powerSource: PowerSource
    public let batteryLevel: Int?
    public let isCharging: Bool
    public let isLowPowerMode: Bool
    public let thermalState: ThermalState
    public let timeRemainingMinutes: Int?
    public let shouldConservePower: Bool

    public var batteryIcon: String {
        guard let level = batteryLevel else {
            return "battery.0"
        }

        if isCharging {
            return "battery.100.bolt"
        }

        switch level {
        case 0..<10: return "battery.0"
        case 10..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    public var formattedTimeRemaining: String? {
        guard let minutes = timeRemainingMinutes else { return nil }

        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
