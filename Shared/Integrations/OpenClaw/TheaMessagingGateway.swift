import Foundation
import OSLog

// MARK: - Thea Native Messaging Gateway
// Central orchestrator for all messaging platform connectors.
// Replaces OpenClaw entirely — Thea connects directly to each platform's API.
// Hosts the built-in WebSocket server on port 18789 (via TheaGatewayWSServer).
// All inbound messages are filtered by OpenClawSecurityGuard before reaching AI.

@MainActor
final class TheaMessagingGateway: ObservableObject {
    static let shared = TheaMessagingGateway()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MessagingGateway")

    // MARK: - State

    @Published private(set) var connectedPlatforms: Set<MessagingPlatform> = []
    @Published private(set) var lastError: String?
    @Published private(set) var isRunning = false

    private var connectors: [MessagingPlatform: any MessagingPlatformConnector] = [:]
    private var wsServer: TheaGatewayWSServer?

    private init() {}

    // MARK: - Lifecycle

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        logger.info("TheaMessagingGateway starting…")

        // Start the built-in WebSocket server (OpenClawClient.swift connects here)
        wsServer = TheaGatewayWSServer(port: 18789, gateway: self)
        do {
            try await wsServer?.startListening()
            logger.info("WebSocket server listening on port 18789")
        } catch {
            logger.error("Failed to start WS server: \(error)")
        }

        // Start connectors for all enabled platforms
        for platform in MessagingPlatform.allCases {
            let creds = MessagingCredentialsStore.load(for: platform)
            guard creds.isEnabled else { continue }
            await startConnector(for: platform, credentials: creds)
        }

        curl_ntfy_milestone("TheaMessagingGateway started. Connected: \(connectedPlatforms.count) platforms.")
    }

    func stop() async {
        logger.info("TheaMessagingGateway stopping…")
        for (_, connector) in connectors {
            await connector.disconnect()
        }
        connectors.removeAll()
        connectedPlatforms.removeAll()
        await wsServer?.stop()
        wsServer = nil
        isRunning = false
    }

    // MARK: - Connector Management

    private func startConnector(for platform: MessagingPlatform, credentials: MessagingCredentials) async {
        let connector: any MessagingPlatformConnector
        switch platform {
        case .telegram:  connector = TelegramConnector(credentials: credentials)
        case .discord:   connector = DiscordConnector(credentials: credentials)
        case .slack:     connector = SlackConnector(credentials: credentials)
        case .imessage:  connector = BlueBubblesConnector(credentials: credentials)
        case .whatsapp:  connector = WhatsAppConnector(credentials: credentials)
        case .signal:    connector = SignalConnector(credentials: credentials)
        case .matrix:    connector = MatrixConnector(credentials: credentials)
        }

        // Wire message handler — all inbound messages funnel through routeInbound
        await connector.setMessageHandler { [weak self] message in
            guard let self else { return }
            await self.routeInbound(message)
        }

        do {
            try await connector.connect()
            connectors[platform] = connector
            connectedPlatforms.insert(platform)
            logger.info("Connected: \(platform.displayName)")
            lastError = nil
        } catch {
            lastError = "[\(platform.displayName)] \(error.localizedDescription)"
            logger.error("Failed to connect \(platform.displayName): \(error)")
        }
    }

    func restartConnector(for platform: MessagingPlatform) async {
        if let existing = connectors[platform] {
            await existing.disconnect()
            connectors.removeValue(forKey: platform)
            connectedPlatforms.remove(platform)
        }
        let creds = MessagingCredentialsStore.load(for: platform)
        guard creds.isEnabled else { return }
        await startConnector(for: platform, credentials: creds)
    }

    // MARK: - Message Routing

    /// All inbound messages from all connectors pass through here.
    /// Security guard → session manager → OpenClawBridge → AI.
    func routeInbound(_ message: TheaGatewayMessage) async {
        // 1. Security: 22-pattern injection guard (OpenClawSecurityGuard — kept exactly as-is)
        let isSafe = await OpenClawSecurityGuard.shared.isSafe(message)
        guard isSafe else {
            logger.warning("Message blocked by security guard from \(message.senderId) on \(message.platform.rawValue)")
            return
        }

        // 2. Session persistence (SwiftData, MMR re-ranking)
        await MessagingSessionManager.shared.appendMessage(message)

        // 3. Route to OpenClawBridge (AI response generation + multi-agent routing)
        await OpenClawBridge.shared.processInboundMessage(message)

        // 4. Broadcast to any connected WS clients (e.g. OpenClawClient)
        await wsServer?.broadcastInbound(message)
    }

    // MARK: - Outbound Send

    /// Send a message back to a specific platform.
    func send(_ message: OutboundMessagingMessage, via platform: MessagingPlatform) async throws {
        guard let connector = connectors[platform] else {
            throw MessagingError.notConnected(platform: platform)
        }
        try await connector.send(message)
    }

    /// Convenience: send a text reply to the same chat a message came from.
    // periphery:ignore - Reserved: reply(to:text:) instance method — reserved for future feature activation
    func reply(to inbound: TheaGatewayMessage, text: String) async throws {
        // periphery:ignore - Reserved: reply(to:text:) instance method reserved for future feature activation
        let outbound = OutboundMessagingMessage(
            chatId: inbound.chatId,
            content: text,
            replyToId: inbound.id
        )
        try await send(outbound, via: inbound.platform)
    }

    // MARK: - Health

    // periphery:ignore - Reserved: healthStatus() instance method reserved for future feature activation
    func healthStatus() -> [String: Any] {
        let connectorList = connectedPlatforms.map(\.rawValue).sorted()
        return [
            "status": "ok",
            "platform": "thea",
            "port": 18789,
            "connectors": connectorList,
            "connectorCount": connectorList.count
        ]
    }

    // MARK: - Private helpers

    private func curl_ntfy_milestone(_ msg: String) {
        // Fire-and-forget ntfy notification via URLSession (non-blocking)
        var req = URLRequest(url: URL(string: "https://ntfy.sh/thea-msm3u")!) // swiftlint:disable:this force_unwrapping
        req.httpMethod = "POST"
        req.setValue("Thea O-Gateway - Milestone", forHTTPHeaderField: "Title")
        req.setValue("3", forHTTPHeaderField: "Priority")
        req.setValue("white_check_mark", forHTTPHeaderField: "Tags")
        req.httpBody = msg.data(using: .utf8)
        URLSession.shared.dataTask(with: req).resume()
    }
}
