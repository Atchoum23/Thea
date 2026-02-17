// FocusModeIntelligence+Configuration.swift
// THEA - Public Configuration API
// Split from FocusModeIntelligence.swift

import Foundation

// MARK: - Public Configuration API

extension FocusModeIntelligence {

    // MARK: - Callback Registration

    /// Configure event callbacks for Focus Mode state changes.
    ///
    /// Register handlers that fire when focus mode transitions occur,
    /// auto-replies are sent, or urgent/emergency communications arrive.
    ///
    /// - Parameters:
    ///   - onFocusModeChanged: Called when the active focus mode changes (or deactivates with `nil`).
    ///   - onAutoReplySent: Called after an auto-reply is successfully sent, with the communication and message text.
    ///   - onUrgentDetected: Called when a contact confirms their message is urgent.
    ///   - onEmergencyDetected: Called when emergency keywords are detected in a message.
    ///   - onSettingsChanged: Called when global settings are updated.
    public func configure(
        onFocusModeChanged: @escaping @Sendable (FocusModeConfiguration?) -> Void,
        onAutoReplySent: @escaping @Sendable (IncomingCommunication, String) -> Void,
        onUrgentDetected: @escaping @Sendable (IncomingCommunication) -> Void,
        onEmergencyDetected: @escaping @Sendable (IncomingCommunication) -> Void,
        onSettingsChanged: @escaping @Sendable (FocusModeGlobalSettings) -> Void
    ) {
        self.setOnFocusModeChanged(onFocusModeChanged)
        self.setOnAutoReplySent(onAutoReplySent)
        self.setOnUrgentDetected(onUrgentDetected)
        self.setOnEmergencyDetected(onEmergencyDetected)
        self.setOnSettingsChanged(onSettingsChanged)
    }

    // MARK: - Settings Management

    /// Update the global Focus Mode settings and notify observers.
    ///
    /// Persists settings to shared UserDefaults and syncs to iPhone.
    ///
    /// - Parameter settings: The new global settings to apply.
    public func updateSettings(_ settings: FocusModeGlobalSettings) {
        self.setGlobalSettings(settings)
        notifySettingsChanged(settings)

        Task {
            await saveSettings()
            await syncSettingsToiPhone()
        }
    }

    /// Returns the current global Focus Mode settings.
    ///
    /// - Returns: The active `FocusModeGlobalSettings` instance.
    public func getSettings() -> FocusModeGlobalSettings {
        getGlobalSettings()
    }

    /// Update THEA-specific settings for a particular Focus mode.
    ///
    /// - Parameters:
    ///   - modeId: The identifier of the Focus mode to update.
    ///   - settings: The new THEA settings to apply to this mode.
    public func updateFocusModeSettings(_ modeId: String, settings: FocusModeConfiguration.TheaFocusSettings) {
        guard var mode = getFocusMode(modeId) else { return }
        mode.theaSettings = settings
        setFocusMode(modeId, mode: mode)

        Task {
            await saveSettings()
        }
    }

    // MARK: - Emergency Contact Management

    /// Add a contact to the emergency contacts list.
    ///
    /// Emergency contacts always ring through, even during active Focus modes.
    ///
    /// - Parameter contactId: The unique identifier of the contact to add.
    public func addEmergencyContact(_ contactId: String) {
        addEmergencyContactInternal(contactId)

        Task {
            await saveSettings()
        }
    }

    /// Remove a contact from the emergency contacts list.
    ///
    /// - Parameter contactId: The unique identifier of the contact to remove.
    public func removeEmergencyContact(_ contactId: String) {
        removeEmergencyContactInternal(contactId)

        Task {
            await saveSettings()
        }
    }

    // MARK: - Contact Language

    /// Manually set the preferred language for a contact.
    ///
    /// Overrides any automatically detected language. Used for auto-reply localization.
    ///
    /// - Parameters:
    ///   - contactId: The unique identifier of the contact.
    ///   - language: A BCP-47 language code (e.g. "en", "fr", "de").
    public func setContactLanguage(_ contactId: String, language: String) {
        setContactLanguageInfo(contactId, info: ContactLanguageInfo(
            contactId: contactId,
            detectedLanguage: language,
            confidence: 1.0,
            detectionMethod: .manualSetting,
            isManuallySet: true,
            previousLanguages: [],
            lastUpdated: Date()
        ))

        Task {
            await saveContactLanguages()
        }
    }
}
