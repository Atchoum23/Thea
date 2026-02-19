import Foundation
import OSLog

// MARK: - Discord Connector
// Discord Gateway WebSocket v10 + REST API. No external dependencies.
// Credential: botToken (Bot section of Discord Developer Portal).
// Intents: GUILD_MESSAGES (512) + MESSAGE_CONTENT (32768) + DIRECT_MESSAGES (4096) = 37376

actor DiscordConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .discord
    private(set) var isConnected = false
    var credentials: MessagingCredentials

    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var webSocket: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var seqNum: Int?
    private let logger = Logger(subsystem: "ai.thea.app", category: "DiscordConnector")

    private let gatewayURL = "wss://gateway.discord.gg/?v=10&encoding=json"
    private let restBase = "https://discord.com/api/v10"
    private let intents = 37376  // GUILD_MESSAGES | MESSAGE_CONTENT | DIRECT_MESSAGES

    init(credentials: MessagingCredentials) {
        self.credentials = credentials
    }

    // MARK: - Connect

    func connect() async throws {
        guard let token = credentials.botToken, !token.isEmpty else {
            throw MessagingError.missingCredentials(platform: .discord, field: "botToken")
        }

        webSocket = URLSession.shared.webSocketTask(with: URL(string: gatewayURL)!)  // swiftlint:disable:this force_unwrapping
        webSocket?.resume()
        isConnected = true
        logger.info("Discord WebSocket connecting…")

        receiveTask = Task { await receiveLoop(token: token) }
    }

    // MARK: - Receive Loop

    private func receiveLoop(token: String) async {
        while !Task.isCancelled, let ws = webSocket {
            do {
                let msg = try await ws.receive()
                guard case .string(let text) = msg,
                      let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                seqNum = json["s"] as? Int ?? seqNum

                switch json["op"] as? Int {
                case 10:  // Hello
                    let interval = (((json["d"] as? [String: Any])?["heartbeat_interval"] as? Double) ?? 41250) / 1000.0
                    heartbeatTask?.cancel()
                    heartbeatTask = Task { [self] in await heartbeatLoop(interval: interval) }
                    await identify(token: token)

                case 0:  // Dispatch
                    if (json["t"] as? String) == "MESSAGE_CREATE" {
                        await handleMessageCreate(json["d"] as? [String: Any])
                    }

                case 11:  // Heartbeat ACK
                    logger.debug("Discord heartbeat acknowledged")

                case 9:  // Invalid Session — reconnect
                    logger.warning("Discord invalid session, reconnecting…")
                    try? await Task.sleep(for: .seconds(5))
                    await identify(token: token)

                default:
                    break
                }
            } catch {
                if isConnected {
                    logger.error("Discord receive error: \(error.localizedDescription)")
                    isConnected = false
                }
                return
            }
        }
    }

    private func handleMessageCreate(_ data: [String: Any]?) async {
        guard let data,
              let content = data["content"] as? String, !content.isEmpty,
              let channelId = data["channel_id"] as? String,
              let author = data["author"] as? [String: Any],
              let authorId = author["id"] as? String,
              let msgId = data["id"] as? String,
              (author["bot"] as? Bool) != true  // skip bot messages
        else { return }

        let isGuildMessage = data["guild_id"] != nil

        await messageHandler?(TheaGatewayMessage(
            id: msgId,
            platform: .discord,
            chatId: channelId,
            senderId: authorId,
            senderName: author["global_name"] as? String ?? author["username"] as? String ?? "Unknown",
            content: content,
            timestamp: Date(),
            isGroup: isGuildMessage
        ))
    }

    // MARK: - Heartbeat

    private func heartbeatLoop(interval: Double) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            guard let ws = webSocket else { return }
            let payload: [String: Any] = ["op": 1, "d": seqNum as Any]
            if let data = try? JSONSerialization.data(withJSONObject: payload),
               let str = String(data: data, encoding: .utf8) {
                try? await ws.send(.string(str))
            }
        }
    }

    // MARK: - Identify

    private func identify(token: String) async {
        guard let ws = webSocket else { return }
        let payload: [String: Any] = [
            "op": 2,
            "d": [
                "token": token,
                "intents": intents,
                "properties": ["os": "macOS", "browser": "Thea", "device": "Thea"]
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            try? await ws.send(.string(str))
        }
    }

    // MARK: - Send

    func send(_ message: OutboundMessagingMessage) async throws {
        guard let token = credentials.botToken, !token.isEmpty else {
            throw MessagingError.notConnected(platform: .discord)
        }

        var req = URLRequest(url: URL(string: "\(restBase)/channels/\(message.chatId)/messages")!)  // swiftlint:disable:this force_unwrapping
        req.httpMethod = "POST"
        req.setValue("Bot \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["content": message.content]
        if let replyId = message.replyToId {
            body["message_reference"] = ["message_id": replyId]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode > 299 {
            throw MessagingError.sendFailed(platform: .discord, underlying: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        heartbeatTask?.cancel()
        receiveTask?.cancel()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        logger.info("Disconnected from Discord")
    }

    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void) {
        messageHandler = handler
    }
}
