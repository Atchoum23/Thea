import Foundation
import SwiftUI

/// ViewModel for the Health Dashboard
@MainActor
@Observable
public final class HealthDashboardViewModel {
    // MARK: - Published Properties

    public var sleepRecords: [SleepRecord] = []
    public var heartRateRecords: [HeartRateRecord] = []
    public var activitySummaries: [ActivitySummary] = []
    public var bloodPressureReadings: [BloodPressureReading] = []
    public var cardiacAnomalies: [CardiacAnomaly] = []
    public var vo2MaxRecords: [VO2MaxRecord] = []

    public var isLoading = false
    public var errorMessage: String?
    public var isAuthorized = false

    // MARK: - Computed Properties

    public var latestSleepRecord: SleepRecord? {
        sleepRecords.first
    }

    public var averageSleepQuality: SleepQuality {
        guard !sleepRecords.isEmpty else { return .poor }

        let scores = sleepRecords.map(\.quality.score)
        let averageScore = scores.reduce(0, +) / scores.count

        return switch averageScore {
        case 90 ... 100: .excellent
        case 70 ..< 90: .good
        case 50 ..< 70: .fair
        default: .poor
        }
    }

    public var averageRestingHeartRate: Int {
        let restingRecords = heartRateRecords.filter { $0.context == .resting }
        guard !restingRecords.isEmpty else { return 0 }

        let total = restingRecords.reduce(0) { $0 + $1.beatsPerMinute }
        return total / restingRecords.count
    }

    public var todayActivitySummary: ActivitySummary? {
        activitySummaries.first { Calendar.current.isDateInToday($0.date) }
    }

    public var hasCardiacAnomalies: Bool {
        !cardiacAnomalies.isEmpty
    }

    public var latestVO2Max: VO2MaxRecord? {
        vo2MaxRecords.first
    }

    // MARK: - Private Properties

    private let healthService: HealthKitService

    // MARK: - Initialization

    public init(healthService: HealthKitService = HealthKitService()) {
        self.healthService = healthService
    }

    // MARK: - Public Methods

    /// Request authorization to access health data
    public func requestAuthorization() async {
        isLoading = true
        errorMessage = nil

        do {
            isAuthorized = try await healthService.requestAuthorization()
            if isAuthorized {
                await loadAllData()
            }
        } catch {
            errorMessage = error.localizedDescription
            isAuthorized = false
        }

        isLoading = false
    }

    /// Load all health data
    public func loadAllData() async {
        isLoading = true
        errorMessage = nil

        do {
            try await loadSleepData()
            try await loadHeartRateData()
            try await loadActivityData()
            try await loadBloodPressureData()
            try await loadVO2MaxData()
            await detectAnomalies()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh all data
    public func refreshData() async {
        await loadAllData()
    }

    /// Load sleep data for the last 7 days
    public func loadSleepData() async throws {
        let dateRange = DateInterval.lastDays(7)
        sleepRecords = try await healthService.fetchSleepData(for: dateRange)
            .sorted { $0.startDate > $1.startDate }
    }

    /// Load heart rate data for the last 7 days
    public func loadHeartRateData() async throws {
        let dateRange = DateInterval.lastDays(7)
        heartRateRecords = try await healthService.fetchHeartRateData(for: dateRange)
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Load activity data for the last 7 days
    public func loadActivityData() async throws {
        var summaries: [ActivitySummary] = []

        for dayOffset in 0 ..< 7 {
            let date = Date().daysAgo(dayOffset)
            let summary = try await healthService.fetchActivityData(for: date)
            summaries.append(summary)
        }

        activitySummaries = summaries.sorted { $0.date > $1.date }
    }

    /// Load blood pressure data for the last 30 days
    public func loadBloodPressureData() async throws {
        let dateRange = DateInterval.lastDays(30)
        bloodPressureReadings = try await healthService.fetchBloodPressureData(for: dateRange)
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Load VO2 Max data for the last 90 days
    public func loadVO2MaxData() async throws {
        let dateRange = DateInterval.lastDays(90)
        vo2MaxRecords = try await healthService.fetchVO2MaxData(for: dateRange)
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Detect cardiac anomalies
    public func detectAnomalies() async {
        do {
            cardiacAnomalies = try await healthService.detectCardiacAnomalies(in: heartRateRecords)
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            // Silently fail - anomaly detection is not critical
            cardiacAnomalies = []
        }
    }

    /// Get sleep trend for the past week
    public func getSleepTrend() -> Trend {
        guard sleepRecords.count >= 2 else { return .unknown }

        let recentRecords = Array(sleepRecords.prefix(3))
        let olderRecords = Array(sleepRecords.dropFirst(3).prefix(3))

        guard !recentRecords.isEmpty, !olderRecords.isEmpty else { return .unknown }

        let recentAverage = recentRecords.map(\.quality.score).reduce(0, +) / recentRecords.count
        let olderAverage = olderRecords.map(\.quality.score).reduce(0, +) / olderRecords.count

        if recentAverage > olderAverage + 10 {
            return .improving
        } else if recentAverage < olderAverage - 10 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Get activity trend for the past week
    public func getActivityTrend() -> Trend {
        guard activitySummaries.count >= 2 else { return .unknown }

        let recentSummaries = Array(activitySummaries.prefix(3))
        let olderSummaries = Array(activitySummaries.dropFirst(3).prefix(3))

        guard !recentSummaries.isEmpty, !olderSummaries.isEmpty else { return .unknown }

        let recentAverage = recentSummaries.map(\.activityScore).reduce(0, +) / recentSummaries.count
        let olderAverage = olderSummaries.map(\.activityScore).reduce(0, +) / olderSummaries.count

        if recentAverage > olderAverage + 10 {
            return .improving
        } else if recentAverage < olderAverage - 10 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Format duration in hours and minutes
    public func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    /// Format distance based on user preference
    public func formatDistance(_ meters: Double, useMetric: Bool = true) -> String {
        if useMetric {
            let km = meters / 1000
            return String(format: "%.2f km", km)
        } else {
            let miles = meters / 1609.34
            return String(format: "%.2f mi", miles)
        }
    }

    // MARK: - Health Data Export

    /// Export health data to a structured JSON file.
    /// Returns the URL of the exported file, or nil on failure.
    public func exportHealthData() -> URL? {
        let export = HealthExportData(
            exportDate: Date(),
            periodDays: 7,
            sleep: sleepRecords.map { record in
                HealthExportData.SleepEntry(
                    date: record.startDate,
                    durationMinutes: Int(record.duration / 60),
                    quality: record.quality.rawValue
                )
            },
            heartRate: heartRateRecords.prefix(50).map { record in
                HealthExportData.HeartRateEntry(
                    timestamp: record.timestamp,
                    bpm: record.beatsPerMinute,
                    context: record.context.rawValue
                )
            },
            activity: activitySummaries.map { summary in
                HealthExportData.ActivityEntry(
                    date: summary.date,
                    steps: summary.steps,
                    activeCalories: summary.activeCalories,
                    exerciseMinutes: summary.exerciseMinutes,
                    distanceMeters: summary.distance,
                    activityScore: summary.activityScore
                )
            },
            bloodPressure: bloodPressureReadings.prefix(30).map { reading in
                HealthExportData.BloodPressureEntry(
                    timestamp: reading.timestamp,
                    systolic: reading.systolic,
                    diastolic: reading.diastolic,
                    category: reading.category.rawValue
                )
            },
            vo2Max: vo2MaxRecords.prefix(10).map { record in
                HealthExportData.VO2MaxEntry(
                    timestamp: record.timestamp,
                    value: record.value,
                    fitnessLevel: record.fitnessLevel.rawValue
                )
            },
            anomalies: cardiacAnomalies.map { anomaly in
                HealthExportData.AnomalyEntry(
                    timestamp: anomaly.timestamp,
                    type: anomaly.type.rawValue,
                    heartRate: anomaly.heartRate
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(export) else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let filename = "Thea-Health-Export-\(dateString).json"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard (try? data.write(to: tempURL)) != nil else { return nil }
        return tempURL
    }
}

// MARK: - Health Export Data

/// Codable structure for health data export
struct HealthExportData: Codable, Sendable {
    let exportDate: Date
    let periodDays: Int
    let sleep: [SleepEntry]
    let heartRate: [HeartRateEntry]
    let activity: [ActivityEntry]
    let bloodPressure: [BloodPressureEntry]
    let vo2Max: [VO2MaxEntry]
    let anomalies: [AnomalyEntry]

    struct SleepEntry: Codable, Sendable {
        let date: Date
        let durationMinutes: Int
        let quality: String
    }

    struct HeartRateEntry: Codable, Sendable {
        let timestamp: Date
        let bpm: Int
        let context: String
    }

    struct ActivityEntry: Codable, Sendable {
        let date: Date
        let steps: Int
        let activeCalories: Int
        let exerciseMinutes: Int
        let distanceMeters: Double
        let activityScore: Int
    }

    struct BloodPressureEntry: Codable, Sendable {
        let timestamp: Date
        let systolic: Int
        let diastolic: Int
        let category: String
    }

    struct VO2MaxEntry: Codable, Sendable {
        let timestamp: Date
        let value: Double
        let fitnessLevel: String
    }

    struct AnomalyEntry: Codable, Sendable {
        let timestamp: Date
        let type: String
        let heartRate: Int
    }
}
