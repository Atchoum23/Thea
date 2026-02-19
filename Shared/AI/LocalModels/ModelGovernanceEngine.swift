//
//  ModelGovernanceEngine.swift
//  Thea
//
//  Central governance system for intelligent model management
//  Implements Supra-Model (always-present anchor) and Dynamic Fleet management
//
//  ARCHITECTURE:
//  - Supra-Model: Always-installed best-suited model that evolves over time
//  - Dynamic Fleet: Task-specific models managed based on usage, resources, and quality
//  - Predictive Preloading: Anticipates model needs using learned patterns
//  - Quality Benchmarking: EMA-based tracking of model performance
//
//  CREATED: February 5, 2026
//

import Foundation
import OSLog

// MARK: - Model Governance Engine

/// Central governance engine for intelligent, autonomous model management
/// Coordinates Supra-Model selection, dynamic fleet management, and predictive optimization
/// Now integrated with AdaptiveGovernanceOrchestrator for self-tuning capabilities
@MainActor
@Observable
final class ModelGovernanceEngine {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = ModelGovernanceEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "ModelGovernance")

    // MARK: - Core State

    /// The current Supra-Model (always-present anchor model)
    private(set) var supraModel: SupraModelState?

    /// Dynamic model fleet organized by tier
    private(set) var modelFleet = ModelFleet()

    /// Current governance policy
    // periphery:ignore - Reserved: shared static property reserved for future feature activation
    private(set) var policy: GovernanceEnginePolicy = .default

    /// System resource snapshot
    private(set) var resourceSnapshot = ResourceSnapshot()

    /// Whether governance is actively managing models
    private(set) var isActive = false

    // MARK: - Sub-components

    private let supraSelector: SupraModelSelector
    private let preloader: PredictivePreloader
    private let qualityTracker: ModelQualityBenchmark

    // MARK: - Adaptive Governance Integration

    /// The adaptive governance orchestrator for self-tuning
    private let adaptiveOrchestrator = AdaptiveGovernanceOrchestrator()

    // MARK: - Persistence Keys

    private let supraModelKey = "ModelGovernanceEngine.supraModel"
    private let fleetStateKey = "ModelGovernanceEngine.fleetState"
    private let policyKey = "ModelGovernanceEngine.policy"

    // MARK: - Initialization

    private init() {
        // Initialize with adaptive orchestrator integration
        self.supraSelector = SupraModelSelector(adaptiveOrchestrator: adaptiveOrchestrator)
        self.preloader = PredictivePreloader()
        self.qualityTracker = ModelQualityBenchmark()

        loadPersistedState()

        Task {
            await initialize()
        }
    }

    // MARK: - Initialization

    private func initialize() async {
        logger.info("Initializing Model Governance Engine...")

        // 1. Capture current resource state
        await updateResourceSnapshot()

        // 2. Ensure Supra-Model is present
        await ensureSupraModelPresent()

        // 3. Initialize dynamic fleet
        await initializeFleet()

        // 4. Start background governance
        startBackgroundGovernance()

        isActive = true
        logger.info("Model Governance Engine initialized - Supra-Model: \(self.supraModel?.modelName ?? "pending")")
    }

    // MARK: - Supra-Model Management

    /// Ensures the Supra-Model (always-present anchor) is installed and optimal
    func ensureSupraModelPresent() async {
        // Get current installed models
        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()
        let installedModels = manager.availableModels

        if installedModels.isEmpty {
            // No models at all - need to bootstrap
            logger.warning("No local models installed - initiating Supra-Model bootstrap")
            await bootstrapSupraModel()
            return
        }

        // Evaluate current Supra-Model
        if let currentSupra = supraModel {
            // Check if current Supra-Model is still optimal
            let shouldEvolve = await supraSelector.shouldEvolveSupraModel(
                current: currentSupra,
                installedModels: installedModels,
                resourceSnapshot: resourceSnapshot,
                qualityTracker: qualityTracker
            )

            if shouldEvolve.shouldChange {
                logger.info("Supra-Model evolution triggered: \(shouldEvolve.reason)")
                await evolveSupraModel(to: shouldEvolve.recommendedModel)
            }
        } else {
            // No Supra-Model designated - select one from installed models
            await selectInitialSupraModel(from: installedModels)
        }
    }

    /// Bootstrap the Supra-Model when no models are installed
    private func bootstrapSupraModel() async {
        let recommendation = await supraSelector.getBootstrapRecommendation(
            resourceSnapshot: resourceSnapshot
        )

        guard let rec = recommendation else {
            logger.error("Failed to get bootstrap recommendation")
            return
        }

        // Check with AI Governor for consent
        guard AIModelGovernor.shared.hasAutonomousConsent else {
            logger.info("Autonomous consent not granted - Supra-Model bootstrap pending user approval")

            // Notify user that a model needs to be downloaded
            NotificationCenter.default.post(
                name: .supraModelBootstrapRequired,
                object: rec
            )
            return
        }

        // Initiate download via ProactiveModelManager
        let proactiveManager = ProactiveModelManager.shared
        await proactiveManager.startModelDownload(rec)

        // Set as pending Supra-Model
        supraModel = SupraModelState(
            modelId: rec.modelId,
            modelName: rec.modelName,
            status: .downloading,
            designatedAt: Date(),
            reason: "Bootstrap: \(rec.reason)"
        )

        persistState()
    }

    /// Select initial Supra-Model from installed models
    private func selectInitialSupraModel(from models: [LocalModel]) async {
        guard let best = await supraSelector.selectBestSupraModel(
            from: models,
            resourceSnapshot: resourceSnapshot,
            qualityTracker: qualityTracker
        ) else {
            logger.warning("No suitable Supra-Model found among \(models.count) installed models")
            return
        }

        supraModel = SupraModelState(
            modelId: best.model.name,
            modelName: best.model.name,
            status: .active,
            designatedAt: Date(),
            reason: best.reason,
            qualityScore: best.score,
            lastVerified: Date()
        )

        logger.info("Designated Supra-Model: \(best.model.name) (score: \(best.score))")
        persistState()
    }

    /// Evolve Supra-Model to a better option
    private func evolveSupraModel(to newModel: LocalModel?) async {
        guard let newModel = newModel else { return }

        let previousSupra = supraModel?.modelName

        supraModel = SupraModelState(
            modelId: newModel.name,
            modelName: newModel.name,
            status: .active,
            designatedAt: Date(),
            reason: "Evolution from \(previousSupra ?? "none"): Better quality/resource fit",
            previousModel: previousSupra,
            lastVerified: Date()
        )

        logger.info("Supra-Model evolved: \(previousSupra ?? "none") → \(newModel.name)")
        persistState()

        // Notify observers
        NotificationCenter.default.post(
            name: .supraModelEvolved,
            object: newModel.name,
            userInfo: ["previous": previousSupra ?? ""]
        )
    }

    /// Get the current Supra-Model for inference
    // periphery:ignore - Reserved: getSupraModelForInference() instance method — reserved for future feature activation
    func getSupraModelForInference() async -> LocalModel? {
        guard let supra = supraModel, supra.status == .active else {
            return nil
        }

        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()

        return manager.availableModels.first { $0.name == supra.modelName }
    }

    // MARK: - Dynamic Fleet Management

// periphery:ignore - Reserved: getSupraModelForInference() instance method reserved for future feature activation

    /// Initialize the dynamic model fleet
    private func initializeFleet() async {
        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()

        // Categorize models into tiers
        for model in manager.availableModels {
            let tier = await determineModelTier(model)
            modelFleet.assignModel(model, to: tier)
        }

        logger.info("Fleet initialized: T1=\(self.modelFleet.tier1.count), T2=\(self.modelFleet.tier2.count), T3=\(self.modelFleet.tier3.count)")
    }

    /// Determine appropriate tier for a model
    private func determineModelTier(_ model: LocalModel) async -> ModelTier {
        let qualityScore = qualityTracker.getQualityScore(for: model.name)
        let usageFrequency = await getUsageFrequency(for: model.name)
        let sizeGB = Double(model.size) / 1_000_000_000

        // Supra-Model is always Tier 1
        if model.name == supraModel?.modelName {
            return .tier1AlwaysLoaded
        }

        // High usage + good quality + reasonable size = Tier 1
        if usageFrequency > 0.7 && qualityScore > 0.7 && sizeGB < 10 {
            return .tier1AlwaysLoaded
        }

        // Moderate usage or specialized capability = Tier 2
        if usageFrequency > 0.3 || qualityScore > 0.8 {
            return .tier2OnDemand
        }

        // Low usage or large size = Tier 3
        return .tier3Situational
    }

    /// Get usage frequency for a model (0-1)
    private func getUsageFrequency(for modelName: String) async -> Double {
        let proactiveManager = ProactiveModelManager.shared
        guard let record = proactiveManager.modelUsageHistory[modelName] else {
            return 0.0
        }

        // Calculate relative usage
        let totalUsage = proactiveManager.modelUsageHistory.values.reduce(0) { $0 + $1.usageCount }
        guard totalUsage > 0 else { return 0.0 }

        return Double(record.usageCount) / Double(totalUsage)
    }

    /// Select optimal model for a task
    // periphery:ignore - Reserved: selectModelForTask(_:context:) instance method — reserved for future feature activation
    func selectModelForTask(_ taskType: TaskType, context: GovernanceTaskContext = GovernanceTaskContext()) async -> GovernanceModelSelection? {
        // 1. Record the task request for learning
        preloader.recordTaskRequest(taskType)

        // 2. Check Tier 1 (always loaded) first
        if let tier1Match = await findBestModelInTier(.tier1AlwaysLoaded, for: taskType) {
            return tier1Match
        }

        // 3. Check Tier 2 (on-demand)
        if let tier2Match = await findBestModelInTier(.tier2OnDemand, for: taskType) {
            // periphery:ignore - Reserved: selectModelForTask(_:context:) instance method reserved for future feature activation
            // Ensure model is loaded
            await ensureModelLoaded(tier2Match.model)
            return tier2Match
        }

        // 4. Check Tier 3 (situational)
        if context.allowSituational, let tier3Match = await findBestModelInTier(.tier3Situational, for: taskType) {
            await ensureModelLoaded(tier3Match.model)
            return tier3Match
        }

        // 5. Fall back to Supra-Model
        if let supraModel = await getSupraModelForInference() {
            return GovernanceModelSelection(
                model: supraModel,
                tier: .tier1AlwaysLoaded,
                score: 0.6,
                reason: "Supra-Model fallback - no specialized model available"
            )
        }

        return nil
    }

    /// Find best model in a specific tier for a task
    private func findBestModelInTier(_ tier: ModelTier, for taskType: TaskType) async -> GovernanceModelSelection? {
        let modelsInTier = modelFleet.getModels(in: tier)
        guard !modelsInTier.isEmpty else { return nil }

        var bestMatch: (model: LocalModel, score: Double, reason: String)?

        for model in modelsInTier {
            let capabilityScore = calculateCapabilityScore(model, for: taskType)
            let qualityScore = qualityTracker.getQualityScore(for: model.name)
            let combinedScore = (capabilityScore * 0.6) + (qualityScore * 0.4)

            if bestMatch == nil || combinedScore > bestMatch!.score {
                bestMatch = (model, combinedScore, "Capability: \(Int(capabilityScore * 100))%, Quality: \(Int(qualityScore * 100))%")
            }
        }

        guard let best = bestMatch else { return nil }
        return GovernanceModelSelection(model: best.model, tier: tier, score: best.score, reason: best.reason)
    }

    /// Calculate capability score for a model and task
    private func calculateCapabilityScore(_ model: LocalModel, for taskType: TaskType) -> Double {
        let name = model.name.lowercased()

        switch taskType {
        case .codeGeneration, .debugging, .codeRefactoring:
            if name.contains("code") || name.contains("deepseek") || name.contains("qwen") && name.contains("coder") {
                return 0.95
            }
            return 0.5

        case .math, .mathLogic, .analysis, .complexReasoning:
            if name.contains("qwen") || name.contains("deepseek") || name.contains("r1") {
                return 0.9
            }
            return 0.6

        case .creative, .creativeWriting, .contentCreation, .creation:
            if name.contains("mistral") || name.contains("llama") {
                return 0.85
            }
            return 0.7

        case .translation:
            if name.contains("qwen") {
                return 0.9
            }
            return 0.5

        default:
            return 0.7
        }
    }

    /// Ensure a model is loaded and ready
    private func ensureModelLoaded(_ model: LocalModel) async {
        let manager = LocalModelManager.shared
        do {
            _ = try await manager.loadModel(model)
        } catch {
            logger.error("Failed to load model \(model.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Predictive Preloading

    /// Predict and preload models based on usage patterns
    func performPredictivePreloading() async {
        let predictions = preloader.predictNextTasks()

        for prediction in predictions.prefix(2) { // Preload top 2 predictions
            guard prediction.probability > 0.4 else { continue }

            if let selection = await findBestModelInTier(.tier2OnDemand, for: prediction.taskType) {
                logger.info("Predictive preload: \(selection.model.name) for \(prediction.taskType.rawValue)")
                await ensureModelLoaded(selection.model)
            }
        }
    }

    // MARK: - Resource Management

    /// Update the current resource snapshot
    func updateResourceSnapshot() async {
        #if os(macOS)
        let fileManager = FileManager.default

        // Get available memory
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }

        var availableMemoryGB: Double = 8.0 // Default
        if result == KERN_SUCCESS {
            // Use system page size for memory calculation
            let pageSize = UInt64(getpagesize())
            let freePages = vmStats.free_count + vmStats.inactive_count
            availableMemoryGB = Double(UInt64(freePages) * pageSize) / 1_000_000_000
        }

        // Get total memory
        let totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000

        // Get disk space
        var availableDiskGB: Double = 50.0
        var totalDiskGB: Double = 500.0
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = attributes[.systemFreeSize] as? Int64,
               let totalSpace = attributes[.systemSize] as? Int64 {
                availableDiskGB = Double(freeSpace) / 1_000_000_000
                totalDiskGB = Double(totalSpace) / 1_000_000_000
            }
        } catch {
            logger.error("Failed to read file system attributes: \(error.localizedDescription)")
        }

        // Get thermal state
        let thermalState = ProcessInfo.processInfo.thermalState
        let mappedThermal: ResourceThermalState = switch thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }

        // Calculate model storage
        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()
        let modelStorageGB = manager.availableModels.reduce(0.0) { $0 + Double($1.size) / 1_000_000_000 }

        resourceSnapshot = ResourceSnapshot(
            availableMemoryGB: availableMemoryGB,
            totalMemoryGB: totalMemoryGB,
            availableDiskGB: availableDiskGB,
            totalDiskGB: totalDiskGB,
            modelStorageGB: modelStorageGB,
            thermalState: mappedThermal,
            timestamp: Date()
        )
        #endif
    }

    /// Check if resources allow downloading a model
    // periphery:ignore - Reserved: canAccommodateModel(sizeGB:) instance method — reserved for future feature activation
    func canAccommodateModel(sizeGB: Double) -> Bool {
        // Need 1.5x space for safety margin
        let requiredSpace = sizeGB * 1.5

        guard resourceSnapshot.availableDiskGB > requiredSpace else {
            return false
        }

        // Check memory for loading
        guard resourceSnapshot.availableMemoryGB > sizeGB * 1.2 else {
            // periphery:ignore - Reserved: canAccommodateModel(sizeGB:) instance method reserved for future feature activation
            return false
        }

        return true
    }

    // MARK: - Background Governance

    private var governanceTask: Task<Void, Never>?

    private func startBackgroundGovernance() {
        // Start the adaptive orchestrator
        Task {
            await adaptiveOrchestrator.start()
        }

        governanceTask = Task {
            while !Task.isCancelled {
                // Get adaptive interval from orchestrator (replaces fixed 5-minute interval)
                let interval = await adaptiveOrchestrator.recommendedInterval()
                logger.debug("Next governance cycle in \(Int(interval)) seconds (adaptive)")

                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    break
                }

                await performGovernanceCycle()
            }
        }
    }

    /// Perform a full governance cycle
    func performGovernanceCycle() async {
        guard isActive else { return }

        let cycleStart = Date()
        logger.debug("Starting governance cycle...")

        // 1. Update resource snapshot
        await updateResourceSnapshot()

        // 2. Update adaptive orchestrator with activity metrics
        await adaptiveOrchestrator.updateActivity(
            queryCount: getRecentQueryCount(),
            errorCount: getRecentErrorCount(),
            resourcePressure: resourceSnapshot.memoryPressure
        )

        // 3. Verify Supra-Model
        await ensureSupraModelPresent()

        // 4. Re-evaluate fleet tiers
        await reEvaluateFleetTiers()

        // 5. Perform predictive preloading
        await performPredictivePreloading()

        // 6. Check for cleanup candidates
        await checkCleanupCandidates()

        // 7. Execute adaptive orchestrator cycle
        let cycleMetrics = await adaptiveOrchestrator.executeGovernanceCycle()
        logger.debug("Adaptive cycle: \(cycleMetrics.changesApplied) changes, \(cycleMetrics.issuesDetected) issues")

        // 8. Persist state
        persistState()

        let cycleDuration = Date().timeIntervalSince(cycleStart)
        logger.debug("Governance cycle complete in \(String(format: "%.2f", cycleDuration))s")
    }

    /// Get recent query count for adaptive learning
    private func getRecentQueryCount() -> Int {
        // Get from ProactiveModelManager usage history
        let manager = ProactiveModelManager.shared
        let recentUsage = manager.modelUsageHistory.values.reduce(0) { $0 + $1.usageCount }
        return recentUsage
    }

    /// Get recent error count for adaptive learning
    private func getRecentErrorCount() -> Int {
        // Count models with zero usage (potential load failures) from recent fleet
        let manager = ProactiveModelManager.shared
        let zeroUsageCount = manager.modelUsageHistory.values
            .filter { $0.usageCount == 0 && $0.lastUsed != Date.distantPast }
            .count
        return zeroUsageCount
    }

    /// Re-evaluate fleet tier assignments
    private func reEvaluateFleetTiers() async {
        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()

        var newFleet = ModelFleet()

        for model in manager.availableModels {
            let newTier = await determineModelTier(model)
            let currentTier = modelFleet.getTier(for: model.name)

            if newTier != currentTier {
                logger.info("Model \(model.name) tier changed: \(currentTier?.rawValue ?? "none") → \(newTier.rawValue)")
            }

            newFleet.assignModel(model, to: newTier)
        }

        modelFleet = newFleet
    }

    /// Check for models that should be cleaned up
    private func checkCleanupCandidates() async {
        let governor = AIModelGovernor.shared
        let decisions = await governor.determineModelsToCleanup()

        for decision in decisions where decision.shouldDelete {
            // Don't delete the Supra-Model
            guard decision.model.name != supraModel?.modelName else {
                logger.info("Skipping cleanup of Supra-Model: \(decision.model.name)")
                continue
            }

            // Execute cleanup if approved
            if governor.hasAutonomousConsent {
                logger.info("Auto-cleanup: \(decision.model.name) - \(decision.reasoning)")
                await ProactiveModelManager.shared.deleteModel(decision.model)
            }
        }
    }

    // MARK: - Quality Feedback

    /// Record quality feedback for a model
    // periphery:ignore - Reserved: recordModelQuality(modelName:taskType:success:latency:userSatisfaction:) instance method — reserved for future feature activation
    func recordModelQuality(
        modelName: String,
        taskType: TaskType,
        success: Bool,
        latency: TimeInterval,
        userSatisfaction: Double? = nil
    ) {
        qualityTracker.recordQuality(
            modelName: modelName,
            // periphery:ignore - Reserved: recordModelQuality(modelName:taskType:success:latency:userSatisfaction:) instance method reserved for future feature activation
            taskType: taskType,
            success: success,
            latency: latency,
            userSatisfaction: userSatisfaction
        )

        // Update usage tracking
        ProactiveModelManager.shared.recordModelUsage(modelName)

        // Record to adaptive governance for learning
        Task { @MainActor in
            // Record system feedback via hyperparameter tuner
            // The HyperparameterTuner uses these outcomes to adjust its parameters
            let tuner = HyperparameterTuner.shared
            let successValue = tuner.getValue(.qualitySuccessWeight)
            let latencyValue = tuner.getValue(.qualityLatencyWeight)

            tuner.recordOutcome(.qualitySuccessWeight, testedValue: successValue, outcome: success ? 1.0 : 0.0)
            tuner.recordOutcome(.qualityLatencyWeight, testedValue: latencyValue, outcome: min(1.0, max(0.0, 1.0 - (latency / 30.0))))

            // Record user satisfaction if provided
            if let satisfaction = userSatisfaction {
                let satisfactionValue = tuner.getValue(.qualitySatisfactionWeight)
                tuner.recordOutcome(.qualitySatisfactionWeight, testedValue: satisfactionValue, outcome: satisfaction)
            }
        }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        // Load Supra-Model state
        if let data = UserDefaults.standard.data(forKey: supraModelKey) {
            do {
                supraModel = try JSONDecoder().decode(SupraModelState.self, from: data)
            } catch {
                logger.error("Failed to decode SupraModelState: \(error.localizedDescription)")
            }
        }

        // Load fleet state
        if let data = UserDefaults.standard.data(forKey: fleetStateKey) {
            do {
                modelFleet = try JSONDecoder().decode(ModelFleet.self, from: data)
            } catch {
                logger.error("Failed to decode ModelFleet: \(error.localizedDescription)")
            }
        }

        // Load policy
        if let data = UserDefaults.standard.data(forKey: policyKey) {
            do {
                policy = try JSONDecoder().decode(GovernanceEnginePolicy.self, from: data)
            } catch {
                logger.error("Failed to decode GovernanceEnginePolicy: \(error.localizedDescription)")
            }
        }
    }

    private func persistState() {
        // Save Supra-Model state
        do {
            let data = try JSONEncoder().encode(supraModel)
            UserDefaults.standard.set(data, forKey: supraModelKey)
        } catch {
            logger.error("Failed to encode SupraModelState: \(error.localizedDescription)")
        }

        // Save fleet state
        do {
            let data = try JSONEncoder().encode(modelFleet)
            UserDefaults.standard.set(data, forKey: fleetStateKey)
        } catch {
            logger.error("Failed to encode ModelFleet: \(error.localizedDescription)")
        }

        // Save policy
        do {
            let data = try JSONEncoder().encode(policy)
            UserDefaults.standard.set(data, forKey: policyKey)
        } catch {
            logger.error("Failed to encode GovernanceEnginePolicy: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    // periphery:ignore - Reserved: shutdown() instance method — reserved for future feature activation
    func shutdown() {
        governanceTask?.cancel()
        isActive = false
        persistState()
    }
}

// MARK: - Supporting Types

// periphery:ignore - Reserved: shutdown() instance method reserved for future feature activation

/// State of the Supra-Model (always-present anchor)
struct SupraModelState: Codable, Sendable {
    let modelId: String
    let modelName: String
    var status: SupraModelStatus
    let designatedAt: Date
    let reason: String
    var previousModel: String?
    var qualityScore: Double?
    var lastVerified: Date?
}

enum SupraModelStatus: String, Codable, Sendable {
    case active      // Currently serving as Supra-Model
    case downloading // Being downloaded
    case pending     // Awaiting user approval
    case evolving    // Transitioning to a new model
}

/// Model tier classification
enum ModelTier: String, Codable, Sendable, CaseIterable {
    case tier1AlwaysLoaded   = "Tier 1: Always Loaded"
    case tier2OnDemand       = "Tier 2: On-Demand"
    case tier3Situational    = "Tier 3: Situational"
}

/// Dynamic model fleet
struct ModelFleet: Codable, Sendable {
    var tier1: [String] = []  // Model names in Tier 1
    var tier2: [String] = []  // Model names in Tier 2
    var tier3: [String] = []  // Model names in Tier 3

    private var modelTierMap: [String: ModelTier] = [:]

    mutating func assignModel(_ model: LocalModel, to tier: ModelTier) {
        // Remove from any existing tier
        tier1.removeAll { $0 == model.name }
        tier2.removeAll { $0 == model.name }
        tier3.removeAll { $0 == model.name }

        // Add to new tier
        switch tier {
        case .tier1AlwaysLoaded:
            tier1.append(model.name)
        case .tier2OnDemand:
            tier2.append(model.name)
        case .tier3Situational:
            tier3.append(model.name)
        }

        modelTierMap[model.name] = tier
    }

    @MainActor
    func getModels(in tier: ModelTier) -> [LocalModel] {
        let names: [String] = switch tier {
        case .tier1AlwaysLoaded: tier1
        case .tier2OnDemand: tier2
        case .tier3Situational: tier3
        }

        let manager = LocalModelManager.shared
        return manager.availableModels.filter { names.contains($0.name) }
    }

    func getTier(for modelName: String) -> ModelTier? {
        modelTierMap[modelName]
    }
}

/// Model selection result for governance engine
struct GovernanceModelSelection: Sendable {
    let model: LocalModel
    // periphery:ignore - Reserved: tier property — reserved for future feature activation
    let tier: ModelTier
    // periphery:ignore - Reserved: score property — reserved for future feature activation
    let score: Double
    // periphery:ignore - Reserved: reason property — reserved for future feature activation
    let reason: String
}

/// Task context for model selection in governance engine
// periphery:ignore - Reserved: GovernanceTaskContext type — reserved for future feature activation
struct GovernanceTaskContext: Sendable {
    // periphery:ignore - Reserved: tier property reserved for future feature activation
    // periphery:ignore - Reserved: score property reserved for future feature activation
    // periphery:ignore - Reserved: reason property reserved for future feature activation
    var urgency: GovernanceTaskUrgency = .normal
    var allowSituational: Bool = true
    var preferLocal: Bool = true
    // periphery:ignore - Reserved: GovernanceTaskContext type reserved for future feature activation
    var maxLatencyMs: Int?

    enum GovernanceTaskUrgency: String, Sendable {
        case low
        case normal
        case high
        case critical
    }
}

/// Governance policy
struct GovernanceEnginePolicy: Codable, Sendable {
    var supraModelMinQuality: Double = 0.6
    var tier1MaxModels: Int = 3
    var tier2MaxModels: Int = 5
    var enablePredictivePreloading: Bool = true
    var preloadProbabilityThreshold: Double = 0.4
    var governanceCycleSeconds: Int = 300
    var enableAutoEvolution: Bool = true

    static let `default` = GovernanceEnginePolicy()
}

/// Resource snapshot
struct ResourceSnapshot: Sendable {
    var availableMemoryGB: Double = 8.0
    var totalMemoryGB: Double = 16.0
    var availableDiskGB: Double = 50.0
    var totalDiskGB: Double = 500.0
    // periphery:ignore - Reserved: modelStorageGB property — reserved for future feature activation
    var modelStorageGB: Double = 0.0
    // periphery:ignore - Reserved: thermalState property — reserved for future feature activation
    var thermalState: ResourceThermalState = .nominal
    var timestamp = Date()

// periphery:ignore - Reserved: modelStorageGB property reserved for future feature activation

// periphery:ignore - Reserved: thermalState property reserved for future feature activation

    var memoryPressure: Double {
        1.0 - (availableMemoryGB / totalMemoryGB)
    }

    // periphery:ignore - Reserved: diskPressure property — reserved for future feature activation
    var diskPressure: Double {
        // periphery:ignore - Reserved: diskPressure property reserved for future feature activation
        1.0 - (availableDiskGB / totalDiskGB)
    }
}

enum ResourceThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

// MARK: - Notifications

extension Notification.Name {
    static let supraModelEvolved = Notification.Name("ModelGovernance.supraModelEvolved")
    static let supraModelBootstrapRequired = Notification.Name("ModelGovernance.bootstrapRequired")
    // periphery:ignore - Reserved: fleetReorganized static property reserved for future feature activation
    static let fleetReorganized = Notification.Name("ModelGovernance.fleetReorganized")
}
