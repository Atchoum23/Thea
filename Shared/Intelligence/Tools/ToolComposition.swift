// ToolComposition.swift
// Thea V2
//
// Tool composition and chaining system
// Enables complex workflows with pipelines, conditional branching, and parallel execution

import Foundation
import OSLog

// MARK: - Tool Definition

/// Definition of a tool that can be composed
public struct ComposableTool: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let category: ToolCategory
    public let inputSchema: [ParameterSchema]
    public let outputSchema: [ParameterSchema]
    public let isIdempotent: Bool
    public let isCacheable: Bool
    public let estimatedDuration: TimeInterval
    public let requiredPermissions: Set<Permission>

    public init(
        id: String,
        name: String,
        description: String,
        category: ToolCategory,
        inputSchema: [ParameterSchema] = [],
        outputSchema: [ParameterSchema] = [],
        isIdempotent: Bool = false,
        isCacheable: Bool = false,
        estimatedDuration: TimeInterval = 1.0,
        requiredPermissions: Set<Permission> = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.isIdempotent = isIdempotent
        self.isCacheable = isCacheable
        self.estimatedDuration = estimatedDuration
        self.requiredPermissions = requiredPermissions
    }

    public struct ParameterSchema: Sendable {
        public let name: String
        public let type: ParameterType
        public let isRequired: Bool
        public let defaultValue: String?
        public let description: String

        public init(
            name: String,
            type: ParameterType,
            isRequired: Bool = true,
            defaultValue: String? = nil,
            description: String = ""
        ) {
            self.name = name
            self.type = type
            self.isRequired = isRequired
            self.defaultValue = defaultValue
            self.description = description
        }

        public enum ParameterType: String, Sendable {
            case string, number, boolean, array, object, file, any
        }
    }

    public enum ToolCategory: String, Sendable {
        case fileSystem
        case codeAnalysis
        case webSearch
        case execution
        case communication
        case ai
        case utility
    }

    public enum Permission: String, Sendable {
        case readFile
        case writeFile
        case executeCode
        case networkAccess
        case systemAccess
    }
}

// MARK: - Tool Pipeline

/// A pipeline of tool calls
public struct ToolPipeline: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let steps: [PipelineStep]
    public let errorHandling: ErrorHandlingStrategy
    public let timeout: TimeInterval
    public let isParallel: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        steps: [PipelineStep],
        errorHandling: ErrorHandlingStrategy = .stopOnError,
        timeout: TimeInterval = 300,
        isParallel: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.errorHandling = errorHandling
        self.timeout = timeout
        self.isParallel = isParallel
    }

    public enum ErrorHandlingStrategy: String, Sendable {
        case stopOnError       // Stop pipeline on first error
        case continueOnError   // Continue with next step
        case retryThenContinue // Retry failed step, then continue
        case fallbackStep      // Execute fallback step
    }
}

/// A step in a pipeline
public struct PipelineStep: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let toolId: String
    public let inputs: [String: InputMapping]
    public let condition: StepCondition?
    public let retryPolicy: ToolRetryPolicy
    public let fallbackStep: UUID?
    public let outputMappings: [String: String]  // output name -> variable name

    public init(
        id: UUID = UUID(),
        name: String,
        toolId: String,
        inputs: [String: InputMapping] = [:],
        condition: StepCondition? = nil,
        retryPolicy: ToolRetryPolicy = .default,
        fallbackStep: UUID? = nil,
        outputMappings: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.toolId = toolId
        self.inputs = inputs
        self.condition = condition
        self.retryPolicy = retryPolicy
        self.fallbackStep = fallbackStep
        self.outputMappings = outputMappings
    }
}

/// Input mapping for a step
public enum InputMapping: Sendable {
    case literal(String)                  // Static value
    case variable(String)                 // From context variable
    case previousOutput(stepId: UUID, outputName: String)  // From previous step
    case expression(String)               // Evaluated expression
    case userInput(prompt: String)        // Request from user
}

/// Condition for executing a step
public enum StepCondition: Sendable {
    case always
    case ifTrue(variable: String)
    case ifEquals(variable: String, value: String)
    case ifContains(variable: String, substring: String)
    case ifPreviousSucceeded(stepId: UUID)
    case ifPreviousFailed(stepId: UUID)
    case custom(expression: String)
}

/// Retry policy for a step
public struct ToolRetryPolicy: Sendable {
    public let maxRetries: Int
    public let delaySeconds: Double
    public let backoffMultiplier: Double

    public static let `default` = ToolRetryPolicy(maxRetries: 2, delaySeconds: 1.0, backoffMultiplier: 2.0)
    public static let none = ToolRetryPolicy(maxRetries: 0, delaySeconds: 0, backoffMultiplier: 1.0)
    public static let aggressive = ToolRetryPolicy(maxRetries: 5, delaySeconds: 0.5, backoffMultiplier: 1.5)

    public init(maxRetries: Int, delaySeconds: Double, backoffMultiplier: Double) {
        self.maxRetries = maxRetries
        self.delaySeconds = delaySeconds
        self.backoffMultiplier = backoffMultiplier
    }
}

// MARK: - Execution Context

/// Context for pipeline execution
public struct ToolPipelineContext: Sendable {
    public var variables: [String: String]
    public var stepResults: [UUID: StepResult]
    public var errors: [ToolPipelineError]
    public var startTime: Date
    public var currentStepIndex: Int

    public init(
        variables: [String: String] = [:],
        stepResults: [UUID: StepResult] = [:],
        errors: [ToolPipelineError] = [],
        startTime: Date = Date(),
        currentStepIndex: Int = 0
    ) {
        self.variables = variables
        self.stepResults = stepResults
        self.errors = errors
        self.startTime = startTime
        self.currentStepIndex = currentStepIndex
    }
}

/// Result of a single step
public struct StepResult: Sendable {
    public let stepId: UUID
    public let success: Bool
    public let outputs: [String: String]
    public let duration: TimeInterval
    public let retryCount: Int
    public let error: String?

    public init(
        stepId: UUID,
        success: Bool,
        outputs: [String: String] = [:],
        duration: TimeInterval = 0,
        retryCount: Int = 0,
        error: String? = nil
    ) {
        self.stepId = stepId
        self.success = success
        self.outputs = outputs
        self.duration = duration
        self.retryCount = retryCount
        self.error = error
    }
}

/// Pipeline execution error
public struct ToolPipelineError: Identifiable, Sendable {
    public let id: UUID
    public let stepId: UUID?
    public let message: String
    public let isRecoverable: Bool
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        stepId: UUID? = nil,
        message: String,
        isRecoverable: Bool = true,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stepId = stepId
        self.message = message
        self.isRecoverable = isRecoverable
        self.timestamp = timestamp
    }
}

// MARK: - Pipeline Result

/// Result of pipeline execution
public struct ToolPipelineResult: Sendable {
    public let pipelineId: UUID
    public let success: Bool
    public let stepResults: [StepResult]
    public let finalOutputs: [String: String]
    public let totalDuration: TimeInterval
    public let errors: [ToolPipelineError]

    public init(
        pipelineId: UUID,
        success: Bool,
        stepResults: [StepResult],
        finalOutputs: [String: String],
        totalDuration: TimeInterval,
        errors: [ToolPipelineError]
    ) {
        self.pipelineId = pipelineId
        self.success = success
        self.stepResults = stepResults
        self.finalOutputs = finalOutputs
        self.totalDuration = totalDuration
        self.errors = errors
    }
}

