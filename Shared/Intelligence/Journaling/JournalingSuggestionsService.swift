//
//  JournalingSuggestionsService.swift
//  Thea
//
//  AAF3-2: JournalingSuggestions framework integration (iOS 17.2+).
//  Surfaces curated life moments (photos, workouts, podcasts, music, locations)
//  without requiring individual HealthKit / Photos permissions — Apple curates them.
//
//  NOTE: JournalingSuggestions programmatic background access is not available.
//  Suggestions are surfaced via JournalingSuggestionsPicker (SwiftUI view).
//  This service manages state from picker callbacks and provides AI context.
//
//  Available on iOS only. macOS does not have the JournalingSuggestions framework.
//

#if os(iOS)
import Foundation
import JournalingSuggestions
import os.log

@available(iOS 17.2, *)
@MainActor
final class JournalingSuggestionsService: ObservableObject {
    static let shared = JournalingSuggestionsService()

    // MARK: - Published State

    @Published var recentSuggestions: [JournalingSuggestion] = []
    @Published var lastFetchDate: Date?

    // MARK: - Private

    private let logger = Logger(subsystem: "app.theathe", category: "JournalingSuggestionsService")

    private init() {
        logger.info("JournalingSuggestionsService initialized")
    }

    // MARK: - Picker Callback

    /// Called when the user selects a suggestion from JournalingSuggestionsPicker.
    /// Add a `JournalingSuggestionsPicker { suggestion in self.addSuggestion(suggestion) }` to your view.
    func addSuggestion(_ suggestion: JournalingSuggestion) {
        // Prepend most recent; cap at 20
        recentSuggestions.insert(suggestion, at: 0)
        if recentSuggestions.count > 20 { recentSuggestions.removeLast() }
        lastFetchDate = Date()
        logger.info("Added journaling suggestion — total: \(self.recentSuggestions.count)")
    }

    // MARK: - Context Summary

    /// Returns a prose summary of recent suggestions for AI context injection.
    func contextSummary() -> String {
        guard !recentSuggestions.isEmpty else {
            return "No recent journaling suggestions available."
        }
        let count = recentSuggestions.count
        let dateStr = lastFetchDate.map {
            DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short)
        } ?? "unknown"
        return "You have \(count) recent life moments available for reflection (last updated \(dateStr))."
    }

    // MARK: - Suggested Prompt

    /// Generates a reflective AI prompt based on the most recent suggestion.
    func suggestedReflectionPrompt() -> String? {
        guard let first = recentSuggestions.first else { return nil }
        // JournalingSuggestion.date is DateInterval? — use start date if available
        let date = first.date?.start ?? Date()
        let dateStr = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        return "I had a notable moment on \(dateStr). Help me reflect on it and what it might mean for my goals."
    }
}
#endif
