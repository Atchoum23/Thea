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
        case .earlyMorning: return "Early Morning"
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        case .lateNight: return "Late Night"
        case .deepNight: return "Deep Night"
        }
    }

    public var shortName: String {
        switch self {
        case .earlyMorning: return "Early"
        case .morning: return "Morn"
        case .midday: return "Mid"
        case .afternoon: return "After"
        case .evening: return "Eve"
        case .night: return "Night"
        case .lateNight: return "Late"
        case .deepNight: return "Deep"
        }
    }

    public var description: String {
        switch self {
        case .earlyMorning: return "Gentle awakening period"
        case .morning: return "Peak alertness and focus"
        case .midday: return "High energy for tasks"
        case .afternoon: return "Post-lunch recovery"
        case .evening: return "Wind-down begins"
        case .night: return "Relaxation mode"
        case .lateNight: return "Sleep preparation"
        case .deepNight: return "Deep rest period"
        }
    }

    public var iconName: String {
        switch self {
        case .earlyMorning: return "sunrise.fill"
        case .morning: return "sun.max.fill"
        case .midday: return "sun.max.circle.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        case .lateNight: return "moon.fill"
        case .deepNight: return "moon.zzz.fill"
        }
    }

    public var primaryColor: Color {
        switch self {
        case .earlyMorning: return Color.orange.opacity(0.7)
        case .morning: return Color.yellow
        case .midday: return Color.orange
        case .afternoon: return Color.orange.opacity(0.8)
        case .evening: return Color.purple
        case .night: return Color.indigo
        case .lateNight: return Color.blue.opacity(0.6)
        case .deepNight: return Color.blue.opacity(0.4)
        }
    }

    public var themeColors: [Color] {
        switch self {
        case .earlyMorning: return [Color.orange, Color.yellow.opacity(0.5)]
        case .morning: return [Color.yellow, Color.orange.opacity(0.5)]
        case .midday: return [Color.orange, Color.yellow.opacity(0.6)]
        case .afternoon: return [Color.orange, Color.red.opacity(0.4)]
        case .evening: return [Color.purple, Color.pink.opacity(0.5)]
        case .night: return [Color.indigo, Color.purple.opacity(0.6)]
        case .lateNight: return [Color.blue, Color.indigo.opacity(0.5)]
        case .deepNight: return [Color.blue.opacity(0.6), Color.black.opacity(0.3)]
        }
    }

    public var color: String {
        switch self {
        case .earlyMorning: return "#FB923C"  // Orange 400
        case .morning: return "#FBBF24"       // Amber 400
        case .midday: return "#F59E0B"        // Amber 500
        case .afternoon: return "#F97316"     // Orange 500
        case .evening: return "#A855F7"       // Purple 500
        case .night: return "#6366F1"         // Indigo 500
        case .lateNight: return "#3B82F6"     // Blue 500
        case .deepNight: return "#1E40AF"     // Blue 700
        }
    }

    public var timeRange: String {
        switch self {
        case .earlyMorning: return "5:00 AM - 7:00 AM"
        case .morning: return "7:00 AM - 10:00 AM"
        case .midday: return "10:00 AM - 1:00 PM"
        case .afternoon: return "1:00 PM - 5:00 PM"
        case .evening: return "5:00 PM - 8:00 PM"
        case .night: return "8:00 PM - 10:00 PM"
        case .lateNight: return "10:00 PM - 12:00 AM"
        case .deepNight: return "12:00 AM - 5:00 AM"
        }
    }

    public var backgroundColors: [Color] {
        themeColors
    }

    public var startHour: Int {
        switch self {
        case .earlyMorning: return 5
        case .morning: return 7
        case .midday: return 10
        case .afternoon: return 13
        case .evening: return 17
        case .night: return 20
        case .lateNight: return 22
        case .deepNight: return 0
        }
    }

    public var endHour: Int {
        switch self {
        case .earlyMorning: return 7
        case .morning: return 10
        case .midday: return 13
        case .afternoon: return 17
        case .evening: return 20
        case .night: return 22
        case .lateNight: return 24
        case .deepNight: return 5
        }
    }

    /// Get current phase based on time of day
    public static func current(hour: Int = Calendar.current.component(.hour, from: Date())) -> CircadianPhase {
        if hour >= 5 && hour < 7 { return .earlyMorning }
        if hour >= 7 && hour < 10 { return .morning }
        if hour >= 10 && hour < 13 { return .midday }
        if hour >= 13 && hour < 17 { return .afternoon }
        if hour >= 17 && hour < 20 { return .evening }
        if hour >= 20 && hour < 22 { return .night }
        if hour >= 22 { return .lateNight }
        return .deepNight
    }

    public static func phaseForHour(_ hour: Int) -> CircadianPhase {
        current(hour: hour)
    }

    /// Recommended UI brightness (0.0-1.0)
    public var recommendedBrightness: Double {
        switch self {
        case .earlyMorning: return 0.6
        case .morning: return 0.9
        case .midday: return 1.0
        case .afternoon: return 0.95
        case .evening: return 0.7
        case .night: return 0.4
        case .lateNight: return 0.3
        case .deepNight: return 0.2
        }
    }

    /// Recommended blue light filter intensity (0.0-1.0)
    public var blueFilterIntensity: Double {
        switch self {
        case .earlyMorning: return 0.1
        case .morning: return 0.0
        case .midday: return 0.0
        case .afternoon: return 0.2
        case .evening: return 0.6
        case .night: return 0.8
        case .lateNight: return 0.9
        case .deepNight: return 1.0
        }
    }

    /// Phase-specific health and wellness recommendations
    public var recommendations: [PhaseRecommendation] {
        switch self {
        case .earlyMorning:
            return [
                PhaseRecommendation(icon: "sun.horizon", title: "Natural Light", description: "Expose yourself to natural daylight within 30 minutes of waking"),
                PhaseRecommendation(icon: "drop.fill", title: "Hydration", description: "Drink 16-20oz of water to rehydrate after sleep"),
                PhaseRecommendation(icon: "figure.walk", title: "Light Movement", description: "Gentle stretching or yoga to awaken the body")
            ]
        case .morning:
            return [
                PhaseRecommendation(icon: "brain.head.profile", title: "Deep Work", description: "Tackle complex tasks requiring focus and creativity"),
                PhaseRecommendation(icon: "cup.and.saucer", title: "Strategic Caffeine", description: "90-120 minutes after waking for optimal cortisol alignment"),
                PhaseRecommendation(icon: "calendar", title: "Daily Planning", description: "Set priorities and structure your day")
            ]
        case .midday:
            return [
                PhaseRecommendation(icon: "fork.knife", title: "Balanced Nutrition", description: "Eat a nutrient-dense meal with protein, healthy fats, and complex carbs"),
                PhaseRecommendation(icon: "figure.walk", title: "Post-Meal Movement", description: "10-15 minute walk to aid digestion and maintain energy"),
                PhaseRecommendation(icon: "sun.max.fill", title: "Sunlight Break", description: "Spend time outdoors to regulate circadian rhythm")
            ]
        case .afternoon:
            return [
                PhaseRecommendation(icon: "powersleep", title: "Power Nap", description: "15-20 minute nap if needed (before 3 PM)"),
                PhaseRecommendation(icon: "drop.fill", title: "Hydrate", description: "Combat afternoon fatigue with water intake"),
                PhaseRecommendation(icon: "figure.stand", title: "Movement Break", description: "Stand, stretch, or take a brief walk every hour")
            ]
        case .evening:
            return [
                PhaseRecommendation(icon: "book.fill", title: "Wind Down Activities", description: "Light reading, journaling, or relaxing hobbies"),
                PhaseRecommendation(icon: "moon.stars", title: "Dim Lighting", description: "Reduce bright lights and increase warm tones"),
                PhaseRecommendation(icon: "fork.knife", title: "Light Dinner", description: "Eat 2-3 hours before bedtime for better sleep")
            ]
        case .night:
            return [
                PhaseRecommendation(icon: "laptopcomputer.slash", title: "Screen Curfew", description: "Stop screen time 60-90 minutes before bed"),
                PhaseRecommendation(icon: "bed.double.fill", title: "Sleep Preparation", description: "Begin bedtime routine: shower, skincare, etc."),
                PhaseRecommendation(icon: "thermometer.medium", title: "Cool Temperature", description: "Lower room temp to 65-68°F (18-20°C)")
            ]
        case .lateNight:
            return [
                PhaseRecommendation(icon: "moon.zzz.fill", title: "Sleep Now", description: "This is past optimal bedtime—prioritize rest"),
                PhaseRecommendation(icon: "figure.mind.and.body", title: "Relaxation", description: "Deep breathing or meditation to facilitate sleep"),
                PhaseRecommendation(icon: "iphone.slash", title: "Device-Free Zone", description: "Keep phones and electronics out of bedroom")
            ]
        case .deepNight:
            return [
                PhaseRecommendation(icon: "bed.double.fill", title: "Deep Rest", description: "Body is in critical repair phase—stay asleep"),
                PhaseRecommendation(icon: "moon.fill", title: "Minimize Disturbance", description: "Use blackout curtains and white noise if needed"),
                PhaseRecommendation(icon: "eye.slash", title: "Avoid Light", description: "If awake, use dim red light only")
            ]
        }
    }
}

// MARK: - Focus Mode

/// Focus mode type
public enum FocusMode: String, Sendable, Codable, CaseIterable {
    case work
    case study
    case creative
    case relax
    case sleep

    public var displayName: String {
        switch self {
        case .work: return "Work"
        case .study: return "Study"
        case .creative: return "Creative"
        case .relax: return "Relax"
        case .sleep: return "Sleep"
        }
    }

    public var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .creative: return "paintbrush.fill"
        case .relax: return "leaf.fill"
        case .sleep: return "moon.zzz.fill"
        }
    }

    public var color: String {
        switch self {
        case .work: return "#3B82F6"      // Blue
        case .study: return "#8B5CF6"     // Purple
        case .creative: return "#F59E0B"  // Amber
        case .relax: return "#10B981"     // Green
        case .sleep: return "#6366F1"     // Indigo
        }
    }

    /// Recommended session duration in minutes
    public var recommendedDuration: Int {
        switch self {
        case .work: return 50
        case .study: return 45
        case .creative: return 90
        case .relax: return 15
        case .sleep: return 480
        }
    }

    /// Recommended break duration in minutes
    public var breakDuration: Int {
        switch self {
        case .work: return 10
        case .study: return 10
        case .creative: return 20
        case .relax: return 0
        case .sleep: return 0
        }
    }

    /// Whether ambient audio is recommended
    public var supportsAmbientAudio: Bool {
        switch self {
        case .work, .study, .creative, .relax: return true
        case .sleep: return false
        }
    }
}

/// Focus session record
public struct FocusSession: Sendable, Codable, Identifiable {
    public let id: UUID
    public let mode: FocusMode
    public let startDate: Date
    public let endDate: Date?
    public let targetDuration: Int // minutes
    public let completed: Bool
    public let interrupted: Bool
    public let notes: String?

    public init(
        id: UUID = UUID(),
        mode: FocusMode,
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
        guard let endDate = endDate else { return nil }
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
        case .rain: return "Rain"
        case .ocean: return "Ocean Waves"
        case .forest: return "Forest"
        case .whitenoise: return "White Noise"
        case .brownnoise: return "Brown Noise"
        case .fireplace: return "Fireplace"
        case .cafe: return "Café Ambience"
        case .thunderstorm: return "Thunderstorm"
        }
    }

    public var icon: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .whitenoise: return "waveform"
        case .brownnoise: return "waveform.circle"
        case .fireplace: return "flame.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
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
            case .circadian: return "Circadian Rhythm"
            case .focus: return "Focus & Concentration"
            case .stress: return "Stress Management"
            case .productivity: return "Productivity"
            }
        }

        public var icon: String {
            switch self {
            case .circadian: return "sun.max.fill"
            case .focus: return "target"
            case .stress: return "heart.fill"
            case .productivity: return "chart.line.uptrend.xyaxis"
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
            return "A focus session is already active. End the current session before starting a new one."
        case .sessionNotFound:
            return "The requested focus session was not found."
        case .invalidDuration:
            return "The session duration must be greater than 0."
        case .audioPlaybackFailed(let reason):
            return "Audio playback failed: \(reason)"
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
