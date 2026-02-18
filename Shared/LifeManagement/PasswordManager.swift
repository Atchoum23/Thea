// PasswordManager.swift
// Thea — Secure credential vault
//
// Stores and manages passwords, login credentials, and secure notes.
// Uses Keychain for encrypted storage. Provides password generation,
// strength analysis, and breach-risk indicators.

import Foundation
import OSLog
import Security

private let pwLogger = Logger(subsystem: "ai.thea.app", category: "PasswordManager")

// MARK: - Models

/// A stored credential entry.
struct PasswordEntry: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var username: String
    var url: String?
    var category: CredentialCategory
    var notes: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var passwordStrength: PasswordStrength?

    init(
        title: String, username: String = "", url: String? = nil,
        category: CredentialCategory = .website, notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.username = username
        self.url = url
        self.category = category
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastUsedAt = nil
        self.passwordStrength = nil
    }
}

enum CredentialCategory: String, Codable, Sendable, CaseIterable {
    case website, email, banking, social, work, development, wifi, server, other

    var displayName: String {
        switch self {
        case .website: "Website"
        case .email: "Email"
        case .banking: "Banking"
        case .social: "Social Media"
        case .work: "Work"
        case .development: "Development"
        case .wifi: "Wi-Fi"
        case .server: "Server"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .website: "globe"
        case .email: "envelope"
        case .banking: "building.columns"
        case .social: "person.2"
        case .work: "briefcase"
        case .development: "terminal"
        case .wifi: "wifi"
        case .server: "server.rack"
        case .other: "key"
        }
    }
}

enum PasswordStrength: String, Codable, Sendable, CaseIterable, Comparable {
    case veryWeak, weak, fair, strong, veryStrong

    var displayName: String {
        switch self {
        case .veryWeak: "Very Weak"
        case .weak: "Weak"
        case .fair: "Fair"
        case .strong: "Strong"
        case .veryStrong: "Very Strong"
        }
    }

    var score: Int {
        switch self {
        case .veryWeak: 0
        case .weak: 1
        case .fair: 2
        case .strong: 3
        case .veryStrong: 4
        }
    }

    static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
        lhs.score < rhs.score
    }
}

// MARK: - Password Analysis

enum PasswordAnalyzer {
    /// Analyze password strength based on length, character variety, and patterns.
    static func analyzeStrength(_ password: String) -> PasswordStrength {
        var score = 0

        // Length scoring
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        if password.count >= 20 { score += 1 }

        // Character variety
        let hasUpper = password.contains(where: \.isUppercase)
        let hasLower = password.contains(where: \.isLowercase)
        let hasDigit = password.contains(where: \.isNumber)
        let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })

        let variety = [hasUpper, hasLower, hasDigit, hasSpecial].filter { $0 }.count
        score += variety

        // Penalize common patterns
        let lower = password.lowercased()
        let commonPatterns = ["password", "123456", "qwerty", "admin", "letmein",
                              "welcome", "monkey", "abc123"]
        if commonPatterns.contains(where: { lower.contains($0) }) {
            score = max(score - 3, 0)
        }

        // Penalize short passwords
        if password.count < 6 { return .veryWeak }

        switch score {
        case 0...2: return .veryWeak
        case 3: return .weak
        case 4...5: return .fair
        case 6...7: return .strong
        default: return .veryStrong
        }
    }

    /// Generate a random password with configurable options.
    static func generatePassword(
        length: Int = 16,
        includeUppercase: Bool = true,
        includeLowercase: Bool = true,
        includeDigits: Bool = true,
        includeSpecial: Bool = true
    ) -> String {
        var chars = ""
        if includeLowercase { chars += "abcdefghijkmnpqrstuvwxyz" }
        if includeUppercase { chars += "ABCDEFGHJKLMNPQRSTUVWXYZ" }
        if includeDigits { chars += "23456789" }
        if includeSpecial { chars += "!@#$%^&*-_=+" }
        guard !chars.isEmpty else { return "" }

        let charArray = Array(chars)
        var result = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<charArray.count)
            result.append(charArray[randomIndex])
        }
        return result
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static let service = "ai.thea.passwordvault"

    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess ? result as? Data : nil
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Manager

@MainActor
final class PasswordManager: ObservableObject {
    static let shared = PasswordManager()

    @Published private(set) var entries: [PasswordEntry] = []

    private let metadataURL: URL
    private let keychainPrefix = "pw_"

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/LifeManagement", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            pwLogger.error("Failed to create storage directory: \(error.localizedDescription)")
        }
        metadataURL = dir.appendingPathComponent("passwords_meta.json")
        loadMetadata()
    }

    // MARK: - CRUD

    func addEntry(_ entry: PasswordEntry, password: String) {
        var newEntry = entry
        newEntry.passwordStrength = PasswordAnalyzer.analyzeStrength(password)
        entries.append(newEntry)
        storePassword(password, for: newEntry.id)
        saveMetadata()
        pwLogger.info("Added credential: \(entry.title)")
    }

    func updateEntry(_ entry: PasswordEntry, newPassword: String? = nil) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            var updated = entry
            updated.updatedAt = Date()
            if let pw = newPassword {
                updated.passwordStrength = PasswordAnalyzer.analyzeStrength(pw)
                storePassword(pw, for: entry.id)
            }
            entries[idx] = updated
            saveMetadata()
        }
    }

    func deleteEntry(id: UUID) {
        KeychainHelper.delete(key: keychainPrefix + id.uuidString)
        entries.removeAll { $0.id == id }
        saveMetadata()
    }

    func getPassword(for id: UUID) -> String? {
        guard let data = KeychainHelper.load(key: keychainPrefix + id.uuidString) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Queries

    var favoriteEntries: [PasswordEntry] {
        entries.filter(\.isFavorite).sorted { $0.title < $1.title }
    }

    var weakPasswords: [PasswordEntry] {
        entries.filter { ($0.passwordStrength ?? .veryWeak) < .fair }
    }

    var entriesByCategory: [CredentialCategory: [PasswordEntry]] {
        Dictionary(grouping: entries, by: \.category)
    }

    func search(query: String) -> [PasswordEntry] {
        let q = query.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(q) ||
            $0.username.lowercased().contains(q) ||
            ($0.url?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Private

    private func storePassword(_ password: String, for id: UUID) {
        guard let data = password.data(using: .utf8) else { return }
        KeychainHelper.save(key: keychainPrefix + id.uuidString, data: data)
    }

    private func saveMetadata() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(entries)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            pwLogger.error("Failed to save password metadata: \(error.localizedDescription)")
        }
    }

    private func loadMetadata() {
        let data: Data
        do {
            data = try Data(contentsOf: metadataURL)
        } catch {
            pwLogger.error("Failed to read password metadata: \(error.localizedDescription)")
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            entries = try decoder.decode([PasswordEntry].self, from: data)
        } catch {
            pwLogger.error("Failed to decode password metadata: \(error.localizedDescription)")
        }
    }
}
