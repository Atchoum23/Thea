//
//  TVInferenceClient.swift
//  Thea TV
//
//  Lightweight inference relay client for tvOS.
//  Discovers macOS server via Bonjour, sends InferenceRequests,
//  receives streamed responses over TCP.
//
//  CREATED: February 15, 2026
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "app.thea.tv", category: "InferenceClient")

/// tvOS client that connects to a Thea macOS server and relays AI inference requests.
@MainActor
final class TVInferenceClient: ObservableObject {
    static let shared = TVInferenceClient()

    @Published var isConnected = false
    @Published var serverName: String?

    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var pendingRequests: [String: CheckedContinuation<String, Error>] = [:]

    private init() {
        startBrowsing()
    }

    // MARK: - Bonjour Discovery

    private func startBrowsing() {
        let browser = NWBrowser(for: .bonjour(type: "_thea-inference._tcp.", domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    logger.info("Bonjour browser ready — looking for Thea servers")
                case .failed(let error):
                    logger.error("Bonjour browser failed: \(error.localizedDescription)")
                    self?.isConnected = false
                default:
                    break
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                if let result = results.first {
                    logger.info("Found Thea server: \(String(describing: result.endpoint))")
                    self.connectTo(endpoint: result.endpoint)
                }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    private func connectTo(endpoint: NWEndpoint) {
        connection?.cancel()

        let conn = NWConnection(to: endpoint, using: .tcp)
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    logger.info("Connected to Thea server")
                    self?.isConnected = true
                    self?.receiveMessages()
                case .failed(let error):
                    logger.error("Connection failed: \(error.localizedDescription)")
                    self?.isConnected = false
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }
        conn.start(queue: .main)
        self.connection = conn
    }

    // MARK: - Send Inference Request

    /// Send a chat message and return the AI response text.
    func sendChat(messages: [InferenceMessage]) async throws -> String {
        let request = InferenceRequest(
            messages: messages,
            preferredModel: nil,
            stream: false
        )

        let relayMessage = InferenceRelayMessage.inferenceRequest(request)
        let data = try JSONEncoder().encode(relayMessage)

        guard let connection, connection.state == .ready else {
            throw TVInferenceError.notConnected
        }

        // Send length-prefixed JSON
        var length = UInt32(data.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)
        connection.send(content: lengthData + data, completion: .contentProcessed { error in
            if let error {
                logger.error("Send failed: \(error.localizedDescription)")
            }
        })

        // Wait for response
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.requestId] = continuation
            // Timeout after 60 seconds
            Task {
                try? await Task.sleep(for: .seconds(60))
                if let cont = await self.pendingRequests.removeValue(forKey: request.requestId) {
                    cont.resume(throwing: TVInferenceError.timeout)
                }
            }
        }
    }

    // MARK: - Receive Messages

    private func receiveMessages() {
        guard let connection else { return }

        // Read length prefix (4 bytes)
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    logger.error("Receive error: \(error.localizedDescription)")
                    return
                }
                guard let lengthData = data, lengthData.count == 4 else {
                    if isComplete {
                        self.isConnected = false
                    }
                    return
                }

                let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                self.readMessageBody(length: Int(length))
            }
        }
    }

    private func readMessageBody(length: Int) {
        guard let connection else { return }

        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    logger.error("Receive body error: \(error.localizedDescription)")
                    self.receiveMessages()
                    return
                }
                guard let messageData = data else {
                    self.receiveMessages()
                    return
                }

                self.handleRelayMessage(messageData)
                self.receiveMessages()
            }
        }
    }

    private func handleRelayMessage(_ data: Data) {
        guard let message = try? JSONDecoder().decode(InferenceRelayMessage.self, from: data) else {
            logger.warning("Failed to decode relay message")
            return
        }

        switch message {
        case .streamComplete(let complete):
            if let continuation = pendingRequests.removeValue(forKey: complete.requestId) {
                serverName = complete.provider
                continuation.resume(returning: complete.fullText)
            }
        case .streamError(let error):
            if let continuation = pendingRequests.removeValue(forKey: error.requestId) {
                continuation.resume(throwing: TVInferenceError.serverError(error.errorDescription))
            }
        case .streamDelta:
            // For non-streaming mode, we just wait for complete
            break
        case .capabilitiesResponse(let caps):
            serverName = caps.serverName
        default:
            break
        }
    }
}

// MARK: - Errors

enum TVInferenceError: LocalizedError {
    case notConnected
    case timeout
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to a Thea server. Make sure Thea is running on your Mac."
        case .timeout: "Request timed out. The server may be busy."
        case .serverError(let msg): msg
        }
    }
}
