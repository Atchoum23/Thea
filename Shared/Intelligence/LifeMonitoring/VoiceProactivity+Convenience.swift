// VoiceProactivity+Convenience.swift
// THEA - Voice Proactivity Convenience Extensions
// Created by Claude - February 2026
//
// High-level convenience methods for common voice interactions:
// deadline notifications, incoming message alerts, and preference queries.

import Foundation
import AVFoundation

// MARK: - Speech Delegate Helper

/// Delegate that fires a completion closure when speech finishes.
///
/// Used internally by ``VoiceProactivity`` to bridge
/// `AVSpeechSynthesizerDelegate` callbacks into async/await.
class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}

// MARK: - Convenience Extensions

extension VoiceProactivity {

    /// Notify the user about an upcoming or overdue deadline.
    ///
    /// Formats the due date as a relative time string and queues
    /// a voice reminder with urgency-appropriate priority.
    /// - Parameters:
    ///   - title: The deadline title (e.g., "Tax filing").
    ///   - dueDate: When the deadline is due.
    ///   - urgency: The urgency level from ``DeadlineUrgency``.
    public func notifyDeadline(
        title: String,
        dueDate: Date,
        urgency: DeadlineUrgency
    ) async {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: dueDate, relativeTo: Date())

        let priority: VoiceInteractionPriority = switch urgency {
        case .overdue: .urgent
        case .critical: .urgent
        case .urgent: .high
        case .approaching: .normal
        default: .low
        }

        let message: String
        if urgency == .overdue {
            message = "Reminder: \(title) is overdue. It was due \(relative)."
        } else {
            message = "Reminder: \(title) is due \(relative)."
        }

        let interaction = VoiceInteraction(
            type: .reminder,
            priority: priority,
            message: message
        )

        await queueInteraction(interaction)
    }

    /// Notify the user about an incoming message.
    ///
    /// Reads the sender, platform, and a preview aloud, then listens
    /// for "reply" or "dismiss" keywords.
    /// - Parameters:
    ///   - sender: The sender's display name.
    ///   - platform: The messaging platform the message arrived on.
    ///   - preview: A short preview of the message content.
    public func notifyMessage(
        from sender: String,
        platform: MessagingPlatform,
        preview: String
    ) async {
        let message = "New \(platform.displayName) message from \(sender). They said: \(preview)"

        let interaction = VoiceInteraction(
            type: .notification,
            priority: .normal,
            message: message,
            expectedResponses: [
                VoiceInteraction.ExpectedResponse(keywords: ["reply", "respond", "answer"], action: "reply"),
                VoiceInteraction.ExpectedResponse(keywords: ["ignore", "later", "dismiss"], action: "dismiss")
            ]
        )

        await queueInteraction(interaction)
    }

    /// Ask the user to choose among named options via voice.
    ///
    /// - Parameters:
    ///   - question: The question to speak.
    ///   - options: Named options with keywords to match against spoken input.
    /// - Returns: The `name` of the matched option, or `nil` if no match.
    public func askPreference(
        question: String,
        options: [(name: String, keywords: [String])]
    ) async -> String? {
        let responses = options.map { option in
            VoiceInteraction.ExpectedResponse(
                keywords: option.keywords,
                action: option.name
            )
        }

        let response = await askQuestion(
            question,
            expectedResponses: responses,
            priority: .normal
        )

        return response?.matchedExpectation?.action
    }
}
