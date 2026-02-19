// AutomatableSuggestionEngine.swift
// THEA - Automatable Suggestion System
// Created by Claude - February 2026
//
// ALL suggestions are automatable with proper user consent
// Suggestions evolve from: Suggestion -> Pre-approved -> Fully Automated

import Foundation

// MARK: - User Consent System

/// Manages user consent for automation
public actor UserConsentManager {
    public static let shared = UserConsentManager()

    private var categoryConsents: [SuggestionCategory: AutomationLevel] = [:]
    private var specificConsents: [String: SpecificConsent] = [:] // pattern hash -> consent
    private var consentHistory: [ConsentRecord] = []

    public struct SpecificConsent: Sendable {
        public let pattern: String // Description of what's being consented to
        public let automationLevel: AutomationLevel
        public let conditions: [String: String]? // Additional conditions
        public let expiresAt: Date?
        public let createdAt: Date

        public var isExpired: Bool {
            if let expires = expiresAt {
                return Date() > expires
            }
            return false
        }
    }

    public struct ConsentRecord: Sendable {
        public let category: SuggestionCategory
        public let pattern: String?
        public let oldLevel: AutomationLevel
        public let newLevel: AutomationLevel
        public let timestamp: Date
        public let reason: String?
    }

    private init() {
        // Consents will be loaded when start() is called
    }

    // MARK: - Initialization

    /// Load consents from persistent storage (call after init)
    public func loadSavedConsents() {
        loadConsentsFromStorage()
    }

    // MARK: - Public API

    /// Get consent level for a category
    public func getConsentLevel(for category: SuggestionCategory) -> AutomationLevel {
        categoryConsents[category] ?? .suggestOnly
    }

    /// Get consent level for a specific pattern
    public func getConsentLevel(for pattern: String, category: SuggestionCategory) -> AutomationLevel {
        // Check specific consent first
        if let specific = specificConsents[pattern], !specific.isExpired {
            return specific.automationLevel
        }
        // Fall back to category consent
        return getConsentLevel(for: category)
    }

    /// Set consent level for a category
    public func setConsentLevel(
        _ level: AutomationLevel,
        for category: SuggestionCategory,
        reason: String? = nil
    ) {
        let old = categoryConsents[category] ?? .suggestOnly
        categoryConsents[category] = level

        recordConsent(ConsentRecord(
            category: category,
            pattern: nil,
            oldLevel: old,
            newLevel: level,
            timestamp: Date(),
            reason: reason
        ))

        saveConsents()
    }

    /// Set consent for a specific pattern
    public func setSpecificConsent(
        _ level: AutomationLevel,
        for pattern: String,
        category: SuggestionCategory,
        conditions: [String: String]? = nil,
        expiresIn: TimeInterval? = nil,
        reason: String? = nil
    ) {
        let old = specificConsents[pattern]?.automationLevel ?? getConsentLevel(for: category)

        specificConsents[pattern] = SpecificConsent(
            pattern: pattern,
            automationLevel: level,
            conditions: conditions,
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) },
            createdAt: Date()
        )

        recordConsent(ConsentRecord(
            category: category,
            pattern: pattern,
            oldLevel: old,
            newLevel: level,
            timestamp: Date(),
            reason: reason
        ))

        saveConsents()
    }

    /// Check if action should be executed based on consent
    public func shouldExecute(
        suggestion: AutomatableSuggestion,
        pattern: String
    ) -> (shouldExecute: Bool, requiresConfirmation: Bool) {
        let level = getConsentLevel(for: pattern, category: suggestion.category)

        switch level {
        case .manualOnly:
            return (false, false) // Never auto-execute
        case .suggestOnly:
            return (false, false) // Only show suggestion
        case .confirmEach:
            return (true, true) // Execute but confirm first
        case .preApproved:
            return (true, false) // Execute if confidence high enough
        case .fullyAutomated:
            return (true, false) // Always execute
        }
    }

    /// Revoke all consents for a category
    public func revokeConsents(for category: SuggestionCategory) {
        categoryConsents[category] = .suggestOnly

        // Also revoke specific consents in this category
        specificConsents = specificConsents.filter { !$0.key.contains(category.rawValue) }

        saveConsents()
    }

    /// Get consent history
    public func getConsentHistory(limit: Int = 100) -> [ConsentRecord] {
        Array(consentHistory.suffix(limit))
    }

    // MARK: - Private

    private func recordConsent(_ record: ConsentRecord) {
        consentHistory.append(record)
        if consentHistory.count > 10000 {
            consentHistory.removeFirst(consentHistory.count - 10000)
        }
    }

    private func loadConsentsFromStorage() {
        // Load from UserDefaults or persistent storage
        // Implementation would read from actual storage
    }

    private func saveConsents() {
        // Save to UserDefaults or persistent storage
        // Implementation would write to actual storage
    }
}

// MARK: - Automatable Suggestion Engine

/// Engine that generates and executes automatable suggestions
public actor AutomatableSuggestionEngine {
    // MARK: - Singleton

    public static let shared = AutomatableSuggestionEngine()

    // MARK: - Properties

    private var pendingSuggestions: [UUID: AutomatableSuggestion] = [:]
    private var executedSuggestions: [AutomatableSuggestion] = []
    // periphery:ignore - Reserved: suggestionPatterns property — reserved for future feature activation
    private var suggestionPatterns: [SuggestionPattern] = []
    private var actionRegistry: [UUID: SuggestionAction] = [:] // Store actions by ID for reverse lookups
    // periphery:ignore - Reserved: suggestionPatterns property reserved for future feature activation
    private var isRunning = false

    private let consentManager = UserConsentManager.shared
    private var actionExecutors: [SuggestionAction.ActionType: ActionExecutor] = [
        .createReminder: ReminderExecutor(),
        .createEvent: CalendarExecutor(),
        .sendMessage: MessageExecutor(),
        .moveFile: FileExecutor(),
        .changeSetting: SettingsExecutor(),
        .runShortcut: ShortcutExecutor(),
        .openURL: URLExecutor()
    ]

    // Callbacks
    private var onSuggestionGenerated: ((AutomatableSuggestion) -> Void)?
    private var onConfirmationNeeded: ((AutomatableSuggestion) async -> Bool)?
    private var onSuggestionExecuted: ((AutomatableSuggestion, AutomatableSuggestion.ExecutionResult) -> Void)?
    private var onExecutionFailed: ((AutomatableSuggestion, Error) -> Void)?

    // MARK: - Initialization

    private init() {
        // Executors are initialized in property declaration
    }

    // MARK: - Configuration

    public func configure(
        onSuggestionGenerated: @escaping @Sendable (AutomatableSuggestion) -> Void,
        onConfirmationNeeded: @escaping @Sendable (AutomatableSuggestion) async -> Bool,
        onSuggestionExecuted: @escaping @Sendable (AutomatableSuggestion, AutomatableSuggestion.ExecutionResult) -> Void,
        onExecutionFailed: @escaping @Sendable (AutomatableSuggestion, Error) -> Void
    ) {
        self.onSuggestionGenerated = onSuggestionGenerated
        self.onConfirmationNeeded = onConfirmationNeeded
        self.onSuggestionExecuted = onSuggestionExecuted
        self.onExecutionFailed = onExecutionFailed
    }

    /// Register custom action executor
    public func registerExecutor(_ executor: ActionExecutor, for actionType: SuggestionAction.ActionType) {
        actionExecutors[actionType] = executor
    }

    // MARK: - Lifecycle

    public func start() {
        isRunning = true
    }

    public func stop() {
        isRunning = false
    }

    // MARK: - Suggestion Generation

    /// Generate a suggestion from detected pattern/need
    public func generateSuggestion(
        title: String,
        description: String,
        category: SuggestionCategory,
        action: SuggestionAction,
        context: SuggestionContext,
        confidence: Double = 0.8,
        priority: Int = 5,
        benefit: AutomatableSuggestion.PotentialBenefit = AutomatableSuggestion.PotentialBenefit()
    ) async {
        let patternHash = generatePatternHash(category: category, action: action, context: context)
        let consentLevel = await consentManager.getConsentLevel(for: patternHash, category: category)

        let suggestion = AutomatableSuggestion(
            title: title,
            description: description,
            category: category,
            action: action,
            context: context,
            confidence: confidence,
            priority: priority,
            potentialBenefit: benefit,
            automationLevel: consentLevel
        )

        pendingSuggestions[suggestion.id] = suggestion
        onSuggestionGenerated?(suggestion)

        // Check if we should auto-execute
        let (shouldExecute, requiresConfirmation) = await consentManager.shouldExecute(
            suggestion: suggestion,
            pattern: patternHash
        )

        if shouldExecute {
            if requiresConfirmation {
                // Ask for confirmation
                if let confirm = onConfirmationNeeded, await confirm(suggestion) {
                    await executeSuggestion(suggestion.id)
                }
            } else if confidence >= 0.75 { // Only auto-execute with high confidence
                await executeSuggestion(suggestion.id)
            }
        }
    }

    // MARK: - Suggestion Execution

    /// Execute a suggestion
    public func executeSuggestion(_ id: UUID) async {
        guard var suggestion = pendingSuggestions[id] else { return }

        do {
            // Get appropriate executor
            guard let executor = actionExecutors[suggestion.action.type] else {
                throw SuggestionError.noExecutor(suggestion.action.type)
            }

            // Execute the action
            let result = try await executor.execute(suggestion.action)

            // Update suggestion
            suggestion.executedAt = Date()
            suggestion.executionResult = result
            pendingSuggestions.removeValue(forKey: id)
            executedSuggestions.append(suggestion)

            // Keep history manageable
            if executedSuggestions.count > 10000 {
                executedSuggestions.removeFirst(executedSuggestions.count - 10000)
            }

            onSuggestionExecuted?(suggestion, result)

            // Learn from execution
            await learnFromExecution(suggestion, result: result)

        } catch {
            let result = AutomatableSuggestion.ExecutionResult(
                success: false,
                message: error.localizedDescription
            )
            suggestion.executionResult = result
            onExecutionFailed?(suggestion, error)
        }
    }

    /// Dismiss a suggestion without executing
    public func dismissSuggestion(_ id: UUID, reason: String? = nil) async {
        guard var suggestion = pendingSuggestions[id] else { return }

        suggestion.userFeedback = AutomatableSuggestion.UserFeedback(
            wasHelpful: false,
            shouldRepeat: reason == nil, // If no reason, might just be wrong timing
            comment: reason
        )

        pendingSuggestions.removeValue(forKey: id)
        executedSuggestions.append(suggestion)

        // Learn from dismissal
        await learnFromDismissal(suggestion)
    }

    /// Provide feedback on an executed suggestion
    public func provideFeedback(_ id: UUID, feedback: AutomatableSuggestion.UserFeedback) async {
        // Find in executed suggestions
        if let index = executedSuggestions.firstIndex(where: { $0.id == id }) {
            executedSuggestions[index].userFeedback = feedback

            // Adjust automation level if requested
            if let newLevel = feedback.adjustAutomationLevel {
                let pattern = generatePatternHash(
                    category: executedSuggestions[index].category,
                    action: executedSuggestions[index].action,
                    context: executedSuggestions[index].context
                )

                await consentManager.setSpecificConsent(
                    newLevel,
                    for: pattern,
                    category: executedSuggestions[index].category,
                    reason: "User feedback adjustment"
                )
            }

            // Learn from feedback
            await learnFromFeedback(executedSuggestions[index], feedback: feedback)
        }
    }

    /// Undo a reversible action
    public func undoSuggestion(_ id: UUID) async throws {
        guard let suggestion = executedSuggestions.first(where: { $0.id == id }),
              suggestion.action.reversible,
              let reverseActionId = suggestion.action.reverseActionId,
              let reverseAction = actionRegistry[reverseActionId] else {
            throw SuggestionError.cannotUndo
        }

        guard let executor = actionExecutors[reverseAction.type] else {
            throw SuggestionError.noExecutor(reverseAction.type)
        }

        _ = try await executor.execute(reverseAction)
    }

    /// Register an action in the registry (for reverse action lookups)
    public func registerAction(_ action: SuggestionAction) {
        actionRegistry[action.id] = action
    }

    // MARK: - Query

    /// Get pending suggestions
    public func getPendingSuggestions() -> [AutomatableSuggestion] {
        Array(pendingSuggestions.values).sorted { $0.priority > $1.priority }
    }

    /// Get suggestion history
    public func getSuggestionHistory(limit: Int = 100) -> [AutomatableSuggestion] {
        Array(executedSuggestions.suffix(limit))
    }

    /// Get suggestions by category
    public func getSuggestions(category: SuggestionCategory) -> [AutomatableSuggestion] {
        executedSuggestions.filter { $0.category == category }
    }

    /// Get automation statistics
    public func getAutomationStats() -> AutomationStats {
        let total = executedSuggestions.count
        let automated = executedSuggestions.filter { $0.currentAutomationLevel >= .preApproved }.count
        let successful = executedSuggestions.filter { $0.executionResult?.success == true }.count
        let helpful = executedSuggestions.filter { $0.userFeedback?.wasHelpful == true }.count
        let feedbackCount = executedSuggestions.filter { $0.userFeedback != nil }.count

        let timeSaved = executedSuggestions
            .compactMap { $0.potentialBenefit.timeSaved }
            .reduce(0, +)

        return AutomationStats(
            totalSuggestions: total,
            automatedCount: automated,
            successRate: total > 0 ? Double(successful) / Double(total) : 0,
            helpfulRate: feedbackCount > 0 ? Double(helpful) / Double(feedbackCount) : 0,
            totalTimeSaved: timeSaved,
            categoryBreakdown: Dictionary(grouping: executedSuggestions) { $0.category }
                .mapValues { $0.count }
        )
    }

    // MARK: - Private Methods

    private func generatePatternHash(
        category: SuggestionCategory,
        action: SuggestionAction,
        context: SuggestionContext
    ) -> String {
        // Generate a hash that identifies similar suggestions
        "\(category.rawValue):\(action.type.rawValue):\(context.trigger.rawValue)"
    }

    private func learnFromExecution(_ suggestion: AutomatableSuggestion, result: AutomatableSuggestion.ExecutionResult) async {
        // Track successful patterns for improving future suggestions
        if result.success {
            // Increase confidence for similar future suggestions
            let pattern = generatePatternHash(
                category: suggestion.category,
                action: suggestion.action,
                context: suggestion.context
            )

            // Could update a pattern confidence score here
            _ = pattern
        }
    }

    // periphery:ignore - Reserved: suggestion parameter — kept for API compatibility
    private func learnFromDismissal(_ suggestion: AutomatableSuggestion) async {
        // periphery:ignore - Reserved: suggestion parameter kept for API compatibility
        // Learn what types of suggestions users don't want
        // Could reduce frequency of similar suggestions
    }

    // periphery:ignore - Reserved: suggestion parameter kept for API compatibility
    private func learnFromFeedback(_ suggestion: AutomatableSuggestion, feedback: AutomatableSuggestion.UserFeedback) async {
        // Adjust future suggestion generation based on feedback
        if !feedback.wasHelpful && !feedback.shouldRepeat {
            // Blacklist this pattern
        }
    }
}
