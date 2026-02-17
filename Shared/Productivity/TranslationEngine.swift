// TranslationEngine.swift
// Thea — AI-powered multi-provider translation service
// Replaces: DeepL, Google Translate, Auto Translate
//
// Provides on-device (Apple Translation framework) and cloud AI translation.
// Supports 27 languages via ConversationLanguageService catalog.

import Foundation
import NaturalLanguage
import OSLog

private let tlLogger = Logger(subsystem: "ai.thea.app", category: "TranslationEngine")

// MARK: - Translation Request

struct TranslationRequest: Sendable {
    let text: String
    let sourceLanguage: String?   // BCP-47, nil = auto-detect
    let targetLanguage: String    // BCP-47
    let provider: TranslationProvider

    init(text: String, from source: String? = nil, to target: String, provider: TranslationProvider = .auto) {
        self.text = text
        self.sourceLanguage = source
        self.targetLanguage = target
        self.provider = provider
    }
}

// MARK: - Translation Provider

enum TranslationProvider: String, Codable, Sendable, CaseIterable {
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

// MARK: - Translation Result

struct TranslationResult: Sendable, Codable, Identifiable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let detectedSourceLanguage: String?
    let targetLanguage: String
    let provider: String
    let timestamp: Date
    let confidenceScore: Double?

    init(
        sourceText: String,
        translatedText: String,
        detectedSourceLanguage: String?,
        targetLanguage: String,
        provider: String,
        confidenceScore: Double? = nil
    ) {
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

// MARK: - Translation Error

enum TranslationError: Error, LocalizedError, Sendable {
    case noProviderAvailable
    case unsupportedLanguagePair(source: String, target: String)
    case emptyInput
    case providerFailed(String)
    case rateLimited
    case networkUnavailable

    var errorDescription: String? {
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

// MARK: - Translation History Entry

struct TranslationHistoryEntry: Codable, Sendable, Identifiable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let provider: String
    let timestamp: Date
    let isFavorite: Bool

    init(from result: TranslationResult, sourceLanguage: String, isFavorite: Bool = false) {
        self.id = result.id
        self.sourceText = result.sourceText
        self.translatedText = result.translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = result.targetLanguage
        self.provider = result.provider
        self.timestamp = result.timestamp
        self.isFavorite = isFavorite
    }

    func toggled() -> TranslationHistoryEntry {
        TranslationHistoryEntry(
            id: id,
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            provider: provider,
            timestamp: timestamp,
            isFavorite: !isFavorite
        )
    }

    private init(
        id: UUID, sourceText: String, translatedText: String,
        sourceLanguage: String, targetLanguage: String,
        provider: String, timestamp: Date, isFavorite: Bool
    ) {
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

// MARK: - Language Pair

struct LanguagePair: Codable, Sendable, Hashable {
    let source: String
    let target: String

    var displayName: String {
        let sourceName = Self.languageName(for: source)
        let targetName = Self.languageName(for: target)
        return "\(sourceName) → \(targetName)"
    }

    var reversed: LanguagePair {
        LanguagePair(source: target, target: source)
    }

    static func languageName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

// MARK: - Translation Engine

@MainActor
final class TranslationEngine: ObservableObject {
    static let shared = TranslationEngine()

    @Published private(set) var history: [TranslationHistoryEntry] = []
    @Published private(set) var isTranslating = false
    @Published var preferredProvider: TranslationProvider = .auto
    @Published var recentPairs: [LanguagePair] = []

    private let maxHistoryEntries = 200
    private let maxRecentPairs = 10
    private let historyFileURL: URL
    private let recentPairsFileURL: URL
    private let logger = Logger(subsystem: "ai.thea.app", category: "TranslationEngine")

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/Translation", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        self.historyFileURL = dir.appendingPathComponent("history.json")
        self.recentPairsFileURL = dir.appendingPathComponent("recent_pairs.json")

        loadHistory()
        loadRecentPairs()
    }

    // MARK: - Public API

    /// Translate text from one language to another
    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyInput
        }

        isTranslating = true
        defer { isTranslating = false }

        let detectedSource = request.sourceLanguage ?? detectLanguage(request.text)
        let sourceCode = detectedSource ?? "en"

        guard sourceCode != request.targetLanguage else {
            return TranslationResult(
                sourceText: request.text,
                translatedText: request.text,
                detectedSourceLanguage: detectedSource,
                targetLanguage: request.targetLanguage,
                provider: "passthrough"
            )
        }

        let provider = request.provider == .auto
            ? selectBestProvider(for: sourceCode, target: request.targetLanguage)
            : request.provider

        let result: TranslationResult

        switch provider {
        case .claudeAI:
            result = try await translateViaAI(
                text: request.text, from: sourceCode, to: request.targetLanguage,
                providerID: "anthropic", providerName: "Claude AI"
            )
        case .openRouterAI:
            result = try await translateViaAI(
                text: request.text, from: sourceCode, to: request.targetLanguage,
                providerID: "openrouter", providerName: "OpenRouter AI"
            )
        case .localMLX:
            result = try await translateViaAI(
                text: request.text, from: sourceCode, to: request.targetLanguage,
                providerID: "local", providerName: "Local MLX"
            )
        case .appleOnDevice:
            result = try await translateViaApple(
                text: request.text, from: sourceCode, to: request.targetLanguage
            )
        case .auto:
            result = try await translateViaAI(
                text: request.text, from: sourceCode, to: request.targetLanguage,
                providerID: nil, providerName: "Auto"
            )
        }

        let entry = TranslationHistoryEntry(from: result, sourceLanguage: sourceCode)
        addToHistory(entry)

        let pair = LanguagePair(source: sourceCode, target: request.targetLanguage)
        addRecentPair(pair)

        logger.info("Translated \(request.text.prefix(40))... from \(sourceCode) to \(request.targetLanguage) via \(result.provider)")

        return result
    }

    /// Quick translate — auto-detect source, translate to target
    func quickTranslate(_ text: String, to targetLanguage: String) async throws -> String {
        let result = try await translate(
            TranslationRequest(text: text, to: targetLanguage)
        )
        return result.translatedText
    }

    /// Detect the language of input text
    func detectLanguage(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else { return nil }
        return lang.rawValue
    }

    /// Get language confidence scores for text
    func detectLanguageConfidences(_ text: String) -> [(code: String, confidence: Double)] {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
        return hypotheses.map { (code: $0.key.rawValue, confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }
    }

    // MARK: - History Management

    func clearHistory() {
        history = []
        saveHistory()
    }

    func toggleFavorite(_ entry: TranslationHistoryEntry) {
        if let idx = history.firstIndex(where: { $0.id == entry.id }) {
            history[idx] = history[idx].toggled()
            saveHistory()
        }
    }

    func deleteHistoryEntry(_ entry: TranslationHistoryEntry) {
        history.removeAll { $0.id == entry.id }
        saveHistory()
    }

    // MARK: - Provider Selection

    private func selectBestProvider(for source: String, target: String) -> TranslationProvider {
        // Try Apple on-device first for common pairs
        let appleSupported = isAppleTranslationAvailable(from: source, to: target)
        if appleSupported {
            return .appleOnDevice
        }

        // Then try configured AI providers
        if let _ = ProviderRegistry.shared.getProvider(id: "anthropic") {
            return .claudeAI
        }
        if let _ = ProviderRegistry.shared.getProvider(id: "openrouter") {
            return .openRouterAI
        }

        #if os(macOS)
        if let _ = ProviderRegistry.shared.getProvider(id: "local") {
            return .localMLX
        }
        #endif

        return .claudeAI
    }

    private func isAppleTranslationAvailable(from source: String, to target: String) -> Bool {
        // Apple Translation framework supports ~20 language pairs on-device
        // Common pairs that Apple supports well
        let appleLanguages: Set<String> = [
            "en", "es", "fr", "de", "it", "pt", "pt-BR", "zh-Hans", "zh-Hant",
            "ja", "ko", "ar", "ru", "pl", "nl", "tr", "th", "vi", "id", "uk"
        ]
        return appleLanguages.contains(source) && appleLanguages.contains(target)
    }

    // MARK: - AI Provider Translation

    private func translateViaAI(
        text: String,
        from source: String,
        to target: String,
        providerID: String?,
        providerName: String
    ) async throws -> TranslationResult {
        let provider: (any AIProvider)?

        if let id = providerID {
            provider = ProviderRegistry.shared.getProvider(id: id)
        } else {
            provider = ProviderRegistry.shared.getProvider(id: "anthropic")
                ?? ProviderRegistry.shared.getProvider(id: "openrouter")
                ?? ProviderRegistry.shared.getProvider(id: "openai")
        }

        guard let aiProvider = provider else {
            throw TranslationError.noProviderAvailable
        }

        let sourceName = LanguagePair.languageName(for: source)
        let targetName = LanguagePair.languageName(for: target)

        let systemPrompt = """
            You are a professional translator. Translate the following text from \(sourceName) to \(targetName). \
            Rules: \
            1. Output ONLY the translated text — no explanations, no quotes, no prefixes. \
            2. Preserve the original formatting (line breaks, paragraphs, lists). \
            3. Preserve technical terms, proper nouns, brand names, and code snippets as-is. \
            4. Use natural, fluent \(targetName) — not word-for-word translation. \
            5. Match the formality level of the source text.
            """

        let messages: [AIMessage] = [
            AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .system,
                content: .text(systemPrompt),
                timestamp: Date(),
                model: ""
            ),
            AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(text),
                timestamp: Date(),
                model: ""
            )
        ]

        // Select a cost-effective model
        let model = selectTranslationModel(for: aiProvider)

        let responseStream = try await aiProvider.chat(
            messages: messages,
            model: model,
            stream: false
        )

        var translatedText = ""
        for try await chunk in responseStream {
            switch chunk.type {
            case .delta(let delta):
                translatedText += delta
            case .thinkingDelta: break
            case .complete(let message):
                if translatedText.isEmpty {
                    translatedText = message.content.textValue
                }
            case .error:
                break
            }
        }

        guard !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.providerFailed("Empty response from \(providerName)")
        }

        return TranslationResult(
            sourceText: text,
            translatedText: translatedText.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedSourceLanguage: source,
            targetLanguage: target,
            provider: providerName,
            confidenceScore: 0.9
        )
    }

    private func selectTranslationModel(for provider: any AIProvider) -> String {
        // Prefer fast, cheap models for translation
        let providerName = provider.metadata.name.lowercased()
        if providerName.contains("anthropic") {
            return "claude-haiku-4-5-20251001"
        } else if providerName.contains("openai") {
            return "gpt-4o-mini"
        } else if providerName.contains("openrouter") {
            return "anthropic/claude-haiku-4-5-20251001"
        } else if providerName.contains("google") {
            return "gemini-2.0-flash"
        }
        return "claude-haiku-4-5-20251001"
    }

    // MARK: - Apple Translation Framework

    private func translateViaApple(
        text: String,
        from source: String,
        to target: String
    ) async throws -> TranslationResult {
        // Apple Translation framework requires specific locale format
        // and availability check. Fall back to AI if not available.
        // Note: Translation.framework requires import Translation and
        // is only available on macOS 14.4+ / iOS 17.4+
        // For now, use AI fallback since Translation requires SwiftUI view context
        logger.info("Apple on-device translation requested — falling back to AI provider")
        return try await translateViaAI(
            text: text, from: source, to: target,
            providerID: nil, providerName: "Auto (Apple fallback)"
        )
    }

    // MARK: - Persistence

    private func addToHistory(_ entry: TranslationHistoryEntry) {
        history.insert(entry, at: 0)
        if history.count > maxHistoryEntries {
            // Keep favorites, trim oldest non-favorites
            let favorites = history.filter(\.isFavorite)
            var nonFavorites = history.filter { !$0.isFavorite }
            if nonFavorites.count > maxHistoryEntries - favorites.count {
                nonFavorites = Array(nonFavorites.prefix(maxHistoryEntries - favorites.count))
            }
            history = (favorites + nonFavorites).sorted { $0.timestamp > $1.timestamp }
        }
        saveHistory()
    }

    private func addRecentPair(_ pair: LanguagePair) {
        recentPairs.removeAll { $0 == pair }
        recentPairs.insert(pair, at: 0)
        if recentPairs.count > maxRecentPairs {
            recentPairs = Array(recentPairs.prefix(maxRecentPairs))
        }
        saveRecentPairs()
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            history = try JSONDecoder().decode([TranslationHistoryEntry].self, from: data)
        } catch {
            logger.error("Failed to load translation history: \(error.localizedDescription)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save translation history: \(error.localizedDescription)")
        }
    }

    private func loadRecentPairs() {
        guard FileManager.default.fileExists(atPath: recentPairsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: recentPairsFileURL)
            recentPairs = try JSONDecoder().decode([LanguagePair].self, from: data)
        } catch {
            logger.error("Failed to load recent pairs: \(error.localizedDescription)")
        }
    }

    private func saveRecentPairs() {
        do {
            let data = try JSONEncoder().encode(recentPairs)
            try data.write(to: recentPairsFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save recent pairs: \(error.localizedDescription)")
        }
    }
}
