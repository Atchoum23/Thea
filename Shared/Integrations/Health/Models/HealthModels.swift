import Foundation
import SwiftUI

// MARK: - Sleep Models

/// Sleep stage during sleep analysis
public enum SleepStage: String, Sendable, Codable {
    case awake
    case light
    case deep
    case rem

    public var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .light: return "Light Sleep"
        case .deep: return "Deep Sleep"
        case .rem: return "REM Sleep"
        }
    }

    public var color: Color {
        switch self {
        case .awake: return .red
        case .light: return Color(red: 0.38, green: 0.65, blue: 0.98)  // Light blue #60A5FA
        case .deep: return Color(red: 0.23, green: 0.51, blue: 0.96)   // Blue #3B82F6
        case .rem: return Color(red: 0.55, green: 0.36, blue: 0.96)    // Purple #8B5CF6
        }
    }
}

/// Sleep quality rating
public enum SleepQuality: String, Sendable, Codable {
    case poor
    case fair
    case good
    case excellent

    public var displayName: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }

    public var score: Int {
        switch self {
        case .poor: return 25
        case .fair: return 50
        case .good: return 75
        case .excellent: return 100
        }
    }

    public var color: String {
        switch self {
        case .poor: return "#EF4444"      // Red
        case .fair: return "#F59E0B"      // Amber
        case .good: return "#10B981"      // Green
        case .excellent: return "#059669" // Dark green
        }
    }

    /// Calculate sleep quality based on metrics
    public static func calculate(
        totalMinutes: Int,
        deepMinutes: Int,
        remMinutes: Int,
        awakeMinutes: Int
    ) -> SleepQuality {
        let deepPercent = Double(deepMinutes) / Double(totalMinutes) * 100
        let remPercent = Double(remMinutes) / Double(totalMinutes) * 100
        let awakePercent = Double(awakeMinutes) / Double(totalMinutes) * 100

        // Excellent: >20% deep, >20% REM, <5% awake, total >420 min (7h)
        if deepPercent > 20 && remPercent > 20 && awakePercent < 5 && totalMinutes > 420 {
            return .excellent
        }

        // Good: >15% deep, >15% REM, <10% awake, total >360 min (6h)
        if deepPercent > 15 && remPercent > 15 && awakePercent < 10 && totalMinutes > 360 {
            return .good
        }

        // Fair: >10% deep, >10% REM, <15% awake
        if deepPercent > 10 && remPercent > 10 && awakePercent < 15 {
            return .fair
        }

        return .poor
    }
}

/// Individual sleep record
public struct SleepRecord: Sendable, Codable, Identifiable {
    public let id: UUID
    public let startDate: Date
    public let endDate: Date
    public let stages: [SleepStageSegment]
    public let quality: SleepQuality
    public let source: DataSource

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        stages: [SleepStageSegment],
        quality: SleepQuality,
        source: DataSource = .healthKit
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.stages = stages
        self.quality = quality
        self.source = source
    }

    /// Total sleep duration in minutes
    public var totalMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Deep sleep minutes
    public var deepMinutes: Int {
        stages.filter { $0.stage == .deep }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    /// REM sleep minutes
    public var remMinutes: Int {
        stages.filter { $0.stage == .rem }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    /// Light sleep minutes
    public var lightMinutes: Int {
        stages.filter { $0.stage == .light }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    /// Awake minutes
    public var awakeMinutes: Int {
        stages.filter { $0.stage == .awake }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    /// Sleep efficiency (time asleep / time in bed)
    public var efficiency: Double {
        let asleepMinutes = totalMinutes - awakeMinutes
        return Double(asleepMinutes) / Double(totalMinutes) * 100
    }
}

/// Sleep stage segment within a sleep record
public struct SleepStageSegment: Sendable, Codable, Identifiable {
    public let id: UUID
    public let stage: SleepStage
    public let startDate: Date
    public let endDate: Date

    public init(
        id: UUID = UUID(),
        stage: SleepStage,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.stage = stage
        self.startDate = startDate
        self.endDate = endDate
    }

    public var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}

// MARK: - Heart Rate Models

/// Heart rate context
public enum HeartRateContext: String, Sendable, Codable {
    case resting
    case active
    case workout
    case sleep
    case recovery

    public var displayName: String {
        switch self {
        case .resting: return "Resting"
        case .active: return "Active"
        case .workout: return "Workout"
        case .sleep: return "Sleep"
        case .recovery: return "Recovery"
        }
    }
}

/// Heart rate record
public struct HeartRateRecord: Sendable, Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let beatsPerMinute: Int
    public let context: HeartRateContext
    public let source: DataSource

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        beatsPerMinute: Int,
        context: HeartRateContext,
        source: DataSource = .healthKit
    ) {
        self.id = id
        self.timestamp = timestamp
        self.beatsPerMinute = beatsPerMinute
        self.context = context
        self.source = source
    }

    /// Check if heart rate is in normal range for context
    public var isNormal: Bool {
        switch context {
        case .resting:
            return beatsPerMinute >= 60 && beatsPerMinute <= 100
        case .active:
            return beatsPerMinute >= 100 && beatsPerMinute <= 150
        case .workout:
            return beatsPerMinute >= 120 && beatsPerMinute <= 180
        case .sleep:
            return beatsPerMinute >= 40 && beatsPerMinute <= 60
        case .recovery:
            return beatsPerMinute >= 80 && beatsPerMinute <= 120
        }
    }
}

/// Cardiac anomaly detection
public struct CardiacAnomaly: Sendable, Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let type: AnomalyType
    public let severity: Severity
    public let heartRate: Int
    public let description: String

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        type: AnomalyType,
        severity: Severity,
        heartRate: Int,
        description: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.severity = severity
        self.heartRate = heartRate
        self.description = description
    }

    public enum AnomalyType: String, Sendable, Codable {
        case tachycardia  // High heart rate
        case bradycardia  // Low heart rate
        case irregular    // Irregular rhythm

        public var displayName: String {
            switch self {
            case .tachycardia: return "Tachycardia"
            case .bradycardia: return "Bradycardia"
            case .irregular: return "Irregular Rhythm"
            }
        }
    }

    public enum Severity: String, Sendable, Codable {
        case mild
        case moderate
        case severe

        public var color: String {
            switch self {
            case .mild: return "#F59E0B"      // Amber
            case .moderate: return "#F97316"  // Orange
            case .severe: return "#EF4444"    // Red
            }
        }
    }
}

// MARK: - Activity Models

/// Daily activity summary
public struct ActivitySummary: Sendable, Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let steps: Int
    public let activeCalories: Int
    public let totalCalories: Int
    public let distance: Double  // meters
    public let activeMinutes: Int
    public let flightsClimbed: Int
    public let source: DataSource

    public init(
        id: UUID = UUID(),
        date: Date,
        steps: Int,
        activeCalories: Int,
        totalCalories: Int,
        distance: Double,
        activeMinutes: Int,
        flightsClimbed: Int,
        source: DataSource = .healthKit
    ) {
        self.id = id
        self.date = date
        self.steps = steps
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.distance = distance
        self.activeMinutes = activeMinutes
        self.flightsClimbed = flightsClimbed
        self.source = source
    }

    /// Distance in kilometers
    public var distanceKm: Double {
        distance / 1000
    }

    /// Distance in miles
    public var distanceMiles: Double {
        distance / 1609.34
    }

    /// Check if daily step goal is met (default 10,000 steps)
    public func meetsStepGoal(_ goal: Int = 10000) -> Bool {
        steps >= goal
    }

    /// Check if daily active minutes goal is met (default 30 minutes)
    public func meetsActiveMinutesGoal(_ goal: Int = 30) -> Bool {
        activeMinutes >= goal
    }

    /// Activity score (0-100)
    public var activityScore: Int {
        var score = 0

        // Steps contribution (max 40 points)
        score += min(40, (steps * 40) / 10000)

        // Active minutes contribution (max 30 points)
        score += min(30, (activeMinutes * 30) / 30)

        // Calories contribution (max 20 points)
        score += min(20, (activeCalories * 20) / 500)

        // Flights climbed contribution (max 10 points)
        score += min(10, (flightsClimbed * 10) / 10)

        return score
    }
}

// MARK: - Vital Signs

/// Blood pressure reading
public struct BloodPressureReading: Sendable, Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let systolic: Int
    public let diastolic: Int
    public let pulse: Int?
    public let source: DataSource

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        systolic: Int,
        diastolic: Int,
        pulse: Int? = nil,
        source: DataSource = .manual
    ) {
        self.id = id
        self.timestamp = timestamp
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.source = source
    }

    /// Blood pressure category
    public var category: Category {
        if systolic < 120 && diastolic < 80 {
            return .normal
        } else if systolic < 130 && diastolic < 80 {
            return .elevated
        } else if systolic < 140 || diastolic < 90 {
            return .stage1Hypertension
        } else if systolic < 180 || diastolic < 120 {
            return .stage2Hypertension
        } else {
            return .hypertensiveCrisis
        }
    }

    public enum Category: String, Sendable, Codable {
        case normal
        case elevated
        case stage1Hypertension
        case stage2Hypertension
        case hypertensiveCrisis

        public var displayName: String {
            switch self {
            case .normal: return "Normal"
            case .elevated: return "Elevated"
            case .stage1Hypertension: return "Stage 1 Hypertension"
            case .stage2Hypertension: return "Stage 2 Hypertension"
            case .hypertensiveCrisis: return "Hypertensive Crisis"
            }
        }

        public var color: String {
            switch self {
            case .normal: return "#10B981"            // Green
            case .elevated: return "#F59E0B"          // Amber
            case .stage1Hypertension: return "#F97316" // Orange
            case .stage2Hypertension: return "#EF4444" // Red
            case .hypertensiveCrisis: return "#DC2626" // Dark red
            }
        }
    }
}

// MARK: - Health Error

/// Health-specific errors
public enum HealthError: Error, Sendable, LocalizedError {
    case authorizationDenied
    case healthKitUnavailable
    case dataNotAvailable
    case invalidDateRange
    case fetchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "HealthKit authorization was denied. Please enable access in Settings."
        case .healthKitUnavailable:
            return "HealthKit is not available on this device."
        case .dataNotAvailable:
            return "Health data is not available for the requested period."
        case .invalidDateRange:
            return "The specified date range is invalid."
        case .fetchFailed(let reason):
            return "Failed to fetch health data: \(reason)"
        }
    }
}
