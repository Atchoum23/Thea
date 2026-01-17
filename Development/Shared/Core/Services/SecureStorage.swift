import Foundation
import KeychainAccess

@MainActor
final class SecureStorage {
    static let shared = SecureStorage()

    private let keychain: Keychain

    private init() {
        self.keychain = Keychain(service: "ai.thea.app")
            .synchronizable(false) // Don't sync via iCloud Keychain for security
            .accessibility(.whenUnlocked)
    }

    // MARK: - API Keys

    func saveAPIKey(_ key: String, for provider: String) throws {
        try keychain.set(key, key: "apikey.\(provider)")
    }

    func loadAPIKey(for provider: String) throws -> String? {
        try keychain.get("apikey.\(provider)")
    }

    func deleteAPIKey(for provider: String) throws {
        try keychain.remove("apikey.\(provider)")
    }

    func hasAPIKey(for provider: String) -> Bool {
        (try? keychain.contains("apikey.\(provider)")) ?? false
    }

    // MARK: - Financial Credentials

    func saveFinancialCredentials(_ credentials: FinancialCredentials, for provider: String) throws {
        let data = try JSONEncoder().encode(credentials)
        try keychain.set(data, key: "financial.\(provider)")
    }

    func loadFinancialCredentials(for provider: String) throws -> FinancialCredentials? {
        guard let data = try keychain.getData("financial.\(provider)") else {
            return nil
        }
        return try JSONDecoder().decode(FinancialCredentials.self, from: data)
    }

    func deleteFinancialCredentials(for provider: String) throws {
        try keychain.remove("financial.\(provider)")
    }

    // MARK: - Encryption Key

    func getOrCreateEncryptionKey() throws -> Data {
        if let keyData = try keychain.getData("encryption.master.key") {
            return keyData
        }

        // Generate new 256-bit key
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw SecureStorageError.keyGenerationFailed
        }

        try keychain.set(keyData, key: "encryption.master.key")
        return keyData
    }

    // MARK: - Clear All

    func clearAll() throws {
        try keychain.removeAll()
    }
}

// MARK: - Errors

enum SecureStorageError: Error, LocalizedError {
    case keyGenerationFailed
    case keyNotFound
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keyNotFound:
            return "Encryption key not found"
        case .encodingFailed:
            return "Failed to encode credentials"
        case .decodingFailed:
            return "Failed to decode credentials"
        }
    }
}
