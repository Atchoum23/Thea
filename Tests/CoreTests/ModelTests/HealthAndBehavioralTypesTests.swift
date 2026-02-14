// HealthAndBehavioralTypesTests.swift
// Tests for HealthCoachingPipeline + BehavioralFingerprint types (standalone test doubles)

import Testing
import Foundation

// MARK: - Health Coaching Test Doubles

private enum TestSleepQuality: String, Sendable, CaseIterable {
    case poor, fair, good, excellent

    var score: Double {
        switch self {
        case .poor: 0.25
        case .fair: 0.5
        case .good: 0.75
        case .excellent: 1.0
        }
    }
}

private enum TestHealthDataPoint: Sendable {
    case sleep(totalMinutes: Int, deepMinutes: Int, remMinutes: Int, quality: TestSleepQuality, date: Date)
    case activity(steps: Int, activeCalories: Int, exerciseMinutes: Int, date: Date)
    case heartRate(averageBPM: Int, restingBPM: Int, date: Date)
    case bloodPressure(systolic: Int, diastolic: Int, date: Date)

    var category: String {
        switch self {
        case .sleep: "sleep"
        case .activity: "activity"
        case .heartRate: "heartRate"
        case .bloodPressure: "bloodPressure"
        }
    }
}

private struct TestCoachingInsight: Identifiable, Sendable {
    let id = UUID()
    let category: TestCoachingInsightCategory
    let severity: TestCoachingSeverity
    let title: String
    let message: String
    let suggestion: String
    let dataValue: Double
}

private enum TestCoachingInsightCategory: String, Sendable, CaseIterable {
    case sleep, activity, heartRate, bloodPressure, nutrition, stress
}

private enum TestCoachingSeverity: String, Sendable, CaseIterable, Comparable {
    case critical, warning, info, positive

    var rank: Int {
        switch self {
        case .critical: 3
        case .warning: 2
        case .info: 1
        case .positive: 0
        }
    }

    static func < (lhs: TestCoachingSeverity, rhs: TestCoachingSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

private struct TestHealthAnalysisReport: Sendable {
    let date: Date
    let dataPoints: [TestHealthDataPoint]
    let insights: [TestCoachingInsight]
    let overallScore: Double
}

// MARK: - Behavioral Fingerprint Test Doubles

private struct TestTimeSlot: Codable, Sendable {
    var activityCounts: [String: Int] = [:]
    var notificationsSent: Int = 0
    var notificationsEngaged: Int = 0
    var cognitiveLoadSamples: [Double] = []

    var dominantActivity: TestBehavioralActivityType {
        guard let (activity, _) = activityCounts.max(by: { $0.value < $1.value }) else {
            return .idle
        }
        return TestBehavioralActivityType(rawValue: activity) ?? .idle
    }

    var receptivityScore: Double {
        guard notificationsSent > 0 else { return 0.5 }
        return Double(notificationsEngaged) / Double(notificationsSent)
    }

    var averageCognitiveLoad: Double {
        guard !cognitiveLoadSamples.isEmpty else { return 0.5 }
        return cognitiveLoadSamples.reduce(0, +) / Double(cognitiveLoadSamples.count)
    }

    mutating func recordActivity(_ activity: TestBehavioralActivityType) {
        activityCounts[activity.rawValue, default: 0] += 1
    }

    mutating func recordNotificationResponse(engaged: Bool) {
        notificationsSent += 1
        if engaged { notificationsEngaged += 1 }
    }

    func activityScore(for activity: TestBehavioralActivityType) -> Double {
        let total = activityCounts.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(activityCounts[activity.rawValue, default: 0]) / Double(total)
    }
}

private enum TestBehavioralActivityType: String, Codable, Sendable, CaseIterable {
    case deepWork, meetings, browsing, communication, exercise, leisure, sleep, idle, healthSuggestion
}

private enum TestDayOfWeek: String, Sendable, CaseIterable {
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

private struct TestBehavioralTimeContext: Sendable {
    let activity: TestBehavioralActivityType
    let receptivity: Double
    let cognitiveLoad: Double
    let isAwake: Bool
}

// MARK: - Health Data Point Tests

@Suite("Health Data Point — Categories")
struct HealthDataPointCategoryTests {
    @Test("Sleep data point has sleep category")
    func sleepCategory() {
        let dp = TestHealthDataPoint.sleep(totalMinutes: 480, deepMinutes: 90, remMinutes: 120, quality: .good, date: Date())
        #expect(dp.category == "sleep")
    }

    @Test("Activity data point has activity category")
    func activityCategory() {
        let dp = TestHealthDataPoint.activity(steps: 10000, activeCalories: 500, exerciseMinutes: 30, date: Date())
        #expect(dp.category == "activity")
    }

    @Test("Heart rate data point has heartRate category")
    func heartRateCategory() {
        let dp = TestHealthDataPoint.heartRate(averageBPM: 72, restingBPM: 60, date: Date())
        #expect(dp.category == "heartRate")
    }

    @Test("Blood pressure data point has bloodPressure category")
    func bloodPressureCategory() {
        let dp = TestHealthDataPoint.bloodPressure(systolic: 120, diastolic: 80, date: Date())
        #expect(dp.category == "bloodPressure")
    }
}

// MARK: - Sleep Quality Tests

@Suite("Sleep Quality — Scoring")
struct SleepQualityTests {
    @Test("All 4 quality levels exist")
    func allCases() {
        #expect(TestSleepQuality.allCases.count == 4)
    }

    @Test("Quality scores are monotonically increasing")
    func scoresOrdered() {
        let scores = [TestSleepQuality.poor, .fair, .good, .excellent].map(\.score)
        for i in 0..<scores.count - 1 {
            #expect(scores[i] < scores[i + 1])
        }
    }

    @Test("Poor sleep scores 0.25")
    func poorScore() { #expect(TestSleepQuality.poor.score == 0.25) }

    @Test("Excellent sleep scores 1.0")
    func excellentScore() { #expect(TestSleepQuality.excellent.score == 1.0) }
}

// MARK: - Coaching Severity Tests

@Suite("Coaching Severity — Ranking")
struct CoachingSeverityTests {
    @Test("All 4 severity levels exist")
    func allCases() {
        #expect(TestCoachingSeverity.allCases.count == 4)
    }

    @Test("Critical has highest rank")
    func criticalRank() { #expect(TestCoachingSeverity.critical.rank == 3) }

    @Test("Positive has lowest rank")
    func positiveRank() { #expect(TestCoachingSeverity.positive.rank == 0) }

    @Test("Severity is Comparable: critical > warning > info > positive")
    func severityOrdering() {
        #expect(TestCoachingSeverity.positive < .info)
        #expect(TestCoachingSeverity.info < .warning)
        #expect(TestCoachingSeverity.warning < .critical)
    }

    @Test("Sorted severities are in ascending order")
    func sortedOrder() {
        let sorted = [TestCoachingSeverity.warning, .positive, .critical, .info].sorted()
        #expect(sorted == [.positive, .info, .warning, .critical])
    }
}

// MARK: - Coaching Insight Category Tests

@Suite("Coaching Insight Category — Completeness")
struct CoachingInsightCategoryTests {
    @Test("All 6 categories exist")
    func allCases() {
        #expect(TestCoachingInsightCategory.allCases.count == 6)
    }

    @Test("All categories have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestCoachingInsightCategory.allCases.map(\.rawValue))
        #expect(rawValues.count == TestCoachingInsightCategory.allCases.count)
    }

    @Test("Key categories present: sleep, activity, heartRate")
    func keyCategories() {
        let cases = TestCoachingInsightCategory.allCases.map(\.rawValue)
        #expect(cases.contains("sleep"))
        #expect(cases.contains("activity"))
        #expect(cases.contains("heartRate"))
    }
}

// MARK: - Health Analysis Report Tests

@Suite("Health Analysis Report — Construction")
struct HealthAnalysisReportTests {
    @Test("Report with no insights")
    func emptyInsights() {
        let report = TestHealthAnalysisReport(date: Date(), dataPoints: [], insights: [], overallScore: 0.0)
        #expect(report.insights.isEmpty)
        #expect(report.overallScore == 0.0)
    }

    @Test("Report preserves overall score")
    func scorePreserved() {
        let report = TestHealthAnalysisReport(date: Date(), dataPoints: [], insights: [], overallScore: 0.85)
        #expect(report.overallScore == 0.85)
    }

    @Test("Report limits active insights via prefix")
    func limitedInsights() {
        let insights = (0..<10).map { i in
            TestCoachingInsight(category: .sleep, severity: .info, title: "T\(i)", message: "", suggestion: "", dataValue: 0)
        }
        let maxActive = 5
        let active = Array(insights.prefix(maxActive))
        #expect(active.count == maxActive)
    }
}

// MARK: - Time Slot Tests

@Suite("Time Slot — Activity Tracking")
struct TimeSlotTests {
    @Test("Default time slot has idle as dominant activity")
    func defaultDominant() {
        let slot = TestTimeSlot()
        #expect(slot.dominantActivity == .idle)
    }

    @Test("Recording activities updates dominant")
    func recordActivity() {
        var slot = TestTimeSlot()
        slot.recordActivity(.deepWork)
        slot.recordActivity(.deepWork)
        slot.recordActivity(.browsing)
        #expect(slot.dominantActivity == .deepWork)
    }

    @Test("Default receptivity score is 0.5 (unknown)")
    func defaultReceptivity() {
        let slot = TestTimeSlot()
        #expect(slot.receptivityScore == 0.5)
    }

    @Test("Receptivity score reflects engagement ratio")
    func receptivityEngagement() {
        var slot = TestTimeSlot()
        slot.recordNotificationResponse(engaged: true)
        slot.recordNotificationResponse(engaged: true)
        slot.recordNotificationResponse(engaged: false)
        #expect(slot.receptivityScore == 2.0 / 3.0)
    }

    @Test("100% engagement gives receptivity 1.0")
    func perfectReceptivity() {
        var slot = TestTimeSlot()
        slot.recordNotificationResponse(engaged: true)
        slot.recordNotificationResponse(engaged: true)
        #expect(slot.receptivityScore == 1.0)
    }

    @Test("0% engagement gives receptivity 0.0")
    func zeroReceptivity() {
        var slot = TestTimeSlot()
        slot.recordNotificationResponse(engaged: false)
        slot.recordNotificationResponse(engaged: false)
        #expect(slot.receptivityScore == 0.0)
    }

    @Test("Default cognitive load is 0.5")
    func defaultCognitiveLoad() {
        let slot = TestTimeSlot()
        #expect(slot.averageCognitiveLoad == 0.5)
    }

    @Test("Cognitive load averages samples")
    func cognitiveLoadAverage() {
        var slot = TestTimeSlot()
        slot.cognitiveLoadSamples = [0.2, 0.4, 0.6]
        #expect(abs(slot.averageCognitiveLoad - 0.4) < 0.001)
    }

    @Test("Activity score for unrecorded activity is 0")
    func zeroActivityScore() {
        let slot = TestTimeSlot()
        #expect(slot.activityScore(for: .deepWork) == 0.0)
    }

    @Test("Activity score reflects proportion")
    func activityScoreProportion() {
        var slot = TestTimeSlot()
        slot.recordActivity(.deepWork)
        slot.recordActivity(.deepWork)
        slot.recordActivity(.browsing)
        slot.recordActivity(.browsing)
        #expect(slot.activityScore(for: .deepWork) == 0.5)
    }

    @Test("TimeSlot is Codable")
    func codableRoundtrip() throws {
        var slot = TestTimeSlot()
        slot.recordActivity(.deepWork)
        slot.recordNotificationResponse(engaged: true)
        slot.cognitiveLoadSamples = [0.3, 0.7]

        let data = try JSONEncoder().encode(slot)
        let decoded = try JSONDecoder().decode(TestTimeSlot.self, from: data)
        #expect(decoded.dominantActivity == .deepWork)
        #expect(decoded.notificationsSent == 1)
        #expect(decoded.notificationsEngaged == 1)
        #expect(decoded.cognitiveLoadSamples.count == 2)
    }
}

// MARK: - Behavioral Activity Type Tests

@Suite("Behavioral Activity Type — Enum")
struct BehavioralActivityTypeTests {
    @Test("All 9 activity types exist")
    func allCases() {
        #expect(TestBehavioralActivityType.allCases.count == 9)
    }

    @Test("All activity types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestBehavioralActivityType.allCases.map(\.rawValue))
        #expect(rawValues.count == TestBehavioralActivityType.allCases.count)
    }

    @Test("Activity type roundtrips through raw value")
    func rawValueRoundtrip() {
        for activity in TestBehavioralActivityType.allCases {
            #expect(TestBehavioralActivityType(rawValue: activity.rawValue) == activity)
        }
    }

    @Test("Invalid raw value returns nil")
    func invalidRawValue() {
        #expect(TestBehavioralActivityType(rawValue: "invalidActivity") == nil)
    }

    @Test("Activity type is Codable")
    func codableRoundtrip() throws {
        let activity = TestBehavioralActivityType.deepWork
        let data = try JSONEncoder().encode(activity)
        let decoded = try JSONDecoder().decode(TestBehavioralActivityType.self, from: data)
        #expect(decoded == activity)
    }
}

// MARK: - Day of Week Tests

@Suite("Day of Week — Index Mapping")
struct DayOfWeekTests {
    @Test("All 7 days exist")
    func allCases() {
        #expect(TestDayOfWeek.allCases.count == 7)
    }

    @Test("Monday is index 0")
    func mondayIndex() { #expect(TestDayOfWeek.monday.index == 0) }

    @Test("Sunday is index 6")
    func sundayIndex() { #expect(TestDayOfWeek.sunday.index == 6) }

    @Test("All indices are unique 0-6")
    func uniqueIndices() {
        let indices = Set(TestDayOfWeek.allCases.map(\.index))
        #expect(indices == Set(0..<7))
    }

    @Test("Indices are consecutive starting from Monday")
    func consecutiveIndices() {
        let expected = [0, 1, 2, 3, 4, 5, 6]
        let actual = TestDayOfWeek.allCases.map(\.index)
        #expect(actual == expected)
    }
}

// MARK: - Behavioral Time Context Tests

@Suite("Behavioral Time Context — State")
struct BehavioralTimeContextTests {
    @Test("Awake context with high receptivity")
    func awakeHighReceptivity() {
        let ctx = TestBehavioralTimeContext(activity: .deepWork, receptivity: 0.9, cognitiveLoad: 0.7, isAwake: true)
        #expect(ctx.isAwake)
        #expect(ctx.receptivity > 0.5)
        #expect(ctx.activity == .deepWork)
    }

    @Test("Sleep context")
    func sleepContext() {
        let ctx = TestBehavioralTimeContext(activity: .sleep, receptivity: 0.0, cognitiveLoad: 0.0, isAwake: false)
        #expect(!ctx.isAwake)
        #expect(ctx.receptivity == 0.0)
    }

    @Test("Idle context has neutral receptivity")
    func idleContext() {
        let ctx = TestBehavioralTimeContext(activity: .idle, receptivity: 0.5, cognitiveLoad: 0.3, isAwake: true)
        #expect(ctx.isAwake)
        #expect(ctx.receptivity == 0.5)
    }
}

// MARK: - Coaching Insight Construction Tests

@Suite("Coaching Insight — Construction")
struct CoachingInsightTests {
    @Test("Insight has unique ID")
    func uniqueID() {
        let a = TestCoachingInsight(category: .sleep, severity: .warning, title: "Low sleep", message: "", suggestion: "", dataValue: 5.5)
        let b = TestCoachingInsight(category: .sleep, severity: .warning, title: "Low sleep", message: "", suggestion: "", dataValue: 5.5)
        #expect(a.id != b.id)
    }

    @Test("Critical insights sort before info")
    func severitySorting() {
        let critical = TestCoachingInsight(category: .heartRate, severity: .critical, title: "High HR", message: "", suggestion: "", dataValue: 110)
        let info = TestCoachingInsight(category: .activity, severity: .info, title: "Low steps", message: "", suggestion: "", dataValue: 3000)
        let sorted = [info, critical].sorted { $0.severity > $1.severity }
        #expect(sorted.first?.severity == .critical)
    }
}
