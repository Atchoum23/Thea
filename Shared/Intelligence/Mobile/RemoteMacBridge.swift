// RemoteMacBridge.swift
// Thea - Mobile Intelligence
//
// Connects iOS/iPadOS devices to a Mac running Thea for inference.
// Uses Bonjour for discovery and HTTP/WebSocket for communication.
// Also works on macOS laptops connecting to more powerful Mac desktops.

import Foundation
import Network
import Observation

// MARK: - Remote Mac Info

/// Information about a discovered Mac running Thea
public struct RemoteMacInfo: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let capabilities: MacCapabilities

    public struct MacCapabilities: Sendable, Hashable {
        public let maxModelSize: String     // e.g., "70B"
        public let hasGPU: Bool
        public let ramGB: Int
        public let availableModels: [String]
    }
}

// MARK: - Connection State

public enum RemoteMacConnectionState: String, Sendable {
    case disconnected
    case discovering
    case connecting
    case connected
    case error
}

// MARK: - Remote Mac Bridge

/// Manages connection to a Mac for remote inference
@MainActor
@Observable
public final class RemoteMacBridge {
    public static let shared = RemoteMacBridge()

    // MARK: - State

    public private(set) var connectionState: RemoteMacConnectionState = .disconnected
    public private(set) var discoveredMacs: [RemoteMacInfo] = []
    public private(set) var connectedMac: RemoteMacInfo?
    public private(set) var lastError: String?

    /// Callback when connection state changes
    public var onConnectionStateChanged: (@Sendable (RemoteMacConnectionState) -> Void)?

    /// Callback when a response is received
    public var onResponseReceived: (@Sendable (String) -> Void)?

    // MARK: - Internal

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let serviceType = "_thea._tcp"
    private let browseQueue = DispatchQueue(label: "ai.thea.mac-discovery")

    private init() {}

    // MARK: - Discovery

    /// Start discovering Macs running Thea on the local network
    public func startDiscovery() {
        stopDiscovery()

        connectionState = .discovering
        discoveredMacs = []

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    break // Discovery active
                case .failed(let error):
                    self?.connectionState = .error
                    self?.lastError = error.localizedDescription
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleDiscoveryResults(results)
            }
        }

        browser?.start(queue: browseQueue)
    }

    /// Stop discovering Macs
    public func stopDiscovery() {
        browser?.cancel()
        browser = nil
        if connectionState == .discovering {
            connectionState = .disconnected
        }
    }

    private func handleDiscoveryResults(_ results: Set<NWBrowser.Result>) {
        var macs: [RemoteMacInfo] = []

        for result in results {
            if case let .service(name, _, _, _) = result.endpoint {
                // Resolve the service to get host/port
                let mac = RemoteMacInfo(
                    id: name,
                    name: name,
                    host: "\(name).local",
                    port: 8765, // Default Thea port
                    capabilities: .init(
                        maxModelSize: "Unknown",
                        hasGPU: true,
                        ramGB: 0,
                        availableModels: []
                    )
                )
                macs.append(mac)
            }
        }

        discoveredMacs = macs

        // Notify orchestrator
        MobileIntelligenceOrchestrator.shared.setRemoteMacAvailable(!macs.isEmpty)
    }

    // MARK: - Connection

    /// Connect to a specific Mac
    public func connect(to mac: RemoteMacInfo) async throws {
        disconnect()

        connectionState = .connecting

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(mac.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(mac.port))
        )

        let parameters = NWParameters.tcp
        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state, mac: mac)
            }
        }

        connection?.start(queue: browseQueue)

        // Wait for connection with timeout
        try await withTimeout(seconds: 10) { [weak self] in
            while await self?.connectionState == .connecting {
                try await Task.sleep(for: .milliseconds(100))
            }

            if await self?.connectionState != .connected {
                throw RemoteMacError.connectionFailed
            }
        }
    }

    /// Disconnect from current Mac
    public func disconnect() {
        connection?.cancel()
        connection = nil
        connectedMac = nil
        connectionState = .disconnected
        MobileIntelligenceOrchestrator.shared.setRemoteMacAvailable(false)
    }

    private func handleConnectionState(_ state: NWConnection.State, mac: RemoteMacInfo) {
        switch state {
        case .ready:
            connectionState = .connected
            connectedMac = mac
            lastError = nil
            onConnectionStateChanged?(.connected)
            startReceiving()

        case .failed(let error):
            connectionState = .error
            lastError = error.localizedDescription
            connectedMac = nil
            onConnectionStateChanged?(.error)

        case .cancelled:
            connectionState = .disconnected
            connectedMac = nil
            onConnectionStateChanged?(.disconnected)

        default:
            break
        }
    }

    // MARK: - Communication

    /// Send an inference request to the connected Mac
    public func sendInferenceRequest(
        query: String,
        model: String? = nil,
        maxTokens: Int = 2048,
        stream: Bool = true
    ) async throws -> String {
        guard let connection = connection, connectionState == .connected else {
            throw RemoteMacError.notConnected
        }

        let request = InferenceRequest(
            query: query,
            model: model,
            maxTokens: maxTokens,
            stream: stream
        )

        let data = try JSONEncoder().encode(request)

        // Send request
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        // Wait for response
        return try await receiveResponse()
    }

    private func startReceiving() {
        guard let connection = connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let data = data, !data.isEmpty {
                    if let response = String(data: data, encoding: .utf8) {
                        self?.onResponseReceived?(response)
                    }
                }

                if !isComplete && error == nil {
                    self?.startReceiving()
                }
            }
        }
    }

    private func receiveResponse() async throws -> String {
        guard let connection = connection else {
            throw RemoteMacError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1_000_000) { data, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: RemoteMacError.invalidResponse)
                }
            }
        }
    }

    // MARK: - Auto-Connect

    /// Automatically connect to the best available Mac
    public func autoConnect() async {
        startDiscovery()

        // Wait for discovery
        try? await Task.sleep(for: .seconds(3))

        // Connect to first available Mac
        if let mac = discoveredMacs.first {
            try? await connect(to: mac)
        }
    }
}

// MARK: - Supporting Types

private struct InferenceRequest: Codable {
    let query: String
    let model: String?
    let maxTokens: Int
    let stream: Bool
}

public enum RemoteMacError: Error, LocalizedError {
    case notConnected
    case connectionFailed
    case invalidResponse
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to a Mac"
        case .connectionFailed: return "Failed to connect to Mac"
        case .invalidResponse: return "Invalid response from Mac"
        case .timeout: return "Connection timed out"
        }
    }
}

// MARK: - Timeout Helper

private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw RemoteMacError.timeout
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
