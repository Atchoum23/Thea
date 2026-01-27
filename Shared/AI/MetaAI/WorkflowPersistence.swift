// WorkflowPersistence.swift
import Foundation
import OSLog

/// Save/load workflows to disk with versioning support.
@MainActor
@Observable
public final class WorkflowPersistence {
    public static let shared = WorkflowPersistence()

    private let workflowsDirectory: URL
    private let workflowsFileName = "workflows.json"
    private let logger = Logger(subsystem: "com.thea.workflows", category: "Persistence")

    /// Current schema version for migration support
    private static let currentSchemaVersion = 1

    private init() {
        // Default workflows directory with safe unwrapping
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            workflowsDirectory = appSupport.appendingPathComponent("Thea/workflows")
        } else {
            // Fallback to temporary directory if app support unavailable
            workflowsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Thea/workflows")
        }

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(at: workflowsDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create workflows directory: \(error.localizedDescription)")
        }
    }

    /// Load workflows from disk
    public func load() async throws -> [Workflow] {
        let fileURL = workflowsDirectory.appendingPathComponent(workflowsFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("No workflows file found, returning empty array")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let container = try decoder.decode(WorkflowsContainer.self, from: data)

            // Handle schema migration if needed
            if container.schemaVersion < Self.currentSchemaVersion {
                logger.info("Migrating workflows from schema v\(container.schemaVersion) to v\(Self.currentSchemaVersion)")
                // Future migration logic here
            }

            logger.info("Loaded \(container.workflows.count) workflows")
            return container.workflows.map { $0.toWorkflow() }
        } catch {
            logger.error("Failed to load workflows: \(error.localizedDescription)")
            throw WorkflowPersistenceError.loadFailed(error.localizedDescription)
        }
    }

    /// Save workflows to disk
    public func save(_ workflows: [Workflow]) async throws {
        let fileURL = workflowsDirectory.appendingPathComponent(workflowsFileName)

        do {
            let codableWorkflows = workflows.map { CodableWorkflow(from: $0) }
            let container = WorkflowsContainer(
                schemaVersion: Self.currentSchemaVersion,
                savedAt: Date(),
                workflows: codableWorkflows
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(container)
            try data.write(to: fileURL, options: .atomic)

            logger.info("Saved \(workflows.count) workflows")
        } catch {
            logger.error("Failed to save workflows: \(error.localizedDescription)")
            throw WorkflowPersistenceError.saveFailed(error.localizedDescription)
        }
    }

    /// Auto-save workflows (debounced save operation)
    public func autoSave(_ workflows: [Workflow]) async {
        do {
            try await save(workflows)
        } catch {
            logger.error("Auto-save failed: \(error.localizedDescription)")
        }
    }

    /// Export workflows to a specific location
    public func export(_ workflows: [Workflow], to url: URL) async throws {
        let codableWorkflows = workflows.map { CodableWorkflow(from: $0) }
        let container = WorkflowsContainer(
            schemaVersion: Self.currentSchemaVersion,
            savedAt: Date(),
            workflows: codableWorkflows
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(container)
        try data.write(to: url, options: .atomic)

        logger.info("Exported \(workflows.count) workflows to \(url.lastPathComponent)")
    }

    /// Import workflows from a file
    public func importWorkflows(from url: URL) async throws -> [Workflow] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let container = try decoder.decode(WorkflowsContainer.self, from: data)
        logger.info("Imported \(container.workflows.count) workflows from \(url.lastPathComponent)")

        return container.workflows.map { $0.toWorkflow() }
    }

    /// Delete all saved workflows
    public func deleteAll() async throws {
        let fileURL = workflowsDirectory.appendingPathComponent(workflowsFileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            logger.info("Deleted all workflows")
        }
    }
}

// MARK: - Persistence Errors

public enum WorkflowPersistenceError: LocalizedError {
    case loadFailed(String)
    case saveFailed(String)
    case migrationFailed(String)
    case importFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .loadFailed(reason):
            "Failed to load workflows: \(reason)"
        case let .saveFailed(reason):
            "Failed to save workflows: \(reason)"
        case let .migrationFailed(reason):
            "Failed to migrate workflows: \(reason)"
        case let .importFailed(reason):
            "Failed to import workflows: \(reason)"
        }
    }
}

// MARK: - Codable Wrapper Types

/// Container for versioned workflow storage
private struct WorkflowsContainer: Codable {
    let schemaVersion: Int
    let savedAt: Date
    let workflows: [CodableWorkflow]
}

/// Codable representation of Workflow
private struct CodableWorkflow: Codable {
    let id: UUID
    let name: String
    let description: String
    let nodes: [CodableWorkflowNode]
    let edges: [CodableWorkflowEdge]
    let variables: [String: CodableValue]
    let isActive: Bool
    let createdAt: Date
    let modifiedAt: Date

    init(from workflow: Workflow) {
        id = workflow.id
        name = workflow.name
        description = workflow.description
        nodes = workflow.nodes.map { CodableWorkflowNode(from: $0) }
        edges = workflow.edges.map { CodableWorkflowEdge(from: $0) }
        variables = workflow.variables.mapValues { CodableValue(from: $0) }
        isActive = workflow.isActive
        createdAt = workflow.createdAt
        modifiedAt = workflow.modifiedAt
    }

    func toWorkflow() -> Workflow {
        Workflow(
            id: id,
            name: name,
            description: description,
            nodes: nodes.map { $0.toWorkflowNode() },
            edges: edges.map { $0.toWorkflowEdge() },
            variables: variables.mapValues { $0.toAny() },
            isActive: isActive,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

/// Codable representation of WorkflowNode
private struct CodableWorkflowNode: Codable {
    let id: UUID
    let type: String
    let positionX: CGFloat
    let positionY: CGFloat
    let config: [String: CodableValue]
    let inputs: [CodableNodePort]
    let outputs: [CodableNodePort]

    init(from node: WorkflowNode) {
        id = node.id
        type = node.type.rawValue
        positionX = node.position.x
        positionY = node.position.y
        config = node.config.mapValues { CodableValue(from: $0) }
        inputs = node.inputs.map { CodableNodePort(from: $0) }
        outputs = node.outputs.map { CodableNodePort(from: $0) }
    }

    func toWorkflowNode() -> WorkflowNode {
        WorkflowNode(
            id: id,
            type: WorkflowNodeType(rawValue: type) ?? .variable,
            position: CGPoint(x: positionX, y: positionY),
            config: config.mapValues { $0.toAny() },
            inputs: inputs.map { $0.toNodePort() },
            outputs: outputs.map { $0.toNodePort() }
        )
    }
}

/// Codable representation of WorkflowEdge
private struct CodableWorkflowEdge: Codable {
    let id: UUID
    let sourceNodeId: UUID
    let sourcePort: String
    let targetNodeId: UUID
    let targetPort: String

    init(from edge: WorkflowEdge) {
        id = edge.id
        sourceNodeId = edge.sourceNodeId
        sourcePort = edge.sourcePort
        targetNodeId = edge.targetNodeId
        targetPort = edge.targetPort
    }

    func toWorkflowEdge() -> WorkflowEdge {
        WorkflowEdge(
            id: id,
            sourceNodeId: sourceNodeId,
            sourcePort: sourcePort,
            targetNodeId: targetNodeId,
            targetPort: targetPort
        )
    }
}

/// Codable representation of NodePort
private struct CodableNodePort: Codable {
    let name: String
    let type: String

    init(from port: NodePort) {
        name = port.name
        type = portTypeToString(port.type)
    }

    func toNodePort() -> NodePort {
        NodePort(name: name, type: stringToPortType(type))
    }
}

/// Helper to convert PortType to String
private func portTypeToString(_ type: NodePort.PortType) -> String {
    switch type {
    case .string: "string"
    case .number: "number"
    case .boolean: "boolean"
    case .array: "array"
    case .object: "object"
    case .any: "any"
    }
}

/// Helper to convert String to PortType
private func stringToPortType(_ string: String) -> NodePort.PortType {
    switch string {
    case "string": .string
    case "number": .number
    case "boolean": .boolean
    case "array": .array
    case "object": .object
    default: .any
    }
}

/// Codable wrapper for Any values
private enum CodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([CodableValue])
    case dictionary([String: CodableValue])
    case null

    init(from value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            self = .array(array.map { CodableValue(from: $0) })
        case let dict as [String: Any]:
            self = .dictionary(dict.mapValues { CodableValue(from: $0) })
        default:
            self = .null
        }
    }

    func toAny() -> Any {
        switch self {
        case let .string(value): value
        case let .int(value): value
        case let .double(value): value
        case let .bool(value): value
        case let .array(values): values.map { $0.toAny() }
        case let .dictionary(dict): dict.mapValues { $0.toAny() }
        case .null: NSNull()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([CodableValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: CodableValue].self) {
            self = .dictionary(dict)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .array(values):
            try container.encode(values)
        case let .dictionary(dict):
            try container.encode(dict)
        case .null:
            try container.encodeNil()
        }
    }
}
