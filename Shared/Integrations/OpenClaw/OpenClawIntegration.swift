import Foundation
import OSLog

// MARK: - OpenClaw Integration (Repurposed — Phase O)
// Lifecycle manager for Thea's native messaging gateway (TheaMessagingGateway).
// Previously managed an external OpenClaw daemon; now delegates all state to
// TheaMessagingGateway.shared which hosts its own WebSocket server on port 18789.
// All Published properties are preserved for UI compatibility.

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

    // MARK: - Lifecycle (Delegated to TheaMessagingGateway)

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        logger.info("Messaging integration enabled — starting TheaMessagingGateway")
        startListening()
    }

    func disable() {
        isEnabled = false
        eventTask?.cancel()
        eventTask = nil
        connectionState = .disconnected
        channels = []
        Task { await TheaMessagingGateway.shared.stop() }
        logger.info("Messaging integration disabled")
    }

    // MARK: - Connection (via TheaMessagingGateway)

    private func startListening() {
        eventTask?.cancel()
        eventTask = Task {
            // Start the native gateway
            await TheaMessagingGateway.shared.start()

            // Mirror gateway state into legacy Published properties
            for await _ in AsyncStream<Void>(unfolding: {
                try? await Task.sleep(for: .seconds(1))
                return ()
            }) {
                let connected = await MainActor.run { !TheaMessagingGateway.shared.connectedPlatforms.isEmpty }
                if connected && connectionState != .connected {
                    connectionState = .connected
                    lastError = nil
                    logger.info("Native messaging gateway connected")
                } else if !connected && connectionState == .connected {
                    connectionState = .disconnected
                }

                let gateError = await MainActor.run { TheaMessagingGateway.shared.lastError }
                if let err = gateError { lastError = err }

                if Task.isCancelled { break }
            }
        }
    }

    // MARK: - Actions

    func sendMessage(to channelID: String, text: String) async throws {
        // For legacy callers: try to infer platform from channelID prefix or send via client
        try await client.sendMessage(channelID: channelID, text: text)
    }

    /// Check if Thea's native gateway is reachable (health endpoint)
    func checkAvailability() async -> Bool {
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
