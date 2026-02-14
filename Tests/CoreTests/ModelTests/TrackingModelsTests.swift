@testable import TheaModels
import XCTest

/// Tests for TrackingModels — health snapshots, screen time, input statistics,
/// browsing records, location visits, life insights, and window state.
final class TrackingModelsTests: XCTestCase {

    // MARK: - HealthSnapshot

    func testHealthSnapshotCreation() {
        let date = Date()
        let snapshot = HealthSnapshot(date: date, steps: 8500, activeCalories: 320.5)
        XCTAssertEqual(snapshot.steps, 8500)
        XCTAssertEqual(snapshot.activeCalories, 320.5, accuracy: 0.01)
        XCTAssertEqual(snapshot.date, date)
    }

    func testHealthSnapshotDefaults() {
        let snapshot = HealthSnapshot(date: Date())
        XCTAssertEqual(snapshot.steps, 0)
        XCTAssertEqual(snapshot.activeCalories, 0)
        XCTAssertNil(snapshot.heartRateAverage)
        XCTAssertNil(snapshot.heartRateMin)
        XCTAssertNil(snapshot.heartRateMax)
        XCTAssertEqual(snapshot.sleepDuration, 0)
        XCTAssertEqual(snapshot.workoutMinutes, 0)
        XCTAssertTrue(snapshot.snapshotData.isEmpty)
    }

    func testHeartRateCalculations() {
        let snapshot = HealthSnapshot(
            date: Date(),
            heartRateAverage: 72.0,
            heartRateMin: 55.0,
            heartRateMax: 145.0
        )
        XCTAssertEqual(snapshot.heartRateAverage, 72.0)
        XCTAssertEqual(snapshot.heartRateMin, 55.0)
        XCTAssertEqual(snapshot.heartRateMax, 145.0)
        XCTAssertLessThanOrEqual(snapshot.heartRateMin ?? 0, snapshot.heartRateAverage ?? 0)
        XCTAssertGreaterThanOrEqual(snapshot.heartRateMax ?? 0, snapshot.heartRateAverage ?? 0)
    }

    func testSleepDuration() {
        let sevenHours: TimeInterval = 7 * 3600
        let snapshot = HealthSnapshot(date: Date(), sleepDuration: sevenHours)
        XCTAssertEqual(snapshot.sleepDuration, sevenHours)
        XCTAssertEqual(snapshot.sleepDuration / 3600, 7.0, accuracy: 0.01)
    }

    // MARK: - DailyScreenTimeRecord

    func testScreenTimeRecordCreation() {
        let record = DailyScreenTimeRecord(
            date: Date(),
            totalScreenTime: 8 * 3600,
            productivityScore: 0.72,
            focusTimeMinutes: 180
        )
        XCTAssertEqual(record.totalScreenTime, 8 * 3600)
        XCTAssertEqual(record.productivityScore, 0.72, accuracy: 0.01)
        XCTAssertEqual(record.focusTimeMinutes, 180)
    }

    func testScreenTimeDefaults() {
        let record = DailyScreenTimeRecord(date: Date())
        XCTAssertEqual(record.totalScreenTime, 0)
        XCTAssertEqual(record.productivityScore, 0)
        XCTAssertEqual(record.focusTimeMinutes, 0)
        XCTAssertTrue(record.appUsageData.isEmpty)
    }

    // MARK: - DailyInputStatistics

    func testInputStatisticsCreation() {
        let stats = DailyInputStatistics(
            date: Date(),
            mouseClicks: 1500,
            keystrokes: 8000,
            mouseDistancePixels: 50000.5,
            activeMinutes: 420,
            activityLevel: "active"
        )
        XCTAssertEqual(stats.mouseClicks, 1500)
        XCTAssertEqual(stats.keystrokes, 8000)
        XCTAssertEqual(stats.mouseDistancePixels, 50000.5, accuracy: 0.01)
        XCTAssertEqual(stats.activeMinutes, 420)
        XCTAssertEqual(stats.activityLevel, "active")
    }

    func testInputStatisticsDefaultActivityLevel() {
        let stats = DailyInputStatistics(date: Date())
        XCTAssertEqual(stats.activityLevel, "sedentary")
        XCTAssertEqual(stats.mouseClicks, 0)
        XCTAssertEqual(stats.keystrokes, 0)
    }

    func testActivityLevelClassification() {
        let levels = ["sedentary", "light", "moderate", "active", "very_active"]
        for level in levels {
            let stats = DailyInputStatistics(date: Date(), activityLevel: level)
            XCTAssertEqual(stats.activityLevel, level)
        }
    }

    // MARK: - BrowsingRecord

    func testBrowsingRecordCreation() {
        let sessionID = UUID()
        let record = BrowsingRecord(
            sessionID: sessionID,
            url: "https://developer.apple.com/swift",
            title: "Swift - Apple Developer",
            duration: 300,
            category: "development"
        )
        XCTAssertEqual(record.sessionID, sessionID)
        XCTAssertEqual(record.url, "https://developer.apple.com/swift")
        XCTAssertEqual(record.title, "Swift - Apple Developer")
        XCTAssertEqual(record.duration, 300)
        XCTAssertEqual(record.category, "development")
    }

    func testBrowsingRecordDefaults() {
        let record = BrowsingRecord(sessionID: UUID(), url: "https://example.com", title: "Example")
        XCTAssertEqual(record.duration, 0)
        XCTAssertEqual(record.category, "other")
        XCTAssertNil(record.contentSummary)
    }

    // MARK: - LocationVisitRecord

    func testLocationVisitCreation() {
        let visit = LocationVisitRecord(
            latitude: 48.8566,
            longitude: 2.3522,
            placeName: "Paris",
            category: "travel"
        )
        XCTAssertEqual(visit.latitude, 48.8566, accuracy: 0.0001)
        XCTAssertEqual(visit.longitude, 2.3522, accuracy: 0.0001)
        XCTAssertEqual(visit.placeName, "Paris")
        XCTAssertEqual(visit.category, "travel")
        XCTAssertNil(visit.departureTime)
    }

    func testLocationVisitDuration() {
        let arrival = Date()
        let departure = arrival.addingTimeInterval(3600)
        let visit = LocationVisitRecord(
            latitude: 0, longitude: 0,
            arrivalTime: arrival,
            departureTime: departure
        )
        let duration = visit.departureTime!.timeIntervalSince(visit.arrivalTime)
        XCTAssertEqual(duration, 3600, accuracy: 0.1, "Should track 1 hour visit")
    }

    func testLocationCoordinateRanges() {
        // Valid coordinate ranges
        let visit = LocationVisitRecord(latitude: -90, longitude: -180)
        XCTAssertGreaterThanOrEqual(visit.latitude, -90)
        XCTAssertLessThanOrEqual(visit.latitude, 90)
        XCTAssertGreaterThanOrEqual(visit.longitude, -180)
        XCTAssertLessThanOrEqual(visit.longitude, 180)
    }

    // MARK: - LifeInsight

    func testLifeInsightCreation() {
        let insight = LifeInsight(
            insightType: "health",
            title: "Sleep Pattern Change",
            insightDescription: "Your sleep duration has decreased by 30 minutes over the past week",
            actionableRecommendations: ["Try going to bed 30 minutes earlier", "Reduce screen time before bed"],
            priority: "high"
        )
        XCTAssertEqual(insight.insightType, "health")
        XCTAssertEqual(insight.title, "Sleep Pattern Change")
        XCTAssertEqual(insight.actionableRecommendations.count, 2)
        XCTAssertEqual(insight.priority, "high")
        XCTAssertFalse(insight.isRead)
    }

    func testLifeInsightReadState() {
        let insight = LifeInsight(insightType: "productivity", title: "Test", insightDescription: "Test")
        XCTAssertFalse(insight.isRead)
        insight.isRead = true
        XCTAssertTrue(insight.isRead)
    }

    func testLifeInsightDefaults() {
        let insight = LifeInsight(insightType: "test", title: "Test", insightDescription: "Desc")
        XCTAssertEqual(insight.priority, "medium")
        XCTAssertTrue(insight.actionableRecommendations.isEmpty)
        XCTAssertFalse(insight.isRead)
    }

    func testLifeInsightPriorityLevels() {
        let priorities = ["low", "medium", "high", "critical"]
        for priority in priorities {
            let insight = LifeInsight(
                insightType: "test", title: "Test",
                insightDescription: "D", priority: priority
            )
            XCTAssertEqual(insight.priority, priority)
        }
    }

    // MARK: - WindowState

    func testWindowStateCreation() {
        let convID = UUID()
        let state = WindowState(
            windowType: "chat",
            conversationID: convID
        )
        XCTAssertEqual(state.windowType, "chat")
        XCTAssertEqual(state.conversationID, convID)
        XCTAssertNil(state.projectID)
        XCTAssertTrue(state.position.isEmpty)
        XCTAssertTrue(state.size.isEmpty)
    }

    func testWindowStateTypes() {
        let types = ["chat", "settings", "clipboard", "sidebar"]
        for windowType in types {
            let state = WindowState(windowType: windowType)
            XCTAssertEqual(state.windowType, windowType)
        }
    }

    // MARK: - Cross-Model Integrity

    func testAllModelsHaveUniqueIDs() {
        let snapshot = HealthSnapshot(date: Date())
        let screen = DailyScreenTimeRecord(date: Date())
        let input = DailyInputStatistics(date: Date())
        let browsing = BrowsingRecord(sessionID: UUID(), url: "", title: "")
        let location = LocationVisitRecord(latitude: 0, longitude: 0)
        let insight = LifeInsight(insightType: "", title: "", insightDescription: "")
        let window = WindowState(windowType: "")

        let ids: Set<UUID> = [
            snapshot.id, screen.id, input.id,
            browsing.id, location.id, insight.id, window.id
        ]
        XCTAssertEqual(ids.count, 7, "All model IDs should be unique")
    }
}
