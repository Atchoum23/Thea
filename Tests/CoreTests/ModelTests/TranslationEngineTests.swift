// TranslationEngineTests.swift
// Tests for TranslationEngine types, language detection, history, and provider selection

import Testing
import Foundation

// MARK: - Translation Provider Tests

@Suite("TranslationProvider")
struct TranslationProviderTests {
    @Test("All cases have unique raw values")
    func uniqueRawValues() {
        let rawValues = TranslationProviderTestDouble.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All cases have non-empty icons")
    func icons() {
        for provider in TranslationProviderTestDouble.allCases {
            #expect(!provider.icon.isEmpty, "Provider \(provider.rawValue) should have an icon")
        }
    }

    @Test("On-device identification", arguments: [
        (TranslationProviderTestDouble.appleOnDevice, true),
        (.localMLX, true),
        (.auto, false),
        (.claudeAI, false),
        (.openRouterAI, false)
    ])
    func isOnDevice(provider: TranslationProviderTestDouble, expected: Bool) {
        #expect(provider.isOnDevice == expected)
    }

    @Test("Count matches expected")
    func caseCount() {
        #expect(TranslationProviderTestDouble.allCases.count == 5)
    }
}

// MARK: - Translation Error Tests

@Suite("TranslationError")
struct TranslationErrorTests {
    @Test("All errors have descriptions")
    func descriptions() {
        let errors: [TranslationErrorTestDouble] = [
            .noProviderAvailable,
            .unsupportedLanguagePair(source: "en", target: "xx"),
            .emptyInput,
            .providerFailed("timeout"),
            .rateLimited,
            .networkUnavailable
        ]
        for error in errors {
            #expect(!error.errorDescription.isEmpty, "Error should have description")
        }
    }

    @Test("Unsupported pair includes language codes in description")
    func unsupportedPairDescription() {
        let error = TranslationErrorTestDouble.unsupportedLanguagePair(source: "en", target: "xx")
        #expect(error.errorDescription.contains("en"))
        #expect(error.errorDescription.contains("xx"))
    }

    @Test("Provider failed preserves detail")
    func providerFailedDetail() {
        let error = TranslationErrorTestDouble.providerFailed("Connection timeout")
        #expect(error.errorDescription.contains("Connection timeout"))
    }
}

// MARK: - Translation Result Tests

@Suite("TranslationResult")
struct TranslationResultTests {
    @Test("Creation with all fields")
    func creation() {
        let result = TranslationResultTestDouble(
            sourceText: "Hello",
            translatedText: "Bonjour",
            detectedSourceLanguage: "en",
            targetLanguage: "fr",
            provider: "Claude AI",
            confidenceScore: 0.95
        )
        #expect(result.sourceText == "Hello")
        #expect(result.translatedText == "Bonjour")
        #expect(result.detectedSourceLanguage == "en")
        #expect(result.targetLanguage == "fr")
        #expect(result.provider == "Claude AI")
        #expect(result.confidenceScore == 0.95)
    }

    @Test("Creation with nil optional fields")
    func nilFields() {
        let result = TranslationResultTestDouble(
            sourceText: "Test",
            translatedText: "Test",
            detectedSourceLanguage: nil,
            targetLanguage: "en",
            provider: "Auto"
        )
        #expect(result.detectedSourceLanguage == nil)
        #expect(result.confidenceScore == nil)
    }

    @Test("Identifiable with unique IDs")
    func uniqueIDs() {
        let r1 = TranslationResultTestDouble(sourceText: "A", translatedText: "B", detectedSourceLanguage: nil, targetLanguage: "fr", provider: "x")
        let r2 = TranslationResultTestDouble(sourceText: "A", translatedText: "B", detectedSourceLanguage: nil, targetLanguage: "fr", provider: "x")
        #expect(r1.id != r2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let result = TranslationResultTestDouble(
            sourceText: "Hello world",
            translatedText: "Bonjour le monde",
            detectedSourceLanguage: "en",
            targetLanguage: "fr",
            provider: "Claude AI",
            confidenceScore: 0.9
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TranslationResultTestDouble.self, from: data)
        #expect(decoded.sourceText == result.sourceText)
        #expect(decoded.translatedText == result.translatedText)
        #expect(decoded.targetLanguage == result.targetLanguage)
        #expect(decoded.provider == result.provider)
    }
}

// MARK: - Translation History Entry Tests

@Suite("TranslationHistoryEntry")
struct TranslationHistoryEntryTests {
    @Test("Creation from result")
    func fromResult() {
        let result = TranslationResultTestDouble(
            sourceText: "Hello",
            translatedText: "Hola",
            detectedSourceLanguage: "en",
            targetLanguage: "es",
            provider: "OpenRouter AI"
        )
        let entry = TranslationHistoryEntryTestDouble(from: result, sourceLanguage: "en")
        #expect(entry.id == result.id)
        #expect(entry.sourceText == "Hello")
        #expect(entry.translatedText == "Hola")
        #expect(entry.sourceLanguage == "en")
        #expect(entry.targetLanguage == "es")
        #expect(entry.provider == "OpenRouter AI")
        #expect(!entry.isFavorite)
    }

    @Test("Toggle favorite")
    func toggleFavorite() {
        let result = TranslationResultTestDouble(sourceText: "A", translatedText: "B", detectedSourceLanguage: nil, targetLanguage: "fr", provider: "x")
        let entry = TranslationHistoryEntryTestDouble(from: result, sourceLanguage: "en")
        #expect(!entry.isFavorite)

        let toggled = entry.toggled()
        #expect(toggled.isFavorite)
        #expect(toggled.id == entry.id)
        #expect(toggled.sourceText == entry.sourceText)

        let toggledBack = toggled.toggled()
        #expect(!toggledBack.isFavorite)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let result = TranslationResultTestDouble(sourceText: "A", translatedText: "B", detectedSourceLanguage: "en", targetLanguage: "de", provider: "Claude AI")
        let entry = TranslationHistoryEntryTestDouble(from: result, sourceLanguage: "en", isFavorite: true)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TranslationHistoryEntryTestDouble.self, from: data)
        #expect(decoded.sourceText == "A")
        #expect(decoded.translatedText == "B")
        #expect(decoded.sourceLanguage == "en")
        #expect(decoded.targetLanguage == "de")
        #expect(decoded.isFavorite)
    }
}

// MARK: - Language Pair Tests

@Suite("LanguagePair")
struct LanguagePairTests {
    @Test("Display name includes arrow")
    func displayName() {
        let pair = LanguagePairTestDouble(source: "en", target: "fr")
        let name = pair.displayName
        #expect(name.contains("→"))
    }

    @Test("Reversed swaps source and target")
    func reversed() {
        let pair = LanguagePairTestDouble(source: "en", target: "ja")
        let rev = pair.reversed
        #expect(rev.source == "ja")
        #expect(rev.target == "en")
    }

    @Test("Double reverse equals original")
    func doubleReverse() {
        let pair = LanguagePairTestDouble(source: "de", target: "ru")
        let doubleRev = pair.reversed.reversed
        #expect(doubleRev == pair)
    }

    @Test("Hashable — equal pairs hash equal")
    func hashable() {
        let p1 = LanguagePairTestDouble(source: "en", target: "fr")
        let p2 = LanguagePairTestDouble(source: "en", target: "fr")
        #expect(p1 == p2)
        #expect(p1.hashValue == p2.hashValue)
    }

    @Test("Different pairs are not equal")
    func inequality() {
        let p1 = LanguagePairTestDouble(source: "en", target: "fr")
        let p2 = LanguagePairTestDouble(source: "fr", target: "en")
        #expect(p1 != p2)
    }

    @Test("Language name resolution")
    func languageName() {
        let name = LanguagePairTestDouble.languageName(for: "fr")
        // Should resolve to "French" or locale-specific equivalent
        #expect(!name.isEmpty)
        #expect(name != "fr") // Should resolve, not just return code

        let unknown = LanguagePairTestDouble.languageName(for: "zzzz")
        #expect(!unknown.isEmpty) // Falls back to code itself
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let pair = LanguagePairTestDouble(source: "en", target: "zh-Hans")
        let data = try JSONEncoder().encode(pair)
        let decoded = try JSONDecoder().decode(LanguagePairTestDouble.self, from: data)
        #expect(decoded == pair)
    }
}

// MARK: - Translation Request Tests

@Suite("TranslationRequest")
struct TranslationRequestTests {
    @Test("Default provider is auto")
    func defaultProvider() {
        let req = TranslationRequestTestDouble(text: "Hello", from: nil, to: "fr")
        #expect(req.provider == .auto)
    }

    @Test("Explicit provider")
    func explicitProvider() {
        let req = TranslationRequestTestDouble(text: "Hello", from: "en", to: "de", provider: .claudeAI)
        #expect(req.provider == .claudeAI)
        #expect(req.sourceLanguage == "en")
        #expect(req.targetLanguage == "de")
    }

    @Test("Nil source language for auto-detect")
    func autoDetect() {
        let req = TranslationRequestTestDouble(text: "Bonjour", from: nil, to: "en")
        #expect(req.sourceLanguage == nil)
    }
}

// MARK: - Language Detection Tests

@Suite("LanguageDetection")
struct LanguageDetectionTests {
    @Test("Detect French text")
    func detectFrench() {
        let text = "Bonjour, comment allez-vous aujourd'hui? Je suis très content de vous voir."
        let detected = detectLanguageHelper(text)
        #expect(detected == "fr")
    }

    @Test("Detect Spanish text")
    func detectSpanish() {
        let text = "Buenos días, ¿cómo estás? Espero que tengas un buen día."
        let detected = detectLanguageHelper(text)
        #expect(detected == "es")
    }

    @Test("Detect German text")
    func detectGerman() {
        let text = "Guten Morgen, wie geht es Ihnen? Ich hoffe, Sie haben einen schönen Tag."
        let detected = detectLanguageHelper(text)
        #expect(detected == "de")
    }

    @Test("Detect Japanese text")
    func detectJapanese() {
        let text = "おはようございます。今日はいい天気ですね。"
        let detected = detectLanguageHelper(text)
        #expect(detected == "ja")
    }

    @Test("Detect Russian text")
    func detectRussian() {
        let text = "Добрый день, как ваши дела? Надеюсь, у вас всё хорошо."
        let detected = detectLanguageHelper(text)
        #expect(detected == "ru")
    }

    @Test("Detect English text")
    func detectEnglish() {
        let text = "Hello, how are you doing today? I hope you're having a wonderful day."
        let detected = detectLanguageHelper(text)
        #expect(detected == "en")
    }

    @Test("Very short text may return nil")
    func shortText() {
        let text = "Hi"
        // NLLanguageRecognizer may or may not detect with very short text
        let detected = detectLanguageHelper(text)
        // Just verify it doesn't crash; result may be nil or a language
        _ = detected
    }

    @Test("Empty text returns nil")
    func emptyText() {
        let detected = detectLanguageHelper("")
        #expect(detected == nil)
    }

    @Test("Confidence scores for multi-language text")
    func confidenceScores() {
        let text = "Bonjour, comment allez-vous?"
        let scores = detectLanguageConfidencesHelper(text)
        #expect(!scores.isEmpty)
        #expect(scores[0].confidence > 0)
        // Scores should be sorted descending
        if scores.count > 1 {
            #expect(scores[0].confidence >= scores[1].confidence)
        }
    }
}

// MARK: - History Management Tests

@Suite("HistoryManagement")
struct HistoryManagementTests {
    @Test("History trimming keeps favorites")
    func historyTrimmingKeepsFavorites() {
        var history: [TranslationHistoryEntryTestDouble] = []

        // Add 205 entries (over 200 limit)
        for idx in 0..<205 {
            let result = TranslationResultTestDouble(
                sourceText: "Text \(idx)",
                translatedText: "Texte \(idx)",
                detectedSourceLanguage: "en",
                targetLanguage: "fr",
                provider: "Test"
            )
            let entry = TranslationHistoryEntryTestDouble(
                from: result,
                sourceLanguage: "en",
                isFavorite: idx % 50 == 0 // 5 favorites
            )
            history.insert(entry, at: 0)
        }

        // Simulate trimming
        let maxEntries = 200
        let favorites = history.filter(\.isFavorite)
        var nonFavorites = history.filter { !$0.isFavorite }
        if nonFavorites.count > maxEntries - favorites.count {
            nonFavorites = Array(nonFavorites.prefix(maxEntries - favorites.count))
        }
        let trimmed = (favorites + nonFavorites).sorted { $0.timestamp > $1.timestamp }

        #expect(trimmed.count <= maxEntries)
        // All favorites should be preserved
        #expect(trimmed.filter(\.isFavorite).count == favorites.count)
    }

    @Test("Recent pairs deduplication")
    func recentPairsDedup() {
        var pairs: [LanguagePairTestDouble] = []
        let pair1 = LanguagePairTestDouble(source: "en", target: "fr")
        let pair2 = LanguagePairTestDouble(source: "en", target: "de")

        // Add pair1 twice
        pairs.removeAll { $0 == pair1 }
        pairs.insert(pair1, at: 0)
        pairs.removeAll { $0 == pair2 }
        pairs.insert(pair2, at: 0)
        pairs.removeAll { $0 == pair1 }
        pairs.insert(pair1, at: 0)

        // pair1 should be at position 0 (most recent)
        #expect(pairs[0] == pair1)
        // pair2 should be at position 1
        #expect(pairs[1] == pair2)
        // No duplicates
        #expect(pairs.count == 2)
    }

    @Test("Recent pairs max limit")
    func recentPairsMaxLimit() {
        var pairs: [LanguagePairTestDouble] = []
        let maxPairs = 10

        for idx in 0..<15 {
            let pair = LanguagePairTestDouble(source: "en", target: "l\(idx)")
            pairs.removeAll { $0 == pair }
            pairs.insert(pair, at: 0)
            if pairs.count > maxPairs {
                pairs = Array(pairs.prefix(maxPairs))
            }
        }

        #expect(pairs.count == maxPairs)
        // Most recent should be l14
        #expect(pairs[0].target == "l14")
    }
}

// MARK: - Apple Translation Availability Tests

@Suite("AppleTranslationAvailability")
struct AppleTranslationAvailabilityTests {
    private let appleLanguages: Set<String> = [
        "en", "es", "fr", "de", "it", "pt", "pt-BR", "zh-Hans", "zh-Hant",
        "ja", "ko", "ar", "ru", "pl", "nl", "tr", "th", "vi", "id", "uk"
    ]

    @Test("Common pair supported", arguments: [
        ("en", "fr"),
        ("en", "de"),
        ("en", "ja"),
        ("fr", "es"),
        ("de", "it")
    ])
    func supportedPair(source: String, target: String) {
        #expect(appleLanguages.contains(source))
        #expect(appleLanguages.contains(target))
    }

    @Test("Unsupported language not in Apple set", arguments: [
        "bn", "he", "hi", "sv", "da", "fi", "no"
    ])
    func unsupportedLanguage(code: String) {
        #expect(!appleLanguages.contains(code))
    }
}

// MARK: - Translation Model Selection Tests

@Suite("ModelSelection")
struct ModelSelectionTests {
    @Test("Anthropic provider uses Haiku")
    func anthropicModel() {
        let model = selectModelByProvider("anthropic")
        #expect(model.contains("haiku"))
    }

    @Test("OpenAI provider uses mini model")
    func openaiModel() {
        let model = selectModelByProvider("openai")
        #expect(model.contains("mini"))
    }

    @Test("OpenRouter provider uses Haiku via namespace")
    func openRouterModel() {
        let model = selectModelByProvider("openrouter")
        #expect(model.contains("anthropic/"))
        #expect(model.contains("haiku"))
    }

    @Test("Google provider uses Flash")
    func googleModel() {
        let model = selectModelByProvider("google")
        #expect(model.contains("flash"))
    }

    @Test("Unknown provider falls back to Haiku")
    func unknownProvider() {
        let model = selectModelByProvider("unknownprovider")
        #expect(model.contains("haiku"))
    }

    private func selectModelByProvider(_ name: String) -> String {
        if name.contains("anthropic") {
            return "claude-haiku-4-5-20251001"
        } else if name.contains("openai") {
            return "gpt-4o-mini"
        } else if name.contains("openrouter") {
            return "anthropic/claude-haiku-4-5-20251001"
        } else if name.contains("google") {
            return "gemini-2.0-flash"
        }
        return "claude-haiku-4-5-20251001"
    }
}

// MARK: - Test Doubles

// Mirror production types for testing without importing app target

enum TranslationProviderTestDouble: String, Codable, Sendable, CaseIterable {
    case auto = "Auto"
    case appleOnDevice = "Apple (On-Device)"
    case claudeAI = "Claude AI"
    case openRouterAI = "OpenRouter AI"
    case localMLX = "Local MLX"

    var icon: String {
        switch self {
        case .auto: "sparkles"
        case .appleOnDevice: "apple.logo"
        case .claudeAI: "cloud"
        case .openRouterAI: "network"
        case .localMLX: "desktopcomputer"
        }
    }

    var isOnDevice: Bool {
        switch self {
        case .appleOnDevice, .localMLX: true
        case .auto, .claudeAI, .openRouterAI: false
        }
    }
}

enum TranslationErrorTestDouble: Error {
    case noProviderAvailable
    case unsupportedLanguagePair(source: String, target: String)
    case emptyInput
    case providerFailed(String)
    case rateLimited
    case networkUnavailable

    var errorDescription: String {
        switch self {
        case .noProviderAvailable:
            "No translation provider is available. Configure an AI provider in Settings."
        case .unsupportedLanguagePair(let source, let target):
            "Translation from \(source) to \(target) is not supported."
        case .emptyInput:
            "No text to translate."
        case .providerFailed(let detail):
            "Translation failed: \(detail)"
        case .rateLimited:
            "Too many translation requests. Please wait a moment."
        case .networkUnavailable:
            "Network is unavailable. On-device translation may still work."
        }
    }
}

struct TranslationResultTestDouble: Sendable, Codable, Identifiable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let detectedSourceLanguage: String?
    let targetLanguage: String
    let provider: String
    let timestamp: Date
    let confidenceScore: Double?

    init(sourceText: String, translatedText: String, detectedSourceLanguage: String?,
         targetLanguage: String, provider: String, confidenceScore: Double? = nil) {
        self.id = UUID()
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.detectedSourceLanguage = detectedSourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
        self.timestamp = Date()
        self.confidenceScore = confidenceScore
    }
}

struct TranslationHistoryEntryTestDouble: Codable, Sendable, Identifiable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let provider: String
    let timestamp: Date
    let isFavorite: Bool

    init(from result: TranslationResultTestDouble, sourceLanguage: String, isFavorite: Bool = false) {
        self.id = result.id
        self.sourceText = result.sourceText
        self.translatedText = result.translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = result.targetLanguage
        self.provider = result.provider
        self.timestamp = result.timestamp
        self.isFavorite = isFavorite
    }

    func toggled() -> TranslationHistoryEntryTestDouble {
        TranslationHistoryEntryTestDouble(
            id: id, sourceText: sourceText, translatedText: translatedText,
            sourceLanguage: sourceLanguage, targetLanguage: targetLanguage,
            provider: provider, timestamp: timestamp, isFavorite: !isFavorite
        )
    }

    private init(id: UUID, sourceText: String, translatedText: String,
                 sourceLanguage: String, targetLanguage: String,
                 provider: String, timestamp: Date, isFavorite: Bool) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
        self.timestamp = timestamp
        self.isFavorite = isFavorite
    }
}

struct LanguagePairTestDouble: Codable, Sendable, Hashable {
    let source: String
    let target: String

    var displayName: String {
        let sourceName = Self.languageName(for: source)
        let targetName = Self.languageName(for: target)
        return "\(sourceName) → \(targetName)"
    }

    var reversed: LanguagePairTestDouble {
        LanguagePairTestDouble(source: target, target: source)
    }

    static func languageName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

struct TranslationRequestTestDouble: Sendable {
    let text: String
    let sourceLanguage: String?
    let targetLanguage: String
    let provider: TranslationProviderTestDouble

    init(text: String, from source: String? = nil, to target: String,
         provider: TranslationProviderTestDouble = .auto) {
        self.text = text
        self.sourceLanguage = source
        self.targetLanguage = target
        self.provider = provider
    }
}

// MARK: - Language Detection Helpers

import NaturalLanguage

func detectLanguageHelper(_ text: String) -> String? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    return recognizer.dominantLanguage?.rawValue
}

func detectLanguageConfidencesHelper(_ text: String) -> [(code: String, confidence: Double)] {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
    return hypotheses.map { (code: $0.key.rawValue, confidence: $0.value) }
        .sorted { $0.confidence > $1.confidence }
}
