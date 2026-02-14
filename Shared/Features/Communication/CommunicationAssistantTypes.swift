//
//  CommunicationAssistantTypes.swift
//  Thea
//
//  Supporting types for CommunicationAssistant
//

import Foundation

// MARK: - Models

public struct EmailDraftRequest: Sendable {
    public let recipients: [String]
    public let cc: [String]
    public let subject: String?
    public let context: String?
    public let recipientName: String?
    public let intent: EmailIntent
    public let tone: CommunicationTone?
    public let length: CommunicationResponseLength?

    public init(
        recipients: [String] = [],
        cc: [String] = [],
        subject: String? = nil,
        context: String? = nil,
        recipientName: String? = nil,
        intent: EmailIntent = .custom,
        tone: CommunicationTone? = nil,
        length: CommunicationResponseLength? = nil
    ) {
        self.recipients = recipients
        self.cc = cc
        self.subject = subject
        self.context = context
        self.recipientName = recipientName
        self.intent = intent
        self.tone = tone
        self.length = length
    }
}

public enum EmailIntent: String, Codable, Sendable, CaseIterable {
    case reply
    case followUp
    case introduction
    case request
    case update
    case thank
    case apology
    case custom

    public var displayName: String {
        switch self {
        case .reply: "Reply"
        case .followUp: "Follow Up"
        case .introduction: "Introduction"
        case .request: "Request"
        case .update: "Update"
        case .thank: "Thank You"
        case .apology: "Apology"
        case .custom: "Custom"
        }
    }
}

public struct EmailDraft: Identifiable, Codable, Sendable {
    public let id: String
    public var subject: String
    public var body: String
    public let recipients: [String]
    public let cc: [String]
    public let tone: CommunicationTone
    public let createdAt: Date
}

public struct CommunicationDraft: Identifiable, Codable, Sendable {
    public let id: String
    public let type: DraftType
    public var content: String
    public let tone: CommunicationTone
    public let createdAt: Date

    public enum DraftType: String, Codable, Sendable {
        case email, message, post, comment
    }
}

public enum CommunicationTone: String, Codable, Sendable, CaseIterable {
    case casual
    case friendly
    case professional
    case formal
    case direct

    public var displayName: String {
        rawValue.capitalized
    }

    public var description: String {
        switch self {
        case .casual: "Relaxed and informal"
        case .friendly: "Warm and personable"
        case .professional: "Business appropriate"
        case .formal: "Traditional and proper"
        case .direct: "Brief and to the point"
        }
    }
}

public enum CommunicationResponseLength: String, Codable, Sendable, CaseIterable {
    case brief
    case concise
    case detailed
    case comprehensive

    public var displayName: String {
        rawValue.capitalized
    }
}

public struct ReplySuggestion: Identifiable, Sendable {
    public let id: String
    public let text: String
    public let tone: CommunicationTone

    public init(text: String, tone: CommunicationTone) {
        id = UUID().uuidString
        self.text = text
        self.tone = tone
    }
}

public struct MessageContext: Sendable {
    public let previousMessages: [String]
    public let relationship: ContactRelationship?
    public let urgency: Urgency

    public enum ContactRelationship: String, Sendable {
        case colleague, friend, family, business, unknown
    }

    public enum Urgency: String, Sendable {
        case low, normal, high
    }
}

public enum MessageSentiment: String, Sendable {
    case positive
    case negative
    case neutral
    case question
}

public struct MessageTemplate: Identifiable, Codable, Sendable {
    public let id: String
    public var name: String
    public let category: TemplateCategory
    public var subject: String?
    public var body: String
    public let tone: CommunicationTone

    public init(
        id: String = UUID().uuidString,
        name: String,
        category: TemplateCategory,
        subject: String? = nil,
        body: String,
        tone: CommunicationTone
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subject = subject
        self.body = body
        self.tone = tone
    }
}

public enum TemplateCategory: String, Codable, Sendable, CaseIterable {
    case email
    case message
    case social
    case professional
    case personal

    public var displayName: String {
        rawValue.capitalized
    }
}
