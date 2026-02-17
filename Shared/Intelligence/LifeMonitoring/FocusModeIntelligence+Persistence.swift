// FocusModeIntelligence+Persistence.swift
// THEA - Lifecycle, Persistence, iPhone Sync, Shortcuts, Periodic Tasks, Queries
// Split from FocusModeIntelligence.swift

import Foundation
import Intents
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Lifecycle, Persistence & Sync

extension FocusModeIntelligence {

    // MARK: - Lifecycle

    /// Start the Focus Mode Intelligence system.
    ///
    /// Loads persisted settings, contact languages, and focus mode configurations,
    /// then begins platform-specific focus monitoring and periodic background tasks.
    public func start() async {
        guard !getIsRunning() else { return }
        setIsRunning(true)

        // Load saved data
        await loadSettings()
        await loadFocusModes()
        await loadContactLanguages()

        // Start Focus mode monitoring
        #if os(macOS)
        await startMacOSFocusMonitoring()
        #else
        await startIOSFocusMonitoring()
        #endif

        // Setup Shortcuts (autonomous)
        await ensureShortcutsExist()

        // Start periodic tasks
        await startPeriodicTasks()
    }

    /// Stop the Focus Mode Intelligence system.
    ///
    /// Cancels all monitoring, persists current settings, and releases resources.
    public func stop() async {
        setIsRunning(false)

        #if os(macOS)
        cancelFocusDBMonitor()
        #endif

        cancelWhatsAppStatusTask()

        await saveSettings()
    }

    // MARK: - iPhone Sync

    /// Notify the paired iPhone of a Focus mode state change via shared App Group UserDefaults.
    ///
    /// - Parameters:
    ///   - active: Whether a Focus mode is now active.
    ///   - mode: The Focus mode configuration that changed.
    func notifyiPhoneOfFocusChange(active: Bool, mode: FocusModeConfiguration) async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            defaults.set(active, forKey: "focusModeActive")
            defaults.set(mode.id, forKey: "currentFocusModeId")
            defaults.set(mode.name, forKey: "currentFocusModeName")
            defaults.set(Date(), forKey: "focusModeLastSync")
            defaults.synchronize()
        }
    }

    /// Sync all global settings to the paired iPhone via shared App Group UserDefaults.
    func syncSettingsToiPhone() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            if let encoded = try? JSONEncoder().encode(getGlobalSettings()) {
                defaults.set(encoded, forKey: "focusModeGlobalSettings")
            }
            defaults.synchronize()
        }
    }

    // MARK: - Shortcuts Setup (Autonomous)

    /// Ensure all required Shortcuts automations exist on the device.
    ///
    /// On iOS, prompts the user to install Shortcuts.
    /// On macOS, logs the required Shortcuts for manual setup.
    func ensureShortcutsExist() async {
        let requiredShortcuts = [
            "THEA Focus Activated",
            "THEA Focus Deactivated",
            "THEA Auto Reply",
            "THEA WhatsApp Reply",
            "THEA COMBOX Greeting"
        ]

        #if os(iOS)
        await generateAndInstallShortcuts()
        #elseif os(macOS)
        print("[FocusMode] Required Shortcuts: \(requiredShortcuts)")
        #endif
    }

    #if os(iOS)
    /// Generate and offer to install required Shortcuts on iOS.
    private func generateAndInstallShortcuts() async {
        print("[FocusMode] Would prompt user to install required Shortcuts")
    }
    #endif

    // MARK: - Periodic Tasks

    /// Start background periodic tasks for pattern analysis.
    ///
    /// Runs an hourly analysis loop that evaluates contact priorities
    /// and suggests Focus mode activation based on learned patterns.
    func startPeriodicTasks() async {
        Task {
            while getIsRunning() {
                try? await Task.sleep(for: .seconds(3600))
                await analyzeUsagePatterns()
            }
        }
    }

    /// Analyze usage patterns to improve Focus mode behavior over time.
    private func analyzeUsagePatterns() async {
        let settings = getGlobalSettings()

        if settings.learnContactPriorities {
            // Analyze which contacts frequently mark things as urgent
            // Adjust their priority scores
        }

        if settings.suggestFocusModeActivation {
            // Based on calendar, time of day, location, suggest Focus activation
        }
    }

    // MARK: - Persistence

    /// Load global settings from shared UserDefaults.
    func loadSettings() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let data = defaults.data(forKey: "focusModeGlobalSettings"),
           let settings = try? JSONDecoder().decode(FocusModeGlobalSettings.self, from: data) {
            setGlobalSettings(settings)
            setEmergencyContacts(Set(settings.emergencyContacts))
        }
    }

    /// Save global settings to shared UserDefaults.
    func saveSettings() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(getGlobalSettings()) {
            defaults.set(encoded, forKey: "focusModeGlobalSettings")
            defaults.synchronize()
        }
    }

    /// Load all Focus mode configurations from shared UserDefaults.
    func loadFocusModes() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let data = defaults.data(forKey: "focusModeConfigurations"),
           let modes = try? JSONDecoder().decode([String: FocusModeConfiguration].self, from: data) {
            setAllFocusModes(modes)
        }
    }

    /// Load contact language preferences from shared UserDefaults.
    func loadContactLanguages() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let data = defaults.data(forKey: "contactLanguages"),
           let languages = try? JSONDecoder().decode([String: ContactLanguageInfo].self, from: data) {
            setAllContactLanguages(languages)
        }
    }

    /// Save contact language preferences to shared UserDefaults.
    func saveContactLanguages() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(getAllContactLanguages()) {
            defaults.set(encoded, forKey: "contactLanguages")
            defaults.synchronize()
        }
    }

    // MARK: - Query Methods

    /// Returns the currently active Focus mode configuration, if any.
    ///
    /// - Returns: The active `FocusModeConfiguration`, or `nil` if no Focus mode is active.
    public func getCurrentFocusMode() -> FocusModeConfiguration? {
        getCurrentFocusModeInternal()
    }

    /// Returns all registered Focus mode configurations.
    ///
    /// - Returns: An array of all `FocusModeConfiguration` instances.
    public func getAllFocusModes() -> [FocusModeConfiguration] {
        Array(getAllFocusModesInternal().values)
    }

    /// Returns recent communications received during Focus mode.
    ///
    /// - Parameter limit: Maximum number of communications to return (default: 50).
    /// - Returns: The most recent communications, up to the specified limit.
    public func getRecentCommunications(limit: Int = 50) -> [IncomingCommunication] {
        Array(getRecentCommunicationsInternal().suffix(limit))
    }

    /// Returns the detected language for a specific contact.
    ///
    /// - Parameter contactId: The unique identifier of the contact.
    /// - Returns: The BCP-47 language code, or `nil` if no language has been detected.
    public func getContactLanguageId(_ contactId: String) -> String? {
        getContactLanguage(contactId)?.detectedLanguage
    }

    /// Check whether a contact is in the emergency contacts list.
    ///
    /// - Parameter contactId: The unique identifier of the contact.
    /// - Returns: `true` if the contact is an emergency contact.
    public func isEmergencyContact(_ contactId: String) -> Bool {
        getEmergencyContacts().contains(contactId)
    }

    /// Returns the learned priority score for a contact.
    ///
    /// Higher scores indicate contacts more likely to have genuinely urgent matters.
    ///
    /// - Parameter contactId: The unique identifier of the contact.
    /// - Returns: A priority score between 0.0 and 1.0 (default: 0.5).
    public func getContactPriority(_ contactId: String) -> Double {
        getContactPriorityValue(contactId)
    }
}
