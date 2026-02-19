// MessagingHub.swift
// Thea — Central cross-platform messaging router
//
// Routes messages from all channels (native + OpenClaw bridge) to AI
// for comprehension and automated response. Maintains per-channel
// conversation state in SwiftData.

import Foundation
import OSLog

private let msgLogger = Logger(subsystem: "ai.thea.app", category: "MessagingHub")

// MARK: - Unified Message Types

/// A platform-agnostic message that normalizes across all channels.
struct UnifiedMessage: Codable, Sendable, Identifiable {
    let id: UUID
    let channelType: MessagingChannelType
    let channelID: String
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let isFromUser: Bool
    let isFromBot: Bool
    let replyToMessageID: String?
    let attachments: [UnifiedAttachment]
    let metadata: [String: String]

    init(
        channelType: MessagingChannelType,
        channelID: String,
        // periphery:ignore - Reserved: msgLogger global var reserved for future feature activation
        senderID: String,
        senderName: String? = nil,
        content: String,
        timestamp: Date = Date(),
        isFromUser: Bool = false,
        isFromBot: Bool = false,
        replyToMessageID: String? = nil,
        attachments: [UnifiedAttachment] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.channelType = channelType
        self.channelID = channelID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isFromUser = isFromUser
        // periphery:ignore - Reserved: init(channelType:channelID:senderID:senderName:content:timestamp:isFromUser:isFromBot:replyToMessageID:attachments:metadata:) initializer reserved for future feature activation
        self.isFromBot = isFromBot
        self.replyToMessageID = replyToMessageID
        self.attachments = attachments
        self.metadata = metadata
    }
}

/// A platform-agnostic attachment.
struct UnifiedAttachment: Codable, Sendable, Identifiable {
    let id: UUID
    let type: AttachmentType
    let url: String?
    let mimeType: String?
    let fileName: String?
    let sizeBytes: Int?
    let localPath: String?

    enum AttachmentType: String, Codable, Sendable, CaseIterable {
        case image
        case audio
        case video
        case document
        case voiceNote
        case sticker
        case location
        case contact
    }

    init(
        type: AttachmentType,
        url: String? = nil,
        mimeType: String? = nil,
        fileName: String? = nil,
        sizeBytes: Int? = nil,
        localPath: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.url = url
        self.mimeType = mimeType
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.localPath = localPath
    }
}

/// Types of messaging channels.
enum MessagingChannelType: String, Codable, Sendable, CaseIterable {
    // periphery:ignore - Reserved: init(type:url:mimeType:fileName:sizeBytes:localPath:) initializer reserved for future feature activation
    case iMessage
    case whatsApp
    case telegram
    case discord
    case slack
    case signal
    case email
    case notification
    case phoneCall
    case physicalMail

    var displayName: String {
        switch self {
        case .iMessage: "iMessage"
        case .whatsApp: "WhatsApp"
        case .telegram: "Telegram"
        case .discord: "Discord"
        case .slack: "Slack"
        case .signal: "Signal"
        case .email: "Email"
        case .notification: "Notifications"
        case .phoneCall: "Phone Calls"
        case .physicalMail: "Physical Mail"
        }
    }

    var icon: String {
        switch self {
        case .iMessage: "message.fill"
        case .whatsApp: "phone.circle.fill"
        case .telegram: "paperplane.fill"
        case .discord: "headphones"
        case .slack: "number.square.fill"
        case .signal: "lock.fill"
        case .email: "envelope.fill"
        case .notification: "bell.fill"
        case .phoneCall: "phone.fill"
        case .physicalMail: "doc.text.fill"
        }
    }

    /// Whether this channel uses OpenClaw bridge (vs native integration).
    var usesBridge: Bool {
        switch self {
        case .whatsApp, .telegram, .discord, .slack, .signal:
            return true
        case .iMessage, .email, .notification, .phoneCall, .physicalMail:
            return false
        }
    }
}

/// Status of a messaging channel.
enum MessagingChannelStatus: String, Codable, Sendable {
    case connected
    case disconnected
    case connecting
    case error
    case disabled

    var isActive: Bool {
        self == .connected
    }
}

/// A registered messaging channel.
struct RegisteredChannel: Codable, Sendable, Identifiable {
    let id: UUID
    let type: MessagingChannelType
    let name: String
    var status: MessagingChannelStatus
    var lastActivityAt: Date?
    var unreadCount: Int
    var isEnabled: Bool
    var autoReplyEnabled: Bool

    init(
        type: MessagingChannelType,
        name: String,
        status: MessagingChannelStatus = .disconnected,
        isEnabled: Bool = true,
        autoReplyEnabled: Bool = false
    ) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.status = status
        self.lastActivityAt = nil
        self.unreadCount = 0
        self.isEnabled = isEnabled
        self.autoReplyEnabled = autoReplyEnabled
    }
}

// MARK: - Message Comprehension Types

// periphery:ignore - Reserved: init(type:name:status:isEnabled:autoReplyEnabled:) initializer reserved for future feature activation

/// AI-extracted understanding of a message.
struct MsgComprehension: Codable, Sendable {
    let intent: MsgIntent
    let urgency: MsgUrgency
    let requiredAction: MsgAction?
    let entities: [MsgEntity]
    let sentiment: MsgSentiment
    let summary: String?
    let suggestedResponse: String?

    init(
        intent: MsgIntent = .informational,
        urgency: MsgUrgency = .normal,
        requiredAction: MsgAction? = nil,
        entities: [MsgEntity] = [],
        sentiment: MsgSentiment = .neutral,
        summary: String? = nil,
        suggestedResponse: String? = nil
    ) {
        // periphery:ignore - Reserved: MsgComprehension type reserved for future feature activation
        self.intent = intent
        self.urgency = urgency
        self.requiredAction = requiredAction
        self.entities = entities
        self.sentiment = sentiment
        self.summary = summary
        self.suggestedResponse = suggestedResponse
    }
}

/// The intent of a message.
enum MsgIntent: String, Codable, Sendable, CaseIterable {
    case question
    case request
    case informational
    case socialGreeting
    case confirmation
    case scheduling
    case urgent
    case complaint
    case followUp

    var requiresResponse: Bool {
        switch self {
        case .question, .request, .scheduling, .urgent, .complaint:
            return true
        case .informational, .socialGreeting, .confirmation, .followUp:
            return false
        }
    }
}

/// Urgency level of a message.
enum MsgUrgency: String, Codable, Sendable, CaseIterable, Comparable {
    case low
    case normal
    case high
    case critical

    var numericValue: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .high: 2
        case .critical: 3
        }
    }

    static func < (lhs: MsgUrgency, rhs: MsgUrgency) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

/// An action the user should take.
enum MsgAction: String, Codable, Sendable, CaseIterable {
    case reply
    case createCalendarEvent
    case setReminder
    case makePayment
    case openLink
    case callBack
    case forward
    case archive
    case trackPackage
    case reviewDocument

    var displayName: String {
        switch self {
        case .reply: "Reply"
        case .createCalendarEvent: "Create Event"
        case .setReminder: "Set Reminder"
        case .makePayment: "Make Payment"
        case .openLink: "Open Link"
        case .callBack: "Call Back"
        case .forward: "Forward"
        case .archive: "Archive"
        case .trackPackage: "Track Package"
        case .reviewDocument: "Review Document"
        }
    }
}

/// An entity extracted from message content.
struct MsgEntity: Codable, Sendable, Identifiable {
    let id: UUID
    let type: EntityType
    let value: String
    let confidence: Double

    enum EntityType: String, Codable, Sendable, CaseIterable {
        case person
        case organization
        case date
        case time
        case location
        case phoneNumber
        case email
        case url
        case amount
        case trackingNumber
    }

    init(type: EntityType, value: String, confidence: Double = 1.0) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.confidence = min(max(confidence, 0), 1)
    }
}

/// Sentiment of a message.
enum MsgSentiment: String, Codable, Sendable, CaseIterable {
    case positive
    case neutral
    case negative
    case mixed
}

// MARK: - Messaging Hub

// periphery:ignore - Reserved: init(type:value:confidence:) initializer reserved for future feature activation

/// Central message router for all messaging channels.
@MainActor
final class MessagingHub: ObservableObject {
    static let shared = MessagingHub()

    // MARK: - Published State

    @Published private(set) var channels: [RegisteredChannel] = []
    @Published private(set) var recentMessages: [UnifiedMessage] = []
    @Published private(set) var unreadTotal: Int = 0
    @Published private(set) var isProcessing = false

    // MARK: - Configuration

    var maxRecentMessages = 500
    var autoReplyGlobalEnabled = false
    var comprehensionEnabled = true

    // MARK: - Private

    private let storageURL: URL
    private var messageHandlers: [(UnifiedMessage) -> Void] = []

    // MARK: - Init

    private init() {
        // periphery:ignore - Reserved: isProcessing property reserved for future feature activation
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        // periphery:ignore - Reserved: maxRecentMessages property reserved for future feature activation
        // periphery:ignore - Reserved: autoReplyGlobalEnabled property reserved for future feature activation
        // periphery:ignore - Reserved: comprehensionEnabled property reserved for future feature activation
        ).first ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/Messaging", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // periphery:ignore - Reserved: messageHandlers property reserved for future feature activation
        } catch {
            ErrorLogger.log(error, context: "MessagingHub.init.createDirectory")
        }
        self.storageURL = dir.appendingPathComponent("messaging_state.json")
        loadState()
    }

    // MARK: - Channel Registration

    func registerChannel(_ channel: RegisteredChannel) {
        if let index = channels.firstIndex(where: { $0.type == channel.type && $0.name == channel.name }) {
            channels[index] = channel
        } else {
            channels.append(channel)
        }
        saveState()
        msgLogger.info("Registered channel: \(channel.type.displayName) (\(channel.name))")
    }

    func unregisterChannel(type: MessagingChannelType, name: String) {
        // periphery:ignore - Reserved: registerChannel(_:) instance method reserved for future feature activation
        channels.removeAll { $0.type == type && $0.name == name }
        saveState()
    }

    func updateChannelStatus(_ type: MessagingChannelType, name: String, status: MessagingChannelStatus) {
        if let index = channels.firstIndex(where: { $0.type == type && $0.name == name }) {
            channels[index].status = status
        }
    }

// periphery:ignore - Reserved: unregisterChannel(type:name:) instance method reserved for future feature activation

    func enableChannel(_ type: MessagingChannelType, name: String, enabled: Bool) {
        if let index = channels.firstIndex(where: { $0.type == type && $0.name == name }) {
            channels[index].isEnabled = enabled
            // periphery:ignore - Reserved: updateChannelStatus(_:name:status:) instance method reserved for future feature activation
            saveState()
        }
    }

    func setAutoReply(_ type: MessagingChannelType, name: String, enabled: Bool) {
        if let index = channels.firstIndex(where: { $0.type == type && $0.name == name }) {
            channels[index].autoReplyEnabled = enabled
            saveState()
        }
    }

    // MARK: - Message Routing

    /// Route an incoming message from any channel.
    func routeIncomingMessage(_ message: UnifiedMessage) async {
        isProcessing = true
        defer { isProcessing = false }

        // Update channel activity
        if let index = channels.firstIndex(where: { $0.type == message.channelType }) {
            channels[index].lastActivityAt = message.timestamp
            if !message.isFromUser && !message.isFromBot {
                // periphery:ignore - Reserved: routeIncomingMessage(_:) instance method reserved for future feature activation
                channels[index].unreadCount += 1
            }
        }

        // Add to recent messages
        recentMessages.append(message)
        if recentMessages.count > maxRecentMessages {
            recentMessages = Array(recentMessages.suffix(maxRecentMessages))
        }

        // Update unread total
        unreadTotal = channels.reduce(0) { $0 + $1.unreadCount }

        // Comprehend message if enabled
        if comprehensionEnabled {
            let comprehension = MsgComprehensionEngine.analyze(message)

            // Log comprehension
            msgLogger.info("Message from \(message.channelType.displayName): intent=\(comprehension.intent.rawValue), urgency=\(comprehension.urgency.rawValue)")

            // Check if auto-reply is appropriate
            if shouldAutoReply(for: message, comprehension: comprehension) {
                if let response = comprehension.suggestedResponse {
                    msgLogger.info("Auto-reply queued for \(message.channelType.displayName): \(response.prefix(50))")
                }
            }
        }

        // Notify handlers
        for handler in messageHandlers {
            handler(message)
        }

        saveState()
    }

    /// Mark messages as read for a channel.
    func markAsRead(channelType: MessagingChannelType, channelName: String? = nil) {
        for index in channels.indices {
            if channels[index].type == channelType {
                if let name = channelName, channels[index].name != name { continue }
                channels[index].unreadCount = 0
            }
        }
        unreadTotal = channels.reduce(0) { $0 + $1.unreadCount }
        saveState()
    }

    /// Register a handler for incoming messages.
    func onMessage(_ handler: @escaping (UnifiedMessage) -> Void) {
        messageHandlers.append(handler)
    }

    // MARK: - Query

    func messages(for channelType: MessagingChannelType, limit: Int = 50) -> [UnifiedMessage] {
        // periphery:ignore - Reserved: onMessage(_:) instance method reserved for future feature activation
        let filtered = recentMessages.filter { $0.channelType == channelType }
        return Array(filtered.suffix(limit))
    }

    func messages(from senderID: String, limit: Int = 50) -> [UnifiedMessage] {
        let filtered = recentMessages.filter { $0.senderID == senderID }
        return Array(filtered.suffix(limit))
    }

    func searchMessages(query: String, limit: Int = 50) -> [UnifiedMessage] {
        // periphery:ignore - Reserved: messages(from:limit:) instance method reserved for future feature activation
        let lowered = query.lowercased()
        let filtered = recentMessages.filter {
            $0.content.lowercased().contains(lowered) ||
            ($0.senderName?.lowercased().contains(lowered) ?? false)
        // periphery:ignore - Reserved: searchMessages(query:limit:) instance method reserved for future feature activation
        }
        return Array(filtered.suffix(limit))
    }

    var activeChannels: [RegisteredChannel] {
        channels.filter { $0.isEnabled && $0.status.isActive }
    }

    var channelsByType: [MessagingChannelType: [RegisteredChannel]] {
        Dictionary(grouping: channels, by: \.type)
    }

    // periphery:ignore - Reserved: channelsByType property reserved for future feature activation
    // MARK: - OpenClaw Bridge Integration

    /// Convert an OpenClaw message to a UnifiedMessage.
    func fromOpenClaw(
        platform: String,
        channelID: String,
        // periphery:ignore - Reserved: fromOpenClaw(platform:channelID:senderID:senderName:content:isFromBot:attachments:) instance method reserved for future feature activation
        senderID: String,
        senderName: String?,
        content: String,
        isFromBot: Bool,
        attachments: [(type: String, url: String?, mimeType: String?, fileName: String?)] = []
    ) -> UnifiedMessage {
        let channelType = mapOpenClawPlatform(platform)
        let unifiedAttachments = attachments.map { att in
            UnifiedAttachment(
                type: mapAttachmentType(att.type),
                url: att.url,
                mimeType: att.mimeType,
                fileName: att.fileName
            )
        }
        return UnifiedMessage(
            channelType: channelType,
            channelID: channelID,
            senderID: senderID,
            senderName: senderName,
            content: content,
            isFromBot: isFromBot,
            attachments: unifiedAttachments
        )
    }

    private func mapOpenClawPlatform(_ platform: String) -> MessagingChannelType {
        switch platform.lowercased() {
        // periphery:ignore - Reserved: mapOpenClawPlatform(_:) instance method reserved for future feature activation
        case "whatsapp": return .whatsApp
        case "telegram": return .telegram
        case "discord": return .discord
        case "slack": return .slack
        case "signal": return .signal
        case "imessage": return .iMessage
        default: return .notification
        }
    }

    private func mapAttachmentType(_ type: String) -> UnifiedAttachment.AttachmentType {
        // periphery:ignore - Reserved: mapAttachmentType(_:) instance method reserved for future feature activation
        switch type.lowercased() {
        case "image": return .image
        case "audio": return .audio
        case "video": return .video
        case "document": return .document
        case "sticker": return .sticker
        default: return .document
        }
    }

    // MARK: - Auto-Reply Logic

    // periphery:ignore - Reserved: shouldAutoReply(for:comprehension:) instance method reserved for future feature activation
    private func shouldAutoReply(for message: UnifiedMessage, comprehension: MsgComprehension) -> Bool {
        guard autoReplyGlobalEnabled else { return false }
        guard !message.isFromBot else { return false }

        // Check channel-level auto-reply
        guard let channel = channels.first(where: { $0.type == message.channelType }),
              channel.autoReplyEnabled else { return false }

        // Only auto-reply for messages that require a response
        return comprehension.intent.requiresResponse
    }

    // MARK: - Persistence

    private struct SaveableState: Codable {
        let channels: [RegisteredChannel]
        let recentMessageCount: Int
    }

    private func saveState() {
        let state = SaveableState(
            channels: channels,
            recentMessageCount: recentMessages.count
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            ErrorLogger.log(error, context: "MessagingHub.saveState")
        }
    }

    private func loadState() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        let data: Data
        do {
            data = try Data(contentsOf: storageURL)
        } catch {
            ErrorLogger.log(error, context: "MessagingHub.loadState.read")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let state = try decoder.decode(SaveableState.self, from: data)
            self.channels = state.channels
        } catch {
            ErrorLogger.log(error, context: "MessagingHub.loadState.decode")
        }
    }
}
