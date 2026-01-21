// ProgressTracker.swift
import Foundation
import OSLog

public actor ProgressTracker {
    public static let shared = ProgressTracker()

    private let logger = Logger(subsystem: "com.thea.app", category: "ProgressTracker")

    // Configurable project path - can be set at runtime
    private var _configuredPath: String?

    /// Set a custom project path (useful when running from installed app)
    public func setProjectPath(_ path: String) {
        _configuredPath = path
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

    private func getProgressFile() async -> String {
        (await getBasePath() as NSString).appendingPathComponent(".thea_progress.json")
    }

    private var currentProgress: ExecutionProgress?

    // MARK: - Public API

    public func startPhase(_ phaseId: String) async throws {
        let progress = ExecutionProgress(
            phaseId: phaseId,
            currentFileIndex: 0,
            filesCompleted: [],
            filesFailed: [],
            startTime: Date(),
            lastUpdateTime: Date(),
            status: .inProgress,
            errorLog: []
        )

        currentProgress = progress
        try await saveProgress()

        logger.info("Started tracking phase: \(phaseId)")
    }

    public func updateProgress(
        fileCompleted: String? = nil,
        fileFailed: String? = nil,
        error: String? = nil,
        status: ExecutionProgress.ExecutionStatus? = nil
    ) async throws {
        guard var progress = currentProgress else {
            logger.warning("No active progress to update")
            return
        }

        if let file = fileCompleted {
            progress.filesCompleted.append(file)
            progress.currentFileIndex += 1
        }

        if let file = fileFailed {
            progress.filesFailed.append(file)
        }

        if let errorMsg = error {
            progress.errorLog.append("[\(Date())] \(errorMsg)")
        }

        if let newStatus = status {
            progress.status = newStatus
        }

        progress.lastUpdateTime = Date()
        currentProgress = progress

        try await saveProgress()
    }

    public func completePhase() async throws {
        guard var progress = currentProgress else { return }

        progress.status = .completed
        progress.lastUpdateTime = Date()
        currentProgress = progress

        try await saveProgress()

        logger.info("Completed phase: \(progress.phaseId)")
    }

    public func failPhase(reason: String) async throws {
        guard var progress = currentProgress else { return }

        progress.status = .failed
        progress.errorLog.append("[\(Date())] FAILED: \(reason)")
        progress.lastUpdateTime = Date()
        currentProgress = progress

        try await saveProgress()

        logger.error("Failed phase: \(progress.phaseId) - \(reason)")
    }

    public func loadProgress() async -> ExecutionProgress? {
        guard FileManager.default.fileExists(atPath: await getProgressFile()) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: await getProgressFile()))
            let progress = try JSONDecoder().decode(ExecutionProgress.self, from: data)
            currentProgress = progress
            return progress
        } catch {
            logger.error("Failed to load progress: \(error.localizedDescription)")
            return nil
        }
    }

    public func canResume() async -> Bool {
        guard let progress = await loadProgress() else { return false }
        return progress.status == .inProgress || progress.status == .waitingForApproval
    }

    public func getResumePoint() async -> (phaseId: String, fileIndex: Int)? {
        guard let progress = await loadProgress(),
              progress.status == .inProgress else {
            return nil
        }
        return (progress.phaseId, progress.currentFileIndex)
    }

    public func clearProgress() async throws {
        currentProgress = nil
        try? FileManager.default.removeItem(atPath: await getProgressFile())
        logger.info("Cleared progress tracking")
    }

    // MARK: - Private

    private func saveProgress() async throws {
        guard let progress = currentProgress else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(progress)
        try data.write(to: URL(fileURLWithPath: await getProgressFile()))
    }
}
