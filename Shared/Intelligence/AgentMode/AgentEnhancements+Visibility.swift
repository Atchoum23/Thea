// AgentEnhancements+Visibility.swift
// Thea V2
//
// Task visibility, usage tracking, prompt enhancement, and checkpoints.

import Foundation
import OSLog

// MARK: - Task Visibility

/// Real-time task execution visibility
/// Inspired by Lovable's task visibility during agent execution
@MainActor
public final class AgentTaskVisibility: ObservableObject {
    public static let shared = AgentTaskVisibility()

    private let logger = Logger(subsystem: "com.thea.v2", category: "AgentTaskVisibility")

    @Published public var currentStep: AgentVisibilityTaskStep?
    @Published public var modifiedFiles: [AgentModifiedFile] = []
    @Published public var toolsUsed: [AgentToolUsage] = []
    @Published public var executionLog: [AgentExecutionLogEntry] = []
    @Published public var isExpanded: Bool = false

    private init() {}

    /// Update current step
    public func setCurrentStep(_ step: AgentVisibilityTaskStep) {
        currentStep = step
        addLogEntry(.stepStarted(step))
        logger.debug("Current step: \(step.description)")
    }

    /// Record file modification
    public func recordFileModification(_ file: AgentModifiedFile) {
        if let index = modifiedFiles.firstIndex(where: { $0.path == file.path }) {
            modifiedFiles[index] = file
        } else {
            modifiedFiles.append(file)
        }
        addLogEntry(.fileModified(file))
    }

    /// Record tool usage
    public func recordToolUsage(_ tool: AgentToolUsage) {
        toolsUsed.append(tool)
        addLogEntry(.toolUsed(tool))
    }

    /// Add log entry
    public func addLogEntry(_ entry: AgentExecutionLogEntry) {
        executionLog.append(entry)

        // Keep log size manageable
        if executionLog.count > 1000 {
            executionLog.removeFirst(100)
        }
    }

    /// Clear all tracking
    public func clear() {
        currentStep = nil
        modifiedFiles.removeAll()
        toolsUsed.removeAll()
        executionLog.removeAll()
    }
}

public struct AgentVisibilityTaskStep: Identifiable, Sendable {
    public let id: UUID
    public var description: String
    public var phase: AgentPhase
    public var startedAt: Date
    public var completedAt: Date?
    public var status: AgentStepStatus

    public init(
        id: UUID = UUID(),
        description: String,
        phase: AgentPhase,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        status: AgentStepStatus = .running
    ) {
        self.id = id
        self.description = description
        self.phase = phase
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
    }
}

public struct AgentModifiedFile: Identifiable, Sendable {
    public let id: UUID
    public var path: String
    public var modificationType: ModificationType
    public var linesAdded: Int
    public var linesRemoved: Int
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        path: String,
        modificationType: ModificationType,
        linesAdded: Int = 0,
        linesRemoved: Int = 0,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.path = path
        self.modificationType = modificationType
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.timestamp = timestamp
    }

    public enum ModificationType: String, Sendable {
        case created
        case modified
        case deleted
        case renamed
    }
}

public struct AgentToolUsage: Identifiable, Sendable {
    public let id: UUID
    public var toolName: String
    public var input: String
    public var output: String?
    public var duration: TimeInterval
    public var timestamp: Date
    public var success: Bool

    public init(
        id: UUID = UUID(),
        toolName: String,
        input: String,
        output: String? = nil,
        duration: TimeInterval = 0,
        timestamp: Date = Date(),
        success: Bool = true
    ) {
        self.id = id
        self.toolName = toolName
        self.input = input
        self.output = output
        self.duration = duration
        self.timestamp = timestamp
        self.success = success
    }
}

public enum AgentExecutionLogEntry: Identifiable, Sendable {
    case stepStarted(AgentVisibilityTaskStep)
    case stepCompleted(AgentVisibilityTaskStep)
    case fileModified(AgentModifiedFile)
    case toolUsed(AgentToolUsage)
    case error(String)
    case info(String)

    public var id: UUID {
        switch self {
        case .stepStarted(let step), .stepCompleted(let step): return step.id
        case .fileModified(let file): return file.id
        case .toolUsed(let tool): return tool.id
        case .error, .info: return UUID()
        }
    }

    public var timestamp: Date {
        switch self {
        case .stepStarted(let step), .stepCompleted(let step): return step.startedAt
        case .fileModified(let file): return file.timestamp
        case .toolUsed(let tool): return tool.timestamp
        case .error, .info: return Date()
        }
    }
}

// MARK: - Usage Tracking

/// Track token/credit usage per message
/// Inspired by Lovable's per-message cost display
@MainActor
public final class AgentUsageTracker: ObservableObject {
    public static let shared = AgentUsageTracker()

    private let logger = Logger(subsystem: "com.thea.v2", category: "AgentUsageTracker")

    @Published public private(set) var sessionUsage = AgentSessionUsage()
    @Published public private(set) var messageUsages: [UUID: AgentMessageUsage] = [:]

    private init() {}

    /// Record usage for a message
    public func recordUsage(
        messageId: UUID,
        promptTokens: Int,
        completionTokens: Int,
        model: String,
        cost: Double? = nil
    ) {
        let usage = AgentMessageUsage(
            messageId: messageId,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            model: model,
            cost: cost,
            timestamp: Date()
        )

        messageUsages[messageId] = usage
        sessionUsage.totalPromptTokens += promptTokens
        sessionUsage.totalCompletionTokens += completionTokens
        if let cost = cost {
            sessionUsage.totalCost += cost
        }
        sessionUsage.messageCount += 1

        logger.debug("Recorded usage for message \(messageId): \(promptTokens + completionTokens) tokens")
    }

    /// Get usage for specific message
    public func usage(for messageId: UUID) -> AgentMessageUsage? {
        messageUsages[messageId]
    }

    /// Reset session usage
    public func resetSession() {
        sessionUsage = AgentSessionUsage()
        messageUsages.removeAll()
        logger.info("Session usage reset")
    }
}

public struct AgentSessionUsage: Sendable {
    public var totalPromptTokens: Int = 0
    public var totalCompletionTokens: Int = 0
    public var totalCost: Double = 0.0
    public var messageCount: Int = 0
    public var startedAt = Date()

    public var totalTokens: Int {
        totalPromptTokens + totalCompletionTokens
    }
}

public struct AgentMessageUsage: Identifiable, Sendable {
    public var id: UUID { messageId }
    public let messageId: UUID
    public var promptTokens: Int
    public var completionTokens: Int
    public var model: String
    public var cost: Double?
    public var timestamp: Date

    public var totalTokens: Int {
        promptTokens + completionTokens
    }
}

// MARK: - Prompt Enhancement

/// Enhance user prompts for better results
/// Inspired by Bolt's "Enhance prompt" feature
public struct AgentPromptEnhancer {

    /// Enhance a user prompt with additional context and structure
    public static func enhance(_ prompt: String, context: AgentPromptContext) -> AgentEnhancedPrompt {
        var enhanced = prompt
        var suggestions: [String] = []

        // Add specificity suggestions
        if prompt.count < 50 {
            suggestions.append("Consider adding more detail about your requirements")
        }

        // Add technical context if relevant
        if context.hasCodeContext {
            enhanced = """
            Context: Working with \(context.language ?? "code") in \(context.framework ?? "the current project")

            \(prompt)
            """
        }

        // Add constraint suggestions
        if !prompt.lowercased().contains("should") && !prompt.lowercased().contains("must") {
            suggestions.append("Consider specifying constraints (e.g., 'should be responsive', 'must handle errors')")
        }

        return AgentEnhancedPrompt(
            original: prompt,
            enhanced: enhanced,
            suggestions: suggestions,
            addedContext: context
        )
    }
}

public struct AgentEnhancedPrompt: Sendable {
    public var original: String
    public var enhanced: String
    public var suggestions: [String]
    public var addedContext: AgentPromptContext
}

public struct AgentPromptContext: Sendable {
    public var hasCodeContext: Bool
    public var language: String?
    public var framework: String?
    public var projectName: String?
    public var relevantFiles: [String]

    public init(
        hasCodeContext: Bool = false,
        language: String? = nil,
        framework: String? = nil,
        projectName: String? = nil,
        relevantFiles: [String] = []
    ) {
        self.hasCodeContext = hasCodeContext
        self.language = language
        self.framework = framework
        self.projectName = projectName
        self.relevantFiles = relevantFiles
    }
}

// MARK: - Context Checkpoints

/// Save and restore context checkpoints
/// Inspired by Bolt's version history/backups
@MainActor
public final class AgentContextCheckpoints: ObservableObject {
    public static let shared = AgentContextCheckpoints()

    private let logger = Logger(subsystem: "com.thea.v2", category: "AgentContextCheckpoints")

    @Published public private(set) var checkpoints: [AgentContextCheckpoint] = []
    @Published public private(set) var autoCheckpoints: [AgentContextCheckpoint] = []

    private let maxAutoCheckpoints = 10

    private init() {}

    /// Create a manual checkpoint
    public func createCheckpoint(name: String, context: AgentConversationContext) -> AgentContextCheckpoint {
        let checkpoint = AgentContextCheckpoint(
            name: name,
            context: context,
            isAutomatic: false
        )
        checkpoints.append(checkpoint)
        logger.info("Created checkpoint: \(name)")
        return checkpoint
    }

    /// Create an automatic checkpoint
    public func createAutoCheckpoint(context: AgentConversationContext) {
        let checkpoint = AgentContextCheckpoint(
            name: "Auto-save \(ISO8601DateFormatter().string(from: Date()))",
            context: context,
            isAutomatic: true
        )
        autoCheckpoints.append(checkpoint)

        // Maintain max auto checkpoints
        while autoCheckpoints.count > maxAutoCheckpoints {
            autoCheckpoints.removeFirst()
        }

        logger.debug("Created auto checkpoint")
    }

    /// Restore from checkpoint
    public func restore(_ checkpoint: AgentContextCheckpoint) -> AgentConversationContext {
        logger.info("Restoring checkpoint: \(checkpoint.name)")
        return checkpoint.context
    }

    /// Fork from checkpoint (create new conversation branch)
    public func fork(_ checkpoint: AgentContextCheckpoint, newName: String) -> AgentContextCheckpoint {
        var forked = checkpoint
        forked.id = UUID()
        forked.name = newName
        forked.createdAt = Date()
        forked.isAutomatic = false
        checkpoints.append(forked)
        logger.info("Forked checkpoint '\(checkpoint.name)' as '\(newName)'")
        return forked
    }

    /// Delete checkpoint
    public func delete(_ checkpoint: AgentContextCheckpoint) {
        checkpoints.removeAll { $0.id == checkpoint.id }
        autoCheckpoints.removeAll { $0.id == checkpoint.id }
        logger.info("Deleted checkpoint: \(checkpoint.name)")
    }
}

public struct AgentContextCheckpoint: Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var context: AgentConversationContext
    public var createdAt = Date()
    public var isAutomatic: Bool
}

/// Lightweight chat message for agent conversation context
public struct ChatMessage: Codable, Sendable {
    public let role: String
    public let content: String
    public let timestamp: Date

    public init(role: String, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// Conversation context for checkpointing
public struct AgentConversationContext: Codable, Sendable {
    public var messages: [ChatMessage]
    public var artifacts: [AgentModeArtifact]
    public var taskGroups: [TaskGroup]
    public var mode: AgentMode
    public var phase: AgentPhase

    public init(
        messages: [ChatMessage] = [],
        artifacts: [AgentModeArtifact] = [],
        taskGroups: [TaskGroup] = [],
        mode: AgentMode = .auto,
        phase: AgentPhase = .gatherContext
    ) {
        self.messages = messages
        self.artifacts = artifacts
        self.taskGroups = taskGroups
        self.mode = mode
        self.phase = phase
    }
}
