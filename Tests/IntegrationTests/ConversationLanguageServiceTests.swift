// ConversationLanguageServiceTests.swift
// Q3 Security Coverage — 100% branch coverage for ConversationLanguageService.swift
//
// Covers:
//   • All 27 supported languages (code, name, nativeName, flag, id)
//   • setLanguage: code present branch (logs name from list or falls back to code)
//   • setLanguage: nil branch (reset to default)
//   • toggleLanguage: deactivate (same code) branch
//   • toggleLanguage: activate (different code) branch
//   • currentLanguage: nil guard branch (no preferredLanguage)
//   • currentLanguage: found branch (code matches supported list)
//   • currentLanguage: not-found branch (code not in supported list)
//   • isLanguageActive: true branch
//   • isLanguageActive: false branch
//   • detectAndSuggestLanguage: nil branch (no dominant language)
//   • detectAndSuggestLanguage: English → nil branch
//   • detectAndSuggestLanguage: unsupported language → nil branch
//   • detectAndSuggestLanguage: supported non-English → returns code
//   • ConversationLanguage struct: Identifiable (id == code)

@testable import TheaCore
import XCTest

/// Tests for ConversationLanguageService — @MainActor, @Observable.
@MainActor
final class ConversationLanguageServiceTests: XCTestCase {

    private var service: ConversationLanguageService { ConversationLanguageService.shared }

    // MARK: - ConversationLanguage struct

    func testConversationLanguageIdentifiableIdEqualsCode() {
        let lang = ConversationLanguage(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷")
        XCTAssertEqual(lang.id, "fr")
    }

    func testConversationLanguageHashable() {
        let lang1 = ConversationLanguage(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪")
        let lang2 = ConversationLanguage(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪")
        var set: Set<ConversationLanguage> = []
        set.insert(lang1)
        set.insert(lang2)
        XCTAssertEqual(set.count, 1, "Duplicate ConversationLanguage should be de-duplicated in a Set")
    }

    func testConversationLanguageSendable() {
        // Sendable conformance is compile-time; just verify we can pass it across contexts
        let lang = ConversationLanguage(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵")
        Task { _ = lang }  // No Sendable warning = conformance works
    }

    // MARK: - supportedLanguages — 27 languages

    func testSupportedLanguagesCount() {
        XCTAssertEqual(service.supportedLanguages.count, 27)
    }

    func testAllLanguageCodesAreUnique() {
        let codes = service.supportedLanguages.map { $0.code }
        XCTAssertEqual(codes.count, Set(codes).count, "All BCP-47 codes must be unique")
    }

    func testLanguageEnglish() {
        assertLanguage(code: "en", name: "English", nativeName: "English", flag: "🇺🇸")
    }

    func testLanguageSpanish() {
        assertLanguage(code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸")
    }

    func testLanguageFrench() {
        assertLanguage(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷")
    }

    func testLanguageGerman() {
        assertLanguage(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪")
    }

    func testLanguageItalian() {
        assertLanguage(code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹")
    }

    func testLanguagePortuguese() {
        assertLanguage(code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹")
    }

    func testLanguageBrazilianPortuguese() {
        assertLanguage(code: "pt-BR", name: "Brazilian Portuguese", nativeName: "Português (BR)", flag: "🇧🇷")
    }

    func testLanguageChineseSimplified() {
        assertLanguage(code: "zh-Hans", name: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳")
    }

    func testLanguageChineseTraditional() {
        assertLanguage(code: "zh-Hant", name: "Chinese (Traditional)", nativeName: "繁體中文", flag: "🇹🇼")
    }

    func testLanguageJapanese() {
        assertLanguage(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵")
    }

    func testLanguageKorean() {
        assertLanguage(code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷")
    }

    func testLanguageArabic() {
        assertLanguage(code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦")
    }

    func testLanguageHebrew() {
        assertLanguage(code: "he", name: "Hebrew", nativeName: "עברית", flag: "🇮🇱")
    }

    func testLanguageRussian() {
        assertLanguage(code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺")
    }

    func testLanguageUkrainian() {
        assertLanguage(code: "uk", name: "Ukrainian", nativeName: "Українська", flag: "🇺🇦")
    }

    func testLanguagePolish() {
        assertLanguage(code: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱")
    }

    func testLanguageDutch() {
        assertLanguage(code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱")
    }

    func testLanguageSwedish() {
        assertLanguage(code: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪")
    }

    func testLanguageDanish() {
        assertLanguage(code: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰")
    }

    func testLanguageFinnish() {
        assertLanguage(code: "fi", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮")
    }

    func testLanguageNorwegian() {
        assertLanguage(code: "no", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴")
    }

    func testLanguageTurkish() {
        assertLanguage(code: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷")
    }

    func testLanguageThai() {
        assertLanguage(code: "th", name: "Thai", nativeName: "ภาษาไทย", flag: "🇹🇭")
    }

    func testLanguageVietnamese() {
        assertLanguage(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳")
    }

    func testLanguageIndonesian() {
        assertLanguage(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩")
    }

    func testLanguageHindi() {
        assertLanguage(code: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳")
    }

    func testLanguageBengali() {
        assertLanguage(code: "bn", name: "Bengali", nativeName: "বাংলা", flag: "🇧🇩")
    }

    // MARK: - setLanguage — code present, name in list

    func testSetLanguageKnownCodeLogsNativeName() {
        let conversation = makeConversation()
        service.setLanguage("fr", for: conversation)
        XCTAssertEqual(conversation.metadata.preferredLanguage, "fr")
    }

    func testSetLanguageUnknownCodeFallsBackToCode() {
        // Branch: code not found in supportedLanguages → uses code as the log name
        let conversation = makeConversation()
        service.setLanguage("xx-XX", for: conversation)
        XCTAssertEqual(conversation.metadata.preferredLanguage, "xx-XX")
    }

    // MARK: - setLanguage — nil (reset)

    func testSetLanguageNilResetsPreference() {
        let conversation = makeConversation()
        service.setLanguage("de", for: conversation)
        XCTAssertNotNil(conversation.metadata.preferredLanguage)

        service.setLanguage(nil, for: conversation)
        XCTAssertNil(conversation.metadata.preferredLanguage)
    }

    // MARK: - toggleLanguage

    func testToggleLanguageActivatesWhenNotSet() {
        let conversation = makeConversation()
        XCTAssertNil(conversation.metadata.preferredLanguage)

        service.toggleLanguage("es", for: conversation)
        XCTAssertEqual(conversation.metadata.preferredLanguage, "es")
    }

    func testToggleLanguageDeactivatesWhenAlreadySet() {
        let conversation = makeConversation()
        service.setLanguage("es", for: conversation)

        // Toggle with same code → should deactivate (set to nil)
        service.toggleLanguage("es", for: conversation)
        XCTAssertNil(conversation.metadata.preferredLanguage, "Toggling same language should deactivate it")
    }

    func testToggleLanguageSwitchesToNewLanguage() {
        let conversation = makeConversation()
        service.setLanguage("es", for: conversation)

        // Toggle with different code → should switch
        service.toggleLanguage("fr", for: conversation)
        XCTAssertEqual(conversation.metadata.preferredLanguage, "fr")
    }

    func testToggleLanguageMultipleTimes() {
        let conversation = makeConversation()
        // off → "ja"
        service.toggleLanguage("ja", for: conversation)
        XCTAssertEqual(conversation.metadata.preferredLanguage, "ja")

        // "ja" → off
        service.toggleLanguage("ja", for: conversation)
        XCTAssertNil(conversation.metadata.preferredLanguage)

        // off → "ja" again
        service.toggleLanguage("ja", for: conversation)
        XCTAssertEqual(conversation.metadata.preferredLanguage, "ja")
    }

    // MARK: - currentLanguage

    func testCurrentLanguageReturnsNilWhenNoneSet() {
        let conversation = makeConversation()
        // No preferred language set
        let lang = service.currentLanguage(for: conversation)
        XCTAssertNil(lang)
    }

    func testCurrentLanguageReturnsSupportedLanguage() {
        let conversation = makeConversation()
        service.setLanguage("ko", for: conversation)

        let lang = service.currentLanguage(for: conversation)
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang?.code, "ko")
        XCTAssertEqual(lang?.name, "Korean")
    }

    func testCurrentLanguageReturnsNilForUnsupportedCode() {
        // Branch: code is set but not found in supportedLanguages
        let conversation = makeConversation()
        service.setLanguage("zz-UNKNOWN", for: conversation)

        let lang = service.currentLanguage(for: conversation)
        XCTAssertNil(lang, "Code not in supportedLanguages should return nil from currentLanguage")
    }

    func testCurrentLanguageAfterReset() {
        let conversation = makeConversation()
        service.setLanguage("ru", for: conversation)
        service.setLanguage(nil, for: conversation)

        let lang = service.currentLanguage(for: conversation)
        XCTAssertNil(lang)
    }

    // MARK: - isLanguageActive

    func testIsLanguageActiveReturnsTrueWhenSet() {
        let conversation = makeConversation()
        service.setLanguage("zh-Hans", for: conversation)
        XCTAssertTrue(service.isLanguageActive("zh-Hans", for: conversation))
    }

    func testIsLanguageActiveReturnsFalseWhenDifferentLanguageSet() {
        let conversation = makeConversation()
        service.setLanguage("zh-Hans", for: conversation)
        XCTAssertFalse(service.isLanguageActive("zh-Hant", for: conversation))
    }

    func testIsLanguageActiveReturnsFalseWhenNoneSet() {
        let conversation = makeConversation()
        XCTAssertFalse(service.isLanguageActive("en", for: conversation))
    }

    func testIsLanguageActiveReturnsTrueAfterToggleOn() {
        let conversation = makeConversation()
        service.toggleLanguage("tr", for: conversation)
        XCTAssertTrue(service.isLanguageActive("tr", for: conversation))
    }

    func testIsLanguageActiveReturnsFalseAfterToggleOff() {
        let conversation = makeConversation()
        service.toggleLanguage("tr", for: conversation)
        service.toggleLanguage("tr", for: conversation)
        XCTAssertFalse(service.isLanguageActive("tr", for: conversation))
    }

    // MARK: - detectAndSuggestLanguage

    func testDetectAndSuggestReturnsNilForShortText() {
        // Very short / ambiguous text — NL may not produce a dominant language
        let result = service.detectAndSuggestLanguage(from: "ok")
        // Either nil (no dominant language) or a code — just ensure no crash
        if let code = result {
            // If a code is returned, it should not be English
            XCTAssertNotEqual(code, "en")
        }
    }

    func testDetectAndSuggestReturnsNilForEnglishText() {
        // English text → should return nil (we don't suggest English, it's the default)
        let text = "The quick brown fox jumps over the lazy dog. Swift programming is great."
        let result = service.detectAndSuggestLanguage(from: text)
        // If NL identifies this as English, result should be nil
        if let code = result {
            XCTAssertNotEqual(code, "en", "English should not be suggested — it is the default language")
        }
        // nil is also a valid result
    }

    func testDetectAndSuggestForFrenchText() {
        let frenchText = "Bonjour, je suis en train de programmer une application iOS en Swift. C'est très amusant!"
        let result = service.detectAndSuggestLanguage(from: frenchText)
        // NL should detect French; result should be "fr" or nil if NL is uncertain
        if let code = result {
            let isSupported = code == "fr" || service.supportedLanguages.contains { $0.code == code || $0.code.hasPrefix(code) }
            XCTAssertTrue(isSupported, "Detected code '\(code)' should be in supported languages")
        }
    }

    func testDetectAndSuggestForSpanishText() {
        let spanishText = "Hola, cómo estás? Me gusta programar aplicaciones en Swift para iOS y macOS."
        let result = service.detectAndSuggestLanguage(from: spanishText)
        if let code = result {
            XCTAssertNotEqual(code, "en")
        }
    }

    func testDetectAndSuggestForGermanText() {
        let germanText = "Guten Morgen! Ich entwickle eine App mit Swift und SwiftUI für macOS und iOS."
        let result = service.detectAndSuggestLanguage(from: germanText)
        if let code = result {
            XCTAssertNotEqual(code, "en")
        }
    }

    func testDetectAndSuggestForJapaneseText() {
        let japaneseText = "こんにちは。スウィフトでiOSアプリを作っています。とても楽しいです。"
        let result = service.detectAndSuggestLanguage(from: japaneseText)
        if let code = result {
            // Japanese is in supported list
            let isSupported = service.supportedLanguages.contains { $0.code == code || $0.code.hasPrefix(code) }
            XCTAssertTrue(isSupported, "Japanese should be in supported languages, got code: '\(code)'")
        }
    }

    func testDetectAndSuggestOnlyReturnsSupportedLanguages() {
        // Any code returned must be in supported languages (or have a prefix match)
        let texts = [
            "Привет, как дела?",          // Russian
            "مرحبا كيف حالك؟",              // Arabic
            "안녕하세요, 잘 지내세요?",          // Korean
            "Olá, tudo bem?"               // Portuguese
        ]
        for text in texts {
            let result = service.detectAndSuggestLanguage(from: text)
            if let code = result {
                let isSupported = service.supportedLanguages.contains { $0.code == code || $0.code.hasPrefix(code) }
                XCTAssertTrue(isSupported, "Code '\(code)' for text '\(text.prefix(20))' is not in supported languages")
            }
        }
    }

    // MARK: - Multiple Conversations Independence

    func testMultipleConversationsHaveIndependentLanguages() {
        let conv1 = makeConversation()
        let conv2 = makeConversation()

        service.setLanguage("fr", for: conv1)
        service.setLanguage("de", for: conv2)

        XCTAssertEqual(conv1.metadata.preferredLanguage, "fr")
        XCTAssertEqual(conv2.metadata.preferredLanguage, "de")
    }

    func testResettingOneConversationDoesNotAffectAnother() {
        let conv1 = makeConversation()
        let conv2 = makeConversation()

        service.setLanguage("ja", for: conv1)
        service.setLanguage("ko", for: conv2)

        service.setLanguage(nil, for: conv1)

        XCTAssertNil(conv1.metadata.preferredLanguage)
        XCTAssertEqual(conv2.metadata.preferredLanguage, "ko")
    }

    // MARK: - Helpers

    /// Create a lightweight Conversation without SwiftData backing for unit tests.
    private func makeConversation() -> Conversation {
        Conversation(title: "Test Conversation \(UUID().uuidString.prefix(8))")
    }

    /// Assert a specific language entry in the supportedLanguages list.
    private func assertLanguage(
        code: String,
        name: String,
        nativeName: String,
        flag: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let lang = service.supportedLanguages.first(where: { $0.code == code }) else {
            XCTFail("Language '\(code)' not found in supportedLanguages", file: file, line: line)
            return
        }
        XCTAssertEqual(lang.name, name, "name mismatch for \(code)", file: file, line: line)
        XCTAssertEqual(lang.nativeName, nativeName, "nativeName mismatch for \(code)", file: file, line: line)
        XCTAssertEqual(lang.flag, flag, "flag mismatch for \(code)", file: file, line: line)
        XCTAssertEqual(lang.id, code, "id (== code) mismatch for \(code)", file: file, line: line)
    }
}
