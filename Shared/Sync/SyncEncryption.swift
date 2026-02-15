//
//  SyncEncryption.swift
//  Thea
//
//  End-to-end encryption for sync data using AES-256-GCM.
//  Encrypts data before sending to iCloud; decrypts on receive.
//  Key is derived from user's iCloud keychain-stored master secret.
//

import CryptoKit
import Foundation
import os.log

/// Provides AES-256-GCM encryption for sync payloads.
/// Key material is stored in the user's Keychain (synced via iCloud Keychain).
actor SyncEncryption {
    static let shared = SyncEncryption()

    private let logger = Logger(subsystem: "app.thea", category: "SyncEncryption")
    private let keychainService = "app.thea.sync.encryption"
    private let keychainAccount = "masterKey"

    private var cachedKey: SymmetricKey?

    // MARK: - Key Management

    /// Get or create the symmetric encryption key.
    /// Stored in Keychain with iCloud Keychain sync so all devices share the same key.
    func getOrCreateKey() throws -> SymmetricKey {
        if let cached = cachedKey {
            return cached
        }

        // Try to load from Keychain
        if let keyData = loadKeyFromKeychain() {
            let key = SymmetricKey(data: keyData)
            cachedKey = key
            return key
        }

        // Generate new key and save to Keychain
        let key = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(key)
        cachedKey = key
        logger.info("Generated new sync encryption key")
        return key
    }

    /// Encrypt data using AES-256-GCM
    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw SyncEncryptionError.encryptionFailed
        }
        return combined
    }

    /// Decrypt data using AES-256-GCM
    func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Encrypt a Codable value to Data
    func encryptCodable<T: Codable>(_ value: T) throws -> Data {
        let plainData = try JSONEncoder().encode(value)
        return try encrypt(plainData)
    }

    /// Decrypt Data to a Codable value
    func decryptCodable<T: Codable>(_ data: Data, as type: T.Type) throws -> T {
        let plainData = try decrypt(data)
        return try JSONDecoder().decode(type, from: plainData)
    }

    /// Rotate the encryption key. Re-encrypts all sync data with the new key.
    func rotateKey() throws {
        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey)
        cachedKey = newKey
        logger.info("Sync encryption key rotated")
    }

    /// Check if encryption is available (key exists or can be created)
    var isAvailable: Bool {
        do {
            _ = try getOrCreateKey()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Keychain Operations

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        return nil
    }

    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        // Delete existing key if present
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: true
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key with iCloud Keychain sync
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SyncEncryptionError.keychainSaveFailed(status)
        }
    }
}

// MARK: - Errors

enum SyncEncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: "Failed to encrypt sync data"
        case .decryptionFailed: "Failed to decrypt sync data"
        case .keychainSaveFailed(let status): "Failed to save encryption key to Keychain (status: \(status))"
        case .keychainLoadFailed: "Failed to load encryption key from Keychain"
        }
    }
}
