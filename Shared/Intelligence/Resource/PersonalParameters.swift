// PersonalParameters.swift
// Thea — AI3: PersonalParameters Foundation
//
// Single source of truth for all Tier 2 personalizable parameters.
// Tier 1 (population-fixed) are `let` constants — never personalize.
// Tier 2 (personalizable) are @AppStorage — SelfTuningEngine updates via outcome signals.
//
// Bootstrap: .claude/personal-parameters-defaults.txt seeds initial values.
// Once SelfTuningEngine has ≥30 days data, PersonalParameters.snapshot()
// supersedes the static document for Claude §0.3 context injection.

import Foundation
import SwiftUI

// MARK: - PersonalParameters

/// Single source of truth for all Tier 2 personalizable parameters.
/// Tier 1 (population-fixed) are `let` constants — NEVER personalize.
/// Tier 2 (personalizable) are @AppStorage — SelfTuningEngine updates via outcome signals.
@MainActor
public final class PersonalParameters: ObservableObject {
    public static let shared = PersonalParameters()

    // MARK: - Tier 1 — Population-Fixed (NEVER personalize)

    /// Context-switch recovery ceiling (population: 23min 15s ± ~5min)
    public let contextSwitchRecoveryCeiling: TimeInterval = 23 * 60 + 15

    /// Working memory chunk limit (population: 4 ± 1; Miller's Law)
    public let workingMemoryChunks: Int = 4

    /// Flow-state productivity multiplier (~5× baseline output)
    public let flowProductivityMultiplier: Double = 5.0

    // MARK: - Tier 2 — Interrupt Management

    /// Max interrupts budget per day (research default: 4)
    @AppStorage("pp.interruptBudget")
    public var interruptBudget: Int = 4

    /// Idle duration before Thea considers user breakpointed (minutes)
    @AppStorage("pp.idleBreakpointMin")
    public var idleBreakpointMinutes: Double = 3.0

    // MARK: - Tier 2 — Flow State

    /// Sustained focus ramp time before flow threshold is reachable (minutes)
    @AppStorage("pp.flowRampMin")
    public var flowRampMinutes: Double = 17.5

    /// Readiness score threshold to enter flow-protection mode (0–1)
    @AppStorage("pp.flowThreshold")
    public var flowThreshold: Double = 0.85

    // MARK: - Tier 2 — Ultradian Rhythm

    /// Target work block duration (minutes; default 75 = ultradian peak window)
    @AppStorage("pp.workBlockMin")
    public var workBlockMinutes: Double = 75

    /// Target break duration after a work block (minutes)
    @AppStorage("pp.breakMin")
    public var breakMinutes: Double = 33

    /// Full ultradian cycle duration (minutes; work + break)
    @AppStorage("pp.ultradianCycleMin")
    public var ultradianCycleMinutes: Double = 100

    /// Minimum physiological signals needed to confirm trough (1–5)
    @AppStorage("pp.ultradianMinSignals")
    public var ultradianMinSignals: Int = 3

    // MARK: - Tier 2 — HRV / Physiology

    /// HRV trough threshold as fraction below rolling baseline (0–1)
    @AppStorage("pp.hrvTroughPct")
    public var hrvTroughPercent: Double = 0.10

    /// Rolling baseline window for personal HRV calibration (days)
    @AppStorage("pp.hrvBaselineDays")
    public var hrvBaselineDays: Int = 30

    // MARK: - Tier 2 — Morning Readiness Weights (must sum to 1.0)

    /// Weight of HRV in morning readiness composite
    @AppStorage("pp.morningWtHRV")
    public var morningWeightHRV: Double = 0.40

    /// Weight of sleep duration/quality in morning readiness composite
    @AppStorage("pp.morningWtSleep")
    public var morningWeightSleep: Double = 0.25

    /// Weight of deep sleep % in morning readiness composite
    @AppStorage("pp.morningWtDeep")
    public var morningWeightDeep: Double = 0.15

    /// Weight of wrist skin temperature in morning readiness composite
    @AppStorage("pp.morningWtTemp")
    public var morningWeightTemperature: Double = 0.10

    /// Weight of REM sleep % in morning readiness composite
    @AppStorage("pp.morningWtREM")
    public var morningWeightREM: Double = 0.10

    // MARK: - Tier 2 — Readiness State Thresholds

    /// Minimum readiness score to transition from IDLE → ACTIVE (0–1)
    @AppStorage("pp.stateActiveThreshold")
    public var stateActiveThreshold: Double = 0.65

    /// Minimum readiness score to transition to HIGH state (0–1)
    @AppStorage("pp.stateHighThreshold")
    public var stateHighThreshold: Double = 0.90

    /// Readiness score below which to satisfice rather than optimize (0–1)
    @AppStorage("pp.satisficeTarget")
    public var satisficeTarget: Double = 0.70

    // MARK: - Tier 2 — Exploration / Novelty

    /// Days of data required before switching from exploration to exploitation
    @AppStorage("pp.exploreDays")
    public var exploreDays: Int = 60

    /// Engagement points threshold per domain to consider it well-explored
    @AppStorage("pp.explorePointsPerDomain")
    public var explorePointsPerDomain: Int = 500

    /// Half-life of domain engagement decay (days)
    @AppStorage("pp.exploreDecayHalfLifeDays")
    public var exploreDecayHalfLifeDays: Int = 14

    // MARK: - Tier 2 — Claude Session Management

    /// Context fill % at which Claude Code triggers compaction (0–1)
    @AppStorage("pp.claudeCompactAt")
    public var claudeCompactAt: Double = 0.70

    /// Max retry attempts before circuit breaker opens on Claude API
    @AppStorage("pp.claudeCircuitBreaker")
    public var claudeCircuitBreakerAttempts: Int = 3

    /// Max Claude API spend per session (USD)
    @AppStorage("pp.claudeBudgetPerSession")
    public var claudeBudgetPerSession: Double = 2.00

    // MARK: - Private Init

    private init() {}

    // MARK: - Snapshot for Claude §0.3 Context Injection

    /// Returns a compact text block for injection into Claude Code session context.
    /// Supersedes `.claude/personal-parameters-defaults.txt` once SelfTuningEngine
    /// has ≥30 days of outcome data. Call at autonomous session start.
    public func snapshot() -> String {
        """
        PersonalParameters snapshot (Tier 2 live values):
        Interrupts:   budget=\(interruptBudget)/day      idleBreakpoint=\(idleBreakpointMinutes)min
        Flow:         ramp=\(flowRampMinutes)min      threshold=\(Int(flowThreshold * 100))%
        Work blocks:  work=\(workBlockMinutes)min      break=\(breakMinutes)min
        Ultradian:    cycle=\(ultradianCycleMinutes)min      minSignals=\(ultradianMinSignals)
        HRV:          trough=±\(Int(hrvTroughPercent * 100))%   baseline=\(hrvBaselineDays)d
        MorningWts:   HRV=\(morningWeightHRV)  sleep=\(morningWeightSleep)  deep=\(morningWeightDeep)  temp=\(morningWeightTemperature)  rem=\(morningWeightREM)
        States:       act≥\(stateActiveThreshold)    high≥\(stateHighThreshold)    satisfice@\(satisficeTarget)
        Explore:      days=\(exploreDays)  points/domain=\(explorePointsPerDomain)  decay=\(exploreDecayHalfLifeDays)d
        Claude:       compact@\(Int(claudeCompactAt * 100))%    circuit=\(claudeCircuitBreakerAttempts)    budget=$\(String(format: "%.2f", claudeBudgetPerSession))/session
        """
    }
}
