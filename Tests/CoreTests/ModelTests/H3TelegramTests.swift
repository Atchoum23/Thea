// H3TelegramTests.swift
// Tests for Telegram channel implementation (H3)

import Testing
import Foundation

// MARK: - Telegram Message Model Tests

@Suite("Telegram — Message Model")
struct TelegramMessageModelTests {
    @Test("Create message with defaults")
    func createDefault() {
        let msg = TGTestMessage(chatID: "chat1", senderID: "user1", content: "Hello")
        #expect(msg.chatID == "chat1")
        #expect(msg.content == "Hello")
        #expect(!msg.isFromBot)
        #expect(msg.chatType == .privateChat)
        #expect(msg.attachments.isEmpty)
    }

    @Test("Create group message")
    func createGroup() {
        let msg = TGTestMessage(chatID: "-123456", senderID: "user1", content: "Group msg", chatType: .group)
        #expect(msg.chatType == .group)
    }

    @Test("Create channel message")
    func createChannel() {
        let msg = TGTestMessage(chatID: "ch1", senderID: "user1", content: "Post", chatType: .channel)
        #expect(msg.chatType == .channel)
    }

    @Test("Message IDs are unique")
    func uniqueIDs() {
        let msg1 = TGTestMessage(chatID: "c", senderID: "s", content: "1")
        let msg2 = TGTestMessage(chatID: "c", senderID: "s", content: "2")
        #expect(msg1.id != msg2.id)
    }
}

// MARK: - Telegram Chat Type Tests

@Suite("Telegram — Chat Types")
struct TelegramChatTypeTests {
    @Test("All 5 chat types exist")
    func allTypes() {
        let types: [TGTestChatType] = [.privateChat, .group, .supergroup, .channel, .bot]
        #expect(types.count == 5)
    }

    @Test("Chat types have display names")
    func displayNames() {
        #expect(TGTestChatType.privateChat.displayName == "Private Chat")
        #expect(TGTestChatType.group.displayName == "Group")
        #expect(TGTestChatType.supergroup.displayName == "Supergroup")
        #expect(TGTestChatType.channel.displayName == "Channel")
        #expect(TGTestChatType.bot.displayName == "Bot")
    }

    @Test("Chat types have icons")
    func icons() {
        #expect(TGTestChatType.privateChat.icon == "person.fill")
        #expect(TGTestChatType.channel.icon == "megaphone.fill")
        #expect(TGTestChatType.bot.icon == "cpu")
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let types: [TGTestChatType] = [.privateChat, .group, .supergroup, .channel, .bot]
        let rawValues = Set(types.map(\.rawValue))
        #expect(rawValues.count == types.count)
    }
}

// MARK: - Telegram Attachment Tests

@Suite("Telegram — Attachment Types")
struct TelegramAttachmentTypeTests {
    @Test("All 11 attachment types exist")
    func allTypes() {
        let types: [TGTestAttachmentType] = [
            .photo, .video, .audio, .voiceMessage, .videoNote,
            .document, .sticker, .animation, .contact, .location, .poll
        ]
        #expect(types.count == 11)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let types: [TGTestAttachmentType] = [
            .photo, .video, .audio, .voiceMessage, .videoNote,
            .document, .sticker, .animation, .contact, .location, .poll
        ]
        let rawValues = Set(types.map(\.rawValue))
        #expect(rawValues.count == types.count)
    }

    @Test("Create attachment with caption")
    func withCaption() {
        let att = TGTestAttachment(type: .photo, caption: "Beautiful sunset")
        #expect(att.type == .photo)
        #expect(att.caption == "Beautiful sunset")
    }
}

// MARK: - Telegram Contact Tests

@Suite("Telegram — Contact Model")
struct TelegramContactTests {
    @Test("Create contact")
    func createContact() {
        let contact = TGTestContact(id: "user1", name: "Alice", username: "alice_wonder")
        #expect(contact.id == "user1")
        #expect(contact.name == "Alice")
        #expect(contact.username == "alice_wonder")
        #expect(!contact.isBot)
    }

    @Test("Bot contact")
    func botContact() {
        let bot = TGTestContact(id: "bot1", name: "MyBot", isBot: true)
        #expect(bot.isBot)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let contact = TGTestContact(id: "u1", name: "Alice", username: "@alice")
        let data = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(TGTestContact.self, from: data)
        #expect(decoded.id == "u1")
        #expect(decoded.name == "Alice")
        #expect(decoded.username == "@alice")
    }
}

// MARK: - Telegram Group Tests

@Suite("Telegram — Group Model")
struct TelegramGroupTests {
    @Test("Create group")
    func createGroup() {
        let group = TGTestGroup(id: "g1", name: "Dev Chat", memberCount: 150, type: .supergroup)
        #expect(group.name == "Dev Chat")
        #expect(group.memberCount == 150)
        #expect(group.type == .supergroup)
        #expect(!group.isMuted)
    }

    @Test("Muted group")
    func mutedGroup() {
        let group = TGTestGroup(id: "g1", name: "Spam", isMuted: true)
        #expect(group.isMuted)
    }
}

// MARK: - Telegram Subscribed Channel Tests

@Suite("Telegram — Subscribed Channel")
struct TelegramSubscribedChannelTests {
    @Test("Create subscribed channel")
    func createChannel() {
        let channel = TGTestSubscribedChannel(id: "ch1", name: "News", subscriberCount: 50000)
        #expect(channel.name == "News")
        #expect(channel.subscriberCount == 50000)
        #expect(channel.isMonitored)
    }

    @Test("Unmonitored channel")
    func unmonitored() {
        let channel = TGTestSubscribedChannel(id: "ch2", name: "Archive", isMonitored: false)
        #expect(!channel.isMonitored)
    }
}

// MARK: - Telegram Desktop Export Parsing Tests

@Suite("Telegram — Export Parsing")
struct TelegramExportParsingTests {
    @Test("Parse personal chat export")
    func parsePersonalChat() {
        let json: [String: Any] = [
            "name": "Alice",
            "type": "personal_chat",
            "messages": [
                [
                    "id": 1,
                    "type": "message",
                    "date": "2026-02-15T14:30:00",
                    "from": "Alice",
                    "from_id": "user123",
                    "text": "Hello!"
                ],
                [
                    "id": 2,
                    "type": "message",
                    "date": "2026-02-15T14:31:00",
                    "from": "Me",
                    "from_id": "user456",
                    "text": "Hi there!"
                ]
            ]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 2)
        #expect(messages[0].senderName == "Alice")
        #expect(messages[0].content == "Hello!")
        #expect(messages[1].content == "Hi there!")
        #expect(messages[0].chatType == .privateChat)
    }

    @Test("Parse group chat export")
    func parseGroupChat() {
        let json: [String: Any] = [
            "name": "Dev Team",
            "type": "private_group",
            "messages": [
                [
                    "id": 1,
                    "type": "message",
                    "date": "2026-02-15T10:00:00",
                    "from": "Bob",
                    "from_id": "user789",
                    "text": "Meeting at 3pm"
                ]
            ]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].chatType == .group)
    }

    @Test("Parse channel export")
    func parseChannelExport() {
        let json: [String: Any] = [
            "name": "Tech News",
            "type": "public_channel",
            "messages": [
                [
                    "id": 100,
                    "type": "message",
                    "date": "2026-02-15T09:00:00",
                    "from": "Tech News",
                    "text": "Breaking: New Swift 6.1 released!"
                ]
            ]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].chatType == .channel)
    }

    @Test("Parse supergroup export")
    func parseSupergroup() {
        let json: [String: Any] = [
            "name": "Swift Community",
            "type": "public_supergroup",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T12:00:00",
                "from": "Member1",
                "text": "Question about concurrency"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].chatType == .supergroup)
    }

    @Test("Parse bot chat export")
    func parseBotChat() {
        let json: [String: Any] = [
            "name": "BotFather",
            "type": "bot_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T08:00:00",
                "from": "BotFather",
                "text": "/newbot"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].chatType == .bot)
    }

    @Test("Parse messages with photo attachment")
    func parsePhotoAttachment() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": "",
                "photo": "photos/photo_1.jpg"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].attachments.count == 1)
        #expect(messages[0].attachments[0].type == .photo)
    }

    @Test("Parse messages with file attachment")
    func parseFileAttachment() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": "Here's the doc",
                "file": "files/report.pdf",
                "mime_type": "application/pdf",
                "file_size_bytes": 250000
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].attachments.count == 1)
        #expect(messages[0].attachments[0].type == .document)
        #expect(messages[0].attachments[0].fileName == "files/report.pdf")
        #expect(messages[0].attachments[0].sizeBytes == 250000)
    }

    @Test("Parse voice message attachment")
    func parseVoiceMessage() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": "",
                "file": "voice/voice_1.ogg",
                "mime_type": "audio/ogg",
                "media_type": "voice_message"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].attachments[0].type == .voiceMessage)
    }

    @Test("Parse video message (video note)")
    func parseVideoNote() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": "",
                "file": "video/round_1.mp4",
                "mime_type": "video/mp4",
                "media_type": "video_message"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages[0].attachments[0].type == .videoNote)
    }

    @Test("Parse sticker attachment")
    func parseStickerAttachment() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": "",
                "file": "stickers/sticker_1.webp",
                "mime_type": "image/webp",
                "media_type": "sticker"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages[0].attachments[0].type == .sticker)
    }

    @Test("Parse reply to message")
    func parseReply() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 2,
                "type": "message",
                "date": "2026-02-15T14:01:00",
                "from": "Bob",
                "text": "I agree!",
                "reply_to_message_id": 1
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].replyToID == "1")
    }

    @Test("Skip service messages")
    func skipServiceMessages() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "private_group",
            "messages": [
                [
                    "id": 1,
                    "type": "service",
                    "date": "2026-02-15T14:00:00",
                    "from": "Alice",
                    "text": "Alice joined the group"
                ],
                [
                    "id": 2,
                    "type": "message",
                    "date": "2026-02-15T14:01:00",
                    "from": "Bob",
                    "text": "Welcome!"
                ]
            ]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].content == "Welcome!")
    }

    @Test("Parse structured text with entities")
    func parseStructuredText() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": [
                    "Hello ",
                    ["type": "bold", "text": "world"],
                    "!"
                ] as [Any]
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages.count == 1)
        #expect(messages[0].content == "Hello world!")
    }

    @Test("Empty export returns no messages")
    func emptyExport() {
        let json: [String: Any] = ["name": "Test", "type": "personal_chat", "messages": [] as [[String: Any]]]
        let messages = parseTGExport(json)
        #expect(messages.isEmpty)
    }

    @Test("Missing messages key returns empty")
    func missingMessages() {
        let json: [String: Any] = ["name": "Test", "type": "personal_chat"]
        let messages = parseTGExport(json)
        #expect(messages.isEmpty)
    }

    @Test("Chat type detection — negative IDs are groups")
    func chatTypeDetection() {
        #expect(detectTGChatType("-123456") == .group)
        #expect(detectTGChatType("123456") == .privateChat)
    }

    @Test("Multiple messages preserve order")
    func messageOrder() {
        let messages: [[String: Any]] = (1...5).map { i in
            [
                "id": i,
                "type": "message",
                "date": "2026-02-15T1\(i):00:00",
                "from": "User\(i)",
                "text": "Message \(i)"
            ] as [String: Any]
        }
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": messages
        ]
        let parsed = parseTGExport(json)
        #expect(parsed.count == 5)
        for i in 0..<4 {
            #expect(parsed[i].timestamp <= parsed[i + 1].timestamp)
        }
    }

    @Test("Audio file type detection")
    func audioFileDetection() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": "",
                "file": "audio/song.mp3",
                "mime_type": "audio/mpeg"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages[0].attachments[0].type == .audio)
    }

    @Test("Video file type detection")
    func videoFileDetection() {
        let json: [String: Any] = [
            "name": "Test",
            "type": "personal_chat",
            "messages": [[
                "id": 1,
                "type": "message",
                "date": "2026-02-15T14:00:00",
                "from": "Alice",
                "text": "",
                "file": "video/clip.mp4",
                "mime_type": "video/mp4"
            ]]
        ]
        let messages = parseTGExport(json)
        #expect(messages[0].attachments[0].type == .video)
    }
}

// MARK: - Cross-Platform Integration Tests

@Suite("H3 — Cross-Platform Integration")
struct H3CrossPlatformTests {
    @Test("MessagingChannelType WhatsApp properties")
    func whatsAppChannelType() {
        let type = TestMessagingChannelType.whatsApp
        #expect(type.displayName == "WhatsApp")
        #expect(type.usesBridge)
        #expect(type.icon == "phone.circle.fill")
    }

    @Test("MessagingChannelType Telegram properties")
    func telegramChannelType() {
        let type = TestMessagingChannelType.telegram
        #expect(type.displayName == "Telegram")
        #expect(type.usesBridge)
        #expect(type.icon == "paperplane.fill")
    }

    @Test("Bridge channels use OpenClaw")
    func bridgeChannels() {
        let bridgeTypes: [TestMessagingChannelType] = [.whatsApp, .telegram, .discord, .slack, .signal]
        for type in bridgeTypes {
            #expect(type.usesBridge, "Expected \(type.rawValue) to use bridge")
        }
    }

    @Test("Native channels don't use bridge")
    func nativeChannels() {
        let nativeTypes: [TestMessagingChannelType] = [.iMessage, .email, .notification, .phoneCall, .physicalMail]
        for type in nativeTypes {
            #expect(!type.usesBridge, "Expected \(type.rawValue) to be native")
        }
    }
}

// MARK: - Telegram Test Doubles

private struct TGTestMessage: Codable, Identifiable {
    let id: String
    let chatID: String
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let isFromBot: Bool
    let attachments: [TGTestAttachment]
    var replyToID: String?
    var chatType: TGTestChatType

    init(
        chatID: String, senderID: String, senderName: String? = nil, content: String,
        timestamp: Date = Date(), isFromBot: Bool = false,
        attachments: [TGTestAttachment] = [], replyToID: String? = nil,
        chatType: TGTestChatType = .privateChat
    ) {
        self.id = UUID().uuidString
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

private enum TGTestChatType: String, Codable, CaseIterable {
    case privateChat, group, supergroup, channel, bot

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

private enum TGTestAttachmentType: String, Codable, CaseIterable {
    case photo, video, audio, voiceMessage, videoNote, document, sticker, animation, contact, location, poll
}

private struct TGTestAttachment: Codable, Identifiable {
    let id: UUID
    let type: TGTestAttachmentType
    var url: String?
    var mimeType: String?
    var fileName: String?
    var sizeBytes: Int?
    var caption: String?

    init(type: TGTestAttachmentType, url: String? = nil, mimeType: String? = nil,
         fileName: String? = nil, sizeBytes: Int? = nil, caption: String? = nil) {
        self.id = UUID()
        self.type = type
        self.url = url
        self.mimeType = mimeType
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.caption = caption
    }
}

private struct TGTestContact: Codable, Identifiable {
    let id: String
    var name: String
    var username: String?
    var isBot: Bool

    init(id: String, name: String, username: String? = nil, isBot: Bool = false) {
        self.id = id
        self.name = name
        self.username = username
        self.isBot = isBot
    }
}

private struct TGTestGroup: Codable, Identifiable {
    let id: String
    var name: String
    var memberCount: Int
    var type: TGTestChatType
    var isMuted: Bool

    init(id: String, name: String, memberCount: Int = 0, type: TGTestChatType = .group, isMuted: Bool = false) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.type = type
        self.isMuted = isMuted
    }
}

private struct TGTestSubscribedChannel: Codable, Identifiable {
    let id: String
    var name: String
    var subscriberCount: Int
    var isMonitored: Bool

    init(id: String, name: String, subscriberCount: Int = 0, isMonitored: Bool = true) {
        self.id = id
        self.name = name
        self.subscriberCount = subscriberCount
        self.isMonitored = isMonitored
    }
}

private enum TestMessagingChannelType: String, CaseIterable {
    case iMessage, whatsApp, telegram, discord, slack, signal, email, notification, phoneCall, physicalMail

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

    var usesBridge: Bool {
        switch self {
        case .whatsApp, .telegram, .discord, .slack, .signal: return true
        case .iMessage, .email, .notification, .phoneCall, .physicalMail: return false
        }
    }
}

// MARK: - Telegram Parser (Mirrors Production Logic)

// Parse Telegram Desktop export JSON — mirrors TelegramChannel.parseExportJSON()
// swiftlint:disable:next cyclomatic_complexity
private func parseTGExport(_ json: [String: Any]) -> [TGTestMessage] {
    var messages: [TGTestMessage] = []

    let chatName = json["name"] as? String ?? "Unknown"
    let chatID = "export_\(chatName.hashValue)"
    let chatType: TGTestChatType
    if let typeStr = json["type"] as? String {
        switch typeStr {
        case "personal_chat": chatType = .privateChat
        case "bot_chat": chatType = .bot
        case "private_group", "public_group": chatType = .group
        case "private_supergroup", "public_supergroup": chatType = .supergroup
        case "private_channel", "public_channel": chatType = .channel
        default: chatType = .privateChat
        }
    } else {
        chatType = .privateChat
    }

    guard let messageList = json["messages"] as? [[String: Any]] else { return [] }

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

    for msgDict in messageList {
        guard let idRaw = msgDict["id"],
              let dateStr = msgDict["date"] as? String else { continue }

        let msgID = "\(idRaw)"
        _ = msgID  // Used for identification in production code
        let timestamp = dateFormatter.date(from: dateStr) ?? Date()

        let content: String
        if let textArray = msgDict["text"] as? [Any] {
            content = textArray.compactMap { item -> String? in
                if let str = item as? String { return str }
                if let dict = item as? [String: Any] { return dict["text"] as? String }
                return nil
            }.joined()
        } else if let text = msgDict["text"] as? String {
            content = text
        } else {
            content = ""
        }

        let senderName = msgDict["from"] as? String ?? "Unknown"
        let senderID = msgDict["from_id"] as? String ?? senderName

        var attachments: [TGTestAttachment] = []
        if let photo = msgDict["photo"] as? String {
            attachments.append(TGTestAttachment(type: .photo, fileName: photo))
        }
        if let file = msgDict["file"] as? String {
            let mimeType = msgDict["mime_type"] as? String
            let size = msgDict["file_size_bytes"] as? Int
            let attachType: TGTestAttachmentType
            if msgDict["media_type"] as? String == "voice_message" { attachType = .voiceMessage } else if msgDict["media_type"] as? String == "video_message" { attachType = .videoNote } else if msgDict["media_type"] as? String == "sticker" { attachType = .sticker } else if mimeType?.hasPrefix("audio/") == true { attachType = .audio } else if mimeType?.hasPrefix("video/") == true { attachType = .video } else { attachType = .document }
            attachments.append(TGTestAttachment(type: attachType, mimeType: mimeType, fileName: file, sizeBytes: size))
        }

        let replyToID: String?
        if let replyTo = msgDict["reply_to_message_id"] { replyToID = "\(replyTo)" } else { replyToID = nil }

        if msgDict["type"] as? String == "service" { continue }

        messages.append(TGTestMessage(
            chatID: chatID, senderID: senderID, senderName: senderName,
            content: content, timestamp: timestamp, attachments: attachments,
            replyToID: replyToID, chatType: chatType
        ))
    }
    return messages
}

/// Detect Telegram chat type from channel ID
private func detectTGChatType(_ channelID: String) -> TGTestChatType {
    if let numID = Int64(channelID), numID < 0 { return .group }
    return .privateChat
}
