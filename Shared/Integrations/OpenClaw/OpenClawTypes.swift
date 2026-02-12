import Foundation

// MARK: - OpenClaw Types
// Data types for OpenClaw Gateway communication
// Supports WhatsApp, Telegram, Discord, Slack, Signal, iMessage

enum OpenClawPlatform: String, Codable, Sendable, CaseIterable {
    case whatsapp
    case telegram
    case discord
    case slack
    case signal
    case imessage
    case matrix
    case irc

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

struct OpenClawChannel: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let platform: OpenClawPlatform
    let name: String
    let isGroup: Bool
    let participantCount: Int?
    let lastActivityAt: Date?
}

struct OpenClawMessage: Identifiable, Codable, Sendable {
    let id: String
    let channelID: String
    let platform: OpenClawPlatform
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let attachments: [OpenClawAttachment]
    let replyToMessageID: String?
    let isFromBot: Bool
}

struct OpenClawAttachment: Codable, Sendable {
    let type: AttachmentType
    let url: URL?
    let mimeType: String?
    let fileName: String?
    let sizeBytes: Int?

    enum AttachmentType: String, Codable, Sendable {
        case image
        case audio
        case video
        case document
        case sticker
    }
}

// MARK: - Gateway Protocol

/// Commands sent to OpenClaw Gateway
enum OpenClawGatewayCommand: Sendable {
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

    var params: [String: Any] {
        switch self {
        case .listChannels, .listSessions, .ping:
            return [:]
        case let .sendMessage(channelID, text):
            return ["channel_id": channelID, "text": text]
        case let .sendReply(channelID, text, replyToID):
            return ["channel_id": channelID, "text": text, "reply_to": replyToID]
        case let .getHistory(channelID, limit):
            return ["channel_id": channelID, "limit": limit]
        case let .markRead(channelID, messageID):
            return ["channel_id": channelID, "message_id": messageID]
        }
    }
}

/// Events received from OpenClaw Gateway
enum OpenClawGatewayEvent: Sendable {
    case connected
    case disconnected(reason: String?)
    case messageReceived(OpenClawMessage)
    case channelUpdated(OpenClawChannel)
    case error(String)
    case pong
}

// MARK: - Connection State

enum OpenClawConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}
