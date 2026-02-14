// FocusModeSettings.swift
// THEA - Global Focus Mode settings and location structures
// Extracted from FocusModeIntelligence.swift

import Foundation

// MARK: - Global Settings

/// Global THEA Focus Mode settings (synced across devices)
public struct FocusModeGlobalSettings: Codable, Sendable {
    // Enable/disable entire system
    public var systemEnabled: Bool

    // Auto-reply settings
    public var autoReplyEnabled: Bool
    public var autoReplyDelay: TimeInterval // Seconds before auto-reply
    public var maxAutoRepliesPerContact: Int
    public var autoReplyWindow: TimeInterval // Don't reply again within this time
    public var askIfUrgent: Bool
    public var autoReplyPlatforms: [CommunicationPlatform]

    // WhatsApp settings
    public var whatsAppStatusSyncEnabled: Bool
    public var whatsAppAutoReplyEnabled: Bool
    public var preservePreviousWhatsAppStatus: Bool

    // Telegram settings
    public var telegramStatusSyncEnabled: Bool
    public var telegramAutoReplyEnabled: Bool

    // Caller notification settings
    public var callerNotificationEnabled: Bool
    public var callerNotificationPlatforms: [CommunicationPlatform]
    public var sendSMSAfterMissedCall: Bool
    public var smsDelayAfterMissedCall: TimeInterval

    // Callback system
    public var autoCallbackEnabled: Bool // Instead of asking them to call twice
    public var callbackDelay: TimeInterval

    // Emergency settings
    public var emergencyContactsEnabled: Bool
    public var emergencyContacts: [String] // Always ring through
    public var emergencyKeywordDetection: Bool
    public var autoDialEmergencyServices: Bool // If emergency detected

    // Swisscom COMBOX
    public var comboxIntegrationEnabled: Bool
    public var comboxSwitchGreetingOnFocus: Bool
    public var comboxDefaultGreeting: String
    public var comboxFocusGreeting: String

    // Learning & anticipation
    public var learnContactLanguages: Bool
    public var learnContactPriorities: Bool
    public var suggestFocusModeActivation: Bool
    public var predictUrgentContacts: Bool

    // Time-aware responses
    public var timeAwareResponses: Bool
    public var businessHoursStart: DateComponents
    public var businessHoursEnd: DateComponents
    public var includeAvailabilityInReply: Bool // "I'll be available at 3 PM"

    // Cross-device sync
    public var syncSettingsAcrossDevices: Bool
    public var macAsPrimaryController: Bool
    public var useHandoff: Bool

    // === CALL FORWARDING WORKAROUND ===
    // iOS Focus Mode rejects calls at network level (3-tone disconnect)
    // Solution: Forward to COMBOX instead of letting iOS reject
    public var useCallForwardingWorkaround: Bool
    public var callForwardingNumber: String // Usually "086" for Swisscom COMBOX
    public var forwardAllCallsOnFocus: Bool // Unconditional forwarding
    public var forwardOnlyBlockedCalls: Bool // Conditional forwarding (busy/no answer)
    public var callForwardingActivationCode: String // *21* for Swisscom
    public var callForwardingDeactivationCode: String // #21# for Swisscom

    // === VOIP CALL INTERCEPTION (Enhancement 1) ===
    public var voipInterceptionEnabled: Bool
    public var voipInterceptWhatsApp: Bool
    public var voipInterceptTelegram: Bool
    public var voipInterceptFaceTime: Bool
    public var voipPlayTTSBeforeRinging: Bool // Play TTS message before deciding to ring
    public var voipTTSMessage: [String: String] // Language -> message

    // === SMART CONTACT ESCALATION (Enhancement 2) ===
    public var smartEscalationEnabled: Bool
    public var escalationMessageThreshold: Int // Number of messages to trigger escalation
    public var escalationTimeWindow: TimeInterval // Within this time period
    public var autoEscalateToUrgent: Bool // Automatically mark as urgent
    public var escalationAutoReplyEnabled: Bool // Send auto-reply asking if truly urgent
    public var escalationNotifyUser: Bool // Only notify user after contact confirms urgency

    // === CALENDAR-AWARE AUTO-REPLIES (Enhancement 3) ===
    public var calendarAwareRepliesEnabled: Bool
    public var includeNextAvailableSlot: Bool
    public var respectCalendarBusyStatus: Bool
    public var autoFocusOnCalendarEvents: Bool // Auto-enable Focus during meetings

    // === LOCATION-BASED BEHAVIOR (Enhancement 4) ===
    public var locationAwareBehaviorEnabled: Bool
    public var homeLocation: LocationCoordinate?
    public var workLocation: LocationCoordinate?
    public var customLocations: [NamedLocation]

    // === VOICE MESSAGE SUPPORT (Enhancement 5) ===
    public var voiceMessageAnalysisEnabled: Bool
    public var transcribeVoiceMessages: Bool
    public var analyzeVoiceUrgency: Bool // Analyze tone for urgency
    public var autoReplyToVoiceMessages: Bool

    // === GROUP CHAT HANDLING (Enhancement 6) ===
    public var groupChatHandlingEnabled: Bool
    public var silenceGroupChats: Bool
    public var onlyRespondToDirectMentions: Bool
    public var groupChatAutoReplyEnabled: Bool
    public var groupChatMaxReplies: Int

    // === VIP MODE (Enhancement 7) ===
    public var vipModeEnabled: Bool
    public var vipContacts: [String] // Contact IDs with VIP status
    public var vipCustomMessages: [String: String] // Contact ID -> custom message
    public var vipAlwaysRingThrough: Bool

    // === LEARNING FROM OUTCOMES (Enhancement 8) ===
    public var learningEnabled: Bool
    public var trackResponsePatterns: Bool
    public var adjustPriorityFromFeedback: Bool
    public var learnOptimalReplyTiming: Bool
    public var learnUrgencyIndicators: Bool

    public init() {
        self.systemEnabled = true
        self.autoReplyEnabled = true
        self.autoReplyDelay = 30
        self.maxAutoRepliesPerContact = 2
        self.autoReplyWindow = 3600
        self.askIfUrgent = true
        self.autoReplyPlatforms = [.imessage, .sms, .whatsapp, .telegram]

        self.whatsAppStatusSyncEnabled = true
        self.whatsAppAutoReplyEnabled = true
        self.preservePreviousWhatsAppStatus = true

        self.telegramStatusSyncEnabled = false
        self.telegramAutoReplyEnabled = false

        self.callerNotificationEnabled = true
        self.callerNotificationPlatforms = [.phone, .facetime, .whatsapp]
        self.sendSMSAfterMissedCall = true
        self.smsDelayAfterMissedCall = 10

        self.autoCallbackEnabled = false
        self.callbackDelay = 5

        self.emergencyContactsEnabled = true
        self.emergencyContacts = []
        self.emergencyKeywordDetection = true
        self.autoDialEmergencyServices = false

        self.comboxIntegrationEnabled = true
        self.comboxSwitchGreetingOnFocus = true
        self.comboxDefaultGreeting = "standard"
        self.comboxFocusGreeting = "focus_mode"

        self.learnContactLanguages = true
        self.learnContactPriorities = true
        self.suggestFocusModeActivation = true
        self.predictUrgentContacts = true

        self.timeAwareResponses = true
        self.businessHoursStart = DateComponents(hour: 9, minute: 0)
        self.businessHoursEnd = DateComponents(hour: 18, minute: 0)
        self.includeAvailabilityInReply = true

        self.syncSettingsAcrossDevices = true
        self.macAsPrimaryController = true
        self.useHandoff = true

        // Call forwarding workaround (CRITICAL for iOS Focus Mode)
        self.useCallForwardingWorkaround = true
        self.callForwardingNumber = "086" // Swisscom COMBOX
        self.forwardAllCallsOnFocus = true
        self.forwardOnlyBlockedCalls = false
        self.callForwardingActivationCode = "*21*" // Swisscom unconditional forwarding
        self.callForwardingDeactivationCode = "#21#" // Swisscom disable forwarding

        // VoIP interception
        self.voipInterceptionEnabled = true
        self.voipInterceptWhatsApp = true
        self.voipInterceptTelegram = true
        self.voipInterceptFaceTime = true
        self.voipPlayTTSBeforeRinging = true
        self.voipTTSMessage = [
            "en": "This person has Focus Mode enabled. If urgent, stay on the line.",
            "de": "Diese Person hat den Fokus-Modus aktiviert. Bei Dringlichkeit bleiben Sie dran.",
            "fr": "Cette personne est en mode Concentration. Si urgent, restez en ligne.",
            "it": "Questa persona ha la modalità Focus attiva. Se urgente, rimanga in linea."
        ]

        // Smart escalation (fully configurable)
        self.smartEscalationEnabled = true
        self.escalationMessageThreshold = 3 // Number of messages to trigger
        self.escalationTimeWindow = 300 // Time window in seconds (5 minutes)
        self.autoEscalateToUrgent = true
        self.escalationAutoReplyEnabled = true // Auto-reply asking if urgent
        self.escalationNotifyUser = false // Only notify user after confirmation

        // Calendar-aware
        self.calendarAwareRepliesEnabled = true
        self.includeNextAvailableSlot = true
        self.respectCalendarBusyStatus = true
        self.autoFocusOnCalendarEvents = false

        // Location-based
        self.locationAwareBehaviorEnabled = true
        self.homeLocation = nil
        self.workLocation = nil
        self.customLocations = []

        // Voice messages
        self.voiceMessageAnalysisEnabled = true
        self.transcribeVoiceMessages = true
        self.analyzeVoiceUrgency = true
        self.autoReplyToVoiceMessages = true

        // Group chats
        self.groupChatHandlingEnabled = true
        self.silenceGroupChats = true
        self.onlyRespondToDirectMentions = true
        self.groupChatAutoReplyEnabled = false
        self.groupChatMaxReplies = 1

        // VIP mode
        self.vipModeEnabled = true
        self.vipContacts = []
        self.vipCustomMessages = [:]
        self.vipAlwaysRingThrough = true

        // Learning
        self.learningEnabled = true
        self.trackResponsePatterns = true
        self.adjustPriorityFromFeedback = true
        self.learnOptimalReplyTiming = true
        self.learnUrgencyIndicators = true
    }
}

// MARK: - Location Structures for Enhancement 4

public struct LocationCoordinate: Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct NamedLocation: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let coordinate: LocationCoordinate
    public let radius: Double // meters
    public var focusBehavior: LocationFocusBehavior

    public init(id: UUID = UUID(), name: String, coordinate: LocationCoordinate, radius: Double, focusBehavior: LocationFocusBehavior) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.radius = radius
        self.focusBehavior = focusBehavior
    }
}

public struct LocationFocusBehavior: Codable, Sendable {
    public var autoEnableFocus: Bool
    public var focusModeToEnable: String?
    public var customAutoReply: String?
    public var silenceAllNotifications: Bool

    public init(autoEnableFocus: Bool = false, focusModeToEnable: String? = nil, customAutoReply: String? = nil, silenceAllNotifications: Bool = false) {
        self.autoEnableFocus = autoEnableFocus
        self.focusModeToEnable = focusModeToEnable
        self.customAutoReply = customAutoReply
        self.silenceAllNotifications = silenceAllNotifications
    }
}
