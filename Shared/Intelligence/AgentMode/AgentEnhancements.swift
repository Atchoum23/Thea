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
