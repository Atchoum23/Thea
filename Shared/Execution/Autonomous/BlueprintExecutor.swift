// BlueprintExecutor.swift
// Thea V2
//
// Autonomous execution system for multi-step tasks.
// Enables Thea to execute complex operations like a human developer would:
// Plan → Execute → Verify → Fix → Repeat until success
//
// This makes Thea V2 capable of:
// - Executing multi-file code changes
// - Running and parsing build output
// - Automatically fixing errors and retrying
// - Managing context across long operations
// - Self-improving through learned patterns
//
// CREATED: February 2, 2026 - Making Thea self-sufficient
// SEE ALSO: V2_MIGRATION_COMPLETE.md for context
//
// Extension files:
//   BlueprintExecutor+StepExecution.swift  - Step/command/file/AI execution
//   BlueprintExecutor+Verification.swift   - Verification, recovery, logging

import Foundation
import OSLog

// MARK: - Blueprint Executor

/// Autonomous execution engine for complex, multi-step tasks.
/// This is what makes Thea V2 capable of executing its own blueprints.
@MainActor
@Observable
public final class BlueprintExecutor {
    public static let shared = BlueprintExecutor()

    let logger = Logger(subsystem: "com.thea.execution", category: "BlueprintExecutor")

    // MARK: - Configuration

    /// Maximum retry attempts per step
    public var maxRetries: Int = 3

    /// Maximum total execution time (seconds)
    public var maxExecutionTime: TimeInterval = 3600 // 1 hour

    /// Enable automatic error recovery
    public var autoRecovery: Bool = true

    /// Enable learning from successful patterns
    public var enableLearning: Bool = true

    // MARK: - State

    /// Current execution status
    public private(set) var status: BlueprintExecutionStatus = .idle

    /// Current phase being executed
    public private(set) var currentPhase: String = ""

    /// Current step within phase
    public private(set) var currentStep: Int = 0

    /// Total steps in current phase
    public private(set) var totalSteps: Int = 0

    /// Execution progress (0-1)
    public private(set) var progress: Double = 0

    /// Errors encountered during execution
    public var errors: [BlueprintExecutionError] = []

    /// Execution log
    public var executionLog: [BlueprintLogEntry] = []

    // MARK: - Internal

    let buildVerifier = BuildVerificationAgent()
    var startTime: Date?
    var currentTask: Task<BlueprintExecutionResult, Never>?

    /// Dynamic configuration for log retention
    var maxLogEntries: Int {
        DynamicConfig.shared.optimalLogRetention
    }

    private init() {}

    // MARK: - Public API

    /// Execute a blueprint with all its phases
    public func execute(blueprint: Blueprint) async -> BlueprintExecutionResult {
        guard status == .idle else {
            return BlueprintExecutionResult(success: false, error: "Executor is already running")
        }

        startTime = Date()
        status = .running
        errors = []
        executionLog = []
        progress = 0

        log("Starting blueprint execution: \(blueprint.name)")
        log("Total phases: \(blueprint.phases.count)")

        var allResults: [BlueprintPhaseResult] = []

        for (index, phase) in blueprint.phases.enumerated() {
            currentPhase = phase.name
            progress = Double(index) / Double(blueprint.phases.count)

            log("Starting phase \(index + 1)/\(blueprint.phases.count): \(phase.name)")

            let result = await executePhase(phase)
            allResults.append(result)

            if !result.success {
                log("Phase failed: \(phase.name)", level: .error)
                status = .failed
                return BlueprintExecutionResult(
                    success: false,
                    phaseResults: allResults,
                    error: "Phase '\(phase.name)' failed: \(result.error ?? "Unknown error")"
                )
            }

            log("Phase completed: \(phase.name)")

            // Check time limit
            if let start = startTime, Date().timeIntervalSince(start) > maxExecutionTime {
                log("Execution time limit exceeded", level: .error)
                status = .failed
                return BlueprintExecutionResult(
                    success: false,
                    phaseResults: allResults,
                    error: "Execution time limit exceeded"
                )
            }
        }

        progress = 1.0
        status = .completed
        log("Blueprint execution completed successfully")

        return BlueprintExecutionResult(
            success: true,
            phaseResults: allResults,
            executionTime: Date().timeIntervalSince(startTime ?? Date())
        )
    }

    /// Execute a single phase with retry logic
    public func executePhase(_ phase: BlueprintPhase) async -> BlueprintPhaseResult {
        currentStep = 0
        totalSteps = phase.steps.count

        var stepResults: [BlueprintStepResult] = []

        for (index, step) in phase.steps.enumerated() {
            currentStep = index + 1
            log("Executing step \(index + 1)/\(phase.steps.count): \(step.description)")

            var attempts = 0
            var lastError: String?

            while attempts < maxRetries {
                attempts += 1

                let result = await executeStep(step)

                if result.success {
                    stepResults.append(result)
                    break
                } else {
                    lastError = result.error
                    log("Step failed (attempt \(attempts)/\(maxRetries)): \(result.error ?? "Unknown")", level: .warning)

                    if autoRecovery && attempts < maxRetries {
                        log("Attempting automatic recovery...")
                        if let recovery = await attemptRecovery(step: step, error: result.error ?? "") {
                            log("Recovery action: \(recovery)")
                        }
                    }
                }
            }

            if stepResults.count <= index {
                // Step failed after all retries
                return BlueprintPhaseResult(
                    phase: phase.name,
                    success: false,
                    stepResults: stepResults,
                    error: lastError
                )
            }
        }

        // Verify phase completion
        if let verification = phase.verification {
            log("Running phase verification...")
            let verifyResult = await runVerification(verification)
            if !verifyResult.success {
                return BlueprintPhaseResult(
                    phase: phase.name,
                    success: false,
                    stepResults: stepResults,
                    error: "Verification failed: \(verifyResult.error ?? "")"
                )
            }
        }

        return BlueprintPhaseResult(
            phase: phase.name,
            success: true,
            stepResults: stepResults
        )
    }

    /// Stop current execution
    public func stop() {
        currentTask?.cancel()
        status = .cancelled
        log("Execution cancelled by user")
    }

    /// Reset executor state
    public func reset() {
        status = .idle
        currentPhase = ""
        currentStep = 0
        totalSteps = 0
        progress = 0
        errors = []
        executionLog = []
    }
}

// Supporting types are in BlueprintExecutorTypes.swift
// Step execution is in BlueprintExecutor+StepExecution.swift
// Verification & recovery is in BlueprintExecutor+Verification.swift
// BuildVerificationAgent is in BuildVerificationAgent.swift
// BlueprintContextManager is in BlueprintContextManager.swift
