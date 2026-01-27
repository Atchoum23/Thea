// PhaseDefinition.swift
import Foundation

public struct PhaseDefinition: Sendable, Codable, Identifiable {
    public let id: String // "phase5", "phase6", etc.
    public let number: Int
    public let title: String
    public let description: String
    public let estimatedHours: ClosedRange<Int>
    public let deliverable: String? // DMG name
    public let files: [FileRequirement]
    public let verificationChecklist: [ChecklistItem]
    public let dependencies: [String] // IDs of prerequisite phases

    public init(
        id: String,
        number: Int,
        title: String,
        description: String,
        estimatedHours: ClosedRange<Int>,
        deliverable: String?,
        files: [FileRequirement],
        verificationChecklist: [ChecklistItem],
        dependencies: [String]
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.description = description
        self.estimatedHours = estimatedHours
        self.deliverable = deliverable
        self.files = files
        self.verificationChecklist = verificationChecklist
        self.dependencies = dependencies
    }
}

public struct FileRequirement: Sendable, Codable, Identifiable {
    public var id: String { path }
    public let path: String // Relative to Development/
    public let status: FileStatus
    public let description: String
    public let codeHints: [String] // Implementation hints from spec
    public let estimatedLines: Int?

    public enum FileStatus: String, Codable, Sendable {
        case new = "NEW"
        case edit = "EDIT"
        case exists = "EXISTS"
    }
}

public struct ChecklistItem: Sendable, Codable, Identifiable {
    public let id: UUID
    public let description: String
    public var completed: Bool
    public let verificationMethod: VerificationMethod

    public enum VerificationMethod: String, Codable, Sendable {
        case buildSucceeds
        case testPasses
        case fileExists
        case manualCheck
        case screenVerification
    }
}

public struct ExecutionProgress: Sendable, Codable {
    public let phaseId: String
    public var currentFileIndex: Int
    public var filesCompleted: [String]
    public var filesFailed: [String]
    public var startTime: Date
    public var lastUpdateTime: Date
    public var status: ExecutionStatus
    public var errorLog: [String]

    public enum ExecutionStatus: String, Codable, Sendable {
        case notStarted
        case inProgress
        case waitingForApproval
        case paused
        case completed
        case failed
    }
}
