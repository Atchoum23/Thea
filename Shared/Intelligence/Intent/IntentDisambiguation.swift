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

// MARK: - Intent Disambiguator

/// Main engine for intent disambiguation
@MainActor
public final class IntentDisambiguator: ObservableObject {
    public static let shared = IntentDisambiguator()

    private let logger = Logger(subsystem: "com.thea.intent", category: "Disambiguator")

    // Configuration
    public var ambiguityThreshold: Float = 0.3  // Above this = needs clarification
    public var confidenceThreshold: Float = 0.7  // Below this = needs clarification
    public var highRiskActions: Set<String> = ["delete", "remove", "drop", "reset", "force", "overwrite"]

    @Published public private(set) var pendingQuestions: [ClarifyingQuestion] = []
    @Published public private(set) var pendingConfirmation: IntentConfirmation?

    // MARK: - Intent Parsing

    /// Parse a user query into intent
    public func parseIntent(_ query: String) -> UserIntent {
        // Classify primary intent
        let (category, categoryConfidence) = classifyIntent(query)

        // Extract entities
        let entities = extractEntities(query)

        // Detect ambiguity
        let (ambiguityScore, interpretations) = detectAmbiguity(query, category: category)

        // Determine risk level
        let riskLevel = assessIntentRiskLevel(query, category: category)

        // Check if confirmation required
        let requiresConfirmation = riskLevel == .high || riskLevel == .critical

        return UserIntent(
            originalQuery: query,
            primaryIntent: category,
            confidence: categoryConfidence,
            ambiguityScore: ambiguityScore,
            possibleInterpretations: interpretations,
            extractedEntities: entities,
            requiredConfirmation: requiresConfirmation,
            riskLevel: riskLevel
        )
    }

    /// Full disambiguation process
    public func disambiguate(_ query: String) -> DisambiguationResult {
        let intent = parseIntent(query)

        // Check if clarification needed
        let needsClarification = intent.ambiguityScore > ambiguityThreshold ||
                                 intent.confidence < confidenceThreshold

        var questions: [ClarifyingQuestion] = []
        if needsClarification {
            questions = generateClarifyingQuestions(intent)
            pendingQuestions = questions
        }

        // Check if confirmation needed
        var confirmation: IntentConfirmation?
        if intent.requiredConfirmation {
            confirmation = generateConfirmation(intent)
            pendingConfirmation = confirmation
        }

        let canProceed = !needsClarification && !intent.requiredConfirmation

        return DisambiguationResult(
            intent: intent,
            clarificationNeeded: needsClarification,
            questions: questions,
            confirmationNeeded: intent.requiredConfirmation,
            confirmation: confirmation,
            canProceed: canProceed
        )
    }

    // MARK: - Answer Processing

    /// Process answer to clarifying question
    public func processAnswer(questionId: UUID, answer: String) -> UserIntent? {
        guard let questionIndex = pendingQuestions.firstIndex(where: { $0.id == questionId }) else {
            return nil
        }

        let question = pendingQuestions[questionIndex]
        pendingQuestions.remove(at: questionIndex)

        // Update intent based on answer
        logger.info("Processed answer for question: \(question.question) -> \(answer)")

        return nil  // Return updated intent if needed
    }

    /// Process confirmation response
    public func processConfirmation(confirmed: Bool) -> Bool {
        guard let confirmation = pendingConfirmation else { return false }

        pendingConfirmation = nil

        if confirmed {
            logger.info("User confirmed action: \(confirmation.summary)")
            return true
        } else {
            logger.info("User rejected action: \(confirmation.summary)")
            return false
        }
    }

    // MARK: - Private Helpers

    private func classifyIntent(_ query: String) -> (IntentCategory, Float) {
        let lowercased = query.lowercased()

        // Code generation indicators
        if lowercased.contains("create") || lowercased.contains("write") ||
           lowercased.contains("generate") || lowercased.contains("implement") {
            if lowercased.contains("test") {
                return (.testing, 0.85)
            }
            if lowercased.contains("doc") {
                return (.documentation, 0.85)
            }
            return (.codeGeneration, 0.85)
        }

        // Modification indicators
        if lowercased.contains("change") || lowercased.contains("modify") ||
           lowercased.contains("update") || lowercased.contains("edit") {
            return (.codeModification, 0.85)
        }

        // Debugging indicators
        if lowercased.contains("debug") || lowercased.contains("fix") ||
           lowercased.contains("error") || lowercased.contains("bug") {
            return (.debugging, 0.85)
        }

        // Refactoring indicators
        if lowercased.contains("refactor") || lowercased.contains("restructure") ||
           lowercased.contains("reorganize") {
            return (.refactoring, 0.85)
        }

        // Question indicators
        if lowercased.contains("what") || lowercased.contains("how") ||
           lowercased.contains("why") || lowercased.contains("explain") ||
           query.hasSuffix("?") {
            return (.question, 0.80)
        }

        // Research indicators
        if lowercased.contains("research") || lowercased.contains("find") ||
           lowercased.contains("search") || lowercased.contains("look up") {
            return (.research, 0.80)
        }

        // File operation indicators
        if lowercased.contains("file") || lowercased.contains("folder") ||
           lowercased.contains("directory") {
            return (.fileOperation, 0.75)
        }

        // System command indicators
        if lowercased.contains("run") || lowercased.contains("execute") ||
           lowercased.contains("command") {
            return (.systemCommand, 0.75)
        }

        return (.unknown, 0.40)
    }

    private func extractEntities(_ query: String) -> [IntentEntity] {
        var entities: [IntentEntity] = []

        // Extract file names (simple pattern)
        let filePattern = #"\b[\w-]+\.(swift|py|js|ts|json|md|txt|yml|yaml)\b"#
        if let regex = try? NSRegularExpression(pattern: filePattern),
           let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) {
            let range = Range(match.range, in: query)!
            entities.append(IntentEntity(
                type: .fileName,
                value: String(query[range])
            ))
        }

        // Extract function names (camelCase or snake_case)
        let funcPattern = #"\b[a-z][a-zA-Z0-9_]*\("#
        if let regex = try? NSRegularExpression(pattern: funcPattern),
           let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) {
            let range = Range(match.range, in: query)!
            let value = String(query[range]).dropLast()  // Remove (
            entities.append(IntentEntity(
                type: .functionName,
                value: String(value)
            ))
        }

        // Extract paths
        let pathPattern = #"[/~][\w/.-]+"#
        if let regex = try? NSRegularExpression(pattern: pathPattern),
           let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) {
            let range = Range(match.range, in: query)!
            entities.append(IntentEntity(
                type: .path,
                value: String(query[range])
            ))
        }

        return entities
    }

    private func detectAmbiguity(_ query: String, category: IntentCategory) -> (Float, [IntentInterpretation]) {
        var interpretations: [IntentInterpretation] = []
        var ambiguityScore: Float = 0.0

        let lowercased = query.lowercased()

        // Check for vague terms
        let vagueTerms = ["it", "this", "that", "something", "stuff", "thing"]
        for term in vagueTerms where lowercased.contains(term) {
            ambiguityScore += 0.2
        }

        // Check for multiple possible actions
        let actionWords = ["create", "modify", "delete", "update", "read", "write"]
        let foundActions = actionWords.filter { lowercased.contains($0) }
        if foundActions.count > 1 {
            ambiguityScore += 0.3

            for action in foundActions {
                interpretations.append(IntentInterpretation(
                    description: "Perform \(action) operation",
                    category: category,
                    confidence: 0.5,
                    assumptions: ["User wants to \(action)"]
                ))
            }
        }

        // Check for missing target
        if category == .codeModification && !query.contains("in ") && !query.contains("file") {
            ambiguityScore += 0.2
            interpretations.append(IntentInterpretation(
                description: "Modify current file",
                category: category,
                confidence: 0.6,
                assumptions: ["Target is the current file"]
            ))
            interpretations.append(IntentInterpretation(
                description: "Modify all matching files",
                category: category,
                confidence: 0.4,
                assumptions: ["Target is all relevant files"]
            ))
        }

        return (min(1.0, ambiguityScore), interpretations)
    }

    private func assessIntentRiskLevel(_ query: String, category: IntentCategory) -> IntentRiskLevel {
        let lowercased = query.lowercased()

        // Critical actions
        if lowercased.contains("delete all") || lowercased.contains("drop database") ||
           lowercased.contains("rm -rf") || lowercased.contains("force push") {
            return .critical
        }

        // High risk actions
        for action in highRiskActions where lowercased.contains(action) {
            return .high
        }

        // Medium risk categories
        if category == .systemCommand || category == .fileOperation {
            if lowercased.contains("all") || lowercased.contains("recursive") {
                return .medium
            }
        }

        return .low
    }

    private func generateClarifyingQuestions(_ intent: UserIntent) -> [ClarifyingQuestion] {
        var questions: [ClarifyingQuestion] = []

        // For ambiguous interpretations
        if intent.possibleInterpretations.count > 1 {
            let options = intent.possibleInterpretations.map { interpretation in
                QuestionOption(
                    label: interpretation.description,
                    description: interpretation.assumptions.joined(separator: ", "),
                    value: interpretation.id.uuidString,
                    isRecommended: interpretation.confidence > 0.5
                )
            }

            questions.append(ClarifyingQuestion(
                question: "I found multiple ways to interpret your request. Which did you mean?",
                context: "Your request: \"\(intent.originalQuery)\"",
                options: options,
                questionType: .multipleChoice
            ))
        }

        // For missing file target
        if intent.primaryIntent == .codeModification &&
           !intent.extractedEntities.contains(where: { $0.type == .fileName }) {
            questions.append(ClarifyingQuestion(
                question: "Which file should I modify?",
                context: "Please specify the target file",
                options: [
                    QuestionOption(label: "Current file", value: "current", isRecommended: true),
                    QuestionOption(label: "All matching files", value: "all"),
                    QuestionOption(label: "Let me specify", value: "specify")
                ],
                questionType: .multipleChoice
            ))
        }

        return questions
    }

    private func generateConfirmation(_ intent: UserIntent) -> IntentConfirmation {
        var actions: [IntentConfirmation.PlannedAction] = []
        var warnings: [String] = []

        // Generate planned actions based on intent
        switch intent.primaryIntent {
        case .codeModification:
            actions.append(IntentConfirmation.PlannedAction(
                description: "Modify code based on request",
                type: .modify,
                target: intent.extractedEntities.first { $0.type == .fileName }?.value ?? "target file",
                isReversible: true
            ))
        case .fileOperation:
            actions.append(IntentConfirmation.PlannedAction(
                description: "Perform file operation",
                type: .modify,
                target: "file system",
                isReversible: false
            ))
            warnings.append("This operation may not be reversible")
        case .systemCommand:
            actions.append(IntentConfirmation.PlannedAction(
                description: "Execute system command",
                type: .execute,
                target: "system",
                isReversible: false
            ))
            warnings.append("System commands may have lasting effects")
        default:
            break
        }

        // Add risk-specific warnings
        switch intent.riskLevel {
        case .critical:
            warnings.append("⚠️ CRITICAL: This action is destructive and cannot be undone")
        case .high:
            warnings.append("This action may cause significant changes")
        case .medium:
            warnings.append("Please review the planned actions carefully")
        case .low:
            break
        }

        let summary = "I will \(intent.primaryIntent.rawValue) based on: \"\(intent.originalQuery)\""

        return IntentConfirmation(
            intent: intent,
            summary: summary,
            actions: actions,
            warnings: warnings,
            requiresExplicitConfirmation: intent.riskLevel == .critical,
            confirmationPhrase: intent.riskLevel == .critical ? "confirm delete" : nil
        )
    }
}
