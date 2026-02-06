// AutomatableSuggestionEngine.swift
// THEA - Automatable Suggestion System
// Created by Claude - February 2026
//
// ALL suggestions are automatable with proper user consent
// Suggestions evolve from: Suggestion -> Pre-approved -> Fully Automated

import Foundation

// MARK: - Automation Levels

/// Level of automation for a suggestion
public enum AutomationLevel: Int, Sendable, CaseIterable, Comparable {
    case manualOnly = 0        // User must manually perform
    case suggestOnly = 1       // Show suggestion, user decides
    case confirmEach = 2       // Ask for confirmation each time
    case preApproved = 3       // Pre-approved for similar situations
    case fullyAutomated = 4    // Execute automatically, notify after

    public static func < (lhs: AutomationLevel, rhs: AutomationLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .manualOnly: return "Manual Only"
        case .suggestOnly: return "Suggest Only"
        case .confirmEach: return "Confirm Each Time"
        case .preApproved: return "Pre-Approved"
        case .fullyAutomated: return "Fully Automated"
        }
    }

    public var emoji: String {
        switch self {
        case .manualOnly: return "🔒"
        case .suggestOnly: return "💡"
        case .confirmEach: return "✋"
        case .preApproved: return "✅"
        case .fullyAutomated: return "🤖"
        }
    }
}

// MARK: - Suggestion Categories

/// Category of suggestion for consent grouping
public enum SuggestionCategory: String, Sendable, CaseIterable {
    // Communication
    case sendMessage = "send_message"
    case sendEmail = "send_email"
    case scheduleCall = "schedule_call"
    case createReminder = "create_reminder"

    // Calendar
    case scheduleEvent = "schedule_event"
    case moveEvent = "move_event"
    case cancelEvent = "cancel_event"
    case setReminder = "set_reminder"

    // Tasks
    case createTask = "create_task"
    case completeTask = "complete_task"
    case delegateTask = "delegate_task"
    case updateTaskPriority = "update_priority"

    // Files
    case organizeFile = "organize_file"
    case archiveFile = "archive_file"
    case backupFile = "backup_file"
    case shareFile = "share_file"

    // Financial
    case payBill = "pay_bill"
    case transferMoney = "transfer_money"
    case categorizeTransaction = "categorize_transaction"
    case setBudgetAlert = "set_budget_alert"

    // Health
    case logMedication = "log_medication"
    case scheduleAppointment = "schedule_appointment"
    case logHealthData = "log_health_data"
    case setHealthReminder = "set_health_reminder"

    // System
    case adjustSettings = "adjust_settings"
    case cleanupStorage = "cleanup_storage"
    case updateApp = "update_app"
    case restartService = "restart_service"

    // Smart Home
    case controlDevice = "control_device"
    case setRoutine = "set_routine"
    case adjustTemperature = "adjust_temperature"
    case setLighting = "set_lighting"

    public var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public var defaultMaxAutomation: AutomationLevel {
        switch self {
        // High-risk: require confirmation
        case .sendMessage, .sendEmail, .payBill, .transferMoney, .shareFile:
            return .confirmEach
        // Medium-risk: can be pre-approved
        case .scheduleEvent, .moveEvent, .cancelEvent, .createTask, .completeTask:
            return .preApproved
        // Low-risk: can be fully automated
        case .organizeFile, .categorizeTransaction, .logHealthData, .adjustSettings:
            return .fullyAutomated
        default:
            return .preApproved
        }
    }
}

// MARK: - Automatable Suggestion

/// A suggestion that can be automated at any level
public struct AutomatableSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let category: SuggestionCategory
    public let action: SuggestionAction
    public let context: SuggestionContext
    public let confidence: Double
    public let priority: Int
    public let potentialBenefit: PotentialBenefit
    public let createdAt: Date
    public var currentAutomationLevel: AutomationLevel
    public var executedAt: Date?
    public var executionResult: ExecutionResult?
    public var userFeedback: UserFeedback?

    public struct PotentialBenefit: Sendable {
        public let timeSaved: TimeInterval?
        public let moneySaved: Double?
        public let stressReduced: String?
        public let description: String

        public init(
            timeSaved: TimeInterval? = nil,
            moneySaved: Double? = nil,
            stressReduced: String? = nil,
            description: String = ""
        ) {
            self.timeSaved = timeSaved
            self.moneySaved = moneySaved
            self.stressReduced = stressReduced
            self.description = description
        }
    }

    public struct ExecutionResult: Sendable {
        public let success: Bool
        public let timestamp: Date
        public let message: String?
        public let details: [String: String]

        public init(success: Bool, message: String? = nil, details: [String: String] = [:]) {
            self.success = success
            self.timestamp = Date()
            self.message = message
            self.details = details
        }
    }

    public struct UserFeedback: Sendable {
        public let wasHelpful: Bool
        public let shouldRepeat: Bool
        public let adjustAutomationLevel: AutomationLevel?
        public let comment: String?
        public let timestamp: Date

        public init(
            wasHelpful: Bool,
            shouldRepeat: Bool = true,
            adjustAutomationLevel: AutomationLevel? = nil,
            comment: String? = nil
        ) {
            self.wasHelpful = wasHelpful
            self.shouldRepeat = shouldRepeat
            self.adjustAutomationLevel = adjustAutomationLevel
            self.comment = comment
            self.timestamp = Date()
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: SuggestionCategory,
        action: SuggestionAction,
        context: SuggestionContext,
        confidence: Double = 0.8,
        priority: Int = 5,
        potentialBenefit: PotentialBenefit = PotentialBenefit(),
        automationLevel: AutomationLevel = .suggestOnly
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.action = action
        self.context = context
        self.confidence = confidence
        self.priority = priority
        self.potentialBenefit = potentialBenefit
        self.createdAt = Date()
        self.currentAutomationLevel = automationLevel
        self.executedAt = nil
        self.executionResult = nil
        self.userFeedback = nil
    }
}

// MARK: - Suggestion Action

/// The executable action for a suggestion
public struct SuggestionAction: Identifiable, Sendable {
    public let id: UUID
    public let type: ActionType
    public let parameters: [String: AnySendable]
    public let reversible: Bool
    public let reverseActionId: UUID? // Reference to reverse action to avoid infinite size

    public enum ActionType: String, Sendable {
        // Communication
        case sendMessage = "send_message"
        case sendEmail = "send_email"
        case makeCall = "make_call"

        // Calendar
        case createEvent = "create_event"
        case updateEvent = "update_event"
        case deleteEvent = "delete_event"

        // Reminders
        case createReminder = "create_reminder"
        case completeReminder = "complete_reminder"

        // Files
        case moveFile = "move_file"
        case renameFile = "rename_file"
        case deleteFile = "delete_file"
        case createFolder = "create_folder"

        // Settings
        case changeSetting = "change_setting"
        case toggleFeature = "toggle_feature"

        // Shortcuts
        case runShortcut = "run_shortcut"
        case runScript = "run_script"

        // External
        case openURL = "open_url"
        case apiCall = "api_call"

        // Composite
        case sequence = "sequence" // Multiple actions in order
        case conditional = "conditional" // If-then-else
    }

    public init(
        id: UUID = UUID(),
        type: ActionType,
        parameters: [String: AnySendable] = [:],
        reversible: Bool = false,
        reverseActionId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.reversible = reversible
        self.reverseActionId = reverseActionId
    }
}

/// Type-erased Sendable wrapper
public struct AnySendable: @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public func typed<T>() -> T? {
        value as? T
    }
}

// MARK: - Suggestion Context

/// Context that triggered the suggestion
public struct SuggestionContext: Sendable {
    public let trigger: Trigger
    public let relatedData: [String: AnySendable]
    public let timestamp: Date
    public let source: String

    public enum Trigger: String, Sendable {
        case pattern = "pattern"           // Detected behavioral pattern
        case schedule = "schedule"         // Time-based trigger
        case event = "event"               // External event
        case location = "location"         // Location-based
        case condition = "condition"       // Condition met
        case prediction = "prediction"     // Predicted need
        case request = "request"           // User implied request
        case deadline = "deadline"         // Approaching deadline
        case anomaly = "anomaly"           // Something unusual
    }

    public init(
        trigger: Trigger,
        relatedData: [String: AnySendable] = [:],
        source: String = ""
    ) {
        self.trigger = trigger
        self.relatedData = relatedData
        self.timestamp = Date()
        self.source = source
    }
}

// MARK: - Suggestion Pattern

/// A learned pattern that can trigger suggestions
public struct SuggestionPattern: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let category: SuggestionCategory
    public let triggers: [SuggestionContext.Trigger]
    public let conditions: [String: String]
    public let confidence: Double
    public let occurrenceCount: Int
    public let lastOccurrence: Date
    public let suggestedAction: SuggestionAction.ActionType

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: SuggestionCategory,
        triggers: [SuggestionContext.Trigger],
        conditions: [String: String] = [:],
        confidence: Double,
        occurrenceCount: Int = 1,
        lastOccurrence: Date = Date(),
        suggestedAction: SuggestionAction.ActionType
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.triggers = triggers
        self.conditions = conditions
        self.confidence = confidence
        self.occurrenceCount = occurrenceCount
        self.lastOccurrence = lastOccurrence
        self.suggestedAction = suggestedAction
    }
}

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
    private var suggestionPatterns: [SuggestionPattern] = []
    private var actionRegistry: [UUID: SuggestionAction] = [:] // Store actions by ID for reverse lookups
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

    private func learnFromDismissal(_ suggestion: AutomatableSuggestion) async {
        // Learn what types of suggestions users don't want
        // Could reduce frequency of similar suggestions
    }

    private func learnFromFeedback(_ suggestion: AutomatableSuggestion, feedback: AutomatableSuggestion.UserFeedback) async {
        // Adjust future suggestion generation based on feedback
        if !feedback.wasHelpful && !feedback.shouldRepeat {
            // Blacklist this pattern
        }
    }
}

// MARK: - Automation Stats

public struct AutomationStats: Sendable {
    public let totalSuggestions: Int
    public let automatedCount: Int
    public let successRate: Double
    public let helpfulRate: Double
    public let totalTimeSaved: TimeInterval
    public let categoryBreakdown: [SuggestionCategory: Int]

    public var automationRate: Double {
        totalSuggestions > 0 ? Double(automatedCount) / Double(totalSuggestions) : 0
    }

    public var formattedTimeSaved: String {
        let hours = Int(totalTimeSaved / 3600)
        let minutes = Int((totalTimeSaved.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Action Executors

/// Protocol for executing suggestion actions
public protocol ActionExecutor: Sendable {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult
    func canExecute(_ action: SuggestionAction) -> Bool
}

/// Reminder action executor
struct ReminderExecutor: ActionExecutor {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult {
        guard let title = action.parameters["title"]?.typed() as String?,
              let dueDate = action.parameters["dueDate"]?.typed() as Date? else {
            throw SuggestionError.missingParameters(["title", "dueDate"])
        }

        // Would integrate with RemindersIntegration
        // let reminderId = try await RemindersIntegration.shared.createReminder(...)

        return AutomatableSuggestion.ExecutionResult(
            success: true,
            message: "Created reminder: \(title)",
            details: ["dueDate": dueDate.description]
        )
    }

    func canExecute(_ action: SuggestionAction) -> Bool {
        action.type == .createReminder
    }
}

/// Calendar action executor
struct CalendarExecutor: ActionExecutor {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult {
        guard let title = action.parameters["title"]?.typed() as String?,
              let startDate = action.parameters["startDate"]?.typed() as Date? else {
            throw SuggestionError.missingParameters(["title", "startDate"])
        }

        // Would integrate with CalendarIntegration
        // let eventId = try await CalendarIntegration.shared.createEvent(...)

        return AutomatableSuggestion.ExecutionResult(
            success: true,
            message: "Created event: \(title)",
            details: ["startDate": startDate.description]
        )
    }

    func canExecute(_ action: SuggestionAction) -> Bool {
        [.createEvent, .updateEvent, .deleteEvent].contains(action.type)
    }
}

/// Message action executor
struct MessageExecutor: ActionExecutor {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult {
        guard let recipient = action.parameters["recipient"]?.typed() as String?,
              let message = action.parameters["message"]?.typed() as String? else {
            throw SuggestionError.missingParameters(["recipient", "message"])
        }

        // Would integrate with MessagesIntegration
        // try await MessagesIntegration.shared.sendMessage(...)

        return AutomatableSuggestion.ExecutionResult(
            success: true,
            message: "Sent message to \(recipient)",
            details: ["messageLength": "\(message.count)"]
        )
    }

    func canExecute(_ action: SuggestionAction) -> Bool {
        action.type == .sendMessage
    }
}

/// File action executor
struct FileExecutor: ActionExecutor {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult {
        guard let sourcePath = action.parameters["source"]?.typed() as String?,
              let destPath = action.parameters["destination"]?.typed() as String? else {
            throw SuggestionError.missingParameters(["source", "destination"])
        }

        // Would perform actual file operation
        let fm = FileManager.default
        if fm.fileExists(atPath: sourcePath) {
            try fm.moveItem(atPath: sourcePath, toPath: destPath)
        }

        return AutomatableSuggestion.ExecutionResult(
            success: true,
            message: "Moved file",
            details: ["from": sourcePath, "to": destPath]
        )
    }

    func canExecute(_ action: SuggestionAction) -> Bool {
        [.moveFile, .renameFile, .deleteFile, .createFolder].contains(action.type)
    }
}

/// Settings action executor
struct SettingsExecutor: ActionExecutor {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult {
        guard let settingKey = action.parameters["key"]?.typed() as String? else {
            throw SuggestionError.missingParameters(["key"])
        }

        let newValue = action.parameters["value"]

        // Would integrate with actual settings
        UserDefaults.standard.set(newValue?.value, forKey: settingKey)

        return AutomatableSuggestion.ExecutionResult(
            success: true,
            message: "Updated setting: \(settingKey)"
        )
    }

    func canExecute(_ action: SuggestionAction) -> Bool {
        [.changeSetting, .toggleFeature].contains(action.type)
    }
}

/// Shortcut action executor
struct ShortcutExecutor: ActionExecutor {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult {
        guard let shortcutName = action.parameters["name"]?.typed() as String? else {
            throw SuggestionError.missingParameters(["name"])
        }

        // Would run Shortcuts app shortcut
        // This requires proper integration with Shortcuts framework

        return AutomatableSuggestion.ExecutionResult(
            success: true,
            message: "Ran shortcut: \(shortcutName)"
        )
    }

    func canExecute(_ action: SuggestionAction) -> Bool {
        [.runShortcut, .runScript].contains(action.type)
    }
}

/// URL action executor
struct URLExecutor: ActionExecutor {
    func execute(_ action: SuggestionAction) async throws -> AutomatableSuggestion.ExecutionResult {
        guard let urlString = action.parameters["url"]?.typed() as String?,
              let url = URL(string: urlString) else {
            throw SuggestionError.missingParameters(["url"])
        }

        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        await MainActor.run {
            UIApplication.shared.open(url)
        }
        #endif

        return AutomatableSuggestion.ExecutionResult(
            success: true,
            message: "Opened URL",
            details: ["url": urlString]
        )
    }

    func canExecute(_ action: SuggestionAction) -> Bool {
        action.type == .openURL
    }
}

// MARK: - Errors

public enum SuggestionError: Error, LocalizedError {
    case noExecutor(SuggestionAction.ActionType)
    case missingParameters([String])
    case cannotUndo
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noExecutor(let type):
            return "No executor registered for action type: \(type.rawValue)"
        case .missingParameters(let params):
            return "Missing required parameters: \(params.joined(separator: ", "))"
        case .cannotUndo:
            return "This action cannot be undone"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
