// WebSocketServer.swift
// Thea V2 - WebSocket Server for Browser Extension Communication
//
// Provides a local WebSocket server for browser extensions to send
// life monitoring data to THEA.

import Foundation
import Network
import os.log

// MARK: - WebSocket Server Protocol

@MainActor
public protocol LifeMonitorWebSocketServerDelegate: AnyObject, Sendable {
    nonisolated func webSocketServer(
        _ _server: LifeMonitorWebSocketServer,
        didReceiveData data: Data,
        from _clientId: String
    )
    nonisolated func webSocketServer(
        _ _server: LifeMonitorWebSocketServer,
        clientConnected clientId: String
    )
    nonisolated func webSocketServer(
        _ _server: LifeMonitorWebSocketServer,
        clientDisconnected clientId: String
    )
}

// MARK: - WebSocket Server

/// Local WebSocket server for browser extension communication
public actor LifeMonitorWebSocketServer {
    private let logger = Logger(subsystem: "ai.thea.app", category: "WebSocketServer")

    private let port: UInt16
    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]

    public weak var delegate: LifeMonitorWebSocketServerDelegate?

    /// Set the delegate (for use from MainActor contexts)
    public func setDelegate(_ delegate: LifeMonitorWebSocketServerDelegate?) {
        self.delegate = delegate
    }

    public private(set) var isRunning = false

    public init(port: UInt16 = 9876) {
        self.port = port
    }

    // MARK: - Lifecycle

    public func start() async throws {
        guard !isRunning else {
            logger.warning("WebSocket server already running")
            return
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        // Configure for WebSocket
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            logger.error("Failed to create listener: \(error.localizedDescription)")
            throw error
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleListenerState(state) }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { await self?.handleNewConnection(connection) }
        }

        listener?.start(queue: .main)
        isRunning = true
        logger.info("WebSocket server started on port \(self.port)")
    }

    public func stop() async {
        listener?.cancel()
        listener = nil

        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()

        isRunning = false
        logger.info("WebSocket server stopped")
    }

    // MARK: - Connection Handling

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("WebSocket server ready")
        case let .failed(error):
            logger.error("WebSocket server failed: \(error.localizedDescription)")
            isRunning = false
        case .cancelled:
            logger.info("WebSocket server cancelled")
            isRunning = false
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let clientId = UUID().uuidString
        connections[clientId] = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleConnectionState(state, clientId: clientId) }
        }

        startReceiving(connection: connection, clientId: clientId)
        connection.start(queue: .main)

        logger.info("New WebSocket connection: \(clientId)")
    }

    private func handleConnectionState(_ state: NWConnection.State, clientId: String) {
        switch state {
        case .ready:
            logger.debug("Connection ready: \(clientId)")
            delegate?.webSocketServer(self, clientConnected: clientId)

        case let .failed(error):
            logger.error("Connection failed: \(error.localizedDescription)")
            removeConnection(clientId: clientId)

        case .cancelled:
            logger.debug("Connection cancelled: \(clientId)")
            removeConnection(clientId: clientId)

        default:
            break
        }
    }

    private func removeConnection(clientId: String) {
        connections.removeValue(forKey: clientId)
        delegate?.webSocketServer(self, clientDisconnected: clientId)
    }

    // MARK: - Message Handling

    private func startReceiving(connection: NWConnection, clientId: String) {
        connection.receiveMessage { [weak self] content, context, _, error in
            guard let self = self else { return }

            if let error {
                Task { self.logger.error("Receive error: \(error.localizedDescription)") }
                return
            }

            if let data = content, !data.isEmpty {
                // Check if it's a WebSocket message
                if let wsMetadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                    switch wsMetadata.opcode {
                    case .text, .binary:
                        Task { await self.handleMessage(data, from: clientId) }
                    case .close:
                        Task { await self.removeConnection(clientId: clientId) }
                        return
                    case .ping:
                        // Auto-handled by NWProtocolWebSocket
                        break
                    default:
                        break
                    }
                } else {
                    // Handle as regular HTTP upgrade request or data
                    Task { await self.handleMessage(data, from: clientId) }
                }
            }

            // Continue receiving
            Task { await self.startReceiving(connection: connection, clientId: clientId) }
        }
    }

    private func handleMessage(_ data: Data, from clientId: String) {
        // Try to parse as JSON
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Handle different message types
                if let type = json["type"] as? String {
                    switch type {
                    case "sync":
                        handleSyncRequest(json, clientId: clientId)
                    case "lifeMonitorData":
                        // Forward to delegate
                        if let innerData = json["data"] {
                            let eventData = try JSONSerialization.data(withJSONObject: innerData)
                            delegate?.webSocketServer(self, didReceiveData: eventData, from: clientId)
                        }
                    case "getState", "getLifeMonitorSettings":
                        sendSettings(to: clientId)
                    default:
                        delegate?.webSocketServer(self, didReceiveData: data, from: clientId)
                    }
                }
            }
        } catch {
            logger.error("Failed to parse message: \(error.localizedDescription)")
        }
    }

    private func handleSyncRequest(_ _json: [String: Any], clientId: String) {
        // Send back acknowledgment with current state
        let response: [String: Any] = [
            "success": true,
            "state": [
                "lifeMonitorEnabled": true,
                "capturePageContent": true,
                "captureReadingBehavior": true
            ]
        ]

        sendMessage(response, to: clientId)
    }

    private func sendSettings(to clientId: String) {
        let settings: [String: Any] = [
            "success": true,
            "data": [
                "enabled": true,
                "capturePageContent": true,
                "captureReadingBehavior": true,
                "captureSelections": true,
                "captureLinkClicks": true
            ]
        ]

        sendMessage(settings, to: clientId)
    }

    // MARK: - Sending

    public func sendMessage(_ message: [String: Any], to clientId: String) {
        guard let connection = connections[clientId] else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            sendData(data, to: connection)
        } catch {
            logger.error("Failed to serialize message: \(error.localizedDescription)")
        }
    }

    public func broadcast(_ message: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            for (_, connection) in connections {
                sendData(data, to: connection)
            }
        } catch {
            logger.error("Failed to serialize broadcast: \(error.localizedDescription)")
        }
    }

    private func sendData(_ data: Data, to connection: NWConnection) {
        // Create WebSocket metadata for text message
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "textMessage",
            metadata: [metadata]
        )

        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { [weak self] error in
                if let error {
                    Task { self?.logger.error("Send error: \(error.localizedDescription)") }
                }
            }
        )
    }
}
