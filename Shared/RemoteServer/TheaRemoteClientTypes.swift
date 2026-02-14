//
//  TheaRemoteClientTypes.swift
//  Thea
//
//  Supporting types for TheaRemoteClient
//  Copyright 2026. All rights reserved.
//

import Foundation

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
        case .alreadyConnected: "Already connected to a server"
        case .notConnected: "Not connected to a server"
        case .connectionTimeout: "Connection timed out"
        case .connectionCancelled: "Connection was cancelled"
        case .connectionClosed: "Connection was closed"
        case .invalidAddress: "Invalid server address"
        case .keyNotInitialized: "Client keys not initialized"
        case let .authenticationFailed(reason): "Authentication failed: \(reason)"
        case .unexpectedMessage: "Received unexpected message"
        case .permissionDenied: "Permission denied for this operation"
        case .timeout: "Operation timed out"
        case let .serverError(error): "Server error: \(error)"
        case let .confirmationRequired(action, _): "Confirmation required for: \(action)"
        }
    }
}
