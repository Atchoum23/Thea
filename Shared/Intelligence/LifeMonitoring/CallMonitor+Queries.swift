// CallMonitor+Queries.swift
// THEA - Voice Call Transcription & Intelligence
//
// Query and search methods for call history, transcripts,
// action items, and commitments.

import Foundation

// MARK: - CallMonitor Query Methods

extension CallMonitor {

    // MARK: - Active Call Queries

    /// Returns all currently active (in-progress) calls.
    /// - Returns: An array of `CallRecord` values representing calls that have not yet ended.
    public func getActiveCalls() -> [CallRecord] {
        Array(activeCalls.values)
    }

    // MARK: - History Queries

    /// Returns the most recent calls from history.
    /// - Parameter limit: Maximum number of calls to return. Defaults to 100.
    /// - Returns: An array of `CallRecord` values, ordered oldest-to-newest, capped at `limit`.
    public func getCallHistory(limit: Int = 100) -> [CallRecord] {
        Array(callHistory.suffix(limit))
    }

    /// Returns all historical calls involving a specific contact.
    /// - Parameter identifier: The participant identifier to match (e.g., phone number, email, or contact ID).
    /// - Returns: An array of `CallRecord` values where at least one participant matches the identifier.
    public func getCalls(with identifier: String) -> [CallRecord] {
        callHistory.filter { call in
            call.participants.contains { $0.identifier == identifier }
        }
    }

    // MARK: - Transcript Search

    /// Searches all call transcripts for a given query string (case-insensitive).
    /// - Parameter query: The text to search for within transcript segments.
    /// - Returns: An array of tuples pairing each matching `CallRecord` with its matching `CallTranscriptSegment` values.
    public func searchTranscripts(query: String) -> [(CallRecord, [CallTranscriptSegment])] {
        let lowercasedQuery = query.lowercased()
        var results: [(CallRecord, [CallTranscriptSegment])] = []

        for call in callHistory {
            let matchingSegments = call.transcript.segments.filter {
                $0.text.lowercased().contains(lowercasedQuery)
            }
            if !matchingSegments.isEmpty {
                results.append((call, matchingSegments))
            }
        }

        return results
    }

    // MARK: - Action Items & Commitments

    /// Returns action items extracted from calls within the specified number of days.
    /// - Parameter days: The look-back window in days. Defaults to 7.
    /// - Returns: A flat array of `CallAnalysis.ActionItem` values from all matching calls.
    public func getRecentActionItems(days: Int = 7) -> [CallAnalysis.ActionItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return callHistory
            .filter { $0.startTime >= cutoff }
            .compactMap { $0.analysis?.actionItems }
            .flatMap { $0 }
    }

    /// Returns commitments extracted from calls within the specified number of days.
    /// - Parameter days: The look-back window in days. Defaults to 7.
    /// - Returns: A flat array of `CallAnalysis.Commitment` values from all matching calls.
    public func getRecentCommitments(days: Int = 7) -> [CallAnalysis.Commitment] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return callHistory
            .filter { $0.startTime >= cutoff }
            .compactMap { $0.analysis?.commitments }
            .flatMap { $0 }
    }
}
