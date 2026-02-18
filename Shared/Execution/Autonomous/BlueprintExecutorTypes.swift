//
//  BlueprintExecutorTypes.swift
//  Thea
//
//  Supporting types for BlueprintExecutor
//

import Foundation

// MARK: - Models
// All types prefixed with "Blueprint" to avoid conflicts with existing models

/// Lifecycle status of a blueprint execution run.
public enum BlueprintExecutionStatus: String, Sendable {
    case idle
    case running
    case completed
    case failed
    case cancelled
}

/// The outcome of a completed blueprint execution, including per-phase results and diagnostics.
public struct BlueprintExecutionResult: Sendable {
    public let success: Bool
    public var phaseResults: [BlueprintPhaseResult] = []
    public var error: String?
    public var executionTime: TimeInterval = 0
}

/// The execution result for a single phase within a blueprint.
public struct BlueprintPhaseResult: Sendable {
    public let phase: String
    public let success: Bool
    public var stepResults: [BlueprintStepResult] = []
    public var error: String?
}

public struct BlueprintStepResult: Sendable {
    public let step: String
    public let success: Bool
    public var error: String?
    public var output: String?
}

public struct Blueprint: Sendable {
    public let name: String
    public let description: String
    public let phases: [BlueprintPhase]

    public init(name: String, description: String, phases: [BlueprintPhase]) {
        self.name = name
        self.description = description
        self.phases = phases
    }
}

public struct BlueprintPhase: Sendable {
    public let name: String
    public let description: String
    public let steps: [BlueprintStep]
    public var verification: BlueprintVerificationCheck?

    public init(name: String, description: String, steps: [BlueprintStep], verification: BlueprintVerificationCheck? = nil) {
        self.name = name
        self.description = description
        self.steps = steps
        self.verification = verification
    }
}

public struct BlueprintStep: Sendable {
    public let description: String
    public let type: BlueprintStepType

    public init(description: String, type: BlueprintStepType) {
        self.description = description
        self.type = type
    }
}

public enum BlueprintStepType: Sendable {
    case command(String)
    case fileOperation(BlueprintFileOperation)
    case aiTask(BlueprintAITask)
    case verification(BlueprintVerificationCheck)
    case conditional(BlueprintCondition, then: [BlueprintStep], else: [BlueprintStep])
}

public enum BlueprintFileOperation: Sendable {
    case read(String)
    case write(String, content: String)
    case delete(String)
    case move(from: String, to: String)
    case exists(String)
}

public struct BlueprintAITask: Sendable {
    public let description: String
    public let prompt: String
    public var systemPrompt: String?
    public var model: String?
    public var maxTokens: Int?

    public init(description: String, prompt: String, systemPrompt: String? = nil, model: String? = nil, maxTokens: Int? = nil) {
        self.description = description
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.model = model
        self.maxTokens = maxTokens
    }
}

public enum BlueprintVerificationCheck: Sendable {
    case buildSucceeds(scheme: String)
    case testsPass(target: String?)
    case fileExists(String)
    case commandSucceeds(String)
    case custom(description: String, check: @Sendable () async -> Bool)
}

public enum BlueprintCondition: Sendable {
    case fileExists(String)
    case commandSucceeds(String)
    case always
    case never
}

public struct BlueprintExecutionError: Sendable, Identifiable {
    public let id = UUID()
    public let type: ErrorType
    public let message: String
    public let context: String

    public enum ErrorType: String, Sendable {
        case commandFailed
        case buildFailed
        case testFailed
        case fileNotFound
        case permissionDenied
        case aiError
        case timeout
    }
}

public struct BlueprintBuildResult: Sendable {
    public let success: Bool
    public let errors: [BlueprintBuildError]
    public let warnings: [BlueprintBuildWarning]
    public let output: String
}

public struct BlueprintBuildError: Sendable {
    public let message: String
    public let file: String?
    public let line: Int?
}

public struct BlueprintBuildWarning: Sendable {
    public let message: String
    public let file: String?
}

public struct BlueprintTestResult: Sendable {
    public let success: Bool
    public let failures: [BlueprintTestFailure]
    public let output: String
}

public struct BlueprintTestFailure: Sendable {
    public let test: String
    public let message: String
}

public struct BlueprintLogEntry: Sendable, Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let level: BlueprintLogLevel
    public let message: String
}

public enum BlueprintLogLevel: String, Sendable {
    case info
    case warning
    case error
}
