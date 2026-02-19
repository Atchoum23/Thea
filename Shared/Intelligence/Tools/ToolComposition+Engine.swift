// ToolComposition+Engine.swift
// Thea
//
// ToolResultCache and ToolCompositionEngine implementation.

import Foundation
import os.log

// MARK: - Tool Result Cache

/// Cache for tool results
public actor ToolResultCache {
    private var cache: [String: CachedResult] = [:]
    private let maxSize: Int
    private let defaultTTL: TimeInterval

    public init(maxSize: Int = 1000, defaultTTL: TimeInterval = 300) {
        self.maxSize = maxSize
        self.defaultTTL = defaultTTL
    }

    public struct CachedResult: Sendable {
        let result: [String: String]
        let timestamp: Date
        let ttl: TimeInterval
    }

    public func get(key: String) -> [String: String]? {
        guard let cached = cache[key] else { return nil }

        if Date().timeIntervalSince(cached.timestamp) > cached.ttl {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.result
    }

    public func set(key: String, result: [String: String], ttl: TimeInterval? = nil) {
        // Evict oldest if at capacity
        if cache.count >= maxSize {
            let oldest = cache.min { $0.value.timestamp < $1.value.timestamp }
            if let oldestKey = oldest?.key {
                cache.removeValue(forKey: oldestKey)
            }
        }

        cache[key] = CachedResult(
            result: result,
            timestamp: Date(),
            ttl: ttl ?? defaultTTL
        )
    }

    public func invalidate(key: String) {
        cache.removeValue(forKey: key)
    }

    public func clear() {
        cache.removeAll()
    }
}

// MARK: - Tool Composition Engine

/// Main engine for tool composition and execution
@MainActor
public final class ToolCompositionEngine: ObservableObject {
    public static let shared = ToolCompositionEngine()

    private let logger = Logger(subsystem: "com.thea.tools", category: "Composition")
    private let cache: ToolResultCache

    @Published public private(set) var registeredTools: [String: ComposableTool] = [:]
    @Published public private(set) var savedPipelines: [ToolPipeline] = []
    @Published public private(set) var isExecuting: Bool = false
    @Published public private(set) var currentPipeline: ToolPipeline?

    private init() {
        self.cache = ToolResultCache()
        registerBuiltInTools()
    }

    // MARK: - Tool Registration

    public func registerTool(_ tool: ComposableTool) {
        registeredTools[tool.id] = tool
        logger.info("Registered tool: \(tool.name) (\(tool.id))")
    }

    public func getTool(_ id: String) -> ComposableTool? {
        registeredTools[id]
    }

    // MARK: - Pipeline Management

    public func savePipeline(_ pipeline: ToolPipeline) {
        if let index = savedPipelines.firstIndex(where: { $0.id == pipeline.id }) {
            savedPipelines[index] = pipeline
        } else {
            savedPipelines.append(pipeline)
        }
        logger.info("Saved pipeline: \(pipeline.name)")
    }

    public func deletePipeline(_ id: UUID) {
        savedPipelines.removeAll { $0.id == id }
    }

    // MARK: - Pipeline Execution

    public func execute(_ pipeline: ToolPipeline, initialContext: [String: String] = [:]) async -> ToolPipelineResult {
        isExecuting = true
        currentPipeline = pipeline
        defer {
            isExecuting = false
            currentPipeline = nil
        }

        let startTime = Date()
        var context = ToolPipelineContext(variables: initialContext)
        var stepResults: [StepResult] = []

        logger.info("Starting pipeline: \(pipeline.name) with \(pipeline.steps.count) steps")

        if pipeline.isParallel {
            // Execute all steps in parallel
            stepResults = await executeParallel(pipeline.steps, context: &context)
        } else {
            // Execute steps sequentially
            for step in pipeline.steps {
                // Check condition
                if let condition = step.condition, !evaluateCondition(condition, context: context) {
                    logger.debug("Skipping step \(step.name): condition not met")
                    continue
                }

                // Execute step
                let result = await executeStep(step, context: &context, pipeline: pipeline)
                stepResults.append(result)

                // Store results in context
                for (outputName, varName) in step.outputMappings {
                    if let value = result.outputs[outputName] {
                        context.variables[varName] = value
                    }
                }

                // Handle errors
                if !result.success {
                    context.errors.append(ToolPipelineError(
                        stepId: step.id,
                        message: result.error ?? "Unknown error"
                    ))

                    switch pipeline.errorHandling {
                    case .stopOnError:
                        logger.error("Pipeline stopped at step \(step.name): \(result.error ?? "")")
                    case .continueOnError:
                        logger.warning("Continuing after error in step \(step.name)")
                        continue
                    case .retryThenContinue:
                        // Already retried in executeStep
                        continue
                    case .fallbackStep:
                        if let fallbackId = step.fallbackStep,
                           let fallbackStep = pipeline.steps.first(where: { $0.id == fallbackId }) {
                            let fallbackResult = await executeStep(fallbackStep, context: &context, pipeline: pipeline)
                            stepResults.append(fallbackResult)
                        }
                    }

                    if pipeline.errorHandling == .stopOnError {
                        break
                    }
                }
            }
        }

        let totalDuration = Date().timeIntervalSince(startTime)
        let success = stepResults.allSatisfy { $0.success } && context.errors.isEmpty

        logger.info("Pipeline \(pipeline.name) completed: \(success ? "success" : "failed") in \(String(format: "%.2f", totalDuration))s")

        return ToolPipelineResult(
            pipelineId: pipeline.id,
            success: success,
            stepResults: stepResults,
            finalOutputs: context.variables,
            totalDuration: totalDuration,
            errors: context.errors
        )
    }

    private func executeStep(
        _ step: PipelineStep,
        context: inout ToolPipelineContext,
        // periphery:ignore - Reserved: pipeline parameter kept for API compatibility
        pipeline: ToolPipeline
    ) async -> StepResult {
        let startTime = Date()
        var retryCount = 0

        // Resolve inputs
        let resolvedInputs = resolveInputs(step.inputs, context: context)

        // Check cache if tool is cacheable
        if let tool = registeredTools[step.toolId], tool.isCacheable {
            let cacheKey = "\(step.toolId):\(resolvedInputs.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"
            if let cachedResult = await cache.get(key: cacheKey) {
                logger.debug("Cache hit for step \(step.name)")
                return StepResult(
                    stepId: step.id,
                    success: true,
                    outputs: cachedResult,
                    duration: 0,
                    retryCount: 0
                )
            }
        }

        // Execute with retry
        while retryCount <= step.retryPolicy.maxRetries {
            do {
                let outputs = try await executeTool(step.toolId, inputs: resolvedInputs)
                let duration = Date().timeIntervalSince(startTime)

                // Cache result if cacheable
                if let tool = registeredTools[step.toolId], tool.isCacheable {
                    let cacheKey = "\(step.toolId):\(resolvedInputs.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"
                    await cache.set(key: cacheKey, result: outputs)
                }

                return StepResult(
                    stepId: step.id,
                    success: true,
                    outputs: outputs,
                    duration: duration,
                    retryCount: retryCount
                )
            } catch {
                retryCount += 1

                if retryCount <= step.retryPolicy.maxRetries {
                    let delay = step.retryPolicy.delaySeconds * pow(step.retryPolicy.backoffMultiplier, Double(retryCount - 1))
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        break
                    }
                    logger.debug("Retrying step \(step.name) (attempt \(retryCount))")
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    return StepResult(
                        stepId: step.id,
                        success: false,
                        duration: duration,
                        retryCount: retryCount - 1,
                        error: error.localizedDescription
                    )
                }
            }
        }

        // Should not reach here
        return StepResult(stepId: step.id, success: false, error: "Max retries exceeded")
    }

    private func executeParallel(_ steps: [PipelineStep], context: inout ToolPipelineContext) async -> [StepResult] {
        // Capture context as a copy before entering task group
        let capturedContext = context
        return await withTaskGroup(of: StepResult.self) { group in
            for step in steps {
                group.addTask {
                    // Use captured copy for parallel execution
                    await self.executeStepIsolated(step, context: capturedContext)
                }
            }

            var results: [StepResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func executeStepIsolated(_ step: PipelineStep, context: ToolPipelineContext) async -> StepResult {
        let startTime = Date()
        let resolvedInputs = resolveInputs(step.inputs, context: context)

        do {
            let outputs = try await executeTool(step.toolId, inputs: resolvedInputs)
            return StepResult(
                stepId: step.id,
                success: true,
                outputs: outputs,
                duration: Date().timeIntervalSince(startTime)
            )
        } catch {
            return StepResult(
                stepId: step.id,
                success: false,
                duration: Date().timeIntervalSince(startTime),
                error: error.localizedDescription
            )
        }
    }

    private func executeTool(_ toolId: String, inputs: [String: String]) async throws -> [String: String] {
        // Simulate tool execution
        // In production, this would call actual tool implementations
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        return ["result": "Executed \(toolId) with inputs: \(inputs)"]
    }

    // MARK: - Helpers

    private func resolveInputs(_ inputs: [String: InputMapping], context: ToolPipelineContext) -> [String: String] {
        var resolved: [String: String] = [:]

        for (name, mapping) in inputs {
            switch mapping {
            case .literal(let value):
                resolved[name] = value

            case .variable(let varName):
                resolved[name] = context.variables[varName] ?? ""

            case .previousOutput(let stepId, let outputName):
                if let result = context.stepResults[stepId] {
                    resolved[name] = result.outputs[outputName] ?? ""
                }

            case .expression(let expr):
                // Simple expression evaluation (in production, use proper parser)
                resolved[name] = evaluateExpression(expr, context: context)

            case .userInput:
                // Would need to request from user
                resolved[name] = ""
            }
        }

        return resolved
    }

    private func evaluateCondition(_ condition: StepCondition, context: ToolPipelineContext) -> Bool {
        switch condition {
        case .always:
            return true

        case .ifTrue(let variable):
            return context.variables[variable]?.lowercased() == "true"

        case .ifEquals(let variable, let value):
            return context.variables[variable] == value

        case .ifContains(let variable, let substring):
            return context.variables[variable]?.contains(substring) ?? false

        case .ifPreviousSucceeded(let stepId):
            return context.stepResults[stepId]?.success ?? false

        case .ifPreviousFailed(let stepId):
            return !(context.stepResults[stepId]?.success ?? true)

        case .custom:
            return true  // Would need expression evaluator
        }
    }

    private func evaluateExpression(_ expr: String, context: ToolPipelineContext) -> String {
        // Simple variable substitution
        var result = expr
        for (name, value) in context.variables {
            result = result.replacingOccurrences(of: "${\(name)}", with: value)
        }
        return result
    }

    // MARK: - Built-in Tools

    private func registerBuiltInTools() {
        registerTool(ComposableTool(
            id: "read_file",
            name: "Read File",
            description: "Read contents of a file",
            category: .fileSystem,
            inputSchema: [
                ComposableTool.ParameterSchema(name: "path", type: .string, description: "File path")
            ],
            outputSchema: [
                ComposableTool.ParameterSchema(name: "content", type: .string)
            ],
            isIdempotent: true,
            isCacheable: true,
            requiredPermissions: [.readFile]
        ))

        registerTool(ComposableTool(
            id: "write_file",
            name: "Write File",
            description: "Write contents to a file",
            category: .fileSystem,
            inputSchema: [
                ComposableTool.ParameterSchema(name: "path", type: .string),
                ComposableTool.ParameterSchema(name: "content", type: .string)
            ],
            requiredPermissions: [.writeFile]
        ))

        registerTool(ComposableTool(
            id: "search_code",
            name: "Search Code",
            description: "Search for patterns in codebase",
            category: .codeAnalysis,
            inputSchema: [
                ComposableTool.ParameterSchema(name: "pattern", type: .string),
                ComposableTool.ParameterSchema(name: "path", type: .string, isRequired: false)
            ],
            outputSchema: [
                ComposableTool.ParameterSchema(name: "matches", type: .array)
            ],
            isIdempotent: true,
            isCacheable: true,
            requiredPermissions: [.readFile]
        ))

        registerTool(ComposableTool(
            id: "execute_command",
            name: "Execute Command",
            description: "Execute a shell command",
            category: .execution,
            inputSchema: [
                ComposableTool.ParameterSchema(name: "command", type: .string)
            ],
            outputSchema: [
                ComposableTool.ParameterSchema(name: "stdout", type: .string),
                ComposableTool.ParameterSchema(name: "stderr", type: .string),
                ComposableTool.ParameterSchema(name: "exitCode", type: .number)
            ],
            requiredPermissions: [.executeCode, .systemAccess]
        ))

        registerTool(ComposableTool(
            id: "web_search",
            name: "Web Search",
            description: "Search the web",
            category: .webSearch,
            inputSchema: [
                ComposableTool.ParameterSchema(name: "query", type: .string)
            ],
            outputSchema: [
                ComposableTool.ParameterSchema(name: "results", type: .array)
            ],
            isIdempotent: true,
            isCacheable: true,
            estimatedDuration: 2.0,
            requiredPermissions: [.networkAccess]
        ))
    }
}
