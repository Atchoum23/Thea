// WorkflowEngineTypes.swift
// n8n-style workflow automation types for Thea
// Extracted from WorkflowEngine.swift for file_length compliance.

import Foundation

// MARK: - Automation Workflow Types

/// A complete automation workflow definition
struct AutomationWorkflow: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var nodes: [AutomationNode]
    var connections: [Connection]
    var trigger: AutomationWorkflowTrigger
    var isEnabled: Bool
    var createdAt: Date
    var lastModified: Date
    var lastRun: Date?
    var runCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        nodes: [AutomationNode] = [],
        connections: [Connection] = [],
        trigger: AutomationWorkflowTrigger = .manual,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.nodes = nodes
        self.connections = connections
        self.trigger = trigger
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.lastModified = Date()
        self.lastRun = nil
        // periphery:ignore - Reserved: init(id:name:description:nodes:connections:trigger:isEnabled:) initializer reserved for future feature activation
        self.runCount = 0
    }
}

/// A node in the automation workflow
struct AutomationNode: Identifiable, Codable, Sendable {
    let id: UUID
    var type: AutomationNodeType
    var name: String
    var position: Position
    var configuration: NodeConfiguration
    var isEnabled: Bool

    struct Position: Codable, Sendable {
        var x: Double
        var y: Double
    }

    // periphery:ignore - Reserved: init(id:type:name:position:configuration:isEnabled:) initializer — reserved for future feature activation
    init(
        id: UUID = UUID(),
        type: AutomationNodeType,
        name: String,
        position: Position = Position(x: 0, y: 0),
        configuration: NodeConfiguration = NodeConfiguration(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.position = position
        self.configuration = configuration
        self.isEnabled = isEnabled
    }
}

// periphery:ignore - Reserved: init(id:type:name:position:configuration:isEnabled:) initializer reserved for future feature activation
/// Types of automation nodes available
enum AutomationNodeType: String, Codable, Sendable, CaseIterable {
    case llmPrompt = "LLM Prompt"
    case httpRequest = "HTTP Request"
    case fileRead = "Read File"
    case fileWrite = "Write File"
    case conditional = "Conditional"
    case loop = "Loop"
    case aggregate = "Aggregate"
    case transform = "Transform"
    case delay = "Delay"
    case subWorkflow = "Sub-Workflow"
    case notification = "Notification"
    case codeExecute = "Execute Code"

    var icon: String {
        switch self {
        case .llmPrompt: "🤖"
        case .httpRequest: "🌐"
        case .fileRead: "📖"
        case .fileWrite: "✍️"
        case .conditional: "❓"
        case .loop: "🔄"
        case .aggregate: "📊"
        case .transform: "🔀"
        case .delay: "⏱️"
        case .subWorkflow: "📦"
        case .notification: "🔔"
        case .codeExecute: "💻"
        }
    }

    var category: AutomationNodeCategory {
        switch self {
        case .llmPrompt: .ai
        case .httpRequest: .integration
        case .fileRead, .fileWrite: .file
        case .conditional, .loop: .logic
        case .aggregate, .transform: .data
        case .delay: .utility
        case .subWorkflow: .workflow
        case .notification: .action
        case .codeExecute: .advanced
        }
    }
}

enum AutomationNodeCategory: String, Sendable {
    case ai = "AI"
    case integration = "Integration"
    case file = "File"
    case logic = "Logic"
    case data = "Data"
    case utility = "Utility"
    case workflow = "Workflow"
    case action = "Action"
    case advanced = "Advanced"
}

/// Node configuration
struct NodeConfiguration: Codable, Sendable {
    var parameters: [String: String]
    var retryCount: Int
    var timeout: TimeInterval
    var continueOnError: Bool

    // periphery:ignore - Reserved: init(parameters:retryCount:timeout:continueOnError:) initializer — reserved for future feature activation
    init(
        parameters: [String: String] = [:],
        retryCount: Int = 0,
        timeout: TimeInterval = 30,
        continueOnError: Bool = false
    ) {
        self.parameters = parameters
        self.retryCount = retryCount
        self.timeout = timeout
        self.continueOnError = continueOnError
    }
}

/// Connection between nodes
struct Connection: Identifiable, Codable, Sendable {
    let id: UUID
    var sourceNodeId: UUID
    // periphery:ignore - Reserved: init(parameters:retryCount:timeout:continueOnError:) initializer reserved for future feature activation
    var targetNodeId: UUID
    var sourcePort: String
    var targetPort: String
    var condition: String?

    // periphery:ignore - Reserved: init(id:sourceNodeId:targetNodeId:sourcePort:targetPort:condition:) initializer — reserved for future feature activation
    init(
        id: UUID = UUID(),
        sourceNodeId: UUID,
        targetNodeId: UUID,
        sourcePort: String = "output",
        targetPort: String = "input",
        condition: String? = nil
    ) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.sourcePort = sourcePort
        self.targetPort = targetPort
        self.condition = condition
    }
}

// periphery:ignore - Reserved: init(id:sourceNodeId:targetNodeId:sourcePort:targetPort:condition:) initializer reserved for future feature activation

/// Workflow trigger types
enum AutomationWorkflowTrigger: Codable, Sendable {
    case manual
    case schedule(cron: String)
    case webhook(path: String)
    case fileChange(path: String)
    case voiceCommand(phrase: String)
    case shortcut(name: String)
}

// MARK: - Execution Types

/// Result of workflow execution
struct AutomationWorkflowResult: Sendable {
    // periphery:ignore - Reserved: workflowId property — reserved for future feature activation
    let workflowId: UUID
    let startTime: Date
    let endTime: Date
    // periphery:ignore - Reserved: manual case reserved for future feature activation
    // periphery:ignore - Reserved: schedule(cron:) case reserved for future feature activation
    // periphery:ignore - Reserved: webhook(path:) case reserved for future feature activation
    // periphery:ignore - Reserved: fileChange(path:) case reserved for future feature activation
    // periphery:ignore - Reserved: voiceCommand(phrase:) case reserved for future feature activation
    // periphery:ignore - Reserved: shortcut(name:) case reserved for future feature activation
    let status: AutomationExecutionStatus
    // periphery:ignore - Reserved: nodeResults property — reserved for future feature activation
    let nodeResults: [UUID: NodeResult]
    // periphery:ignore - Reserved: error property — reserved for future feature activation
    let error: String?

    // periphery:ignore - Reserved: duration property — reserved for future feature activation
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    // periphery:ignore - Reserved: workflowId property reserved for future feature activation
    }
}

// periphery:ignore - Reserved: nodeResults property reserved for future feature activation
// periphery:ignore - Reserved: error property reserved for future feature activation
struct NodeResult: Sendable {
    // periphery:ignore - Reserved: duration property reserved for future feature activation
    let nodeId: UUID
    let status: AutomationExecutionStatus
    let output: String?
    let error: String?
    let duration: TimeInterval
// periphery:ignore - Reserved: nodeId property reserved for future feature activation
// periphery:ignore - Reserved: status property reserved for future feature activation
// periphery:ignore - Reserved: output property reserved for future feature activation
// periphery:ignore - Reserved: error property reserved for future feature activation
// periphery:ignore - Reserved: duration property reserved for future feature activation
}

enum AutomationExecutionStatus: String, Sendable {
    case pending = "Pending"
    case running = "Running"
    case success = "Success"
    case failed = "Failed"
    case skipped = "Skipped"
    case cancelled = "Cancelled"
}

// MARK: - Errors

// periphery:ignore - Reserved: AutomationWorkflowError type reserved for future feature activation
enum AutomationWorkflowError: Error, LocalizedError {
    case invalidConfiguration(String)
    case executionFailed(String)
    case unsupportedOperation(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let msg): "Invalid configuration: \(msg)"
        case .executionFailed(let msg): "Execution failed: \(msg)"
        case .unsupportedOperation(let msg): "Unsupported: \(msg)"
        case .timeout: "Operation timed out"
        }
    }
}
