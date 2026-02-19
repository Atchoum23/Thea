//
//  ProactiveResourceMatcher.swift
//  Thea
//
//  Proactively matches user needs to discovered resources before they ask.
//  Uses context analysis, conversation patterns, and semantic matching to
//  suggest relevant MCP servers, tools, and capabilities.
//
//  Copyright 2026. All rights reserved.
//

import Combine
import Foundation
import NaturalLanguage
import os.log

// MARK: - Match Types

/// A proactive resource match suggestion
public struct ResourceMatch: Identifiable, Sendable {
    public let id: UUID
    public let resource: DiscoveredResource
    public let matchReason: MatchReason
    public var confidence: Double
    public let context: MatchContext
    public let suggestedTools: [DiscoveredTool]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        resource: DiscoveredResource,
        matchReason: MatchReason,
        confidence: Double,
        context: MatchContext,
        suggestedTools: [DiscoveredTool] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.resource = resource
        self.matchReason = matchReason
        self.confidence = confidence
        self.context = context
        self.suggestedTools = suggestedTools
        self.timestamp = timestamp
    }
}

/// Why a resource was matched
public enum MatchReason: Sendable {
    case topicMention(topic: String)
    case keywordMatch(keywords: [String])
    case capabilityNeed(capability: ResourceCapability.CapabilityCategory)
    case taskType(type: String)
    case libraryReference(library: String)
    case patternDetected(pattern: String)
    case contextualRelevance(score: Double)
    case userPreference
    case frequentUse

    public var displayDescription: String {
        switch self {
        case .topicMention(let topic):
            return "Mentioned '\(topic)'"
        case .keywordMatch(let keywords):
            return "Keywords: \(keywords.joined(separator: ", "))"
        case .capabilityNeed(let capability):
            return "Needs \(capability.rawValue) capability"
        case .taskType(let type):
            return "Task type: \(type)"
        case .libraryReference(let library):
            return "Referenced '\(library)'"
        case .patternDetected(let pattern):
            return "Pattern: \(pattern)"
        case .contextualRelevance(let score):
            return "Contextually relevant (\(Int(score * 100))%)"
        case .userPreference:
            return "Based on your preferences"
        case .frequentUse:
            return "Frequently used"
        }
    }
}

/// Context in which a match was made
public struct MatchContext: Sendable {
    public let conversationId: UUID?
    public let messageContent: String?
    public let detectedIntent: String?
    public let extractedEntities: [String: String]
    public let timeOfDay: String?

    public init(
        conversationId: UUID? = nil,
        messageContent: String? = nil,
        detectedIntent: String? = nil,
        extractedEntities: [String: String] = [:],
        timeOfDay: String? = nil
    ) {
        self.conversationId = conversationId
        self.messageContent = messageContent
        self.detectedIntent = detectedIntent
        self.extractedEntities = extractedEntities
        self.timeOfDay = timeOfDay
    }
}

// MARK: - Proactive Resource Matcher

/// Proactively suggests resources based on conversation context and user patterns
@MainActor
public final class ProactiveResourceMatcher: ObservableObject {
    public static let shared = ProactiveResourceMatcher()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ResourceMatcher")
    private let discoveryEngine = ResourceDiscoveryEngine.shared

    // MARK: - Published State

    /// Current proactive suggestions (top matches for current context)
    @Published public private(set) var currentSuggestions: [ResourceMatch] = []

    /// All recent matches (history)
    @Published public private(set) var recentMatches: [ResourceMatch] = []

    /// Whether matching is active
    @Published public private(set) var isMatching: Bool = false

    // MARK: - Configuration

    /// Minimum confidence to show a suggestion
    @Published public var minimumConfidence: Double = 0.4

    /// Maximum suggestions to show at once
    @Published public var maxSuggestions: Int = 5

    /// Whether to use NLP for enhanced matching
    @Published public var useNLPMatching: Bool = true

    /// Whether proactive matching is enabled
    @Published public var isEnabled: Bool = true

    // MARK: - Private State

    private var userPreferences = UserResourcePreferences()
    private var usageHistory: [UUID: ResourceUsageStats] = [:]
    private var nlpTagger: NLTagger?
    // periphery:ignore - Reserved: cancellables property reserved for future feature activation
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Keyword/Topic Mappings

    /// Maps keywords to capability categories
    private let keywordToCapability: [String: ResourceCapability.CapabilityCategory] = [
        "file": .fileSystem,
        "folder": .fileSystem,
        "directory": .fileSystem,
        "database": .database,
        "sql": .database,
        "query": .database,
        "api": .api,
        "endpoint": .api,
        "rest": .api,
        "graphql": .api,
        "web": .web,
        "browser": .web,
        "scrape": .web,
        "crawl": .web,
        "ai": .ai,
        "model": .ai,
        "llm": .ai,
        "docs": .documentation,
        "documentation": .documentation,
        "reference": .documentation,
        "library": .documentation
    ]

    /// Common programming libraries and their documentation needs
    private let libraryKeywords: Set<String> = [
        "react", "vue", "angular", "svelte", "nextjs", "nuxt",
        "express", "fastapi", "django", "flask", "rails",
        "swift", "swiftui", "uikit", "combine",
        "typescript", "javascript", "python", "rust", "go",
        "tensorflow", "pytorch", "langchain", "llamaindex",
        "postgres", "mongodb", "redis", "elasticsearch",
        "docker", "kubernetes", "terraform", "aws", "gcp", "azure"
    ]

    // MARK: - Initialization

    private init() {
        setupNLP()
        loadUserPreferences()
        loadUsageHistory()

        logger.info("ProactiveResourceMatcher initialized")
    }

    private func setupNLP() {
        nlpTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])
    }

    // MARK: - Public API

    /// Analyze text and find matching resources
    public func analyzeAndMatch(
        text: String,
        conversationId: UUID? = nil,
        intent: String? = nil
    ) async -> [ResourceMatch] {
        guard isEnabled else { return [] }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        isMatching = true
        defer { isMatching = false }

        let context = MatchContext(
            conversationId: conversationId,
            messageContent: text,
            detectedIntent: intent ?? detectIntent(text),
            extractedEntities: extractEntities(text),
            timeOfDay: currentTimeOfDayPeriod()
        )

        var matches: [ResourceMatch] = []

        // 1. Keyword-based matching
        let keywordMatches = await matchByKeywords(text, context: context)
        matches.append(contentsOf: keywordMatches)

        // 2. Library reference matching (for Context7)
        let libraryMatches = await matchLibraryReferences(text, context: context)
        matches.append(contentsOf: libraryMatches)

        // 3. Capability-based matching
        let capabilityMatches = await matchByCapabilities(text, context: context)
        matches.append(contentsOf: capabilityMatches)

        // 4. Pattern-based matching
        let patternMatches = await matchByPatterns(text, context: context)
        matches.append(contentsOf: patternMatches)

        // 5. User preference boost
        matches = applyUserPreferenceBoost(matches)

        // 6. Frequent use boost
        matches = applyFrequentUseBoost(matches)

        // Deduplicate and sort by confidence
        matches = deduplicateMatches(matches)
        matches.sort { $0.confidence > $1.confidence }

        // Filter by minimum confidence
        matches = matches.filter { $0.confidence >= minimumConfidence }

        // Limit results
        let topMatches = Array(matches.prefix(maxSuggestions))

        // Update state
        currentSuggestions = topMatches
        recentMatches = (topMatches + recentMatches).prefix(50).map { $0 }

        logger.debug("Found \(topMatches.count) matches for text analysis")

        return topMatches
    }

    /// Record that a user used a suggested resource
    public func recordUsage(resourceId: UUID, wasHelpful: Bool) {
        var stats = usageHistory[resourceId] ?? ResourceUsageStats()
        stats.usageCount += 1
        stats.lastUsed = Date()
        if wasHelpful {
            stats.helpfulCount += 1
        }
        usageHistory[resourceId] = stats
        saveUsageHistory()
    }

    /// Record user preference for a resource
    public func recordPreference(resourceId: UUID, isFavorite: Bool) {
        if isFavorite {
            userPreferences.favoriteResources.insert(resourceId)
        } else {
            userPreferences.favoriteResources.remove(resourceId)
        }
        saveUserPreferences()
    }

    /// Clear all suggestions
    public func clearSuggestions() {
        currentSuggestions = []
    }

    // MARK: - Matching Strategies

    private func matchByKeywords(_ text: String, context: MatchContext) async -> [ResourceMatch] {
        let textLower = text.lowercased()
        var matches: [ResourceMatch] = []

        // Extract keywords from text
        let words = textLower.components(separatedBy: .alphanumerics.inverted).filter { !$0.isEmpty }
        var matchedKeywords: [String] = []

        for word in words {
            if keywordToCapability.keys.contains(word) {
                matchedKeywords.append(word)
            }
        }

        guard !matchedKeywords.isEmpty else { return [] }

        // Find resources matching these keywords
        let searchQuery = matchedKeywords.joined(separator: " ")
        let resources = discoveryEngine.search(query: searchQuery, limit: 10)

        for resource in resources {
            let confidence = min(0.9, 0.5 + Double(matchedKeywords.count) * 0.1)
            let match = ResourceMatch(
                resource: resource,
                matchReason: .keywordMatch(keywords: matchedKeywords),
                confidence: confidence,
                context: context,
                suggestedTools: resource.tools
            )
            matches.append(match)
        }

        return matches
    }

    private func matchLibraryReferences(_ text: String, context: MatchContext) async -> [ResourceMatch] {
        let textLower = text.lowercased()
        var matches: [ResourceMatch] = []
        var detectedLibraries: [String] = []

        // Check for library mentions
        for library in libraryKeywords {
            if textLower.contains(library) {
                detectedLibraries.append(library)
            }
        }

        guard !detectedLibraries.isEmpty else { return [] }

        // Context7 is perfect for library documentation
        if let context7 = discoveryEngine.getResource(qualifiedName: "context7/documentation", registry: .context7) {
            for library in detectedLibraries {
                let match = ResourceMatch(
                    resource: context7,
                    matchReason: .libraryReference(library: library),
                    confidence: 0.85,
                    context: context,
                    suggestedTools: context7.tools.filter { $0.name.contains("library") || $0.name.contains("docs") }
                )
                matches.append(match)
            }
        }

        return matches
    }

    private func matchByCapabilities(_ text: String, context: MatchContext) async -> [ResourceMatch] {
        let textLower = text.lowercased()
        var matches: [ResourceMatch] = []
        var neededCapabilities: Set<ResourceCapability.CapabilityCategory> = []

        // Detect needed capabilities from text
        for (keyword, capability) in keywordToCapability {
            if textLower.contains(keyword) {
                neededCapabilities.insert(capability)
            }
        }

        guard !neededCapabilities.isEmpty else { return [] }

        // Find resources with matching capabilities
        for capability in neededCapabilities {
            let resources = discoveryEngine.findByCapability(capability)
            for resource in resources.prefix(3) {
                let match = ResourceMatch(
                    resource: resource,
                    matchReason: .capabilityNeed(capability: capability),
                    confidence: 0.6,
                    context: context,
                    suggestedTools: resource.tools.filter { _ in
                        resource.capabilities.contains { $0.category == capability }
                    }
                )
                matches.append(match)
            }
        }

        return matches
    }

    private func matchByPatterns(_ text: String, context: MatchContext) async -> [ResourceMatch] {
        var matches: [ResourceMatch] = []

        // Pattern: "how to X with Y" - likely needs documentation
        if text.lowercased().contains("how to") || text.lowercased().contains("how do") {
            if let context7 = discoveryEngine.getResource(qualifiedName: "context7/documentation", registry: .context7) {
                let match = ResourceMatch(
                    resource: context7,
                    matchReason: .patternDetected(pattern: "learning/how-to question"),
                    confidence: 0.7,
                    context: context,
                    suggestedTools: context7.tools
                )
                matches.append(match)
            }
        }

        // Pattern: "create/build X" - likely needs tools
        if text.lowercased().contains("create") || text.lowercased().contains("build") || text.lowercased().contains("make") {
            let toolResources = discoveryEngine.search(query: "create build generator", capabilities: [.tools], limit: 3)
            for resource in toolResources {
                let match = ResourceMatch(
                    resource: resource,
                    matchReason: .patternDetected(pattern: "creation task"),
                    confidence: 0.55,
                    context: context,
                    suggestedTools: resource.tools
                )
                matches.append(match)
            }
        }

        // Pattern: URLs or API references
        let urlPattern: NSRegularExpression?
        do {
            urlPattern = try NSRegularExpression(pattern: "https?://[\\w\\-._~:/?#\\[\\]@!$&'()*+,;=]+", options: [])
        } catch {
            logger.debug("Could not compile URL pattern: \(error.localizedDescription)")
            urlPattern = nil
        }
        if urlPattern?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil {
            let webResources = discoveryEngine.findByCapability(.web)
            for resource in webResources.prefix(2) {
                let match = ResourceMatch(
                    resource: resource,
                    matchReason: .patternDetected(pattern: "URL reference"),
                    confidence: 0.65,
                    context: context,
                    suggestedTools: resource.tools
                )
                matches.append(match)
            }
        }

        return matches
    }

    // MARK: - Boost Functions

    private func applyUserPreferenceBoost(_ matches: [ResourceMatch]) -> [ResourceMatch] {
        matches.map { match in
            var boostedMatch = match
            if userPreferences.favoriteResources.contains(match.resource.id) {
                boostedMatch.confidence = min(1.0, boostedMatch.confidence + 0.15)
            }
            return boostedMatch
        }
    }

    private func applyFrequentUseBoost(_ matches: [ResourceMatch]) -> [ResourceMatch] {
        matches.map { match in
            var boostedMatch = match
            if let stats = usageHistory[match.resource.id], stats.usageCount > 3 {
                let boost = min(0.2, Double(stats.usageCount) * 0.02)
                boostedMatch.confidence = min(1.0, boostedMatch.confidence + boost)
            }
            return boostedMatch
        }
    }

    // MARK: - Helper Methods

    private func detectIntent(_ text: String) -> String {
        let textLower = text.lowercased()

        if textLower.contains("how") || textLower.contains("what") || textLower.contains("why") {
            return "question"
        }
        if textLower.contains("create") || textLower.contains("build") || textLower.contains("make") {
            return "creation"
        }
        if textLower.contains("fix") || textLower.contains("error") || textLower.contains("bug") {
            return "debugging"
        }
        if textLower.contains("find") || textLower.contains("search") || textLower.contains("look") {
            return "search"
        }
        if textLower.contains("explain") || textLower.contains("understand") {
            return "learning"
        }

        return "general"
    }

    private func extractEntities(_ text: String) -> [String: String] {
        guard useNLPMatching, let tagger = nlpTagger else { return [:] }

        var entities: [String: String] = [:]

        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entity = String(text[range])
                entities[entity] = tag.rawValue
            }
            return true
        }

        return entities
    }

    private func currentTimeOfDayPeriod() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }

    private func deduplicateMatches(_ matches: [ResourceMatch]) -> [ResourceMatch] {
        var seen: Set<UUID> = []
        var unique: [ResourceMatch] = []

        for match in matches {
            if !seen.contains(match.resource.id) {
                seen.insert(match.resource.id)
                unique.append(match)
            }
        }

        return unique
    }

    // MARK: - Persistence

    private let preferencesKey = "thea.resource_matcher.preferences"
    private let historyKey = "thea.resource_matcher.history"

    private func saveUserPreferences() {
        do {
            let data = try JSONEncoder().encode(userPreferences)
            UserDefaults.standard.set(data, forKey: preferencesKey)
        } catch {
            logger.debug("Could not save user preferences: \(error.localizedDescription)")
        }
    }

    private func loadUserPreferences() {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey) else { return }
        do {
            userPreferences = try JSONDecoder().decode(UserResourcePreferences.self, from: data)
        } catch {
            logger.debug("Could not load user preferences: \(error.localizedDescription)")
        }
    }

    private func saveUsageHistory() {
        do {
            let data = try JSONEncoder().encode(usageHistory)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            logger.debug("Could not save usage history: \(error.localizedDescription)")
        }
    }

    private func loadUsageHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        do {
            usageHistory = try JSONDecoder().decode([UUID: ResourceUsageStats].self, from: data)
        } catch {
            logger.debug("Could not load usage history: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

private struct UserResourcePreferences: Codable {
    var favoriteResources: Set<UUID> = []
    var blockedResources: Set<UUID> = []
    var preferredRegistries: Set<ResourceRegistry> = []
}

private struct ResourceUsageStats: Codable {
    var usageCount: Int = 0
    var helpfulCount: Int = 0
    var lastUsed: Date?
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View showing proactive resource suggestions
public struct ResourceSuggestionsView: View {
    @StateObject private var matcher = ProactiveResourceMatcher.shared

    public init() {}

    @ViewBuilder
    public var body: some View {
        if !matcher.currentSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Suggested Resources")
                            .font(.headline)
                        Spacer()
                        Button(action: { matcher.clearSuggestions() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(matcher.currentSuggestions) { match in
                        ResourceMatchRow(match: match)
                    }
                }
                .padding()
                #if os(iOS)
                .background(Color(.systemBackground).opacity(0.95))
                #else
                .background(Color(.windowBackgroundColor).opacity(0.95))
                #endif
                .cornerRadius(12)
                .shadow(radius: 4)
        }
    }
}

struct ResourceMatchRow: View {
    let match: ResourceMatch

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.resource.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(match.matchReason.displayDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(Int(match.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
