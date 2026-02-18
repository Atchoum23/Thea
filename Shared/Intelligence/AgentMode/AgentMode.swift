// AgentMode.swift
// Thea V2
//
// Agent execution modes inspired by modern AI assistant patterns:
// - Antigravity (Google): Planning vs Fast modes
// - Claude Code: Agentic loop (gather context → take action → verify)
// - Cursor: Subagents with specialized capabilities

import Foundation
import OSLog

// MARK: - Agent Mode

/// Agent execution mode controlling how Thea approaches tasks
public enum AgentMode: String, Codable, Sendable, CaseIterable {
    /// Planning mode: For complex tasks requiring research, decomposition, and verification
    /// Agent creates task groups, produces artifacts, and plans before executing
    case planning

    /// Fast mode: For simple tasks that can be completed quickly
    /// Agent executes directly without extensive planning
    case fast

    /// Auto mode: Let Thea decide based on task complexity
    case auto

    public var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .fast: return "Fast"
        case .auto: return "Auto"
        }
    }

    public var description: String {
        switch self {
        case .planning:
            return "Deep research, complex tasks, or collaborative work. Agent plans before executing."
        case .fast:
            return "Simple tasks completed quickly without extensive planning."
        case .auto:
            return "Automatically choose mode based on task complexity."
        }
    }

    /// Recommended for task type
    public static func recommended(for taskType: TaskType) -> AgentMode {
        switch taskType {
        case .codeGeneration, .codeRefactoring, .debugging, .research, .analysis:
            return .planning
        case .simpleQA, .factual, .translation:
            return .fast
        default:
            return .auto
        }
    }
}

// MARK: - Agent Phase (Agentic Loop)

/// Phase in the agentic execution loop
/// Based on Claude Code's three-phase approach
public enum AgentPhase: String, Codable, Sendable {
    /// Gathering context: Understanding codebase, searching files, researching
    case gatherContext

    /// Taking action: Making changes, writing code, executing commands
    case takeAction

    /// Verifying results: Running tests, checking for errors, validating changes
    case verifyResults

    /// Completed: Task finished
    case done

    /// User interrupted or steering
    case userIntervention

    public var displayName: String {
        switch self {
        case .gatherContext: return "Gathering Context"
        case .takeAction: return "Taking Action"
        case .verifyResults: return "Verifying Results"
        case .done: return "Done"
        case .userIntervention: return "User Input"
        }
    }
}

// MARK: - Agent Execution State

/// Current state of agent execution
/// Observable state machine tracking the current agent execution progress and all active tasks.
@MainActor
public final class AgentExecutionState: ObservableObject {
    @Published public var mode: AgentMode = .auto
    @Published public var phase: AgentPhase = .gatherContext
    @Published public var currentTask: AgentModeTask?
    @Published public var taskGroups: [TaskGroup] = []
    @Published public var artifacts: [AgentModeArtifact] = []
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var canInterrupt: Bool = true

    private let logger = Logger(subsystem: "com.thea.v2", category: "AgentExecutionState")

    public init() {}

    /// Transition to next phase
    public func transition(to phase: AgentPhase) {
        self.phase = phase
        logger.debug("Agent transitioned to phase: \(phase.rawValue)")

        EventBus.shared.publish(StateEvent(
            source: .system,
            component: "AgentExecution",
            previousState: self.phase.rawValue,
            newState: phase.rawValue,
            reason: "Phase transition"
        ))
    }

    /// Add a task group
    public func addTaskGroup(_ group: TaskGroup) {
        taskGroups.append(group)
        logger.debug("Added task group: \(group.title)")
    }

    /// Add an artifact
    public func addArtifact(_ artifact: AgentModeArtifact) {
        artifacts.append(artifact)
        logger.debug("Added artifact: \(artifact.title)")
    }

    /// Update progress
    public func updateProgress(_ value: Double, message: String? = nil) {
        progress = min(1.0, max(0.0, value))
        if let msg = message {
            statusMessage = msg
        }
    }

    /// Reset state for new task
    public func reset() {
        phase = .gatherContext
        currentTask = nil
        taskGroups.removeAll()
        artifacts.removeAll()
        progress = 0.0
        statusMessage = ""
        canInterrupt = true
    }
}

// MARK: - Task Group

/// A group of related subtasks for complex operations
/// Inspired by Antigravity's Task Groups
public struct TaskGroup: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var subtasks: [AgentSubtask]
    public var status: TaskGroupStatus
    public var createdAt: Date
    public var completedAt: Date?
    public var editedFiles: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        subtasks: [AgentSubtask] = [],
        status: TaskGroupStatus = .pending,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        editedFiles: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.subtasks = subtasks
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.editedFiles = editedFiles
    }

    public var progress: Double {
        guard !subtasks.isEmpty else { return 0 }
        let completed = subtasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(subtasks.count)
    }
}

/// Lifecycle status of a task group within the agent execution pipeline.
public enum TaskGroupStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled
}

// MARK: - Agent Subtask

/// A specific subtask within a task group
public struct AgentSubtask: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var status: SubtaskStatus
    public var steps: [AgentStep]
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        status: SubtaskStatus = .pending,
        steps: [AgentStep] = [],
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.steps = steps
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// Execution status of a single subtask within a task group.
public enum SubtaskStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
    case skipped
}

// MARK: - Agent Step

/// A single step within a subtask
public struct AgentStep: Identifiable, Codable, Sendable {
    public let id: UUID
    public var action: String
    public var details: String?
    public var status: AgentStepStatus
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        action: String,
        details: String? = nil,
        status: AgentStepStatus = .pending,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.details = details
        self.status = status
        self.timestamp = timestamp
    }
}

/// Execution status of an individual step within a subtask.
public enum AgentStepStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

// MARK: - Agent Mode Task

/// A high-level task being executed by the agent
public struct AgentModeTask: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var userQuery: String
    public var taskType: TaskType
    public var mode: AgentMode
    public var startedAt: Date
    public var completedAt: Date?
    public var status: AgentModeTaskStatus

    public init(
        id: UUID = UUID(),
        title: String,
        userQuery: String,
        taskType: TaskType,
        mode: AgentMode = .auto,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        status: AgentModeTaskStatus = .running
    ) {
        self.id = id
        self.title = title
        self.userQuery = userQuery
        self.taskType = taskType
        self.mode = mode
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
    }
}

/// Top-level execution status of an agent mode task.
public enum AgentModeTaskStatus: String, Codable, Sendable {
    case pending
    case running
    case awaitingReview
    case completed
    case failed
    case cancelled
}

// MARK: - Agent Mode Artifact

/// An artifact produced by the agent during execution
/// Inspired by Antigravity's artifacts system
public struct AgentModeArtifact: Identifiable, Codable, Sendable {
    public let id: UUID
    public var type: AgentArtifactType
    public var title: String
    public var content: String
    public var filePath: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        type: AgentArtifactType,
        title: String,
        content: String,
        filePath: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.filePath = filePath
        self.createdAt = createdAt
    }
}

/// The category of content produced by an agent artifact.
public enum AgentArtifactType: String, Codable, Sendable, CaseIterable {
    case implementationPlan   // Planning document
    case taskList             // List of tasks to complete
    case walkthrough          // Step-by-step explanation
    case codeSnippet          // Generated code
    case documentation        // Generated docs
    case analysis             // Analysis results
    case screenshot           // Screenshot capture
    case recording            // Browser/screen recording
    case knowledge            // Learned knowledge item

    public var displayName: String {
        switch self {
        case .implementationPlan: return "Implementation Plan"
        case .taskList: return "Task List"
        case .walkthrough: return "Walkthrough"
        case .codeSnippet: return "Code Snippet"
        case .documentation: return "Documentation"
        case .analysis: return "Analysis"
        case .screenshot: return "Screenshot"
        case .recording: return "Recording"
        case .knowledge: return "Knowledge"
        }
    }
}

// MARK: - Artifact Review Policy

/// Policy for reviewing artifacts before agent proceeds
/// Inspired by Antigravity's Artifact Review Policy
public enum ArtifactReviewPolicy: String, Codable, Sendable {
    /// Agent never asks for review, proceeds automatically
    case alwaysProceed

    /// Agent always asks for review before proceeding
    case requestReview

    /// Agent asks for review only for implementation plans
    case reviewPlansOnly

    public var displayName: String {
        switch self {
        case .alwaysProceed: return "Always Proceed"
        case .requestReview: return "Request Review"
        case .reviewPlansOnly: return "Review Plans Only"
        }
    }

    public var description: String {
        switch self {
        case .alwaysProceed:
            return "Agent proceeds without asking for review."
        case .requestReview:
            return "Agent always asks for review before making changes."
        case .reviewPlansOnly:
            return "Agent asks for review only for implementation plans."
        }
    }
}

// MARK: - Terminal Command Execution Policy

/// Policy for executing terminal commands
/// Inspired by Antigravity's Terminal Command Auto Execution
public enum TerminalExecutionPolicy: String, Codable, Sendable {
    /// Never auto-execute commands (except those in allow list)
    case requestReview

    /// Always auto-execute commands (except those in deny list)
    case alwaysProceed

    public var displayName: String {
        switch self {
        case .requestReview: return "Request Review"
        case .alwaysProceed: return "Always Proceed"
        }
    }
}

// MARK: - Agent Settings

/// Settings for agent behavior
public struct AgentSettings: Codable, Sendable {
    public var defaultMode: AgentMode
    public var artifactReviewPolicy: ArtifactReviewPolicy
    public var terminalExecutionPolicy: TerminalExecutionPolicy
    public var allowedCommands: [String]
    public var deniedCommands: [String]
    public var nonWorkspaceFileAccess: Bool

    public init(
        defaultMode: AgentMode = .auto,
        artifactReviewPolicy: ArtifactReviewPolicy = .reviewPlansOnly,
        terminalExecutionPolicy: TerminalExecutionPolicy = .requestReview,
        allowedCommands: [String] = ["ls", "cat", "pwd", "echo", "git status", "git diff"],
        deniedCommands: [String] = ["rm -rf", "sudo", "chmod", "chown"],
        nonWorkspaceFileAccess: Bool = false
    ) {
        self.defaultMode = defaultMode
        self.artifactReviewPolicy = artifactReviewPolicy
        self.terminalExecutionPolicy = terminalExecutionPolicy
        self.allowedCommands = allowedCommands
        self.deniedCommands = deniedCommands
        self.nonWorkspaceFileAccess = nonWorkspaceFileAccess
    }

    public static let `default` = AgentSettings()
}
