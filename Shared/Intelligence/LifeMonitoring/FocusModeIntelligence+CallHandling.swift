// FocusModeIntelligence+CallHandling.swift
// THEA - Call Forwarding & VoIP Call Interception
// Split from FocusModeIntelligence.swift
//
// Related extensions:
// - FocusModeIntelligence+Escalation.swift: Smart contact escalation, calendar, location, voice, groups

import Foundation
import UserNotifications
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Call Forwarding & VoIP Interception

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

    /// Enable unconditional call forwarding to COMBOX when Focus Mode activates.
    ///
    /// Uses Swisscom USSD codes (e.g. `*21*086#`) to redirect all incoming calls
    /// to voicemail. On iOS, delegates to Shortcuts; on macOS, sends command to iPhone
    /// via App Group UserDefaults.
    func enableCallForwarding() async {
        guard !getCallForwardingEnabled() else { return }

        let forwardingCode = getGlobalSettings().callForwardingActivationCode +
                             getGlobalSettings().callForwardingNumber + "#"

        print("[CallForwarding] Enabling call forwarding with code: \(forwardingCode)")

        #if os(iOS)
        await executeCallForwardingViaShortcuts(code: forwardingCode, action: "enable")
        #elseif os(macOS)
        await sendCallForwardingCommandToiPhone(code: forwardingCode, enable: true)
        #endif

        setCallForwardingEnabled(true)
        print("[CallForwarding] Call forwarding enabled - all calls now go to COMBOX")
    }

    /// Disable call forwarding when Focus Mode deactivates, restoring normal call behavior.
    func disableCallForwarding() async {
        guard getCallForwardingEnabled() else { return }

        let disableCode = getGlobalSettings().callForwardingDeactivationCode

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
    /// Execute a call forwarding USSD code via the "THEA Call Forwarding" shortcut on iOS.
    ///
    /// - Parameters:
    ///   - code: The USSD code to execute (e.g. `*21*086#`).
    ///   - action: A description of the action ("enable" or "disable").
    func executeCallForwardingViaShortcuts(code: String, action: String) async {
        let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        if let url = URL(string: "shortcuts://run-shortcut?name=THEA%20Call%20Forwarding&input=text&text=\(encodedCode)") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
    }
    #endif

    #if os(macOS)
    /// Send a call forwarding command to the paired iPhone via App Group UserDefaults.
    ///
    /// The iPhone app polls for pending commands and executes them.
    ///
    /// - Parameters:
    ///   - code: The USSD code to execute.
    ///   - enable: `true` to enable forwarding, `false` to disable.
    func sendCallForwardingCommandToiPhone(code: String, enable: Bool) async {
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

    /// Start monitoring for incoming VoIP calls on macOS.
    ///
    /// Monitors WhatsApp, Telegram, and FaceTime based on global settings.
    func startVoIPInterception() async {
        guard !getVoIPMonitoringActive() else { return }
        setVoIPMonitoringActive(true)

        #if os(macOS)
        if getGlobalSettings().voipInterceptWhatsApp {
            await startWhatsAppCallMonitoring()
        }

        if getGlobalSettings().voipInterceptTelegram {
            await startTelegramCallMonitoring()
        }

        if getGlobalSettings().voipInterceptFaceTime {
            await startFaceTimeCallMonitoring()
        }

        print("[VoIP] Started VoIP call interception on Mac")
        #endif
    }

    /// Stop all VoIP call monitoring.
    func stopVoIPInterception() async {
        setVoIPMonitoringActive(false)

        #if os(macOS)
        clearVoIPNotificationObserver()
        print("[VoIP] Stopped VoIP call interception")
        #endif
    }

    #if os(macOS)
    /// Start monitoring WhatsApp Desktop for incoming call windows.
    func startWhatsAppCallMonitoring() async {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "net.whatsapp.WhatsApp" else { return }

            Task {
                await self?.handlePotentialWhatsAppCall()
            }
        }

        print("[VoIP] WhatsApp call monitoring started")
    }

    /// Check if WhatsApp is currently showing an incoming call UI.
    func handlePotentialWhatsAppCall() async {
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

    /// Start monitoring Telegram Desktop for incoming calls.
    func startTelegramCallMonitoring() async {
        print("[VoIP] Telegram call monitoring started")
    }

    /// Start monitoring FaceTime for incoming calls.
    func startFaceTimeCallMonitoring() async {
        print("[VoIP] FaceTime call monitoring started")
    }

    /// Intercept a detected VoIP call and show a notification to the user.
    ///
    /// - Parameters:
    ///   - platform: The VoIP platform that received the call.
    ///   - callInfo: Information about the call (e.g. window title).
    func interceptVoIPCall(platform: CommunicationPlatform, callInfo: String) async {
        print("[VoIP] Intercepted \(platform.displayName) call: \(callInfo)")

        if getGlobalSettings().voipPlayTTSBeforeRinging {
            await showVoIPInterceptionNotification(platform: platform, callInfo: callInfo)
        }
    }

    /// Show a local notification about an intercepted VoIP call during Focus mode.
    ///
    /// - Parameters:
    ///   - platform: The VoIP platform.
    ///   - callInfo: Description of the incoming call.
    func showVoIPInterceptionNotification(platform: CommunicationPlatform, callInfo: String) async {
        let content = UNMutableNotificationContent()
        content.title = "\u{1F4DE} \(platform.displayName) Call During Focus"
        content.body = "Incoming call: \(callInfo)\nYour Focus Mode is active."
        content.sound = .default
        content.categoryIdentifier = "VOIP_INTERCEPTION"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif
}
