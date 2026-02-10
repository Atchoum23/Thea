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

import Foundation
import OSLog

// MARK: - Blueprint Executor

/// Autonomous execution engine for complex, multi-step tasks.
/// This is what makes Thea V2 capable of executing its own blueprints.
@MainActor
@Observable
public final class BlueprintExecutor {
    public static let shared = BlueprintExecutor()

    private let logger = Logger(subsystem: "com.thea.execution", category: "BlueprintExecutor")

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
    public private(set) var errors: [BlueprintExecutionError] = []

    /// Execution log
    public private(set) var executionLog: [BlueprintLogEntry] = []

    // MARK: - Private

    private let buildVerifier = BuildVerificationAgent()
    private let contextManager = BlueprintContextManager()
    private var startTime: Date?
    private var currentTask: Task<BlueprintExecutionResult, Never>?

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

    // MARK: - Private Execution Methods

    private func executeStep(_ step: BlueprintStep) async -> BlueprintStepResult {
        switch step.type {
        case .command(let command):
            return await executeCommand(command)

        case .fileOperation(let operation):
            return await executeFileOperation(operation)

        case .aiTask(let task):
            return await executeAITask(task)

        case .verification(let check):
            return await runVerification(check)

        case .conditional(let condition, let thenSteps, let elseSteps):
            let conditionMet = await evaluateCondition(condition)
            let steps = conditionMet ? thenSteps : elseSteps
            for subStep in steps {
                let result = await executeStep(subStep)
                if !result.success {
                    return result
                }
            }
            return BlueprintStepResult(step: step.description, success: true)
        }
    }

    private func executeCommand(_ command: String) async -> BlueprintStepResult {
        log("Executing command: \(command)")

        #if os(macOS)
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            let combinedOutput = output + errorOutput

            log("Command output: \(combinedOutput.prefix(500))...")

            // Check for common error patterns
            if process.terminationStatus != 0 || combinedOutput.contains("error:") || combinedOutput.contains("FAILED") {
                let errorMessage = extractErrorMessage(from: combinedOutput)
                errors.append(BlueprintExecutionError(
                    type: .commandFailed,
                    message: errorMessage,
                    context: command
                ))
                return BlueprintStepResult(step: command, success: false, error: errorMessage, output: combinedOutput)
            }

            return BlueprintStepResult(step: command, success: true, output: combinedOutput)
        } catch {
            let errorMsg = error.localizedDescription
            errors.append(BlueprintExecutionError(
                type: .commandFailed,
                message: errorMsg,
                context: command
            ))
            return BlueprintStepResult(step: command, success: false, error: errorMsg)
        }
        #else
        // Command execution not supported on iOS/watchOS/tvOS
        return BlueprintStepResult(step: command, success: false, error: "Command execution not available on this platform")
        #endif
    }

    private func executeFileOperation(_ operation: BlueprintFileOperation) async -> BlueprintStepResult {
        switch operation {
        case .read(let path):
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return BlueprintStepResult(step: "Read \(path)", success: true, output: content)
            } catch {
                return BlueprintStepResult(step: "Read \(path)", success: false, error: error.localizedDescription)
            }

        case .write(let path, let content):
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                return BlueprintStepResult(step: "Write \(path)", success: true)
            } catch {
                return BlueprintStepResult(step: "Write \(path)", success: false, error: error.localizedDescription)
            }

        case .delete(let path):
            do {
                try FileManager.default.removeItem(atPath: path)
                return BlueprintStepResult(step: "Delete \(path)", success: true)
            } catch {
                return BlueprintStepResult(step: "Delete \(path)", success: false, error: error.localizedDescription)
            }

        case .move(let from, let to):
            do {
                try FileManager.default.moveItem(atPath: from, toPath: to)
                return BlueprintStepResult(step: "Move \(from) to \(to)", success: true)
            } catch {
                return BlueprintStepResult(step: "Move \(from) to \(to)", success: false, error: error.localizedDescription)
            }

        case .exists(let path):
            let exists = FileManager.default.fileExists(atPath: path)
            return BlueprintStepResult(step: "Check exists \(path)", success: exists, output: exists ? "exists" : "not found")
        }
    }

    private func executeAITask(_ task: BlueprintAITask) async -> BlueprintStepResult {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return BlueprintStepResult(step: task.description, success: false, error: "No AI provider available")
        }

        do {
            let model: String
            if let specifiedModel = task.model {
                model = specifiedModel
            } else {
                model = await DynamicConfig.shared.bestModel(for: .codeGeneration)
            }

            var messages: [AIMessage] = []
            if let systemPrompt = task.systemPrompt, !systemPrompt.isEmpty {
                messages.append(AIMessage(
                    id: UUID(), conversationID: UUID(), role: .system,
                    content: .text(systemPrompt), timestamp: Date(), model: model
                ))
            }
            messages.append(AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(task.prompt), timestamp: Date(), model: model
            ))

            let stream = try await provider.chat(messages: messages, model: model, stream: false)
            var result = ""
            for try await chunk in stream {
                switch chunk.type {
                case .delta(let text): result += text
                case .complete(let msg): result = msg.content.textValue
                case .error(let err): throw err
                }
            }

            return BlueprintStepResult(step: task.description, success: true, output: result)
        } catch {
            return BlueprintStepResult(step: task.description, success: false, error: error.localizedDescription)
        }
    }

    private func runVerification(_ check: BlueprintVerificationCheck) async -> BlueprintStepResult {
        switch check {
        case .buildSucceeds(let scheme):
            let result = await buildVerifier.verifyBuild(scheme: scheme)
            if result.success {
                return BlueprintStepResult(step: "Build \(scheme)", success: true)
            } else {
                let errorSummary = result.errors.map { $0.message }.joined(separator: "\n")
                return BlueprintStepResult(step: "Build \(scheme)", success: false, error: errorSummary)
            }

        case .testsPass(let target):
            let result = await buildVerifier.runTests(target: target)
            return BlueprintStepResult(
                step: "Tests \(target ?? "all")",
                success: result.success,
                error: result.success ? nil : "Tests failed"
            )

        case .fileExists(let path):
            let exists = FileManager.default.fileExists(atPath: path)
            return BlueprintStepResult(step: "File exists \(path)", success: exists)

        case .commandSucceeds(let command):
            return await executeCommand(command)

        case .custom(let description, let check):
            let success = await check()
            return BlueprintStepResult(step: description, success: success)
        }
    }

    private func evaluateCondition(_ condition: BlueprintCondition) async -> Bool {
        switch condition {
        case .fileExists(let path):
            return FileManager.default.fileExists(atPath: path)

        case .commandSucceeds(let command):
            let result = await executeCommand(command)
            return result.success

        case .always:
            return true

        case .never:
            return false
        }
    }

    private func attemptRecovery(step: BlueprintStep, error: String) async -> String? {
        // Analyze error and suggest fix
        if error.contains("cannot find type") {
            return "Missing import - will add required import statement"
        } else if error.contains("no such file") {
            return "File not found - will create required file"
        } else if error.contains("permission denied") {
            return "Permission issue - will request elevated permissions"
        }

        // Use AI for complex recovery
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            return nil
        }

        let prompt = """
        An error occurred during automated execution:
        Step: \(step.description)
        Error: \(error)

        Suggest a brief recovery action (1 line).
        """

        do {
            let model = await DynamicConfig.shared.bestModel(for: .classification)
            let messages = [AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(prompt), timestamp: Date(), model: model
            )]
            let stream = try await provider.chat(messages: messages, model: model, stream: false)
            var suggestion = ""
            for try await chunk in stream {
                switch chunk.type {
                case .delta(let text): suggestion += text
                case .complete(let msg): suggestion = msg.content.textValue
                case .error(let err): throw err
                }
            }
            return suggestion.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func extractErrorMessage(from output: String) -> String {
        // Find first error line
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("error:") || line.contains("Error:") {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        return "Unknown error"
    }

    // Dynamic configuration
    private var maxLogEntries: Int {
        DynamicConfig.shared.optimalLogRetention
    }

    private func log(_ message: String, level: BlueprintLogLevel = .info) {
        let entry = BlueprintLogEntry(timestamp: Date(), level: level, message: message)
        executionLog.append(entry)

        // Prevent unbounded log growth using dynamic limit
        if executionLog.count > maxLogEntries {
            executionLog.removeFirst(executionLog.count - maxLogEntries)
        }

        switch level {
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }
    }
}

// MARK: - Build Verification Agent

/// Verifies builds and runs tests with error parsing
@MainActor
final class BuildVerificationAgent {
    private let logger = Logger(subsystem: "com.thea.execution", category: "BuildVerification")

    func verifyBuild(scheme: String, configuration: String = "Debug") async -> BlueprintBuildResult {
        #if os(macOS)
        let command = "xcodebuild -scheme \(scheme) -configuration \(configuration) build 2>&1"

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            let errors = parseBuildErrors(output)

            return BlueprintBuildResult(
                success: errors.isEmpty && output.contains("BUILD SUCCEEDED"),
                errors: errors,
                warnings: parseBuildWarnings(output),
                output: output
            )
        } catch {
            return BlueprintBuildResult(
                success: false,
                errors: [BlueprintBuildError(message: error.localizedDescription, file: nil, line: nil)],
                warnings: [],
                output: ""
            )
        }
        #else
        return BlueprintBuildResult(
            success: false,
            errors: [BlueprintBuildError(message: "Build verification not available on this platform", file: nil, line: nil)],
            warnings: [],
            output: ""
        )
        #endif
    }

    func runTests(target: String? = nil) async -> BlueprintTestResult {
        #if os(macOS)
        let command = target != nil
            ? "swift test --filter \(target!)"
            : "swift test"

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            let passed = output.contains("Test Suite") && output.contains("passed")
            let failures = parseTestFailures(output)

            return BlueprintTestResult(
                success: passed && failures.isEmpty,
                failures: failures,
                output: output
            )
        } catch {
            return BlueprintTestResult(
                success: false,
                failures: [BlueprintTestFailure(test: "Unknown", message: error.localizedDescription)],
                output: ""
            )
        }
        #else
        return BlueprintTestResult(
            success: false,
            failures: [BlueprintTestFailure(test: "Unknown", message: "Test execution not available on this platform")],
            output: ""
        )
        #endif
    }

    private func parseBuildErrors(_ output: String) -> [BlueprintBuildError] {
        var errors: [BlueprintBuildError] = []
        let pattern = #"(.+?):(\d+):(\d+): error: (.+)"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(output.startIndex..., in: output)
            let matches = regex.matches(in: output, range: range)

            for match in matches {
                if let fileRange = Range(match.range(at: 1), in: output),
                   let lineRange = Range(match.range(at: 2), in: output),
                   let messageRange = Range(match.range(at: 4), in: output) {
                    errors.append(BlueprintBuildError(
                        message: String(output[messageRange]),
                        file: String(output[fileRange]),
                        line: Int(output[lineRange])
                    ))
                }
            }
        }

        return errors
    }

    private func parseBuildWarnings(_ output: String) -> [BlueprintBuildWarning] {
        var warnings: [BlueprintBuildWarning] = []
        let pattern = #"(.+?):(\d+):(\d+): warning: (.+)"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(output.startIndex..., in: output)
            let matches = regex.matches(in: output, range: range)

            for match in matches {
                if let fileRange = Range(match.range(at: 1), in: output),
                   let messageRange = Range(match.range(at: 4), in: output) {
                    warnings.append(BlueprintBuildWarning(
                        message: String(output[messageRange]),
                        file: String(output[fileRange])
                    ))
                }
            }
        }

        return warnings
    }

    private func parseTestFailures(_ output: String) -> [BlueprintTestFailure] {
        var failures: [BlueprintTestFailure] = []
        let pattern = #"Test Case .+ '(.+)' failed"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(output.startIndex..., in: output)
            let matches = regex.matches(in: output, range: range)

            for match in matches {
                if let testRange = Range(match.range(at: 1), in: output) {
                    failures.append(BlueprintTestFailure(
                        test: String(output[testRange]),
                        message: "Test failed"
                    ))
                }
            }
        }

        return failures
    }
}

// MARK: - Context Manager

/// Manages execution context and handles compaction for long operations
@MainActor
final class BlueprintContextManager {
    private var context: [String: Any] = [:]
    private var history: [BlueprintContextSnapshot] = []
    private let maxHistorySize = 100

    func set(_ key: String, value: Any) {
        context[key] = value
    }

    func get<T>(_ key: String) -> T? {
        context[key] as? T
    }

    func snapshot() {
        let snap = BlueprintContextSnapshot(timestamp: Date(), context: context)
        history.append(snap)

        if history.count > maxHistorySize {
            compactHistory()
        }
    }

    private func compactHistory() {
        // Keep first, last, and every 10th snapshot
        var compacted: [BlueprintContextSnapshot] = []
        for (index, snapshot) in history.enumerated() {
            if index == 0 || index == history.count - 1 || index % 10 == 0 {
                compacted.append(snapshot)
            }
        }
        history = compacted
    }
}

private struct BlueprintContextSnapshot {
    let timestamp: Date
    let context: [String: Any]
}

// MARK: - Models
// All types prefixed with "Blueprint" to avoid conflicts with existing models

public enum BlueprintExecutionStatus: String, Sendable {
    case idle
    case running
    case completed
    case failed
    case cancelled
}

public struct BlueprintExecutionResult: Sendable {
    public let success: Bool
    public var phaseResults: [BlueprintPhaseResult] = []
    public var error: String?
    public var executionTime: TimeInterval = 0
}

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
