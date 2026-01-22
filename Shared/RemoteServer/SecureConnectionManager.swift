//
//  SecureConnectionManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import Network
import CryptoKit
import Security
import Combine

// MARK: - Secure Connection Manager

/// Manages TLS connections, authentication, and encryption for remote access
@MainActor
public class SecureConnectionManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isInitialized = false
    @Published public private(set) var securityEvents: [SecurityEvent] = []
    @Published public private(set) var activePairingCode: String?

    // MARK: - Security Configuration

    public var whitelist: Set<String> = []
    public var rateLimitPerMinute: Int = 10
    public var challengeValiditySeconds: TimeInterval = 30

    // MARK: - Keys

    private var serverPrivateKey: P256.Signing.PrivateKey?
    private var serverPublicKey: P256.Signing.PublicKey?
    private var sharedSecret: SymmetricKey?

    // MARK: - Rate Limiting

    private var connectionAttempts: [String: [Date]] = [:]

    // MARK: - Pairing

    private var pairingCodes: [String: PairingSession] = [:]

    // MARK: - Initialization

    public init() {}

    /// Initialize the connection manager and generate/load keys
    public func initialize() async throws {
        // Generate or load server key pair
        if let keyData = loadKeyFromKeychain(identifier: "thea.remote.server.privatekey") {
            serverPrivateKey = try? P256.Signing.PrivateKey(rawRepresentation: keyData)
        }

        if serverPrivateKey == nil {
            serverPrivateKey = P256.Signing.PrivateKey()
            if let keyData = serverPrivateKey?.rawRepresentation {
                saveKeyToKeychain(keyData, identifier: "thea.remote.server.privatekey")
            }
        }

        serverPublicKey = serverPrivateKey?.publicKey

        isInitialized = true
    }

    // MARK: - TLS Configuration

    /// Create TLS parameters for secure connections
    public func createTLSParameters() throws -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()

        // Configure TLS 1.3
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)

        // Create identity for server
        if let identity = createServerIdentity() {
            sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, identity)
        }

        // Set verification handler for client certificates
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, trust, completion in
            // Accept connections (we'll do app-level authentication)
            completion(true)
        }, .global(qos: .userInteractive))

        let parameters = NWParameters(tls: tlsOptions)
        return parameters
    }

    private func createServerIdentity() -> sec_identity_t? {
        // In production, use a proper certificate
        // For now, we rely on app-level authentication
        return nil
    }

    // MARK: - Authentication

    /// Generate a challenge for client authentication
    public func generateChallenge() throws -> AuthChallenge {
        var nonceData = Data(count: 32)
        let result = nonceData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw ConnectionSecurityError.challengeGenerationFailed
        }

        return AuthChallenge(
            nonce: nonceData,
            timestamp: Date(),
            serverPublicKey: serverPublicKey?.rawRepresentation
        )
    }

    /// Verify client authentication response
    public func verifyAuthentication(
        challenge: AuthChallenge,
        response: AuthResponse,
        method: AuthenticationMethod
    ) async throws -> Bool {
        // Verify challenge hasn't expired
        guard Date().timeIntervalSince(challenge.timestamp) < challengeValiditySeconds else {
            logEvent(.authenticationFailed, "Challenge expired")
            return false
        }

        // Verify challenge ID matches
        guard response.challengeId == challenge.challengeId else {
            logEvent(.authenticationFailed, "Challenge ID mismatch")
            return false
        }

        switch method {
        case .pairingCode:
            return await verifyPairingCode(response: response)

        case .sharedSecret:
            return verifySharedSecret(challenge: challenge, response: response)

        case .certificate:
            return verifyCertificate(response: response)

        case .iCloudIdentity:
            return await verifyiCloudIdentity(response: response)

        case .biometric:
            return await verifyBiometric()
        }
    }

    // MARK: - Pairing Code Authentication

    /// Generate a new pairing code for client connection
    public func generatePairingCode(validFor duration: TimeInterval = 300) -> String {
        // Generate 6-digit code
        let code = String(format: "%06d", Int.random(in: 0...999999))

        let session = PairingSession(
            code: code,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(duration),
            isUsed: false
        )

        pairingCodes[code] = session
        activePairingCode = code

        // Schedule cleanup
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await MainActor.run {
                self.pairingCodes.removeValue(forKey: code)
                if self.activePairingCode == code {
                    self.activePairingCode = nil
                }
            }
        }

        return code
    }

    private func verifyPairingCode(response: AuthResponse) async -> Bool {
        guard let code = response.pairingCode,
              let session = pairingCodes[code] else {
            logEvent(.authenticationFailed, "Invalid pairing code")
            return false
        }

        guard !session.isUsed else {
            logEvent(.authenticationFailed, "Pairing code already used")
            return false
        }

        guard Date() < session.expiresAt else {
            logEvent(.authenticationFailed, "Pairing code expired")
            return false
        }

        // Mark as used
        pairingCodes[code]?.isUsed = true
        activePairingCode = nil

        logEvent(.clientConnected, "Client authenticated via pairing code")
        return true
    }

    // MARK: - Shared Secret Authentication

    private func verifySharedSecret(challenge: AuthChallenge, response: AuthResponse) -> Bool {
        guard let secret = response.sharedSecret,
              let storedSecret = loadKeyFromKeychain(identifier: "thea.remote.sharedsecret") else {
            logEvent(.authenticationFailed, "No shared secret configured")
            return false
        }

        // Verify HMAC of challenge nonce with shared secret
        let key = SymmetricKey(data: storedSecret)
        let expectedSignature = HMAC<SHA256>.authenticationCode(for: challenge.nonce, using: key)

        guard response.signature == Data(expectedSignature) else {
            logEvent(.authenticationFailed, "Shared secret verification failed")
            return false
        }

        return true
    }

    /// Set shared secret for authentication
    public func setSharedSecret(_ secret: String) {
        let secretData = Data(secret.utf8)
        saveKeyToKeychain(secretData, identifier: "thea.remote.sharedsecret")
    }

    // MARK: - Certificate Authentication

    private func verifyCertificate(response: AuthResponse) -> Bool {
        guard let certData = response.clientPublicKey else {
            logEvent(.authenticationFailed, "No client certificate provided")
            return false
        }

        // Load trusted certificates
        guard let trustedCerts = loadTrustedCertificates() else {
            logEvent(.authenticationFailed, "No trusted certificates configured")
            return false
        }

        // Check if client certificate is in trusted list
        let isValid = trustedCerts.contains(certData)

        if !isValid {
            logEvent(.authenticationFailed, "Client certificate not trusted")
        }

        return isValid
    }

    /// Add a trusted client certificate
    public func addTrustedCertificate(_ certData: Data) {
        var certs = loadTrustedCertificates() ?? []
        certs.append(certData)
        saveTrustedCertificates(certs)
    }

    /// Remove a trusted client certificate
    public func removeTrustedCertificate(_ certData: Data) {
        var certs = loadTrustedCertificates() ?? []
        certs.removeAll { $0 == certData }
        saveTrustedCertificates(certs)
    }

    private func loadTrustedCertificates() -> [Data]? {
        guard let data = UserDefaults.standard.data(forKey: "thea.remote.trustedcerts"),
              let certs = try? JSONDecoder().decode([Data].self, from: data) else {
            return nil
        }
        return certs
    }

    private func saveTrustedCertificates(_ certs: [Data]) {
        if let data = try? JSONEncoder().encode(certs) {
            UserDefaults.standard.set(data, forKey: "thea.remote.trustedcerts")
        }
    }

    // MARK: - iCloud Identity Authentication

    private func verifyiCloudIdentity(response: AuthResponse) async -> Bool {
        // In a real implementation, this would verify the client's iCloud identity
        // matches one of the devices on the same iCloud account
        logEvent(.authenticationFailed, "iCloud identity verification not implemented")
        return false
    }

    // MARK: - Biometric Authentication

    private func verifyBiometric() async -> Bool {
        #if os(macOS)
        // This would show a local biometric prompt on the server
        // and only allow connection if approved
        logEvent(.authenticationFailed, "Biometric verification not implemented")
        return false
        #else
        return false
        #endif
    }

    // MARK: - Whitelist Management

    /// Check if an endpoint is in the whitelist
    public func isWhitelisted(_ endpoint: NWEndpoint) async -> Bool {
        guard !whitelist.isEmpty else { return true }

        switch endpoint {
        case .hostPort(let host, _):
            let hostString = "\(host)"
            return whitelist.contains(hostString)
        default:
            return false
        }
    }

    /// Add IP to whitelist
    public func addToWhitelist(_ ip: String) {
        whitelist.insert(ip)
        saveWhitelist()
    }

    /// Remove IP from whitelist
    public func removeFromWhitelist(_ ip: String) {
        whitelist.remove(ip)
        saveWhitelist()
    }

    private func loadWhitelist() {
        if let list = UserDefaults.standard.stringArray(forKey: "thea.remote.whitelist") {
            whitelist = Set(list)
        }
    }

    private func saveWhitelist() {
        UserDefaults.standard.set(Array(whitelist), forKey: "thea.remote.whitelist")
    }

    // MARK: - Rate Limiting

    /// Check rate limit for an endpoint
    public func checkRateLimit(for endpoint: NWEndpoint) async -> Bool {
        let key: String
        switch endpoint {
        case .hostPort(let host, _):
            key = "\(host)"
        default:
            return true
        }

        let now = Date()
        let cutoff = now.addingTimeInterval(-60) // 1 minute window

        // Clean old entries
        connectionAttempts[key] = connectionAttempts[key]?.filter { $0 > cutoff } ?? []

        // Check limit
        let attempts = connectionAttempts[key]?.count ?? 0
        if attempts >= rateLimitPerMinute {
            logEvent(.rateLimitExceeded, "Rate limit exceeded for \(key)")
            return false
        }

        // Record attempt
        connectionAttempts[key, default: []].append(now)
        return true
    }

    // MARK: - Encryption

    /// Encrypt data for transmission
    public func encrypt(_ data: Data, for session: RemoteSession) throws -> Data {
        guard let sessionKey = session.sessionKey else {
            throw ConnectionSecurityError.noSessionKey
        }

        let key = SymmetricKey(data: sessionKey)
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw ConnectionSecurityError.encryptionFailed
        }

        return combined
    }

    /// Decrypt received data
    public func decrypt(_ data: Data, for session: RemoteSession) throws -> Data {
        guard let sessionKey = session.sessionKey else {
            throw ConnectionSecurityError.noSessionKey
        }

        let key = SymmetricKey(data: sessionKey)
        let sealedBox = try AES.GCM.SealedBox(combined: data)

        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Generate session encryption key via ECDH
    public func generateSessionKey(clientPublicKeyData: Data) throws -> Data {
        guard let privateKey = serverPrivateKey else {
            throw ConnectionSecurityError.keyNotInitialized
        }

        // Parse client public key
        let clientKey = try P256.KeyAgreement.PublicKey(rawRepresentation: clientPublicKeyData)
        let serverKeyAgreement = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey.rawRepresentation)

        // Perform ECDH
        let sharedSecret = try serverKeyAgreement.sharedSecretFromKeyAgreement(with: clientKey)

        // Derive session key
        let sessionKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: "thea.remote.session".data(using: .utf8)!,
            outputByteCount: 32
        )

        return sessionKey.withUnsafeBytes { Data($0) }
    }

    // MARK: - Keychain Operations

    private func saveKeyToKeychain(_ data: Data, identifier: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "app.thea.remote",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyFromKeychain(identifier: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "app.thea.remote",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Logging

    private func logEvent(_ type: SecurityEventType, _ details: String) {
        let event = SecurityEvent(type: type, details: details, timestamp: Date())
        securityEvents.append(event)

        // Keep only recent events
        if securityEvents.count > 500 {
            securityEvents.removeFirst(250)
        }
    }
}

// MARK: - Pairing Session

private struct PairingSession {
    let code: String
    let createdAt: Date
    let expiresAt: Date
    var isUsed: Bool
}

// MARK: - Connection Security Error

public enum ConnectionSecurityError: Error, LocalizedError, Sendable {
    case keyNotInitialized
    case challengeGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case noSessionKey
    case invalidCertificate

    public var errorDescription: String? {
        switch self {
        case .keyNotInitialized: return "Security keys not initialized"
        case .challengeGenerationFailed: return "Failed to generate authentication challenge"
        case .encryptionFailed: return "Data encryption failed"
        case .decryptionFailed: return "Data decryption failed"
        case .noSessionKey: return "No session encryption key available"
        case .invalidCertificate: return "Invalid certificate"
        }
    }
}
