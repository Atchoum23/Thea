// FocusModeModels.swift
// THEA - Focus Mode data models and enums
// Extracted from FocusModeIntelligence.swift

import Foundation

// MARK: - Focus Mode Configuration

/// Complete Focus Mode configuration with all settings
public struct FocusModeConfiguration: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public var isActive: Bool
    public let iconName: String?
    public let colorHex: String?

    // Contact settings
    public var allowedContacts: [String] // Contact identifiers
    public var allowedContactGroups: [String] // Group names
    public var silenceAllContacts: Bool
    public var allowCallsFrom: CallAllowance

    // App settings
    public var allowedApps: [String] // Bundle identifiers
    public var silenceAllApps: Bool

    // Repeated calls setting
    public var allowRepeatedCalls: Bool
    public var repeatedCallsWindow: TimeInterval // Default: 180 seconds

    // Status sharing
    public var shareStatusEnabled: Bool

    // Schedule
    public var schedules: [FocusSchedule]
    public var smartActivation: SmartActivation?

    // THEA-specific settings
    public var theaSettings: TheaFocusSettings

    public enum CallAllowance: String, Codable, Sendable {
        case everyone = "everyone"
        case allowedPeopleOnly = "allowed_only"
        case favorites = "favorites"
        case contactsOnly = "contacts_only"
        case noOne = "no_one"
    }

    public struct FocusSchedule: Codable, Sendable {
        public let id: UUID
        public let enabled: Bool
        public let startTime: DateComponents
        public let endTime: DateComponents
        public let daysOfWeek: [Int] // 1 = Sunday, 7 = Saturday
        public let location: LocationTrigger?
        public let appTrigger: String? // Bundle ID
    }

    public struct LocationTrigger: Codable, Sendable {
        public let name: String
        public let latitude: Double
        public let longitude: Double
        public let radius: Double
        public let triggerOnArrival: Bool
        public let triggerOnDeparture: Bool
    }

    public struct SmartActivation: Codable, Sendable {
        public let enabled: Bool
        public let learnFromUsage: Bool
        public let suggestActivation: Bool
    }

    /// THEA-specific settings for this Focus mode
    public struct TheaFocusSettings: Codable, Sendable {
        public var autoReplyEnabled: Bool
        public var autoReplyMessage: [String: String] // Language code -> message
        public var whatsAppStatusEnabled: Bool
        public var whatsAppStatusMessage: String
        public var telegramStatusEnabled: Bool
        public var telegramStatusMessage: String
        public var callerNotificationEnabled: Bool
        public var urgentCallbackEnabled: Bool
        public var comboxGreetingType: String?
        public var emergencyContactsAlwaysRing: [String] // Always allowed
        public var customCallbackInstructions: [String: String]

        public init(
            autoReplyEnabled: Bool = true,
            autoReplyMessage: [String: String] = [:],
            whatsAppStatusEnabled: Bool = true,
            whatsAppStatusMessage: String = "\u{1F515} Focus Mode",
            telegramStatusEnabled: Bool = false,
            telegramStatusMessage: String = "\u{1F515} Focus Mode",
            callerNotificationEnabled: Bool = true,
            urgentCallbackEnabled: Bool = true,
            comboxGreetingType: String? = nil,
            emergencyContactsAlwaysRing: [String] = [],
            customCallbackInstructions: [String: String] = [:]
        ) {
            self.autoReplyEnabled = autoReplyEnabled
            self.autoReplyMessage = autoReplyMessage
            self.whatsAppStatusEnabled = whatsAppStatusEnabled
            self.whatsAppStatusMessage = whatsAppStatusMessage
            self.telegramStatusEnabled = telegramStatusEnabled
            self.telegramStatusMessage = telegramStatusMessage
            self.callerNotificationEnabled = callerNotificationEnabled
            self.urgentCallbackEnabled = urgentCallbackEnabled
            self.comboxGreetingType = comboxGreetingType
            self.emergencyContactsAlwaysRing = emergencyContactsAlwaysRing
            self.customCallbackInstructions = customCallbackInstructions
        }
    }

    public init(
        id: String,
        name: String,
        isActive: Bool = false,
        iconName: String? = nil,
        colorHex: String? = nil,
        allowedContacts: [String] = [],
        allowedContactGroups: [String] = [],
        silenceAllContacts: Bool = false,
        allowCallsFrom: CallAllowance = .allowedPeopleOnly,
        allowedApps: [String] = [],
        silenceAllApps: Bool = false,
        allowRepeatedCalls: Bool = true,
        repeatedCallsWindow: TimeInterval = 180,
        shareStatusEnabled: Bool = true,
        schedules: [FocusSchedule] = [],
        smartActivation: SmartActivation? = nil,
        theaSettings: TheaFocusSettings = TheaFocusSettings()
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.iconName = iconName
        self.colorHex = colorHex
        self.allowedContacts = allowedContacts
        self.allowedContactGroups = allowedContactGroups
        self.silenceAllContacts = silenceAllContacts
        self.allowCallsFrom = allowCallsFrom
        self.allowedApps = allowedApps
        self.silenceAllApps = silenceAllApps
        self.allowRepeatedCalls = allowRepeatedCalls
        self.repeatedCallsWindow = repeatedCallsWindow
        self.shareStatusEnabled = shareStatusEnabled
        self.schedules = schedules
        self.smartActivation = smartActivation
        self.theaSettings = theaSettings
    }
}

// MARK: - Communication Platform

/// All supported communication platforms
public enum CommunicationPlatform: String, Codable, Sendable, CaseIterable {
    // Voice calls
    case phone = "phone"
    case facetime = "facetime"
    case facetimeAudio = "facetime_audio"

    // Messaging - Apple
    case imessage = "imessage"
    case sms = "sms"

    // Messaging - Third party
    case whatsapp = "whatsapp"
    case telegram = "telegram"
    case signal = "signal"
    case threema = "threema"
    case messenger = "messenger"
    case instagram = "instagram"
    case snapchat = "snapchat"
    case viber = "viber"
    case line = "line"
    case wechat = "wechat"

    // Business/Work
    case slack = "slack"
    case teams = "teams"
    case discord = "discord"
    case zoom = "zoom"
    case webex = "webex"
    case googleMeet = "google_meet"

    // Email (for completeness)
    case email = "email"

    public var displayName: String {
        switch self {
        case .phone: return "Phone"
        case .facetime: return "FaceTime"
        case .facetimeAudio: return "FaceTime Audio"
        case .imessage: return "iMessage"
        case .sms: return "SMS"
        case .whatsapp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .signal: return "Signal"
        case .threema: return "Threema"
        case .messenger: return "Messenger"
        case .instagram: return "Instagram"
        case .snapchat: return "Snapchat"
        case .viber: return "Viber"
        case .line: return "LINE"
        case .wechat: return "WeChat"
        case .slack: return "Slack"
        case .teams: return "Teams"
        case .discord: return "Discord"
        case .zoom: return "Zoom"
        case .webex: return "Webex"
        case .googleMeet: return "Google Meet"
        case .email: return "Email"
        }
    }

    public var supportsAutoReply: Bool {
        switch self {
        case .imessage, .sms, .whatsapp, .telegram, .signal, .threema,
             .messenger, .instagram, .viber, .line, .slack, .teams, .email:
            return true
        default:
            return false
        }
    }

    public var supportsStatusUpdate: Bool {
        switch self {
        case .whatsapp, .telegram, .signal, .slack, .teams, .discord:
            return true
        default:
            return false
        }
    }

    public var supportsVoiceCalls: Bool {
        switch self {
        case .phone, .facetime, .facetimeAudio, .whatsapp, .telegram,
             .signal, .messenger, .viber, .line, .slack, .teams,
             .discord, .zoom, .webex, .googleMeet:
            return true
        default:
            return false
        }
    }

    public var bundleIdentifier: String? {
        switch self {
        case .phone: return "com.apple.mobilephone"
        case .facetime, .facetimeAudio: return "com.apple.facetime"
        case .imessage, .sms: return "com.apple.MobileSMS"
        case .whatsapp: return "net.whatsapp.WhatsApp"
        case .telegram: return "ph.telegra.Telegraph"
        case .signal: return "org.whispersystems.signal"
        case .threema: return "ch.threema.iapp"
        case .messenger: return "com.facebook.Messenger"
        case .instagram: return "com.burbn.instagram"
        case .snapchat: return "com.toyopagroup.picaboo"
        case .viber: return "com.viber"
        case .line: return "jp.naver.line"
        case .wechat: return "com.tencent.xin"
        case .slack: return "com.tinyspeck.chatlyio"
        case .teams: return "com.microsoft.teams"
        case .discord: return "com.hammerandchisel.discord"
        case .zoom: return "us.zoom.videomeetings"
        case .webex: return "com.cisco.webexmeetings"
        case .googleMeet: return "com.google.meet"
        case .email: return "com.apple.mobilemail"
        }
    }
}

// MARK: - Contact Language Info

/// Comprehensive language detection for contacts
public struct ContactLanguageInfo: Codable, Sendable {
    public let contactId: String
    public var detectedLanguage: String // ISO 639-1
    public var confidence: Double
    public var detectionMethod: DetectionMethod
    public var isManuallySet: Bool
    public var previousLanguages: [String] // For multilingual contacts
    public var lastUpdated: Date

    public enum DetectionMethod: String, Codable, Sendable {
        case phoneCountryCode = "phone_country"
        case addressCountry = "address_country"
        case messageHistory = "message_history"
        case contactNotes = "notes"
        case contactName = "name_analysis"
        case manualSetting = "manual"
        case deviceLocale = "device_locale"
        case aiDetection = "ai_detection"
    }
}
