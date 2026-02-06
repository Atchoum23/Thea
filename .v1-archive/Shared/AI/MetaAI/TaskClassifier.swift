// TaskClassifier.swift
import Foundation
import OSLog

/// Classifies user queries into task types for optimal model routing.
/// Uses AI-powered semantic classification with keyword matching fallback.
@MainActor
@Observable
public final class TaskClassifier {
    public static let shared = TaskClassifier()

    private let config = OrchestratorConfiguration.load()
    private let logger = Logger(subsystem: "com.thea.metaai", category: "TaskClassifier")

    /// Enable AI-powered semantic classification (vs keyword-based)
    public var useSemanticClassification: Bool = true

    private init() {}

    // MARK: - Public API

    /// Classify a query into a task type with confidence score
    /// Uses AI-powered semantic classification when enabled
    public func classify(_ query: String, context: [String] = []) async throws -> TaskClassification {
        // 1. Try AI-powered semantic classification first (if enabled)
        if useSemanticClassification {
            do {
                let aiClassification = try await AIIntelligence.shared.classifyTask(query, conversationContext: context)

                // Convert AITaskClassification to TaskClassification
                let result = TaskClassification(
                    primaryType: aiClassification.primaryType,
                    secondaryTypes: aiClassification.secondaryTypes,
                    confidence: Float(aiClassification.confidence),
                    reasoning: aiClassification.reasoning,
                    source: .semantic
                )

                logger.info("Semantic classification: \(aiClassification.primaryType.rawValue) with \(String(format: "%.0f%%", aiClassification.confidence * 100)) confidence")

                // If AI confidence is high enough, use it
                if result.confidence >= 0.7 {
                    return result
                }

                // Otherwise, combine with keyword classification
                let keywordResult = classifyByKeywords(query)

                // Use the higher confidence result
                if keywordResult.confidence > result.confidence {
                    logger.debug("Keyword classification had higher confidence, using that")
                    return keywordResult
                }

                return result

            } catch {
                logger.warning("Semantic classification failed: \(error.localizedDescription)")
                // Fall through to keyword classification
            }
        }

        // 2. Try keyword-based classification (fast fallback)
        let keywordResult = classifyByKeywords(query)

        // 3. If confidence is high enough, use keyword result
        if keywordResult.confidence >= config.classificationConfidenceThreshold {
            return keywordResult
        }

        // 4. If AI classification is enabled via old path and confidence is low, use AI
        if config.useAIForClassification && !useSemanticClassification {
            return try await classifyWithAI(query, fallback: keywordResult)
        }

        // 5. Return keyword result as fallback
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
        // Use a fast, cheap model for classification
        // Priority: local model > gpt-4o-mini > fallback

        // Try to get a fast provider
        guard let provider = getClassificationProvider() else {
            return fallback
        }

        let prompt = createClassificationPrompt(for: query)

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "classifier"
            )

            var response = ""
            let stream = try await provider.chat(
                messages: [message],
                model: getClassificationModelID(for: provider),
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    response += text
                }
            }

            // Parse the AI response
            return try parseClassificationResponse(response, query: query, fallback: fallback)

        } catch {
            print("⚠️ AI classification failed: \(error), using keyword fallback")
            return fallback
        }
    }

    private func getClassificationProvider() -> AIProvider? {
        // Prefer local models for classification (fast, free)
        if let localProvider = ProviderRegistry.shared.getLocalProvider() {
            return localProvider
        }

        // Fallback to cheap cloud model
        if let openRouter = ProviderRegistry.shared.getProvider(id: "openrouter") {
            return openRouter
        }

        if let openAI = ProviderRegistry.shared.getProvider(id: "openai") {
            return openAI
        }

        return nil
    }

    private func getClassificationModelID(for provider: AIProvider) -> String {
        if provider.metadata.name == "local" {
            return provider.metadata.name
        }
        // Use cheapest/fastest model for classification
        return "openai/gpt-4o-mini"
    }

    private func createClassificationPrompt(for query: String) -> String {
        let taskTypes = TaskType.allCases.map { "\($0.rawValue): \($0.displayName)" }.joined(separator: "\n")

        return """
        Classify the following user query into the most appropriate task type.

        Query: "\(query)"

        Available task types:
        \(taskTypes)

        Respond with ONLY a JSON object (no markdown, no explanation):
        {"taskType": "taskTypeRawValue", "confidence": 0.0-1.0, "reasoning": "brief explanation"}

        Choose the single most appropriate task type. Be precise.
        """
    }

    private func parseClassificationResponse(
        _ response: String,
        query: String,
        fallback: TaskClassification
    ) throws -> TaskClassification {
        // Extract JSON from response
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            return fallback
        }

        struct ClassificationResponse: Codable {
            let taskType: String
            let confidence: Double
            let reasoning: String
        }

        do {
            let decoded = try JSONDecoder().decode(ClassificationResponse.self, from: data)

            guard let taskType = TaskType(rawValue: decoded.taskType) else {
                return fallback
            }

            return TaskClassification(
                primaryType: taskType,
                secondaryTypes: [],
                confidence: Float(decoded.confidence),
                reasoning: decoded.reasoning
            )
        } catch {
            print("⚠️ Failed to parse classification response: \(error)")
            return fallback
        }
    }

    private func extractJSON(from response: String) -> String {
        // Try to find JSON object in response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            return String(response[startIndex...endIndex])
        }
        return response
    }
}

// MARK: - Supporting Types

/// Result of task classification
public struct TaskClassification: Sendable {
    /// How the classification was determined
    public enum Source: String, Sendable {
        case keyword   // Pattern/keyword matching
        case semantic  // AI-powered semantic understanding
        case hybrid    // Combination of both
    }

    public let primaryType: TaskType
    public let secondaryTypes: [TaskType]
    public let confidence: Float // 0.0 - 1.0
    public let reasoning: String
    public let source: Source

    public init(
        primaryType: TaskType,
        secondaryTypes: [TaskType] = [],
        confidence: Float,
        reasoning: String,
        source: Source = .keyword
    ) {
        self.primaryType = primaryType
        self.secondaryTypes = secondaryTypes
        self.confidence = confidence
        self.reasoning = reasoning
        self.source = source
    }

    /// Check if classification is confident enough to use
    public func isConfident(threshold: Float = 0.7) -> Bool {
        confidence >= threshold
    }

    /// Get all relevant task types (primary + secondary)
    public var allTypes: [TaskType] {
        [primaryType] + secondaryTypes
    }

    /// Human-readable description
    public var description: String {
        var desc = "\(primaryType.rawValue)"
        if !secondaryTypes.isEmpty {
            desc += " (also: \(secondaryTypes.map(\.rawValue).joined(separator: ", ")))"
        }
        desc += " [\(source.rawValue), \(Int(confidence * 100))%]"
        return desc
    }
}
