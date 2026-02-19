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
        #if os(macOS)
        // Use AppleScript to send via Telegram Desktop
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

    // periphery:ignore - Reserved: sendViaShortcuts(to:message:platform:) instance method reserved for future feature activation
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
