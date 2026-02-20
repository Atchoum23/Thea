//
//  JournalingSuggestionsService.swift
//  Thea
//
//  AAF3-2: JournalingSuggestions framework integration (iOS 17.2+).
//  Surfaces curated life moments (photos, workouts, podcasts, music, locations)
//  without requiring individual HealthKit / Photos permissions — Apple curates them.
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
    @Published var isAuthorized: Bool = false
    @Published var lastFetchDate: Date?

    // MARK: - Private

    private let logger = Logger(subsystem: "app.theathe", category: "JournalingSuggestionsService")

    private init() {
        logger.info("JournalingSuggestionsService initialized")
    }

    // MARK: - Fetch

    /// Fetches curated life-moment suggestions from the JournalingSuggestions framework.
    /// Combines recent suggestions across all asset types.
    func fetchSuggestions() async {
        do {
            var collected: [JournalingSuggestion] = []
            let fetcher = JournalingSuggestionsFetcher()
            for await suggestion in fetcher.suggestions {
                collected.append(suggestion)
                if collected.count >= 20 { break }
            }
            recentSuggestions = collected
            lastFetchDate = Date()
            isAuthorized = true
            logger.info("Fetched \(collected.count) journaling suggestions")
        } catch {
            logger.error("Failed to fetch journaling suggestions: \(error.localizedDescription)")
        }
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
        return "You have \(count) recent life moments available for reflection (fetched \(dateStr))."
    }

    // MARK: - Suggested Prompt

    /// Generates a reflective AI prompt based on the most recent suggestion.
    func suggestedReflectionPrompt() -> String? {
        guard let first = recentSuggestions.first else { return nil }
        let dateStr = DateFormatter.localizedString(from: first.date, dateStyle: .medium, timeStyle: .none)
        return "I had a notable moment on \(dateStr). Help me reflect on it and what it might mean for my goals."
    }
}

// MARK: - JournalingSuggestionsFetcher

/// Lightweight async fetcher that iterates the JournalingSuggestions API.
@available(iOS 17.2, *)
private struct JournalingSuggestionsFetcher {
    /// AsyncSequence of suggestions — collects at most the requested count.
    var suggestions: AsyncThrowingStream<JournalingSuggestion, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // JournalingSuggestions.Suggestion is the public API type
                    for try await item in JournalingSuggestion.suggestions {
                        continuation.yield(item)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
#endif
