// IntelligentAutoComplete.swift
// Thea V2 - Intelligent Auto-Complete & Suggestions
//
// Provides context-aware, predictive text completion
// Learns from user patterns to improve suggestions

import Foundation
import OSLog

// MARK: - Intelligent Auto-Complete

/// Provides intelligent, context-aware auto-completion and suggestions
@MainActor
@Observable
public final class IntelligentAutoComplete {

    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "AutoComplete")

    // MARK: - State

    /// Current suggestions
    public private(set) var suggestions: [AutoCompleteSuggestion] = []

    /// Recently used phrases
    public private(set) var recentPhrases: [UsedPhrase] = []

    /// Learned user vocabulary
    public private(set) var userVocabulary: [VocabularyEntry] = []

    // MARK: - Configuration

    public var configuration = AutoCompleteConfiguration()

    // MARK: - Private State

    private var phrasePredictionModel = SimplePhraseModel()
    private var contextBuffer: [String] = []

    // MARK: - Initialization

    public init() {
        loadUserData()
    }

    // MARK: - Public API

    /// Get suggestions for current input
    public func getSuggestions(for input: String, context: CompletionContext) -> [AutoCompleteSuggestion] {
        guard !input.isEmpty || configuration.showSuggestionsOnEmpty else {
            return []
        }

        var allSuggestions: [AutoCompleteSuggestion] = []

        // 1. Phrase completions based on history
        let phraseCompletions = getPhraseCompletions(for: input)
        allSuggestions.append(contentsOf: phraseCompletions)

        // 2. Context-aware suggestions
        let contextualSuggestions = getContextualSuggestions(for: input, context: context)
        allSuggestions.append(contentsOf: contextualSuggestions)

        // 3. Template suggestions
        let templateSuggestions = getTemplateSuggestions(for: input, context: context)
        allSuggestions.append(contentsOf: templateSuggestions)

        // 4. Smart completions based on patterns
        let patternSuggestions = getPatternBasedSuggestions(for: input)
        allSuggestions.append(contentsOf: patternSuggestions)

        // Sort by relevance and deduplicate
        let sortedSuggestions = allSuggestions
            .sorted { $0.relevance > $1.relevance }
            .reduce(into: [AutoCompleteSuggestion]()) { result, suggestion in
                if !result.contains(where: { $0.text == suggestion.text }) {
                    result.append(suggestion)
                }
            }
            .prefix(configuration.maxSuggestions)

        suggestions = Array(sortedSuggestions)
        return suggestions
    }

    /// Record that a suggestion was accepted
    public func acceptSuggestion(_ suggestion: AutoCompleteSuggestion) {
        // Record usage
        recordPhrase(suggestion.text)

        // Update prediction model
        phrasePredictionModel.reinforce(suggestion.text)

        logger.debug("Suggestion accepted: \(suggestion.text.prefix(30))")
    }

    /// Record that user typed their own text (didn't accept suggestion)
    public func recordTypedText(_ text: String) {
        guard !text.isEmpty else { return }

        recordPhrase(text)

        // Add to vocabulary if it looks like a term
        if text.split(separator: " ").count <= 3 {
            addToVocabulary(text)
        }
    }

    /// Get quick action suggestions based on context
    public func getQuickActions(for context: CompletionContext) -> [AutoCompleteQuickAction] {
        var actions: [AutoCompleteQuickAction] = []

        // Time-based suggestions
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 8 && hour <= 10 {
            actions.append(AutoCompleteQuickAction(
                id: UUID(),
                title: "Morning Briefing",
                prompt: "Give me a summary of my priorities for today",
                icon: "sun.max"
            ))
        }

        if hour >= 17 && hour <= 19 {
            actions.append(AutoCompleteQuickAction(
                id: UUID(),
                title: "Day Wrap-up",
                prompt: "Summarize what I accomplished today",
                icon: "sunset"
            ))
        }

        // Context-based suggestions
        if context.recentTopics.contains("code") || context.currentApp.contains("Xcode") {
            actions.append(AutoCompleteQuickAction(
                id: UUID(),
                title: "Review Code",
                prompt: "Review my recent code changes",
                icon: "chevron.left.forwardslash.chevron.right"
            ))
        }

        if context.hasAttachments {
            actions.append(AutoCompleteQuickAction(
                id: UUID(),
                title: "Analyze Attachment",
                prompt: "Analyze the attached file",
                icon: "doc.text.magnifyingglass"
            ))
        }

        return actions
    }

    // MARK: - Private Methods

    private func getPhraseCompletions(for input: String) -> [AutoCompleteSuggestion] {
        let inputLower = input.lowercased()

        // Find matching phrases from history
        let matchingPhrases = recentPhrases.filter { phrase in
            phrase.text.lowercased().hasPrefix(inputLower)
        }

        return matchingPhrases.prefix(3).map { phrase in
            AutoCompleteSuggestion(
                id: UUID(),
                text: phrase.text,
                type: .phrase,
                relevance: min(1.0, Double(phrase.useCount) / 10.0),
                source: .history
            )
        }
    }

    private func getContextualSuggestions(for input: String, context: CompletionContext) -> [AutoCompleteSuggestion] {
        var suggestions: [AutoCompleteSuggestion] = []

        // App-specific suggestions
        if context.currentApp.contains("Xcode") || context.recentTopics.contains("Swift") {
            let codeSuggestions = [
                "Help me fix this Swift error",
                "Explain this Swift code",
                "Optimize this function for performance",
                "Add unit tests for this code"
            ]

            for text in codeSuggestions where text.lowercased().contains(input.lowercased()) {
                suggestions.append(AutoCompleteSuggestion(
                    id: UUID(),
                    text: text,
                    type: .contextual,
                    relevance: 0.8,
                    source: .contextual
                ))
            }
        }

        return suggestions
    }

    // periphery:ignore - Reserved: context parameter kept for API compatibility
    private func getTemplateSuggestions(for input: String, context: CompletionContext) -> [AutoCompleteSuggestion] {
        let templates = [
            "Explain [topic] in simple terms",
            "Compare [A] and [B]",
            "Write a [type] about [topic]",
            "Help me understand [concept]",
            "What are the pros and cons of [option]?",
            "Summarize [content]",
            "Generate ideas for [topic]"
        ]

        let inputLower = input.lowercased()

        return templates.compactMap { template in
            let templateStart = template.prefix { $0 != "[" }.lowercased()
            guard templateStart.hasPrefix(inputLower) || inputLower.isEmpty else { return nil }

            return AutoCompleteSuggestion(
                id: UUID(),
                text: template,
                type: .template,
                relevance: 0.6,
                source: .template
            )
        }
    }

    private func getPatternBasedSuggestions(for input: String) -> [AutoCompleteSuggestion] {
        // Use prediction model for next-phrase suggestions
        let predictions = phrasePredictionModel.predict(after: input)

        return predictions.map { prediction in
            AutoCompleteSuggestion(
                id: UUID(),
                text: prediction.text,
                type: .predicted,
                relevance: prediction.confidence,
                source: .learned
            )
        }
    }

    private func recordPhrase(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        if let index = recentPhrases.firstIndex(where: { $0.text == cleanText }) {
            recentPhrases[index].useCount += 1
            recentPhrases[index].lastUsed = Date()
        } else {
            let phrase = UsedPhrase(text: cleanText, useCount: 1, lastUsed: Date())
            recentPhrases.insert(phrase, at: 0)
        }

        // Limit size
        if recentPhrases.count > 500 {
            recentPhrases.removeLast()
        }

        saveUserData()
    }

    private func addToVocabulary(_ term: String) {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanTerm.isEmpty else { return }

        if let index = userVocabulary.firstIndex(where: { $0.term == cleanTerm }) {
            userVocabulary[index].frequency += 1
        } else {
            userVocabulary.append(VocabularyEntry(term: cleanTerm, frequency: 1, category: .general))
        }
    }

    private func loadUserData() {
        if let data = UserDefaults.standard.data(forKey: "AutoCompletePhrases") {
            do {
                recentPhrases = try JSONDecoder().decode([UsedPhrase].self, from: data)
            } catch {
                logger.error("Failed to decode auto-complete phrases: \(error.localizedDescription)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: "AutoCompleteVocabulary") {
            do {
                userVocabulary = try JSONDecoder().decode([VocabularyEntry].self, from: data)
            } catch {
                logger.error("Failed to decode auto-complete vocabulary: \(error.localizedDescription)")
            }
        }
    }

    private func saveUserData() {
        do {
            let encoded = try JSONEncoder().encode(recentPhrases)
            UserDefaults.standard.set(encoded, forKey: "AutoCompletePhrases")
        } catch {
            logger.error("Failed to encode auto-complete phrases: \(error.localizedDescription)")
        }
        do {
            let encoded = try JSONEncoder().encode(userVocabulary)
            UserDefaults.standard.set(encoded, forKey: "AutoCompleteVocabulary")
        } catch {
            logger.error("Failed to encode auto-complete vocabulary: \(error.localizedDescription)")
        }
    }
}

// MARK: - Simple Phrase Prediction Model

private class SimplePhraseModel {
    private var bigramCounts: [String: [String: Int]] = [:]
    private var unigramCounts: [String: Int] = [:]

    func reinforce(_ text: String) {
        let words = text.lowercased().split(separator: " ").map(String.init)

        for word in words {
            unigramCounts[word, default: 0] += 1
        }

        for i in 0..<(words.count - 1) {
            let current = words[i]
            let next = words[i + 1]
            bigramCounts[current, default: [:]][next, default: 0] += 1
        }
    }

    func predict(after text: String) -> [PhraseMatch] {
        let words = text.lowercased().split(separator: " ").map(String.init)
        guard let lastWord = words.last, let nextWords = bigramCounts[lastWord] else {
            return []
        }

        return nextWords.sorted { $0.value > $1.value }.prefix(3).map { word, wordCount in
            PhraseMatch(
                text: text + " " + word,
                confidence: min(1.0, Double(wordCount) / 10.0)
            )
        }
    }
}

// MARK: - Supporting Types

public struct AutoCompleteConfiguration: Sendable {
    public var enabled: Bool = true
    public var maxSuggestions: Int = 5
    public var showSuggestionsOnEmpty: Bool = true
    public var minCharactersToTrigger: Int = 1

    public init() {}
}

public struct AutoCompleteSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let type: SuggestionType
    public let relevance: Double
    public let source: SuggestionSource

    public enum SuggestionType: String, Sendable {
        case phrase
        case template
        case contextual
        case predicted
        case command
    }

    public enum SuggestionSource: String, Sendable {
        case history
        case template
        case contextual
        case learned
        case system
    }
}

public struct CompletionContext: Sendable {
    public let currentApp: String
    public let recentTopics: [String]
    public let hasAttachments: Bool
    public let conversationLength: Int

    public init(
        currentApp: String = "",
        recentTopics: [String] = [],
        hasAttachments: Bool = false,
        conversationLength: Int = 0
    ) {
        self.currentApp = currentApp
        self.recentTopics = recentTopics
        self.hasAttachments = hasAttachments
        self.conversationLength = conversationLength
    }
}

public struct UsedPhrase: Codable, Sendable {
    public var text: String
    public var useCount: Int
    public var lastUsed: Date
}

public struct VocabularyEntry: Codable, Sendable {
    public var term: String
    public var frequency: Int
    public var category: VocabularyCategory

    public enum VocabularyCategory: String, Codable, Sendable {
        case general
        case technical
        case domain
        case personal
    }
}

public struct AutoCompleteQuickAction: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let prompt: String
    public let icon: String
}

private struct PhraseMatch {
    let text: String
    let confidence: Double
}
