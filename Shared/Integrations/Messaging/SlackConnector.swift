import Foundation
import OSLog

// MARK: - Slack Connector
// Slack via Socket Mode WebSocket. No public URL required.
// Credentials: botToken (xoxb-…) + apiKey (App-Level Token xapp-… for Socket Mode).
// Socket Mode delivers events via WSS; responses sent via chat.postMessage REST.

actor SlackConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .slack
    private(set) var isConnected = false
    var credentials: MessagingCredentials

    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "ai.thea.app", category: "SlackConnector")

    init(credentials: MessagingCredentials) {
        self.credentials = credentials
    }

    // MARK: - Connect

    func connect() async throws {
        guard let appToken = credentials.apiKey, appToken.hasPrefix("xapp-") else {
            throw MessagingError.missingCredentials(platform: .slack, field: "apiKey (xapp- token for Socket Mode)")
        }

        // Open Socket Mode connection
        var req = URLRequest(url: URL(string: "https://slack.com/api/apps.connections.open")!)  // swiftlint:disable:this force_unwrapping
        req.httpMethod = "POST"
        req.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let wssUrl = json["url"] as? String,
              (json["ok"] as? Bool) == true
        else {
            throw MessagingError.authenticationFailed(platform: .slack)
        }

        webSocket = URLSession.shared.webSocketTask(with: URL(string: wssUrl)!)  // swiftlint:disable:this force_unwrapping
        webSocket?.resume()
        isConnected = true
        logger.info("Connected to Slack Socket Mode")

        receiveTask = Task { await receiveLoop() }
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        while !Task.isCancelled, let ws = webSocket {
            do {
                let msg = try await ws.receive()
                guard case .string(let text) = msg,
                      let data = text.data(using: .utf8),
                      let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                // ACK every envelope immediately
                if let envelopeId = envelope["envelope_id"] as? String {
                    let ack = "{\"envelope_id\":\"\(envelopeId)\"}"
                    try? await ws.send(.string(ack))
                }

                // Handle disconnection events
                if (envelope["type"] as? String) == "disconnect" {
                    logger.warning("Slack Socket Mode disconnect event received")
                    isConnected = false
                    return
                }

                // Handle message events
                guard (envelope["type"] as? String) == "events_api",
                      let payload = envelope["payload"] as? [String: Any],
                      let event = payload["event"] as? [String: Any],
                      (event["type"] as? String) == "message",
                      (event["subtype"] as? String) == nil,  // skip subtypes (bot_message, etc.)
                      let text = event["text"] as? String, !text.isEmpty,
                      let channelId = event["channel"] as? String,
                      let userId = event["user"] as? String,
                      let ts = event["ts"] as? String
                else { continue }

                await messageHandler?(TheaGatewayMessage(
                    id: ts,
                    platform: .slack,
                    chatId: channelId,
                    senderId: userId,
                    senderName: userId,  // Slack doesn't include username in events
                    content: text,
                    timestamp: Date(),
                    isGroup: channelId.hasPrefix("C")  // C = channel, D = DM, G = group DM
                ))
            } catch {
                if isConnected {
                    logger.error("Slack receive error: \(error.localizedDescription)")
                    isConnected = false
                }
                return
            }
        }
    }

    // MARK: - Send

    func send(_ message: OutboundMessagingMessage) async throws {
        guard let botToken = credentials.botToken, !botToken.isEmpty else {
            throw MessagingError.notConnected(platform: .slack)
        }

        var req = URLRequest(url: URL(string: "https://slack.com/api/chat.postMessage")!)  // swiftlint:disable:this force_unwrapping
        req.httpMethod = "POST"
        req.setValue("Bearer \(botToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["channel": message.chatId, "text": message.content]
        if let replyId = message.replyToId {
            body["thread_ts"] = replyId  // Slack threads via thread_ts
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["ok"] as? Bool) == true
        else {
            let errMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "unknown"
            throw MessagingError.sendFailed(platform: .slack, underlying: errMsg)
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        receiveTask?.cancel()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        logger.info("Disconnected from Slack")
    }

    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void) {
        messageHandler = handler
    }
}
