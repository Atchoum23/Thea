// ExecutionPipeline.swift
import Foundation
import OSLog

/// Orchestrates multi-step task execution with error recovery and progress tracking.
/// Provides a robust framework for executing complex AI workflows with automatic retry,
/// checkpointing, and graceful degradation.
@MainActor
@Observable
public final class ExecutionPipeline {
    public static let shared = ExecutionPipeline()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "ExecutionPipeline")

    /// Currently running pipelines
    public private(set) var activePipelines: [PipelineExecution] = []

    /// Completed pipeline history (limited to last 50)
    public private(set) var pipelineHistory: [PipelineExecution] = []

    /// Configuration for pipeline behavior
    public var config = PipelineConfig()

    private init() {}

    // MARK: - Pipeline Execution

    // Execute a pipeline with the given stages
    // swiftlint:disable:next function_body_length
    public func execute(
        _ pipeline: Pipeline,
        input: [String: Any] = [:],
        progressHandler: @escaping @Sendable (PipelineProgress) -> Void
    ) async throws -> PipelineResult {
        logger.info("Starting pipeline: \(pipeline.name) with \(pipeline.stages.count) stages")

        let execution = PipelineExecution(
            id: UUID(),
            pipelineId: pipeline.id,
            pipelineName: pipeline.name,
            startTime: Date(),
            status: .running,
            currentStage: nil,
            completedStages: [],
            stageResults: [:],
            errors: []
        )

        activePipelines.append(execution)

        defer {
            execution.endTime = Date()
            activePipelines.removeAll { $0.id == execution.id }
            addToHistory(execution)
        }

        var context = PipelineContext(input: input)

        do {
            for (index, stage) in pipeline.stages.enumerated() {
                execution.currentStage = stage.id

                let progress = PipelineProgress(
                    pipelineId: pipeline.id,
                    currentStageIndex: index,
                    totalStages: pipeline.stages.count,
                    stageName: stage.name,
                    stageProgress: 0,
                    overallProgress: Float(index) / Float(pipeline.stages.count),
                    message: "Executing: \(stage.name)"
                )
                progressHandler(progress)

                // Execute stage with retry logic
                let stageResult = try await executeStageWithRetry(
                    stage,
                    context: context,
                    execution: execution
                ) { stageProgress in
                    var updatedProgress = progress
                    updatedProgress.stageProgress = stageProgress
                    updatedProgress.message = "Stage \(stage.name): \(Int(stageProgress * 100))%"
                    progressHandler(updatedProgress)
                }

                // Store result and update context
                execution.stageResults[stage.id] = stageResult
                execution.completedStages.append(stage.id)
                context = context.with(stageResult: stageResult, forStage: stage.name)

                // Check for early termination conditions
                if stageResult.shouldTerminate {
                    logger.info("Pipeline terminated early at stage: \(stage.name)")
                    break
                }
            }

            execution.status = .completed

            let finalProgress = PipelineProgress(
                pipelineId: pipeline.id,
                currentStageIndex: pipeline.stages.count,
                totalStages: pipeline.stages.count,
                stageName: "Complete",
                stageProgress: 1.0,
                overallProgress: 1.0,
                message: "Pipeline completed successfully"
            )
            progressHandler(finalProgress)

            return PipelineResult(
                executionId: execution.id,
                success: true,
                finalOutput: context.output,
                stageResults: execution.stageResults,
                duration: Date().timeIntervalSince(execution.startTime),
                errors: []
            )

        } catch {
            execution.status = .failed
            execution.errors.append(PipelineError(
                stageId: execution.currentStage,
                error: error.localizedDescription,
                timestamp: Date(),
                recoverable: false
            ))

            logger.error("Pipeline failed: \(error.localizedDescription)")

            return PipelineResult(
                executionId: execution.id,
                success: false,
                finalOutput: context.output,
                stageResults: execution.stageResults,
                duration: Date().timeIntervalSince(execution.startTime),
                errors: execution.errors.map(\.error)
            )
        }
    }

    // MARK: - Stage Execution

    private func executeStageWithRetry(
        _ stage: PipelineStage,
        context: PipelineContext,
        execution: PipelineExecution,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> StageResult {
        var lastError: Error?
        let maxRetries = stage.retryPolicy?.maxRetries ?? config.defaultMaxRetries

        for attempt in 0 ... maxRetries {
            do {
                if attempt > 0 {
                    let delay = calculateBackoffDelay(attempt: attempt, policy: stage.retryPolicy)
                    logger.info("Retrying stage \(stage.name) after \(delay)s (attempt \(attempt + 1)/\(maxRetries + 1))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                return try await executeStage(stage, context: context, progressHandler: progressHandler)

            } catch {
                lastError = error

                execution.errors.append(PipelineError(
                    stageId: stage.id,
                    error: error.localizedDescription,
                    timestamp: Date(),
                    recoverable: attempt < maxRetries
                ))

                // Check if error is retryable
                if !isRetryableError(error) {
                    throw error
                }
            }
        }

        throw lastError ?? PipelineExecutionError.stageExecutionFailed("Unknown error")
    }

    private func executeStage(
        _ stage: PipelineStage,
        context: PipelineContext,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> StageResult {
        logger.info("Executing stage: \(stage.name)")

        let startTime = Date()
        progressHandler(0.1)

        // Execute based on stage type
        let output: [String: Any] = switch stage.type {
        case .aiInference:
            try await executeAIInferenceStage(stage, context: context)

        case .toolExecution:
            try await executeToolStage(stage, context: context)

        case .dataTransformation:
            executeTransformationStage(stage, context: context)

        case .conditional:
            executeConditionalStage(stage, context: context)

        case .aggregation:
            await executeAggregationStage(stage, context: context)

        case .validation:
            try executeValidationStage(stage, context: context)

        case .custom:
            try await executeCustomStage(stage, context: context)
        }

        progressHandler(1.0)

        return StageResult(
            stageId: stage.id,
            stageName: stage.name,
            success: true,
            output: output,
            duration: Date().timeIntervalSince(startTime),
            shouldTerminate: output["_terminate"] as? Bool ?? false
        )
    }

    // MARK: - Stage Type Implementations

    private func executeAIInferenceStage(_ stage: PipelineStage, context: PipelineContext) async throws -> [String: Any] {
        guard let prompt = stage.config["prompt"] as? String else {
            throw PipelineExecutionError.invalidStageConfig("AI inference stage requires 'prompt' config")
        }

        // Substitute context variables in prompt
        let resolvedPrompt = resolveTemplate(prompt, with: context)

        // Get provider and model from config
        let defaultProviderId = SettingsManager.shared.defaultProvider
        let providerId = stage.config["provider"] as? String ?? defaultProviderId
        let model = stage.config["model"] as? String ?? "gpt-4o"

        guard let provider = ProviderRegistry.shared.getProvider(id: providerId) else {
            throw PipelineExecutionError.providerNotAvailable(providerId)
        }

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(resolvedPrompt),
            timestamp: Date(),
            model: model
        )

        var result = ""
        let stream = try await provider.chat(messages: [message], model: model, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                result += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return ["output": result, "model": model, "provider": providerId]
    }

    private func executeToolStage(_ stage: PipelineStage, context: PipelineContext) async throws -> [String: Any] {
        guard let toolName = stage.config["tool"] as? String else {
            throw PipelineExecutionError.invalidStageConfig("Tool stage requires 'tool' config")
        }

        let toolFramework = ToolFramework.shared
        guard let tool = toolFramework.registeredTools.first(where: { $0.name == toolName }) else {
            throw PipelineExecutionError.toolNotFound(toolName)
        }

        // Merge stage config with context for tool parameters
        var parameters = stage.config["parameters"] as? [String: Any] ?? [:]
        for (key, value) in context.output {
            if parameters[key] == nil {
                parameters[key] = value
            }
        }

        let result = try await toolFramework.executeTool(tool, parameters: parameters)

        return [
            "output": result.output ?? "",
            "success": result.success,
            "tool": toolName
        ]
    }

    private func executeTransformationStage(_ stage: PipelineStage, context: PipelineContext) -> [String: Any] {
        guard let transformType = stage.config["transform"] as? String else {
            return context.output
        }

        var output = context.output

        switch transformType {
        case "map":
            if let key = stage.config["key"] as? String,
               let array = output[key] as? [Any],
               let expression = stage.config["expression"] as? String
            {
                output[key] = array.map { item in
                    // Simple expression evaluation
                    "\(item)" + (expression.contains("uppercase") ? String(describing: item).uppercased() : "")
                }
            }

        case "filter":
            if let key = stage.config["key"] as? String,
               let array = output[key] as? [String],
               let predicate = stage.config["predicate"] as? String
            {
                output[key] = array.filter { $0.contains(predicate) }
            }

        case "merge":
            if let keys = stage.config["keys"] as? [String] {
                var merged: [Any] = []
                for key in keys {
                    if let value = output[key] {
                        merged.append(value)
                    }
                }
                output["merged"] = merged
            }

        case "extract":
            if let sourceKey = stage.config["source"] as? String,
               let targetKey = stage.config["target"] as? String,
               let source = output[sourceKey] as? [String: Any],
               let path = stage.config["path"] as? String
            {
                output[targetKey] = source[path]
            }

        default:
            break
        }

        return output
    }

    private func executeConditionalStage(_ stage: PipelineStage, context: PipelineContext) -> [String: Any] {
        guard let condition = stage.config["condition"] as? String else {
            return ["result": false, "branch": "false"]
        }

        let result = evaluateCondition(condition, context: context)

        return [
            "result": result,
            "branch": result ? "true" : "false",
            "_terminate": stage.config["terminateOnFalse"] as? Bool == true && !result
        ]
    }

    private func executeAggregationStage(_ stage: PipelineStage, context: PipelineContext) async -> [String: Any] {
        // Collect results to aggregate
        var results: [AggregatorInput] = []

        if let sourceKeys = stage.config["sources"] as? [String] {
            for key in sourceKeys {
                if let content = context.output[key] as? String {
                    results.append(AggregatorInput(
                        source: key,
                        content: content,
                        confidence: 0.8
                    ))
                }
            }
        }

        let aggregated = await ResultAggregator.shared.aggregate(results)

        return [
            "output": aggregated.content,
            "confidence": aggregated.confidence,
            "sources": aggregated.sources,
            "conflictCount": aggregated.conflicts.count
        ]
    }

    private func executeValidationStage(_ stage: PipelineStage, context: PipelineContext) throws -> [String: Any] {
        var validationErrors: [String] = []

        // Required fields validation
        if let requiredFields = stage.config["required"] as? [String] {
            for field in requiredFields {
                if context.output[field] == nil {
                    validationErrors.append("Missing required field: \(field)")
                }
            }
        }

        // Type validation
        if let typeChecks = stage.config["types"] as? [String: String] {
            for (field, expectedType) in typeChecks {
                if let value = context.output[field] {
                    let actualType = String(describing: type(of: value))
                    if !actualType.lowercased().contains(expectedType.lowercased()) {
                        validationErrors.append("Type mismatch for \(field): expected \(expectedType), got \(actualType)")
                    }
                }
            }
        }

        let isValid = validationErrors.isEmpty

        if !isValid, stage.config["failOnInvalid"] as? Bool == true {
            throw PipelineExecutionError.validationFailed(validationErrors.joined(separator: "; "))
        }

        return [
            "valid": isValid,
            "errors": validationErrors,
            "_terminate": !isValid && stage.config["terminateOnInvalid"] as? Bool == true
        ]
    }

    private func executeCustomStage(_ stage: PipelineStage, context: PipelineContext) async throws -> [String: Any] {
        // Custom stages can be implemented via registered handlers
        logger.warning("Custom stage execution not fully implemented: \(stage.name)")
        return context.output
    }

    // MARK: - Helper Methods

    private func resolveTemplate(_ template: String, with context: PipelineContext) -> String {
        var resolved = template

        for (key, value) in context.output {
            resolved = resolved.replacingOccurrences(of: "{{\(key)}}", with: "\(value)")
        }

        for (key, value) in context.input {
            resolved = resolved.replacingOccurrences(of: "{{input.\(key)}}", with: "\(value)")
        }

        return resolved
    }

    private func evaluateCondition(_ condition: String, context: PipelineContext) -> Bool {
        // Simple condition evaluation
        if condition.contains("==") {
            let parts = condition.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                let lhsKey = parts[0].replacingOccurrences(of: "=", with: "")
                let rhs = parts[1].replacingOccurrences(of: "=", with: "")
                if let lhs = context.output[lhsKey] {
                    return rhs == "\(lhs)"
                }
            }
        }

        if condition.contains(">") {
            let parts = condition.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2,
               let lhsValue = context.output[parts[0]] as? Int,
               let rhsValue = Int(parts[1])
            {
                return lhsValue > rhsValue
            }
        }

        return false
    }

    private func calculateBackoffDelay(attempt: Int, policy: RetryPolicy?) -> Double {
        let baseDelay = policy?.baseDelay ?? config.defaultRetryDelay
        let maxDelay = policy?.maxDelay ?? 60.0

        switch policy?.backoffStrategy ?? .exponential {
        case .fixed:
            return baseDelay
        case .linear:
            return min(baseDelay * Double(attempt + 1), maxDelay)
        case .exponential:
            return min(baseDelay * pow(2, Double(attempt)), maxDelay)
        }
    }

    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors, timeouts, and rate limits are typically retryable
        let errorString = error.localizedDescription.lowercased()
        return errorString.contains("timeout") ||
            errorString.contains("network") ||
            errorString.contains("rate limit") ||
            errorString.contains("temporarily unavailable")
    }

    private func addToHistory(_ execution: PipelineExecution) {
        pipelineHistory.insert(execution, at: 0)
        if pipelineHistory.count > 50 {
            pipelineHistory.removeLast()
        }
    }

    // MARK: - Pipeline Management

    /// Cancel a running pipeline
    public func cancel(executionId: UUID) {
        if let execution = activePipelines.first(where: { $0.id == executionId }) {
            execution.status = .cancelled
            logger.info("Pipeline cancelled: \(executionId)")
        }
    }

    /// Get status of a pipeline execution
    public func getStatus(executionId: UUID) -> PipelineExecution? {
        activePipelines.first { $0.id == executionId } ??
            pipelineHistory.first { $0.id == executionId }
    }
}

// MARK: - Models

/// Pipeline definition
public struct Pipeline: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let stages: [PipelineStage]
    public let metadata: [String: String]

    public init(id: UUID = UUID(), name: String, description: String = "", stages: [PipelineStage], metadata: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.description = description
        self.stages = stages
        self.metadata = metadata
    }
}

/// Pipeline stage definition
public struct PipelineStage: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let name: String
    public let type: StageType
    public let config: [String: Any]
    public let retryPolicy: RetryPolicy?
    public let timeout: TimeInterval?

    public init(
        id: UUID = UUID(),
        name: String,
        type: StageType,
        config: [String: Any] = [:],
        retryPolicy: RetryPolicy? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.config = config
        self.retryPolicy = retryPolicy
        self.timeout = timeout
    }

    public enum StageType: Sendable {
        case aiInference
        case toolExecution
        case dataTransformation
        case conditional
        case aggregation
        case validation
        case custom
    }
}

/// Retry policy configuration
public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let baseDelay: Double
    public let maxDelay: Double
    public let backoffStrategy: BackoffStrategy

    public init(maxRetries: Int = 3, baseDelay: Double = 1.0, maxDelay: Double = 60.0, backoffStrategy: BackoffStrategy = .exponential) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffStrategy = backoffStrategy
    }

    public enum BackoffStrategy: Sendable {
        case fixed
        case linear
        case exponential
    }
}

/// Pipeline execution tracking
public class PipelineExecution: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let pipelineId: UUID
    public let pipelineName: String
    public let startTime: Date
    public var endTime: Date?
    public var status: ExecutionStatus
    public var currentStage: UUID?
    public var completedStages: [UUID]
    public var stageResults: [UUID: StageResult]
    public var errors: [PipelineError]

    public enum ExecutionStatus {
        case pending
        case running
        case completed
        case failed
        case cancelled
    }

    init(id: UUID, pipelineId: UUID, pipelineName: String, startTime: Date, status: ExecutionStatus, currentStage: UUID?, completedStages: [UUID], stageResults: [UUID: StageResult], errors: [PipelineError]) {
        self.id = id
        self.pipelineId = pipelineId
        self.pipelineName = pipelineName
        self.startTime = startTime
        self.status = status
        self.currentStage = currentStage
        self.completedStages = completedStages
        self.stageResults = stageResults
        self.errors = errors
    }
}

/// Result from a single stage
public struct StageResult: @unchecked Sendable {
    public let stageId: UUID
    public let stageName: String
    public let success: Bool
    public let output: [String: Any]
    public let duration: TimeInterval
    public let shouldTerminate: Bool
}

/// Final pipeline result
public struct PipelineResult: @unchecked Sendable {
    public let executionId: UUID
    public let success: Bool
    public let finalOutput: [String: Any]
    public let stageResults: [UUID: StageResult]
    public let duration: TimeInterval
    public let errors: [String]
}

/// Pipeline progress update
public struct PipelineProgress: Sendable {
    public let pipelineId: UUID
    public let currentStageIndex: Int
    public let totalStages: Int
    public var stageName: String
    public var stageProgress: Float
    public var overallProgress: Float
    public var message: String
}

/// Pipeline error record
public struct PipelineError: Sendable {
    public let stageId: UUID?
    public let error: String
    public let timestamp: Date
    public let recoverable: Bool
}

/// Context passed between pipeline stages
public struct PipelineContext: @unchecked Sendable {
    public let input: [String: Any]
    public var output: [String: Any]
    public var stageHistory: [String: [String: Any]]

    public init(input: [String: Any]) {
        self.input = input
        output = input
        stageHistory = [:]
    }

    public func with(stageResult: StageResult, forStage stageName: String) -> PipelineContext {
        var updated = self
        updated.stageHistory[stageName] = stageResult.output

        // Merge stage output into context output
        for (key, value) in stageResult.output where !key.hasPrefix("_") {
            updated.output[key] = value
        }

        return updated
    }
}

/// Pipeline configuration
public struct PipelineConfig: Sendable {
    public var defaultMaxRetries: Int = 3
    public var defaultRetryDelay: Double = 1.0
    public var defaultStageTimeout: TimeInterval = 300
    public var maxConcurrentPipelines: Int = 5
}

/// Pipeline execution errors
public enum PipelineExecutionError: LocalizedError {
    case invalidStageConfig(String)
    case stageExecutionFailed(String)
    case providerNotAvailable(String)
    case toolNotFound(String)
    case validationFailed(String)
    case timeout(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case let .invalidStageConfig(msg): "Invalid stage configuration: \(msg)"
        case let .stageExecutionFailed(msg): "Stage execution failed: \(msg)"
        case let .providerNotAvailable(id): "AI provider not available: \(id)"
        case let .toolNotFound(name): "Tool not found: \(name)"
        case let .validationFailed(msg): "Validation failed: \(msg)"
        case let .timeout(stage): "Stage timed out: \(stage)"
        case .cancelled: "Pipeline was cancelled"
        }
    }
}
