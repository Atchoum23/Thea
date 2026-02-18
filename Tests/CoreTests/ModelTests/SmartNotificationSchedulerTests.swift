// SmartNotificationSchedulerTests.swift
// Tests for SmartNotificationScheduler service logic: delivery decisions, priority bypass,
// receptivity thresholds, focus mode deferral, and sleep-aware scheduling.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Scheduling/SmartNotificationScheduler.swift)

private enum SNSPriority: String, Sendable, CaseIterable {
    case low, medium, high, critical
}

private enum SNSDeliveryDecision: Sendable {
    case now(reason: String)
    case deferred(until: Date, reason: String)

    var isImmediate: Bool {
        if case .now = self { return true }
        return false
    }

    var reason: String {
        switch self {
        case .now(let r): r
        case .deferred(_, let r): r
        }
    }

    var deferralDate: Date? {
        switch self {
        case .now: nil
        case .deferred(let date, _): date
        }
    }
}

private struct SNSContext: Sendable {
    let receptivity: Double
    let cognitiveLoad: Double
    let isAwake: Bool
    let isInFocusMode: Bool
}

// MARK: - Scheduler (mirrors production logic)

// @unchecked Sendable: test helper class used in single-threaded test context; no concurrent access
private final class TestSmartNotificationScheduler: @unchecked Sendable {
    var isEnabled = true
    var maxDelayHours = 4
    var receptivityThreshold = 0.3
    var bypassPriorities: Set<SNSPriority> = [.critical]

    var scheduledCount = 0
    var immediateCount = 0
    var deferredCount = 0

    // Simulated behavioral data
    var typicalWakeTime = 7
    var typicalSleepTime = 23
    var hourlyReceptivity: [Int: Double] = [:] // hour -> receptivity

    func optimalDeliveryTime(
        priority: SNSPriority,
        context: SNSContext,
        currentHour: Int
    ) -> SNSDeliveryDecision {
        scheduledCount += 1

        // Bypass if disabled or critical priority
        guard isEnabled, !bypassPriorities.contains(priority) else {
            immediateCount += 1
            return .now(reason: "Smart scheduling disabled or priority bypass")
        }

        // Focus mode deferral
        if context.isInFocusMode, priority != .high {
            deferredCount += 1
            let deferDate = Date().addingTimeInterval(30 * 60)
            return .deferred(until: deferDate, reason: "User in Focus Mode")
        }

        // Sleep deferral
        if !context.isAwake {
            deferredCount += 1
            let deferDate = nextOccurrence(ofHour: typicalWakeTime)
            return .deferred(until: deferDate, reason: "User likely asleep")
        }

        // High receptivity -> deliver now
        if context.receptivity >= receptivityThreshold {
            immediateCount += 1
            return .now(reason: "Current receptivity meets threshold")
        }

        // Low receptivity -> find better time within delay window
        let maxHour = min(currentHour + maxDelayHours, typicalSleepTime)
        var bestHour = currentHour
        var bestReceptivity = context.receptivity

        // Only search if there are future hours to check
        if currentHour + 1 <= maxHour {
            for hour in (currentHour + 1)...maxHour {
                let r = hourlyReceptivity[hour] ?? 0.5
                if r > bestReceptivity {
                    bestReceptivity = r
                    bestHour = hour
                }
            }
        }

        if bestHour == currentHour {
            immediateCount += 1
            return .now(reason: "No better time found within delay window")
        }

        deferredCount += 1
        return .deferred(
            until: nextOccurrence(ofHour: bestHour),
            reason: "Better receptivity at \(bestHour):00"
        )
    }

    private func nextOccurrence(ofHour hour: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        components.second = 0

        if let date = calendar.date(from: components), date > now {
            return date
        }
        components.day = (components.day ?? 0) + 1
        return calendar.date(from: components) ?? now
    }
}

// MARK: - Tests: Construction

@Suite("SmartNotificationScheduler — Construction")
struct SNSConstructionTests {
    @Test("Default configuration values")
    func defaults() {
        let scheduler = TestSmartNotificationScheduler()
        #expect(scheduler.isEnabled)
        #expect(scheduler.maxDelayHours == 4)
        #expect(scheduler.receptivityThreshold == 0.3)
        #expect(scheduler.bypassPriorities == [.critical])
    }

    @Test("Default statistics are zero")
    func defaultStats() {
        let scheduler = TestSmartNotificationScheduler()
        #expect(scheduler.scheduledCount == 0)
        #expect(scheduler.immediateCount == 0)
        #expect(scheduler.deferredCount == 0)
    }
}

// MARK: - Tests: Priority Bypass

@Suite("SmartNotificationScheduler — Priority Bypass")
struct SNSPriorityBypassTests {
    @Test("Critical priority always delivers immediately")
    func criticalBypass() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.0, cognitiveLoad: 1.0, isAwake: false, isInFocusMode: true)
        let decision = scheduler.optimalDeliveryTime(priority: .critical, context: context, currentHour: 3)
        #expect(decision.isImmediate)
    }

    @Test("High priority is NOT bypassed by default")
    func highNotBypassed() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.0, cognitiveLoad: 0.5, isAwake: false, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .high, context: context, currentHour: 3)
        #expect(!decision.isImmediate) // deferred because asleep
    }

    @Test("Custom bypass priorities are respected")
    func customBypass() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.bypassPriorities = [.critical, .high]
        let context = SNSContext(receptivity: 0.0, cognitiveLoad: 1.0, isAwake: false, isInFocusMode: true)
        let decision = scheduler.optimalDeliveryTime(priority: .high, context: context, currentHour: 3)
        #expect(decision.isImmediate)
    }
}

// MARK: - Tests: Disabled Scheduling

@Suite("SmartNotificationScheduler — Disabled Mode")
struct SNSDisabledTests {
    @Test("Disabled scheduler always delivers immediately")
    func disabledDeliversNow() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.isEnabled = false
        let context = SNSContext(receptivity: 0.0, cognitiveLoad: 1.0, isAwake: false, isInFocusMode: true)
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 3)
        #expect(decision.isImmediate)
        #expect(decision.reason.contains("disabled"))
    }
}

// MARK: - Tests: Focus Mode Deferral

@Suite("SmartNotificationScheduler — Focus Mode")
struct SNSFocusModeTests {
    @Test("Non-high priority deferred during focus mode")
    func lowDeferredInFocus() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.9, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: true)
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 10)
        #expect(!decision.isImmediate)
        #expect(decision.reason.contains("Focus Mode"))
    }

    @Test("Medium priority deferred during focus mode")
    func mediumDeferredInFocus() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.9, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: true)
        let decision = scheduler.optimalDeliveryTime(priority: .medium, context: context, currentHour: 10)
        #expect(!decision.isImmediate)
    }

    @Test("High priority NOT deferred during focus mode")
    func highNotDeferredInFocus() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.9, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: true)
        let decision = scheduler.optimalDeliveryTime(priority: .high, context: context, currentHour: 10)
        // High is not in bypassPriorities, and focus mode only defers non-high
        // The code checks: `priority != .high` for focus deferral, so high goes through
        #expect(decision.isImmediate)
    }

    @Test("Focus mode deferral is approximately 30 minutes")
    func focusDeferralDuration() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.9, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: true)
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 10)
        if let deferDate = decision.deferralDate {
            let delay = deferDate.timeIntervalSinceNow
            // Should be approximately 30 minutes (1800 seconds), with some tolerance
            #expect(delay > 1700 && delay < 1900)
        } else {
            Issue.record("Expected deferred decision with a date")
        }
    }
}

// MARK: - Tests: Sleep-Aware Scheduling

@Suite("SmartNotificationScheduler — Sleep Awareness")
struct SNSSleepTests {
    @Test("Notification deferred when user is asleep")
    func deferredWhenAsleep() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.8, cognitiveLoad: 0.0, isAwake: false, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 3)
        #expect(!decision.isImmediate)
        #expect(decision.reason.contains("asleep"))
    }

    @Test("Sleep deferral targets wake time")
    func defersToWakeTime() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.typicalWakeTime = 8
        let context = SNSContext(receptivity: 0.0, cognitiveLoad: 0.0, isAwake: false, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .medium, context: context, currentHour: 2)
        if let deferDate = decision.deferralDate {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: deferDate)
            #expect(hour == 8)
        } else {
            Issue.record("Expected deferred decision")
        }
    }
}

// MARK: - Tests: Receptivity-Based Decisions

@Suite("SmartNotificationScheduler — Receptivity Threshold")
struct SNSReceptivityTests {
    @Test("High receptivity delivers immediately")
    func highReceptivityImmediate() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.8, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .medium, context: context, currentHour: 10)
        #expect(decision.isImmediate)
        #expect(decision.reason.contains("receptivity"))
    }

    @Test("Receptivity exactly at threshold delivers immediately")
    func atThresholdImmediate() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.receptivityThreshold = 0.5
        let context = SNSContext(receptivity: 0.5, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .medium, context: context, currentHour: 10)
        #expect(decision.isImmediate)
    }

    @Test("Low receptivity with better future time defers")
    func lowReceptivityDefers() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.receptivityThreshold = 0.5
        scheduler.hourlyReceptivity[12] = 0.9 // Much better at noon
        let context = SNSContext(receptivity: 0.1, cognitiveLoad: 0.8, isAwake: true, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .medium, context: context, currentHour: 10)
        #expect(!decision.isImmediate)
        #expect(decision.reason.contains("12:00"))
    }

    @Test("Low receptivity with no better future time delivers now")
    func lowReceptivityNoBetterTime() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.receptivityThreshold = 0.5
        // All future hours have lower receptivity than current
        for h in 11...23 {
            scheduler.hourlyReceptivity[h] = 0.05
        }
        let context = SNSContext(receptivity: 0.1, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 10)
        #expect(decision.isImmediate)
        #expect(decision.reason.contains("No better time"))
    }

    @Test("Custom receptivity threshold is respected")
    func customThreshold() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.receptivityThreshold = 0.9 // Very high threshold
        let context = SNSContext(receptivity: 0.8, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        // 0.8 is below 0.9 threshold — should try to defer
        // With default hourlyReceptivity (nil = 0.5), no future hour beats 0.8
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 10)
        #expect(decision.isImmediate)
    }
}

// MARK: - Tests: Statistics Tracking

@Suite("SmartNotificationScheduler — Statistics")
struct SNSStatisticsTests {
    @Test("Scheduling increments scheduled count")
    func incrementsScheduled() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.8, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        _ = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 10)
        _ = scheduler.optimalDeliveryTime(priority: .medium, context: context, currentHour: 11)
        #expect(scheduler.scheduledCount == 2)
    }

    @Test("Immediate delivery increments immediate count")
    func incrementsImmediate() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.9, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        _ = scheduler.optimalDeliveryTime(priority: .medium, context: context, currentHour: 10)
        #expect(scheduler.immediateCount == 1)
        #expect(scheduler.deferredCount == 0)
    }

    @Test("Deferred delivery increments deferred count")
    func incrementsDeferred() {
        let scheduler = TestSmartNotificationScheduler()
        let context = SNSContext(receptivity: 0.0, cognitiveLoad: 0.0, isAwake: false, isInFocusMode: false)
        _ = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 3)
        #expect(scheduler.deferredCount == 1)
        #expect(scheduler.immediateCount == 0)
    }

    @Test("Statistics are cumulative across multiple calls")
    func cumulativeStats() {
        let scheduler = TestSmartNotificationScheduler()
        let awake = SNSContext(receptivity: 0.9, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        let asleep = SNSContext(receptivity: 0.0, cognitiveLoad: 0.0, isAwake: false, isInFocusMode: false)

        _ = scheduler.optimalDeliveryTime(priority: .medium, context: awake, currentHour: 10)
        _ = scheduler.optimalDeliveryTime(priority: .low, context: asleep, currentHour: 3)
        _ = scheduler.optimalDeliveryTime(priority: .critical, context: asleep, currentHour: 3)

        #expect(scheduler.scheduledCount == 3)
        #expect(scheduler.immediateCount == 2) // awake + critical
        #expect(scheduler.deferredCount == 1) // asleep low
    }
}

// MARK: - Tests: Max Delay Window

@Suite("SmartNotificationScheduler — Delay Window")
struct SNSDelayWindowTests {
    @Test("Search window respects maxDelayHours")
    func windowRespected() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.maxDelayHours = 2
        scheduler.receptivityThreshold = 0.5

        // Good receptivity at hour 15, but maxDelay is 2h from hour 10 -> max is 12
        scheduler.hourlyReceptivity[15] = 0.95
        scheduler.hourlyReceptivity[12] = 0.6

        let context = SNSContext(receptivity: 0.1, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 10)
        #expect(!decision.isImmediate)
        // Should find 12 (within window), not 15 (outside window)
        #expect(decision.reason.contains("12:00"))
    }

    @Test("Zero maxDelayHours causes immediate delivery with low receptivity")
    func zeroDelay() {
        let scheduler = TestSmartNotificationScheduler()
        scheduler.maxDelayHours = 0
        scheduler.receptivityThreshold = 0.5

        let context = SNSContext(receptivity: 0.1, cognitiveLoad: 0.5, isAwake: true, isInFocusMode: false)
        let decision = scheduler.optimalDeliveryTime(priority: .low, context: context, currentHour: 10)
        #expect(decision.isImmediate)
    }
}

// MARK: - Tests: DeliveryDecision Type

@Suite("DeliveryDecision — Properties")
struct SNSDeliveryDecisionTests {
    @Test("Now decision is immediate")
    func nowIsImmediate() {
        let d = SNSDeliveryDecision.now(reason: "test")
        #expect(d.isImmediate)
        #expect(d.deferralDate == nil)
    }

    @Test("Deferred decision is not immediate")
    func deferredNotImmediate() {
        let future = Date().addingTimeInterval(3600)
        let d = SNSDeliveryDecision.deferred(until: future, reason: "test")
        #expect(!d.isImmediate)
        #expect(d.deferralDate != nil)
    }

    @Test("Reason is accessible for both variants")
    func reasonAccessible() {
        let now = SNSDeliveryDecision.now(reason: "immediate reason")
        let deferred = SNSDeliveryDecision.deferred(until: Date(), reason: "deferred reason")
        #expect(now.reason == "immediate reason")
        #expect(deferred.reason == "deferred reason")
    }
}
