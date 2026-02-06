// EfficiencySuggestionEngine.swift
// Thea V2 - Proactive Efficiency Suggestion Engine
//
// Generates actionable suggestions based on detected behavior patterns:
// - Keyboard shortcut recommendations
// - Automation opportunities
// - Workflow optimizations
// - Focus time scheduling
// - Health & wellness reminders
//
// Learns from user acceptance/rejection to improve suggestions over time.

import Combine
import Foundation
import os.log

// MARK: - Efficiency Suggestion Engine

/// Generates proactive efficiency suggestions based on behavior patterns
@MainActor
public final class EfficiencySuggestionEngine: ObservableObject {
    public static let shared = EfficiencySuggestionEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "EfficiencySuggestionEngine")

    // MARK: - Published State

    @Published public private(set) var isActive = false
    @Published public private(set) var pendingSuggestions: [EfficiencySuggestion] = []
    @Published public private(set) var suggestionHistory: [SuggestionRecord] = []
    @Published public private(set) var acceptanceRate: Double = 0

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var suggestionTimer: Timer?
    private var dismissedSuggestionTypes: Set<String> = []
    private var acceptedCount = 0
    private var totalCount = 0

    // MARK: - Configuration

    public var configuration = SuggestionConfiguration()

    // MARK: - Initialization

    private init() {
        logger.info("EfficiencySuggestionEngine initialized")
    }

    // MARK: - Lifecycle

    /// Start the suggestion engine
    public func start() {
        guard !isActive else { return }

        logger.info("Starting efficiency suggestion engine...")

        // Subscribe to behavior patterns
        subscribeToPatterns()

        // Generate suggestions periodically
        suggestionTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.generateSuggestions()
            }
        }

        isActive = true
        logger.info("Efficiency suggestion engine started")
    }

    /// Stop the engine
    public func stop() {
        guard isActive else { return }

        suggestionTimer?.invalidate()
        suggestionTimer = nil
        cancellables.removeAll()

        isActive = false
        logger.info("Efficiency suggestion engine stopped")
    }

    // MARK: - Pattern Subscription

    private func subscribeToPatterns() {
        // Listen for new behavior patterns
        BehaviorPatternAnalyzer.shared.$detectedPatterns
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] patterns in
                Task { @MainActor [weak self] in
                    self?.processPatterns(patterns)
                }
            }
            .store(in: &cancellables)
    }

    private func processPatterns(_ patterns: [BehaviorPattern]) {
        for pattern in patterns {
            if let suggestion = generateSuggestionForPattern(pattern) {
                addSuggestion(suggestion)
            }
        }
    }

    // MARK: - Suggestion Generation

    /// Generate suggestions based on current state
    public func generateSuggestions() async {
        logger.debug("Generating efficiency suggestions...")

        var newSuggestions: [EfficiencySuggestion] = []

        // 1. Shortcut suggestions based on app usage
        newSuggestions.append(contentsOf: generateShortcutSuggestions())

        // 2. Focus time suggestions based on productivity patterns
        newSuggestions.append(contentsOf: generateFocusTimeSuggestions())

        // 3. Break reminders based on continuous activity
        newSuggestions.append(contentsOf: generateBreakSuggestions())

        // 4. Automation suggestions based on repetitive patterns
        newSuggestions.append(contentsOf: generateAutomationSuggestions())

        // 5. Workflow optimization suggestions
        newSuggestions.append(contentsOf: generateWorkflowSuggestions())

        // Filter out dismissed suggestion types
        newSuggestions = newSuggestions.filter { suggestion in
            !dismissedSuggestionTypes.contains(suggestion.type.rawValue)
        }

        // Add new unique suggestions
        for suggestion in newSuggestions {
            if !pendingSuggestions.contains(where: { $0.title == suggestion.title }) {
                addSuggestion(suggestion)
            }
        }

        // Limit pending suggestions
        if pendingSuggestions.count > 10 {
            pendingSuggestions = Array(pendingSuggestions.prefix(10))
        }

        logger.info("Generated \(newSuggestions.count) new suggestions, \(self.pendingSuggestions.count) pending")
    }

    private func generateSuggestionForPattern(_ pattern: BehaviorPattern) -> EfficiencySuggestion? {
        switch pattern.type {
        case .repetitiveAction:
            return EfficiencySuggestion(
                id: UUID(),
                type: .automation,
                title: "Automate Repetitive Task",
                description: pattern.description,
                actionLabel: "Create Shortcut",
                impact: .high,
                effort: .medium,
                category: .workflow,
                relatedApps: Array(pattern.relatedApps),
                createdAt: Date()
            )

        case .distraction:
            return EfficiencySuggestion(
                id: UUID(),
                type: .focus,
                title: "Reduce Distractions",
                description: pattern.description,
                actionLabel: "Enable Focus Mode",
                impact: .high,
                effort: .low,
                category: .focus,
                relatedApps: Array(pattern.relatedApps),
                createdAt: Date()
            )

        case .inefficiency:
            return EfficiencySuggestion(
                id: UUID(),
                type: .workflow,
                title: "Improve Workflow",
                description: pattern.description,
                actionLabel: "Learn More",
                impact: .medium,
                effort: .low,
                category: .workflow,
                relatedApps: [],
                createdAt: Date()
            )

        case .productivityPeak:
            return EfficiencySuggestion(
                id: UUID(),
                type: .scheduling,
                title: "Optimize Your Schedule",
                description: "Schedule important tasks during your peak hours: \(pattern.description)",
                actionLabel: "View Calendar",
                impact: .medium,
                effort: .low,
                category: .time,
                relatedApps: [],
                createdAt: Date()
            )

        case .healthRisk:
            return EfficiencySuggestion(
                id: UUID(),
                type: .health,
                title: "Health Reminder",
                description: pattern.description,
                actionLabel: "Dismiss",
                impact: .medium,
                effort: .low,
                category: .wellbeing,
                relatedApps: [],
                createdAt: Date()
            )

        case .opportunity:
            return nil
        }
    }

    private func generateShortcutSuggestions() -> [EfficiencySuggestion] {
        var suggestions: [EfficiencySuggestion] = []

        // Get app usage data
        let topApps = AppUsageMonitor.shared.getTopApps(limit: 5)

        for appRecord in topApps {
            // Suggest keyboard shortcuts for frequently used apps
            if appRecord.totalDuration > 3600 { // More than 1 hour of use
                let shortcutSuggestion = getShortcutSuggestion(for: appRecord.app.bundleIdentifier)
                if let suggestion = shortcutSuggestion {
                    suggestions.append(suggestion)
                }
            }
        }

        return suggestions
    }

    private func generateFocusTimeSuggestions() -> [EfficiencySuggestion] {
        var suggestions: [EfficiencySuggestion] = []

        let insights = BehaviorPatternAnalyzer.shared.productivityInsights

        // Suggest scheduling focus time during peak hours
        if !insights.peakProductivityHours.isEmpty && insights.overallProductivityLevel != .high {
            let peakHoursStr = insights.peakProductivityHours.map { "\($0):00" }.joined(separator: ", ")
            suggestions.append(EfficiencySuggestion(
                id: UUID(),
                type: .focus,
                title: "Schedule Deep Work",
                description: "Your peak productivity hours are \(peakHoursStr). Consider scheduling focused work during these times.",
                actionLabel: "Schedule",
                impact: .high,
                effort: .low,
                category: .time,
                relatedApps: [],
                createdAt: Date()
            ))
        }

        return suggestions
    }

    private func generateBreakSuggestions() -> [EfficiencySuggestion] {
        var suggestions: [EfficiencySuggestion] = []

        let inputStats = InputActivityMonitor.shared.todayStats

        // Suggest break if active for more than 90 minutes continuously
        if inputStats.totalActiveTime > 5400 && inputStats.sessionCount <= 2 {
            suggestions.append(EfficiencySuggestion(
                id: UUID(),
                type: .health,
                title: "Time for a Break",
                description: "You've been actively working for over 90 minutes. A short break can boost productivity.",
                actionLabel: "Start Break Timer",
                impact: .medium,
                effort: .low,
                category: .wellbeing,
                relatedApps: [],
                createdAt: Date()
            ))
        }

        return suggestions
    }

    private func generateAutomationSuggestions() -> [EfficiencySuggestion] {
        var suggestions: [EfficiencySuggestion] = []

        // Check for repetitive patterns that could be automated
        let patterns = BehaviorPatternAnalyzer.shared.detectedPatterns

        for pattern in patterns where pattern.type == .repetitiveAction && pattern.frequency >= 5 {
            if let timeSaved = pattern.potentialTimeSaved, timeSaved > 300 { // More than 5 minutes saved
                suggestions.append(EfficiencySuggestion(
                    id: UUID(),
                    type: .automation,
                    title: "Automation Opportunity",
                    description: "This task could save you \(Int(timeSaved / 60)) minutes if automated.",
                    actionLabel: "Create Automation",
                    impact: .high,
                    effort: .medium,
                    category: .workflow,
                    relatedApps: Array(pattern.relatedApps),
                    createdAt: Date()
                ))
            }
        }

        return suggestions
    }

    private func generateWorkflowSuggestions() -> [EfficiencySuggestion] {
        var suggestions: [EfficiencySuggestion] = []

        let insights = BehaviorPatternAnalyzer.shared.productivityInsights

        // Suggest workflow improvements based on context switch cost
        if insights.contextSwitchCost > 1800 { // More than 30 minutes lost to context switching
            suggestions.append(EfficiencySuggestion(
                id: UUID(),
                type: .workflow,
                title: "Reduce Context Switching",
                description: "You've lost ~\(Int(insights.contextSwitchCost / 60)) minutes today to context switching. Try batching similar tasks together.",
                actionLabel: "Learn More",
                impact: .high,
                effort: .medium,
                category: .workflow,
                relatedApps: [],
                createdAt: Date()
            ))
        }

        return suggestions
    }

    private func getShortcutSuggestion(for bundleId: String) -> EfficiencySuggestion? {
        // App-specific shortcut suggestions
        let shortcuts: [String: (title: String, shortcut: String)] = [
            "com.apple.Safari": ("Quick Tab Navigation", "⌘+1-9 to switch tabs, ⌘+T for new tab"),
            "com.apple.mail": ("Email Shortcuts", "⌘+⇧+D to send, ⌘+R to reply"),
            "com.apple.finder": ("Finder Navigation", "⌘+⇧+G to go to folder, ⌘+⇧+. to show hidden"),
            "com.microsoft.VSCode": ("Code Navigation", "⌘+P to quick open, ⌘+⇧+F for global search"),
            "com.apple.dt.Xcode": ("Xcode Shortcuts", "⌘+B to build, ⌘+R to run"),
            "com.tinyspeck.slackmacgap": ("Slack Navigation", "⌘+K to quick switch, ⌘+⇧+A for all unreads")
        ]

        guard let (title, shortcut) = shortcuts[bundleId] else { return nil }

        return EfficiencySuggestion(
            id: UUID(),
            type: .shortcut,
            title: title,
            description: "Try these shortcuts: \(shortcut)",
            actionLabel: "Got it",
            impact: .low,
            effort: .low,
            category: .shortcuts,
            relatedApps: [bundleId],
            createdAt: Date()
        )
    }

    // MARK: - Suggestion Management

    private func addSuggestion(_ suggestion: EfficiencySuggestion) {
        pendingSuggestions.append(suggestion)

        // Emit event
        let event = LifeEvent(
            type: .efficiencySuggestion,
            source: .inputActivity,
            summary: suggestion.title,
            data: [
                "suggestionId": suggestion.id.uuidString,
                "type": suggestion.type.rawValue,
                "description": suggestion.description,
                "impact": suggestion.impact.rawValue,
                "effort": suggestion.effort.rawValue
            ],
            significance: suggestion.impact == .high ? .moderate : .minor
        )

        LifeMonitoringCoordinator.shared.submitEvent(event)
    }

    /// Mark a suggestion as accepted
    public func acceptSuggestion(_ suggestion: EfficiencySuggestion) {
        if let index = pendingSuggestions.firstIndex(where: { $0.id == suggestion.id }) {
            pendingSuggestions.remove(at: index)
        }

        suggestionHistory.append(SuggestionRecord(
            suggestion: suggestion,
            outcome: .accepted,
            respondedAt: Date()
        ))

        acceptedCount += 1
        totalCount += 1
        updateAcceptanceRate()

        logger.info("Suggestion accepted: \(suggestion.title)")
    }

    /// Mark a suggestion as dismissed
    public func dismissSuggestion(_ suggestion: EfficiencySuggestion, permanently: Bool = false) {
        if let index = pendingSuggestions.firstIndex(where: { $0.id == suggestion.id }) {
            pendingSuggestions.remove(at: index)
        }

        if permanently {
            dismissedSuggestionTypes.insert(suggestion.type.rawValue)
        }

        suggestionHistory.append(SuggestionRecord(
            suggestion: suggestion,
            outcome: permanently ? .dismissedPermanently : .dismissed,
            respondedAt: Date()
        ))

        totalCount += 1
        updateAcceptanceRate()

        logger.info("Suggestion dismissed: \(suggestion.title), permanently: \(permanently)")
    }

    private func updateAcceptanceRate() {
        if totalCount > 0 {
            acceptanceRate = Double(acceptedCount) / Double(totalCount)
        }
    }
}

// MARK: - Supporting Types

/// Configuration for the suggestion engine
public struct SuggestionConfiguration: Sendable {
    public var maxPendingSuggestions: Int = 10
    public var suggestionIntervalSeconds: TimeInterval = 600
    public var minImpactForNotification: SuggestionImpact = .medium
}

/// An efficiency suggestion
public struct EfficiencySuggestion: Identifiable, Sendable {
    public let id: UUID
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let actionLabel: String
    public let impact: SuggestionImpact
    public let effort: SuggestionEffort
    public let category: SuggestionCategory
    public let relatedApps: [String]
    public let createdAt: Date

    public enum SuggestionType: String, Sendable {
        case shortcut = "shortcut"
        case automation = "automation"
        case workflow = "workflow"
        case focus = "focus"
        case scheduling = "scheduling"
        case health = "health"
    }

    public enum SuggestionCategory: String, Sendable {
        case shortcuts = "shortcuts"
        case workflow = "workflow"
        case focus = "focus"
        case time = "time"
        case wellbeing = "wellbeing"
    }
}

/// Impact level of a suggestion
public enum SuggestionImpact: String, Sendable, Comparable {
    case low, medium, high

    public static func < (lhs: SuggestionImpact, rhs: SuggestionImpact) -> Bool {
        let order: [SuggestionImpact] = [.low, .medium, .high]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// Effort level to implement a suggestion
public enum SuggestionEffort: String, Sendable {
    case low, medium, high
}

/// Record of a suggestion outcome
public struct SuggestionRecord: Identifiable, Sendable {
    public var id: UUID { suggestion.id }
    public let suggestion: EfficiencySuggestion
    public let outcome: SuggestionOutcome
    public let respondedAt: Date

    public enum SuggestionOutcome: String, Sendable {
        case accepted
        case dismissed
        case dismissedPermanently
        case expired
    }
}
