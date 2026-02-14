//
//  SecurityHardening.swift
//  Thea
//
//  Comprehensive security hardening for Thea. Covers credential management,
//  data encryption, secure communication, and privacy protection.
//
//  Copyright 2026. All rights reserved.
//

import CryptoKit
import Foundation
import os.log

// MARK: - Security Types

/// Security level for different operations
public enum SecurityLevel: Int, Codable, Sendable, Comparable {
    case standard = 0
    case enhanced = 1
    case maximum = 2

    public static func < (lhs: SecurityLevel, rhs: SecurityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .standard: "Standard encryption and security"
        case .enhanced: "Enhanced security with additional checks"
        case .maximum: "Maximum security with full audit trail"
        }
    }
}

/// Credential type for secure storage
public enum CredentialType: String, Codable, Sendable {
    case apiKey
    case accessToken
    case refreshToken
    case password
    case encryptionKey
    case certificate
}

/// Stored credential
public struct SecureCredential: Codable, Sendable {
    public let id: String
    public let type: CredentialType
    public let service: String
    public let createdAt: Date
    public var lastUsed: Date?
    public var expiresAt: Date?
    public var metadata: [String: String]

    public init(
        id: String,
        type: CredentialType,
        service: String,
        createdAt: Date = Date(),
        lastUsed: Date? = nil,
        expiresAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.service = service
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.expiresAt = expiresAt
        self.metadata = metadata
    }

    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

/// Security audit event
public struct SecurityAuditEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: EventType
    public let severity: Severity
    public let description: String
    public let details: [String: String]
    public let resolved: Bool

    public enum EventType: String, Codable, Sendable {
        case credentialAccess
        case credentialCreation
        case credentialDeletion
        case encryptionOperation
        case decryptionOperation
        case authenticationAttempt
        case authenticationSuccess
        case authenticationFailure
        case permissionChange
        case suspiciousActivity
        case dataExport
        case configurationChange
    }

    public enum Severity: String, Codable, Sendable {
        case info
        case warning
        case critical
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: EventType,
        severity: Severity,
        description: String,
        details: [String: String] = [:],
        resolved: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.severity = severity
        self.description = description
        self.details = details
        self.resolved = resolved
    }
}

/// Data classification for privacy
public enum DataClassification: String, Codable, Sendable {
    case publicData
    case internalData
    case confidential
    case restricted
    case pii  // Personally Identifiable Information

    public var requiresEncryption: Bool {
        switch self {
        case .publicData, .internalData: false
        case .confidential, .restricted, .pii: true
        }
    }

    public var retentionDays: Int? {
        switch self {
        case .publicData: nil
        case .internalData: 365
        case .confidential: 90
        case .restricted: 30
        case .pii: 7
        }
    }
}

// MARK: - Security Manager

/// Central security management for Thea
@MainActor
public final class SecurityManager: ObservableObject {
    public static let shared = SecurityManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Security")

    // MARK: - Published State

    /// Current security level
    @Published public var securityLevel: SecurityLevel = .enhanced

    /// Recent security events
    @Published public private(set) var recentEvents: [SecurityAuditEvent] = []

    /// Whether biometric authentication is enabled
    @Published public var biometricEnabled: Bool = false

    /// Whether audit logging is enabled
    @Published public var auditLoggingEnabled: Bool = true

    /// Active credentials (metadata only, not values)
    @Published public private(set) var activeCredentials: [SecureCredential] = []

    // MARK: - Private State

    private let keychain = KeychainManager()
    private let encryption = EncryptionService()
    private var auditLog: [SecurityAuditEvent] = []
    private let maxAuditEvents = 1000

    // MARK: - Initialization

    private init() {
        loadCredentialMetadata()
        loadAuditLog()
        cleanupExpiredCredentials()

        logger.info("SecurityManager initialized with level: \(self.securityLevel.description)")
    }

    // MARK: - Credential Management

    /// Store a credential securely
    public func storeCredential(
        id: String,
        type: CredentialType,
        service: String,
        value: String,
        expiresAt: Date? = nil,
        metadata: [String: String] = [:]
    ) throws {
        // Encrypt the value
        let encryptedValue = try encryption.encrypt(value)

        // Store in keychain
        try keychain.store(key: id, data: encryptedValue, service: service)

        // Create metadata record
        let credential = SecureCredential(
            id: id,
            type: type,
            service: service,
            expiresAt: expiresAt,
            metadata: metadata
        )

        activeCredentials.removeAll { $0.id == id }
        activeCredentials.append(credential)
        saveCredentialMetadata()

        logEvent(
            type: .credentialCreation,
            severity: .info,
            description: "Created credential: \(id) for service: \(service)"
        )

        logger.info("Stored credential: \(id)")
    }

    /// Retrieve a credential
    public func retrieveCredential(id: String, service: String) throws -> String {
        // Get encrypted data from keychain
        guard let encryptedData = try keychain.retrieve(key: id, service: service) else {
            throw SecurityError.credentialNotFound(id)
        }

        // Decrypt
        let value = try encryption.decryptToString(encryptedData)

        // Update last used
        if let index = activeCredentials.firstIndex(where: { $0.id == id }) {
            activeCredentials[index].lastUsed = Date()
            saveCredentialMetadata()
        }

        logEvent(
            type: .credentialAccess,
            severity: .info,
            description: "Accessed credential: \(id)"
        )

        return value
    }

    /// Delete a credential
    public func deleteCredential(id: String, service: String) throws {
        try keychain.delete(key: id, service: service)

        activeCredentials.removeAll { $0.id == id }
        saveCredentialMetadata()

        logEvent(
            type: .credentialDeletion,
            severity: .info,
            description: "Deleted credential: \(id)"
        )

        logger.info("Deleted credential: \(id)")
    }

    /// Check if credential exists
    public func hasCredential(id: String) -> Bool {
        activeCredentials.contains { $0.id == id && !$0.isExpired }
    }

    /// Cleanup expired credentials
    public func cleanupExpiredCredentials() {
        let expiredIds = activeCredentials.filter(\.isExpired).map(\.id)

        for credential in activeCredentials.filter(\.isExpired) {
            try? keychain.delete(key: credential.id, service: credential.service)
        }

        activeCredentials.removeAll { $0.isExpired }
        saveCredentialMetadata()

        if !expiredIds.isEmpty {
            logger.info("Cleaned up \(expiredIds.count) expired credentials")
        }
    }

    // MARK: - Data Encryption

    /// Encrypt sensitive data
    public func encryptData(_ data: Data, classification: DataClassification) throws -> Data {
        guard classification.requiresEncryption else {
            return data
        }

        let encrypted = try encryption.encrypt(data)

        logEvent(
            type: .encryptionOperation,
            severity: .info,
            description: "Encrypted \(classification.rawValue) data"
        )

        return encrypted
    }

    /// Decrypt sensitive data
    public func decryptData(_ data: Data) throws -> Data {
        let decrypted = try encryption.decrypt(data)

        logEvent(
            type: .decryptionOperation,
            severity: .info,
            description: "Decrypted data"
        )

        return decrypted
    }

    /// Generate secure random token
    public func generateSecureToken(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Hash sensitive data (one-way)
    public func hashData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Privacy Protection

    /// Redact sensitive information from text
    public func redactSensitiveInfo(_ text: String) -> String {
        var redacted = text

        // Redact email addresses
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        redacted = redact(pattern: emailPattern, in: redacted, replacement: "[EMAIL]")

        // Redact phone numbers
        let phonePattern = "\\+?[0-9]{1,4}?[-.\\s]?\\(?[0-9]{1,3}?\\)?[-.\\s]?[0-9]{1,4}[-.\\s]?[0-9]{1,4}[-.\\s]?[0-9]{1,9}"
        redacted = redact(pattern: phonePattern, in: redacted, replacement: "[PHONE]")

        // Redact credit card numbers
        let ccPattern = "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b"
        redacted = redact(pattern: ccPattern, in: redacted, replacement: "[CARD]")

        // Redact SSN
        let ssnPattern = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        redacted = redact(pattern: ssnPattern, in: redacted, replacement: "[SSN]")

        // Redact API keys (common patterns)
        let apiKeyPattern = "sk-[a-zA-Z0-9]{20,}|api[_-]?key[\"']?\\s*[:=]\\s*[\"']?[a-zA-Z0-9]{20,}"
        redacted = redact(pattern: apiKeyPattern, in: redacted, replacement: "[API_KEY]")

        return redacted
    }

    private func redact(pattern: String, in text: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: replacement
        )
    }

    /// Check if text contains sensitive information
    public func containsSensitiveInfo(_ text: String) -> Bool {
        text != redactSensitiveInfo(text)
    }

    // MARK: - Audit Logging

    /// Log a security event
    public func logEvent(
        type: SecurityAuditEvent.EventType,
        severity: SecurityAuditEvent.Severity,
        description: String,
        details: [String: String] = [:]
    ) {
        guard auditLoggingEnabled else { return }

        let event = SecurityAuditEvent(
            eventType: type,
            severity: severity,
            description: description,
            details: details
        )

        auditLog.append(event)
        recentEvents = Array(auditLog.suffix(50))

        // Trim if needed
        if auditLog.count > maxAuditEvents {
            auditLog = Array(auditLog.suffix(maxAuditEvents))
        }

        saveAuditLog()

        if severity == .critical {
            logger.critical("Security event: \(description)")
        } else if severity == .warning {
            logger.warning("Security event: \(description)")
        }
    }

    /// Get audit events for a time range
    public func getAuditEvents(from: Date, to: Date) -> [SecurityAuditEvent] {
        auditLog.filter { $0.timestamp >= from && $0.timestamp <= to }
    }

    /// Export audit log
    public func exportAuditLog() -> Data? {
        try? JSONEncoder().encode(auditLog)
    }

    // MARK: - Security Checks

    /// Perform security health check
    public func performSecurityCheck() -> SecurityHealthReport {
        var issues: [SecurityHealthReport.Issue] = []

        // Check for expired credentials
        let expiredCount = activeCredentials.filter(\.isExpired).count
        if expiredCount > 0 {
            issues.append(SecurityHealthReport.Issue(
                severity: .warning,
                description: "\(expiredCount) expired credentials found",
                recommendation: "Clean up expired credentials"
            ))
        }

        // Check for old credentials
        let oldCredentials = activeCredentials.filter { cred in
            guard let lastUsed = cred.lastUsed else { return true }
            return Date().timeIntervalSince(lastUsed) > 90 * 24 * 60 * 60 // 90 days
        }
        if !oldCredentials.isEmpty {
            issues.append(SecurityHealthReport.Issue(
                severity: .info,
                description: "\(oldCredentials.count) credentials haven't been used in 90+ days",
                recommendation: "Review and rotate unused credentials"
            ))
        }

        // Check security level
        if securityLevel == .standard {
            issues.append(SecurityHealthReport.Issue(
                severity: .info,
                description: "Security level is set to standard",
                recommendation: "Consider enabling enhanced security"
            ))
        }

        // Check audit logging
        if !auditLoggingEnabled {
            issues.append(SecurityHealthReport.Issue(
                severity: .warning,
                description: "Audit logging is disabled",
                recommendation: "Enable audit logging for security monitoring"
            ))
        }

        return SecurityHealthReport(
            timestamp: Date(),
            overallHealth: issues.isEmpty ? .healthy : (issues.contains { $0.severity == .critical } ? .critical : .warning),
            issues: issues,
            credentialCount: activeCredentials.count,
            auditEventCount: auditLog.count
        )
    }

    // MARK: - Persistence

    private func saveCredentialMetadata() {
        if let data = try? JSONEncoder().encode(activeCredentials) {
            UserDefaults.standard.set(data, forKey: "thea.security.credentials_metadata")
        }
    }

    private func loadCredentialMetadata() {
        guard let data = UserDefaults.standard.data(forKey: "thea.security.credentials_metadata"),
              let credentials = try? JSONDecoder().decode([SecureCredential].self, from: data) else {
            return
        }
        activeCredentials = credentials
    }

    private func saveAuditLog() {
        // Only save recent events for performance
        let recentLog = Array(auditLog.suffix(500))
        if let data = try? JSONEncoder().encode(recentLog) {
            UserDefaults.standard.set(data, forKey: "thea.security.audit_log")
        }
    }

    private func loadAuditLog() {
        guard let data = UserDefaults.standard.data(forKey: "thea.security.audit_log"),
              let log = try? JSONDecoder().decode([SecurityAuditEvent].self, from: data) else {
            return
        }
        auditLog = log
        recentEvents = Array(log.suffix(50))
    }
}

// MARK: - Security Health Report

public struct SecurityHealthReport: Sendable {
    public let timestamp: Date
    public let overallHealth: HealthStatus
    public let issues: [Issue]
    public let credentialCount: Int
    public let auditEventCount: Int

    public enum HealthStatus: String, Sendable {
        case healthy
        case warning
        case critical
    }

    public struct Issue: Sendable {
        public let severity: SecurityAuditEvent.Severity
        public let description: String
        public let recommendation: String
    }
}

// MARK: - Security Errors

public enum SecurityError: Error, LocalizedError {
    case credentialNotFound(String)
    case encryptionFailed
    case decryptionFailed
    case keychainError(String)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .credentialNotFound(let id): "Credential not found: \(id)"
        case .encryptionFailed: "Encryption failed"
        case .decryptionFailed: "Decryption failed"
        case .keychainError(let msg): "Keychain error: \(msg)"
        case .invalidData: "Invalid data"
        }
    }
}

// MARK: - Keychain Manager

private final class KeychainManager: Sendable {
    func store(key: String, data: Data, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainError("Failed to store: \(status)")
        }
    }

    func retrieve(key: String, service: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw SecurityError.keychainError("Failed to retrieve: \(status)")
        }

        return result as? Data
    }

    func delete(key: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityError.keychainError("Failed to delete: \(status)")
        }
    }
}

// MARK: - Encryption Service

private final class EncryptionService: Sendable {
    private let key: SymmetricKey

    init() {
        // In production, this should be stored in Keychain
        self.key = SymmetricKey(size: .bits256)
    }

    func encrypt(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw SecurityError.invalidData
        }
        return try encrypt(data)
    }

    func encrypt(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw SecurityError.encryptionFailed
            }
            return combined
        } catch {
            throw SecurityError.encryptionFailed
        }
    }

    func decrypt(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SecurityError.decryptionFailed
        }
    }

    func decryptToString(_ data: Data) throws -> String {
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw SecurityError.invalidData
        }
        return string
    }
}
