// FocusModeIntelligence+EventHandlers.swift
// THEA - Focus Mode Activation/Deactivation Event Handlers
// Split from FocusModeIntelligence.swift

import Foundation

// MARK: - Focus Mode Event Handlers

extension FocusModeIntelligence {

    // MARK: - Activation

    /// Handle Focus mode activation — enables call forwarding, status sync,
    /// VoIP interception, and cross-device sync.
    ///
    /// Called when a Focus mode transitions from inactive to active. Orchestrates
    /// all side effects: carrier call forwarding, WhatsApp/Telegram status updates,
    /// COMBOX greeting changes, VoIP monitoring, and iPhone notification.
    ///
    /// - Parameter mode: The Focus mode configuration that was just activated.
    func handleFocusModeActivated(_ mode: FocusModeConfiguration) async {
        print("[FocusMode] Activated: \(mode.name)")

        // CRITICAL: CALL FORWARDING WORKAROUND
        // iOS Focus Mode rejects calls at network level (3-tone disconnect)
        // Solution: Enable call forwarding to COMBOX BEFORE iOS can reject

        let settings = getGlobalSettings()

        if settings.useCallForwardingWorkaround {
            let modeBlocksCalls = mode.allowCallsFrom != .everyone

            if modeBlocksCalls {
                await enableCallForwarding()
                print("[FocusMode] Call forwarding enabled - mode '\(mode.name)' blocks some calls")
            } else {
                print("[FocusMode] Call forwarding NOT needed - mode '\(mode.name)' allows all calls")
            }
        }

        // 1. Update WhatsApp status
        if settings.whatsAppStatusSyncEnabled && mode.theaSettings.whatsAppStatusEnabled {
            await updateWhatsAppStatus(mode.theaSettings.whatsAppStatusMessage)
        }

        // 2. Update Telegram status
        if settings.telegramStatusSyncEnabled && mode.theaSettings.telegramStatusEnabled {
            await updateTelegramStatus(mode.theaSettings.telegramStatusMessage)
        }

        // 3. Switch COMBOX greeting (now even more important since calls go there)
        if settings.comboxIntegrationEnabled && settings.comboxSwitchGreetingOnFocus {
            if let greeting = mode.theaSettings.comboxGreetingType {
                await switchComboxGreeting(to: greeting)
            } else {
                await switchComboxGreeting(to: settings.comboxFocusGreeting)
            }
        }

        // 4. Start VoIP call interception
        if settings.voipInterceptionEnabled {
            await startVoIPInterception()
        }

        // 5. Sync to iPhone
        await notifyiPhoneOfFocusChange(active: true, mode: mode)
    }

    // MARK: - Deactivation

    /// Handle Focus mode deactivation — reverts all changes made during activation.
    ///
    /// Disables call forwarding, reverts messaging statuses, stops VoIP interception,
    /// processes pending callbacks, applies session learning, and syncs state to iPhone.
    ///
    /// - Parameter mode: The Focus mode configuration that was just deactivated.
    func handleFocusModeDeactivated(_ mode: FocusModeConfiguration) async {
        print("[FocusMode] Deactivated: \(mode.name)")

        let settings = getGlobalSettings()

        // CRITICAL: DISABLE CALL FORWARDING
        if settings.useCallForwardingWorkaround && getCallForwardingEnabled() {
            await disableCallForwarding()
        }

        // 1. Revert WhatsApp status
        if settings.whatsAppStatusSyncEnabled && settings.preservePreviousWhatsAppStatus {
            await revertWhatsAppStatus()
        }

        // 2. Revert Telegram status
        if settings.telegramStatusSyncEnabled {
            await clearTelegramStatus()
        }

        // 3. Revert COMBOX greeting
        if settings.comboxIntegrationEnabled && settings.comboxSwitchGreetingOnFocus {
            await switchComboxGreeting(to: settings.comboxDefaultGreeting)
        }

        // 4. Stop VoIP interception
        if settings.voipInterceptionEnabled {
            await stopVoIPInterception()
        }

        // 5. Process pending callbacks
        await processPendingCallbacks()

        // 6. Apply learning from this Focus session
        if settings.learningEnabled {
            await applyLearningFromSession(mode: mode)
        }

        // 7. Sync to iPhone
        await notifyiPhoneOfFocusChange(active: false, mode: mode)
    }
}
