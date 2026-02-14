// ExtensionSyncBridge.swift
// Live synchronization between Thea app and browser extensions
// Supports Safari (native), Chrome, and Brave via WebSocket + Native Messaging

import Combine
import Foundation
import Network
import OSLog

// Protocols and supporting types are in ExtensionSyncBridgeTypes.swift
// Message handlers are in ExtensionSyncBridge+MessageHandlers.swift
// State sync, App Group sync, and public API are in ExtensionSyncBridge+SyncAPI.swift

// MARK: - Extension Sync Bridge

@MainActor
public final class ExtensionSyncBridge: ObservableObject {
    public static let shared = ExtensionSyncBridge()

    let logger = Logger(subsystem: "com.thea.app", category: "ExtensionSync")

    // MARK: - Published State

    @Published public internal(set) var connectedExtensions: [ExtensionConnection] = []
    @Published public private(set) var isServerRunning = false
    @Published public internal(set) var lastSyncTime: Date?
    @Published public var settings = SyncSettings()

    // MARK: - Extension Stats (shared state)

    @Published public var stats = ExtensionStats()

    // MARK: - Feature State (for sync when managers aren't available)

    public var adBlockerEnabled: Bool = true
    public var darkModeEnabled: Bool = false
    public var darkModeThemeId: String = "midnight"
    public var privacyProtectionEnabled: Bool = true
    public var passwordManagerLocked: Bool = true
    public var emailProtectionAutoRemoveTrackers: Bool = true
    public var printFriendlyAutoDetect: Bool = true

    // MARK: - Internal Properties (accessed from extension files)

    var activeConnections: [NWConnection] = []
    let appGroupIdentifier = "group.app.theathe"

    // MARK: - Private Properties

    private var webSocketServer: NWListener?
    private var heartbeatTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let webSocketPort: UInt16 = 9876

    // MARK: - Initialization

    private init() {
        loadSettings()
        setupAppGroupSync()
        startServer()
    }

    // Note: deinit removed because @MainActor isolated methods cannot be called from deinit
    // Server cleanup should be handled explicitly via stopServer() before deallocation

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "extensionSync.settings"),
           let loaded = try? JSONDecoder().decode(SyncSettings.self, from: data)
        {
            settings = loaded
        }
    }

    public func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "extensionSync.settings")
        }
    }

    // MARK: - Server Management

    /// Start the WebSocket server for Chrome/Brave extensions
    public func startServer() {
        guard !isServerRunning else { return }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            webSocketServer = try NWListener(using: params, on: NWEndpoint.Port(rawValue: webSocketPort)!)

            webSocketServer?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    switch state {
                    case .ready:
                        self?.isServerRunning = true
                        self?.logger.info("Extension sync server started on port \(self?.webSocketPort ?? 0)")
                    case let .failed(error):
                        self?.isServerRunning = false
                        self?.logger.error("Server failed: \(error.localizedDescription)")
                    case .cancelled:
                        self?.isServerRunning = false
                    default:
                        break
                    }
                }
            }

            webSocketServer?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }

            webSocketServer?.start(queue: .main)

            // Start heartbeat
            startHeartbeat()

            logger.info("Starting extension sync server...")

        } catch {
            logger.error("Failed to start server: \(error.localizedDescription)")
        }
    }

    /// Stop the WebSocket server
    public func stopServer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        for connection in activeConnections {
            connection.cancel()
        }
        activeConnections.removeAll()

        webSocketServer?.cancel()
        webSocketServer = nil
        isServerRunning = false

        logger.info("Extension sync server stopped")
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() {
        let message = SyncMessage(
            type: .heartbeat,
            data: ["timestamp": AnyCodable(Date().timeIntervalSince1970)]
        )
        broadcast(message)
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        logger.info("New extension connection received")

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.handleConnectionReady(connection)
                case let .failed(error):
                    self?.logger.error("Connection failed: \(error.localizedDescription)")
                    self?.removeConnection(connection)
                case .cancelled:
                    self?.removeConnection(connection)
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        activeConnections.append(connection)
    }

    private func handleConnectionReady(_ connection: NWConnection) {
        // Start receiving messages
        receiveMessage(from: connection)

        // Send current state
        sendCurrentState(to: connection)
    }

    private func removeConnection(_ connection: NWConnection) {
        activeConnections.removeAll { $0 === connection }

        // Update connected extensions
        connectedExtensions.removeAll { $0.connectionId == ObjectIdentifier(connection).debugDescription }
    }

    private func receiveMessage(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                if let data, !data.isEmpty {
                    self?.handleReceivedData(data, from: connection)
                }

                if let error {
                    self?.logger.error("Receive error: \(error.localizedDescription)")
                    return
                }

                if isComplete {
                    connection.cancel()
                } else {
                    // Continue receiving
                    self?.receiveMessage(from: connection)
                }
            }
        }
    }

    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        do {
            let message = try JSONDecoder().decode(SyncMessage.self, from: data)
            handleMessage(message, from: connection)
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
        }
    }

    func handleMessage(_ message: SyncMessage, from connection: NWConnection) {
        Task { @MainActor in
            switch message.type {
            case .identify:
                handleIdentify(message, from: connection)

            case .sync:
                handleSync(message, from: connection)

            case .stateUpdate:
                handleStateUpdate(message, from: connection)

            case .featureToggle:
                handleFeatureToggle(message)

            case .credentialRequest:
                handleCredentialRequest(message, from: connection)

            case .aliasRequest:
                handleAliasRequest(message, from: connection)

            case .statsUpdate:
                handleStatsUpdate(message)

            case .heartbeat:
                // Extension is alive
                updateConnectionHeartbeat(connection)

            default:
                break
            }
        }
    }

    // MARK: - Message Sending

    func send(_ message: SyncMessage, to connection: NWConnection) {
        do {
            let data = try JSONEncoder().encode(message)
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    self.logger.error("Send error: \(error.localizedDescription)")
                }
            })
        } catch {
            logger.error("Failed to encode message: \(error.localizedDescription)")
        }
    }

    /// Broadcast message to all connected extensions
    public func broadcast(_ message: SyncMessage) {
        for connection in activeConnections {
            send(message, to: connection)
        }

        // Also sync via App Group for Safari extension
        syncToAppGroup(message)
    }
}
