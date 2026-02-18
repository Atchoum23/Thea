// EventBusEvents.swift
// Thea V2
//
// Event protocol, metadata enums, and concrete event structs
// extracted from EventBus.swift for file_length compliance.

import Foundation

// MARK: - Event Protocol

/// Base protocol for all Thea events
public protocol TheaEvent: Sendable, Codable, Identifiable {
    var id: UUID { get }
    var timestamp: Date { get }
    var source: EventSource { get }
    var category: EventCategory { get }
}

// MARK: - Event Metadata

public enum EventSource: String, Sendable, Codable, CaseIterable {
    case user           // User-initiated action
    case ai             // AI-generated action
    case system         // System/OS event
    case agent          // Sub-agent action
    case integration    // External integration
    case scheduler      // Scheduled task
    case memory         // Memory system
    case verification   // Verification system
}

public enum EventCategory: String, Sendable, Codable, CaseIterable {
    case message        // Chat messages
    case action         // Executable actions
    case navigation     // UI navigation
    case state          // State changes
    case error          // Errors and failures
    case performance    // Performance metrics
    case learning       // Learning events
    case integration    // External integrations
    case memory         // Memory operations
    case verification   // Confidence checks
    case configuration  // Config changes
    case lifecycle      // App lifecycle
}

// MARK: - Concrete Events

/// Chat message event
public struct MessageEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .message }

    public let conversationId: UUID
    public let content: String
    public let role: MessageRole
    public let model: String?
    public let confidence: Double?
    public let tokenCount: Int?

    public enum MessageRole: String, Sendable, Codable {
        case user, assistant, system
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, source, conversationId, content, role, model, confidence, tokenCount
    }

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

/// Action execution event
public struct ActionEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .action }

    public let actionType: ActionType
    public let target: String?
    public let parameters: [String: String]
    public let success: Bool
    public let duration: TimeInterval?
    public let error: String?

    public enum ActionType: String, Sendable, Codable {
        case codeExecution, terminalCommand, fileOperation
        case webSearch, apiCall, modelQuery
        case memoryStore, memoryRetrieve
        case verification, classification, routing
        case agentSpawn, workflowStep
    }

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

/// State change event
public struct StateEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .state }

    public let component: String
    public let previousState: String?
    public let newState: String
    public let reason: String?

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

/// Error event
public struct ErrorEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .error }

    public let errorType: String
    public let message: String
    public let context: [String: String]
    public let recoverable: Bool
    public let stackTrace: String?

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

/// Performance metric event
public struct PerformanceEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .performance }

    public let operation: String
    public let duration: TimeInterval
    public let metadata: [String: String]

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

/// Learning event
public struct LearningEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .learning }

    public let learningType: LearningType
    public let relatedEventId: UUID?
    public let data: [String: String]
    public let improvement: Double?

    public enum LearningType: String, Sendable, Codable {
        case userCorrection     // User corrected AI
        case patternDetected    // New pattern found
        case preferenceInferred // Preference learned
        case errorFixed         // Error pattern learned
        case workflowOptimized  // Workflow improved
        case feedbackPositive   // Positive feedback
        case feedbackNegative   // Negative feedback
    }

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

/// Memory operation event
public struct MemoryEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .memory }

    public let operation: MemoryOperation
    public let tier: MemoryTier
    public let itemCount: Int
    public let relevanceScore: Double?

    public enum MemoryOperation: String, Sendable, Codable {
        case store, retrieve, consolidate, prune, search
    }

    public enum MemoryTier: String, Sendable, Codable {
        case working, episodic, semantic, procedural
    }

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

/// Verification event
public struct VerificationEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .verification }

    public let verificationType: VerificationType
    public let confidence: Double
    public let sources: [String]
    public let conflicts: Int

    public enum VerificationType: String, Sendable, Codable {
        case multiModel, webSearch, codeExecution, staticAnalysis, userFeedback
    }

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

/// Navigation event
public struct NavigationEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .navigation }

    public let fromView: String?
    public let toView: String
    public let parameters: [String: String]

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

/// Component event - generic event for any component
public struct ComponentEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .state }

    public let action: String
    public let component: String
    public let details: [String: String]

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

/// Lifecycle event
public struct LifecycleEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public var category: EventCategory { .lifecycle }

    public let event: LifecycleType
    public let details: [String: String]

    public enum LifecycleType: String, Sendable, Codable {
        case appLaunch, appTerminate, appBackground, appForeground
        case sessionStart, sessionEnd
        case configurationChange
    }

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
