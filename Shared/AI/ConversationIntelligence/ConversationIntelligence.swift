// ConversationIntelligence.swift
// Advanced conversation analysis, summarization, and management

import Foundation
import OSLog
import Combine
import NaturalLanguage

// MARK: - Conversation Intelligence Service

/// Provides advanced conversation analysis and management
@MainActor
public final class ConversationIntelligenceService: ObservableObject {
    public static let shared = ConversationIntelligenceService()

    private let logger = Logger(subsystem: "com.thea.app", category: "ConversationIntelligence")

    // NLP components
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .sentimentScore])
    private let tokenizer = NLTokenizer(unit: .word)

    // MARK: - Published State

    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var recentAnalyses: [ConversationAnalysis] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Conversation Analysis

    /// Analyze a conversation
    public func analyzeConversation(_ conversation: Conversation) async -> ConversationAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let messages = conversation.messages

        // Extract metrics
        let messageCount = messages.count
        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }

        // Analyze content
        let allText = messages.map { $0.content }.joined(separator: " ")
        let topics = extractTopics(from: allText)
        let entities = extractEntities(from: allText)
        let sentiment = analyzeSentiment(text: allText)
        let complexity = analyzeComplexity(messages: messages)

        // Detect conversation type
        let conversationType = detectConversationType(messages: messages)

        // Generate summary
        let summary = generateSummary(conversation: conversation)

        // Extract action items
        let actionItems = extractActionItems(from: messages)

        // Calculate engagement metrics
        let engagement = calculateEngagement(
            userMessages: userMessages,
            assistantMessages: assistantMessages
        )

        let analysis = ConversationAnalysis(
            conversationId: conversation.id,
            messageCount: messageCount,
            userMessageCount: userMessages.count,
            assistantMessageCount: assistantMessages.count,
            topics: topics,
            entities: entities,
            sentiment: sentiment,
            complexity: complexity,
            conversationType: conversationType,
            summary: summary,
            actionItems: actionItems,
            engagement: engagement,
            timestamp: Date()
        )

        recentAnalyses.append(analysis)
        if recentAnalyses.count > 50 {
            recentAnalyses.removeFirst()
        }

        return analysis
    }

    // MARK: - Topic Extraction

    private func extractTopics(from text: String) -> [Topic] {
        var topicCounts: [String: Int] = [:]

        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let word = String(text[range]).lowercased()
                if word.count > 3 {
                    topicCounts[word, default: 0] += 1
                }
            }
            return true
        }

        // Also extract noun phrases using lexical class
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun {
                let word = String(text[range]).lowercased()
                if word.count > 3 {
                    topicCounts[word, default: 0] += 1
                }
            }
            return true
        }

        return topicCounts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { Topic(name: $0.key, frequency: $0.value) }
    }

    // MARK: - Entity Extraction

    private func extractEntities(from text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            guard let tag = tag else { return true }

            let entityType: EntityType?
            switch tag {
            case .personalName: entityType = .person
            case .placeName: entityType = .location
            case .organizationName: entityType = .organization
            default: entityType = nil
            }

            if let type = entityType {
                let value = String(text[range])
                if !entities.contains(where: { $0.value == value }) {
                    entities.append(ExtractedEntity(type: type, value: value))
                }
            }

            return true
        }

        return entities
    }

    // MARK: - Sentiment Analysis

    private func analyzeSentiment(text: String) -> SentimentResult {
        tagger.string = text

        var scores: [Double] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                scores.append(score)
            }
            return true
        }

        let averageScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        let label: SentimentLabel
        if averageScore > 0.3 {
            label = .positive
        } else if averageScore < -0.3 {
            label = .negative
        } else {
            label = .neutral
        }

        return SentimentResult(score: averageScore, label: label)
    }

    // MARK: - Complexity Analysis

    private func analyzeComplexity(messages: [ConversationMessage]) -> ComplexityMetrics {
        let allText = messages.map { $0.content }.joined(separator: " ")

        // Word count
        tokenizer.string = allText
        var wordCount = 0
        tokenizer.enumerateTokens(in: allText.startIndex..<allText.endIndex) { _, _ in
            wordCount += 1
            return true
        }

        // Sentence count
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = allText
        var sentenceCount = 0
        sentenceTokenizer.enumerateTokens(in: allText.startIndex..<allText.endIndex) { _, _ in
            sentenceCount += 1
            return true
        }

        let avgWordsPerSentence = sentenceCount > 0 ? Double(wordCount) / Double(sentenceCount) : 0

        // Unique words for vocabulary diversity
        var uniqueWords = Set<String>()
        tokenizer.string = allText
        tokenizer.enumerateTokens(in: allText.startIndex..<allText.endIndex) { range, _ in
            uniqueWords.insert(String(allText[range]).lowercased())
            return true
        }

        let vocabularyDiversity = wordCount > 0 ? Double(uniqueWords.count) / Double(wordCount) : 0

        // Check for code blocks
        let hasCode = allText.contains("```") || allText.contains("    ")

        // Estimate reading time (average 200 words per minute)
        let readingTimeMinutes = Double(wordCount) / 200.0

        return ComplexityMetrics(
            wordCount: wordCount,
            sentenceCount: sentenceCount,
            averageWordsPerSentence: avgWordsPerSentence,
            vocabularyDiversity: vocabularyDiversity,
            hasCodeBlocks: hasCode,
            estimatedReadingTime: readingTimeMinutes
        )
    }

    // MARK: - Conversation Type Detection

    private func detectConversationType(messages: [ConversationMessage]) -> ConversationType {
        let allText = messages.map { $0.content.lowercased() }.joined(separator: " ")

        // Code-related keywords
        let codeKeywords = ["code", "function", "variable", "error", "bug", "implement", "class", "method", "api"]
        let codeScore = codeKeywords.filter { allText.contains($0) }.count

        // Question keywords
        let questionKeywords = ["how", "what", "why", "when", "where", "can you", "could you"]
        let questionScore = questionKeywords.filter { allText.contains($0) }.count

        // Creative keywords
        let creativeKeywords = ["write", "create", "story", "poem", "design", "imagine", "generate"]
        let creativeScore = creativeKeywords.filter { allText.contains($0) }.count

        // Analysis keywords
        let analysisKeywords = ["analyze", "compare", "evaluate", "review", "assess", "summarize"]
        let analysisScore = analysisKeywords.filter { allText.contains($0) }.count

        // Task keywords
        let taskKeywords = ["help me", "do this", "complete", "finish", "task", "todo"]
        let taskScore = taskKeywords.filter { allText.contains($0) }.count

        let scores: [(ConversationType, Int)] = [
            (.coding, codeScore),
            (.question, questionScore),
            (.creative, creativeScore),
            (.analysis, analysisScore),
            (.task, taskScore)
        ]

        return scores.max(by: { $0.1 < $1.1 })?.0 ?? .general
    }

    // MARK: - Summary Generation

    private func generateSummary(conversation: Conversation) -> String {
        // Extract key points from conversation
        let messages = conversation.messages

        guard !messages.isEmpty else {
            return "Empty conversation"
        }

        // Get first user message as the initial topic
        let firstUserMessage = messages.first { $0.role == .user }?.content ?? ""
        let truncatedFirst = String(firstUserMessage.prefix(100))

        // Get last exchange
        let lastMessages = messages.suffix(2)
        let lastExchange = lastMessages.map { "\($0.role == .user ? "User" : "AI"): \($0.content.prefix(50))..." }.joined(separator: " → ")

        let messageCount = messages.count
        let userCount = messages.filter { $0.role == .user }.count

        return "Conversation about \"\(truncatedFirst)\" with \(messageCount) messages (\(userCount) from user). Latest: \(lastExchange)"
    }

    // MARK: - Action Item Extraction

    private func extractActionItems(from messages: [ConversationMessage]) -> [ActionItem] {
        var actionItems: [ActionItem] = []

        let actionPatterns = [
            "i will", "i'll", "let me", "i should", "i need to",
            "you should", "you need to", "please", "remember to",
            "don't forget", "make sure", "todo:", "action:"
        ]

        for message in messages {
            let lowercased = message.content.lowercased()

            for pattern in actionPatterns {
                if lowercased.contains(pattern) {
                    // Extract the sentence containing the pattern
                    let sentences = message.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                    for sentence in sentences {
                        if sentence.lowercased().contains(pattern) {
                            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.count > 10 && trimmed.count < 200 {
                                actionItems.append(ActionItem(
                                    text: trimmed,
                                    source: message.role == .user ? .user : .assistant,
                                    priority: determinePriority(text: trimmed)
                                ))
                            }
                        }
                    }
                }
            }
        }

        // Deduplicate
        var seen = Set<String>()
        actionItems = actionItems.filter { item in
            let normalized = item.text.lowercased()
            if seen.contains(normalized) { return false }
            seen.insert(normalized)
            return true
        }

        return Array(actionItems.prefix(10))
    }

    private func determinePriority(text: String) -> ActionPriority {
        let lowercased = text.lowercased()

        if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("immediately") {
            return .high
        } else if lowercased.contains("when you can") || lowercased.contains("eventually") || lowercased.contains("later") {
            return .low
        }

        return .medium
    }

    // MARK: - Engagement Metrics

    private func calculateEngagement(userMessages: [ConversationMessage], assistantMessages: [ConversationMessage]) -> EngagementMetrics {
        let userWordCounts = userMessages.map { countWords(in: $0.content) }
        let assistantWordCounts = assistantMessages.map { countWords(in: $0.content) }

        let avgUserLength = userWordCounts.isEmpty ? 0 : Double(userWordCounts.reduce(0, +)) / Double(userWordCounts.count)
        let avgAssistantLength = assistantWordCounts.isEmpty ? 0 : Double(assistantWordCounts.reduce(0, +)) / Double(assistantWordCounts.count)

        // Question ratio
        let questionCount = userMessages.filter { $0.content.contains("?") }.count
        let questionRatio = userMessages.isEmpty ? 0 : Double(questionCount) / Double(userMessages.count)

        // Follow-up indicator (short responses suggesting continued conversation)
        let followUps = userMessages.filter { countWords(in: $0.content) < 10 }.count
        let followUpRatio = userMessages.isEmpty ? 0 : Double(followUps) / Double(userMessages.count)

        return EngagementMetrics(
            averageUserMessageLength: avgUserLength,
            averageAssistantResponseLength: avgAssistantLength,
            questionRatio: questionRatio,
            followUpRatio: followUpRatio,
            responseRatio: userMessages.isEmpty ? 0 : Double(assistantMessages.count) / Double(userMessages.count)
        )
    }

    private func countWords(in text: String) -> Int {
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }

    // MARK: - Conversation Search

    /// Search conversations by content
    public func searchConversations(_ conversations: [Conversation], query: String) -> [SearchResult] {
        let queryLowercased = query.lowercased()

        return conversations.compactMap { conversation in
            var matchScore = 0
            var matchingMessages: [String] = []

            for message in conversation.messages {
                if message.content.lowercased().contains(queryLowercased) {
                    matchScore += 1
                    matchingMessages.append(String(message.content.prefix(100)))
                }
            }

            if matchScore > 0 {
                return SearchResult(
                    conversationId: conversation.id,
                    title: conversation.title,
                    matchScore: matchScore,
                    matchingExcerpts: Array(matchingMessages.prefix(3))
                )
            }

            return nil
        }.sorted { $0.matchScore > $1.matchScore }
    }

    // MARK: - Smart Suggestions

    /// Get smart follow-up suggestions
    public func getFollowUpSuggestions(for conversation: Conversation) -> [FollowUpSuggestion] {
        var suggestions: [FollowUpSuggestion] = []

        guard let lastMessage = conversation.messages.last else {
            return suggestions
        }

        let lastContent = lastMessage.content.lowercased()

        // If last message was from assistant, suggest user responses
        if lastMessage.role == .assistant {
            // Code-related suggestions
            if lastContent.contains("code") || lastContent.contains("```") {
                suggestions.append(FollowUpSuggestion(text: "Can you explain this code?", type: .clarification))
                suggestions.append(FollowUpSuggestion(text: "Can you make it more efficient?", type: .improvement))
                suggestions.append(FollowUpSuggestion(text: "Add error handling", type: .enhancement))
            }

            // Explanation suggestions
            if lastContent.contains("because") || lastContent.contains("reason") {
                suggestions.append(FollowUpSuggestion(text: "Can you give an example?", type: .example))
                suggestions.append(FollowUpSuggestion(text: "Tell me more about this", type: .deepDive))
            }

            // List suggestions
            if lastContent.contains("1.") || lastContent.contains("- ") {
                suggestions.append(FollowUpSuggestion(text: "Can you elaborate on the first point?", type: .deepDive))
                suggestions.append(FollowUpSuggestion(text: "Which is most important?", type: .prioritization))
            }
        }

        // General suggestions
        suggestions.append(FollowUpSuggestion(text: "Summarize our conversation", type: .summary))

        return Array(suggestions.prefix(5))
    }
}

// MARK: - Types

public struct Conversation: Identifiable {
    public let id: String
    public let title: String
    public let messages: [ConversationMessage]
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: String, title: String, messages: [ConversationMessage], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ConversationMessage: Identifiable {
    public let id: String
    public let role: MessageRole
    public let content: String
    public let timestamp: Date

    public enum MessageRole {
        case user
        case assistant
        case system
    }

    public init(id: String, role: MessageRole, content: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

public struct ConversationAnalysis {
    public let conversationId: String
    public let messageCount: Int
    public let userMessageCount: Int
    public let assistantMessageCount: Int
    public let topics: [Topic]
    public let entities: [ExtractedEntity]
    public let sentiment: SentimentResult
    public let complexity: ComplexityMetrics
    public let conversationType: ConversationType
    public let summary: String
    public let actionItems: [ActionItem]
    public let engagement: EngagementMetrics
    public let timestamp: Date
}

public struct Topic: Identifiable {
    public let id = UUID()
    public let name: String
    public let frequency: Int
}

public struct ExtractedEntity: Identifiable {
    public let id = UUID()
    public let type: EntityType
    public let value: String
}

public enum EntityType {
    case person
    case location
    case organization
    case date
    case product
}

public struct SentimentResult {
    public let score: Double // -1 to 1
    public let label: SentimentLabel
}

public enum SentimentLabel {
    case positive
    case neutral
    case negative
}

public struct ComplexityMetrics {
    public let wordCount: Int
    public let sentenceCount: Int
    public let averageWordsPerSentence: Double
    public let vocabularyDiversity: Double
    public let hasCodeBlocks: Bool
    public let estimatedReadingTime: Double // in minutes
}

public enum ConversationType {
    case coding
    case question
    case creative
    case analysis
    case task
    case general
}

public struct ActionItem: Identifiable {
    public let id = UUID()
    public let text: String
    public let source: ActionSource
    public let priority: ActionPriority

    public enum ActionSource {
        case user
        case assistant
    }
}

public enum ActionPriority {
    case high
    case medium
    case low
}

public struct EngagementMetrics {
    public let averageUserMessageLength: Double
    public let averageAssistantResponseLength: Double
    public let questionRatio: Double
    public let followUpRatio: Double
    public let responseRatio: Double
}

public struct SearchResult: Identifiable {
    public let id = UUID()
    public let conversationId: String
    public let title: String
    public let matchScore: Int
    public let matchingExcerpts: [String]
}

public struct FollowUpSuggestion: Identifiable {
    public let id = UUID()
    public let text: String
    public let type: SuggestionType

    public enum SuggestionType {
        case clarification
        case improvement
        case enhancement
        case example
        case deepDive
        case prioritization
        case summary
    }
}
