// VoiceProactivity+Interactions.swift
// THEA - Voice Interaction Queue and Delivery
// Created by Claude - February 2026
//
// Public API for queuing, delivering, and responding to voice interactions.
// Includes driving-mode helpers for hands-free messaging and notifications.

import Foundation
import UserNotifications

// MARK: - Public Interaction API

extension VoiceProactivity {

    /// Queue a voice interaction for delivery.
    ///
    /// The interaction is inserted into the priority-sorted pending queue
    /// and delivered as soon as the current context allows.
    /// - Parameter interaction: The interaction to queue.
    public func queueInteraction(_ interaction: VoiceInteraction) async {
        pendingInteractions.append(interaction)
        pendingInteractions.sort { $0.priority > $1.priority }

        await processPendingInteractions()
    }

    /// Speak a message immediately, bypassing the queue.
    ///
    /// - Parameters:
    ///   - message: The text to speak.
    ///   - priority: The priority level (defaults to `.urgent`).
    public func speakImmediate(
        _ message: String,
        priority: VoiceInteractionPriority = .urgent
    ) async {
        let interaction = VoiceInteraction(
            type: .alert,
            priority: priority,
            message: message
        )

        await deliverInteraction(interaction)
    }

    /// Ask a question and wait for the user's spoken response.
    ///
    /// - Parameters:
    ///   - question: The question to speak.
    ///   - expectedResponses: Keyword-action pairs to match against the response.
    ///   - priority: Delivery priority (defaults to `.normal`).
    ///   - timeout: How long to wait for a response, in seconds (defaults to 10).
    /// - Returns: The user's response, or `nil` if timed out.
    public func askQuestion(
        _ question: String,
        expectedResponses: [VoiceInteraction.ExpectedResponse],
        priority: VoiceInteractionPriority = .normal,
        timeout: TimeInterval = 10
    ) async -> VoiceResponse? {
        let interaction = VoiceInteraction(
            type: .question,
            priority: priority,
            message: question,
            expectedResponses: expectedResponses,
            expiresIn: timeout
        )

        await deliverInteraction(interaction)

        // Wait for response
        return await waitForResponse(interaction: interaction, timeout: timeout)
    }

    /// Send a message to a recipient via voice interface.
    ///
    /// Attempts direct delivery first, then Mac relay, and falls back
    /// to voice confirmation if neither is available.
    /// - Parameters:
    ///   - recipient: The recipient identifier.
    ///   - recipientName: Optional display name.
    ///   - message: The message body.
    ///   - platform: Target messaging platform.
    /// - Returns: `true` if the message was sent successfully.
    public func sendMessage(
        to recipient: String,
        recipientName: String?,
        message: String,
        platform: VoiceRelayPlatform
    ) async -> Bool {
        let relay = MessageRelay(
            platform: platform,
            recipient: recipient,
            recipientName: recipientName,
            message: message
        )

        // Try to send directly if possible
        if await canSendDirectly(platform: platform) {
            return await sendMessageDirectly(relay)
        }

        // Otherwise relay through Mac
        if configuration.macRelayEnabled {
            return await relayThroughMac(.sendMessage(relay))
        }

        // Confirm message via voice
        let name = recipientName ?? recipient
        await speakImmediate("I'll prepare a message to \(name) on \(platform.displayName). The message is: \(message). Would you like me to send it?")

        return false // Requires user confirmation
    }
}

// MARK: - Driving Mode Helpers

extension VoiceProactivity {

    /// Initiate a full conversation-style messaging flow.
    ///
    /// Walks the user through selecting a recipient, platform, composing
    /// the message, and confirming before sending. Designed for hands-free
    /// use while driving.
    public func startMessagingFlow() async {
        // Ask who to message
        let whoResponse = await askQuestion(
            "Who would you like to message?",
            expectedResponses: [],
            priority: .high,
            timeout: 15
        )

        guard let recipient = whoResponse?.transcription else {
            await speakImmediate("I didn't catch that. Let me know when you want to send a message.")
            return
        }

        // Ask what platform
        let platformResponse = await askQuestion(
            "Would you like to use iMessage, WhatsApp, or Telegram?",
            expectedResponses: [
                VoiceInteraction.ExpectedResponse(keywords: ["imessage", "message", "text"], action: "imessage"),
                VoiceInteraction.ExpectedResponse(keywords: ["whatsapp", "whats app"], action: "whatsapp"),
                VoiceInteraction.ExpectedResponse(keywords: ["telegram"], action: "telegram")
            ],
            priority: .high
        )

        let platform = determinePlatform(from: platformResponse)

        // Ask for the message
        let messageResponse = await askQuestion(
            "What would you like to say?",
            expectedResponses: [],
            priority: .high,
            timeout: 30
        )

        guard let message = messageResponse?.transcription else {
            await speakImmediate("I didn't catch the message. Let's try again later.")
            return
        }

        // Confirm and send
        let confirmResponse = await askQuestion(
            "I'll send '\(message)' to \(recipient) via \(platform.displayName). Should I send it?",
            expectedResponses: [
                VoiceInteraction.ExpectedResponse(keywords: ["yes", "yeah", "yep", "send", "confirm"], action: "send"),
                VoiceInteraction.ExpectedResponse(keywords: ["no", "nope", "cancel", "don't"], action: "cancel")
            ],
            priority: .high
        )

        if confirmResponse?.matchedExpectation?.action == "send" {
            let success = await sendMessage(to: recipient, recipientName: nil, message: message, platform: platform)
            if success {
                await speakImmediate("Message sent!")
            } else {
                await speakImmediate("I couldn't send that message. Please try again later.")
            }
        } else {
            await speakImmediate("Message cancelled.")
        }
    }

    /// Read recent notifications aloud from the notification center.
    ///
    /// - Parameter limit: Maximum number of notifications to read (defaults to 5).
    public func readNotifications(limit: Int = 5) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()

        guard !delivered.isEmpty else {
            await speakImmediate("You have no new notifications.")
            return
        }

        let recent = delivered.prefix(limit)
        await speakImmediate("You have \(delivered.count) notification\(delivered.count == 1 ? "" : "s"). Here are the most recent:")

        for notification in recent {
            let title = notification.request.content.title
            let body = notification.request.content.body
            let text = body.isEmpty ? title : "\(title): \(body)"
            await speakImmediate(text)
        }
    }

    /// Start navigation to a destination.
    ///
    /// Announces the navigation and optionally relays the command
    /// to the Mac for map display.
    /// - Parameter destination: The destination address or place name.
    public func startNavigation(to destination: String) async {
        await speakImmediate("Starting navigation to \(destination).")

        // Would integrate with Maps
        if configuration.macRelayEnabled {
            _ = await relayThroughMac(.navigate(to: destination))
        }
    }
}
