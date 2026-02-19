// UnifiedIntelligenceHub+Core.swift
// Thea
//
// UnifiedIntelligenceHub class implementation.

import Foundation
import Observation
import os.log

private let hubLogger = Logger(subsystem: "ai.thea.app", category: "UnifiedIntelligenceHub")

// MARK: - Unified Intelligence Hub

@MainActor
@Observable
public final class UnifiedIntelligenceHub {
    public static let shared = UnifiedIntelligenceHub()

    // MARK: - State

    private(set) var isActive = false
    private(set) var detectedPatterns: [IntelligencePattern] = []
    private(set) var activeBlockers: [DetectedBlocker] = []
    private(set) var inferredGoals: [InferredGoal] = []
    private(set) var pendingSuggestions: [UnifiedSuggestion] = []
    private(set) var preloadedResources: [PreloadedResource] = []

    // MARK: - Metrics

    private(set) var suggestionAcceptanceRate: Double = 0.5
    private(set) var predictionAccuracy: Double = 0.5
    private(set) var averageResponseQuality: Double = 0.7
    private(set) var blockerResolutionRate: Double = 0.5

    // MARK: - History

    private var eventHistory: [IntelligenceEvent] = []
    private var suggestionHistory: [(suggestion: UnifiedSuggestion, accepted: Bool, timestamp: Date)] = []
    private var patternHistory: [IntelligencePattern] = []

    // MARK: - Configuration

    private let maxSuggestions = 3
    private let maxHistorySize = 1000
    private let patternDecayDays = 30
    // periphery:ignore - Reserved: suggestionCooldownSeconds property — reserved for future feature activation
    private let suggestionCooldownSeconds: TimeInterval = 60

    // periphery:ignore - Reserved: suggestionCooldownSeconds property reserved for future feature activation
    // MARK: - Subsystems

    private var subsystems: [String: any IntelligenceSubsystem] = [:]

    // MARK: - Initialization

    private init() {
        hubLogger.info("🧠 UnifiedIntelligenceHub initializing...")
        startBackgroundProcessing()
    }

    // MARK: - Public API

    /// Activate the intelligence hub
    public func activate() {
        isActive = true
        hubLogger.info("✅ UnifiedIntelligenceHub activated")
    }

    /// Deactivate the intelligence hub
    public func deactivate() {
        isActive = false
        hubLogger.info("⏸️ UnifiedIntelligenceHub deactivated")
    }

    /// Register an intelligence subsystem
    public func registerSubsystem(_ subsystem: any IntelligenceSubsystem) {
        subsystems[subsystem.subsystemId] = subsystem
        hubLogger.info("📦 Registered subsystem: \(subsystem.subsystemId)")
    }

    /// Process an intelligence event
    public func processEvent(_ event: IntelligenceEvent) async {
        guard isActive else { return }

        // Store in history
        eventHistory.append(event)
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst(eventHistory.count - maxHistorySize)
        }

        // Process event
        switch event {
        case .queryReceived(let query, let conversationId):
            await handleQueryReceived(query: query, conversationId: conversationId)

        case .responseGenerated(let quality, let latency):
            await handleResponseGenerated(quality: quality, latency: latency)

        case .taskCompleted(let taskType, let success, let duration):
            await handleTaskCompleted(taskType: taskType, success: success, duration: duration)

        case .patternDetected(let pattern):
            await handlePatternDetected(pattern)

        case .suggestionPresented(let suggestion):
            await handleSuggestionPresented(suggestion)

        case .suggestionAccepted(let suggestionId):
            await handleSuggestionAccepted(suggestionId: suggestionId)

        case .suggestionDismissed(let suggestionId):
            await handleSuggestionDismissed(suggestionId: suggestionId)

        case .blockerDetected(let blocker):
            await handleBlockerDetected(blocker)

        case .goalInferred(let goal):
            await handleGoalInferred(goal)

        case .contextPreloaded(let resources):
            await handleContextPreloaded(resources)

        case .userModelUpdated(let aspect):
            await handleUserModelUpdated(aspect: aspect)
        }

        // Forward to subsystems
        for (_, subsystem) in subsystems {
            await subsystem.processEvent(event)
        }
    }

    /// Get top suggestions for current context
    public func getTopSuggestions(context: IntelligenceContext) async -> [UnifiedSuggestion] {
        var allSuggestions: [UnifiedSuggestion] = []

        // Collect from all subsystems
        for (_, subsystem) in subsystems {
            let suggestions = await subsystem.getSuggestions(context: context)
            allSuggestions.append(contentsOf: suggestions)
        }

        // Add pending suggestions
        allSuggestions.append(contentsOf: pendingSuggestions)

        // Filter expired
        let now = Date()
        allSuggestions = allSuggestions.filter { suggestion in
            if let expiresAt = suggestion.expiresAt {
                return expiresAt > now
            }
            return true
        }

        // Deduplicate by title similarity
        allSuggestions = deduplicateSuggestions(allSuggestions)

        // Sort by combined score
        allSuggestions.sort { $0.combinedScore > $1.combinedScore }

        // Apply cognitive load limit
        let maxLoad = context.userModel.currentCognitiveLoad > 0.7 ? 1 : maxSuggestions

        return Array(allSuggestions.prefix(maxLoad))
    }

    /// Get current intelligence context
    public func buildContext(
        query: String? = nil,
        conversationId: UUID? = nil,
        recentQueries: [String] = []
    ) -> IntelligenceContext {
        IntelligenceContext(
            currentQuery: query,
            conversationId: conversationId,
            recentQueries: recentQueries,
            currentTaskType: inferCurrentTaskType(from: query),
            activeGoals: inferredGoals.filter { $0.progress < 1.0 },
            userModel: buildUserModelSnapshot(),
            timeOfDay: Date(),
            sessionDuration: calculateSessionDuration()
        )
    }

    // periphery:ignore - Reserved: context parameter — kept for API compatibility
    /// Check for blockers in current context
    public func checkForBlockers(context: IntelligenceContext) async -> [DetectedBlocker] {
        // periphery:ignore - Reserved: context parameter kept for API compatibility
        activeBlockers.filter { blocker in
            // Return blockers that haven't been resolved
            let age = Date().timeIntervalSince(blocker.detectedAt)
            return age < 3600 // Within last hour
        }
    }

    /// Get relevant patterns for a task type
    public func getPatternsForTask(_ taskType: String) -> [IntelligencePattern] {
        detectedPatterns.filter { pattern in
            pattern.metadata["taskType"] == taskType ||
            pattern.type == .workflow
        }.sorted { $0.confidence > $1.confidence }
    }

    /// Get progress on inferred goals
    public func getGoalProgress() -> [(goal: InferredGoal, trend: Double)] {
        inferredGoals.map { goal in
            // Calculate trend based on recent activity
            let trend = calculateGoalTrend(goal)
            return (goal, trend)
        }
    }

}

// MARK: - Private Event Handlers

extension UnifiedIntelligenceHub {

    // MARK: - Private Event Handlers

    // periphery:ignore - Reserved: _conversationId parameter kept for API compatibility
    private func handleQueryReceived(query: String, conversationId _conversationId: UUID) async {
        hubLogger.debug("📝 Query received: \(query.prefix(50))...")

        // Check for repeated queries (potential blocker)
        let recentQueries = eventHistory.compactMap { event -> String? in
            if case .queryReceived(let q, _) = event { return q }
            return nil
        }.suffix(10)

        let similarCount = recentQueries.filter { similar(query, $0) }.count
        if similarCount >= 3 {
            let blocker = DetectedBlocker(
                type: .repeatedQuery,
                description: "You've asked similar questions multiple times",
                severity: .medium,
                context: DetectedBlocker.BlockerContext(
                    attemptCount: similarCount,
                    relatedQueries: Array(recentQueries)
                ),
                suggestedResolutions: [
                    "Would you like me to rephrase the problem differently?",
                    "Let me break this down into smaller steps",
                    "Here's a different approach we could try"
                ]
            )
            await handleBlockerDetected(blocker)
        }
    }

    private func handleResponseGenerated(quality: Double, latency: TimeInterval) async {
        // Update running average
        averageResponseQuality = (averageResponseQuality * 0.9) + (quality * 0.1)

        if latency > 10.0 {
            hubLogger.warning("⚠️ Slow response: \(latency)s")
        }
    }

    private func handleTaskCompleted(taskType: String, success: Bool, duration: TimeInterval) async {
        // Detect patterns in task completion
        let pattern = IntelligencePattern(
            type: .productivity,
            description: "Completed \(taskType) task",
            confidence: success ? 0.8 : 0.4,
            metadata: [
                "taskType": taskType,
                "success": String(success),
                "duration": String(format: "%.1f", duration)
            ]
        )
        await handlePatternDetected(pattern)

        // Update goal progress if relevant
        for (index, goal) in inferredGoals.enumerated() {
            if isTaskRelatedToGoal(taskType: taskType, goal: goal) {
                let updatedGoal = goal
                let progressIncrement = success ? 0.1 : 0.02
                inferredGoals[index] = InferredGoal(
                    id: updatedGoal.id,
                    title: updatedGoal.title,
                    description: updatedGoal.description,
                    category: updatedGoal.category,
                    confidence: updatedGoal.confidence,
                    priority: updatedGoal.priority,
                    deadline: updatedGoal.deadline,
                    progress: min(1.0, updatedGoal.progress + progressIncrement),
                    relatedConversations: updatedGoal.relatedConversations,
                    relatedProjects: updatedGoal.relatedProjects,
                    subGoals: updatedGoal.subGoals,
                    inferredAt: updatedGoal.inferredAt,
                    lastUpdated: Date()
                )
            }
        }
    }

    private func handlePatternDetected(_ pattern: IntelligencePattern) async {
        // Check if we've seen this pattern before
        if let existingIndex = detectedPatterns.firstIndex(where: {
            $0.type == pattern.type && $0.description == pattern.description
        }) {
            // Update existing pattern
            let existing = detectedPatterns[existingIndex]
            detectedPatterns[existingIndex] = IntelligencePattern(
                id: existing.id,
                type: existing.type,
                description: existing.description,
                confidence: min(1.0, existing.confidence + 0.05),
                occurrences: existing.occurrences + 1,
                firstSeen: existing.firstSeen,
                lastSeen: Date(),
                metadata: existing.metadata.merging(pattern.metadata) { _, new in new }
            )
        } else {
            detectedPatterns.append(pattern)
        }

        // Prune old patterns
        let cutoff = Date().addingTimeInterval(-Double(patternDecayDays) * 86400)
        detectedPatterns = detectedPatterns.filter { $0.lastSeen > cutoff }

        hubLogger.debug("📊 Pattern tracked: \(pattern.type.rawValue) - \(pattern.description)")
    }

    private func handleSuggestionPresented(_ suggestion: UnifiedSuggestion) async {
        pendingSuggestions.append(suggestion)
    }

    private func handleSuggestionAccepted(suggestionId: UUID) async {
        if let index = pendingSuggestions.firstIndex(where: { $0.id == suggestionId }) {
            let suggestion = pendingSuggestions.remove(at: index)
            suggestionHistory.append((suggestion, true, Date()))
            updateSuggestionAcceptanceRate()
            hubLogger.info("✅ Suggestion accepted: \(suggestion.title)")
        }
    }

    private func handleSuggestionDismissed(suggestionId: UUID) async {
        if let index = pendingSuggestions.firstIndex(where: { $0.id == suggestionId }) {
            let suggestion = pendingSuggestions.remove(at: index)
            suggestionHistory.append((suggestion, false, Date()))
            updateSuggestionAcceptanceRate()
            hubLogger.debug("❌ Suggestion dismissed: \(suggestion.title)")
        }
    }

    private func handleBlockerDetected(_ blocker: DetectedBlocker) async {
        // Avoid duplicate blockers
        if !activeBlockers.contains(where: { $0.type == blocker.type }) {
            activeBlockers.append(blocker)

            // Create suggestion to address blocker
            let suggestion = UnifiedSuggestion(
                source: .blockerAnticipator,
                title: "I noticed you might be stuck",
                description: blocker.description,
                action: .showMessage(blocker.suggestedResolutions.first ?? "Would you like help?"),
                relevanceScore: 0.9,
                confidenceScore: Double(blocker.severity == .critical ? 0.95 : 0.7),
                timeSensitivity: blocker.severity == .critical ? .immediate : .soon,
                cognitiveLoad: .low
            )
            pendingSuggestions.append(suggestion)

            hubLogger.warning("🚧 Blocker detected: \(blocker.type.rawValue)")
        }
    }

    private func handleGoalInferred(_ goal: InferredGoal) async {
        // Check for existing similar goal
        if let existingIndex = inferredGoals.firstIndex(where: {
            similar($0.title, goal.title) || $0.relatedProjects.first == goal.relatedProjects.first
        }) {
            // Merge with existing
            let existing = inferredGoals[existingIndex]
            inferredGoals[existingIndex] = InferredGoal(
                id: existing.id,
                title: goal.confidence > existing.confidence ? goal.title : existing.title,
                description: goal.description.count > existing.description.count ? goal.description : existing.description,
                category: goal.category,
                confidence: max(existing.confidence, goal.confidence),
                priority: goal.priority,
                deadline: goal.deadline ?? existing.deadline,
                progress: max(existing.progress, goal.progress),
                relatedConversations: Array(Set(existing.relatedConversations + goal.relatedConversations)),
                relatedProjects: Array(Set(existing.relatedProjects + goal.relatedProjects)),
                subGoals: existing.subGoals + goal.subGoals,
                inferredAt: existing.inferredAt,
                lastUpdated: Date()
            )
        } else {
            inferredGoals.append(goal)
        }

        hubLogger.info("🎯 Goal tracked: \(goal.title) (confidence: \(String(format: "%.0f", goal.confidence * 100))%)")
    }

    private func handleContextPreloaded(_ resources: [PreloadedResource]) async {
        preloadedResources.append(contentsOf: resources)

        // Remove expired resources
        let now = Date()
        preloadedResources = preloadedResources.filter { $0.expiresAt > now }
    }

    private func handleUserModelUpdated(aspect: UserModelAspect) async {
        hubLogger.debug("👤 User model updated: \(aspect.rawValue)")
    }

    // MARK: - Private Helpers

    private func startBackgroundProcessing() {
        Task.detached { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }
                await self?.performPeriodicMaintenance()
            }
        }
    }

    private func performPeriodicMaintenance() async {
        // Clean up expired suggestions
        let now = Date()
        pendingSuggestions = pendingSuggestions.filter { suggestion in
            if let expiresAt = suggestion.expiresAt {
                return expiresAt > now
            }
            return true
        }

        // Clean up resolved blockers (older than 1 hour)
        let blockerCutoff = now.addingTimeInterval(-3600)
        activeBlockers = activeBlockers.filter { $0.detectedAt > blockerCutoff }

        // Decay pattern confidence
        for (index, pattern) in detectedPatterns.enumerated() {
            let daysSinceLastSeen = now.timeIntervalSince(pattern.lastSeen) / 86400
            if daysSinceLastSeen > 7 {
                let decayFactor = 1.0 - (daysSinceLastSeen / Double(patternDecayDays))
                detectedPatterns[index] = IntelligencePattern(
                    id: pattern.id,
                    type: pattern.type,
                    description: pattern.description,
                    confidence: pattern.confidence * max(0.1, decayFactor),
                    occurrences: pattern.occurrences,
                    firstSeen: pattern.firstSeen,
                    lastSeen: pattern.lastSeen,
                    metadata: pattern.metadata
                )
            }
        }

        // Trim history
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst(eventHistory.count - maxHistorySize)
        }
        if suggestionHistory.count > maxHistorySize {
            suggestionHistory.removeFirst(suggestionHistory.count - maxHistorySize)
        }
    }

    private func similar(_ a: String, _ b: String) -> Bool {
        let aLower = a.lowercased()
        let bLower = b.lowercased()

        // Simple similarity check - could be enhanced with embeddings
        if aLower == bLower { return true }
        if aLower.contains(bLower) || bLower.contains(aLower) { return true }

        // Word overlap
        let aWords = Set(aLower.split(separator: " ").map(String.init))
        let bWords = Set(bLower.split(separator: " ").map(String.init))
        let overlap = aWords.intersection(bWords)
        let similarity = Double(overlap.count) / Double(max(aWords.count, bWords.count))

        return similarity > 0.6
    }

    private func deduplicateSuggestions(_ suggestions: [UnifiedSuggestion]) -> [UnifiedSuggestion] {
        var seen: Set<String> = []
        var unique: [UnifiedSuggestion] = []

        for suggestion in suggestions {
            let key = suggestion.title.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(suggestion)
            }
        }

        return unique
    }

    private func updateSuggestionAcceptanceRate() {
        let recent = suggestionHistory.suffix(50)
        guard !recent.isEmpty else { return }
        let accepted = recent.filter { $0.accepted }.count
        suggestionAcceptanceRate = Double(accepted) / Double(recent.count)
    }

    private func inferCurrentTaskType(from query: String?) -> String? {
        guard let query = query?.lowercased() else { return nil }

        if query.contains("fix") || query.contains("bug") || query.contains("error") {
            return "debugging"
        } else if query.contains("write") || query.contains("create") || query.contains("implement") {
            return "codeGeneration"
        } else if query.contains("explain") || query.contains("what") || query.contains("how") {
            return "explanation"
        } else if query.contains("review") || query.contains("check") {
            return "codeReview"
        }
        return nil
    }

    private func buildUserModelSnapshot() -> IntelligenceContext.UserModelSnapshot {
        // Build from recent patterns and history
        IntelligenceContext.UserModelSnapshot(
            technicalLevel: 0.7, // Could be learned
            preferredVerbosity: 0.5,
            currentCognitiveLoad: calculateCurrentCognitiveLoad(),
            recentProductivity: calculateRecentProductivity()
        )
    }

    private func calculateSessionDuration() -> TimeInterval {
        guard let firstEvent = eventHistory.first else { return 0 }
        if case .queryReceived = firstEvent {
            return Date().timeIntervalSince(Date()) // Would need actual timestamp
        }
        return 0
    }

    private func calculateCurrentCognitiveLoad() -> Double {
        // Based on recent blockers and error frequency
        let recentBlockers = activeBlockers.count
        let baseLoad = min(1.0, Double(recentBlockers) * 0.3)
        return baseLoad
    }

    private func calculateRecentProductivity() -> Double {
        let recentTasks = eventHistory.suffix(20).compactMap { event -> Bool? in
            if case .taskCompleted(_, let success, _) = event {
                return success
            }
            return nil
        }
        guard !recentTasks.isEmpty else { return 0.5 }
        return Double(recentTasks.filter { $0 }.count) / Double(recentTasks.count)
    }

    private func isTaskRelatedToGoal(taskType: String, goal: InferredGoal) -> Bool {
        // Simple heuristic - could be enhanced
        let goalLower = goal.title.lowercased()
        let taskLower = taskType.lowercased()

        if goalLower.contains(taskLower) { return true }
        if goal.category == .project && taskType.contains("code") { return true }
        if goal.category == .learning && taskType.contains("explain") { return true }

        return false
    }

    private func calculateGoalTrend(_ goal: InferredGoal) -> Double {
        // Positive = progressing, Negative = stalled
        let daysSinceUpdate = Date().timeIntervalSince(goal.lastUpdated) / 86400

        if daysSinceUpdate < 1 {
            return 0.8 // Active progress
        } else if daysSinceUpdate < 3 {
            return 0.3 // Some progress
        } else if daysSinceUpdate < 7 {
            return -0.2 // Slowing down
        } else {
            return -0.5 // Stalled
        }
    }
}
