// FocusModeIntelligence+AutoReply.swift
// THEA - Auto-Reply, Message Sending, Language Detection, Urgency Detection
// Split from FocusModeIntelligence.swift

import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Auto-Reply, Messaging & Language Detection

extension FocusModeIntelligence {

    // MARK: - Auto-Reply Logic

    func shouldSendAutoReply(to contactKey: String, platform: CommunicationPlatform) async -> Bool {
        guard getGlobalSettings().autoReplyEnabled else { return false }
        guard getGlobalSettings().autoReplyPlatforms.contains(platform) else { return false }

        // Check reply window
        if let lastReply = getRecentAutoReply(for: contactKey) {
            let timeSince = Date().timeIntervalSince(lastReply)
            if timeSince < getGlobalSettings().autoReplyWindow {
                return false
            }
        }

        // Check max replies
        if let state = getConversationState(for: contactKey) {
            if state.autoRepliesSent >= getGlobalSettings().maxAutoRepliesPerContact {
                return false
            }
        }

        return true
    }

    func sendInitialAutoReply(
        to communication: inout IncomingCommunication,
        state: inout ConversationState,
        language: String
    ) async {
        let template = getMessageTemplates().autoReply[language] ?? getMessageTemplates().autoReply["en"]!

        var message = template.initialMessage

        // Add time-aware context if enabled
        if getGlobalSettings().timeAwareResponses && getGlobalSettings().includeAvailabilityInReply {
            if let availabilityInfo = getAvailabilityInfo(language: language) {
                message += " " + availabilityInfo
            }
        }

        // Add urgent question if enabled
        if getGlobalSettings().askIfUrgent {
            message += "\n\n" + template.urgentQuestion
            state.currentStage = .askedIfUrgent
            state.awaitingUrgencyResponse = true
        }

        // Send via appropriate method
        let success = await sendMessage(to: communication.phoneNumber ?? "", message: message, platform: communication.platform)

        if success {
            communication.autoReplyStatus = .sent
            state.autoRepliesSent += 1
            setRecentAutoReply(for: state.contactId, date: Date())
            notifyAutoReplySent(communication, message)
        } else {
            communication.autoReplyStatus = .failed
        }
    }

    func sendUrgentCallInstructions(
        to communication: inout IncomingCommunication,
        state: inout ConversationState,
        language: String
    ) async {
        let template = getMessageTemplates().autoReply[language] ?? getMessageTemplates().autoReply["en"]!

        let message = template.urgentConfirmed

        let success = await sendMessage(to: communication.phoneNumber ?? "", message: message, platform: communication.platform)

        if success {
            state.currentStage = .callInstructionsSent
            communication.autoReplyStatus = .sent
            notifyAutoReplySent(communication, message)
        }
    }

    func sendMissedCallNotification(for communication: IncomingCommunication) async {
        guard let phoneNumber = communication.phoneNumber else { return }

        let language = await detectLanguage(for: communication.contactId, phoneNumber: phoneNumber, messageContent: nil)
        let template = getMessageTemplates().callerNotification[language] ?? getMessageTemplates().callerNotification["en"]!

        // Send via SMS (most reliable for call notifications)
        let success = await sendMessage(to: phoneNumber, message: template.missedCallSMS, platform: .sms)

        if success {
            print("[FocusMode] Sent missed call notification to \(phoneNumber)")
        }
    }

    func handleEmergencyMessage(_ communication: IncomingCommunication) async {
        // Emergency detected - immediate action
        print("[FocusMode] EMERGENCY DETECTED from \(communication.contactName ?? communication.phoneNumber ?? "unknown")")

        // If auto-dial emergency services is enabled and keywords suggest real emergency
        // This is a safety feature - be very careful with false positives
        if getGlobalSettings().autoDialEmergencyServices {
            // Only for true emergencies (911 keywords, etc.)
            // This would need very careful implementation
        }

        // Send immediate response with emergency services info
        guard let phoneNumber = communication.phoneNumber else { return }
        _ = communication.languageDetected ?? "en"

        let emergencyMessage = """
        \u{26A0}\u{FE0F} I received your message and see this may be an emergency.

        If you need emergency services, please call:
        \u{1F6A8} 112 (Europe) / 911 (US) / 999 (UK)

        I'm notifying you that I'm calling you back immediately.
        """

        _ = await sendMessage(to: phoneNumber, message: emergencyMessage, platform: communication.platform)

        // Auto-callback if enabled
        if getGlobalSettings().autoCallbackEnabled {
            await initiateCallback(to: phoneNumber, reason: "Emergency detected")
        }
    }

    // MARK: - Message Sending

    func sendMessage(to phoneNumber: String, message: String, platform: CommunicationPlatform) async -> Bool {
        #if os(macOS)
        // On Mac, we can use AppleScript for Messages and direct APIs for others
        switch platform {
        case .imessage, .sms:
            return await sendViaMessages(to: phoneNumber, message: message)
        case .whatsapp:
            return await sendViaWhatsApp(to: phoneNumber, message: message)
        case .telegram:
            return await sendViaTelegram(to: phoneNumber, message: message)
        default:
            return false
        }
        #else
        // On iOS, use Shortcuts
        return await sendViaShortcuts(to: phoneNumber, message: message, platform: platform)
        #endif
    }

    #if os(macOS)
    func sendViaMessages(to phoneNumber: String, message: String) async -> Bool {
        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(phoneNumber)" of targetService
            send "\(message.replacingOccurrences(of: "\"", with: "\\\""))" to targetBuddy
        end tell
        """

        return await runAppleScript(script)
    }

    func sendViaWhatsApp(to phoneNumber: String, message: String) async -> Bool {
        // WhatsApp MCP Server approach - using AppleScript automation
        // Reference: https://github.com/victor-torres/whatsapp-applescript

        let cleanNumber = phoneNumber.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: " ", with: "")

        let script = """
        tell application "WhatsApp" to activate
        delay 0.5
        tell application "System Events"
            tell process "WhatsApp"
                -- Open new chat
                keystroke "n" using command down
                delay 0.3
                -- Type phone number
                keystroke "\(cleanNumber)"
                delay 0.5
                -- Press enter to select
                key code 36
                delay 0.3
                -- Type message
                keystroke "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
                delay 0.2
                -- Send
                key code 36
            end tell
        end tell
        """

        return await runAppleScript(script)
    }

    func sendViaTelegram(to chatId: String, message: String) async -> Bool {
        // Telegram Bot API or desktop automation
        // For personal account, use desktop automation similar to WhatsApp
        false // Placeholder
    }

    func runAppleScript(_ script: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    if error == nil {
                        continuation.resume(returning: true)
                    } else {
                        print("[AppleScript] Error: \(error ?? [:])")
                        continuation.resume(returning: false)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func runAppleScriptReturning(_ script: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    let result = appleScript.executeAndReturnError(&error)
                    if error == nil {
                        continuation.resume(returning: result.stringValue)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif

    func sendViaShortcuts(to phoneNumber: String, message: String, platform: CommunicationPlatform) async -> Bool {
        #if os(iOS)
        let shortcutName: String
        switch platform {
        case .imessage, .sms:
            shortcutName = "THEA%20Auto%20Reply"
        case .whatsapp:
            shortcutName = "THEA%20WhatsApp%20Reply"
        default:
            return false
        }

        let input = "\(phoneNumber)|\(message)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "shortcuts://run-shortcut?name=\(shortcutName)&input=text&text=\(input)") else {
            return false
        }

        return await MainActor.run {
            UIApplication.shared.open(url)
            return true
        }
        #else
        return false
        #endif
    }

    // MARK: - WhatsApp Status Management

    func updateWhatsAppStatus(_ status: String) async {
        // Save current status first
        #if os(macOS)
        // Read current status via AppleScript/automation
        // This is complex as WhatsApp doesn't expose this easily
        setPreviousWhatsAppStatus(await getCurrentWhatsAppStatus())

        // Update status
        _ = """
        tell application "WhatsApp" to activate
        delay 0.5
        tell application "System Events"
            tell process "WhatsApp"
                -- Navigate to Settings > Profile
                keystroke "," using command down
                delay 0.3
                -- This would need UI navigation to change status
                -- Placeholder - actual implementation depends on WhatsApp UI
            end tell
        end tell
        """

        // Note: WhatsApp status change via automation is complex
        // Alternative: Use WhatsApp Web automation or third-party APIs
        print("[WhatsApp] Would update status to: \(status)")
        #endif
    }

    func revertWhatsAppStatus() async {
        if let previous = getPreviousWhatsAppStatus() {
            await updateWhatsAppStatus(previous)
            setPreviousWhatsAppStatus(nil)
        }
    }

    func getCurrentWhatsAppStatus() async -> String? {
        // Read current WhatsApp status
        nil // Placeholder
    }

    // MARK: - Telegram Status Management

    func updateTelegramStatus(_ status: String) async {
        // Telegram Bot API or automation
        print("[Telegram] Would update status to: \(status)")
    }

    func clearTelegramStatus() async {
        print("[Telegram] Would clear status")
    }

    // MARK: - COMBOX Integration

    func switchComboxGreeting(to greetingType: String) async {
        // Swisscom COMBOX greeting change
        // This requires calling 086 and navigating menus via DTMF

        print("[COMBOX] Would switch greeting to: \(greetingType)")

        // Actual implementation would use Shortcuts to:
        // 1. Call 086
        // 2. Navigate menu with DTMF tones
        // 3. Select appropriate greeting

        #if os(iOS)
        // Trigger Shortcuts automation
        if let url = URL(string: "shortcuts://run-shortcut?name=THEA%20COMBOX%20Greeting&input=text&text=\(greetingType)") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }

    // MARK: - Language Detection

    func detectLanguage(for contactId: String?, phoneNumber: String?, messageContent: String?) async -> String {
        // Check cached
        if let cId = contactId, let cached = getContactLanguage(cId), cached.confidence > 0.7 {
            return cached.detectedLanguage
        }

        // Try phone number
        if let phone = phoneNumber, let langFromPhone = languageFromPhoneNumber(phone) {
            if let cId = contactId {
                setContactLanguageInfo(cId, info: ContactLanguageInfo(
                    contactId: cId,
                    detectedLanguage: langFromPhone,
                    confidence: 0.7,
                    detectionMethod: .phoneCountryCode,
                    isManuallySet: false,
                    previousLanguages: [],
                    lastUpdated: Date()
                ))
            }
            return langFromPhone
        }

        // Try message content analysis
        if let content = messageContent, !content.isEmpty {
            if let detected = detectLanguageFromText(content) {
                if let cId = contactId {
                    var info = getContactLanguage(cId) ?? ContactLanguageInfo(
                        contactId: cId,
                        detectedLanguage: detected,
                        confidence: 0.6,
                        detectionMethod: .messageHistory,
                        isManuallySet: false,
                        previousLanguages: [],
                        lastUpdated: Date()
                    )
                    info.detectedLanguage = detected
                    info.lastUpdated = Date()
                    setContactLanguageInfo(cId, info: info)
                }
                return detected
            }
        }

        // Default to device locale
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    func languageFromPhoneNumber(_ phoneNumber: String) -> String? {
        let countryCodeToLanguage: [String: String] = [
            "+1": "en", "+44": "en", "+61": "en", "+64": "en",
            "+33": "fr", "+32": "fr", // Belgium - could be fr/nl
            "+41": "de", // Switzerland - could be de/fr/it
            "+49": "de", "+43": "de",
            "+39": "it",
            "+34": "es", "+52": "es", "+54": "es",
            "+351": "pt", "+55": "pt",
            "+31": "nl",
            "+81": "ja",
            "+86": "zh", "+852": "zh", "+886": "zh",
            "+82": "ko",
            "+7": "ru",
            "+966": "ar", "+971": "ar", "+20": "ar"
        ]

        for (code, lang) in countryCodeToLanguage {
            if phoneNumber.hasPrefix(code) {
                return lang
            }
        }

        return nil
    }

    func detectLanguageFromText(_ text: String) -> String? {
        // Simple keyword-based detection
        let languageIndicators: [String: [String]] = [
            "fr": ["bonjour", "merci", "salut", "oui", "non", "comment", "pourquoi", "c'est", "je", "tu"],
            "de": ["hallo", "danke", "guten", "bitte", "ja", "nein", "wie", "warum", "ich", "du", "ist"],
            "it": ["ciao", "grazie", "buongiorno", "si\u{300}", "no", "come", "perche\u{301}", "sono", "tu", "e\u{300}"],
            "es": ["hola", "gracias", "buenos", "si\u{301}", "no", "co\u{301}mo", "por que\u{301}", "soy", "tu\u{301}", "es"],
            "pt": ["ola\u{301}", "obrigado", "bom dia", "sim", "na\u{303}o", "como", "por que", "sou", "tu", "e\u{301}"],
            "nl": ["hallo", "dank", "goedemorgen", "ja", "nee", "hoe", "waarom", "ik", "jij", "is"]
        ]

        let lowercased = text.lowercased()

        var scores: [String: Int] = [:]
        for (lang, indicators) in languageIndicators {
            for indicator in indicators {
                if lowercased.contains(indicator) {
                    scores[lang, default: 0] += 1
                }
            }
        }

        // Return language with highest score, if any
        if let (lang, score) = scores.max(by: { $0.value < $1.value }), score >= 2 {
            return lang
        }

        return nil
    }

    // MARK: - Urgency Detection

    func detectUrgency(in message: String, language: String) -> IncomingCommunication.UrgencyLevel {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased()

        // Check for emergency keywords first
        for keyword in templates.emergencyKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return .emergency
            }
        }

        // Check for urgent keywords
        for keyword in templates.yesKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return .urgent
            }
        }

        return .unknown
    }

    func detectEmergency(in message: String, language: String) -> Bool {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased()

        for keyword in templates.emergencyKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    func isAffirmativeResponse(_ message: String, language: String) -> Bool {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for keyword in templates.yesKeywords {
            if lowercased == keyword.lowercased() || lowercased.hasPrefix(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    func isNegativeResponse(_ message: String, language: String) -> Bool {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for keyword in templates.noKeywords {
            if lowercased == keyword.lowercased() || lowercased.hasPrefix(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    // MARK: - Time-Aware Responses

    func getAvailabilityInfo(language: String) -> String? {
        guard let mode = getCurrentFocusMode() else { return nil }

        // Check if Focus mode has a schedule that tells us when it ends
        for schedule in mode.schedules where schedule.enabled {
            // Calculate when this schedule ends
            let calendar = Calendar.current
            let now = Date()

            if let endHour = schedule.endTime.hour,
               let endMinute = schedule.endTime.minute {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = endHour
                components.minute = endMinute

                if let endTime = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    formatter.locale = Locale(identifier: language)

                    let timeString = formatter.string(from: endTime)

                    // Localized availability messages
                    let availabilityMessages: [String: String] = [
                        "en": "I should be available around \(timeString).",
                        "fr": "Je devrais \u{00EA}tre disponible vers \(timeString).",
                        "de": "Ich sollte gegen \(timeString) verf\u{00FC}gbar sein.",
                        "it": "Dovrei essere disponibile verso le \(timeString).",
                        "es": "Deber\u{00ED}a estar disponible alrededor de las \(timeString)."
                    ]

                    return availabilityMessages[language] ?? availabilityMessages["en"]
                }
            }
        }

        return nil
    }

    // MARK: - Callback System

    func initiateCallback(to phoneNumber: String, reason: String) async {
        // Initiate a call back to the contact
        #if os(iOS)
        if let url = URL(string: "tel://\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
        #elseif os(macOS)
        // On Mac, use FaceTime or handoff to iPhone
        if let url = URL(string: "facetime://\(phoneNumber)") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    func processPendingCallbacks() async {
        for callback in getPendingCallbacks() where !callback.completed {
            // Schedule reminder or initiate callback
            print("[FocusMode] Pending callback to \(callback.phoneNumber): \(callback.reason)")
        }
    }
}
