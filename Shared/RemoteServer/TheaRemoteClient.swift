//
//  TheaRemoteClient.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Combine
import CryptoKit
import Foundation
import Network

// Supporting types (ClientConnectionState, ClientCredentials, ClientError) are in TheaRemoteClientTypes.swift

// MARK: - Thea Remote Client

/// Client for connecting to Thea remote servers on other devices
@MainActor
public class TheaRemoteClient: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var connectionState: ClientConnectionState = .disconnected
    @Published public private(set) var connectedServer: DiscoveredDevice?
    @Published public private(set) var grantedPermissions: Set<RemotePermission> = []
    @Published public private(set) var latency: TimeInterval = 0
    @Published public internal(set) var lastScreenFrame: ScreenFrame?

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
                case let .failed(error):
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
        case let .failed(error):
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

        guard case let .authChallenge(challenge) = challengeMessage else {
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
        case let .authSuccess(permissions):
            grantedPermissions = permissions
            connectionState = .connected

        case let .authFailure(reason):
            throw ClientError.authenticationFailed(reason)

        default:
            throw ClientError.unexpectedMessage
        }
    }

    private func buildAuthResponse(
        challenge: AuthChallenge,
        method _: AuthenticationMethod,
        credentials: ClientCredentials
    ) throws -> AuthResponse {
        // Sign the challenge nonce
        let signature: Data
        if let sessionKey {
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
            sharedInfo: Data("thea.remote.session".utf8),
            outputByteCount: 32
        )

        return sessionKey.withUnsafeBytes { Data($0) }
    }

    // MARK: - Message Handling

    private func startMessageHandling() {
        messageTask = Task {
            while !Task.isCancelled, connectionState == .connected {
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
        case let .screenResponse(response):
            if case let .frame(frame) = response {
                lastScreenFrame = frame
                onScreenFrame?(frame)
            }

        case .pong:
            // Latency is measured in ping loop
            break

        case let .error(errorMessage):
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
            while !Task.isCancelled, connectionState == .connected {
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

    // MARK: - Network Send/Receive

    func send(message: RemoteMessage) async throws {
        guard let connection else {
            throw ClientError.notConnected
        }

        let data = try message.encode()

        // Add length prefix
        var length = UInt32(data.count).bigEndian
        var framedData = Data(bytes: &length, count: 4)
        framedData.append(data)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: framedData, completion: .contentProcessed { error in
                if let error {
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

    func receiveWithTimeout(timeout: TimeInterval) async throws -> RemoteMessage {
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
        guard let connection else {
            throw ClientError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { content, _, isComplete, error in
                if let error {
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
