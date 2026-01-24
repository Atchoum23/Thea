// ExtensionSyncBridge.swift
// Live synchronization between Thea app and browser extensions
// Supports Safari (native), Chrome, and Brave via WebSocket + Native Messaging

import Foundation
import OSLog
import Combine
import Network

// MARK: - Extension Sync Bridge

@MainActor
public final class ExtensionSyncBridge: ObservableObject {
    public static let shared = ExtensionSyncBridge()

    private let logger = Logger(subsystem: "com.thea.app", category: "ExtensionSync")

    // MARK: - Published State

    @Published public private(set) var connectedExtensions: [ExtensionConnection] = []
    @Published public private(set) var isServerRunning = false
    @Published public private(set) var lastSyncTime: Date?
    @Published public var settings = SyncSettings()

    // MARK: - Private Properties

    private var webSocketServer: NWListener?
    private var activeConnections: [NWConnection] = []
    private var heartbeatTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let appGroupIdentifier = "group.com.thea.app"
    private let webSocketPort: UInt16 = 9876

    // MARK: - Initialization

    private init() {
        loadSettings()
        setupAppGroupSync()
        startServer()
        setupStateObservers()
    }

    deinit {
        stopServer()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "extensionSync.settings"),
           let loaded = try? JSONDecoder().decode(SyncSettings.self, from: data) {
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
                    case .failed(let error):
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
                self?.handleNewConnection(connection)
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
                case .failed(let error):
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
            if let data = data, !data.isEmpty {
                self?.handleReceivedData(data, from: connection)
            }

            if let error = error {
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

    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        do {
            let message = try JSONDecoder().decode(SyncMessage.self, from: data)
            handleMessage(message, from: connection)
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
        }
    }

    private func handleMessage(_ message: SyncMessage, from connection: NWConnection) {
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

    // MARK: - Message Handlers

    private func handleIdentify(_ message: SyncMessage, from connection: NWConnection) {
        guard let extensionType = message.data["type"]?.value as? String,
              let version = message.data["version"]?.value as? String else {
            return
        }

        let extensionConnection = ExtensionConnection(
            connectionId: ObjectIdentifier(connection).debugDescription,
            type: ExtensionType(rawValue: extensionType) ?? .chrome,
            version: version,
            connectedAt: Date(),
            lastHeartbeat: Date()
        )

        // Remove existing connection of same type
        connectedExtensions.removeAll { $0.type == extensionConnection.type }
        connectedExtensions.append(extensionConnection)

        logger.info("Extension identified: \(extensionType) v\(version)")

        // Send acknowledgment with current state
        sendCurrentState(to: connection)
    }

    private func handleSync(_ message: SyncMessage, from connection: NWConnection) {
        // Merge state from extension
        if let extensionState = message.data["state"]?.value as? [String: Any] {
            mergeExtensionState(extensionState)
        }

        lastSyncTime = Date()

        // Send updated state back
        sendCurrentState(to: connection)
    }

    private func handleStateUpdate(_ message: SyncMessage, from connection: NWConnection) {
        if let extensionState = message.data["state"]?.value as? [String: Any] {
            mergeExtensionState(extensionState)
        }
    }

    private func handleFeatureToggle(_ message: SyncMessage) {
        guard let feature = message.data["feature"]?.value as? String,
              let enabled = message.data["enabled"]?.value as? Bool else {
            return
        }

        // Update feature state in managers
        switch feature {
        case "adBlocker":
            TheaAdBlockerManager.shared.isEnabled = enabled
        case "darkMode":
            TheaDarkModeManager.shared.isEnabled = enabled
        case "privacyProtection":
            TheaPrivacyProtectionManager.shared.isEnabled = enabled
        case "passwordManager":
            // Password manager state update
            break
        case "emailProtection":
            // Email protection state update
            break
        default:
            break
        }

        // Broadcast to all extensions
        let updateMessage = SyncMessage(
            type: .featureToggle,
            data: [
                "feature": AnyCodable(feature),
                "enabled": AnyCodable(enabled)
            ]
        )
        broadcast(updateMessage)
    }

    private func handleCredentialRequest(_ message: SyncMessage, from connection: NWConnection) {
        guard let domain = message.data["domain"]?.value as? String else { return }

        Task {
            do {
                let credentials = try await TheaPasswordManager.shared.getCredentials(for: domain)

                let response = SyncMessage(
                    type: .credentialResponse,
                    data: [
                        "domain": AnyCodable(domain),
                        "hasCredentials": AnyCodable(!credentials.isEmpty),
                        "count": AnyCodable(credentials.count)
                    ]
                )
                send(response, to: connection)
            } catch {
                logger.error("Failed to get credentials: \(error.localizedDescription)")
            }
        }
    }

    private func handleAliasRequest(_ message: SyncMessage, from connection: NWConnection) {
        guard let domain = message.data["domain"]?.value as? String else { return }

        Task {
            do {
                let alias = try await TheaEmailProtectionManager.shared.generateAlias(for: domain)

                let response = SyncMessage(
                    type: .aliasResponse,
                    data: [
                        "domain": AnyCodable(domain),
                        "alias": AnyCodable(alias.alias),
                        "id": AnyCodable(alias.id)
                    ]
                )
                send(response, to: connection)
            } catch {
                logger.error("Failed to generate alias: \(error.localizedDescription)")
            }
        }
    }

    private func handleStatsUpdate(_ message: SyncMessage) {
        if let stats = message.data["stats"]?.value as? [String: Any] {
            // Update global stats
            if let adsBlocked = stats["adsBlocked"] as? Int {
                TheaExtensionState.shared.stats.adsBlocked += adsBlocked
            }
            if let trackersBlocked = stats["trackersBlocked"] as? Int {
                TheaExtensionState.shared.stats.trackersBlocked += trackersBlocked
            }
        }
    }

    private func updateConnectionHeartbeat(_ connection: NWConnection) {
        let connectionId = ObjectIdentifier(connection).debugDescription
        if let index = connectedExtensions.firstIndex(where: { $0.connectionId == connectionId }) {
            connectedExtensions[index].lastHeartbeat = Date()
        }
    }

    // MARK: - State Synchronization

    private func sendCurrentState(to connection: NWConnection) {
        let state = getCurrentState()
        let message = SyncMessage(
            type: .stateUpdate,
            data: ["state": AnyCodable(state)]
        )
        send(message, to: connection)
    }

    private func getCurrentState() -> [String: Any] {
        return [
            "adBlockerEnabled": TheaAdBlockerManager.shared.isEnabled,
            "darkModeEnabled": TheaDarkModeManager.shared.isEnabled,
            "darkModeTheme": TheaDarkModeManager.shared.globalTheme.id,
            "privacyProtectionEnabled": TheaPrivacyProtectionManager.shared.isEnabled,
            "passwordManagerEnabled": !TheaPasswordManager.shared.isLocked,
            "emailProtectionEnabled": TheaEmailProtectionManager.shared.settings.autoRemoveTrackers,
            "printFriendlyEnabled": TheaPrintFriendlyManager.shared.settings.autoDetectMainContent,
            "stats": [
                "adsBlocked": TheaExtensionState.shared.stats.adsBlocked,
                "trackersBlocked": TheaExtensionState.shared.stats.trackersBlocked,
                "emailsProtected": TheaExtensionState.shared.stats.emailsProtected,
                "passwordsAutofilled": TheaExtensionState.shared.stats.passwordsAutofilled,
                "pagesDarkened": TheaExtensionState.shared.stats.pagesDarkened
            ]
        ]
    }

    private func mergeExtensionState(_ extensionState: [String: Any]) {
        // Merge stats
        if let stats = extensionState["stats"] as? [String: Int] {
            if let adsBlocked = stats["adsBlocked"] {
                TheaExtensionState.shared.stats.adsBlocked = max(
                    TheaExtensionState.shared.stats.adsBlocked,
                    adsBlocked
                )
            }
            // ... merge other stats
        }
    }

    // MARK: - Message Sending

    private func send(_ message: SyncMessage, to connection: NWConnection) {
        do {
            let data = try JSONEncoder().encode(message)
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
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

    // MARK: - App Group Sync (Safari)

    private func setupAppGroupSync() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.warning("Failed to access app group")
            return
        }

        // Watch for changes from Safari extension
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppGroupChange()
        }
    }

    private func handleAppGroupChange() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        // Check for pending messages from Safari extension
        if let messageData = userDefaults.data(forKey: "safari.pendingMessage") {
            if let message = try? JSONDecoder().decode(SyncMessage.self, from: messageData) {
                handleSafariExtensionMessage(message)
            }
            userDefaults.removeObject(forKey: "safari.pendingMessage")
        }
    }

    private func handleSafariExtensionMessage(_ message: SyncMessage) {
        switch message.type {
        case .stateUpdate, .featureToggle, .statsUpdate:
            handleMessage(message, from: activeConnections.first ?? NWConnection(host: "localhost", port: 0, using: .tcp))
        default:
            break
        }
    }

    private func syncToAppGroup(_ message: SyncMessage) {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        if let data = try? JSONEncoder().encode(message) {
            userDefaults.set(data, forKey: "app.pendingMessage")
        }

        // Also sync current state
        let state = getCurrentState()
        if let stateData = try? JSONSerialization.data(withJSONObject: state) {
            userDefaults.set(stateData, forKey: "app.currentState")
        }
    }

    // MARK: - State Observers

    private func setupStateObservers() {
        // Observe ad blocker changes
        TheaAdBlockerManager.shared.$isEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.broadcastFeatureChange("adBlocker", enabled: enabled)
            }
            .store(in: &cancellables)

        // Observe dark mode changes
        TheaDarkModeManager.shared.$isEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.broadcastFeatureChange("darkMode", enabled: enabled)
            }
            .store(in: &cancellables)

        // Observe privacy protection changes
        TheaPrivacyProtectionManager.shared.$isEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.broadcastFeatureChange("privacyProtection", enabled: enabled)
            }
            .store(in: &cancellables)

        // Observe theme changes
        TheaDarkModeManager.shared.$globalTheme
            .dropFirst()
            .sink { [weak self] theme in
                let message = SyncMessage(
                    type: .themeChange,
                    data: ["theme": AnyCodable(theme.id)]
                )
                self?.broadcast(message)
            }
            .store(in: &cancellables)
    }

    private func broadcastFeatureChange(_ feature: String, enabled: Bool) {
        let message = SyncMessage(
            type: .featureToggle,
            data: [
                "feature": AnyCodable(feature),
                "enabled": AnyCodable(enabled)
            ]
        )
        broadcast(message)
    }

    // MARK: - Public API

    /// Notify extensions of credential update
    public func notifyCredentialUpdate(domain: String) {
        let message = SyncMessage(
            type: .credentialUpdate,
            data: ["domain": AnyCodable(domain)]
        )
        broadcast(message)
    }

    /// Notify extensions of alias creation
    public func notifyAliasCreated(alias: EmailAlias) {
        let message = SyncMessage(
            type: .aliasCreated,
            data: [
                "id": AnyCodable(alias.id),
                "alias": AnyCodable(alias.alias),
                "domain": AnyCodable(alias.domain)
            ]
        )
        broadcast(message)
    }

    /// Force sync with all extensions
    public func forceSync() {
        let message = SyncMessage(
            type: .sync,
            data: ["state": AnyCodable(getCurrentState())]
        )
        broadcast(message)
        lastSyncTime = Date()
    }
}

// MARK: - Supporting Types

public struct ExtensionConnection: Identifiable {
    public let id = UUID()
    public let connectionId: String
    public let type: ExtensionType
    public let version: String
    public let connectedAt: Date
    public var lastHeartbeat: Date
}

public enum ExtensionType: String, Codable {
    case safari
    case chrome
    case brave
}

public struct SyncMessage: Codable {
    public let type: MessageType
    public let data: [String: AnyCodable]
    public let timestamp: Date

    public enum MessageType: String, Codable {
        case identify
        case sync
        case stateUpdate
        case featureToggle
        case credentialRequest
        case credentialResponse
        case credentialUpdate
        case aliasRequest
        case aliasResponse
        case aliasCreated
        case statsUpdate
        case themeChange
        case heartbeat
    }

    public init(type: MessageType, data: [String: AnyCodable]) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

public struct SyncSettings: Codable {
    public var autoSync: Bool = true
    public var syncInterval: TimeInterval = 30
    public var syncOnAppForeground: Bool = true
    public var syncStats: Bool = true
    public var syncCredentials: Bool = true
    public var syncAliases: Bool = true
    public var syncThemes: Bool = true
}
