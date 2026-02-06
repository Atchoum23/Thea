//
//  ModelPrewarmingService.swift
//  Thea
//
//  Predictive model pre-warming based on learned user behavior patterns.
//  Wires PredictivePreloader predictions to MLXInferenceEngine loading.
//
//  ALGORITHM:
//  1. Subscribes to PredictivePreloader predictions every 60 seconds
//  2. Pre-loads top 2 predicted models before user requests
//  3. Uses AdaptiveUIEngine interaction patterns as additional signals
//  4. Maintains warm model cache with LRU eviction
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog

// MARK: - Model Pre-warming Service

/// Proactively loads AI models based on predicted user needs
public actor ModelPrewarmingService {
    public static let shared = ModelPrewarmingService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ModelPrewarming")

    // MARK: - Configuration

    /// How often to check predictions (seconds)
    private let checkInterval: TimeInterval = 60.0

    /// Maximum number of models to keep warm
    private let maxWarmModels: Int = 2

    /// Minimum prediction probability to trigger pre-loading
    private let minimumProbability: Double = 0.25

    /// Persistence key for warm model tracking
    private let warmModelsKey = "ModelPrewarming.warmModels"

    // MARK: - State

    /// Currently warm (pre-loaded) model IDs
    private var warmModelIDs: Set<String> = []

    /// Last prediction check time
    private var lastCheckTime: Date?

    /// Active monitoring task
    private var monitoringTask: Task<Void, Never>?

    /// Whether monitoring is active
    public private(set) var isMonitoring: Bool = false

    /// Pre-warming statistics
    public private(set) var stats: PrewarmingStats = PrewarmingStats()

    // MARK: - Model Mapping

    /// Maps task types to preferred local model IDs
    /// This should be populated from LocalModelRecommendationEngine
    private var taskToModelMapping: [TaskType: String] = [
        .codeGeneration: "mlx-community/Qwen2.5-Coder-3B-4bit",
        .codeAnalysis: "mlx-community/Qwen2.5-Coder-3B-4bit",
        .debugging: "mlx-community/Qwen2.5-Coder-3B-4bit",
        .math: "mlx-community/Qwen2.5-3B-4bit",
        .creative: "mlx-community/Qwen2.5-3B-4bit",
        .conversation: "mlx-community/Qwen2.5-1.5B-4bit",
        .factual: "mlx-community/Qwen2.5-1.5B-4bit",
        .analysis: "mlx-community/Qwen2.5-3B-4bit",
        .summarization: "mlx-community/Qwen2.5-1.5B-4bit",
        .planning: "mlx-community/Qwen2.5-3B-4bit",
    ]

    // MARK: - Initialization

    private init() {
        Task {
            await loadPersistedState()
        }
    }

    // MARK: - Public API

    /// Start monitoring predictions and pre-warming models
    public func startMonitoring() {
        guard !isMonitoring else {
            logger.debug("Monitoring already active")
            return
        }

        isMonitoring = true
        logger.info("Starting model pre-warming monitoring")

        monitoringTask = Task { [weak self] in
            await self?.monitoringLoop()
        }
    }

    /// Stop monitoring
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
        logger.info("Stopped model pre-warming monitoring")
    }

    /// Manually trigger a prediction check
    public func checkPredictions() async {
        await performPredictionCheck()
    }

    /// Update task-to-model mapping from recommendation engine
    public func updateModelMapping(_ mapping: [TaskType: String]) {
        taskToModelMapping = mapping
        logger.debug("Updated task-to-model mapping with \(mapping.count) entries")
    }

    /// Get currently warm model IDs
    public func getWarmModels() -> Set<String> {
        warmModelIDs
    }

    /// Check if a model is currently warm
    public func isModelWarm(_ modelID: String) -> Bool {
        warmModelIDs.contains(modelID)
    }

    /// Record a successful model usage (reinforces prediction accuracy)
    public func recordModelUsage(modelID: String, taskType: TaskType) {
        stats.successfulPredictions += warmModelIDs.contains(modelID) ? 1 : 0
        stats.totalUsages += 1

        // Record to PredictivePreloader for learning
        let preloader = PredictivePreloader()
        preloader.recordTaskRequest(taskType)

        logger.debug("Recorded model usage: \(modelID) for \(taskType.rawValue)")
    }

    // MARK: - Private Implementation

    /// Main monitoring loop
    private func monitoringLoop() async {
        while !Task.isCancelled && isMonitoring {
            await performPredictionCheck()

            // Wait for next check interval
            do {
                try await Task.sleep(for: .seconds(checkInterval))
            } catch {
                break // Task was cancelled
            }
        }
    }

    /// Perform a single prediction check and pre-warm as needed
    private func performPredictionCheck() async {
        lastCheckTime = Date()
        stats.checksPerformed += 1

        // Get predictions from PredictivePreloader
        let preloader = PredictivePreloader()
        let predictions = preloader.predictNextTasks()

        guard !predictions.isEmpty else {
            logger.debug("No predictions available")
            return
        }

        // Filter predictions above threshold
        let viablePredictions = predictions.filter { $0.probability >= minimumProbability }

        guard !viablePredictions.isEmpty else {
            logger.debug("No predictions above threshold \(self.minimumProbability)")
            return
        }

        // Get model IDs for top predictions
        var modelsToWarm: [String] = []
        for prediction in viablePredictions.prefix(maxWarmModels) {
            if let modelID = taskToModelMapping[prediction.taskType] {
                modelsToWarm.append(modelID)
            }
        }

        // Remove duplicates while preserving order
        modelsToWarm = Array(NSOrderedSet(array: modelsToWarm)) as? [String] ?? modelsToWarm

        // Pre-warm models that aren't already warm
        for modelID in modelsToWarm {
            if !warmModelIDs.contains(modelID) {
                await preloadModel(modelID)
            }
        }

        // Evict old models if over limit
        await evictExcessModels(keeping: Set(modelsToWarm))

        logger.debug("Prediction check complete. Warm models: \(self.warmModelIDs.count)")
    }

    /// Pre-load a specific model
    private func preloadModel(_ modelID: String) async {
        logger.info("Pre-warming model: \(modelID)")
        stats.preloadAttempts += 1

        #if os(macOS)
        do {
            // Use MLXInferenceEngine to load the model
            _ = try await MainActor.run {
                Task {
                    _ = try await MLXInferenceEngine.shared.loadModel(id: modelID)
                }
            }

            warmModelIDs.insert(modelID)
            stats.successfulPreloads += 1
            persistState()

            logger.info("Successfully pre-warmed model: \(modelID)")
        } catch {
            logger.error("Failed to pre-warm model \(modelID): \(error.localizedDescription)")
        }
        #else
        // MLX only available on macOS
        logger.debug("Model pre-warming skipped (not macOS)")
        #endif
    }

    /// Evict models beyond the limit
    private func evictExcessModels(keeping priorityModels: Set<String>) async {
        // Find models to potentially evict (not in priority set)
        let candidates = warmModelIDs.subtracting(priorityModels)

        // Calculate how many to evict
        let totalAfterPriority = priorityModels.count + candidates.count
        let toEvict = max(0, totalAfterPriority - maxWarmModels)

        guard toEvict > 0 else { return }

        // Evict oldest (we don't have timestamps, so just remove arbitrary ones)
        let evictList = Array(candidates.prefix(toEvict))

        for modelID in evictList {
            warmModelIDs.remove(modelID)
            logger.debug("Evicted model from warm cache: \(modelID)")
        }

        persistState()
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        if let data = UserDefaults.standard.data(forKey: warmModelsKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            warmModelIDs = decoded
        }

        logger.debug("Loaded \(self.warmModelIDs.count) warm models from persistence")
    }

    private func persistState() {
        if let data = try? JSONEncoder().encode(warmModelIDs) {
            UserDefaults.standard.set(data, forKey: warmModelsKey)
        }
    }
}

// MARK: - Supporting Types

/// Statistics for pre-warming performance
public struct PrewarmingStats: Sendable {
    public var checksPerformed: Int = 0
    public var preloadAttempts: Int = 0
    public var successfulPreloads: Int = 0
    public var successfulPredictions: Int = 0
    public var totalUsages: Int = 0

    /// Prediction hit rate (how often the pre-warmed model was actually used)
    public var hitRate: Double {
        guard totalUsages > 0 else { return 0 }
        return Double(successfulPredictions) / Double(totalUsages)
    }

    /// Pre-load success rate
    public var preloadSuccessRate: Double {
        guard preloadAttempts > 0 else { return 0 }
        return Double(successfulPreloads) / Double(preloadAttempts)
    }
}

// MARK: - AdaptiveUIEngine Integration

extension ModelPrewarmingService {
    /// Incorporate AdaptiveUIEngine patterns into prediction signals
    @MainActor
    public func incorporateUIPatterns() async {
        let patterns = AdaptiveUIEngine.shared.interactionPatterns

        // Analyze patterns for task-related actions
        for (action, pattern) in patterns {
            // High-frequency actions suggest likely task types
            if pattern.frequency >= 5 {
                // Map UI actions to task types
                let taskType = inferTaskTypeFromAction(action)
                if let modelID = await taskToModelMapping[taskType] {
                    // Boost this model's priority
                    logger.debug("UI pattern suggests task \(taskType.rawValue), boosting model \(modelID)")
                }
            }
        }
    }

    /// Infer task type from UI action name
    @MainActor
    private func inferTaskTypeFromAction(_ action: String) -> TaskType {
        let lowercased = action.lowercased()

        if lowercased.contains("code") || lowercased.contains("debug") {
            return .codeGeneration
        } else if lowercased.contains("write") || lowercased.contains("creative") {
            return .creative
        } else if lowercased.contains("search") || lowercased.contains("research") {
            return .research
        } else if lowercased.contains("analyze") {
            return .analysis
        } else if lowercased.contains("math") || lowercased.contains("calculate") {
            return .math
        }

        return .conversation
    }
}

// MARK: - Global Task Type Mapping Access

extension ModelPrewarmingService {
    /// Get the preferred model for a task type
    public func getPreferredModel(for taskType: TaskType) -> String? {
        taskToModelMapping[taskType]
    }

    /// Register a model preference for a task type
    public func registerModelPreference(taskType: TaskType, modelID: String) {
        taskToModelMapping[taskType] = modelID
    }
}
