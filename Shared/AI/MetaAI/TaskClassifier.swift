// TaskClassifier.swift
import Foundation

/// Classifies user queries into task types for optimal model routing.
/// Uses keyword matching and optional AI-based classification for accuracy.
@MainActor
@Observable
public final class TaskClassifier {
    public static let shared = TaskClassifier()

    private let config = OrchestratorConfiguration.load()

    private init() {}

    // MARK: - Public API

    /// Classify a query into a task type with confidence score
    public func classify(_ query: String) async throws -> TaskClassification {
        // 1. Try keyword-based classification first (fast)
        let keywordResult = classifyByKeywords(query)

        // 2. If confidence is high enough, use keyword result
        if keywordResult.confidence >= config.classificationConfidenceThreshold {
            return keywordResult
        }

        // 3. If AI classification is enabled and confidence is low, use AI
        if config.useAIForClassification {
            return try await classifyWithAI(query, fallback: keywordResult)
        }

        // 4. Return keyword result as fallback
        return keywordResult
    }

    /// Assess query complexity level
    public func assessComplexity(_ query: String) -> QueryComplexity {
        let wordCount = query.split(separator: " ").count
        let hasMultipleQuestions = query.components(separatedBy: "?").count > 2
        let hasSteps = query.contains("first") || query.contains("then") || query.contains("finally")
        let hasMultipleTasks = query.contains("and also") || query.contains("additionally")

        if wordCount < 20 && !hasMultipleQuestions && !hasSteps {
            return .simple
        }

        if hasMultipleQuestions || hasSteps || hasMultipleTasks || wordCount > 100 {
            return .complex
        }

        return .moderate
    }

    // MARK: - Keyword-Based Classification

    private func classifyByKeywords(_ query: String) -> TaskClassification {
        let lowercased = query.lowercased()

        // Code generation patterns
        if matchesCodePatterns(lowercased) {
            return TaskClassification(
                primaryType: .codeGeneration,
                secondaryTypes: [],
                confidence: 0.85,
                reasoning: "Contains code generation keywords"
            )
        }

        // Math and logic patterns
        if matchesMathPatterns(lowercased) {
            return TaskClassification(
                primaryType: .mathLogic,
                secondaryTypes: [],
                confidence: 0.9,
                reasoning: "Contains mathematical or logical operations"
            )
        }

        // Summarization patterns
        if matchesSummarizationPatterns(lowercased) {
            return TaskClassification(
                primaryType: .summarization,
                secondaryTypes: [],
                confidence: 0.8,
                reasoning: "Request for summarization or condensing"
            )
        }

        // Complex reasoning patterns
        if matchesReasoningPatterns(lowercased) {
            return TaskClassification(
                primaryType: .complexReasoning,
                secondaryTypes: [],
                confidence: 0.75,
                reasoning: "Requires complex reasoning or analysis"
            )
        }

        // Creative writing patterns
        if matchesCreativePatterns(lowercased) {
            return TaskClassification(
                primaryType: .creativeWriting,
                secondaryTypes: [],
                confidence: 0.8,
                reasoning: "Creative writing or storytelling request"
            )
        }

        // Debugging patterns
        if matchesDebuggingPatterns(lowercased) {
            return TaskClassification(
                primaryType: .debugging,
                secondaryTypes: [.codeGeneration],
                confidence: 0.85,
                reasoning: "Debugging or error resolution request"
            )
        }

        // Analysis patterns
        if matchesAnalysisPatterns(lowercased) {
            return TaskClassification(
                primaryType: .analysis,
                secondaryTypes: [],
                confidence: 0.7,
                reasoning: "Request for analysis or evaluation"
            )
        }

        // Planning patterns
        if matchesPlanningPatterns(lowercased) {
            return TaskClassification(
                primaryType: .planning,
                secondaryTypes: [],
                confidence: 0.75,
                reasoning: "Planning or strategy request"
            )
        }

        // Factual lookup patterns
        if matchesFactualPatterns(lowercased) {
            return TaskClassification(
                primaryType: .factual,
                secondaryTypes: [],
                confidence: 0.7,
                reasoning: "Factual information lookup"
            )
        }

        // Default to simple Q&A with low confidence
        return TaskClassification(
            primaryType: .simpleQA,
            secondaryTypes: [],
            confidence: 0.5,
            reasoning: "No specific pattern matched, defaulting to Q&A"
        )
    }

    // MARK: - Pattern Matching Helpers

    private func matchesCodePatterns(_ query: String) -> Bool {
        let codeKeywords = [
            "write code", "implement", "function", "class", "method",
            "algorithm", "programming", "code for", "script",
            "def ", "func ", "class ", "import ", "package",
            "swift", "python", "javascript", "typescript"
        ]
        return codeKeywords.contains { query.contains($0) }
    }

    private func matchesMathPatterns(_ query: String) -> Bool {
        let mathKeywords = [
            "calculate", "solve", "equation", "formula",
            "integral", "derivative", "matrix", "algebra",
            "geometry", "probability", "statistics",
            "x =", "+ ", "- ", "* ", "/ "
        ]
        return mathKeywords.contains { query.contains($0) }
    }

    private func matchesSummarizationPatterns(_ query: String) -> Bool {
        let summaryKeywords = [
            "summarize", "summary", "condense", "brief",
            "tldr", "tl;dr", "key points", "main points",
            "in short", "overview"
        ]
        return summaryKeywords.contains { query.contains($0) }
    }

    private func matchesReasoningPatterns(_ query: String) -> Bool {
        let reasoningKeywords = [
            "why", "explain", "reasoning", "logic",
            "deduce", "infer", "conclude", "analyze deeply",
            "complex question", "philosophical", "ethical"
        ]
        return reasoningKeywords.contains { query.contains($0) }
    }

    private func matchesCreativePatterns(_ query: String) -> Bool {
        let creativeKeywords = [
            "write a story", "poem", "creative", "imagine",
            "fictional", "narrative", "novel", "screenplay",
            "dialogue", "character"
        ]
        return creativeKeywords.contains { query.contains($0) }
    }

    private func matchesDebuggingPatterns(_ query: String) -> Bool {
        let debugKeywords = [
            "debug", "error", "bug", "fix", "not working",
            "broken", "crash", "exception", "traceback",
            "stack trace", "syntax error"
        ]
        return debugKeywords.contains { query.contains($0) }
    }

    private func matchesAnalysisPatterns(_ query: String) -> Bool {
        let analysisKeywords = [
            "analyze", "analysis", "evaluate", "assess",
            "compare", "contrast", "pros and cons",
            "advantages", "disadvantages", "review"
        ]
        return analysisKeywords.contains { query.contains($0) }
    }

    private func matchesPlanningPatterns(_ query: String) -> Bool {
        let planningKeywords = [
            "plan", "strategy", "roadmap", "outline",
            "steps to", "how to", "guide", "process",
            "workflow", "procedure"
        ]
        return planningKeywords.contains { query.contains($0) }
    }

    private func matchesFactualPatterns(_ query: String) -> Bool {
        let factualKeywords = [
            "what is", "who is", "when did", "where is",
            "definition", "meaning", "fact", "information about"
        ]
        return factualKeywords.contains { query.contains($0) }
    }

    // MARK: - AI-Based Classification

    private func classifyWithAI(_ query: String, fallback: TaskClassification) async throws -> TaskClassification {
        // TODO: Implement AI-based classification using a fast model
        // For now, return the keyword-based fallback
        // Future implementation:
        // 1. Use a fast model (gpt-4o-mini or local 7B)
        // 2. Prompt: "Classify this query into one of: [task types]. Return JSON with type and confidence."
        // 3. Parse response and return TaskClassification

        fallback
    }
}

// MARK: - Supporting Types

/// Result of task classification
public struct TaskClassification: Sendable {
    public let primaryType: TaskType
    public let secondaryTypes: [TaskType]
    public let confidence: Float // 0.0 - 1.0
    public let reasoning: String

    public init(
        primaryType: TaskType,
        secondaryTypes: [TaskType] = [],
        confidence: Float,
        reasoning: String
    ) {
        self.primaryType = primaryType
        self.secondaryTypes = secondaryTypes
        self.confidence = confidence
        self.reasoning = reasoning
    }

    /// Check if classification is confident enough to use
    public func isConfident(threshold: Float = 0.7) -> Bool {
        confidence >= threshold
    }

    /// Get all relevant task types (primary + secondary)
    public var allTypes: [TaskType] {
        [primaryType] + secondaryTypes
    }
}
