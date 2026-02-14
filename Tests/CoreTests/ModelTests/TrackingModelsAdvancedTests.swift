@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

/// Advanced tests for TrackingModels: HealthSnapshot, DailyScreenTimeRecord,
/// DailyInputStatistics, BrowsingRecord, LocationVisitRecord, LifeInsight, WindowState.
@MainActor
final class TrackingModelsAdvancedTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            HealthSnapshot.self, DailyScreenTimeRecord.self,
            DailyInputStatistics.self, BrowsingRecord.self,
            LocationVisitRecord.self, LifeInsight.self, WindowState.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - HealthSnapshot

    func testHealthSnapshotDefaults() {
        let snapshot = HealthSnapshot(date: Date())
        XCTAssertEqual(snapshot.steps, 0)
        XCTAssertEqual(snapshot.activeCalories, 0)
        XCTAssertNil(snapshot.heartRateAverage)
        XCTAssertNil(snapshot.heartRateMin)
        XCTAssertNil(snapshot.heartRateMax)
        XCTAssertEqual(snapshot.sleepDuration, 0)
        XCTAssertEqual(snapshot.workoutMinutes, 0)
    }

    func testHealthSnapshotFullData() {
        let snapshot = HealthSnapshot(
            date: Date(),
            steps: 12_500,
            activeCalories: 450.5,
            heartRateAverage: 72.0,
            heartRateMin: 55.0,
            heartRateMax: 165.0,
            sleepDuration: 7.5 * 3600,
            workoutMinutes: 45
        )
        XCTAssertEqual(snapshot.steps, 12_500)
        XCTAssertEqual(snapshot.activeCalories, 450.5)
        XCTAssertEqual(snapshot.heartRateAverage, 72.0)
        XCTAssertEqual(snapshot.heartRateMin, 55.0)
        XCTAssertEqual(snapshot.heartRateMax, 165.0)
        XCTAssertEqual(snapshot.sleepDuration, 27_000, accuracy: 0.1)
        XCTAssertEqual(snapshot.workoutMinutes, 45)
    }

    func testHealthSnapshotPersists() throws {
        let snapshot = HealthSnapshot(
            date: Date(),
            steps: 8000,
            activeCalories: 300
        )
        modelContext.insert(snapshot)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<HealthSnapshot>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].steps, 8000)
    }

    // MARK: - DailyScreenTimeRecord

    func testScreenTimeDefaults() {
        let record = DailyScreenTimeRecord(date: Date())
        XCTAssertEqual(record.totalScreenTime, 0)
        XCTAssertEqual(record.productivityScore, 0)
        XCTAssertEqual(record.focusTimeMinutes, 0)
    }

    func testScreenTimeWithData() {
        let record = DailyScreenTimeRecord(
            date: Date(),
            totalScreenTime: 8 * 3600,
            productivityScore: 0.75,
            focusTimeMinutes: 180
        )
        XCTAssertEqual(record.totalScreenTime, 28_800, accuracy: 0.1)
        XCTAssertEqual(record.productivityScore, 0.75)
        XCTAssertEqual(record.focusTimeMinutes, 180)
    }

    func testScreenTimePersists() throws {
        let record = DailyScreenTimeRecord(
            date: Date(),
            totalScreenTime: 14400,
            productivityScore: 0.8
        )
        modelContext.insert(record)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<DailyScreenTimeRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].productivityScore, 0.8)
    }

    // MARK: - DailyInputStatistics

    func testInputStatsDefaults() {
        let stats = DailyInputStatistics(date: Date())
        XCTAssertEqual(stats.mouseClicks, 0)
        XCTAssertEqual(stats.keystrokes, 0)
        XCTAssertEqual(stats.mouseDistancePixels, 0)
        XCTAssertEqual(stats.activeMinutes, 0)
        XCTAssertEqual(stats.activityLevel, "sedentary")
    }

    func testInputStatsWithData() {
        let stats = DailyInputStatistics(
            date: Date(),
            mouseClicks: 5000,
            keystrokes: 25_000,
            mouseDistancePixels: 150_000.5,
            activeMinutes: 480,
            activityLevel: "very_active"
        )
        XCTAssertEqual(stats.mouseClicks, 5000)
        XCTAssertEqual(stats.keystrokes, 25_000)
        XCTAssertEqual(stats.mouseDistancePixels, 150_000.5, accuracy: 0.1)
        XCTAssertEqual(stats.activeMinutes, 480)
        XCTAssertEqual(stats.activityLevel, "very_active")
    }

    // MARK: - BrowsingRecord

    func testBrowsingRecordDefaults() {
        let record = BrowsingRecord(
            sessionID: UUID(),
            url: "https://example.com",
            title: "Example"
        )
        XCTAssertEqual(record.duration, 0)
        XCTAssertEqual(record.category, "other")
        XCTAssertNil(record.contentSummary)
    }

    func testBrowsingRecordFullData() {
        let sessionID = UUID()
        let record = BrowsingRecord(
            sessionID: sessionID,
            url: "https://developer.apple.com/swift",
            title: "Swift - Apple Developer",
            duration: 300,
            category: "development",
            contentSummary: "Swift programming language documentation"
        )
        XCTAssertEqual(record.sessionID, sessionID)
        XCTAssertEqual(record.url, "https://developer.apple.com/swift")
        XCTAssertEqual(record.title, "Swift - Apple Developer")
        XCTAssertEqual(record.duration, 300)
        XCTAssertEqual(record.category, "development")
        XCTAssertNotNil(record.contentSummary)
    }

    func testBrowsingRecordPersists() throws {
        let record = BrowsingRecord(
            sessionID: UUID(),
            url: "https://test.com",
            title: "Test",
            category: "research"
        )
        modelContext.insert(record)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<BrowsingRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].category, "research")
    }

    // MARK: - LocationVisitRecord

    func testLocationDefaults() {
        let location = LocationVisitRecord(
            latitude: 46.2044,
            longitude: 6.1432
        )
        XCTAssertNil(location.departureTime)
        XCTAssertNil(location.placeName)
        XCTAssertEqual(location.category, "other")
    }

    func testLocationWithPlace() {
        let location = LocationVisitRecord(
            latitude: 46.2044,
            longitude: 6.1432,
            arrivalTime: Date(timeIntervalSince1970: 1_700_000_000),
            departureTime: Date(timeIntervalSince1970: 1_700_003_600),
            placeName: "Geneva",
            category: "home"
        )
        XCTAssertEqual(location.latitude, 46.2044, accuracy: 0.0001)
        XCTAssertEqual(location.longitude, 6.1432, accuracy: 0.0001)
        XCTAssertEqual(location.placeName, "Geneva")
        XCTAssertEqual(location.category, "home")
        XCTAssertNotNil(location.departureTime)
    }

    func testLocationVisitDuration() {
        let arrival = Date(timeIntervalSince1970: 1_700_000_000)
        let departure = Date(timeIntervalSince1970: 1_700_003_600)
        let location = LocationVisitRecord(
            latitude: 0,
            longitude: 0,
            arrivalTime: arrival,
            departureTime: departure
        )
        let duration = location.departureTime!.timeIntervalSince(location.arrivalTime)
        XCTAssertEqual(duration, 3600, accuracy: 0.1) // 1 hour
    }

    // MARK: - LifeInsight

    func testLifeInsightDefaults() {
        let insight = LifeInsight(
            insightType: "health",
            title: "Take a break",
            insightDescription: "You've been sitting for 3 hours"
        )
        XCTAssertTrue(insight.actionableRecommendations.isEmpty)
        XCTAssertEqual(insight.priority, "medium")
        XCTAssertFalse(insight.isRead)
    }

    func testLifeInsightFullData() {
        let insight = LifeInsight(
            insightType: "productivity",
            title: "Peak Hours Detected",
            insightDescription: "Your most productive hours are 9-11 AM",
            actionableRecommendations: [
                "Schedule deep work during 9-11 AM",
                "Avoid meetings before noon"
            ],
            priority: "high",
            isRead: true
        )
        XCTAssertEqual(insight.insightType, "productivity")
        XCTAssertEqual(insight.actionableRecommendations.count, 2)
        XCTAssertEqual(insight.priority, "high")
        XCTAssertTrue(insight.isRead)
    }

    func testLifeInsightMarkAsRead() {
        let insight = LifeInsight(
            insightType: "wellness",
            title: "Test",
            insightDescription: "Desc"
        )
        XCTAssertFalse(insight.isRead)
        insight.isRead = true
        XCTAssertTrue(insight.isRead)
    }

    func testLifeInsightPersists() throws {
        let insight = LifeInsight(
            insightType: "sleep",
            title: "Sleep Quality",
            insightDescription: "Sleep quality improved 15%"
        )
        modelContext.insert(insight)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<LifeInsight>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].title, "Sleep Quality")
    }

    // MARK: - WindowState

    func testWindowStateDefaults() {
        let state = WindowState(windowType: "main")
        XCTAssertEqual(state.windowType, "main")
        XCTAssertNil(state.conversationID)
        XCTAssertNil(state.projectID)
    }

    func testWindowStateWithContext() {
        let convID = UUID()
        let projID = UUID()
        let state = WindowState(
            windowType: "chat",
            conversationID: convID,
            projectID: projID
        )
        XCTAssertEqual(state.conversationID, convID)
        XCTAssertEqual(state.projectID, projID)
    }

    func testWindowStatePersists() throws {
        let state = WindowState(
            windowType: "settings",
            position: Data([1, 2, 3, 4]),
            size: Data([5, 6, 7, 8])
        )
        modelContext.insert(state)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<WindowState>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].windowType, "settings")
    }
}
