// ConversationMemory.swift
// Intelligent conversation memory system with summarization and retrieval
// Enables long-term context across sessions

import Foundation
import os.log

// MARK: - Conversation Memory System

/// Manages conversation history with intelligent summarization and retrieval
/// Supports long-term memory across sessions with semantic search
@MainActor
@Observable
final class ConversationMemory {
    static let shared = ConversationMemory()

    // MARK: - Configuration

    struct Configuration: Codable, Sendable {
        var enableLongTermMemory: Bool = true
        var enableAutoSummarization: Bool = true
        var maxMessagesBeforeSummary: Int = 20
        var maxSummariesStored: Int = 100
        var maxFactsStored: Int = 500
        var summarizationThreshold: Int = 15 // messages before triggering summarization
        var enableSemanticRetrieval: Bool = true
        var maxRetrievedContext: Int = 5
    }

    private(set) var configuration = Configuration()
    private(set) var conversationSummaries: [ConversationSummary] = []
    private(set) var learnedFacts: [LearnedFact] = []
    private(set) var userPreferences: [String: String] = [:]
    private(set) var isProcessing = false
    private let logger = Logger(subsystem: "app.thea", category: "ConversationMemory")

    // MARK: - Memory Types

    struct ConversationSummary: Codable, Identifiable, Sendable {
        let id: UUID
        let timestamp: Date
        let projectId: UUID?
        let summary: String
        let keyTopics: [String]
        let messageCount: Int
        let importanceScore: Double

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            projectId: UUID? = nil,
            summary: String,
            keyTopics: [String],
            messageCount: Int,
            importanceScore: Double = 0.5
        ) {
            self.id = id
            self.timestamp = timestamp
            self.projectId = projectId
            self.summary = summary
            self.keyTopics = keyTopics
            self.messageCount = messageCount
            self.importanceScore = importanceScore
        }
    }

    struct LearnedFact: Codable, Identifiable, Sendable {
        let id: UUID
        let timestamp: Date
        let category: FactCategory
        let fact: String
        let source: String // e.g., "conversation", "explicit", "inferred"
        var confidence: Double
        var lastReferencedAt: Date?

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            category: FactCategory,
            fact: String,
            source: String,
            confidence: Double = 1.0
        ) {
            self.id = id
            self.timestamp = timestamp
            self.category = category
            self.fact = fact
            self.source = source
            self.confidence = confidence
        }
    }

    enum FactCategory: String, Codable, Sendable, CaseIterable {
        case userPreference     // User likes/dislikes
        case userInfo           // Name, occupation, etc.
        case technicalContext   // Tech stack, languages used
        case projectDetails     // Current project info
        case workStyle          // Communication preferences
        case schedulingInfo     // Time zone, availability
        case domainKnowledge    // Subject-specific facts
        case relationship       // How user interacts with AI

        var displayName: String {
            switch self {
            case .userPreference: "Preferences"
            case .userInfo: "Personal Info"
            case .technicalContext: "Technical Context"
            case .projectDetails: "Project Details"
            case .workStyle: "Work Style"
            case .schedulingInfo: "Scheduling"
            case .domainKnowledge: "Domain Knowledge"
            case .relationship: "Interaction Style"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        loadMemory()
    }

    // MARK: - Memory Operations

    /// Add a conversation exchange to memory and potentially trigger summarization
    func recordConversation(
        userMessage: String,
        assistantResponse: String,
        projectId: UUID? = nil,
        messageIndex: Int
    ) async {
        guard configuration.enableLongTermMemory else { return }

        // Extract and store facts from the conversation
        await extractFacts(from: userMessage, source: "user")

        // Check if summarization is needed
        if configuration.enableAutoSummarization,
           // periphery:ignore - Reserved: assistantResponse parameter kept for API compatibility
           messageIndex > 0,
           messageIndex % configuration.summarizationThreshold == 0 {
            await triggerSummarization(projectId: projectId)
        }

        saveMemory()
    }

    /// Learn a fact explicitly (from user instruction like "remember that...")
    func learnFact(category: FactCategory, fact: String, source: String = "explicit") {
        // Check for duplicate
        if learnedFacts.contains(where: { $0.fact.lowercased() == fact.lowercased() }) {
            return
        }

        let newFact = LearnedFact(
            category: category,
            fact: fact,
            source: source,
            confidence: source == "explicit" ? 1.0 : 0.8
        )

        learnedFacts.append(newFact)

        // Enforce storage limit
        if learnedFacts.count > configuration.maxFactsStored {
            // Remove lowest confidence facts
            learnedFacts.sort { $0.confidence > $1.confidence }
            learnedFacts = Array(learnedFacts.prefix(configuration.maxFactsStored))
        }

        saveMemory()
    }

    /// Retrieve relevant context for a new conversation
    func retrieveContext(for query: String, projectId: UUID? = nil) -> RetrievedContext {
        var relevantSummaries: [ConversationSummary] = []
        var relevantFacts: [LearnedFact] = []

        // Filter summaries by project if specified
        var candidateSummaries = conversationSummaries
        if let projectId {
            candidateSummaries = conversationSummaries.filter { $0.projectId == projectId }
        }

        // Keyword-based search — functional for topic matching
        // Future enhancement: embedding-based semantic search for higher recall
        let queryTerms = query.lowercased().split(separator: " ").map(String.init)

        for summary in candidateSummaries {
            let summaryTerms = Set(summary.keyTopics.map { $0.lowercased() })
            let overlap = queryTerms.filter { term in
                summaryTerms.contains { $0.contains(term) }
            }

            if !overlap.isEmpty || summary.importanceScore > 0.7 {
                relevantSummaries.append(summary)
            }
        }

        // Retrieve relevant facts
        for fact in learnedFacts {
            let factLower = fact.fact.lowercased()
            if queryTerms.contains(where: { factLower.contains($0) }) {
                var updatedFact = fact
                updatedFact.lastReferencedAt = Date()
                relevantFacts.append(updatedFact)
            }
        }

        // Limit results
        relevantSummaries = Array(relevantSummaries
            .sorted { $0.importanceScore > $1.importanceScore }
            .prefix(configuration.maxRetrievedContext))

        relevantFacts = Array(relevantFacts
            .sorted { $0.confidence > $1.confidence }
            .prefix(configuration.maxRetrievedContext * 2))

        return RetrievedContext(
            summaries: relevantSummaries,
            facts: relevantFacts,
            userPreferences: userPreferences
        )
    }

    /// Build a context prompt from retrieved memory
    func buildContextPrompt(for query: String, projectId: UUID? = nil) -> String? {
        let context = retrieveContext(for: query, projectId: projectId)

        guard !context.facts.isEmpty || !context.summaries.isEmpty else {
            return nil
        }

        var prompt = "Context from previous conversations:\n\n"

        // Add relevant facts
        // periphery:ignore - Reserved: buildContextPrompt(for:projectId:) instance method reserved for future feature activation
        if !context.facts.isEmpty {
            prompt += "Known facts about the user:\n"
            for fact in context.facts {
                prompt += "- \(fact.fact)\n"
            }
            prompt += "\n"
        }

        // Add relevant summaries
        if !context.summaries.isEmpty {
            prompt += "Previous conversation summaries:\n"
            for summary in context.summaries {
                let timeAgo = formatRelativeTime(summary.timestamp)
                prompt += "[\(timeAgo)] \(summary.summary)\n"
            }
            prompt += "\n"
        }

        // Add user preferences
        if !context.userPreferences.isEmpty {
            prompt += "User preferences:\n"
            for (key, value) in context.userPreferences {
                prompt += "- \(key): \(value)\n"
            }
        }

        return prompt
    }

    // MARK: - Fact Extraction

    private func extractFacts(from text: String, source: String) async {
        // Simple pattern-based fact extraction
        // In production, this would use NLP or an LLM

        let patterns: [(FactCategory, NSRegularExpression)] = createFactPatterns()

        for (category, regex) in patterns {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            for match in matches {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let extractedFact = String(text[matchRange])
                learnFact(category: category, fact: extractedFact, source: source)
            }
        }
    }

    private func createFactPatterns() -> [(FactCategory, NSRegularExpression)] {
        var patterns: [(FactCategory, NSRegularExpression)] = []

        // "My name is..." pattern
        do {
            let regex = try NSRegularExpression(
                pattern: #"(?:my name is|I'm|I am)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)"#,
                options: .caseInsensitive
            )
            patterns.append((.userInfo, regex))
        } catch {
            logger.error("Failed to create name pattern regex: \(error.localizedDescription)")
        }

        // "I prefer..." pattern
        do {
            let regex = try NSRegularExpression(
                pattern: #"I (?:prefer|like|want|need)\s+(.+?)(?:\.|$)"#,
                options: .caseInsensitive
            )
            patterns.append((.userPreference, regex))
        } catch {
            logger.error("Failed to create preference pattern regex: \(error.localizedDescription)")
        }

        // Tech stack patterns
        do {
            let regex = try NSRegularExpression(
                pattern: #"(?:using|work with|develop in|coding in)\s+(Swift|Python|JavaScript|TypeScript|Rust|Go|Ruby|Java|Kotlin|C\+\+)"#,
                options: .caseInsensitive
            )
            patterns.append((.technicalContext, regex))
        } catch {
            logger.error("Failed to create tech stack pattern regex: \(error.localizedDescription)")
        }

        // Project patterns
        do {
            let regex = try NSRegularExpression(
                pattern: #"(?:project|app|application)\s+(?:called|named)\s+([A-Za-z0-9]+)"#,
                options: .caseInsensitive
            )
            patterns.append((.projectDetails, regex))
        } catch {
            logger.error("Failed to create project pattern regex: \(error.localizedDescription)")
        }

        return patterns
    }

    // MARK: - Summarization

    private func triggerSummarization(projectId: UUID?) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        // Build context from recent learned facts for summarization
        let recentFacts = learnedFacts.suffix(20).map { $0.fact }
        let factsContext = recentFacts.isEmpty
            ? "No specific facts extracted."
            : recentFacts.joined(separator: "\n- ")

        // Attempt AI-powered summarization via available provider
        let aiSummary = await generateAISummary(factsContext: factsContext)

        let summary = ConversationSummary(
            projectId: projectId,
            summary: aiSummary.text,
            keyTopics: aiSummary.keyTopics,
            messageCount: configuration.summarizationThreshold,
            importanceScore: aiSummary.importance
        )

        conversationSummaries.append(summary)

        // Enforce storage limit
        if conversationSummaries.count > configuration.maxSummariesStored {
            // Remove oldest low-importance summaries
            conversationSummaries.sort { $0.importanceScore > $1.importanceScore }
            conversationSummaries = Array(conversationSummaries.prefix(configuration.maxSummariesStored))
        }

        saveMemory()
    }

    private struct AISummaryResult {
        let text: String
        let keyTopics: [String]
        let importance: Double
    }

    private func generateAISummary(factsContext: String) async -> AISummaryResult {
        // Try to get an AI provider for summarization (prefer cheap, fast models)
        guard let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
                          ?? ProviderRegistry.shared.getProvider(id: "anthropic")
                          ?? ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            logger.info("No provider available for summarization, using fact-based fallback")
            return fallbackSummary(factsContext: factsContext)
        }

        let modelId = "openai/gpt-4o-mini"
        let prompt = """
        Summarize the following conversation context into a concise summary. \
        Extract key topics as a JSON array and rate importance from 0.0 to 1.0.

        Context and learned facts:
        - \(factsContext)

        Respond in this exact JSON format (no other text):
        {"summary": "...", "keyTopics": ["topic1", "topic2"], "importance": 0.7}
        """

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: modelId
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: modelId,
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                }
            }

            // Parse JSON response
            if let jsonStart = responseText.firstIndex(of: "{"),
               let jsonEnd = responseText.lastIndex(of: "}") {
                let jsonStr = String(responseText[jsonStart...jsonEnd])
                if let data = jsonStr.data(using: .utf8) {
                    struct SummaryJSON: Decodable {
                        let summary: String
                        let keyTopics: [String]
                        let importance: Double
                    }
                    let parsed = try JSONDecoder().decode(SummaryJSON.self, from: data)
                    return AISummaryResult(
                        text: parsed.summary,
                        keyTopics: parsed.keyTopics,
                        importance: min(max(parsed.importance, 0.0), 1.0)
                    )
                }
            }

            // If JSON parsing failed but we have text, use it as-is
            if !responseText.isEmpty {
                return AISummaryResult(
                    text: responseText.prefix(500).description,
                    keyTopics: Array(learnedFacts.prefix(5).map { $0.fact }),
                    importance: 0.5
                )
            }
        } catch {
            logger.warning("AI summarization failed: \(error.localizedDescription)")
        }

        return fallbackSummary(factsContext: factsContext)
    }

    private func fallbackSummary(factsContext: String) -> AISummaryResult {
        // Deterministic fallback when no AI provider is available
        let topics = Array(learnedFacts.suffix(5).map { $0.fact })
        let topicSummary = topics.isEmpty
            ? "General conversation"
            : "Topics discussed: \(topics.joined(separator: ", "))"
        let importance = min(Double(learnedFacts.count) / 20.0, 0.8)
        return AISummaryResult(
            text: topicSummary,
            // periphery:ignore - Reserved: factsContext parameter kept for API compatibility
            keyTopics: topics,
            importance: max(importance, 0.3)
        )
    }

    // MARK: - User Preferences

    func setUserPreference(key: String, value: String) {
        userPreferences[key] = value
        saveMemory()
    }

    func removeUserPreference(key: String) {
        userPreferences.removeValue(forKey: key)
        saveMemory()
    // periphery:ignore - Reserved: setUserPreference(key:value:) instance method reserved for future feature activation
    }

    // MARK: - Memory Management

    // periphery:ignore - Reserved: removeUserPreference(key:) instance method reserved for future feature activation
    func forgetFact(id: UUID) {
        learnedFacts.removeAll { $0.id == id }
        saveMemory()
    }

    func forgetSummary(id: UUID) {
        // periphery:ignore - Reserved: forgetFact(id:) instance method reserved for future feature activation
        conversationSummaries.removeAll { $0.id == id }
        saveMemory()
    }

    // periphery:ignore - Reserved: forgetSummary(id:) instance method reserved for future feature activation
    func clearAllMemory() {
        conversationSummaries.removeAll()
        learnedFacts.removeAll()
        userPreferences.removeAll()
        saveMemory()
    }

    func clearProjectMemory(projectId: UUID) {
        conversationSummaries.removeAll { $0.projectId == projectId }
        saveMemory()
    }

// periphery:ignore - Reserved: clearProjectMemory(projectId:) instance method reserved for future feature activation

    // MARK: - Persistence

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "ConversationMemory.config") {
            do {
                configuration = try JSONDecoder().decode(Configuration.self, from: data)
            } catch {
                logger.error("Failed to decode ConversationMemory configuration: \(error.localizedDescription)")
            }
        }
    }

    private func loadMemory() {
        let decoder = JSONDecoder()

        if let data = UserDefaults.standard.data(forKey: "ConversationMemory.summaries") {
            do {
                conversationSummaries = try decoder.decode([ConversationSummary].self, from: data)
            } catch {
                logger.error("Failed to decode conversation summaries: \(error.localizedDescription)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: "ConversationMemory.facts") {
            do {
                learnedFacts = try decoder.decode([LearnedFact].self, from: data)
            } catch {
                logger.error("Failed to decode learned facts: \(error.localizedDescription)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: "ConversationMemory.prefs") {
            do {
                userPreferences = try decoder.decode([String: String].self, from: data)
            } catch {
                logger.error("Failed to decode user preferences: \(error.localizedDescription)")
            }
        }
    }

    private func saveMemory() {
        let encoder = JSONEncoder()

        do {
            let summariesData = try encoder.encode(conversationSummaries)
            UserDefaults.standard.set(summariesData, forKey: "ConversationMemory.summaries")
        } catch {
            logger.error("Failed to save conversation summaries: \(error.localizedDescription)")
        }

        do {
            let factsData = try encoder.encode(learnedFacts)
            UserDefaults.standard.set(factsData, forKey: "ConversationMemory.facts")
        } catch {
            logger.error("Failed to save learned facts: \(error.localizedDescription)")
        }

        do {
            let prefsData = try encoder.encode(userPreferences)
            UserDefaults.standard.set(prefsData, forKey: "ConversationMemory.prefs")
        } catch {
            logger.error("Failed to save user preferences: \(error.localizedDescription)")
        }
    }

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: "ConversationMemory.config")
        } catch {
            logger.error("Failed to save memory configuration: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        // periphery:ignore - Reserved: formatRelativeTime(_:) instance method reserved for future feature activation
        if interval < 3600 {
            return "\(Int(interval / 60)) minutes ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600)) hours ago"
        } else if interval < 604800 {
            return "\(Int(interval / 86400)) days ago"
        } else {
            return "\(Int(interval / 604800)) weeks ago"
        }
    }

    // MARK: - Statistics

    func getStatistics() -> ConversationMemoryStats {
        ConversationMemoryStats(
            totalSummaries: conversationSummaries.count,
            totalFacts: learnedFacts.count,
            factsByCategory: Dictionary(grouping: learnedFacts) { $0.category }
                .mapValues { $0.count },
            preferencesCount: userPreferences.count,
            oldestMemory: conversationSummaries.min { $0.timestamp < $1.timestamp }?.timestamp
        )
    }
}

// MARK: - Supporting Types

struct RetrievedContext: Sendable {
    let summaries: [ConversationMemory.ConversationSummary]
    let facts: [ConversationMemory.LearnedFact]
    let userPreferences: [String: String]

    var isEmpty: Bool {
        summaries.isEmpty && facts.isEmpty && userPreferences.isEmpty
    // periphery:ignore - Reserved: isEmpty property reserved for future feature activation
    }
}

struct ConversationMemoryStats: Sendable {
    let totalSummaries: Int
    let totalFacts: Int
    let factsByCategory: [ConversationMemory.FactCategory: Int]
    // periphery:ignore - Reserved: factsByCategory property reserved for future feature activation
    let preferencesCount: Int
    // periphery:ignore - Reserved: oldestMemory property reserved for future feature activation
    let oldestMemory: Date?
}
