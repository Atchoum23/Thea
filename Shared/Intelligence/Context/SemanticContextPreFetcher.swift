//
//  SemanticContextPreFetcher.swift
//  Thea
//
//  Proactively loads relevant context before queries are processed.
//  Uses intent prediction and pattern matching to pre-warm relevant resources.
//

import Foundation
import Observation
import os.log

private let prefetchLogger = Logger(subsystem: "ai.thea.app", category: "SemanticContextPreFetcher")

// MARK: - Context Item

public struct ContextItem: Identifiable, Sendable {
    public let id: UUID
    public let type: ContextType
    public let identifier: String
    public let content: String
    public let relevanceScore: Double
    public let source: ContextSource
    public let loadedAt: Date
    public let expiresAt: Date
    public let metadata: [String: String]

    public enum ContextType: String, Sendable {
        case file             // Source code, config files
        case conversation     // Past conversation snippets
        case memory           // Semantic/episodic memory
        case documentation    // API docs, guides
        case codeSnippet      // Specific code fragments
        case projectStructure // Directory layout
        case errorHistory     // Past errors and solutions
        case userPreference   // Learned preferences
    }

    public enum ContextSource: String, Sendable {
        case patternPrediction   // Based on detected patterns
        case goalRelated         // Related to active goals
        case recentActivity      // Recent file/conversation access
        case semanticSimilarity  // Content similarity
        case explicitMention     // @-mentioned in query
        case projectContext      // Current project files
    }

    public init(
        id: UUID = UUID(),
        type: ContextType,
        identifier: String,
        content: String,
        relevanceScore: Double,
        source: ContextSource,
        loadedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(300),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.identifier = identifier
        self.content = content
        self.relevanceScore = relevanceScore
        self.source = source
        self.loadedAt = loadedAt
        self.expiresAt = expiresAt
        self.metadata = metadata
    }

    public var isExpired: Bool {
        Date() > expiresAt
    }
}

// MARK: - Context Bundle

public struct ContextBundle: Sendable {
    public let items: [ContextItem]
    public let totalTokenEstimate: Int
    public let createdAt: Date

    public init(items: [ContextItem]) {
        self.items = items
        self.totalTokenEstimate = items.reduce(0) { $0 + Self.estimateTokens($1.content) }
        self.createdAt = Date()
    }

    private static func estimateTokens(_ content: String) -> Int {
        // Rough estimate: ~4 characters per token
        content.count / 4
    }

    /// Get items within token budget
    public func itemsWithinBudget(_ tokenBudget: Int) -> [ContextItem] {
        var result: [ContextItem] = []
        var usedTokens = 0

        for item in items.sorted(by: { $0.relevanceScore > $1.relevanceScore }) {
            let itemTokens = Self.estimateTokens(item.content)
            if usedTokens + itemTokens <= tokenBudget {
                result.append(item)
                usedTokens += itemTokens
            }
        }

        return result
    }

    /// Format as system prompt context
    public func formatForSystemPrompt(tokenBudget: Int = 4000) -> String {
        let relevantItems = itemsWithinBudget(tokenBudget)

        guard !relevantItems.isEmpty else { return "" }

        var sections: [String: [ContextItem]] = [:]
        for item in relevantItems {
            let key = item.type.rawValue
            sections[key, default: []].append(item)
        }

        var output = "## Relevant Context\n\n"

        for (sectionName, items) in sections.sorted(by: { $0.key < $1.key }) {
            output += "### \(sectionName.capitalized)\n"
            for item in items.prefix(3) {
                output += "- \(item.identifier): \(item.content.prefix(200))...\n"
            }
            output += "\n"
        }

        return output
    }
}

// MARK: - Prefetch Request

public struct PrefetchRequest: Sendable {
    public let query: String?
    public let conversationId: UUID?
    public let projectPath: String?
    public let recentFiles: [String]
    public let activeGoals: [InferredGoal]
    public let userContext: UserContextSnapshot

    public struct UserContextSnapshot: Sendable {
        public let recentTaskTypes: [String]
        public let preferredModels: [String]
        public let currentFocus: String?
        public let timeOfDay: TimeOfDay

        public enum TimeOfDay: String, Sendable {
            case earlyMorning  // 5-8
            case morning       // 8-12
            case afternoon     // 12-17
            case evening       // 17-21
            case night         // 21-5
        }

        public init(
            recentTaskTypes: [String] = [],
            preferredModels: [String] = [],
            currentFocus: String? = nil,
            timeOfDay: TimeOfDay = .morning
        ) {
            self.recentTaskTypes = recentTaskTypes
            self.preferredModels = preferredModels
            self.currentFocus = currentFocus
            self.timeOfDay = timeOfDay
        }

        public static func current() -> UserContextSnapshot {
            let hour = Calendar.current.component(.hour, from: Date())
            let timeOfDay: TimeOfDay
            switch hour {
            case 5..<8: timeOfDay = .earlyMorning
            case 8..<12: timeOfDay = .morning
            case 12..<17: timeOfDay = .afternoon
            case 17..<21: timeOfDay = .evening
            default: timeOfDay = .night
            }

            return UserContextSnapshot(timeOfDay: timeOfDay)
        }
    }

    public init(
        query: String? = nil,
        conversationId: UUID? = nil,
        projectPath: String? = nil,
        recentFiles: [String] = [],
        activeGoals: [InferredGoal] = [],
        userContext: UserContextSnapshot = .current()
    ) {
        self.query = query
        self.conversationId = conversationId
        self.projectPath = projectPath
        self.recentFiles = recentFiles
        self.activeGoals = activeGoals
        self.userContext = userContext
    }
}

// MARK: - Semantic Context Pre-Fetcher

@MainActor
@Observable
public final class SemanticContextPreFetcher {
    public static let shared = SemanticContextPreFetcher()

    // MARK: - State

    private(set) var cachedContext: [UUID: ContextBundle] = [:]
    private(set) var preloadedItems: [ContextItem] = []
    private(set) var isPrefetching = false
    private(set) var lastPrefetchTime: Date?

    // MARK: - Configuration

    private let maxCachedBundles = 10
    private let defaultTokenBudget = 8000
    private let prefetchCooldown: TimeInterval = 30
    private let itemExpirationSeconds: TimeInterval = 300

    // MARK: - Initialization

    private init() {
        prefetchLogger.info("📦 SemanticContextPreFetcher initializing...")
        startBackgroundCleanup()
    }

    // MARK: - Public API

    /// Prefetch context for an upcoming query
    public func prefetchContext(for request: PrefetchRequest) async -> ContextBundle {
        isPrefetching = true
        defer { isPrefetching = false }

        var items: [ContextItem] = []

        // 1. Get context from query analysis
        if let query = request.query {
            let queryItems = await prefetchForQuery(query)
            items.append(contentsOf: queryItems)
        }

        // 2. Get context from recent files
        let fileItems = await prefetchFromRecentFiles(request.recentFiles)
        items.append(contentsOf: fileItems)

        // 3. Get context from active goals
        let goalItems = await prefetchFromGoals(request.activeGoals)
        items.append(contentsOf: goalItems)

        // 4. Get context from project structure
        if let projectPath = request.projectPath {
            let projectItems = await prefetchFromProject(projectPath)
            items.append(contentsOf: projectItems)
        }

        // 5. Get context from conversation history
        if let conversationId = request.conversationId {
            let convoItems = await prefetchFromConversation(conversationId)
            items.append(contentsOf: convoItems)
        }

        // 6. Get context from memory systems
        let memoryItems = await prefetchFromMemory(request)
        items.append(contentsOf: memoryItems)

        // Deduplicate and sort by relevance
        items = deduplicateItems(items)
        items.sort { $0.relevanceScore > $1.relevanceScore }

        // Create bundle
        let bundle = ContextBundle(items: items)

        // Cache it
        if let convId = request.conversationId {
            cachedContext[convId] = bundle
            cleanupCache()
        }

        // Update preloaded items
        preloadedItems = items
        lastPrefetchTime = Date()

        prefetchLogger.info("📦 Prefetched \(items.count) context items (\(bundle.totalTokenEstimate) tokens)")

        // Notify hub
        let resources = items.map { item in
            PreloadedResource(
                type: mapToResourceType(item.type),
                identifier: item.identifier,
                relevanceScore: item.relevanceScore
            )
        }
        await UnifiedIntelligenceHub.shared.processEvent(.contextPreloaded(resources: resources))

        return bundle
    }

    /// Get cached context for a conversation
    public func getCachedContext(for conversationId: UUID) -> ContextBundle? {
        cachedContext[conversationId]
    }

    /// Get all valid preloaded items
    public func getPreloadedItems() -> [ContextItem] {
        preloadedItems.filter { !$0.isExpired }
    }

    /// Invalidate context for a conversation
    public func invalidateContext(for conversationId: UUID) {
        cachedContext.removeValue(forKey: conversationId)
    }

    /// Clear all cached context
    public func clearAllContext() {
        cachedContext.removeAll()
        preloadedItems.removeAll()
    }

    // MARK: - Prefetch Strategies

    private func prefetchForQuery(_ query: String) async -> [ContextItem] {
        var items: [ContextItem] = []
        let queryLower = query.lowercased()

        // Extract key terms
        let keyTerms = extractKeyTerms(from: query)

        // Check for code-related queries
        if queryLower.contains("function") || queryLower.contains("class") ||
           queryLower.contains("implement") || queryLower.contains("fix") {
            // Would search for relevant code snippets
            items.append(ContextItem(
                type: .codeSnippet,
                identifier: "query_related_code",
                content: "Code context placeholder for: \(keyTerms.joined(separator: ", "))",
                relevanceScore: 0.7,
                source: .semanticSimilarity
            ))
        }

        // Check for documentation queries
        if queryLower.contains("how") || queryLower.contains("what") ||
           queryLower.contains("explain") || queryLower.contains("docs") {
            items.append(ContextItem(
                type: .documentation,
                identifier: "query_docs",
                content: "Documentation context for: \(keyTerms.joined(separator: ", "))",
                relevanceScore: 0.6,
                source: .semanticSimilarity
            ))
        }

        // Check for error-related queries
        if queryLower.contains("error") || queryLower.contains("bug") ||
           queryLower.contains("crash") || queryLower.contains("fail") {
            items.append(ContextItem(
                type: .errorHistory,
                identifier: "error_context",
                content: "Error history context for troubleshooting",
                relevanceScore: 0.8,
                source: .patternPrediction
            ))
        }

        return items
    }

    private func prefetchFromRecentFiles(_ files: [String]) async -> [ContextItem] {
        var items: [ContextItem] = []

        for (index, file) in files.prefix(5).enumerated() {
            // Relevance decreases with recency
            let relevance = 0.9 - (Double(index) * 0.1)

            items.append(ContextItem(
                type: .file,
                identifier: file,
                content: "Content of recently accessed file: \(file)",
                relevanceScore: relevance,
                source: .recentActivity,
                metadata: ["index": String(index)]
            ))
        }

        return items
    }

    private func prefetchFromGoals(_ goals: [InferredGoal]) async -> [ContextItem] {
        var items: [ContextItem] = []

        for goal in goals.prefix(3) {
            items.append(ContextItem(
                type: .memory,
                identifier: "goal_\(goal.id.uuidString.prefix(8))",
                content: "Active goal: \(goal.title) - \(goal.description). Progress: \(Int(goal.progress * 100))%",
                relevanceScore: goal.confidence * 0.8,
                source: .goalRelated,
                metadata: [
                    "goalId": goal.id.uuidString,
                    "category": goal.category.rawValue
                ]
            ))
        }

        return items
    }

    private func prefetchFromProject(_ projectPath: String) async -> [ContextItem] {
        var items: [ContextItem] = []

        // Add project structure context
        items.append(ContextItem(
            type: .projectStructure,
            identifier: projectPath,
            content: "Project structure at: \(projectPath)",
            relevanceScore: 0.6,
            source: .projectContext,
            metadata: ["path": projectPath]
        ))

        // Would add key files like package.json, Podfile, etc.

        return items
    }

    private func prefetchFromConversation(_ conversationId: UUID) async -> [ContextItem] {
        var items: [ContextItem] = []

        // Would load recent messages from conversation
        items.append(ContextItem(
            type: .conversation,
            identifier: conversationId.uuidString,
            content: "Recent conversation context",
            relevanceScore: 0.7,
            source: .recentActivity,
            metadata: ["conversationId": conversationId.uuidString]
        ))

        return items
    }

    private func prefetchFromMemory(_ request: PrefetchRequest) async -> [ContextItem] {
        var items: [ContextItem] = []

        // User preferences
        items.append(ContextItem(
            type: .userPreference,
            identifier: "user_prefs",
            content: "User preferences: Recent tasks - \(request.userContext.recentTaskTypes.joined(separator: ", "))",
            relevanceScore: 0.5,
            source: .patternPrediction
        ))

        // Time-based context
        let timeContext = switch request.userContext.timeOfDay {
        case .earlyMorning: "Early morning focus - user typically reviews and plans"
        case .morning: "Morning productivity peak - complex tasks"
        case .afternoon: "Afternoon work - mixed tasks"
        case .evening: "Evening wind-down - lighter tasks"
        case .night: "Night work - focus mode"
        }

        items.append(ContextItem(
            type: .memory,
            identifier: "time_context",
            content: timeContext,
            relevanceScore: 0.4,
            source: .patternPrediction
        ))

        return items
    }

    // MARK: - Helper Methods

    private func extractKeyTerms(from query: String) -> [String] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        let stopWords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been",
                             "being", "have", "has", "had", "do", "does", "did", "will",
                             "would", "could", "should", "may", "might", "must", "shall",
                             "can", "need", "to", "of", "in", "for", "on", "with", "at",
                             "by", "from", "up", "about", "into", "through", "during",
                             "before", "after", "above", "below", "between", "under",
                             "and", "but", "if", "or", "because", "as", "until", "while",
                             "this", "that", "these", "those", "i", "me", "my", "myself",
                             "we", "our", "you", "your", "he", "she", "it", "they", "them",
                             "what", "which", "who", "whom", "how", "when", "where", "why"])

        return words.filter { word in
            word.count > 2 && !stopWords.contains(word)
        }
    }

    private func deduplicateItems(_ items: [ContextItem]) -> [ContextItem] {
        var seen: Set<String> = []
        var unique: [ContextItem] = []

        for item in items {
            let key = "\(item.type.rawValue):\(item.identifier)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(item)
            }
        }

        return unique
    }

    private func mapToResourceType(_ contextType: ContextItem.ContextType) -> PreloadedResource.ResourceType {
        switch contextType {
        case .file: return .file
        case .conversation: return .conversation
        case .memory: return .memory
        case .documentation: return .documentation
        case .codeSnippet: return .codeSnippet
        case .projectStructure: return .file
        case .errorHistory: return .memory
        case .userPreference: return .memory
        }
    }

    private func cleanupCache() {
        // Remove oldest entries if over limit
        if cachedContext.count > maxCachedBundles {
            let sortedKeys = cachedContext.keys.sorted { _, _ in
                // Would sort by creation time in real implementation
                Bool.random()
            }
            for key in sortedKeys.prefix(cachedContext.count - maxCachedBundles) {
                cachedContext.removeValue(forKey: key)
            }
        }
    }

    private func startBackgroundCleanup() {
        Task.detached { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(60))
                await self?.performCleanup()
            }
        }
    }

    private func performCleanup() {
        // Remove expired items
        preloadedItems = preloadedItems.filter { !$0.isExpired }

        // Clean up old cache entries
        let expiredTime = Date().addingTimeInterval(-itemExpirationSeconds * 2)
        for (key, bundle) in cachedContext {
            if bundle.createdAt < expiredTime {
                cachedContext.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - Context Pre-Fetcher Extensions

extension SemanticContextPreFetcher {
    /// Quick prefetch for typing prediction
    public func quickPrefetch(partialQuery: String) async {
        guard partialQuery.count > 5 else { return }

        // Check cooldown
        if let lastTime = lastPrefetchTime,
           Date().timeIntervalSince(lastTime) < prefetchCooldown {
            return
        }

        let request = PrefetchRequest(
            query: partialQuery,
            userContext: .current()
        )

        _ = await prefetchContext(for: request)
    }

    /// Build context for a specific task type
    public func buildContextForTask(_ taskType: String) async -> ContextBundle {
        var items: [ContextItem] = []

        switch taskType.lowercased() {
        case "codegen", "codegeneration":
            items.append(ContextItem(
                type: .codeSnippet,
                identifier: "code_patterns",
                content: "User's preferred coding patterns and style",
                relevanceScore: 0.8,
                source: .patternPrediction
            ))

        case "debugging", "debug":
            items.append(ContextItem(
                type: .errorHistory,
                identifier: "debug_context",
                content: "Recent error patterns and solutions",
                relevanceScore: 0.9,
                source: .patternPrediction
            ))

        case "explanation", "explain":
            items.append(ContextItem(
                type: .userPreference,
                identifier: "explanation_style",
                content: "User's preferred explanation depth and style",
                relevanceScore: 0.7,
                source: .patternPrediction
            ))

        default:
            break
        }

        return ContextBundle(items: items)
    }
}
