import Foundation

// MARK: - OpenClaw Types
// Data types for OpenClaw Gateway communication
// Supports WhatsApp, Telegram, Discord, Slack, Signal, iMessage,
// BlueBubbles, Google Chat, Microsoft Teams, WebChat, Zalo, Matrix, IRC

// MARK: - Wire Protocol Types (O0/O1)

/// Request sent to Gateway: {"type":"req","id":"uuid","method":"...","params":{...}}
struct OpenClawWireRequest: Sendable {
    let type = "req"
    let id: String
    let method: String
    let params: [String: Any]

    init(id: String = UUID().uuidString, method: String, params: [String: Any] = [:]) {
        self.id = id
        self.method = method
        self.params = params
    }

    func encoded() throws -> String {
        let dict: [String: Any] = ["type": type, "id": id, "method": method, "params": params]
        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OpenClawError.encodingFailed
        }
        return json
    }
}

/// Response from Gateway: {"type":"res","id":"uuid","ok":bool,"payload":{...}|"error":{...}}
struct OpenClawWireResponse: Codable, Sendable {
    let type: String   // "res"
    let id: String?
    let ok: Bool?
    let payload: OpenClawJSONValue?
    let error: OpenClawResponseError?
}

/// Event pushed by Gateway: {"type":"event","event":"...","payload":{...},"seq":42}
struct OpenClawWireEvent: Codable, Sendable {
    let type: String    // "event"
    let event: String
    let payload: OpenClawJSONValue?
    let seq: Int?
    let stateVersion: Int?
}

/// Error object in a Gateway response
struct OpenClawResponseError: Codable, Sendable {
    let code: Int
    let message: String
    let data: OpenClawJSONValue?
}

/// Type-erased JSON value for flexible payload handling
/// Decodes any JSON value (object, array, string, number, bool, null)
@preconcurrency
enum OpenClawJSONValue: Codable, Sendable {
    case object([String: OpenClawJSONValue])
    case array([OpenClawJSONValue])
    case string(String)
    case number(Double)
    case int(Int)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let obj = try? container.decode([String: OpenClawJSONValue].self) {
            self = .object(obj)
        } else if let arr = try? container.decode([OpenClawJSONValue].self) {
            self = .array(arr)
        } else if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(obj): try container.encode(obj)
        case let .array(arr): try container.encode(arr)
        case let .string(s): try container.encode(s)
        case let .number(d): try container.encode(d)
        case let .int(i): try container.encode(i)
        case let .bool(b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }

    /// Decode this JSON value as a strongly-typed Codable
    func decode<T: Decodable>(as type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }

    /// Return raw JSON Data
    var rawData: Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}

// MARK: - Payload Container

/// Type-safe wrapper around a raw JSON Data response from the Gateway
struct OpenClawPayload: Sendable {
    let data: Data

    init(_ data: Data) { self.data = data }
    init(jsonValue: OpenClawJSONValue) { self.data = jsonValue.rawData }

    func decode<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    var rawJSON: Data { data }
    var binaryData: Data? { nil } // reserved for binary payloads
}

// MARK: - Platform

enum OpenClawPlatform: String, Codable, Sendable, CaseIterable {
    case whatsapp
    case telegram
    case discord
    case slack
    case signal
    case imessage
    case matrix
    case irc
    case bluebubbles    // Recommended iMessage bridge (BlueBubbles)
    case googleChat     // Google Chat
    case microsoftTeams // Microsoft Teams
    case webchat        // OpenClaw WebChat
    case zalo

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
        case .bluebubbles: "iMessage (BlueBubbles)"
        case .googleChat: "Google Chat"
        case .microsoftTeams: "Microsoft Teams"
        case .webchat: "WebChat"
        case .zalo: "Zalo"
        }
    }
}

// MARK: - Channel & Message

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

// MARK: - Session (O1)

/// Maps to agent:{agentId}:{provider}:{scope}:{identifier}
struct OpenClawSession: Identifiable, Codable, Sendable {
    let id: String           // session key e.g. "agent:main:whatsapp:dm:+15555550123"
    let agentId: String      // "main", "work", "personal", etc.
    let channelType: String  // "whatsapp", "telegram", etc.
    let scope: String        // "dm", "group", "channel"
    let identifier: String   // "+15555550123", group ID, etc.
    let lastActivity: Date?
    var transcript: [OpenClawMessage]

    init(id: String, agentId: String, channelType: String, scope: String,
         identifier: String, lastActivity: Date? = nil, transcript: [OpenClawMessage] = []) {
        self.id = id
        self.agentId = agentId
        self.channelType = channelType
        self.scope = scope
        self.identifier = identifier
        self.lastActivity = lastActivity
        self.transcript = transcript
    }
}

// MARK: - Agent (O1)

/// Named agent configured in the Gateway
struct OpenClawAgent: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let model: String
    let isDefault: Bool
    var sessionCount: Int
}

// MARK: - Canvas (O1)

/// Agent-driven visual workspace state
struct OpenClawCanvasState: Codable, Sendable {
    let html: String
    let a2uiVersion: Int
    let updatedAt: Date
}

// MARK: - Node Capabilities (O1)

/// Capabilities available on paired nodes (iOS, Android, macOS companion)
enum OpenClawNodeCapability: String, Codable, Sendable {
    case cameraSnap       = "node.camera.snap"
    case cameraClip       = "node.camera.clip"
    case screenRecord     = "node.screen.record"
    case locationGet      = "node.location.get"
    case notificationSend = "node.notification.send"
    case systemRun        = "node.system.run"     // macOS only
    case systemNotify     = "node.system.notify"  // macOS only
}

/// Paired node (remote device)
struct OpenClawNode: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let platform: String  // "ios", "android", "macos"
    let capabilities: [OpenClawNodeCapability]
    let lastSeen: Date?
}

// MARK: - Cron Jobs (O1)

/// Scheduled task managed by Gateway
struct OpenClawCronJob: Identifiable, Codable, Sendable {
    let id: String
    let expression: String   // cron expression e.g. "0 9 * * 1-5"
    let agentId: String
    let message: String      // injected task message
    var enabled: Bool
    let nextRun: Date?
}

// MARK: - Gateway Status (O1)

struct OpenClawGatewayStatus: Codable, Sendable {
    let version: String
    let protocolVersion: Int
    let uptime: TimeInterval
    let connectedNodes: Int
    let activeChannels: Int
    let memoryUsedMB: Double

    enum CodingKeys: String, CodingKey {
        case version
        case protocolVersion = "protocol"
        case uptime
        case connectedNodes
        case activeChannels
        case memoryUsedMB
    }
}

// MARK: - Memory (O1)

struct OpenClawMemoryResult: Identifiable, Codable, Sendable {
    let id: String
    let content: String
    let score: Double
    let tags: [String]
    let createdAt: Date?
}

// MARK: - Security Audit (O1)

struct OpenClawSecurityAuditResult: Codable, Sendable {
    let riskScore: Double      // 0.0 (safe) – 10.0 (critical)
    let findings: [OpenClawSecurityFinding]
    let auditedAt: Date
    let passed: Bool
}

struct OpenClawSecurityFinding: Identifiable, Codable, Sendable {
    let id: String
    let severity: Severity
    let category: String
    let description: String
    let recommendation: String?

    enum Severity: String, Codable, Sendable {
        case info, low, medium, high, critical
    }
}

// MARK: - Gateway Commands (O0 / O1)

/// Commands sent to OpenClaw Gateway (proper req/res protocol)
enum OpenClawGatewayCommand: Sendable {
    // Messaging
    case listChannels
    case sendMessage(channelID: String, text: String)
    case sendReply(channelID: String, text: String, replyToID: String)
    case markRead(channelID: String, messageID: String)
    case ping

    // Sessions (O1)
    case listSessions(agentId: String?)
    case getSession(sessionKey: String)
    case resetSession(sessionKey: String)
    case getHistory(sessionKey: String, limit: Int, before: Date?)

    // Agents (O1)
    case listAgents
    case getAgentConfig(agentId: String)

    // Canvas (O1)
    case getCanvas(agentId: String)
    case setCanvas(agentId: String, html: String)

    // Nodes (O1)
    case listNodes
    case invokeNode(nodeId: String, capability: OpenClawNodeCapability, params: [String: Any])

    // Config (O1)
    case getConfig(path: String?)
    case setConfig(path: String, value: Any)

    // Cron (O1)
    case listCronJobs(agentId: String?)
    case createCronJob(expression: String, agentId: String, message: String)
    case deleteCronJob(id: String)
    case enableCronJob(id: String, enabled: Bool)

    // Memory (O1)
    case searchMemory(agentId: String, query: String, limit: Int)
    case addMemory(agentId: String, content: String, tags: [String])

    // Status (O1)
    case getGatewayStatus
    case runSecurityAudit

    var method: String {
        switch self {
        case .listChannels:        "channels.list"
        case .sendMessage:         "message.send"
        case .sendReply:           "message.reply"
        case .markRead:            "message.markRead"
        case .ping:                "ping"
        case .listSessions:        "sessions.list"
        case .getSession:          "session.get"
        case .resetSession:        "session.reset"
        case .getHistory:          "session.history"
        case .listAgents:          "agents.list"
        case .getAgentConfig:      "agent.config.get"
        case .getCanvas:           "canvas.get"
        case .setCanvas:           "canvas.set"
        case .listNodes:           "nodes.list"
        case .invokeNode:          "node.invoke"
        case .getConfig:           "config.get"
        case .setConfig:           "config.set"
        case .listCronJobs:        "cron.list"
        case .createCronJob:       "cron.create"
        case .deleteCronJob:       "cron.delete"
        case .enableCronJob:       "cron.enable"
        case .searchMemory:        "memory.search"
        case .addMemory:           "memory.add"
        case .getGatewayStatus:    "gateway.status"
        case .runSecurityAudit:    "security.audit"
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    var params: [String: Any] {
        switch self {
        case .listChannels, .ping, .listAgents, .getGatewayStatus, .runSecurityAudit:
            return [:]
        case let .sendMessage(channelID, text):
            return ["channel_id": channelID, "text": text]
        case let .sendReply(channelID, text, replyToID):
            return ["channel_id": channelID, "text": text, "reply_to": replyToID]
        case let .markRead(channelID, messageID):
            return ["channel_id": channelID, "message_id": messageID]
        case let .listSessions(agentId):
            return agentId.map { ["agent_id": $0] } ?? [:]
        case let .getSession(key):
            return ["session_key": key]
        case let .resetSession(key):
            return ["session_key": key]
        case let .getHistory(key, limit, before):
            var p: [String: Any] = ["session_key": key, "limit": limit]
            if let b = before { p["before"] = b.timeIntervalSince1970 }
            return p
        case let .getAgentConfig(agentId):
            return ["agent_id": agentId]
        case let .getCanvas(agentId):
            return ["agent_id": agentId]
        case let .setCanvas(agentId, html):
            return ["agent_id": agentId, "html": html]
        case .listNodes:
            return [:]
        case let .invokeNode(nodeId, capability, extraParams):
            var p: [String: Any] = ["node_id": nodeId, "capability": capability.rawValue]
            p.merge(extraParams) { $1 }
            return p
        case let .getConfig(path):
            return path.map { ["path": $0] } ?? [:]
        case let .setConfig(path, value):
            return ["path": path, "value": value]
        case let .listCronJobs(agentId):
            return agentId.map { ["agent_id": $0] } ?? [:]
        case let .createCronJob(expression, agentId, message):
            return ["expression": expression, "agent_id": agentId, "message": message]
        case let .deleteCronJob(id):
            return ["id": id]
        case let .enableCronJob(id, enabled):
            return ["id": id, "enabled": enabled]
        case let .searchMemory(agentId, query, limit):
            return ["agent_id": agentId, "query": query, "limit": limit]
        case let .addMemory(agentId, content, tags):
            return ["agent_id": agentId, "content": content, "tags": tags]
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}

// MARK: - Gateway Events (O1)

/// Events received from OpenClaw Gateway
enum OpenClawGatewayEvent: Sendable {
    // Connection
    case connected
    case disconnected(reason: String?)
    case error(String)
    case pong

    // Messages
    case messageReceived(OpenClawMessage)
    case channelUpdated(OpenClawChannel)

    // Auth handshake (O1)
    case authChallenge(nonce: String)
    case authSuccess(deviceToken: String?)

    // Sessions (O1)
    case sessionCreated(OpenClawSession)
    case sessionUpdated(OpenClawSession)

    // Canvas (O1)
    case canvasUpdated(OpenClawCanvasState)

    // Nodes (O1)
    case nodeStatus(nodeId: String, capabilities: [OpenClawNodeCapability])

    // Cron (O1)
    case cronFired(OpenClawCronJob)

    // Gateway meta (O1)
    case gatewayStatus(OpenClawGatewayStatus)
    case configUpdated
}

// MARK: - Connection State

enum OpenClawConnectionState: String, Sendable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case reconnecting
    case failed
}

// MARK: - Errors

enum OpenClawError: Error, LocalizedError {
    case notConnected
    case encodingFailed
    case decodingFailed(String)
    case gatewayNotRunning
    case authenticationFailed
    case requestTimeout
    case channelNotFound(String)
    case gatewayError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Not connected to OpenClaw Gateway"
        case .encodingFailed:
            "Failed to encode message"
        case let .decodingFailed(detail):
            "Failed to decode gateway response: \(detail)"
        case .gatewayNotRunning:
            "OpenClaw Gateway is not running. Start it with: openclaw gateway start"
        case .authenticationFailed:
            "OpenClaw authentication failed"
        case .requestTimeout:
            "Gateway request timed out"
        case let .channelNotFound(id):
            "Channel not found: \(id)"
        case let .gatewayError(code, message):
            "Gateway error \(code): \(message)"
        }
    }
}
