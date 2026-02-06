//
//  UnifiedSuggestionCoordinator.swift
//  Thea
//
//  Coordinates suggestions from all intelligence subsystems.
//  Deduplicates, ranks, and presents the best suggestions to users.
//

import Foundation
import Observation
import os.log

private let suggestionLogger = Logger(subsystem: "ai.thea.app", category: "UnifiedSuggestionCoordinator")

// MARK: - Suggestion Source Info

public struct SuggestionSourceInfo: Sendable {
    public let source: UnifiedSuggestion.SuggestionSource
    public let priority: Int
    public let cooldownSeconds: TimeInterval
    public let maxConcurrent: Int

    public init(
        source: UnifiedSuggestion.SuggestionSource,
        priority: Int,
        cooldownSeconds: TimeInterval,
        maxConcurrent: Int
    ) {
        self.source = source
        self.priority = priority
        self.cooldownSeconds = cooldownSeconds
        self.maxConcurrent = maxConcurrent
    }
}

// MARK: - Suggestion Feedback

public struct SuggestionFeedback: Sendable {
    public let suggestionId: UUID
    public let action: FeedbackAction
    public let timestamp: Date
    public let context: [String: String]

    public enum FeedbackAction: String, Sendable {
        case accepted
        case dismissed
        case deferred
        case helpful
        case notHelpful
        case tooFrequent
        case irrelevant
    }

    public init(
        suggestionId: UUID,
        action: FeedbackAction,
        timestamp: Date = Date(),
        context: [String: String] = [:]
    ) {
        self.suggestionId = suggestionId
        self.action = action
        self.timestamp = timestamp
        self.context = context
    }
}

// MARK: - Suggestion Statistics

public struct SuggestionStatistics: Sendable {
    public var totalPresented: Int
    public var totalAccepted: Int
    public var totalDismissed: Int
    public var acceptanceRate: Double
    public var averageTimeToAction: TimeInterval
    public var sourcePerformance: [String: Double]

    public init(
        totalPresented: Int = 0,
        totalAccepted: Int = 0,
        totalDismissed: Int = 0,
        acceptanceRate: Double = 0.5,
        averageTimeToAction: TimeInterval = 0,
        sourcePerformance: [String: Double] = [:]
    ) {
        self.totalPresented = totalPresented
        self.totalAccepted = totalAccepted
        self.totalDismissed = totalDismissed
        self.acceptanceRate = acceptanceRate
        self.averageTimeToAction = averageTimeToAction
        self.sourcePerformance = sourcePerformance
    }
}

// MARK: - Unified Suggestion Coordinator

@MainActor
@Observable
public final class UnifiedSuggestionCoordinator {
    public static let shared = UnifiedSuggestionCoordinator()

    // MARK: - State

    private(set) var activeSuggestions: [UnifiedSuggestion] = []
    private(set) var statistics = SuggestionStatistics()
    private(set) var isEnabled = true

    // MARK: - Configuration

    private let maxActiveSuggestions = 3
    private let globalCooldownSeconds: TimeInterval = 30
    private let duplicateWindowSeconds: TimeInterval = 300

    // MARK: - History

    private var presentedHistory: [(suggestion: UnifiedSuggestion, timestamp: Date)] = []
    private var feedbackHistory: [SuggestionFeedback] = []
    private var lastPresentationTime: Date?
    private var sourceCooldowns: [UnifiedSuggestion.SuggestionSource: Date] = [:]

    // MARK: - Source Configuration

    private let sourceConfig: [UnifiedSuggestion.SuggestionSource: SuggestionSourceInfo] = [
        .blockerAnticipator: SuggestionSourceInfo(source: .blockerAnticipator, priority: 1, cooldownSeconds: 60, maxConcurrent: 1),
        .goalProgress: SuggestionSourceInfo(source: .goalProgress, priority: 2, cooldownSeconds: 300, maxConcurrent: 1),
        .proactiveEngine: SuggestionSourceInfo(source: .proactiveEngine, priority: 3, cooldownSeconds: 120, maxConcurrent: 2),
        .contextPrediction: SuggestionSourceInfo(source: .contextPrediction, priority: 4, cooldownSeconds: 180, maxConcurrent: 1),
        .workflowAutomation: SuggestionSourceInfo(source: .workflowAutomation, priority: 5, cooldownSeconds: 600, maxConcurrent: 1),
        .memoryInsight: SuggestionSourceInfo(source: .memoryInsight, priority: 6, cooldownSeconds: 300, maxConcurrent: 1),
        .causalAnalysis: SuggestionSourceInfo(source: .causalAnalysis, priority: 7, cooldownSeconds: 600, maxConcurrent: 1)
    ]

    // MARK: - Initialization

    private init() {
        suggestionLogger.info("💡 UnifiedSuggestionCoordinator initializing...")
        startMaintenanceLoop()
    }

    // MARK: - Public API

    /// Submit suggestions from a source
    public func submitSuggestions(_ suggestions: [UnifiedSuggestion]) async {
        guard isEnabled else { return }

        for suggestion in suggestions {
            await processSuggestion(suggestion)
        }

        // Update active suggestions
        await updateActiveSuggestions()
    }

    /// Submit a single suggestion
    public func submitSuggestion(_ suggestion: UnifiedSuggestion) async {
        await submitSuggestions([suggestion])
    }

    /// Get current suggestions for display
    public func getCurrentSuggestions(context: IntelligenceContext) async -> [UnifiedSuggestion] {
        // Filter by context
        var filtered = activeSuggestions.filter { suggestion in
            // Check expiration
            if let expiresAt = suggestion.expiresAt, expiresAt < Date() {
                return false
            }

            // Check cognitive load limit
            if context.userModel.currentCognitiveLoad > 0.7 {
                return suggestion.cognitiveLoad == .minimal || suggestion.cognitiveLoad == .low
            }

            return true
        }

        // Apply time sensitivity filtering
        let now = Date()
        filtered = filtered.filter { suggestion in
            switch suggestion.timeSensitivity {
            case .immediate:
                return true
            case .soon:
                return true
            case .whenIdle:
                // Only show if no recent activity
                return context.sessionDuration > 60
            case .scheduled:
                return true
            case .lowPriority:
                return activeSuggestions.count <= 1
            }
        }

        // Sort by combined score
        filtered.sort { $0.combinedScore > $1.combinedScore }

        return Array(filtered.prefix(maxActiveSuggestions))
    }

    /// Record user feedback on a suggestion
    public func recordFeedback(_ feedback: SuggestionFeedback) async {
        feedbackHistory.append(feedback)

        // Update statistics
        switch feedback.action {
        case .accepted, .helpful:
            statistics.totalAccepted += 1
            await updateSourcePerformance(for: feedback.suggestionId, positive: true)

        case .dismissed, .notHelpful, .irrelevant:
            statistics.totalDismissed += 1
            await updateSourcePerformance(for: feedback.suggestionId, positive: false)

        case .tooFrequent:
            // Extend cooldown for this source
            if let suggestion = findSuggestion(by: feedback.suggestionId) {
                let extendedCooldown = Date().addingTimeInterval(600) // 10 minutes
                sourceCooldowns[suggestion.source] = extendedCooldown
            }

        case .deferred:
            // Keep in queue but lower priority
            break
        }

        // Remove from active suggestions
        activeSuggestions.removeAll { $0.id == feedback.suggestionId }

        // Notify hub
        if feedback.action == .accepted {
            await UnifiedIntelligenceHub.shared.processEvent(.suggestionAccepted(suggestionId: feedback.suggestionId))
        } else {
            await UnifiedIntelligenceHub.shared.processEvent(.suggestionDismissed(suggestionId: feedback.suggestionId))
        }

        // Update acceptance rate
        updateAcceptanceRate()

        suggestionLogger.debug("📝 Recorded feedback: \(feedback.action.rawValue) for suggestion \(feedback.suggestionId)")
    }

    /// Dismiss all active suggestions
    public func dismissAll() {
        for suggestion in activeSuggestions {
            Task {
                await recordFeedback(SuggestionFeedback(
                    suggestionId: suggestion.id,
                    action: .dismissed
                ))
            }
        }
        activeSuggestions.removeAll()
    }

    /// Enable/disable suggestions
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            activeSuggestions.removeAll()
        }
    }

    /// Get statistics
    public func getStatistics() -> SuggestionStatistics {
        statistics
    }

    /// Get suggestions by source
    public func getSuggestionsBySource(_ source: UnifiedSuggestion.SuggestionSource) -> [UnifiedSuggestion] {
        activeSuggestions.filter { $0.source == source }
    }

    // MARK: - Private Methods

    private func processSuggestion(_ suggestion: UnifiedSuggestion) async {
        // Check global cooldown
        if let lastTime = lastPresentationTime,
           Date().timeIntervalSince(lastTime) < globalCooldownSeconds {
            // Only high-priority suggestions bypass global cooldown
            if suggestion.timeSensitivity != .immediate {
                return
            }
        }

        // Check source-specific cooldown
        if let cooldownEnd = sourceCooldowns[suggestion.source],
           Date() < cooldownEnd {
            return
        }

        // Check for duplicates
        if isDuplicate(suggestion) {
            return
        }

        // Check source limits
        let currentFromSource = activeSuggestions.filter { $0.source == suggestion.source }.count
        if let config = sourceConfig[suggestion.source],
           currentFromSource >= config.maxConcurrent {
            // Replace if new one has higher score
            if let lowestIndex = activeSuggestions
                .enumerated()
                .filter({ $0.element.source == suggestion.source })
                .min(by: { $0.element.combinedScore < $1.element.combinedScore })?.offset {
                if activeSuggestions[lowestIndex].combinedScore < suggestion.combinedScore {
                    activeSuggestions.remove(at: lowestIndex)
                } else {
                    return
                }
            }
        }

        // Add to active suggestions
        activeSuggestions.append(suggestion)

        // Update cooldown
        if let config = sourceConfig[suggestion.source] {
            sourceCooldowns[suggestion.source] = Date().addingTimeInterval(config.cooldownSeconds)
        }

        // Track presentation
        presentedHistory.append((suggestion, Date()))
        statistics.totalPresented += 1
        lastPresentationTime = Date()

        // Notify hub
        await UnifiedIntelligenceHub.shared.processEvent(.suggestionPresented(suggestion: suggestion))

        suggestionLogger.debug("💡 Added suggestion: \(suggestion.title) from \(suggestion.source.rawValue)")
    }

    private func isDuplicate(_ suggestion: UnifiedSuggestion) -> Bool {
        let cutoff = Date().addingTimeInterval(-duplicateWindowSeconds)

        // Check active suggestions
        if activeSuggestions.contains(where: { isSimilar($0, suggestion) }) {
            return true
        }

        // Check recent history
        let recentPresentations = presentedHistory.filter { $0.timestamp > cutoff }
        if recentPresentations.contains(where: { isSimilar($0.suggestion, suggestion) }) {
            return true
        }

        return false
    }

    private func isSimilar(_ a: UnifiedSuggestion, _ b: UnifiedSuggestion) -> Bool {
        // Same title
        if a.title.lowercased() == b.title.lowercased() {
            return true
        }

        // High word overlap
        let aWords = Set(a.title.lowercased().split(separator: " ").map(String.init))
        let bWords = Set(b.title.lowercased().split(separator: " ").map(String.init))
        let overlap = Double(aWords.intersection(bWords).count) / Double(max(aWords.count, bWords.count))

        return overlap > 0.7
    }

    private func updateActiveSuggestions() async {
        // Remove expired suggestions
        let now = Date()
        activeSuggestions = activeSuggestions.filter { suggestion in
            if let expiresAt = suggestion.expiresAt {
                return expiresAt > now
            }
            return true
        }

        // Sort by combined score
        activeSuggestions.sort { $0.combinedScore > $1.combinedScore }

        // Trim to max
        if activeSuggestions.count > maxActiveSuggestions * 2 {
            activeSuggestions = Array(activeSuggestions.prefix(maxActiveSuggestions * 2))
        }
    }

    private func findSuggestion(by id: UUID) -> UnifiedSuggestion? {
        activeSuggestions.first { $0.id == id } ??
        presentedHistory.first { $0.suggestion.id == id }?.suggestion
    }

    private func updateSourcePerformance(for suggestionId: UUID, positive: Bool) async {
        guard let suggestion = findSuggestion(by: suggestionId) else { return }

        let source = suggestion.source.rawValue
        let currentScore = statistics.sourcePerformance[source] ?? 0.5

        let adjustment = positive ? 0.05 : -0.05
        statistics.sourcePerformance[source] = max(0.1, min(1.0, currentScore + adjustment))
    }

    private func updateAcceptanceRate() {
        let total = statistics.totalAccepted + statistics.totalDismissed
        if total > 0 {
            statistics.acceptanceRate = Double(statistics.totalAccepted) / Double(total)
        }
    }

    private func startMaintenanceLoop() {
        Task.detached { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(60))
                await self?.performMaintenance()
            }
        }
    }

    private func performMaintenance() async {
        // Clean expired suggestions
        let now = Date()
        activeSuggestions = activeSuggestions.filter { suggestion in
            if let expiresAt = suggestion.expiresAt {
                return expiresAt > now
            }
            // Default expiration: 10 minutes
            return true
        }

        // Clean old history
        let historyCutoff = now.addingTimeInterval(-3600) // 1 hour
        presentedHistory = presentedHistory.filter { $0.timestamp > historyCutoff }
        feedbackHistory = feedbackHistory.filter { $0.timestamp > historyCutoff }

        // Clean expired cooldowns
        sourceCooldowns = sourceCooldowns.filter { $0.value > now }
    }
}

// MARK: - Suggestion Builder

public struct SuggestionBuilder {
    private var source: UnifiedSuggestion.SuggestionSource
    private var title: String = ""
    private var description: String = ""
    private var action: UnifiedSuggestion.SuggestionAction = .showMessage("")
    private var relevanceScore: Double = 0.5
    private var confidenceScore: Double = 0.5
    private var timeSensitivity: UnifiedSuggestion.TimeSensitivity = .whenIdle
    private var cognitiveLoad: UnifiedSuggestion.CognitiveLoad = .low
    private var expiresAt: Date?
    private var metadata: [String: String] = [:]

    public init(source: UnifiedSuggestion.SuggestionSource) {
        self.source = source
    }

    public func title(_ title: String) -> SuggestionBuilder {
        var builder = self
        builder.title = title
        return builder
    }

    public func description(_ description: String) -> SuggestionBuilder {
        var builder = self
        builder.description = description
        return builder
    }

    public func action(_ action: UnifiedSuggestion.SuggestionAction) -> SuggestionBuilder {
        var builder = self
        builder.action = action
        return builder
    }

    public func relevance(_ score: Double) -> SuggestionBuilder {
        var builder = self
        builder.relevanceScore = score
        return builder
    }

    public func confidence(_ score: Double) -> SuggestionBuilder {
        var builder = self
        builder.confidenceScore = score
        return builder
    }

    public func timeSensitivity(_ sensitivity: UnifiedSuggestion.TimeSensitivity) -> SuggestionBuilder {
        var builder = self
        builder.timeSensitivity = sensitivity
        return builder
    }

    public func cognitiveLoad(_ load: UnifiedSuggestion.CognitiveLoad) -> SuggestionBuilder {
        var builder = self
        builder.cognitiveLoad = load
        return builder
    }

    public func expiresIn(_ seconds: TimeInterval) -> SuggestionBuilder {
        var builder = self
        builder.expiresAt = Date().addingTimeInterval(seconds)
        return builder
    }

    public func metadata(_ key: String, _ value: String) -> SuggestionBuilder {
        var builder = self
        builder.metadata[key] = value
        return builder
    }

    public func build() -> UnifiedSuggestion {
        UnifiedSuggestion(
            source: source,
            title: title,
            description: description,
            action: action,
            relevanceScore: relevanceScore,
            confidenceScore: confidenceScore,
            timeSensitivity: timeSensitivity,
            cognitiveLoad: cognitiveLoad,
            expiresAt: expiresAt,
            metadata: metadata
        )
    }
}
