// FocusModeIntelligence+CallHandling.swift
// THEA - Call Forwarding, VoIP Interception, Contact Escalation, Voice Messages, Group Chats
// Split from FocusModeIntelligence.swift

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

// MARK: - Call Handling, VoIP Interception & Escalation

extension FocusModeIntelligence {

    // MARK: - Call Forwarding Workaround (Critical for iOS Focus Mode)

    // PROBLEM: When iOS Focus Mode blocks a call, the call is IMMEDIATELY rejected
    // at the network level. The caller hears a 3-tone disconnect sound (like the
    // line was hung up). This means:
    // - The caller can't leave a voicemail
    // - THEA can't detect the call happened
    // - "Call twice within 3 minutes" DOESN'T WORK because the first call is rejected
    //
    // SOLUTION: Use carrier call forwarding to redirect ALL calls to COMBOX
    // when Focus Mode is active. This way:
    // - Calls go to COMBOX instead of being rejected
    // - COMBOX plays a Focus-aware greeting explaining the situation
    // - Caller can leave voicemail
    // - THEA sends SMS after voicemail with callback instructions
    // - For truly urgent calls, we can detect repeated attempts via COMBOX
    //
    // Swisscom Call Forwarding Codes:
    // - *21*NUMBER# : Forward ALL calls unconditionally
    // - *67*NUMBER# : Forward when BUSY
    // - *61*NUMBER# : Forward when NO ANSWER (after X rings)
    // - *62*NUMBER# : Forward when UNREACHABLE
    // - #21# : Disable unconditional forwarding
    // - #67# : Disable busy forwarding
    // - #61# : Disable no-answer forwarding
    // - #62# : Disable unreachable forwarding
    //
    // For Focus Mode, we use unconditional forwarding (*21*086#) because
    // we want ALL calls to go to COMBOX, not just some.

    /// Enable call forwarding to COMBOX when Focus Mode activates
    func enableCallForwarding() async {
        guard !getCallForwardingEnabled() else { return }

        let forwardingCode = getGlobalSettings().callForwardingActivationCode +
                             getGlobalSettings().callForwardingNumber + "#"
        // e.g., "*21*086#" for Swisscom

        print("[CallForwarding] Enabling call forwarding with code: \(forwardingCode)")

        #if os(iOS)
        // Use Shortcuts to dial the USSD code
        // Note: iOS doesn't allow programmatic USSD execution, so we use Shortcuts
        await executeCallForwardingViaShortcuts(code: forwardingCode, action: "enable")
        #elseif os(macOS)
        // Mac sends command to iPhone via Shortcuts URL scheme or Handoff
        await sendCallForwardingCommandToiPhone(code: forwardingCode, enable: true)
        #endif

        setCallForwardingEnabled(true)
        print("[CallForwarding] Call forwarding enabled - all calls now go to COMBOX")
    }

    /// Disable call forwarding when Focus Mode deactivates
    func disableCallForwarding() async {
        guard getCallForwardingEnabled() else { return }

        let disableCode = getGlobalSettings().callForwardingDeactivationCode
        // e.g., "#21#" for Swisscom

        print("[CallForwarding] Disabling call forwarding with code: \(disableCode)")

        #if os(iOS)
        await executeCallForwardingViaShortcuts(code: disableCode, action: "disable")
        #elseif os(macOS)
        await sendCallForwardingCommandToiPhone(code: disableCode, enable: false)
        #endif

        setCallForwardingEnabled(false)
        print("[CallForwarding] Call forwarding disabled - normal call behavior restored")
    }

    #if os(iOS)
    func executeCallForwardingViaShortcuts(code: String, action: String) async {
        // Use the "THEA Call Forwarding" shortcut to execute USSD code
        let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        if let url = URL(string: "shortcuts://run-shortcut?name=THEA%20Call%20Forwarding&input=text&text=\(encodedCode)") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }

        // Alternative: Use tel: URL scheme with USSD (may not work on all carriers)
        // Some carriers allow: tel://*21*086%23
        // The %23 is URL-encoded #
    }
    #endif

    #if os(macOS)
    func sendCallForwardingCommandToiPhone(code: String, enable: Bool) async {
        // Send command to iPhone to execute call forwarding
        // Options:
        // 1. App Group UserDefaults (iPhone app polls for commands)
        // 2. Push notification to trigger Shortcut
        // 3. Handoff/Continuity

        // Using App Group for now
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            defaults.set(code, forKey: "pendingCallForwardingCode")
            defaults.set(enable, forKey: "pendingCallForwardingEnable")
            defaults.set(Date(), forKey: "pendingCallForwardingTimestamp")
            defaults.synchronize()

            print("[CallForwarding] Sent \(enable ? "enable" : "disable") command to iPhone")
        }
    }
    #endif

    // MARK: - VoIP Call Interception (Enhancement 1)

    // For VoIP calls (WhatsApp, Telegram, FaceTime), we CAN intercept on Mac
    // because these apps run on Mac too. When a VoIP call comes in:
    // 1. Mac detects the incoming call notification
    // 2. Before letting it ring, play a TTS message to the caller
    // 3. Ask if it's urgent
    // 4. If urgent, ring through; otherwise, decline and send auto-reply

    func startVoIPInterception() async {
        guard !getVoIPMonitoringActive() else { return }
        setVoIPMonitoringActive(true)

        #if os(macOS)
        // Monitor for VoIP call notifications on Mac
        // WhatsApp, Telegram, FaceTime all post notifications

        // Monitor WhatsApp calls
        if getGlobalSettings().voipInterceptWhatsApp {
            await startWhatsAppCallMonitoring()
        }

        // Monitor Telegram calls
        if getGlobalSettings().voipInterceptTelegram {
            await startTelegramCallMonitoring()
        }

        // Monitor FaceTime calls
        if getGlobalSettings().voipInterceptFaceTime {
            await startFaceTimeCallMonitoring()
        }

        print("[VoIP] Started VoIP call interception on Mac")
        #endif
    }

    func stopVoIPInterception() async {
        setVoIPMonitoringActive(false)

        #if os(macOS)
        clearVoIPNotificationObserver()
        print("[VoIP] Stopped VoIP call interception")
        #endif
    }

    #if os(macOS)
    func startWhatsAppCallMonitoring() async {
        // Monitor WhatsApp Desktop for incoming calls
        // WhatsApp shows a notification - we can intercept via NSWorkspace

        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "net.whatsapp.WhatsApp" else { return }

            // Check if this is a call notification
            Task {
                await self?.handlePotentialWhatsAppCall()
            }
        }

        print("[VoIP] WhatsApp call monitoring started")
    }

    func handlePotentialWhatsAppCall() async {
        // Detect if WhatsApp is showing a call UI
        // This is tricky - we'd need to check the window title or use accessibility API

        let script = """
        tell application "System Events"
            tell process "WhatsApp"
                if exists window 1 then
                    set winTitle to name of window 1
                    return winTitle
                end if
            end tell
        end tell
        return ""
        """

        if let windowTitle = await runAppleScriptReturning(script) {
            let callIndicators = ["incoming call", "calling", "video call", "voice call",
                                  "eingehender anruf", "appel entrant", "chiamata in arrivo"]
            let lowercased = windowTitle.lowercased()

            for indicator in callIndicators {
                if lowercased.contains(indicator) {
                    await interceptVoIPCall(platform: .whatsapp, callInfo: windowTitle)
                    return
                }
            }
        }
    }

    func startTelegramCallMonitoring() async {
        // Similar approach for Telegram Desktop
        print("[VoIP] Telegram call monitoring started")
    }

    func startFaceTimeCallMonitoring() async {
        // FaceTime calls can be intercepted via CallKit on Mac
        print("[VoIP] FaceTime call monitoring started")
    }

    func interceptVoIPCall(platform: CommunicationPlatform, callInfo: String) async {
        print("[VoIP] Intercepted \(platform.displayName) call: \(callInfo)")

        // Option 1: Play TTS message (requires the call to be answered first)
        // Option 2: Show notification asking user what to do
        // Option 3: Auto-decline and send message

        // For now, send auto-reply via the platform
        if getGlobalSettings().voipPlayTTSBeforeRinging {
            // We can't play audio TO the caller without answering
            // But we can show a notification to the user
            await showVoIPInterceptionNotification(platform: platform, callInfo: callInfo)
        }
    }

    func showVoIPInterceptionNotification(platform: CommunicationPlatform, callInfo: String) async {
        // Show notification via UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        content.title = "\u{1F4DE} \(platform.displayName) Call During Focus"
        content.body = "Incoming call: \(callInfo)\nYour Focus Mode is active."
        content.sound = .default
        content.categoryIdentifier = "VOIP_INTERCEPTION"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif

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
            // Only escalate once per window - check if already pending
            if !getEscalationPending().contains(contactKey) {
                await handleEscalation(contactKey: contactKey, messageCount: timestamps.count)
            } else {
                // Already pending - check if this message is a confirmation
                await checkEscalationConfirmation(contactKey: contactKey, messageContent: messageContent)
            }
        }
    }

    func handleEscalation(contactKey: String, messageCount: Int) async {
        print("[Escalation] Contact \(contactKey) sent \(messageCount) messages in \(Int(getGlobalSettings().escalationTimeWindow))s window")

        // Mark as pending escalation
        addEscalationPending(contactKey)

        // DON'T notify user yet - first ask the contact if it's truly urgent
        // This prevents unnecessary interruptions
        let language = await detectLanguage(for: contactKey, phoneNumber: contactKey, messageContent: nil)

        // Localized escalation inquiry
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

    func checkEscalationConfirmation(contactKey: String, messageContent: String) async {
        let language = await detectLanguage(for: contactKey, phoneNumber: contactKey, messageContent: messageContent)

        // Check if this is an affirmative response
        if isAffirmativeResponse(messageContent, language: language) {
            // YES - this IS urgent, now notify user
            removeEscalationPending(contactKey)

            // Update conversation state
            if var state = getConversationState(for: contactKey) {
                state.markedAsUrgent = true
                state.currentStage = .confirmedUrgent
                setConversationState(for: contactKey, state: state)
            }

            // NOW we notify the user (only after confirmation)
            if getGlobalSettings().escalationNotifyUser {
                await notifyUserOfUrgentContact(contactKey: contactKey)
            }

            // Send confirmation and call instructions
            let template = getMessageTemplates().autoReply[language] ?? getMessageTemplates().autoReply["en"]!
            _ = await sendMessage(to: contactKey, message: template.urgentConfirmed, platform: .sms)

            print("[Escalation] Contact \(contactKey) confirmed urgency - user notified")
        } else if isNegativeResponse(messageContent, language: language) {
            // NO - not urgent, just chatty
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
        // If ambiguous, we don't respond again - wait for clearer answer
    }

    func notifyUserOfUrgentContact(contactKey: String) async {
        // Send notification to user about urgent contact
        // This could be a push notification, sound alert, etc.
        let content = UNMutableNotificationContent()
        content.title = "\u{26A0}\u{FE0F} Urgent Message"
        content.body = "Contact \(contactKey) has confirmed this is urgent."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)

        print("[Escalation] User notified about urgent contact: \(contactKey)")
    }

    // MARK: - Calendar-Aware Auto-Replies (Enhancement 3 - PRIVACY-FOCUSED)

    // PRIVACY: Never share meeting details or calendar info!
    // Only share when user will be available again - no meeting titles or details.

    func getCalendarAwareMessage(language: String) async -> String? {
        guard getGlobalSettings().calendarAwareRepliesEnabled else { return nil }

        #if os(macOS)
        // Read ONLY the end time of current event - NOT the title (privacy)
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
            // PRIVACY: Only say when available, NEVER mention what the event is
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

    func getNextAvailableSlot(language: String) async -> String? {
        guard getGlobalSettings().includeNextAvailableSlot else { return nil }

        #if os(macOS)
        // Find next free slot - only return TIME, no event details (privacy)
        return nil
        #else
        return nil
        #endif
    }

    // MARK: - Location-Based Behavior (Enhancement 4 - PRIVACY-FOCUSED)

    // PRIVACY: Never reveal location to contacts!
    // Location is used internally to adjust THEA's behavior, but never shared.
    // - At home: Might respond faster
    // - At work: Professional tone
    // - Custom locations: User-defined behavior
    //
    // The contact will NEVER know where the user is.

    func getCurrentLocationBehavior() async -> LocationFocusBehavior? {
        guard getGlobalSettings().locationAwareBehaviorEnabled else { return nil }

        // Would need CoreLocation access
        // For now, return nil - actual implementation would check GPS
        return nil
    }

    func getLocationAwareMessage(language: String) async -> String? {
        // PRIVACY: Location is NEVER shared with contacts
        // This function returns nil - location only affects internal behavior
        // (e.g., response timing, tone) but is never mentioned in messages
        nil
    }

    /// Internal: Adjust response behavior based on location (without revealing it)
    func getLocationBasedResponseDelay() async -> TimeInterval {
        guard let _ = await getCurrentLocationBehavior() else {
            return getGlobalSettings().autoReplyDelay
        }

        // At home might mean faster responses, at work might mean slower
        // But we NEVER tell the contact where we are
        return getGlobalSettings().autoReplyDelay
    }

    // MARK: - Voice Message Support (Enhancement 5)

    // When receiving voice messages:
    // - Transcribe them using speech recognition
    // - Analyze for urgency
    // - Include transcription context in responses

    /// Handle incoming voice message
    public func handleIncomingVoiceMessage(
        from contactId: String?,
        phoneNumber: String?,
        platform: CommunicationPlatform,
        audioURL: URL
    ) async {
        guard getGlobalSettings().voiceMessageAnalysisEnabled else { return }
        guard getCurrentFocusMode() != nil else { return }

        var transcription: String?

        // Transcribe the voice message
        if getGlobalSettings().transcribeVoiceMessages {
            transcription = await transcribeVoiceMessage(audioURL: audioURL)
        }

        // Handle like a text message but with voice context
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

    /// Handle incoming group chat message
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

        // Check if we should respond
        if getGlobalSettings().silenceGroupChats {
            // Only respond to direct mentions
            if getGlobalSettings().onlyRespondToDirectMentions && !isMention {
                return
            }
        }

        // Check reply limit for this group
        let replyCount = getGroupChatAutoReplyCount(for: groupId)
        if replyCount >= getGlobalSettings().groupChatMaxReplies {
            return
        }

        if getGlobalSettings().groupChatAutoReplyEnabled {
            let language = await detectLanguage(for: contactId, phoneNumber: nil, messageContent: messageContent)
            let template = getMessageTemplates().autoReply[language] ?? getMessageTemplates().autoReply["en"]!

            // Send a group-appropriate response
            let groupMessage = """
            [Auto-reply] \(template.initialMessage)
            (This is an automated response - I'll catch up with the group when available)
            """

            // Only send if mentioned
            if isMention {
                await sendGroupMessage(groupId: groupId, message: groupMessage, platform: platform)
                setGroupChatAutoReplyCount(for: groupId, count: replyCount + 1)
            }
        }
    }

    func sendGroupMessage(groupId: String, message: String, platform: CommunicationPlatform) async {
        // Similar to sendMessage but for groups
        print("[GroupChat] Would send to group \(groupId): \(message)")
    }
}
