// AgentEnhancements+MessageQueue.swift
// Thea V2
//
// Message queue, clarifying questions, and quick actions for agent mode.

import Foundation
import OSLog

// MARK: - Message Queue

/// Manages queued messages for sequential processing
/// Inspired by Lovable's message queue with reorder/pause/remove
@MainActor
public final class AgentMessageQueue: ObservableObject {
    public static let shared = AgentMessageQueue()

    private let logger = Logger(subsystem: "com.thea.v2", category: "AgentMessageQueue")

    @Published public private(set) var queue: [AgentQueuedMessage] = []
    @Published public private(set) var currentMessage: AgentQueuedMessage?
    @Published public var isPaused: Bool = false

    private init() {}

    /// Add message to queue
    public func enqueue(_ message: AgentQueuedMessage) {
        queue.append(message)
        logger.debug("Enqueued message: \(message.content.prefix(50))...")

        // Start processing if not already
        if currentMessage == nil && !isPaused {
            Task {
                await processNext()
            }
        }
    }

    /// Remove message from queue
    public func remove(at index: Int) {
        guard index < queue.count else { return }
        let removed = queue.remove(at: index)
        logger.debug("Removed message: \(removed.id)")
    }

    /// Reorder message in queue
    public func move(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        logger.debug("Reordered queue")
    }

    /// Pause queue processing
    public func pause() {
        isPaused = true
        logger.info("Queue paused")
    }

    /// Resume queue processing
    public func resume() {
        isPaused = false
        logger.info("Queue resumed")

        if currentMessage == nil {
            Task {
                await processNext()
            }
        }
    }

    /// Clear entire queue
    public func clear() {
        queue.removeAll()
        logger.info("Queue cleared")
    }

    /// Process next message in queue
    private func processNext() async {
        guard !isPaused, !queue.isEmpty, currentMessage == nil else { return }

        currentMessage = queue.removeFirst()
        logger.debug("Processing message: \(self.currentMessage?.id.uuidString ?? "nil")")

        // Message processing would be handled by the conversation system
        // This just manages the queue state
    }

    /// Mark current message as complete and process next
    public func completeCurrentMessage() {
        currentMessage = nil

        Task {
            await processNext()
        }
    }
}

/// A message in the queue
public struct AgentQueuedMessage: Identifiable, Sendable {
    public let id: UUID
    public var content: String
    public var attachments: [String]
    public var priority: AgentMessagePriority
    public var queuedAt: Date
    public var sender: String?

    public init(
        id: UUID = UUID(),
        content: String,
        attachments: [String] = [],
        priority: AgentMessagePriority = .normal,
        queuedAt: Date = Date(),
        sender: String? = nil
    ) {
        self.id = id
        self.content = content
        self.attachments = attachments
        self.priority = priority
        self.queuedAt = queuedAt
        self.sender = sender
    }
}

public enum AgentMessagePriority: Int, Codable, Sendable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3

    public static func < (lhs: AgentMessagePriority, rhs: AgentMessagePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Clarifying Questions

/// System for generating and handling clarifying questions
/// Inspired by Lovable's interactive clarification flow
public struct AgentClarifyingQuestion: Identifiable, Codable, Sendable {
    public let id: UUID
    public var question: String
    public var options: [AgentQuestionOption]
    public var allowsCustomResponse: Bool
    public var category: AgentQuestionCategory
    public var importance: AgentQuestionImportance
    public var answer: String?

    public init(
        id: UUID = UUID(),
        question: String,
        options: [AgentQuestionOption] = [],
        allowsCustomResponse: Bool = true,
        category: AgentQuestionCategory = .general,
        importance: AgentQuestionImportance = .recommended,
        answer: String? = nil
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.allowsCustomResponse = allowsCustomResponse
        self.category = category
        self.importance = importance
        self.answer = answer
    }
}

public struct AgentQuestionOption: Identifiable, Codable, Sendable {
    public let id: UUID
    public var label: String
    public var value: String
    public var description: String?

    public init(id: UUID = UUID(), label: String, value: String, description: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.description = description
    }
}

public enum AgentQuestionCategory: String, Codable, Sendable {
    case general
    case technical
    case design
    case architecture
    case scope
    case requirements
}

public enum AgentQuestionImportance: String, Codable, Sendable {
    case required    // Must answer before proceeding
    case recommended // Should answer for better results
    case optional    // Nice to have
}

// MARK: - Quick Actions

/// Contextual quick action buttons
/// Inspired by Bolt's quick action buttons
public struct AgentQuickAction: Identifiable, Sendable {
    public let id: UUID
    public var label: String
    public var icon: String
    public var action: AgentQuickActionType
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        icon: String,
        action: AgentQuickActionType,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.action = action
        self.isEnabled = isEnabled
    }
}

public enum AgentQuickActionType: Sendable {
    case implementPlan(planId: UUID)
    case showExample(topic: String)
    case refineIdea
    case askFollowUp(question: String)
    case runTests
    case deployPreview
    case saveToKnowledge
    case switchMode(AgentMode)
    case custom(identifier: String, payload: String)
}
