// EventBusEvents.swift
// Thea V2
//
// Event protocol, metadata enums, and concrete event structs
// extracted from EventBus.swift for file_length compliance.

import Foundation

// MARK: - Event Protocol

/// Base protocol for all Thea events published through the EventBus.
public protocol TheaEvent: Sendable, Codable, Identifiable {
    /// Unique identifier for this event instance.
    var id: UUID { get }
    /// When the event occurred.
    var timestamp: Date { get }
    /// Origin of the event (user, AI, system, etc.).
    var source: EventSource { get }
    /// Logical category this event belongs to.
    var category: EventCategory { get }
}

// MARK: - Event Metadata

/// Identifies the origin of an event within the system.
public enum EventSource: String, Sendable, Codable, CaseIterable {
    /// User-initiated action (tap, keystroke, explicit request).
    case user
    /// AI-generated action or response.
    case ai
    /// System or OS-level event (notifications, lifecycle).
    case system
    /// Sub-agent spawned action.
    case agent
    /// External integration event (third-party API, webhook).
    case integration
    /// Scheduled or timer-triggered task.
    case scheduler
    /// Memory subsystem operation.
    case memory
    /// Verification or confidence-check subsystem.
    case verification
}

/// Logical category grouping for events.
public enum EventCategory: String, Sendable, Codable, CaseIterable {
    /// Chat message sent or received.
    case message
    /// Executable action (code run, file op, API call).
    case action
    /// UI navigation between views.
    case navigation
    /// State transition within a component.
    case state
    /// Error or failure condition.
    case error
    /// Performance measurement or metric.
    case performance
    /// Learning or adaptation event.
    case learning
    /// External integration activity.
    case integration
    /// Memory store, retrieve, or maintenance operation.
    case memory
    /// Confidence or verification check.
    case verification
    /// Configuration or settings change.
    case configuration
    /// Application lifecycle event (launch, background, terminate).
    case lifecycle
}

// MARK: - Concrete Events

/// Event representing a chat message being sent or received.
public struct MessageEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the message event occurred.
    public let timestamp: Date
    /// Origin of the message.
    public let source: EventSource
    /// Always `.message`.
    public var category: EventCategory { .message }

    /// Conversation this message belongs to.
    public let conversationId: UUID
    /// Text content of the message.
    public let content: String
    /// Role of the sender (user, assistant, system).
    public let role: MessageRole
    /// Model that generated the response, if applicable.
    public let model: String?
    /// Confidence score of the response, if available.
    public let confidence: Double?
    /// Token count of the message content.
    public let tokenCount: Int?

    /// Sender role for a chat message.
    public enum MessageRole: String, Sendable, Codable {
        /// User-sent message.
        case user
        /// AI assistant response.
        case assistant
        /// System prompt or instruction.
        case system
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, source, conversationId, content, role, model, confidence, tokenCount
    }

    /// Creates a message event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the event occurred.
    ///   - source: Event origin.
    ///   - conversationId: Parent conversation ID.
    ///   - content: Message text.
    ///   - role: Sender role.
    ///   - model: AI model used, if applicable.
    ///   - confidence: Response confidence score.
    ///   - tokenCount: Token count of the message.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .user,
        conversationId: UUID,
        content: String,
        role: MessageRole,
        model: String? = nil,
        confidence: Double? = nil,
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.conversationId = conversationId
        self.content = content
        self.role = role
        self.model = model
        self.confidence = confidence
        self.tokenCount = tokenCount
    }
}

/// Event representing an action being executed (code run, API call, file op, etc.).
public struct ActionEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the action occurred.
    public let timestamp: Date
    /// Origin of the action.
    public let source: EventSource
    /// Always `.action`.
    public var category: EventCategory { .action }

    /// Type of action performed.
    public let actionType: ActionType
    /// Target resource or endpoint of the action.
    public let target: String?
    /// Key-value parameters passed to the action.
    public let parameters: [String: String]
    /// Whether the action succeeded.
    public let success: Bool
    /// How long the action took, in seconds.
    public let duration: TimeInterval?
    /// Error message if the action failed.
    public let error: String?

    /// Classification of executable actions.
    public enum ActionType: String, Sendable, Codable {
        /// Running code in a sandbox.
        case codeExecution
        /// Executing a terminal/shell command.
        case terminalCommand
        /// File read, write, or delete.
        case fileOperation
        /// Web search query.
        case webSearch
        /// External API call.
        case apiCall
        /// AI model query.
        case modelQuery
        /// Storing data in memory.
        case memoryStore
        /// Retrieving data from memory.
        case memoryRetrieve
        /// Running verification checks.
        case verification
        /// Task classification.
        case classification
        /// Model routing decision.
        case routing
        /// Spawning a sub-agent.
        case agentSpawn
        /// Step within a multi-step workflow.
        case workflowStep
    }

    /// Creates an action event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the action occurred.
    ///   - source: Event origin.
    ///   - actionType: Type of action.
    ///   - target: Target resource.
    ///   - parameters: Action parameters.
    ///   - success: Whether the action succeeded.
    ///   - duration: Execution duration.
    ///   - error: Error message on failure.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .ai,
        actionType: ActionType,
        target: String? = nil,
        parameters: [String: String] = [:],
        success: Bool,
        duration: TimeInterval? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.actionType = actionType
        self.target = target
        self.parameters = parameters
        self.success = success
        self.duration = duration
        self.error = error
    }
}

/// Event representing a state transition within a component.
public struct StateEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the state change occurred.
    public let timestamp: Date
    /// Origin of the state change.
    public let source: EventSource
    /// Always `.state`.
    public var category: EventCategory { .state }

    /// Name of the component whose state changed.
    public let component: String
    /// Previous state value, if known.
    public let previousState: String?
    /// New state value after the transition.
    public let newState: String
    /// Reason for the state change.
    public let reason: String?

    /// Creates a state change event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the change occurred.
    ///   - source: Event origin.
    ///   - component: Component that changed state.
    ///   - previousState: State before the transition.
    ///   - newState: State after the transition.
    ///   - reason: Why the state changed.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .system,
        component: String,
        previousState: String? = nil,
        newState: String,
        reason: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.component = component
        self.previousState = previousState
        self.newState = newState
        self.reason = reason
    }
}

/// Event representing an error or failure condition.
public struct ErrorEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the error occurred.
    public let timestamp: Date
    /// Origin of the error.
    public let source: EventSource
    /// Always `.error`.
    public var category: EventCategory { .error }

    /// Classification of the error (e.g. "NetworkError", "ParseError").
    public let errorType: String
    /// Human-readable error description.
    public let message: String
    /// Additional context key-value pairs.
    public let context: [String: String]
    /// Whether the error can be automatically recovered from.
    public let recoverable: Bool
    /// Optional stack trace for debugging.
    public let stackTrace: String?

    /// Creates an error event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the error occurred.
    ///   - source: Event origin.
    ///   - errorType: Error classification.
    ///   - message: Error description.
    ///   - context: Contextual key-value pairs.
    ///   - recoverable: Whether recovery is possible.
    ///   - stackTrace: Stack trace for debugging.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .system,
        errorType: String,
        message: String,
        context: [String: String] = [:],
        recoverable: Bool = true,
        stackTrace: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.errorType = errorType
        self.message = message
        self.context = context
        self.recoverable = recoverable
        self.stackTrace = stackTrace
    }
}

/// Event capturing a performance metric for an operation.
public struct PerformanceEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the measurement was taken.
    public let timestamp: Date
    /// Origin of the measurement.
    public let source: EventSource
    /// Always `.performance`.
    public var category: EventCategory { .performance }

    /// Name of the measured operation.
    public let operation: String
    /// Duration of the operation in seconds.
    public let duration: TimeInterval
    /// Additional metadata (tokens, model, etc.).
    public let metadata: [String: String]

    /// Creates a performance event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the measurement occurred.
    ///   - source: Event origin.
    ///   - operation: Operation name.
    ///   - duration: How long the operation took.
    ///   - metadata: Additional context.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .system,
        operation: String,
        duration: TimeInterval,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.operation = operation
        self.duration = duration
        self.metadata = metadata
    }
}

/// Event representing a learning or adaptation occurrence.
public struct LearningEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the learning event occurred.
    public let timestamp: Date
    /// Origin of the learning signal.
    public let source: EventSource
    /// Always `.learning`.
    public var category: EventCategory { .learning }

    /// Type of learning that occurred.
    public let learningType: LearningType
    /// ID of the event that triggered this learning, if applicable.
    public let relatedEventId: UUID?
    /// Key-value data associated with the learning.
    public let data: [String: String]
    /// Measured improvement from this learning (0.0 - 1.0).
    public let improvement: Double?

    /// Classification of learning events.
    public enum LearningType: String, Sendable, Codable {
        /// User corrected an AI response.
        case userCorrection
        /// New behavioral pattern detected.
        case patternDetected
        /// User preference inferred from behavior.
        case preferenceInferred
        /// Error pattern learned for future avoidance.
        case errorFixed
        /// Workflow optimized based on usage.
        case workflowOptimized
        /// User gave explicit positive feedback.
        case feedbackPositive
        /// User gave explicit negative feedback.
        case feedbackNegative
    }

    /// Creates a learning event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the learning occurred.
    ///   - source: Event origin.
    ///   - learningType: Type of learning.
    ///   - relatedEventId: Triggering event ID.
    ///   - data: Associated data.
    ///   - improvement: Measured improvement score.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .ai,
        learningType: LearningType,
        relatedEventId: UUID? = nil,
        data: [String: String] = [:],
        improvement: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.learningType = learningType
        self.relatedEventId = relatedEventId
        self.data = data
        self.improvement = improvement
    }
}

/// Event representing a memory subsystem operation.
public struct MemoryEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the memory operation occurred.
    public let timestamp: Date
    /// Origin of the operation.
    public let source: EventSource
    /// Always `.memory`.
    public var category: EventCategory { .memory }

    /// Type of memory operation performed.
    public let operation: MemoryOperation
    /// Memory tier involved in the operation.
    public let tier: MemoryTier
    /// Number of memory items affected.
    public let itemCount: Int
    /// Relevance score of retrieved items, if applicable.
    public let relevanceScore: Double?

    /// Types of memory operations.
    public enum MemoryOperation: String, Sendable, Codable {
        /// Storing new data into memory.
        case store
        /// Retrieving data from memory.
        case retrieve
        /// Consolidating scattered memories.
        case consolidate
        /// Pruning weak or expired memories.
        case prune
        /// Searching across memory tiers.
        case search
    }

    /// Memory tier classification.
    public enum MemoryTier: String, Sendable, Codable {
        /// Short-term working memory.
        case working
        /// Episodic memory (specific events).
        case episodic
        /// Semantic memory (facts and concepts).
        case semantic
        /// Procedural memory (how-to knowledge).
        case procedural
    }

    /// Creates a memory event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the operation occurred.
    ///   - source: Event origin.
    ///   - operation: Memory operation type.
    ///   - tier: Memory tier involved.
    ///   - itemCount: Number of items affected.
    ///   - relevanceScore: Relevance score for retrievals.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .memory,
        operation: MemoryOperation,
        tier: MemoryTier,
        itemCount: Int,
        relevanceScore: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.operation = operation
        self.tier = tier
        self.itemCount = itemCount
        self.relevanceScore = relevanceScore
    }
}

/// Event representing a verification or confidence check.
public struct VerificationEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the verification occurred.
    public let timestamp: Date
    /// Origin of the verification.
    public let source: EventSource
    /// Always `.verification`.
    public var category: EventCategory { .verification }

    /// Type of verification performed.
    public let verificationType: VerificationType
    /// Resulting confidence score (0.0 - 1.0).
    public let confidence: Double
    /// Sources consulted during verification.
    public let sources: [String]
    /// Number of conflicting signals found.
    public let conflicts: Int

    /// Classification of verification methods.
    public enum VerificationType: String, Sendable, Codable {
        /// Cross-model consensus check.
        case multiModel
        /// Web search fact-checking.
        case webSearch
        /// Code execution validation.
        case codeExecution
        /// Static analysis check.
        case staticAnalysis
        /// User feedback-based calibration.
        case userFeedback
    }

    /// Creates a verification event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the verification occurred.
    ///   - source: Event origin.
    ///   - verificationType: Verification method used.
    ///   - confidence: Resulting confidence score.
    ///   - sources: Sources consulted.
    ///   - conflicts: Number of conflicts found.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .verification,
        verificationType: VerificationType,
        confidence: Double,
        sources: [String] = [],
        conflicts: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.verificationType = verificationType
        self.confidence = confidence
        self.sources = sources
        self.conflicts = conflicts
    }
}

/// Event representing a UI navigation between views.
public struct NavigationEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the navigation occurred.
    public let timestamp: Date
    /// Origin of the navigation.
    public let source: EventSource
    /// Always `.navigation`.
    public var category: EventCategory { .navigation }

    /// View navigated away from, if known.
    public let fromView: String?
    /// View navigated to.
    public let toView: String
    /// Additional navigation parameters.
    public let parameters: [String: String]

    /// Creates a navigation event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the navigation occurred.
    ///   - source: Event origin.
    ///   - fromView: Source view.
    ///   - toView: Destination view.
    ///   - parameters: Navigation parameters.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .user,
        fromView: String? = nil,
        toView: String,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.fromView = fromView
        self.toView = toView
        self.parameters = parameters
    }
}

/// Generic component event for arbitrary component-level state changes.
public struct ComponentEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the component event occurred.
    public let timestamp: Date
    /// Origin of the event.
    public let source: EventSource
    /// Always `.state`.
    public var category: EventCategory { .state }

    /// Action performed by the component.
    public let action: String
    /// Name of the component.
    public let component: String
    /// Additional details as key-value pairs.
    public let details: [String: String]

    /// Creates a component event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the event occurred.
    ///   - source: Event origin.
    ///   - action: Action performed.
    ///   - component: Component name.
    ///   - details: Additional details.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .system,
        action: String,
        component: String,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.action = action
        self.component = component
        self.details = details
    }
}

/// Event representing an application lifecycle transition.
public struct LifecycleEvent: TheaEvent {
    /// Unique event identifier.
    public let id: UUID
    /// When the lifecycle event occurred.
    public let timestamp: Date
    /// Origin of the event.
    public let source: EventSource
    /// Always `.lifecycle`.
    public var category: EventCategory { .lifecycle }

    /// Type of lifecycle transition.
    public let event: LifecycleType
    /// Additional details about the lifecycle event.
    public let details: [String: String]

    /// Classification of app lifecycle events.
    public enum LifecycleType: String, Sendable, Codable {
        /// Application launched.
        case appLaunch
        /// Application terminating.
        case appTerminate
        /// Application moved to background.
        case appBackground
        /// Application returned to foreground.
        case appForeground
        /// User session started.
        case sessionStart
        /// User session ended.
        case sessionEnd
        /// Configuration or settings changed.
        case configurationChange
    }

    /// Creates a lifecycle event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: When the event occurred.
    ///   - source: Event origin.
    ///   - event: Type of lifecycle transition.
    ///   - details: Additional context.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: EventSource = .system,
        event: LifecycleType,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.event = event
        self.details = details
    }
}
