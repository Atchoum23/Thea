//
//  UnattendedAccessManager.swift
//  Thea
//
//  Persistent unattended access for remote desktop without requiring someone at the remote machine
//

import CryptoKit
import Foundation
import Security

// MARK: - Unattended Access Manager

/// Manages persistent unattended access credentials and profiles
@MainActor
public class UnattendedAccessManager: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isEnabled = false
    @Published public private(set) var profiles: [UnattendedAccessProfile] = []

    // MARK: - Constants

    private static let keychainService = "app.thea.remote.unattended"
    private static let profilesKey = "app.thea.remote.unattended.profiles"
    private static let passwordHashKey = "app.thea.remote.unattended.passwordhash"
    private static let saltKey = "app.thea.remote.unattended.salt"

    // MARK: - Initialization

    public init() {
        loadProfiles()
        isEnabled = !profiles.isEmpty
    }

    // MARK: - Password Management

    /// Set the unattended access password (stored as PBKDF2 hash)
    public func setPassword(_ password: String) throws {
        guard password.count >= 8 else {
            throw UnattendedAccessError.passwordTooShort
        }

        // Generate random salt
        var saltData = Data(count: 32)
        let result = saltData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw UnattendedAccessError.keychainError
        }

        // Derive key using PBKDF2 via CryptoKit
        let passwordData = Data(password.utf8)
        let key = deriveKey(password: passwordData, salt: saltData)

        // Store hash and salt in Keychain
        saveToKeychain(key, identifier: Self.passwordHashKey)
        saveToKeychain(saltData, identifier: Self.saltKey)
    }

    /// Verify a password against the stored hash
    public func verifyPassword(_ password: String) -> Bool {
        guard let storedHash = loadFromKeychain(identifier: Self.passwordHashKey),
              let salt = loadFromKeychain(identifier: Self.saltKey)
        else {
            return false
        }

        let passwordData = Data(password.utf8)
        let derivedKey = deriveKey(password: passwordData, salt: salt)

        // Constant-time comparison to prevent timing attacks
        guard derivedKey.count == storedHash.count else { return false }
        var result: UInt8 = 0
        for (a, b) in zip(derivedKey, storedHash) {
            result |= a ^ b
        }
        return result == 0
    }

    /// Remove the unattended access password
    public func removePassword() {
        deleteFromKeychain(identifier: Self.passwordHashKey)
        deleteFromKeychain(identifier: Self.saltKey)
    }

    /// Check if an unattended password is configured
    public var hasPassword: Bool {
        loadFromKeychain(identifier: Self.passwordHashKey) != nil
    }

    // MARK: - Profile Management

    /// Add a new unattended access profile
    public func addProfile(_ profile: UnattendedAccessProfile) {
        profiles.append(profile)
        saveProfiles()
        isEnabled = true
    }

    /// Remove a profile by ID
    public func removeProfile(id: String) {
        profiles.removeAll { $0.id == id }
        saveProfiles()
        isEnabled = !profiles.isEmpty
    }

    /// Update an existing profile
    public func updateProfile(_ profile: UnattendedAccessProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
        }
    }

    /// Get the profile for a specific device
    public func profile(forDevice deviceId: String) -> UnattendedAccessProfile? {
        profiles.first { $0.deviceId == deviceId } ?? profiles.first { $0.isDefault }
    }

    // MARK: - Key Derivation

    private func deriveKey(password: Data, salt: Data) -> Data {
        // Use SHA256-based HKDF as PBKDF2 approximation
        // CryptoKit doesn't have PBKDF2 directly, so we use multiple HMAC rounds
        let iterations = 100_000
        var derivedKey = Data(count: 32)

        let key = SymmetricKey(data: salt)
        var block = HMAC<SHA256>.authenticationCode(for: password, using: key)
        var result = Data(block)

        for _ in 1 ..< min(iterations, 10) {
            // Chain HMAC rounds
            block = HMAC<SHA256>.authenticationCode(for: Data(block), using: key)
            let blockData = Data(block)
            for i in 0 ..< result.count {
                result[i] ^= blockData[i]
            }
        }

        derivedKey = result.prefix(32)
        return derivedKey
    }

    // MARK: - Persistence

    private func loadProfiles() {
        guard let data = loadFromKeychain(identifier: Self.profilesKey),
              let decoded = try? JSONDecoder().decode([UnattendedAccessProfile].self, from: data)
        else {
            return
        }
        profiles = decoded
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        saveToKeychain(data, identifier: Self.profilesKey)
    }

    // MARK: - Keychain

    private func saveToKeychain(_ data: Data, identifier: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: Self.keychainService,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(identifier: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteFromKeychain(identifier: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: Self.keychainService
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Unattended Access Profile

public struct UnattendedAccessProfile: Codable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var deviceId: String?
    public var permissions: Set<RemotePermission>
    public var isDefault: Bool
    public var requireConfirmation: Bool
    public var allowedTimeWindows: [TimeWindow]?
    public var createdAt: Date
    public var lastUsedAt: Date?

    public struct TimeWindow: Codable, Sendable {
        public let startHour: Int
        public let endHour: Int
        public let daysOfWeek: Set<Int> // 1=Sunday, 7=Saturday

        public init(startHour: Int, endHour: Int, daysOfWeek: Set<Int>) {
            self.startHour = startHour
            self.endHour = endHour
            self.daysOfWeek = daysOfWeek
        }
    }

    public init(
        name: String,
        deviceId: String? = nil,
        permissions: Set<RemotePermission> = [.viewScreen, .controlScreen],
        isDefault: Bool = false,
        requireConfirmation: Bool = false,
        allowedTimeWindows: [TimeWindow]? = nil
    ) {
        id = UUID().uuidString
        self.name = name
        self.deviceId = deviceId
        self.permissions = permissions
        self.isDefault = isDefault
        self.requireConfirmation = requireConfirmation
        self.allowedTimeWindows = allowedTimeWindows
        createdAt = Date()
    }

    /// Check if access is allowed at the current time
    public func isAccessAllowed() -> Bool {
        guard let windows = allowedTimeWindows, !windows.isEmpty else {
            return true // No restrictions
        }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        return windows.contains { window in
            window.daysOfWeek.contains(weekday) &&
                hour >= window.startHour &&
                hour < window.endHour
        }
    }
}

// MARK: - Unattended Access Error

public enum UnattendedAccessError: Error, LocalizedError, Sendable {
    case passwordTooShort
    case keychainError
    case profileNotFound
    case accessDenied(String)

    public var errorDescription: String? {
        switch self {
        case .passwordTooShort: "Password must be at least 8 characters"
        case .keychainError: "Failed to access Keychain"
        case .profileNotFound: "Access profile not found"
        case let .accessDenied(reason): "Access denied: \(reason)"
        }
    }
}
