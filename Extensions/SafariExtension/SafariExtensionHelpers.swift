//
//  SafariExtensionHelpers.swift
//  TheaSafariExtension
//
//  Keychain, password generation, and text analysis helpers
//  for the Safari Web Extension.
//

import Foundation
import os.log
import Security

// MARK: - Keychain Helper

/// Thread-safe Keychain operations scoped to the Thea app group.
enum KeychainHelper {

    private static let logger = Logger(subsystem: "app.thea.safari", category: "Keychain")
    private static let accessGroup = "group.app.theathe"
    private static let servicePrefix = "app.thea.safari"

    // MARK: Query Credentials

    /// Returns matching credentials for a domain. Passwords are intentionally omitted.
    static func queryCredentials(domain: String) -> [[String: String]] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: domain,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]]
        else {
            if status != errSecItemNotFound {
                logger.warning("Keychain query failed for \(domain, privacy: .public): \(status)")
            }
            return []
        }

        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String else { return nil }
            let server = item[kSecAttrServer as String] as? String ?? domain
            return ["username": account, "domain": server]
        }
    }

    // MARK: Save Credential

    /// Saves or updates a credential in the Keychain.
    @discardableResult
    static func saveCredential(domain: String, username: String, password: String) -> Bool {
        guard let passwordData = password.data(using: .utf8) else {
            logger.error("Failed to encode password for \(domain, privacy: .public)")
            return false
        }

        // Check if already exists
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: domain,
            kSecAttrAccount as String: username,
            kSecAttrAccessGroup as String: accessGroup
        ]

        let status = SecItemCopyMatching(searchQuery as CFDictionary, nil)

        if status == errSecSuccess {
            // Update existing
            let updateAttrs: [String: Any] = [
                kSecValueData as String: passwordData
            ]
            let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttrs as CFDictionary)
            if updateStatus != errSecSuccess {
                logger.error("Keychain update failed for \(domain, privacy: .public): \(updateStatus)")
                return false
            }
            logger.info("Updated credential for \(domain, privacy: .public)")
            return true
        } else {
            // Add new
            var addQuery = searchQuery
            addQuery[kSecValueData as String] = passwordData
            addQuery[kSecAttrSynchronizable as String] = kCFBooleanFalse

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                logger.error("Keychain add failed for \(domain, privacy: .public): \(addStatus)")
                return false
            }
            logger.info("Saved new credential for \(domain, privacy: .public)")
            return true
        }
    }

    // MARK: TOTP Secret

    /// Retrieves a TOTP secret stored in the Keychain for a domain.
    static func getTOTPSecret(domain: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(servicePrefix).totp",
            kSecAttrAccount as String: domain,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return secret
    }
}

// MARK: - Password Generator

/// Generates cryptographically strong passwords in Apple-style format.
enum PasswordGenerator {

    /// Generates a password in Apple-style `xxxxx-xxxxx-xxxxx` format using
    /// `SecRandomCopyBytes` for cryptographic randomness.
    static func generateStrongPassword() -> String {
        // Character set: lowercase + uppercase + digits (no ambiguous chars)
        let chars = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789")
        let groupSize = 6
        let groupCount = 3

        var groups: [String] = []
        for _ in 0..<groupCount {
            var bytes = [UInt8](repeating: 0, count: groupSize)
            let status = SecRandomCopyBytes(kSecRandomDefault, groupSize, &bytes)
            guard status == errSecSuccess else {
                // Fallback — should never happen
                return UUID().uuidString.prefix(18).description
            }

            let group = bytes.map { byte in
                chars[Int(byte) % chars.count]
            }
            groups.append(String(group))
        }

        return groups.joined(separator: "-")
    }
}

// MARK: - Text Analyzer

/// Lightweight text analysis without ML dependencies.
/// Used for quick in-extension analysis; heavier work is routed to the main app.
enum TextAnalyzer {

    struct StyleAnalysis {
        let averageSentenceLength: Double
        let averageWordLength: Double
        let vocabularyRichness: Double
        let formalityScore: Double // 0.0 (casual) to 1.0 (formal)
        let sentenceCount: Int
        let wordCount: Int

        var asDictionary: [String: Any] {
            [
                "averageSentenceLength": averageSentenceLength,
                "averageWordLength": averageWordLength,
                "vocabularyRichness": vocabularyRichness,
                "formalityScore": formalityScore,
                "sentenceCount": sentenceCount,
                "wordCount": wordCount
            ]
        }
    }

    /// Performs basic text style analysis: sentence length, word length,
    /// vocabulary richness, and a heuristic formality score.
    static func analyzeStyle(_ text: String) -> StyleAnalysis {
        guard !text.isEmpty else {
            return StyleAnalysis(
                averageSentenceLength: 0, averageWordLength: 0,
                vocabularyRichness: 0, formalityScore: 0.5,
                sentenceCount: 0, wordCount: 0
            )
        }

        // Split into sentences
        let sentenceDelimiters = CharacterSet(charactersIn: ".!?")
        let sentences = text.components(separatedBy: sentenceDelimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let sentenceCount = max(sentences.count, 1)

        // Split into words
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = words.count

        // Average sentence length (words per sentence)
        let avgSentenceLength = Double(wordCount) / Double(sentenceCount)

        // Average word length
        let totalWordChars = words.reduce(0) { $0 + $1.count }
        let avgWordLength = wordCount > 0 ? Double(totalWordChars) / Double(wordCount) : 0

        // Vocabulary richness (unique words / total words)
        let uniqueWords = Set(words.map { $0.lowercased() })
        let richness = wordCount > 0 ? Double(uniqueWords.count) / Double(wordCount) : 0

        // Formality heuristic
        let formalityScore = computeFormality(text: text, words: words, avgWordLength: avgWordLength)

        return StyleAnalysis(
            averageSentenceLength: avgSentenceLength,
            averageWordLength: avgWordLength,
            vocabularyRichness: min(richness, 1.0),
            formalityScore: formalityScore,
            sentenceCount: sentenceCount,
            wordCount: wordCount
        )
    }

    // MARK: Private

    private static let formalIndicators: Set<String> = [
        "therefore", "however", "furthermore", "consequently", "nevertheless",
        "accordingly", "regarding", "concerning", "notwithstanding", "hereby",
        "whereas", "pursuant", "hereafter", "aforementioned"
    ]

    private static let casualIndicators: Set<String> = [
        "yeah", "gonna", "wanna", "kinda", "lol", "omg", "tbh",
        "btw", "idk", "imo", "ngl", "fr", "literally", "basically",
        "hey", "ok", "okay", "cool", "awesome", "stuff", "things"
    ]

    private static func computeFormality(
        text: String,
        words: [String],
        avgWordLength: Double
    ) -> Double {
        let lowercasedWords = Set(words.map { $0.lowercased() })

        let formalCount = lowercasedWords.intersection(formalIndicators).count
        let casualCount = lowercasedWords.intersection(casualIndicators).count

        // Contractions lower formality
        let contractionCount = text.components(separatedBy: "'").count - 1

        // Base score from word length (longer words = more formal)
        var score = min(max((avgWordLength - 3.0) / 4.0, 0.0), 1.0)

        // Adjust for indicators
        let indicatorWeight = 0.1
        score += Double(formalCount) * indicatorWeight
        score -= Double(casualCount) * indicatorWeight
        score -= Double(contractionCount) * 0.03

        return min(max(score, 0.0), 1.0)
    }
}
