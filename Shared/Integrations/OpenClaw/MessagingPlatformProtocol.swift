import Foundation

// MARK: - Messaging Platform Protocol
// Core types and protocol for Thea's native messaging gateway.
// Thea connects directly to each platform's API — no external daemon required.
// Port 18789 is hosted by TheaGatewayWSServer (Thea IS the gateway).

// MARK: - Platform Enum

/// Canonical list of messaging platforms Thea connects to natively.
enum MessagingPlatform: String, CaseIterable, Codable, Sendable, Hashable {
    case telegram
    case discord
    case slack
    case imessage    // via BlueBubbles local server
    case whatsapp    // via Meta Cloud API
    case signal      // via signal-cli Unix socket
    case matrix

    var displayName: String {
        switch self {
        case .telegram: "Telegram"
        case .discord:  "Discord"
        case .slack:    "Slack"
        case .imessage: "iMessage (BlueBubbles)"
        case .whatsapp: "WhatsApp"
        case .signal:   "Signal"
        case .matrix:   "Matrix/Element"
        }
    }

    /// SF Symbol name for this platform
    var symbolName: String {
        switch self {
        case .telegram: "paperplane.fill"
        case .discord:  "gamecontroller.fill"
        case .slack:    "number.square.fill"
        case .imessage: "message.fill"
        case .whatsapp: "phone.bubble.fill"
        case .signal:   "lock.shield.fill"
        case .matrix:   "square.grid.3x3.fill"
        }
    }

    /// Map to the equivalent OpenClawPlatform for security guard compatibility
    var openClawPlatform: OpenClawPlatform {
        switch self {
        case .telegram: .telegram
        case .discord:  .discord
        case .slack:    .slack
        case .imessage: .imessage
        case .whatsapp: .whatsapp
        case .signal:   .signal
        case .matrix:   .matrix
        }
    }
}

// MARK: - Unified Inbound Message

/// Unified inbound message from any messaging platform.
/// All connectors produce this type; security guard and session manager consume it.
struct TheaGatewayMessage: Sendable, Identifiable, Codable {
    let id: String
    let platform: MessagingPlatform
    let chatId: String        // channel / DM / group identifier
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
    let isGroup: Bool
    var attachments: [MessagingAttachment]

    init(
        id: String = UUID().uuidString,
        platform: MessagingPlatform,
        chatId: String,
        senderId: String,
        senderName: String,
        content: String,
        timestamp: Date = Date(),
        isGroup: Bool = false,
        attachments: [MessagingAttachment] = []
    ) {
        self.id = id
        self.platform = platform
        self.chatId = chatId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isGroup = isGroup
        self.attachments = attachments
    }
}

// MARK: - Outbound Message

/// Message to send back to a platform.
struct OutboundMessagingMessage: Sendable {
    let chatId: String
    let content: String
    var replyToId: String?
    var attachments: [MessagingAttachment]

    init(chatId: String, content: String, replyToId: String? = nil, attachments: [MessagingAttachment] = []) {
        self.chatId = chatId
        self.content = content
        self.replyToId = replyToId
        self.attachments = attachments
    }
}

// MARK: - Attachment

struct MessagingAttachment: Sendable, Codable {
    enum AttachmentKind: String, Codable, Sendable {
        case image, audio, video, file
    }
    let kind: AttachmentKind
    let data: Data
    let mimeType: String
    let fileName: String?
}

// MARK: - Credentials

/// Per-platform credentials. All tokens stored in Keychain via MessagingCredentialsStore.
struct MessagingCredentials: Sendable {
    var botToken: String?      // Telegram / Discord / Slack bot token
    var apiKey: String?        // WhatsApp phone number ID, Matrix access token, Slack app token
    var serverUrl: String?     // BlueBubbles URL, Matrix homeserver URL, Signal phone number
    var webhookSecret: String? // Slack signing secret, WhatsApp verify token
    var isEnabled: Bool

    init(
        botToken: String? = nil,
        apiKey: String? = nil,
        serverUrl: String? = nil,
        webhookSecret: String? = nil,
        isEnabled: Bool = false
    ) {
        self.botToken = botToken
        self.apiKey = apiKey
        self.serverUrl = serverUrl
        self.webhookSecret = webhookSecret
        self.isEnabled = isEnabled
    }
}

// MARK: - Errors

enum MessagingError: Error, LocalizedError, Sendable {
    case missingCredentials(platform: MessagingPlatform, field: String)
    case notConnected(platform: MessagingPlatform)
    case sendFailed(platform: MessagingPlatform, underlying: String)
    case dependencyMissing(name: String, installHint: String)
    case authenticationFailed(platform: MessagingPlatform)
    case platformUnavailable(platform: MessagingPlatform, reason: String)

    var errorDescription: String? {
        switch self {
        case let .missingCredentials(p, f):  "[\(p.displayName)] Missing credential: \(f)"
        case let .notConnected(p):            "[\(p.displayName)] Not connected"
        case let .sendFailed(p, e):           "[\(p.displayName)] Send failed: \(e)"
        case let .dependencyMissing(n, h):    "\(n) not found. Install: \(h)"
        case let .authenticationFailed(p):    "[\(p.displayName)] Authentication failed"
        case let .platformUnavailable(p, r):  "[\(p.displayName)] Unavailable: \(r)"
        }
    }
}

// MARK: - Connector Protocol

/// All messaging platform connectors must implement this protocol.
/// Connectors are Swift actors for safe concurrent access.
protocol MessagingPlatformConnector: Actor {
    var platform: MessagingPlatform { get }
    var isConnected: Bool { get }
    var credentials: MessagingCredentials { get set }

    func connect() async throws
    func disconnect() async
    func send(_ message: OutboundMessagingMessage) async throws
    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void)
}

// MARK: - OpenClawSecurityGuard extension for TheaGatewayMessage

// Extension adds a convenience isSafe() method that accepts TheaGatewayMessage
// without modifying OpenClawSecurityGuard.swift (which must stay EXACTLY as-is).
extension OpenClawSecurityGuard {
    /// Returns true if the message passes all security checks (22 injection patterns + length + keywords).
    func isSafe(_ message: TheaGatewayMessage) async -> Bool {
        let ocMessage = OpenClawMessage(
            id: message.id,
            channelID: message.chatId,
            platform: message.platform.openClawPlatform,
            senderID: message.senderId,
            senderName: message.senderName,
            content: message.content,
            timestamp: message.timestamp,
            attachments: [],
            replyToMessageID: nil,
            isFromBot: false
        )
        return validate(ocMessage).isAllowed
    }
}
