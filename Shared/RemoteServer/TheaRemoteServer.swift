//
//  TheaRemoteServer.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import Network
import CryptoKit
import Combine

// MARK: - Thea Remote Server

/// Core remote server that enables Thea to act as a gateway to the entire system
/// Provides screen sharing, input control, file access, system control, and network access
@MainActor
public class TheaRemoteServer: ObservableObject {
    public static let shared = TheaRemoteServer()

    // MARK: - Published State

    @Published public private(set) var isRunning = false
    @Published public private(set) var serverStatus: ServerStatus = .stopped
    @Published public private(set) var connectedClients: [RemoteClient] = []
    @Published public private(set) var serverAddress: String?
    @Published public private(set) var serverPort: UInt16 = 0
    @Published public private(set) var transferStats: TransferStatistics = TransferStatistics()
    @Published public private(set) var securityEvents: [SecurityEvent] = []

    // MARK: - Configuration

    @Published public var configuration: RemoteServerConfiguration {
        didSet { configuration.save() }
    }

    // MARK: - Services

    public let screenService: RemoteScreenService
    public let inputService: RemoteInputService
    public let fileService: RemoteFileService
    public let systemService: RemoteSystemService
    public let networkDiscovery: NetworkDiscoveryService
    public let connectionManager: SecureConnectionManager
    public let sessionManager: RemoteSessionManager

    // MARK: - Network

    private var listener: NWListener?
    private var tlsParameters: NWParameters?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        self.configuration = RemoteServerConfiguration.load()
        self.screenService = RemoteScreenService()
        self.inputService = RemoteInputService()
        self.fileService = RemoteFileService()
        self.systemService = RemoteSystemService()
        self.networkDiscovery = NetworkDiscoveryService()
        self.connectionManager = SecureConnectionManager()
        self.sessionManager = RemoteSessionManager()

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Monitor session changes
        sessionManager.$activeSessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.connectedClients = sessions.map { $0.client }
            }
            .store(in: &cancellables)

        // Monitor connection manager events
        connectionManager.$securityEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                self?.securityEvents = events
            }
            .store(in: &cancellables)
    }

    // MARK: - Server Control

    /// Start the remote server
    public func start() async throws {
        guard !isRunning else { return }

        serverStatus = .starting

        do {
            // Generate or load server identity
            try await connectionManager.initialize()

            // Create TLS parameters
            tlsParameters = try connectionManager.createTLSParameters()

            // Create listener
            let parameters = tlsParameters ?? NWParameters.tcp
            parameters.includePeerToPeer = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: configuration.port) ?? .any)

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerStateChange(state)
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    await self?.handleNewConnection(connection)
                }
            }

            listener?.start(queue: .global(qos: .userInteractive))

            // Start network discovery
            if configuration.enableDiscovery {
                await networkDiscovery.startAdvertising(
                    serverName: configuration.serverName,
                    port: configuration.port
                )
            }

            isRunning = true
            serverStatus = .running
            serverPort = listener?.port?.rawValue ?? configuration.port
            serverAddress = getLocalIPAddress()

            logSecurityEvent(.serverStarted, details: "Server started on port \(serverPort)")

        } catch {
            serverStatus = .error(error.localizedDescription)
            throw error
        }
    }

    /// Stop the remote server
    public func stop() async {
        guard isRunning else { return }

        serverStatus = .stopping

        // Disconnect all clients
        await sessionManager.disconnectAll(reason: "Server shutting down")

        // Stop listener
        listener?.cancel()
        listener = nil

        // Stop network discovery
        await networkDiscovery.stopAdvertising()

        isRunning = false
        serverStatus = .stopped
        serverAddress = nil
        serverPort = 0

        logSecurityEvent(.serverStopped, details: "Server stopped gracefully")
    }

    // MARK: - Connection Handling

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            serverStatus = .running
        case .failed(let error):
            serverStatus = .error(error.localizedDescription)
            logSecurityEvent(.serverError, details: "Listener failed: \(error)")
        case .cancelled:
            serverStatus = .stopped
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) async {
        // Check if we allow new connections
        guard connectedClients.count < configuration.maxConnections else {
            connection.cancel()
            logSecurityEvent(.connectionRejected, details: "Max connections reached")
            return
        }

        // Validate connection
        let endpoint = connection.endpoint

        // Check IP whitelist if enabled
        if configuration.useWhitelist {
            guard await connectionManager.isWhitelisted(endpoint) else {
                connection.cancel()
                logSecurityEvent(.connectionRejected, details: "IP not in whitelist: \(endpoint)")
                return
            }
        }

        // Check rate limiting
        guard await connectionManager.checkRateLimit(for: endpoint) else {
            connection.cancel()
            logSecurityEvent(.rateLimitExceeded, details: "Rate limit exceeded: \(endpoint)")
            return
        }

        // Create session
        let session = await sessionManager.createSession(for: connection)

        // Handle authentication
        Task {
            do {
                try await authenticateSession(session)
            } catch {
                await sessionManager.terminateSession(session.id, reason: "Authentication failed")
            }
        }
    }

    private func authenticateSession(_ session: RemoteSession) async throws {
        // Send authentication challenge
        let challenge = try connectionManager.generateChallenge()
        try await session.send(message: .authChallenge(challenge))

        // Wait for response with timeout
        let response = try await session.receiveWithTimeout(timeout: configuration.authTimeout)

        guard case .authResponse(let authData) = response else {
            throw RemoteServerError.authenticationFailed("Invalid response type")
        }

        // Verify authentication
        let isValid = try await connectionManager.verifyAuthentication(
            challenge: challenge,
            response: authData,
            method: configuration.authMethod
        )

        guard isValid else {
            logSecurityEvent(.authenticationFailed, details: "Invalid credentials for session \(session.id)")
            throw RemoteServerError.authenticationFailed("Invalid credentials")
        }

        // Update session to authenticated
        await sessionManager.authenticateSession(session.id, permissions: authData.requestedPermissions)

        // Send success
        try await session.send(message: .authSuccess(session.permissions))

        logSecurityEvent(.clientConnected, details: "Client authenticated: \(session.client.name)")

        // Start handling messages
        await handleSessionMessages(session)
    }

    // MARK: - Message Handling

    private func handleSessionMessages(_ session: RemoteSession) async {
        for await message in session.messageStream {
            do {
                try await handleMessage(message, from: session)
            } catch {
                await sessionManager.terminateSession(session.id, reason: error.localizedDescription)
                return
            }
        }
    }

    private func handleMessage(_ message: RemoteMessage, from session: RemoteSession) async throws {
        // Verify permission for the requested action
        guard session.hasPermission(for: message.requiredPermission) else {
            try await session.send(message: .error("Permission denied for \(message.requiredPermission)"))
            logSecurityEvent(.permissionDenied, details: "Session \(session.id) denied: \(message.requiredPermission)")
            return
        }

        switch message {
        case .screenRequest(let request):
            let response = try await screenService.handleRequest(request)
            try await session.send(message: .screenResponse(response))

        case .inputRequest(let request):
            try await inputService.handleRequest(request)
            try await session.send(message: .inputAck)

        case .fileRequest(let request):
            let response = try await fileService.handleRequest(request)
            try await session.send(message: .fileResponse(response))

        case .systemRequest(let request):
            let response = try await systemService.handleRequest(request, requireConfirmation: configuration.requireConfirmation)
            try await session.send(message: .systemResponse(response))

        case .networkRequest(let request):
            let response = try await handleNetworkRequest(request)
            try await session.send(message: .networkResponse(response))

        case .ping:
            try await session.send(message: .pong)

        case .disconnect:
            await sessionManager.terminateSession(session.id, reason: "Client disconnected")

        default:
            break
        }

        // Update statistics
        transferStats.messagesReceived += 1
    }

    // MARK: - Network Proxy
    // SECURITY: Network proxy functionality has been removed to prevent SSRF attacks (FINDING-001)
    // The proxy allowed arbitrary HTTP/TCP requests which could be used for:
    // - Internal network scanning
    // - Lateral movement
    // - Data exfiltration
    // - Accessing internal services (127.0.0.1, 169.254.x.x, 10.x.x.x, etc.)

    private func handleNetworkRequest(_ request: NetworkProxyRequest) async throws -> NetworkProxyResponse {
        // SECURITY FIX (FINDING-001): Network proxy is permanently disabled
        // This feature was identified as a critical security vulnerability
        logSecurityEvent(.commandBlocked, details: "Network proxy request blocked - feature disabled for security")
        throw RemoteServerError.featureDisabled("Network proxy has been permanently disabled for security reasons (SSRF prevention)")
    }

    // SECURITY: These methods are kept as stubs but will never be called
    // They remain for API compatibility but throw immediately

    private func performHTTPRequest(url: URL, method: String, headers: [String: String], body: Data?) async throws -> NetworkProxyResponse {
        // SECURITY FIX (FINDING-001): HTTP proxy disabled
        throw RemoteServerError.featureDisabled("HTTP proxy disabled for security")
    }

    private func establishTCPProxy(host: String, port: Int) async throws -> NetworkProxyResponse {
        // SECURITY FIX (FINDING-001): TCP proxy disabled
        throw RemoteServerError.featureDisabled("TCP proxy disabled for security")
    }

    private func scanLocalNetwork() async throws -> NetworkProxyResponse {
        // SECURITY FIX (FINDING-001): Network scanning disabled
        throw RemoteServerError.featureDisabled("Network scanning disabled for security")
    }

    // MARK: - Utilities

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }

        return address
    }

    private func logSecurityEvent(_ type: SecurityEventType, details: String) {
        let event = SecurityEvent(type: type, details: details, timestamp: Date())
        securityEvents.append(event)

        // Keep only recent events
        if securityEvents.count > 1000 {
            securityEvents.removeFirst(500)
        }
    }
}

// MARK: - Server Configuration

public struct RemoteServerConfiguration: Codable, Sendable {
    public var serverName: String
    public var port: UInt16
    public var maxConnections: Int
    public var authMethod: AuthenticationMethod
    public var authTimeout: TimeInterval
    public var requireConfirmation: Bool
    public var enableDiscovery: Bool
    public var enableScreenSharing: Bool
    public var enableInputControl: Bool
    public var enableFileAccess: Bool
    public var enableSystemControl: Bool
    public var enableNetworkProxy: Bool
    public var useWhitelist: Bool
    public var whitelist: [String]
    public var encryptionRequired: Bool
    public var sessionTimeout: TimeInterval
    public var maxFileTransferSize: Int64
    public var allowedPaths: [String]
    public var blockedPaths: [String]

    // SECURITY FIX (FINDING-015): Network discovery is now opt-in (disabled by default)
    // This prevents automatic network presence exposure and requires explicit user consent
    public init(
        serverName: String = "Thea Remote",
        port: UInt16 = 9847,
        maxConnections: Int = 5,
        authMethod: AuthenticationMethod = .pairingCode,
        authTimeout: TimeInterval = 30,
        requireConfirmation: Bool = true,
        enableDiscovery: Bool = false,  // SECURITY: Disabled by default - requires explicit opt-in
        enableScreenSharing: Bool = true,
        enableInputControl: Bool = true,
        enableFileAccess: Bool = true,
        enableSystemControl: Bool = false,
        enableNetworkProxy: Bool = false,
        useWhitelist: Bool = false,
        whitelist: [String] = [],
        encryptionRequired: Bool = true,
        sessionTimeout: TimeInterval = 3600,
        maxFileTransferSize: Int64 = 1_073_741_824, // 1GB
        allowedPaths: [String] = [],
        blockedPaths: [String] = ["/etc", "/var", "/private", "/System"]
    ) {
        self.serverName = serverName
        self.port = port
        self.maxConnections = maxConnections
        self.authMethod = authMethod
        self.authTimeout = authTimeout
        self.requireConfirmation = requireConfirmation
        self.enableDiscovery = enableDiscovery
        self.enableScreenSharing = enableScreenSharing
        self.enableInputControl = enableInputControl
        self.enableFileAccess = enableFileAccess
        self.enableSystemControl = enableSystemControl
        self.enableNetworkProxy = enableNetworkProxy
        self.useWhitelist = useWhitelist
        self.whitelist = whitelist
        self.encryptionRequired = encryptionRequired
        self.sessionTimeout = sessionTimeout
        self.maxFileTransferSize = maxFileTransferSize
        self.allowedPaths = allowedPaths
        self.blockedPaths = blockedPaths
    }

    private static let storageKey = "RemoteServerConfiguration"

    public static func load() -> RemoteServerConfiguration {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(RemoteServerConfiguration.self, from: data) {
            return config
        }
        return RemoteServerConfiguration()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: RemoteServerConfiguration.storageKey)
        }
    }
}

// MARK: - Authentication Method

public enum AuthenticationMethod: String, Codable, Sendable, CaseIterable {
    case pairingCode       // One-time pairing code
    case sharedSecret      // Pre-shared secret
    case certificate       // Client certificate
    case iCloudIdentity    // Same iCloud account
    case biometric         // Require biometric on server

    public var displayName: String {
        switch self {
        case .pairingCode: return "Pairing Code"
        case .sharedSecret: return "Shared Secret"
        case .certificate: return "Client Certificate"
        case .iCloudIdentity: return "iCloud Identity"
        case .biometric: return "Biometric Verification"
        }
    }
}

// MARK: - Server Status

public enum ServerStatus: Sendable, Equatable {
    case stopped
    case starting
    case running
    case stopping
    case error(String)

    public var isActive: Bool {
        switch self {
        case .running, .starting: return true
        default: return false
        }
    }
}

// MARK: - Remote Client

public struct RemoteClient: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let deviceType: DeviceType
    public let ipAddress: String
    public let connectedAt: Date
    public var lastActivityAt: Date
    public let permissions: Set<RemotePermission>

    public enum DeviceType: String, Codable, Sendable {
        case mac
        case iPhone
        case iPad
        case unknown
    }
}

// MARK: - Remote Permission

public enum RemotePermission: String, Codable, Sendable, CaseIterable {
    case viewScreen
    case controlScreen
    case viewFiles
    case readFiles
    case writeFiles
    case deleteFiles
    case executeCommands
    case systemControl
    case networkAccess

    public var displayName: String {
        switch self {
        case .viewScreen: return "View Screen"
        case .controlScreen: return "Control Screen"
        case .viewFiles: return "View Files"
        case .readFiles: return "Read Files"
        case .writeFiles: return "Write Files"
        case .deleteFiles: return "Delete Files"
        case .executeCommands: return "Execute Commands"
        case .systemControl: return "System Control"
        case .networkAccess: return "Network Access"
        }
    }

    public var riskLevel: RiskLevel {
        switch self {
        case .viewScreen, .viewFiles: return .low
        case .controlScreen, .readFiles: return .medium
        case .writeFiles, .executeCommands, .networkAccess: return .high
        case .deleteFiles, .systemControl: return .critical
        }
    }

    public enum RiskLevel: Int, Sendable, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3

        public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - Transfer Statistics

public struct TransferStatistics: Sendable {
    public var bytesReceived: Int64 = 0
    public var bytesSent: Int64 = 0
    public var messagesReceived: Int64 = 0
    public var messagesSent: Int64 = 0
    public var screenFramesSent: Int64 = 0
    public var filesTransferred: Int64 = 0
}

// MARK: - Security Event

public struct SecurityEvent: Identifiable, Sendable {
    public let id = UUID()
    public let type: SecurityEventType
    public let details: String
    public let timestamp: Date
}

public enum SecurityEventType: String, Codable, Sendable {
    case serverStarted
    case serverStopped
    case serverError
    case clientConnected
    case clientDisconnected
    case connectionRejected
    case authenticationFailed
    case permissionDenied
    case rateLimitExceeded
    case suspiciousActivity
    case fileAccessBlocked
    case commandBlocked
}

// MARK: - Remote Server Error

public enum RemoteServerError: Error, LocalizedError, Sendable {
    case notRunning
    case alreadyRunning
    case authenticationFailed(String)
    case permissionDenied(String)
    case connectionFailed(String)
    case networkError(String)
    case featureDisabled(String)
    case timeout
    case invalidMessage
    case serverFull

    public var errorDescription: String? {
        switch self {
        case .notRunning: return "Server is not running"
        case .alreadyRunning: return "Server is already running"
        case .authenticationFailed(let reason): return "Authentication failed: \(reason)"
        case .permissionDenied(let action): return "Permission denied for: \(action)"
        case .connectionFailed(let reason): return "Connection failed: \(reason)"
        case .networkError(let reason): return "Network error: \(reason)"
        case .featureDisabled(let feature): return "Feature disabled: \(feature)"
        case .timeout: return "Operation timed out"
        case .invalidMessage: return "Invalid message received"
        case .serverFull: return "Server has reached maximum connections"
        }
    }
}
