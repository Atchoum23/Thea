import Foundation
import SwiftUI

// MARK: - Circadian Phase

/// Circadian rhythm phase (8-phase system for precise tracking)
public enum CircadianPhase: String, CaseIterable, Sendable, Codable {
    case earlyMorning
    case morning
    case midday
    case afternoon
    case evening
    case night
    case lateNight
    case deepNight

    public var displayName: String {
        switch self {
        case .earlyMorning: "Early Morning"
        case .morning: "Morning"
        case .midday: "Midday"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .night: "Night"
        case .lateNight: "Late Night"
        case .deepNight: "Deep Night"
        }
    }

    public var shortName: String {
        switch self {
        case .earlyMorning: "Early"
        case .morning: "Morn"
        case .midday: "Mid"
        case .afternoon: "After"
        case .evening: "Eve"
        case .night: "Night"
        case .lateNight: "Late"
        case .deepNight: "Deep"
        }
    }

    public var description: String {
        switch self {
        case .earlyMorning: "Gentle awakening period"
        case .morning: "Peak alertness and focus"
        case .midday: "High energy for tasks"
        case .afternoon: "Post-lunch recovery"
        case .evening: "Wind-down begins"
        case .night: "Relaxation mode"
        case .lateNight: "Sleep preparation"
        case .deepNight: "Deep rest period"
        }
    }

    public var iconName: String {
        switch self {
        case .earlyMorning: "sunrise.fill"
        case .morning: "sun.max.fill"
        case .midday: "sun.max.circle.fill"
        case .afternoon: "sun.haze.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        case .lateNight: "moon.fill"
        case .deepNight: "moon.zzz.fill"
        }
    }

    public var primaryColor: Color {
        switch self {
        case .earlyMorning: Color.orange.opacity(0.7)
        case .morning: Color.yellow
        case .midday: Color.orange
        case .afternoon: Color.orange.opacity(0.8)
        case .evening: Color.purple
        case .night: Color.indigo
        case .lateNight: Color.blue.opacity(0.6)
        case .deepNight: Color.blue.opacity(0.4)
        }
    }

    public var themeColors: [Color] {
        switch self {
        case .earlyMorning: [Color.orange, Color.yellow.opacity(0.5)]
        case .morning: [Color.yellow, Color.orange.opacity(0.5)]
        case .midday: [Color.orange, Color.yellow.opacity(0.6)]
        case .afternoon: [Color.orange, Color.red.opacity(0.4)]
        case .evening: [Color.purple, Color.pink.opacity(0.5)]
        case .night: [Color.indigo, Color.purple.opacity(0.6)]
        case .lateNight: [Color.blue, Color.indigo.opacity(0.5)]
        case .deepNight: [Color.blue.opacity(0.6), Color.black.opacity(0.3)]
        }
    }

    public var color: String {
        switch self {
        case .earlyMorning: "#FB923C" // Orange 400
        case .morning: "#FBBF24" // Amber 400
        case .midday: "#F59E0B" // Amber 500
        case .afternoon: "#F97316" // Orange 500
        case .evening: "#A855F7" // Purple 500
        case .night: "#6366F1" // Indigo 500
        case .lateNight: "#3B82F6" // Blue 500
        case .deepNight: "#1E40AF" // Blue 700
        }
    }

    public var timeRange: String {
        switch self {
        case .earlyMorning: "5:00 AM - 7:00 AM"
        case .morning: "7:00 AM - 10:00 AM"
        case .midday: "10:00 AM - 1:00 PM"
        case .afternoon: "1:00 PM - 5:00 PM"
        case .evening: "5:00 PM - 8:00 PM"
        case .night: "8:00 PM - 10:00 PM"
        case .lateNight: "10:00 PM - 12:00 AM"
        case .deepNight: "12:00 AM - 5:00 AM"
        }
    }

    public var backgroundColors: [Color] {
        themeColors
    }

    public var startHour: Int {
        switch self {
        case .earlyMorning: 5
        case .morning: 7
        case .midday: 10
        case .afternoon: 13
        case .evening: 17
        case .night: 20
        case .lateNight: 22
        case .deepNight: 0
        }
    }

    public var endHour: Int {
        switch self {
        case .earlyMorning: 7
        case .morning: 10
        case .midday: 13
        case .afternoon: 17
        case .evening: 20
        case .night: 22
        case .lateNight: 24
        case .deepNight: 5
        }
    }

    /// Get current phase based on time of day
    public static func current(hour: Int = Calendar.current.component(.hour, from: Date())) -> CircadianPhase {
        if hour >= 5, hour < 7 { return .earlyMorning }
        if hour >= 7, hour < 10 { return .morning }
        if hour >= 10, hour < 13 { return .midday }
        if hour >= 13, hour < 17 { return .afternoon }
        if hour >= 17, hour < 20 { return .evening }
        if hour >= 20, hour < 22 { return .night }
        if hour >= 22 { return .lateNight }
        return .deepNight
    }

    public static func phaseForHour(_ hour: Int) -> CircadianPhase {
        current(hour: hour)
    }

    /// Recommended UI brightness (0.0-1.0)
    public var recommendedBrightness: Double {
        switch self {
        case .earlyMorning: 0.6
        case .morning: 0.9
        case .midday: 1.0
        case .afternoon: 0.95
        case .evening: 0.7
        case .night: 0.4
        case .lateNight: 0.3
        case .deepNight: 0.2
        }
    }

    /// Recommended blue light filter intensity (0.0-1.0)
    public var blueFilterIntensity: Double {
        switch self {
        case .earlyMorning: 0.1
        case .morning: 0.0
        case .midday: 0.0
        case .afternoon: 0.2
        case .evening: 0.6
        case .night: 0.8
        case .lateNight: 0.9
        case .deepNight: 1.0
        }
    }

    /// Phase-specific health and wellness recommendations
    public var recommendations: [PhaseRecommendation] {
        switch self {
        case .earlyMorning:
            [
                PhaseRecommendation(icon: "sun.horizon", title: "Natural Light", description: "Expose yourself to natural daylight within 30 minutes of waking"),
                PhaseRecommendation(icon: "drop.fill", title: "Hydration", description: "Drink 16-20oz of water to rehydrate after sleep"),
                PhaseRecommendation(icon: "figure.walk", title: "Light Movement", description: "Gentle stretching or yoga to awaken the body")
            ]
        case .morning:
            [
                PhaseRecommendation(icon: "brain.head.profile", title: "Deep Work", description: "Tackle complex tasks requiring focus and creativity"),
                PhaseRecommendation(icon: "cup.and.saucer", title: "Strategic Caffeine", description: "90-120 minutes after waking for optimal cortisol alignment"),
                PhaseRecommendation(icon: "calendar", title: "Daily Planning", description: "Set priorities and structure your day")
            ]
        case .midday:
            [
                PhaseRecommendation(icon: "fork.knife", title: "Balanced Nutrition", description: "Eat a nutrient-dense meal with protein, healthy fats, and complex carbs"),
                PhaseRecommendation(icon: "figure.walk", title: "Post-Meal Movement", description: "10-15 minute walk to aid digestion and maintain energy"),
                PhaseRecommendation(icon: "sun.max.fill", title: "Sunlight Break", description: "Spend time outdoors to regulate circadian rhythm")
            ]
        case .afternoon:
            [
                PhaseRecommendation(icon: "powersleep", title: "Power Nap", description: "15-20 minute nap if needed (before 3 PM)"),
                PhaseRecommendation(icon: "drop.fill", title: "Hydrate", description: "Combat afternoon fatigue with water intake"),
                PhaseRecommendation(icon: "figure.stand", title: "Movement Break", description: "Stand, stretch, or take a brief walk every hour")
            ]
        case .evening:
            [
                PhaseRecommendation(icon: "book.fill", title: "Wind Down Activities", description: "Light reading, journaling, or relaxing hobbies"),
                PhaseRecommendation(icon: "moon.stars", title: "Dim Lighting", description: "Reduce bright lights and increase warm tones"),
                PhaseRecommendation(icon: "fork.knife", title: "Light Dinner", description: "Eat 2-3 hours before bedtime for better sleep")
            ]
        case .night:
            [
                PhaseRecommendation(icon: "laptopcomputer.slash", title: "Screen Curfew", description: "Stop screen time 60-90 minutes before bed"),
                PhaseRecommendation(icon: "bed.double.fill", title: "Sleep Preparation", description: "Begin bedtime routine: shower, skincare, etc."),
                PhaseRecommendation(icon: "thermometer.medium", title: "Cool Temperature", description: "Lower room temp to 65-68°F (18-20°C)")
            ]
        case .lateNight:
            [
                PhaseRecommendation(icon: "moon.zzz.fill", title: "Sleep Now", description: "This is past optimal bedtime—prioritize rest"),
                PhaseRecommendation(icon: "figure.mind.and.body", title: "Relaxation", description: "Deep breathing or meditation to facilitate sleep"),
                PhaseRecommendation(icon: "iphone.slash", title: "Device-Free Zone", description: "Keep phones and electronics out of bedroom")
            ]
        case .deepNight:
            [
                PhaseRecommendation(icon: "bed.double.fill", title: "Deep Rest", description: "Body is in critical repair phase—stay asleep"),
                PhaseRecommendation(icon: "moon.fill", title: "Minimize Disturbance", description: "Use blackout curtains and white noise if needed"),
                PhaseRecommendation(icon: "eye.slash", title: "Avoid Light", description: "If awake, use dim red light only")
            ]
        }
    }
}

// MARK: - Focus Mode

/// Focus mode type
public enum WellnessFocusMode: String, Sendable, Codable, CaseIterable {
    case work
    case study
    case creative
    case relax
    case sleep

    public var displayName: String {
        switch self {
        case .work: "Work"
        case .study: "Study"
        case .creative: "Creative"
        case .relax: "Relax"
        case .sleep: "Sleep"
        }
    }

    public var icon: String {
        switch self {
        case .work: "briefcase.fill"
        case .study: "book.fill"
        case .creative: "paintbrush.fill"
        case .relax: "leaf.fill"
        case .sleep: "moon.zzz.fill"
        }
    }

    public var color: String {
        switch self {
        case .work: "#3B82F6" // Blue
        case .study: "#8B5CF6" // Purple
        case .creative: "#F59E0B" // Amber
        case .relax: "#10B981" // Green
        case .sleep: "#6366F1" // Indigo
        }
    }

    /// Recommended session duration in minutes
    public var recommendedDuration: Int {
        switch self {
        case .work: 50
        case .study: 45
        case .creative: 90
        case .relax: 15
        case .sleep: 480
        }
    }

    /// Recommended break duration in minutes
    public var breakDuration: Int {
        switch self {
        case .work: 10
        case .study: 10
        case .creative: 20
        case .relax: 0
        case .sleep: 0
        }
    }

    /// Whether ambient audio is recommended
    public var supportsAmbientAudio: Bool {
        switch self {
        case .work, .study, .creative, .relax: true
        case .sleep: false
        }
    }
}

/// Focus session record
public struct FocusSession: Sendable, Codable, Identifiable {
    public let id: UUID
    public let mode: WellnessFocusMode
    public let startDate: Date
    public let endDate: Date?
    public let targetDuration: Int // minutes
    public let completed: Bool
    public let interrupted: Bool
    public let notes: String?

    public init(
        id: UUID = UUID(),
        mode: WellnessFocusMode,
        startDate: Date,
        endDate: Date? = nil,
        targetDuration: Int,
        completed: Bool = false,
        interrupted: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.mode = mode
        self.startDate = startDate
        self.endDate = endDate
        self.targetDuration = targetDuration
        self.completed = completed
        self.interrupted = interrupted
        self.notes = notes
    }

    /// Actual duration in minutes
    public var actualDuration: Int? {
        guard let endDate else { return nil }
        return Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Whether session is currently active
    public var isActive: Bool {
        endDate == nil
    }

    /// Session completion percentage
    public var completionPercentage: Double {
        guard let actual = actualDuration else { return 0 }
        return min(100, (Double(actual) / Double(targetDuration)) * 100)
    }
}

// MARK: - Ambient Audio

/// Ambient audio type
public enum AmbientAudio: String, Sendable, Codable, CaseIterable {
    case rain
    case ocean
    case forest
    case whitenoise
    case brownnoise
    case fireplace
    case cafe
    case thunderstorm

    public var displayName: String {
        switch self {
        case .rain: "Rain"
        case .ocean: "Ocean Waves"
        case .forest: "Forest"
        case .whitenoise: "White Noise"
        case .brownnoise: "Brown Noise"
        case .fireplace: "Fireplace"
        case .cafe: "Café Ambience"
        case .thunderstorm: "Thunderstorm"
        }
    }

    public var icon: String {
        switch self {
        case .rain: "cloud.rain.fill"
        case .ocean: "water.waves"
        case .forest: "leaf.fill"
        case .whitenoise: "waveform"
        case .brownnoise: "waveform.circle"
        case .fireplace: "flame.fill"
        case .cafe: "cup.and.saucer.fill"
        case .thunderstorm: "cloud.bolt.rain.fill"
        }
    }
}

// MARK: - Wellness Insight

/// Wellness insight generated from patterns
public struct WellnessInsight: Sendable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let category: Category
    public let priority: Priority
    public let timestamp: Date
    public let actionItems: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: Category,
        priority: Priority,
        timestamp: Date = Date(),
        actionItems: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.timestamp = timestamp
        self.actionItems = actionItems
    }

    public enum Category: String, Sendable, Codable {
        case circadian
        case focus
        case stress
        case productivity

        public var displayName: String {
            switch self {
            case .circadian: "Circadian Rhythm"
            case .focus: "Focus & Concentration"
            case .stress: "Stress Management"
            case .productivity: "Productivity"
            }
        }

        public var icon: String {
            switch self {
            case .circadian: "sun.max.fill"
            case .focus: "target"
            case .stress: "heart.fill"
            case .productivity: "chart.line.uptrend.xyaxis"
            }
        }
    }
}

// MARK: - Wellness Error

/// Wellness-specific errors
public enum WellnessError: Error, Sendable, LocalizedError {
    case sessionAlreadyActive
    case sessionNotFound
    case invalidDuration
    case audioPlaybackFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            "A focus session is already active. End the current session before starting a new one."
        case .sessionNotFound:
            "The requested focus session was not found."
        case .invalidDuration:
            "The session duration must be greater than 0."
        case let .audioPlaybackFailed(reason):
            "Audio playback failed: \(reason)"
        }
    }
}

// MARK: - Phase Recommendation

public struct PhaseRecommendation: Hashable, Sendable {
    public let icon: String
    public let title: String
    public let description: String

    public init(icon: String, title: String, description: String) {
        self.icon = icon
        self.title = title
        self.description = description
    }
}
