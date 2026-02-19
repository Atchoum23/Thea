// FocusModeIntelligence+VIP.swift
// THEA - VIP contact management and personalized messaging
// Split from FocusModeIntelligence+Learning.swift

import Foundation

// MARK: - VIP Mode

extension FocusModeIntelligence {

    // VIP contacts get special treatment:
    // - Custom personalized messages
    // - Always ring through (optional)
    // - Higher priority in callbacks

    /// Check whether a contact is in the VIP list.
    ///
    /// - Parameter contactId: The contact identifier to look up.
    /// - Returns: `true` if the contact is a VIP.
    public func isVIPContact(_ contactId: String) -> Bool {
        getGlobalSettings().vipContacts.contains(contactId)
    }

    /// Add a contact to the VIP list with an optional custom auto-reply message.
    ///
    /// - Parameters:
    ///   - contactId: The contact identifier to add.
    ///   - customMessage: An optional personalized message for this VIP. If `nil`, the default VIP message is used.
    public func addVIPContact(_ contactId: String, customMessage: String? = nil) {
        var settings = getGlobalSettings()
        if !settings.vipContacts.contains(contactId) {
            settings.vipContacts.append(contactId)
        }
        if let message = customMessage {
            settings.vipCustomMessages[contactId] = message
        }
        setGlobalSettings(settings)

        Task {
            await saveSettings()
        }
    }

    /// Remove a contact from the VIP list and delete their custom message.
    ///
    /// - Parameter contactId: The contact identifier to remove.
    public func removeVIPContact(_ contactId: String) {
        var settings = getGlobalSettings()
        settings.vipContacts.removeAll { $0 == contactId }
        settings.vipCustomMessages.removeValue(forKey: contactId)
        setGlobalSettings(settings)

        Task {
            await saveSettings()
        }
    }

    // periphery:ignore - Reserved: getVIPMessage(for:language:) instance method reserved for future feature activation
    /// Retrieve the auto-reply message for a VIP contact.
    ///
    /// Returns the custom message if one is set, otherwise a localized default VIP message.
    ///
    /// - Parameters:
    ///   - contactId: The VIP contact identifier.
    ///   - language: The BCP-47 language code for the default message.
    /// - Returns: The VIP message string, or `nil` if the contact is not a VIP.
    func getVIPMessage(for contactId: String, language: String) -> String? {
        guard isVIPContact(contactId) else { return nil }

        // Check for custom message first
        if let custom = getGlobalSettings().vipCustomMessages[contactId] {
            return custom
        }

        // Return a VIP-specific default
        let vipMessages: [String: String] = [
            "en": "Hi! I'm currently in Focus Mode but saw it's you. Is this something that can't wait?",
            "de": "Hallo! Ich bin gerade im Fokus-Modus, aber ich sehe, dass du es bist. Kann das nicht warten?",
            "fr": "Salut! Je suis en mode Concentration mais j'ai vu que c'\u{00E9}tait toi. C'est quelque chose qui ne peut pas attendre?",
            "it": "Ciao! Sono in modalit\u{00E0} Focus ma ho visto che sei tu. \u{00C8} qualcosa che non pu\u{00F2} aspettare?"
        ]

        return vipMessages[language] ?? vipMessages["en"]
    }
}
