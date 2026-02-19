// MultiLanguageUtteranceBuilder.swift
// Handles multi-language text-to-speech by detecting language segments
// and creating properly configured utterances for each language
//
// AVSpeechSynthesizer limitation: Cannot mix languages in a single utterance
// Solution: Detect language segments and queue multiple utterances

import Foundation
import os.log
import AVFoundation
import NaturalLanguage

// MARK: - Language Segment

/// A segment of text with detected language
struct LanguageSegment: Identifiable, Sendable {
    let id: UUID
    let text: String
    let language: String  // BCP-47 code
    let confidence: Double
    let range: Range<String.Index>

    init(text: String, language: String, confidence: Double, range: Range<String.Index>) {
        self.id = UUID()
        self.text = text
        self.language = language
        self.confidence = confidence
        self.range = range
    }
}

// periphery:ignore - Reserved: LanguageSegment type reserved for future feature activation

// MARK: - Multi-Language Utterance Builder

/// Builds multiple utterances from text containing different languages
@MainActor
@Observable
final class MultiLanguageUtteranceBuilder {
    private let logger = Logger(subsystem: "ai.thea.app", category: "MultiLanguageUtteranceBuilder")
    static let shared = MultiLanguageUtteranceBuilder()

    // Voice preferences
    private(set) var preferredVoices: [String: AVSpeechSynthesisVoice] = [:]
    private(set) var useEnhancedVoices = true
    private(set) var usePremiumVoices = true

    // Statistics
    private(set) var totalUtterancesCreated: Int = 0
    private(set) var languagesUsed: Set<String> = []

    private init() {
        loadPreferredVoices()
    }

// periphery:ignore - Reserved: shared static property reserved for future feature activation

    // MARK: - Public API

    /// Build utterances from text, automatically detecting language segments
    func buildUtterances(from text: String) -> [AVSpeechUtterance] {
        let segments = detectLanguageSegments(text)
        return segments.map { segment in
            createUtterance(for: segment)
        }
    }

    /// Build utterances with explicit language hints
    func buildUtterances(from text: String, preferredLanguage: String) -> [AVSpeechUtterance] {
        let segments = detectLanguageSegments(text, defaultLanguage: preferredLanguage)
        return segments.map { segment in
            createUtterance(for: segment)
        }
    // periphery:ignore - Reserved: buildUtterances(from:) instance method reserved for future feature activation
    }

    /// Detect language segments in text
    func detectLanguageSegments(_ text: String, defaultLanguage: String = "en") -> [LanguageSegment] {
        let recognizer = NLLanguageRecognizer()
        var segments: [LanguageSegment] = []

        // periphery:ignore - Reserved: buildUtterances(from:preferredLanguage:) instance method reserved for future feature activation
        // First, try sentence-level detection
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text

        var currentLanguage: String?
        var currentStart: String.Index?
        var segmentText = ""

// periphery:ignore - Reserved: detectLanguageSegments(_:defaultLanguage:) instance method reserved for future feature activation

        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])

            // Detect language for this sentence
            recognizer.reset()
            recognizer.processString(sentence)

            let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
            let detectedLang = hypotheses.first?.key.rawValue ?? defaultLanguage
            let confidence = hypotheses.first?.value ?? 0.5

            if currentLanguage == nil {
                // First segment
                currentLanguage = detectedLang
                currentStart = range.lowerBound
                segmentText = sentence
            } else if detectedLang == currentLanguage {
                // Same language, extend segment
                segmentText += sentence
            } else {
                // Language change - finalize current segment
                if let start = currentStart, !segmentText.isEmpty {
                    let segmentRange = start..<range.lowerBound
                    segments.append(LanguageSegment(
                        text: segmentText.trimmingCharacters(in: .whitespacesAndNewlines),
                        language: currentLanguage!,
                        confidence: confidence,
                        range: segmentRange
                    ))
                }

                // Start new segment
                currentLanguage = detectedLang
                currentStart = range.lowerBound
                segmentText = sentence
            }

            return true
        }

        // Don't forget the last segment
        if let lang = currentLanguage, let start = currentStart, !segmentText.isEmpty {
            let segmentRange = start..<text.endIndex
            segments.append(LanguageSegment(
                text: segmentText.trimmingCharacters(in: .whitespacesAndNewlines),
                language: lang,
                confidence: 0.8,
                range: segmentRange
            ))
        }

        // If no segments detected, use the entire text as one segment
        if segments.isEmpty && !text.isEmpty {
            recognizer.reset()
            recognizer.processString(text)
            let lang = recognizer.dominantLanguage?.rawValue ?? defaultLanguage

            segments.append(LanguageSegment(
                text: text,
                language: lang,
                confidence: 0.5,
                range: text.startIndex..<text.endIndex
            ))
        }

        return segments
    }

    // MARK: - Utterance Creation

    /// Create an utterance for a language segment
    private func createUtterance(for segment: LanguageSegment) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: segment.text)

        // Get the best voice for this language
        if let voice = getBestVoice(for: segment.language) {
            utterance.voice = voice
        }

        // Apply default speech parameters
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // periphery:ignore - Reserved: createUtterance(for:) instance method reserved for future feature activation
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Add small pause between segments for natural speech
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        totalUtterancesCreated += 1
        languagesUsed.insert(segment.language)

        return utterance
    }

    /// Get the best available voice for a language
    func getBestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        // Check preferred voices first
        if let preferred = preferredVoices[language] {
            return preferred
        }

        // Get all voices for this language
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language) || language.hasPrefix($0.language.prefix(2))
        // periphery:ignore - Reserved: getBestVoice(for:) instance method reserved for future feature activation
        }

        // Sort by quality
        let sorted = voices.sorted { v1, v2 in
            qualityScore(v1) > qualityScore(v2)
        }

        // Return best available
        if usePremiumVoices, let premium = sorted.first(where: { $0.quality == .premium }) {
            return premium
        }
        if useEnhancedVoices, let enhanced = sorted.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }

        return sorted.first
    }

    private func qualityScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: 3
        case .enhanced: 2
        case .default: 1
        @unknown default: 0
        }
    }

// periphery:ignore - Reserved: qualityScore(_:) instance method reserved for future feature activation

    // MARK: - Voice Management

    /// Set preferred voice for a language
    func setPreferredVoice(_ voice: AVSpeechSynthesisVoice, for language: String) {
        preferredVoices[language] = voice
        savePreferredVoices()
    }

    /// Get available voices for a language
    func availableVoices(for language: String) -> [AVSpeechSynthesisVoice] {
        // periphery:ignore - Reserved: setPreferredVoice(_:for:) instance method reserved for future feature activation
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language) || language.hasPrefix($0.language.prefix(2))
        }.sorted { qualityScore($0) > qualityScore($1) }
    }

    // periphery:ignore - Reserved: availableVoices(for:) instance method reserved for future feature activation
    /// Get all available languages
    var availableLanguages: [String] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let languages = Set(voices.map { String($0.language.prefix(2)) })
        return languages.sorted()
    }

// periphery:ignore - Reserved: availableLanguages property reserved for future feature activation

    // MARK: - Configuration

    /// Enable/disable enhanced voices
    func setUseEnhancedVoices(_ enabled: Bool) {
        useEnhancedVoices = enabled
    }

    // periphery:ignore - Reserved: setUseEnhancedVoices(_:) instance method reserved for future feature activation
    /// Enable/disable premium voices
    func setUsePremiumVoices(_ enabled: Bool) {
        usePremiumVoices = enabled
    }

// periphery:ignore - Reserved: setUsePremiumVoices(_:) instance method reserved for future feature activation

    // MARK: - Persistence

    private func loadPreferredVoices() {
        guard let data = UserDefaults.standard.data(forKey: "preferredVoices") else { return }
        let identifiers: [String: String]
        do {
            identifiers = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            logger.error("MultiLanguageUtteranceBuilder: failed to decode preferred voices: \(error.localizedDescription)")
            return
        }
        for (language, identifier) in identifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                preferredVoices[language] = voice
            }
        }
    }

    private func savePreferredVoices() {
        let identifiers = preferredVoices.mapValues { $0.identifier }
        // periphery:ignore - Reserved: savePreferredVoices() instance method reserved for future feature activation
        do {
            let data = try JSONEncoder().encode(identifiers)
            UserDefaults.standard.set(data, forKey: "preferredVoices")
        } catch {
            logger.error("MultiLanguageUtteranceBuilder: failed to encode preferred voices: \(error.localizedDescription)")
        }
    }
}

// MARK: - Speech Manager Extension

/// Extension to integrate with existing speech synthesis
extension MultiLanguageUtteranceBuilder {
    /// Speak text with automatic language detection
    func speak(_ text: String, using synthesizer: AVSpeechSynthesizer) {
        // periphery:ignore - Reserved: speak(_:using:) instance method reserved for future feature activation
        let utterances = buildUtterances(from: text)
        for utterance in utterances {
            synthesizer.speak(utterance)
        }
    }

    /// Get language display name
    // periphery:ignore - Reserved: languageDisplayName(for:) instance method reserved for future feature activation
    func languageDisplayName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}
