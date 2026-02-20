// LifeMonitoringCoordinatorTypes.swift
// Thea V2 - Types for Life Monitoring Coordinator
//
// Extracted from LifeMonitoringCoordinator.swift

import Combine
import Foundation
import os.log

// MARK: - Supporting Types

public enum DataSourceType: String, CaseIterable, Sendable {
    case browserExtension = "browser"
    case clipboard = "clipboard"
    case messages = "messages"
    case mail = "mail"
    case fileSystem = "files"
    case health = "health"
    case location = "location"
    case appUsage = "apps"
    case calendar = "calendar"
    case reminders = "reminders"

    // V2 Comprehensive Sources
    case socialMedia = "social_media"
    case interactions = "interactions"
    case tvActivity = "tv_activity" // Samsung TV via Tizen

    // V2.1 Extended Sources
    case homeKit = "homekit"
    case shortcuts = "shortcuts"
    case media = "media"
    case photos = "photos"
    case notifications = "notifications"
    case documentEditing = "document_editing"
    case inputActivity = "input_activity"
    case weather = "weather"

    public var displayName: String {
        switch self {
        case .browserExtension: return "Browser"
        case .clipboard: return "Clipboard"
        case .messages: return "Messages"
        case .mail: return "Mail"
        case .fileSystem: return "Files"
        case .health: return "Health"
        case .location: return "Location"
        case .appUsage: return "Apps"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .socialMedia: return "Social Media"
        case .interactions: return "Interactions"
        case .tvActivity: return "TV Activity"
        case .homeKit: return "HomeKit"
        case .shortcuts: return "Shortcuts"
        case .media: return "Media"
        case .photos: return "Photos"
        case .notifications: return "Notifications"
        case .documentEditing: return "Documents"
        case .inputActivity: return "Input Activity"
        case .weather: return "Weather"
        }
    }

    public var icon: String {
        switch self {
        case .browserExtension: return "globe"
        case .clipboard: return "doc.on.clipboard"
        case .messages: return "message"
        case .mail: return "envelope"
        case .fileSystem: return "folder"
        case .health: return "heart"
        case .location: return "location"
        case .appUsage: return "app.badge"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .socialMedia: return "person.2"
        case .interactions: return "person.3"
        case .tvActivity: return "tv"
        case .homeKit: return "homekit"
        case .shortcuts: return "square.stack.3d.up"
        case .media: return "play.circle"
        case .photos: return "photo"
        case .notifications: return "bell"
        case .documentEditing: return "doc.text"
        case .inputActivity: return "keyboard"
        case .weather: return "cloud.sun"
        }
    }
}

public enum ConnectionStatus: String, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

public struct LifeMonitoringConfiguration: Codable, Sendable {
    public var enabled: Bool = true

    // Data source toggles (Legacy)
    public var browserMonitoringEnabled: Bool = true
    public var clipboardMonitoringEnabled: Bool = true
    public var messagesMonitoringEnabled: Bool = true
    public var mailMonitoringEnabled: Bool = true
    public var fileSystemMonitoringEnabled: Bool = true

    // V2 Comprehensive Monitoring toggles
    public var socialMediaMonitoringEnabled: Bool = true
    public var appUsageMonitoringEnabled: Bool = true
    public var interactionTrackingEnabled: Bool = true
    public var healthMonitoringEnabled: Bool = true
    public var locationTrackingEnabled: Bool = true
    public var tvActivityEnabled: Bool = true // Samsung TV via Tizen

    // V2.1 Extended Monitoring toggles
    public var calendarMonitoringEnabled: Bool = true
    public var remindersMonitoringEnabled: Bool = true
    public var homeKitMonitoringEnabled: Bool = true
    public var shortcutsMonitoringEnabled: Bool = true
    public var mediaMonitoringEnabled: Bool = true
    public var photosMonitoringEnabled: Bool = true
    public var notificationMonitoringEnabled: Bool = true
    public var documentEditingMonitoringEnabled: Bool = true
    public var inputActivityMonitoringEnabled: Bool = true
    public var behaviorPatternAnalysisEnabled: Bool = true
    public var efficiencySuggestionsEnabled: Bool = true

    // V2.2 AI-Powered Intelligence toggles
    public var holisticPatternIntelligenceEnabled: Bool = true
    public var predictiveEngineEnabled: Bool = true

    // Browser monitoring options
    public var capturePageContent: Bool = true
    public var captureReadingBehavior: Bool = true
    public var captureSelections: Bool = true

    // Content capture
    public var captureFullContent: Bool = true // vs summary only
    public var aiAnalysisEnabled: Bool = true

    // Social media options
    public var enabledSocialPlatforms: Set<String> = [
        "whatsapp", "instagram", "facebook", "messenger",
        "tinder", "raya", "bumble", "hinge",
        "twitter", "telegram", "discord", "slack", "teams"
    ]
    public var trackDatingApps: Bool = true
    public var recordSocialContactNames: Bool = true
    public var recordMessagePreviews: Bool = false // Privacy option

    // App usage options
    public var trackProductivityApps: Bool = true
    public var trackSocialApps: Bool = true
    public var trackEntertainmentApps: Bool = true
    public var calculateProductivityScore: Bool = true

    // Interaction tracking options
    public var trackPersonalInteractions: Bool = true
    public var trackBusinessInteractions: Bool = true
    public var generateRelationshipInsights: Bool = true

    // File system options
    public var watchedDirectories: [String] = [
        "~/Documents",
        "~/Desktop",
        "~/Downloads"
    ]

    // Privacy
    public var excludedDomains: [String] = []
    public var excludedApps: [String] = []
    public var excludedContacts: [String] = []

    // Retention
    public var retentionDays: Int = 90

    // iCloud Sync
    public var iCloudSyncEnabled: Bool = true
    public var syncSignificantEventsOnly: Bool = false // Sync ALL events for 100% coverage
    public var syncAcrossAllDevices: Bool = true // Include TV, Watch, etc.

    public init() {}
}

public struct LifeMonitoringStatistics: Sendable {
    public let isEnabled: Bool
    public let activeSources: Set<DataSourceType>
    public let todayEventCount: Int
    public let lastEventTime: Date?
    public let connectionStatus: ConnectionStatus
}

// MARK: - Life Event

/// A single life event from any monitoring source
public struct LifeEvent: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: LifeEventType
    public let source: DataSourceType
    public let summary: String
    public let data: [String: String]
    public let significance: EventSignificance
    public let sentiment: Double // -1 to 1
    public let extractedEntities: [ExtractedEntity]?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: LifeEventType,
        source: DataSourceType,
        summary: String,
        data: [String: String] = [:],
        significance: EventSignificance = .minor,
        sentiment: Double = 0.0,
        extractedEntities: [ExtractedEntity]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.source = source
        self.summary = summary
        self.data = data
        self.significance = significance
        self.sentiment = sentiment
        self.extractedEntities = extractedEntities
    }
}

public enum LifeEventType: String, Codable, Sendable {
    // Browser
    case pageVisit = "page_visit"
    case pageRead = "page_read"
    case linkClick = "link_click"
    case searchQuery = "search"
    case formSubmit = "form_submit"

    // Communication
    case messageReceived = "message_received"
    case messageSent = "message_sent"
    case emailReceived = "email_received"
    case emailSent = "email_sent"

    // Productivity
    case fileActivity = "file_activity"
    case appSwitch = "app_switch"
    case clipboardCopy = "clipboard_copy"
    case documentActivity = "document_activity"
    case inputActivity = "input_activity"
    case behaviorPattern = "behavior_pattern"
    case efficiencySuggestion = "efficiency_suggestion"

    // Calendar/Tasks
    case eventStart = "event_start"
    case reminderDue = "reminder_due"
    case calendarEventCreated = "calendar_event_created"
    case calendarEventModified = "calendar_event_modified"
    case calendarEventDeleted = "calendar_event_deleted"
    case reminderCreated = "reminder_created"
    case reminderCompleted = "reminder_completed"
    case reminderDeleted = "reminder_deleted"

    // Health
    case healthMetric = "health_metric"
    case activityGoal = "activity_goal"

    // Location
    case locationArrival = "location_arrival"
    case locationDeparture = "location_departure"

    // Social Media (V2)
    case socialLike = "social_like"
    case socialComment = "social_comment"
    case socialFollow = "social_follow"
    case socialMention = "social_mention"
    case socialMatch = "social_match" // Dating apps
    case socialStoryView = "social_story_view"
    case socialCall = "social_call"
    case socialVideoCall = "social_video_call"

    // Interactions (V2)
    case interactionPerson = "interaction_person"
    case interactionCompany = "interaction_company"
    case relationshipInsight = "relationship_insight"

    // TV Activity (V2 - Samsung TV via Tizen)
    case tvWatching = "tv_watching"
    case tvAppLaunch = "tv_app_launch"
    case tvChannelChange = "tv_channel_change"
    case tvVolumeChange = "tv_volume_change"
    case tvPowerState = "tv_power_state"

    // HomeKit (V2.1)
    case homeKitPowerChange = "homekit_power_change"
    case homeKitBrightnessChange = "homekit_brightness_change"
    case homeKitThermostatChange = "homekit_thermostat_change"
    case homeKitLockChange = "homekit_lock_change"
    case homeKitMotionDetected = "homekit_motion_detected"
    case homeKitContactSensorChange = "homekit_contact_sensor_change"
    case homeKitDoorChange = "homekit_door_change"
    case homeKitDeviceActive = "homekit_device_active"
    case homeKitSensorReading = "homekit_sensor_reading"
    case homeKitStateChange = "homekit_state_change"
    case homeKitSceneExecuted = "homekit_scene_executed"

    // Shortcuts (V2.1)
    case shortcutExecuted = "shortcut_executed"
    case shortcutFailed = "shortcut_failed"

    // Media (V2.1)
    case musicPlaying = "music_playing"
    case musicPaused = "music_paused"
    case musicStopped = "music_stopped"
    case musicSessionEnded = "music_session_ended"
    case videoPlaying = "video_playing"
    case videoPaused = "video_paused"
    case videoStopped = "video_stopped"
    case videoSessionEnded = "video_session_ended"

    // Photos (V2.1)
    case photoTaken = "photo_taken"
    case screenshotTaken = "screenshot_taken"
    case photoEdited = "photo_edited"
    case photoFavorited = "photo_favorited"
    case photoDeleted = "photo_deleted"

    // Notifications (V2.1)
    case notificationReceived = "notification_received"
    case notificationInteracted = "notification_interacted"
    case notificationDismissed = "notification_dismissed"

    // Weather (V2.1)
    case weatherChange = "weather_change"
}

public enum EventSignificance: Int, Codable, Comparable, Sendable {
    case trivial = 0
    case minor = 1
    case moderate = 2
    case significant = 3
    case major = 4

    public static func < (lhs: EventSignificance, rhs: EventSignificance) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ExtractedEntity: Codable, Sendable {
    public let type: String
    public let value: String
    public let confidence: Double

    public init(type: String, value: String, confidence: Double) {
        self.type = type
        self.value = value
        self.confidence = confidence
    }
}

// MARK: - Browser Event Payload

/// Payload received from browser extension
struct BrowserEventPayload: Codable {
    let type: String
    let timestamp: Double
    let data: BrowserEventData

    struct BrowserEventData: Codable {
        // Page info
        let url: String?
        let title: String?
        let hostname: String?

        // Content
        let content: String?
        let wordCount: Int?
        let estimatedReadTime: Int?

        // Reading behavior
        let maxScrollDepth: Int?
        let focusTime: Int?
        let engagement: String?
        let clicks: Int?
        let selections: [String]?

        // Flags
        let isInitial: Bool?
        let isComplete: Bool?
    }

    func toLifeEvent() -> LifeEvent {
        let eventType: LifeEventType = data.isComplete == true ? .pageRead : .pageVisit
        let significance: EventSignificance = calculateSignificance()

        var eventData: [String: String] = [:]
        if let url = data.url { eventData["url"] = url }
        if let hostname = data.hostname { eventData["hostname"] = hostname }
        if let content = data.content { eventData["content"] = String(content.prefix(10000)) }
        if let wordCount = data.wordCount { eventData["wordCount"] = String(wordCount) }
        if let scrollDepth = data.maxScrollDepth { eventData["scrollDepth"] = String(scrollDepth) }
        if let focusTime = data.focusTime { eventData["focusTimeMs"] = String(focusTime) }
        if let engagement = data.engagement { eventData["engagement"] = engagement }

        return LifeEvent(
            timestamp: Date(timeIntervalSince1970: timestamp / 1000),
            type: eventType,
            source: .browserExtension,
            summary: data.title ?? data.url ?? "Unknown page",
            data: eventData,
            significance: significance
        )
    }

    private func calculateSignificance() -> EventSignificance {
        // Higher engagement = higher significance
        if let engagement = data.engagement {
            switch engagement {
            case "high": return .significant
            case "medium": return .moderate
            case "low": return .minor
            default: return .trivial
            }
        }

        // Long content = more significant
        if let wordCount = data.wordCount, wordCount > 1000 {
            return .moderate
        }

        return .minor
    }
}

// MARK: - TV Activity Event (Tizen)

/// Event from Samsung TV via Thea-Tizen app
public struct TVActivityEvent: Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let activityType: TVActivityType
    public let description: String
    public let metadata: [String: String]
    public let significance: EventSignificance

    public enum TVActivityType: String, Codable, Sendable {
        case watching = "watching"
        case appLaunch = "app_launch"
        case channelChange = "channel_change"
        case volumeChange = "volume_change"
        case powerOn = "power_on"
        case powerOff = "power_off"
        case inputChange = "input_change"
        case searchQuery = "search_query"
        case playbackStart = "playback_start"
        case playbackPause = "playback_pause"
        case playbackStop = "playback_stop"
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        activityType: TVActivityType,
        description: String,
        metadata: [String: String] = [:],
        significance: EventSignificance = .minor
    ) {
        self.id = id
        self.timestamp = timestamp
        self.activityType = activityType
        self.description = description
        self.metadata = metadata
        self.significance = significance
    }

    public func toLifeEventType() -> LifeEventType {
        switch activityType {
        case .watching, .playbackStart, .playbackPause, .playbackStop:
            return .tvWatching
        case .appLaunch:
            return .tvAppLaunch
        case .channelChange, .inputChange:
            return .tvChannelChange
        case .volumeChange:
            return .tvVolumeChange
        case .powerOn, .powerOff:
            return .tvPowerState
        case .searchQuery:
            return .searchQuery
        }
    }
}

// MARK: - iOS Screen Time Observer

#if os(iOS)
    @available(iOS 16.0, *)
    @MainActor
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    final class LifeMonitoringScreenTimeObserver: ObservableObject {
        static let shared = LifeMonitoringScreenTimeObserver()

        private init() {}

        func requestAuthorization() async throws {
            // Screen Time API authorization would go here
            // This requires proper entitlements and App Store review
        }

        func startMonitoring() {
            // Screen Time monitoring implementation
        }
    }
#endif
