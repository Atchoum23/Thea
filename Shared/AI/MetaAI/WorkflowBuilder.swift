import Foundation
import SwiftData

// MARK: - Sendable Wrapper for [String: Any]
// Safely transfers dictionaries across actor boundaries

@frozen
public struct SendableDict: @unchecked Sendable {
    private let storage: [String: Any]

    public init(_ dict: [String: Any]) {
        self.storage = dict
    }

    public var value: [String: Any] {
        storage
    }
}

// MARK: - Visual Workflow Builder
// Node-based workflow creation and execution engine

@MainActor
@Observable
final class WorkflowBuilder {
    static let shared = WorkflowBuilder()

    private(set) var workflows: [Workflow] = []
    private(set) var activeExecutions: [WorkflowExecution] = []
    private(set) var nodeLibrary: [NodeTemplate] = []

    private var workflowIndex: [UUID: Workflow] = [:]

    private init() {
        initializeNodeLibrary()
        Task {
            await loadWorkflows()
        }
    }
    
    // MARK: - Persistence
    
    func loadWorkflows() async {
        do {
            let loaded = try await WorkflowPersistence.shared.load()
            workflows = loaded
            workflowIndex = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            
            // Add templates if no workflows exist
            if workflows.isEmpty {
                for template in WorkflowTemplates.all {
                    workflows.append(template)
                    workflowIndex[template.id] = template
                }
                try await WorkflowPersistence.shared.save(workflows)
            }
        } catch {
            // If loading fails, start with templates
            workflows = WorkflowTemplates.all
            workflowIndex = Dictionary(uniqueKeysWithValues: workflows.map { ($0.id, $0) })
        }
    }
    
    func saveWorkflows() async {
        await WorkflowPersistence.shared.autoSave(workflows)
    }

    // MARK: - Workflow Management

    func createWorkflow(name: String, description: String = "") -> Workflow {
        let workflow = Workflow(
            id: UUID(),
            name: name,
            description: description,
            nodes: [],
            edges: [],
            variables: [:],
            isActive: false,
            createdAt: Date(),
            modifiedAt: Date()
        )

        workflows.append(workflow)
        workflowIndex[workflow.id] = workflow
        
        Task {
            await saveWorkflows()
        }

        return workflow
    }

    func deleteWorkflow(_ workflowId: UUID) throws {
        guard let workflow = workflowIndex[workflowId] else {
            throw WorkflowError.workflowNotFound
        }

        // Cannot delete active workflow
        guard !workflow.isActive else {
            throw WorkflowError.workflowActive
        }

        workflows.removeAll { $0.id == workflowId }
        workflowIndex.removeValue(forKey: workflowId)
    }

    func duplicateWorkflow(_ workflowId: UUID) throws -> Workflow {
        guard let original = workflowIndex[workflowId] else {
            throw WorkflowError.workflowNotFound
        }

        let duplicate = Workflow(
            id: UUID(),
            name: "\(original.name) (Copy)",
            description: original.description,
            nodes: original.nodes.map { node in
                WorkflowNode(
                    id: UUID(),
                    type: node.type,
                    position: CGPoint(x: node.position.x + 50, y: node.position.y + 50),
                    config: node.config,
                    inputs: node.inputs,
                    outputs: node.outputs
                )
            },
            edges: original.edges,
            variables: original.variables,
            isActive: false,
            createdAt: Date(),
            modifiedAt: Date()
        )

        workflows.append(duplicate)
        workflowIndex[duplicate.id] = duplicate

        return duplicate
    }

    // MARK: - Node Management

    func addNode(
        to workflowId: UUID,
        type: WorkflowNodeType,
        position: CGPoint,
        config: [String: Any] = [:]
    ) throws -> WorkflowNode {
        guard let workflow = workflowIndex[workflowId] else {
            throw WorkflowError.workflowNotFound
        }

        let template = nodeLibrary.first { $0.type == type }!

        let node = WorkflowNode(
            id: UUID(),
            type: type,
            position: position,
            config: config,
            inputs: template.inputs,
            outputs: template.outputs
        )

        workflow.nodes.append(node)
        workflow.modifiedAt = Date()

        return node
    }

    func removeNode(from workflowId: UUID, nodeId: UUID) throws {
        guard let workflow = workflowIndex[workflowId] else {
            throw WorkflowError.workflowNotFound
        }

        // Remove connected edges
        workflow.edges.removeAll { edge in
            edge.sourceNodeId == nodeId || edge.targetNodeId == nodeId
        }

        // Remove node
        workflow.nodes.removeAll { $0.id == nodeId }
        workflow.modifiedAt = Date()
    }

    func updateNodePosition(
        in workflowId: UUID,
        nodeId: UUID,
        position: CGPoint
    ) throws {
        guard let workflow = workflowIndex[workflowId],
              let node = workflow.nodes.first(where: { $0.id == nodeId }) else {
            throw WorkflowError.nodeNotFound
        }

        node.position = position
        workflow.modifiedAt = Date()
    }

    func updateNodeConfig(
        in workflowId: UUID,
        nodeId: UUID,
        config: [String: Any]
    ) throws {
        guard let workflow = workflowIndex[workflowId],
              let node = workflow.nodes.first(where: { $0.id == nodeId }) else {
            throw WorkflowError.nodeNotFound
        }

        node.config = config
        workflow.modifiedAt = Date()
    }

    // MARK: - Edge Management

    func connectNodes(
        in workflowId: UUID,
        from sourceNodeId: UUID,
        outputPort: String,
        to targetNodeId: UUID,
        inputPort: String
    ) throws {
        guard let workflow = workflowIndex[workflowId] else {
            throw WorkflowError.workflowNotFound
        }

        guard let sourceNode = workflow.nodes.first(where: { $0.id == sourceNodeId }),
              let targetNode = workflow.nodes.first(where: { $0.id == targetNodeId }) else {
            throw WorkflowError.nodeNotFound
        }

        // Validate ports exist
        guard sourceNode.outputs.contains(where: { $0.name == outputPort }),
              targetNode.inputs.contains(where: { $0.name == inputPort }) else {
            throw WorkflowError.invalidConnection
        }

        // Check for cycles
        if try wouldCreateCycle(
            in: workflow,
            from: sourceNodeId,
            to: targetNodeId
        ) {
            throw WorkflowError.cyclicConnection
        }

        let edge = WorkflowEdge(
            id: UUID(),
            sourceNodeId: sourceNodeId,
            sourcePort: outputPort,
            targetNodeId: targetNodeId,
            targetPort: inputPort
        )

        workflow.edges.append(edge)
        workflow.modifiedAt = Date()
    }

    func disconnectNodes(
        in workflowId: UUID,
        edgeId: UUID
    ) throws {
        guard let workflow = workflowIndex[workflowId] else {
            throw WorkflowError.workflowNotFound
        }

        workflow.edges.removeAll { $0.id == edgeId }
        workflow.modifiedAt = Date()
    }

    // MARK: - Workflow Execution

    func executeWorkflow(
        _ workflowId: UUID,
        inputs: [String: Any] = [:],
        progressHandler: @escaping @Sendable (WorkflowProgress) -> Void
    ) async throws -> WorkflowExecutionResult {
        guard let workflow = workflowIndex[workflowId] else {
            throw WorkflowError.workflowNotFound
        }

        // Validate workflow
        try validateWorkflow(workflow)

        let execution = WorkflowExecution(
            id: UUID(),
            workflowId: workflowId,
            startTime: Date(),
            status: .running,
            currentNode: nil,
            outputs: [:],
            errors: []
        )

        activeExecutions.append(execution)
        workflow.isActive = true

        defer {
            workflow.isActive = false
            activeExecutions.removeAll { $0.id == execution.id }
        }

        do {
            // Topological sort for execution order
            let executionOrder = try topologicalSort(workflow)

            var nodeOutputs: [UUID: [String: Any]] = [:]

            // Set initial inputs
            workflow.variables = inputs

            // Execute nodes in order
            for (index, nodeId) in executionOrder.enumerated() {
                guard let node = workflow.nodes.first(where: { $0.id == nodeId }) else {
                    continue
                }

                execution.currentNode = nodeId

                let progress = Float(index) / Float(executionOrder.count)
                progressHandler(WorkflowProgress(
                    phase: "Executing \(node.type.rawValue)",
                    percentage: progress,
                    currentNodeId: nodeId
                ))

                // Gather inputs for this node
                let nodeInputs = gatherNodeInputs(
                    for: node,
                    in: workflow,
                    outputs: nodeOutputs
                )

                // Execute node with sendable wrapper
                // Wrap nodeInputs in SendableDict for safe transfer across isolation boundaries
                let sendableInputs = SendableDict(nodeInputs)
                let result = try await executeNode(node, inputs: sendableInputs, workflow: workflow)

                // Store outputs
                nodeOutputs[nodeId] = result
            }

            execution.status = .completed
            execution.endTime = Date()
            execution.outputs = nodeOutputs

            progressHandler(WorkflowProgress(
                phase: "Workflow completed",
                percentage: 1.0,
                currentNodeId: nil
            ))

            return WorkflowExecutionResult(
                executionId: execution.id,
                success: true,
                outputs: nodeOutputs,
                duration: execution.endTime!.timeIntervalSince(execution.startTime),
                errors: []
            )

        } catch {
            execution.status = .failed
            execution.endTime = Date()
            execution.errors.append(error.localizedDescription)

            return WorkflowExecutionResult(
                executionId: execution.id,
                success: false,
                outputs: [:],
                duration: execution.endTime!.timeIntervalSince(execution.startTime),
                errors: [error.localizedDescription]
            )
        }
    }

    // MARK: - Node Execution

    nonisolated private func executeNode(
        _ node: WorkflowNode,
        inputs: SendableDict,
        workflow: Workflow
    ) async throws -> [String: Any] {
        // Extract the dictionary from the sendable wrapper
        let inputDict = inputs.value
        switch node.type {
        case .input:
            return inputDict

        case .output:
            return inputDict

        case .aiInference:
            return try await executeAIInference(node, inputs: inputDict)

        case .toolExecution:
            return try await executeToolNode(node, inputs: inputDict)

        case .conditional:
            return executeConditional(node, inputs: inputDict)

        case .loop:
            return try await executeLoop(node, inputs: inputDict, workflow: workflow)

        case .variable:
            return executeVariable(node, inputs: inputDict)

        case .transformation:
            return executeTransformation(node, inputs: inputDict)

        case .merge:
            return executeMerge(node, inputs: inputDict)

        case .split:
            return executeSplit(node, inputs: inputDict)
        }
    }

    nonisolated private func executeAIInference(
        _ node: WorkflowNode,
        inputs: [String: Any]
    ) async throws -> [String: Any] {
        guard let prompt = inputs["prompt"] as? String else {
            throw WorkflowError.invalidNodeInput
        }

        let provider = await ProviderRegistry.shared.getProvider(id: await SettingsManager.shared.defaultProvider)!
        let model = node.config["model"] as? String ?? "gpt-4o"

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: model
        )

        var result = ""
        let stream = try await provider.chat(messages: [message], model: model, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                result += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        return ["output": result]
    }

    nonisolated private func executeToolNode(
        _ node: WorkflowNode,
        inputs: [String: Any]
    ) async throws -> [String: Any] {
        guard let toolName = node.config["toolName"] as? String else {
            throw WorkflowError.invalidNodeConfig
        }

        let toolFramework = await ToolFramework.shared
        guard let tool = await toolFramework.registeredTools.first(where: { $0.name == toolName }) else {
            throw WorkflowError.toolNotFound
        }

        let result = try await toolFramework.executeTool(tool, parameters: inputs)

        return ["output": result.output ?? "", "success": result.success]
    }

    nonisolated private func executeConditional(
        _ node: WorkflowNode,
        inputs: [String: Any]
    ) -> [String: Any] {
        guard let condition = node.config["condition"] as? String else {
            return ["result": false]
        }

        // Simple condition evaluation
        let result = evaluateCondition(condition, inputs: inputs)

        return ["result": result, "branch": result ? "true" : "false"]
    }

    nonisolated private func executeLoop(
        _ node: WorkflowNode,
        inputs: [String: Any],
        workflow: Workflow
    ) async throws -> [String: Any] {
        guard let iterations = node.config["iterations"] as? Int else {
            throw WorkflowError.invalidNodeConfig
        }

        var results: [[String: Any]] = []

        for i in 0..<iterations {
            var loopInputs = inputs
            loopInputs["iteration"] = i

            results.append(loopInputs)
        }

        return ["results": results, "count": iterations]
    }

    nonisolated private func executeVariable(
        _ node: WorkflowNode,
        inputs: [String: Any]
    ) -> [String: Any] {
        guard let variableName = node.config["name"] as? String else {
            return [:]
        }

        if let value = inputs[variableName] {
            return ["value": value]
        }

        return ["value": node.config["defaultValue"] ?? ""]
    }

    nonisolated private func executeTransformation(
        _ node: WorkflowNode,
        inputs: [String: Any]
    ) -> [String: Any] {
        guard let transformType = node.config["type"] as? String else {
            return inputs
        }

        // Simple transformations
        switch transformType {
        case "uppercase":
            if let text = inputs["input"] as? String {
                return ["output": text.uppercased()]
            }
        case "lowercase":
            if let text = inputs["input"] as? String {
                return ["output": text.lowercased()]
            }
        case "json_parse":
            if let jsonString = inputs["input"] as? String,
               let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                return ["output": json]
            }
        default:
            break
        }

        return inputs
    }

    nonisolated private func executeMerge(
        _ node: WorkflowNode,
        inputs: [String: Any]
    ) -> [String: Any] {
        // Merge all inputs into single output
        return ["merged": inputs]
    }

    nonisolated private func executeSplit(
        _ node: WorkflowNode,
        inputs: [String: Any]
    ) -> [String: Any] {
        // Split input into multiple outputs
        if let array = inputs["input"] as? [Any] {
            var outputs: [String: Any] = [:]
            for (index, item) in array.enumerated() {
                outputs["output\(index)"] = item
            }
            return outputs
        }

        return inputs
    }

    // MARK: - Helper Methods

    private func gatherNodeInputs(
        for node: WorkflowNode,
        in workflow: Workflow,
        outputs: [UUID: [String: Any]]
    ) -> [String: Any] {
        var inputs: [String: Any] = [:]

        // Find incoming edges
        let incomingEdges = workflow.edges.filter { $0.targetNodeId == node.id }

        for edge in incomingEdges {
            if let sourceOutputs = outputs[edge.sourceNodeId],
               let value = sourceOutputs[edge.sourcePort] {
                inputs[edge.targetPort] = value
            }
        }

        // Include workflow variables
        for (key, value) in workflow.variables {
            if inputs[key] == nil {
                inputs[key] = value
            }
        }

        return inputs
    }

    private func validateWorkflow(_ workflow: Workflow) throws {
        // Must have at least one node
        guard !workflow.nodes.isEmpty else {
            throw WorkflowError.emptyWorkflow
        }

        // Must have start node
        guard workflow.nodes.contains(where: { $0.type == .input }) else {
            throw WorkflowError.missingStartNode
        }

        // Check for orphaned nodes
        for node in workflow.nodes {
            if node.type != .input {
                let hasIncoming = workflow.edges.contains { $0.targetNodeId == node.id }
                if !hasIncoming {
                    throw WorkflowError.orphanedNode
                }
            }
        }
    }

    private func topologicalSort(_ workflow: Workflow) throws -> [UUID] {
        var sorted: [UUID] = []
        var visited: Set<UUID> = []
        var visiting: Set<UUID> = []

        func visit(_ nodeId: UUID) throws {
            if visited.contains(nodeId) {
                return
            }

            if visiting.contains(nodeId) {
                throw WorkflowError.cyclicConnection
            }

            visiting.insert(nodeId)

            // Visit all dependencies
            let outgoing = workflow.edges.filter { $0.sourceNodeId == nodeId }
            for edge in outgoing {
                try visit(edge.targetNodeId)
            }

            visiting.remove(nodeId)
            visited.insert(nodeId)
            sorted.insert(nodeId, at: 0)
        }

        // Start with input nodes
        for node in workflow.nodes where node.type == .input {
            try visit(node.id)
        }

        return sorted
    }

    private func wouldCreateCycle(
        in workflow: Workflow,
        from sourceId: UUID,
        to targetId: UUID
    ) throws -> Bool {
        // Check if there's a path from target to source
        var visited: Set<UUID> = []
        var queue: [UUID] = [targetId]

        while !queue.isEmpty {
            let currentId = queue.removeFirst()

            if visited.contains(currentId) {
                continue
            }

            visited.insert(currentId)

            if currentId == sourceId {
                return true
            }

            let outgoing = workflow.edges.filter { $0.sourceNodeId == currentId }
            queue.append(contentsOf: outgoing.map { $0.targetNodeId })
        }

        return false
    }

    nonisolated private func evaluateCondition(
        _ condition: String,
        inputs: [String: Any]
    ) -> Bool {
        // Very simple condition evaluation
        // In production, use a proper expression parser
        if condition.contains(">") {
            let parts = condition.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2,
               let lhs = inputs[parts[0]] as? Int,
               let rhs = Int(parts[1]) {
                return lhs > rhs
            }
        }

        return false
    }

    private func initializeNodeLibrary() {
        nodeLibrary = [
            NodeTemplate(
                type: .input,
                name: "Input",
                description: "Workflow input",
                inputs: [],
                outputs: [NodePort(name: "output", type: .any)]
            ),
            NodeTemplate(
                type: .output,
                name: "Output",
                description: "Workflow output",
                inputs: [NodePort(name: "input", type: .any)],
                outputs: []
            ),
            NodeTemplate(
                type: .aiInference,
                name: "AI Inference",
                description: "Run AI model",
                inputs: [NodePort(name: "prompt", type: .string)],
                outputs: [NodePort(name: "output", type: .string)]
            ),
            NodeTemplate(
                type: .toolExecution,
                name: "Tool Execution",
                description: "Execute a tool",
                inputs: [NodePort(name: "input", type: .any)],
                outputs: [NodePort(name: "output", type: .any)]
            ),
            NodeTemplate(
                type: .conditional,
                name: "Conditional",
                description: "Branch based on condition",
                inputs: [NodePort(name: "input", type: .any)],
                outputs: [
                    NodePort(name: "true", type: .any),
                    NodePort(name: "false", type: .any)
                ]
            ),
            NodeTemplate(
                type: .loop,
                name: "Loop",
                description: "Repeat execution",
                inputs: [NodePort(name: "input", type: .any)],
                outputs: [NodePort(name: "results", type: .array)]
            ),
            NodeTemplate(
                type: .variable,
                name: "Variable",
                description: "Store/retrieve value",
                inputs: [],
                outputs: [NodePort(name: "value", type: .any)]
            ),
            NodeTemplate(
                type: .transformation,
                name: "Transform",
                description: "Transform data",
                inputs: [NodePort(name: "input", type: .any)],
                outputs: [NodePort(name: "output", type: .any)]
            ),
            NodeTemplate(
                type: .merge,
                name: "Merge",
                description: "Combine inputs",
                inputs: [
                    NodePort(name: "input1", type: .any),
                    NodePort(name: "input2", type: .any)
                ],
                outputs: [NodePort(name: "merged", type: .any)]
            ),
            NodeTemplate(
                type: .split,
                name: "Split",
                description: "Split into multiple outputs",
                inputs: [NodePort(name: "input", type: .array)],
                outputs: [NodePort(name: "outputs", type: .array)]
            )
        ]
    }
}

// MARK: - Models

public class Workflow: Identifiable, Hashable, @unchecked Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var nodes: [WorkflowNode]
    public var edges: [WorkflowEdge]
    public var variables: [String: Any]
    public var isActive: Bool
    public let createdAt: Date
    public var modifiedAt: Date

    public init(id: UUID, name: String, description: String, nodes: [WorkflowNode], edges: [WorkflowEdge], variables: [String: Any], isActive: Bool, createdAt: Date, modifiedAt: Date) {
        self.id = id
        self.name = name
        self.description = description
        self.nodes = nodes
        self.edges = edges
        self.variables = variables
        self.isActive = isActive
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public static func == (lhs: Workflow, rhs: Workflow) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public class WorkflowNode: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let type: WorkflowNodeType
    public var position: CGPoint
    public var config: [String: Any]
    public let inputs: [NodePort]
    public let outputs: [NodePort]

    public init(id: UUID, type: WorkflowNodeType, position: CGPoint, config: [String: Any], inputs: [NodePort], outputs: [NodePort]) {
        self.id = id
        self.type = type
        self.position = position
        self.config = config
        self.inputs = inputs
        self.outputs = outputs
    }
}

public struct WorkflowEdge: Identifiable {
    public let id: UUID
    public let sourceNodeId: UUID
    public let sourcePort: String
    public let targetNodeId: UUID
    public let targetPort: String
}

public struct NodePort {
    public let name: String
    public let type: PortType

    public enum PortType {
        case string, number, boolean, array, object, any
    }
}

struct NodeTemplate {
    let type: WorkflowNodeType
    let name: String
    let description: String
    let inputs: [NodePort]
    let outputs: [NodePort]
}

public enum WorkflowNodeType: String {
    case input = "Input"
    case output = "Output"
    case aiInference = "AI Inference"
    case toolExecution = "Tool Execution"
    case conditional = "Conditional"
    case loop = "Loop"
    case variable = "Variable"
    case transformation = "Transformation"
    case merge = "Merge"
    case split = "Split"
}

class WorkflowExecution: Identifiable {
    let id: UUID
    let workflowId: UUID
    let startTime: Date
    var status: ExecutionStatus
    var currentNode: UUID?
    var endTime: Date?
    var outputs: [UUID: [String: Any]]
    var errors: [String]

    enum ExecutionStatus {
        case running, completed, failed
    }

    init(id: UUID, workflowId: UUID, startTime: Date, status: ExecutionStatus, currentNode: UUID?, outputs: [UUID: [String: Any]], errors: [String]) {
        self.id = id
        self.workflowId = workflowId
        self.startTime = startTime
        self.status = status
        self.currentNode = currentNode
        self.outputs = outputs
        self.errors = errors
    }
}

struct WorkflowExecutionResult {
    let executionId: UUID
    let success: Bool
    let outputs: [UUID: [String: Any]]
    let duration: TimeInterval
    let errors: [String]
}

struct WorkflowProgress: Sendable {
    let phase: String
    let percentage: Float
    let currentNodeId: UUID?
}

enum WorkflowError: LocalizedError {
    case workflowNotFound
    case workflowActive
    case nodeNotFound
    case invalidConnection
    case cyclicConnection
    case emptyWorkflow
    case missingStartNode
    case orphanedNode
    case invalidNodeInput
    case invalidNodeConfig
    case toolNotFound

    var errorDescription: String? {
        switch self {
        case .workflowNotFound:
            return "Workflow not found"
        case .workflowActive:
            return "Cannot modify active workflow"
        case .nodeNotFound:
            return "Node not found"
        case .invalidConnection:
            return "Invalid node connection"
        case .cyclicConnection:
            return "Connection would create a cycle"
        case .emptyWorkflow:
            return "Workflow has no nodes"
        case .missingStartNode:
            return "Workflow must have an input node"
        case .orphanedNode:
            return "Workflow has orphaned nodes"
        case .invalidNodeInput:
            return "Invalid node input"
        case .invalidNodeConfig:
            return "Invalid node configuration"
        case .toolNotFound:
            return "Tool not found"
        }
    }
}
