// SelfEvolutionEngineTypes.swift
// Types and models for the SelfEvolutionEngine

import Combine
import Foundation
import OSLog

// MARK: - Types

public class EvolutionTask: Identifiable, ObservableObject, Codable {
    public let id: UUID
    public let request: String
    @Published public var status: TaskStatus
    public let createdAt: Date

    public var analysis: FeatureAnalysis?
    public var plan: ImplementationPlan?
    public var estimate: ComplexityEstimate?
    public var currentStep: Int = 0
    public var completedSteps: [Int] = []
    public var buildResult: BuildResult?
    public var testsPassed: Bool = false
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case id, request, status, createdAt, analysis, plan, estimate
        case currentStep, completedSteps, buildResult, testsPassed, error
    }

    init(id: UUID, request: String, status: TaskStatus, createdAt: Date) {
        self.id = id
        self.request = request
        self.status = status
        self.createdAt = createdAt
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        request = try container.decode(String.self, forKey: .request)
        status = try container.decode(TaskStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        analysis = try container.decodeIfPresent(FeatureAnalysis.self, forKey: .analysis)
        plan = try container.decodeIfPresent(ImplementationPlan.self, forKey: .plan)
        estimate = try container.decodeIfPresent(ComplexityEstimate.self, forKey: .estimate)
        currentStep = try container.decodeIfPresent(Int.self, forKey: .currentStep) ?? 0
        completedSteps = try container.decodeIfPresent([Int].self, forKey: .completedSteps) ?? []
        buildResult = try container.decodeIfPresent(BuildResult.self, forKey: .buildResult)
        testsPassed = try container.decodeIfPresent(Bool.self, forKey: .testsPassed) ?? false
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(request, forKey: .request)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(analysis, forKey: .analysis)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encodeIfPresent(estimate, forKey: .estimate)
        try container.encode(currentStep, forKey: .currentStep)
        try container.encode(completedSteps, forKey: .completedSteps)
        try container.encodeIfPresent(buildResult, forKey: .buildResult)
        try container.encode(testsPassed, forKey: .testsPassed)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

public enum TaskStatus: String, Codable {
    case analyzing
    case planned
    case implementing
    case building
    case testing
    case testsFailed
    case buildFailed
    case readyToInstall
    case installed
    case failed
}

public struct FeatureAnalysis: Codable {
    public let category: FeatureCategory
    public let scope: ImplementationScope
    public let affectedFiles: [AffectedFile]
    public let dependencies: [String]
    public let risks: [ImplementationRisk]
    public let summary: String
}

public enum FeatureCategory: String, Codable {
    case ui
    case networking
    case ai
    case data
    case settings
    case security
    case core
}

public enum ImplementationScope: String, Codable {
    case minor
    case moderate
    case major
}

public struct AffectedFile: Codable {
    public let path: String
    public let action: FileAction
    public let description: String

    public enum FileAction: String, Codable {
        case create
        case modify
        case delete
    }
}

public struct ImplementationRisk: Codable {
    public let level: RiskLevel
    public let description: String
    public let mitigation: String

    public enum RiskLevel: String, Codable {
        case low
        case medium
        case high
    }
}

public struct ImplementationPlan: Codable {
    public let steps: [ImplementationStep]
    public let estimatedTotalDuration: Int
    public let requiredCapabilities: [String]
}

public struct ImplementationStep: Codable {
    public let order: Int
    public let title: String
    public let description: String
    public let type: StepType
    public let filePath: String?
    public let estimatedDuration: Int

    public enum StepType: String, Codable {
        case createFile
        case modifyFile
        case deleteFile
        case build
        case test
    }
}

public struct ComplexityEstimate: Codable {
    public let level: ComplexityLevel
    public let estimatedSteps: Int
    public let estimatedDuration: Int
    public let confidence: Double
}

public enum ComplexityLevel: String, Codable {
    case low
    case medium
    case high
}

public struct BuildProgress {
    public let phase: BuildPhase
    public let progress: Double
}

public enum BuildPhase: String {
    case preparing
    case compiling
    case linking
    case signing
}

public struct BuildResult: Codable {
    public let success: Bool
    public let outputPath: URL?
    public let duration: TimeInterval
    public let warnings: [String]
    public let errors: [String]
}

public struct PendingUpdate {
    public let task: EvolutionTask
    public let buildPath: URL
    public let version: String
    public let createdAt: Date
}

public enum EvolutionError: Error, LocalizedError {
    case noPlan
    case fileNotFound(String)
    case buildFailed(String)
    case testsFailed
    case noUpdateAvailable
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noPlan: "No implementation plan available"
        case let .fileNotFound(path): "File not found: \(path)"
        case let .buildFailed(reason): "Build failed: \(reason)"
        case .testsFailed: "Tests failed"
        case .noUpdateAvailable: "No update available"
        case let .installFailed(reason): "Installation failed: \(reason)"
        }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let evolutionUpdateReady = Notification.Name("thea.evolution.updateReady")
    static let evolutionInstallComplete = Notification.Name("thea.evolution.installComplete")
}
