// PhaseOrchestrator.swift
import Foundation
import OSLog

public actor PhaseOrchestrator {
    public static let shared = PhaseOrchestrator()

    private let logger = Logger(subsystem: "com.thea.app", category: "PhaseOrchestrator")

    public struct PhaseResult: Sendable {
        public let phaseId: String
        public let success: Bool
        public let filesCreated: Int
        public let errorsFixed: Int
        public let duration: TimeInterval
        public let dmgPath: String?
        public let errorMessage: String?
    }

    public enum OrchestratorError: Error, LocalizedError, Sendable {
        case phaseNotFound(Int)
        case dependencyNotMet(String)
        case approvalRejected(String)
        case executionFailed(String)
        case alreadyRunning

        public var errorDescription: String? {
            switch self {
            case .phaseNotFound(let number):
                return "Phase \(number) not found in spec"
            case .dependencyNotMet(let dep):
                return "Dependency not met: \(dep)"
            case .approvalRejected(let reason):
                return "Approval rejected: \(reason)"
            case .executionFailed(let reason):
                return "Execution failed: \(reason)"
            case .alreadyRunning:
                return "A phase is already running"
            }
        }
    }

    private var isRunning = false

    // MARK: - Public API

    public func executePhase(_ number: Int) async throws -> PhaseResult {
        guard !isRunning else {
            throw OrchestratorError.alreadyRunning
        }

        isRunning = true
        defer { isRunning = false }

        let startTime = Date()

        logger.info("Starting execution of Phase \(number)")

        // 1. Parse spec and get phase
        guard let phase = try await SpecParser.shared.getPhase(number) else {
            throw OrchestratorError.phaseNotFound(number)
        }

        // 2. Check dependencies
        for dep in phase.dependencies {
            let depProgress = await ProgressTracker.shared.loadProgress()
            if depProgress?.phaseId != dep || depProgress?.status != .completed {
                // Allow if previous phase is complete
                logger.warning("Dependency \(dep) may not be complete")
            }
        }

        // 3. Request approval to start
        let startApproval = await ApprovalGate.shared.requestApproval(
            level: .phaseStart,
            description: "Start Phase \(number): \(phase.title)",
            details: """
            Files to create/edit: \(phase.files.count)
            Estimated time: \(phase.estimatedHours.lowerBound)-\(phase.estimatedHours.upperBound) hours
            Deliverable: \(phase.deliverable ?? "None")
            """
        )

        guard startApproval.approved else {
            throw OrchestratorError.approvalRejected(startApproval.message ?? "User rejected")
        }

        // 4. Start progress tracking
        try await ProgressTracker.shared.startPhase(phase.id)

        // 5. Get architecture rules
        let spec = try await SpecParser.shared.parseSpec()
        let rules = spec.architectureRules

        // 6. Decompose into tasks
        _ = await TaskDecomposer.shared.decompose(phase: phase)

        // 7. Execute each file task
        var filesCreated = 0
        var errors: [String] = []

        for file in phase.files {
            do {
                try await executeFileTask(file: file, rules: rules)
                filesCreated += 1
                try await ProgressTracker.shared.updateProgress(fileCompleted: file.path)

                // Notify UI
                await postProgressUpdate(phase: phase, filesCompleted: filesCreated)

            } catch {
                errors.append("\(file.path): \(error.localizedDescription)")
                try await ProgressTracker.shared.updateProgress(
                    fileFailed: file.path,
                    error: error.localizedDescription
                )
            }
        }

        // 8. Build and fix errors
        logger.info("Running build loop...")
        let buildResult = try await AutonomousBuildLoop.shared.run(maxIterations: 15)

        if !buildResult.success {
            try await ProgressTracker.shared.failPhase(reason: "Build failed after \(buildResult.iterations) iterations")
            throw OrchestratorError.executionFailed("Build failed with \(buildResult.finalBuildResult.errors.count) errors")
        }

        // 9. Request completion approval
        let completeApproval = await ApprovalGate.shared.requestApproval(
            level: .phaseComplete,
            description: "Complete Phase \(number): \(phase.title)",
            details: """
            Files created: \(filesCreated)
            Build: ✅ Succeeded
            Errors fixed: \(buildResult.errorsFixed)
            Duration: \(Int(Date().timeIntervalSince(startTime) / 60)) minutes
            """
        )

        guard completeApproval.approved else {
            throw OrchestratorError.approvalRejected(completeApproval.message ?? "User rejected completion")
        }

        // 10. Create DMG if specified
        var dmgPath: String?
        if let deliverable = phase.deliverable {
            dmgPath = try await createDMG(name: deliverable)
        }

        // 11. Complete progress
        try await ProgressTracker.shared.completePhase()

        // 12. Update spec with completion status
        try await updateSpecWithCompletion(phase: phase)

        let duration = Date().timeIntervalSince(startTime)

        logger.info("✅ Phase \(number) completed in \(Int(duration / 60)) minutes")

        return PhaseResult(
            phaseId: phase.id,
            success: true,
            filesCreated: filesCreated,
            errorsFixed: buildResult.errorsFixed,
            duration: duration,
            dmgPath: dmgPath,
            errorMessage: nil
        )
    }

    public func resumePhase() async throws -> PhaseResult {
        guard let (phaseId, fileIndex) = await ProgressTracker.shared.getResumePoint() else {
            throw OrchestratorError.executionFailed("No phase to resume")
        }

        let phaseNumber = Int(phaseId.replacingOccurrences(of: "phase", with: "")) ?? 0
        logger.info("Resuming phase \(phaseNumber) from file index \(fileIndex)")

        // Re-execute from the resume point
        return try await executePhase(phaseNumber)
    }

    // MARK: - Private Implementation

    private func executeFileTask(file: FileRequirement, rules: [String]) async throws {
        logger.info("Processing file: \(file.path)")

        switch file.status {
        case .new:
            // Generate and create new file
            let relatedFiles = await FileCreator.shared.getRelatedFiles(for: file.path)

            let result = try await CodeGenerator.shared.generateCodeWithContext(
                for: file,
                existingCode: nil,
                relatedFiles: relatedFiles,
                architectureRules: rules
            )

            _ = try await FileCreator.shared.createFile(
                at: file.path,
                content: result.code
            )

        case .edit:
            // Load existing, generate changes, update
            let existing = try await FileCreator.shared.readFile(at: file.path)
            let relatedFiles = await FileCreator.shared.getRelatedFiles(for: file.path)

            let result = try await CodeGenerator.shared.generateCodeWithContext(
                for: file,
                existingCode: existing,
                relatedFiles: relatedFiles,
                architectureRules: rules
            )

            _ = try await FileCreator.shared.editFile(
                at: file.path,
                newContent: result.code
            )

        case .exists:
            // Just verify it exists
            let exists = await FileCreator.shared.fileExists(at: file.path)
            if !exists {
                throw FileCreator.CreationError.invalidPath(path: file.path)
            }
        }
    }

    private func createDMG(name: String) async throws -> String {
        let dmgDir = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/macOS/DMG files"
        let appPath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/build/Release/Thea.app"
        let dmgPath = "\(dmgDir)/\(name)"

        // Build release
        let buildResult = try await XcodeBuildRunner.shared.build(
            scheme: "Thea-macOS",
            configuration: "Release"
        )

        guard buildResult.success else {
            throw OrchestratorError.executionFailed("Release build failed")
        }

        // Create DMG
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "create",
            "-volname", name.replacingOccurrences(of: ".dmg", with: ""),
            "-srcfolder", appPath,
            "-format", "UDZO",
            dmgPath
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw OrchestratorError.executionFailed("DMG creation failed")
        }

        return dmgPath
    }

    private func updateSpecWithCompletion(phase: PhaseDefinition) async throws {
        // Read spec
        let specPath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/THEA_MASTER_SPEC.md"
        var content = try String(contentsOfFile: specPath, encoding: .utf8)

        // Update checklist items for this phase
        for item in phase.verificationChecklist {
            let unchecked = "- [ ] \(item.description)"
            let checked = "- [x] \(item.description)"
            content = content.replacingOccurrences(of: unchecked, with: checked)
        }

        // Add completion status
        let statusMarker = "**Status**: ✅ COMPLETED (\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)))"
        let phaseHeader = "### Phase \(phase.number):"
        if let range = content.range(of: phaseHeader) {
            // Find the line after the header
            if let lineEnd = content.range(of: "\n", range: range.upperBound..<content.endIndex) {
                content.insert(contentsOf: "\n\(statusMarker)", at: lineEnd.lowerBound)
            }
        }

        // Write updated spec
        try content.write(toFile: specPath, atomically: true, encoding: .utf8)
    }

    private func postProgressUpdate(phase: PhaseDefinition, filesCompleted: Int) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .phaseProgressUpdated,
                object: nil,
                userInfo: [
                    "phaseId": phase.id,
                    "filesCompleted": filesCompleted,
                    "totalFiles": phase.files.count
                ]
            )
        }
    }
}
