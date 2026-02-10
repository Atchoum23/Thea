// WorkflowEngine.swift
// n8n-style workflow automation engine for Thea
// Enables visual workflow building and LLM-powered automation
// Differs from n8n by using pure LLM orchestration
// Note: Uses AutomationWorkflow prefix to avoid conflicts with MetaAI/WorkflowBuilder

import Foundation
import Combine
#if canImport(UserNotifications)
import UserNotifications
#endif

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
    var targetNodeId: UUID
    var sourcePort: String
    var targetPort: String
    var condition: String?

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
    let workflowId: UUID
    let startTime: Date
    let endTime: Date
    let status: AutomationExecutionStatus
    let nodeResults: [UUID: NodeResult]
    let error: String?

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct NodeResult: Sendable {
    let nodeId: UUID
    let status: AutomationExecutionStatus
    let output: String?
    let error: String?
    let duration: TimeInterval
}

enum AutomationExecutionStatus: String, Sendable {
    case pending = "Pending"
    case running = "Running"
    case success = "Success"
    case failed = "Failed"
    case skipped = "Skipped"
    case cancelled = "Cancelled"
}

// MARK: - Workflow Engine

/// Main workflow execution engine
@MainActor
@Observable
final class WorkflowEngine {
    static let shared = WorkflowEngine()

    // State
    private(set) var workflows: [AutomationWorkflow] = []
    private(set) var isExecuting = false
    private(set) var currentWorkflowId: UUID?
    private(set) var executionProgress: Double = 0
    private(set) var executionHistory: [AutomationWorkflowResult] = []

    // Callbacks
    var onWorkflowComplete: ((AutomationWorkflowResult) -> Void)?
    var onNodeProgress: ((UUID, AutomationExecutionStatus) -> Void)?
    var onError: ((Error) -> Void)?

    // Internal
    private var runningTasks: [UUID: Task<Void, Never>] = [:]

    private init() {
        loadWorkflows()
    }

    // MARK: - Workflow Management

    /// Create a new workflow
    func createWorkflow(name: String, description: String = "") -> AutomationWorkflow {
        let workflow = AutomationWorkflow(name: name, description: description)
        workflows.append(workflow)
        saveWorkflows()
        return workflow
    }

    /// Update a workflow
    func updateWorkflow(_ workflow: AutomationWorkflow) {
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            var updated = workflow
            updated.lastModified = Date()
            workflows[index] = updated
            saveWorkflows()
        }
    }

    /// Delete a workflow
    func deleteWorkflow(id: UUID) {
        workflows.removeAll { $0.id == id }
        saveWorkflows()
    }

    /// Get a workflow by ID
    func getWorkflow(id: UUID) -> AutomationWorkflow? {
        workflows.first { $0.id == id }
    }

    // MARK: - Workflow Execution

    /// Execute a workflow
    func execute(_ workflow: AutomationWorkflow, input: [String: Any] = [:]) async -> AutomationWorkflowResult {
        let startTime = Date()
        currentWorkflowId = workflow.id
        isExecuting = true
        executionProgress = 0

        var nodeResults: [UUID: NodeResult] = [:]
        var context: [String: Any] = input
        var hasError = false
        var errorMessage: String?

        // Build execution order (topological sort)
        let orderedNodes = topologicalSort(workflow)

        for (index, node) in orderedNodes.enumerated() where node.isEnabled {
            onNodeProgress?(node.id, .running)

            let nodeStart = Date()
            do {
                let output = try await executeNode(node, context: context)
                context[node.id.uuidString] = output

                nodeResults[node.id] = NodeResult(
                    nodeId: node.id,
                    status: .success,
                    output: output,
                    error: nil,
                    duration: Date().timeIntervalSince(nodeStart)
                )
                onNodeProgress?(node.id, .success)
            } catch {
                let result = NodeResult(
                    nodeId: node.id,
                    status: .failed,
                    output: nil,
                    error: error.localizedDescription,
                    duration: Date().timeIntervalSince(nodeStart)
                )
                nodeResults[node.id] = result
                onNodeProgress?(node.id, .failed)

                if !node.configuration.continueOnError {
                    hasError = true
                    errorMessage = error.localizedDescription
                    break
                }
            }

            executionProgress = Double(index + 1) / Double(orderedNodes.count)
        }

        let result = AutomationWorkflowResult(
            workflowId: workflow.id,
            startTime: startTime,
            endTime: Date(),
            status: hasError ? .failed : .success,
            nodeResults: nodeResults,
            error: errorMessage
        )

        // Update workflow stats
        if var updated = getWorkflow(id: workflow.id) {
            updated.lastRun = Date()
            updated.runCount += 1
            updateWorkflow(updated)
        }

        executionHistory.insert(result, at: 0)
        if executionHistory.count > 100 {
            executionHistory = Array(executionHistory.prefix(100))
        }

        isExecuting = false
        currentWorkflowId = nil
        onWorkflowComplete?(result)

        return result
    }

    /// Cancel running workflow
    func cancelExecution() {
        runningTasks.values.forEach { $0.cancel() }
        runningTasks.removeAll()
        isExecuting = false
        currentWorkflowId = nil
    }

    // MARK: - Node Execution

    private func executeNode(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        switch node.type {
        case .llmPrompt:
            return try await executeLLMPrompt(node, context: context)
        case .httpRequest:
            return try await executeHTTPRequest(node, context: context)
        case .fileRead:
            return try await executeFileRead(node, context: context)
        case .fileWrite:
            return try await executeFileWrite(node, context: context)
        case .conditional:
            return try await executeConditional(node, context: context)
        case .loop:
            return try await executeLoop(node, context: context)
        case .aggregate:
            return try await executeAggregate(node, context: context)
        case .transform:
            return try await executeTransform(node, context: context)
        case .delay:
            return try await executeDelay(node, context: context)
        case .notification:
            return try await executeNotification(node, context: context)
        case .subWorkflow:
            return try await executeSubWorkflow(node, context: context)
        case .codeExecute:
            return try await executeCode(node, context: context)
        }
    }

    private func executeLLMPrompt(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        let prompt = node.configuration.parameters["prompt"] ?? ""
        let modelName = node.configuration.parameters["model"] ?? "default"
        let systemPrompt = node.configuration.parameters["systemPrompt"]
        let temperatureStr = node.configuration.parameters["temperature"]
        _ = temperatureStr.flatMap { Double($0) }

        // Interpolate context variables
        let interpolatedPrompt = interpolate(prompt, with: context)

        // Get provider from registry
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw AutomationWorkflowError.executionFailed("No AI provider available")
        }

        // Resolve model - use specified model or default
        let model: String
        if modelName == "default" || modelName.isEmpty {
            model = "gpt-4o" // Fallback default
        } else {
            model = modelName
        }

        // Build messages
        var messages: [AIMessage] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            messages.append(AIMessage(
                id: UUID(), conversationID: UUID(), role: .system,
                content: .text(systemPrompt), timestamp: Date(), model: model
            ))
        }
        messages.append(AIMessage(
            id: UUID(), conversationID: UUID(), role: .user,
            content: .text(interpolatedPrompt), timestamp: Date(), model: model
        ))

        // Execute LLM call
        let stream = try await provider.chat(messages: messages, model: model, stream: false)
        var result = ""
        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text): result += text
            case .complete(let msg): result = msg.content.textValue
            case .error(let err): throw err
            }
        }
        return result
    }

    private func executeHTTPRequest(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        guard let urlString = node.configuration.parameters["url"],
              let url = URL(string: interpolate(urlString, with: context)) else {
            throw AutomationWorkflowError.invalidConfiguration("Invalid URL")
        }

        let method = node.configuration.parameters["method"] ?? "GET"
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = node.configuration.timeout

        if let headers = node.configuration.parameters["headers"] {
            for header in headers.components(separatedBy: "\n") {
                let parts = header.components(separatedBy: ":")
                if parts.count == 2 {
                    request.addValue(parts[1].trimmingCharacters(in: .whitespaces),
                                   forHTTPHeaderField: parts[0].trimmingCharacters(in: .whitespaces))
                }
            }
        }

        if let body = node.configuration.parameters["body"], method != "GET" {
            request.httpBody = interpolate(body, with: context).data(using: .utf8)
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func executeFileRead(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        guard let path = node.configuration.parameters["path"] else {
            throw AutomationWorkflowError.invalidConfiguration("No file path specified")
        }

        let interpolatedPath = interpolate(path, with: context)
        return try String(contentsOfFile: interpolatedPath, encoding: .utf8)
    }

    private func executeFileWrite(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        guard let path = node.configuration.parameters["path"],
              let content = node.configuration.parameters["content"] else {
            throw AutomationWorkflowError.invalidConfiguration("Missing path or content")
        }

        let interpolatedPath = interpolate(path, with: context)
        let interpolatedContent = interpolate(content, with: context)

        try interpolatedContent.write(toFile: interpolatedPath, atomically: true, encoding: .utf8)
        return "File written successfully"
    }

    private func executeConditional(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        guard let condition = node.configuration.parameters["condition"] else {
            throw AutomationWorkflowError.invalidConfiguration("No condition specified")
        }

        let interpolated = interpolate(condition, with: context)
        // Simple evaluation - in production, use proper expression parser
        let result = evaluateCondition(interpolated)
        return result ? "true" : "false"
    }

    private func executeLoop(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        guard let items = node.configuration.parameters["items"] else {
            throw AutomationWorkflowError.invalidConfiguration("No items to loop over")
        }

        let interpolated = interpolate(items, with: context)
        let itemList = interpolated.components(separatedBy: ",")
        return "Processed \(itemList.count) items"
    }

    private func executeAggregate(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        let strategy = node.configuration.parameters["strategy"] ?? "join"
        let inputs = context.values.compactMap { $0 as? String }

        switch strategy {
        case "join":
            let separator = node.configuration.parameters["separator"] ?? "\n"
            return inputs.joined(separator: separator)
        case "count":
            return String(inputs.count)
        case "first":
            return inputs.first ?? ""
        case "last":
            return inputs.last ?? ""
        default:
            return inputs.joined(separator: "\n")
        }
    }

    private func executeTransform(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        guard let input = node.configuration.parameters["input"],
              let transform = node.configuration.parameters["transform"] else {
            throw AutomationWorkflowError.invalidConfiguration("Missing input or transform")
        }

        let interpolated = interpolate(input, with: context)

        switch transform {
        case "uppercase":
            return interpolated.uppercased()
        case "lowercase":
            return interpolated.lowercased()
        case "trim":
            return interpolated.trimmingCharacters(in: .whitespacesAndNewlines)
        case "json":
            // Parse JSON and return formatted
            if let data = interpolated.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let formatted = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                return String(data: formatted, encoding: .utf8) ?? interpolated
            }
            return interpolated
        default:
            return interpolated
        }
    }

    private func executeDelay(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        let seconds = Double(node.configuration.parameters["seconds"] ?? "1") ?? 1
        try await Task.sleep(for: .seconds(seconds))
        return "Delayed \(seconds) seconds"
    }

    private func executeNotification(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        let title = interpolate(node.configuration.parameters["title"] ?? "Thea Workflow", with: context)
        let body = interpolate(node.configuration.parameters["body"] ?? "", with: context)
        let sound = node.configuration.parameters["sound"] ?? "default"

        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound == "none" ? nil : .default
        content.categoryIdentifier = "WORKFLOW_NOTIFICATION"

        let request = UNNotificationRequest(
            identifier: "workflow-\(node.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        try await UNUserNotificationCenter.current().add(request)
        #endif

        return "Notification sent: \(title) - \(body)"
    }

    private func executeSubWorkflow(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        guard let workflowId = node.configuration.parameters["workflowId"],
              let uuid = UUID(uuidString: workflowId),
              let subWorkflow = getWorkflow(id: uuid) else {
            throw AutomationWorkflowError.invalidConfiguration("Sub-workflow not found")
        }

        let result = await execute(subWorkflow, input: context.mapValues { "\($0)" })
        return result.status == .success ? "Sub-workflow completed" : "Sub-workflow failed"
    }

    private func executeCode(_ node: AutomationNode, context: [String: Any]) async throws -> String {
        // Code execution is disabled for security
        // In production, could use JavaScriptCore or similar
        throw AutomationWorkflowError.unsupportedOperation("Code execution is not supported")
    }

    // MARK: - Helpers

    private func topologicalSort(_ workflow: AutomationWorkflow) -> [AutomationNode] {
        var result: [AutomationNode] = []
        var visited: Set<UUID> = []

        func visit(_ node: AutomationNode) {
            guard !visited.contains(node.id) else { return }
            visited.insert(node.id)

            // Visit dependencies first
            let incomingConnections = workflow.connections.filter { $0.targetNodeId == node.id }
            for connection in incomingConnections {
                if let sourceNode = workflow.nodes.first(where: { $0.id == connection.sourceNodeId }) {
                    visit(sourceNode)
                }
            }

            result.append(node)
        }

        for node in workflow.nodes {
            visit(node)
        }

        return result
    }

    private func interpolate(_ text: String, with context: [String: Any]) -> String {
        var result = text
        for (key, value) in context {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: "\(value)")
        }
        return result
    }

    private func evaluateCondition(_ condition: String) -> Bool {
        // Simple evaluation - just check for "true" or non-empty
        condition.lowercased() == "true" || (!condition.isEmpty && condition != "false" && condition != "0")
    }

    // MARK: - Persistence

    private func loadWorkflows() {
        guard let data = UserDefaults.standard.data(forKey: "workflows"),
              let saved = try? JSONDecoder().decode([AutomationWorkflow].self, from: data) else {
            return
        }
        workflows = saved
    }

    private func saveWorkflows() {
        if let data = try? JSONEncoder().encode(workflows) {
            UserDefaults.standard.set(data, forKey: "workflows")
        }
    }
}

// MARK: - Errors

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
