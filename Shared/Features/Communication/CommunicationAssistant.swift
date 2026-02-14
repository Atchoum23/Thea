//
//  CommunicationAssistant.swift
//  Thea
//
//  Created by Thea
//  Email drafting, message suggestions, and tone adjustment
//

import Foundation
import os.log

// MARK: - Communication Assistant

/// AI-powered communication assistance for emails, messages, and more
@MainActor
public final class CommunicationAssistant: ObservableObject {
    public static let shared = CommunicationAssistant()

    private let logger = Logger(subsystem: "app.thea.communication", category: "CommunicationAssistant")

    // MARK: - State

    @Published public private(set) var isProcessing = false
    @Published public private(set) var recentDrafts: [CommunicationDraft] = []
    @Published public private(set) var savedTemplates: [MessageTemplate] = []

    // MARK: - Configuration

    public var defaultTone: CommunicationTone = .professional
    public var defaultLength: CommunicationResponseLength = .concise
    public var includeGreeting = true
    public var includeSignature = true
    public var signatureName = ""

    private init() {
        loadConfiguration()
        loadTemplates()
    }

    // MARK: - Email Drafting

    /// Generate an email draft
    public func generateEmailDraft(_ request: EmailDraftRequest) async throws -> EmailDraft {
        isProcessing = true
        defer { isProcessing = false }

        logger.info("Generating email draft: \(request.subject ?? "No subject")")

        // Build the email components
        var draft = EmailDraft(
            id: UUID().uuidString,
            subject: request.subject ?? generateSubject(for: request),
            body: "",
            recipients: request.recipients,
            cc: request.cc,
            tone: request.tone ?? defaultTone,
            createdAt: Date()
        )

        // Generate greeting
        if includeGreeting {
            draft.body += generateGreeting(for: request)
        }

        // Generate body content
        draft.body += generateBody(for: request)

        // Generate closing
        draft.body += generateClosing(for: request)

        // Add signature
        if includeSignature, !signatureName.isEmpty {
            draft.body += "\n\n\(signatureName)"
        }

        // Store in recent drafts
        let communicationDraft = CommunicationDraft(
            id: draft.id,
            type: .email,
            content: draft.body,
            tone: draft.tone,
            createdAt: draft.createdAt
        )
        recentDrafts.insert(communicationDraft, at: 0)
        if recentDrafts.count > 20 {
            recentDrafts = Array(recentDrafts.prefix(20))
        }

        return draft
    }

    private func generateSubject(for request: EmailDraftRequest) -> String {
        switch request.intent {
        case .reply:
            "Re: \(request.context ?? "Your message")"
        case .followUp:
            "Following up: \(request.context ?? "Our conversation")"
        case .introduction:
            "Introduction from \(signatureName.isEmpty ? "me" : signatureName)"
        case .request:
            "Request: \(request.context ?? "Assistance needed")"
        case .update:
            "Update: \(request.context ?? "Status update")"
        case .thank:
            "Thank you"
        case .apology:
            "Apology"
        case .custom:
            request.context ?? "Message"
        }
    }

    private func generateGreeting(for request: EmailDraftRequest) -> String {
        let recipientName = request.recipientName ?? "there"
        let tone = request.tone ?? defaultTone

        switch tone {
        case .casual:
            return "Hey \(recipientName),\n\n"
        case .friendly:
            return "Hi \(recipientName),\n\n"
        case .professional:
            return "Dear \(recipientName),\n\n"
        case .formal:
            return "Dear Mr./Ms. \(recipientName),\n\n"
        case .direct:
            return "\(recipientName),\n\n"
        }
    }

    private func generateBody(for request: EmailDraftRequest) -> String {
        let tone = request.tone ?? defaultTone
        let length = request.length ?? defaultLength

        // Base content
        var body = ""

        switch request.intent {
        case .reply:
            body = generateReplyBody(context: request.context, tone: tone)
        case .followUp:
            body = generateFollowUpBody(context: request.context, tone: tone)
        case .introduction:
            body = generateIntroductionBody(context: request.context, tone: tone)
        case .request:
            body = generateRequestBody(context: request.context, tone: tone)
        case .update:
            body = generateUpdateBody(context: request.context, tone: tone)
        case .thank:
            body = generateThankBody(context: request.context, tone: tone)
        case .apology:
            body = generateApologyBody(context: request.context, tone: tone)
        case .custom:
            body = request.context ?? ""
        }

        // Adjust length
        body = adjustLength(body, to: length)

        return body
    }

    private func generateReplyBody(context: String?, tone _: CommunicationTone) -> String {
        "Thank you for your message. I wanted to respond regarding \(context ?? "your inquiry").\n\n[Your response here]"
    }

    private func generateFollowUpBody(context: String?, tone _: CommunicationTone) -> String {
        "I wanted to follow up on \(context ?? "our previous conversation"). [Your follow-up content here]"
    }

    private func generateIntroductionBody(context: String?, tone _: CommunicationTone) -> String {
        "I hope this email finds you well. \(context ?? "I wanted to introduce myself and discuss a potential opportunity.")"
    }

    private func generateRequestBody(context: String?, tone _: CommunicationTone) -> String {
        "I am writing to request \(context ?? "your assistance with a matter"). [Details of your request here]"
    }

    private func generateUpdateBody(context: String?, tone _: CommunicationTone) -> String {
        "I wanted to provide an update on \(context ?? "the current status"). [Your update details here]"
    }

    private func generateThankBody(context: String?, tone _: CommunicationTone) -> String {
        "Thank you so much for \(context ?? "your help and support"). I really appreciate it."
    }

    private func generateApologyBody(context: String?, tone _: CommunicationTone) -> String {
        "I sincerely apologize for \(context ?? "any inconvenience caused"). [Explanation and resolution here]"
    }

    private func generateClosing(for request: EmailDraftRequest) -> String {
        let tone = request.tone ?? defaultTone

        switch tone {
        case .casual:
            return "\n\nTalk soon,"
        case .friendly:
            return "\n\nBest,"
        case .professional:
            return "\n\nBest regards,"
        case .formal:
            return "\n\nSincerely,"
        case .direct:
            return "\n\nThanks,"
        }
    }

    private func adjustLength(_ text: String, to length: CommunicationResponseLength) -> String {
        // Simplified length adjustment
        // In production, would use AI to properly summarize or expand
        switch length {
        case .brief:
            String(text.prefix(200))
        case .concise:
            text
        case .detailed:
            text + "\n\n[Additional details can be added here]"
        case .comprehensive:
            text + "\n\n[Comprehensive explanation and context can be added here]"
        }
    }

    // MARK: - Message Suggestions

    /// Generate reply suggestions for a message
    public func generateReplySuggestions(for message: String, context _: MessageContext? = nil) async throws -> [ReplySuggestion] {
        isProcessing = true
        defer { isProcessing = false }

        logger.info("Generating reply suggestions")

        // Analyze sentiment of incoming message
        let sentiment = analyzeSentiment(message)

        var suggestions: [ReplySuggestion] = []

        // Generate suggestions based on sentiment and context
        switch sentiment {
        case .positive:
            suggestions = [
                ReplySuggestion(text: "Thank you! I appreciate that.", tone: .friendly),
                ReplySuggestion(text: "Great to hear! Let me know if you need anything else.", tone: .professional),
                ReplySuggestion(text: "Awesome! 🎉", tone: .casual)
            ]

        case .negative:
            suggestions = [
                ReplySuggestion(text: "I'm sorry to hear that. How can I help?", tone: .friendly),
                ReplySuggestion(text: "I apologize for the inconvenience. Let me look into this.", tone: .professional),
                ReplySuggestion(text: "Oh no! Let me see what I can do.", tone: .casual)
            ]

        case .neutral:
            suggestions = [
                ReplySuggestion(text: "Thanks for letting me know.", tone: .professional),
                ReplySuggestion(text: "Got it, I'll take care of it.", tone: .direct),
                ReplySuggestion(text: "Sounds good!", tone: .casual)
            ]

        case .question:
            suggestions = [
                ReplySuggestion(text: "Great question! Let me explain...", tone: .friendly),
                ReplySuggestion(text: "To answer your question: [response]", tone: .professional),
                ReplySuggestion(text: "Here's what you need to know: [details]", tone: .direct)
            ]
        }

        return suggestions
    }

    private func analyzeSentiment(_ text: String) -> MessageSentiment {
        let lowercased = text.lowercased()

        // Simple keyword-based sentiment analysis
        let positiveWords = ["thank", "great", "awesome", "wonderful", "excellent", "perfect", "love", "happy"]
        let negativeWords = ["sorry", "problem", "issue", "error", "frustrated", "disappointed", "wrong", "bad"]
        let questionMarkers = ["?", "how", "what", "when", "where", "why", "could you", "can you"]

        // Check for questions
        for marker in questionMarkers {
            if lowercased.contains(marker) {
                return .question
            }
        }

        // Count sentiment words
        let positiveCount = positiveWords.count { lowercased.contains($0) }
        let negativeCount = negativeWords.count { lowercased.contains($0) }

        if positiveCount > negativeCount {
            return .positive
        } else if negativeCount > positiveCount {
            return .negative
        }

        return .neutral
    }

    // MARK: - Tone Adjustment

    /// Adjust the tone of existing text
    public func adjustTone(_ text: String, to tone: CommunicationTone) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }

        logger.info("Adjusting tone to: \(tone.rawValue)")

        // Simplified tone adjustment
        // In production, would use AI to properly rewrite
        switch tone {
        case .casual:
            return makeCasual(text)
        case .friendly:
            return makeFriendly(text)
        case .professional:
            return makeProfessional(text)
        case .formal:
            return makeFormal(text)
        case .direct:
            return makeDirect(text)
        }
    }

    private func makeCasual(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "Dear", with: "Hey")
        result = result.replacingOccurrences(of: "Sincerely", with: "Later")
        result = result.replacingOccurrences(of: "Best regards", with: "Cheers")
        return result
    }

    private func makeFriendly(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "Dear", with: "Hi")
        result = result.replacingOccurrences(of: "Sincerely", with: "Best")
        return result
    }

    private func makeProfessional(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "Hey", with: "Dear")
        result = result.replacingOccurrences(of: "Cheers", with: "Best regards")
        return result
    }

    private func makeFormal(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "Hi", with: "Dear")
        result = result.replacingOccurrences(of: "Hey", with: "Dear")
        result = result.replacingOccurrences(of: "Thanks", with: "Thank you")
        result = result.replacingOccurrences(of: "Best", with: "Sincerely")
        return result
    }

    private func makeDirect(_ text: String) -> String {
        // Remove fluff words and get to the point
        var result = text
        let fluffPhrases = [
            "I hope this email finds you well. ",
            "I just wanted to ",
            "I was wondering if ",
            "I think that "
        ]
        for phrase in fluffPhrases {
            result = result.replacingOccurrences(of: phrase, with: "")
        }
        return result
    }

    // MARK: - Templates

    /// Get template by category
    public func getTemplates(for category: TemplateCategory) -> [MessageTemplate] {
        savedTemplates.filter { $0.category == category }
    }

    /// Save a new template
    public func saveTemplate(_ template: MessageTemplate) {
        savedTemplates.append(template)
        saveTemplates()
    }

    /// Delete a template
    public func deleteTemplate(_ id: String) {
        savedTemplates.removeAll { $0.id == id }
        saveTemplates()
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        if let toneName = UserDefaults.standard.string(forKey: "thea.comm.defaultTone"),
           let tone = CommunicationTone(rawValue: toneName)
        {
            defaultTone = tone
        }

        if let lengthName = UserDefaults.standard.string(forKey: "thea.comm.defaultLength"),
           let length = CommunicationResponseLength(rawValue: lengthName)
        {
            defaultLength = length
        }

        includeGreeting = UserDefaults.standard.bool(forKey: "thea.comm.includeGreeting")
        includeSignature = UserDefaults.standard.bool(forKey: "thea.comm.includeSignature")
        signatureName = UserDefaults.standard.string(forKey: "thea.comm.signatureName") ?? ""
    }

    public func saveConfiguration() {
        UserDefaults.standard.set(defaultTone.rawValue, forKey: "thea.comm.defaultTone")
        UserDefaults.standard.set(defaultLength.rawValue, forKey: "thea.comm.defaultLength")
        UserDefaults.standard.set(includeGreeting, forKey: "thea.comm.includeGreeting")
        UserDefaults.standard.set(includeSignature, forKey: "thea.comm.includeSignature")
        UserDefaults.standard.set(signatureName, forKey: "thea.comm.signatureName")
    }

    private func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: "thea.comm.templates"),
           let templates = try? JSONDecoder().decode([MessageTemplate].self, from: data)
        {
            savedTemplates = templates
        } else {
            // Load default templates
            savedTemplates = defaultTemplates()
        }
    }

    private func saveTemplates() {
        if let data = try? JSONEncoder().encode(savedTemplates) {
            UserDefaults.standard.set(data, forKey: "thea.comm.templates")
        }
    }

    private func defaultTemplates() -> [MessageTemplate] {
        [
            MessageTemplate(
                name: "Out of Office",
                category: .email,
                subject: "Out of Office",
                body: "Thank you for your email. I am currently out of the office and will return on [DATE]. I will respond to your message when I return.",
                tone: .professional
            ),
            MessageTemplate(
                name: "Meeting Request",
                category: .email,
                subject: "Meeting Request: [TOPIC]",
                body: "I would like to schedule a meeting to discuss [TOPIC]. Would [DATE/TIME] work for you?",
                tone: .professional
            ),
            MessageTemplate(
                name: "Follow Up",
                category: .email,
                subject: "Following Up",
                body: "I wanted to follow up on our previous conversation about [TOPIC]. Please let me know if you have any updates.",
                tone: .professional
            ),
            MessageTemplate(
                name: "Quick Acknowledgment",
                category: .message,
                body: "Got it, thanks!",
                tone: .casual
            )
        ]
    }
}

// Supporting types are in CommunicationAssistantTypes.swift
