// FocusModeIntelligence+LanguageDetection.swift
// THEA - Language Detection, Urgency Detection, Time-Aware Responses
// Split from FocusModeIntelligence+AutoReply.swift

import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Language Detection, Urgency Detection & Time-Aware Responses

extension FocusModeIntelligence {

    // MARK: - Language Detection

    /// Detect the preferred language for a contact using multiple signals.
    ///
    /// Uses a cascading strategy: cached preference > phone country code >
    /// message content analysis > device locale fallback.
    ///
    /// - Parameters:
    ///   - contactId: The contact's unique identifier for cache lookup.
    ///   - phoneNumber: The phone number for country code detection.
    ///   - messageContent: Message text for keyword-based language analysis.
    /// - Returns: A BCP-47 language code (e.g. "en", "fr", "de").
    func detectLanguage(for contactId: String?, phoneNumber: String?, messageContent: String?) async -> String {
        // Check cached
        if let cId = contactId, let cached = getContactLanguage(cId), cached.confidence > 0.7 {
            return cached.detectedLanguage
        }

        // Try phone number
        if let phone = phoneNumber, let langFromPhone = languageFromPhoneNumber(phone) {
            if let cId = contactId {
                setContactLanguageInfo(cId, info: ContactLanguageInfo(
                    contactId: cId,
                    detectedLanguage: langFromPhone,
                    confidence: 0.7,
                    detectionMethod: .phoneCountryCode,
                    isManuallySet: false,
                    previousLanguages: [],
                    lastUpdated: Date()
                ))
            }
            return langFromPhone
        }

        // Try message content analysis
        if let content = messageContent, !content.isEmpty {
            if let detected = detectLanguageFromText(content) {
                if let cId = contactId {
                    var info = getContactLanguage(cId) ?? ContactLanguageInfo(
                        contactId: cId,
                        detectedLanguage: detected,
                        confidence: 0.6,
                        detectionMethod: .messageHistory,
                        isManuallySet: false,
                        previousLanguages: [],
                        lastUpdated: Date()
                    )
                    info.detectedLanguage = detected
                    info.lastUpdated = Date()
                    setContactLanguageInfo(cId, info: info)
                }
                return detected
            }
        }

        // Default to device locale
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    /// Map a phone number's country code prefix to a likely language.
    ///
    /// - Parameter phoneNumber: The full phone number including country code prefix.
    /// - Returns: A BCP-47 language code, or `nil` if the prefix is unrecognized.
    func languageFromPhoneNumber(_ phoneNumber: String) -> String? {
        let countryCodeToLanguage: [String: String] = [
            "+1": "en", "+44": "en", "+61": "en", "+64": "en",
            "+33": "fr", "+32": "fr", // Belgium - could be fr/nl
            "+41": "de", // Switzerland - could be de/fr/it
            "+49": "de", "+43": "de",
            "+39": "it",
            "+34": "es", "+52": "es", "+54": "es",
            "+351": "pt", "+55": "pt",
            "+31": "nl",
            "+81": "ja",
            "+86": "zh", "+852": "zh", "+886": "zh",
            "+82": "ko",
            "+7": "ru",
            "+966": "ar", "+971": "ar", "+20": "ar"
        ]

        for (code, lang) in countryCodeToLanguage {
            if phoneNumber.hasPrefix(code) {
                return lang
            }
        }

        return nil
    }

    /// Detect language from message text using keyword frequency analysis.
    ///
    /// Scores text against known indicator words for each supported language.
    /// Requires at least 2 matching keywords for a positive detection.
    ///
    /// - Parameter text: The message text to analyze.
    /// - Returns: A BCP-47 language code, or `nil` if no language scored high enough.
    func detectLanguageFromText(_ text: String) -> String? {
        let languageIndicators: [String: [String]] = [
            "fr": ["bonjour", "merci", "salut", "oui", "non", "comment", "pourquoi", "c'est", "je", "tu"],
            "de": ["hallo", "danke", "guten", "bitte", "ja", "nein", "wie", "warum", "ich", "du", "ist"],
            "it": ["ciao", "grazie", "buongiorno", "si\u{300}", "no", "come", "perche\u{301}", "sono", "tu", "e\u{300}"],
            "es": ["hola", "gracias", "buenos", "si\u{301}", "no", "co\u{301}mo", "por que\u{301}", "soy", "tu\u{301}", "es"],
            "pt": ["ola\u{301}", "obrigado", "bom dia", "sim", "na\u{303}o", "como", "por que", "sou", "tu", "e\u{301}"],
            "nl": ["hallo", "dank", "goedemorgen", "ja", "nee", "hoe", "waarom", "ik", "jij", "is"]
        ]

        let lowercased = text.lowercased()

        var scores: [String: Int] = [:]
        for (lang, indicators) in languageIndicators {
            for indicator in indicators {
                if lowercased.contains(indicator) {
                    scores[lang, default: 0] += 1
                }
            }
        }

        if let (lang, score) = scores.max(by: { $0.value < $1.value }), score >= 2 {
            return lang
        }

        return nil
    }

    // MARK: - Urgency Detection

    /// Detect the urgency level of a message using template-based keyword matching.
    ///
    /// Checks emergency keywords first (returns `.emergency`), then urgent keywords
    /// (returns `.urgent`), and falls back to `.unknown`.
    ///
    /// - Parameters:
    ///   - message: The message text to analyze.
    ///   - language: The BCP-47 language code for template selection.
    /// - Returns: The detected urgency level.
    func detectUrgency(in message: String, language: String) -> IncomingCommunication.UrgencyLevel {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased()

        for keyword in templates.emergencyKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return .emergency
            }
        }

        for keyword in templates.yesKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return .urgent
            }
        }

        return .unknown
    }

    /// Check if a message contains emergency keywords.
    ///
    /// - Parameters:
    ///   - message: The message text to scan.
    ///   - language: The BCP-47 language code for template selection.
    /// - Returns: `true` if any emergency keyword is found.
    func detectEmergency(in message: String, language: String) -> Bool {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased()

        for keyword in templates.emergencyKeywords {
            if lowercased.contains(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    /// Check if a message is an affirmative response (e.g. "yes", "oui", "ja").
    ///
    /// - Parameters:
    ///   - message: The response text to check.
    ///   - language: The BCP-47 language code for template selection.
    /// - Returns: `true` if the message matches an affirmative keyword.
    func isAffirmativeResponse(_ message: String, language: String) -> Bool {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for keyword in templates.yesKeywords {
            if lowercased == keyword.lowercased() || lowercased.hasPrefix(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    /// Check if a message is a negative response (e.g. "no", "non", "nein").
    ///
    /// - Parameters:
    ///   - message: The response text to check.
    ///   - language: The BCP-47 language code for template selection.
    /// - Returns: `true` if the message matches a negative keyword.
    func isNegativeResponse(_ message: String, language: String) -> Bool {
        let templates = getMessageTemplates().urgentResponse[language] ?? getMessageTemplates().urgentResponse["en"]!
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        for keyword in templates.noKeywords {
            if lowercased == keyword.lowercased() || lowercased.hasPrefix(keyword.lowercased()) {
                return true
            }
        }

        return false
    }

    // MARK: - Time-Aware Responses

    /// Generate a localized availability message based on the active Focus mode's schedule.
    ///
    /// Reads the schedule end time and formats it into a human-readable string
    /// like "I should be available around 5:00 PM."
    ///
    /// - Parameter language: The BCP-47 language code for localization.
    /// - Returns: A localized availability string, or `nil` if no schedule information is available.
    func getAvailabilityInfo(language: String) -> String? {
        guard let mode = getCurrentFocusMode() else { return nil }

        for schedule in mode.schedules where schedule.enabled {
            let calendar = Calendar.current
            let now = Date()

            if let endHour = schedule.endTime.hour,
               let endMinute = schedule.endTime.minute {
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = endHour
                components.minute = endMinute

                if let endTime = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    formatter.locale = Locale(identifier: language)

                    let timeString = formatter.string(from: endTime)

                    let availabilityMessages: [String: String] = [
                        "en": "I should be available around \(timeString).",
                        "fr": "Je devrais \u{00EA}tre disponible vers \(timeString).",
                        "de": "Ich sollte gegen \(timeString) verf\u{00FC}gbar sein.",
                        "it": "Dovrei essere disponibile verso le \(timeString).",
                        "es": "Deber\u{00ED}a estar disponible alrededor de las \(timeString)."
                    ]

                    return availabilityMessages[language] ?? availabilityMessages["en"]
                }
            }
        }

        return nil
    }

    // MARK: - Callback System

    /// Initiate a callback to a phone number via the appropriate platform.
    ///
    /// On iOS, opens the phone dialer. On macOS, opens FaceTime.
    ///
    /// - Parameters:
    ///   - phoneNumber: The phone number to call back.
    ///   - reason: A description of why the callback was initiated.
    func initiateCallback(to phoneNumber: String, reason: String) async {
        #if os(iOS)
        if let url = URL(string: "tel://\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
        #elseif os(macOS)
        if let url = URL(string: "facetime://\(phoneNumber)") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    /// Process all pending callbacks that have not yet been completed.
    func processPendingCallbacks() async {
        for callback in getPendingCallbacks() where !callback.completed {
            print("[FocusMode] Pending callback to \(callback.phoneNumber): \(callback.reason)")
        }
    }
}
