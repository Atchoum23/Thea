// FocusModeIntelligence+Learning.swift
// THEA - Focus mode control, session summaries, follow-ups, voicemail, and activity awareness
// Split from original monolith; urgency assessment, VIP, analytics, prediction,
// and reliability have been moved to dedicated extension files.

import Foundation
import UserNotifications
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shortcuts, Summaries, Follow-Ups, Voicemail & Activity

extension FocusModeIntelligence {

    // MARK: - Public API for Shortcuts Integration

    /// Activate or deactivate a Focus Mode by name, typically called from Shortcuts automation.
    ///
    /// - Parameter modeName: The name of the Focus Mode to activate, or `nil` to deactivate.
    public func setActiveFocusMode(_ modeName: String?) async {
        if let name = modeName {
            // Find the mode by name
            if let mode = getAllFocusModes().first(where: { $0.name == name }) {
                var activeMode = mode
                activeMode.isActive = true
                setCurrentFocusModeValue(activeMode)
                await handleFocusModeActivated(activeMode)
                notifyFocusModeChanged(activeMode)
            }
        } else {
            // Focus mode deactivated
            if let previousMode = getCurrentFocusMode() {
                setCurrentFocusModeValue(nil)
                await handleFocusModeDeactivated(previousMode)
                notifyFocusModeChanged(nil)
            }
        }
    }

    /// Generate human-readable instructions for setting up Shortcuts automations.
    ///
    /// - Returns: A multi-line string with step-by-step Shortcuts setup instructions.
    public func generateShortcutsSetupInstructions() -> String {
        """
        # THEA Focus Mode Shortcuts Setup

        ## Required Shortcuts (THEA will help create these automatically)

        ### 1. "THEA Focus Activated" (Automation)
        **Trigger:** When ANY Focus mode turns ON
        **Actions:**
        1. Get name of Focus
        2. Open URL: thea://focus-activated?mode=[Focus Name]

        ### 2. "THEA Focus Deactivated" (Automation)
        **Trigger:** When ANY Focus mode turns OFF
        **Actions:**
        1. Open URL: thea://focus-deactivated

        ### 3. "THEA Call Forwarding" (Shortcut)
        **Input:** USSD code (e.g., *21*086#)
        **Actions:**
        1. Get text from Input
        2. Call [Input text]

        Note: This enables/disables call forwarding to COMBOX

        ### 4. "THEA Auto Reply" (Shortcut)
        **Input:** "phoneNumber|message"
        **Actions:**
        1. Split Input by "|"
        2. Send Message [Item 2] to [Item 1]

        ### 5. "THEA WhatsApp Reply" (Shortcut)
        **Input:** "phoneNumber|message"
        **Actions:**
        1. Split Input by "|"
        2. Open URL: whatsapp://send?phone=[Item 1]&text=[URL-encoded Item 2]
        3. Wait 1 second
        4. Tap "Send" (accessibility)

        ### 6. "THEA COMBOX Greeting" (Shortcut)
        **Input:** greeting type
        **Actions:**
        1. Call 086
        2. Wait for answer
        3. Play DTMF: 9 (settings menu)
        4. Wait 1 second
        5. Play DTMF: 1 (greeting settings)
        6. Wait 1 second
        7. If Input = "focus_mode": Play DTMF: 2
           Else: Play DTMF: 1

        ## Important Notes

        - Enable "Ask Before Running" = OFF for all automations
        - Grant necessary permissions to THEA app
        - Test each shortcut individually first

        ## Why Call Forwarding?

        When Focus Mode blocks calls, iOS **immediately rejects them** at the network level.
        The caller hears a 3-tone disconnect sound (like you hung up).
        They can't leave voicemail, and "call twice" won't work!

        **Solution:** Forward ALL calls to COMBOX when Focus is active.
        - Calls go to voicemail instead of being rejected
        - COMBOX plays a Focus-aware greeting
        - THEA sends SMS after voicemail with callback instructions
        """
    }

    // MARK: - Focus Session Summary

    /// Generate an end-of-Focus summary of everything that happened during the session.
    ///
    /// Includes message counts, missed calls, auto-replies sent, urgent contacts,
    /// and suggested follow-up actions.
    ///
    /// - Returns: A ``FocusSessionSummary`` with all session statistics and recommendations.
    public func generateFocusSessionSummary() async -> FocusSessionSummary {
        let duration = getCurrentSessionAnalytics().map {
            Date().timeIntervalSince($0.startTime)
        } ?? 0

        let allComms = getRecentCommunicationsInternal()

        let missedCalls = allComms.filter {
            $0.type == .missedCall && $0.focusModeWhenReceived != nil
        }

        let messages = allComms.filter {
            $0.type == .message && $0.focusModeWhenReceived != nil
        }

        let urgentContacts = getAllConversationStates().filter {
            $0.value.markedAsUrgent
        }.map { $0.key }

        let pendingResponses = getAllConversationStates().filter {
            $0.value.currentStage == .askedIfUrgent || $0.value.currentStage == .initial
        }.count

        return FocusSessionSummary(
            duration: duration,
            messagesReceived: messages.count,
            callsMissed: missedCalls.count,
            autoRepliesSent: getCurrentSessionAnalytics()?.autoRepliesSent ?? 0,
            urgentContacts: urgentContacts,
            pendingResponses: pendingResponses,
            topPriorityContacts: getTopPriorityContacts(from: messages),
            suggestedFollowUps: await generateFollowUpSuggestions()
        )
    }

    /// Summary of a completed Focus session.
    public struct FocusSessionSummary: Sendable {
        let duration: TimeInterval
        let messagesReceived: Int
        let callsMissed: Int
        let autoRepliesSent: Int
        let urgentContacts: [String]
        let pendingResponses: Int
        let topPriorityContacts: [String]
        let suggestedFollowUps: [ContactFollowUpSuggestion]
    }

    /// A suggested follow-up action for a contact after a Focus session ends.
    public struct ContactFollowUpSuggestion: Sendable {
        let contactId: String
        let reason: String
        let priority: Int // 1 = highest
        let suggestedAction: String
    }

    /// Extract the top priority contacts from a list of communications by message frequency.
    ///
    /// - Parameter communications: The list of incoming communications to analyze.
    /// - Returns: Up to 5 contact identifiers sorted by message count (descending).
    func getTopPriorityContacts(from communications: [IncomingCommunication]) -> [String] {
        var contactCounts: [String: Int] = [:]
        for comm in communications {
            if let cId = comm.contactId ?? comm.phoneNumber {
                contactCounts[cId, default: 0] += 1
            }
        }

        return contactCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    /// Generate follow-up suggestions based on urgency flags and message frequency.
    ///
    /// - Returns: An array of ``ContactFollowUpSuggestion`` sorted by priority (highest first).
    func generateFollowUpSuggestions() async -> [ContactFollowUpSuggestion] {
        var suggestions: [ContactFollowUpSuggestion] = []

        // Suggest following up with urgent contacts
        for (contactKey, state) in getAllConversationStates() where state.markedAsUrgent {
            suggestions.append(ContactFollowUpSuggestion(
                contactId: contactKey,
                reason: "Marked as urgent during Focus",
                priority: 1,
                suggestedAction: "Call back immediately"
            ))
        }

        // Suggest following up with high-frequency contacts
        for (contactKey, timestamps) in getAllMessageCountTracking() {
            if timestamps.count >= 3 {
                suggestions.append(ContactFollowUpSuggestion(
                    contactId: contactKey,
                    reason: "Sent \(timestamps.count) messages",
                    priority: 2,
                    suggestedAction: "Check their messages"
                ))
            }
        }

        return suggestions.sorted { $0.priority < $1.priority }
    }

    // MARK: - Swisscom COMBOX Visual Voicemail Integration

    /// Check COMBOX for new voicemails (requires Swisscom Visual Voicemail).
    ///
    /// Integrates with the iOS Visual Voicemail system or polls COMBOX status via DTMF commands.
    ///
    /// - Returns: An array of ``VoicemailInfo`` for each new voicemail found.
    public func checkComboxForNewVoicemails() async -> [VoicemailInfo] {
        // Swisscom Visual Voicemail pushes to device
        // We can monitor for these notifications

        // This would integrate with the iOS Visual Voicemail system
        // or poll COMBOX status via DTMF commands
        []
    }

    /// Information about a single voicemail message.
    public struct VoicemailInfo: Sendable {
        let callerNumber: String
        let callerName: String?
        let timestamp: Date
        let duration: TimeInterval
        let transcription: String? // If available
        let urgencyAssessment: UrgencyAssessment?
    }

    // MARK: - Health & Activity Awareness

    /// Adjust Focus Mode behavior based on the user's current physical activity.
    ///
    /// Modifies escalation thresholds, auto-reply delays, and other settings
    /// to match the user's context (sleeping, exercising, driving, etc.).
    ///
    /// - Parameter activity: The user's current ``UserActivity``.
    public func adjustForActivity(_ activity: UserActivity) {
        var settings = getGlobalSettings()
        switch activity {
        case .sleeping:
            // Only true emergencies should break through
            settings.escalationMessageThreshold = 5
        case .exercising:
            // Brief responses only
            settings.autoReplyDelay = 0 // Immediate
        case .driving:
            // Voice-only if needed
            break
        case .inMeeting:
            // Standard Focus behavior
            break
        case .available:
            // Disable auto-replies
            settings.autoReplyEnabled = false
        }
        setGlobalSettings(settings)
    }

    /// The user's current physical activity or availability state.
    public enum UserActivity: String, Sendable {
        case sleeping, exercising, driving, inMeeting, available
    }
}
