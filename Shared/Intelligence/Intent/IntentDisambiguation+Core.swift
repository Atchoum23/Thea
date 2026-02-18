// IntentDisambiguation+Core.swift
// Thea
//
// IntentDisambiguator class implementation.

import Foundation
import os.log

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
        do {
            let regex = try NSRegularExpression(pattern: filePattern)
            if let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) {
                let range = Range(match.range, in: query)!
                entities.append(IntentEntity(
                    type: .fileName,
                    value: String(query[range])
                ))
            }
        } catch {
            logger.debug("Invalid file pattern regex: \(error.localizedDescription)")
        }

        // Extract function names (camelCase or snake_case)
        let funcPattern = #"\b[a-z][a-zA-Z0-9_]*\("#
        do {
            let regex = try NSRegularExpression(pattern: funcPattern)
            if let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) {
                let range = Range(match.range, in: query)!
                let value = String(query[range]).dropLast()  // Remove (
                entities.append(IntentEntity(
                    type: .functionName,
                    value: String(value)
                ))
            }
        } catch {
            logger.debug("Invalid function pattern regex: \(error.localizedDescription)")
        }

        // Extract paths
        let pathPattern = #"[/~][\w/.-]+"#
        do {
            let regex = try NSRegularExpression(pattern: pathPattern)
            if let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) {
                let range = Range(match.range, in: query)!
                entities.append(IntentEntity(
                    type: .path,
                    value: String(query[range])
                ))
            }
        } catch {
            logger.debug("Invalid path pattern regex: \(error.localizedDescription)")
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
