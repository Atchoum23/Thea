// EventBus.swift
// Thea V2
//
// Central event sourcing system - the nervous system of Thea
// ALL actions, state changes, and communications flow through here

import Foundation
import Combine
import OSLog

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

// MARK: - Event Bus

/// Central event bus for all Thea events
@MainActor
public final class EventBus: ObservableObject {
    public static let shared = EventBus()

    private let logger = Logger(subsystem: "com.thea.v2", category: "EventBus")

    // Published state
    @Published public private(set) var recentEvents: [any TheaEvent] = []
    @Published public private(set) var eventCount: Int = 0

    // Configuration
    public var maxRecentEvents: Int = 100
    public var persistEvents: Bool = true
    public var enableLogging: Bool = true

    // Subscribers (marked @Sendable for thread safety)
    private var categorySubscribers: [EventCategory: [@Sendable (any TheaEvent) -> Void]] = [:]
    private var globalSubscribers: [@Sendable (any TheaEvent) -> Void] = []

    // Event store
    private var eventHistory: [any TheaEvent] = []
    private let maxHistorySize = 10000

    private init() {
        // Initialize category subscriber lists
        for category in EventCategory.allCases {
            categorySubscribers[category] = []
        }
    }

    // MARK: - Publishing

    /// Publish an event to all subscribers
    public func publish<E: TheaEvent>(_ event: E) {
        // Add to recent events
        recentEvents.append(event)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeFirst()
        }

        // Add to history
        eventHistory.append(event)
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst(eventHistory.count - maxHistorySize)
        }

        eventCount += 1

        // Log if enabled
        if enableLogging {
            logger.debug("Event: \(event.category.rawValue) from \(event.source.rawValue)")
        }

        // Notify category subscribers
        if let subscribers = categorySubscribers[event.category] {
            for subscriber in subscribers {
                subscriber(event)
            }
        }

        // Notify global subscribers
        for subscriber in globalSubscribers {
            subscriber(event)
        }

        // Persist if enabled
        if persistEvents {
            Task {
                await persistEvent(event)
            }
        }
    }

    // MARK: - Subscribing

    /// Subscribe to events of a specific category
    public func subscribe(to category: EventCategory, handler: @escaping @Sendable (any TheaEvent) -> Void) {
        categorySubscribers[category]?.append(handler)
    }

    /// Subscribe to all events
    public func subscribeToAll(handler: @escaping @Sendable (any TheaEvent) -> Void) {
        globalSubscribers.append(handler)
    }

    /// Clear all subscribers (useful for testing and cleanup)
    public func clearSubscribers() {
        for category in EventCategory.allCases {
            categorySubscribers[category] = []
        }
        globalSubscribers.removeAll()
    }

    // MARK: - Querying

    /// Get events matching criteria (optimized single-pass filter)
    public func getEvents(
        category: EventCategory? = nil,
        source: EventSource? = nil,
        since: Date? = nil,
        limit: Int = 100
    ) -> [any TheaEvent] {
        // Single-pass filter for efficiency
        let filtered = eventHistory.filter { event in
            if let category, event.category != category { return false }
            if let source, event.source != source { return false }
            if let since, event.timestamp < since { return false }
            return true
        }

        return Array(filtered.suffix(limit))
    }

    /// Get events by ID
    public func getEvent(id: UUID) -> (any TheaEvent)? {
        eventHistory.first { $0.id == id }
    }

    /// Get events for a specific conversation
    public func getConversationEvents(conversationId: UUID) -> [MessageEvent] {
        eventHistory
            .compactMap { $0 as? MessageEvent }
            .filter { $0.conversationId == conversationId }
    }

    // MARK: - Convenience Publishers

    /// Log a message event
    public func logMessage(
        conversationId: UUID,
        content: String,
        role: MessageEvent.MessageRole,
        model: String? = nil,
        confidence: Double? = nil
    ) {
        let event = MessageEvent(
            source: role == .user ? .user : .ai,
            conversationId: conversationId,
            content: content,
            role: role,
            model: model,
            confidence: confidence
        )
        publish(event)
    }

    /// Log an action event
    public func logAction(
        _ actionType: ActionEvent.ActionType,
        target: String? = nil,
        parameters: [String: String] = [:],
        success: Bool,
        duration: TimeInterval? = nil,
        error: String? = nil
    ) {
        let event = ActionEvent(
            actionType: actionType,
            target: target,
            parameters: parameters,
            success: success,
            duration: duration,
            error: error
        )
        publish(event)
    }

    /// Log an error event
    public func logError(
        _ errorType: String,
        message: String,
        context: [String: String] = [:],
        recoverable: Bool = true
    ) {
        let event = ErrorEvent(
            errorType: errorType,
            message: message,
            context: context,
            recoverable: recoverable
        )
        publish(event)
    }

    /// Log a performance event
    public func logPerformance(
        operation: String,
        duration: TimeInterval,
        metadata: [String: String] = [:]
    ) {
        let event = PerformanceEvent(
            operation: operation,
            duration: duration,
            metadata: metadata
        )
        publish(event)
    }

    /// Log a learning event
    public func logLearning(
        type: LearningEvent.LearningType,
        relatedTo eventId: UUID? = nil,
        data: [String: String] = [:],
        improvement: Double? = nil
    ) {
        let event = LearningEvent(
            learningType: type,
            relatedEventId: eventId,
            data: data,
            improvement: improvement
        )
        publish(event)
    }

    /// Log a memory event
    public func logMemory(
        operation: MemoryEvent.MemoryOperation,
        tier: MemoryEvent.MemoryTier,
        itemCount: Int,
        relevanceScore: Double? = nil
    ) {
        let event = MemoryEvent(
            operation: operation,
            tier: tier,
            itemCount: itemCount,
            relevanceScore: relevanceScore
        )
        publish(event)
    }

    /// Log a verification event
    public func logVerification(
        type: VerificationEvent.VerificationType,
        confidence: Double,
        sources: [String] = [],
        conflicts: Int = 0
    ) {
        let event = VerificationEvent(
            verificationType: type,
            confidence: confidence,
            sources: sources,
            conflicts: conflicts
        )
        publish(event)
    }

    /// Log a state change event
    public func logStateChange(
        component: String,
        from previousState: String? = nil,
        to newState: String,
        reason: String? = nil
    ) {
        let event = StateEvent(
            component: component,
            previousState: previousState,
            newState: newState,
            reason: reason
        )
        publish(event)
    }

    /// Log a navigation event
    public func logNavigation(
        from fromView: String? = nil,
        to toView: String,
        parameters: [String: String] = [:]
    ) {
        let event = NavigationEvent(
            fromView: fromView,
            toView: toView,
            parameters: parameters
        )
        publish(event)
    }

    /// Log a lifecycle event
    public func logLifecycle(
        _ event: LifecycleEvent.LifecycleType,
        details: [String: String] = [:]
    ) {
        let lifecycleEvent = LifecycleEvent(
            event: event,
            details: details
        )
        publish(lifecycleEvent)
    }

    /// Log a component event
    public func logComponent(
        action: String,
        component: String,
        details: [String: String] = [:]
    ) {
        let event = ComponentEvent(
            action: action,
            component: component,
            details: details
        )
        publish(event)
    }

    // MARK: - Replay

    /// Replay events for debugging/analysis
    public func replay(
        from startDate: Date,
        to endDate: Date,
        handler: @escaping (any TheaEvent) -> Void
    ) {
        let eventsToReplay = eventHistory.filter {
            $0.timestamp >= startDate && $0.timestamp <= endDate
        }

        for event in eventsToReplay {
            handler(event)
        }
    }

    // MARK: - Persistence

    private func persistEvent(_ event: any TheaEvent) async {
        // Store last N events to UserDefaults
        // In production, would use EventStore with file-based storage
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            var storedEvents = loadPersistedEventData()

            if let eventData = try? encoder.encode(AnyTheaEvent(event)) {
                storedEvents.append(eventData)
                if storedEvents.count > maxHistorySize {
                    storedEvents.removeFirst()
                }
                UserDefaults.standard.set(storedEvents, forKey: "EventBus.events")
            }
        }
    }

    private func loadPersistedEventData() -> [Data] {
        UserDefaults.standard.array(forKey: "EventBus.events") as? [Data] ?? []
    }

    // MARK: - Statistics

    public struct EventStatistics: Sendable {
        public let totalEvents: Int
        public let eventsByCategory: [EventCategory: Int]
        public let eventsBySource: [EventSource: Int]
        public let errorRate: Double
        public let averageEventsPerMinute: Double
    }

    public func getStatistics() -> EventStatistics {
        var byCategory: [EventCategory: Int] = [:]
        var bySource: [EventSource: Int] = [:]
        var errorCount = 0

        for event in eventHistory {
            byCategory[event.category, default: 0] += 1
            bySource[event.source, default: 0] += 1
            if event.category == .error {
                errorCount += 1
            }
        }

        let totalEvents = eventHistory.count
        let errorRate = totalEvents > 0 ? Double(errorCount) / Double(totalEvents) : 0

        // Calculate events per minute
        let timeSpan: TimeInterval
        if let first = eventHistory.first, let last = eventHistory.last {
            timeSpan = max(1, last.timestamp.timeIntervalSince(first.timestamp)) / 60
        } else {
            timeSpan = 1
        }
        let eventsPerMinute = Double(totalEvents) / timeSpan

        return EventStatistics(
            totalEvents: totalEvents,
            eventsByCategory: byCategory,
            eventsBySource: bySource,
            errorRate: errorRate,
            averageEventsPerMinute: eventsPerMinute
        )
    }

    // MARK: - Reset

    public func clearHistory() {
        eventHistory.removeAll()
        recentEvents.removeAll()
        eventCount = 0
        UserDefaults.standard.removeObject(forKey: "EventBus.events")
    }
}

// MARK: - Type Erasure Helper

private struct AnyTheaEvent: Codable {
    let id: UUID
    let timestamp: Date
    let source: EventSource
    let category: EventCategory
    let data: Data

    init<E: TheaEvent>(_ event: E) {
        self.id = event.id
        self.timestamp = event.timestamp
        self.source = event.source
        self.category = event.category
        self.data = (try? JSONEncoder().encode(event)) ?? Data()
    }
}
