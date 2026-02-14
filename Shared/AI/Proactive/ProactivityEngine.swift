// ProactivityEngine.swift
// Thea V2 - Omni-AI Proactivity System
//
// Enables THEA to anticipate user needs and act autonomously.
// Transforms THEA from reactive to proactive assistant.

import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Proactivity Engine

/// THEA's proactive intelligence - anticipates needs and acts autonomously
@MainActor
public final class ProactivityEngine: ObservableObject {
    public static let shared = ProactivityEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Proactivity")

    // MARK: - Published State

    @Published public private(set) var isEnabled = true
    @Published public private(set) var pendingSuggestions: [AIProactivitySuggestion] = []
    @Published public private(set) var activeAmbientAgents: [AmbientAgent] = []
    @Published public private(set) var lastPrediction: UserIntentPrediction?

    // MARK: - Configuration

    public var predictionConfidenceThreshold: Double = 0.7
    public var maxPendingSuggestions = 5
    public var suggestionCooldownMinutes = 15

    // MARK: - Internal State

    private var lastSuggestionTimes: [String: Date] = [:]
    private var ambientAgentTasks: [String: Task<Void, Never>] = [:]
    private var patternCache: [MemoryDetectedPattern] = []
    private var lastPatternAnalysis: Date?

    // MARK: - Context Watch State

    /// Registered context watches for contradiction detection
    @Published public private(set) var contextWatches: [ContextWatch] = []

    /// Detected context changes/contradictions
    @Published public private(set) var pendingProactiveContextChanges: [ProactiveContextChange] = []

    /// Task for context monitoring
    private var contextWatchTask: Task<Void, Never>?

    /// How often to check for context changes (seconds)
    public var contextCheckInterval: TimeInterval = 300  // 5 minutes

    private init() {
        logger.info("ProactivityEngine initialized")
    }

    // MARK: - Ambient Agents

    /// Register and start an ambient agent
    public func registerAmbientAgent(_ agent: AmbientAgent) {
        guard !activeAmbientAgents.contains(where: { $0.id == agent.id }) else {
            logger.warning("Ambient agent \(agent.id) already registered")
            return
        }

        activeAmbientAgents.append(agent)
        startAgent(agent)
        logger.info("Registered ambient agent: \(agent.name)")
    }

    /// Stop and unregister an ambient agent
    public func unregisterAmbientAgent(id: String) {
        ambientAgentTasks[id]?.cancel()
        ambientAgentTasks.removeValue(forKey: id)
        activeAmbientAgents.removeAll { $0.id == id }
        logger.info("Unregistered ambient agent: \(id)")
    }

    private func startAgent(_ agent: AmbientAgent) {
        let task = Task {
            while !Task.isCancelled && isEnabled {
                await agent.check()

                if let suggestion = await agent.generateSuggestion() {
                    await queueSuggestion(suggestion)
                }

                // Wait for next check interval
                try? await Task.sleep(nanoseconds: UInt64(agent.checkIntervalSeconds) * 1_000_000_000)
            }
        }

        ambientAgentTasks[agent.id] = task
    }

    // MARK: - Intent Prediction

    /// Predict user's next likely intent based on patterns and context
    public func predictNextIntent(
        currentContext: MemoryContextSnapshot,
        recentQueries: [String] = []
    ) async -> UserIntentPrediction? {
        // 1. Analyze time-based patterns
        let timePatterns = await getRelevantTimePatterns(for: currentContext)

        // 2. Analyze query sequence patterns
        let queryPatterns = await getQuerySequencePatterns(recentQueries: recentQueries)

        // 3. Analyze context-based patterns
        let contextPatterns = await getContextPatterns(context: currentContext)

        // 4. Combine predictions
        var predictions: [IntentCandidate] = []

        for pattern in timePatterns {
            predictions.append(IntentCandidate(
                intent: pattern.event,  // MemoryDetectedPattern uses .event
                confidence: pattern.confidence * 0.4,  // Time weight
                source: .timePattern
            ))
        }

        for pattern in queryPatterns {
            predictions.append(IntentCandidate(
                intent: pattern.intent,
                confidence: pattern.confidence * 0.35,  // Sequence weight
                source: .querySequence
            ))
        }

        for pattern in contextPatterns {
            predictions.append(IntentCandidate(
                intent: pattern.intent,
                confidence: pattern.confidence * 0.25,  // Context weight
                source: .contextMatch
            ))
        }

        // Aggregate by intent and find highest confidence
        let aggregated = Dictionary(grouping: predictions) { $0.intent }
            .mapValues { candidates in
                candidates.reduce(0.0) { $0 + $1.confidence }
            }

        guard let (topIntent, confidence) = aggregated.max(by: { $0.value < $1.value }),
              confidence >= predictionConfidenceThreshold else {
            return nil
        }

        let prediction = UserIntentPrediction(
            predictedIntent: topIntent,
            confidence: min(1.0, confidence),
            reasoning: generateReasoning(for: topIntent, predictions: predictions),
            suggestedPreparation: generatePreparation(for: topIntent)
        )

        lastPrediction = prediction
        logger.debug("Predicted intent: \(topIntent) (confidence: \(Int(confidence * 100))%)")

        return prediction
    }

    private func getRelevantTimePatterns(for context: MemoryContextSnapshot) async -> [MemoryDetectedPattern] {
        // Refresh pattern cache if stale (older than 1 hour)
        if lastPatternAnalysis == nil ||
           Date().timeIntervalSince(lastPatternAnalysis!) > 3600 {
            patternCache = await MemoryManager.shared.detectPatterns(windowDays: 30)
            lastPatternAnalysis = Date()
        }

        // Filter patterns matching current time context
        return patternCache.filter { pattern in
            // Match hour (within 1 hour window)
            let hourMatch = abs(pattern.hourOfDay - context.timeOfDay) <= 1
            // Match day of week
            let dayMatch = pattern.dayOfWeek == context.dayOfWeek

            return hourMatch && dayMatch
        }
    }

    private func getQuerySequencePatterns(recentQueries: [String]) async -> [IntentCandidate] {
        guard recentQueries.count >= 2 else { return [] }

        // Look for common follow-up patterns
        // This is simplified - a real implementation would use sequence learning
        var candidates: [IntentCandidate] = []

        // Check if recent query pattern suggests next step
        let lastQuery = recentQueries.last ?? ""

        // Common follow-up patterns
        let followUpPatterns: [(trigger: String, followUp: String, confidence: Double)] = [
            ("write code", "run tests", 0.6),
            ("create file", "edit file", 0.5),
            ("search for", "read more about", 0.4),
            ("debug", "fix bug", 0.7),
            ("review", "suggest improvements", 0.5),
            ("summarize", "action items", 0.5),
            ("draft email", "send email", 0.6),
            ("schedule meeting", "prepare agenda", 0.5)
        ]

        for pattern in followUpPatterns {
            if lastQuery.lowercased().contains(pattern.trigger) {
                candidates.append(IntentCandidate(
                    intent: pattern.followUp,
                    confidence: pattern.confidence,
                    source: .querySequence
                ))
            }
        }

        return candidates
    }

    private func getContextPatterns(context: MemoryContextSnapshot) async -> [IntentCandidate] {
        var candidates: [IntentCandidate] = []

        // Battery-based suggestions
        if let battery = context.batteryLevel, battery < 20 && context.isPluggedIn != true {
            candidates.append(IntentCandidate(
                intent: "switch to efficient mode",
                confidence: 0.8,
                source: .contextMatch
            ))
        }

        // Time-of-day based suggestions
        switch context.timeOfDay {
        case 8...9:
            candidates.append(IntentCandidate(
                intent: "morning briefing",
                confidence: 0.5,
                source: .contextMatch
            ))
        case 17...18:
            candidates.append(IntentCandidate(
                intent: "end of day summary",
                confidence: 0.5,
                source: .contextMatch
            ))
        default:
            break
        }

        return candidates
    }

    private func generateReasoning(for intent: String, predictions: [IntentCandidate]) -> String {
        let sources = Set(predictions.filter { $0.intent == intent }.map(\.source))
        let sourceNames = sources.map(\.description).joined(separator: ", ")
        return "Based on \(sourceNames)"
    }

    private func generatePreparation(for intent: String) -> [PreparationAction] {
        // Generate actions to prepare for predicted intent
        var actions: [PreparationAction] = []

        // Model pre-warming
        if intent.contains("code") {
            actions.append(.preWarmModel("code-specialized-model"))
        }

        // Context gathering
        actions.append(.gatherContext(intent))

        return actions
    }

    // MARK: - Proactive Suggestions

    /// Queue a proactive suggestion for the user
    public func queueSuggestion(_ suggestion: AIProactivitySuggestion) async {
        // Check cooldown
        if let lastTime = lastSuggestionTimes[suggestion.type],
           Date().timeIntervalSince(lastTime) < Double(suggestionCooldownMinutes * 60) {
            logger.debug("Suggestion \(suggestion.type) is in cooldown")
            return
        }

        // Check if duplicate pending
        guard !pendingSuggestions.contains(where: { $0.type == suggestion.type }) else {
            return
        }

        // Add to pending
        pendingSuggestions.append(suggestion)

        // Trim to max
        if pendingSuggestions.count > maxPendingSuggestions {
            pendingSuggestions = Array(pendingSuggestions.suffix(maxPendingSuggestions))
        }

        lastSuggestionTimes[suggestion.type] = Date()
        logger.info("Queued proactive suggestion: \(suggestion.title)")

        // Store as prospective memory (using MemoryManager's types)
        let memoryTrigger: MemoryTriggerCondition = .contextMatch(suggestion.reason)
        let memoryPriority: OmniMemoryPriority = suggestion.priority == .high ? .high : .normal
        await MemoryManager.shared.storeProspectiveMemory(
            intention: "Suggested: \(suggestion.title)",
            triggerCondition: memoryTrigger,
            priority: memoryPriority
        )
    }

    /// Dismiss a suggestion (user declined or actioned)
    public func dismissSuggestion(_ suggestion: AIProactivitySuggestion, wasActioned: Bool) async {
        pendingSuggestions.removeAll { $0.id == suggestion.id }

        // Learn from the interaction
        if wasActioned {
            await MemoryManager.shared.learnPreference(
                category: .timing,
                preference: "accepted_\(suggestion.type)",
                strength: 0.3
            )
        } else {
            await MemoryManager.shared.learnPreference(
                category: .timing,
                preference: "declined_\(suggestion.type)",
                strength: 0.2
            )
        }
    }

    // MARK: - Autonomous Actions

    /// Execute an autonomous action (with user permission system)
    public func executeAutonomousAction(
        _ action: ProactiveAutonomousAction,
        requiresConfirmation: Bool = true
    ) async -> ProactiveActionResult {
        guard isEnabled else {
            return ProactiveActionResult(
                success: false,
                message: "Proactivity engine is disabled"
            )
        }

        // Check if action is allowed
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "autonomousActionsEnabled") else {
            return ProactiveActionResult(
                success: false,
                message: "Autonomous actions are disabled in settings"
            )
        }

        // Check hourly limit
        let maxActions = defaults.integer(forKey: "maxAutonomousActionsPerHour")
        guard maxActions > 0 else {
            return ProactiveActionResult(
                success: false,
                message: "Autonomous action limit reached"
            )
        }

        // If requires confirmation, queue as suggestion instead
        if requiresConfirmation && defaults.bool(forKey: "requireAutonomousConfirmation") {
            await queueSuggestion(AIProactivitySuggestion(
                type: "autonomous_\(action.type)",
                title: action.description,
                reason: "THEA wants to: \(action.description)",
                priority: .normal,
                actionPayload: action.payload
            ))

            return ProactiveActionResult(
                success: true,
                message: "Action queued for user confirmation"
            )
        }

        // Execute the action
        do {
            try await action.execute()

            // Log successful autonomous action
            await MemoryManager.shared.storeEpisodicMemory(
                event: "autonomous_action",
                context: action.description,
                outcome: "success"
            )

            logger.info("Executed autonomous action: \(action.description)")

            return ProactiveActionResult(
                success: true,
                message: "Action completed: \(action.description)"
            )
        } catch {
            logger.error("Autonomous action failed: \(error.localizedDescription)")

            return ProactiveActionResult(
                success: false,
                message: "Action failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Engine Control

    /// Enable or disable proactive features
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled

        if enabled {
            // Restart all agents
            for agent in activeAmbientAgents {
                startAgent(agent)
            }
            logger.info("Proactivity engine enabled")
        } else {
            // Stop all agents
            for (id, task) in ambientAgentTasks {
                task.cancel()
                ambientAgentTasks.removeValue(forKey: id)
            }
            logger.info("Proactivity engine disabled")
        }
    }

    /// Reset engine state
    public func reset() {
        pendingSuggestions.removeAll()
        lastSuggestionTimes.removeAll()
        patternCache.removeAll()
        lastPatternAnalysis = nil
        lastPrediction = nil
        contextWatches.removeAll()
        pendingProactiveContextChanges.removeAll()
        stopContextWatching()
        logger.info("Proactivity engine reset")
    }

    // MARK: - Context Watches (Proactive Notifications)

    /// Register a context watch to monitor for changes/contradictions
    /// - Parameters:
    ///   - query: The original query to monitor
    ///   - originalAnswer: The answer that was provided
    ///   - conversationId: The conversation where this was discussed
    ///   - keywords: Keywords to monitor for new related information
    public func registerContextWatch(
        query: String,
        originalAnswer: String,
        conversationId: UUID,
        keywords: [String] = []
    ) {
        let watch = ContextWatch(
            query: query,
            originalAnswer: originalAnswer,
            conversationId: conversationId,
            keywords: keywords.isEmpty ? extractKeywords(from: query) : keywords,
            registeredAt: Date()
        )

        contextWatches.append(watch)
        logger.info("Registered context watch for query: \(query.prefix(50))...")

        // Start monitoring if not already running
        if contextWatchTask == nil {
            startContextWatching()
        }
    }

    /// Remove a context watch
    public func unregisterContextWatch(id: UUID) {
        contextWatches.removeAll { $0.id == id }
        logger.debug("Unregistered context watch: \(id)")

        // Stop monitoring if no watches left
        if contextWatches.isEmpty {
            stopContextWatching()
        }
    }

    /// Remove all context watches for a conversation
    public func unregisterContextWatches(forConversation conversationId: UUID) {
        let count = contextWatches.filter { $0.conversationId == conversationId }.count
        contextWatches.removeAll { $0.conversationId == conversationId }
        logger.debug("Unregistered \(count) context watches for conversation: \(conversationId)")
    }

    /// Dismiss a context change notification
    public func dismissProactiveContextChange(_ changeId: UUID, acknowledged: Bool = true) async {
        pendingProactiveContextChanges.removeAll { $0.id == changeId }

        if acknowledged {
            // Learn that user cares about this type of notification
            await MemoryManager.shared.learnPreference(
                category: .timing,
                preference: "context_change_acknowledged",
                strength: 0.2
            )
        }
    }

    /// Start monitoring for context changes
    private func startContextWatching() {
        guard contextWatchTask == nil else { return }

        contextWatchTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkProactiveContextChanges()

                do {
                    try await Task.sleep(for: .seconds(self?.contextCheckInterval ?? 300))
                } catch {
                    break
                }
            }
        }

        logger.info("Started context watch monitoring")
    }

    /// Stop monitoring for context changes
    private func stopContextWatching() {
        contextWatchTask?.cancel()
        contextWatchTask = nil
        logger.info("Stopped context watch monitoring")
    }

    /// Check all context watches for changes
    private func checkProactiveContextChanges() async {
        guard isEnabled, !contextWatches.isEmpty else { return }

        for watch in contextWatches {
            // Skip recently checked watches
            if let lastCheck = watch.lastChecked,
               Date().timeIntervalSince(lastCheck) < contextCheckInterval {
                continue
            }

            // Search memory for new related information
            let newFacts = await searchForNewFacts(related: watch)

            // Check for contradictions
            for fact in newFacts {
                if let contradiction = await detectContradiction(
                    originalAnswer: watch.originalAnswer,
                    newFact: fact.content
                ) {
                    let change = ProactiveContextChange(
                        watchId: watch.id,
                        conversationId: watch.conversationId,
                        originalQuery: watch.query,
                        originalAnswer: watch.originalAnswer,
                        newInformation: fact.content,
                        contradictionDetails: contradiction,
                        detectedAt: Date(),
                        source: fact.source
                    )

                    pendingProactiveContextChanges.append(change)
                    await notifyProactiveContextChange(change)

                    logger.info("Detected context change for watch: \(watch.id)")
                }
            }

            // Update last checked time
            if let index = contextWatches.firstIndex(where: { $0.id == watch.id }) {
                contextWatches[index].lastChecked = Date()
            }
        }
    }

    /// Search for new facts related to a context watch
    private func searchForNewFacts(related watch: ContextWatch) async -> [NewFactResult] {
        var results: [NewFactResult] = []

        // Query MemoryManager for recent memories matching keywords
        for keyword in watch.keywords {
            let memories = MemoryManager.shared.keywordSearch(
                query: keyword,
                limit: 5
            )

            for memory in memories {
                // Only consider facts newer than the watch registration
                if memory.timestamp > watch.registeredAt {
                    results.append(NewFactResult(
                        content: memory.value,
                        source: memory.source.rawValue,
                        timestamp: memory.timestamp
                    ))
                }
            }
        }

        return results
    }

    /// Detect if new information contradicts the original answer
    private func detectContradiction(
        originalAnswer: String,
        newFact: String
    ) async -> String? {
        // Simple keyword-based contradiction detection
        // A more sophisticated implementation would use semantic similarity

        let original = originalAnswer.lowercased()
        let newLower = newFact.lowercased()

        // Check for negation patterns
        let negationPatterns: [(String, String)] = [
            ("is not", "is"),
            ("isn't", "is"),
            ("cannot", "can"),
            ("won't", "will"),
            ("doesn't", "does"),
            ("never", "always"),
            ("false", "true"),
            ("incorrect", "correct"),
            ("wrong", "right"),
            ("outdated", "current"),
            ("deprecated", "supported"),
            ("removed", "available")
        ]

        for (negation, affirmation) in negationPatterns {
            // Check if original says X and new says NOT X
            if original.contains(affirmation) && newLower.contains(negation) {
                return "Original stated '\(affirmation)' but new information indicates '\(negation)'"
            }
            // Check if original says NOT X and new says X
            if original.contains(negation) && newLower.contains(affirmation) && !newLower.contains(negation) {
                return "Original stated '\(negation)' but new information suggests otherwise"
            }
        }

        // Check for version/date contradictions
        let versionPattern = try? NSRegularExpression(
            pattern: "\\b(version|v)?\\s*(\\d+\\.\\d+(?:\\.\\d+)?)\\b",
            options: .caseInsensitive
        )

        if let pattern = versionPattern {
            let originalVersions = pattern.matches(in: original, range: NSRange(original.startIndex..., in: original))
            let newVersions = pattern.matches(in: newLower, range: NSRange(newLower.startIndex..., in: newLower))

            if !originalVersions.isEmpty && !newVersions.isEmpty {
                // Versions mentioned in both - might indicate update
                return "Version information may have changed - please verify current versions"
            }
        }

        return nil
    }

    /// Notify about a context change
    private func notifyProactiveContextChange(_ change: ProactiveContextChange) async {
        // Queue as a proactive suggestion
        let suggestion = AIProactivitySuggestion(
            type: "context_change_\(change.id)",
            title: "Information Update Available",
            reason: "New information may affect a previous answer: \(change.contradictionDetails)",
            priority: .normal,
            actionPayload: [
                "watchId": change.watchId.uuidString,
                "conversationId": change.conversationId.uuidString
            ]
        )

        await queueSuggestion(suggestion)

        // Also store as prospective memory
        await MemoryManager.shared.storeProspectiveMemory(
            intention: "Notify user about context change: \(change.contradictionDetails)",
            triggerCondition: .contextMatch(change.originalQuery),
            priority: .high
        )
    }

    /// Extract keywords from a query for monitoring
    private func extractKeywords(from query: String) -> [String] {
        // Remove common words and extract meaningful keywords
        let stopWords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "shall", "can", "need", "dare",
            "ought", "used", "to", "of", "in", "for", "on", "with", "at", "by",
            "from", "up", "about", "into", "through", "during", "before", "after",
            "above", "below", "between", "under", "again", "further", "then",
            "once", "here", "there", "when", "where", "why", "how", "all", "each",
            "few", "more", "most", "other", "some", "such", "no", "nor", "not",
            "only", "own", "same", "so", "than", "too", "very", "just", "but",
            "and", "or", "if", "because", "as", "until", "while", "what", "which",
            "who", "whom", "this", "that", "these", "those", "am", "i", "me", "my",
            "we", "our", "you", "your", "he", "him", "his", "she", "her", "it",
            "its", "they", "them", "their"
        ]

        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopWords.contains($0) }

        // Return unique keywords, max 10
        return Array(Set(words).prefix(10))
    }
}

// MARK: - Ambient Agent Protocol

/// An ambient agent that runs continuously and monitors for triggers
public protocol AmbientAgent: Sendable {
    var id: String { get }
    var name: String { get }
    var checkIntervalSeconds: Int { get }

    func check() async
    func generateSuggestion() async -> AIProactivitySuggestion?
}

// MARK: - Built-in Ambient Agents

/// Monitors battery and suggests efficiency actions
public actor BatteryAmbientAgent: AmbientAgent {
    public let id = "battery_monitor"
    public let name = "Battery Monitor"
    public let checkIntervalSeconds = 300  // 5 minutes

    private var lastBatteryLevel: Int?
    private var alertedLow = false

    public init() {}

    public func check() async {
        // Get current battery level
        let batteryLevel: Int? = await MainActor.run {
            #if os(macOS)
            // macOS: read battery via IOKit (simplified)
            nil
            #elseif os(iOS)
            Int(UIDevice.current.batteryLevel * 100)
            #else
            nil
            #endif
        }
        lastBatteryLevel = batteryLevel
    }

    public func generateSuggestion() async -> AIProactivitySuggestion? {
        guard let level = lastBatteryLevel,
              level < 20,
              !alertedLow else {
            return nil
        }

        alertedLow = true

        return AIProactivitySuggestion(
            type: "low_battery",
            title: "Switch to Power Saving Mode",
            reason: "Battery is at \(level)%. I can switch to local-only models to save power.",
            priority: .high
        )
    }
}

/// Monitors time patterns and suggests daily routines
public actor TimePatternAgent: AmbientAgent {
    public let id = "time_pattern"
    public let name = "Time Pattern Monitor"
    public let checkIntervalSeconds = 600  // 10 minutes

    private var lastCheckedHour: Int = -1

    public init() {}

    public func check() async {
        let hour = Calendar.current.component(.hour, from: Date())
        lastCheckedHour = hour
    }

    public func generateSuggestion() async -> AIProactivitySuggestion? {
        let hour = lastCheckedHour

        switch hour {
        case 9:
            return AIProactivitySuggestion(
                type: "morning_briefing",
                title: "Morning Briefing",
                reason: "Would you like me to summarize your day ahead?",
                priority: .normal
            )
        case 17:
            return AIProactivitySuggestion(
                type: "end_of_day",
                title: "End of Day Summary",
                reason: "Ready to review what you accomplished today?",
                priority: .normal
            )
        default:
            return nil
        }
    }
}

// MARK: - Supporting Types

/// Proactive suggestion from the ProactivityEngine
/// Note: Distinct from ProactiveSuggestion in MultiModalCoordinator
public struct AIProactivitySuggestion: Identifiable, Sendable {
    public let id: UUID
    public let type: String
    public let title: String
    public let reason: String
    public let priority: EngineSuggestionPriority
    public let timestamp: Date
    public let actionPayload: [String: String]?

    public init(
        id: UUID = UUID(),
        type: String,
        title: String,
        reason: String,
        priority: EngineSuggestionPriority = .normal,
        actionPayload: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.reason = reason
        self.priority = priority
        self.timestamp = Date()
        self.actionPayload = actionPayload
    }
}

/// Priority level for proactive engine suggestions
public enum EngineSuggestionPriority: String, Sendable {
    case low
    case normal
    case high
}

public struct UserIntentPrediction: Sendable {
    public let predictedIntent: String
    public let confidence: Double
    public let reasoning: String
    public let suggestedPreparation: [PreparationAction]
}

public enum PreparationAction: Sendable {
    case preWarmModel(String)
    case gatherContext(String)
    case preloadData(String)
    case notifyUser(String)
}

struct IntentCandidate {
    let intent: String
    let confidence: Double
    let source: IntentSource
}

enum IntentSource: CustomStringConvertible {
    case timePattern
    case querySequence
    case contextMatch
    case userHistory

    var description: String {
        switch self {
        case .timePattern: return "time patterns"
        case .querySequence: return "recent activity"
        case .contextMatch: return "current context"
        case .userHistory: return "your history"
        }
    }
}

// MARK: - Autonomous Actions

public struct ProactiveAutonomousAction: Sendable {
    public let type: String
    public let description: String
    public let payload: [String: String]
    public let execute: @Sendable () async throws -> Void

    public init(
        type: String,
        description: String,
        payload: [String: String] = [:],
        execute: @escaping @Sendable () async throws -> Void
    ) {
        self.type = type
        self.description = description
        self.payload = payload
        self.execute = execute
    }
}

public struct ProactiveActionResult: Sendable {
    public let success: Bool
    public let message: String
}

// MARK: - Context Watch Types

/// A registered watch for monitoring context changes
public struct ContextWatch: Identifiable, Sendable {
    public let id: UUID
    public let query: String
    public let originalAnswer: String
    public let conversationId: UUID
    public let keywords: [String]
    public let registeredAt: Date
    public var lastChecked: Date?

    public init(
        id: UUID = UUID(),
        query: String,
        originalAnswer: String,
        conversationId: UUID,
        keywords: [String],
        registeredAt: Date = Date(),
        lastChecked: Date? = nil
    ) {
        self.id = id
        self.query = query
        self.originalAnswer = originalAnswer
        self.conversationId = conversationId
        self.keywords = keywords
        self.registeredAt = registeredAt
        self.lastChecked = lastChecked
    }
}

/// A detected change in context that may affect previous answers
public struct ProactiveContextChange: Identifiable, Sendable {
    public let id: UUID
    public let watchId: UUID
    public let conversationId: UUID
    public let originalQuery: String
    public let originalAnswer: String
    public let newInformation: String
    public let contradictionDetails: String
    public let detectedAt: Date
    public let source: String

    public init(
        id: UUID = UUID(),
        watchId: UUID,
        conversationId: UUID,
        originalQuery: String,
        originalAnswer: String,
        newInformation: String,
        contradictionDetails: String,
        detectedAt: Date = Date(),
        source: String
    ) {
        self.id = id
        self.watchId = watchId
        self.conversationId = conversationId
        self.originalQuery = originalQuery
        self.originalAnswer = originalAnswer
        self.newInformation = newInformation
        self.contradictionDetails = contradictionDetails
        self.detectedAt = detectedAt
        self.source = source
    }
}

/// Result of searching for new facts
private struct NewFactResult {
    let content: String
    let source: String
    let timestamp: Date
}
