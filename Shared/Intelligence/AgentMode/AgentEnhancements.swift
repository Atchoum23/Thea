// AgentEnhancements.swift
// Thea V2
//
// Enhanced agent features inspired by modern AI assistants:
// - Lovable: Plan persistence, clarifying questions, message queue, task visibility
// - Bolt: Project/Account knowledge, prompt enhancement, version history
// - Vapi: Multi-agent squads with handoffs
// - HuggingFace smolagents: CodeAgent pattern, human-in-the-loop

import Foundation
import OSLog

// MARK: - Plan Persistence

/// Manages plan persistence to workspace files
/// Inspired by Lovable's .lovable/plan.md pattern
@MainActor
public final class AgentPlanPersistence: ObservableObject {
    public static let shared = AgentPlanPersistence()

    private let logger = Logger(subsystem: "com.thea.v2", category: "AgentPlanPersistence")
    private let planFileName = "plan.md"
    private let planHistoryFileName = "plan_history.json"

    @Published public private(set) var currentPlan: AgentImplementationPlan?
    @Published public private(set) var planHistory: [AgentImplementationPlan] = []

    private init() {}

    /// Save plan to workspace .thea/plan.md
    public func savePlan(_ plan: AgentImplementationPlan, to workspacePath: URL) async throws {
        let theaDir = workspacePath.appendingPathComponent(".thea")

        // Create .thea directory if needed
        if !FileManager.default.fileExists(atPath: theaDir.path) {
            try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        }

        // Save current plan as markdown
        let planPath = theaDir.appendingPathComponent(planFileName)
        let markdown = plan.toMarkdown()
        try markdown.write(to: planPath, atomically: true, encoding: .utf8)

        // Add to history
        var updatedHistory = planHistory
        updatedHistory.append(plan)

        // Save history as JSON
        let historyPath = theaDir.appendingPathComponent(planHistoryFileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let historyData = try encoder.encode(updatedHistory)
        try historyData.write(to: historyPath)

        currentPlan = plan
        planHistory = updatedHistory

        logger.info("Saved plan to \(planPath.path)")
    }

    /// Load plan from workspace
    public func loadPlan(from workspacePath: URL) async throws {
        let theaDir = workspacePath.appendingPathComponent(".thea")
        let historyPath = theaDir.appendingPathComponent(planHistoryFileName)

        guard FileManager.default.fileExists(atPath: historyPath.path) else {
            logger.debug("No plan history found at \(historyPath.path)")
            return
        }

        let data = try Data(contentsOf: historyPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        planHistory = try decoder.decode([AgentImplementationPlan].self, from: data)
        currentPlan = planHistory.last

        logger.info("Loaded \(self.planHistory.count) plans from history")
    }
}

/// A structured implementation plan
/// Inspired by Lovable's plan document format
public struct AgentImplementationPlan: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var overview: String
    public var keyDecisions: [AgentKeyDecision]
    public var components: [AgentPlanComponent]
    public var dataModels: [AgentDataModel]
    public var apiEndpoints: [AgentPlanAPIEndpoint]
    public var implementationSteps: [AgentPlanImplementationStep]
    public var diagrams: [AgentPlanDiagram]
    public var status: AgentPlanStatus
    public var createdAt: Date
    public var approvedAt: Date?
    public var approvedBy: String?

    public init(
        id: UUID = UUID(),
        title: String,
        overview: String,
        keyDecisions: [AgentKeyDecision] = [],
        components: [AgentPlanComponent] = [],
        dataModels: [AgentDataModel] = [],
        apiEndpoints: [AgentPlanAPIEndpoint] = [],
        implementationSteps: [AgentPlanImplementationStep] = [],
        diagrams: [AgentPlanDiagram] = [],
        status: AgentPlanStatus = .draft,
        createdAt: Date = Date(),
        approvedAt: Date? = nil,
        approvedBy: String? = nil
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.keyDecisions = keyDecisions
        self.components = components
        self.dataModels = dataModels
        self.apiEndpoints = apiEndpoints
        self.implementationSteps = implementationSteps
        self.diagrams = diagrams
        self.status = status
        self.createdAt = createdAt
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
    }

    /// Convert plan to markdown format
    public func toMarkdown() -> String {
        var md = """
        # \(title)

        > Status: \(status.displayName)
        > Created: \(ISO8601DateFormatter().string(from: createdAt))

        ## Overview

        \(overview)

        """

        if !keyDecisions.isEmpty {
            md += "\n## Key Decisions\n\n"
            for decision in keyDecisions {
                md += "### \(decision.title)\n\n"
                md += "\(decision.description)\n\n"
                if let rationale = decision.rationale {
                    md += "_Rationale: \(rationale)_\n\n"
                }
            }
        }

        if !components.isEmpty {
            md += "\n## Components\n\n"
            for component in components {
                md += "- **\(component.name)**: \(component.description)\n"
            }
            md += "\n"
        }

        if !implementationSteps.isEmpty {
            md += "\n## Implementation Steps\n\n"
            for (index, step) in implementationSteps.enumerated() {
                let checkbox = step.completed ? "[x]" : "[ ]"
                md += "\(index + 1). \(checkbox) \(step.title)\n"
                if !step.details.isEmpty {
                    md += "   - \(step.details)\n"
                }
            }
        }

        return md
    }
}

public enum AgentPlanStatus: String, Codable, Sendable {
    case draft
    case pendingReview
    case approved
    case implementing
    case completed
    case rejected

    public var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .pendingReview: return "Pending Review"
        case .approved: return "Approved"
        case .implementing: return "Implementing"
        case .completed: return "Completed"
        case .rejected: return "Rejected"
        }
    }
}

public struct AgentKeyDecision: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var rationale: String?
    public var alternatives: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        rationale: String? = nil,
        alternatives: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.rationale = rationale
        self.alternatives = alternatives
    }
}

public struct AgentPlanComponent: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var filePath: String?
    public var dependencies: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        filePath: String? = nil,
        dependencies: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.filePath = filePath
        self.dependencies = dependencies
    }
}

public struct AgentDataModel: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var fields: [AgentModelField]
    public var relationships: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        fields: [AgentModelField] = [],
        relationships: [String] = []
    ) {
        self.id = id
        self.name = name
        self.fields = fields
        self.relationships = relationships
    }
}

public struct AgentModelField: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: String
    public var isOptional: Bool

    public init(id: UUID = UUID(), name: String, type: String, isOptional: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.isOptional = isOptional
    }
}

public struct AgentPlanAPIEndpoint: Identifiable, Codable, Sendable {
    public let id: UUID
    public var method: String
    public var path: String
    public var description: String

    public init(id: UUID = UUID(), method: String, path: String, description: String) {
        self.id = id
        self.method = method
        self.path = path
        self.description = description
    }
}

public struct AgentPlanImplementationStep: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var details: String
    public var completed: Bool
    public var order: Int

    public init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        completed: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.completed = completed
        self.order = order
    }
}

public struct AgentPlanDiagram: Identifiable, Codable, Sendable {
    public let id: UUID
    public var type: DiagramType
    public var title: String
    public var content: String  // Mermaid or ASCII art

    public init(id: UUID = UUID(), type: DiagramType, title: String, content: String) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
    }

    public enum DiagramType: String, Codable, Sendable {
        case flowchart
        case sequence
        case entityRelationship
        case architecture
        case stateChart
    }
}

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
