// FocusModeIntelligence+Escalation.swift
// THEA - Smart Contact Escalation, Calendar, Location, Voice Messages & Group Chats
// Split from FocusModeIntelligence+CallHandling.swift

import Foundation
import UserNotifications
#if canImport(Speech)
import Speech
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Escalation, Context-Aware Replies & Enhanced Communication

extension FocusModeIntelligence {

    // MARK: - Smart Contact Escalation (Enhancement 2)

    // If someone sends multiple messages in a short time, they're probably urgent.
    // Track message counts per contact and auto-escalate to urgent status.
    //
    // CONFIGURABLE:
    // - escalationMessageThreshold: Number of messages to trigger (default: 3)
    // - escalationTimeWindow: Time window in seconds (default: 300 = 5 min)
    // - escalationAutoReplyEnabled: Send auto-reply asking if truly urgent
    // - escalationNotifyUser: Whether to disturb user or handle silently
    //
    // BEHAVIOR:
    // When threshold is reached, THEA auto-replies asking if it's truly urgent.
    // If contact confirms, only then is user notified. This prevents unnecessary
    // interruptions from people who just send many messages but aren't urgent.

    /// Track an incoming message for potential escalation based on frequency.
    ///
    /// Maintains a sliding window of message timestamps per contact. When the
    /// threshold is reached, sends an inquiry asking if the matter is truly urgent.
    ///
    /// - Parameters:
    ///   - contactKey: The unique key identifying the contact.
    ///   - messageContent: The message text (used for confirmation checks).
    func trackMessageForEscalation(contactKey: String, messageContent: String) async {
        guard getGlobalSettings().smartEscalationEnabled else { return }

        var timestamps = getMessageCountTracking(for: contactKey)

        // Clean old timestamps outside the window
        let cutoff = Date().addingTimeInterval(-getGlobalSettings().escalationTimeWindow)
        timestamps = timestamps.filter { $0 > cutoff }

        // Add current timestamp
        timestamps.append(Date())
        setMessageCountTracking(for: contactKey, timestamps: timestamps)

        // Check if we've hit the threshold
        if timestamps.count >= getGlobalSettings().escalationMessageThreshold {
            if !getEscalationPending().contains(contactKey) {
                await handleEscalation(contactKey: contactKey, messageCount: timestamps.count)
            } else {
                await checkEscalationConfirmation(contactKey: contactKey, messageContent: messageContent)
            }
        }
    }

    /// Handle a contact that has exceeded the message frequency threshold.
    ///
    /// Sends a localized inquiry asking if the matter is truly urgent, rather than
    /// immediately notifying the user (to prevent unnecessary interruptions).
    ///
    /// - Parameters:
    ///   - contactKey: The unique key identifying the contact.
    ///   - messageCount: The number of messages received in the escalation window.
    func handleEscalation(contactKey: String, messageCount: Int) async {
        print("[Escalation] Contact \(contactKey) sent \(messageCount) messages in \(Int(getGlobalSettings().escalationTimeWindow))s window")

        addEscalationPending(contactKey)

        let language = await detectLanguage(for: contactKey, phoneNumber: contactKey, messageContent: nil)

        let escalationInquiry: [String: String] = [
            "en": "I noticed you've sent several messages. Is this urgent and needs my immediate attention? Reply YES if so, otherwise I'll get back to you when I'm available.",
            "de": "Ich habe bemerkt, dass du mehrere Nachrichten gesendet hast. Ist das dringend und braucht meine sofortige Aufmerksamkeit? Antworte JA falls ja, sonst melde ich mich, wenn ich verf\u{00FC}gbar bin.",
            "fr": "J'ai remarqu\u{00E9} que tu as envoy\u{00E9} plusieurs messages. Est-ce urgent et n\u{00E9}cessite mon attention imm\u{00E9}diate? R\u{00E9}ponds OUI si c'est le cas, sinon je te recontacte d\u{00E8}s que possible.",
            "it": "Ho notato che hai inviato diversi messaggi. \u{00C8} urgente e richiede la mia attenzione immediata? Rispondi S\u{00CC} se s\u{00EC}, altrimenti ti rispondo quando sar\u{00F2} disponibile."
        ]

        let message = escalationInquiry[language] ?? escalationInquiry["en"]!
        _ = await sendMessage(to: contactKey, message: message, platform: .sms)

        print("[Escalation] Sent inquiry to \(contactKey) - waiting for confirmation before notifying user")
    }

    /// Check if a pending escalation contact has confirmed or denied urgency.
    ///
    /// - Parameters:
    ///   - contactKey: The unique key identifying the contact.
    ///   - messageContent: The response message to analyze.
    func checkEscalationConfirmation(contactKey: String, messageContent: String) async {
        let language = await detectLanguage(for: contactKey, phoneNumber: contactKey, messageContent: messageContent)

        if isAffirmativeResponse(messageContent, language: language) {
            removeEscalationPending(contactKey)

            if var state = getConversationState(for: contactKey) {
                state.markedAsUrgent = true
                state.currentStage = .confirmedUrgent
                setConversationState(for: contactKey, state: state)
            }

            if getGlobalSettings().escalationNotifyUser {
                await notifyUserOfUrgentContact(contactKey: contactKey)
            }

            let template = getMessageTemplates().autoReply[language] ?? getMessageTemplates().autoReply["en"]!
            _ = await sendMessage(to: contactKey, message: template.urgentConfirmed, platform: .sms)

            print("[Escalation] Contact \(contactKey) confirmed urgency - user notified")
        } else if isNegativeResponse(messageContent, language: language) {
            removeEscalationPending(contactKey)

            let notUrgentReply: [String: String] = [
                "en": "No problem! I'll get back to you when I'm available. Thanks for understanding.",
                "de": "Kein Problem! Ich melde mich, wenn ich verf\u{00FC}gbar bin. Danke f\u{00FC}r dein Verst\u{00E4}ndnis.",
                "fr": "Pas de probl\u{00E8}me! Je te recontacte d\u{00E8}s que possible. Merci de ta compr\u{00E9}hension.",
                "it": "Nessun problema! Ti rispondo quando sar\u{00F2} disponibile. Grazie per la comprensione."
            ]

            let message = notUrgentReply[language] ?? notUrgentReply["en"]!
            _ = await sendMessage(to: contactKey, message: message, platform: .sms)

            print("[Escalation] Contact \(contactKey) confirmed NOT urgent - no user notification")
        }
    }

    /// Send a local notification to the user about an urgent contact.
    ///
    /// - Parameter contactKey: The unique key identifying the urgent contact.
    func notifyUserOfUrgentContact(contactKey: String) async {
        let content = UNMutableNotificationContent()
        content.title = "\u{26A0}\u{FE0F} Urgent Message"
        content.body = "Contact \(contactKey) has confirmed this is urgent."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request) // Safe: notification delivery failure is non-fatal; focus mode continues

        print("[Escalation] User notified about urgent contact: \(contactKey)")
    }

    // MARK: - Calendar-Aware Auto-Replies (Enhancement 3 - PRIVACY-FOCUSED)

    // PRIVACY: Never share meeting details or calendar info!
    // Only share when user will be available again - no meeting titles or details.

    /// Get a privacy-safe calendar-aware message showing only availability time.
    ///
    /// PRIVACY: Only reveals when the user will be available, never what the event is.
    ///
    /// - Parameter language: The BCP-47 language code for localization.
    /// - Returns: A localized availability message, or `nil` if unavailable.
    func getCalendarAwareMessage(language: String) async -> String? {
        guard getGlobalSettings().calendarAwareRepliesEnabled else { return nil }

        #if os(macOS)
        let script = """
        tell application "Calendar"
            set currentDate to current date
            set theCalendars to calendars
            repeat with cal in theCalendars
                set theEvents to (every event of cal whose start date \u{2264} currentDate and end date \u{2265} currentDate)
                if (count of theEvents) > 0 then
                    set theEvent to item 1 of theEvents
                    set eventEnd to end date of theEvent
                    -- Only return end time, NOT the event title (privacy)
                    return (eventEnd as string)
                end if
            end repeat
            return ""
        end tell
        """

        if let result = await runAppleScriptReturning(script), !result.isEmpty {
            let messages: [String: String] = [
                "en": "I should be available after \(result).",
                "de": "Ich sollte nach \(result) verf\u{00FC}gbar sein.",
                "fr": "Je devrais \u{00EA}tre disponible apr\u{00E8}s \(result).",
                "it": "Dovrei essere disponibile dopo \(result)."
            ]

            return messages[language] ?? messages["en"]
        }
        #endif

        return nil
    }

    /// Find the next available time slot (privacy-safe: time only, no event details).
    ///
    /// - Parameter language: The BCP-47 language code for localization.
    /// - Returns: A localized next-available message, or `nil`.
    func getNextAvailableSlot(language: String) async -> String? {
        guard getGlobalSettings().includeNextAvailableSlot else { return nil }

        #if os(macOS)
        return nil
        #else
        return nil
        #endif
    }

    // MARK: - Location-Based Behavior (Enhancement 4 - PRIVACY-FOCUSED)

    // PRIVACY: Never reveal location to contacts!
    // Location is used internally to adjust THEA's behavior, but never shared.

    /// Get the current location-based behavior configuration.
    ///
    /// - Returns: A `LocationFocusBehavior`, or `nil` if location awareness is disabled.
    func getCurrentLocationBehavior() async -> LocationFocusBehavior? {
        guard getGlobalSettings().locationAwareBehaviorEnabled else { return nil }
        return nil
    }

    /// Get a location-aware message for the contact.
    ///
    /// PRIVACY: Always returns `nil` -- location is NEVER shared with contacts.
    func getLocationAwareMessage(language: String) async -> String? {
        nil
    }

    /// Calculate the response delay adjusted for the user's current location.
    ///
    /// Location affects internal timing but is never revealed to contacts.
    ///
    /// - Returns: The appropriate response delay in seconds.
    func getLocationBasedResponseDelay() async -> TimeInterval {
        guard let _ = await getCurrentLocationBehavior() else {
            return getGlobalSettings().autoReplyDelay
        }
        return getGlobalSettings().autoReplyDelay
    }

    // MARK: - Voice Message Support (Enhancement 5)

    /// Handle an incoming voice message by transcribing and processing it.
    ///
    /// Transcribes the audio using Speech framework, then routes the transcription
    /// through the standard message handling pipeline with a "[Voice message]" prefix.
    ///
    /// - Parameters:
    ///   - contactId: The sender's contact identifier, if resolved.
    ///   - phoneNumber: The sender's phone number, if available.
    ///   - platform: The communication platform.
    ///   - audioURL: The local URL of the voice message audio file.
    public func handleIncomingVoiceMessage(
        from contactId: String?,
        phoneNumber: String?,
        platform: CommunicationPlatform,
        audioURL: URL
    ) async {
        guard getGlobalSettings().voiceMessageAnalysisEnabled else { return }
        guard getCurrentFocusMode() != nil else { return }

        var transcription: String?

        if getGlobalSettings().transcribeVoiceMessages {
            transcription = await transcribeVoiceMessage(audioURL: audioURL)
        }

        if let text = transcription {
            await handleIncomingMessage(
                from: contactId,
                contactName: nil,
                phoneNumber: phoneNumber,
                platform: platform,
                messageContent: "[Voice message]: \(text)"
            )
        }
    }

    /// Transcribe a voice message audio file using the Speech framework.
    ///
    /// - Parameter audioURL: The local URL of the audio file to transcribe.
    /// - Returns: The transcribed text, or `nil` if transcription failed.
    func transcribeVoiceMessage(audioURL: URL) async -> String? {
        #if os(macOS) || os(iOS)
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("[VoiceMessage] Audio file not found: \(audioURL)")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let recognizer = SFSpeechRecognizer()
            guard let recognizer, recognizer.isAvailable else {
                print("[VoiceMessage] Speech recognizer unavailable")
                continuation.resume(returning: nil)
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    print("[VoiceMessage] Transcription error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
        #else
        return nil
        #endif
    }

    // MARK: - Group Chat Handling (Enhancement 6)

    // Different handling for group chats:
    // - Don't spam the group with auto-replies
    // - Only respond to direct mentions
    // - Track group activity separately

    /// Handle an incoming group chat message with mention-aware auto-reply.
    ///
    /// Only responds to direct mentions (not all group messages), and respects
    /// a per-group reply limit to avoid spamming.
    ///
    /// - Parameters:
    ///   - groupId: The unique identifier of the group chat.
    ///   - groupName: The display name of the group, if available.
    ///   - contactId: The sender's contact identifier, if resolved.
    ///   - platform: The communication platform.
    ///   - messageContent: The message text.
    ///   - isMention: Whether the user was directly mentioned/tagged.
    public func handleIncomingGroupMessage(
        groupId: String,
        groupName: String?,
        from contactId: String?,
        platform: CommunicationPlatform,
        messageContent: String,
        isMention: Bool
    ) async {
        guard getGlobalSettings().groupChatHandlingEnabled else { return }
        guard getCurrentFocusMode() != nil else { return }

        if getGlobalSettings().silenceGroupChats {
            if getGlobalSettings().onlyRespondToDirectMentions && !isMention {
                return
            }
        }

        let replyCount = getGroupChatAutoReplyCount(for: groupId)
        if replyCount >= getGlobalSettings().groupChatMaxReplies {
            return
        }

        if getGlobalSettings().groupChatAutoReplyEnabled {
            let language = await detectLanguage(for: contactId, phoneNumber: nil, messageContent: messageContent)
            let template = getMessageTemplates().autoReply[language] ?? getMessageTemplates().autoReply["en"]!

            let groupMessage = """
            [Auto-reply] \(template.initialMessage)
            (This is an automated response - I'll catch up with the group when available)
            """

            if isMention {
                await sendGroupMessage(groupId: groupId, message: groupMessage, platform: platform)
                setGroupChatAutoReplyCount(for: groupId, count: replyCount + 1)
            }
        }
    }

    /// Send a message to a group chat.
    ///
    /// - Parameters:
    ///   - groupId: The unique identifier of the group chat.
    ///   - message: The message text to send.
    ///   - platform: The communication platform.
    func sendGroupMessage(groupId: String, message: String, platform: CommunicationPlatform) async {
        print("[GroupChat] Would send to group \(groupId): \(message)")
    }
}
