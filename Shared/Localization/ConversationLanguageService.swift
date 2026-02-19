// ConversationLanguageService.swift
// Thea — Multilingual Conversation Management
//
// Manages language preferences for AI conversations.
// Can be toggled on/off multiple times per conversation.

import Foundation
import NaturalLanguage
import OSLog

// MARK: - Conversation Language Service

@MainActor
@Observable
final class ConversationLanguageService {
    static let shared = ConversationLanguageService()

    private let logger = Logger(subsystem: "com.thea.app", category: "ConversationLanguage")

    /// Supported conversation languages (subset of LocalizationManager's 27)
    let supportedLanguages: [ConversationLanguage] = [
        ConversationLanguage(code: "en", name: "English", nativeName: "English", flag: "🇺🇸"),
        ConversationLanguage(code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸"),
        ConversationLanguage(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
        ConversationLanguage(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
        ConversationLanguage(code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
        ConversationLanguage(code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹"),
        ConversationLanguage(code: "pt-BR", name: "Brazilian Portuguese", nativeName: "Português (BR)", flag: "🇧🇷"),
        ConversationLanguage(code: "zh-Hans", name: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳"),
        ConversationLanguage(code: "zh-Hant", name: "Chinese (Traditional)", nativeName: "繁體中文", flag: "🇹🇼"),
        ConversationLanguage(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
        ConversationLanguage(code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
        ConversationLanguage(code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
        ConversationLanguage(code: "he", name: "Hebrew", nativeName: "עברית", flag: "🇮🇱"),
        ConversationLanguage(code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
        ConversationLanguage(code: "uk", name: "Ukrainian", nativeName: "Українська", flag: "🇺🇦"),
        ConversationLanguage(code: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱"),
        ConversationLanguage(code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱"),
        ConversationLanguage(code: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪"),
        ConversationLanguage(code: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰"),
        ConversationLanguage(code: "fi", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮"),
        ConversationLanguage(code: "no", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴"),
        ConversationLanguage(code: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷"),
        ConversationLanguage(code: "th", name: "Thai", nativeName: "ภาษาไทย", flag: "🇹🇭"),
        ConversationLanguage(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳"),
        ConversationLanguage(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩"),
        ConversationLanguage(code: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳"),
        ConversationLanguage(code: "bn", name: "Bengali", nativeName: "বাংলা", flag: "🇧🇩")
    ]

    private init() {}

    // MARK: - Language Toggle

    /// Set the conversation language (nil to revert to default/English)
    func setLanguage(_ languageCode: String?, for conversation: Conversation) {
        conversation.metadata.preferredLanguage = languageCode

        if let code = languageCode {
            let name = supportedLanguages.first { $0.code == code }?.nativeName ?? code
            logger.info("Conversation \(conversation.id): language set to \(name) (\(code))")
        } else {
            logger.info("Conversation \(conversation.id): language reset to default")
        }
    }

    /// Toggle language on/off for a conversation
    func toggleLanguage(_ languageCode: String, for conversation: Conversation) {
        if conversation.metadata.preferredLanguage == languageCode {
            // periphery:ignore - Reserved: toggleLanguage(_:for:) instance method reserved for future feature activation
            // Deactivate
            setLanguage(nil, for: conversation)
        } else {
            // Activate
            setLanguage(languageCode, for: conversation)
        }
    }

    /// Get the current language for a conversation
    func currentLanguage(for conversation: Conversation) -> ConversationLanguage? {
        guard let code = conversation.metadata.preferredLanguage else { return nil }
        return supportedLanguages.first { $0.code == code }
    }

    /// Check if a specific language is active for a conversation
    func isLanguageActive(_ languageCode: String, for conversation: Conversation) -> Bool {
        // periphery:ignore - Reserved: isLanguageActive(_:for:) instance method reserved for future feature activation
        conversation.metadata.preferredLanguage == languageCode
    }

    // MARK: - Language Detection

    /// Detect the language of a user message and optionally auto-set it
    // periphery:ignore - Reserved: detectAndSuggestLanguage(from:) instance method reserved for future feature activation
    func detectAndSuggestLanguage(from text: String) -> String? {
        // Use NaturalLanguage framework for detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominantLanguage = recognizer.dominantLanguage else { return nil }
        let code = dominantLanguage.rawValue

        // Only suggest if it's a supported language and not English
        guard code != "en",
              supportedLanguages.contains(where: { $0.code == code || $0.code.hasPrefix(code) })
        else {
            return nil
        }

        return code
    }
}

// MARK: - Types

struct ConversationLanguage: Identifiable, Sendable, Hashable {
    let code: String       // BCP-47 code
    let name: String       // English name
    let nativeName: String // Native name
    let flag: String       // Flag emoji

    var id: String { code }
}
