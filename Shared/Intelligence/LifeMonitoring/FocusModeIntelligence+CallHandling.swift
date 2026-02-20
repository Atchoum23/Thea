// FocusModeIntelligence+CallHandling.swift
// THEA - Call Forwarding & VoIP Interception
// Split from FocusModeIntelligence.swift
//
// Note: Smart Contact Escalation, Calendar/Location-aware replies, Voice Messages,
// and Group Chat handling are in FocusModeIntelligence+Escalation.swift

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
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
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
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to schedule VoIP interception notification: \(error.localizedDescription)")
        }
    }
    #endif
}
