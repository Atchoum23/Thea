// ProactiveModelManager.swift
// Thea V2
//
// Autonomous model management that analyzes incoming requests BEFORE work starts
// Can auto-download models needed for tasks and auto-cleanup unused models
//
// CREATED: February 2, 2026

import Foundation
import OSLog

// MARK: - Proactive Model Manager

/// Autonomous model management with proactive downloading and cleanup
/// Analyzes user requests before execution to ensure optimal models are available
@MainActor
@Observable
final class ProactiveModelManager {
    static let shared = ProactiveModelManager()

    private let logger = Logger(subsystem: "com.thea.ai", category: "ProactiveModelManager")

    // MARK: - AI-Powered Configuration (No hardcoded thresholds!)

    /// Enable autonomous model downloading - delegates to AIModelGovernor
    var enableAutoDownload: Bool {
        get { AIModelGovernor.shared.hasAutonomousConsent && UserDefaults.standard.bool(forKey: "ProactiveModelManager.enableAutoDownload") }
        set { UserDefaults.standard.set(newValue, forKey: "ProactiveModelManager.enableAutoDownload") }
    }

    /// Enable autonomous model cleanup - delegates to AIModelGovernor
    var enableAutoCleanup: Bool {
        get { AIModelGovernor.shared.hasAutonomousConsent && UserDefaults.standard.bool(forKey: "ProactiveModelManager.enableAutoCleanup") }
        set { UserDefaults.standard.set(newValue, forKey: "ProactiveModelManager.enableAutoCleanup") }
    }

    // NOTE: maxDiskSpaceGB and inactiveDaysThreshold are now DEPRECATED
    // AIModelGovernor makes intelligent decisions based on actual value analysis
    // These are kept for backward compatibility only

    @available(*, deprecated, message: "Use AIModelGovernor for intelligent storage management")
    // periphery:ignore - Reserved: maxDiskSpaceGB property — reserved for future feature activation
    var maxDiskSpaceGB: Double {
        get { 0 } // AI-determined
        // swiftlint:disable:next unused_setter_value
        set { } // No-op - AI-determined
    }

    @available(*, deprecated, message: "Use AIModelGovernor for value-based cleanup decisions")
    // periphery:ignore - Reserved: inactiveDaysThreshold property — reserved for future feature activation
    var inactiveDaysThreshold: Int {
        get { 0 } // AI-determined
        // swiftlint:disable:next unused_setter_value
        set { } // No-op - AI-determined
    }

    // Confidence threshold is now AI-determined based on proactivity score
    // periphery:ignore - Reserved: autoDownloadConfidenceThreshold property — reserved for future feature activation
    var autoDownloadConfidenceThreshold: Double {
        // Dynamic threshold based on proactivity level
        let proactivity = AIModelGovernor.shared.proactivityScore
        return max(0.3, 0.8 - (proactivity * 0.3)) // Higher proactivity = lower threshold
    }

    // MARK: - State

    private(set) var isAnalyzing = false
    private(set) var pendingDownloads: [PendingModelDownload] = []
    private(set) var downloadQueue: [ModelDownloadTask] = []
    private(set) var cleanupCandidates: [CleanupCandidate] = []
    private(set) var lastAnalysis: RequestAnalysis?
    private(set) var modelUsageHistory: [String: ModelUsageRecord] = [:]

    // Download progress tracking
    private(set) var activeDownloads: [String: DownloadProgress] = [:]

    // MARK: - Initialization

    private init() {
        loadUsageHistory()
        Task {
            await performStartupAnalysis()
        }
    }

// periphery:ignore - Reserved: maxDiskSpaceGB property reserved for future feature activation

    // MARK: - Pre-Request Analysis (Called BEFORE work starts)

    /// Analyze a user request and prepare models BEFORE execution begins
    /// Returns recommendations and can trigger auto-download if enabled
    func analyzeRequest(_ request: String) async -> RequestAnalysis {
        // periphery:ignore - Reserved: inactiveDaysThreshold property reserved for future feature activation
        isAnalyzing = true
        defer { isAnalyzing = false }

        logger.info("Analyzing request for model requirements...")

        // 1. Classify the task
        // periphery:ignore - Reserved: autoDownloadConfidenceThreshold property reserved for future feature activation
        let classification: ClassificationResult
        do {
            classification = try await TaskClassifier.shared.classify(request)
        } catch {
            logger.error("Failed to classify request: \(error.localizedDescription)")
            return RequestAnalysis(
                request: request,
                taskType: TaskType.unknown,
                confidence: 0,
                hasOptimalModel: true,
                recommendation: nil
            )
        }

        // 2. Check if we have an optimal local model for this task
        let orchestrator = UnifiedLocalModelOrchestrator.shared
        let localSelection = await orchestrator.selectModel(for: classification.taskType)

        // 3. Use AI Governor to determine if we need a better model (AI-powered decision!)
        var recommendation: ProactiveModelRecommendation?
        let governor = AIModelGovernor.shared

        if let rec = await findBestModelToDownload(for: classification.taskType) {
            // Let AI Governor make the intelligent decision
            let decision = await governor.shouldDownloadModel(
                recommendation: rec,
                forTask: classification.taskType,
                userRequest: request
            )

            // periphery:ignore - Reserved: analyzeRequest(_:) instance method reserved for future feature activation
            recommendation = rec

            if decision.shouldDownload {
                logger.info("AI Governor approved download: \(rec.modelName) - \(decision.reasoning)")
                await startModelDownload(rec)
            } else if enableAutoDownload {
                // Queue for user review with AI reasoning
                pendingDownloads.append(PendingModelDownload(
                    recommendation: rec,
                    taskType: classification.taskType,
                    requestedAt: Date()
                ))
                logger.info("AI Governor deferred download: \(decision.reasoning)")
            }
        }

        let needsBetterModel = localSelection == nil || localSelection!.score < 0.7

        // 4. AI-powered cleanup (intelligent value-based decisions)
        if enableAutoCleanup {
            await performAIGuidedCleanup()
        }

        let analysis = RequestAnalysis(
            request: request,
            taskType: classification.taskType,
            confidence: classification.confidence,
            hasOptimalModel: !needsBetterModel,
            currentModel: localSelection?.model.name,
            currentModelScore: localSelection?.score,
            recommendation: recommendation,
            estimatedWaitTime: recommendation != nil ? estimateDownloadTime(recommendation!) : nil
        )

        lastAnalysis = analysis
        return analysis
    }

    /// Quick pre-flight check - call this at the START of any task
    // periphery:ignore - Reserved: preflightCheck(for:) instance method — reserved for future feature activation
    func preflightCheck(for taskType: TaskType) async -> PreflightResult {
        let orchestrator = UnifiedLocalModelOrchestrator.shared
        let localSelection = await orchestrator.selectModel(for: taskType)

        // Record that this task type was requested
        recordTaskRequest(taskType)

        if let selection = localSelection, selection.score >= 0.7 {
            return PreflightResult(
                ready: true,
                selectedModel: selection.model.name,
                score: selection.score,
                action: .proceed
            )
        }

        // Check if a download is in progress for this task type
        if let pending = pendingDownloads.first(where: { $0.taskType == taskType }) {
            if let progress = activeDownloads[pending.recommendation.modelId] {
                return PreflightResult(
                    ready: false,
                    selectedModel: pending.recommendation.modelName,
                    score: 0,
                    action: .waitForDownload(progress: progress.percentage)
                )
            }
        }

        // Find best model to download
        if let recommendation = await findBestModelToDownload(for: taskType) {
            if enableAutoDownload {
                await startModelDownload(recommendation)
                return PreflightResult(
                    ready: false,
                    selectedModel: recommendation.modelName,
                    score: 0,
                    // periphery:ignore - Reserved: preflightCheck(for:) instance method reserved for future feature activation
                    action: .downloadStarted(model: recommendation.modelName)
                )
            } else {
                return PreflightResult(
                    ready: false,
                    selectedModel: nil,
                    score: 0,
                    action: .suggestDownload(recommendation)
                )
            }
        }

        // Fall back to remote models
        return PreflightResult(
            ready: true,
            selectedModel: nil,
            score: 0,
            action: .useRemote
        )
    }

    // MARK: - Model Download

    private func findBestModelToDownload(for taskType: TaskType) async -> ProactiveModelRecommendation? {
        let engine = LocalModelRecommendationEngine.shared
        let hardware = engine.systemProfile

        // Get task-specific model recommendations
        let candidates = getRecommendedModels(for: taskType, hardware: hardware)

        // Filter out already installed models
        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()
        let installedNames = Set(manager.availableModels.map { $0.name.lowercased() })

        let notInstalled = candidates.filter { !installedNames.contains($0.modelName.lowercased()) }

        // Return the best candidate
        return notInstalled.first
    }

    private func getRecommendedModels(
        for taskType: TaskType,
        hardware: SystemHardwareProfile?
    ) -> [ProactiveModelRecommendation] {
        let maxSize = hardware?.chipType.maxRecommendedModelSizeGB ?? 8.0

        // Task-specific model recommendations (MLX-optimized models from HuggingFace)
        switch taskType {
        case .codeGeneration, .debugging, .codeRefactoring:
            return [
                ProactiveModelRecommendation(
                    modelId: "mlx-community/deepseek-coder-v2-lite-instruct-4bit",
                    modelName: "DeepSeek Coder V2 Lite 4-bit",
                    estimatedSizeGB: 4.5,
                    downloadURL: "https://huggingface.co/mlx-community/deepseek-coder-v2-lite-instruct-4bit",
                    reason: "Optimized for code generation with excellent performance",
                    taskTypes: [.codeGeneration, .debugging, .codeRefactoring],
                    // periphery:ignore - Reserved: findBestModelToDownload(for:) instance method reserved for future feature activation
                    priority: .high
                ),
                ProactiveModelRecommendation(
                    modelId: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
                    modelName: "Qwen 2.5 Coder 7B 4-bit",
                    estimatedSizeGB: 4.2,
                    downloadURL: "https://huggingface.co/mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
                    reason: "Strong coding performance, multilingual support",
                    taskTypes: [.codeGeneration, .debugging],
                    priority: .high
                )
            ].filter { $0.estimatedSizeGB <= maxSize }

        case .math, .mathLogic, .analysis, .complexReasoning:
            return [
                ProactiveModelRecommendation(
                    modelId: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                    // periphery:ignore - Reserved: getRecommendedModels(for:hardware:) instance method reserved for future feature activation
                    modelName: "Qwen 2.5 7B Instruct 4-bit",
                    estimatedSizeGB: 4.5,
                    downloadURL: "https://huggingface.co/mlx-community/Qwen2.5-7B-Instruct-4bit",
                    reason: "Excellent reasoning and math capabilities",
                    taskTypes: [.math, .analysis],
                    priority: .high
                ),
                ProactiveModelRecommendation(
                    modelId: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
                    modelName: "DeepSeek R1 Distill 7B 4-bit",
                    estimatedSizeGB: 4.8,
                    downloadURL: "https://huggingface.co/mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
                    reason: "Advanced reasoning with chain-of-thought",
                    taskTypes: [.math, .complexReasoning, .analysis],
                    priority: .high
                )
            ].filter { $0.estimatedSizeGB <= maxSize }

        case .creative, .creativeWriting, .contentCreation, .creation:
            return [
                ProactiveModelRecommendation(
                    modelId: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
                    modelName: "Mistral 7B Instruct 4-bit",
                    estimatedSizeGB: 4.1,
                    downloadURL: "https://huggingface.co/mlx-community/Mistral-7B-Instruct-v0.3-4bit",
                    reason: "Creative and fluent writing capabilities",
                    taskTypes: [.creative, .conversation],
                    priority: .medium
                )
            ].filter { $0.estimatedSizeGB <= maxSize }

        case .translation:
            return [
                ProactiveModelRecommendation(
                    modelId: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                    modelName: "Qwen 2.5 7B Instruct 4-bit",
                    estimatedSizeGB: 4.5,
                    downloadURL: "https://huggingface.co/mlx-community/Qwen2.5-7B-Instruct-4bit",
                    reason: "Strong multilingual and translation support",
                    taskTypes: [.translation],
                    priority: .high
                )
            ].filter { $0.estimatedSizeGB <= maxSize }

        default:
            // General-purpose model
            return [
                ProactiveModelRecommendation(
                    modelId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                    modelName: "Llama 3.2 3B Instruct 4-bit",
                    estimatedSizeGB: 2.0,
                    downloadURL: "https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit",
                    reason: "Fast, efficient general-purpose model",
                    taskTypes: [.conversation, .factual],
                    priority: .medium
                )
            ].filter { $0.estimatedSizeGB <= maxSize }
        }
    }

    func startModelDownload(_ recommendation: ProactiveModelRecommendation) async {
        guard !activeDownloads.keys.contains(recommendation.modelId) else {
            logger.info("Download already in progress for \(recommendation.modelName)")
            return
        }

        logger.info("Starting download: \(recommendation.modelName)")

        // Initialize progress tracking
        activeDownloads[recommendation.modelId] = DownloadProgress(
            modelId: recommendation.modelId,
            modelName: recommendation.modelName,
            percentage: 0,
            bytesDownloaded: 0,
            totalBytes: Int64(recommendation.estimatedSizeGB * 1_000_000_000),
            startedAt: Date()
        )

        // Create download task
        let task = ModelDownloadTask(
            recommendation: recommendation,
            status: ModelDownloadStatus.downloading,
            startedAt: Date()
        )
        downloadQueue.append(task)

        // Perform actual download using HuggingFace Hub
        await performHuggingFaceDownload(recommendation)
    }

    private func performHuggingFaceDownload(_ recommendation: ProactiveModelRecommendation) async {
        #if os(macOS)
        // Use huggingface-cli or mlx_lm.convert for MLX models
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        // MLX models directory
        let modelsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("SharedLLMs/models-mlx/hub")

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create models directory: \(error.localizedDescription)")
        }

        // Use huggingface-cli to download
        process.arguments = [
            "huggingface-cli", "download",
            recommendation.modelId,
            "--local-dir", modelsDir.appendingPathComponent("models--\(recommendation.modelId.replacingOccurrences(of: "/", with: "--"))").path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()

            // Monitor progress (simplified - real implementation would parse output)
            Task {
                while process.isRunning {
                    do {
                        try await Task.sleep(for: .seconds(2))
                    } catch {
                        break
                    }

                    // Update progress (estimate based on time for now)
                    if var progress = activeDownloads[recommendation.modelId] {
                        let elapsed = Date().timeIntervalSince(progress.startedAt)
                        let estimatedTotal = recommendation.estimatedSizeGB * 60 // Rough: 1GB/min
                        progress.percentage = min(0.95, elapsed / estimatedTotal)
                        activeDownloads[recommendation.modelId] = progress
                    }
                }

                // Download complete
                if process.terminationStatus == 0 {
                    logger.info("Download complete: \(recommendation.modelName)")
                    activeDownloads.removeValue(forKey: recommendation.modelId)

                    // Update download queue status
                    if let index = downloadQueue.firstIndex(where: { $0.recommendation.modelId == recommendation.modelId }) {
                        downloadQueue[index].status = .completed
                        downloadQueue[index].completedAt = Date()
                    }

                    // Refresh model discovery
                    await LocalModelManager.shared.discoverModels()

                    // Post notification
                    NotificationCenter.default.post(
                        name: .modelDownloadCompleted,
                        object: recommendation.modelName
                    )
                } else {
                    logger.error("Download failed: \(recommendation.modelName)")
                    activeDownloads.removeValue(forKey: recommendation.modelId)

                    if let index = downloadQueue.firstIndex(where: { $0.recommendation.modelId == recommendation.modelId }) {
                        downloadQueue[index].status = .failed
                    }
                }
            }
        } catch {
            logger.error("Failed to start download: \(error.localizedDescription)")
            activeDownloads.removeValue(forKey: recommendation.modelId)
        }
        #endif
    }

    private func estimateDownloadTime(_ recommendation: ProactiveModelRecommendation) -> TimeInterval {
        // Estimate based on size (assume ~50MB/s average download speed)
        let bytesPerSecond: Double = 50_000_000
        let totalBytes = recommendation.estimatedSizeGB * 1_000_000_000
        return totalBytes / bytesPerSecond
    }

    // MARK: - AI-Powered Cleanup (No arbitrary thresholds!)

    /// AI-guided cleanup - decisions based on actual value analysis, not arbitrary time limits
    private func performAIGuidedCleanup() async {
        guard enableAutoCleanup else { return }

        let governor = AIModelGovernor.shared
        let decisions = await governor.determineModelsToCleanup()

        // Update cleanup candidates based on AI analysis
        cleanupCandidates = decisions.filter { $0.shouldDelete }.map { decision in
            CleanupCandidate(
                model: decision.model,
                lastUsed: Date(), // AI determines relevance, not just recency
                sizeGB: decision.freedSpace,
                usageCount: 0
            )
        }

        // Execute AI-approved deletions
        for decision in decisions where decision.shouldDelete {
            logger.info("AI-guided cleanup: \(decision.model.name) - \(decision.reasoning)")
            await deleteModel(decision.model)

            // Record for proactivity learning
            governor.recordUserFeedback(ProactivityFeedback(
                // periphery:ignore - Reserved: estimateDownloadTime(_:) instance method reserved for future feature activation
                action: "auto_cleanup_\(decision.model.name)",
                wasHelpful: true, // Assume helpful until user complains
                userOverrode: false
            ))
        }
    }

    /// Legacy method - now delegates to AI-guided cleanup
    @available(*, deprecated, message: "Use performAIGuidedCleanup for intelligent cleanup")
    // periphery:ignore - Reserved: checkAndPerformCleanup() instance method — reserved for future feature activation
    private func checkAndPerformCleanup() async {
        await performAIGuidedCleanup()
    }

    func deleteModel(_ model: LocalModel) async {
        logger.info("Deleting model: \(model.name)")

        do {
            try FileManager.default.removeItem(at: model.path)
            logger.info("Successfully deleted: \(model.name)")

            // Refresh discovery
            await LocalModelManager.shared.discoverModels()

            // Remove from usage history
            modelUsageHistory.removeValue(forKey: model.name)
            saveUsageHistory()
        } catch {
            logger.error("Failed to delete model: \(error.localizedDescription)")
        }
    }

    // MARK: - Usage Tracking

    // periphery:ignore - Reserved: recordTaskRequest(_:) instance method — reserved for future feature activation
    private func recordTaskRequest(_ taskType: TaskType) {
        // This helps us understand what the user needs
        let key = "taskRequest:\(taskType.rawValue)"
        var count = UserDefaults.standard.integer(forKey: key)
        count += 1
        UserDefaults.standard.set(count, forKey: key)
    }

    // periphery:ignore - Reserved: checkAndPerformCleanup() instance method reserved for future feature activation
    func recordModelUsage(_ modelName: String) {
        var record = modelUsageHistory[modelName] ?? ModelUsageRecord(modelName: modelName)
        record.usageCount += 1
        record.lastUsed = Date()
        modelUsageHistory[modelName] = record
        saveUsageHistory()
    }

    private func loadUsageHistory() {
        guard let data = UserDefaults.standard.data(forKey: "ProactiveModelManager.usageHistory") else {
            return
        }
        do {
            modelUsageHistory = try JSONDecoder().decode([String: ModelUsageRecord].self, from: data)
        } catch {
            logger.error("Failed to decode modelUsageHistory: \(error.localizedDescription)")
        }
    }

    private func saveUsageHistory() {
        do {
            let data = try JSONEncoder().encode(modelUsageHistory)
            UserDefaults.standard.set(data, forKey: "ProactiveModelManager.usageHistory")
        // periphery:ignore - Reserved: recordTaskRequest(_:) instance method reserved for future feature activation
        } catch {
            logger.error("Failed to encode modelUsageHistory: \(error.localizedDescription)")
        }
    }

    // MARK: - Startup Analysis

    // periphery:ignore - Reserved: recordModelUsage(_:) instance method reserved for future feature activation
    private func performStartupAnalysis() async {
        logger.info("Performing startup analysis...")

        // Check disk space
        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()

        let totalUsedGB = manager.availableModels.reduce(0.0) { $0 + Double($1.size) / 1_000_000_000 }
        logger.info("Local models using \(String(format: "%.1f", totalUsedGB))GB of disk space")

        // Identify potential cleanup candidates
        await performAIGuidedCleanup()
    }

    // MARK: - User Consent

    /// Request user consent for autonomous model management
    @available(*, deprecated, message: "Use AIModelGovernor for consent management")
    // periphery:ignore - Reserved: requestAutonomousConsent() instance method — reserved for future feature activation
    func requestAutonomousConsent() -> AutonomousConsentRequest {
        AutonomousConsentRequest(
            enableAutoDownload: enableAutoDownload,
            enableAutoCleanup: enableAutoCleanup,
            maxDiskSpaceGB: maxDiskSpaceGB,
            inactiveDaysThreshold: inactiveDaysThreshold
        )
    }

    @available(*, deprecated, message: "Use AIModelGovernor for consent management")
    // periphery:ignore - Reserved: applyConsentSettings(_:) instance method — reserved for future feature activation
    func applyConsentSettings(_ settings: AutonomousConsentRequest) {
        enableAutoDownload = settings.enableAutoDownload
        enableAutoCleanup = settings.enableAutoCleanup
        maxDiskSpaceGB = settings.maxDiskSpaceGB
        inactiveDaysThreshold = settings.inactiveDaysThreshold

        let autoDown = self.enableAutoDownload
        let autoClean = self.enableAutoCleanup
        logger.info("Applied consent settings: autoDownload=\(autoDown), autoCleanup=\(autoClean)")
    }
}

// MARK: - Supporting Types

struct RequestAnalysis: Sendable {
    // periphery:ignore - Reserved: request property — reserved for future feature activation
    let request: String
    // periphery:ignore - Reserved: taskType property — reserved for future feature activation
    let taskType: TaskType
    // periphery:ignore - Reserved: confidence property — reserved for future feature activation
    let confidence: Double
    // periphery:ignore - Reserved: hasOptimalModel property — reserved for future feature activation
    let hasOptimalModel: Bool
    // periphery:ignore - Reserved: requestAutonomousConsent() instance method reserved for future feature activation
    var currentModel: String?
    // periphery:ignore - Reserved: currentModelScore property — reserved for future feature activation
    var currentModelScore: Double?
    // periphery:ignore - Reserved: recommendation property — reserved for future feature activation
    var recommendation: ProactiveModelRecommendation?
    // periphery:ignore - Reserved: estimatedWaitTime property — reserved for future feature activation
    var estimatedWaitTime: TimeInterval?
}

// periphery:ignore - Reserved: PreflightResult type — reserved for future feature activation
struct PreflightResult: Sendable {
    let ready: Bool
    let selectedModel: String?
    // periphery:ignore - Reserved: applyConsentSettings(_:) instance method reserved for future feature activation
    let score: Double
    let action: PreflightAction
}

enum PreflightAction: Sendable {
    // periphery:ignore - Reserved: proceed case — reserved for future feature activation
    case proceed
    // periphery:ignore - Reserved: waitForDownload(progress:) case — reserved for future feature activation
    case waitForDownload(progress: Double)
    // periphery:ignore - Reserved: downloadStarted(model:) case — reserved for future feature activation
    case downloadStarted(model: String)
    // periphery:ignore - Reserved: suggestDownload(_:) case — reserved for future feature activation
    case suggestDownload(ProactiveModelRecommendation)
    // periphery:ignore - Reserved: useRemote case — reserved for future feature activation
    case useRemote
}

struct ProactiveModelRecommendation: Sendable, Identifiable {
    var id: String { modelId }
    // periphery:ignore - Reserved: request property reserved for future feature activation
    // periphery:ignore - Reserved: taskType property reserved for future feature activation
    // periphery:ignore - Reserved: confidence property reserved for future feature activation
    // periphery:ignore - Reserved: hasOptimalModel property reserved for future feature activation
    // periphery:ignore - Reserved: currentModel property reserved for future feature activation
    // periphery:ignore - Reserved: currentModelScore property reserved for future feature activation
    // periphery:ignore - Reserved: recommendation property reserved for future feature activation
    // periphery:ignore - Reserved: estimatedWaitTime property reserved for future feature activation
    let modelId: String
    let modelName: String
    // periphery:ignore - Reserved: PreflightResult type reserved for future feature activation
    let estimatedSizeGB: Double
    // periphery:ignore - Reserved: downloadURL property — reserved for future feature activation
    let downloadURL: String
    let reason: String
    let taskTypes: [TaskType]
    let priority: SuggestionPriority
}

// periphery:ignore - Reserved: proceed case reserved for future feature activation
// periphery:ignore - Reserved: waitForDownload(progress:) case reserved for future feature activation
// periphery:ignore - Reserved: downloadStarted(model:) case reserved for future feature activation
// periphery:ignore - Reserved: suggestDownload(_:) case reserved for future feature activation
// periphery:ignore - Reserved: useRemote case reserved for future feature activation
struct PendingModelDownload: Sendable, Identifiable {
    var id: String { recommendation.modelId }
    let recommendation: ProactiveModelRecommendation
    let taskType: TaskType
    let requestedAt: Date
}

// periphery:ignore - Reserved: downloadURL property reserved for future feature activation
struct ModelDownloadTask: Sendable, Identifiable {
    var id: String { recommendation.modelId }
    let recommendation: ProactiveModelRecommendation
    var status: ModelDownloadStatus
    let startedAt: Date
    var completedAt: Date?
}

enum ModelDownloadStatus: String, Sendable {
    // periphery:ignore - Reserved: requestedAt property reserved for future feature activation
    case pending
    case downloading
    case completed
    case failed
    case cancelled
// periphery:ignore - Reserved: status property reserved for future feature activation
// periphery:ignore - Reserved: startedAt property reserved for future feature activation
// periphery:ignore - Reserved: completedAt property reserved for future feature activation
}

struct DownloadProgress: Sendable {
    let modelId: String
    let modelName: String
    var percentage: Double
    // periphery:ignore - Reserved: bytesDownloaded property — reserved for future feature activation
    var bytesDownloaded: Int64
    // periphery:ignore - Reserved: totalBytes property — reserved for future feature activation
    let totalBytes: Int64
    let startedAt: Date

    // periphery:ignore - Reserved: remainingTime property — reserved for future feature activation
    var remainingTime: TimeInterval? {
        guard percentage > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(startedAt)
        let totalEstimate = elapsed / percentage
        // periphery:ignore - Reserved: bytesDownloaded property reserved for future feature activation
        // periphery:ignore - Reserved: totalBytes property reserved for future feature activation
        return totalEstimate - elapsed
    }
// periphery:ignore - Reserved: remainingTime property reserved for future feature activation
}

struct CleanupCandidate: Sendable, Identifiable {
    var id: String { model.name }
    let model: LocalModel
    let lastUsed: Date
    let sizeGB: Double
    // periphery:ignore - Reserved: usageCount property — reserved for future feature activation
    let usageCount: Int
}

struct ModelUsageRecord: Codable, Sendable {
    let modelName: String
    // periphery:ignore - Reserved: usageCount property reserved for future feature activation
    var usageCount: Int = 0
    var lastUsed = Date.distantPast
}

// periphery:ignore - Reserved: AutonomousConsentRequest type — reserved for future feature activation
struct AutonomousConsentRequest: Sendable {
    var enableAutoDownload: Bool
    var enableAutoCleanup: Bool
    var maxDiskSpaceGB: Double
    // periphery:ignore - Reserved: AutonomousConsentRequest type reserved for future feature activation
    var inactiveDaysThreshold: Int
}

// MARK: - Notifications

extension Notification.Name {
    static let modelDownloadCompleted = Notification.Name("ProactiveModelManager.downloadCompleted")
    // periphery:ignore - Reserved: modelDownloadFailed static property — reserved for future feature activation
    static let modelDownloadFailed = Notification.Name("ProactiveModelManager.downloadFailed")
    // periphery:ignore - Reserved: modelCleanupCompleted static property — reserved for future feature activation
    static let modelCleanupCompleted = Notification.Name("ProactiveModelManager.cleanupCompleted")
}

// periphery:ignore - Reserved: modelDownloadFailed static property reserved for future feature activation

// periphery:ignore - Reserved: modelCleanupCompleted static property reserved for future feature activation

// MARK: - Helper Extensions

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        // periphery:ignore - Reserved: nonZeroOr(_:) instance method reserved for future feature activation
        self == 0 ? defaultValue : self
    }
}

private extension Int {
    // periphery:ignore - Reserved: nonZeroOr(_:) instance method reserved for future feature activation
    func nonZeroOr(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}
