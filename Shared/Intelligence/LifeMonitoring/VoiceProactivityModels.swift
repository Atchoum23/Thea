// VoiceProactivityModels.swift
// THEA - Voice Proactivity Model Types
// Created by Claude - February 2026
//
// Core types for contextual voice interactions: context detection,
// interaction lifecycle, messaging relay, and device relay commands.

import Foundation

// MARK: - Voice Context

/// Context that determines when voice interaction is appropriate.
///
/// The context drives volume, interruption policy, and which priorities
/// are allowed to speak. It is typically set automatically via activity
/// recognition, CarPlay detection, or calendar events.
public enum VoiceContext: String, Sendable, CaseIterable {
    case driving             // In vehicle, hands busy
    case walking             // Walking, can listen
    case exercising          // Working out
    case working             // At work, be quiet
    case sleeping            // Do not disturb
    case meeting             // In a meeting
    case home                // At home, normal volume
    case transit             // Public transit
    case unknown             // Default

    /// Whether voice output is appropriate in this context.
    public var isVoiceSafe: Bool {
        switch self {
        case .driving, .walking, .exercising, .home:
            return true
        case .working, .sleeping, .meeting, .transit, .unknown:
            return false
        }
    }

    /// Recommended speech volume (0.0–1.0) for this context.
    public var preferredVolume: Float {
        switch self {
        case .driving: return 0.9
        case .walking, .exercising: return 0.7
        case .home: return 0.5
        default: return 0.3
        }
    }

    /// The interruption policy governing which priorities may interrupt in this context.
    public var interruptionPolicy: InterruptionPolicy {
        switch self {
        case .driving: return .urgentOnly
        case .working, .meeting: return .emergencyOnly
        case .sleeping: return .never
        default: return .normal
        }
    }

    /// Policy controlling which interaction priorities are allowed to interrupt the user.
    public enum InterruptionPolicy: String, Sendable {
        case never           // Never interrupt
        case emergencyOnly   // Only emergencies
        case urgentOnly      // Urgent and above
        case normal          // Normal threshold
        case always          // Any notification
    }
}

// MARK: - Voice Interaction Types

/// The type of voice interaction to deliver.
public enum VoiceInteractionType: String, Sendable {
    case notification         // One-way notification
    case question             // Expecting yes/no response
    case request              // Expecting action/data
    case conversation         // Multi-turn
    case alert                // Urgent alert
    case reminder             // Scheduled reminder
}

/// Priority of a voice interaction, from low to emergency.
///
/// Higher priorities are allowed in more contexts. For example,
/// `.emergency` can interrupt even during sleep, while `.low`
/// is only delivered when at home.
public enum VoiceInteractionPriority: Int, Sendable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case urgent = 4
    case emergency = 5

    public static func < (lhs: VoiceInteractionPriority, rhs: VoiceInteractionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The set of ``VoiceContext`` values in which this priority is allowed.
    public var allowedInContext: [VoiceContext] {
        switch self {
        case .emergency: return VoiceContext.allCases
        case .urgent: return [.driving, .walking, .exercising, .home, .transit]
        case .high: return [.driving, .walking, .home]
        case .normal: return [.walking, .home]
        case .low: return [.home]
        }
    }
}

// MARK: - Voice Interaction

/// A voice interaction to deliver to the user.
///
/// Interactions are queued by priority, filtered by context, and delivered
/// via speech synthesis. They optionally expect a spoken response.
public struct VoiceInteraction: Identifiable, Sendable {
    public let id: UUID
    public let type: VoiceInteractionType
    public let priority: VoiceInteractionPriority
    public let message: String
    public let ssml: String? // SSML for more natural speech
    public let expectedResponses: [ExpectedResponse]?
    public let followUpId: UUID? // Reference to follow-up interaction
    public let context: [String: String]
    public let createdAt: Date
    public var deliveredAt: Date?
    public var response: VoiceResponse?
    public let expiresAt: Date?

    /// A possible user response with keywords to match and an action to take.
    public struct ExpectedResponse: Sendable {
        /// Keywords that, if spoken, match this response.
        public let keywords: [String]
        /// The action identifier to execute when matched.
        public let action: String
        /// Optional ID of the next interaction in a conversation flow.
        public let nextInteractionId: UUID?

        /// Creates an expected response.
        /// - Parameters:
        ///   - keywords: Spoken keywords to match against.
        ///   - action: Action identifier for this response.
        ///   - nextInteractionId: Optional follow-up interaction ID.
        public init(keywords: [String], action: String, nextInteractionId: UUID? = nil) {
            self.keywords = keywords
            self.action = action
            self.nextInteractionId = nextInteractionId
        }
    }

    /// Creates a new voice interaction.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - type: The type of interaction.
    ///   - priority: Delivery priority (defaults to `.normal`).
    ///   - message: The text to speak.
    ///   - ssml: Optional SSML markup for richer speech.
    ///   - expectedResponses: Responses to listen for after speaking.
    ///   - followUpId: ID of a follow-up interaction.
    ///   - context: Arbitrary key-value metadata.
    ///   - expiresIn: Time interval after which this interaction expires.
    public init(
        id: UUID = UUID(),
        type: VoiceInteractionType,
        priority: VoiceInteractionPriority = .normal,
        message: String,
        ssml: String? = nil,
        expectedResponses: [ExpectedResponse]? = nil,
        followUpId: UUID? = nil,
        context: [String: String] = [:],
        expiresIn: TimeInterval? = nil
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.message = message
        self.ssml = ssml
        self.expectedResponses = expectedResponses
        self.followUpId = followUpId
        self.context = context
        self.createdAt = Date()
        self.deliveredAt = nil
        self.response = nil
        self.expiresAt = expiresIn.map { Date().addingTimeInterval($0) }
    }

    /// Whether the interaction has passed its expiration date.
    public var isExpired: Bool {
        if let expires = expiresAt {
            return Date() > expires
        }
        return false
    }
}

/// A user's spoken response to a voice interaction.
public struct VoiceResponse: Sendable {
    /// The speech-to-text transcription of the user's response.
    public let transcription: String
    /// Confidence score (0.0–1.0) for the transcription.
    public let confidence: Double
    /// The expected response that matched, if any.
    public let matchedExpectation: VoiceInteraction.ExpectedResponse?
    /// When the response was captured.
    public let timestamp: Date

    /// Creates a voice response.
    /// - Parameters:
    ///   - transcription: The transcribed text.
    ///   - confidence: Transcription confidence (0.0–1.0).
    ///   - matchedExpectation: The matched expected response, if any.
    public init(
        transcription: String,
        confidence: Double,
        matchedExpectation: VoiceInteraction.ExpectedResponse? = nil
    ) {
        self.transcription = transcription
        self.confidence = confidence
        self.matchedExpectation = matchedExpectation
        self.timestamp = Date()
    }
}

// MARK: - Messaging Relay

/// Platform for sending messages through voice commands (voice relay only — separate from TheaMessagingPlatform/gateway).
public enum VoiceRelayPlatform: String, Sendable, CaseIterable {
    case iMessage = "imessage"
    case whatsApp = "whatsapp"
    case telegram
    case signal
    case slack
    case sms

    /// Human-readable name for the platform.
    public var displayName: String {
        switch self {
        case .iMessage: return "iMessage"
        case .whatsApp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .signal: return "Signal"
        case .slack: return "Slack"
        case .sms: return "SMS"
        }
    }

    /// The URL scheme used to open this platform's app, if available.
    public var urlScheme: String? {
        switch self {
        case .iMessage: return "imessage://"
        case .whatsApp: return "whatsapp://"
        case .telegram: return "tg://"
        case .signal: return nil // Uses Shortcuts
        case .slack: return "slack://"
        case .sms: return "sms://"
        }
    }
}

/// A message to relay through a messaging platform.
public struct MessageRelay: Sendable {
    /// The target messaging platform.
    public let platform: VoiceRelayPlatform
    /// The recipient's identifier (phone number, username, etc.).
    public let recipient: String
    /// Optional display name for the recipient.
    public let recipientName: String?
    /// The message body.
    public let message: String
    /// Optional file paths of attachments.
    public let attachments: [String]?
    /// Optional ID of the message being replied to.
    public let replyToMessageId: String?

    /// Creates a message relay.
    /// - Parameters:
    ///   - platform: Target messaging platform.
    ///   - recipient: Recipient identifier.
    ///   - recipientName: Optional display name.
    ///   - message: Message body text.
    ///   - attachments: Optional file path attachments.
    ///   - replyToMessageId: Optional reply-to message ID.
    public init(
        platform: VoiceRelayPlatform,
        recipient: String,
        recipientName: String? = nil,
        message: String,
        attachments: [String]? = nil,
        replyToMessageId: String? = nil
    ) {
        self.platform = platform
        self.recipient = recipient
        self.recipientName = recipientName
        self.message = message
        self.attachments = attachments
        self.replyToMessageId = replyToMessageId
    }
}

// MARK: - Device Relay

/// Commands that can be relayed between devices (e.g., iPhone to Mac).
public enum DeviceRelayCommand: Sendable {
    case sendMessage(MessageRelay)
    case makeCall(to: String, platform: VoiceRelayPlatform)
    case readNotifications
    case playMedia(String)
    case pauseMedia
    case navigate(to: String)
    case searchWeb(query: String)
    case setReminder(title: String, dueDate: Date)
    case custom(action: String, parameters: [String: String])
}

/// Result of a device relay command.
public struct DeviceRelayResult: Sendable {
    /// Whether the relay succeeded.
    public let success: Bool
    /// The device that initiated the relay.
    public let sourceDevice: String
    /// The device that received the relay.
    public let targetDevice: String
    /// Description of the relayed command.
    public let command: String
    /// Optional status message.
    public let message: String?
    /// When the relay completed.
    public let timestamp: Date

    /// Creates a device relay result.
    /// - Parameters:
    ///   - success: Whether the command succeeded.
    ///   - sourceDevice: Originating device name.
    ///   - targetDevice: Target device name.
    ///   - command: Command description.
    ///   - message: Optional status message.
    public init(
        success: Bool,
        sourceDevice: String,
        targetDevice: String,
        command: String,
        message: String? = nil
    ) {
        self.success = success
        self.sourceDevice = sourceDevice
        self.targetDevice = targetDevice
        self.command = command
        self.message = message
        self.timestamp = Date()
    }
}
