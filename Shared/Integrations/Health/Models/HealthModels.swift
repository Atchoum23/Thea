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
        case .awake: "Awake"
        case .light: "Light Sleep"
        case .deep: "Deep Sleep"
        case .rem: "REM Sleep"
        }
    }

    public var color: Color {
        switch self {
        case .awake: .red
        case .light: Color(red: 0.38, green: 0.65, blue: 0.98) // Light blue #60A5FA
        case .deep: Color(red: 0.23, green: 0.51, blue: 0.96) // Blue #3B82F6
        case .rem: Color(red: 0.55, green: 0.36, blue: 0.96) // Purple #8B5CF6
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
        case .poor: "Poor"
        case .fair: "Fair"
        case .good: "Good"
        case .excellent: "Excellent"
        }
    }

    public var score: Int {
        switch self {
        case .poor: 25
        case .fair: 50
        case .good: 75
        case .excellent: 100
        }
    }

    public var color: String {
        switch self {
        case .poor: "#EF4444" // Red
        case .fair: "#F59E0B" // Amber
        case .good: "#10B981" // Green
        case .excellent: "#059669" // Dark green
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
        if deepPercent > 20, remPercent > 20, awakePercent < 5, totalMinutes > 420 {
            return .excellent
        }

        // Good: >15% deep, >15% REM, <10% awake, total >360 min (6h)
        if deepPercent > 15, remPercent > 15, awakePercent < 10, totalMinutes > 360 {
            return .good
        }

        // Fair: >10% deep, >10% REM, <15% awake
        if deepPercent > 10, remPercent > 10, awakePercent < 15 {
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
        case .resting: "Resting"
        case .active: "Active"
        case .workout: "Workout"
        case .sleep: "Sleep"
        case .recovery: "Recovery"
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
            beatsPerMinute >= 60 && beatsPerMinute <= 100
        case .active:
            beatsPerMinute >= 100 && beatsPerMinute <= 150
        case .workout:
            beatsPerMinute >= 120 && beatsPerMinute <= 180
        case .sleep:
            beatsPerMinute >= 40 && beatsPerMinute <= 60
        case .recovery:
            beatsPerMinute >= 80 && beatsPerMinute <= 120
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
        case tachycardia // High heart rate
        case bradycardia // Low heart rate
        case irregular // Irregular rhythm

        public var displayName: String {
            switch self {
            case .tachycardia: "Tachycardia"
            case .bradycardia: "Bradycardia"
            case .irregular: "Irregular Rhythm"
            }
        }
    }

    public enum Severity: String, Sendable, Codable {
        case mild
        case moderate
        case severe

        public var color: String {
            switch self {
            case .mild: "#F59E0B" // Amber
            case .moderate: "#F97316" // Orange
            case .severe: "#EF4444" // Red
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
    public let distance: Double // meters
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
            .normal
        } else if systolic < 130 && diastolic < 80 {
            .elevated
        } else if systolic < 140 || diastolic < 90 {
            .stage1Hypertension
        } else if systolic < 180 || diastolic < 120 {
            .stage2Hypertension
        } else {
            .hypertensiveCrisis
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
            case .normal: "Normal"
            case .elevated: "Elevated"
            case .stage1Hypertension: "Stage 1 Hypertension"
            case .stage2Hypertension: "Stage 2 Hypertension"
            case .hypertensiveCrisis: "Hypertensive Crisis"
            }
        }

        public var color: String {
            switch self {
            case .normal: "#10B981" // Green
            case .elevated: "#F59E0B" // Amber
            case .stage1Hypertension: "#F97316" // Orange
            case .stage2Hypertension: "#EF4444" // Red
            case .hypertensiveCrisis: "#DC2626" // Dark red
            }
        }
    }
}

// MARK: - VO2 Max Models

/// VO2 Max fitness level classification
public enum VO2MaxFitnessLevel: String, Sendable, Codable {
    case poor
    case belowAverage
    case average
    case aboveAverage
    case good
    case excellent
    case superior

    public var displayName: String {
        switch self {
        case .poor: "Poor"
        case .belowAverage: "Below Average"
        case .average: "Average"
        case .aboveAverage: "Above Average"
        case .good: "Good"
        case .excellent: "Excellent"
        case .superior: "Superior"
        }
    }

    /// Classify VO2 Max value based on age and sex
    public static func classify(vo2Max: Double, age: Int, isMale: Bool) -> VO2MaxFitnessLevel {
        // Simplified classification based on ACSM guidelines
        if isMale {
            switch age {
            case ..<30:
                if vo2Max >= 55 { return .superior }
                else if vo2Max >= 49 { return .excellent }
                else if vo2Max >= 43 { return .good }
                else if vo2Max >= 37 { return .aboveAverage }
                else if vo2Max >= 33 { return .average }
                else if vo2Max >= 29 { return .belowAverage }
                else { return .poor }
            case 30 ..< 40:
                if vo2Max >= 52 { return .superior }
                else if vo2Max >= 45 { return .excellent }
                else if vo2Max >= 40 { return .good }
                else if vo2Max >= 35 { return .aboveAverage }
                else if vo2Max >= 31 { return .average }
                else if vo2Max >= 27 { return .belowAverage }
                else { return .poor }
            default:
                if vo2Max >= 46 { return .superior }
                else if vo2Max >= 40 { return .excellent }
                else if vo2Max >= 36 { return .good }
                else if vo2Max >= 31 { return .aboveAverage }
                else if vo2Max >= 27 { return .average }
                else if vo2Max >= 23 { return .belowAverage }
                else { return .poor }
            }
        } else {
            switch age {
            case ..<30:
                if vo2Max >= 49 { return .superior }
                else if vo2Max >= 43 { return .excellent }
                else if vo2Max >= 37 { return .good }
                else if vo2Max >= 32 { return .aboveAverage }
                else if vo2Max >= 28 { return .average }
                else if vo2Max >= 24 { return .belowAverage }
                else { return .poor }
            case 30 ..< 40:
                if vo2Max >= 45 { return .superior }
                else if vo2Max >= 39 { return .excellent }
                else if vo2Max >= 34 { return .good }
                else if vo2Max >= 29 { return .aboveAverage }
                else if vo2Max >= 25 { return .average }
                else if vo2Max >= 21 { return .belowAverage }
                else { return .poor }
            default:
                if vo2Max >= 40 { return .superior }
                else if vo2Max >= 35 { return .excellent }
                else if vo2Max >= 31 { return .good }
                else if vo2Max >= 26 { return .aboveAverage }
                else if vo2Max >= 22 { return .average }
                else if vo2Max >= 19 { return .belowAverage }
                else { return .poor }
            }
        }
    }
}

/// VO2 Max measurement record
public struct VO2MaxRecord: Sendable, Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let value: Double // mL/kg/min
    public let source: DataSource

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        value: Double,
        source: DataSource = .healthKit
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.source = source
    }

    /// Formatted display value
    public var displayValue: String {
        String(format: "%.1f mL/kg/min", value)
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
            "HealthKit authorization was denied. Please enable access in Settings."
        case .healthKitUnavailable:
            "HealthKit is not available on this device."
        case .dataNotAvailable:
            "Health data is not available for the requested period."
        case .invalidDateRange:
            "The specified date range is invalid."
        case let .fetchFailed(reason):
            "Failed to fetch health data: \(reason)"
        }
    }
}
