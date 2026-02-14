// IntentDisambiguation.swift
// Thea V2
//
// User intent disambiguation system
// Detects ambiguity, generates clarifying questions, and confirms intent

import Foundation
import OSLog

// MARK: - User Intent

/// Represents a parsed user intent
public struct UserIntent: Identifiable, Sendable {
    public let id: UUID
    public let originalQuery: String
    public let primaryIntent: IntentCategory
    public let confidence: Float
    public let ambiguityScore: Float  // 0 = clear, 1 = highly ambiguous
    public let possibleInterpretations: [IntentInterpretation]
    public let extractedEntities: [IntentEntity]
    public let requiredConfirmation: Bool
    public let riskLevel: IntentRiskLevel

    public init(
        id: UUID = UUID(),
        originalQuery: String,
        primaryIntent: IntentCategory,
        confidence: Float,
        ambiguityScore: Float,
        possibleInterpretations: [IntentInterpretation] = [],
        extractedEntities: [IntentEntity] = [],
        requiredConfirmation: Bool = false,
        riskLevel: IntentRiskLevel = .low
    ) {
        self.id = id
        self.originalQuery = originalQuery
        self.primaryIntent = primaryIntent
        self.confidence = confidence
        self.ambiguityScore = ambiguityScore
        self.possibleInterpretations = possibleInterpretations
        self.extractedEntities = extractedEntities
        self.requiredConfirmation = requiredConfirmation
        self.riskLevel = riskLevel
    }
}

public enum IntentCategory: String, Codable, Sendable {
    case codeGeneration
    case codeModification
    case codeExplanation
    case debugging
    case refactoring
    case testing
    case documentation
    case research
    case fileOperation
    case systemCommand
    case question
    case conversation
    case taskManagement
    case unknown
}

public enum IntentRiskLevel: String, Sendable {
    case low       // Safe operations
    case medium    // Reversible changes
    case high      // Significant changes
    case critical  // Destructive/irreversible
}

/// A possible interpretation of the user's intent
public struct IntentInterpretation: Identifiable, Sendable {
    public let id: UUID
    public let description: String
    public let category: IntentCategory
    public let confidence: Float
    public let assumptions: [String]
    public let requiredContext: [String]

    public init(
        id: UUID = UUID(),
        description: String,
        category: IntentCategory,
        confidence: Float,
        assumptions: [String] = [],
        requiredContext: [String] = []
    ) {
        self.id = id
        self.description = description
        self.category = category
        self.confidence = confidence
        self.assumptions = assumptions
        self.requiredContext = requiredContext
    }
}

/// An entity extracted from the query
public struct IntentEntity: Identifiable, Sendable {
    public let id: UUID
    public let type: EntityType
    public let value: String
    public let confidence: Float
    public let span: Range<String.Index>?

    public init(
        id: UUID = UUID(),
        type: EntityType,
        value: String,
        confidence: Float = 0.9,
        span: Range<String.Index>? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.confidence = confidence
        self.span = span
    }

    public enum EntityType: String, Sendable {
        case fileName
        case functionName
        case className
        case variableName
        case path
        case url
        case number
        case language
        case framework
        case command
        case action
    }
}

// MARK: - Clarifying Question

/// A clarifying question to ask the user
public struct ClarifyingQuestion: Identifiable, Sendable {
    public let id: UUID
    public let question: String
    public let context: String
    public let options: [QuestionOption]
    public let isRequired: Bool
    public let defaultOption: UUID?
    public let questionType: QuestionType

    public init(
        id: UUID = UUID(),
        question: String,
        context: String = "",
        options: [QuestionOption] = [],
        isRequired: Bool = true,
        defaultOption: UUID? = nil,
        questionType: QuestionType = .multipleChoice
    ) {
        self.id = id
        self.question = question
        self.context = context
        self.options = options
        self.isRequired = isRequired
        self.defaultOption = defaultOption
        self.questionType = questionType
    }

    public enum QuestionType: String, Sendable {
        case multipleChoice
        case yesNo
        case freeText
        case confirmation
        case selection
    }
}

/// An option for a clarifying question
public struct QuestionOption: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let description: String
    public let value: String
    public let isRecommended: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        description: String = "",
        value: String,
        isRecommended: Bool = false
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.value = value
        self.isRecommended = isRecommended
    }
}

// MARK: - Intent Confirmation

/// Confirmation request for high-stakes actions
public struct IntentConfirmation: Identifiable, Sendable {
    public let id: UUID
    public let intent: UserIntent
    public let summary: String
    public let actions: [PlannedAction]
    public let warnings: [String]
    public let requiresExplicitConfirmation: Bool
    public let confirmationPhrase: String?

    public init(
        id: UUID = UUID(),
        intent: UserIntent,
        summary: String,
        actions: [PlannedAction],
        warnings: [String] = [],
        requiresExplicitConfirmation: Bool = false,
        confirmationPhrase: String? = nil
    ) {
        self.id = id
        self.intent = intent
        self.summary = summary
        self.actions = actions
        self.warnings = warnings
        self.requiresExplicitConfirmation = requiresExplicitConfirmation
        self.confirmationPhrase = confirmationPhrase
    }

    public struct PlannedAction: Identifiable, Sendable {
        public let id: UUID
        public let description: String
        public let type: ActionType
        public let target: String
        public let isReversible: Bool

        public init(
            id: UUID = UUID(),
            description: String,
            type: ActionType,
            target: String,
            isReversible: Bool = true
        ) {
            self.id = id
            self.description = description
            self.type = type
            self.target = target
            self.isReversible = isReversible
        }

        public enum ActionType: String, Sendable {
            case create
            case modify
            case delete
            case execute
            case read
            case send
        }
    }
}

// MARK: - Disambiguation Result

/// Result of disambiguation process
public struct DisambiguationResult: Sendable {
    public let intent: UserIntent
    public let clarificationNeeded: Bool
    public let questions: [ClarifyingQuestion]
    public let confirmationNeeded: Bool
    public let confirmation: IntentConfirmation?
    public let canProceed: Bool

    public init(
        intent: UserIntent,
        clarificationNeeded: Bool = false,
        questions: [ClarifyingQuestion] = [],
        confirmationNeeded: Bool = false,
        confirmation: IntentConfirmation? = nil,
        canProceed: Bool = true
    ) {
        self.intent = intent
        self.clarificationNeeded = clarificationNeeded
        self.questions = questions
        self.confirmationNeeded = confirmationNeeded
        self.confirmation = confirmation
        self.canProceed = canProceed
    }
}

