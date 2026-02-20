// FinancialCredentialStore.swift
// Thea — Financial Intelligence Hub (AAC3-2)
//
// Keychain-backed credential store for all financial API tokens.
// RULE: Financial credentials MUST NEVER be stored in SwiftData, UserDefaults,
//       or any persistence layer other than the Keychain.

import Foundation
import Security
import OSLog

// MARK: - Financial Credential Store

enum FinancialCredentialStore {

    private static let logger = Logger(subsystem: "com.thea.app", category: "FinancialCredentialStore")

    // MARK: - Save

    /// Persist a token for a given provider key.
    /// - Parameters:
    ///   - token: The secret value (API key, access token, etc.)
    ///   - provider: A `FinancialAPIProvider.keychainKey` or custom string identifier
    @discardableResult
    static func save(token: String, for provider: String) -> Bool { // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
        guard let data = token.data(using: .utf8) else {
            logger.error("Failed to encode token for \(provider)")
            return false
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: accountKey(for: provider),
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Delete any existing item first (update pattern)
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            logger.debug("Saved credential for \(provider)")
            return true
        } else {
            logger.error("Keychain save failed for \(provider): \(status)")
            return false
        }
    }

    // MARK: - Load

    /// Retrieve a token for a given provider key.
    /// Returns `nil` if no credential is stored or on Keychain error.
    static func load(for provider: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: accountKey(for: provider),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                logger.debug("Keychain load failed for \(provider): \(status)")
            }
            return nil
        }

        return token
    }

    // MARK: - Delete

    /// Remove stored credentials for a provider.
    @discardableResult
    static func delete(for provider: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: accountKey(for: provider)
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            logger.debug("Deleted credential for \(provider)")
            return true
        } else {
            logger.error("Keychain delete failed for \(provider): \(status)")
            return false
        }
    }

    // MARK: - Multi-Key Support

    /// Save multiple credentials for a provider (e.g. apiKey + secret pair).
    /// Uses composite key: "thea.financial.{provider}.{suffix}"
    @discardableResult
    static func save(token: String, for provider: String, suffix: String) -> Bool {
        save(token: token, for: "\(provider).\(suffix)")
    }

    /// Load a credential by provider + suffix.
    static func load(for provider: String, suffix: String) -> String? {
        load(for: "\(provider).\(suffix)")
    }

    /// Delete a credential by provider + suffix.
    @discardableResult
    static func delete(for provider: String, suffix: String) -> Bool {
        delete(for: "\(provider).\(suffix)")
    }

    // MARK: - Convenience for FinancialAPIProvider

    /// Save using a typed `FinancialAPIProvider`.
    @discardableResult
    static func save(token: String, provider: FinancialAPIProvider) -> Bool {
        save(token: token, for: provider.rawValue)
    }

    /// Load using a typed `FinancialAPIProvider`.
    static func load(provider: FinancialAPIProvider) -> String? {
        load(for: provider.rawValue)
    }

    /// Check whether credentials exist for a provider.
    static func hasCredentials(for provider: FinancialAPIProvider) -> Bool {
        load(provider: provider) != nil
    }

    // MARK: - Private

    private static func accountKey(for provider: String) -> String {
        "thea.financial.\(provider)"
    }
}
