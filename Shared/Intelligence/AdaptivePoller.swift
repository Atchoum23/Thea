// AdaptivePoller.swift
// Thea — AS3: Adaptive Polling Engine
//
// Generic actor for intelligent polling with 3 evidence-based strategies:
//
//   1. decorrelatedJitter  — AWS exponential backoff + jitter (RFC 8900 / Exponential Backoff and Jitter blog)
//                           Base interval doubles each attempt, jitter removes thundering herd.
//                           Best for: retrying failed requests, unknown completion time.
//
//   2. knownDuration       — Skip the first 80% of the expected duration, then poll the tail.
//                           Avoids wasted polls during guaranteed-busy time.
//                           Best for: CI jobs, batch jobs with known typical duration.
//                           ciTypicalDurationMinutes from PersonalParameters (SelfTuningEngine adapts).
//
//   3. activityDetection   — Short interval when activity is detected (e.g., new log lines),
//                           steps up to a longer interval when idle.
//                           Best for: streaming logs, live build output, progressive uploads.
//
// Usage:
//   let poller = AdaptivePoller.ciJob()
//   await poller.poll(until: { await buildFinished() })
//
// All intervals in seconds. Cancellation-safe via Task.isCancelled checks.
// Dynamic ciTypicalDurationMinutes from PersonalParameters (SelfTuningEngine adapts).

import Foundation
import OSLog

// MARK: - AdaptivePoller

/// Generic adaptive polling actor. Supply a `work` closure; call `poll(until:)`.
actor AdaptivePoller {

    // MARK: - Strategy

    enum Strategy: Sendable {
        /// AWS decorrelated jitter: interval = random(base, prev × 3), capped at maxInterval.
        case decorrelatedJitter(base: Double, maxInterval: Double)

        /// Skip `skipFraction` of expected duration, then poll every `tailInterval`.
        case knownDuration(expectedSeconds: Double, skipFraction: Double, tailInterval: Double)

        /// Short poll when activity observed; step up to `idleInterval` after `idleCount` quiet polls.
        case activityDetection(activeInterval: Double, idleInterval: Double, idleCount: Int)
    }

    // MARK: - State

    private let strategy: Strategy
    private let logger = Logger(subsystem: "ai.thea.app", category: "AdaptivePoller")

    // Jitter state
    private var prevJitterInterval: Double = 0

    // Activity detection state
    private var consecutiveIdlePolls: Int = 0

    // MARK: - Init

    init(strategy: Strategy) {
        self.strategy = strategy
    }

    // MARK: - Static Factories

    /// Retrying unknown-duration tasks (API calls, network requests).
    /// Starts at 1s, caps at 60s, with decorrelated jitter to prevent thundering herd.
    static func retrying(base: Double = 1.0, maxInterval: Double = 60.0) -> AdaptivePoller {
        AdaptivePoller(strategy: .decorrelatedJitter(base: base, maxInterval: maxInterval))
    }

    /// CI/batch job polling. Skips 80% of typical duration, polls tail at 15s intervals.
    /// Uses PersonalParameters.ciTypicalDurationMinutes as the expected duration.
    @MainActor
    static func ciJob(tailInterval: Double = 15.0) -> AdaptivePoller {
        let expectedSec = PersonalParameters.shared.ciTypicalDurationMinutes * 60
        return AdaptivePoller(strategy: .knownDuration(
            expectedSeconds: expectedSec,
            skipFraction: 0.80,
            tailInterval: tailInterval
        ))
    }

    /// Log/stream monitoring. Fast (2s) when new content seen, backs off to 30s when idle.
    static func logMonitor(
        activeInterval: Double = 2.0,
        idleInterval: Double = 30.0,
        idleCount: Int = 5
    ) -> AdaptivePoller {
        AdaptivePoller(strategy: .activityDetection(
            activeInterval: activeInterval,
            idleInterval: idleInterval,
            idleCount: idleCount
        ))
    }

    // MARK: - Poll

    /// Repeatedly call `check` until it returns `true`, sleeping between calls according
    /// to the selected strategy. Respects Task cancellation — exits cleanly if cancelled.
    ///
    /// - Parameters:
    ///   - check: Async closure returning `true` when the condition is met.
    ///   - activity: Optional closure returning `true` if activity was observed since last poll.
    ///               Only used by `.activityDetection` strategy.
    ///   - timeout: Optional hard timeout in seconds. Returns `false` if exceeded.
    /// - Returns: `true` if condition met, `false` if timed out or cancelled.
    @discardableResult
    func poll(
        until check: @Sendable () async -> Bool,
        activity: (@Sendable () async -> Bool)? = nil,
        timeout: Double? = nil
    ) async -> Bool {
        let start = Date.now
        var pollCount = 0

        // knownDuration: skip first `skipFraction` of expected duration
        if case .knownDuration(let expectedSec, let skipFraction, _) = strategy {
            let skipSec = expectedSec * skipFraction
            logger.info("AdaptivePoller: knownDuration — skipping first \(Int(skipSec))s of \(Int(expectedSec))s")
            do {
                try await Task.sleep(for: .seconds(skipSec))
            } catch {
                return false // cancelled
            }
        }

        while !Task.isCancelled {
            // Hard timeout check
            if let timeout, Date.now.timeIntervalSince(start) >= timeout {
                logger.warning("AdaptivePoller: timeout after \(Int(timeout))s (\(pollCount) polls)")
                return false
            }

            // Check condition
            let done = await check()
            pollCount += 1

            if done {
                logger.info("AdaptivePoller: condition met after \(pollCount) polls")
                return true
            }

            // Compute next interval
            let interval = await nextInterval(activityCheck: activity)
            logger.debug("AdaptivePoller: poll \(pollCount) — waiting \(String(format: \"%.1f\", interval))s")

            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return false // cancelled
            }
        }

        return false
    }

    // MARK: - Interval Computation

    private func nextInterval(activityCheck: (@Sendable () async -> Bool)?) async -> Double {
        switch strategy {
        case .decorrelatedJitter(let base, let maxInterval):
            // AWS formula: sleep = min(cap, random_between(base, prevSleep × 3))
            let prev = prevJitterInterval > 0 ? prevJitterInterval : base
            let next = Double.random(in: base...min(maxInterval, prev * 3))
            prevJitterInterval = next
            return next

        case .knownDuration(_, _, let tailInterval):
            // Already skipped the wait phase; just poll at tailInterval
            return tailInterval

        case .activityDetection(let activeInterval, let idleInterval, let idleCount):
            let hasActivity = await activityCheck?() ?? false
            if hasActivity {
                consecutiveIdlePolls = 0
                return activeInterval
            } else {
                consecutiveIdlePolls += 1
                // Step up to idle interval after `idleCount` consecutive quiet polls
                return consecutiveIdlePolls >= idleCount ? idleInterval : activeInterval
            }
        }
    }
}
