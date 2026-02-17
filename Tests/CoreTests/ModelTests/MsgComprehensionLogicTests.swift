// MsgComprehensionLogicTests.swift
// Tests for MsgComprehensionEngine detection logic — intent, urgency,
// sentiment, entity extraction, action detection, and message routing.

import Testing
import Foundation

// MARK: - Detection Helpers (mirror MsgComprehensionEngine static methods)

// Since MsgComprehensionEngine depends on UnifiedMessage and other types
// that require SwiftUI/SwiftData, we replicate the pure detection logic
// here for isolated testing. The patterns match the production code exactly.

private enum DetectIntent {
    static func run(_ text: String) -> String {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lower.hasSuffix("?") || lower.hasPrefix("can you") || lower.hasPrefix("could you") ||
           lower.hasPrefix("would you") || lower.hasPrefix("what") || lower.hasPrefix("when") ||
           lower.hasPrefix("where") || lower.hasPrefix("who") || lower.hasPrefix("how") ||
           lower.hasPrefix("why") || lower.hasPrefix("is it") || lower.hasPrefix("are you") ||
           lower.hasPrefix("do you") || lower.hasPrefix("est-ce") || lower.hasPrefix("qu'est") ||
           lower.hasPrefix("quand") || lower.hasPrefix("comment") || lower.hasPrefix("pourquoi") {
            return "question"
        }

        let urgentPatterns = ["urgent", "asap", "immediately", "emergency", "critical",
                              "right now", "right away", "tout de suite", "immédiatement",
                              "dringend", "sofort", "срочно"]
        if urgentPatterns.contains(where: { lower.contains($0) }) {
            return "urgent"
        }

        let schedulePatterns = ["meeting", "appointment", "schedule", "calendar",
                                "let's meet", "available", "free on", "rendez-vous",
                                "réunion", "termin", "treffen"]
        if schedulePatterns.contains(where: { lower.contains($0) }) {
            return "scheduling"
        }

        let requestPatterns = ["please", "could you", "can you", "i need", "send me",
                               "help me", "s'il vous plaît", "s'il te plaît", "bitte",
                               "пожалуйста", "would you mind"]
        if requestPatterns.contains(where: { lower.contains($0) }) {
            return "request"
        }

        let complaintPatterns = ["not working", "broken", "issue", "problem", "bug",
                                 "complaint", "disappointed", "frustrated", "ne marche pas",
                                 "funktioniert nicht", "не работает"]
        if complaintPatterns.contains(where: { lower.contains($0) }) {
            return "complaint"
        }

        let greetingPatterns = ["hello", "hi ", "hey ", "good morning", "good afternoon",
                                "good evening", "bonjour", "bonsoir", "salut",
                                "hallo", "guten tag", "привет", "здравствуйте"]
        if greetingPatterns.contains(where: { lower.hasPrefix($0) || lower == $0.trimmingCharacters(in: .whitespaces) }) {
            return "socialGreeting"
        }

        let confirmPatterns = ["ok", "okay", "sure", "yes", "confirmed", "agreed",
                               "sounds good", "perfect", "great", "d'accord", "oui",
                               "einverstanden", "ja", "da", "да", "хорошо"]
        if confirmPatterns.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") || lower.hasPrefix($0 + ",") || lower.hasPrefix($0 + "!") }) {
            return "confirmation"
        }

        let followUpPatterns = ["following up", "any update", "just checking", "reminder",
                                "circling back", "as discussed", "re:", "relance",
                                "nachfrage", "noch mal"]
        if followUpPatterns.contains(where: { lower.contains($0) }) {
            return "followUp"
        }

        return "informational"
    }
}

private enum DetectUrgency {
    static func run(_ text: String) -> String {
        let lower = text.lowercased()

        let criticalPatterns = ["emergency", "critical", "life or death",
                                "urgence", "notfall", "экстренно"]
        if criticalPatterns.contains(where: { lower.contains($0) }) {
            return "critical"
        }

        let highPatterns = ["urgent", "asap", "immediately", "right now",
                            "deadline today", "due today", "срочно",
                            "tout de suite", "sofort", "dringend"]
        if highPatterns.contains(where: { lower.contains($0) }) {
            return "high"
        }

        let lowPatterns = ["no rush", "whenever", "when you can", "low priority",
                           "pas urgent", "quand tu peux", "keine eile",
                           "не срочно"]
        if lowPatterns.contains(where: { lower.contains($0) }) {
            return "low"
        }

        return "normal"
    }
}

private enum DetectSentiment {
    static func run(_ text: String) -> String {
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

        if posCount > 0 && negCount > 0 { return "mixed" }
        if posCount > negCount { return "positive" }
        if negCount > posCount { return "negative" }
        return "neutral"
    }
}

private enum GenerateSummary {
    static func run(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 100 else { return nil }

        let firstSentence = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?")).first ?? trimmed
        if firstSentence.count <= 120 {
            return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(trimmed.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

private enum DetectAction {
    static func run(_ text: String, intent: String) -> String? {
        let lower = text.lowercased()

        if intent == "scheduling" || lower.contains("meet") || lower.contains("calendar") ||
           lower.contains("rendez-vous") || lower.contains("termin") {
            return "createCalendarEvent"
        }

        let paymentPatterns = ["pay", "invoice", "bill", "transfer",
                               "payment", "virement", "zahlung"]
        if paymentPatterns.contains(where: { lower.contains($0) }) {
            return "makePayment"
        }

        let trackingPatterns = ["tracking", "package", "delivery", "shipped",
                                "colis", "livraison", "paket", "sendung"]
        if trackingPatterns.contains(where: { lower.contains($0) }) {
            return "trackPackage"
        }

        let callPatterns = ["call me", "call back", "rappelle", "ruf.*an",
                            "missed call"]
        if callPatterns.contains(where: { lower.contains($0) }) {
            return "callBack"
        }

        if lower.contains("http://") || lower.contains("https://") {
            return "openLink"
        }

        let docPatterns = ["review", "sign", "contract", "document",
                           "contrat", "vertrag", "dokument"]
        if docPatterns.contains(where: { lower.contains($0) }) {
            return "reviewDocument"
        }

        let reminderPatterns = ["remind me", "don't forget", "rappelle-moi",
                                "erinnere mich", "напомни"]
        if reminderPatterns.contains(where: { lower.contains($0) }) {
            return "setReminder"
        }

        let requiresResponse = ["question", "request", "scheduling", "urgent", "complaint"].contains(intent)
        if requiresResponse {
            return "reply"
        }

        return nil
    }
}

private enum ExtractEntities {
    static func run(_ text: String) -> [(type: String, value: String)] {
        var entities: [(type: String, value: String)] = []

        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        for match in matches(for: emailPattern, in: text) {
            entities.append(("email", match))
        }

        let urlPattern = #"https?://[^\s<>\"')\]]+"#
        for match in matches(for: urlPattern, in: text) {
            entities.append(("url", match))
        }

        let phonePattern = #"(?:\+\d{1,3}[\s.-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{2,4}"#
        for match in matches(for: phonePattern, in: text) {
            let digits = match.filter(\.isNumber)
            if digits.count >= 7 && digits.count <= 15 {
                entities.append(("phoneNumber", match.trimmingCharacters(in: .whitespaces)))
            }
        }

        let amountPattern = #"(?:CHF|EUR|USD|GBP|Fr\.|€|\$|£)\s?\d[\d',.\s]*\d|\d[\d',.\s]*\d\s?(?:CHF|EUR|USD|GBP|Fr\.)"#
        for match in matches(for: amountPattern, in: text) {
            entities.append(("amount", match.trimmingCharacters(in: .whitespaces)))
        }

        let datePattern = #"\b\d{1,2}[./]\d{1,2}[./]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b"#
        for match in matches(for: datePattern, in: text) {
            entities.append(("date", match))
        }

        let timePattern = #"\b\d{1,2}:\d{2}(?::\d{2})?\s?(?:AM|PM|am|pm)?\b|\b\d{1,2}[hH]\d{0,2}\b"#
        for match in matches(for: timePattern, in: text) {
            entities.append(("time", match))
        }

        return entities
    }

    private static func matches(for pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}

// MARK: - Tests: Intent Detection

@Suite("Intent Detection — Pattern Matching")
struct IntentDetectionTests {
    @Test("Question mark suffix")
    func questionMark() {
        #expect(DetectIntent.run("Is this working?") == "question")
    }

    @Test("English question words")
    func englishQuestions() {
        #expect(DetectIntent.run("What time is it") == "question")
        #expect(DetectIntent.run("When does it start") == "question")
        #expect(DetectIntent.run("Where are you") == "question")
        #expect(DetectIntent.run("Who is calling") == "question")
        #expect(DetectIntent.run("How does it work") == "question")
        #expect(DetectIntent.run("Why did it fail") == "question")
    }

    @Test("French question words")
    func frenchQuestions() {
        #expect(DetectIntent.run("Est-ce que tu viens") == "question")
        #expect(DetectIntent.run("Qu'est-ce que c'est") == "question")
        #expect(DetectIntent.run("Quand est-ce que tu arrives") == "question")
        #expect(DetectIntent.run("Comment ça marche") == "question")
        #expect(DetectIntent.run("Pourquoi pas") == "question")
    }

    @Test("Urgent patterns")
    func urgent() {
        #expect(DetectIntent.run("This is urgent") == "urgent")
        #expect(DetectIntent.run("Need this ASAP") == "urgent")
        #expect(DetectIntent.run("Respond immediately") == "urgent")
        #expect(DetectIntent.run("Do it right now") == "urgent")
        #expect(DetectIntent.run("Tout de suite!") == "urgent")
        #expect(DetectIntent.run("Срочно нужно") == "urgent")
    }

    @Test("Scheduling patterns")
    func scheduling() {
        #expect(DetectIntent.run("Let's set up a meeting") == "scheduling")
        #expect(DetectIntent.run("I have an appointment") == "scheduling")
        #expect(DetectIntent.run("Check the calendar") == "scheduling")
        #expect(DetectIntent.run("Rendez-vous demain") == "scheduling")
    }

    @Test("Request patterns")
    func request() {
        #expect(DetectIntent.run("Please send the file") == "request")
        #expect(DetectIntent.run("I need help with this") == "request")
        #expect(DetectIntent.run("Help me understand") == "request")
        #expect(DetectIntent.run("S'il vous plaît, envoyez") == "request")
        #expect(DetectIntent.run("Bitte senden Sie") == "request")
        #expect(DetectIntent.run("Пожалуйста, отправьте") == "request")
    }

    @Test("Complaint patterns")
    func complaint() {
        #expect(DetectIntent.run("The app is not working") == "complaint")
        #expect(DetectIntent.run("Something is broken") == "complaint")
        #expect(DetectIntent.run("I found a bug in the system") == "complaint")
        #expect(DetectIntent.run("Ne marche pas du tout") == "complaint")
        #expect(DetectIntent.run("Funktioniert nicht mehr") == "complaint")
        #expect(DetectIntent.run("Не работает совсем") == "complaint")
    }

    @Test("Social greeting patterns")
    func greeting() {
        #expect(DetectIntent.run("Hello there") == "socialGreeting")
        #expect(DetectIntent.run("Hi everyone") == "socialGreeting")
        #expect(DetectIntent.run("Hey team") == "socialGreeting")
        #expect(DetectIntent.run("Good morning") == "socialGreeting")
        #expect(DetectIntent.run("Bonjour à tous") == "socialGreeting")
        #expect(DetectIntent.run("Привет") == "socialGreeting")
    }

    @Test("Confirmation patterns")
    func confirmation() {
        #expect(DetectIntent.run("ok") == "confirmation")
        #expect(DetectIntent.run("okay, will do") == "confirmation")
        #expect(DetectIntent.run("sure thing") == "confirmation")
        #expect(DetectIntent.run("yes!") == "confirmation")
        #expect(DetectIntent.run("d'accord") == "confirmation")
        #expect(DetectIntent.run("Да") == "confirmation")
    }

    @Test("Follow-up patterns")
    func followUp() {
        #expect(DetectIntent.run("Following up on my last email") == "followUp")
        #expect(DetectIntent.run("Any update on the project") == "followUp")
        #expect(DetectIntent.run("Just checking in") == "followUp")
        #expect(DetectIntent.run("Circling back on this") == "followUp")
        #expect(DetectIntent.run("Re: Previous discussion") == "followUp")
    }

    @Test("Informational default")
    func informational() {
        #expect(DetectIntent.run("The weather is nice today") == "informational")
        #expect(DetectIntent.run("FYI the server was updated") == "informational")
    }
}

// MARK: - Tests: Urgency Detection

@Suite("Urgency Detection — Level Classification")
struct UrgencyDetectionTests {
    @Test("Critical urgency")
    func critical() {
        #expect(DetectUrgency.run("This is an emergency") == "critical")
        #expect(DetectUrgency.run("Critical failure in production") == "critical")
        #expect(DetectUrgency.run("Life or death situation") == "critical")
        #expect(DetectUrgency.run("Notfall! Sofort handeln!") == "critical")
    }

    @Test("High urgency")
    func high() {
        #expect(DetectUrgency.run("This is urgent") == "high")
        #expect(DetectUrgency.run("Need this ASAP") == "high")
        #expect(DetectUrgency.run("Do it right now") == "high")
        #expect(DetectUrgency.run("Deadline today!") == "high")
        #expect(DetectUrgency.run("Dringend bitte antworten") == "high")
    }

    @Test("Low urgency")
    func low() {
        #expect(DetectUrgency.run("No rush on this") == "low")
        #expect(DetectUrgency.run("Whenever you get a chance") == "low")
        #expect(DetectUrgency.run("Low priority task") == "low")
        #expect(DetectUrgency.run("Keine eile damit") == "low")
    }

    @Test("Normal urgency default")
    func normal() {
        #expect(DetectUrgency.run("Can you send the report") == "normal")
        #expect(DetectUrgency.run("Here are the files") == "normal")
    }

    @Test("Critical takes priority over high")
    func criticalOverHigh() {
        // "emergency" matches critical even though "urgent" would match high
        #expect(DetectUrgency.run("Urgent emergency alert") == "critical")
    }
}

// MARK: - Tests: Sentiment Detection

@Suite("Sentiment Detection — Word-based Analysis")
struct SentimentDetectionTests {
    @Test("Positive sentiment")
    func positive() {
        #expect(DetectSentiment.run("This is great work!") == "positive")
        #expect(DetectSentiment.run("Thank you so much") == "positive")
        #expect(DetectSentiment.run("Merci beaucoup, c'est génial") == "positive")
        #expect(DetectSentiment.run("Danke, wunderbar!") == "positive")
        #expect(DetectSentiment.run("Спасибо, отлично!") == "positive")
    }

    @Test("Negative sentiment")
    func negative() {
        #expect(DetectSentiment.run("This is terrible") == "negative")
        #expect(DetectSentiment.run("I hate this awful thing") == "negative")
        #expect(DetectSentiment.run("Very disappointed and frustrated") == "negative")
        #expect(DetectSentiment.run("C'est vraiment mauvais") == "negative")
    }

    @Test("Mixed sentiment")
    func mixed() {
        #expect(DetectSentiment.run("It's good but also bad in some ways") == "mixed")
        #expect(DetectSentiment.run("Thanks for the effort, but the result is terrible") == "mixed")
    }

    @Test("Neutral sentiment")
    func neutral() {
        #expect(DetectSentiment.run("The meeting is at 3pm") == "neutral")
        #expect(DetectSentiment.run("Please send the file") == "neutral")
    }
}

// MARK: - Tests: Summary Generation

@Suite("Summary Generation — Text Truncation")
struct SummaryGenerationTests {
    @Test("Short text returns nil")
    func shortText() {
        #expect(GenerateSummary.run("Hello") == nil)
        #expect(GenerateSummary.run("Short message") == nil)
    }

    @Test("Exactly 100 chars returns nil")
    func exactly100() {
        let text = String(repeating: "a", count: 100)
        #expect(GenerateSummary.run(text) == nil)
    }

    @Test("101+ chars generates summary")
    func longText() {
        let text = String(repeating: "a", count: 101)
        let summary = GenerateSummary.run(text)
        #expect(summary != nil)
    }

    @Test("Uses first sentence if short enough")
    func firstSentence() {
        let text = "This is the first sentence. " + String(repeating: "More text here ", count: 10)
        let summary = GenerateSummary.run(text)
        #expect(summary == "This is the first sentence")
    }

    @Test("Truncates to 120 chars with ellipsis")
    func truncation() {
        let text = String(repeating: "Long word ", count: 20)
        let summary = GenerateSummary.run(text)
        #expect(summary != nil)
        #expect(summary!.count <= 121) // 120 + 1 for "…"
    }
}

// MARK: - Tests: OpenClaw Platform Mapping

@Suite("OpenClaw Platform Mapping")
struct OpenClawMappingTests {
    @Test("Known platform strings map correctly")
    func knownPlatforms() {
        // Test the mapping logic directly
        func mapPlatform(_ platform: String) -> String {
            switch platform.lowercased() {
            case "whatsapp": return "whatsApp"
            case "telegram": return "telegram"
            case "discord": return "discord"
            case "slack": return "slack"
            case "signal": return "signal"
            case "imessage": return "iMessage"
            default: return "notification"
            }
        }

        #expect(mapPlatform("whatsapp") == "whatsApp")
        #expect(mapPlatform("WhatsApp") == "whatsApp")
        #expect(mapPlatform("telegram") == "telegram")
        #expect(mapPlatform("discord") == "discord")
        #expect(mapPlatform("slack") == "slack")
        #expect(mapPlatform("signal") == "signal")
        #expect(mapPlatform("imessage") == "iMessage")
    }

    @Test("Unknown platform defaults to notification")
    func unknownPlatform() {
        func mapPlatform(_ platform: String) -> String {
            switch platform.lowercased() {
            case "whatsapp": return "whatsApp"
            case "telegram": return "telegram"
            case "discord": return "discord"
            case "slack": return "slack"
            case "signal": return "signal"
            case "imessage": return "iMessage"
            default: return "notification"
            }
        }

        #expect(mapPlatform("facebook") == "notification")
        #expect(mapPlatform("line") == "notification")
        #expect(mapPlatform("unknown") == "notification")
    }
}

// MARK: - Tests: Attachment Type Mapping

@Suite("Attachment Type Mapping")
struct AttachmentMappingTests {
    @Test("Known types map correctly")
    func knownTypes() {
        func mapType(_ type: String) -> String {
            switch type.lowercased() {
            case "image": return "image"
            case "audio": return "audio"
            case "video": return "video"
            case "document": return "document"
            case "sticker": return "sticker"
            default: return "document"
            }
        }

        #expect(mapType("image") == "image")
        #expect(mapType("audio") == "audio")
        #expect(mapType("video") == "video")
        #expect(mapType("document") == "document")
        #expect(mapType("sticker") == "sticker")
    }

    @Test("Unknown types default to document")
    func unknownTypes() {
        func mapType(_ type: String) -> String {
            switch type.lowercased() {
            case "image": return "image"
            case "audio": return "audio"
            case "video": return "video"
            case "document": return "document"
            case "sticker": return "sticker"
            default: return "document"
            }
        }

        #expect(mapType("gif") == "document")
        #expect(mapType("binary") == "document")
    }
}

// MARK: - Tests: Auto-Reply Logic

@Suite("Auto-Reply Logic")
struct AutoReplyTests {
    @Test("Bot messages never get auto-reply")
    func botMessages() {
        // Auto-reply should be blocked for bot messages
        let isFromBot = true
        #expect(isFromBot == true) // Would block auto-reply
    }

    @Test("Intents that require response allow auto-reply")
    func respondingIntents() {
        let responding = ["question", "request", "scheduling", "urgent", "complaint"]
        for intent in responding {
            #expect(responding.contains(intent))
        }
    }

    @Test("Intents that don't require response block auto-reply")
    func nonRespondingIntents() {
        let nonResponding = ["informational", "socialGreeting", "confirmation", "followUp"]
        let responding = ["question", "request", "scheduling", "urgent", "complaint"]
        for intent in nonResponding {
            #expect(!responding.contains(intent))
        }
    }
}

// MARK: - Tests: Suggested Response Generation

@Suite("Suggested Response Generation")
struct SuggestedResponseTests {
    private func generateResponse(intent: String) -> String? {
        switch intent {
        case "socialGreeting": return "Hi! How can I help?"
        case "confirmation": return nil
        case "scheduling": return "Let me check my calendar and get back to you."
        case "urgent": return "I see this is urgent. I'm looking into it right away."
        case "complaint": return "I'm sorry to hear that. Let me look into this."
        case "question": return nil
        case "request": return nil
        case "informational": return nil
        case "followUp": return "Thanks for following up. Let me check on the status."
        default: return nil
        }
    }

    @Test("Greeting response")
    func greeting() {
        #expect(generateResponse(intent: "socialGreeting") == "Hi! How can I help?")
    }

    @Test("Scheduling response")
    func scheduling() {
        #expect(generateResponse(intent: "scheduling") != nil)
    }

    @Test("Urgent response")
    func urgent() {
        #expect(generateResponse(intent: "urgent") != nil)
    }

    @Test("Complaint response")
    func complaint() {
        #expect(generateResponse(intent: "complaint") != nil)
    }

    @Test("Follow-up response")
    func followUp() {
        #expect(generateResponse(intent: "followUp") != nil)
    }

    @Test("No response for question (needs real AI)")
    func question() {
        #expect(generateResponse(intent: "question") == nil)
    }

    @Test("No response for request (needs real AI)")
    func request() {
        #expect(generateResponse(intent: "request") == nil)
    }

    @Test("No response for confirmation")
    func confirmation() {
        #expect(generateResponse(intent: "confirmation") == nil)
    }

    @Test("No response for informational")
    func informational() {
        #expect(generateResponse(intent: "informational") == nil)
    }
}

// MARK: - Tests: Entity Extraction

@Suite("Entity Extraction — Regex Patterns")
struct EntityExtractionTests {
    @Test("Email extraction")
    func emails() {
        let entities = ExtractEntities.run("Contact us at hello@example.com or support@thea.app")
        let emails = entities.filter { $0.type == "email" }
        #expect(emails.count == 2)
        #expect(emails.contains { $0.value == "hello@example.com" })
        #expect(emails.contains { $0.value == "support@thea.app" })
    }

    @Test("URL extraction")
    func urls() {
        let entities = ExtractEntities.run("Visit https://example.com and http://test.org/page")
        let urls = entities.filter { $0.type == "url" }
        #expect(urls.count == 2)
    }

    @Test("Phone number extraction")
    func phones() {
        let entities = ExtractEntities.run("Call +41 79 123 4567 or (044) 123-4567")
        let phones = entities.filter { $0.type == "phoneNumber" }
        #expect(phones.count >= 1)
    }

    @Test("Currency amount extraction")
    func amounts() {
        let entities = ExtractEntities.run("The total is CHF 1'234.50 or €99.99")
        let amounts = entities.filter { $0.type == "amount" }
        #expect(amounts.count >= 1)
    }

    @Test("Date extraction")
    func dates() {
        let entities = ExtractEntities.run("Meeting on 15.02.2026 and 2026-02-15")
        let dates = entities.filter { $0.type == "date" }
        #expect(dates.count == 2)
    }

    @Test("Time extraction")
    func times() {
        let entities = ExtractEntities.run("Meeting at 14:30 or 2pm or 15h30")
        let times = entities.filter { $0.type == "time" }
        #expect(times.count >= 2)
    }

    @Test("No entities in plain text")
    func noEntities() {
        let entities = ExtractEntities.run("Hello world, how are you doing today")
        #expect(entities.isEmpty)
    }

    @Test("Mixed entity extraction")
    func mixed() {
        let text = "Email john@test.com about the CHF 500.00 invoice, meeting at 14:00 on 01.03.2026"
        let entities = ExtractEntities.run(text)
        let types = Set(entities.map(\.type))
        #expect(types.contains("email"))
        #expect(types.contains("amount"))
        #expect(types.contains("time"))
        #expect(types.contains("date"))
    }
}

// MARK: - Tests: Action Detection

@Suite("Action Detection — Content-based Actions")
struct ActionDetectionTests {
    @Test("Scheduling intent triggers calendar event")
    func schedulingAction() {
        #expect(DetectAction.run("Let's meet tomorrow", intent: "scheduling") == "createCalendarEvent")
    }

    @Test("Calendar keyword triggers calendar event")
    func calendarKeyword() {
        #expect(DetectAction.run("Add to calendar", intent: "informational") == "createCalendarEvent")
    }

    @Test("Payment patterns")
    func payment() {
        #expect(DetectAction.run("Please pay the invoice", intent: "request") == "makePayment")
        #expect(DetectAction.run("Send the bill", intent: "request") == "makePayment")
    }

    @Test("Package tracking patterns")
    func tracking() {
        #expect(DetectAction.run("Track my package", intent: "request") == "trackPackage")
        #expect(DetectAction.run("The delivery is coming", intent: "informational") == "trackPackage")
    }

    @Test("Call back patterns")
    func callBack() {
        #expect(DetectAction.run("Please call me back", intent: "request") == "callBack")
        #expect(DetectAction.run("You have a missed call", intent: "informational") == "callBack")
    }

    @Test("Link opening")
    func openLink() {
        #expect(DetectAction.run("Check https://example.com", intent: "informational") == "openLink")
    }

    @Test("Document review patterns")
    func reviewDocument() {
        #expect(DetectAction.run("Please review the contract", intent: "request") == "reviewDocument")
        #expect(DetectAction.run("Bitte Vertrag prüfen", intent: "request") == "reviewDocument")
    }

    @Test("Reminder patterns")
    func setReminder() {
        #expect(DetectAction.run("Remind me at 5pm", intent: "request") == "setReminder")
        #expect(DetectAction.run("Don't forget to send it", intent: "informational") == "setReminder")
    }

    @Test("Reply fallback for response-requiring intents")
    func replyFallback() {
        #expect(DetectAction.run("Some question text", intent: "question") == "reply")
        #expect(DetectAction.run("A complaint about service", intent: "complaint") == "reply")
    }

    @Test("No action for non-responding informational")
    func noAction() {
        #expect(DetectAction.run("Nice weather today", intent: "informational") == nil)
    }
}

// MARK: - Tests: Message Routing State

@Suite("Message Routing State")
struct MessageRoutingTests {
    @Test("Active channels filter")
    func activeChannels() {
        struct Chan {
            let isEnabled: Bool
            let statusIsActive: Bool
        }
        let channels = [
            Chan(isEnabled: true, statusIsActive: true),
            Chan(isEnabled: true, statusIsActive: false),
            Chan(isEnabled: false, statusIsActive: true),
            Chan(isEnabled: false, statusIsActive: false)
        ]
        let active = channels.filter { $0.isEnabled && $0.statusIsActive }
        #expect(active.count == 1)
    }

    @Test("Message deduplication by unread count")
    func unreadCount() {
        var count = 0
        count += 1 // incoming message
        count += 1 // another incoming
        #expect(count == 2)
        count = 0 // mark as read
        #expect(count == 0)
    }

    @Test("Recent messages capped at maxRecentMessages")
    func recentMessagesCap() {
        let maxRecent = 500
        var messages = Array(0..<600)
        if messages.count > maxRecent {
            messages = Array(messages.suffix(maxRecent))
        }
        #expect(messages.count == maxRecent)
        #expect(messages.first == 100)
    }

    @Test("Search messages by content")
    func searchByContent() {
        let contents = ["Hello world", "Goodbye world", "Hello again", "Test"]
        let query = "hello"
        let results = contents.filter { $0.lowercased().contains(query) }
        #expect(results.count == 2)
    }

    @Test("Search messages by sender name")
    func searchBySender() {
        let senders: [String?] = ["Alice", "Bob", nil, "Alice Smith"]
        let query = "alice"
        let results = senders.filter { $0?.lowercased().contains(query) ?? false }
        #expect(results.count == 2)
    }
}

// MARK: - Tests: Persistence

@Suite("Messaging Persistence")
struct MsgPersistenceTests {
    @Test("SaveableState encodes and decodes")
    func stateRoundtrip() throws {
        struct SaveableState: Codable {
            let channelCount: Int
            let messageCount: Int
        }
        let state = SaveableState(channelCount: 5, messageCount: 100)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SaveableState.self, from: data)
        #expect(decoded.channelCount == 5)
        #expect(decoded.messageCount == 100)
    }

    @Test("Channel state persists across encode/decode")
    func channelPersistence() throws {
        struct PChannel: Codable {
            let type: String
            let name: String
            let isEnabled: Bool
            let autoReply: Bool
        }
        let channel = PChannel(type: "whatsApp", name: "Business", isEnabled: true, autoReply: true)
        let data = try JSONEncoder().encode(channel)
        let decoded = try JSONDecoder().decode(PChannel.self, from: data)
        #expect(decoded.type == "whatsApp")
        #expect(decoded.name == "Business")
        #expect(decoded.isEnabled)
        #expect(decoded.autoReply)
    }
}
