// LiveAutoCorrect.swift
// Thea V2
//
// AI-powered live auto-correct with language detection.
// Provides real-time text correction as users type.
//
// FEATURES:
// - Live language detection (supports 50+ languages)
// - Context-aware spelling correction
// - Grammar improvement suggestions
// - Smart punctuation
// - Code/URL/email preservation (no correction)
// - User dictionary learning
//
// USAGE:
//   let corrector = LiveAutoCorrect.shared
//   corrector.isEnabled = true
//   let corrected = await corrector.correct("teh quick brwon fox")
//   // Returns: "the quick brown fox"
//
// CREATED: February 2, 2026

import Foundation
import NaturalLanguage
import OSLog
import Combine
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Live Auto-Correct Service

@MainActor
@Observable
public final class LiveAutoCorrect {
    public static let shared = LiveAutoCorrect()

    private let logger = Logger(subsystem: "com.thea.ai", category: "LiveAutoCorrect")

    // MARK: - Configuration

    /// Enable/disable live auto-correct
    public var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "LiveAutoCorrect.isEnabled")
            logger.info("Live auto-correct \(self.isEnabled ? "enabled" : "disabled")")
        }
    }

    /// Correct as user types (debounced)
    public var liveMode: Bool = true

    /// Debounce interval for live corrections (milliseconds)
    public var debounceInterval: Int = 300

    /// Minimum word length to attempt correction
    public var minimumWordLength: Int = 2

    /// Show inline suggestions vs auto-replace
    public var showSuggestions: Bool = true

    /// Languages to support (empty = auto-detect all)
    public var supportedLanguages: Set<String> = []

    /// User's custom dictionary additions
    public var userDictionary: Set<String> = []

    // MARK: - State

    /// Currently detected language
    public private(set) var detectedLanguage: String = "en"

    /// Confidence of language detection (0-1)
    public private(set) var languageConfidence: Double = 0

    /// Statistics
    public private(set) var stats = AutoCorrectStats()

    // MARK: - Dynamic Configuration
    // Note: Uses DynamicConfig for AI-powered optimal values

    private var maxCacheSize: Int {
        DynamicConfig.shared.optimalCacheSize
    }

    // MARK: - Private

    private let languageRecognizer = NLLanguageRecognizer()
    #if os(macOS)
    private let spellChecker = NSSpellChecker.shared
    #endif
    private var correctionCache: [String: CorrectionResult] = [:]
    private var cacheOrder: [String] = [] // LRU tracking
    private var debounceTask: Task<Void, Never>?

    private init() {
        loadSettings()
        loadUserDictionary()
    }

    // MARK: - Public API

    /// Correct text with AI-powered analysis
    /// - Parameter text: The text to correct
    /// - Returns: Corrected text with metadata
    public func correct(_ text: String) async -> CorrectionResult {
        guard isEnabled else {
            return CorrectionResult(original: text, corrected: text, corrections: [])
        }

        // Check cache
        if let cached = correctionCache[text] {
            return cached
        }

        let startTime = Date()

        // Detect language
        let language = detectLanguage(in: text)
        detectedLanguage = language.code
        languageConfidence = language.confidence

        // Skip correction for code, URLs, emails
        if shouldSkipCorrection(text) {
            return CorrectionResult(original: text, corrected: text, corrections: [])
        }

        // Perform corrections
        var corrections: [Correction] = []
        var correctedText = text

        // Word-level spelling correction
        let words = tokenize(text)
        for word in words {
            if let correction = correctWord(word, language: language.code) {
                corrections.append(correction)
                correctedText = correctedText.replacingOccurrences(
                    of: word.text,
                    with: correction.replacement,
                    range: word.range
                )
            }
        }

        // Grammar and punctuation (using AI for complex cases)
        if corrections.isEmpty {
            // Only use AI if basic spell check found nothing
            if let aiCorrections = await correctWithAI(text, language: language.code) {
                corrections.append(contentsOf: aiCorrections)
                for correction in aiCorrections {
                    correctedText = correctedText.replacingOccurrences(
                        of: correction.original,
                        with: correction.replacement
                    )
                }
            }
        }

        // Update stats
        stats.totalCorrections += corrections.count
        stats.textsProcessed += 1
        stats.averageProcessingTime = (stats.averageProcessingTime + Date().timeIntervalSince(startTime)) / 2

        let result = CorrectionResult(
            original: text,
            corrected: correctedText,
            corrections: corrections,
            language: language.code,
            confidence: language.confidence,
            processingTime: Date().timeIntervalSince(startTime)
        )

        // Cache result with LRU eviction
        cacheResult(text: text, result: result)

        return result
    }

    private func cacheResult(text: String, result: CorrectionResult) {
        // Remove if already exists (will re-add at end)
        if let index = cacheOrder.firstIndex(of: text) {
            cacheOrder.remove(at: index)
        }

        correctionCache[text] = result
        cacheOrder.append(text)

        // Evict oldest entries if over dynamic limit
        while cacheOrder.count > maxCacheSize {
            let oldest = cacheOrder.removeFirst()
            correctionCache.removeValue(forKey: oldest)
        }
    }

    /// Process text as user types (debounced)
    public func processLiveInput(_ text: String, completion: @escaping @Sendable (CorrectionResult) -> Void) {
        debounceTask?.cancel()

        debounceTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: UInt64(self.debounceInterval) * 1_000_000)
            } catch {
                return // Task was cancelled
            }

            if !Task.isCancelled {
                let result = await self.correct(text)
                await MainActor.run {
                    completion(result)
                }
            }
        }
    }

    /// Get suggestions for a specific word
    public func suggestions(for word: String) -> [String] {
        #if os(macOS)
        let range = NSRange(location: 0, length: word.utf16.count)
        let guesses = spellChecker.guesses(
            forWordRange: range,
            in: word,
            language: detectedLanguage,
            inSpellDocumentWithTag: 0
        )
        return guesses ?? []
        #elseif os(iOS)
        // Use UITextChecker for iOS
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: word.utf16.count)
        let guesses = checker.guesses(forWordRange: range, in: word, language: detectedLanguage) ?? []
        return guesses
        #else
        return []
        #endif
    }

    /// Add word to user dictionary
    public func addToUserDictionary(_ word: String) {
        userDictionary.insert(word.lowercased())
        saveUserDictionary()
        #if os(macOS)
        spellChecker.learnWord(word)
        #elseif os(iOS)
        UITextChecker.learnWord(word)
        #endif
        logger.info("Added '\(word)' to user dictionary")
    }

    /// Remove word from user dictionary
    public func removeFromUserDictionary(_ word: String) {
        userDictionary.remove(word.lowercased())
        saveUserDictionary()
        #if os(macOS)
        spellChecker.unlearnWord(word)
        #elseif os(iOS)
        UITextChecker.unlearnWord(word)
        #endif
    }

    /// Clear correction cache
    public func clearCache() {
        correctionCache.removeAll()
    }

    /// Reset statistics
    public func resetStats() {
        stats = AutoCorrectStats()
    }

    // MARK: - Language Detection

    /// Detect language with confidence score
    public func detectLanguage(in text: String) -> (code: String, confidence: Double) {
        languageRecognizer.reset()
        languageRecognizer.processString(text)

        guard let language = languageRecognizer.dominantLanguage else {
            return ("en", 0.5) // Default to English
        }

        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
        let confidence = hypotheses[language] ?? 0.5

        return (language.rawValue, confidence)
    }

    /// Get all detected languages with confidence scores
    public func detectLanguages(in text: String, maxResults: Int = 5) -> [(code: String, confidence: Double)] {
        languageRecognizer.reset()
        languageRecognizer.processString(text)

        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: maxResults)
        return hypotheses.map { ($0.key.rawValue, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: - Private Methods

    private func tokenize(_ text: String) -> [WordToken] {
        var tokens: [WordToken] = []
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .tokenType) { tag, range in
            if tag == .word {
                let word = String(text[range])
                if word.count >= minimumWordLength {
                    tokens.append(WordToken(
                        text: word,
                        range: range
                    ))
                }
            }
            return true
        }

        return tokens
    }

    private func correctWord(_ word: WordToken, language: String) -> Correction? {
        // Skip if in user dictionary
        if userDictionary.contains(word.text.lowercased()) {
            return nil
        }

        // Skip proper nouns (capitalized words)
        if word.text.first?.isUppercase == true && word.text.dropFirst().allSatisfy({ $0.isLowercase }) {
            // Might be a proper noun - skip
            return nil
        }

        let range = NSRange(location: 0, length: word.text.utf16.count)

        #if os(macOS)
        let misspelledRange = spellChecker.checkSpelling(
            of: word.text,
            startingAt: 0,
            language: language,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )

        if misspelledRange.location != NSNotFound {
            // Word is misspelled
            if let suggestions = spellChecker.guesses(
                forWordRange: range,
                in: word.text,
                language: language,
                inSpellDocumentWithTag: 0
            ), let firstSuggestion = suggestions.first {
                return Correction(
                    original: word.text,
                    replacement: firstSuggestion,
                    type: .spelling,
                    confidence: 0.9,
                    alternatives: Array(suggestions.prefix(5))
                )
            }
        }
        #elseif os(iOS)
        let checker = UITextChecker()
        let misspelledRange = checker.rangeOfMisspelledWord(
            in: word.text,
            range: range,
            startingAt: 0,
            wrap: false,
            language: language
        )

        if misspelledRange.location != NSNotFound {
            // Word is misspelled
            if let suggestions = checker.guesses(forWordRange: range, in: word.text, language: language),
               let firstSuggestion = suggestions.first {
                return Correction(
                    original: word.text,
                    replacement: firstSuggestion,
                    type: .spelling,
                    confidence: 0.9,
                    alternatives: Array(suggestions.prefix(5))
                )
            }
        }
        #endif

        return nil
    }

    private func correctWithAI(_ text: String, language: String) async -> [Correction]? {
        guard let provider = ProviderRegistry.shared.bestAvailableProvider else {
            return nil
        }

        let prompt = """
        Correct any grammar, spelling, or punctuation errors in the following \(languageName(for: language)) text.
        Return ONLY the corrected text, nothing else. If no corrections needed, return the original text exactly.

        Text: \(text)
        """

        do {
            let model = await DynamicConfig.shared.bestModel(for: .correction)
            let corrected = try await AIProviderHelpers.singleResponse(
                provider: provider,
                prompt: prompt,
                model: model,
                temperature: DynamicConfig.shared.temperature(for: .correction),
                maxTokens: DynamicConfig.shared.maxTokens(for: .correction, inputLength: text.count)
            )

            let trimmedCorrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedCorrected != text && !trimmedCorrected.isEmpty {
                return [Correction(
                    original: text,
                    replacement: trimmedCorrected,
                    type: .grammar,
                    confidence: 0.8,
                    alternatives: []
                )]
            }
        } catch {
            logger.warning("AI correction failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func shouldSkipCorrection(_ text: String) -> Bool {
        // Skip code blocks
        if text.contains("```") || text.contains("func ") || text.contains("let ") ||
           text.contains("var ") || text.contains("class ") || text.contains("struct ") {
            return true
        }

        // Skip URLs
        let urlPattern = #"https?://[^\s]+"#
        if text.range(of: urlPattern, options: .regularExpression) != nil {
            return true
        }

        // Skip email addresses
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if text.range(of: emailPattern, options: .regularExpression) != nil {
            return true
        }

        // Skip file paths
        if text.contains("/") && (text.hasPrefix("/") || text.hasPrefix("~/") || text.contains(".swift")) {
            return true
        }

        return false
    }

    private func languageName(for code: String) -> String {
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: code) ?? "Unknown"
    }

    // MARK: - Persistence

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "LiveAutoCorrect.isEnabled")
        liveMode = UserDefaults.standard.object(forKey: "LiveAutoCorrect.liveMode") as? Bool ?? true
        debounceInterval = UserDefaults.standard.object(forKey: "LiveAutoCorrect.debounceInterval") as? Int ?? 300
        showSuggestions = UserDefaults.standard.object(forKey: "LiveAutoCorrect.showSuggestions") as? Bool ?? true
    }

    private func loadUserDictionary() {
        let url = getUserDictionaryURL()
        if let data = try? Data(contentsOf: url),
           let words = try? JSONDecoder().decode(Set<String>.self, from: data) {
            userDictionary = words
            // Learn all words
            for word in words {
                #if os(macOS)
                spellChecker.learnWord(word)
                #elseif os(iOS)
                UITextChecker.learnWord(word)
                #endif
            }
        }
    }

    private func saveUserDictionary() {
        let url = getUserDictionaryURL()
        if let data = try? JSONEncoder().encode(userDictionary) {
            try? data.write(to: url)
        }
    }

    private func getUserDictionaryURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("Thea", isDirectory: true)
        try? FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        return theaDir.appendingPathComponent("user_dictionary.json")
    }
}

// MARK: - Models

public struct CorrectionResult: Sendable {
    public let original: String
    public let corrected: String
    public let corrections: [Correction]
    public var language: String = "en"
    public var confidence: Double = 0
    public var processingTime: TimeInterval = 0

    public var hasCorrections: Bool {
        !corrections.isEmpty
    }

    public var correctionCount: Int {
        corrections.count
    }
}

public struct Correction: Sendable, Identifiable {
    public let id = UUID()
    public let original: String
    public let replacement: String
    public let type: CorrectionType
    public let confidence: Double
    public let alternatives: [String]
}

public enum CorrectionType: String, Sendable, Codable {
    case spelling
    case grammar
    case punctuation
    case capitalization
    case whitespace
}

public struct AutoCorrectStats: Sendable {
    public var totalCorrections: Int = 0
    public var textsProcessed: Int = 0
    public var averageProcessingTime: TimeInterval = 0
    public var languagesDetected: [String: Int] = [:]
}

private struct WordToken {
    let text: String
    let range: Range<String.Index>?
}

// MARK: - SwiftUI View Modifier

import SwiftUI

public struct AutoCorrectModifier: ViewModifier {
    @Binding var text: String
    @State private var correctionResult: CorrectionResult?
    @State private var showSuggestions = false

    public func body(content: Content) -> some View {
        content
            .onChange(of: text) { _, newValue in
                if LiveAutoCorrect.shared.isEnabled && LiveAutoCorrect.shared.liveMode {
                    LiveAutoCorrect.shared.processLiveInput(newValue) { result in
                        Task { @MainActor in
                            correctionResult = result
                            if result.hasCorrections && LiveAutoCorrect.shared.showSuggestions {
                                showSuggestions = true
                            } else if !LiveAutoCorrect.shared.showSuggestions && result.hasCorrections {
                                // Auto-replace mode
                                text = result.corrected
                            }
                        }
                    }
                }
            }
            .popover(isPresented: $showSuggestions) {
                if let result = correctionResult {
                    AutoCorrectSuggestionView(result: result) { accepted in
                        if accepted {
                            text = result.corrected
                        }
                        showSuggestions = false
                    }
                }
            }
    }
}

public extension View {
    /// Enable AI-powered auto-correct for a text field
    func autoCorrect(text: Binding<String>) -> some View {
        modifier(AutoCorrectModifier(text: text))
    }
}

// MARK: - Suggestion View

struct AutoCorrectSuggestionView: View {
    let result: CorrectionResult
    let onAction: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.badge.checkmark")
                    .foregroundStyle(.blue)
                Text("Suggested Correction")
                    .font(.headline)
                Spacer()
                Text(result.language.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            ForEach(result.corrections) { correction in
                HStack {
                    Text(correction.original)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Text(correction.replacement)
                        .bold()
                        .foregroundStyle(.primary)
                }
                .font(.body)
            }

            Divider()

            HStack {
                Button("Ignore") {
                    onAction(false)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Accept") {
                    onAction(true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 280)
    }
}
