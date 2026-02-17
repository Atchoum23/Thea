// FocusModeIntelligence+StatusSync.swift
// THEA - WhatsApp, Telegram & COMBOX Status Synchronization
// Split from FocusModeIntelligence+AutoReply.swift

import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Messaging Platform Status Sync

extension FocusModeIntelligence {

    // MARK: - WhatsApp Status Management

    /// Update the WhatsApp Desktop status message via AppleScript UI automation.
    ///
    /// Saves the previous status before overwriting so it can be reverted
    /// when Focus mode deactivates.
    ///
    /// - Parameter status: The new status text to set.
    func updateWhatsAppStatus(_ status: String) async {
        #if os(macOS)
        setPreviousWhatsAppStatus(await getCurrentWhatsAppStatus())

        let escapedStatus = status.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "WhatsApp" to activate
        delay 0.5
        tell application "System Events"
            tell process "WhatsApp"
                keystroke "," using command down
                delay 0.5
                -- Click profile area to edit status
                click static text 1 of group 1 of scroll area 1 of window 1
                delay 0.3
                keystroke "a" using command down
                keystroke "\(escapedStatus)"
                delay 0.1
                key code 36
            end tell
        end tell
        """
        _ = await runAppleScript(script)
        #endif
    }

    /// Revert WhatsApp status to the value saved before Focus mode activated.
    func revertWhatsAppStatus() async {
        if let previous = getPreviousWhatsAppStatus() {
            await updateWhatsAppStatus(previous)
            setPreviousWhatsAppStatus(nil)
        }
    }

    /// Read the current WhatsApp Desktop status via AppleScript UI inspection.
    ///
    /// - Returns: The current status text, or `nil` if WhatsApp is not running or inaccessible.
    func getCurrentWhatsAppStatus() async -> String? {
        #if os(macOS)
        return await runAppleScriptReturning("""
        tell application "System Events"
            if exists (process "WhatsApp") then
                tell process "WhatsApp"
                    try
                        return description of static text 1 of group 1 of toolbar 1 of window 1
                    end try
                end tell
            end if
        end tell
        return ""
        """)
        #else
        return nil
        #endif
    }

    // MARK: - Telegram Status Management

    /// Update Telegram status message.
    ///
    /// - Parameter status: The new status text to set.
    func updateTelegramStatus(_ status: String) async {
        print("[Telegram] Would update status to: \(status)")
    }

    /// Clear the Telegram status message.
    func clearTelegramStatus() async {
        print("[Telegram] Would clear status")
    }

    // MARK: - COMBOX Integration

    /// Switch the Swisscom COMBOX voicemail greeting.
    ///
    /// Changes the greeting type by triggering a Shortcuts automation that
    /// calls 086 and navigates the DTMF menu. On iOS, opens the shortcut
    /// directly; on macOS, would need to relay to iPhone.
    ///
    /// - Parameter greetingType: The greeting type identifier to switch to.
    func switchComboxGreeting(to greetingType: String) async {
        print("[COMBOX] Would switch greeting to: \(greetingType)")

        #if os(iOS)
        if let url = URL(string: "shortcuts://run-shortcut?name=THEA%20COMBOX%20Greeting&input=text&text=\(greetingType)") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }
}
