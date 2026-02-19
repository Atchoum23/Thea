// FocusModeIntelligence+Learning.swift
// THEA - Urgency Assessment, VIP Mode, Learning, Reliability, Anticipation
// Split from FocusModeIntelligence.swift

import Foundation
import UserNotifications
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Learning, Analytics, Prediction & Advanced Features

extension FocusModeIntelligence {


    // MARK: - Public API for Shortcuts Integration

    /// Called when Focus mode changes via Shortcuts automation
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

    /// Generate Shortcuts automation instructions
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

    /// Generate end-of-Focus summary of what happened
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

    public struct FocusSessionSummary: Sendable {
        // periphery:ignore - Reserved: duration property — reserved for future feature activation
        let duration: TimeInterval
        // periphery:ignore - Reserved: messagesReceived property — reserved for future feature activation
        let messagesReceived: Int
        // periphery:ignore - Reserved: callsMissed property — reserved for future feature activation
        let callsMissed: Int
        // periphery:ignore - Reserved: autoRepliesSent property — reserved for future feature activation
        let autoRepliesSent: Int
        // periphery:ignore - Reserved: urgentContacts property — reserved for future feature activation
        let urgentContacts: [String]
        // periphery:ignore - Reserved: pendingResponses property — reserved for future feature activation
        let pendingResponses: Int
        // periphery:ignore - Reserved: topPriorityContacts property — reserved for future feature activation
        let topPriorityContacts: [String]
        // periphery:ignore - Reserved: suggestedFollowUps property — reserved for future feature activation
        let suggestedFollowUps: [ContactFollowUpSuggestion]
    }

    public struct ContactFollowUpSuggestion: Sendable {
        // periphery:ignore - Reserved: contactId property — reserved for future feature activation
        let contactId: String
        // periphery:ignore - Reserved: reason property — reserved for future feature activation
        let reason: String
        let priority: Int // 1 = highest
        // periphery:ignore - Reserved: suggestedAction property — reserved for future feature activation
        let suggestedAction: String
    }

// periphery:ignore - Reserved: duration property reserved for future feature activation

// periphery:ignore - Reserved: messagesReceived property reserved for future feature activation

// periphery:ignore - Reserved: callsMissed property reserved for future feature activation

// periphery:ignore - Reserved: autoRepliesSent property reserved for future feature activation

// periphery:ignore - Reserved: urgentContacts property reserved for future feature activation

// periphery:ignore - Reserved: pendingResponses property reserved for future feature activation

// periphery:ignore - Reserved: topPriorityContacts property reserved for future feature activation

// periphery:ignore - Reserved: suggestedFollowUps property reserved for future feature activation

    func getTopPriorityContacts(from communications: [IncomingCommunication]) -> [String] {
        var contactCounts: [String: Int] = [:]
        // periphery:ignore - Reserved: contactId property reserved for future feature activation
        // periphery:ignore - Reserved: reason property reserved for future feature activation
        for comm in communications {
            // periphery:ignore - Reserved: suggestedAction property reserved for future feature activation
            if let cId = comm.contactId ?? comm.phoneNumber {
                contactCounts[cId, default: 0] += 1
            }
        }

        return contactCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

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

    /// Check COMBOX for new voicemails (requires Swisscom Visual Voicemail)
    public func checkComboxForNewVoicemails() async -> [VoicemailInfo] {
        // Swisscom Visual Voicemail pushes to device
        // We can monitor for these notifications

        // This would integrate with the iOS Visual Voicemail system
        // or poll COMBOX status via DTMF commands
        []
    }

    public struct VoicemailInfo: Sendable {
        // periphery:ignore - Reserved: callerNumber property — reserved for future feature activation
        let callerNumber: String
        // periphery:ignore - Reserved: callerName property — reserved for future feature activation
        let callerName: String?
        // periphery:ignore - Reserved: timestamp property — reserved for future feature activation
        let timestamp: Date
        // periphery:ignore - Reserved: duration property — reserved for future feature activation
        let duration: TimeInterval
        // periphery:ignore - Reserved: transcription property — reserved for future feature activation
        let transcription: String? // If available
        // periphery:ignore - Reserved: callerNumber property reserved for future feature activation
        // periphery:ignore - Reserved: callerName property reserved for future feature activation
        // periphery:ignore - Reserved: timestamp property reserved for future feature activation
        // periphery:ignore - Reserved: duration property reserved for future feature activation
        // periphery:ignore - Reserved: transcription property reserved for future feature activation
        // periphery:ignore - Reserved: urgencyAssessment property reserved for future feature activation
        let urgencyAssessment: UrgencyAssessment?
    }

    // MARK: - Health & Activity Awareness

    /// Adjust behavior based on user's current activity
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

    public enum UserActivity: String, Sendable {
        case sleeping, exercising, driving, inMeeting, available
    }
}
