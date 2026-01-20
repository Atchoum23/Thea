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

    // Dynamic base path for the project
    private var basePath: String {
        // 1. Use configured path if set
        if let configured = _configuredPath, FileManager.default.fileExists(atPath: configured) {
            return configured
        }

        // 2. Try environment variable
        if let envPath = ProcessInfo.processInfo.environment["THEA_PROJECT_PATH"],
           FileManager.default.fileExists(atPath: envPath) {
            return envPath
        }

        // 3. Try UserDefaults (persisted setting)
        if let savedPath = UserDefaults.standard.string(forKey: "TheaProjectPath"),
           FileManager.default.fileExists(atPath: savedPath) {
            return savedPath
        }

        // 4. Try Bundle path resolution (works when running from Xcode)
        if let bundlePath = Bundle.main.resourcePath {
            let appPath = (bundlePath as NSString).deletingLastPathComponent
            let devPath = (appPath as NSString).deletingLastPathComponent
            if FileManager.default.fileExists(atPath: (devPath as NSString).appendingPathComponent("Shared")) {
                return devPath
            }
        }

        // 5. Fallback to known development path
        return "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
    }

    private var progressFile: String {
        (basePath as NSString).appendingPathComponent(".thea_progress.json")
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
        guard FileManager.default.fileExists(atPath: progressFile) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: progressFile))
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
        try? FileManager.default.removeItem(atPath: progressFile)
        logger.info("Cleared progress tracking")
    }

    // MARK: - Private

    private func saveProgress() async throws {
        guard let progress = currentProgress else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(progress)
        try data.write(to: URL(fileURLWithPath: progressFile))
    }
}
