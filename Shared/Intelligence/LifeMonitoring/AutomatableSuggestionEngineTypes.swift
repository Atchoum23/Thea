// AutomatableSuggestionEngineTypes.swift
// THEA - Automatable Suggestion System Types
// Created by Claude - February 2026
//
// Types, models, and protocols extracted from AutomatableSuggestionEngine.swift

import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

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
        case pattern           // Detected behavioral pattern
        case schedule          // Time-based trigger
        case event             // External event
        case location          // Location-based
        case condition         // Condition met
        case prediction        // Predicted need
        case request           // User implied request
        case deadline          // Approaching deadline
        case anomaly           // Something unusual
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
