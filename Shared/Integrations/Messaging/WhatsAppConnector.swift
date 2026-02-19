import Foundation
import OSLog

// MARK: - WhatsApp Connector
// WhatsApp via Meta Cloud API v21.0.
// Receives webhook events via TheaGatewayWSServer (Thea handles the HTTP POST from Meta).
// Sends messages via REST (POST /messages).
// Credentials: botToken (access token) + apiKey (phone number ID) + webhookSecret (verify token).
// Note: Meta requires your server to be publicly reachable for webhook delivery.
// For local dev, use ngrok or Cloudflare Tunnel pointing to port 18789.

actor WhatsAppConnector: MessagingPlatformConnector {
    // periphery:ignore - Reserved: platform property — reserved for future feature activation
    let platform: MessagingPlatform = .whatsapp
    private(set) var isConnected = false
    // periphery:ignore - Reserved: platform property reserved for future feature activation
    var credentials: MessagingCredentials

    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private let apiBase = "https://graph.facebook.com/v21.0"
    private let logger = Logger(subsystem: "ai.thea.app", category: "WhatsAppConnector")

    init(credentials: MessagingCredentials) {
        self.credentials = credentials
    }

    // MARK: - Connect
    // WhatsApp uses webhooks for inbound — no persistent connection to maintain.
    // We validate credentials by calling the API, then register for webhook delivery.

    func connect() async throws {
        guard let token = credentials.botToken, !token.isEmpty,
              let phoneId = credentials.apiKey, !phoneId.isEmpty
        else {
            throw MessagingError.missingCredentials(platform: .whatsapp, field: "botToken + apiKey (phone number ID)")
        }

        // Verify credentials
        let url = URL(string: "\(apiBase)/\(phoneId)?fields=display_phone_number,status&access_token=\(token)")!  // swiftlint:disable:this force_unwrapping
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["id"] != nil
            else {
                throw MessagingError.authenticationFailed(platform: .whatsapp)
            }
            let displayNumber = json["display_phone_number"] as? String ?? phoneId
            logger.info("WhatsApp connected: \(displayNumber)")
        } catch let err as MessagingError {
            throw err
        } catch {
            throw MessagingError.authenticationFailed(platform: .whatsapp)
        }

        isConnected = true
        // Webhook processing happens via TheaGatewayWSServer → processWebhook()
    }

    // MARK: - Webhook Processing
    // Called by TheaGatewayWSServer when it receives a POST from Meta's servers.

    // periphery:ignore - Reserved: processWebhook(body:) instance method — reserved for future feature activation
    func processWebhook(body: Data) async {
        // periphery:ignore - Reserved: processWebhook(body:) instance method reserved for future feature activation
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let entry = (json["entry"] as? [[String: Any]])?.first,
              let changes = (entry["changes"] as? [[String: Any]])?.first,
              let value = changes["value"] as? [String: Any]
        else { return }

        // Handle message events
        guard let messages = value["messages"] as? [[String: Any]],
              let msg = messages.first,
              (msg["type"] as? String) == "text",
              let text = (msg["text"] as? [String: Any])?["body"] as? String,
              !text.isEmpty
        else { return }

        // Resolve sender name from contacts
        let contacts = value["contacts"] as? [[String: Any]]
        let senderPhone = msg["from"] as? String ?? "unknown"
        let senderName = (contacts?.first?["profile"] as? [String: Any])?["name"] as? String
                       ?? senderPhone

        await messageHandler?(TheaGatewayMessage(
            id: msg["id"] as? String ?? UUID().uuidString,
            platform: .whatsapp,
            chatId: senderPhone,
            senderId: senderPhone,
            senderName: senderName,
            content: text,
            timestamp: Date(),
            isGroup: false  // WhatsApp group support is a future enhancement
        ))
    }

    // periphery:ignore - Reserved: verifyWebhook(challenge:mode:token:) instance method reserved for future feature activation
    /// Handle Meta webhook verification (GET request with hub.challenge).
    func verifyWebhook(challenge: String, mode: String, token: String) -> String? {
        guard mode == "subscribe",
              token == credentials.webhookSecret else { return nil }
        return challenge
    }

    // MARK: - Send

    func send(_ message: OutboundMessagingMessage) async throws {
        guard let token = credentials.botToken, !token.isEmpty,
              let phoneId = credentials.apiKey, !phoneId.isEmpty
        else {
            throw MessagingError.notConnected(platform: .whatsapp)
        }

        var req = URLRequest(url: URL(string: "\(apiBase)/\(phoneId)/messages")!)  // swiftlint:disable:this force_unwrapping
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "messaging_product": "whatsapp",
            "to": message.chatId,
            "type": "text",
            "text": ["body": message.content, "preview_url": false]
        ])

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode > 299 {
            throw MessagingError.sendFailed(platform: .whatsapp, underlying: "HTTP \(http.statusCode)")
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        isConnected = false
        logger.info("WhatsApp connector stopped")
    }

    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void) {
        messageHandler = handler
    }
}
