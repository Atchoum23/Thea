import Foundation
import OSLog

// MARK: - OpenClaw Integration
// Manages the lifecycle of OpenClaw connectivity within Thea
// Registers as an integration module, handles connection state

@MainActor
@Observable
final class OpenClawIntegration {
    static let shared = OpenClawIntegration()

    private let logger = Logger(subsystem: "com.thea.app", category: "OpenClawIntegration")
    private let client = OpenClawClient()
    private var eventTask: Task<Void, Never>?

    // MARK: - State

    private(set) var isEnabled = false
    private(set) var connectionState: OpenClawConnectionState = .disconnected
    private(set) var channels: [OpenClawChannel] = []
    private(set) var lastError: String?

    /// Callback for incoming messages
    var onMessageReceived: (@Sendable (OpenClawMessage) async -> Void)?

    private init() {}

    // MARK: - Lifecycle

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        logger.info("OpenClaw integration enabled")
        startListening()
    }

    func disable() {
        isEnabled = false
        eventTask?.cancel()
        eventTask = nil
        Task { await client.disconnect() }
        connectionState = .disconnected
        channels = []
        logger.info("OpenClaw integration disabled")
    }

    // MARK: - Connection

    private func startListening() {
        eventTask?.cancel()

        eventTask = Task {
            let events = await client.connect()

            for await event in events {
                await handleEvent(event)
            }
        }
    }

    private func handleEvent(_ event: OpenClawGatewayEvent) async {
        switch event {
        case .connected:
            connectionState = .connected
            lastError = nil
            logger.info("Connected to OpenClaw Gateway")
            // Request channel list on connect
            try? await client.listChannels()

        case let .disconnected(reason):
            connectionState = .disconnected
            if let reason {
                logger.info("Disconnected: \(reason)")
            }

        case let .messageReceived(message):
            logger.debug("Message from \(message.senderName ?? message.senderID) on \(message.platform.rawValue)")
            await onMessageReceived?(message)

        case let .channelUpdated(channel):
            if let idx = channels.firstIndex(where: { $0.id == channel.id }) {
                channels[idx] = channel
            } else {
                channels.append(channel)
            }

        case let .error(message):
            lastError = message
            logger.error("OpenClaw error: \(message)")

        case .pong:
            break
        }
    }

    // MARK: - Actions

    func sendMessage(to channelID: String, text: String) async throws {
        try await client.sendMessage(channelID: channelID, text: text)
    }

    /// Check if OpenClaw Gateway is reachable
    func checkAvailability() async -> Bool {
        // Try TCP connection to Gateway port
        let url = URL(string: "http://127.0.0.1:18789/health")!  // swiftlint:disable:this force_unwrapping
        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
