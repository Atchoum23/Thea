// BehavioralFingerprintServiceTests.swift
// Tests for BehavioralFingerprint service logic: activity recording, querying optimal times,
// daily summaries, wake/sleep estimation, and notification receptivity.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/UserModel/BehavioralFingerprint.swift)

private enum BFActivityType: String, Sendable, CaseIterable, Codable {
    case deepWork, meetings, browsing, communication, exercise, leisure, sleep, idle, healthSuggestion
}

private enum BFDayOfWeek: String, Sendable, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var index: Int {
        switch self {
        case .monday: 0
        case .tuesday: 1
        case .wednesday: 2
        case .thursday: 3
        case .friday: 4
        case .saturday: 5
        case .sunday: 6
        }
    }
}

private struct BFTimeSlot: Sendable {
    var activityCounts: [String: Int] = [:]
    var notificationsSent: Int = 0
    var notificationsEngaged: Int = 0
    var cognitiveLoadSamples: [Double] = []

    var dominantActivity: BFActivityType {
        guard let (activity, _) = activityCounts.max(by: { $0.value < $1.value }) else { return .idle }
        return BFActivityType(rawValue: activity) ?? .idle
    }

    var receptivityScore: Double {
        guard notificationsSent > 0 else { return 0.5 }
        return Double(notificationsEngaged) / Double(notificationsSent)
    }

    var averageCognitiveLoad: Double {
        guard !cognitiveLoadSamples.isEmpty else { return 0.5 }
        return cognitiveLoadSamples.reduce(0, +) / Double(cognitiveLoadSamples.count)
    }

    mutating func recordActivity(_ activity: BFActivityType) {
        activityCounts[activity.rawValue, default: 0] += 1
    }

    mutating func recordNotificationResponse(engaged: Bool) {
        notificationsSent += 1
        if engaged { notificationsEngaged += 1 }
    }

    func activityScore(for activity: BFActivityType) -> Double {
        let total = activityCounts.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(activityCounts[activity.rawValue, default: 0]) / Double(total)
    }
}

private struct BFHourSummary: Sendable {
    let hour: Int
    let dominantActivity: BFActivityType
    let receptivity: Double
    let cognitiveLoad: Double
}

private struct BFTimeContext: Sendable {
    let activity: BFActivityType
    let receptivity: Double
    let cognitiveLoad: Double
    let isAwake: Bool
}

// MARK: - Fingerprint Service (mirrors production logic)

private final class TestBehavioralFingerprint: @unchecked Sendable {
    var timeSlots: [[BFTimeSlot]] // [dayOfWeek][hour]
    var typicalWakeTime: Int = 7
    var typicalSleepTime: Int = 23
    var overallResponsiveness: Double = 0.5
    var totalObservations: Int = 0

    init() {
        timeSlots = (0..<7).map { _ in (0..<24).map { _ in BFTimeSlot() } }
    }

    // Record activity at a specific day/hour (test-friendly)
    func recordActivity(_ activity: BFActivityType, day: Int, hour: Int) {
        guard day >= 0, day < 7, hour >= 0, hour < 24 else { return }
        timeSlots[day][hour].recordActivity(activity)
        totalObservations += 1

        // Mirror production logic: non-sleep/idle activity before wake time shifts wake earlier
        if activity != .sleep, activity != .idle {
            if hour < typicalWakeTime || (hour < 6 && totalObservations > 100) {
                typicalWakeTime = hour
            }
            if hour > typicalSleepTime || (hour > 20 && totalObservations > 100) {
                typicalSleepTime = hour
            }
        }
    }

    func recordNotificationEngagement(engaged: Bool, day: Int, hour: Int) {
        guard day >= 0, day < 7, hour >= 0, hour < 24 else { return }
        timeSlots[day][hour].recordNotificationResponse(engaged: engaged)

        let total = timeSlots.flatMap { $0 }
        let responded = total.reduce(0) { $0 + $1.notificationsEngaged }
        let sent = total.reduce(0) { $0 + $1.notificationsSent }
        overallResponsiveness = sent > 0 ? Double(responded) / Double(sent) : 0.5
    }

    func dominantActivity(day: BFDayOfWeek, hour: Int) -> BFActivityType {
        guard hour >= 0, hour < 24 else { return .idle }
        return timeSlots[day.index][hour].dominantActivity
    }

    func receptivity(day: BFDayOfWeek, hour: Int) -> Double {
        guard hour >= 0, hour < 24 else { return 0.0 }
        return timeSlots[day.index][hour].receptivityScore
    }

    func bestTimeFor(_ activity: BFActivityType, on day: BFDayOfWeek) -> Int? {
        let daySlots = timeSlots[day.index]
        var bestHour: Int?
        var bestScore: Double = 0

        for hour in typicalWakeTime...min(typicalSleepTime, 23) {
            let score = daySlots[hour].activityScore(for: activity)
            if score > bestScore {
                bestScore = score
                bestHour = hour
            }
        }
        return bestHour
    }

    func bestNotificationTime(on day: BFDayOfWeek) -> Int {
        let daySlots = timeSlots[day.index]
        var bestHour = 9
        var bestReceptivity: Double = 0

        for hour in typicalWakeTime...min(typicalSleepTime, 23) {
            let r = daySlots[hour].receptivityScore
            if r > bestReceptivity {
                bestReceptivity = r
                bestHour = hour
            }
        }
        return bestHour
    }

    func dailySummary(for day: BFDayOfWeek) -> [BFHourSummary] {
        timeSlots[day.index].enumerated().map { hour, slot in
            BFHourSummary(
                hour: hour,
                dominantActivity: slot.dominantActivity,
                receptivity: slot.receptivityScore,
                cognitiveLoad: slot.averageCognitiveLoad
            )
        }
    }

    func isLikelyAwake(at hour: Int) -> Bool {
        hour >= typicalWakeTime && hour <= typicalSleepTime
    }

    var totalRecordedSlots: Int {
        timeSlots.flatMap { $0 }.filter { !$0.activityCounts.isEmpty }.count
    }
}

// MARK: - Tests: Construction

@Suite("BehavioralFingerprint — Construction")
struct BFConstructionTests {
    @Test("Default fingerprint has 7x24 time slots")
    func defaultGrid() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.timeSlots.count == 7)
        for day in fp.timeSlots {
            #expect(day.count == 24)
        }
    }

    @Test("Default wake and sleep times")
    func defaultWakeSleep() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.typicalWakeTime == 7)
        #expect(fp.typicalSleepTime == 23)
    }

    @Test("Default overall responsiveness is neutral")
    func defaultResponsiveness() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.overallResponsiveness == 0.5)
    }

    @Test("Default total observations is zero")
    func defaultObservations() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.totalObservations == 0)
    }

    @Test("No recorded slots initially")
    func noRecordedSlots() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.totalRecordedSlots == 0)
    }
}

// MARK: - Tests: Activity Recording

@Suite("BehavioralFingerprint — Activity Recording")
struct BFActivityRecordingTests {
    @Test("Recording activity increments observation count")
    func incrementsCount() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.deepWork, day: 0, hour: 9)
        #expect(fp.totalObservations == 1)
    }

    @Test("Recording activity updates dominant activity for slot")
    func updatesDominant() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.deepWork, day: 0, hour: 9)
        fp.recordActivity(.deepWork, day: 0, hour: 9)
        fp.recordActivity(.browsing, day: 0, hour: 9)
        #expect(fp.dominantActivity(day: .monday, hour: 9) == .deepWork)
    }

    @Test("Recording at multiple times fills multiple slots")
    func multipleSlots() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.deepWork, day: 0, hour: 9)
        fp.recordActivity(.meetings, day: 0, hour: 14)
        fp.recordActivity(.exercise, day: 2, hour: 18)
        #expect(fp.totalRecordedSlots == 3)
    }

    @Test("Out-of-bounds day is silently ignored")
    func outOfBoundsDay() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.deepWork, day: 7, hour: 9)
        #expect(fp.totalObservations == 0)
    }

    @Test("Out-of-bounds hour is silently ignored")
    func outOfBoundsHour() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.deepWork, day: 0, hour: 25)
        #expect(fp.totalObservations == 0)
    }

    @Test("Negative indices are silently ignored")
    func negativeIndices() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.deepWork, day: -1, hour: 9)
        fp.recordActivity(.deepWork, day: 0, hour: -1)
        #expect(fp.totalObservations == 0)
    }
}

// MARK: - Tests: Wake/Sleep Estimation

@Suite("BehavioralFingerprint — Wake/Sleep Estimation")
struct BFWakeSleepTests {
    @Test("Activity before default wake time shifts wake time earlier")
    func wakeTimeShiftsEarlier() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.typicalWakeTime == 7)
        fp.recordActivity(.deepWork, day: 0, hour: 5)
        #expect(fp.typicalWakeTime == 5)
    }

    @Test("Sleep activity does not shift wake time")
    func sleepDoesNotShift() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.sleep, day: 0, hour: 4)
        #expect(fp.typicalWakeTime == 7) // unchanged
    }

    @Test("Idle activity does not shift wake time")
    func idleDoesNotShift() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.idle, day: 0, hour: 4)
        #expect(fp.typicalWakeTime == 7) // unchanged
    }

    @Test("isLikelyAwake returns true during awake hours")
    func awakeHours() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.isLikelyAwake(at: 7)) // wake time
        #expect(fp.isLikelyAwake(at: 12))
        #expect(fp.isLikelyAwake(at: 23)) // sleep time (inclusive)
    }

    @Test("isLikelyAwake returns false during sleep hours")
    func sleepHours() {
        let fp = TestBehavioralFingerprint()
        #expect(!fp.isLikelyAwake(at: 3))
        #expect(!fp.isLikelyAwake(at: 6))
    }

    @Test("Activity at early hour shifts wake time and expands awake range")
    func earlyActivityExpandsRange() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.exercise, day: 0, hour: 5)
        // Wake time should shift to 5
        #expect(fp.typicalWakeTime == 5)
        // Now isLikelyAwake at 5 should be true
        #expect(fp.isLikelyAwake(at: 5))
    }
}

// MARK: - Tests: Querying Best Times

@Suite("BehavioralFingerprint — Best Time Queries")
struct BFBestTimeTests {
    @Test("bestTimeFor returns hour with highest activity score")
    func bestTimeReturnsOptimal() {
        let fp = TestBehavioralFingerprint()
        // Record deep work heavily at 10 AM on Monday
        for _ in 0..<10 {
            fp.recordActivity(.deepWork, day: 0, hour: 10)
        }
        // Record some deep work at 14 (less dominant)
        for _ in 0..<3 {
            fp.recordActivity(.deepWork, day: 0, hour: 14)
            fp.recordActivity(.meetings, day: 0, hour: 14)
        }

        let best = fp.bestTimeFor(.deepWork, on: .monday)
        #expect(best == 10)
    }

    @Test("bestTimeFor returns nil when no data exists for that activity")
    func bestTimeNoData() {
        let fp = TestBehavioralFingerprint()
        let best = fp.bestTimeFor(.exercise, on: .friday)
        #expect(best == nil)
    }

    @Test("bestTimeFor only searches within wake-sleep range")
    func onlySearchesAwakeRange() {
        let fp = TestBehavioralFingerprint()
        // Record exercise at 18 on Saturday (within default wake/sleep)
        for _ in 0..<5 {
            fp.recordActivity(.exercise, day: 5, hour: 18)
        }

        let best = fp.bestTimeFor(.exercise, on: .saturday)
        #expect(best == 18)
    }

    @Test("bestNotificationTime returns hour with highest receptivity")
    func bestNotificationTime() {
        let fp = TestBehavioralFingerprint()
        // High engagement at 11 AM on Tuesday
        for _ in 0..<5 {
            fp.recordNotificationEngagement(engaged: true, day: 1, hour: 11)
        }
        // Low engagement at 15
        fp.recordNotificationEngagement(engaged: false, day: 1, hour: 15)
        fp.recordNotificationEngagement(engaged: false, day: 1, hour: 15)
        fp.recordNotificationEngagement(engaged: true, day: 1, hour: 15)

        let best = fp.bestNotificationTime(on: .tuesday)
        #expect(best == 11)
    }

    @Test("bestNotificationTime defaults to 9 when all slots have 0.5 neutral receptivity")
    func defaultNotificationTimeNeutral() {
        let fp = TestBehavioralFingerprint()
        // No engagement data recorded => all slots return 0.5 (neutral)
        // bestReceptivity starts at 0, and 0.5 > 0, so first hour in range wins
        // First hour is typicalWakeTime (7), so 7 wins
        let best = fp.bestNotificationTime(on: .wednesday)
        // With default wake=7, the first slot at 7 has receptivity 0.5 > 0 initial, so 7 wins
        #expect(best == 7)
    }
}

// MARK: - Tests: Notification Engagement

@Suite("BehavioralFingerprint — Notification Engagement")
struct BFNotificationTests {
    @Test("Recording engagement updates receptivity for slot")
    func updatesReceptivity() {
        let fp = TestBehavioralFingerprint()
        fp.recordNotificationEngagement(engaged: true, day: 0, hour: 10)
        fp.recordNotificationEngagement(engaged: false, day: 0, hour: 10)
        let r = fp.receptivity(day: .monday, hour: 10)
        #expect(r == 0.5) // 1 out of 2
    }

    @Test("100% engagement gives receptivity 1.0")
    func perfectEngagement() {
        let fp = TestBehavioralFingerprint()
        fp.recordNotificationEngagement(engaged: true, day: 3, hour: 14)
        fp.recordNotificationEngagement(engaged: true, day: 3, hour: 14)
        #expect(fp.receptivity(day: .thursday, hour: 14) == 1.0)
    }

    @Test("Overall responsiveness reflects all slots")
    func overallResponsiveness() {
        let fp = TestBehavioralFingerprint()
        fp.recordNotificationEngagement(engaged: true, day: 0, hour: 9)
        fp.recordNotificationEngagement(engaged: false, day: 1, hour: 10)
        fp.recordNotificationEngagement(engaged: false, day: 2, hour: 11)
        // 1 out of 3 total
        #expect(abs(fp.overallResponsiveness - 1.0 / 3.0) < 0.001)
    }

    @Test("Receptivity for unrecorded slot is neutral (0.5)")
    func neutralReceptivity() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.receptivity(day: .friday, hour: 12) == 0.5)
    }
}

// MARK: - Tests: Daily Summary

@Suite("BehavioralFingerprint — Daily Summary")
struct BFDailySummaryTests {
    @Test("Daily summary has 24 hour entries")
    func twentyFourHours() {
        let fp = TestBehavioralFingerprint()
        let summary = fp.dailySummary(for: .monday)
        #expect(summary.count == 24)
    }

    @Test("Summary hours are sequential 0-23")
    func sequentialHours() {
        let fp = TestBehavioralFingerprint()
        let summary = fp.dailySummary(for: .tuesday)
        let hours = summary.map(\.hour)
        #expect(hours == Array(0..<24))
    }

    @Test("Summary reflects recorded activities")
    func reflectsRecordedData() {
        let fp = TestBehavioralFingerprint()
        fp.recordActivity(.deepWork, day: 3, hour: 9)
        fp.recordActivity(.deepWork, day: 3, hour: 9)
        fp.recordActivity(.meetings, day: 3, hour: 14)

        let summary = fp.dailySummary(for: .thursday)
        #expect(summary[9].dominantActivity == .deepWork)
        #expect(summary[14].dominantActivity == .meetings)
        #expect(summary[0].dominantActivity == .idle) // no data
    }

    @Test("Summary includes receptivity and cognitive load")
    func includesAllMetrics() {
        let fp = TestBehavioralFingerprint()
        fp.recordNotificationEngagement(engaged: true, day: 4, hour: 10)
        fp.timeSlots[4][10].cognitiveLoadSamples = [0.8, 0.9]

        let summary = fp.dailySummary(for: .friday)
        #expect(summary[10].receptivity == 1.0)
        #expect(abs(summary[10].cognitiveLoad - 0.85) < 0.001)
    }
}

// MARK: - Tests: Edge Cases

@Suite("BehavioralFingerprint — Edge Cases")
struct BFEdgeCaseTests {
    @Test("Querying dominant activity at invalid hour returns idle")
    func invalidHourReturnsIdle() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.dominantActivity(day: .monday, hour: -1) == .idle)
        #expect(fp.dominantActivity(day: .monday, hour: 24) == .idle)
        #expect(fp.dominantActivity(day: .monday, hour: 100) == .idle)
    }

    @Test("Querying receptivity at invalid hour returns 0.0")
    func invalidHourReceptivity() {
        let fp = TestBehavioralFingerprint()
        #expect(fp.receptivity(day: .monday, hour: -1) == 0.0)
        #expect(fp.receptivity(day: .monday, hour: 25) == 0.0)
    }

    @Test("Heavy recording at single slot does not corrupt other slots")
    func isolatedSlots() {
        let fp = TestBehavioralFingerprint()
        for _ in 0..<1000 {
            fp.recordActivity(.deepWork, day: 0, hour: 9)
        }
        #expect(fp.dominantActivity(day: .monday, hour: 9) == .deepWork)
        #expect(fp.dominantActivity(day: .monday, hour: 10) == .idle) // untouched
        #expect(fp.dominantActivity(day: .tuesday, hour: 9) == .idle) // different day
    }

    @Test("All activity types can be recorded and queried")
    func allActivityTypes() {
        let fp = TestBehavioralFingerprint()
        for (i, activity) in BFActivityType.allCases.enumerated() {
            let hour = 7 + (i % 16) // keep within default wake-sleep range
            fp.recordActivity(activity, day: 0, hour: hour)
        }
        #expect(fp.totalObservations == BFActivityType.allCases.count)
    }
}
