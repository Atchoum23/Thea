// EventBus.swift
// Thea
//
// Event-sourcing foundation for Thea
// All actions as events for replay, debugging, and learning

import Foundation
import OSLog
import Combine

// MARK: - Event Protocol

/// Base protocol for all events in the system
public protocol TheaEvent: Sendable, Codable, Identifiable {
    var id: UUID { get }
    var timestamp: Date { get }
    var source: EventSource { get }
    var category: EventCategory { get }
}

// MARK: - Event Source

public enum EventSource: String, Sendable, Codable {
    case user = "User"
    case ai = "AI"
    case system = "System"
    case agent = "Agent"
    case integration = "Integration"
    case scheduler = "Scheduler"
}

// MARK: - Event Category

public enum EventCategory: String, Sendable, Codable, CaseIterable {
    case message = "Message"
    case action = "Action"
    case navigation = "Navigation"
    case state = "State"
    case error = "Error"
    case performance = "Performance"
    case learning = "Learning"
    case integration = "Integration"
}

// MARK: - Concrete Events

/// User sent a message
public struct MessageEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .message

    public let conversationId: UUID
    public let content: String
    public let role: MessageRole
    public let model: String?

    public enum MessageRole: String, Sendable, Codable {
        case user, assistant, system
    }

    public init(
        conversationId: UUID,
        content: String,
        role: MessageRole,
        model: String? = nil,
        source: EventSource = .user
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.source = source
        self.conversationId = conversationId
        self.content = content
        self.role = role
        self.model = model
    }
}

/// AI action was taken
public struct ActionEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .action

    public let actionType: ActionType
    public let details: [String: String]
    public let success: Bool
    public let error: String?

    public enum ActionType: String, Sendable, Codable {
        case modelQuery = "Model Query"
        case codeExecution = "Code Execution"
        case webSearch = "Web Search"
        case fileOperation = "File Operation"
        case terminalCommand = "Terminal Command"
        case agentSpawn = "Agent Spawn"
        case workflowStep = "Workflow Step"
        case confidenceCheck = "Confidence Check"
    }

    public init(
        actionType: ActionType,
        details: [String: String] = [:],
        success: Bool = true,
        error: String? = nil,
        source: EventSource = .ai
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.source = source
        self.actionType = actionType
        self.details = details
        self.success = success
        self.error = error
    }
}

/// State change occurred
public struct StateChangeEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .state

    public let component: String
    public let previousValue: String?
    public let newValue: String
    public let reason: String?

    public init(
        component: String,
        previousValue: String? = nil,
        newValue: String,
        reason: String? = nil,
        source: EventSource = .system
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.source = source
        self.component = component
        self.previousValue = previousValue
        self.newValue = newValue
        self.reason = reason
    }
}

/// Error occurred
public struct ErrorEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .error

    public let errorType: String
    public let message: String
    public let stackTrace: String?
    public let recoverable: Bool

    public init(
        errorType: String,
        message: String,
        stackTrace: String? = nil,
        recoverable: Bool = true,
        source: EventSource = .system
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.source = source
        self.errorType = errorType
        self.message = message
        self.stackTrace = stackTrace
        self.recoverable = recoverable
    }
}

/// Performance metric
public struct PerformanceEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .performance

    public let operation: String
    public let duration: TimeInterval
    public let metadata: [String: String]

    public init(
        operation: String,
        duration: TimeInterval,
        metadata: [String: String] = [:],
        source: EventSource = .system
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.source = source
        self.operation = operation
        self.duration = duration
        self.metadata = metadata
    }
}

/// Learning event (feedback, correction)
public struct LearningEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .learning

    public let learningType: LearningType
    public let relatedEventId: UUID?
    public let data: [String: String]

    public enum LearningType: String, Sendable, Codable {
        case feedback = "Feedback"
        case correction = "Correction"
        case preference = "Preference"
        case pattern = "Pattern"
    }

    public init(
        learningType: LearningType,
        relatedEventId: UUID? = nil,
        data: [String: String] = [:],
        source: EventSource = .user
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.source = source
        self.learningType = learningType
        self.relatedEventId = relatedEventId
        self.data = data
    }
}

// MARK: - Event Bus

/// Central event bus for publishing and subscribing to events
@MainActor
public final class EventBus: ObservableObject {
    public static let shared = EventBus()

    private let logger = Logger(subsystem: "com.thea.core", category: "EventBus")

    // Event storage
    @Published public private(set) var recentEvents: [any TheaEvent] = []
    private var eventHistory: [any TheaEvent] = []

    // Subscribers
    private var subscribers: [EventCategory: [(any TheaEvent) -> Void]] = [:]
    private var globalSubscribers: [(any TheaEvent) -> Void] = []

    // Configuration
    public var maxRecentEvents: Int = 100
    public var maxHistorySize: Int = 10000
    public var persistEvents: Bool = true

    private let storageKey = "thea_event_history"

    private init() {
        Task { await loadHistory() }
    }

    // MARK: - Publishing

    /// Publish an event to all subscribers
    public func publish<E: TheaEvent>(_ event: E) {
        logger.debug("Publishing event: \(event.category.rawValue) from \(event.source.rawValue)")

        // Add to recent events
        recentEvents.append(event)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeFirst()
        }

        // Add to history
        eventHistory.append(event)
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst()
        }

        // Notify category subscribers
        if let categorySubscribers = subscribers[event.category] {
            for subscriber in categorySubscribers {
                subscriber(event)
            }
        }

        // Notify global subscribers
        for subscriber in globalSubscribers {
            subscriber(event)
        }

        // Persist periodically
        if persistEvents && eventHistory.count % 50 == 0 {
            Task { await saveHistory() }
        }
    }

    // MARK: - Subscribing

    /// Subscribe to events of a specific category
    public func subscribe(
        to category: EventCategory,
        handler: @escaping (any TheaEvent) -> Void
    ) {
        if subscribers[category] == nil {
            subscribers[category] = []
        }
        subscribers[category]?.append(handler)
    }

    /// Subscribe to all events
    public func subscribeToAll(handler: @escaping (any TheaEvent) -> Void) {
        globalSubscribers.append(handler)
    }

    // MARK: - Querying

    /// Get events filtered by criteria
    public func getEvents(
        category: EventCategory? = nil,
        source: EventSource? = nil,
        since: Date? = nil,
        limit: Int = 100
    ) -> [any TheaEvent] {
        var filtered = eventHistory

        if let category {
            filtered = filtered.filter { $0.category == category }
        }

        if let source {
            filtered = filtered.filter { $0.source == source }
        }

        if let since {
            filtered = filtered.filter { $0.timestamp >= since }
        }

        return Array(filtered.suffix(limit))
    }

    /// Get events for a specific conversation
    public func getConversationEvents(conversationId: UUID) -> [MessageEvent] {
        eventHistory
            .compactMap { $0 as? MessageEvent }
            .filter { $0.conversationId == conversationId }
    }

    // MARK: - Analytics

    /// Get event statistics
    public func getStatistics() -> EventStatistics {
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let dayAgo = now.addingTimeInterval(-86400)

        let recentHour = eventHistory.filter { $0.timestamp >= hourAgo }
        let recentDay = eventHistory.filter { $0.timestamp >= dayAgo }

        var categoryBreakdown: [EventCategory: Int] = [:]
        for category in EventCategory.allCases {
            categoryBreakdown[category] = eventHistory.filter { $0.category == category }.count
        }

        let errors = eventHistory.compactMap { $0 as? ErrorEvent }
        let errorRate = eventHistory.isEmpty ? 0.0 : Double(errors.count) / Double(eventHistory.count)

        return EventStatistics(
            totalEvents: eventHistory.count,
            eventsLastHour: recentHour.count,
            eventsLastDay: recentDay.count,
            categoryBreakdown: categoryBreakdown,
            errorRate: errorRate,
            oldestEvent: eventHistory.first?.timestamp,
            newestEvent: eventHistory.last?.timestamp
        )
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

    private func loadHistory() async {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        do {
            let container = try JSONDecoder().decode(EventHistoryContainer.self, from: data)
            // Note: In production, would need type-erased decoding for different event types
            logger.info("Loaded \(container.eventCount) events from history")
        } catch {
            logger.warning("Failed to load event history: \(error.localizedDescription)")
        }
    }

    private func saveHistory() async {
        // Note: Would need type-erased encoding for full implementation
        let container = EventHistoryContainer(
            eventCount: eventHistory.count,
            lastSaved: Date()
        )

        do {
            let data = try JSONEncoder().encode(container)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.warning("Failed to save event history: \(error.localizedDescription)")
        }
    }

    /// Clear all event history
    public func clearHistory() {
        eventHistory.removeAll()
        recentEvents.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        logger.info("Cleared event history")
    }
}

// MARK: - Supporting Types

public struct EventStatistics: Sendable {
    public let totalEvents: Int
    public let eventsLastHour: Int
    public let eventsLastDay: Int
    public let categoryBreakdown: [EventCategory: Int]
    public let errorRate: Double
    public let oldestEvent: Date?
    public let newestEvent: Date?
}

struct EventHistoryContainer: Codable {
    let eventCount: Int
    let lastSaved: Date
}

// MARK: - Convenience Extensions

extension EventBus {
    /// Log a message event
    public func logMessage(
        conversationId: UUID,
        content: String,
        role: MessageEvent.MessageRole,
        model: String? = nil
    ) {
        publish(MessageEvent(
            conversationId: conversationId,
            content: content,
            role: role,
            model: model
        ))
    }

    /// Log an action event
    public func logAction(
        _ actionType: ActionEvent.ActionType,
        details: [String: String] = [:],
        success: Bool = true,
        error: String? = nil
    ) {
        publish(ActionEvent(
            actionType: actionType,
            details: details,
            success: success,
            error: error
        ))
    }

    /// Log an error event
    public func logError(
        _ errorType: String,
        message: String,
        recoverable: Bool = true
    ) {
        publish(ErrorEvent(
            errorType: errorType,
            message: message,
            recoverable: recoverable
        ))
    }

    /// Log a performance metric
    public func logPerformance(
        operation: String,
        duration: TimeInterval,
        metadata: [String: String] = [:]
    ) {
        publish(PerformanceEvent(
            operation: operation,
            duration: duration,
            metadata: metadata
        ))
    }

    /// Log a learning event
    public func logLearning(
        type: LearningEvent.LearningType,
        relatedTo eventId: UUID? = nil,
        data: [String: String] = [:]
    ) {
        publish(LearningEvent(
            learningType: type,
            relatedEventId: eventId,
            data: data
        ))
    }
}
