// FocusModeIntelligence+SessionAnalytics.swift
// THEA - Focus session analytics, learning from outcomes, and user feedback
// Split from FocusModeIntelligence+Learning.swift

import Foundation

// MARK: - Session Analytics & Learning

extension FocusModeIntelligence {

    // MARK: - Types

    // Track how Focus sessions go and learn:
    // - Which contacts actually have urgent matters
    // - Optimal reply timing
    // - Which phrases indicate real urgency
    // - Adjust behavior based on feedback

    /// Analytics data collected during a single Focus session.
    struct FocusSessionAnalytics: Codable, Sendable {
        let sessionId: UUID
        let focusModeId: String
        let startTime: Date
        var endTime: Date?
        var messagesReceived: Int
        var callsReceived: Int
        var urgentMarked: Int
        var actuallyUrgent: Int // Based on user feedback
        var autoRepliesSent: Int
        var contactResponses: [String: ContactResponse] // Contact -> their response

        /// Tracks a single contact's response behavior during a Focus session.
        struct ContactResponse: Codable, Sendable {
            let contactId: String
            var messagesBeforeUrgent: Int
            var claimedUrgent: Bool
            var wasActuallyUrgent: Bool?
            var responseTime: TimeInterval?
        }
    }

    // MARK: - Session Lifecycle

    /// Start collecting analytics for a new Focus session.
    ///
    /// - Parameter mode: The ``FocusModeConfiguration`` being activated.
    func startSessionAnalytics(mode: FocusModeConfiguration) {
        // periphery:ignore - Reserved: startSessionAnalytics(mode:) instance method reserved for future feature activation
        setCurrentSessionAnalytics(FocusSessionAnalytics(
            sessionId: UUID(),
            focusModeId: mode.id,
            startTime: Date(),
            messagesReceived: 0,
            callsReceived: 0,
            urgentMarked: 0,
            actuallyUrgent: 0,
            autoRepliesSent: 0,
            contactResponses: [:]
        ))
    }

    /// Apply machine-learning analysis to the completed Focus session.
    ///
    /// Analyzes contact patterns, adjusts priorities, evaluates timing, and learns
    /// new urgency indicators based on the session data and user feedback.
    ///
    /// - Parameter mode: The ``FocusModeConfiguration`` that was active during the session.
    // periphery:ignore - Reserved: mode parameter kept for API compatibility
    func applyLearningFromSession(mode: FocusModeConfiguration) async {
        guard var analytics = getCurrentSessionAnalytics() else { return }

        analytics.endTime = Date()
        appendHistoricalAnalytics(analytics)

        // Analyze patterns
        if getGlobalSettings().trackResponsePatterns {
            await analyzeContactPatterns()
        }

        if getGlobalSettings().adjustPriorityFromFeedback {
            await adjustContactPriorities()
        }

        if getGlobalSettings().learnOptimalReplyTiming {
            await analyzeOptimalTiming()
        }

        if getGlobalSettings().learnUrgencyIndicators {
            await learnNewUrgencyPatterns()
        }

        // Save analytics
        await saveAnalytics()

        setCurrentSessionAnalytics(nil)
    }

    // MARK: - Pattern Analysis

    /// Analyze which contacts frequently claim urgency and adjust their priority scores.
    func analyzeContactPatterns() async {
        // Analyze which contacts frequently mark things as urgent
        // Adjust their priority scores accordingly

        var urgencyFrequency: [String: Double] = [:]

        for session in getHistoricalAnalytics() {
            for (contactId, response) in session.contactResponses {
                if response.claimedUrgent {
                    urgencyFrequency[contactId, default: 0] += 1
                }
            }
        }

        // Contacts who frequently claim urgency might need different handling
        for (contactId, frequency) in urgencyFrequency {
            if frequency > 5 {
                // This contact often has urgent matters
                let current = getContactPriority(contactId)
                setContactPriorityValue(contactId, priority: min(1.0, current + 0.1))
            }
        }
    }

    /// Adjust contact priorities based on whether "urgent" claims were actually urgent.
    func adjustContactPriorities() async {
        // Adjust based on whether "urgent" claims were actually urgent
        // This requires user feedback mechanism
    }

    /// Analyze when auto-replies are most effective (immediate vs. delayed).
    func analyzeOptimalTiming() async {
        // Analyze when auto-replies are most effective
        // e.g., immediate replies vs delayed replies
    }

    /// Discover new phrases that indicate urgency beyond the current keyword list.
    func learnNewUrgencyPatterns() async {
        // Look for new phrases that indicate urgency
        // that aren't in our current keyword list
    }

    /// Persist historical analytics to UserDefaults (app group).
    func saveAnalytics() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(getHistoricalAnalytics()) { // Safe: encode failure → analytics not persisted this cycle; in-memory state intact
            defaults.set(encoded, forKey: "focusModeAnalytics")
            defaults.synchronize()
        }
    }

    // MARK: - User Feedback

    /// Record user feedback on whether a contact's matter was actually urgent.
    ///
    /// Updates the current session analytics and adjusts the contact's priority score
    /// based on whether their urgency claim was justified.
    ///
    /// - Parameters:
    ///   - contactId: The contact identifier to provide feedback for.
    ///   - wasActuallyUrgent: `true` if the contact's matter was genuinely urgent.
    public func markUrgencyFeedback(contactId: String, wasActuallyUrgent: Bool) {
        guard var analytics = getCurrentSessionAnalytics(),
              var response = analytics.contactResponses[contactId] else { return }

        response.wasActuallyUrgent = wasActuallyUrgent
        analytics.contactResponses[contactId] = response

        if wasActuallyUrgent {
            analytics.actuallyUrgent += 1
        }

        setCurrentSessionAnalytics(analytics)

        // Adjust contact priority based on feedback
        if getGlobalSettings().adjustPriorityFromFeedback {
            let currentPriority = getContactPriority(contactId)

            if wasActuallyUrgent {
                // They were right, increase priority slightly
                setContactPriorityValue(contactId, priority: min(1.0, currentPriority + 0.05))
            } else {
                // They weren't urgent, decrease priority slightly
                setContactPriorityValue(contactId, priority: max(0.0, currentPriority - 0.02))
            }
        }
    }
}
