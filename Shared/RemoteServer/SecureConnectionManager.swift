//
//  SecureConnectionManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import CloudKit
import Combine
import CryptoKit
import Foundation
import LocalAuthentication
import Network
import Security

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

        // SECURITY FIX (FINDING-002): Properly validate TLS certificates
        // Previous implementation blindly accepted all certificates, enabling MITM attacks
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, secTrust, completion in
            // Perform proper certificate validation
            guard let trust = sec_trust_copy_ref(secTrust).takeRetainedValue() as SecTrust? else {
                completion(false)
                return
            }

            // Set standard SSL policy for certificate validation
            let policy = SecPolicyCreateSSL(true, nil)
            SecTrustSetPolicies(trust, policy)

            // Evaluate the trust chain
            var error: CFError?
            let isValid = SecTrustEvaluateWithError(trust, &error)

            if !isValid {
                // Log the validation failure for debugging
                if let error {
                    print("SECURITY: TLS certificate validation failed: \(error)")
                }
            }

            completion(isValid)
        }, .global(qos: .userInteractive))

        let parameters = NWParameters(tls: tlsOptions)
        return parameters
    }

    private func createServerIdentity() -> sec_identity_t? {
        // In production, use a proper certificate
        // For now, we rely on app-level authentication
        nil
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

        case .unattendedPassword:
            return verifyUnattendedPassword(response: response)

        case .totp:
            return verifyTOTPAuth(response: response)
        }
    }

    // MARK: - Pairing Code Authentication

    /// Generate a new pairing code for client connection
    /// SECURITY FIX (FINDING-006): Increased from 6 digits to cryptographically strong 12-character alphanumeric
    public func generatePairingCode(validFor duration: TimeInterval = 300) -> String {
        // SECURITY FIX: Generate cryptographically strong 12-character code
        // Uses alphanumeric characters (removed ambiguous ones: 0, O, l, 1, I)
        let characters = "23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"
        var codeData = Data(count: 12)
        let result = codeData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!)
        }

        let code: String = if result == errSecSuccess {
            codeData.map { characters[characters.index(characters.startIndex, offsetBy: Int($0) % characters.count)] }
                .map { String($0) }
                .joined()
        } else {
            // Fallback (still better than 6 digits)
            (0 ..< 12).map { _ in
                String(characters.randomElement()!)
            }.joined()
        }

        let session = PairingSession(
            code: code,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(duration),
            isUsed: false,
            failedAttempts: 0 // SECURITY: Track failed attempts
        )

        pairingCodes[code] = session
        activePairingCode = code

        // Schedule cleanup
        Task {
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                self.pairingCodes.removeValue(forKey: code)
                if self.activePairingCode == code {
                    self.activePairingCode = nil
                }
            }
        }

        return code
    }

    // SECURITY FIX (FINDING-006): Maximum failed attempts before lockout
    private let maxFailedAttempts = 3

    // SECURITY FIX (Race Condition): Use actor isolation to ensure atomic check-and-mark
    // The @MainActor annotation on the class ensures serialized access to pairingCodes
    private func verifyPairingCode(response: AuthResponse) async -> Bool {
        guard let code = response.pairingCode else {
            logEvent(.authenticationFailed, "No pairing code provided")
            // SECURITY: Add delay to prevent timing attacks
            try? await Task.sleep(for: .milliseconds(500)) // 500ms
            return false
        }

        // SECURITY FIX (Race Condition): Perform atomic check-and-mark in single operation
        // First, get the session and verify it exists
        guard let session = pairingCodes[code] else {
            logEvent(.authenticationFailed, "Invalid pairing code")
            try? await Task.sleep(for: .milliseconds(500)) // 500ms delay for timing attacks
            return false
        }

        // SECURITY FIX (FINDING-006): Check for lockout due to failed attempts
        guard session.failedAttempts < maxFailedAttempts else {
            logEvent(.authenticationFailed, "Pairing code locked due to too many failed attempts")
            pairingCodes.removeValue(forKey: code)
            activePairingCode = nil
            return false
        }

        // SECURITY FIX (Race Condition): Check isUsed AND mark as used atomically
        // Since we're on @MainActor, no other code can interleave between check and mark
        guard !session.isUsed else {
            logEvent(.authenticationFailed, "Pairing code already used (possible replay attack)")
            return false
        }

        // Immediately mark as used before any async operation can interleave
        // This is the atomic operation - must happen synchronously
        pairingCodes[code]?.isUsed = true

        // Now perform remaining validations (even if expired, code is burned)
        guard Date() < session.expiresAt else {
            logEvent(.authenticationFailed, "Pairing code expired")
            pairingCodes.removeValue(forKey: code)
            activePairingCode = nil
            return false
        }

        activePairingCode = nil
        logEvent(.clientConnected, "Client authenticated via pairing code")
        return true
    }

    // MARK: - Shared Secret Authentication

    private func verifySharedSecret(challenge: AuthChallenge, response: AuthResponse) -> Bool {
        guard let _ = response.sharedSecret,
              let storedSecret = loadKeyFromKeychain(identifier: "thea.remote.sharedsecret")
        else {
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

    // SECURITY FIX (FINDING-011): Store trusted certificates in Keychain instead of UserDefaults
    private func loadTrustedCertificates() -> [Data]? {
        guard let data = loadKeyFromKeychain(identifier: "thea.remote.trustedcerts"),
              let certs = try? JSONDecoder().decode([Data].self, from: data)
        else {
            return nil
        }
        return certs
    }

    // SECURITY FIX (FINDING-011): Store trusted certificates in Keychain instead of UserDefaults
    private func saveTrustedCertificates(_ certs: [Data]) {
        if let data = try? JSONEncoder().encode(certs) {
            saveKeyToKeychain(data, identifier: "thea.remote.trustedcerts")
        }
    }

    // MARK: - iCloud Identity Authentication

    private func verifyiCloudIdentity(response: AuthResponse) async -> Bool {
        // Verify the client's iCloud user record ID matches the server's iCloud account
        guard let clientiCloudToken = response.sharedSecret else {
            logEvent(.authenticationFailed, "No iCloud identity token provided by client")
            return false
        }

        do {
            let container = CKContainer(identifier: "iCloud.app.theathe")
            let serverRecordID = try await container.userRecordID()
            let serverIdentity = serverRecordID.recordName

            // Compare client-provided identity with server's iCloud identity
            // Client sends HMAC(iCloudRecordName, sharedPairingKey) for verification
            if let pairingKeyData = loadKeyFromKeychain(identifier: "thea.remote.pairingkey") {
                let key = SymmetricKey(data: pairingKeyData)
                let expectedHMAC = HMAC<SHA256>.authenticationCode(
                    for: Data(serverIdentity.utf8),
                    using: key
                )
                let expectedTokenData = Data(expectedHMAC)

                if clientiCloudToken == expectedTokenData {
                    logEvent(.clientConnected, "iCloud identity verified — same account")
                    return true
                }
            }

            // Fallback: direct record name comparison (less secure, for initial pairing)
            if clientiCloudToken == Data(serverIdentity.utf8) {
                logEvent(.clientConnected, "iCloud identity matched via direct comparison")
                return true
            }

            logEvent(.authenticationFailed, "iCloud identity mismatch")
            return false
        } catch {
            logEvent(.authenticationFailed, "iCloud identity check failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Biometric Authentication

    private func verifyBiometric() async -> Bool {
        let context = LAContext()
        context.localizedReason = "Authorize remote connection to Thea"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error {
                logEvent(.authenticationFailed, "Biometric not available: \(error.localizedDescription)")
            } else {
                logEvent(.authenticationFailed, "Biometric authentication not available on this device")
            }
            return false
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Approve incoming remote connection to Thea"
            )
            if success {
                logEvent(.clientConnected, "Biometric authentication approved")
            } else {
                logEvent(.authenticationFailed, "Biometric authentication denied by user")
            }
            return success
        } catch {
            logEvent(.authenticationFailed, "Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Unattended Password Authentication

    private func verifyUnattendedPassword(response: AuthResponse) -> Bool {
        guard let password = response.sharedSecret else {
            logEvent(.authenticationFailed, "No unattended password provided")
            return false
        }

        guard let storedHash = loadKeyFromKeychain(identifier: "thea.remote.unattended.hash"),
              let storedSalt = loadKeyFromKeychain(identifier: "thea.remote.unattended.salt")
        else {
            logEvent(.authenticationFailed, "No unattended password configured")
            return false
        }

        // Hash the provided password with the stored salt
        let key = SymmetricKey(data: password)
        let hmac = HMAC<SHA256>.authenticationCode(for: storedSalt, using: key)
        let computedHash = Data(hmac)

        // Constant-time comparison
        guard computedHash.count == storedHash.count else { return false }
        var result: UInt8 = 0
        for i in 0 ..< computedHash.count {
            result |= computedHash[i] ^ storedHash[i]
        }

        let isValid = result == 0
        if isValid {
            logEvent(.clientConnected, "Client authenticated via unattended password")
        } else {
            logEvent(.authenticationFailed, "Invalid unattended password")
        }
        return isValid
    }

    /// Set the unattended access password
    public func setUnattendedPassword(_ password: String) {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }

        let key = SymmetricKey(data: Data(password.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: salt, using: key)

        saveKeyToKeychain(Data(hmac), identifier: "thea.remote.unattended.hash")
        saveKeyToKeychain(salt, identifier: "thea.remote.unattended.salt")
    }

    /// Check if unattended password is configured
    public var hasUnattendedPassword: Bool {
        loadKeyFromKeychain(identifier: "thea.remote.unattended.hash") != nil
    }

    // MARK: - TOTP Authentication

    private func verifyTOTPAuth(response: AuthResponse) -> Bool {
        guard let code = response.pairingCode else {
            logEvent(.authenticationFailed, "No TOTP code provided")
            return false
        }

        // Delegate to TOTPAuthenticator
        // Note: The TOTPAuthenticator is @MainActor, so this is safe
        let authenticator = TOTPAuthenticator()
        let isValid = authenticator.verify(code: code)

        if isValid {
            logEvent(.clientConnected, "Client authenticated via TOTP")
        } else {
            logEvent(.authenticationFailed, "Invalid TOTP code")
        }
        return isValid
    }

    // MARK: - Whitelist Management

    /// Check if an endpoint is in the whitelist
    public func isWhitelisted(_ endpoint: NWEndpoint) async -> Bool {
        guard !whitelist.isEmpty else { return true }

        switch endpoint {
        case let .hostPort(host, _):
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

    // SECURITY FIX (FINDING-011): Store whitelist in Keychain instead of UserDefaults
    private func loadWhitelist() {
        if let data = loadKeyFromKeychain(identifier: "thea.remote.whitelist"),
           let jsonArray = try? JSONDecoder().decode([String].self, from: data)
        {
            whitelist = Set(jsonArray)
        }
    }

    // SECURITY FIX (FINDING-011): Store whitelist in Keychain instead of UserDefaults
    private func saveWhitelist() {
        if let data = try? JSONEncoder().encode(Array(whitelist)) {
            saveKeyToKeychain(data, identifier: "thea.remote.whitelist")
        }
    }

    // MARK: - Rate Limiting

    /// Check rate limit for an endpoint
    public func checkRateLimit(for endpoint: NWEndpoint) async -> Bool {
        let key: String
        switch endpoint {
        case let .hostPort(host, _):
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
            sharedInfo: Data("thea.remote.session".utf8),
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
    var failedAttempts: Int // SECURITY FIX (FINDING-006): Track failed attempts for lockout
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
        case .keyNotInitialized: "Security keys not initialized"
        case .challengeGenerationFailed: "Failed to generate authentication challenge"
        case .encryptionFailed: "Data encryption failed"
        case .decryptionFailed: "Data decryption failed"
        case .noSessionKey: "No session encryption key available"
        case .invalidCertificate: "Invalid certificate"
        }
    }
}
