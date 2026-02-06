// FocusModeShortcutsIntegration.swift
// THEA - iOS Shortcuts Integration for Focus Mode Automation
// Created by Claude - February 2026
//
// Bridges THEA with iOS Shortcuts for:
// - Detecting Focus mode changes (via Shortcuts Automations)
// - Sending auto-replies (Messages, WhatsApp)
// - Updating WhatsApp status
// - Managing COMBOX greetings

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shortcuts URL Schemes

/// URL schemes for triggering Shortcuts automations
public enum TheaShortcutsURL {
    // Base Shortcuts app URL
    private static let shortcutsBase = "shortcuts://run-shortcut"

    // MARK: - Focus Mode Shortcuts

    /// Shortcut to run when Focus Mode is activated
    /// Expected Shortcut name: "THEA Focus Activated"
    /// Input: Focus mode name
    public static func focusActivated(modeName: String) -> URL? {
        let encoded = modeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(shortcutsBase)?name=THEA%20Focus%20Activated&input=text&text=\(encoded)")
    }

    /// Shortcut to run when Focus Mode is deactivated
    /// Expected Shortcut name: "THEA Focus Deactivated"
    public static func focusDeactivated() -> URL? {
        URL(string: "\(shortcutsBase)?name=THEA%20Focus%20Deactivated")
    }

    // MARK: - Auto-Reply Shortcuts

    /// Shortcut to send iMessage/SMS reply
    /// Expected Shortcut name: "THEA Auto Reply"
    /// Input: "phoneNumber|message"
    public static func sendAutoReply(to phoneNumber: String, message: String) -> URL? {
        let input = "\(phoneNumber)|\(message)"
        let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(shortcutsBase)?name=THEA%20Auto%20Reply&input=text&text=\(encoded)")
    }

    /// Shortcut to send WhatsApp message
    /// Expected Shortcut name: "THEA WhatsApp Reply"
    /// Input: "phoneNumber|message"
    public static func sendWhatsAppReply(to phoneNumber: String, message: String) -> URL? {
        let input = "\(phoneNumber)|\(message)"
        let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(shortcutsBase)?name=THEA%20WhatsApp%20Reply&input=text&text=\(encoded)")
    }

    // MARK: - WhatsApp Status Shortcuts

    /// Shortcut to update WhatsApp status/About
    /// Expected Shortcut name: "THEA Update WhatsApp Status"
    /// Input: status message
    public static func updateWhatsAppStatus(_ status: String) -> URL? {
        let encoded = status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(shortcutsBase)?name=THEA%20Update%20WhatsApp%20Status&input=text&text=\(encoded)")
    }

    // MARK: - COMBOX Shortcuts

    /// Shortcut to change COMBOX greeting
    /// Expected Shortcut name: "THEA COMBOX Greeting"
    /// Input: greeting type (standard, focus_mode, vacation, etc.)
    public static func changeComboxGreeting(to type: String) -> URL? {
        let encoded = type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "\(shortcutsBase)?name=THEA%20COMBOX%20Greeting&input=text&text=\(encoded)")
    }

    // MARK: - Direct WhatsApp URLs

    /// Open WhatsApp chat with specific number
    public static func whatsAppChat(phoneNumber: String, message: String? = nil) -> URL? {
        var urlString = "whatsapp://send?phone=\(phoneNumber.replacingOccurrences(of: "+", with: ""))"
        if let msg = message {
            urlString += "&text=\(msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        return URL(string: urlString)
    }

    /// Open WhatsApp Business API URL (web-based)
    public static func whatsAppBusinessAPI(phoneNumber: String, message: String) -> URL? {
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(phoneNumber.replacingOccurrences(of: "+", with: ""))?text=\(encoded)")
    }

    // MARK: - Telegram URLs

    /// Open Telegram chat with specific user
    public static func telegramChat(username: String, message: String? = nil) -> URL? {
        var urlString = "tg://resolve?domain=\(username)"
        if let msg = message {
            urlString += "&text=\(msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        return URL(string: urlString)
    }
}

// MARK: - Shortcuts Automation Generator

/// Generates Shortcuts that users can import for THEA integration
public struct TheaShortcutsGenerator {

    /// Instructions for setting up Focus Mode automations
    public static let focusModeAutomationInstructions = """
    # THEA Focus Mode Automation Setup

    ## Required Shortcuts to Create:

    ### 1. "THEA Focus Activated"
    Trigger: When ANY Focus mode turns ON
    Actions:
    1. Get name of Focus
    2. Open URL: thea://focus-activated?mode=[Focus Name]

    ### 2. "THEA Focus Deactivated"
    Trigger: When ANY Focus mode turns OFF
    Actions:
    1. Open URL: thea://focus-deactivated

    ### 3. "THEA Auto Reply" (for iMessage/SMS)
    Actions:
    1. Split Input by "|"
    2. Get Item 1 from Split (phone number)
    3. Get Item 2 from Split (message)
    4. Send Message [Item 2] to [Item 1]

    ### 4. "THEA WhatsApp Reply"
    Actions:
    1. Split Input by "|"
    2. Get Item 1 from Split (phone number)
    3. Get Item 2 from Split (message)
    4. Open URL: whatsapp://send?phone=[Item 1]&text=[Item 2]
    5. Wait 1 second
    6. Press "Send" (accessibility action)

    ### 5. "THEA Update WhatsApp Status"
    Note: WhatsApp doesn't expose status updates via URL scheme.
    This requires either:
    - Manual status update
    - WhatsApp Business API integration
    - Third-party automation tool (like Shortcuts + accessibility)

    ### 6. "THEA COMBOX Greeting"
    Actions:
    1. If Input is "focus_mode":
       - Call 086
       - Wait 3 seconds
       - Play DTMF: 9 (settings)
       - Wait 1 second
       - Play DTMF: 1 (greeting)
       - Wait 1 second
       - Play DTMF: 2 (select greeting 2 - pre-recorded focus mode greeting)
    2. Else if Input is "standard":
       - Same flow, select greeting 1

    ## Focus Mode Automation Setup:
    1. Open Shortcuts app
    2. Go to Automation tab
    3. Create Personal Automation
    4. Choose "Focus"
    5. Select "When turning on" / "When turning off"
    6. Select which Focus modes to trigger
    7. Add "Run Shortcut" action
    8. Select appropriate THEA shortcut
    9. IMPORTANT: Disable "Ask Before Running"
    """

    /// Generate a shareable Shortcuts file content
    /// Note: This is a simplified representation; actual .shortcut files are binary plist
    public static func generateShortcutManifest(name: String, actions: [String]) -> [String: Any] {
        [
            "WFWorkflowName": name,
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 2071128575,
                "WFWorkflowIconGlyphNumber": 59511
            ],
            "WFWorkflowActions": actions.map { action in
                ["WFWorkflowActionIdentifier": action]
            }
        ]
    }
}

// MARK: - App URL Handler

/// Handles incoming URLs from Shortcuts automations
public actor TheaURLHandler {
    public static let shared = TheaURLHandler()

    /// THEA's custom URL scheme: thea://
    public enum URLAction: String {
        case focusActivated = "focus-activated"
        case focusDeactivated = "focus-deactivated"
        case handleMessage = "handle-message"
        case handleCall = "handle-call"
        case urgentResponse = "urgent-response"
    }

    /// Handle incoming URL
    public func handleURL(_ url: URL) async {
        guard url.scheme == "thea" else { return }

        let action = URLAction(rawValue: url.host ?? "")
        let params = parseQueryParameters(url)

        switch action {
        case .focusActivated:
            if let modeName = params["mode"] {
                await FocusModeIntelligence.shared.setActiveFocusMode(modeName)
            }

        case .focusDeactivated:
            await FocusModeIntelligence.shared.setActiveFocusMode(nil)

        case .handleMessage:
            if let from = params["from"],
               let platform = params["platform"],
               let message = params["message"] {
                await FocusModeIntelligence.shared.handleIncomingMessage(
                    from: nil,
                    contactName: nil,
                    phoneNumber: from,
                    platform: CommunicationPlatform(rawValue: platform) ?? .sms,
                    messageContent: message
                )
            }

        case .handleCall:
            if let from = params["from"],
               let platform = params["platform"] {
                await FocusModeIntelligence.shared.handleIncomingCall(
                    from: from,
                    contactId: nil,
                    contactName: nil,
                    platform: CommunicationPlatform(rawValue: platform) ?? .phone
                )
            }

        case .urgentResponse:
            if let contactId = params["contact"] {
                // Handle urgent response from contact
                print("[THEA] Urgent response from contact: \(contactId)")
            }

        case .none:
            print("[THEA] Unknown URL action: \(url)")
        }
    }

    private func parseQueryParameters(_ url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }

        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }
        return params
    }
}

// MARK: - Shortcuts Execution Helper

/// Helper for executing Shortcuts from THEA
public struct ShortcutsExecutor {

    #if os(iOS)
    /// Execute a Shortcuts URL
    @MainActor
    public static func execute(_ url: URL) async -> Bool {
        guard UIApplication.shared.canOpenURL(url) else {
            print("[Shortcuts] Cannot open URL: \(url)")
            return false
        }

        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Send auto-reply via Shortcuts
    @MainActor
    public static func sendAutoReply(to phoneNumber: String, message: String, platform: CommunicationPlatform) async -> Bool {
        let url: URL?

        switch platform {
        case .imessage, .sms:
            url = TheaShortcutsURL.sendAutoReply(to: phoneNumber, message: message)
        case .whatsapp:
            url = TheaShortcutsURL.sendWhatsAppReply(to: phoneNumber, message: message)
        default:
            url = nil
        }

        guard let shortcutURL = url else { return false }
        return await execute(shortcutURL)
    }

    /// Update WhatsApp status via Shortcuts
    @MainActor
    public static func updateWhatsAppStatus(_ status: String) async -> Bool {
        guard let url = TheaShortcutsURL.updateWhatsAppStatus(status) else { return false }
        return await execute(url)
    }

    /// Notify about Focus mode change
    @MainActor
    public static func notifyFocusModeChanged(activated: Bool, modeName: String?) async -> Bool {
        let url: URL?

        if activated, let name = modeName {
            url = TheaShortcutsURL.focusActivated(modeName: name)
        } else {
            url = TheaShortcutsURL.focusDeactivated()
        }

        guard let shortcutURL = url else { return false }
        return await execute(shortcutURL)
    }
    #endif
}

// MARK: - Intent Extension Support

/// Support for Focus status sharing via Intent Extension
/// This requires an Intent Extension target to be added to the project
public struct FocusStatusIntentSupport {
    /// Instructions for creating the Intent Extension
    public static let intentExtensionInstructions = """
    # THEA Focus Status Intent Extension Setup

    ## Creating the Intent Extension:

    1. In Xcode: File > New > Target
    2. Select "Intents Extension"
    3. Name it "TheaFocusIntents"
    4. Check "Include UI Extension" if you want custom UI

    ## Implementing INShareFocusStatusIntentHandling:

    ```swift
    import Intents

    class FocusStatusIntentHandler: INExtension, INShareFocusStatusIntentHandling {

        func handle(intent: INShareFocusStatusIntent, completion: @escaping (INShareFocusStatusIntentResponse) -> Void) {
            // Get the focus status
            let isFocused = intent.focusStatus?.isFocused ?? false

            // Notify main app via App Group shared container
            let defaults = UserDefaults(suiteName: "group.app.thea")
            defaults?.set(isFocused, forKey: "focusStatusActive")
            defaults?.set(Date(), forKey: "focusStatusTimestamp")

            // Post notification for the main app
            DistributedNotificationCenter.default().post(
                name: NSNotification.Name("TheaFocusStatusChanged"),
                object: nil,
                userInfo: ["isFocused": isFocused]
            )

            completion(INShareFocusStatusIntentResponse(code: .success, userActivity: nil))
        }
    }
    ```

    ## App Group Setup:
    1. Create App Group: group.app.thea
    2. Enable App Groups in both main app and extension
    3. Use shared UserDefaults for communication

    ## Info.plist for Intent Extension:
    Add NSExtension with:
    - NSExtensionPointIdentifier: com.apple.intents-service
    - NSExtensionAttributes:
      - IntentsSupported: [INShareFocusStatusIntent]
    """
}

// MARK: - Mac Companion Communication

/// Communication with Mac companion for cross-device automation
public struct MacCompanionBridge {

    /// Commands that can be sent to Mac companion
    public enum MacCommand: String, Sendable {
        case sendMessage = "send_message"
        case updateStatus = "update_status"
        case checkFocus = "check_focus"
        case syncContacts = "sync_contacts"
    }

    /// Send command to Mac companion via Handoff/Continuity
    public static func sendToMac(command: MacCommand, payload: [String: Any]) async {
        // This would use:
        // 1. Bonjour/Network framework for local network communication
        // 2. CloudKit for iCloud-based sync
        // 3. Handoff/Continuity for direct device communication

        print("[MacBridge] Sending \(command.rawValue) to Mac: \(payload)")
    }

    /// Request Mac to send iMessage (bypasses iOS limitations)
    public static func requestMacSendMessage(to phoneNumber: String, message: String) async -> Bool {
        await sendToMac(command: .sendMessage, payload: [
            "to": phoneNumber,
            "message": message,
            "platform": "imessage"
        ])
        return true
    }
}
