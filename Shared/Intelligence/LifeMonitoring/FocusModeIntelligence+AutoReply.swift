// FocusModeIntelligence+AutoReply.swift
// THEA - Auto-Reply Logic & Message Sending
// Split from FocusModeIntelligence.swift
//
// Related extensions:
// - FocusModeIntelligence+LanguageDetection.swift: Language/urgency detection, time-aware responses
// - FocusModeIntelligence+StatusSync.swift: WhatsApp/Telegram/COMBOX status sync

import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Auto-Reply Logic & Message Sending

extension FocusModeIntelligence {

    // MARK: - Auto-Reply Logic

    /// Determine whether an auto-reply should be sent to a specific contact.
    ///
    /// Checks that auto-reply is enabled globally, the platform is allowed,
    /// the reply window hasn't been exceeded, and the per-contact max hasn't been reached.
    ///
    /// - Parameters:
    ///   - contactKey: The unique key identifying the contact.
    ///   - platform: The communication platform to check against allowed platforms.
    /// - Returns: `true` if an auto-reply should be sent.
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

    /// Send the initial auto-reply to a contact, optionally including availability info and urgency prompt.
    ///
    /// - Parameters:
    ///   - communication: The incoming communication to reply to (mutated with status).
    ///   - state: The conversation state (mutated with reply count and stage).
    ///   - language: The BCP-47 language code for template selection.
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

    /// Send call instructions to a contact who confirmed their message is urgent.
    ///
    /// - Parameters:
    ///   - communication: The incoming communication (mutated with status).
    ///   - state: The conversation state (mutated with stage).
    ///   - language: The BCP-47 language code for template selection.
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

    /// Send an SMS notification to a caller whose call was missed during Focus mode.
    ///
    /// - Parameter communication: The missed call communication record.
    func sendMissedCallNotification(for communication: IncomingCommunication) async {
        guard let phoneNumber = communication.phoneNumber else { return }

        let language = await detectLanguage(for: communication.contactId, phoneNumber: phoneNumber, messageContent: nil)
        let template = getMessageTemplates().callerNotification[language] ?? getMessageTemplates().callerNotification["en"]!

        let success = await sendMessage(to: phoneNumber, message: template.missedCallSMS, platform: .sms)

        if success {
            print("[FocusMode] Sent missed call notification to \(phoneNumber)")
        }
    }

    /// Handle a detected emergency message with immediate response and optional auto-callback.
    ///
    /// - Parameter communication: The incoming communication flagged as an emergency.
    func handleEmergencyMessage(_ communication: IncomingCommunication) async {
        print("[FocusMode] EMERGENCY DETECTED from \(communication.contactName ?? communication.phoneNumber ?? "unknown")")

        if getGlobalSettings().autoDialEmergencyServices {
            // Only for true emergencies (911 keywords, etc.)
        }

        guard let phoneNumber = communication.phoneNumber else { return }
        _ = communication.languageDetected ?? "en"

        let emergencyMessage = """
        \u{26A0}\u{FE0F} I received your message and see this may be an emergency.

        If you need emergency services, please call:
        \u{1F6A8} 112 (Europe) / 911 (US) / 999 (UK)

        I'm notifying you that I'm calling you back immediately.
        """

        _ = await sendMessage(to: phoneNumber, message: emergencyMessage, platform: communication.platform)

        if getGlobalSettings().autoCallbackEnabled {
            await initiateCallback(to: phoneNumber, reason: "Emergency detected")
        }
    }

    // MARK: - Message Sending

    /// Send a message to a phone number via the appropriate platform.
    ///
    /// On macOS, uses AppleScript automation for Messages, WhatsApp, and Telegram.
    /// On iOS, delegates to Shortcuts automations.
    ///
    /// - Parameters:
    ///   - phoneNumber: The recipient's phone number.
    ///   - message: The message text to send.
    ///   - platform: The communication platform to use.
    /// - Returns: `true` if the message was sent successfully.
    func sendMessage(to phoneNumber: String, message: String, platform: CommunicationPlatform) async -> Bool {
        #if os(macOS)
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
        return await sendViaShortcuts(to: phoneNumber, message: message, platform: platform)
        #endif
    }

    #if os(macOS)
    /// Send a message via the macOS Messages app using AppleScript.
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

    /// Send a message via WhatsApp Desktop using AppleScript UI automation.
    func sendViaWhatsApp(to phoneNumber: String, message: String) async -> Bool {
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

    /// Send a message via Telegram Desktop using AppleScript UI automation.
    func sendViaTelegram(to chatId: String, message: String) async -> Bool {
        #if os(macOS)
        let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Telegram" to activate
        delay 0.5
        tell application "System Events"
            tell process "Telegram"
                keystroke "f" using command down
                delay 0.3
                keystroke "\(chatId)"
                delay 0.5
                key code 36
                delay 0.3
                keystroke "\(escapedMessage)"
                delay 0.1
                key code 36
            end tell
        end tell
        """
        return await runAppleScript(script)
        #else
        return false
        #endif
    }

    /// Execute an AppleScript and return whether it succeeded.
    ///
    /// - Parameter script: The AppleScript source code to execute.
    /// - Returns: `true` if the script executed without errors.
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

    /// Execute an AppleScript and return its string result.
    ///
    /// - Parameter script: The AppleScript source code to execute.
    /// - Returns: The string value returned by the script, or `nil` on failure.
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

    /// Send a message via iOS Shortcuts automation.
    ///
    /// - Parameters:
    ///   - phoneNumber: The recipient's phone number.
    ///   - message: The message text to send.
    ///   - platform: The target platform (.imessage/.sms or .whatsapp).
    /// - Returns: `true` if the Shortcuts URL was successfully opened.
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
}
