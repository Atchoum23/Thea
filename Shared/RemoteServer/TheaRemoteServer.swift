//
//  TheaRemoteServer.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Combine
import CryptoKit
import Foundation
import Network

// Supporting types (RemoteServerConfiguration) and non-macOS stubs are in TheaRemoteServerTypes.swift

// MARK: - Thea Remote Server

#if os(macOS)
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
        @Published public private(set) var transferStats: TransferStatistics = .init()
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

        // Extended services
        public let videoEncoder = VideoEncoderService()
        public let qualityMonitor = ConnectionQualityMonitor()
        public let clipboardSync = ClipboardSyncService()
        public let unattendedAccess = UnattendedAccessManager()
        public let privacyMode = PrivacyModeService()
        public let sessionRecording = SessionRecordingService()
        public let wakeOnLan = WakeOnLanService()
        public let sessionChat = SessionChatService()
        public let annotationOverlay = AnnotationOverlayService()
        public let auditLog = AuditLogService()
        public let totpAuth = TOTPAuthenticator()
        public let audioStream = AudioStreamService()
        public let assetInventory = AssetInventoryService()

        // MARK: - Network

        private var listener: NWListener?
        private var tlsParameters: NWParameters?
        private var cancellables = Set<AnyCancellable>()

        // MARK: - Initialization

        private init() {
            configuration = RemoteServerConfiguration.load()
            screenService = RemoteScreenService()
            inputService = RemoteInputService()
            fileService = RemoteFileService()
            systemService = RemoteSystemService()
            networkDiscovery = NetworkDiscoveryService()
            connectionManager = SecureConnectionManager()
            sessionManager = RemoteSessionManager()

            setupObservers()
        }

        // MARK: - Setup

        private func setupObservers() {
            // Monitor session changes
            sessionManager.$activeSessions
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessions in
                    self?.connectedClients = sessions.map(\.client)
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
            case let .failed(error):
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

            guard case let .authResponse(authData) = response else {
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
            case let .screenRequest(request):
                let response = try await screenService.handleRequest(request)
                try await session.send(message: .screenResponse(response))

            case let .inputRequest(request):
                try await inputService.handleRequest(request)
                try await session.send(message: .inputAck)

            case let .fileRequest(request):
                let response = try await fileService.handleRequest(request)
                try await session.send(message: .fileResponse(response))

            case let .systemRequest(request):
                let response = try await systemService.handleRequest(request, requireConfirmation: configuration.requireConfirmation)
                try await session.send(message: .systemResponse(response))

            case let .networkRequest(request):
                let response = try await handleNetworkRequest(request)
                try await session.send(message: .networkResponse(response))

            case let .clipboardRequest(request):
                let response = await handleClipboardRequest(request)
                try await session.send(message: .clipboardResponse(response))

            case let .chatMessage(chatMsg):
                sessionChat.receiveMessage(chatMsg)

            case let .annotationRequest(request):
                handleAnnotationRequest(request)

            case let .recordingRequest(request):
                let response = await handleRecordingRequest(request)
                try await session.send(message: .recordingResponse(response))

            case let .audioRequest(request):
                let response = await handleAudioRequest(request)
                try await session.send(message: .audioResponse(response))

            case let .inventoryRequest(request):
                let response = await handleInventoryRequest(request)
                try await session.send(message: .inventoryResponse(response))

            case let .inferenceRelayRequest(relayData):
                let relayMessage = try JSONDecoder().decode(InferenceRelayMessage.self, from: relayData)
                switch relayMessage {
                case let .inferenceRequest(request):
                    await InferenceRelayHandler.shared.handleInferenceRequest(request) { response in
                        let encoded = try JSONEncoder().encode(response)
                        try await session.send(message: .inferenceRelayResponse(encoded))
                    }
                case .listModelsRequest:
                    let models = await InferenceRelayHandler.shared.handleListModelsRequest()
                    let response = InferenceRelayMessage.listModelsResponse(models)
                    let encoded = try JSONEncoder().encode(response)
                    try await session.send(message: .inferenceRelayResponse(encoded))
                case .capabilitiesRequest:
                    let caps = InferenceRelayHandler.shared.getServerCapabilities()
                    let response = InferenceRelayMessage.capabilitiesResponse(caps)
                    let encoded = try JSONEncoder().encode(response)
                    try await session.send(message: .inferenceRelayResponse(encoded))
                default:
                    break
                }

            case .ping:
                qualityMonitor.recordPingSent()
                try await session.send(message: .pong)

            case .disconnect:
                await sessionManager.terminateSession(session.id, reason: "Client disconnected")

            default:
                break
            }

            // Update statistics
            transferStats.messagesReceived += 1
        }

        // MARK: - Extended Message Handlers

        private func handleClipboardRequest(_ request: ClipboardRequest) async -> ClipboardResponse {
            switch request {
            case .getClipboard:
                if let data = clipboardSync.getCurrentClipboard() {
                    return .clipboardData(data)
                }
                return .error("No clipboard data available")
            case let .setClipboard(data):
                clipboardSync.applyRemoteClipboard(data)
                return .clipboardData(data)
            case .startSync:
                clipboardSync.startSync()
                return .syncStarted
            case .stopSync:
                clipboardSync.stopSync()
                return .syncStopped
            }
        }

        private func handleAnnotationRequest(_ request: AnnotationRequest) {
            switch request {
            case let .addAnnotation(data):
                annotationOverlay.addRemoteAnnotation(data)
            case let .removeAnnotation(id):
                annotationOverlay.removeAnnotation(id: id)
            case .clearAnnotations:
                annotationOverlay.clearAnnotations()
            case .undoLastAnnotation:
                annotationOverlay.undoLastAnnotation()
            }
        }

        private func handleRecordingRequest(_ request: RecordingRequest) async -> RecordingResponse {
            switch request {
            case let .startRecording(sessionId):
                do {
                    let recordingId = try sessionRecording.startRecording(
                        sessionId: sessionId,
                        width: 1920,
                        height: 1080
                    )
                    auditLog.log(action: .screenRecordingStarted, sessionId: sessionId, clientId: "", clientName: "", details: "Recording started: \(recordingId)")
                    return .recordingStarted(recordingId: recordingId)
                } catch {
                    return .error(error.localizedDescription)
                }
            case .stopRecording:
                if let metadata = await sessionRecording.stopRecording() {
                    auditLog.log(action: .screenRecordingStopped, sessionId: metadata.sessionId, clientId: "", clientName: "", details: "Recording stopped: \(metadata.id)")
                    return .recordingStopped(recordingId: metadata.id, durationSeconds: metadata.durationSeconds, fileSizeBytes: metadata.fileSizeBytes)
                }
                return .error("No recording in progress")
            case .listRecordings:
                return .recordingList(sessionRecording.recordings)
            case let .deleteRecording(id):
                do {
                    try sessionRecording.deleteRecording(id: id)
                } catch {
                    return .error("Failed to delete recording: \(error.localizedDescription)")
                }
                return .recordingList(sessionRecording.recordings)
            }
        }

        private func handleAudioRequest(_ request: AudioRequest) async -> AudioResponse {
            switch request {
            case .startAudioStream:
                do {
                    try await audioStream.startCapture()
                    return .audioStreamStarted
                } catch {
                    return .error(error.localizedDescription)
                }
            case .stopAudioStream:
                await audioStream.stopCapture()
                return .audioStreamStopped
            case let .setAudioVolume(volume):
                audioStream.volume = volume
                return .audioStreamStarted
            case .startMicrophoneForward, .stopMicrophoneForward:
                return .error("Microphone forwarding not yet implemented")
            }
        }

        private func handleInventoryRequest(_ request: InventoryRequest) async -> InventoryResponse {
            switch request {
            case .getHardwareInventory:
                let hw = await assetInventory.collectHardwareInventory()
                return .hardwareInventory(hw)
            case .getSoftwareInventory:
                let sw = await assetInventory.collectSoftwareInventory()
                return .softwareInventory(sw)
            case .getFullInventory:
                let result = await assetInventory.collectFullInventory()
                return .hardwareInventory(result.hardware)
            }
        }

        // MARK: - Network Proxy

        // SECURITY: Network proxy functionality has been removed to prevent SSRF attacks (FINDING-001)
        // The proxy allowed arbitrary HTTP/TCP requests which could be used for:
        // - Internal network scanning
        // - Lateral movement
        // - Data exfiltration
        // - Accessing internal services (127.0.0.1, 169.254.x.x, 10.x.x.x, etc.)

        private func handleNetworkRequest(_: NetworkProxyRequest) async throws -> NetworkProxyResponse {
            // SECURITY FIX (FINDING-001): Network proxy is permanently disabled
            // This feature was identified as a critical security vulnerability
            logSecurityEvent(.commandBlocked, details: "Network proxy request blocked - feature disabled for security")
            throw RemoteServerError.featureDisabled("Network proxy has been permanently disabled for security reasons (SSRF prevention)")
        }

        // SECURITY: These methods are kept as stubs but will never be called
        // They remain for API compatibility but throw immediately

        private func performHTTPRequest(url _: URL, method _: String, headers _: [String: String], body _: Data?) async throws -> NetworkProxyResponse {
            // SECURITY FIX (FINDING-001): HTTP proxy disabled
            // periphery:ignore - Reserved: performHTTPRequest(url:method:headers:body:) instance method reserved for future feature activation
            throw RemoteServerError.featureDisabled("HTTP proxy disabled for security")
        }

        private func establishTCPProxy(host _: String, port _: Int) async throws -> NetworkProxyResponse {
            // periphery:ignore - Reserved: establishTCPProxy(host:port:) instance method reserved for future feature activation
            // SECURITY FIX (FINDING-001): TCP proxy disabled
            throw RemoteServerError.featureDisabled("TCP proxy disabled for security")
        }

        // periphery:ignore - Reserved: scanLocalNetwork() instance method reserved for future feature activation
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
                        address = String(decoding: hostname.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
                    }
                }
            }

            return address
        }

        private func logSecurityEvent(_ type: SecurityEventType, details: String) {
            let event = SecurityEvent(type: type, details: details, timestamp: Date())
            securityEvents.append(event)

            // Also log to persistent audit log
            auditLog.logSecurityEvent(type: type, details: details)

            // Keep only recent in-memory events
            if securityEvents.count > 1000 {
                securityEvents.removeFirst(500)
            }
        }
    }

#endif
