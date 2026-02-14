//
//  GoalInferenceEngine.swift
//  Thea
//
//  Infers user goals from conversation patterns, task sequences, and explicit statements.
//  Enables goal-aware proactive suggestions and progress tracking.
//

import Foundation
import Observation
import os.log

private let goalLogger = Logger(subsystem: "ai.thea.app", category: "GoalInferenceEngine")

// MARK: - Goal Signal

public struct GoalSignal: Identifiable, Sendable {
    public let id: UUID
    public let type: SignalType
    public let content: String
    public let confidence: Double
    public let source: SignalSource
    public let timestamp: Date
    public let metadata: [String: String]

    public enum SignalType: String, Sendable {
        case explicitStatement   // "I want to build X"
        case implicitPattern     // Repeated focus on topic
        case projectCreation     // New project started
        case deadlineMention     // Time-bound reference
        case progressIndicator   // "Almost done with X"
        case blockerMention      // "Stuck on X"
        case learningIntent      // "How do I X?"
        case completionSignal    // "Finally finished X"
    }

    public enum SignalSource: String, Sendable {
        case conversationContent
        case conversationTitle
        case projectMetadata
        case taskPatterns
        case fileActivity
        case calendarEvents
        case userFeedback
    }

    public init(
        id: UUID = UUID(),
        type: SignalType,
        content: String,
        confidence: Double,
        source: SignalSource,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.confidence = confidence
        self.source = source
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Goal Extraction Pattern

private struct GoalPattern {
    let regex: String
    let category: InferredGoal.GoalCategory
    let confidenceBoost: Double
    let extractTitle: (String) -> String?
}

// MARK: - Goal Inference Engine

@MainActor
@Observable
public final class GoalInferenceEngine {
    public static let shared = GoalInferenceEngine()

    // MARK: - State

    private(set) var inferredGoals: [InferredGoal] = []
    private(set) var goalSignals: [GoalSignal] = []
    private(set) var isProcessing = false

    // MARK: - Configuration

    private let minConfidenceThreshold = 0.4
    private let signalDecayDays = 14
    private let maxSignalsPerGoal = 50
    private let consolidationInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Patterns

    private let goalPatterns: [GoalPattern] = [
        // Explicit project goals
        GoalPattern(
            regex: "(?:I want to|I need to|I'm trying to|help me|let's) (?:build|create|make|implement|develop) (.+)",
            category: .creation,
            confidenceBoost: 0.3
        ) { match in
            let cleaned = match
                .replacingOccurrences(of: "^(?:a|an|the) ", with: "", options: .regularExpression)
                .trimmingCharacters(in: .punctuationCharacters)
            return "Build \(cleaned)"
        },

        // Learning goals
        GoalPattern(
            regex: "(?:I want to|I need to|help me) (?:learn|understand|figure out|master) (.+)",
            category: .learning,
            confidenceBoost: 0.25
        ) { match in
            "Learn \(match.trimmingCharacters(in: .punctuationCharacters))"
        },

        // Fix/debug goals
        GoalPattern(
            regex: "(?:I need to|help me|let's) (?:fix|debug|solve|resolve) (.+)",
            category: .problemSolving,
            confidenceBoost: 0.25
        ) { match in
            "Fix \(match.trimmingCharacters(in: .punctuationCharacters))"
        },

        // Deadline-bound goals
        GoalPattern(
            regex: "(?:by|before|due|deadline is) (?:tomorrow|next week|monday|tuesday|wednesday|thursday|friday|saturday|sunday|\\d{1,2}[/-]\\d{1,2})",
            category: .project,
            confidenceBoost: 0.2
        ) { _ in nil },

        // Completion signals
        GoalPattern(
            regex: "(?:I've finished|done with|completed|finally) (.+)",
            category: .project,
            confidenceBoost: 0.4
        ) { match in
            match.trimmingCharacters(in: .punctuationCharacters)
        },

        // Productivity goals
        GoalPattern(
            regex: "(?:I want to|need to) (?:be more productive|work faster|improve|optimize) (.+)",
            category: .productivity,
            confidenceBoost: 0.2
        ) { match in
            "Improve \(match.trimmingCharacters(in: .punctuationCharacters))"
        }
    ]

    // MARK: - Initialization

    private init() {
        goalLogger.info("🎯 GoalInferenceEngine initializing...")
        startConsolidationTimer()
    }

    // MARK: - Public API

    /// Process a message for goal signals
    public func processMessage(
        content: String,
        conversationId: UUID,
        conversationTitle: String? = nil
    ) async {
        isProcessing = true
        defer { isProcessing = false }

        // Extract signals from message content
        let contentSignals = extractSignalsFromContent(content, conversationId: conversationId)
        goalSignals.append(contentsOf: contentSignals)

        // Extract signals from conversation title
        if let title = conversationTitle {
            let titleSignals = extractSignalsFromTitle(title, conversationId: conversationId)
            goalSignals.append(contentsOf: titleSignals)
        }

        // Consolidate signals into goals
        await consolidateSignalsIntoGoals()

        // Notify hub
        for goal in inferredGoals where goal.confidence >= minConfidenceThreshold {
            await UnifiedIntelligenceHub.shared.processEvent(.goalInferred(goal: goal))
        }
    }

    /// Process project creation
    public func processProjectCreation(
        projectName: String,
        projectPath: String,
        projectType: String?
    ) async {
        let signal = GoalSignal(
            type: .projectCreation,
            content: projectName,
            confidence: 0.7,
            source: .projectMetadata,
            metadata: [
                "path": projectPath,
                "type": projectType ?? "unknown"
            ]
        )
        goalSignals.append(signal)

        // Create goal immediately for project creation
        let goal = InferredGoal(
            title: "Complete \(projectName)",
            description: "Project created at \(projectPath)",
            category: .project,
            confidence: 0.6,
            priority: .medium,
            relatedProjects: [projectName]
        )

        await addOrUpdateGoal(goal)
    }

    /// Process task completion
    public func processTaskCompletion(
        taskType: String,
        success: Bool,
        conversationId: UUID?
    ) async {
        // Find related goals and update progress
        for (index, goal) in inferredGoals.enumerated() {
            if isTaskRelatedToGoal(taskType: taskType, goal: goal) {
                let progressIncrement = success ? 0.1 : 0.02
                inferredGoals[index] = InferredGoal(
                    id: goal.id,
                    title: goal.title,
                    description: goal.description,
                    category: goal.category,
                    confidence: goal.confidence,
                    priority: goal.priority,
                    deadline: goal.deadline,
                    progress: min(1.0, goal.progress + progressIncrement),
                    relatedConversations: conversationId != nil ?
                        (goal.relatedConversations + [conversationId!]) : goal.relatedConversations,
                    relatedProjects: goal.relatedProjects,
                    subGoals: goal.subGoals,
                    inferredAt: goal.inferredAt,
                    lastUpdated: Date()
                )
            }
        }
    }

    /// Get goals relevant to a query
    public func getRelevantGoals(for query: String) -> [InferredGoal] {
        let queryLower = query.lowercased()
        let queryWords = Set(queryLower.split(separator: " ").map(String.init))

        return inferredGoals
            .filter { goal in
                let titleWords = Set(goal.title.lowercased().split(separator: " ").map(String.init))
                let overlap = titleWords.intersection(queryWords)
                return !overlap.isEmpty || goal.confidence > 0.7
            }
            .sorted { $0.confidence > $1.confidence }
    }

    /// Get active goals (in progress)
    public func getActiveGoals() -> [InferredGoal] {
        inferredGoals.filter { $0.progress < 1.0 && $0.confidence >= minConfidenceThreshold }
    }

    /// Get completed goals
    public func getCompletedGoals() -> [InferredGoal] {
        inferredGoals.filter { $0.progress >= 1.0 }
    }

    /// Mark goal as completed
    public func markGoalCompleted(goalId: UUID) {
        if let index = inferredGoals.firstIndex(where: { $0.id == goalId }) {
            let goal = inferredGoals[index]
            inferredGoals[index] = InferredGoal(
                id: goal.id,
                title: goal.title,
                description: goal.description,
                category: goal.category,
                confidence: goal.confidence,
                priority: goal.priority,
                deadline: goal.deadline,
                progress: 1.0,
                relatedConversations: goal.relatedConversations,
                relatedProjects: goal.relatedProjects,
                subGoals: goal.subGoals,
                inferredAt: goal.inferredAt,
                lastUpdated: Date()
            )
            goalLogger.info("✅ Goal marked complete: \(goal.title)")
        }
    }

    /// Dismiss an inferred goal
    public func dismissGoal(goalId: UUID) {
        inferredGoals.removeAll { $0.id == goalId }
    }
}

// MARK: - Signal Extraction

extension GoalInferenceEngine {

    // MARK: - Signal Extraction

    private func extractSignalsFromContent(_ content: String, conversationId: UUID) -> [GoalSignal] {
        var signals: [GoalSignal] = []
        let contentLower = content.lowercased()

        for pattern in goalPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern.regex, options: [.caseInsensitive])
                let range = NSRange(contentLower.startIndex..., in: contentLower)

                regex.enumerateMatches(in: contentLower, options: [], range: range) { match, _, _ in
                    guard let match = match else { return }

                    let matchedString: String
                    if match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: contentLower) {
                        matchedString = String(contentLower[captureRange])
                    } else if let fullRange = Range(match.range, in: contentLower) {
                        matchedString = String(contentLower[fullRange])
                    } else {
                        return
                    }

                    let signal = GoalSignal(
                        type: determineSignalType(from: pattern, content: matchedString),
                        content: matchedString,
                        confidence: 0.5 + pattern.confidenceBoost,
                        source: .conversationContent,
                        metadata: [
                            "conversationId": conversationId.uuidString,
                            "category": pattern.category.rawValue
                        ]
                    )
                    signals.append(signal)
                }
            } catch {
                goalLogger.error("Regex error: \(error.localizedDescription)")
            }
        }

        // Check for implicit patterns (repeated topics)
        if let topicSignal = detectImplicitTopicPattern(content) {
            signals.append(topicSignal)
        }

        return signals
    }

    private func extractSignalsFromTitle(_ title: String, conversationId: UUID) -> [GoalSignal] {
        var signals: [GoalSignal] = []

        // Titles often indicate purpose
        let titleLower = title.lowercased()

        if titleLower.hasPrefix("fix") || titleLower.contains("bug") || titleLower.contains("error") {
            signals.append(GoalSignal(
                type: .implicitPattern,
                content: title,
                confidence: 0.6,
                source: .conversationTitle,
                metadata: ["category": "problemSolving", "conversationId": conversationId.uuidString]
            ))
        } else if titleLower.contains("build") || titleLower.contains("create") || titleLower.contains("implement") {
            signals.append(GoalSignal(
                type: .implicitPattern,
                content: title,
                confidence: 0.6,
                source: .conversationTitle,
                metadata: ["category": "creation", "conversationId": conversationId.uuidString]
            ))
        } else if titleLower.contains("learn") || titleLower.contains("how to") || titleLower.contains("understand") {
            signals.append(GoalSignal(
                type: .learningIntent,
                content: title,
                confidence: 0.5,
                source: .conversationTitle,
                metadata: ["category": "learning", "conversationId": conversationId.uuidString]
            ))
        }

        return signals
    }

    private func determineSignalType(from pattern: GoalPattern, content: String) -> GoalSignal.SignalType {
        switch pattern.category {
        case .learning:
            return .learningIntent
        case .problemSolving:
            return .blockerMention
        case .creation, .project:
            return .explicitStatement
        case .productivity:
            return .implicitPattern
        case .maintenance, .exploration:
            return .implicitPattern
        }
    }

    private func detectImplicitTopicPattern(_ content: String) -> GoalSignal? {
        // Extract key topics and check for repeated focus
        let words = content.lowercased().split(separator: " ")
        let techTerms = words.filter { word in
            // Filter for technical/topic words
            word.count > 4 &&
            !["about", "would", "could", "should", "which", "where", "there", "these", "those", "think", "really"].contains(String(word))
        }

        // This would be enhanced with actual topic modeling
        if techTerms.count > 3 {
            let topic = techTerms.prefix(3).joined(separator: " ")
            return GoalSignal(
                type: .implicitPattern,
                content: topic,
                confidence: 0.3,
                source: .conversationContent
            )
        }

        return nil
    }

    // MARK: - Goal Consolidation

    private func consolidateSignalsIntoGoals() async {
        // Group signals by similarity
        var signalGroups: [[GoalSignal]] = []

        for signal in goalSignals {
            var foundGroup = false
            for (index, group) in signalGroups.enumerated() {
                if let first = group.first, areSimilarSignals(signal, first) {
                    signalGroups[index].append(signal)
                    foundGroup = true
                    break
                }
            }
            if !foundGroup {
                signalGroups.append([signal])
            }
        }

        // Convert groups to goals
        for group in signalGroups where group.count >= 2 || (group.first?.confidence ?? 0) > 0.6 {
            if let goal = createGoalFromSignals(group) {
                await addOrUpdateGoal(goal)
            }
        }

        // Cleanup old signals
        let cutoff = Date().addingTimeInterval(-Double(signalDecayDays) * 86400)
        goalSignals = goalSignals.filter { $0.timestamp > cutoff }
    }

    private func areSimilarSignals(_ a: GoalSignal, _ b: GoalSignal) -> Bool {
        // Same type
        if a.type == b.type {
            return wordOverlap(a.content, b.content) > 0.4
        }

        // Related types
        let relatedTypes: Set<Set<GoalSignal.SignalType>> = [
            [.explicitStatement, .implicitPattern],
            [.blockerMention, .progressIndicator],
            [.learningIntent, .implicitPattern]
        ]

        for related in relatedTypes {
            if related.contains(a.type) && related.contains(b.type) {
                return wordOverlap(a.content, b.content) > 0.5
            }
        }

        return false
    }

    private func wordOverlap(_ a: String, _ b: String) -> Double {
        let aWords = Set(a.lowercased().split(separator: " ").map(String.init))
        let bWords = Set(b.lowercased().split(separator: " ").map(String.init))

        guard !aWords.isEmpty && !bWords.isEmpty else { return 0 }

        let overlap = aWords.intersection(bWords)
        return Double(overlap.count) / Double(max(aWords.count, bWords.count))
    }

    private func createGoalFromSignals(_ signals: [GoalSignal]) -> InferredGoal? {
        guard let primary = signals.max(by: { $0.confidence < $1.confidence }) else { return nil }

        // Determine category from signals
        let categories = signals.compactMap { signal -> InferredGoal.GoalCategory? in
            if let cat = signal.metadata["category"] {
                return InferredGoal.GoalCategory(rawValue: cat)
            }
            return nil
        }
        let category = categories.first ?? .project

        // Build title
        var title = primary.content.prefix(50)
        if !title.hasPrefix("Build") && !title.hasPrefix("Learn") && !title.hasPrefix("Fix") {
            switch category {
            case .creation: title = "Build \(title)"
            case .learning: title = "Learn \(title)"
            case .problemSolving: title = "Fix \(title)"
            case .productivity: title = "Improve \(title)"
            default: break
            }
        }

        // Calculate combined confidence
        let avgConfidence = signals.reduce(0.0) { $0 + $1.confidence } / Double(signals.count)
        let signalCountBoost = min(0.3, Double(signals.count) * 0.05)
        let confidence = min(1.0, avgConfidence + signalCountBoost)

        // Extract conversation IDs
        let conversationIds = signals.compactMap { signal -> UUID? in
            if let idString = signal.metadata["conversationId"] {
                return UUID(uuidString: idString)
            }
            return nil
        }

        return InferredGoal(
            title: String(title),
            description: "Inferred from \(signals.count) signals",
            category: category,
            confidence: confidence,
            priority: determinePriority(from: signals),
            deadline: extractDeadline(from: signals),
            relatedConversations: Array(Set(conversationIds))
        )
    }

    private func determinePriority(from signals: [GoalSignal]) -> InferredGoal.GoalPriority {
        // Check for urgency indicators
        let hasDeadline = signals.contains { $0.type == .deadlineMention }
        let hasBlocker = signals.contains { $0.type == .blockerMention }

        if hasDeadline { return .high }
        if hasBlocker { return .high }
        if signals.count > 5 { return .medium }
        return .medium
    }

    private func extractDeadline(from signals: [GoalSignal]) -> Date? {
        for signal in signals where signal.type == .deadlineMention {
            // Parse deadline from content (simplified)
            let content = signal.content.lowercased()
            if content.contains("tomorrow") {
                return Calendar.current.date(byAdding: .day, value: 1, to: Date())
            } else if content.contains("next week") {
                return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
            }
            // Could add more sophisticated date parsing
        }
        return nil
    }

    private func addOrUpdateGoal(_ goal: InferredGoal) async {
        // Check for existing similar goal
        if let existingIndex = inferredGoals.firstIndex(where: {
            wordOverlap($0.title, goal.title) > 0.5
        }) {
            let existing = inferredGoals[existingIndex]
            inferredGoals[existingIndex] = InferredGoal(
                id: existing.id,
                title: goal.confidence > existing.confidence ? goal.title : existing.title,
                description: goal.description.count > existing.description.count ? goal.description : existing.description,
                category: goal.category,
                confidence: max(existing.confidence, goal.confidence),
                priority: goal.priority.rawValue < existing.priority.rawValue ? goal.priority : existing.priority,
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
            goalLogger.info("🎯 New goal inferred: \(goal.title) (confidence: \(String(format: "%.0f", goal.confidence * 100))%)")
        }
    }

    private func isTaskRelatedToGoal(taskType: String, goal: InferredGoal) -> Bool {
        let goalLower = goal.title.lowercased()
        let taskLower = taskType.lowercased()

        if goalLower.contains(taskLower) { return true }
        if goal.category == .project && (taskLower.contains("code") || taskLower.contains("implement")) { return true }
        if goal.category == .learning && taskLower.contains("explain") { return true }
        if goal.category == .problemSolving && taskLower.contains("debug") { return true }

        return false
    }

    // MARK: - Background Processing

    private func startConsolidationTimer() {
        Task.detached { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(self?.consolidationInterval ?? 300))
                await self?.consolidateSignalsIntoGoals()
            }
        }
    }
}
