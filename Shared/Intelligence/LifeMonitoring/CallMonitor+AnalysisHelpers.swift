// CallMonitor+AnalysisHelpers.swift
// THEA - Voice Call Transcription & Intelligence
//
// Shared helper methods used by CallAnalysisEngine for date parsing,
// assignee inference, and context expansion.

import Foundation

// MARK: - Analysis Engine Helpers

extension CallAnalysisEngine {

    // MARK: - Date Extraction

    /// Attempts to extract a date from natural language context text.
    ///
    /// Supports relative references: "tomorrow", day names ("monday", "next friday"),
    /// and shorthand ("eod", "eow", "eom", "end of day/week/month").
    ///
    /// - Parameter text: The context string to parse.
    /// - Returns: A `Date` if a recognizable pattern was found, otherwise `nil`.
    func extractDateFromContext(_ text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // Tomorrow
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }

        // Day names
        let days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in days.enumerated() {
            if lowercased.contains("next \(day)") {
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = index + 1 - currentWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                daysToAdd += 7 // "next" means following week
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            } else if lowercased.contains(day) {
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = index + 1 - currentWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            }
        }

        // End of day/week/month
        if lowercased.contains("end of day") || lowercased.contains("eod") {
            return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)
        } else if lowercased.contains("end of week") || lowercased.contains("eow") {
            let weekday = calendar.component(.weekday, from: now)
            let daysToFriday = (6 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysToFriday, to: now)
        } else if lowercased.contains("end of month") || lowercased.contains("eom") {
            let range = calendar.range(of: .day, in: .month, for: now)!
            let daysInMonth = range.count
            let currentDay = calendar.component(.day, from: now)
            return calendar.date(byAdding: .day, value: daysInMonth - currentDay, to: now)
        }

        return nil
    }

    // MARK: - Date Parsing

    /// Parses a date string using common date formats, falling back to natural language extraction.
    ///
    /// Tried formats: "MMMM d, yyyy", "MMMM d", "MM/dd/yyyy".
    ///
    /// - Parameter text: The date string to parse.
    /// - Returns: A `Date` if parsing succeeded, otherwise `nil`.
    func parseDate(_ text: String) -> Date? {
        // Try various date formats
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "MMMM d, yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MMMM d"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM/dd/yyyy"
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return extractDateFromContext(text)
    }

    // MARK: - Assignee Inference

    /// Infers the assignee of an action item based on pronoun patterns and participant list.
    ///
    /// - "I will" / "I'll" maps to "Me"
    /// - "you need to" / "you should" / "can you" maps to the first non-local participant's name,
    ///   or "Other party" if no name is available.
    ///
    /// - Parameters:
    ///   - text: The matched action-item text.
    ///   - participants: The call's participant list for name lookup.
    /// - Returns: An assignee string, or `nil` if no assignment could be inferred.
    func extractAssignee(_ text: String, participants: [CallParticipant]) -> String? {
        let lowercased = text.lowercased()

        // Check for explicit assignment
        if lowercased.contains("i will") || lowercased.contains("i'll") {
            return "Me"
        }

        // Check for "you" patterns
        if lowercased.contains("you need to") || lowercased.contains("you should") || lowercased.contains("can you") {
            // Try to identify which participant
            for participant in participants where !participant.isLocalUser {
                if let name = participant.name {
                    return name
                }
            }
            return "Other party"
        }

        return nil
    }

    // MARK: - Context Expansion

    /// Expands the match range in both directions by a given number of characters
    /// to provide surrounding context for an extracted item.
    ///
    /// - Parameters:
    ///   - text: The full source text.
    ///   - range: The `NSRange` of the original match.
    ///   - chars: Number of characters to expand in each direction.
    /// - Returns: The expanded substring, trimmed of whitespace and newlines.
    func expandContext(_ text: String, range: NSRange, chars: Int) -> String {
        let nsText = text as NSString
        let start = max(0, range.location - chars)
        let end = min(nsText.length, range.location + range.length + chars)
        return nsText.substring(with: NSRange(location: start, length: end - start))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
