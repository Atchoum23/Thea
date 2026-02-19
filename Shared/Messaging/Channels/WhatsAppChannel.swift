import Foundation
import OSLog
#if os(macOS) || os(iOS)
import Speech
#endif

// MARK: - WhatsApp Channel

/// Full WhatsApp message access via OpenClaw Bridge (Baileys adapter).
/// Supports: real-time messaging, history retrieval, media, groups,
/// voice note transcription, read receipts, and offline backup parsing.
@MainActor
final class WhatsAppChannel: ObservableObject {
    static let shared = WhatsAppChannel()

    private let logger = Logger(subsystem: "com.thea.app", category: "WhatsAppChannel")

    // MARK: - Published State

    @Published private(set) var isConnected = false
    @Published private(set) var isPaired = false
    @Published private(set) var contacts: [WhatsAppContact] = []
    @Published private(set) var groups: [WhatsAppGroup] = []
    @Published private(set) var messageCount = 0
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var connectionError: String?

    // MARK: - Configuration

    var enabled = true
    var autoTranscribeVoiceNotes = true
    var syncMediaFiles = false
    var maxHistoryMessages = 500

    // MARK: - Storage

    private let storageDir: URL
    private var conversationCache: [String: [WhatsAppMessage]] = [:]
    private var processedMessageIDs: Set<String> = []

    // periphery:ignore - Reserved: isPaired property reserved for future feature activation
    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        storageDir = appSupport.appendingPathComponent("Thea/WhatsApp")
        do {
            try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        // periphery:ignore - Reserved: enabled property reserved for future feature activation
        } catch {
            // periphery:ignore - Reserved: syncMediaFiles property reserved for future feature activation
            // periphery:ignore - Reserved: maxHistoryMessages property reserved for future feature activation
            logger.debug("Could not create WhatsApp storage directory: \(error.localizedDescription)")
        }
        loadState()
    }

    // MARK: - Connection

    func connect() async {
        guard enabled else { return }
        logger.info("Connecting WhatsApp channel via OpenClaw Bridge")

        MessagingHub.shared.registerChannel(
            RegisteredChannel(type: .whatsApp, name: "WhatsApp")
        )
        MessagingHub.shared.updateChannelStatus(.whatsApp, name: "WhatsApp", status: .connecting)

        // Check if OpenClaw Gateway is available
        let available = await OpenClawIntegration.shared.checkAvailability()
        guard available else {
            connectionError = "OpenClaw Gateway not available at ws://127.0.0.1:18789"
            MessagingHub.shared.updateChannelStatus(.whatsApp, name: "WhatsApp", status: .error)
            logger.warning("OpenClaw Gateway not available")
            return
        // periphery:ignore - Reserved: connect() instance method reserved for future feature activation
        }

        // Enable OpenClaw if not already
        if !OpenClawIntegration.shared.isEnabled {
            OpenClawIntegration.shared.enable()
        }

        // Register message handler for WhatsApp messages
        OpenClawIntegration.shared.onMessageReceived = { [weak self] message in
            await self?.handleOpenClawMessage(message)
        }

        isConnected = true
        isPaired = true
        connectionError = nil
        MessagingHub.shared.updateChannelStatus(.whatsApp, name: "WhatsApp", status: .connected)

        // Channel list comes automatically on connect via OpenClaw event stream
        updateChannelsFromOpenClaw()

        logger.info("WhatsApp channel connected")
    }

    func disconnect() {
        isConnected = false
        MessagingHub.shared.updateChannelStatus(.whatsApp, name: "WhatsApp", status: .disconnected)
        saveState()
        logger.info("WhatsApp channel disconnected")
    }

    // MARK: - Message Handling

    private func handleOpenClawMessage(_ message: OpenClawMessage) async {
        guard message.platform == .whatsapp else { return }
        guard !processedMessageIDs.contains(message.id) else { return }
        processedMessageIDs.insert(message.id)

        // Convert to WhatsAppMessage
        // periphery:ignore - Reserved: disconnect() instance method reserved for future feature activation
        let waMessage = WhatsAppMessage(
            id: message.id,
            chatID: message.channelID,
            senderID: message.senderID,
            senderName: message.senderName,
            content: message.content,
            timestamp: message.timestamp,
            isFromMe: message.isFromBot,
            // periphery:ignore - Reserved: handleOpenClawMessage(_:) instance method reserved for future feature activation
            attachments: message.attachments.map { att in
                WhatsAppAttachment(
                    type: mapAttachmentType(att.type),
                    url: att.url?.absoluteString,
                    mimeType: att.mimeType,
                    fileName: att.fileName,
                    sizeBytes: att.sizeBytes
                )
            },
            replyToID: message.replyToMessageID,
            isGroup: isGroupChat(message.channelID)
        )

        // Cache in conversation
        var messages = conversationCache[message.channelID] ?? []
        messages.append(waMessage)
        if messages.count > maxHistoryMessages {
            messages = Array(messages.suffix(maxHistoryMessages))
        }
        conversationCache[message.channelID] = messages
        messageCount += 1

        // Transcribe voice notes
        if autoTranscribeVoiceNotes,
           waMessage.attachments.contains(where: { $0.type == .voiceNote }) {
            await transcribeVoiceNote(waMessage)
        }

        // Route to MessagingHub
        let unified = MessagingHub.shared.fromOpenClaw(
            platform: "whatsapp",
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

        // Update contact/group info
        updateContactFromMessage(waMessage)
        saveState()
    }

    // MARK: - Send Messages

    func sendMessage(to chatID: String, text: String) async -> Bool {
        guard isConnected else {
            logger.warning("Cannot send: WhatsApp not connected")
            return false
        }
        do {
            try await OpenClawIntegration.shared.sendMessage(to: chatID, text: text)
            logger.info("Sent WhatsApp message to \(chatID)")
            return true
        } catch {
            logger.error("Failed to send WhatsApp message: \(error.localizedDescription)")
            return false
        }
    // periphery:ignore - Reserved: sendMessage(to:text:) instance method reserved for future feature activation
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
    // periphery:ignore - Reserved: replyToMessage(chatID:messageID:text:) instance method reserved for future feature activation
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

// periphery:ignore - Reserved: markAsRead(chatID:messageID:) instance method reserved for future feature activation

    // MARK: - History

    func loadHistory(chatID: String, limit: Int = 50) async -> [WhatsAppMessage] {
        // Return cached messages first
        if let cached = conversationCache[chatID], !cached.isEmpty {
            return Array(cached.suffix(limit))
        }

        // Try fetching from OpenClaw Gateway
        guard isConnected else { return [] }
        do {
            let client = OpenClawClient()
            // periphery:ignore - Reserved: loadHistory(chatID:limit:) instance method reserved for future feature activation
            try await client.send(command: .getHistory(sessionKey: chatID, limit: limit, before: nil))
            // History comes back as events — they'll be processed by handleOpenClawMessage
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return [] }
            return Array((conversationCache[chatID] ?? []).suffix(limit))
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
            return []
        }
    }

    func searchMessages(query: String) -> [WhatsAppMessage] {
        let lower = query.lowercased()
        return conversationCache.values.flatMap { $0 }
            .filter { $0.content.lowercased().contains(lower) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Backup Parsing (Offline Fallback)

    // periphery:ignore - Reserved: searchMessages(query:) instance method reserved for future feature activation
    /// Parse WhatsApp chat export file (txt format from "Export Chat" feature).
    func importChatExport(from url: URL) -> [WhatsAppMessage] {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            logger.error("Failed to read WhatsApp export file: \(error.localizedDescription)")
            return []
        }
        return parseChatExport(content)
    }

    /// Parse WhatsApp chat export text content.
    func parseChatExport(_ content: String) -> [WhatsAppMessage] {
        var messages: [WhatsAppMessage] = []
        let lines = content.components(separatedBy: .newlines)

        // WhatsApp export format: [dd/MM/yyyy, HH:mm:ss] Sender: Message
        // Or: dd.MM.yy, HH:mm - Sender: Message (European format)
        let bracketPattern = #"^\[(\d{1,2}/\d{1,2}/\d{2,4}),?\s*(\d{1,2}:\d{2}(?::\d{2})?)\]\s*(.+?):\s*(.+)$"#
        let dashPattern = #"^(\d{1,2}\.\d{1,2}\.\d{2,4}),?\s*(\d{1,2}:\d{2})\s*-\s*(.+?):\s*(.+)$"#

        var bracketRegex: NSRegularExpression?
        var dashRegex: NSRegularExpression?
        do {
            bracketRegex = try NSRegularExpression(pattern: bracketPattern)
            dashRegex = try NSRegularExpression(pattern: dashPattern)
        } catch {
            logger.debug("Failed to compile WhatsApp export regex patterns: \(error.localizedDescription)")
        }

        let dateFormatterBracket = DateFormatter()
        dateFormatterBracket.locale = Locale(identifier: "en_US_POSIX")

        let dateFormatterDash = DateFormatter()
        dateFormatterDash.locale = Locale(identifier: "de_CH")

        var currentMessage: (date: String, time: String, sender: String, content: String)?

        for line in lines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)

            if let match = bracketRegex?.firstMatch(in: line, range: range),
               match.numberOfRanges == 5 {
                // Flush previous message
                if let prev = currentMessage {
                    if let msg = createParsedMessage(prev, bracketFormat: true) {
                        messages.append(msg)
                    }
                }
                currentMessage = (
                    date: String(line[Range(match.range(at: 1), in: line)!]),  // swiftlint:disable:this force_unwrapping
                    time: String(line[Range(match.range(at: 2), in: line)!]),  // swiftlint:disable:this force_unwrapping
                    sender: String(line[Range(match.range(at: 3), in: line)!]),  // swiftlint:disable:this force_unwrapping
                    content: String(line[Range(match.range(at: 4), in: line)!])  // swiftlint:disable:this force_unwrapping
                )
            } else if let match = dashRegex?.firstMatch(in: line, range: range),
                      match.numberOfRanges == 5 {
                if let prev = currentMessage {
                    if let msg = createParsedMessage(prev, bracketFormat: false) {
                        messages.append(msg)
                    }
                }
                currentMessage = (
                    date: String(line[Range(match.range(at: 1), in: line)!]),  // swiftlint:disable:this force_unwrapping
                    time: String(line[Range(match.range(at: 2), in: line)!]),  // swiftlint:disable:this force_unwrapping
                    sender: String(line[Range(match.range(at: 3), in: line)!]),  // swiftlint:disable:this force_unwrapping
                    content: String(line[Range(match.range(at: 4), in: line)!])  // swiftlint:disable:this force_unwrapping
                )
            } else if currentMessage != nil, !line.isEmpty {
                // Continuation of previous message
                currentMessage?.content += "\n" + line
            }
        }

        // Flush last message
        if let prev = currentMessage {
            if let msg = createParsedMessage(prev, bracketFormat: true) {
                messages.append(msg)
            }
        }

        // Cache parsed messages by chat
        if let firstChatID = messages.first?.chatID {
            conversationCache[firstChatID] = messages
        }

        logger.info("Parsed \(messages.count) messages from WhatsApp export")
        return messages
    }

    private func createParsedMessage(
        _ raw: (date: String, time: String, sender: String, content: String),
        bracketFormat: Bool
    ) -> WhatsAppMessage? {
        let dateString = "\(raw.date) \(raw.time)"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try multiple date formats
        let formats = bracketFormat
            ? ["d/M/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm:ss", "M/d/yy HH:mm:ss",
               "d/M/yyyy HH:mm", "dd/MM/yyyy HH:mm"]
            : ["d.M.yy HH:mm", "dd.MM.yy HH:mm", "dd.MM.yyyy HH:mm",
               "d.M.yyyy HH:mm"]

        var parsedDate: Date?
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                parsedDate = date
                break
            }
        }

        guard let timestamp = parsedDate else { return nil }

        // Detect media attachments from export text
        let attachments: [WhatsAppAttachment]
        let isMedia = raw.content.hasSuffix("(file attached)")
            || raw.content.contains("<Media omitted>")
            || raw.content.hasPrefix("IMG-")
            || raw.content.hasPrefix("VID-")
            || raw.content.hasPrefix("AUD-")
            || raw.content.hasPrefix("PTT-")
            || raw.content.hasPrefix("STK-")

        if isMedia {
            let type: WhatsAppAttachmentType
            if raw.content.hasPrefix("AUD-") || raw.content.hasPrefix("PTT-") {
                type = .voiceNote
            } else if raw.content.hasPrefix("VID-") {
                type = .video
            } else if raw.content.hasPrefix("STK-") {
                type = .sticker
            } else if raw.content.hasPrefix("IMG-") {
                type = .image
            } else {
                type = .document
            }
            attachments = [WhatsAppAttachment(type: type, fileName: raw.content)]
        } else {
            attachments = []
        }

        let chatID = "export_\(raw.sender.hashValue)"

        return WhatsAppMessage(
            id: UUID().uuidString,
            chatID: chatID,
            senderID: raw.sender,
            senderName: raw.sender,
            content: raw.content,
            timestamp: timestamp,
            isFromMe: false,
            attachments: attachments,
            isGroup: false
        )
    }

    // MARK: - Voice Note Transcription

    private func transcribeVoiceNote(_ message: WhatsAppMessage) async {
        #if os(macOS) || os(iOS)
        guard let voiceNote = message.attachments.first(where: { $0.type == .voiceNote }),
              let urlString = voiceNote.url,
              let audioURL = URL(string: urlString) else { return }

        do {
            let transcription = try await transcribeAudio(at: audioURL)
            // periphery:ignore - Reserved: transcribeVoiceNote(_:) instance method reserved for future feature activation
            logger.info("Transcribed voice note: \(transcription.prefix(100))")

            let transcriptionMsg = MessagingHub.shared.fromOpenClaw(
                platform: "whatsapp",
                channelID: message.chatID,
                senderID: message.senderID,
                senderName: message.senderName,
                content: "[Voice Note Transcription] \(transcription)",
                isFromBot: false
            )
            await MessagingHub.shared.routeIncomingMessage(transcriptionMsg)
        } catch {
            logger.warning("Voice note transcription failed: \(error.localizedDescription)")
        }
        #endif
    }

    #if os(macOS) || os(iOS)
    private func transcribeAudio(at url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            recognizer?.recognitionTask(with: request) { result, error in
                // periphery:ignore - Reserved: transcribeAudio(at:) instance method reserved for future feature activation
                if let error {
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    #endif

    // MARK: - Contact & Group Management

    private func updateContactFromMessage(_ message: WhatsAppMessage) {
        if message.isGroup {
            if !groups.contains(where: { $0.id == message.chatID }) {
                groups.append(WhatsAppGroup(
                    id: message.chatID,
                    name: message.chatID,
                    // periphery:ignore - Reserved: updateContactFromMessage(_:) instance method reserved for future feature activation
                    participantCount: 0,
                    lastMessageAt: message.timestamp
                ))
            }
        } else {
            if let index = contacts.firstIndex(where: { $0.id == message.senderID }) {
                contacts[index].lastMessageAt = message.timestamp
            } else if let name = message.senderName {
                contacts.append(WhatsAppContact(
                    id: message.senderID,
                    name: name,
                    phoneNumber: message.senderID,
                    lastMessageAt: message.timestamp
                ))
            }
        }
    }

    private func updateChannelsFromOpenClaw() {
        for channel in OpenClawIntegration.shared.channels where channel.platform == .whatsapp {
            if channel.isGroup {
                if !groups.contains(where: { $0.id == channel.id }) {
                    groups.append(WhatsAppGroup(
                        // periphery:ignore - Reserved: updateChannelsFromOpenClaw() instance method reserved for future feature activation
                        id: channel.id,
                        name: channel.name,
                        participantCount: channel.participantCount ?? 0,
                        lastMessageAt: channel.lastActivityAt
                    ))
                }
            }
        }
    }

    private func isGroupChat(_ channelID: String) -> Bool {
        // WhatsApp group IDs typically end with @g.us
        channelID.hasSuffix("@g.us") || groups.contains { $0.id == channelID }
    }

// periphery:ignore - Reserved: isGroupChat(_:) instance method reserved for future feature activation

    // MARK: - Helpers

    private func mapAttachmentType(_ type: OpenClawAttachment.AttachmentType) -> WhatsAppAttachmentType {
        switch type {
        case .image: return .image
        // periphery:ignore - Reserved: mapAttachmentType(_:) instance method reserved for future feature activation
        case .audio: return .voiceNote
        case .video: return .video
        case .document: return .document
        case .sticker: return .sticker
        }
    }

    // MARK: - Statistics

    var totalMessages: Int { conversationCache.values.reduce(0) { $0 + $1.count } }
    var totalContacts: Int { contacts.count }
    var totalGroups: Int { groups.count }
    var conversationCount: Int { conversationCache.count }

    // MARK: - Persistence

    private func saveState() {
        let state = WhatsAppState(
            // periphery:ignore - Reserved: saveState() instance method reserved for future feature activation
            contacts: contacts,
            groups: groups,
            messageCount: messageCount,
            lastSyncAt: lastSyncAt,
            processedIDs: Array(processedMessageIDs.prefix(5000))
        )
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageDir.appendingPathComponent("state.json"), options: .atomic)
        } catch {
            logger.error("Failed to save WhatsApp state: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        let url = storageDir.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder().decode(WhatsAppState.self, from: data)
            contacts = state.contacts
            groups = state.groups
            messageCount = state.messageCount
            lastSyncAt = state.lastSyncAt
            processedMessageIDs = Set(state.processedIDs)
        } catch {
            logger.debug("Could not load WhatsApp state: \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

struct WhatsAppMessage: Codable, Sendable, Identifiable {
    let id: String
    let chatID: String
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let isFromMe: Bool
    let attachments: [WhatsAppAttachment]
    var replyToID: String?
    var isGroup: Bool

    init(
        id: String = UUID().uuidString,
        chatID: String,
        senderID: String,
        senderName: String? = nil,
        content: String,
        timestamp: Date = Date(),
        isFromMe: Bool = false,
        attachments: [WhatsAppAttachment] = [],
        replyToID: String? = nil,
        isGroup: Bool = false
    ) {
        self.id = id
        self.chatID = chatID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isFromMe = isFromMe
        self.attachments = attachments
        self.replyToID = replyToID
        self.isGroup = isGroup
    }
}

struct WhatsAppContact: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var phoneNumber: String?
    var profilePictureURL: String?
    var lastMessageAt: Date?
    var isBlocked: Bool

    init(
        // periphery:ignore - Reserved: init(id:name:phoneNumber:profilePictureURL:lastMessageAt:isBlocked:) initializer reserved for future feature activation
        id: String,
        name: String,
        phoneNumber: String? = nil,
        profilePictureURL: String? = nil,
        lastMessageAt: Date? = nil,
        isBlocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.profilePictureURL = profilePictureURL
        self.lastMessageAt = lastMessageAt
        self.isBlocked = isBlocked
    }
}

struct WhatsAppGroup: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var participantCount: Int
    var lastMessageAt: Date?
    var isMuted: Bool

    // periphery:ignore - Reserved: init(id:name:participantCount:lastMessageAt:isMuted:) initializer reserved for future feature activation
    init(
        id: String,
        name: String,
        participantCount: Int = 0,
        lastMessageAt: Date? = nil,
        isMuted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.participantCount = participantCount
        self.lastMessageAt = lastMessageAt
        self.isMuted = isMuted
    }
}

enum WhatsAppAttachmentType: String, Codable, Sendable, CaseIterable {
    case image
    case video
    case voiceNote
    case audio
    case document
    case sticker
    case contact
    case location
}

struct WhatsAppAttachment: Codable, Sendable, Identifiable {
    let id: UUID
    let type: WhatsAppAttachmentType
    var url: String?
    var mimeType: String?
    var fileName: String?
    var sizeBytes: Int?
    var transcription: String?

    init(
        type: WhatsAppAttachmentType,
        url: String? = nil,
        mimeType: String? = nil,
        fileName: String? = nil,
        sizeBytes: Int? = nil,
        transcription: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.url = url
        self.mimeType = mimeType
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.transcription = transcription
    }
}

private struct WhatsAppState: Codable {
    let contacts: [WhatsAppContact]
    let groups: [WhatsAppGroup]
    let messageCount: Int
    let lastSyncAt: Date?
    let processedIDs: [String]
}
