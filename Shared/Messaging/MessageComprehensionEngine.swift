// MsgComprehensionEngine.swift
// Thea — AI-powered message understanding
//
// Analyzes incoming messages to extract intent, urgency, entities,
// sentiment, and suggested actions. Uses heuristic analysis with
// pattern matching — no external API calls (privacy-first).

import Foundation
import OSLog

private let msgComprehensionLogger = Logger(subsystem: "ai.thea.app", category: "MessageComprehension")

/// Analyzes messages to extract structured understanding.
enum MsgComprehensionEngine {

    // MARK: - Main Analysis

    /// Analyze a unified message and return comprehension result.
    static func analyze(_ message: UnifiedMessage) -> MsgComprehension {
        let content = message.content
        let intent = detectIntent(content)
        let urgency = detectUrgency(content)
        let action = detectAction(content, intent: intent)
        let entities = extractEntities(content)
        let sentiment = detectSentiment(content)
        let summary = generateSummary(content)
        let suggestedResponse = generateSuggestedResponse(intent: intent, content: content)

        return MsgComprehension(
            intent: intent,
            urgency: urgency,
            requiredAction: action,
            entities: entities,
            sentiment: sentiment,
            summary: summary,
            suggestedResponse: suggestedResponse
        )
    }

    // MARK: - Intent Detection

    static func detectIntent(_ text: String) -> MsgIntent {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Question markers
        if lower.hasSuffix("?") || lower.hasPrefix("can you") || lower.hasPrefix("could you") ||
           lower.hasPrefix("would you") || lower.hasPrefix("what") || lower.hasPrefix("when") ||
           lower.hasPrefix("where") || lower.hasPrefix("who") || lower.hasPrefix("how") ||
           lower.hasPrefix("why") || lower.hasPrefix("is it") || lower.hasPrefix("are you") ||
           lower.hasPrefix("do you") || lower.hasPrefix("est-ce") || lower.hasPrefix("qu'est") ||
           lower.hasPrefix("quand") || lower.hasPrefix("comment") || lower.hasPrefix("pourquoi") {
            return .question
        }

        // Urgent signals
        let urgentPatterns = ["urgent", "asap", "immediately", "emergency", "critical",
                              "right now", "right away", "tout de suite", "immédiatement",
                              "dringend", "sofort", "срочно"]
        if urgentPatterns.contains(where: { lower.contains($0) }) {
            return .urgent
        }

        // Scheduling
        let schedulePatterns = ["meeting", "appointment", "schedule", "calendar",
                                "let's meet", "available", "free on", "rendez-vous",
                                "réunion", "termin", "treffen"]
        if schedulePatterns.contains(where: { lower.contains($0) }) {
            return .scheduling
        }

        // Request patterns
        let requestPatterns = ["please", "could you", "can you", "i need", "send me",
                               "help me", "s'il vous plaît", "s'il te plaît", "bitte",
                               "пожалуйста", "would you mind"]
        if requestPatterns.contains(where: { lower.contains($0) }) {
            return .request
        }

        // Complaint
        let complaintPatterns = ["not working", "broken", "issue", "problem", "bug",
                                 "complaint", "disappointed", "frustrated", "ne marche pas",
                                 "funktioniert nicht", "не работает"]
        if complaintPatterns.contains(where: { lower.contains($0) }) {
            return .complaint
        }

        // Greeting
        let greetingPatterns = ["hello", "hi ", "hey ", "good morning", "good afternoon",
                                "good evening", "bonjour", "bonsoir", "salut",
                                "hallo", "guten tag", "привет", "здравствуйте"]
        if greetingPatterns.contains(where: { lower.hasPrefix($0) || lower == $0.trimmingCharacters(in: .whitespaces) }) {
            return .socialGreeting
        }

        // Confirmation
        let confirmPatterns = ["ok", "okay", "sure", "yes", "confirmed", "agreed",
                               "sounds good", "perfect", "great", "d'accord", "oui",
                               "einverstanden", "ja", "da", "да", "хорошо"]
        if confirmPatterns.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") || lower.hasPrefix($0 + ",") || lower.hasPrefix($0 + "!") }) {
            return .confirmation
        }

        // Follow-up
        let followUpPatterns = ["following up", "any update", "just checking", "reminder",
                                "circling back", "as discussed", "re:", "relance",
                                "nachfrage", "noch mal"]
        if followUpPatterns.contains(where: { lower.contains($0) }) {
            return .followUp
        }

        return .informational
    }

    // MARK: - Urgency Detection

    static func detectUrgency(_ text: String) -> MsgUrgency {
        let lower = text.lowercased()

        let criticalPatterns = ["emergency", "critical", "life or death",
                                "urgence", "notfall", "экстренно"]
        if criticalPatterns.contains(where: { lower.contains($0) }) {
            return .critical
        }

        let highPatterns = ["urgent", "asap", "immediately", "right now",
                            "deadline today", "due today", "срочно",
                            "tout de suite", "sofort", "dringend"]
        if highPatterns.contains(where: { lower.contains($0) }) {
            return .high
        }

        let lowPatterns = ["no rush", "whenever", "when you can", "low priority",
                           "pas urgent", "quand tu peux", "keine eile",
                           "не срочно"]
        if lowPatterns.contains(where: { lower.contains($0) }) {
            return .low
        }

        return .normal
    }

    // MARK: - Action Detection

    static func detectAction(_ text: String, intent: MsgIntent) -> MsgAction? {
        let lower = text.lowercased()

        // Calendar/meeting detection
        if intent == .scheduling || lower.contains("meet") || lower.contains("calendar") ||
           lower.contains("rendez-vous") || lower.contains("termin") {
            return .createCalendarEvent
        }

        // Payment detection
        let paymentPatterns = ["pay", "invoice", "bill", "transfer",
                               "payment", "virement", "zahlung"]
        if paymentPatterns.contains(where: { lower.contains($0) }) {
            return .makePayment
        }

        // Package tracking
        let trackingPatterns = ["tracking", "package", "delivery", "shipped",
                                "colis", "livraison", "paket", "sendung"]
        if trackingPatterns.contains(where: { lower.contains($0) }) {
            return .trackPackage
        }

        // Call back
        let callPatterns = ["call me", "call back", "rappelle", "ruf.*an",
                            "missed call"]
        if callPatterns.contains(where: { lower.contains($0) }) {
            return .callBack
        }

        // Link opening
        if lower.contains("http://") || lower.contains("https://") {
            return .openLink
        }

        // Document review
        let docPatterns = ["review", "sign", "contract", "document",
                           "contrat", "vertrag", "dokument"]
        if docPatterns.contains(where: { lower.contains($0) }) {
            return .reviewDocument
        }

        // Set reminder
        let reminderPatterns = ["remind me", "don't forget", "rappelle-moi",
                                "erinnere mich", "напомни"]
        if reminderPatterns.contains(where: { lower.contains($0) }) {
            return .setReminder
        }

        // Default: reply if the intent requires a response
        if intent.requiresResponse {
            return .reply
        }

        return nil
    }

    // MARK: - Entity Extraction

    static func extractEntities(_ text: String) -> [MsgEntity] {
        var entities: [MsgEntity] = []

        // Email addresses
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        for match in matches(for: emailPattern, in: text) {
            entities.append(MsgEntity(type: .email, value: match))
        }

        // URLs
        let urlPattern = #"https?://[^\s<>"')\]]+"#
        for match in matches(for: urlPattern, in: text) {
            entities.append(MsgEntity(type: .url, value: match))
        }

        // Phone numbers (international format)
        let phonePattern = #"(?:\+\d{1,3}[\s.-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{2,4}"#
        for match in matches(for: phonePattern, in: text) {
            let digits = match.filter(\.isNumber)
            if digits.count >= 7 && digits.count <= 15 {
                entities.append(MsgEntity(type: .phoneNumber, value: match.trimmingCharacters(in: .whitespaces)))
            }
        }

        // Currency amounts (CHF, EUR, USD, GBP)
        let amountPattern = #"(?:CHF|EUR|USD|GBP|Fr\.|€|\$|£)\s?\d[\d',.\s]*\d|\d[\d',.\s]*\d\s?(?:CHF|EUR|USD|GBP|Fr\.)"#
        for match in matches(for: amountPattern, in: text) {
            entities.append(MsgEntity(type: .amount, value: match.trimmingCharacters(in: .whitespaces)))
        }

        // Tracking numbers (common carrier formats)
        let trackingPattern = #"\b[A-Z]{2}\d{9}[A-Z]{2}\b|\b1Z[A-Z0-9]{16}\b|\b\d{12,22}\b"#
        for match in matches(for: trackingPattern, in: text) {
            // Filter out phone numbers
            if match.count >= 12 && !entities.contains(where: { $0.type == .phoneNumber && $0.value.contains(match) }) {
                entities.append(MsgEntity(type: .trackingNumber, value: match, confidence: 0.7))
            }
        }

        // Dates (common formats)
        let datePattern = #"\b\d{1,2}[./]\d{1,2}[./]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b"#
        for match in matches(for: datePattern, in: text) {
            entities.append(MsgEntity(type: .date, value: match))
        }

        // Times
        let timePattern = #"\b\d{1,2}:\d{2}(?::\d{2})?\s?(?:AM|PM|am|pm)?\b|\b\d{1,2}[hH]\d{0,2}\b"#
        for match in matches(for: timePattern, in: text) {
            entities.append(MsgEntity(type: .time, value: match))
        }

        return entities
    }

    // MARK: - Sentiment Detection

    static func detectSentiment(_ text: String) -> MsgSentiment {
        let lower = text.lowercased()

        let positiveWords = ["great", "good", "excellent", "happy", "thanks", "thank you",
                             "love", "amazing", "perfect", "wonderful", "super", "merci",
                             "bien", "génial", "danke", "gut", "wunderbar", "спасибо",
                             "отлично", "хорошо"]
        let negativeWords = ["bad", "terrible", "awful", "angry", "disappointed", "frustrated",
                             "hate", "worst", "horrible", "annoying", "problème", "mauvais",
                             "schlecht", "ärgerlich", "плохо", "ужасно"]

        let posCount = positiveWords.filter { lower.contains($0) }.count
        let negCount = negativeWords.filter { lower.contains($0) }.count

        if posCount > 0 && negCount > 0 {
            return .mixed
        } else if posCount > negCount {
            return .positive
        } else if negCount > posCount {
            return .negative
        }
        return .neutral
    }

    // MARK: - Summary Generation

    static func generateSummary(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 100 else { return nil }

        // Take first sentence or first 120 chars
        let firstSentence = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?")).first ?? trimmed
        if firstSentence.count <= 120 {
            return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(trimmed.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    // MARK: - Suggested Response Generation

    static func generateSuggestedResponse(intent: MsgIntent, content: String) -> String? {
        switch intent {
        case .socialGreeting:
            return "Hi! How can I help?"
        case .confirmation:
            return nil
        case .scheduling:
            return "Let me check my calendar and get back to you."
        case .urgent:
            return "I see this is urgent. I'm looking into it right away."
        case .complaint:
            return "I'm sorry to hear that. Let me look into this."
        case .question:
            return nil // Needs real AI to answer
        case .request:
            return nil // Needs real AI to fulfill
        case .informational:
            return nil
        case .followUp:
            return "Thanks for following up. Let me check on the status."
        }
    }

    // MARK: - Regex Helper

    private static func matches(for pattern: String, in text: String) -> [String] {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            msgComprehensionLogger.error("Invalid regex pattern: \(error.localizedDescription)")
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}
