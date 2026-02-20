// EnergyAdaptiveThrottler.swift
// Thea — Energy-adaptive polling interval management
//
// Central service that monitors power state (low-power mode, thermal state)
// and publishes an intervalMultiplier that polling monitors use to scale
// their sleep intervals. Reduces CPU/battery consumption when device is
// under thermal stress or in low-power mode.
//
// AM3: Extended with ResourceOrchestrator human-readiness awareness.
// fullAuto restored with 6 §10.4 guardrails.

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
/// - AM3: Combined with ResourceOrchestrator state (readiness/flow-protection)
@MainActor
@Observable
public final class EnergyAdaptiveThrottler {
    public static let shared = EnergyAdaptiveThrottler()

    private let logger = Logger(subsystem: "ai.thea.app", category: "EnergyAdaptiveThrottler")

    // MARK: - Published State

    /// Multiplier that consumers apply to their base polling interval.
    /// 1.0 = normal, 3.0 = low power or elevated thermal, 5.0 = critical thermal.
    /// AM3: Also incorporates ResourceOrchestrator state (readiness/flow-protection).
    public private(set) var intervalMultiplier: Double = 1.0

    /// Human-readable reason for the current multiplier.
    public private(set) var throttleReason: String = "Normal"

    // MARK: - AM3: fullAuto Mode

    /// fullAuto: Thea acts autonomously when all 6 §10.4 guardrails are satisfied.
    /// NEVER disable or hide this toggle in the UI.
    public private(set) var fullAutoEnabled: Bool = false

    /// Consecutive AI failures — resets on success (circuit breaker counter).
    private var consecutiveFailures: Int = 0

    /// Accumulated AI cost in the current session (USD).
    public private(set) var sessionCost: Double = 0.0

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

        // Thermal-based base multiplier
        var baseMultiplier: Double
        var baseReason: String
        switch thermalState {
        case .critical:
            baseMultiplier = 5.0; baseReason = "Critical thermal state"
        case .serious:
            baseMultiplier = 3.0; baseReason = "Serious thermal state"
        case .fair:
            baseMultiplier = 2.0; baseReason = "Fair thermal state"
        case .nominal:
            baseMultiplier = 1.0; baseReason = "Normal"
        @unknown default:
            baseMultiplier = 1.0; baseReason = "Normal"
        }

        // AM3: Combine with ResourceOrchestrator human-readiness state (macOS only)
        #if os(macOS)
        let orchestratorMultiplier = ResourceOrchestrator.shared.throttleMultiplier
        let orchestratorState = ResourceOrchestrator.shared.currentState.rawValue
        let combined = max(baseMultiplier, baseMultiplier * orchestratorMultiplier)
        if orchestratorMultiplier != 1.0 {
            setMultiplier(combined, reason: "\(baseReason) + readiness:\(orchestratorState)")
        } else {
            setMultiplier(baseMultiplier, reason: baseReason)
        }
        #else
        setMultiplier(baseMultiplier, reason: baseReason)
        #endif
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

    // MARK: - AM3: fullAuto Guardrail Evaluation

    /// Evaluate all 6 §10.4 guardrails. Sets fullAutoEnabled accordingly.
    /// Call before any autonomous action. Returns true if fullAuto is permitted.
    @discardableResult
    public func evaluateFullAutoGuardrails() -> Bool {
        #if os(macOS)
        let params = PersonalParameters.shared
        let readiness = HumanReadinessEngine.shared.readinessScore
        let budgetRemaining = InterruptBudgetManager.shared.remaining
        let staleness = DataFreshnessOrchestrator.shared.stalenessScore()

        // Guardrail 1: Readiness ≥ stateActiveThreshold (default 0.65)
        guard readiness >= params.stateActiveThreshold else {
            disableFullAuto(reason: "G1: readiness \(Int(readiness * 100))% < \(Int(params.stateActiveThreshold * 100))%")
            return false
        }
        // Guardrail 2: Interrupt budget ≥ 2 remaining
        guard budgetRemaining >= 2 else {
            disableFullAuto(reason: "G2: interrupt budget low (\(budgetRemaining) remaining)")
            return false
        }
        // Guardrail 3: Data staleness < 50%
        guard staleness < 0.5 else {
            disableFullAuto(reason: "G3: data staleness \(Int(staleness * 100))% ≥ 50%")
            return false
        }
        // Guardrail 4: Circuit breaker — < claudeCircuitBreakerAttempts consecutive failures
        guard consecutiveFailures < params.claudeCircuitBreakerAttempts else {
            disableFullAuto(reason: "G4: circuit breaker open (\(consecutiveFailures) consecutive failures)")
            return false
        }
        // Guardrail 5: Session cost < budget cap
        guard sessionCost < params.claudeBudgetPerSession else {
            disableFullAuto(reason: "G5: cost $\(String(format: "%.2f", sessionCost)) ≥ budget $\(String(format: "%.2f", params.claudeBudgetPerSession))")
            return false
        }
        // Guardrail 6: User override always surfaced in UI (UX requirement — enforced at UI layer)

        if !fullAutoEnabled {
            fullAutoEnabled = true
            logger.info("fullAuto ENABLED: all 6 §10.4 guardrails satisfied — readiness=\(Int(readiness * 100))%, budget=\(budgetRemaining), staleness=\(Int(staleness * 100))%")
        }
        return true
        #else
        return false  // fullAuto is macOS-only
        #endif
    }

    /// Record an AI success — resets circuit breaker counter.
    public func recordAISuccess(cost: Double = 0) {
        consecutiveFailures = 0
        sessionCost += cost
    }

    /// Record an AI failure — increments circuit breaker counter.
    public func recordAIFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= PersonalParameters.shared.claudeCircuitBreakerAttempts {
            disableFullAuto(reason: "Circuit breaker triggered: \(consecutiveFailures) consecutive failures")
        }
    }

    private func disableFullAuto(reason: String) {
        if fullAutoEnabled {
            fullAutoEnabled = false
            logger.warning("fullAuto DISABLED: \(reason)")
        }
    }
}
