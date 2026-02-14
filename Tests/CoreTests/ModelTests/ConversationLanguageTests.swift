// ConversationLanguageTests.swift
// Tests for ConversationLanguage type and language catalog

import Foundation
import XCTest

final class ConversationLanguageTests: XCTestCase {

    // MARK: - ConversationLanguage (mirror)

    struct ConversationLanguage: Identifiable, Sendable, Hashable {
        let code: String
        let name: String
        let nativeName: String
        let flag: String
        var id: String { code }
    }

    // Full catalog from ConversationLanguageService
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

    // MARK: - Catalog Integrity Tests

    func testCatalogHas27Languages() {
        XCTAssertEqual(supportedLanguages.count, 27)
    }

    func testAllCodesNonEmpty() {
        for lang in supportedLanguages {
            XCTAssertFalse(lang.code.isEmpty, "\(lang.name) has empty code")
        }
    }

    func testAllNamesNonEmpty() {
        for lang in supportedLanguages {
            XCTAssertFalse(lang.name.isEmpty, "Code \(lang.code) has empty name")
            XCTAssertFalse(lang.nativeName.isEmpty, "Code \(lang.code) has empty nativeName")
        }
    }

    func testAllFlagsNonEmpty() {
        for lang in supportedLanguages {
            XCTAssertFalse(lang.flag.isEmpty, "\(lang.code) has empty flag")
        }
    }

    func testAllCodesUnique() {
        let codes = supportedLanguages.map(\.code)
        XCTAssertEqual(codes.count, Set(codes).count, "Duplicate language codes detected")
    }

    func testAllIdsUnique() {
        let ids = supportedLanguages.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate language IDs detected")
    }

    func testIdEqualsCode() {
        for lang in supportedLanguages {
            XCTAssertEqual(lang.id, lang.code)
        }
    }

    // MARK: - BCP-47 Format Tests

    func testSimpleCodesAreISO639_1() {
        let simpleCodes = supportedLanguages.filter { !$0.code.contains("-") }.map(\.code)
        for code in simpleCodes {
            XCTAssertEqual(code.count, 2, "Simple code \(code) should be 2-letter ISO 639-1")
            XCTAssertTrue(code.allSatisfy(\.isLetter), "Code \(code) should be all letters")
            XCTAssertEqual(code, code.lowercased(), "Code \(code) should be lowercase")
        }
    }

    func testRegionCodesHaveValidFormat() {
        let regionCodes = supportedLanguages.filter { $0.code.contains("-") }
        XCTAssertGreaterThanOrEqual(regionCodes.count, 3, "Should have pt-BR, zh-Hans, zh-Hant at minimum")

        for lang in regionCodes {
            let parts = lang.code.split(separator: "-")
            XCTAssertEqual(parts.count, 2, "Region code \(lang.code) should have 2 parts")
            XCTAssertTrue(parts[0].count == 2, "Language part of \(lang.code) should be 2 chars")
        }
    }

    func testSpecificLanguageCodes() {
        let codeSet = Set(supportedLanguages.map(\.code))
        // Major languages present
        XCTAssertTrue(codeSet.contains("en"), "English")
        XCTAssertTrue(codeSet.contains("es"), "Spanish")
        XCTAssertTrue(codeSet.contains("fr"), "French")
        XCTAssertTrue(codeSet.contains("de"), "German")
        XCTAssertTrue(codeSet.contains("ja"), "Japanese")
        XCTAssertTrue(codeSet.contains("ko"), "Korean")
        XCTAssertTrue(codeSet.contains("ar"), "Arabic")
        XCTAssertTrue(codeSet.contains("ru"), "Russian")
        XCTAssertTrue(codeSet.contains("hi"), "Hindi")
        // Chinese variants
        XCTAssertTrue(codeSet.contains("zh-Hans"), "Simplified Chinese")
        XCTAssertTrue(codeSet.contains("zh-Hant"), "Traditional Chinese")
        // Portuguese variants
        XCTAssertTrue(codeSet.contains("pt"), "Portuguese")
        XCTAssertTrue(codeSet.contains("pt-BR"), "Brazilian Portuguese")
    }

    // MARK: - Hashable & Identifiable Tests

    func testLanguageEquality() {
        let lang1 = ConversationLanguage(code: "en", name: "English", nativeName: "English", flag: "🇺🇸")
        let lang2 = ConversationLanguage(code: "en", name: "English", nativeName: "English", flag: "🇺🇸")
        XCTAssertEqual(lang1, lang2)
    }

    func testLanguageInequalityByCode() {
        let lang1 = ConversationLanguage(code: "en", name: "English", nativeName: "English", flag: "🇺🇸")
        let lang2 = ConversationLanguage(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷")
        XCTAssertNotEqual(lang1, lang2)
    }

    func testLanguageHashable() {
        let langSet = Set(supportedLanguages)
        XCTAssertEqual(langSet.count, 27, "All languages should be unique in a Set")
    }

    // MARK: - Lookup Tests

    func testLookupByCode() {
        let found = supportedLanguages.first { $0.code == "ja" }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Japanese")
        XCTAssertEqual(found?.nativeName, "日本語")
        XCTAssertEqual(found?.flag, "🇯🇵")
    }

    func testLookupByCodeNotFound() {
        let notFound = supportedLanguages.first { $0.code == "xx" }
        XCTAssertNil(notFound)
    }

    func testLookupByRegionCode() {
        let found = supportedLanguages.first { $0.code == "pt-BR" }
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Brazilian Portuguese")
    }

    // MARK: - Flag Emoji Validity

    func testFlagsAreEmoji() {
        for lang in supportedLanguages {
            let scalars = lang.flag.unicodeScalars
            let isFlag = scalars.allSatisfy { scalar in
                scalar.properties.isEmoji || scalar.properties.isEmojiPresentation
                || (scalar.value >= 0x1F1E6 && scalar.value <= 0x1F1FF) // Regional indicator symbols
            }
            XCTAssertTrue(isFlag, "\(lang.code) flag '\(lang.flag)' should be emoji")
        }
    }

    // MARK: - Native Name Localization

    func testNativeNameDiffersFromEnglishName() {
        let sameNameLanguages = supportedLanguages.filter { $0.name == $0.nativeName }
        // Only English should have same name and nativeName
        XCTAssertEqual(sameNameLanguages.count, 1, "Only English should have same name and nativeName")
        XCTAssertEqual(sameNameLanguages.first?.code, "en")
    }

    // MARK: - RTL Languages

    func testRTLLanguagesPresent() {
        let rtlCodes: Set<String> = ["ar", "he"]
        let rtlLanguages = supportedLanguages.filter { rtlCodes.contains($0.code) }
        XCTAssertEqual(rtlLanguages.count, 2, "Should have Arabic and Hebrew")
    }
}
