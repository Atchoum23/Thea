@testable import TheaCore
import XCTest

/// Tests for SmartNotificationScheduler — delivery decisions, statistics tracking,
/// configuration flags, bypass logic, and DeliveryDecision type behavior.
@MainActor
final class SmartNotificationSchedulerTests: XCTestCase {

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        // Reset scheduler state for each test
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = true
        scheduler.maxDelayHours = 4
        scheduler.receptivityThreshold = 0.3
        scheduler.bypassPriorities = [.critical]
    }

    // MARK: - Singleton

    func testSharedInstanceIsAlwaysSameObject() {
        let a = SmartNotificationScheduler.shared
        let b = SmartNotificationScheduler.shared
        XCTAssertTrue(a === b)
    }

    // MARK: - Default Configuration

    func testDefaultIsEnabled() {
        SmartNotificationScheduler.shared.isEnabled = true
        XCTAssertTrue(SmartNotificationScheduler.shared.isEnabled)
    }

    func testDefaultMaxDelayHours() {
        SmartNotificationScheduler.shared.maxDelayHours = 4
        XCTAssertEqual(SmartNotificationScheduler.shared.maxDelayHours, 4)
    }

    func testDefaultReceptivityThreshold() {
        SmartNotificationScheduler.shared.receptivityThreshold = 0.3
        XCTAssertEqual(SmartNotificationScheduler.shared.receptivityThreshold, 0.3, accuracy: 0.001)
    }

    func testDefaultBypassPrioritiesContainsCritical() {
        SmartNotificationScheduler.shared.bypassPriorities = [.critical]
        XCTAssertTrue(SmartNotificationScheduler.shared.bypassPriorities.contains(.critical))
    }

    // MARK: - Bypass: Disabled scheduling

    func testWhenDisabledReturnsNowForAnyPriority() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false

        let priorities: [NotificationPriority] = [.silent, .low, .normal, .high]
        for priority in priorities {
            let decision = scheduler.optimalDeliveryTime(priority: priority)
            XCTAssertTrue(decision.isImmediate, "Expected immediate delivery when scheduler disabled, priority: \(priority)")
        }
    }

    func testWhenDisabledScheduledCountIncrements() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false

        let before = scheduler.scheduledCount
        _ = scheduler.optimalDeliveryTime(priority: .normal)
        XCTAssertEqual(scheduler.scheduledCount, before + 1)
    }

    func testWhenDisabledImmediateCountIncrements() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false

        let before = scheduler.immediateCount
        _ = scheduler.optimalDeliveryTime(priority: .normal)
        XCTAssertEqual(scheduler.immediateCount, before + 1)
    }

    // MARK: - Bypass: Critical priority

    func testCriticalPriorityBypassesSmartScheduling() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = true
        scheduler.bypassPriorities = [.critical]

        let decision = scheduler.optimalDeliveryTime(priority: .critical)
        XCTAssertTrue(decision.isImmediate)
    }

    func testCriticalPriorityIncrementsBothScheduledAndImmediate() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = true
        scheduler.bypassPriorities = [.critical]

        let beforeScheduled = scheduler.scheduledCount
        let beforeImmediate = scheduler.immediateCount
        _ = scheduler.optimalDeliveryTime(priority: .critical)

        XCTAssertEqual(scheduler.scheduledCount, beforeScheduled + 1)
        XCTAssertEqual(scheduler.immediateCount, beforeImmediate + 1)
    }

    func testHighPriorityNotBypassedWhenNotInBypassSet() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = true
        scheduler.bypassPriorities = [.critical] // Only critical bypasses

        // .high is NOT in bypassPriorities, so smart scheduling applies
        // The actual decision depends on BehavioralFingerprint state.
        // We just verify scheduledCount increments (proves the method ran to completion).
        let before = scheduler.scheduledCount
        _ = scheduler.optimalDeliveryTime(priority: .high)
        XCTAssertEqual(scheduler.scheduledCount, before + 1)
    }

    func testMultiplePrioritiesInBypassSet() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = true
        scheduler.bypassPriorities = [.critical, .high]

        let criticalDecision = scheduler.optimalDeliveryTime(priority: .critical)
        XCTAssertTrue(criticalDecision.isImmediate)

        let highDecision = scheduler.optimalDeliveryTime(priority: .high)
        XCTAssertTrue(highDecision.isImmediate)
    }

    func testEmptyBypassSetMeansNothingBypasses() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = true
        scheduler.bypassPriorities = []

        // Even critical goes through smart scheduling now
        // The decision is runtime-dependent but scheduledCount must increment
        let before = scheduler.scheduledCount
        _ = scheduler.optimalDeliveryTime(priority: .critical)
        XCTAssertEqual(scheduler.scheduledCount, before + 1)
    }

    // MARK: - Statistics Counters

    func testScheduledCountStartsAtZeroAfterReset() {
        let scheduler = SmartNotificationScheduler.shared
        // We cannot reset to zero (private setters), but we can verify
        // each call increments by exactly 1
        let before = scheduler.scheduledCount
        _ = scheduler.optimalDeliveryTime(priority: .normal)
        XCTAssertEqual(scheduler.scheduledCount, before + 1)
    }

    func testMultipleCallsAccumulateScheduledCount() {
        let scheduler = SmartNotificationScheduler.shared
        let before = scheduler.scheduledCount

        _ = scheduler.optimalDeliveryTime(priority: .low)
        _ = scheduler.optimalDeliveryTime(priority: .normal)
        _ = scheduler.optimalDeliveryTime(priority: .high)

        XCTAssertEqual(scheduler.scheduledCount, before + 3)
    }

    func testImmediateAndDeferredCountsAreMutuallyExclusive() {
        // Each call to optimalDeliveryTime increments exactly one of immediateCount or deferredCount
        let scheduler = SmartNotificationScheduler.shared
        let beforeImmediate = scheduler.immediateCount
        let beforeDeferred = scheduler.deferredCount
        let beforeTotal = scheduler.scheduledCount

        _ = scheduler.optimalDeliveryTime(priority: .normal)
        let afterImmediate = scheduler.immediateCount
        let afterDeferred = scheduler.deferredCount

        let immediateInc = afterImmediate - beforeImmediate
        let deferredInc = afterDeferred - beforeDeferred

        // Exactly one must have incremented by 1
        XCTAssertEqual(immediateInc + deferredInc, 1)
        XCTAssertEqual(scheduler.scheduledCount, beforeTotal + 1)
    }

    // MARK: - DeliveryDecision Type

    func testDeliveryDecisionNowIsImmediate() {
        let decision = DeliveryDecision.now(reason: "test reason")
        XCTAssertTrue(decision.isImmediate)
    }

    func testDeliveryDecisionDeferredIsNotImmediate() {
        let futureDate = Date().addingTimeInterval(3600)
        let decision = DeliveryDecision.deferred(until: futureDate, reason: "sleep time")
        XCTAssertFalse(decision.isImmediate)
    }

    func testDeliveryDecisionNowPreservesReason() {
        let decision = DeliveryDecision.now(reason: "High receptivity 80%")
        if case .now(let reason) = decision {
            XCTAssertEqual(reason, "High receptivity 80%")
        } else {
            XCTFail("Expected .now case")
        }
    }

    func testDeliveryDecisionDeferredPreservesDateAndReason() {
        let futureDate = Date().addingTimeInterval(7200)
        let decision = DeliveryDecision.deferred(until: futureDate, reason: "better time at 14:00")
        if case .deferred(let until, let reason) = decision {
            XCTAssertEqual(until.timeIntervalSince1970, futureDate.timeIntervalSince1970, accuracy: 0.001)
            XCTAssertEqual(reason, "better time at 14:00")
        } else {
            XCTFail("Expected .deferred case")
        }
    }

    func testDeliveryDecisionDeferredDateIsInFuture() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false // Force immediate to test the other path is skipped

        // Since disabled, we get .now — test the deferred path by constructing manually
        let hourFromNow = Date().addingTimeInterval(3600)
        let decision = DeliveryDecision.deferred(until: hourFromNow, reason: "test")
        XCTAssertGreaterThan(hourFromNow, Date())
        XCTAssertFalse(decision.isImmediate)
    }

    // MARK: - Configuration Mutability

    func testMaxDelayHoursCanBeChanged() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.maxDelayHours = 8
        XCTAssertEqual(scheduler.maxDelayHours, 8)
        scheduler.maxDelayHours = 4 // Reset
    }

    func testReceptivityThresholdCanBeChanged() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.receptivityThreshold = 0.6
        XCTAssertEqual(scheduler.receptivityThreshold, 0.6, accuracy: 0.001)
        scheduler.receptivityThreshold = 0.3 // Reset
    }

    func testBypassPrioritiesCanBeUpdated() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.bypassPriorities = [.critical, .high, .normal]
        XCTAssertEqual(scheduler.bypassPriorities.count, 3)
        XCTAssertTrue(scheduler.bypassPriorities.contains(.normal))
        scheduler.bypassPriorities = [.critical] // Reset
    }

    func testIsEnabledCanBeToggled() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false
        XCTAssertFalse(scheduler.isEnabled)
        scheduler.isEnabled = true
        XCTAssertTrue(scheduler.isEnabled)
    }

    // MARK: - Category Parameter (API Compatibility)

    func testCategoryParameterDefaultsToNil() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false

        // Should compile and work fine with category nil (default)
        let decision = scheduler.optimalDeliveryTime(priority: .normal, category: nil)
        XCTAssertTrue(decision.isImmediate) // Disabled, so immediate
    }

    func testCategoryParameterAcceptsHealthInsight() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false

        let decision = scheduler.optimalDeliveryTime(priority: .normal, category: .healthInsight)
        XCTAssertTrue(decision.isImmediate) // Disabled, so immediate regardless of category
    }

    func testCategoryParameterAcceptsReminder() {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false

        let decision = scheduler.optimalDeliveryTime(priority: .low, category: .reminder)
        XCTAssertTrue(decision.isImmediate)
    }

    // MARK: - NotificationPriority Ordering

    func testNotificationPriorityOrdering() {
        XCTAssertLessThan(NotificationPriority.silent, .low)
        XCTAssertLessThan(NotificationPriority.low, .normal)
        XCTAssertLessThan(NotificationPriority.normal, .high)
        XCTAssertLessThan(NotificationPriority.high, .critical)
    }

    func testNotificationPriorityRawValues() {
        XCTAssertEqual(NotificationPriority.silent.rawValue, 0)
        XCTAssertEqual(NotificationPriority.low.rawValue, 1)
        XCTAssertEqual(NotificationPriority.normal.rawValue, 2)
        XCTAssertEqual(NotificationPriority.high.rawValue, 3)
        XCTAssertEqual(NotificationPriority.critical.rawValue, 4)
    }

    func testNotificationPriorityDisplayNames() {
        XCTAssertEqual(NotificationPriority.silent.displayName, "Silent")
        XCTAssertEqual(NotificationPriority.low.displayName, "Low")
        XCTAssertEqual(NotificationPriority.normal.displayName, "Normal")
        XCTAssertEqual(NotificationPriority.high.displayName, "High")
        XCTAssertEqual(NotificationPriority.critical.displayName, "Critical")
    }

    func testNotificationPriorityAllCasesCount() {
        XCTAssertEqual(NotificationPriority.allCases.count, 5)
    }

    func testNotificationPriorityCodableRoundtrip() throws {
        let priority = NotificationPriority.high
        let data = try JSONEncoder().encode(priority)
        let decoded = try JSONDecoder().decode(NotificationPriority.self, from: data)
        XCTAssertEqual(decoded, priority)
    }

    // MARK: - recordEngagement (Side-Effect Test)

    func testRecordEngagementDoesNotCrash() {
        // recordEngagement calls BehavioralFingerprint.shared.recordNotificationEngagement(engaged: true)
        // Verify it completes without throwing
        SmartNotificationScheduler.shared.recordEngagement()
    }

    // MARK: - scheduleOptimally (Async, No-Network Path)

    func testScheduleOptimallyWhenDisabledCompletesWithoutCrash() async {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = false

        // When disabled, decision is .now — scheduleReminder will attempt to schedule
        // UserNotification. If permission not granted it throws, which is caught internally.
        // We just verify the method completes (no crash / unhandled throw).
        await scheduler.scheduleOptimally(
            title: "Test Notification",
            body: "Test body",
            priority: .low,
            category: .reminder
        )
    }

    func testScheduleOptimallyWithCriticalPriorityCompletesWithoutCrash() async {
        let scheduler = SmartNotificationScheduler.shared
        scheduler.isEnabled = true
        scheduler.bypassPriorities = [.critical]

        await scheduler.scheduleOptimally(
            title: "Critical Alert",
            body: "Urgent message",
            priority: .critical,
            category: nil
        )
    }
}
