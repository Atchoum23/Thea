import Foundation

// MARK: - Health Data Provider Protocol

/// Protocol for services that provide health data
public protocol HealthDataProvider: Actor {
    /// Request authorization to access health data
    func requestAuthorization() async throws -> Bool

    /// Fetch sleep data for a date range
    func fetchSleepData(for dateRange: DateInterval) async throws -> [SleepRecord]

    /// Fetch heart rate data for a date range
    func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HeartRateRecord]

    /// Fetch activity summary for a specific date
    func fetchActivityData(for date: Date) async throws -> ActivitySummary

    /// Fetch blood pressure readings for a date range
    func fetchBloodPressureData(for dateRange: DateInterval) async throws -> [BloodPressureReading]

    /// Detect cardiac anomalies in heart rate data
    func detectCardiacAnomalies(in records: [HeartRateRecord]) async throws -> [CardiacAnomaly]

    /// Fetch VO2 Max data for a date range
    func fetchVO2MaxData(for dateRange: DateInterval) async throws -> [VO2MaxRecord]
}

// MARK: - Health Observer Protocol

/// Protocol for observing health data changes
public protocol HealthObserver: AnyObject {
    /// Called when sleep data is updated
    func healthDataDidUpdate(sleepRecords: [SleepRecord])

    /// Called when heart rate data is updated
    func healthDataDidUpdate(heartRateRecords: [HeartRateRecord])

    /// Called when activity data is updated
    func healthDataDidUpdate(activitySummary: ActivitySummary)

    /// Called when an error occurs
    func healthDataDidFail(with error: Error)
}

// MARK: - Health Analytics Protocol

/// Protocol for health data analytics
public protocol HealthAnalytics: Actor {
    /// Calculate sleep quality trends over time
    func analyzeSleepTrends(records: [SleepRecord]) async -> Trend

    /// Calculate resting heart rate average
    func calculateRestingHeartRate(records: [HeartRateRecord]) async -> Double

    /// Analyze activity patterns
    func analyzeActivityPatterns(summaries: [ActivitySummary]) async -> ActivityPattern

    /// Generate health insights
    func generateInsights(
        sleepRecords: [SleepRecord],
        heartRateRecords: [HeartRateRecord],
        activitySummaries: [ActivitySummary]
    ) async -> [HealthInsight]
}

// MARK: - Supporting Types

/// Activity pattern analysis
public struct ActivityPattern: Sendable, Codable {
    public let averageSteps: Int
    public let averageActiveMinutes: Int
    public let trend: Trend
    public let mostActiveDay: String
    public let leastActiveDay: String

    public init(
        averageSteps: Int,
        averageActiveMinutes: Int,
        trend: Trend,
        mostActiveDay: String,
        leastActiveDay: String
    ) {
        self.averageSteps = averageSteps
        self.averageActiveMinutes = averageActiveMinutes
        self.trend = trend
        self.mostActiveDay = mostActiveDay
        self.leastActiveDay = leastActiveDay
    }
}

/// Health insight generated from data analysis
public struct HealthInsight: Sendable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let category: Category
    public let severity: Severity
    public let priority: Priority
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: Category,
        severity: Severity = .info,
        priority: Priority = .medium,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.severity = severity
        self.priority = priority
        self.timestamp = timestamp
    }

    public var icon: String {
        category.icon
    }

    public enum Severity: String, Sendable, Codable {
        case info = "Info"
        case warning = "Warning"
        case critical = "Critical"

        public var color: String {
            switch self {
            case .info: "#3B82F6" // Blue
            case .warning: "#F59E0B" // Amber
            case .critical: "#EF4444" // Red
            }
        }

        public var icon: String {
            switch self {
            case .info: "info.circle"
            case .warning: "exclamationmark.triangle"
            case .critical: "exclamationmark.octagon"
            }
        }
    }

    public enum Category: String, Sendable, Codable {
        case sleep
        case heartRate
        case activity
        case vitals
        case general

        public var displayName: String {
            switch self {
            case .sleep: "Sleep"
            case .heartRate: "Heart Rate"
            case .activity: "Activity"
            case .vitals: "Vital Signs"
            case .general: "General"
            }
        }

        public var icon: String {
            switch self {
            case .sleep: "bed.double.fill"
            case .heartRate: "heart.fill"
            case .activity: "figure.walk"
            case .vitals: "waveform.path.ecg"
            case .general: "heart.text.square.fill"
            }
        }
    }
}
