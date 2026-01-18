#if os(macOS)
// SelfExecutionService.swift
import Foundation
import OSLog

/// Main entry point for Thea's self-execution capability.
/// This service enables Thea to execute phases from THEA_MASTER_SPEC.md autonomously.
public actor SelfExecutionService {
    public static let shared = SelfExecutionService()

    private let logger = Logger(subsystem: "com.thea.app", category: "SelfExecution")

    public enum ExecutionMode: String, Sendable {
        case automatic   // Execute with minimal approval gates
        case supervised  // Approval required at each step
        case dryRun      // Simulate without making changes
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

    /// Check if ready to execute (API keys configured)
    public func checkReadiness() async -> (ready: Bool, missingRequirements: [String]) {
        var missing: [String] = []

        // Check for at least one AI provider
        let hasAnthropic = UserDefaults.standard.string(forKey: "anthropic_api_key")?.isEmpty == false
        let hasOpenAI = UserDefaults.standard.string(forKey: "openai_api_key")?.isEmpty == false
        let hasOpenRouter = UserDefaults.standard.string(forKey: "openrouter_api_key")?.isEmpty == false

        if !hasAnthropic && !hasOpenAI && !hasOpenRouter {
            missing.append("No AI provider configured. Add an API key in Settings → Providers.")
        }

        // Check git
        let gitPath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/.git"
        if !FileManager.default.fileExists(atPath: gitPath) {
            missing.append("Git repository not initialized")
        }

        // Check spec file
        let specPath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/THEA_MASTER_SPEC.md"
        if !FileManager.default.fileExists(atPath: specPath) {
            missing.append("THEA_MASTER_SPEC.md not found")
        }

        return (missing.isEmpty, missing)
    }
}

#endif
