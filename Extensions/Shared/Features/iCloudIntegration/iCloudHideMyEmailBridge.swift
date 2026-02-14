// iCloudHideMyEmailBridge.swift
// Thea - AI-Powered Browser Extensions
//
// Bridge for iCloud+ Hide My Email integration
//
// ARCHITECTURE UPDATE (v2.0):
// The Chrome/Brave extension now uses DIRECT iCloud.com API access for Hide My Email,
// similar to how Safari and third-party extensions work. This Swift bridge serves as
// a FALLBACK and for local caching/management when the extension cannot access iCloud.com.
//
// Primary Flow (Chrome/Brave):
// Extension -> iCloud.com cookies -> iCloud Premium Mail Settings API -> Real @icloud.com aliases
//
// Fallback Flow (via Native Messaging):
// Extension <-> Native Messaging <-> TheaNativeHost <-> This Bridge <-> Local Cache
//
// Key Points:
// - Primary alias creation is handled by icloud-client.js in the extension
// - This bridge provides local caching and Safari/Settings handoff as backup
// - @icloud.com addresses are created via iCloud+ Hide My Email
// - @privaterelay.appleid.com is ONLY for "Sign in with Apple" authentication

import AppKit
import AuthenticationServices
import Foundation
import LocalAuthentication
import Security

// MARK: - iCloud Hide My Email Bridge

/// Bridge for Chrome/Brave to work with iCloud+ Hide My Email aliases
///
/// IMPORTANT: Apple does NOT provide a public API for creating aliases.
/// This bridge provides:
/// - Opening Safari/Settings for manual alias creation
/// - Caching and autofilling previously created aliases
/// - Syncing aliases that the user creates via Safari
@MainActor
public final class iCloudHideMyEmailBridge: ObservableObject {
    public static let shared = iCloudHideMyEmailBridge()

    // MARK: - Published State

    @Published public private(set) var isConnected = false
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var aliases: [HideMyEmailAlias] = []
    @Published public private(set) var lastSyncTime: Date?
    @Published public private(set) var connectionError: HideMyEmailError?

    // MARK: - Private Properties

    private var sessionToken: Data?
    private var tokenExpiryDate: Date?

    // Keychain identifiers
    private let keychainService = "com.thea.icloud.hidemyemail.bridge"
    private let keychainAccount = "session_token"
    private let aliasesCacheAccount = "aliases_cache"

    // MARK: - Initialization

    private init() {
        Task {
            await restoreSession()
            try? await loadCachedAliases()
        }
    }

    // MARK: - Connection & Authentication

    /// Connect and authenticate - this just enables local caching functionality
    /// Creating aliases still requires Safari or System Settings
    public func connect() async throws {
        // Check if we have a valid session
        if let token = sessionToken, let expiry = tokenExpiryDate, expiry > Date() {
            isConnected = true
            isAuthenticated = true
            return
        }

        // Try to restore from keychain
        if await restoreSession() {
            return
        }

        // Authenticate with biometrics
        try await authenticateWithBiometrics()
    }

    /// Authenticate using Face ID / Touch ID
    private func authenticateWithBiometrics() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw HideMyEmailError.authenticationRequired
        }

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Access Hide My Email aliases"
        )

        guard success else {
            throw HideMyEmailError.authenticationFailed
        }

        try await establishSession()
    }

    /// Establish authenticated session
    private func establishSession() async throws {
        let token = Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
        let expiry = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days

        try storeSessionInKeychain(token: token, expiry: expiry)

        sessionToken = token
        tokenExpiryDate = expiry
        isConnected = true
        isAuthenticated = true
        lastSyncTime = Date()
    }

    /// Restore session from keychain
    @discardableResult
    private func restoreSession() async -> Bool {
        guard let stored = retrieveSessionFromKeychain() else {
            return false
        }

        if stored.expiry > Date() {
            sessionToken = stored.token
            tokenExpiryDate = stored.expiry
            isConnected = true
            isAuthenticated = true
            return true
        }

        clearSessionFromKeychain()
        return false
    }

    // MARK: - Keychain Storage

    private func storeSessionInKeychain(token: Data, expiry: Date) throws {
        let expiryData = withUnsafeBytes(of: expiry.timeIntervalSince1970) { Data($0) }
        let combined = token + expiryData

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: combined,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HideMyEmailError.keychainError(status)
        }
    }

    private func retrieveSessionFromKeychain() -> (token: Data, expiry: Date)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data, data.count > 8 else {
            return nil
        }

        let tokenData = data.prefix(data.count - 8)
        let expiryData = data.suffix(8)

        let expiry = expiryData.withUnsafeBytes { buffer in
            Date(timeIntervalSince1970: buffer.load(as: TimeInterval.self))
        }

        return (Data(tokenData), expiry)
    }

    private func clearSessionFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Hide My Email Operations

    /// Open Safari to create a new Hide My Email alias
    /// Apple does NOT provide an API - user must create aliases manually in Safari
    ///
    /// - Parameter domain: The domain to associate with the alias (for label)
    /// - Returns: Instructions for the user
    public func openSafariToCreateAlias(for domain: String) async throws -> AliasCreationInstructions {
        // Open Safari with iCloud settings
        // The user will need to manually create the alias
        let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud")!

        NSWorkspace.shared.open(url)

        return AliasCreationInstructions(
            steps: [
                "System Settings will open to iCloud preferences",
                "Click 'iCloud' and then 'Hide My Email'",
                "Click '+' to create a new alias",
                "Copy the generated @icloud.com address",
                "Return to the browser and paste it"
            ],
            note: "Apple does not provide an API for third-party apps to create Hide My Email aliases. You must create them manually in Safari or System Settings.",
            domain: domain
        )
    }

    /// Open Safari's Hide My Email management page
    public func openHideMyEmailSettings() {
        // Open System Settings > Apple ID > iCloud > Hide My Email
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Register an alias that the user created elsewhere (Safari, Settings)
    /// This caches the alias locally for future autofill
    public func registerAlias(
        email: String,
        label: String,
        domain: String
    ) async throws -> HideMyEmailAlias {
        guard isAuthenticated else {
            try await connect()
        }

        // Validate it looks like an iCloud Hide My Email alias
        guard email.hasSuffix("@icloud.com") else {
            throw HideMyEmailError.invalidAliasFormat
        }

        let alias = HideMyEmailAlias(
            id: UUID().uuidString,
            email: email,
            label: label,
            domain: domain,
            isActive: true,
            createdAt: Date(),
            forwardTo: nil,
            messagesReceived: 0,
            lastUsed: nil,
            source: .manualEntry
        )

        // Add to local cache
        aliases.append(alias)
        try await persistAliasCache()

        NotificationCenter.default.post(
            name: .hideMyEmailAliasRegistered,
            object: nil,
            userInfo: ["alias": alias]
        )

        return alias
    }

    /// Get alias for a specific domain (from local cache)
    public func getAlias(for domain: String) -> HideMyEmailAlias? {
        aliases.first { $0.domain == domain && $0.isActive }
    }

    /// Get all cached aliases
    public func getAllAliases() -> [HideMyEmailAlias] {
        aliases
    }

    /// Mark an alias as used for a domain
    public func markAliasUsed(_ aliasId: String, for domain: String) async throws {
        if let index = aliases.firstIndex(where: { $0.id == aliasId }) {
            var alias = aliases[index]
            alias = HideMyEmailAlias(
                id: alias.id,
                email: alias.email,
                label: alias.label,
                domain: domain,
                isActive: alias.isActive,
                createdAt: alias.createdAt,
                forwardTo: alias.forwardTo,
                messagesReceived: alias.messagesReceived,
                lastUsed: Date(),
                source: alias.source
            )
            aliases[index] = alias
            try await persistAliasCache()
        }
    }

    /// Remove an alias from local cache
    /// Note: This does NOT delete it from iCloud - only removes local tracking
    public func removeAliasFromCache(_ aliasId: String) async throws {
        aliases.removeAll { $0.id == aliasId }
        try await persistAliasCache()
    }

    // MARK: - Local Cache Management

    /// Load cached aliases from keychain
    private func loadCachedAliases() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: aliasesCacheAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            let decoder = JSONDecoder()
            aliases = (try? decoder.decode([HideMyEmailAlias].self, from: data)) ?? []
        }
    }

    /// Persist aliases to keychain
    private func persistAliasCache() async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(aliases)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: aliasesCacheAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)

        lastSyncTime = Date()
    }

    // MARK: - Disconnect

    /// Disconnect (clears session but keeps alias cache)
    public func disconnect() {
        clearSessionFromKeychain()
        sessionToken = nil
        tokenExpiryDate = nil
        isConnected = false
        isAuthenticated = false
    }

    /// Clear all cached data
    public func clearCache() {
        aliases = []
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: aliasesCacheAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Data Types

public struct HideMyEmailAlias: Identifiable, Codable, Sendable {
    public let id: String
    public let email: String
    public let label: String
    public let domain: String
    public let isActive: Bool
    public let createdAt: Date
    public let forwardTo: String?
    public let messagesReceived: Int
    public let lastUsed: Date?
    public let source: AliasSource

    public enum AliasSource: String, Codable, Sendable {
        case manualEntry = "manual" // User manually entered from Safari/Settings
        case imported // Imported from export
        case safari // Detected from Safari (future)
    }

    public init(
        id: String,
        email: String,
        label: String,
        domain: String,
        isActive: Bool,
        createdAt: Date,
        forwardTo: String?,
        messagesReceived: Int,
        lastUsed: Date?,
        source: AliasSource = .manualEntry
    ) {
        self.id = id
        self.email = email
        self.label = label
        self.domain = domain
        self.isActive = isActive
        self.createdAt = createdAt
        self.forwardTo = forwardTo
        self.messagesReceived = messagesReceived
        self.lastUsed = lastUsed
        self.source = source
    }
}

public struct AliasCreationInstructions: Sendable {
    public let steps: [String]
    public let note: String
    public let domain: String
}

// MARK: - Errors

public enum HideMyEmailError: Error, LocalizedError {
    case notConnected
    case authenticationRequired
    case authenticationFailed
    case keychainError(OSStatus)
    case networkError(Error)
    case noPublicAPI
    case invalidAliasFormat
    case aliasNotFound

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            "Not connected"
        case .authenticationRequired:
            "Authentication is required"
        case .authenticationFailed:
            "Authentication failed"
        case let .keychainError(status):
            "Keychain error: \(status)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .noPublicAPI:
            "Apple does not provide a public API for creating Hide My Email aliases. Please use Safari or System Settings."
        case .invalidAliasFormat:
            "Invalid alias format. Hide My Email aliases end in @icloud.com"
        case .aliasNotFound:
            "Alias not found"
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let hideMyEmailAliasRegistered = Notification.Name("com.thea.hideMyEmailAliasRegistered")
    static let hideMyEmailConnected = Notification.Name("com.thea.hideMyEmailConnected")
    static let hideMyEmailDisconnected = Notification.Name("com.thea.hideMyEmailDisconnected")
}
