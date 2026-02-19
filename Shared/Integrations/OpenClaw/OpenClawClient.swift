import Foundation
import OSLog

// MARK: - OpenClaw Client (unchanged — connects to Thea's own WS server)
// WebSocket client that connects to Thea's built-in TheaGatewayWSServer at ws://127.0.0.1:18789.
// No longer connects to an external OpenClaw daemon — Thea IS the gateway (Phase O upgrade).
// Connection URL, reconnect logic, and message parsing remain identical.

actor OpenClawClient {
    private let logger = Logger(subsystem: "com.thea.app", category: "OpenClawClient")

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var eventContinuation: AsyncStream<OpenClawGatewayEvent>.Continuation?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private(set) var connectionState: OpenClawConnectionState = .disconnected
    private(set) var gatewayURL: URL

    init(gatewayURL: URL = URL(string: "ws://127.0.0.1:18789")!) { // swiftlint:disable:this force_unwrapping
        self.gatewayURL = gatewayURL
    // periphery:ignore - Reserved: logger property reserved for future feature activation
    }

    // periphery:ignore - Reserved: session property reserved for future feature activation
    // periphery:ignore - Reserved: eventContinuation property reserved for future feature activation
    // periphery:ignore - Reserved: reconnectAttempts property reserved for future feature activation
    // periphery:ignore - Reserved: maxReconnectAttempts property reserved for future feature activation
    // MARK: - Connection

    func connect() -> AsyncStream<OpenClawGatewayEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
            Task { self.startConnection() }

            continuation.onTermination = { _ in
                Task { await self.disconnect() }
            }
        // periphery:ignore - Reserved: connect() instance method reserved for future feature activation
        }
    }

    private func startConnection() {
        guard connectionState != .connected else { return }

        connectionState = .connecting
        logger.info("Connecting to OpenClaw Gateway at \(self.gatewayURL.absoluteString)")

        let config = URLSessionConfiguration.default
        // periphery:ignore - Reserved: startConnection() instance method reserved for future feature activation
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)

        webSocket = session?.webSocketTask(with: gatewayURL)
        webSocket?.resume()

        connectionState = .connected
        reconnectAttempts = 0
        eventContinuation?.yield(.connected)
        logger.info("Connected to OpenClaw Gateway")

        Task { await receiveMessages() }
    }

    func disconnect() {
        connectionState = .disconnected
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        // periphery:ignore - Reserved: disconnect() instance method reserved for future feature activation
        eventContinuation?.yield(.disconnected(reason: "Manual disconnect"))
        eventContinuation?.finish()
        eventContinuation = nil
    }

    // MARK: - Send Commands

    func send(command: OpenClawGatewayCommand) async throws {
        guard let ws = webSocket, connectionState == .connected else {
            throw OpenClawError.notConnected
        }

        let rpcID = UUID().uuidString
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": rpcID,
            "method": command.method,
            "params": command.params
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw OpenClawError.encodingFailed
        }

        try await ws.send(.string(json))
    }

    func sendMessage(channelID: String, text: String) async throws {
        try await send(command: .sendMessage(channelID: channelID, text: text))
    }

    func listChannels() async throws {
        try await send(command: .listChannels)
    }

    // MARK: - Receive

// periphery:ignore - Reserved: listChannels() instance method reserved for future feature activation

    private func receiveMessages() async {
        guard let ws = webSocket else { return }

        while connectionState == .connected {
            // periphery:ignore - Reserved: receiveMessages() instance method reserved for future feature activation
            do {
                let message = try await ws.receive()
                switch message {
                case let .string(text):
                    if let data = text.data(using: .utf8) {
                        parseGatewayMessage(data)
                    }
                case let .data(data):
                    parseGatewayMessage(data)
                @unknown default:
                    break
                }
            } catch {
                if connectionState == .connected {
                    logger.error("WebSocket receive error: \(error.localizedDescription)")
                    eventContinuation?.yield(.disconnected(reason: error.localizedDescription))
                    await attemptReconnect()
                }
                return
            }
        }
    }

    private func parseGatewayMessage(_ data: Data) {
        let json: [String: Any]
        do {
            // periphery:ignore - Reserved: parseGatewayMessage(_:) instance method reserved for future feature activation
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.error("Gateway message is not a JSON object")
                return
            }
            json = parsed
        } catch {
            logger.error("Failed to parse gateway message: \(error.localizedDescription)")
            return
        }

        // Handle JSON-RPC notification (no id = event push)
        if let method = json["method"] as? String {
            switch method {
            case "message.received":
                if let params = json["params"] as? [String: Any],
                   let message = parseIncomingMessage(params)
                {
                    eventContinuation?.yield(.messageReceived(message))
                }
            case "channel.updated":
                if let params = json["params"] as? [String: Any],
                   let channel = parseChannel(params)
                {
                    eventContinuation?.yield(.channelUpdated(channel))
                }
            default:
                logger.debug("Unknown event method: \(method)")
            }
        }

        // Handle pong
        if let result = json["result"] as? String, result == "pong" {
            eventContinuation?.yield(.pong)
        }
    }

    // MARK: - Reconnection

    private func attemptReconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            // periphery:ignore - Reserved: attemptReconnect() instance method reserved for future feature activation
            connectionState = .failed
            eventContinuation?.yield(.error("Max reconnection attempts reached"))
            return
        }

        connectionState = .reconnecting
        reconnectAttempts += 1

        // Exponential backoff: 1s, 2s, 4s, 8s, ..., max 30s
        let delay = min(pow(2.0, Double(reconnectAttempts - 1)), 30.0)
        logger.info("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")

        do {
            try await Task.sleep(for: .seconds(delay))
        } catch {
            logger.debug("Reconnect sleep cancelled: \(error.localizedDescription)")
        }
        startConnection()
    }

    // MARK: - Parsing Helpers

    private func parseIncomingMessage(_ params: [String: Any]) -> OpenClawMessage? {
        // periphery:ignore - Reserved: parseIncomingMessage(_:) instance method reserved for future feature activation
        guard let id = params["id"] as? String,
              let channelID = params["channel_id"] as? String,
              let platformStr = params["platform"] as? String,
              let platform = OpenClawPlatform(rawValue: platformStr),
              let senderID = params["sender_id"] as? String,
              let content = params["content"] as? String
        else { return nil }

        return OpenClawMessage(
            id: id,
            channelID: channelID,
            platform: platform,
            senderID: senderID,
            senderName: params["sender_name"] as? String,
            content: content,
            timestamp: Date(),
            attachments: [],
            replyToMessageID: params["reply_to"] as? String,
            isFromBot: params["is_bot"] as? Bool ?? false
        )
    }

    // periphery:ignore - Reserved: parseChannel(_:) instance method reserved for future feature activation
    private func parseChannel(_ params: [String: Any]) -> OpenClawChannel? {
        guard let id = params["id"] as? String,
              let platformStr = params["platform"] as? String,
              let platform = OpenClawPlatform(rawValue: platformStr),
              let name = params["name"] as? String
        else { return nil }

        return OpenClawChannel(
            id: id,
            platform: platform,
            name: name,
            isGroup: params["is_group"] as? Bool ?? false,
            participantCount: params["participant_count"] as? Int,
            lastActivityAt: nil
        )
    }
}

// OpenClawError is defined in OpenClawTypes.swift (canonical location with full case list)
