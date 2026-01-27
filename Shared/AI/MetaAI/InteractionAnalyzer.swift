import Foundation

// MARK: - Interaction Analyzer

// Analyzes conversations and interactions to extract insights and improve responses

/// Represents an analyzed interaction
public struct AnalyzedInteraction: Sendable, Codable, Identifiable {
    public let id: UUID
    public let conversationId: UUID
    public let userMessage: String
    public let assistantResponse: String
    public let analysis: InteractionAnalysis
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        conversationId: UUID,
        userMessage: String,
        assistantResponse: String,
        analysis: InteractionAnalysis,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.conversationId = conversationId
        self.userMessage = userMessage
        self.assistantResponse = assistantResponse
        self.analysis = analysis
        self.timestamp = timestamp
    }
}

/// Detailed analysis of an interaction
public struct InteractionAnalysis: Sendable, Codable {
    public let intent: UserIntent
    public let sentiment: Sentiment
    public let complexity: InteractionComplexity
    public let topics: [String]
    public let responseQuality: ResponseQuality
    public let suggestions: [String]

    public init(
        intent: UserIntent,
        sentiment: Sentiment,
        complexity: InteractionComplexity,
        topics: [String],
        responseQuality: ResponseQuality,
        suggestions: [String]
    ) {
        self.intent = intent
        self.sentiment = sentiment
        self.complexity = complexity
        self.topics = topics
        self.responseQuality = responseQuality
        self.suggestions = suggestions
    }
}

/// User's intent category
public enum UserIntent: String, Codable, Sendable, CaseIterable {
    case question // Seeking information
    case instruction // Requesting action
    case clarification // Asking for explanation
    case feedback // Providing feedback
    case conversation // General chat
    case complaint // Expressing dissatisfaction
    case praise // Expressing satisfaction
    case unknown

    public var displayName: String {
        switch self {
        case .question: "Question"
        case .instruction: "Instruction"
        case .clarification: "Clarification"
        case .feedback: "Feedback"
        case .conversation: "Conversation"
        case .complaint: "Complaint"
        case .praise: "Praise"
        case .unknown: "Unknown"
        }
    }
}

/// Sentiment analysis result
public struct Sentiment: Sendable, Codable {
    public let polarity: Polarity
    public let score: Double // -1 to 1
    public let confidence: Double // 0 to 1
    public let emotions: [String: Double] // Emotion -> intensity

    public enum Polarity: String, Codable, Sendable {
        case positive
        case neutral
        case negative
        case mixed
    }

    public init(
        polarity: Polarity,
        score: Double,
        confidence: Double,
        emotions: [String: Double] = [:]
    ) {
        self.polarity = polarity
        self.score = score
        self.confidence = confidence
        self.emotions = emotions
    }
}

/// Complexity level of the interaction
public enum InteractionComplexity: String, Codable, Sendable {
    case simple // Single, clear request
    case moderate // Some nuance or context needed
    case complex // Multiple aspects or deep reasoning
    case veryComplex // Expert-level, multi-step

    public var weight: Double {
        switch self {
        case .simple: 1.0
        case .moderate: 1.5
        case .complex: 2.0
        case .veryComplex: 3.0
        }
    }
}

/// Quality assessment of a response
public struct ResponseQuality: Sendable, Codable {
    public let relevance: Double // 0-1, how relevant to query
    public let completeness: Double // 0-1, how complete
    public let clarity: Double // 0-1, how clear
    public let accuracy: Double // 0-1, estimated accuracy
    public let helpfulness: Double // 0-1, overall helpfulness
    public let overallScore: Double // 0-1, weighted average

    public init(
        relevance: Double,
        completeness: Double,
        clarity: Double,
        accuracy: Double,
        helpfulness: Double
    ) {
        self.relevance = relevance
        self.completeness = completeness
        self.clarity = clarity
        self.accuracy = accuracy
        self.helpfulness = helpfulness

        // Weighted average
        overallScore = (
            relevance * 0.25 +
                completeness * 0.20 +
                clarity * 0.15 +
                accuracy * 0.25 +
                helpfulness * 0.15
        )
    }
}

/// Interaction Analyzer for conversation analysis
@MainActor
@Observable
public final class InteractionAnalyzer {
    public static let shared = InteractionAnalyzer()

    private(set) var analyzedInteractions: [AnalyzedInteraction] = []
    private(set) var aggregateMetrics = AggregateMetrics()
    private(set) var isAnalyzing = false

    private init() {}

    // MARK: - Analysis

    /// Analyze a single interaction
    public func analyze(
        userMessage: String,
        assistantResponse: String,
        conversationId: UUID
    ) async -> AnalyzedInteraction {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Detect intent
        let intent = detectIntent(userMessage)

        // Analyze sentiment
        let sentiment = analyzeSentiment(userMessage)

        // Assess complexity
        let complexity = assessComplexity(userMessage)

        // Extract topics
        let topics = extractTopics(userMessage + " " + assistantResponse)

        // Evaluate response quality
        let quality = evaluateResponseQuality(
            query: userMessage,
            response: assistantResponse
        )

        // Generate suggestions
        let suggestions = generateSuggestions(
            intent: intent,
            sentiment: sentiment,
            quality: quality
        )

        let analysis = InteractionAnalysis(
            intent: intent,
            sentiment: sentiment,
            complexity: complexity,
            topics: topics,
            responseQuality: quality,
            suggestions: suggestions
        )

        let interaction = AnalyzedInteraction(
            conversationId: conversationId,
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            analysis: analysis
        )

        analyzedInteractions.append(interaction)
        updateAggregateMetrics()

        return interaction
    }

    // MARK: - Intent Detection

    private func detectIntent(_ message: String) -> UserIntent {
        let lower = message.lowercased()

        if lower.contains("?") || lower.hasPrefix("what") || lower.hasPrefix("how") ||
            lower.hasPrefix("why") || lower.hasPrefix("when") || lower.hasPrefix("who") ||
            lower.hasPrefix("where") || lower.hasPrefix("which")
        {
            return .question
        }

        if lower.hasPrefix("please") || lower.hasPrefix("can you") || lower.hasPrefix("could you") ||
            lower.contains("create") || lower.contains("make") || lower.contains("build") ||
            lower.contains("write") || lower.contains("generate")
        {
            return .instruction
        }

        if lower.contains("explain") || lower.contains("clarify") || lower.contains("what do you mean") ||
            lower.contains("elaborate")
        {
            return .clarification
        }

        if lower.contains("thanks") || lower.contains("great") || lower.contains("excellent") ||
            lower.contains("perfect") || lower.contains("good job")
        {
            return .praise
        }

        if lower.contains("wrong") || lower.contains("incorrect") || lower.contains("bad") ||
            lower.contains("not helpful") || lower.contains("disappointed")
        {
            return .complaint
        }

        if lower.contains("think") || lower.contains("opinion") || lower.contains("feedback") {
            return .feedback
        }

        return .conversation
    }

    // MARK: - Sentiment Analysis

    private func analyzeSentiment(_ message: String) -> Sentiment {
        let lower = message.lowercased()

        // Simple keyword-based sentiment (production would use ML)
        var score = 0.0
        var emotions: [String: Double] = [:]

        // Positive indicators
        let positiveWords = ["good", "great", "excellent", "thanks", "helpful", "amazing", "perfect", "love", "appreciate"]
        for word in positiveWords where lower.contains(word) {
            score += 0.2
            emotions["joy"] = (emotions["joy"] ?? 0) + 0.3
        }

        // Negative indicators
        let negativeWords = ["bad", "wrong", "error", "problem", "issue", "hate", "terrible", "awful", "disappointed"]
        for word in negativeWords where lower.contains(word) {
            score -= 0.2
            emotions["frustration"] = (emotions["frustration"] ?? 0) + 0.3
        }

        // Frustration indicators
        let frustrationWords = ["again", "still", "yet", "why won't", "doesn't work"]
        for word in frustrationWords where lower.contains(word) {
            score -= 0.1
            emotions["frustration"] = (emotions["frustration"] ?? 0) + 0.2
        }

        score = max(-1, min(1, score))

        let polarity: Sentiment.Polarity = if score > 0.3 {
            .positive
        } else if score < -0.3 {
            .negative
        } else if !emotions.isEmpty {
            .mixed
        } else {
            .neutral
        }

        return Sentiment(
            polarity: polarity,
            score: score,
            confidence: 0.7,
            emotions: emotions
        )
    }

    // MARK: - Complexity Assessment

    private func assessComplexity(_ message: String) -> InteractionComplexity {
        let wordCount = message.components(separatedBy: .whitespaces).count
        let sentenceCount = message.components(separatedBy: CharacterSet(charactersIn: ".!?")).count
        let hasMultipleParts = message.contains(" and ") || message.contains(" also ") || message.contains(" then ")

        if wordCount < 10 && sentenceCount <= 1 {
            return .simple
        } else if wordCount < 30 && sentenceCount <= 2 && !hasMultipleParts {
            return .moderate
        } else if wordCount < 75 || hasMultipleParts {
            return .complex
        } else {
            return .veryComplex
        }
    }

    // MARK: - Topic Extraction

    private func extractTopics(_ text: String) -> [String] {
        // Simple keyword extraction (production would use NLP/NER)
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 4 }

        // Remove common words
        let stopWords = Set(["about", "after", "again", "being", "could", "would", "should", "their", "there", "these", "those", "which", "where", "while"])
        let filtered = words.filter { !stopWords.contains($0) }

        // Get unique topics
        let unique = Array(Set(filtered))

        // Return top topics by frequency
        let frequency = Dictionary(filtered.map { ($0, 1) }, uniquingKeysWith: +)
        return unique.sorted { frequency[$0, default: 0] > frequency[$1, default: 0] }
            .prefix(5)
            .map(\.self)
    }

    // MARK: - Response Quality Evaluation

    private func evaluateResponseQuality(query: String, response: String) -> ResponseQuality {
        // Calculate basic metrics

        // Relevance: overlap between query and response words
        let queryWords = Set(query.lowercased().components(separatedBy: .whitespaces))
        let responseWords = Set(response.lowercased().components(separatedBy: .whitespaces))
        let overlap = queryWords.intersection(responseWords).count
        let relevance = min(1.0, Double(overlap) / max(1.0, Double(queryWords.count)) * 2)

        // Completeness: response length relative to query complexity
        let queryLength = query.count
        let responseLength = response.count
        let expectedLength = max(queryLength * 2, 100)
        let completeness = min(1.0, Double(responseLength) / Double(expectedLength))

        // Clarity: sentence structure (longer sentences = potentially less clear)
        let sentences = response.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let avgSentenceLength = Double(responseLength) / max(1.0, Double(sentences.count))
        let clarity = max(0.3, 1.0 - (avgSentenceLength - 100) / 200)

        // Accuracy and helpfulness are estimated based on other factors
        let accuracy = (relevance + completeness) / 2
        let helpfulness = (relevance * 0.4 + completeness * 0.3 + clarity * 0.3)

        return ResponseQuality(
            relevance: relevance,
            completeness: completeness,
            clarity: min(1.0, clarity),
            accuracy: accuracy,
            helpfulness: helpfulness
        )
    }

    // MARK: - Suggestion Generation

    private func generateSuggestions(
        intent: UserIntent,
        sentiment: Sentiment,
        quality: ResponseQuality
    ) -> [String] {
        var suggestions: [String] = []

        if quality.relevance < 0.6 {
            suggestions.append("Consider improving response relevance to the query")
        }

        if quality.completeness < 0.5 {
            suggestions.append("Response may benefit from more detail")
        }

        if quality.clarity < 0.6 {
            suggestions.append("Consider simplifying sentence structure")
        }

        if sentiment.polarity == .negative {
            suggestions.append("User may be frustrated - consider acknowledging concerns")
        }

        if intent == .complaint {
            suggestions.append("Address user's specific complaint directly")
        }

        return suggestions
    }

    // MARK: - Aggregate Metrics

    private func updateAggregateMetrics() {
        guard !analyzedInteractions.isEmpty else { return }

        let qualities = analyzedInteractions.map(\.analysis.responseQuality)
        let sentiments = analyzedInteractions.map(\.analysis.sentiment)

        aggregateMetrics = AggregateMetrics(
            totalInteractions: analyzedInteractions.count,
            averageQuality: qualities.map(\.overallScore).reduce(0, +) / Double(qualities.count),
            averageSentiment: sentiments.map(\.score).reduce(0, +) / Double(sentiments.count),
            intentDistribution: Dictionary(
                analyzedInteractions.map { ($0.analysis.intent.rawValue, 1) },
                uniquingKeysWith: +
            ),
            topTopics: getTopTopics()
        )
    }

    private func getTopTopics() -> [String] {
        let allTopics = analyzedInteractions.flatMap(\.analysis.topics)
        let frequency = Dictionary(allTopics.map { ($0, 1) }, uniquingKeysWith: +)
        return frequency.sorted { $0.value > $1.value }
            .prefix(10)
            .map(\.key)
    }
}

// MARK: - Aggregate Metrics

public struct AggregateMetrics: Sendable {
    public let totalInteractions: Int
    public let averageQuality: Double
    public let averageSentiment: Double
    public let intentDistribution: [String: Int]
    public let topTopics: [String]

    public init(
        totalInteractions: Int = 0,
        averageQuality: Double = 0,
        averageSentiment: Double = 0,
        intentDistribution: [String: Int] = [:],
        topTopics: [String] = []
    ) {
        self.totalInteractions = totalInteractions
        self.averageQuality = averageQuality
        self.averageSentiment = averageSentiment
        self.intentDistribution = intentDistribution
        self.topTopics = topTopics
    }
}
