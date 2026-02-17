// EnergyAdaptiveThrottler.swift
// Thea — Energy-adaptive polling interval management
//
// Central service that monitors power state (low-power mode, thermal state)
// and publishes an intervalMultiplier that polling monitors use to scale
// their sleep intervals. Reduces CPU/battery consumption when device is
// under thermal stress or in low-power mode.

import Foundation
import os.log
#if os(iOS)
    import UIKit
#endif

// MARK: - Energy Adaptive Throttler

/// Monitors power state and provides throttled intervals for polling loops.
/// - Normal: intervalMultiplier = 1.0 (baseline polling)
/// - Low Power Mode (iOS): intervalMultiplier = 3.0
/// - Serious thermal: intervalMultiplier = 3.0
/// - Critical thermal: intervalMultiplier = 5.0
@MainActor
@Observable
public final class EnergyAdaptiveThrottler {
    public static let shared = EnergyAdaptiveThrottler()

    private let logger = Logger(subsystem: "ai.thea.app", category: "EnergyAdaptiveThrottler")

    // MARK: - Published State

    /// Multiplier that consumers apply to their base polling interval.
    /// 1.0 = normal, 3.0 = low power or elevated thermal, 5.0 = critical thermal.
    public private(set) var intervalMultiplier: Double = 1.0

    /// Human-readable reason for the current multiplier.
    public private(set) var throttleReason: String = "Normal"

    // MARK: - Private

    private var monitorTask: Task<Void, Never>?

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateMultiplier()
                try? await Task.sleep(for: .seconds(10))
            }
        }

        // Also react to low-power mode changes on iOS
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMultiplier()
            }
        }
        #endif
    }

    private func updateMultiplier() async {
        let thermalState = ProcessInfo.processInfo.thermalState

        #if os(iOS)
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if isLowPower {
            setMultiplier(3.0, reason: "Low Power Mode active")
            return
        }
        #endif

        switch thermalState {
        case .critical:
            setMultiplier(5.0, reason: "Critical thermal state")
        case .serious:
            setMultiplier(3.0, reason: "Serious thermal state")
        case .fair:
            setMultiplier(2.0, reason: "Fair thermal state")
        case .nominal:
            setMultiplier(1.0, reason: "Normal")
        @unknown default:
            setMultiplier(1.0, reason: "Normal")
        }
    }

    private func setMultiplier(_ multiplier: Double, reason: String) {
        guard multiplier != intervalMultiplier else { return }
        intervalMultiplier = multiplier
        throttleReason = reason
        logger.info("Energy throttle: \(multiplier)x (\(reason))")
    }

    // MARK: - Memory Pressure Integration

    /// Called from the macOS DispatchSource memory pressure handler.
    /// Temporarily raises the interval multiplier to reduce polling load.
    public func applyMemoryPressure(isCritical: Bool) {
        let multiplier: Double = isCritical ? 5.0 : 3.0
        let reason = isCritical ? "Critical memory pressure" : "Memory pressure warning"
        setMultiplier(multiplier, reason: reason)
        // Auto-restore after 60s — thermalState check will normalise if pressure eases
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(60))
            await self?.updateMultiplier()
        }
    }
}
