//
//  TheaRemoteClient.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import Network
import CryptoKit
import Combine

// MARK: - Thea Remote Client

/// Client for connecting to Thea remote servers on other devices
@MainActor
public class TheaRemoteClient: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var connectionState: ClientConnectionState = .disconnected
    @Published public private(set) var connectedServer: DiscoveredDevice?
    @Published public private(set) var grantedPermissions: Set<RemotePermission> = []
    @Published public private(set) var latency: TimeInterval = 0
    @Published public private(set) var lastScreenFrame: ScreenFrame?

    // MARK: - Connection

    private var connection: NWConnection?
    private var messageTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    // MARK: - Encryption

    private var clientPrivateKey: P256.KeyAgreement.PrivateKey?
    private var sessionKey: Data?

    // MARK: - Callbacks

    public var onScreenFrame: ((ScreenFrame) -> Void)?
    public var onDisconnect: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Initialization

    public init() {
        // Generate client key pair
        clientPrivateKey = P256.KeyAgreement.PrivateKey()
    }

    // MARK: - Connection

    /// Connect to a Thea remote server
    public func connect(
        to host: String,
        port: UInt16,
        authMethod: AuthenticationMethod,
        credentials: ClientCredentials
    ) async throws {
        guard connectionState == .disconnected else {
            throw ClientError.alreadyConnected
        }

        connectionState = .connecting

        // Create connection
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )

        // Configure TLS
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)

        // Accept any certificate (we do app-level auth)
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, _, completion in
            completion(true)
        }, .global(qos: .userInteractive))

        let parameters = NWParameters(tls: tlsOptions)
        connection = NWConnection(to: endpoint, using: parameters)

        // Set up state handler
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state)
            }
        }

        // Start connection
        connection?.start(queue: .global(qos: .userInteractive))

        // Wait for connection
        try await waitForConnection()

        // Authenticate
        try await authenticate(method: authMethod, credentials: credentials)

        // Start message handling
        startMessageHandling()

        // Start ping loop
        startPingLoop()
    }

    /// Connect to a discovered device
    public func connect(
        to device: DiscoveredDevice,
        authMethod: AuthenticationMethod,
        credentials: ClientCredentials
    ) async throws {
        guard let address = device.address, let port = device.port else {
            throw ClientError.invalidAddress
        }

        try await connect(to: address, port: port, authMethod: authMethod, credentials: credentials)
        connectedServer = device
    }

    /// Disconnect from server
    public func disconnect() async {
        messageTask?.cancel()
        pingTask?.cancel()

        // Send disconnect message
        if connectionState == .connected {
            try? await send(message: .disconnect)
        }

        connection?.cancel()
        connection = nil

        connectionState = .disconnected
        connectedServer = nil
        grantedPermissions = []
        sessionKey = nil

        onDisconnect?("User disconnected")
    }

    // MARK: - Connection Handling

    private func waitForConnection() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                continuation.resume(throwing: ClientError.connectionTimeout)
            }

            connection?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    timeoutTask.cancel()
                    continuation.resume()
                case .failed(let error):
                    timeoutTask.cancel()
                    continuation.resume(throwing: error)
                case .cancelled:
                    timeoutTask.cancel()
                    continuation.resume(throwing: ClientError.connectionCancelled)
                default:
                    break
                }

                Task { @MainActor in
                    self?.handleConnectionState(state)
                }
            }
        }
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .preparing:
            connectionState = .connecting
        case .ready:
            if connectionState != .connected {
                connectionState = .authenticating
            }
        case .failed(let error):
            connectionState = .error(error.localizedDescription)
            onError?(error)
        case .cancelled:
            connectionState = .disconnected
        default:
            break
        }
    }

    // MARK: - Authentication

    private func authenticate(method: AuthenticationMethod, credentials: ClientCredentials) async throws {
        connectionState = .authenticating

        // Wait for challenge
        let challengeMessage = try await receiveWithTimeout(timeout: 30)

        guard case .authChallenge(let challenge) = challengeMessage else {
            throw ClientError.unexpectedMessage
        }

        // Generate session key if server provided public key
        if let serverPublicKeyData = challenge.serverPublicKey {
            sessionKey = try generateSessionKey(serverPublicKeyData: serverPublicKeyData)
        }

        // Build response
        let response = try buildAuthResponse(
            challenge: challenge,
            method: method,
            credentials: credentials
        )

        try await send(message: .authResponse(response))

        // Wait for result
        let resultMessage = try await receiveWithTimeout(timeout: 30)

        switch resultMessage {
        case .authSuccess(let permissions):
            grantedPermissions = permissions
            connectionState = .connected

        case .authFailure(let reason):
            throw ClientError.authenticationFailed(reason)

        default:
            throw ClientError.unexpectedMessage
        }
    }

    private func buildAuthResponse(
        challenge: AuthChallenge,
        method: AuthenticationMethod,
        credentials: ClientCredentials
    ) throws -> AuthResponse {
        // Sign the challenge nonce
        let signature: Data
        if let sessionKey = sessionKey {
            let key = SymmetricKey(data: sessionKey)
            signature = Data(HMAC<SHA256>.authenticationCode(for: challenge.nonce, using: key))
        } else {
            signature = Data()
        }

        return AuthResponse(
            challengeId: challenge.challengeId,
            signature: signature,
            clientName: credentials.clientName,
            clientType: credentials.deviceType,
            clientPublicKey: clientPrivateKey?.publicKey.rawRepresentation,
            requestedPermissions: credentials.requestedPermissions,
            pairingCode: credentials.pairingCode,
            sharedSecret: credentials.sharedSecret
        )
    }

    private func generateSessionKey(serverPublicKeyData: Data) throws -> Data {
        guard let privateKey = clientPrivateKey else {
            throw ClientError.keyNotInitialized
        }

        let serverKey = try P256.KeyAgreement.PublicKey(rawRepresentation: serverPublicKeyData)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: serverKey)

        let sessionKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: "thea.remote.session".data(using: .utf8)!,
            outputByteCount: 32
        )

        return sessionKey.withUnsafeBytes { Data($0) }
    }

    // MARK: - Message Handling

    private func startMessageHandling() {
        messageTask = Task {
            while !Task.isCancelled && connectionState == .connected {
                do {
                    let message = try await receiveMessage()
                    await handleMessage(message)
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            connectionState = .error(error.localizedDescription)
                            onError?(error)
                        }
                    }
                    return
                }
            }
        }
    }

    private func handleMessage(_ message: RemoteMessage) async {
        switch message {
        case .screenResponse(let response):
            if case .frame(let frame) = response {
                lastScreenFrame = frame
                onScreenFrame?(frame)
            }

        case .pong:
            // Latency is measured in ping loop
            break

        case .error(let errorMessage):
            onError?(ClientError.serverError(errorMessage))

        case .disconnect:
            await disconnect()
            onDisconnect?("Server disconnected")

        default:
            break
        }
    }

    // MARK: - Ping

    private func startPingLoop() {
        pingTask = Task {
            while !Task.isCancelled && connectionState == .connected {
                let pingTime = Date()
                try? await send(message: .ping)

                // Wait for pong (with timeout)
                do {
                    let response = try await receiveWithTimeout(timeout: 5)
                    if case .pong = response {
                        await MainActor.run {
                            latency = Date().timeIntervalSince(pingTime)
                        }
                    }
                } catch {
                    // Ping timeout - connection may be dead
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }

    // MARK: - Screen Operations

    /// Request a full screen capture
    public func captureScreen(quality: Float = 0.7, scale: Float = 0.5) async throws -> ScreenFrame {
        guard connectionState == .connected else {
            throw ClientError.notConnected
        }

        guard grantedPermissions.contains(.viewScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .screenRequest(.captureFullScreen(quality: quality, scale: scale)))

        let response = try await receiveWithTimeout(timeout: 30)

        guard case .screenResponse(let screenResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case .frame(let frame) = screenResponse else {
            if case .error(let error) = screenResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        lastScreenFrame = frame
        return frame
    }

    /// Start screen streaming
    public func startScreenStream(fps: Int = 30, quality: Float = 0.5, scale: Float = 0.5) async throws {
        guard connectionState == .connected else {
            throw ClientError.notConnected
        }

        guard grantedPermissions.contains(.viewScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .screenRequest(.startStream(fps: fps, quality: quality, scale: scale)))
    }

    /// Stop screen streaming
    public func stopScreenStream() async throws {
        try await send(message: .screenRequest(.stopStream))
    }

    // MARK: - Input Operations

    /// Move mouse to position
    public func moveMouse(to x: Int, _ y: Int) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.mouseMove(x: x, y: y)))
    }

    /// Click at position
    public func click(at x: Int, _ y: Int, button: InputRequest.MouseButton = .left, clickCount: Int = 1) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.mouseClick(x: x, y: y, button: button, clickCount: clickCount)))
    }

    /// Type text
    public func typeText(_ text: String) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.typeText(text)))
    }

    /// Press a key
    public func pressKey(keyCode: UInt16, modifiers: KeyModifiers = []) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.keyPress(keyCode: keyCode, modifiers: modifiers)))
    }

    /// Scroll at position
    public func scroll(at x: Int, _ y: Int, deltaX: Int, deltaY: Int) async throws {
        guard grantedPermissions.contains(.controlScreen) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .inputRequest(.scroll(x: x, y: y, deltaX: deltaX, deltaY: deltaY)))
    }

    // MARK: - File Operations

    /// List directory contents
    public func listDirectory(_ path: String, recursive: Bool = false, showHidden: Bool = false) async throws -> [FileItem] {
        guard grantedPermissions.contains(.viewFiles) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .fileRequest(.list(path: path, recursive: recursive, showHidden: showHidden)))

        let response = try await receiveWithTimeout(timeout: 60)

        guard case .fileResponse(let fileResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case .listing(let items) = fileResponse else {
            if case .error(let error) = fileResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        return items
    }

    /// Download a file
    public func downloadFile(_ path: String) async throws -> Data {
        guard grantedPermissions.contains(.readFiles) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .fileRequest(.download(path: path)))

        let response = try await receiveWithTimeout(timeout: 300) // 5 minute timeout for large files

        guard case .fileResponse(let fileResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case .data(let data, _) = fileResponse else {
            if case .error(let error) = fileResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        return data
    }

    /// Upload a file
    public func uploadFile(_ data: Data, to path: String, overwrite: Bool = false) async throws {
        guard grantedPermissions.contains(.writeFiles) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .fileRequest(.upload(path: path, data: data, overwrite: overwrite)))

        let response = try await receiveWithTimeout(timeout: 300)

        guard case .fileResponse(let fileResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        if case .error(let error) = fileResponse {
            throw ClientError.serverError(error)
        }
    }

    // MARK: - System Operations

    /// Get system information
    public func getSystemInfo() async throws -> SystemInfo {
        try await send(message: .systemRequest(.getInfo))

        let response = try await receiveWithTimeout(timeout: 10)

        guard case .systemResponse(let systemResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        guard case .info(let info) = systemResponse else {
            if case .error(let error) = systemResponse {
                throw ClientError.serverError(error)
            }
            throw ClientError.unexpectedMessage
        }

        return info
    }

    /// Execute a command
    public func executeCommand(_ command: String, workingDirectory: String? = nil, timeout: TimeInterval = 60) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        guard grantedPermissions.contains(.executeCommands) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .systemRequest(.executeCommand(command: command, workingDirectory: workingDirectory, timeout: timeout)))

        let response = try await receiveWithTimeout(timeout: timeout + 10)

        guard case .systemResponse(let systemResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        switch systemResponse {
        case .commandOutput(let exitCode, let stdout, let stderr):
            return (exitCode, stdout, stderr)
        case .confirmationRequired(let action, let confirmationId):
            throw ClientError.confirmationRequired(action: action, confirmationId: confirmationId)
        case .error(let error):
            throw ClientError.serverError(error)
        default:
            throw ClientError.unexpectedMessage
        }
    }

    /// Request system reboot
    public func reboot() async throws {
        guard grantedPermissions.contains(.systemControl) else {
            throw ClientError.permissionDenied
        }

        try await send(message: .systemRequest(.reboot))

        let response = try await receiveWithTimeout(timeout: 60)

        guard case .systemResponse(let systemResponse) = response else {
            throw ClientError.unexpectedMessage
        }

        if case .error(let error) = systemResponse {
            throw ClientError.serverError(error)
        }
    }

    // MARK: - Network Send/Receive

    private func send(message: RemoteMessage) async throws {
        guard let connection = connection else {
            throw ClientError.notConnected
        }

        let data = try message.encode()

        // Add length prefix
        var length = UInt32(data.count).bigEndian
        var framedData = Data(bytes: &length, count: 4)
        framedData.append(data)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: framedData, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveMessage() async throws -> RemoteMessage {
        // Receive length prefix
        let lengthData = try await receiveData(length: 4)
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        // Receive message
        let messageData = try await receiveData(length: Int(length))
        return try RemoteMessage.decode(from: messageData)
    }

    private func receiveWithTimeout(timeout: TimeInterval) async throws -> RemoteMessage {
        try await withThrowingTaskGroup(of: RemoteMessage.self) { group in
            group.addTask {
                try await self.receiveMessage()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ClientError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func receiveData(length: Int) async throws -> Data {
        guard let connection = connection else {
            throw ClientError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { content, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = content {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: ClientError.connectionClosed)
                }
            }
        }
    }
}

// MARK: - Client Connection State

public enum ClientConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case error(String)
}

// MARK: - Client Credentials

public struct ClientCredentials: Sendable {
    public let clientName: String
    public let deviceType: RemoteClient.DeviceType
    public let requestedPermissions: Set<RemotePermission>
    public var pairingCode: String?
    public var sharedSecret: Data?

    public init(
        clientName: String,
        deviceType: RemoteClient.DeviceType,
        requestedPermissions: Set<RemotePermission>,
        pairingCode: String? = nil,
        sharedSecret: Data? = nil
    ) {
        self.clientName = clientName
        self.deviceType = deviceType
        self.requestedPermissions = requestedPermissions
        self.pairingCode = pairingCode
        self.sharedSecret = sharedSecret
    }
}

// MARK: - Client Error

public enum ClientError: Error, LocalizedError, Sendable {
    case alreadyConnected
    case notConnected
    case connectionTimeout
    case connectionCancelled
    case connectionClosed
    case invalidAddress
    case keyNotInitialized
    case authenticationFailed(String)
    case unexpectedMessage
    case permissionDenied
    case timeout
    case serverError(String)
    case confirmationRequired(action: String, confirmationId: String)

    public var errorDescription: String? {
        switch self {
        case .alreadyConnected: return "Already connected to a server"
        case .notConnected: return "Not connected to a server"
        case .connectionTimeout: return "Connection timed out"
        case .connectionCancelled: return "Connection was cancelled"
        case .connectionClosed: return "Connection was closed"
        case .invalidAddress: return "Invalid server address"
        case .keyNotInitialized: return "Client keys not initialized"
        case .authenticationFailed(let reason): return "Authentication failed: \(reason)"
        case .unexpectedMessage: return "Received unexpected message"
        case .permissionDenied: return "Permission denied for this operation"
        case .timeout: return "Operation timed out"
        case .serverError(let error): return "Server error: \(error)"
        case .confirmationRequired(let action, _): return "Confirmation required for: \(action)"
        }
    }
}
