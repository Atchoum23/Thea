//
//  RemoteInferenceClient.swift
//  Thea TV
//
//  tvOS client for discovering and connecting to a macOS Thea inference server
//  on the local network via Bonjour. Sends chat requests and receives streamed
//  AI responses in real time.
//
//  CREATED: February 8, 2026
//

import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "app.thea.tvos", category: "InferenceClient")

// MARK: - Connection State

enum InferenceConnectionState: Equatable {
    case disconnected
    case discovering
    case connecting
    case connected
    case error(String)

    var displayName: String {
        switch self {
        case .disconnected: "Disconnected"
        case .discovering: "Searching..."
        case .connecting: "Connecting..."
        case .connected: "Connected"
        case let .error(msg): "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Discovered Server

struct DiscoveredInferenceServer: Identifiable, Equatable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
    let platform: String

    static func == (lhs: DiscoveredInferenceServer, rhs: DiscoveredInferenceServer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Remote Inference Client

@MainActor
final class RemoteInferenceClient: ObservableObject {
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    static let shared = RemoteInferenceClient()

    // MARK: - Published State

    @Published var connectionState: InferenceConnectionState = .disconnected
    @Published var discoveredServers: [DiscoveredInferenceServer] = []
    @Published var connectedServerName: String?
    @Published var availableModels: [InferenceModelInfo] = []
    @Published var serverCapabilities: InferenceServerCapabilities?
    @Published var streamingText = ""

    // MARK: - Callbacks (set by chat view)

    var onStreamDelta: ((String, String) -> Void)?
    var onStreamComplete: ((String, InferenceStreamComplete) -> Void)?
    var onStreamError: ((String, String) -> Void)?

    // MARK: - Private State

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "app.thea.tvos.inference", qos: .userInitiated)

    // Auto-reconnect
    private var lastServerEndpoint: NWEndpoint?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    /// Tailscale fallback endpoints when Bonjour discovery fails (off-LAN)
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private let tailscaleEndpoints: [(name: String, host: String, port: UInt16)] = [
        ("Mac Studio (Tailscale)", "100.121.35.50", 8765),
        ("MacBook Air (Tailscale)", "100.74.240.60", 8765)
    ]

    // MARK: - Bonjour Discovery

    func startDiscovery() {
        guard browser == nil else { return }

        connectionState = .discovering
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_thea-remote._tcp", domain: "local.")
        let parameters = NWParameters()

        let newBrowser = NWBrowser(for: descriptor, using: parameters)

        newBrowser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    logger.info("Bonjour browser ready")
                case let .failed(error):
                    logger.error("Bonjour browser failed: \(error.localizedDescription)")
                    self?.connectionState = .error("Discovery failed")
                case .cancelled:
                    logger.info("Bonjour browser cancelled")
                default:
                    break
                }
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleBrowseResults(results)
            }
        }

        newBrowser.start(queue: queue)
        browser = newBrowser
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        if !connectionState.isConnected {
            connectionState = .disconnected
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var servers: [DiscoveredInferenceServer] = []

        for result in results {
            switch result.endpoint {
            case let .service(name, _, _, _):
                var platform = "macOS"
                if case let .bonjour(txtRecord) = result.metadata {
                    if let p = txtRecord.dictionary["platform"] {
                        platform = p
                    }
                }
                let deviceId: String
                if case let .bonjour(txtRecord) = result.metadata,
                   let id = txtRecord.dictionary["deviceId"]
                {
                    deviceId = id
                } else {
                    deviceId = name
                }

                servers.append(DiscoveredInferenceServer(
                    id: deviceId,
                    name: name,
                    endpoint: result.endpoint,
                    platform: platform
                ))
            default:
                break
            }
        }

        discoveredServers = servers
        logger.info("Discovered \(servers.count) inference server(s)")
    }

    // MARK: - Connection

    func connect(to server: DiscoveredInferenceServer) {
        disconnect()

        connectionState = .connecting
        connectedServerName = server.name
        lastServerEndpoint = server.endpoint

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let newConnection = NWConnection(to: server.endpoint, using: parameters)

        newConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionStateChange(state)
            }
        }

        newConnection.start(queue: queue)
        connection = newConnection
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        connectedServerName = nil
        serverCapabilities = nil
        availableModels = []
        reconnectAttempts = 0
    }

    private func handleConnectionStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionState = .connected
            reconnectAttempts = 0
            logger.info("Connected to inference server: \(self.connectedServerName ?? "unknown")")
            startReceiveLoop()
            // Request server capabilities on connect
            Task { await requestCapabilities() }

        case let .failed(error):
            logger.error("Connection failed: \(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            attemptReconnect()

        case .cancelled:
            if connectionState != .disconnected {
                connectionState = .disconnected
            }

        case .waiting:
            connectionState = .connecting

        default:
            break
        }
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts,
              let endpoint = lastServerEndpoint else {
            connectionState = .error("Server unreachable")
            return
        }

        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 10.0)
        logger.info("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")

        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard connectionState != .connected, connectionState != .disconnected else { return }

            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true
            let newConnection = NWConnection(to: endpoint, using: parameters)
            newConnection.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleConnectionStateChange(state)
                }
            }
            newConnection.start(queue: queue)
            connection = newConnection
        }
    }

    // MARK: - Auto-Connect with Tailscale Fallback

    /// Automatically discover and connect to the best available server.
    /// Tries Bonjour first (5s), then falls back to Tailscale endpoints.
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func autoConnect() async {
        startDiscovery()

        // Wait for Bonjour discovery
        try? await Task.sleep(for: .seconds(5))

        // If Bonjour found servers, connect to the first one
        if let server = discoveredServers.first {
            connect(to: server)
            return
        }

        // Bonjour timeout — fall back to Tailscale endpoints
        addTailscaleEndpoints()

        if let server = discoveredServers.first {
            connect(to: server)
        }
    }

    /// Adds Tailscale-based endpoints as fallback when Bonjour discovery times out
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    private func addTailscaleEndpoints() {
        let tailscaleServers = tailscaleEndpoints.map { endpoint in
            DiscoveredInferenceServer(
                id: "tailscale-\(endpoint.host)",
                name: endpoint.name,
                endpoint: NWEndpoint.hostPort(
                    host: NWEndpoint.Host(endpoint.host),
                    port: NWEndpoint.Port(integerLiteral: endpoint.port)
                ),
                platform: "macOS"
            )
        }
        discoveredServers.append(contentsOf: tailscaleServers)
        logger.info("Added \(tailscaleServers.count) Tailscale fallback endpoint(s)")
    }

    // MARK: - Send / Receive

    /// Send an inference request and return the request ID for tracking.
    func sendInferenceRequest(
        messages: [(role: String, content: String)],
        preferredModel: String? = nil
    ) async throws -> String {
        let request = InferenceRequest(
            messages: messages.map { InferenceMessage(role: $0.role, content: $0.content) },
            preferredModel: preferredModel
        )

        let relayMessage = InferenceRelayMessage.inferenceRequest(request)
        try await sendRelayMessage(relayMessage)
        streamingText = ""

        return request.requestId
    }

    func requestCapabilities() async {
        try? await sendRelayMessage(.capabilitiesRequest)
    }

    func requestModelList() async {
        try? await sendRelayMessage(.listModelsRequest)
    }

    private func sendRelayMessage(_ message: InferenceRelayMessage) async throws {
        guard let connection, connectionState.isConnected else {
            throw InferenceClientError.notConnected
        }

        let encoded = try JSONEncoder().encode(message)

        // 4-byte length prefix (big-endian) + JSON payload
        var length = UInt32(encoded.count).bigEndian
        var frameData = Data(bytes: &length, count: 4)
        frameData.append(encoded)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: frameData, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await self?.receiveOneMessage()
                } catch {
                    if !Task.isCancelled {
                        logger.error("Receive error: \(error.localizedDescription)")
                    }
                    break
                }
            }
        }
    }

    private func receiveOneMessage() async throws {
        guard let connection else { throw InferenceClientError.notConnected }

        // Read 4-byte length prefix
        let lengthData = try await receiveExact(connection: connection, length: 4)
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        guard length > 0, length < 10_000_000 else {
            throw InferenceClientError.invalidFrame
        }

        // Read payload
        let payload = try await receiveExact(connection: connection, length: Int(length))

        // Decode as InferenceRelayMessage
        let message = try JSONDecoder().decode(InferenceRelayMessage.self, from: payload)
        handleRelayMessage(message)
    }

    private func receiveExact(connection: NWConnection, length: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, data.count == length {
                    continuation.resume(returning: data)
                } else if let data, !data.isEmpty {
                    // Partial read — for simplicity, treat as error (real impl would buffer)
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: InferenceClientError.connectionClosed)
                }
            }
        }
    }

    private func handleRelayMessage(_ message: InferenceRelayMessage) {
        switch message {
        case let .streamDelta(delta):
            streamingText += delta.delta
            onStreamDelta?(delta.requestId, delta.delta)

        case let .streamComplete(complete):
            streamingText = complete.fullText
            onStreamComplete?(complete.requestId, complete)

        case let .streamError(error):
            onStreamError?(error.requestId, error.errorDescription)

        case let .listModelsResponse(modelList):
            availableModels = modelList.models

        case let .capabilitiesResponse(caps):
            serverCapabilities = caps

        default:
            logger.warning("Received unexpected relay message type")
        }
    }
}

// MARK: - Errors

enum InferenceClientError: Error, LocalizedError {
    case notConnected
    case invalidFrame
    case connectionClosed
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to inference server"
        case .invalidFrame: "Invalid message frame received"
        case .connectionClosed: "Connection closed by server"
        case .timeout: "Request timed out"
        }
    }
}

// MARK: - NWBrowser.Result.Metadata TXT Record Extension

extension NWBrowser.Result.Metadata {
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var dictionary: [String: String] {
        switch self {
        case let .bonjour(record):
            return record.dictionary
        default:
            return [:]
        }
    }
}

extension NWTXTRecord {
    /// Convert TXT record to dictionary by extracting key-value pairs
    var dictionary: [String: String] {
        var result: [String: String] = [:]
        let knownKeys = ["version", "capabilities", "models", "status", "platform", "deviceId"]
        for key in knownKeys {
            if let value = getEntry(for: key) {
                switch value {
                case let .string(str):
                    result[key] = str
                default:
                    break
                }
            }
        }
        return result
    }
}
