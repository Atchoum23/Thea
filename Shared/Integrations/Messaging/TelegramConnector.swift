import Foundation
import OSLog

// MARK: - Telegram Connector
// Connects to Telegram Bot API via long-polling (getUpdates?timeout=30).
// No external dependencies — pure URLSession.
// Credential: botToken from @BotFather.

actor TelegramConnector: MessagingPlatformConnector {
    // periphery:ignore - Reserved: platform property reserved for future feature activation
    let platform: MessagingPlatform = .telegram
    private(set) var isConnected = false
    var credentials: MessagingCredentials

    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var pollingTask: Task<Void, Never>?
    private let apiBase = "https://api.telegram.org"
    private let logger = Logger(subsystem: "ai.thea.app", category: "TelegramConnector")

    init(credentials: MessagingCredentials) {
        self.credentials = credentials
    }

    // MARK: - Connect

    func connect() async throws {
        guard let token = credentials.botToken, !token.isEmpty else {
            throw MessagingError.missingCredentials(platform: .telegram, field: "botToken")
        }

        // Verify token with getMe
        let url = URL(string: "\(apiBase)/bot\(token)/getMe")!  // swiftlint:disable:this force_unwrapping
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(TGBoolResponse.self, from: data)
        guard result.ok else {
            throw MessagingError.authenticationFailed(platform: .telegram)
        }

        isConnected = true
        logger.info("Connected to Telegram as bot")
        pollingTask = Task { await pollLoop(token: token) }
    }

    // MARK: - Polling Loop

    private func pollLoop(token: String) async {
        var offset = 0

        while !Task.isCancelled && isConnected {
            guard let url = URL(string: "\(apiBase)/bot\(token)/getUpdates?offset=\(offset)&timeout=30&allowed_updates=[\"message\"]") else {
                try? await Task.sleep(for: .seconds(5))
                continue
            }

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 35  // longer than Telegram's 30s timeout
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(TGUpdatesResponse.self, from: data)

                guard response.ok, let updates = response.result else { continue }

                for update in updates {
                    offset = max(offset, update.updateId + 1)
                    guard let msg = update.message, let text = msg.text, !text.isEmpty else { continue }

                    let gatewayMsg = TheaGatewayMessage(
                        id: "\(update.updateId)",
                        platform: .telegram,
                        chatId: "\(msg.chat.id)",
                        senderId: "\(msg.from?.id ?? 0)",
                        senderName: msg.from.map { [$0.firstName, $0.lastName].compactMap { $0 }.joined(separator: " ") } ?? "Unknown",
                        content: text,
                        timestamp: Date(timeIntervalSince1970: Double(msg.date)),
                        isGroup: msg.chat.type != "private"
                    )
                    await messageHandler?(gatewayMsg)
                }
            } catch {
                logger.error("Telegram poll error: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    // MARK: - Send

    func send(_ message: OutboundMessagingMessage) async throws {
        guard let token = credentials.botToken, !token.isEmpty else {
            throw MessagingError.notConnected(platform: .telegram)
        }

        var request = URLRequest(url: URL(string: "\(apiBase)/bot\(token)/sendMessage")!)  // swiftlint:disable:this force_unwrapping
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["chat_id": message.chatId, "text": message.content]
        if let replyId = message.replyToId, let intId = Int(replyId) {
            body["reply_to_message_id"] = intId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MessagingError.sendFailed(platform: .telegram, underlying: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        pollingTask?.cancel()
        pollingTask = nil
        isConnected = false
        logger.info("Disconnected from Telegram")
    }

    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void) {
        messageHandler = handler
    }

    // MARK: - Telegram API Types

    private struct TGBoolResponse: Decodable { let ok: Bool }

    private struct TGUpdatesResponse: Decodable {
        let ok: Bool
        let result: [TGUpdate]?
    }

    private struct TGUpdate: Decodable {
        let updateId: Int
        let message: TGMessage?
        enum CodingKeys: String, CodingKey {
            case updateId = "update_id"; case message
        }
    }

    private struct TGMessage: Decodable {
        let date: Int
        let chat: TGChat
        let from: TGUser?
        let text: String?
    }

    private struct TGChat: Decodable {
        let id: Int64
        let type: String
    }

    private struct TGUser: Decodable {
        let id: Int64
        let firstName: String
        let lastName: String?
        enum CodingKeys: String, CodingKey {
            case id; case firstName = "first_name"; case lastName = "last_name"
        }
    }
}
