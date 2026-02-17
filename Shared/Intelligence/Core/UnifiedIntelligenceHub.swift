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

private let hubLogger = Logger(subsystem: "ai.thea.app", category: "UnifiedIntelligenceHub")

// MARK: - Intelligence Event Types

/// Events emitted by intelligence subsystems for cross-system coordination.
public enum IntelligenceEvent: Sendable {
    /// A user query was received in a conversation.
    case queryReceived(query: String, conversationId: UUID)
    /// An AI response was generated with quality and latency metrics.
    case responseGenerated(quality: Double, latency: TimeInterval)
    /// A task completed with success/failure status and duration.
    case taskCompleted(taskType: String, success: Bool, duration: TimeInterval)
    /// A behavioral or workflow pattern was detected.
    case patternDetected(pattern: IntelligencePattern)
    /// A proactive suggestion was presented to the user.
    case suggestionPresented(suggestion: UnifiedSuggestion)
    /// The user accepted a suggestion.
    case suggestionAccepted(suggestionId: UUID)
    /// The user dismissed a suggestion.
    case suggestionDismissed(suggestionId: UUID)
    /// A blocker preventing user progress was detected.
    case blockerDetected(blocker: DetectedBlocker)
    /// A user goal was inferred from behavior.
    case goalInferred(goal: InferredGoal)
    /// Resources were preloaded in anticipation of user needs.
    case contextPreloaded(resources: [PreloadedResource])
    /// The user behavioral model was updated.
    case userModelUpdated(aspect: UserModelAspect)
}

// MARK: - Intelligence Pattern (renamed to avoid conflict with PatternDetector.IntelligencePattern)

/// A detected behavioral or workflow pattern with confidence and metadata.
public struct IntelligencePattern: Identifiable, Sendable {
    /// Unique pattern identifier.
    public let id: UUID
    /// Classification of this pattern.
    public let type: PatternType
    /// Human-readable description of the detected pattern.
    public let description: String
    /// Confidence in the pattern's validity (0.0 - 1.0).
    public let confidence: Double
    /// Number of times this pattern has been observed.
    public let occurrences: Int
    /// When this pattern was first detected.
    public let firstSeen: Date
    /// When this pattern was most recently observed.
    public let lastSeen: Date
    /// Additional metadata as key-value pairs.
    public let metadata: [String: String]

    /// Classification of detectable intelligence patterns.
    public enum PatternType: String, Sendable {
        /// Recurring sequence of actions (e.g. always runs tests after editing).
        case workflow
        /// Time-based habit (e.g. codes in the morning, reviews in the afternoon).
        case temporal
        /// App or task switching pattern.
        case contextSwitch
        /// How the user formulates queries.
        case queryStyle
        /// How the user recovers from errors.
        case errorRecovery
        /// Skill development trajectory.
        case learningProgress
        /// Work output patterns (focus, breaks, productivity).
        case productivity
        /// Preferred tools, models, or approaches.
        case preference
    }

    /// Creates an intelligence pattern.
    /// - Parameters:
    ///   - id: Pattern identifier.
    ///   - type: Pattern classification.
    ///   - description: Human-readable description.
    ///   - confidence: Confidence score (0.0-1.0).
    ///   - occurrences: Observation count.
    ///   - firstSeen: First detection time.
    ///   - lastSeen: Most recent observation time.
    ///   - metadata: Additional key-value metadata.
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

/// A proactive suggestion from any intelligence subsystem, ranked by relevance and urgency.
public struct UnifiedSuggestion: Identifiable, Sendable {
    /// Unique suggestion identifier.
    public let id: UUID
    /// Which subsystem generated this suggestion.
    public let source: SuggestionSource
    /// Short title for display.
    public let title: String
    /// Detailed description of the suggestion.
    public let description: String
    /// Action to perform if the user accepts.
    public let action: SuggestionAction
    /// How relevant this suggestion is to the current context (0.0 - 1.0).
    public let relevanceScore: Double
    /// Confidence that this suggestion is correct (0.0 - 1.0).
    public let confidenceScore: Double
    /// How urgently this suggestion should be shown.
    public let timeSensitivity: TimeSensitivity
    /// How much cognitive effort the suggestion requires from the user.
    public let cognitiveLoad: CognitiveLoad
    /// When this suggestion expires and should be discarded.
    public let expiresAt: Date?
    /// Additional metadata as key-value pairs.
    public let metadata: [String: String]

    /// Intelligence subsystem that generated a suggestion.
    public enum SuggestionSource: String, Sendable {
        /// Proactive engine detected an opportunity.
        case proactiveEngine
        /// Blocker anticipator detected a potential issue.
        case blockerAnticipator
        /// Goal progress tracker identified next steps.
        case goalProgress
        /// Workflow automation identified an optimization.
        case workflowAutomation
        /// Memory system surfaced a relevant insight.
        case memoryInsight
        /// Context prediction anticipated a need.
        case contextPrediction
        /// Causal analysis identified a root cause.
        case causalAnalysis
    }

    /// Action to perform when a suggestion is accepted.
    public enum SuggestionAction: Sendable {
        /// Display a message to the user.
        case showMessage(String)
        /// Execute a named workflow.
        case executeWorkflow(workflowId: String)
        /// Load contextual resources into the session.
        case loadContext(resources: [String])
        /// Suggest the user take a break of the specified duration.
        case suggestBreak(duration: TimeInterval)
        /// Offer help on a specific topic.
        case offerHelp(topic: String)
        /// Switch to a more appropriate AI model.
        case switchModel(modelId: String)
        /// Preload resources the user is likely to need.
        case preloadResources([String])
    }

    /// How urgently a suggestion should be presented.
    public enum TimeSensitivity: String, Sendable {
        /// Must be shown immediately.
        case immediate
        /// Should be shown within 5 minutes.
        case soon
        /// Show when the user pauses or is idle.
        case whenIdle
        /// Show at a specific scheduled time.
        case scheduled
        /// Show whenever convenient.
        case lowPriority
    }

    /// Cognitive effort required from the user to act on a suggestion.
    public enum CognitiveLoad: String, Sendable {
        /// Quick glance, no action needed.
        case minimal
        /// Simple one-tap action.
        case low
        /// Requires some thought or consideration.
        case moderate
        /// Requires focused attention and decision-making.
        case high
    }

    /// Creates a unified suggestion.
    /// - Parameters:
    ///   - id: Suggestion identifier.
    ///   - source: Generating subsystem.
    ///   - title: Short display title.
    ///   - description: Detailed description.
    ///   - action: Action to perform on acceptance.
    ///   - relevanceScore: Context relevance (0.0-1.0).
    ///   - confidenceScore: Confidence (0.0-1.0).
    ///   - timeSensitivity: Urgency level.
    ///   - cognitiveLoad: Required cognitive effort.
    ///   - expiresAt: Expiration time.
    ///   - metadata: Additional metadata.
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

    /// Weighted composite score for ranking suggestions against each other.
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

/// A detected obstacle preventing the user from making progress.
public struct DetectedBlocker: Identifiable, Sendable {
    /// Unique blocker identifier.
    public let id: UUID
    /// Classification of the blocker.
    public let type: BlockerType
    /// Human-readable description of the blocker.
    public let description: String
    /// How severely the blocker impacts progress.
    public let severity: Severity
    /// When the blocker was detected.
    public let detectedAt: Date
    /// Contextual information about when the blocker was detected.
    public let context: BlockerContext
    /// Suggested ways to resolve the blocker.
    public let suggestedResolutions: [String]

    /// Classification of user progress blockers.
    public enum BlockerType: String, Sendable {
        /// User has been stuck on a task for too long.
        case stuckOnTask
        /// User keeps rephrasing the same question.
        case repeatedQuery
        /// Same error keeps occurring repeatedly.
        case errorLoop
        /// Memory or token limits have been reached.
        case resourceExhausted
        /// Waiting on an external dependency.
        case dependencyWait
        /// Task is too complex for current approach.
        case complexityOverload
        /// A tool or integration is not working.
        case toolFailure
    }

    /// Severity level of a detected blocker.
    public enum Severity: String, Sendable {
        /// Mild slowdown, user can work around it.
        case low
        /// Noticeable issue affecting productivity.
        case medium
        /// Significant blocker requiring intervention.
        case high
        /// Complete stop, user cannot proceed.
        case critical
    }

    /// Contextual information about a detected blocker.
    public struct BlockerContext: Sendable {
        /// Task type the user was working on, if known.
        public let taskType: String?
        /// How long the user has been stuck.
        public let timeSpent: TimeInterval
        /// Number of attempts made.
        public let attemptCount: Int
        /// Related queries the user has tried.
        public let relatedQueries: [String]
        /// Error messages encountered.
        public let errorMessages: [String]

        /// Creates a blocker context.
        /// - Parameters:
        ///   - taskType: Task type being attempted.
        ///   - timeSpent: Time spent on the task.
        ///   - attemptCount: Number of attempts.
        ///   - relatedQueries: Related queries tried.
        ///   - errorMessages: Errors encountered.
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

    /// Creates a detected blocker.
    /// - Parameters:
    ///   - id: Blocker identifier.
    ///   - type: Blocker classification.
    ///   - description: Human-readable description.
    ///   - severity: Impact severity.
    ///   - detectedAt: Detection timestamp.
    ///   - context: Blocker context.
    ///   - suggestedResolutions: Possible resolutions.
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

/// A user goal inferred from conversation history, project structure, and behavior.
public struct InferredGoal: Identifiable, Sendable {
    /// Unique goal identifier.
    public let id: UUID
    /// Short title for the goal.
    public let title: String
    /// Detailed description of the inferred goal.
    public let description: String
    /// Goal category classification.
    public let category: GoalCategory
    /// Confidence in the goal inference (0.0 - 1.0).
    public let confidence: Double
    /// Priority level of the goal.
    public let priority: GoalPriority
    /// Deadline for the goal, if inferred.
    public let deadline: Date?
    /// Estimated progress toward completion (0.0 - 1.0).
    public let progress: Double
    /// Conversation IDs related to this goal.
    public let relatedConversations: [UUID]
    /// Project names related to this goal.
    public let relatedProjects: [String]
    /// Sub-goals that compose this goal.
    public let subGoals: [InferredGoal]
    /// When the goal was first inferred.
    public let inferredAt: Date
    /// When the goal was last updated.
    public let lastUpdated: Date

    /// Classification of inferred user goals.
    public enum GoalCategory: String, Sendable {
        /// Complete a defined project.
        case project
        /// Learn a new skill or technology.
        case learning
        /// Improve personal productivity.
        case productivity
        /// Solve a specific problem or bug.
        case problemSolving
        /// Build something new from scratch.
        case creation
        /// Keep existing systems running.
        case maintenance
        /// Research or explore a topic.
        case exploration
    }

    /// Priority level for inferred goals.
    public enum GoalPriority: String, Sendable {
        /// Must complete as soon as possible.
        case critical
        /// Important, should be addressed soon.
        case high
        /// Normal priority.
        case medium
        /// Address when possible.
        case low
        /// Ongoing background goal.
        case background
    }

    /// Creates an inferred goal.
    /// - Parameters:
    ///   - id: Goal identifier.
    ///   - title: Short title.
    ///   - description: Detailed description.
    ///   - category: Goal category.
    ///   - confidence: Inference confidence (0.0-1.0).
    ///   - priority: Goal priority.
    ///   - deadline: Optional deadline.
    ///   - progress: Completion progress (0.0-1.0).
    ///   - relatedConversations: Related conversation IDs.
    ///   - relatedProjects: Related project names.
    ///   - subGoals: Decomposed sub-goals.
    ///   - inferredAt: First inference time.
    ///   - lastUpdated: Last update time.
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

/// A resource preloaded in anticipation of user needs.
public struct PreloadedResource: Identifiable, Sendable {
    /// Unique resource identifier.
    public let id: UUID
    /// Type of preloaded resource.
    public let type: ResourceType
    /// Identifier or path of the resource.
    public let identifier: String
    /// How relevant this resource is to the anticipated need (0.0 - 1.0).
    public let relevanceScore: Double
    /// When the resource was loaded.
    public let loadedAt: Date
    /// When the preloaded resource expires and should be evicted.
    public let expiresAt: Date

    /// Classification of preloadable resource types.
    public enum ResourceType: String, Sendable {
        /// A file from disk.
        case file
        /// A conversation from history.
        case conversation
        /// A memory record.
        case memory
        /// Documentation or reference material.
        case documentation
        /// A code snippet.
        case codeSnippet
        /// An AI model loaded into memory.
        case model
    }

    /// Creates a preloaded resource record.
    /// - Parameters:
    ///   - id: Resource identifier.
    ///   - type: Resource type.
    ///   - identifier: Resource path or name.
    ///   - relevanceScore: Relevance to anticipated need.
    ///   - loadedAt: When loaded.
    ///   - expiresAt: When the resource expires.
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

/// Aspect of the user behavioral model that was updated.
public enum UserModelAspect: String, Sendable {
    /// How the user prefers to communicate (formal, casual, technical).
    case communicationStyle
    /// User's technical expertise level.
    case technicalLevel
    /// Preferred response detail depth.
    case preferredDepth
    /// How the user learns best (examples, explanations, docs).
    case learningStyle
    /// Work schedule and productivity patterns.
    case workHabits
    /// Preferred tools, models, and approaches.
    case toolPreferences
    /// How the user handles and recovers from errors.
    case errorHandling
    /// How the user makes decisions (quick vs. deliberate).
    case decisionMaking
}

// MARK: - Intelligence Subsystem Protocol

/// Protocol for intelligence subsystems that participate in the unified hub.
public protocol IntelligenceSubsystem: Sendable {
    /// Unique identifier for this subsystem.
    var subsystemId: String { get }
    /// Process an intelligence event from any subsystem.
    /// - Parameter event: The event to process.
    func processEvent(_ event: IntelligenceEvent) async
    /// Returns detected patterns from this subsystem.
    /// - Returns: Array of detected intelligence patterns.
    func getInsights() async -> [IntelligencePattern]
    /// Generates suggestions based on the current intelligence context.
    /// - Parameter context: Current intelligence context snapshot.
    /// - Returns: Ranked suggestions from this subsystem.
    func getSuggestions(context: IntelligenceContext) async -> [UnifiedSuggestion]
}

// MARK: - Intelligence Context

/// Snapshot of the current intelligence state, passed to subsystems for suggestion generation.
public struct IntelligenceContext: Sendable {
    /// The user's current query, if any.
    public let currentQuery: String?
    /// Active conversation identifier.
    public let conversationId: UUID?
    /// Recently submitted queries for pattern detection.
    public let recentQueries: [String]
    /// Classified type of the current task.
    public let currentTaskType: String?
    /// Currently active inferred goals.
    public let activeGoals: [InferredGoal]
    /// Snapshot of the user behavioral model.
    public let userModel: UserModelSnapshot
    /// Current time for temporal reasoning.
    public let timeOfDay: Date
    /// Duration of the current session in seconds.
    public let sessionDuration: TimeInterval

    /// Snapshot of key user behavioral model dimensions.
    public struct UserModelSnapshot: Sendable {
        /// Estimated technical level (0.0 = beginner, 1.0 = expert).
        public let technicalLevel: Double
        /// Preferred response verbosity (0.0 = terse, 1.0 = verbose).
        public let preferredVerbosity: Double
        /// Estimated current cognitive load (0.0 = fresh, 1.0 = overloaded).
        public let currentCognitiveLoad: Double
        /// Recent productivity level (0.0 = unproductive, 1.0 = highly productive).
        public let recentProductivity: Double

        /// Creates a user model snapshot.
        /// - Parameters:
        ///   - technicalLevel: Technical expertise (0.0-1.0).
        ///   - preferredVerbosity: Verbosity preference (0.0-1.0).
        ///   - currentCognitiveLoad: Cognitive load (0.0-1.0).
        ///   - recentProductivity: Productivity level (0.0-1.0).
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

    /// Creates an intelligence context.
    /// - Parameters:
    ///   - currentQuery: Current user query.
    ///   - conversationId: Active conversation ID.
    ///   - recentQueries: Recent query history.
    ///   - currentTaskType: Classified task type.
    ///   - activeGoals: Active inferred goals.
    ///   - userModel: User model snapshot.
    ///   - timeOfDay: Current time.
    ///   - sessionDuration: Session duration.
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
