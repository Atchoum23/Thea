// HolisticPatternIntelligenceTypes.swift
// Thea V2 - Types for AI-Powered Holistic Life Pattern Recognition
//
// Extracted from HolisticPatternIntelligence.swift

import Combine
import Foundation
import os.log

// MARK: - Pattern Categories

/// Categories of life patterns that Thea analyzes
public enum LifePatternCategory: String, CaseIterable, Codable, Sendable {
    // Device Usage Patterns
    case deviceSwitching = "device_switching"      // Patterns in which device is used when
    case appUsageSequences = "app_sequences"       // Common sequences of app usage
    case inputPatterns = "input_patterns"          // Typing, clicking, gesture patterns
    case screenTimeDistribution = "screen_time"    // How screen time is distributed

    // Daily Routine Patterns
    case wakeUpRoutine = "wake_up"                 // Morning routines
    case bedtimeRoutine = "bedtime"                // Evening wind-down patterns
    case mealTimes = "meal_times"                  // Eating schedule patterns
    case exerciseHabits = "exercise"               // Workout timing and types
    case breakPatterns = "breaks"                  // When and how often breaks are taken

    // Productivity Patterns
    case focusPeriods = "focus_periods"            // Best times for deep work
    case taskSwitching = "task_switching"          // How often tasks are switched
    case meetingPatterns = "meetings"              // Meeting frequency and duration
    case deadlineBehavior = "deadlines"            // How work changes near deadlines
    case procrastination = "procrastination"       // Procrastination triggers and patterns

    // Communication Patterns
    case responseTime = "response_time"            // How quickly messages are answered
    case communicationPeaks = "comm_peaks"         // When most communication happens
    case contactFrequency = "contact_frequency"    // How often certain contacts are reached
    case channelPreference = "channel_preference"  // Email vs chat vs call preferences

    // Health & Wellness Patterns
    case sleepQuality = "sleep_quality"            // Sleep duration and consistency
    case activityLevels = "activity_levels"        // Physical activity patterns
    case stressIndicators = "stress_indicators"    // Behavioral indicators of stress
    case posture = "posture"                       // Sitting/standing patterns
    case eyeStrain = "eye_strain"                  // Screen time vs breaks for eyes

    // Location & Movement Patterns
    case locationRoutines = "locations"            // Regular places and timing
    case commute = "commute"                       // Travel patterns
    case travelPreferences = "travel"              // Flight, hotel, transportation choices
    case homeZones = "home_zones"                  // Where time is spent at home

    // Financial Patterns
    case spending = "spending"                     // Spending habits and timing
    case subscriptions = "subscriptions"           // Subscription usage patterns
    case impulsePatterns = "impulse"               // Impulse purchase triggers

    // Entertainment Patterns
    case mediaConsumption = "media"                // TV, music, streaming patterns
    case contentPreferences = "content"            // Types of content consumed
    case bingeWatching = "binge"                   // Binge watching patterns
    case musicMood = "music_mood"                  // Music choices by mood/time

    // Social Patterns
    case socialEngagement = "social"               // Social media activity patterns
    case relationshipMaintenance = "relationships" // How relationships are maintained
    case isolationPeriods = "isolation"            // Periods of reduced social activity

    // Learning Patterns
    case learningStyle = "learning_style"          // How new information is absorbed
    case retentionPatterns = "retention"           // What helps information stick
    case skillDevelopment = "skills"               // Pattern of skill improvement

    // Environmental Patterns
    case homeAutomation = "automation"             // Smart home usage patterns
    case temperaturePrefs = "temperature"          // Climate preferences
    case lightingPatterns = "lighting"             // Lighting preferences by time
    case noiseEnvironment = "noise"                // Noise/quiet preferences

    // Meta Patterns
    case habitFormation = "habit_formation"        // How new habits are formed
    case behaviorChange = "behavior_change"        // What triggers lasting changes
    case motivationCycles = "motivation"           // Cycles of motivation
    case energyLevels = "energy"                   // Energy patterns throughout day
}

// MARK: - Detected Pattern

/// A pattern detected by the AI system
public struct DetectedLifePattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public let category: LifePatternCategory
    public let name: String
    public let description: String
    public let confidence: Double              // 0-1 how confident we are in this pattern
    public let frequency: PatternFrequency     // How often this pattern occurs
    public let timeContext: PatternTimeContext // When this pattern applies
    public let triggers: [PatternTrigger]      // What triggers this pattern
    public let correlations: [PatternCorrelation] // Related patterns
    public let impact: PatternImpact           // Positive/negative impact assessment
    public let suggestions: [PatternSuggestion] // AI-generated suggestions
    public let dataPoints: Int                 // Number of observations
    public let firstObserved: Date
    public let lastObserved: Date
    public let trend: PatternTrend             // Is this pattern growing/declining
    public let predictedNext: Date?            // When this pattern is likely to occur next

    public init(
        id: UUID = UUID(),
        category: LifePatternCategory,
        name: String,
        description: String,
        confidence: Double,
        frequency: PatternFrequency,
        timeContext: PatternTimeContext,
        triggers: [PatternTrigger] = [],
        correlations: [PatternCorrelation] = [],
        impact: PatternImpact,
        suggestions: [PatternSuggestion] = [],
        dataPoints: Int,
        firstObserved: Date,
        lastObserved: Date,
        trend: PatternTrend = .stable,
        predictedNext: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.description = description
        self.confidence = confidence
        self.frequency = frequency
        self.timeContext = timeContext
        self.triggers = triggers
        self.correlations = correlations
        self.impact = impact
        self.suggestions = suggestions
        self.dataPoints = dataPoints
        self.firstObserved = firstObserved
        self.lastObserved = lastObserved
        self.trend = trend
        self.predictedNext = predictedNext
    }
}

/// How often a behavioral pattern recurs.
public enum PatternFrequency: String, Codable, Sendable {
    case rare                        // Less than once a month
    case occasional                  // A few times a month
    case weekly                      // About once a week
    case frequent                    // Multiple times a week
    case daily                       // Every day
    case multipleDays = "multiple_daily" // Multiple times per day
    case continuous                  // Ongoing pattern
}

/// Temporal context associated with a detected behavioral pattern.
public struct PatternTimeContext: Codable, Sendable {
    public var timeOfDay: [Int]?           // Hours when pattern occurs (0-23)
    public var daysOfWeek: [Int]?          // Days when pattern occurs (1-7)
    public var seasonality: Seasonality?   // Seasonal patterns
    public var duration: TimeInterval?      // How long the pattern typically lasts
    public var peakTime: Int?              // Hour when pattern is strongest

    public init(
        timeOfDay: [Int]? = nil,
        daysOfWeek: [Int]? = nil,
        seasonality: Seasonality? = nil,
        duration: TimeInterval? = nil,
        peakTime: Int? = nil
    ) {
        self.timeOfDay = timeOfDay
        self.daysOfWeek = daysOfWeek
        self.seasonality = seasonality
        self.duration = duration
        self.peakTime = peakTime
    }

/// Seasonal cycle in which a behavioral pattern most commonly occurs.
    public enum Seasonality: String, Codable, Sendable {
        case spring, summer, fall, winter
        case weekday, weekend
        case monthStart, monthEnd
        case yearStart, yearEnd
    }
}

public struct PatternTrigger: Codable, Sendable {
    public let type: TriggerType
    public let description: String
    public let confidence: Double

    public init(type: TriggerType, description: String, confidence: Double) {
        self.type = type
        self.description = description
        self.confidence = confidence
    }

    public enum TriggerType: String, Codable, Sendable {
        case time            // Triggered by time of day
        case location        // Triggered by location
        case activity        // Triggered by preceding activity
        case person          // Triggered by interaction with someone
        case emotion         // Triggered by emotional state
        case external        // External trigger (weather, news, etc.)
        case device          // Triggered by device state
        case notification    // Triggered by a notification
        case calendar        // Triggered by calendar event
    }
}

public struct PatternCorrelation: Codable, Sendable {
    public let relatedPatternId: UUID
    public let relationshipType: RelationshipType
    public let strength: Double         // -1 to 1 (negative = inverse correlation)
    public let description: String

    public init(
        relatedPatternId: UUID,
        relationshipType: RelationshipType,
        strength: Double,
        description: String
    ) {
        self.relatedPatternId = relatedPatternId
        self.relationshipType = relationshipType
        self.strength = strength
        self.description = description
    }

    public enum RelationshipType: String, Codable, Sendable {
        case causes         // This pattern causes the other
        case causedBy       // This pattern is caused by the other
        case correlates     // Patterns occur together
        case precedes       // This pattern comes before
        case follows        // This pattern comes after
        case inversely      // Patterns are inversely related
    }
}

public struct PatternImpact: Codable, Sendable {
    public let overallScore: Double      // -1 to 1
    public let productivity: Double?
    public let health: Double?
    public let wellbeing: Double?
    public let relationships: Double?
    public let financial: Double?
    public let description: String

    public init(
        overallScore: Double,
        productivity: Double? = nil,
        health: Double? = nil,
        wellbeing: Double? = nil,
        relationships: Double? = nil,
        financial: Double? = nil,
        description: String
    ) {
        self.overallScore = overallScore
        self.productivity = productivity
        self.health = health
        self.wellbeing = wellbeing
        self.relationships = relationships
        self.financial = financial
        self.description = description
    }
}

public struct PatternSuggestion: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let actionable: Bool
    public let automatable: Bool
    public let expectedImpact: Double   // Expected improvement (-1 to 1)
    public let effort: EffortLevel
    public let priority: Int            // 1-5, higher = more important

    public init(
        id: UUID = UUID(),
        type: SuggestionType,
        title: String,
        description: String,
        actionable: Bool = true,
        automatable: Bool = false,
        expectedImpact: Double,
        effort: EffortLevel,
        priority: Int
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.actionable = actionable
        self.automatable = automatable
        self.expectedImpact = expectedImpact
        self.effort = effort
        self.priority = priority
    }

    public enum SuggestionType: String, Codable, Sendable {
        case reinforce      // Strengthen a positive pattern
        case break_pattern  // Break a negative pattern
        case optimize       // Optimize timing or approach
        case automate       // Suggest automation
        case schedule       // Suggest scheduling
        case environment    // Environmental change
        case habit          // Habit formation suggestion
        case relationship   // Relationship-related
        case health         // Health-related
        case productivity   // Productivity-related
    }

    public enum EffortLevel: String, Codable, Sendable {
        case minimal
        case low
        case medium
        case high
        case significant
    }
}

public enum PatternTrend: String, Codable, Sendable {
    case increasing     // Pattern is becoming more frequent/strong
    case stable         // Pattern is consistent
    case decreasing     // Pattern is becoming less frequent/strong
    case emerging       // New pattern, not enough data yet
    case declining      // Pattern may be disappearing
}

// MARK: - Pattern Insight

public struct PatternInsight: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: InsightType
    public let title: String
    public let description: String
    public let relatedPatternId: UUID?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        type: InsightType,
        title: String,
        description: String,
        relatedPatternId: UUID? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.relatedPatternId = relatedPatternId
        self.timestamp = timestamp
    }

    public enum InsightType: String, Codable, Sendable {
        case positive   // Something going well
        case warning    // Something to address
        case info       // Informational
        case milestone  // Achievement
        case prediction // Future prediction
    }
}

// MARK: - Configuration

public struct HolisticPatternConfiguration: Codable, Sendable {
    public var enabled: Bool = true
    public var deepAnalysisInterval: TimeInterval = 3600 // 1 hour
    public var incrementalAnalysisThrottle: TimeInterval = 300 // 5 minutes
    public var maxEventHistory: Int = 10000
    public var minimumDataPoints: Int = 5
    public var confidenceThreshold: Double = 0.5

    public init() {}
}
