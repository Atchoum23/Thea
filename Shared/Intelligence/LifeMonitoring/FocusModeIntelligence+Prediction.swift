// FocusModeIntelligence+Prediction.swift
// THEA - Proactive Focus Mode prediction and smart auto-activation
// Split from FocusModeIntelligence+Learning.swift

import Foundation
import UserNotifications

// MARK: - Proactive Anticipation & Auto-Focus

extension FocusModeIntelligence {

    // MARK: - Types

    /// A prediction about whether Focus Mode should be activated.
    public struct FocusPrediction: Sendable {
        let shouldActivate: Bool
        let suggestedMode: String?
        let confidence: Double
        let signals: [PredictionSignal]
        let suggestedTime: Date?
    // periphery:ignore - Reserved: suggestedTime property reserved for future feature activation
    }

    /// A single signal contributing to a Focus Mode prediction.
    public struct PredictionSignal: Sendable {
        // periphery:ignore - Reserved: source property reserved for future feature activation
        let source: String
        let confidence: Double
        let suggestedMode: String?
        let suggestedTime: Date?
        let reason: String
    }

    // MARK: - Prediction

    /// Predict whether Focus Mode should be activated based on calendar, time, and location signals.
    ///
    /// Combines calendar events, time-of-day patterns, and location patterns to produce
    /// a confidence-scored prediction about Focus Mode activation.
    ///
    /// - Returns: A ``FocusPrediction`` if signals are present, or `nil` if prediction is disabled or no signals found.
    public func predictFocusModeActivation() async -> FocusPrediction? {
        guard getGlobalSettings().suggestFocusModeActivation else { return nil }

        var signals: [PredictionSignal] = []

        // Check calendar for upcoming events
        if let calendarSignal = await checkCalendarForFocusTriggers() {
            signals.append(calendarSignal)
        }

        // Check time patterns (e.g., always Focus at 9am on weekdays)
        if let timeSignal = checkTimePatterns() {
            signals.append(timeSignal)
        }

        // Check location patterns
        if let locationSignal = await checkLocationPatterns() {
            signals.append(locationSignal)
        }

        // Calculate overall prediction
        guard !signals.isEmpty else { return nil }

        let totalConfidence = signals.map { $0.confidence }.reduce(0, +) / Double(signals.count)
        let suggestedMode = determineBestFocusMode(from: signals)

        return FocusPrediction(
            shouldActivate: totalConfidence > 0.7,
            suggestedMode: suggestedMode,
            confidence: totalConfidence,
            signals: signals,
            suggestedTime: signals.compactMap { $0.suggestedTime }.min()
        )
    }

    // MARK: - Signal Checks

    /// Check the user's calendar for events starting in the next 15 minutes.
    ///
    /// Uses AppleScript on macOS to query Calendar.app for upcoming events.
    ///
    /// - Returns: A ``PredictionSignal`` if an upcoming event is found, or `nil`.
    func checkCalendarForFocusTriggers() async -> PredictionSignal? {
        #if os(macOS)
        // Check for meetings in the next 15 minutes
        let script = """
        tell application "Calendar"
            set currentDate to current date
            set futureDate to currentDate + (15 * minutes)
            set theCalendars to calendars
            repeat with cal in theCalendars
                set theEvents to (every event of cal whose start date \u{2265} currentDate and start date \u{2264} futureDate)
                if (count of theEvents) > 0 then
                    set theEvent to item 1 of theEvents
                    set eventStart to start date of theEvent
                    return (eventStart as string)
                end if
            end repeat
            return ""
        end tell
        """

        if let result = await runAppleScriptReturning(script), !result.isEmpty {
            return PredictionSignal(
                source: "calendar",
                confidence: 0.9,
                suggestedMode: "Work", // or detect from calendar type
                suggestedTime: Date(), // Parse result
                reason: "Upcoming calendar event"
            )
        }
        #endif

        return nil
    }

    /// Check time-of-day and day-of-week patterns for Focus Mode triggers.
    ///
    /// Suggests "Work" Focus at 9am on weekdays and "Sleep" Focus at 10pm.
    ///
    /// - Returns: A ``PredictionSignal`` if a time pattern matches, or `nil`.
    func checkTimePatterns() -> PredictionSignal? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let weekday = calendar.component(.weekday, from: Date())
        let isWeekday = weekday >= 2 && weekday <= 6

        // Example: Suggest Work Focus at 9am on weekdays
        if isWeekday && hour == 9 {
            return PredictionSignal(
                source: "time_pattern",
                confidence: 0.7,
                suggestedMode: "Work",
                suggestedTime: nil,
                reason: "Typical work start time"
            )
        }

        // Suggest Sleep Focus at 10pm
        if hour == 22 {
            return PredictionSignal(
                source: "time_pattern",
                confidence: 0.8,
                suggestedMode: "Sleep",
                suggestedTime: nil,
                reason: "Typical sleep time"
            )
        }

        return nil
    }

    /// Check location-based patterns for Focus Mode triggers.
    ///
    /// - Returns: A ``PredictionSignal`` if a location pattern matches, or `nil`.
    func checkLocationPatterns() async -> PredictionSignal? {
        // Would use CoreLocation
        nil
    }

    /// Select the best Focus Mode from a set of prediction signals.
    ///
    /// - Parameter signals: The prediction signals to evaluate.
    /// - Returns: The suggested Focus Mode name from the highest-confidence signal, or `nil`.
    func determineBestFocusMode(from signals: [PredictionSignal]) -> String? {
        // Return most confident suggestion
        signals.max { $0.confidence < $1.confidence }?.suggestedMode
    }

    // MARK: - Smart Auto-Focus Activation

    /// Automatically enable Focus Mode based on context when confidence is high enough.
    ///
    /// Checks prediction signals and, if confidence exceeds 85%, sends a user notification
    /// suggesting Focus Mode activation.
    public func checkAndAutoEnableFocus() async {
        guard getGlobalSettings().autoFocusOnCalendarEvents else { return }

        // Already in Focus?
        guard getCurrentFocusMode() == nil else { return }

        // Check prediction
        if let prediction = await predictFocusModeActivation(),
           prediction.shouldActivate,
           prediction.confidence > 0.85,
           let modeName = prediction.suggestedMode {

            print("[AutoFocus] High-confidence prediction to enable '\(modeName)' Focus")

            // Could auto-enable or just notify user
            let content = UNMutableNotificationContent()
            content.title = "\u{1F4A1} Focus Mode Suggestion"
            content.body = "Should I enable \(modeName) Focus? Reason: \(prediction.signals.first?.reason ?? "detected pattern")"
            content.sound = .default
            content.categoryIdentifier = "FOCUS_SUGGESTION"
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request) // Safe: notification scheduling failure is non-fatal; prediction continues
        }
    }
}
