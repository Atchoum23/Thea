// LocalizationAndHelpTypesTests.swift
// Tests for Localization types (ConversationLanguageService.swift)
// and help/tip types. Companion to OnboardingTypesTests.swift.
// All test doubles are local mirrors — no real types imported.

import Foundation
import XCTest

final class LocalizationAndHelpTypesTests: XCTestCase {

    // MARK: - Test Doubles: Help Types

    struct FeatureTip: Identifiable, Sendable {
        let id: String
        let featureId: String
        let title: String
        let message: String
        let icon: String
        let action: String?
        let prerequisites: Set<String>
    }

    struct ContextualHelp: Identifiable, Sendable {
        let id: String
        let screenId: String
        let title: String
        let items: [HelpItem]
    }

    struct HelpItem: Sendable {
        let id: UUID
        let question: String
        let answer: String

        init(question: String, answer: String) {
            self.id = UUID()
            self.question = question
            self.answer = answer
        }
    }

    // MARK: - Test Doubles: Localization Types

    struct ConversationLanguage: Identifiable, Sendable, Hashable {
        let code: String
        let name: String
        let nativeName: String
        let flag: String
        var id: String { code }
    }

    final class LanguageService {
        let supportedLanguages: [ConversationLanguage] = [
            ConversationLanguage(code: "en", name: "English", nativeName: "English", flag: "\u{1F1FA}\u{1F1F8}"),
            ConversationLanguage(code: "es", name: "Spanish", nativeName: "Espa\u{00F1}ol", flag: "\u{1F1EA}\u{1F1F8}"),
            ConversationLanguage(code: "fr", name: "French", nativeName: "Fran\u{00E7}ais", flag: "\u{1F1EB}\u{1F1F7}"),
            ConversationLanguage(code: "de", name: "German", nativeName: "Deutsch", flag: "\u{1F1E9}\u{1F1EA}"),
            ConversationLanguage(code: "it", name: "Italian", nativeName: "Italiano", flag: "\u{1F1EE}\u{1F1F9}"),
            ConversationLanguage(code: "pt", name: "Portuguese", nativeName: "Portugu\u{00EA}s", flag: "\u{1F1F5}\u{1F1F9}"),
            ConversationLanguage(code: "pt-BR", name: "Brazilian Portuguese", nativeName: "Portugu\u{00EA}s (BR)", flag: "\u{1F1E7}\u{1F1F7}"),
            ConversationLanguage(code: "zh-Hans", name: "Chinese (Simplified)", nativeName: "\u{7B80}\u{4F53}\u{4E2D}\u{6587}", flag: "\u{1F1E8}\u{1F1F3}"),
            ConversationLanguage(code: "zh-Hant", name: "Chinese (Traditional)", nativeName: "\u{7E41}\u{9AD4}\u{4E2D}\u{6587}", flag: "\u{1F1F9}\u{1F1FC}"),
            ConversationLanguage(code: "ja", name: "Japanese", nativeName: "\u{65E5}\u{672C}\u{8A9E}", flag: "\u{1F1EF}\u{1F1F5}"),
            ConversationLanguage(code: "ko", name: "Korean", nativeName: "\u{D55C}\u{AD6D}\u{C5B4}", flag: "\u{1F1F0}\u{1F1F7}"),
            ConversationLanguage(code: "ar", name: "Arabic", nativeName: "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}", flag: "\u{1F1F8}\u{1F1E6}"),
            ConversationLanguage(code: "he", name: "Hebrew", nativeName: "\u{05E2}\u{05D1}\u{05E8}\u{05D9}\u{05EA}", flag: "\u{1F1EE}\u{1F1F1}"),
            ConversationLanguage(code: "ru", name: "Russian", nativeName: "\u{0420}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439}", flag: "\u{1F1F7}\u{1F1FA}"),
            ConversationLanguage(code: "uk", name: "Ukrainian", nativeName: "\u{0423}\u{043A}\u{0440}\u{0430}\u{0457}\u{043D}\u{0441}\u{044C}\u{043A}\u{0430}", flag: "\u{1F1FA}\u{1F1E6}"),
            ConversationLanguage(code: "pl", name: "Polish", nativeName: "Polski", flag: "\u{1F1F5}\u{1F1F1}"),
            ConversationLanguage(code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "\u{1F1F3}\u{1F1F1}"),
            ConversationLanguage(code: "sv", name: "Swedish", nativeName: "Svenska", flag: "\u{1F1F8}\u{1F1EA}"),
            ConversationLanguage(code: "da", name: "Danish", nativeName: "Dansk", flag: "\u{1F1E9}\u{1F1F0}"),
            ConversationLanguage(code: "fi", name: "Finnish", nativeName: "Suomi", flag: "\u{1F1EB}\u{1F1EE}"),
            ConversationLanguage(code: "no", name: "Norwegian", nativeName: "Norsk", flag: "\u{1F1F3}\u{1F1F4}"),
            ConversationLanguage(code: "tr", name: "Turkish", nativeName: "T\u{00FC}rk\u{00E7}e", flag: "\u{1F1F9}\u{1F1F7}"),
            ConversationLanguage(code: "th", name: "Thai", nativeName: "\u{0E20}\u{0E32}\u{0E29}\u{0E32}\u{0E44}\u{0E17}\u{0E22}", flag: "\u{1F1F9}\u{1F1ED}"),
            ConversationLanguage(code: "vi", name: "Vietnamese", nativeName: "Ti\u{1EBF}ng Vi\u{1EC7}t", flag: "\u{1F1FB}\u{1F1F3}"),
            ConversationLanguage(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "\u{1F1EE}\u{1F1E9}"),
            ConversationLanguage(code: "hi", name: "Hindi", nativeName: "\u{0939}\u{093F}\u{0928}\u{094D}\u{0926}\u{0940}", flag: "\u{1F1EE}\u{1F1F3}"),
            ConversationLanguage(code: "bn", name: "Bengali", nativeName: "\u{09AC}\u{09BE}\u{0982}\u{09B2}\u{09BE}", flag: "\u{1F1E7}\u{1F1E9}")
        ]

        /// Per-conversation language map (conversationID -> code)
        private var conversationLanguages: [String: String] = [:]

        func setLanguage(_ code: String?, forConversation id: String) {
            if let code {
                conversationLanguages[id] = code
            } else {
                conversationLanguages.removeValue(forKey: id)
            }
        }

        func toggleLanguage(_ code: String, forConversation id: String) {
            if conversationLanguages[id] == code {
                conversationLanguages.removeValue(forKey: id)
            } else {
                conversationLanguages[id] = code
            }
        }

        func currentLanguage(forConversation id: String) -> ConversationLanguage? {
            guard let code = conversationLanguages[id] else { return nil }
            return supportedLanguages.first { $0.code == code }
        }

        func isLanguageActive(_ code: String, forConversation id: String) -> Bool {
            conversationLanguages[id] == code
        }

        /// Simulates language detection: returns code if supported and not English
        func detectLanguage(from text: String) -> String? {
            let lowered = text.lowercased()
            // Simple heuristic for test purposes
            let markers: [(String, String)] = [
                ("bonjour", "fr"), ("merci", "fr"), ("salut", "fr"),
                ("hola", "es"), ("gracias", "es"),
                ("danke", "de"), ("guten", "de"),
                ("ciao", "it"), ("grazie", "it"),
                ("obrigado", "pt"), ("obrigada", "pt"),
                ("konnichiwa", "ja"),
                ("annyeong", "ko"),
                ("spasibo", "ru"),
                ("merhaba", "tr"),
                ("namaste", "hi")
            ]
            for (marker, code) in markers where lowered.contains(marker) {
                return code
            }
            // English or unrecognized
            return nil
        }
    }

    // MARK: - FeatureTip Tests

    func testFeatureTipWithPrerequisites() {
        let tip = FeatureTip(id: "tip-agents", featureId: "agents",
                             title: "Create Custom Agents",
                             message: "Did you know you can create specialized agents?",
                             icon: "person.badge.plus", action: "Create Agent",
                             prerequisites: ["conversations"])
        XCTAssertEqual(tip.id, "tip-agents")
        XCTAssertEqual(tip.prerequisites, Set(["conversations"]))
        XCTAssertNotNil(tip.action)
    }

    func testFeatureTipWithNoPrerequisites() {
        let tip = FeatureTip(id: "tip-voice", featureId: "voice",
                             title: "Voice Mode",
                             message: "Press shortcut to talk!",
                             icon: "mic", action: nil,
                             prerequisites: [])
        XCTAssertTrue(tip.prerequisites.isEmpty)
        XCTAssertNil(tip.action)
    }

    // MARK: - ContextualHelp Tests

    func testContextualHelpStructure() {
        let help = ContextualHelp(
            id: "help-conversations",
            screenId: "conversations",
            title: "Conversations Help",
            items: [
                HelpItem(question: "How do I start?", answer: "Click the + button."),
                HelpItem(question: "Can I rename?", answer: "Right-click to rename.")
            ]
        )
        XCTAssertEqual(help.items.count, 2)
        XCTAssertEqual(help.screenId, "conversations")
        XCTAssertEqual(help.items[0].question, "How do I start?")
        XCTAssertEqual(help.items[1].answer, "Right-click to rename.")
    }

    // MARK: - Language Service: Set/Get/Toggle Tests

    func testSetLanguageForConversation() {
        let service = LanguageService()
        service.setLanguage("fr", forConversation: "conv-1")
        let lang = service.currentLanguage(forConversation: "conv-1")
        XCTAssertNotNil(lang)
        XCTAssertEqual(lang?.code, "fr")
        XCTAssertEqual(lang?.name, "French")
    }

    func testClearLanguageForConversation() {
        let service = LanguageService()
        service.setLanguage("de", forConversation: "conv-1")
        service.setLanguage(nil, forConversation: "conv-1")
        XCTAssertNil(service.currentLanguage(forConversation: "conv-1"))
    }

    func testToggleLanguageActivates() {
        let service = LanguageService()
        service.toggleLanguage("ja", forConversation: "conv-2")
        XCTAssertTrue(service.isLanguageActive("ja", forConversation: "conv-2"))
    }

    func testToggleLanguageDeactivates() {
        let service = LanguageService()
        service.toggleLanguage("ja", forConversation: "conv-2")
        service.toggleLanguage("ja", forConversation: "conv-2")
        XCTAssertFalse(service.isLanguageActive("ja", forConversation: "conv-2"))
        XCTAssertNil(service.currentLanguage(forConversation: "conv-2"))
    }

    func testToggleLanguageSwitches() {
        let service = LanguageService()
        service.toggleLanguage("fr", forConversation: "conv-3")
        service.toggleLanguage("de", forConversation: "conv-3")
        XCTAssertTrue(service.isLanguageActive("de", forConversation: "conv-3"))
        XCTAssertFalse(service.isLanguageActive("fr", forConversation: "conv-3"))
    }

    func testLanguageIsolationBetweenConversations() {
        let service = LanguageService()
        service.setLanguage("fr", forConversation: "conv-a")
        service.setLanguage("de", forConversation: "conv-b")
        XCTAssertEqual(service.currentLanguage(forConversation: "conv-a")?.code, "fr")
        XCTAssertEqual(service.currentLanguage(forConversation: "conv-b")?.code, "de")
    }

    func testNoLanguageSetByDefault() {
        let service = LanguageService()
        XCTAssertNil(service.currentLanguage(forConversation: "conv-new"))
        XCTAssertFalse(service.isLanguageActive("en", forConversation: "conv-new"))
    }

    // MARK: - Language Detection Tests

    func testDetectFrench() {
        let service = LanguageService()
        XCTAssertEqual(service.detectLanguage(from: "Bonjour, comment allez-vous?"), "fr")
    }

    func testDetectSpanish() {
        let service = LanguageService()
        XCTAssertEqual(service.detectLanguage(from: "Hola amigo!"), "es")
    }

    func testDetectGerman() {
        let service = LanguageService()
        XCTAssertEqual(service.detectLanguage(from: "Guten Morgen!"), "de")
    }

    func testDetectEnglishReturnsNil() {
        let service = LanguageService()
        // English is not suggested (per real service logic)
        XCTAssertNil(service.detectLanguage(from: "Hello, how are you?"))
    }

    func testDetectUnrecognizedReturnsNil() {
        let service = LanguageService()
        XCTAssertNil(service.detectLanguage(from: "asdfghjkl"))
    }

    // MARK: - Language Catalog Integrity Tests

    func testLanguageCatalogHas27Entries() {
        let service = LanguageService()
        XCTAssertEqual(service.supportedLanguages.count, 27)
    }

    func testAllLanguageCodesUnique() {
        let service = LanguageService()
        let codes = service.supportedLanguages.map(\.code)
        XCTAssertEqual(codes.count, Set(codes).count, "Duplicate language codes found")
    }

    func testRTLLanguagesPresent() {
        let service = LanguageService()
        let rtlCodes: Set<String> = ["ar", "he"]
        let rtl = service.supportedLanguages.filter { rtlCodes.contains($0.code) }
        XCTAssertEqual(rtl.count, 2, "Should have Arabic and Hebrew")
    }

    func testRegionVariantsPresent() {
        let service = LanguageService()
        let codes = Set(service.supportedLanguages.map(\.code))
        XCTAssertTrue(codes.contains("pt"), "Portuguese")
        XCTAssertTrue(codes.contains("pt-BR"), "Brazilian Portuguese")
        XCTAssertTrue(codes.contains("zh-Hans"), "Simplified Chinese")
        XCTAssertTrue(codes.contains("zh-Hant"), "Traditional Chinese")
    }

    func testLanguageHashableInSet() {
        let service = LanguageService()
        let set = Set(service.supportedLanguages)
        XCTAssertEqual(set.count, 27, "All languages should be unique in a Set")
    }

    func testOnlyEnglishHasSameNameAndNativeName() {
        let service = LanguageService()
        let sameNames = service.supportedLanguages.filter { $0.name == $0.nativeName }
        XCTAssertEqual(sameNames.count, 1)
        XCTAssertEqual(sameNames.first?.code, "en")
    }

    func testLookupUnsupportedCodeReturnsNil() {
        let service = LanguageService()
        service.setLanguage("zz-Fake", forConversation: "conv-x")
        XCTAssertNil(service.currentLanguage(forConversation: "conv-x"),
                     "Unsupported code should yield nil from lookup")
    }
}
