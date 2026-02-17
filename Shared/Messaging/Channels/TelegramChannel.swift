import Foundation
import OSLog

// MARK: - Telegram Channel

/// Full Telegram message access via OpenClaw Bridge (grammY adapter).
/// Supports: bot API for automated responses, full chat history,
/// media handling, channel monitoring, and offline export parsing.
@MainActor
final class TelegramChannel: ObservableObject {
    static let shared = TelegramChannel()

    private let logger = Logger(subsystem: "com.thea.app", category: "TelegramChannel")

    // MARK: - Published State

    @Published private(set) var isConnected = false
    @Published private(set) var botUsername: String?
    @Published private(set) var contacts: [TelegramContact] = []
    @Published private(set) var groups: [TelegramGroup] = []
    @Published private(set) var subscribedChannels: [TelegramSubscribedChannel] = []
    @Published private(set) var messageCount = 0
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var connectionError: String?

    // MARK: - Configuration

    var enabled = true
    var monitorSubscribedChannels = true
    var maxHistoryMessages = 500

    // MARK: - Storage

    private let storageDir: URL
    private var conversationCache: [String: [TelegramMessage]] = [:]
    private var processedMessageIDs: Set<String> = []

    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        storageDir = appSupport.appendingPathComponent("Thea/Telegram")
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        loadState()
    }

    // MARK: - Connection

    func connect() async {
        guard enabled else { return }
        logger.info("Connecting Telegram channel via OpenClaw Bridge")

        MessagingHub.shared.registerChannel(
            RegisteredChannel(type: .telegram, name: "Telegram")
        )
        MessagingHub.shared.updateChannelStatus(.telegram, name: "Telegram", status: .connecting)

        // Check OpenClaw Gateway availability
        let available = await OpenClawIntegration.shared.checkAvailability()
        guard available else {
            connectionError = "OpenClaw Gateway not available"
            MessagingHub.shared.updateChannelStatus(.telegram, name: "Telegram", status: .error)
            logger.warning("OpenClaw Gateway not available for Telegram")
            return
        }

        if !OpenClawIntegration.shared.isEnabled {
            OpenClawIntegration.shared.enable()
        }

        // Register for Telegram messages via OpenClaw event stream
        let existingHandler = OpenClawIntegration.shared.onMessageReceived
        OpenClawIntegration.shared.onMessageReceived = { [weak self] message in
            // Chain handlers — don't overwrite WhatsApp handler
            await existingHandler?(message)
            await self?.handleOpenClawMessage(message)
        }

        isConnected = true
        connectionError = nil
        MessagingHub.shared.updateChannelStatus(.telegram, name: "Telegram", status: .connected)

        updateChannelsFromOpenClaw()
        logger.info("Telegram channel connected")
    }

    func disconnect() {
        isConnected = false
        MessagingHub.shared.updateChannelStatus(.telegram, name: "Telegram", status: .disconnected)
        saveState()
        logger.info("Telegram channel disconnected")
    }

    // MARK: - Message Handling

    private func handleOpenClawMessage(_ message: OpenClawMessage) async {
        guard message.platform == .telegram else { return }
        guard !processedMessageIDs.contains(message.id) else { return }
        processedMessageIDs.insert(message.id)

        let tgMessage = TelegramMessage(
            id: message.id,
            chatID: message.channelID,
            senderID: message.senderID,
            senderName: message.senderName,
            content: message.content,
            timestamp: message.timestamp,
            isFromBot: message.isFromBot,
            attachments: message.attachments.map { att in
                TelegramAttachment(
                    type: mapAttachmentType(att.type),
                    url: att.url?.absoluteString,
                    mimeType: att.mimeType,
                    fileName: att.fileName,
                    sizeBytes: att.sizeBytes
                )
            },
            replyToID: message.replyToMessageID,
            chatType: detectChatType(message.channelID)
        )

        // Cache in conversation
        var messages = conversationCache[message.channelID] ?? []
        messages.append(tgMessage)
        if messages.count > maxHistoryMessages {
            messages = Array(messages.suffix(maxHistoryMessages))
        }
        conversationCache[message.channelID] = messages
        messageCount += 1

        // Route to MessagingHub
        let unified = MessagingHub.shared.fromOpenClaw(
            platform: "telegram",
            channelID: message.channelID,
            senderID: message.senderID,
            senderName: message.senderName,
            content: message.content,
            isFromBot: message.isFromBot,
            attachments: message.attachments.map { att in
                (
                    type: att.type.rawValue,
                    url: att.url?.absoluteString,
                    mimeType: att.mimeType,
                    fileName: att.fileName
                )
            }
        )
        await MessagingHub.shared.routeIncomingMessage(unified)

        updateContactFromMessage(tgMessage)
        saveState()
    }

    // MARK: - Send Messages

    func sendMessage(to chatID: String, text: String) async -> Bool {
        guard isConnected else {
            logger.warning("Cannot send: Telegram not connected")
            return false
        }
        do {
            try await OpenClawIntegration.shared.sendMessage(to: chatID, text: text)
            logger.info("Sent Telegram message to \(chatID)")
            return true
        } catch {
            logger.error("Failed to send Telegram message: \(error.localizedDescription)")
            return false
        }
    }

    func replyToMessage(chatID: String, messageID: String, text: String) async -> Bool {
        guard isConnected else { return false }
        do {
            let client = OpenClawClient()
            try await client.send(
                command: .sendReply(channelID: chatID, text: text, replyToID: messageID)
            )
            return true
        } catch {
            logger.error("Failed to reply: \(error.localizedDescription)")
            return false
        }
    }

    func markAsRead(chatID: String, messageID: String) async {
        guard isConnected else { return }
        do {
            let client = OpenClawClient()
            try await client.send(
                command: .markRead(channelID: chatID, messageID: messageID)
            )
        } catch {
            logger.error("Failed to mark read: \(error.localizedDescription)")
        }
    }

    // MARK: - History

    func loadHistory(chatID: String, limit: Int = 50) async -> [TelegramMessage] {
        if let cached = conversationCache[chatID], !cached.isEmpty {
            return Array(cached.suffix(limit))
        }

        guard isConnected else { return [] }
        do {
            let client = OpenClawClient()
            try await client.send(command: .getHistory(channelID: chatID, limit: limit))
            try? await Task.sleep(for: .milliseconds(500))
            return Array((conversationCache[chatID] ?? []).suffix(limit))
        } catch {
            logger.error("Failed to load Telegram history: \(error.localizedDescription)")
            return []
        }
    }

    func searchMessages(query: String) -> [TelegramMessage] {
        let lower = query.lowercased()
        return conversationCache.values.flatMap { $0 }
            .filter { $0.content.lowercased().contains(lower) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Export Parsing (Offline Fallback)

    /// Parse Telegram Desktop JSON export (result.json from "Export chat history").
    func importDesktopExport(from url: URL) -> [TelegramMessage] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return parseDesktopExport(data)
    }

    /// Parse Telegram Desktop JSON export data.
    func parseDesktopExport(_ data: Data) -> [TelegramMessage] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        return parseExportJSON(json)
    }

    /// Parse Telegram export JSON structure.
    func parseExportJSON(_ json: [String: Any]) -> [TelegramMessage] {
        var messages: [TelegramMessage] = []

        let chatName = json["name"] as? String ?? "Unknown"
        let chatID = "export_\(chatName.hashValue)"
        let chatType = chatTypeFromExport(json["type"] as? String)

        guard let messageList = json["messages"] as? [[String: Any]] else {
            return []
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        for msgDict in messageList {
            guard let idRaw = msgDict["id"],
                  let dateStr = msgDict["date"] as? String else { continue }

            // Skip service messages (member join/leave, etc.)
            if msgDict["type"] as? String == "service" { continue }

            let msgID = "\(idRaw)"
            let timestamp = dateFormatter.date(from: dateStr) ?? Date()
            let content = extractTextContent(from: msgDict)
            let senderName = msgDict["from"] as? String ?? "Unknown"
            let senderID = msgDict["from_id"] as? String ?? senderName
            let attachments = extractAttachments(from: msgDict)
            let replyToID = (msgDict["reply_to_message_id"]).map { "\($0)" }

            let message = TelegramMessage(
                id: msgID,
                chatID: chatID,
                senderID: senderID,
                senderName: senderName,
                content: content,
                timestamp: timestamp,
                isFromBot: false,
                attachments: attachments,
                replyToID: replyToID,
                chatType: chatType
            )
            messages.append(message)
        }

        if !messages.isEmpty {
            conversationCache[chatID] = messages
        }

        logger.info("Parsed \(messages.count) messages from Telegram export '\(chatName)'")
        return messages
    }

    // MARK: - Export Parsing Helpers

    private func chatTypeFromExport(_ typeStr: String?) -> TelegramChatType {
        switch typeStr {
        case "personal_chat": return .privateChat
        case "bot_chat": return .bot
        case "private_group", "public_group": return .group
        case "private_supergroup", "public_supergroup": return .supergroup
        case "private_channel", "public_channel": return .channel
        default: return .privateChat
        }
    }

    private func extractTextContent(from msgDict: [String: Any]) -> String {
        if let textArray = msgDict["text"] as? [Any] {
            return textArray.compactMap { item -> String? in
                if let str = item as? String { return str }
                if let dict = item as? [String: Any] { return dict["text"] as? String }
                return nil
            }.joined()
        } else if let text = msgDict["text"] as? String {
            return text
        }
        return ""
    }

    private func extractAttachments(from msgDict: [String: Any]) -> [TelegramAttachment] {
        var attachments: [TelegramAttachment] = []
        if let photo = msgDict["photo"] as? String {
            attachments.append(TelegramAttachment(type: .photo, fileName: photo))
        }
        if let file = msgDict["file"] as? String {
            let mimeType = msgDict["mime_type"] as? String
            let size = msgDict["file_size_bytes"] as? Int
            let attachType = classifyAttachment(mediaType: msgDict["media_type"] as? String, mimeType: mimeType)
            attachments.append(TelegramAttachment(type: attachType, mimeType: mimeType, fileName: file, sizeBytes: size))
        }
        return attachments
    }

    private func classifyAttachment(mediaType: String?, mimeType: String?) -> TelegramAttachmentType {
        switch mediaType {
        case "voice_message": return .voiceMessage
        case "video_message": return .videoNote
        case "sticker": return .sticker
        default: break
        }
        if mimeType?.hasPrefix("audio/") == true { return .audio }
        if mimeType?.hasPrefix("video/") == true { return .video }
        return .document
    }

    // MARK: - Contact & Group Management

    private func updateContactFromMessage(_ message: TelegramMessage) {
        switch message.chatType {
        case .group, .supergroup:
            if !groups.contains(where: { $0.id == message.chatID }) {
                groups.append(TelegramGroup(
                    id: message.chatID,
                    name: message.chatID,
                    memberCount: 0,
                    lastMessageAt: message.timestamp,
                    type: message.chatType
                ))
            }
        case .channel:
            if !subscribedChannels.contains(where: { $0.id == message.chatID }) {
                subscribedChannels.append(TelegramSubscribedChannel(
                    id: message.chatID,
                    name: message.chatID,
                    subscriberCount: 0,
                    lastPostAt: message.timestamp
                ))
            }
        case .privateChat, .bot:
            if let index = contacts.firstIndex(where: { $0.id == message.senderID }) {
                contacts[index].lastMessageAt = message.timestamp
            } else if let name = message.senderName {
                contacts.append(TelegramContact(
                    id: message.senderID,
                    name: name,
                    username: nil,
                    isBot: message.chatType == .bot,
                    lastMessageAt: message.timestamp
                ))
            }
        }
    }

    private func updateChannelsFromOpenClaw() {
        for channel in OpenClawIntegration.shared.channels where channel.platform == .telegram {
            if channel.isGroup {
                if !groups.contains(where: { $0.id == channel.id }) {
                    groups.append(TelegramGroup(
                        id: channel.id,
                        name: channel.name,
                        memberCount: channel.participantCount ?? 0,
                        lastMessageAt: channel.lastActivityAt,
                        type: .group
                    ))
                }
            }
        }
    }

    private func detectChatType(_ channelID: String) -> TelegramChatType {
        if groups.contains(where: { $0.id == channelID }) {
            return .group
        }
        if subscribedChannels.contains(where: { $0.id == channelID }) {
            return .channel
        }
        // Telegram group IDs are typically negative numbers
        if let numID = Int64(channelID), numID < 0 {
            return .group
        }
        return .privateChat
    }

    // MARK: - Helpers

    private func mapAttachmentType(_ type: OpenClawAttachment.AttachmentType) -> TelegramAttachmentType {
        switch type {
        case .image: return .photo
        case .audio: return .audio
        case .video: return .video
        case .document: return .document
        case .sticker: return .sticker
        }
    }

    // MARK: - Statistics

    var totalMessages: Int { conversationCache.values.reduce(0) { $0 + $1.count } }
    var totalContacts: Int { contacts.count }
    var totalGroups: Int { groups.count }
    var totalChannels: Int { subscribedChannels.count }
    var conversationCount: Int { conversationCache.count }

    // MARK: - Persistence

    private func saveState() {
        let state = TelegramState(
            contacts: contacts,
            groups: groups,
            subscribedChannels: subscribedChannels,
            messageCount: messageCount,
            lastSyncAt: lastSyncAt,
            botUsername: botUsername,
            processedIDs: Array(processedMessageIDs.prefix(5000))
        )
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageDir.appendingPathComponent("state.json"), options: .atomic)
        } catch {
            logger.error("Failed to save Telegram state: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        let url = storageDir.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(TelegramState.self, from: data) else { return }
        contacts = state.contacts
        groups = state.groups
        subscribedChannels = state.subscribedChannels
        messageCount = state.messageCount
        lastSyncAt = state.lastSyncAt
        botUsername = state.botUsername
        processedMessageIDs = Set(state.processedIDs)
    }
}

// MARK: - Models

struct TelegramMessage: Codable, Sendable, Identifiable {
    let id: String
    let chatID: String
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let isFromBot: Bool
    let attachments: [TelegramAttachment]
    var replyToID: String?
    var chatType: TelegramChatType

    init(
        id: String = UUID().uuidString,
        chatID: String,
        senderID: String,
        senderName: String? = nil,
        content: String,
        timestamp: Date = Date(),
        isFromBot: Bool = false,
        attachments: [TelegramAttachment] = [],
        replyToID: String? = nil,
        chatType: TelegramChatType = .privateChat
    ) {
        self.id = id
        self.chatID = chatID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isFromBot = isFromBot
        self.attachments = attachments
        self.replyToID = replyToID
        self.chatType = chatType
    }
}

enum TelegramChatType: String, Codable, Sendable, CaseIterable {
    case privateChat
    case group
    case supergroup
    case channel
    case bot

    var displayName: String {
        switch self {
        case .privateChat: "Private Chat"
        case .group: "Group"
        case .supergroup: "Supergroup"
        case .channel: "Channel"
        case .bot: "Bot"
        }
    }

    var icon: String {
        switch self {
        case .privateChat: "person.fill"
        case .group: "person.3.fill"
        case .supergroup: "person.3.fill"
        case .channel: "megaphone.fill"
        case .bot: "cpu"
        }
    }
}

struct TelegramContact: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var username: String?
    var isBot: Bool
    var lastMessageAt: Date?

    init(
        id: String,
        name: String,
        username: String? = nil,
        isBot: Bool = false,
        lastMessageAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.isBot = isBot
        self.lastMessageAt = lastMessageAt
    }
}

struct TelegramGroup: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var memberCount: Int
    var lastMessageAt: Date?
    var type: TelegramChatType
    var isMuted: Bool

    init(
        id: String,
        name: String,
        memberCount: Int = 0,
        lastMessageAt: Date? = nil,
        type: TelegramChatType = .group,
        isMuted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.lastMessageAt = lastMessageAt
        self.type = type
        self.isMuted = isMuted
    }
}

struct TelegramSubscribedChannel: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var subscriberCount: Int
    var lastPostAt: Date?
    var isMonitored: Bool

    init(
        id: String,
        name: String,
        subscriberCount: Int = 0,
        lastPostAt: Date? = nil,
        isMonitored: Bool = true
    ) {
        self.id = id
        self.name = name
        self.subscriberCount = subscriberCount
        self.lastPostAt = lastPostAt
        self.isMonitored = isMonitored
    }
}

enum TelegramAttachmentType: String, Codable, Sendable, CaseIterable {
    case photo
    case video
    case audio
    case voiceMessage
    case videoNote
    case document
    case sticker
    case animation
    case contact
    case location
    case poll
}

struct TelegramAttachment: Codable, Sendable, Identifiable {
    let id: UUID
    let type: TelegramAttachmentType
    var url: String?
    var mimeType: String?
    var fileName: String?
    var sizeBytes: Int?
    var caption: String?

    init(
        type: TelegramAttachmentType,
        url: String? = nil,
        mimeType: String? = nil,
        fileName: String? = nil,
        sizeBytes: Int? = nil,
        caption: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.url = url
        self.mimeType = mimeType
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.caption = caption
    }
}

private struct TelegramState: Codable {
    let contacts: [TelegramContact]
    let groups: [TelegramGroup]
    let subscribedChannels: [TelegramSubscribedChannel]
    let messageCount: Int
    let lastSyncAt: Date?
    let botUsername: String?
    let processedIDs: [String]
}
