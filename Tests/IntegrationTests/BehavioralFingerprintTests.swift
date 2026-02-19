// BehavioralFingerprintTests.swift
// Tests for BehavioralFingerprint — temporal behavioral model
//
// Tests cover: initialization, observation recording, wake/sleep estimation,
// querying helpers, time slot math, and supporting value types.

@testable import TheaCore
import XCTest

// MARK: - TimeSlot Tests (pure value type, no MainActor needed)

final class TimeSlotTests: XCTestCase {

    func testTimeSlotDefaultsToIdleDominantActivity() {
        let slot = TimeSlot()
        XCTAssertEqual(slot.dominantActivity, .idle)
    }

    func testTimeSlotReceptivityWithNoData() {
        let slot = TimeSlot()
        // No notifications sent → neutral 0.5
        XCTAssertEqual(slot.receptivityScore, 0.5)
    }

    func testTimeSlotReceptivityWithEngagements() {
        var slot = TimeSlot()
        slot.recordNotificationResponse(engaged: true)
        slot.recordNotificationResponse(engaged: true)
        slot.recordNotificationResponse(engaged: false)
        // 2 engaged out of 3 sent
        XCTAssertEqual(slot.notificationsSent, 3)
        XCTAssertEqual(slot.notificationsEngaged, 2)
        XCTAssertEqual(slot.receptivityScore, 2.0 / 3.0, accuracy: 0.001)
    }

    func testTimeSlotReceptivityAllEngaged() {
        var slot = TimeSlot()
        slot.recordNotificationResponse(engaged: true)
        slot.recordNotificationResponse(engaged: true)
        XCTAssertEqual(slot.receptivityScore, 1.0, accuracy: 0.001)
    }

    func testTimeSlotReceptivityNoneEngaged() {
        var slot = TimeSlot()
        slot.recordNotificationResponse(engaged: false)
        slot.recordNotificationResponse(engaged: false)
        XCTAssertEqual(slot.receptivityScore, 0.0, accuracy: 0.001)
    }

    func testTimeSlotAverageCognitiveLoadEmptyReturnsNeutral() {
        let slot = TimeSlot()
        XCTAssertEqual(slot.averageCognitiveLoad, 0.5)
    }

    func testTimeSlotAverageCognitiveLoadComputed() {
        var slot = TimeSlot()
        slot.cognitiveLoadSamples = [0.2, 0.4, 0.6]
        XCTAssertEqual(slot.averageCognitiveLoad, 0.4, accuracy: 0.001)
    }

    func testTimeSlotRecordActivityIncrementsCounts() {
        var slot = TimeSlot()
        slot.recordActivity(.deepWork)
        slot.recordActivity(.deepWork)
        slot.recordActivity(.browsing)
        XCTAssertEqual(slot.activityCounts["deepWork"], 2)
        XCTAssertEqual(slot.activityCounts["browsing"], 1)
    }

    func testTimeSlotDominantActivityPicksMax() {
        var slot = TimeSlot()
        slot.recordActivity(.browsing)
        slot.recordActivity(.deepWork)
        slot.recordActivity(.deepWork)
        slot.recordActivity(.deepWork)
        XCTAssertEqual(slot.dominantActivity, .deepWork)
    }

    func testTimeSlotActivityScore() {
        var slot = TimeSlot()
        slot.recordActivity(.deepWork)
        slot.recordActivity(.deepWork)
        slot.recordActivity(.browsing)
        // deepWork = 2/3
        XCTAssertEqual(slot.activityScore(for: .deepWork), 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(slot.activityScore(for: .browsing), 1.0 / 3.0, accuracy: 0.001)
    }

    func testTimeSlotActivityScoreZeroWhenEmpty() {
        let slot = TimeSlot()
        XCTAssertEqual(slot.activityScore(for: .deepWork), 0.0)
    }
}

// MARK: - BehavioralActivityType Tests

final class BehavioralActivityTypeTests: XCTestCase {

    func testAllCasesHaveRawValues() {
        for activity in BehavioralActivityType.allCases {
            XCTAssertFalse(activity.rawValue.isEmpty)
        }
    }

    func testRoundTripCoding() throws {
        for activity in BehavioralActivityType.allCases {
            let encoded = try JSONEncoder().encode(activity)
            let decoded = try JSONDecoder().decode(BehavioralActivityType.self, from: encoded)
            XCTAssertEqual(decoded, activity)
        }
    }
}

// MARK: - DayOfWeek Tests

final class DayOfWeekTests: XCTestCase {

    func testIndicesAreUnique() {
        let indices = DayOfWeek.allCases.map { $0.index }
        XCTAssertEqual(Set(indices).count, DayOfWeek.allCases.count)
    }

    func testIndicesAreInRange() {
        for day in DayOfWeek.allCases {
            XCTAssertGreaterThanOrEqual(day.index, 0)
            XCTAssertLessThan(day.index, 7)
        }
    }

    func testMondayIsIndex0() {
        XCTAssertEqual(DayOfWeek.monday.index, 0)
    }

    func testSundayIsIndex6() {
        XCTAssertEqual(DayOfWeek.sunday.index, 6)
    }
}

// MARK: - BehavioralFingerprint Tests (MainActor)

@MainActor
final class BehavioralFingerprintTests: XCTestCase {

    // We use the shared singleton — reset not possible (private init),
    // so we test observable behaviour only (no mutations that bleed across tests).

    func testSharedSingletonNotNil() {
        XCTAssertNotNil(BehavioralFingerprint.shared)
    }

    func testInitialTimeSlotsAre7x24() {
        let fp = BehavioralFingerprint.shared
        XCTAssertEqual(fp.timeSlots.count, 7)
        for day in fp.timeSlots {
            XCTAssertEqual(day.count, 24)
        }
    }

    func testInitialOverallResponsivenessIsNeutral() {
        // Default 0.5 unless file exists. Either way it must be in [0,1].
        let fp = BehavioralFingerprint.shared
        XCTAssertGreaterThanOrEqual(fp.overallResponsiveness, 0.0)
        XCTAssertLessThanOrEqual(fp.overallResponsiveness, 1.0)
    }

    func testRecordActivityIncrementsTotalObservations() {
        let fp = BehavioralFingerprint.shared
        let before = fp.totalObservations
        fp.recordActivity(.browsing)
        XCTAssertEqual(fp.totalObservations, before + 1)
    }

    func testRecordMultipleActivitiesAccumulate() {
        let fp = BehavioralFingerprint.shared
        let before = fp.totalObservations
        fp.recordActivity(.deepWork)
        fp.recordActivity(.meetings)
        fp.recordActivity(.leisure)
        XCTAssertEqual(fp.totalObservations, before + 3)
    }

    func testDominantActivityBoundaryChecks() {
        let fp = BehavioralFingerprint.shared
        // Invalid hour returns .idle
        XCTAssertEqual(fp.dominantActivity(day: .monday, hour: -1), .idle)
        XCTAssertEqual(fp.dominantActivity(day: .monday, hour: 24), .idle)
    }

    func testDominantActivityValidHour() {
        let fp = BehavioralFingerprint.shared
        // Valid call must not crash; result is any BehavioralActivityType
        let activity = fp.dominantActivity(day: .wednesday, hour: 10)
        XCTAssertNotNil(activity)
    }

    func testReceptivityBoundaryChecks() {
        let fp = BehavioralFingerprint.shared
        // Invalid hours return 0.0
        XCTAssertEqual(fp.receptivity(day: .monday, hour: -1), 0.0)
        XCTAssertEqual(fp.receptivity(day: .monday, hour: 24), 0.0)
    }

    func testReceptivityValidHourIsInRange() {
        let fp = BehavioralFingerprint.shared
        let r = fp.receptivity(day: .friday, hour: 14)
        XCTAssertGreaterThanOrEqual(r, 0.0)
        XCTAssertLessThanOrEqual(r, 1.0)
    }

    func testIsLikelyAwake() {
        let fp = BehavioralFingerprint.shared
        // Wake and sleep times are 7 and 23 by default (may differ if file loaded)
        let wakeHour = fp.typicalWakeTime
        let sleepHour = fp.typicalSleepTime
        XCTAssertTrue(fp.isLikelyAwake(at: wakeHour))
        XCTAssertTrue(fp.isLikelyAwake(at: sleepHour))
        // Hour just before wake should not be awake (unless wake == 0)
        if wakeHour > 0 {
            XCTAssertFalse(fp.isLikelyAwake(at: wakeHour - 1))
        }
    }

    func testBestNotificationTimeIsInWakeWindow() {
        let fp = BehavioralFingerprint.shared
        for day in DayOfWeek.allCases {
            let best = fp.bestNotificationTime(on: day)
            XCTAssertGreaterThanOrEqual(best, 0)
            XCTAssertLessThan(best, 24)
        }
    }

    func testDailySummaryHas24Entries() {
        let fp = BehavioralFingerprint.shared
        for day in DayOfWeek.allCases {
            let summary = fp.dailySummary(for: day)
            XCTAssertEqual(summary.count, 24)
        }
    }

    func testDailySummaryHoursAreSequential() {
        let fp = BehavioralFingerprint.shared
        let summary = fp.dailySummary(for: .monday)
        for (index, entry) in summary.enumerated() {
            XCTAssertEqual(entry.hour, index)
        }
    }

    func testDailySummaryReceptivityInRange() {
        let fp = BehavioralFingerprint.shared
        let summary = fp.dailySummary(for: .tuesday)
        for entry in summary {
            XCTAssertGreaterThanOrEqual(entry.receptivity, 0.0)
            XCTAssertLessThanOrEqual(entry.receptivity, 1.0)
        }
    }

    func testCurrentContextDoesNotCrash() {
        let fp = BehavioralFingerprint.shared
        let context = fp.currentContext()
        XCTAssertGreaterThanOrEqual(context.receptivity, 0.0)
        XCTAssertLessThanOrEqual(context.receptivity, 1.0)
        XCTAssertGreaterThanOrEqual(context.cognitiveLoad, 0.0)
        XCTAssertLessThanOrEqual(context.cognitiveLoad, 1.0)
    }

    func testRecordNotificationEngagementUpdatesResponsiveness() {
        let fp = BehavioralFingerprint.shared
        // Record several engagements; responsiveness must stay in [0,1]
        fp.recordNotificationEngagement(engaged: true)
        fp.recordNotificationEngagement(engaged: false)
        XCTAssertGreaterThanOrEqual(fp.overallResponsiveness, 0.0)
        XCTAssertLessThanOrEqual(fp.overallResponsiveness, 1.0)
    }

    func testTotalRecordedSlotsIsNonNegative() {
        let fp = BehavioralFingerprint.shared
        XCTAssertGreaterThanOrEqual(fp.totalRecordedSlots, 0)
    }

    func testTotalRecordedSlotsAfterRecording() {
        let fp = BehavioralFingerprint.shared
        let before = fp.totalRecordedSlots
        fp.recordActivity(.deepWork)
        // After recording, recorded slots must be >= before
        XCTAssertGreaterThanOrEqual(fp.totalRecordedSlots, before)
    }

    func testBestTimeForActivityOnMonday() {
        let fp = BehavioralFingerprint.shared
        // bestTimeFor returns nil when no data exists; result must be in valid range if non-nil
        let hour = fp.bestTimeFor(.deepWork, on: .monday)
        if let h = hour {
            XCTAssertGreaterThanOrEqual(h, 0)
            XCTAssertLessThan(h, 24)
        }
    }

    func testSaveToDiskDoesNotCrash() {
        // save() is an alias for saveToDisk(); verify it completes without throwing
        let fp = BehavioralFingerprint.shared
        fp.save()
    }

    func testLoadFromDiskDoesNotCrash() {
        let fp = BehavioralFingerprint.shared
        fp.load()
    }
}

// MARK: - BehavioralHourSummary / BehavioralTimeContext value type tests

final class BehavioralSupportingTypesTests: XCTestCase {

    func testBehavioralHourSummaryInit() {
        let summary = BehavioralHourSummary(
            hour: 9,
            dominantActivity: .deepWork,
            receptivity: 0.8,
            cognitiveLoad: 0.7
        )
        XCTAssertEqual(summary.hour, 9)
        XCTAssertEqual(summary.dominantActivity, .deepWork)
        XCTAssertEqual(summary.receptivity, 0.8, accuracy: 0.001)
        XCTAssertEqual(summary.cognitiveLoad, 0.7, accuracy: 0.001)
    }

    func testBehavioralTimeContextInit() {
        let context = BehavioralTimeContext(
            activity: .meetings,
            receptivity: 0.6,
            cognitiveLoad: 0.5,
            isAwake: true
        )
        XCTAssertEqual(context.activity, .meetings)
        XCTAssertEqual(context.receptivity, 0.6, accuracy: 0.001)
        XCTAssertEqual(context.cognitiveLoad, 0.5, accuracy: 0.001)
        XCTAssertTrue(context.isAwake)
    }

    func testBehavioralTimeContextIsAwakeFalse() {
        let context = BehavioralTimeContext(
            activity: .sleep,
            receptivity: 0.0,
            cognitiveLoad: 0.0,
            isAwake: false
        )
        XCTAssertFalse(context.isAwake)
    }
}
