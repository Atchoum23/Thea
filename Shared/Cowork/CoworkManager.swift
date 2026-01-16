import Foundation
import SwiftUI

/// Main manager for Cowork functionality
/// Coordinates sessions, tasks, and execution
@MainActor
@Observable
final class CoworkManager {
    static let shared = CoworkManager()

    // MARK: - State

    var isEnabled: Bool = true
    var sessions: [CoworkSession] = []
    var currentSession: CoworkSession?
    var isProcessing: Bool = false

    // MARK: - Configuration

    var defaultWorkingDirectory: URL
    var maxConcurrentTasks: Int = 3
    var autoSaveArtifacts: Bool = true
    var requireConfirmationForDeletions: Bool = true
    var previewPlanBeforeExecution: Bool = true
    var maxFilesPerOperation: Int = 100
    var backupBeforeModification: Bool = true

    // MARK: - Managers

    let folderAccess = FolderAccessManager.shared
    let skills = CoworkSkillsManager.shared
    let fileOps = FileOperationsManager()

    // MARK: - Callbacks

    var onStepStarted: ((CoworkStep) -> Void)?
    var onStepCompleted: ((CoworkStep) -> Void)?
    var onArtifactCreated: ((CoworkArtifact) -> Void)?
    var onSessionCompleted: ((CoworkSession) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Initialization

    private init() {
        defaultWorkingDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser

        loadConfiguration()
    }

    // MARK: - Session Management

    @discardableResult
    func createSession(name: String? = nil, workingDirectory: URL? = nil) -> CoworkSession {
        let session = CoworkSession(
            name: name ?? "Session \(sessions.count + 1)",
            workingDirectory: workingDirectory ?? defaultWorkingDirectory
        )
        sessions.append(session)
        currentSession = session
        return session
    }

    func deleteSession(_ session: CoworkSession) {
        sessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id {
            currentSession = sessions.first
        }
    }

    func switchToSession(_ session: CoworkSession) {
        currentSession = session
    }

    // MARK: - Plan Creation

    /// Create a plan for a task instruction
    func createPlan(
        for instruction: String,
        in session: CoworkSession? = nil
    ) async throws -> [CoworkStep] {
        let targetSession = session ?? currentSession ?? createSession()
        targetSession.status = .planning
        targetSession.context.userInstructions = instruction

        // This would typically call an LLM to generate steps
        // For now, return a simple placeholder
        let steps = await generateSteps(for: instruction, context: targetSession.context)

        for (index, var step) in steps.enumerated() {
            step.stepNumber = index + 1
            targetSession.addStep(step)
        }

        targetSession.status = .awaitingApproval
        return targetSession.steps
    }

    /// Generate steps from instruction (placeholder for LLM integration)
    private func generateSteps(for instruction: String, context: CoworkContext) async -> [CoworkStep] {
        // This would integrate with the AI orchestrator
        // For now, return a basic template

        var steps: [CoworkStep] = []

        // Simple heuristic-based step generation
        let lowercased = instruction.lowercased()

        if lowercased.contains("organize") || lowercased.contains("sort") {
            steps.append(CoworkStep.builder()
                .number(1)
                .description("Scan directory for files")
                .tool("FileScanner")
                .build())

            steps.append(CoworkStep.builder()
                .number(2)
                .description("Analyze file types and dates")
                .tool("FileAnalyzer")
                .build())

            steps.append(CoworkStep.builder()
                .number(3)
                .description("Create organization structure")
                .tool("DirectoryCreator")
                .build())

            steps.append(CoworkStep.builder()
                .number(4)
                .description("Move files to organized locations")
                .tool("FileMover")
                .build())

            steps.append(CoworkStep.builder()
                .number(5)
                .description("Generate organization report")
                .tool("ReportGenerator")
                .build())
        } else if lowercased.contains("create") || lowercased.contains("generate") {
            steps.append(CoworkStep.builder()
                .number(1)
                .description("Analyze requirements")
                .tool("RequirementAnalyzer")
                .build())

            steps.append(CoworkStep.builder()
                .number(2)
                .description("Generate content")
                .tool("ContentGenerator")
                .build())

            steps.append(CoworkStep.builder()
                .number(3)
                .description("Save to file")
                .tool("FileWriter")
                .build())
        } else {
            // Default single-step plan
            steps.append(CoworkStep.builder()
                .number(1)
                .description("Execute task: \(instruction)")
                .build())
        }

        return steps
    }

    // MARK: - Execution

    /// Execute the current session's plan
    func executePlan(session: CoworkSession? = nil) async throws {
        let targetSession = session ?? currentSession
        guard let targetSession else {
            throw CoworkError.noActiveSession
        }

        guard targetSession.status == .awaitingApproval || targetSession.status == .paused else {
            throw CoworkError.invalidSessionState(targetSession.status)
        }

        targetSession.execute()
        isProcessing = true

        do {
            for stepIndex in targetSession.steps.indices {
                guard targetSession.status == .executing else { break }

                var step = targetSession.steps[stepIndex]
                guard step.status == .pending else { continue }

                // Start step
                step.start()
                targetSession.steps[stepIndex] = step
                onStepStarted?(step)

                // Execute step
                do {
                    try await executeStep(&step, in: targetSession)
                    step.complete()
                    onStepCompleted?(step)
                } catch {
                    step.fail(with: error.localizedDescription)
                    onError?(error)

                    // Decide whether to continue or fail
                    if case CoworkError.criticalError = error {
                        targetSession.fail(with: error.localizedDescription)
                        break
                    }
                }

                targetSession.steps[stepIndex] = step
            }

            if targetSession.status == .executing {
                targetSession.complete()
                onSessionCompleted?(targetSession)
            }
        } catch {
            targetSession.fail(with: error.localizedDescription)
            onError?(error)
        }

        isProcessing = false
    }

    /// Execute a single step
    private func executeStep(_ step: inout CoworkStep, in session: CoworkSession) async throws {
        // Log the execution
        step.addLog(.info, "Executing: \(step.description)")

        // Simulate step execution with tool-specific logic
        for tool in step.toolsUsed {
            step.addLog(.debug, "Using tool: \(tool)")

            switch tool {
            case "FileScanner":
                let files = try fileOps.listDirectory(at: session.workingDirectory)
                for file in files {
                    step.addInputFile(file)
                    session.context.trackFileRead(file)
                }

            case "FileMover":
                // Files would be moved based on previous analysis
                break

            case "FileWriter":
                // Create output file
                let outputURL = session.workingDirectory.appendingPathComponent("output.txt")
                try "Generated content".write(to: outputURL, atomically: true, encoding: .utf8)
                step.addOutputFile(outputURL)
                session.addArtifact(from: outputURL, stepId: step.id)
                session.context.trackFileWrite(outputURL)

            case "ReportGenerator":
                let reportURL = session.workingDirectory.appendingPathComponent("report.md")
                let report = generateReport(for: session)
                try report.write(to: reportURL, atomically: true, encoding: .utf8)
                step.addOutputFile(reportURL)
                session.addArtifact(from: reportURL, stepId: step.id)

            default:
                step.addLog(.debug, "Tool \(tool) not implemented")
            }
        }

        // Simulate some work
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    /// Generate a summary report for a session
    private func generateReport(for session: CoworkSession) -> String {
        let summary = session.summary
        return """
        # Cowork Session Report

        **Session:** \(session.name)
        **Status:** \(session.status.rawValue)
        **Duration:** \(String(format: "%.1f", summary.duration)) seconds

        ## Summary

        - Total Steps: \(summary.totalSteps)
        - Completed: \(summary.completedSteps)
        - Failed: \(summary.failedSteps)
        - Success Rate: \(String(format: "%.0f%%", summary.successRate * 100))

        ## Artifacts

        - Total: \(summary.totalArtifacts)
        - Final Outputs: \(summary.finalArtifacts)
        - Total Size: \(ByteCountFormatter.string(fromByteCount: summary.totalSize, countStyle: .file))

        ## Files

        - Accessed: \(summary.filesAccessed)
        - Modified: \(summary.filesModified)

        ---
        Generated by Thea Cowork
        """
    }

    // MARK: - Task Queue

    func queueTask(_ instruction: String, priority: CoworkTask.TaskPriority = .normal) {
        guard let session = currentSession else { return }
        session.taskQueue.enqueue(instruction: instruction, priority: priority)
    }

    func processQueue() async {
        guard let session = currentSession else { return }

        // Create a local reference to avoid capturing self in the closure
        let manager = self
        let targetSession = session

        await session.taskQueue.startProcessing { task in
            let steps = try await manager.createPlan(for: task.instruction, in: targetSession)
            if !steps.isEmpty {
                try await manager.executePlan(session: targetSession)
            }
        }
    }

    // MARK: - Pause/Resume

    func pause() {
        currentSession?.pause()
        isProcessing = false
    }

    func resume() async throws {
        guard let session = currentSession else { return }
        session.resume()
        try await executePlan(session: session)
    }

    func cancel() {
        currentSession?.taskQueue.cancelAll()
        currentSession?.fail(with: "Cancelled by user")
        isProcessing = false
    }

    // MARK: - Configuration

    func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "cowork.isEnabled")
        defaults.set(defaultWorkingDirectory.path, forKey: "cowork.defaultWorkingDirectory")
        defaults.set(maxConcurrentTasks, forKey: "cowork.maxConcurrentTasks")
        defaults.set(autoSaveArtifacts, forKey: "cowork.autoSaveArtifacts")
        defaults.set(requireConfirmationForDeletions, forKey: "cowork.requireConfirmationForDeletions")
        defaults.set(previewPlanBeforeExecution, forKey: "cowork.previewPlanBeforeExecution")
        defaults.set(maxFilesPerOperation, forKey: "cowork.maxFilesPerOperation")
        defaults.set(backupBeforeModification, forKey: "cowork.backupBeforeModification")
    }

    private func loadConfiguration() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "cowork.isEnabled") != nil {
            isEnabled = defaults.bool(forKey: "cowork.isEnabled")
        }

        if let path = defaults.string(forKey: "cowork.defaultWorkingDirectory") {
            defaultWorkingDirectory = URL(fileURLWithPath: path)
        }

        if defaults.object(forKey: "cowork.maxConcurrentTasks") != nil {
            maxConcurrentTasks = defaults.integer(forKey: "cowork.maxConcurrentTasks")
        }

        autoSaveArtifacts = defaults.object(forKey: "cowork.autoSaveArtifacts") == nil
            ? true
            : defaults.bool(forKey: "cowork.autoSaveArtifacts")

        requireConfirmationForDeletions = defaults.object(forKey: "cowork.requireConfirmationForDeletions") == nil
            ? true
            : defaults.bool(forKey: "cowork.requireConfirmationForDeletions")

        previewPlanBeforeExecution = defaults.object(forKey: "cowork.previewPlanBeforeExecution") == nil
            ? true
            : defaults.bool(forKey: "cowork.previewPlanBeforeExecution")

        if defaults.object(forKey: "cowork.maxFilesPerOperation") != nil {
            maxFilesPerOperation = defaults.integer(forKey: "cowork.maxFilesPerOperation")
        }

        backupBeforeModification = defaults.object(forKey: "cowork.backupBeforeModification") == nil
            ? true
            : defaults.bool(forKey: "cowork.backupBeforeModification")
    }
}

// MARK: - Errors

enum CoworkError: LocalizedError {
    case noActiveSession
    case invalidSessionState(CoworkSession.SessionStatus)
    case folderAccessDenied(URL)
    case criticalError(String)
    case planRejected

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active Cowork session"
        case .invalidSessionState(let status):
            return "Invalid session state: \(status.rawValue)"
        case .folderAccessDenied(let url):
            return "Access denied to folder: \(url.path)"
        case .criticalError(let message):
            return "Critical error: \(message)"
        case .planRejected:
            return "Plan was rejected by user"
        }
    }
}
