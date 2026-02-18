// EventBus.swift
// Thea V2
//
// Central event sourcing system - the nervous system of Thea
// ALL actions, state changes, and communications flow through here
//
// Event types (TheaEvent, EventSource, EventCategory, and all concrete events)
// are defined in EventBusEvents.swift

import Foundation
import Combine
import OSLog

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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var storedEvents = loadPersistedEventData()

        do {
            let eventData = try encoder.encode(AnyTheaEvent(event))
            storedEvents.append(eventData)
            if storedEvents.count > maxHistorySize {
                storedEvents.removeFirst()
            }
            UserDefaults.standard.set(storedEvents, forKey: "EventBus.events")
        } catch {
            logger.error("Failed to encode event for persistence: \(error)")
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
        do {
            self.data = try JSONEncoder().encode(event)
        } catch {
            self.data = Data()
        }
    }
}
