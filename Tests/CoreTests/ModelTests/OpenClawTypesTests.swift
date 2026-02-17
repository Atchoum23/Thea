// OpenClawTypesTests.swift
// Tests for OpenClaw Gateway types (standalone test doubles)

import Testing
import Foundation

// MARK: - OpenClaw Test Doubles

private enum TestOpenClawPlatform: String, Codable, Sendable, CaseIterable {
    case whatsapp, telegram, discord, slack, signal, imessage, matrix, irc

    var displayName: String {
        switch self {
        case .whatsapp: "WhatsApp"
        case .telegram: "Telegram"
        case .discord: "Discord"
        case .slack: "Slack"
        case .signal: "Signal"
        case .imessage: "iMessage"
        case .matrix: "Matrix"
        case .irc: "IRC"
        }
    }
}

private struct TestOpenClawChannel: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let platform: TestOpenClawPlatform
    let name: String
    let isGroup: Bool
    let participantCount: Int?
    let lastActivityAt: Date?
}

private struct TestOpenClawMessage: Identifiable, Codable, Sendable {
    let id: String
    let channelID: String
    let platform: TestOpenClawPlatform
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let attachments: [TestOpenClawAttachment]
    let replyToMessageID: String?
    let isFromBot: Bool
}

private struct TestOpenClawAttachment: Codable, Sendable {
    let type: AttachmentType
    let url: URL?
    let mimeType: String?
    let fileName: String?
    let sizeBytes: Int?

    enum AttachmentType: String, Codable, Sendable, CaseIterable {
        case image, audio, video, document, sticker
    }
}

private enum TestOpenClawGatewayCommand: Sendable {
    case listChannels
    case listSessions
    case sendMessage(channelID: String, text: String)
    case sendReply(channelID: String, text: String, replyToID: String)
    case getHistory(channelID: String, limit: Int)
    case markRead(channelID: String, messageID: String)
    case ping

    var method: String {
        switch self {
        case .listChannels: "channels.list"
        case .listSessions: "sessions.list"
        case .sendMessage: "message.send"
        case .sendReply: "message.reply"
        case .getHistory: "message.history"
        case .markRead: "message.markRead"
        case .ping: "ping"
        }
    }
}

private enum TestOpenClawConnectionState: String, Sendable, CaseIterable {
    case disconnected, connecting, connected, reconnecting, failed
}

// MARK: - Platform Tests

@Suite("OpenClaw Platform — Completeness")
struct OpenClawPlatformTests {
    @Test("All 8 platforms exist")
    func allCases() {
        #expect(TestOpenClawPlatform.allCases.count == 8)
    }

    @Test("All platforms have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestOpenClawPlatform.allCases.map(\.rawValue))
        #expect(rawValues.count == 8)
    }

    @Test("Display names use proper capitalization")
    func displayNames() {
        #expect(TestOpenClawPlatform.whatsapp.displayName == "WhatsApp")
        #expect(TestOpenClawPlatform.imessage.displayName == "iMessage")
        #expect(TestOpenClawPlatform.irc.displayName == "IRC")
    }

    @Test("Display names are non-empty")
    func allDisplayNames() {
        for platform in TestOpenClawPlatform.allCases {
            #expect(!platform.displayName.isEmpty)
        }
    }

    @Test("Platform is Codable")
    func codableRoundtrip() throws {
        for platform in TestOpenClawPlatform.allCases {
            let data = try JSONEncoder().encode(platform)
            let decoded = try JSONDecoder().decode(TestOpenClawPlatform.self, from: data)
            #expect(decoded == platform)
        }
    }
}

// MARK: - Channel Tests

@Suite("OpenClaw Channel — Properties")
struct OpenClawChannelTests {
    @Test("Direct message channel")
    func directMessage() {
        let channel = TestOpenClawChannel(
            id: "ch-1", platform: .whatsapp, name: "Alice",
            isGroup: false, participantCount: 2, lastActivityAt: Date()
        )
        #expect(!channel.isGroup)
        #expect(channel.participantCount == 2)
    }

    @Test("Group channel with participants")
    func groupChannel() {
        let channel = TestOpenClawChannel(
            id: "ch-2", platform: .discord, name: "Dev Chat",
            isGroup: true, participantCount: 150, lastActivityAt: Date()
        )
        #expect(channel.isGroup)
        #expect(channel.participantCount == 150)
    }

    @Test("Channel with no last activity")
    func noActivity() {
        let channel = TestOpenClawChannel(
            id: "ch-3", platform: .irc, name: "#general",
            isGroup: true, participantCount: nil, lastActivityAt: nil
        )
        #expect(channel.lastActivityAt == nil)
        #expect(channel.participantCount == nil)
    }

    @Test("Channel is Hashable")
    func hashable() {
        let a = TestOpenClawChannel(id: "ch-1", platform: .slack, name: "Test",
                                     isGroup: false, participantCount: nil, lastActivityAt: nil)
        let b = TestOpenClawChannel(id: "ch-1", platform: .slack, name: "Test",
                                     isGroup: false, participantCount: nil, lastActivityAt: nil)
        #expect(a == b)
    }

    @Test("Channel Codable roundtrip")
    func codableRoundtrip() throws {
        let channel = TestOpenClawChannel(
            id: "ch-1", platform: .telegram, name: "Bot Channel",
            isGroup: true, participantCount: 42, lastActivityAt: Date()
        )
        let data = try JSONEncoder().encode(channel)
        let decoded = try JSONDecoder().decode(TestOpenClawChannel.self, from: data)
        #expect(decoded.id == "ch-1")
        #expect(decoded.platform == .telegram)
        #expect(decoded.isGroup)
        #expect(decoded.participantCount == 42)
    }
}

// MARK: - Message Tests

@Suite("OpenClaw Message — Properties")
struct OpenClawMessageTests {
    @Test("User message")
    func userMessage() {
        let msg = TestOpenClawMessage(
            id: "msg-1", channelID: "ch-1", platform: .whatsapp,
            senderID: "user-1", senderName: "Alice",
            content: "Hello!", timestamp: Date(),
            attachments: [], replyToMessageID: nil, isFromBot: false
        )
        #expect(!msg.isFromBot)
        #expect(msg.senderName == "Alice")
        #expect(msg.attachments.isEmpty)
    }

    @Test("Bot reply message")
    func botReply() {
        let msg = TestOpenClawMessage(
            id: "msg-2", channelID: "ch-1", platform: .whatsapp,
            senderID: "bot-1", senderName: "Thea",
            content: "Hello! How can I help?", timestamp: Date(),
            attachments: [], replyToMessageID: "msg-1", isFromBot: true
        )
        #expect(msg.isFromBot)
        #expect(msg.replyToMessageID == "msg-1")
    }

    @Test("Message with attachments")
    func withAttachments() {
        let attachment = TestOpenClawAttachment(
            type: .image, url: URL(string: "https://example.com/photo.jpg"),
            mimeType: "image/jpeg", fileName: "photo.jpg", sizeBytes: 1024000
        )
        let msg = TestOpenClawMessage(
            id: "msg-3", channelID: "ch-1", platform: .telegram,
            senderID: "user-2", senderName: nil,
            content: "Check this out", timestamp: Date(),
            attachments: [attachment], replyToMessageID: nil, isFromBot: false
        )
        #expect(msg.attachments.count == 1)
        #expect(msg.senderName == nil)
    }

    @Test("Message Codable roundtrip")
    func codableRoundtrip() throws {
        let msg = TestOpenClawMessage(
            id: "msg-1", channelID: "ch-1", platform: .discord,
            senderID: "user-1", senderName: "Bob",
            content: "Test message", timestamp: Date(),
            attachments: [], replyToMessageID: nil, isFromBot: false
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(TestOpenClawMessage.self, from: data)
        #expect(decoded.id == "msg-1")
        #expect(decoded.content == "Test message")
        #expect(decoded.platform == .discord)
    }
}

// MARK: - Attachment Tests

@Suite("OpenClaw Attachment — Types")
struct OpenClawAttachmentTests {
    @Test("All 5 attachment types exist")
    func allTypes() {
        #expect(TestOpenClawAttachment.AttachmentType.allCases.count == 5)
    }

    @Test("Attachment with all properties")
    func fullAttachment() {
        let att = TestOpenClawAttachment(
            type: .document, url: URL(string: "https://example.com/doc.pdf"),
            mimeType: "application/pdf", fileName: "report.pdf", sizeBytes: 5_000_000
        )
        #expect(att.type == .document)
        #expect(att.mimeType == "application/pdf")
        #expect(att.sizeBytes == 5_000_000)
    }

    @Test("Attachment with nil optional fields")
    func minimalAttachment() {
        let att = TestOpenClawAttachment(type: .sticker, url: nil, mimeType: nil,
                                          fileName: nil, sizeBytes: nil)
        #expect(att.type == .sticker)
        #expect(att.url == nil)
        #expect(att.sizeBytes == nil)
    }

    @Test("Attachment type Codable roundtrip")
    func codableRoundtrip() throws {
        for aType in TestOpenClawAttachment.AttachmentType.allCases {
            let data = try JSONEncoder().encode(aType)
            let decoded = try JSONDecoder().decode(TestOpenClawAttachment.AttachmentType.self, from: data)
            #expect(decoded == aType)
        }
    }
}

// MARK: - Gateway Command Tests

@Suite("OpenClaw Gateway Command — Methods")
struct OpenClawGatewayCommandTests {
    @Test("listChannels method")
    func listChannels() {
        #expect(TestOpenClawGatewayCommand.listChannels.method == "channels.list")
    }

    @Test("listSessions method")
    func listSessions() {
        #expect(TestOpenClawGatewayCommand.listSessions.method == "sessions.list")
    }

    @Test("sendMessage method")
    func sendMessage() {
        let cmd = TestOpenClawGatewayCommand.sendMessage(channelID: "ch-1", text: "Hello")
        #expect(cmd.method == "message.send")
    }

    @Test("sendReply method")
    func sendReply() {
        let cmd = TestOpenClawGatewayCommand.sendReply(channelID: "ch-1", text: "Reply", replyToID: "msg-1")
        #expect(cmd.method == "message.reply")
    }

    @Test("getHistory method")
    func getHistory() {
        let cmd = TestOpenClawGatewayCommand.getHistory(channelID: "ch-1", limit: 50)
        #expect(cmd.method == "message.history")
    }

    @Test("markRead method")
    func markRead() {
        let cmd = TestOpenClawGatewayCommand.markRead(channelID: "ch-1", messageID: "msg-5")
        #expect(cmd.method == "message.markRead")
    }

    @Test("ping method")
    func pingMethod() {
        #expect(TestOpenClawGatewayCommand.ping.method == "ping")
    }

    @Test("All methods are unique")
    func uniqueMethods() {
        let methods = [
            TestOpenClawGatewayCommand.listChannels.method,
            TestOpenClawGatewayCommand.listSessions.method,
            TestOpenClawGatewayCommand.sendMessage(channelID: "", text: "").method,
            TestOpenClawGatewayCommand.sendReply(channelID: "", text: "", replyToID: "").method,
            TestOpenClawGatewayCommand.getHistory(channelID: "", limit: 0).method,
            TestOpenClawGatewayCommand.markRead(channelID: "", messageID: "").method,
            TestOpenClawGatewayCommand.ping.method
        ]
        #expect(Set(methods).count == 7)
    }
}

// MARK: - Connection State Tests

@Suite("OpenClaw Connection State — Cases")
struct OpenClawConnectionStateTests {
    @Test("All 5 connection states exist")
    func allCases() {
        #expect(TestOpenClawConnectionState.allCases.count == 5)
    }

    @Test("All states have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestOpenClawConnectionState.allCases.map(\.rawValue))
        #expect(rawValues.count == 5)
    }
}
