import XCTest
#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif

/// Test suite for Health module services
@MainActor
final class HealthServiceTests: XCTestCase {

    // MARK: - Blood Pressure Tests

    func testBloodPressureCategorization() {
        // Normal
        let normalReading = BloodPressureReading(
            timestamp: Date(),
            systolic: 115,
            diastolic: 75,
            pulse: 65
        )
        XCTAssertEqual(normalReading.category, .normal, "115/75 should be categorized as Normal")

        // Elevated
        let elevatedReading = BloodPressureReading(
            timestamp: Date(),
            systolic: 125,
            diastolic: 75,
            pulse: 68
        )
        XCTAssertEqual(elevatedReading.category, .elevated, "125/75 should be categorized as Elevated")

        // Stage 1 Hypertension
        let stage1Reading = BloodPressureReading(
            timestamp: Date(),
            systolic: 135,
            diastolic: 85,
            pulse: 72
        )
        XCTAssertEqual(stage1Reading.category, .stage1Hypertension, "135/85 should be categorized as Stage 1")

        // Stage 2 Hypertension
        let stage2Reading = BloodPressureReading(
            timestamp: Date(),
            systolic: 145,
            diastolic: 95,
            pulse: 75
        )
        XCTAssertEqual(stage2Reading.category, .stage2Hypertension, "145/95 should be categorized as Stage 2")

        // Hypertensive Crisis
        let crisisReading = BloodPressureReading(
            timestamp: Date(),
            systolic: 185,
            diastolic: 125,
            pulse: 90
        )
        XCTAssertEqual(crisisReading.category, .hypertensiveCrisis, "185/125 should be categorized as Crisis")
    }

    func testBloodPressureCategoryColors() {
        XCTAssertEqual(BloodPressureReading.Category.normal.color, "#10B981")
        XCTAssertEqual(BloodPressureReading.Category.elevated.color, "#F59E0B")
        XCTAssertEqual(BloodPressureReading.Category.stage1Hypertension.color, "#F97316")
        XCTAssertEqual(BloodPressureReading.Category.stage2Hypertension.color, "#EF4444")
        XCTAssertEqual(BloodPressureReading.Category.hypertensiveCrisis.color, "#DC2626")
    }

    // MARK: - Sleep Quality Tests

    func testSleepQualityRating() async {
        let viewModel = SleepQualityViewModel()

        // Excellent sleep (85+)
        let excellentData = SleepData(
            date: Date(),
            bedtime: Date().addingTimeInterval(-28800), // 8 hours ago
            wakeTime: Date(),
            totalMinutes: 480, // 8 hours
            qualityScore: 90.0,
            efficiency: 92.0,
            sleepLatency: 10,
            interruptions: 1,
            restfulness: 88.0,
            stages: [],
            timeline: [],
            factors: []
        )
        XCTAssertEqual(excellentData.qualityRating, "Excellent")

        // Good sleep (70-84)
        let goodData = SleepData(
            date: Date(),
            bedtime: Date().addingTimeInterval(-25200), // 7 hours ago
            wakeTime: Date(),
            totalMinutes: 420,
            qualityScore: 75.0,
            efficiency: 82.0,
            sleepLatency: 15,
            interruptions: 3,
            restfulness: 75.0,
            stages: [],
            timeline: [],
            factors: []
        )
        XCTAssertEqual(goodData.qualityRating, "Good")

        // Fair sleep (50-69)
        let fairData = SleepData(
            date: Date(),
            bedtime: Date().addingTimeInterval(-21600), // 6 hours ago
            wakeTime: Date(),
            totalMinutes: 360,
            qualityScore: 60.0,
            efficiency: 72.0,
            sleepLatency: 25,
            interruptions: 5,
            restfulness: 65.0,
            stages: [],
            timeline: [],
            factors: []
        )
        XCTAssertEqual(fairData.qualityRating, "Fair")

        // Poor sleep (<50)
        let poorData = SleepData(
            date: Date(),
            bedtime: Date().addingTimeInterval(-18000), // 5 hours ago
            wakeTime: Date(),
            totalMinutes: 300,
            qualityScore: 40.0,
            efficiency: 62.0,
            sleepLatency: 35,
            interruptions: 8,
            restfulness: 45.0,
            stages: [],
            timeline: [],
            factors: []
        )
        XCTAssertEqual(poorData.qualityRating, "Poor")
    }

    func testSleepStageDistribution() {
        let stages = [
            SleepStageData(stage: .awake, minutes: 30, percentage: 6.7),
            SleepStageData(stage: .light, minutes: 225, percentage: 50.0),
            SleepStageData(stage: .deep, minutes: 105, percentage: 23.3),
            SleepStageData(stage: .rem, minutes: 90, percentage: 20.0)
        ]

        let totalMinutes = stages.reduce(0) { $0 + $1.minutes }
        XCTAssertEqual(totalMinutes, 450, "Total sleep duration should be 450 minutes (7.5 hours)")

        let totalPercentage = stages.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 100.0, accuracy: 0.1, "Total percentage should be 100%")
    }

    // MARK: - Circadian Phase Tests

    func testCircadianPhaseDetection() {
        // Early Morning (5-7 AM)
        XCTAssertEqual(CircadianPhase.phaseForHour(5), .earlyMorning)
        XCTAssertEqual(CircadianPhase.phaseForHour(6), .earlyMorning)

        // Morning (7-10 AM)
        XCTAssertEqual(CircadianPhase.phaseForHour(7), .morning)
        XCTAssertEqual(CircadianPhase.phaseForHour(9), .morning)

        // Midday (10 AM - 1 PM)
        XCTAssertEqual(CircadianPhase.phaseForHour(10), .midday)
        XCTAssertEqual(CircadianPhase.phaseForHour(12), .midday)

        // Afternoon (1-5 PM)
        XCTAssertEqual(CircadianPhase.phaseForHour(13), .afternoon)
        XCTAssertEqual(CircadianPhase.phaseForHour(16), .afternoon)

        // Evening (5-8 PM)
        XCTAssertEqual(CircadianPhase.phaseForHour(17), .evening)
        XCTAssertEqual(CircadianPhase.phaseForHour(19), .evening)

        // Night (8-10 PM)
        XCTAssertEqual(CircadianPhase.phaseForHour(20), .night)
        XCTAssertEqual(CircadianPhase.phaseForHour(21), .night)

        // Late Night (10 PM - 12 AM)
        XCTAssertEqual(CircadianPhase.phaseForHour(22), .lateNight)
        XCTAssertEqual(CircadianPhase.phaseForHour(23), .lateNight)

        // Deep Night (12 AM - 5 AM)
        XCTAssertEqual(CircadianPhase.phaseForHour(0), .deepNight)
        XCTAssertEqual(CircadianPhase.phaseForHour(3), .deepNight)
    }

    func testCircadianPhaseRecommendations() {
        let morningPhase = CircadianPhase.morning
        XCTAssertFalse(morningPhase.recommendations.isEmpty, "Morning phase should have recommendations")
        XCTAssertTrue(morningPhase.recommendations.count >= 3, "Should have at least 3 recommendations")

        let nightPhase = CircadianPhase.night
        XCTAssertFalse(nightPhase.recommendations.isEmpty, "Night phase should have recommendations")
    }

    // MARK: - Activity Trends Tests

    func testActivityMetricUnits() {
        XCTAssertEqual(ActivityMetric.steps.unit, "steps")
        XCTAssertEqual(ActivityMetric.distance.unit, "km")
        XCTAssertEqual(ActivityMetric.calories.unit, "kcal")
        XCTAssertEqual(ActivityMetric.activeMinutes.unit, "minutes")
    }

    func testActivityGoalProgress() {
        let goal = ActivityGoal(name: "Daily Steps", current: 7500, target: 10000, unit: "steps")

        XCTAssertEqual(goal.progress, 0.75, accuracy: 0.01, "Progress should be 75%")

        let completedGoal = ActivityGoal(name: "Active Minutes", current: 60, target: 30, unit: "minutes")
        XCTAssertEqual(completedGoal.progress, 1.0, accuracy: 0.01, "Progress should be capped at 100%")
    }

    // MARK: - Health Insights Tests

    func testHealthScoreCalculation() async {
        let viewModel = HealthInsightsViewModel()

        await viewModel.loadData(timeRange: .week)

        XCTAssertGreaterThanOrEqual(viewModel.healthScore, 0, "Health score should be non-negative")
        XCTAssertLessThanOrEqual(viewModel.healthScore, 100, "Health score should not exceed 100")

        // Component scores should sum to overall score
        let componentAverage = (viewModel.sleepScore + viewModel.activityScore +
                               viewModel.heartScore + viewModel.nutritionScore) / 4.0
        XCTAssertEqual(viewModel.healthScore, componentAverage, accuracy: 5.0,
                      "Health score should approximate component average")
    }

    func testInsightGeneration() async {
        let viewModel = HealthInsightsViewModel()
        await viewModel.refreshInsights()

        XCTAssertFalse(viewModel.insights.isEmpty, "Should generate at least some insights")

        for insight in viewModel.insights {
            XCTAssertFalse(insight.title.isEmpty, "Insight should have a title")
            XCTAssertFalse(insight.message.isEmpty, "Insight should have a message")
            XCTAssertFalse(insight.icon.isEmpty, "Insight should have an icon")
        }
    }

    // MARK: - Health Goals Tests

    func testGoalCreation() {
        let goal = HealthGoal(
            title: "10,000 Steps",
            description: "Walk 10,000 steps daily",
            category: .activity,
            targetValue: 10000,
            currentValue: 0,
            unit: "steps",
            deadline: Date().addingTimeInterval(86400 * 30), // 30 days
            milestones: []
        )

        XCTAssertEqual(goal.title, "10,000 Steps")
        XCTAssertEqual(goal.category, .activity)
        XCTAssertEqual(goal.progress, 0.0, "New goal should have 0% progress")
        XCTAssertTrue(goal.isActive, "New goal should be active")
    }

    func testGoalProgressTracking() {
        var goal = HealthGoal(
            title: "Weight Loss",
            description: "Lose 10 kg",
            category: .weight,
            targetValue: 10,
            currentValue: 0,
            unit: "kg",
            deadline: nil,
            milestones: []
        )

        XCTAssertEqual(goal.progress, 0.0)

        goal.currentValue = 5
        XCTAssertEqual(goal.progress, 0.5, accuracy: 0.01, "Should be 50% complete")

        goal.currentValue = 10
        XCTAssertEqual(goal.progress, 1.0, "Should be 100% complete")

        goal.currentValue = 15
        XCTAssertEqual(goal.progress, 1.0, "Progress should be capped at 100%")
    }

    func testGoalMilestones() {
        let milestones = [
            GoalMilestone(title: "25% Complete", targetValue: 2500, isCompleted: true, completedDate: Date()),
            GoalMilestone(title: "50% Complete", targetValue: 5000, isCompleted: true, completedDate: Date()),
            GoalMilestone(title: "75% Complete", targetValue: 7500, isCompleted: false),
            GoalMilestone(title: "100% Complete", targetValue: 10000, isCompleted: false)
        ]

        let goal = HealthGoal(
            title: "Step Goal",
            description: "Reach 10,000 steps",
            category: .activity,
            targetValue: 10000,
            currentValue: 6000,
            unit: "steps",
            deadline: nil,
            milestones: milestones
        )

        XCTAssertEqual(goal.milestones.count, 4)
        XCTAssertEqual(goal.milestones.filter { $0.isCompleted }.count, 2, "Should have 2 completed milestones")
    }

    func testGoalCompletion() async {
        let viewModel = HealthGoalsViewModel()
        await viewModel.loadGoals()

        let initialActiveCount = viewModel.activeGoals.count
        let initialCompletedCount = viewModel.completedGoals.count

        if let firstGoal = viewModel.activeGoals.first {
            await viewModel.completeGoal(firstGoal)

            XCTAssertEqual(viewModel.activeGoals.count, initialActiveCount - 1, "Active goals should decrease by 1")
            XCTAssertEqual(viewModel.completedGoals.count, initialCompletedCount + 1, "Completed goals should increase by 1")

            if let completedGoal = viewModel.completedGoals.first {
                XCTAssertFalse(completedGoal.isActive, "Completed goal should be inactive")
                XCTAssertNotNil(completedGoal.completedDate, "Completed goal should have completion date")
            }
        }
    }

    // MARK: - Edge Cases

    func testZeroValues() {
        let goal = ActivityGoal(name: "Test", current: 0, target: 0, unit: "units")
        XCTAssertEqual(goal.progress, 0.0, "Zero target should result in 0% progress")
    }

    func testNegativeValues() {
        // Blood pressure should not accept negative values
        let reading = BloodPressureReading(timestamp: Date(), systolic: -10, diastolic: -5, pulse: -60)
        // The system should handle this gracefully (not crash)
        _ = reading.category
    }

    func testFutureTimestamps() {
        let futureDate = Date().addingTimeInterval(86400 * 365) // 1 year in future
        let reading = BloodPressureReading(timestamp: futureDate, systolic: 120, diastolic: 80, pulse: 70)

        XCTAssertEqual(reading.timestamp, futureDate, "Should accept future timestamps")
    }

    // MARK: - Performance Tests

    func testLargeDateRangePerformance() async {
        measure {
            let viewModel = HealthInsightsViewModel()
            Task {
                await viewModel.loadData(timeRange: .year)
            }
        }
    }

    func testChartDataGeneration() async {
        measure {
            let viewModel = ActivityActivityTrendsViewModel()
            Task {
                await viewModel.loadData(metric: .steps, timeRange: .year)
            }
        }
    }
}
