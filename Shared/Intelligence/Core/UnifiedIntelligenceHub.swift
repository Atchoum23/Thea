//
//  UnifiedIntelligenceHub.swift
//  Thea
//
//  Central coordinator for all intelligence subsystems.
//  Enables meta-learning, cross-system pattern detection, and unified orchestration.
//

import Foundation
import Observation
import os.log

// periphery:ignore - Reserved: hubLogger global var reserved for future feature activation
private let hubLogger = Logger(subsystem: "ai.thea.app", category: "UnifiedIntelligenceHub")

// MARK: - Intelligence Event Types

/// Events emitted by intelligence subsystems and processed by the hub for cross-system coordination.
public enum IntelligenceEvent: Sendable {
    case queryReceived(query: String, conversationId: UUID)
    case responseGenerated(quality: Double, latency: TimeInterval)
    case taskCompleted(taskType: String, success: Bool, duration: TimeInterval)
    case patternDetected(pattern: IntelligencePattern)
    case suggestionPresented(suggestion: UnifiedSuggestion)
    case suggestionAccepted(suggestionId: UUID)
    case suggestionDismissed(suggestionId: UUID)
    case blockerDetected(blocker: DetectedBlocker)
    case goalInferred(goal: InferredGoal)
    case contextPreloaded(resources: [PreloadedResource])
    case userModelUpdated(aspect: UserModelAspect)
}

// MARK: - Intelligence Pattern (renamed to avoid conflict with PatternDetector.IntelligencePattern)

/// A recurring behavioral or workflow pattern detected across user interactions.
public struct IntelligencePattern: Identifiable, Sendable {
    public let id: UUID
    public let type: PatternType
    public let description: String
    public let confidence: Double
    public let occurrences: Int
    public let firstSeen: Date
    public let lastSeen: Date
    public let metadata: [String: String]

    /// The category of detected pattern.
    public enum PatternType: String, Sendable {
        case workflow          // Sequence of actions
        case temporal          // Time-based habit
        case contextSwitch     // App/task switching
        case queryStyle        // How user asks questions
        case errorRecovery     // How user handles errors
        case learningProgress  // Skill development
        case productivity      // Work patterns
        case preference        // Tool/model preferences
    }

    public init(
        id: UUID = UUID(),
        type: PatternType,
        description: String,
        confidence: Double,
        occurrences: Int = 1,
        firstSeen: Date = Date(),
        lastSeen: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.confidence = confidence
        self.occurrences = occurrences
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.metadata = metadata
    }
}

// MARK: - Unified Suggestion

/// A proactive suggestion surfaced by an intelligence subsystem for the user.
public struct UnifiedSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let source: SuggestionSource
    public let title: String
    public let description: String
    public let action: SuggestionAction
    public let relevanceScore: Double
    public let confidenceScore: Double
    public let timeSensitivity: TimeSensitivity
    public let cognitiveLoad: CognitiveLoad
    public let expiresAt: Date?
    public let metadata: [String: String]

    /// The intelligence subsystem that generated this suggestion.
    public enum SuggestionSource: String, Sendable {
        case proactiveEngine
        case blockerAnticipator
        case goalProgress
        case workflowAutomation
        case memoryInsight
        case contextPrediction
        case causalAnalysis
    }

    /// The action to perform when the suggestion is accepted.
    public enum SuggestionAction: Sendable {
        case showMessage(String)
        case executeWorkflow(workflowId: String)
        case loadContext(resources: [String])
        case suggestBreak(duration: TimeInterval)
        case offerHelp(topic: String)
        case switchModel(modelId: String)
        case preloadResources([String])
    }

    /// How urgently the suggestion should be shown.
    public enum TimeSensitivity: String, Sendable {
        case immediate    // Show now
        case soon         // Within 5 minutes
        case whenIdle     // When user pauses
        case scheduled    // At specific time
        case lowPriority  // Whenever convenient
    }

    /// Estimated cognitive effort required to act on this suggestion.
    public enum CognitiveLoad: String, Sendable {
        case minimal      // Quick glance
        case low          // Simple action
        case moderate     // Some thinking
        case high         // Focused attention
    }

    public init(
        id: UUID = UUID(),
        source: SuggestionSource,
        title: String,
        description: String,
        action: SuggestionAction,
        relevanceScore: Double,
        confidenceScore: Double,
        timeSensitivity: TimeSensitivity = .whenIdle,
        cognitiveLoad: CognitiveLoad = .low,
        expiresAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.description = description
        self.action = action
        self.relevanceScore = relevanceScore
        self.confidenceScore = confidenceScore
        self.timeSensitivity = timeSensitivity
        self.cognitiveLoad = cognitiveLoad
        self.expiresAt = expiresAt
        self.metadata = metadata
    }

    /// Combined score for ranking suggestions (weighted relevance, confidence, urgency, and cognitive load).
    public var combinedScore: Double {
        let weights = (relevance: 0.4, confidence: 0.3, timeFactor: 0.2, loadFactor: 0.1)

        let timeFactor: Double = switch timeSensitivity {
        case .immediate: 1.0
        case .soon: 0.8
        case .whenIdle: 0.5
        case .scheduled: 0.6
        case .lowPriority: 0.3
        }

        let loadFactor: Double = switch cognitiveLoad {
        case .minimal: 1.0
        case .low: 0.9
        case .moderate: 0.7
        case .high: 0.5
        }

        return (relevanceScore * weights.relevance) +
               (confidenceScore * weights.confidence) +
               (timeFactor * weights.timeFactor) +
               (loadFactor * weights.loadFactor)
    }
}

// MARK: - Detected Blocker

/// A blocker that is preventing the user from making progress on their current task.
public struct DetectedBlocker: Identifiable, Sendable {
    public let id: UUID
    public let type: BlockerType
    public let description: String
    public let severity: Severity
    public let detectedAt: Date
    public let context: BlockerContext
    public let suggestedResolutions: [String]

    /// The category of detected blocker.
    public enum BlockerType: String, Sendable {
        case stuckOnTask       // Task taking too long
        case repeatedQuery     // Rephrasing same question
        case errorLoop         // Same error repeatedly
        case resourceExhausted // Memory/token limits
        case dependencyWait    // Waiting on external
        case complexityOverload // Task too complex
        case toolFailure       // Tool not working
    }

    /// How severely the blocker is impeding progress.
    public enum Severity: String, Sendable {
        case low       // Mild slowdown
        case medium    // Noticeable issue
        case high      // Significant blocker
        case critical  // Complete stop
    }

    /// Contextual details captured at the moment the blocker was detected.
    public struct BlockerContext: Sendable {
        public let taskType: String?
        public let timeSpent: TimeInterval
        public let attemptCount: Int
        public let relatedQueries: [String]
        public let errorMessages: [String]

        public init(
            taskType: String? = nil,
            timeSpent: TimeInterval = 0,
            attemptCount: Int = 1,
            relatedQueries: [String] = [],
            errorMessages: [String] = []
        ) {
            self.taskType = taskType
            self.timeSpent = timeSpent
            self.attemptCount = attemptCount
            self.relatedQueries = relatedQueries
            self.errorMessages = errorMessages
        }
    }

    public init(
        id: UUID = UUID(),
        type: BlockerType,
        description: String,
        severity: Severity,
        detectedAt: Date = Date(),
        context: BlockerContext = BlockerContext(),
        suggestedResolutions: [String] = []
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.severity = severity
        self.detectedAt = detectedAt
        self.context = context
        self.suggestedResolutions = suggestedResolutions
    }
}

// MARK: - Inferred Goal

/// A user goal inferred from conversation and task history, tracked with progress and confidence.
public struct InferredGoal: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let category: GoalCategory
    public let confidence: Double
    public let priority: GoalPriority
    public let deadline: Date?
    public let progress: Double
    public let relatedConversations: [UUID]
    public let relatedProjects: [String]
    public let subGoals: [InferredGoal]
    public let inferredAt: Date
    public let lastUpdated: Date

    /// The high-level category this goal belongs to.
    public enum GoalCategory: String, Sendable {
        case project       // Complete a project
        case learning      // Learn a skill
        case productivity  // Improve efficiency
        case problemSolving // Fix an issue
        case creation      // Build something new
        case maintenance   // Keep things running
        case exploration   // Research/discover
    }

    /// Priority level for goal completion.
    public enum GoalPriority: String, Sendable {
        case critical   // Must complete ASAP
        case high       // Important
        case medium     // Normal priority
        case low        // When possible
        case background // Ongoing
    }

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: GoalCategory,
        confidence: Double,
        priority: GoalPriority = .medium,
        deadline: Date? = nil,
        progress: Double = 0,
        relatedConversations: [UUID] = [],
        relatedProjects: [String] = [],
        subGoals: [InferredGoal] = [],
        inferredAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.confidence = confidence
        self.priority = priority
        self.deadline = deadline
        self.progress = progress
        self.relatedConversations = relatedConversations
        self.relatedProjects = relatedProjects
        self.subGoals = subGoals
        self.inferredAt = inferredAt
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Preloaded Resource

/// A resource preloaded into context ahead of predicted need, with an expiry window.
public struct PreloadedResource: Identifiable, Sendable {
    public let id: UUID
    public let type: ResourceType
    public let identifier: String
    public let relevanceScore: Double
    public let loadedAt: Date
    public let expiresAt: Date

    /// The kind of resource that was preloaded.
    public enum ResourceType: String, Sendable {
        case file
        case conversation
        case memory
        case documentation
        case codeSnippet
        case model
    }

    public init(
        id: UUID = UUID(),
        type: ResourceType,
        identifier: String,
        relevanceScore: Double,
        loadedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(300)
    ) {
        self.id = id
        self.type = type
        self.identifier = identifier
        self.relevanceScore = relevanceScore
        self.loadedAt = loadedAt
        self.expiresAt = expiresAt
    }
}

// MARK: - User Model Aspect

/// A dimension of the user model that can be updated as new behavioral signals are observed.
public enum UserModelAspect: String, Sendable {
    case communicationStyle
    case technicalLevel
    case preferredDepth
    case learningStyle
    case workHabits
    case toolPreferences
    case errorHandling
    case decisionMaking
}

// MARK: - Intelligence Subsystem Protocol

/// Protocol that all intelligence subsystems must implement to participate in the hub's event loop.
public protocol IntelligenceSubsystem: Sendable {
    var subsystemId: String { get }
    func processEvent(_ event: IntelligenceEvent) async
    func getInsights() async -> [IntelligencePattern]
    func getSuggestions(context: IntelligenceContext) async -> [UnifiedSuggestion]
}

// MARK: - Intelligence Context

/// The current user context snapshot passed to subsystems when requesting suggestions.
public struct IntelligenceContext: Sendable {
    public let currentQuery: String?
    public let conversationId: UUID?
    public let recentQueries: [String]
    public let currentTaskType: String?
    public let activeGoals: [InferredGoal]
    public let userModel: UserModelSnapshot
    public let timeOfDay: Date
    public let sessionDuration: TimeInterval

    /// A lightweight snapshot of the inferred user model dimensions.
    public struct UserModelSnapshot: Sendable {
        public let technicalLevel: Double
        public let preferredVerbosity: Double
        public let currentCognitiveLoad: Double
        public let recentProductivity: Double

        public init(
            technicalLevel: Double = 0.5,
            preferredVerbosity: Double = 0.5,
            currentCognitiveLoad: Double = 0.5,
            recentProductivity: Double = 0.5
        ) {
            self.technicalLevel = technicalLevel
            self.preferredVerbosity = preferredVerbosity
            self.currentCognitiveLoad = currentCognitiveLoad
            self.recentProductivity = recentProductivity
        }
    }

    public init(
        currentQuery: String? = nil,
        conversationId: UUID? = nil,
        recentQueries: [String] = [],
        currentTaskType: String? = nil,
        activeGoals: [InferredGoal] = [],
        userModel: UserModelSnapshot = UserModelSnapshot(),
        timeOfDay: Date = Date(),
        sessionDuration: TimeInterval = 0
    ) {
        self.currentQuery = currentQuery
        self.conversationId = conversationId
        self.recentQueries = recentQueries
        self.currentTaskType = currentTaskType
        self.activeGoals = activeGoals
        self.userModel = userModel
        self.timeOfDay = timeOfDay
        self.sessionDuration = sessionDuration
    }
}
