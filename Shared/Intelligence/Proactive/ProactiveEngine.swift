// ProactiveEngine.swift
// Thea V2
//
// Proactive and anticipatory AI behavior engine
// Predicts user needs, offers suggestions, monitors context for triggers

import Foundation
import OSLog

// MARK: - Proactive Suggestion

/// A proactive suggestion offered to the user
public struct AnticipatoryEngineSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let action: ProactiveEngineAction
    public let confidence: Float  // 0.0 - 1.0
    public let priority: SuggestionPriorityLevel
    public let context: AnticipatoryEngineSuggestionContext
    public let expiresAt: Date?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        type: SuggestionType,
        title: String,
        description: String,
        action: ProactiveEngineAction,
        confidence: Float,
        priority: SuggestionPriorityLevel = .normal,
        context: AnticipatoryEngineSuggestionContext = AnticipatoryEngineSuggestionContext(),
        expiresAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.action = action
        self.confidence = confidence
        self.priority = priority
        self.context = context
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

public enum SuggestionType: String, Codable, Sendable {
    case taskCompletion       // Complete an unfinished task
    case relatedAction        // Related to current work
    case patternBased         // Based on observed patterns
    case timeBased           // Time-triggered (e.g., morning standup)
    case errorResolution     // Resolve detected errors
    case optimization        // Performance/quality improvement
    case reminder            // Reminder for pending items
    case learningOpportunity // Teach something new
    case automation          // Automate repetitive task
}

public enum SuggestionPriorityLevel: Int, Comparable, Sendable {
    case low = 0
    case normal = 50
    case high = 75
    case urgent = 100

    public static func < (lhs: SuggestionPriorityLevel, rhs: SuggestionPriorityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Action to take when suggestion is accepted
public enum ProactiveEngineAction: Sendable {
    case executeTask(taskDescription: String)
    case openFile(path: String)
    case runCommand(command: String)
    case showInformation(content: String)
    case askQuestion(question: String)
    case startWorkflow(workflowId: String)
    case triggerSkill(skillId: String)
    case navigateTo(destination: String)
    case custom(actionId: String, parameters: [String: String])
}

/// Context for why suggestion was made
public struct AnticipatoryEngineSuggestionContext: Sendable {
    public let triggerReason: String
    public let relatedFiles: [String]
    public let relatedTasks: [String]
    public let confidenceFactors: [String: Float]

    public init(
        triggerReason: String = "",
        relatedFiles: [String] = [],
        relatedTasks: [String] = [],
        confidenceFactors: [String: Float] = [:]
    ) {
        self.triggerReason = triggerReason
        self.relatedFiles = relatedFiles
        self.relatedTasks = relatedTasks
        self.confidenceFactors = confidenceFactors
    }
}

// MARK: - Intent Prediction

/// Predicted user intent
public struct PredictedIntent: Sendable {
    public let intent: String
    public let confidence: Float
    public let suggestedActions: [ProactiveEngineAction]
    public let reasoning: String

    public init(intent: String, confidence: Float, suggestedActions: [ProactiveEngineAction] = [], reasoning: String = "") {
        self.intent = intent
        self.confidence = confidence
        self.suggestedActions = suggestedActions
        self.reasoning = reasoning
    }
}

// MARK: - Contextual Trigger

/// A trigger that monitors for specific conditions
public struct ContextualTrigger: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let condition: AnticipatoryTriggerCondition
    public let action: ProactiveEngineAction
    public let isEnabled: Bool
    public let cooldownSeconds: Int  // Minimum seconds between triggers
    public var lastTriggeredAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        condition: AnticipatoryTriggerCondition,
        action: ProactiveEngineAction,
        isEnabled: Bool = true,
        cooldownSeconds: Int = 300,
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.condition = condition
        self.action = action
        self.isEnabled = isEnabled
        self.cooldownSeconds = cooldownSeconds
        self.lastTriggeredAt = lastTriggeredAt
    }
}

public enum AnticipatoryTriggerCondition: Sendable {
    case fileChanged(pattern: String)
    case timeOfDay(hour: Int, minute: Int)
    case errorDetected(pattern: String)
    case taskCompleted(taskType: String)
    case idleFor(seconds: Int)
    case repeatPattern(count: Int, action: String)
    case calendarEvent(keyword: String)
    case buildFailed
    case testFailed
    case highCPUUsage(threshold: Double)
    case custom(evaluator: @Sendable () -> Bool)
}

// MARK: - User Pattern

/// Observed user behavior pattern
public struct UserPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public let patternType: PatternType
    public let description: String
    public let frequency: Int  // How many times observed
    public let confidence: Float
    public let timeOfDay: Int?  // Hour (0-23) if time-based
    public let dayOfWeek: Int?  // 1-7 if day-based
    public let contextTags: [String]
    public let lastObserved: Date
    public let firstObserved: Date

    public init(
        id: UUID = UUID(),
        patternType: PatternType,
        description: String,
        frequency: Int = 1,
        confidence: Float = 0.5,
        timeOfDay: Int? = nil,
        dayOfWeek: Int? = nil,
        contextTags: [String] = [],
        lastObserved: Date = Date(),
        firstObserved: Date = Date()
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.frequency = frequency
        self.confidence = confidence
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.contextTags = contextTags
        self.lastObserved = lastObserved
        self.firstObserved = firstObserved
    }
}

public enum PatternType: String, Codable, Sendable {
    case workflow          // Sequence of actions
    case timeBasedAction   // Action at specific time
    case fileAccess        // Files commonly accessed together
    case taskSequence      // Tasks done in sequence
    case errorResolution   // How errors are typically resolved
    case searchBehavior    // What/how user searches
    case preferredTools    // Tool preferences
    case communicationStyle // How user phrases requests
}
