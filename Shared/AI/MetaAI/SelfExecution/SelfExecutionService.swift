#if os(macOS)
// SelfExecutionService.swift
import Foundation
import OSLog

/// Main entry point for Thea's self-execution capability.
/// This service enables Thea to execute phases from THEA_MASTER_SPEC.md autonomously.
public actor SelfExecutionService {
    public static let shared = SelfExecutionService()

    private let logger = Logger(subsystem: "com.thea.app", category: "SelfExecution")

    // SECURITY FIX (FINDING-014): Removed fullAuto mode which bypassed all approval gates
    // The "fullAuto" mode was a security risk as it allowed execution without any user oversight
    public enum ExecutionMode: String, Sendable {
        case automatic   // Execute with minimal approval gates (still requires approval for destructive ops)
        case supervised  // Approval required at each step (default, recommended)
        case dryRun      // Simulate without making changes
        // NOTE: fullAuto mode has been removed for security reasons - all operations now require appropriate approvals
    }

    public struct ExecutionRequest: Sendable {
        public let phaseNumber: Int
        public let mode: ExecutionMode
        public let continueOnError: Bool

        public init(phaseNumber: Int, mode: ExecutionMode = .supervised, continueOnError: Bool = false) {
            self.phaseNumber = phaseNumber
            self.mode = mode
            self.continueOnError = continueOnError
        }
    }

    public struct ExecutionSummary: Sendable {
        public let phasesExecuted: [Int]
        public let totalFilesCreated: Int
        public let totalErrorsFixed: Int
        public let totalDuration: TimeInterval
        public let dmgPaths: [String]
        public let errors: [String]
    }

    // MARK: - Public API

    /// Execute a single phase
    public func execute(request: ExecutionRequest) async throws -> PhaseOrchestrator.PhaseResult {
        logger.info("Executing phase \(request.phaseNumber) in \(request.mode.rawValue) mode")

        // Configure approval mode
        await ApprovalGate.shared.setVerboseMode(request.mode == .supervised)

        // Create git savepoint
        _ = try await GitSavepoint.shared.createSavepoint(
            message: "Pre-Phase-\(request.phaseNumber) savepoint"
        )

        // Execute
        return try await PhaseOrchestrator.shared.executePhase(request.phaseNumber)
    }

    /// Execute multiple phases in sequence
    public func executePhases(from startPhase: Int, to endPhase: Int, mode: ExecutionMode) async throws -> ExecutionSummary {
        logger.info("Executing phases \(startPhase) to \(endPhase)")

        var phasesExecuted: [Int] = []
        var totalFilesCreated = 0
        var totalErrorsFixed = 0
        var dmgPaths: [String] = []
        var errors: [String] = []
        let startTime = Date()

        for phaseNum in startPhase...endPhase {
            do {
                let result = try await execute(request: ExecutionRequest(
                    phaseNumber: phaseNum,
                    mode: mode
                ))

                phasesExecuted.append(phaseNum)
                totalFilesCreated += result.filesCreated
                totalErrorsFixed += result.errorsFixed
                if let dmg = result.dmgPath {
                    dmgPaths.append(dmg)
                }
            } catch {
                errors.append("Phase \(phaseNum): \(error.localizedDescription)")
                logger.error("Phase \(phaseNum) failed: \(error.localizedDescription)")
                break // Stop on first error
            }
        }

        return ExecutionSummary(
            phasesExecuted: phasesExecuted,
            totalFilesCreated: totalFilesCreated,
            totalErrorsFixed: totalErrorsFixed,
            totalDuration: Date().timeIntervalSince(startTime),
            dmgPaths: dmgPaths,
            errors: errors
        )
    }

    /// Resume from last checkpoint
    public func resume() async throws -> PhaseOrchestrator.PhaseResult {
        logger.info("Resuming from checkpoint")
        return try await PhaseOrchestrator.shared.resumePhase()
    }

    /// Get current spec status
    public func getSpecStatus() async throws -> SpecParser.ParsedSpec {
        try await SpecParser.shared.parseSpec()
    }

    /// Get next phase to execute
    public func getNextPhase() async throws -> PhaseDefinition? {
        let spec = try await SpecParser.shared.parseSpec()

        // Find first incomplete phase
        for phase in spec.phases {
            let allComplete = phase.verificationChecklist.allSatisfy { $0.completed }
            if !allComplete {
                return phase
            }
        }

        return nil
    }

    // Configurable project path - can be set at runtime
    private var _configuredPath: String?

    /// Set a custom project path (useful when running from installed app)
    public func setProjectPath(_ path: String) {
        _configuredPath = path
        // Also save to UserDefaults for persistence
        UserDefaults.standard.set(path, forKey: "TheaProjectPath")
    }

    // Dynamic base path - SECURITY: No hardcoded paths
    private func getBasePath() async -> String {
        if let configured = _configuredPath, FileManager.default.fileExists(atPath: configured) {
            return configured
        }

        // Use centralized ProjectPathManager
        if let path = await MainActor.run(body: { ProjectPathManager.shared.projectPath }) {
            return path
        }

        // Fallback to current working directory
        return FileManager.default.currentDirectoryPath
    }

    /// Check if ready to execute (API keys configured)
    public func checkReadiness() async -> (ready: Bool, missingRequirements: [String]) {
        var missing: [String] = []

        // Check for at least one AI provider via SecureStorage (Keychain)
        let hasAnthropic = await MainActor.run { SecureStorage.shared.hasAPIKey(for: "anthropic") }
        let hasOpenAI = await MainActor.run { SecureStorage.shared.hasAPIKey(for: "openai") }
        let hasOpenRouter = await MainActor.run { SecureStorage.shared.hasAPIKey(for: "openrouter") }

        if !hasAnthropic && !hasOpenAI && !hasOpenRouter {
            missing.append("No AI provider configured. Add an API key in Settings → Providers.")
        }

        // Check git
        let base = await getBasePath()
        let gitPath = (base as NSString).appendingPathComponent(".git")
        if !FileManager.default.fileExists(atPath: gitPath) {
            missing.append("Git repository not initialized")
        }

        // Check spec file - look in multiple locations
        let specLocations = [
            (base as NSString).appendingPathComponent("THEA_MASTER_SPEC.md"),
            (base as NSString).appendingPathComponent("Planning/THEA_SPECIFICATION.md"),
            (base as NSString).appendingPathComponent("Documentation/Architecture/THEA_MASTER_SPEC.md")
        ]

        let hasSpec = specLocations.contains { FileManager.default.fileExists(atPath: $0) }
        if !hasSpec {
            missing.append("THEA_MASTER_SPEC.md not found (checked Planning/ and Documentation/Architecture/)")
        }

        return (missing.isEmpty, missing)
    }

    // MARK: - Execution Control

    private var isCancelled = false

    /// Cancel the current execution
    public func cancelExecution() async {
        isCancelled = true
        logger.info("Execution cancelled by user")
    }

    /// Check if execution was cancelled
    public func checkCancellation() async -> Bool {
        isCancelled
    }

    /// Reset cancellation flag
    public func resetCancellation() async {
        isCancelled = false
    }
}

#endif
