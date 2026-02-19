import Foundation
import OSLog

// MARK: - BlueBubbles Connector (iMessage)
// iMessage via BlueBubbles local HTTP + WebSocket API.
// Requires BlueBubbles server running on a Mac that has iMessage.
// Credentials: serverUrl (e.g. "http://localhost:1234") + apiKey (BlueBubbles password).

actor BlueBubblesConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .imessage
    // periphery:ignore - Reserved: platform property reserved for future feature activation
    private(set) var isConnected = false
    var credentials: MessagingCredentials

    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "ai.thea.app", category: "BlueBubblesConnector")

    init(credentials: MessagingCredentials) {
        self.credentials = credentials
    }

    // MARK: - Connect

    func connect() async throws {
        guard let serverUrl = credentials.serverUrl, !serverUrl.isEmpty,
              let apiKey = credentials.apiKey, !apiKey.isEmpty
        else {
            throw MessagingError.missingCredentials(platform: .imessage, field: "serverUrl + apiKey")
        }

        // Verify server is reachable
        let pingUrl = URL(string: "\(serverUrl)/api/v1/ping")!  // swiftlint:disable:this force_unwrapping
        var pingReq = URLRequest(url: pingUrl)
        pingReq.setValue(apiKey, forHTTPHeaderField: "password")
        pingReq.timeoutInterval = 5

        do {
            let (_, resp) = try await URLSession.shared.data(for: pingReq)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw MessagingError.authenticationFailed(platform: .imessage)
            }
        } catch let error as MessagingError {
            throw error
        } catch {
            throw MessagingError.platformUnavailable(platform: .imessage, reason: "BlueBubbles server unreachable at \(serverUrl)")
        }

        // Connect WebSocket for real-time events
        let wsBase = serverUrl
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        let wsUrlStr = "\(wsBase)/api/v1/socket?password=\(apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey)"

        guard let wsUrl = URL(string: wsUrlStr) else {
            throw MessagingError.platformUnavailable(platform: .imessage, reason: "Invalid BlueBubbles WebSocket URL")
        }

        webSocket = URLSession.shared.webSocketTask(with: wsUrl)
        webSocket?.resume()
        isConnected = true
        logger.info("Connected to BlueBubbles at \(serverUrl)")

        receiveTask = Task { [serverUrl, apiKey] in await receiveLoop(serverUrl: serverUrl, apiKey: apiKey) }
    }

    // MARK: - Receive Loop

    // periphery:ignore - Reserved: serverUrl parameter kept for API compatibility
    private func receiveLoop(serverUrl: String, apiKey: String) async {
        while !Task.isCancelled, let ws = webSocket {
            do {
                let msg = try await ws.receive()
                guard case .string(let text) = msg,
                      let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                guard (json["event"] as? String) == "new-message",
                      let msgData = json["data"] as? [String: Any],
                      let content = msgData["text"] as? String, !content.isEmpty,
                      (msgData["isFromMe"] as? Bool) != true  // skip outgoing messages
                else { continue }

                // BlueBubbles chat GUID format: "iMessage;-;+15555550123" or "iMessage;+;chatGuid"
                let chatGuid = msgData["chatGuid"] as? String
                             ?? (msgData["chats"] as? [[String: Any]])?.first?["guid"] as? String
                             ?? "unknown"

                await messageHandler?(TheaGatewayMessage(
                    id: msgData["guid"] as? String ?? UUID().uuidString,
                    platform: .imessage,
                    chatId: chatGuid,
                    senderId: msgData["handle"] as? String
                           ?? msgData["handleString"] as? String
                           ?? "unknown",
                    senderName: msgData["handleString"] as? String ?? "iMessage Contact",
                    content: content,
                    timestamp: Date(),
                    isGroup: (msgData["isGroup"] as? Bool) ?? chatGuid.contains(";+;")
                ))
            } catch {
                if isConnected {
                    logger.error("BlueBubbles receive error: \(error.localizedDescription)")
                    isConnected = false
                }
                return
            }
        }
    }

    // MARK: - Send

    func send(_ message: OutboundMessagingMessage) async throws {
        guard let serverUrl = credentials.serverUrl, let apiKey = credentials.apiKey else {
            throw MessagingError.notConnected(platform: .imessage)
        }

        var req = URLRequest(url: URL(string: "\(serverUrl)/api/v1/message/text")!)  // swiftlint:disable:this force_unwrapping
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "password")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "chatGuid": message.chatId,
            "message": message.content
        ])

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode > 299 {
            throw MessagingError.sendFailed(platform: .imessage, underlying: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        receiveTask?.cancel()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        logger.info("Disconnected from BlueBubbles")
    }

    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void) {
        messageHandler = handler
    }
}
