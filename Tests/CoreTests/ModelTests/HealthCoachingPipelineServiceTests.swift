// HealthCoachingPipelineServiceTests.swift
// Tests for HealthCoachingPipeline service logic: state management, cooldown enforcement,
// sleep/activity/heart-rate/blood-pressure analysis, insight generation, scoring, and edge cases.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Intelligence/Health/HealthCoachingPipeline.swift)

private enum HCSleepQuality: String, Sendable {
    case poor, fair, good, excellent

    var score: Int {
        switch self {
        case .poor: 25
        case .fair: 50
        case .good: 75
        case .excellent: 100
        }
    }
}

private enum HCHealthDataPoint: Sendable {
    case sleep(totalMinutes: Int, deepMinutes: Int, remMinutes: Int, quality: HCSleepQuality, date: Date)
    case activity(steps: Int, activeCalories: Int, exerciseMinutes: Int, date: Date)
    case heartRate(averageBPM: Int, restingBPM: Int, date: Date)
    case bloodPressure(systolic: Int, diastolic: Int, date: Date)
}

private enum HCInsightCategory: String, Sendable {
    case sleep, activity, heartRate, bloodPressure, nutrition, stress
}

private enum HCSeverity: String, Sendable {
    case critical, warning, info, positive

    var rank: Int {
        switch self {
        case .critical: 3
        case .warning: 2
        case .info: 1
        case .positive: 0
        }
    }
}

private struct HCInsight: Identifiable, Sendable {
    let id = UUID()
    let category: HCInsightCategory
    let severity: HCSeverity
    let title: String
    let message: String
    let suggestion: String
    let dataValue: Double
}

private struct HCReport: Sendable {
    let date: Date
    let dataPoints: [HCHealthDataPoint]
    let insights: [HCInsight]
    let overallScore: Double
}

// MARK: - Pipeline Logic (mirrors production analysis engine)

// @unchecked Sendable: test helper class, single-threaded test context
private final class TestHealthCoachingPipeline: @unchecked Sendable {
    var isEnabled = true
    var analysisCooldownHours = 6
    var maxActiveInsights = 5
    var isAnalyzing = false
    var lastAnalysisDate: Date?
    var activeInsights: [HCInsight] = []
    var lastReport: HCReport?

    func canRunAnalysis() -> Bool {
        guard isEnabled else { return false }
        guard !isAnalyzing else { return false }

        if let lastDate = lastAnalysisDate {
            let hoursSince = Date().timeIntervalSince(lastDate) / 3600
            guard hoursSince >= Double(analysisCooldownHours) else {
                return false
            }
        }
        return true
    }

    func runAnalysis(with data: [HCHealthDataPoint]) {
        guard canRunAnalysis() else { return }
        guard !data.isEmpty else { return }

        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysisDate = Date()
        }

        let insights = analyzeHealthData(data)
        let score = calculateOverallScore(from: data)

        lastReport = HCReport(date: Date(), dataPoints: data, insights: insights, overallScore: score)
        activeInsights = Array(insights.prefix(maxActiveInsights))
    }

    func analyzeHealthData(_ data: [HCHealthDataPoint]) -> [HCInsight] {
        var insights: [HCInsight] = []
        insights.append(contentsOf: analyzeSleepData(from: data))
        insights.append(contentsOf: analyzeActivityData(from: data))
        insights.append(contentsOf: analyzeHeartRateData(from: data))
        insights.append(contentsOf: analyzeBloodPressureData(from: data))
        insights.sort { $0.severity.rank > $1.severity.rank }
        return insights
    }

    func analyzeSleepData(from data: [HCHealthDataPoint]) -> [HCInsight] {
        var insights: [HCInsight] = []

        let sleepData = data.compactMap { point -> (Int, Int, Int, HCSleepQuality, Date)? in
            if case let .sleep(total, deep, rem, quality, date) = point {
                return (total, deep, rem, quality, date)
            }
            return nil
        }

        guard !sleepData.isEmpty else { return insights }

        let totalSleepMinutes: Int = sleepData.reduce(into: 0) { $0 += $1.0 }
        let avgSleepMinutes: Int = totalSleepMinutes / sleepData.count
        var deepPercentSum: Double = 0
        for entry in sleepData {
            deepPercentSum += Double(entry.1) / Double(max(entry.0, 1))
        }
        let avgDeepPercent: Double = deepPercentSum / Double(sleepData.count) * 100

        if avgSleepMinutes < 360 {
            insights.append(HCInsight(
                category: .sleep,
                severity: .warning,
                title: "Sleep duration below target",
                message: "You averaged \(avgSleepMinutes / 60)h \(avgSleepMinutes % 60)m of sleep this week.",
                suggestion: "Try setting a consistent bedtime alarm 8 hours before your wake time.",
                dataValue: Double(avgSleepMinutes)
            ))
        }

        if avgDeepPercent < 15 {
            insights.append(HCInsight(
                category: .sleep,
                severity: .info,
                title: "Deep sleep could improve",
                message: "Deep sleep averaged \(String(format: "%.0f%%", avgDeepPercent)) this week.",
                suggestion: "Avoid screens 1 hour before bed.",
                dataValue: avgDeepPercent
            ))
        }

        let poorNights = sleepData.filter { $0.3 == .poor }.count
        if poorNights >= 3 {
            insights.append(HCInsight(
                category: .sleep,
                severity: .warning,
                title: "Multiple poor sleep nights",
                message: "\(poorNights) out of \(sleepData.count) nights rated as poor quality.",
                suggestion: "Consider evaluating your sleep environment.",
                dataValue: Double(poorNights)
            ))
        }

        return insights
    }

    func analyzeActivityData(from data: [HCHealthDataPoint]) -> [HCInsight] {
        var insights: [HCInsight] = []

        let activityData = data.compactMap { point -> (Int, Int, Int, Date)? in
            if case let .activity(steps, calories, minutes, date) = point {
                return (steps, calories, minutes, date)
            }
            return nil
        }

        guard let today = activityData.last else { return insights }

        if today.0 < 5000 {
            insights.append(HCInsight(
                category: .activity,
                severity: .info,
                title: "Step count below target",
                message: "\(today.0) steps today.",
                suggestion: "A 30-minute walk adds roughly 3,000-4,000 steps.",
                dataValue: Double(today.0)
            ))
        }

        if today.2 < 30 {
            insights.append(HCInsight(
                category: .activity,
                severity: .info,
                title: "Exercise minutes running low",
                message: "\(today.2) minutes of exercise today.",
                suggestion: "Even 10 minutes of brisk walking counts.",
                dataValue: Double(today.2)
            ))
        }

        return insights
    }

    func analyzeHeartRateData(from data: [HCHealthDataPoint]) -> [HCInsight] {
        var insights: [HCInsight] = []

        let hrData = data.compactMap { point -> (Int, Int, Date)? in
            if case let .heartRate(avg, resting, date) = point {
                return (avg, resting, date)
            }
            return nil
        }

        if let latestHR = hrData.last, latestHR.1 > 0, latestHR.1 > 100 {
            insights.append(HCInsight(
                category: .heartRate,
                severity: .warning,
                title: "Elevated resting heart rate",
                message: "Resting heart rate is \(latestHR.1) BPM.",
                suggestion: "Factors: stress, caffeine, dehydration, lack of sleep.",
                dataValue: Double(latestHR.1)
            ))
        }

        return insights
    }

    func analyzeBloodPressureData(from data: [HCHealthDataPoint]) -> [HCInsight] {
        var insights: [HCInsight] = []

        let bpData = data.compactMap { point -> (Int, Int, Date)? in
            if case let .bloodPressure(sys, dia, date) = point {
                return (sys, dia, date)
            }
            return nil
        }

        guard let latestBP = bpData.last else { return insights }

        if latestBP.0 >= 140 || latestBP.1 >= 90 {
            insights.append(HCInsight(
                category: .bloodPressure,
                severity: .critical,
                title: "High blood pressure reading",
                message: "Latest reading: \(latestBP.0)/\(latestBP.1) mmHg.",
                suggestion: "Monitor regularly. Consult your healthcare provider.",
                dataValue: Double(latestBP.0)
            ))
        } else if latestBP.0 >= 130 || latestBP.1 >= 80 {
            insights.append(HCInsight(
                category: .bloodPressure,
                severity: .warning,
                title: "Elevated blood pressure",
                message: "Latest reading: \(latestBP.0)/\(latestBP.1) mmHg.",
                suggestion: "Reduce sodium, increase physical activity.",
                dataValue: Double(latestBP.0)
            ))
        }

        return insights
    }

    func calculateOverallScore(from data: [HCHealthDataPoint]) -> Double {
        var scores: [Double] = []

        for point in data {
            switch point {
            case let .sleep(total, _, _, quality, _):
                let durationScore = min(Double(total) / 480.0, 1.0)
                let qualityScore = Double(quality.score) / 100.0
                scores.append((durationScore + qualityScore) / 2.0)

            case let .activity(steps, _, minutes, _):
                let stepScore = min(Double(steps) / 10000.0, 1.0)
                let exerciseScore = min(Double(minutes) / 30.0, 1.0)
                scores.append((stepScore + exerciseScore) / 2.0)

            case let .heartRate(_, resting, _):
                if resting > 0 {
                    let hrScore = resting <= 70 ? 1.0 : max(0, 1.0 - Double(resting - 70) / 50.0)
                    scores.append(hrScore)
                }

            case let .bloodPressure(systolic, _, _):
                let bpScore = systolic <= 120 ? 1.0 : max(0, 1.0 - Double(systolic - 120) / 40.0)
                scores.append(bpScore)
            }
        }

        return scores.isEmpty ? 0.5 : scores.reduce(0, +) / Double(scores.count)
    }

    func dismissInsight(_ id: UUID) {
        activeInsights.removeAll { $0.id == id }
    }

    func clearAllInsights() {
        activeInsights.removeAll()
    }
}

// MARK: - Tests: Pipeline State Management

@Suite("HealthCoachingPipeline — State Management")
struct HCStateTests {
    @Test("Default state: enabled, not analyzing")
    func defaultState() {
        let pipeline = TestHealthCoachingPipeline()
        #expect(pipeline.isEnabled)
        #expect(!pipeline.isAnalyzing)
        #expect(pipeline.lastAnalysisDate == nil)
        #expect(pipeline.activeInsights.isEmpty)
        #expect(pipeline.lastReport == nil)
    }

    @Test("Default cooldown is 6 hours")
    func defaultCooldown() {
        let pipeline = TestHealthCoachingPipeline()
        #expect(pipeline.analysisCooldownHours == 6)
    }

    @Test("Default max active insights is 5")
    func defaultMaxInsights() {
        let pipeline = TestHealthCoachingPipeline()
        #expect(pipeline.maxActiveInsights == 5)
    }

    @Test("Analysis sets lastAnalysisDate")
    func setsLastAnalysisDate() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [.activity(steps: 3000, activeCalories: 200, exerciseMinutes: 10, date: Date())]
        pipeline.runAnalysis(with: data)
        #expect(pipeline.lastAnalysisDate != nil)
    }

    @Test("Analysis resets isAnalyzing after completion")
    func resetsAnalyzingFlag() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [.activity(steps: 3000, activeCalories: 200, exerciseMinutes: 10, date: Date())]
        pipeline.runAnalysis(with: data)
        #expect(!pipeline.isAnalyzing)
    }

    @Test("Disabled pipeline does not analyze")
    func disabledDoesNotAnalyze() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.isEnabled = false
        let data: [HCHealthDataPoint] = [.activity(steps: 3000, activeCalories: 200, exerciseMinutes: 10, date: Date())]
        pipeline.runAnalysis(with: data)
        #expect(pipeline.lastReport == nil)
    }
}

// MARK: - Tests: Cooldown Enforcement

@Suite("HealthCoachingPipeline — Cooldown Enforcement")
struct HCCooldownTests {
    @Test("First analysis has no cooldown")
    func firstAnalysisNoCooldown() {
        let pipeline = TestHealthCoachingPipeline()
        #expect(pipeline.canRunAnalysis())
    }

    @Test("Cannot run analysis during cooldown")
    func cannotRunDuringCooldown() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.lastAnalysisDate = Date() // Just analyzed
        #expect(!pipeline.canRunAnalysis())
    }

    @Test("Can run analysis after cooldown expires")
    func canRunAfterCooldown() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.lastAnalysisDate = Date().addingTimeInterval(-7 * 3600) // 7 hours ago
        pipeline.analysisCooldownHours = 6
        #expect(pipeline.canRunAnalysis())
    }

    @Test("Cannot run exactly at cooldown boundary")
    func exactCooldownBoundary() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.analysisCooldownHours = 6
        // 5 hours 59 minutes ago
        pipeline.lastAnalysisDate = Date().addingTimeInterval(-5.99 * 3600)
        #expect(!pipeline.canRunAnalysis())
    }

    @Test("Custom cooldown is respected")
    func customCooldown() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.analysisCooldownHours = 1
        pipeline.lastAnalysisDate = Date().addingTimeInterval(-2 * 3600)
        #expect(pipeline.canRunAnalysis())
    }

    @Test("Zero cooldown always allows analysis")
    func zeroCooldown() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.analysisCooldownHours = 0
        pipeline.lastAnalysisDate = Date()
        #expect(pipeline.canRunAnalysis())
    }

    @Test("Empty data prevents actual analysis even when cooldown allows")
    func emptyDataPreventsAnalysis() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.runAnalysis(with: [])
        #expect(pipeline.lastReport == nil)
    }
}

// MARK: - Tests: Sleep Analysis Rules

@Suite("HealthCoachingPipeline — Sleep Analysis")
struct HCSleepAnalysisTests {
    @Test("Short sleep duration triggers warning")
    func shortSleepWarning() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 300, deepMinutes: 60, remMinutes: 60, quality: .fair, date: Date())
        ]
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(insights.contains { $0.title == "Sleep duration below target" })
        #expect(insights.first { $0.title == "Sleep duration below target" }?.severity == .warning)
    }

    @Test("Adequate sleep duration does not trigger warning")
    func adequateSleepNoWarning() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 480, deepMinutes: 100, remMinutes: 100, quality: .good, date: Date())
        ]
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(!insights.contains { $0.title == "Sleep duration below target" })
    }

    @Test("360 minutes exactly does not trigger short sleep warning")
    func exactThresholdNoWarning() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 360, deepMinutes: 80, remMinutes: 80, quality: .fair, date: Date())
        ]
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(!insights.contains { $0.title == "Sleep duration below target" })
    }

    @Test("Low deep sleep percentage triggers info insight")
    func lowDeepSleep() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 480, deepMinutes: 50, remMinutes: 100, quality: .fair, date: Date())
        ]
        // deepPercent = 50/480 * 100 ~ 10.4%
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(insights.contains { $0.title == "Deep sleep could improve" })
    }

    @Test("Adequate deep sleep percentage does not trigger insight")
    func adequateDeepSleep() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 480, deepMinutes: 100, remMinutes: 100, quality: .good, date: Date())
        ]
        // deepPercent = 100/480 * 100 ~ 20.8%
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(!insights.contains { $0.title == "Deep sleep could improve" })
    }

    @Test("Three or more poor sleep nights trigger warning")
    func multiplePoorNights() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 400, deepMinutes: 80, remMinutes: 80, quality: .poor, date: Date()),
            .sleep(totalMinutes: 380, deepMinutes: 70, remMinutes: 70, quality: .poor, date: Date()),
            .sleep(totalMinutes: 390, deepMinutes: 75, remMinutes: 75, quality: .poor, date: Date()),
            .sleep(totalMinutes: 420, deepMinutes: 90, remMinutes: 90, quality: .good, date: Date()),
        ]
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(insights.contains { $0.title == "Multiple poor sleep nights" })
    }

    @Test("Two poor sleep nights do not trigger warning")
    func twoPoorNightsNoWarning() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 400, deepMinutes: 80, remMinutes: 80, quality: .poor, date: Date()),
            .sleep(totalMinutes: 380, deepMinutes: 70, remMinutes: 70, quality: .poor, date: Date()),
            .sleep(totalMinutes: 420, deepMinutes: 90, remMinutes: 90, quality: .good, date: Date()),
        ]
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(!insights.contains { $0.title == "Multiple poor sleep nights" })
    }

    @Test("No sleep data produces no insights")
    func noSleepData() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 5000, activeCalories: 300, exerciseMinutes: 30, date: Date())
        ]
        let insights = pipeline.analyzeSleepData(from: data)
        #expect(insights.isEmpty)
    }

    @Test("Sleep data value stores average minutes correctly")
    func sleepDataValueCorrect() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 300, deepMinutes: 60, remMinutes: 60, quality: .fair, date: Date())
        ]
        let insights = pipeline.analyzeSleepData(from: data)
        let durationInsight = insights.first { $0.title == "Sleep duration below target" }
        #expect(durationInsight?.dataValue == 300.0)
    }
}

// MARK: - Tests: Activity Analysis Rules

@Suite("HealthCoachingPipeline — Activity Analysis")
struct HCActivityAnalysisTests {
    @Test("Low step count triggers info insight")
    func lowStepCount() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 3000, activeCalories: 200, exerciseMinutes: 40, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(insights.contains { $0.title == "Step count below target" })
        #expect(insights.first { $0.title == "Step count below target" }?.severity == .info)
    }

    @Test("Adequate step count does not trigger insight")
    func adequateStepCount() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 8000, activeCalories: 400, exerciseMinutes: 40, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(!insights.contains { $0.title == "Step count below target" })
    }

    @Test("5000 steps exactly does not trigger insight")
    func exactThresholdNoInsight() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 5000, activeCalories: 300, exerciseMinutes: 40, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(!insights.contains { $0.title == "Step count below target" })
    }

    @Test("Low exercise minutes triggers info insight")
    func lowExerciseMinutes() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 8000, activeCalories: 400, exerciseMinutes: 15, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(insights.contains { $0.title == "Exercise minutes running low" })
    }

    @Test("30 minutes of exercise does not trigger insight")
    func adequateExercise() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 8000, activeCalories: 400, exerciseMinutes: 30, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(!insights.contains { $0.title == "Exercise minutes running low" })
    }

    @Test("Both low steps and low exercise produce two insights")
    func bothLowMetrics() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 2000, activeCalories: 100, exerciseMinutes: 10, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(insights.count == 2)
    }

    @Test("No activity data produces no insights")
    func noActivityData() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 480, deepMinutes: 100, remMinutes: 100, quality: .good, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(insights.isEmpty)
    }

    @Test("Uses last activity data point")
    func usesLastActivityData() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 2000, activeCalories: 100, exerciseMinutes: 10, date: Date()),
            .activity(steps: 9000, activeCalories: 500, exerciseMinutes: 45, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        // Last entry has 9000 steps and 45 min exercise — neither should trigger
        #expect(insights.isEmpty)
    }

    @Test("Step count data value is stored correctly")
    func stepDataValue() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 3000, activeCalories: 200, exerciseMinutes: 40, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        let stepInsight = insights.first { $0.title == "Step count below target" }
        #expect(stepInsight?.dataValue == 3000.0)
    }
}

// MARK: - Tests: Heart Rate Analysis

@Suite("HealthCoachingPipeline — Heart Rate Analysis")
struct HCHeartRateTests {
    @Test("Elevated resting heart rate triggers warning")
    func elevatedRestingHR() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 85, restingBPM: 105, date: Date())
        ]
        let insights = pipeline.analyzeHeartRateData(from: data)
        #expect(insights.contains { $0.title == "Elevated resting heart rate" })
        #expect(insights.first?.severity == .warning)
    }

    @Test("Normal resting heart rate produces no insight")
    func normalRestingHR() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 75, restingBPM: 65, date: Date())
        ]
        let insights = pipeline.analyzeHeartRateData(from: data)
        #expect(insights.isEmpty)
    }

    @Test("Resting HR exactly 100 does not trigger (must be > 100)")
    func exactlyHundred() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 80, restingBPM: 100, date: Date())
        ]
        let insights = pipeline.analyzeHeartRateData(from: data)
        #expect(insights.isEmpty)
    }

    @Test("Zero resting BPM does not trigger (guard: > 0)")
    func zeroRestingBPM() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 80, restingBPM: 0, date: Date())
        ]
        let insights = pipeline.analyzeHeartRateData(from: data)
        #expect(insights.isEmpty)
    }

    @Test("No heart rate data produces no insights")
    func noHRData() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 5000, activeCalories: 300, exerciseMinutes: 30, date: Date())
        ]
        let insights = pipeline.analyzeHeartRateData(from: data)
        #expect(insights.isEmpty)
    }
}

// MARK: - Tests: Blood Pressure Analysis

@Suite("HealthCoachingPipeline — Blood Pressure Analysis")
struct HCBloodPressureTests {
    @Test("Stage 2 hypertension triggers critical insight")
    func stage2Hypertension() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 145, diastolic: 95, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.count == 1)
        #expect(insights.first?.severity == .critical)
        #expect(insights.first?.title == "High blood pressure reading")
    }

    @Test("Systolic >= 140 alone triggers critical")
    func highSystolicAlone() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 140, diastolic: 75, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.first?.severity == .critical)
    }

    @Test("Diastolic >= 90 alone triggers critical")
    func highDiastolicAlone() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 125, diastolic: 90, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.first?.severity == .critical)
    }

    @Test("Stage 1 hypertension triggers warning")
    func stage1Hypertension() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 135, diastolic: 85, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.count == 1)
        #expect(insights.first?.severity == .warning)
        #expect(insights.first?.title == "Elevated blood pressure")
    }

    @Test("Systolic >= 130 alone triggers warning")
    func elevatedSystolicAlone() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 130, diastolic: 75, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.first?.severity == .warning)
    }

    @Test("Diastolic >= 80 alone triggers warning")
    func elevatedDiastolicAlone() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 115, diastolic: 80, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.first?.severity == .warning)
    }

    @Test("Normal blood pressure produces no insight")
    func normalBP() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 118, diastolic: 75, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.isEmpty)
    }

    @Test("No blood pressure data produces no insights")
    func noBPData() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 5000, activeCalories: 300, exerciseMinutes: 30, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        #expect(insights.isEmpty)
    }

    @Test("Uses last blood pressure reading")
    func usesLastBPReading() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 150, diastolic: 95, date: Date()),
            .bloodPressure(systolic: 118, diastolic: 75, date: Date())
        ]
        let insights = pipeline.analyzeBloodPressureData(from: data)
        // Last reading is normal
        #expect(insights.isEmpty)
    }
}

// MARK: - Tests: Insight Generation and Sorting

@Suite("HealthCoachingPipeline — Insight Generation")
struct HCInsightGenerationTests {
    @Test("Insights are sorted by severity (critical first)")
    func sortedBySeverity() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 2000, activeCalories: 100, exerciseMinutes: 10, date: Date()),
            .bloodPressure(systolic: 150, diastolic: 95, date: Date()),
        ]
        let insights = pipeline.analyzeHealthData(data)
        #expect(!insights.isEmpty)
        #expect(insights.first?.severity == .critical) // BP critical comes first
    }

    @Test("MaxActiveInsights limits stored insights")
    func maxActiveInsightsLimit() {
        let pipeline = TestHealthCoachingPipeline()
        pipeline.maxActiveInsights = 2
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 200, deepMinutes: 20, remMinutes: 20, quality: .poor, date: Date()),
            .sleep(totalMinutes: 200, deepMinutes: 20, remMinutes: 20, quality: .poor, date: Date()),
            .sleep(totalMinutes: 200, deepMinutes: 20, remMinutes: 20, quality: .poor, date: Date()),
            .activity(steps: 1000, activeCalories: 50, exerciseMinutes: 5, date: Date()),
            .bloodPressure(systolic: 150, diastolic: 95, date: Date()),
        ]
        pipeline.runAnalysis(with: data)
        #expect(pipeline.activeInsights.count <= 2)
    }

    @Test("Full analysis creates a report")
    func createsReport() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 5000, activeCalories: 300, exerciseMinutes: 30, date: Date())
        ]
        pipeline.runAnalysis(with: data)
        #expect(pipeline.lastReport != nil)
        #expect(pipeline.lastReport?.dataPoints.count == 1)
    }

    @Test("Dismiss insight removes it from active list")
    func dismissInsight() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 2000, activeCalories: 100, exerciseMinutes: 10, date: Date())
        ]
        pipeline.runAnalysis(with: data)
        #expect(!pipeline.activeInsights.isEmpty)
        let id = pipeline.activeInsights.first!.id
        pipeline.dismissInsight(id)
        #expect(!pipeline.activeInsights.contains { $0.id == id })
    }

    @Test("Clear all insights empties the list")
    func clearAllInsights() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 2000, activeCalories: 100, exerciseMinutes: 10, date: Date())
        ]
        pipeline.runAnalysis(with: data)
        #expect(!pipeline.activeInsights.isEmpty)
        pipeline.clearAllInsights()
        #expect(pipeline.activeInsights.isEmpty)
    }

    @Test("Severity ranking: critical > warning > info > positive")
    func severityRanking() {
        #expect(HCSeverity.critical.rank > HCSeverity.warning.rank)
        #expect(HCSeverity.warning.rank > HCSeverity.info.rank)
        #expect(HCSeverity.info.rank > HCSeverity.positive.rank)
    }
}

// MARK: - Tests: Overall Scoring

@Suite("HealthCoachingPipeline — Scoring")
struct HCScoringTests {
    @Test("Perfect sleep gives high score")
    func perfectSleep() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 480, deepMinutes: 100, remMinutes: 100, quality: .excellent, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // durationScore = 480/480 = 1.0, qualityScore = 100/100 = 1.0, avg = 1.0
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test("Poor sleep gives low score")
    func poorSleep() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 200, deepMinutes: 20, remMinutes: 20, quality: .poor, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // durationScore = 200/480 = 0.417, qualityScore = 25/100 = 0.25, avg = 0.333
        #expect(score < 0.4)
    }

    @Test("Perfect activity gives high score")
    func perfectActivity() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 10000, activeCalories: 500, exerciseMinutes: 30, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // stepScore = 10000/10000 = 1.0, exerciseScore = 30/30 = 1.0, avg = 1.0
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test("Activity above max caps at 1.0")
    func activityCapped() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 20000, activeCalories: 1000, exerciseMinutes: 120, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // Both capped at 1.0
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test("Low resting heart rate gives perfect score")
    func lowRestingHR() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 65, restingBPM: 60, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // resting <= 70 => score = 1.0
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test("High resting heart rate gives low score")
    func highRestingHR() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 100, restingBPM: 110, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // 110 > 70, score = max(0, 1.0 - (110-70)/50) = max(0, 1.0 - 0.8) = 0.2
        #expect(abs(score - 0.2) < 0.001)
    }

    @Test("Zero resting HR is skipped from scoring")
    func zeroRestingHRSkipped() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 80, restingBPM: 0, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // resting == 0, so guard fails, no score added
        #expect(abs(score - 0.5) < 0.001) // default when empty
    }

    @Test("Normal blood pressure gives perfect score")
    func normalBP() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 115, diastolic: 75, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // systolic <= 120 => score = 1.0
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test("High blood pressure gives low score")
    func highBP() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 160, diastolic: 100, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // 160 > 120, score = max(0, 1.0 - (160-120)/40) = max(0, 1.0 - 1.0) = 0.0
        #expect(abs(score - 0.0) < 0.001)
    }

    @Test("Empty data gives default score 0.5")
    func emptyDataDefault() {
        let pipeline = TestHealthCoachingPipeline()
        let score = pipeline.calculateOverallScore(from: [])
        #expect(abs(score - 0.5) < 0.001)
    }

    @Test("Mixed data averages all scores")
    func mixedData() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 480, deepMinutes: 100, remMinutes: 100, quality: .excellent, date: Date()),
            .activity(steps: 10000, activeCalories: 500, exerciseMinutes: 30, date: Date()),
        ]
        let score = pipeline.calculateOverallScore(from: data)
        // sleep: 1.0, activity: 1.0, avg = 1.0
        #expect(abs(score - 1.0) < 0.001)
    }

    @Test("Report stores overall score")
    func reportStoresScore() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 10000, activeCalories: 500, exerciseMinutes: 30, date: Date())
        ]
        pipeline.runAnalysis(with: data)
        #expect(pipeline.lastReport?.overallScore != nil)
        #expect(abs(pipeline.lastReport!.overallScore - 1.0) < 0.001)
    }
}

// MARK: - Tests: Edge Cases

@Suite("HealthCoachingPipeline — Edge Cases")
struct HCEdgeCaseTests {
    @Test("Sleep with zero total minutes does not crash (guard against division by zero)")
    func zeroSleepMinutes() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 0, deepMinutes: 0, remMinutes: 0, quality: .poor, date: Date())
        ]
        // Should not crash — deepPercent uses max(totalMinutes, 1)
        let insights = pipeline.analyzeSleepData(from: data)
        // 0 < 360 so duration warning fires
        #expect(insights.contains { $0.title == "Sleep duration below target" })
    }

    @Test("Activity with zero steps and zero minutes generates two insights")
    func zeroActivity() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .activity(steps: 0, activeCalories: 0, exerciseMinutes: 0, date: Date())
        ]
        let insights = pipeline.analyzeActivityData(from: data)
        #expect(insights.count == 2)
    }

    @Test("Only non-matching data types return empty insights")
    func mismatchedData() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .heartRate(averageBPM: 75, restingBPM: 65, date: Date())
        ]
        #expect(pipeline.analyzeSleepData(from: data).isEmpty)
        #expect(pipeline.analyzeActivityData(from: data).isEmpty)
        #expect(pipeline.analyzeBloodPressureData(from: data).isEmpty)
    }

    @Test("All healthy data produces no insights")
    func allHealthyNoInsights() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .sleep(totalMinutes: 480, deepMinutes: 100, remMinutes: 100, quality: .excellent, date: Date()),
            .activity(steps: 10000, activeCalories: 500, exerciseMinutes: 45, date: Date()),
            .heartRate(averageBPM: 70, restingBPM: 60, date: Date()),
            .bloodPressure(systolic: 115, diastolic: 72, date: Date()),
        ]
        let insights = pipeline.analyzeHealthData(data)
        #expect(insights.isEmpty)
    }

    @Test("Extremely high BP gives score of 0")
    func extremeHighBP() {
        let pipeline = TestHealthCoachingPipeline()
        let data: [HCHealthDataPoint] = [
            .bloodPressure(systolic: 200, diastolic: 120, date: Date())
        ]
        let score = pipeline.calculateOverallScore(from: data)
        #expect(score == 0.0)
    }
}
