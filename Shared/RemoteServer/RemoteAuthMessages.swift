//
//  RemoteAuthMessages.swift
//  Thea
//
//  Authentication message types for remote server protocol
//

import Foundation

// MARK: - Authentication Messages

public struct AuthChallenge: Codable, Sendable {
    public let challengeId: String
    public let nonce: Data
    public let timestamp: Date
    public let serverPublicKey: Data?

    public init(challengeId: String = UUID().uuidString, nonce: Data, timestamp: Date = Date(), serverPublicKey: Data? = nil) {
        self.challengeId = challengeId
        self.nonce = nonce
        self.timestamp = timestamp
        self.serverPublicKey = serverPublicKey
    }
}

public struct AuthResponse: Codable, Sendable {
    public let challengeId: String
    public let signature: Data
    public let clientName: String
    public let clientType: RemoteClient.DeviceType
    public let clientPublicKey: Data?
    public let requestedPermissions: Set<RemotePermission>
    public let pairingCode: String?
    public let sharedSecret: Data?

    public init(
        challengeId: String,
        signature: Data,
        clientName: String,
        clientType: RemoteClient.DeviceType,
        clientPublicKey: Data? = nil,
        requestedPermissions: Set<RemotePermission>,
        pairingCode: String? = nil,
        sharedSecret: Data? = nil
    ) {
        self.challengeId = challengeId
        self.signature = signature
        self.clientName = clientName
        self.clientType = clientType
        self.clientPublicKey = clientPublicKey
        self.requestedPermissions = requestedPermissions
        self.pairingCode = pairingCode
        self.sharedSecret = sharedSecret
    }
}
