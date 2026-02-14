// MissionOrchestratorTypes.swift
// Supporting types for MissionOrchestrator

import Combine
import Foundation

// MARK: - Mission

public class Mission: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let goal: String
    public let context: MissionContext
    public let analysis: MissionAnalysis
    public let phases: [MissionPhase]
    @Published public var status: MissionStatus
    public let createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public var error: String?
    public var report: MissionReport?

    enum CodingKeys: String, CodingKey {
        case id, goal, context, analysis, phases, status, createdAt, startedAt, completedAt, error, report
    }

    init(id: UUID, goal: String, context: MissionContext, analysis: MissionAnalysis, phases: [MissionPhase], status: MissionStatus, createdAt: Date) {
        self.id = id
        self.goal = goal
        self.context = context
        self.analysis = analysis
        self.phases = phases
        self.status = status
        self.createdAt = createdAt
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goal = try container.decode(String.self, forKey: .goal)
        context = try container.decode(MissionContext.self, forKey: .context)
        analysis = try container.decode(MissionAnalysis.self, forKey: .analysis)
        phases = try container.decode([MissionPhase].self, forKey: .phases)
        status = try container.decode(MissionStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        report = try container.decodeIfPresent(MissionReport.self, forKey: .report)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(goal, forKey: .goal)
        try container.encode(context, forKey: .context)
        try container.encode(analysis, forKey: .analysis)
        try container.encode(phases, forKey: .phases)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(report, forKey: .report)
    }
}

// MARK: - Mission Context & Enums

public struct MissionContext: Codable {
    public var priority: MissionPriority = .normal
    public var deadline: Date?
    public var constraints: [String] = []
    public var preferences: [String: String] = [:]

    public init() {}
}

public enum MissionPriority: String, Codable {
    case low, normal, high, critical
}

public enum MissionStatus: String, Codable {
    case planned, running, paused, completed, failed, cancelled
}

// MARK: - Analysis Types

public struct MissionAnalysis: Codable {
    public let components: [GoalComponent]
    public let capabilities: [RequiredCapability]
    public let complexity: MissionComplexity
    public let dependencies: [ComponentDependency]
    public let feasibility: FeasibilityAssessment
    public let estimatedDuration: TimeInterval
}

public struct GoalComponent: Identifiable, Codable {
    public var id = UUID()
    public let action: String
    public let target: String
    public let details: String?
}

public struct RequiredCapability: Codable {
    public let name: String
    public let importance: CapabilityImportance

    public enum CapabilityImportance: String, Codable {
        case critical, normal, optional
    }
}

public enum MissionComplexity: String, Codable {
    case simple, moderate, complex, epic
}

public struct ComponentDependency: Codable {
    public let from: UUID
    public let to: UUID
    public let type: DependencyType

    public enum DependencyType: String, Codable {
        case sequential, parallel, conditional
    }
}

public struct FeasibilityAssessment: Codable {
    public let feasible: Bool
    public let confidence: Double
    public let blockers: [String]
    public let recommendations: [String]
}

// MARK: - Phase & Step Types

public class MissionPhase: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let name: String
    public let description: String
    public let order: Int
    public let steps: [MissionStep]
    @Published public var status: PhaseStatus
    public var startedAt: Date?
    public var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, order, steps, status, startedAt, completedAt
    }

    init(id: UUID, name: String, description: String, order: Int, steps: [MissionStep], status: PhaseStatus) {
        self.id = id
        self.name = name
        self.description = description
        self.order = order
        self.steps = steps
        self.status = status
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        order = try container.decode(Int.self, forKey: .order)
        steps = try container.decode([MissionStep].self, forKey: .steps)
        status = try container.decode(PhaseStatus.self, forKey: .status)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(order, forKey: .order)
        try container.encode(steps, forKey: .steps)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
    }
}

public enum PhaseStatus: String, Codable {
    case pending, running, completed, failed, skipped
}

public class MissionStep: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let name: String
    public let type: StepType
    public let order: Int
    @Published public var status: StepStatus = .pending
    public var startedAt: Date?
    public var completedAt: Date?
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type, order, status, startedAt, completedAt, error
    }

    init(id: UUID, name: String, type: StepType, order: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.order = order
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(StepType.self, forKey: .type)
        order = try container.decode(Int.self, forKey: .order)
        status = try container.decode(StepStatus.self, forKey: .status)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(order, forKey: .order)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(error, forKey: .error)
    }

    public enum StepType: String, Codable {
        case validation, resourceGathering, checkpoint, planning
        case codeGeneration, codeModification, fileOperation
        case dataCollection, processing, aiAnalysis
        case building, testing, deployment
        case reporting, cleanup, execution
    }
}

public enum StepStatus: String, Codable {
    case pending, running, completed, failed, skipped
}

// MARK: - Logging & Reporting

public struct MissionLog: Identifiable, Codable {
    public var id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let message: String
    public let phase: String?
    public let step: String?
}

public enum LogLevel: String, Codable {
    case info, success, warning, error
}

public struct MissionReport: Codable {
    public let missionId: UUID
    public let goal: String
    public let status: MissionStatus
    public let phasesCompleted: Int
    public let totalPhases: Int
    public let duration: TimeInterval?
    public let logs: [MissionLog]
    public let generatedAt: Date
}

// MARK: - Errors

public enum MissionError: Error, LocalizedError {
    case missionAlreadyActive
    case validationFailed(String)
    case phaseExecutionFailed(String)
    case stepExecutionFailed(String)
    case checkpointRestoreFailed

    public var errorDescription: String? {
        switch self {
        case .missionAlreadyActive: "A mission is already active"
        case let .validationFailed(reason): "Validation failed: \(reason)"
        case let .phaseExecutionFailed(reason): "Phase execution failed: \(reason)"
        case let .stepExecutionFailed(reason): "Step execution failed: \(reason)"
        case .checkpointRestoreFailed: "Failed to restore from checkpoint"
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let missionCompleted = Notification.Name("thea.mission.completed")
    static let missionFailed = Notification.Name("thea.mission.failed")
}
