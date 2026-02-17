// FocusModeIntelligence+Communication.swift
// THEA - Incoming Call and Message Handling
// Split from FocusModeIntelligence.swift

import Foundation

// MARK: - Incoming Communication Handling

extension FocusModeIntelligence {

    // MARK: - Incoming Calls

    /// Handle an incoming call during Focus mode.
    ///
    /// Checks emergency contacts and allowed contacts first. For blocked calls,
    /// waits 30 seconds to determine if the call was missed, then optionally
    /// sends an SMS notification to the caller.
    ///
    /// - Parameters:
    ///   - phoneNumber: The caller's phone number, if available.
    ///   - contactId: The caller's contact identifier, if resolved.
    ///   - contactName: The caller's display name, if available.
    ///   - platform: The communication platform (e.g. cellular, FaceTime).
    public func handleIncomingCall(
        from phoneNumber: String?,
        contactId: String?,
        contactName: String?,
        platform: CommunicationPlatform
    ) async {
        guard getGlobalSettings().systemEnabled else { return }
        guard let mode = getCurrentFocusMode() else { return }

        // Check if emergency contact
        if let cId = contactId, isEmergencyContact(cId) {
            print("[FocusMode] Emergency contact calling - allowing through")
            return
        }

        // Check if allowed contact
        if let cId = contactId, mode.allowedContacts.contains(cId) {
            return
        }

        let communication = IncomingCommunication(
            id: UUID(),
            contactId: contactId,
            contactName: contactName,
            phoneNumber: phoneNumber,
            platform: platform,
            type: .call,
            timestamp: Date(),
            messageContent: nil,
            focusModeWhenReceived: mode.name,
            autoReplyStatus: .pending,
            urgencyLevel: .unknown,
            languageDetected: nil
        )

        appendRecentCommunication(communication)

        // Wait a moment to see if this becomes a missed call
        try? await Task.sleep(for: .seconds(30))

        // If still in our list as a call, it was likely declined/missed
        if let comm = findRecentCommunication(by: communication.id),
           comm.type == .call {
            var missedCall = comm
            missedCall.autoReplyStatus = .pending
            updateRecentCommunication(missedCall)

            // Send missed call notification
            let settings = getGlobalSettings()
            if settings.callerNotificationEnabled && settings.sendSMSAfterMissedCall {
                try? await Task.sleep(for: .seconds(settings.smsDelayAfterMissedCall))
                await sendMissedCallNotification(for: missedCall)
            }
        }
    }

    // MARK: - Incoming Messages

    /// Handle an incoming text message during Focus mode.
    ///
    /// Performs language detection, emergency keyword scanning, urgency analysis,
    /// and manages the conversation state machine (initial -> askedIfUrgent ->
    /// confirmedUrgent -> callInstructionsSent -> resolved).
    ///
    /// - Parameters:
    ///   - contactId: The sender's contact identifier, if resolved.
    ///   - contactName: The sender's display name, if available.
    ///   - phoneNumber: The sender's phone number, if available.
    ///   - platform: The communication platform (e.g. iMessage, WhatsApp).
    ///   - messageContent: The text content of the incoming message.
    public func handleIncomingMessage(
        from contactId: String?,
        contactName: String?,
        phoneNumber: String?,
        platform: CommunicationPlatform,
        messageContent: String
    ) async {
        guard getGlobalSettings().systemEnabled else { return }
        guard let mode = getCurrentFocusMode() else { return }

        // Check if emergency contact
        if let cId = contactId, isEmergencyContact(cId) {
            print("[FocusMode] Message from emergency contact")
        }

        // Check if allowed contact
        if let cId = contactId, mode.allowedContacts.contains(cId) {
            return
        }

        // Detect language
        let language = await detectLanguage(for: contactId, phoneNumber: phoneNumber, messageContent: messageContent)

        var communication = IncomingCommunication(
            id: UUID(),
            contactId: contactId,
            contactName: contactName,
            phoneNumber: phoneNumber,
            platform: platform,
            type: .message,
            timestamp: Date(),
            messageContent: messageContent,
            focusModeWhenReceived: mode.name,
            autoReplyStatus: .pending,
            urgencyLevel: .unknown,
            languageDetected: language
        )

        // Check for emergency keywords first
        if detectEmergency(in: messageContent, language: language) {
            communication.urgencyLevel = .emergency
            notifyEmergencyDetected(communication)
            await handleEmergencyMessage(communication)
            return
        }

        // Check for urgency keywords
        let urgency = detectUrgency(in: messageContent, language: language)
        communication.urgencyLevel = urgency

        appendRecentCommunication(communication)

        // Get or create conversation state
        let contactKey = contactId ?? phoneNumber ?? UUID().uuidString
        var state = getConversationState(for: contactKey) ?? ConversationState(
            contactId: contactKey,
            currentStage: .initial,
            autoRepliesSent: 0,
            lastMessageTime: Date(),
            awaitingUrgencyResponse: false,
            markedAsUrgent: false
        )

        // Process based on conversation state
        await processConversationState(
            &state,
            communication: &communication,
            contactKey: contactKey,
            platform: platform,
            messageContent: messageContent,
            language: language
        )

        state.lastMessageTime = Date()
        setConversationState(for: contactKey, state: state)
    }

    // MARK: - Conversation State Machine

    /// Process the current conversation state and advance to the next stage.
    ///
    /// - Parameters:
    ///   - state: The mutable conversation state for this contact.
    ///   - communication: The mutable incoming communication being processed.
    ///   - contactKey: The unique key identifying this contact.
    ///   - platform: The communication platform.
    ///   - messageContent: The raw text of the message.
    ///   - language: The detected language code for localized replies.
    private func processConversationState(
        _ state: inout ConversationState,
        communication: inout IncomingCommunication,
        contactKey: String,
        platform: CommunicationPlatform,
        messageContent: String,
        language: String
    ) async {
        switch state.currentStage {
        case .initial:
            if await shouldSendAutoReply(to: contactKey, platform: platform) {
                await sendInitialAutoReply(to: &communication, state: &state, language: language)
            }

        case .askedIfUrgent:
            if isAffirmativeResponse(messageContent, language: language) {
                state.markedAsUrgent = true
                state.currentStage = .confirmedUrgent
                communication.urgencyLevel = .urgent
                notifyUrgentDetected(communication)
                await sendUrgentCallInstructions(to: &communication, state: &state, language: language)
            } else if isNegativeResponse(messageContent, language: language) {
                state.currentStage = .resolved
            } else {
                // Ambiguous - treat as potentially urgent
                await sendUrgentCallInstructions(to: &communication, state: &state, language: language)
            }

        case .confirmedUrgent, .callInstructionsSent:
            // They've been told to call twice - no more auto-replies
            break

        case .resolved:
            if Date().timeIntervalSince(state.lastMessageTime) > getGlobalSettings().autoReplyWindow {
                state = ConversationState(
                    contactId: contactKey,
                    currentStage: .initial,
                    autoRepliesSent: 0,
                    lastMessageTime: Date(),
                    awaitingUrgencyResponse: false,
                    markedAsUrgent: false
                )
                if await shouldSendAutoReply(to: contactKey, platform: platform) {
                    await sendInitialAutoReply(to: &communication, state: &state, language: language)
                }
            }
        }
    }
}
