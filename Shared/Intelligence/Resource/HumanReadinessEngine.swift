// HumanReadinessEngine.swift
// Thea — AJ3: Human Readiness Engine
//
// Real-time composite readiness score [0,1] from 5 weighted physiological signals:
// HRV status (Apple Watch SDNN), sleep quality, ultradian phase, temperature
// proxy (wrist skin temp via Apple Watch), REM fraction.
//
// Note: Apple Watch reports SDNN — do NOT compare directly to Oura RMSSD.
// Score drives ResourceOrchestrator state transitions and interrupt gating.

import Combine
import Foundation
import OSLog

// MARK: - HumanReadinessEngine

@MainActor
public final class HumanReadinessEngine: ObservableObject {
    public static let shared = HumanReadinessEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "HumanReadinessEngine")
    private let params = PersonalParameters.shared

    // MARK: - Published State

    @Published public private(set) var readinessScore: Double = 0.5
    @Published public private(set) var ultradianPhase: UltradianPhase = .unknown
    @Published public private(set) var lastUpdated: Date = .now

    // MARK: - Signal Storage

    /// Baseline SDNN (ms) — rolling average over params.hrvBaselineDays
    private var hrvBaselineSDNN: Double = 0
    /// Most recent SDNN measurement
    private var latestSDNN: Double = 0

    private var lastSleepQuality: Double = 0.5   // 0..1
    private var lastDeepFraction: Double = 0.15  // fraction of total sleep
    private var lastREMFraction: Double = 0.10   // fraction of total sleep

    /// Behavioral signals accumulated since last ultradian reset
    private var behavioralSignalCount: Int = 0
    private var ultradianStartTime: Date = .now

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Types

    public enum UltradianPhase: String, Sendable {
        case peak    // High output window — protect from interrupts
        case trough  // Low energy window — ideal for breaks
        case unknown // Insufficient signal data
    }

    // MARK: - Init

    private init() {
        // Recompute readiness every 60s
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
    }

    // MARK: - Public Update API

    /// Call after fetching HRV from HealthKit.
    /// - Parameter sdnn: SDNN value in milliseconds (Apple Watch unit)
    /// - Parameter isBaseline: true when updating the rolling baseline
    public func updateHRVBaseline(_ sdnn: Double, isBaseline: Bool = false) {
        latestSDNN = sdnn
        if isBaseline || hrvBaselineSDNN == 0 {
            hrvBaselineSDNN = sdnn
        } else {
            // Exponential moving average to track slow drift
            let alpha = 1.0 / Double(max(params.hrvBaselineDays, 1))
            hrvBaselineSDNN = (1 - alpha) * hrvBaselineSDNN + alpha * sdnn
        }
        recompute()
        logger.debug("HRV updated: SDNN=\(sdnn, format: .fixed(precision: 1))ms baseline=\(self.hrvBaselineSDNN, format: .fixed(precision: 1))ms")
    }

    /// Call after HealthKit sleep analysis completes.
    public func updateSleepMetrics(quality: Double, deepFraction: Double, remFraction: Double) {
        lastSleepQuality = max(0, min(1, quality))
        lastDeepFraction = max(0, min(1, deepFraction))
        lastREMFraction = max(0, min(1, remFraction))
        recompute()
    }

    /// Called by InterruptBudgetManager and macOSBehavioralSignalExtractor
    /// when a behavioral signal is detected (idle end, app switch, typing burst, etc.)
    public func recordBehavioralSignal() {
        behavioralSignalCount += 1
        // Ultradian trough requires ≥ params.ultradianMinSignals signals within the cycle window
        evaluateUltradianPhase()
        recompute()
    }

    // Alias for InterruptBudgetManager compatibility
    public func recordInterrupt() { recordBehavioralSignal() }

    // MARK: - Core Computation

    public func recompute() {
        let hrv = computeHRVScore()
        let sleep = lastSleepQuality
        let deep = min(lastDeepFraction / 0.20, 1.0)   // Target: ≥20% deep
        let ultradian = ultradianScore()
        let rem = min(lastREMFraction / 0.25, 1.0)     // Target: ≥25% REM

        readinessScore = params.morningWeightHRV * hrv
                       + params.morningWeightSleep * sleep
                       + params.morningWeightDeep * deep
                       + params.morningWeightTemperature * ultradian
                       + params.morningWeightREM * rem

        readinessScore = max(0, min(1, readinessScore))
        lastUpdated = .now

        logger.debug("Readiness=\(self.readinessScore, format: .fixed(precision: 3)) hrv=\(hrv, format: .fixed(precision: 2)) sleep=\(sleep, format: .fixed(precision: 2)) deep=\(deep, format: .fixed(precision: 2)) ultradian=\(ultradian, format: .fixed(precision: 2)) rem=\(rem, format: .fixed(precision: 2))")
    }

    // MARK: - Private Helpers

    private func computeHRVScore() -> Double {
        guard hrvBaselineSDNN > 0, latestSDNN > 0 else { return 0.5 }
        // Trough threshold: within params.hrvTroughPercent of baseline
        let troughThreshold = hrvBaselineSDNN * (1.0 - params.hrvTroughPercent)
        if latestSDNN < troughThreshold { return 0.2 }  // Clear trough
        // Normalize: at baseline → 0.7; above baseline → up to 1.0
        let ratio = latestSDNN / hrvBaselineSDNN
        return min(1.0, max(0.0, 0.7 * min(ratio, 1.0) + 0.3 * max(0, (ratio - 1.0) / 0.5)))
    }

    private func ultradianScore() -> Double {
        switch ultradianPhase {
        case .peak:    return 1.0
        case .trough:  return 0.2
        case .unknown: return 0.5
        }
    }

    private func evaluateUltradianPhase() {
        let elapsed = Date.now.timeIntervalSince(ultradianStartTime)
        let cycleSeconds = params.ultradianCycleMinutes * 60

        if elapsed >= cycleSeconds {
            // Reset cycle — new ultradian window starts
            ultradianStartTime = .now
            behavioralSignalCount = 0
            ultradianPhase = .unknown
            return
        }

        // Declare trough if we've accumulated enough low-energy signals
        if behavioralSignalCount >= params.ultradianMinSignals {
            let troughStart = params.workBlockMinutes * 60
            ultradianPhase = elapsed >= troughStart ? .trough : .peak
        }
    }
}
