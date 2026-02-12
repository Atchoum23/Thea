// UnifiedLocalModelOrchestrator.swift
// Thea V2
//
// Multi-runtime local model orchestration with intelligent routing
// Supports MLX, Ollama, and GGUF runtimes with seamless fallback
//
// CREATED: February 2, 2026

import Foundation
import OSLog

// MARK: - Unified Local Model Orchestrator

/// Orchestrates local model selection across multiple runtimes
/// Integrates with ModelRouter for unified local+remote model routing
@MainActor
@Observable
final class UnifiedLocalModelOrchestrator {
    static let shared = UnifiedLocalModelOrchestrator()

    private let logger = Logger(subsystem: "com.thea.ai", category: "LocalOrchestrator")

    // MARK: - State

    private(set) var availableRuntimes: Set<LocalRuntime> = []
    private(set) var runtimeStatus: [LocalRuntime: RuntimeStatus] = [:]
    private(set) var modelPerformance: [String: LocalModelPerformanceMetrics] = [:]
    private(set) var isInitialized = false

    // MARK: - Configuration

    var preferredRuntime: LocalRuntime = .mlx
    var enableAutomaticFallback = true
    var performanceTrackingEnabled = true
    var maxConcurrentModels = 2

    // MARK: - Initialization

    private init() {
        Task {
            await initialize()
        }
    }

    func initialize() async {
        logger.info("Initializing unified local model orchestrator...")

        // Detect available runtimes
        await detectAvailableRuntimes()

        // Load performance history
        loadPerformanceHistory()

        isInitialized = true
        logger.info("Local orchestrator initialized with \(self.availableRuntimes.count) runtime(s)")
    }

    // MARK: - Runtime Detection

    private func detectAvailableRuntimes() async {
        var detected: Set<LocalRuntime> = []

        // MLX detection (macOS only, Apple Silicon)
        #if os(macOS)
        if await isMLXAvailable() {
            detected.insert(.mlx)
            runtimeStatus[.mlx] = RuntimeStatus(
                isAvailable: true,
                version: "1.0",
                lastChecked: Date()
            )
            logger.debug("MLX runtime available")
        }

        // Ollama detection
        if await isOllamaAvailable() {
            detected.insert(.ollama)
            runtimeStatus[.ollama] = RuntimeStatus(
                isAvailable: true,
                version: await getOllamaVersion(),
                lastChecked: Date()
            )
            logger.debug("Ollama runtime available")
        }

        // GGUF detection (requires llama.cpp or compatible runner)
        if await isGGUFAvailable() {
            detected.insert(.gguf)
            runtimeStatus[.gguf] = RuntimeStatus(
                isAvailable: true,
                version: "llama.cpp",
                lastChecked: Date()
            )
            logger.debug("GGUF runtime available")
        }
        #endif

        availableRuntimes = detected
    }

    private func isMLXAvailable() async -> Bool {
        #if os(macOS)
        // Check if running on Apple Silicon
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.contains("arm64")
        #else
        return false
        #endif
    }

    private func isOllamaAvailable() async -> Bool {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ollama"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    private func isGGUFAvailable() async -> Bool {
        #if os(macOS)
        // Check for llama.cpp or compatible GGUF runner
        let possiblePaths = [
            "/usr/local/bin/llama",
            "/opt/homebrew/bin/llama",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/llama").path
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
        #else
        return false
        #endif
    }

    private func getOllamaVersion() async -> String? {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            return output?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Model Selection

    /// Select the optimal local model for a given task
    func selectModel(
        for taskType: TaskType,
        context: LocalRoutingContext = LocalRoutingContext()
    ) async -> LocalModelSelection? {
        guard !availableRuntimes.isEmpty else {
            logger.warning("No local runtimes available")
            return nil
        }

        let manager = LocalModelManager.shared
        await manager.waitForDiscovery()

        let candidates = manager.availableModels

        guard !candidates.isEmpty else {
            logger.warning("No local models available")
            return nil
        }

        // Score each model for this task
        var scoredModels: [(model: LocalModel, score: Double, reason: String)] = []

        for model in candidates {
            let score = calculateModelScore(model, for: taskType, context: context)
            let reason = buildScoreReason(model, for: taskType, score: score)
            scoredModels.append((model, score, reason))
        }

        // Sort by score
        scoredModels.sort { $0.score > $1.score }

        guard let best = scoredModels.first else {
            return nil
        }

        logger.info("Selected local model: \(best.model.name) (score: \(best.score))")

        return LocalModelSelection(
            model: best.model,
            runtime: mapModelRuntimeToLocal(best.model.runtime),
            score: best.score,
            reason: best.reason,
            alternatives: scoredModels.dropFirst().prefix(3).map { $0.model }
        )
    }

    /// Select the best runtime for a specific model format
    func selectRuntime(for model: LocalModel) -> LocalRuntime {
        // If model has a specific runtime, use it
        let modelRuntime = mapModelRuntimeToLocal(model.runtime)

        // Check if that runtime is available
        if availableRuntimes.contains(modelRuntime) {
            return modelRuntime
        }

        // Fallback chain
        if enableAutomaticFallback {
            let fallbackChain: [LocalRuntime] = [.mlx, .ollama, .gguf]

            for runtime in fallbackChain {
                if availableRuntimes.contains(runtime) && canRuntimeHandle(runtime, model: model) {
                    logger.info("Falling back from \(modelRuntime.rawValue) to \(runtime.rawValue)")
                    return runtime
                }
            }
        }

        // Return model's runtime even if unavailable (caller should handle)
        return modelRuntime
    }

    /// Map from existing ModelRuntime to our LocalRuntime
    private func mapModelRuntimeToLocal(_ runtime: ModelRuntime) -> LocalRuntime {
        switch runtime {
        case .mlx: return .mlx
        case .ollama: return .ollama
        case .gguf: return .gguf
        case .coreML: return .coreML
        }
    }

    private func canRuntimeHandle(_ runtime: LocalRuntime, model: LocalModel) -> Bool {
        switch (runtime, model.type) {
        case (.mlx, .mlx): return true
        case (.ollama, .ollama): return true
        case (.ollama, .gguf): return true  // Ollama can run GGUF models
        case (.gguf, .gguf): return true
        case (.coreML, .coreML): return true
        default: return false
        }
    }

    // MARK: - Scoring

    private func calculateModelScore(
        _ model: LocalModel,
        for taskType: TaskType,
        context: LocalRoutingContext
    ) -> Double {
        var score = 0.5  // Base score

        // 1. Task capability match (40% weight)
        let capabilityScore = calculateCapabilityScore(model, for: taskType)
        score += capabilityScore * 0.4

        // 2. Historical performance (30% weight)
        let performanceScore = getHistoricalPerformance(model, for: taskType)
        score += performanceScore * 0.3

        // 3. Model size appropriateness (15% weight)
        let sizeScore = calculateSizeScore(model, context: context)
        score += sizeScore * 0.15

        // 4. Runtime preference (10% weight)
        let modelLocalRuntime = mapModelRuntimeToLocal(model.runtime)
        let runtimeScore = modelLocalRuntime == preferredRuntime ? 1.0 : 0.7
        score += runtimeScore * 0.1

        // 5. Recency/freshness (5% weight)
        let quantizationScore = calculateQuantizationScore(model)
        score += quantizationScore * 0.05

        return min(1.0, max(0.0, score))
    }

    private func calculateCapabilityScore(_ model: LocalModel, for taskType: TaskType) -> Double {
        let modelName = model.name.lowercased()

        switch taskType {
        case .codeGeneration, .debugging, .codeRefactoring:
            // Prefer coding-optimized models
            if modelName.contains("code") || modelName.contains("deepseek") {
                return 1.0
            }
            if modelName.contains("qwen") || modelName.contains("codellama") {
                return 0.9
            }
            return 0.6

        case .math, .mathLogic, .analysis, .complexReasoning:
            // Prefer reasoning models
            if modelName.contains("qwen") || modelName.contains("deepseek") {
                return 0.95
            }
            if modelName.contains("llama") {
                return 0.85
            }
            return 0.7

        case .creative, .creativeWriting, .contentCreation, .creation:
            // Prefer instruction-tuned general models
            if modelName.contains("instruct") {
                return 0.9
            }
            if modelName.contains("mistral") {
                return 0.85
            }
            return 0.7

        case .translation:
            // Prefer multilingual models
            if modelName.contains("qwen") {
                return 0.95
            }
            return 0.6

        case .conversation:
            // All instruction models work well
            if modelName.contains("instruct") || modelName.contains("chat") {
                return 0.9
            }
            return 0.75

        default:
            return 0.7
        }
    }

    private func getHistoricalPerformance(_ model: LocalModel, for taskType: TaskType) -> Double {
        guard let metrics = modelPerformance[model.name] else {
            return 0.5  // No history, neutral score
        }

        let taskMetrics = metrics.taskMetrics[taskType]
        return taskMetrics?.successRate ?? 0.5
    }

    private func calculateSizeScore(_ model: LocalModel, context: LocalRoutingContext) -> Double {
        let sizeGB = Double(model.size) / 1_000_000_000

        // Check against context constraints
        if let maxSize = context.maxModelSizeGB, sizeGB > maxSize {
            return 0.1  // Model too large
        }

        // Sweet spot is 4-8GB for most hardware
        if sizeGB >= 4 && sizeGB <= 8 {
            return 1.0
        } else if sizeGB < 4 {
            return 0.8  // Smaller models may sacrifice quality
        } else if sizeGB <= 16 {
            return 0.7
        } else {
            return 0.5  // Very large models
        }
    }

    private func calculateQuantizationScore(_ model: LocalModel) -> Double {
        switch model.quantization.lowercased() {
        case "4bit", "q4": return 0.9  // Good balance
        case "8bit", "q8": return 1.0  // Better quality
        case "bf16", "fp16": return 0.8  // Full precision but larger
        default: return 0.7
        }
    }

    private func buildScoreReason(_ model: LocalModel, for taskType: TaskType, score: Double) -> String {
        var reasons: [String] = []

        if score > 0.85 {
            reasons.append("Excellent match for \(taskType.rawValue)")
        } else if score > 0.7 {
            reasons.append("Good fit for \(taskType.rawValue)")
        }

        if model.quantization.lowercased().contains("4bit") {
            reasons.append("Memory-efficient 4-bit quantization")
        }

        let modelLocalRuntime = mapModelRuntimeToLocal(model.runtime)
        if availableRuntimes.contains(modelLocalRuntime) {
            reasons.append("\(modelLocalRuntime.displayName) runtime ready")
        }

        return reasons.joined(separator: "; ")
    }

    // MARK: - Performance Tracking

    func recordModelUsage(
        model: LocalModel,
        taskType: TaskType,
        success: Bool,
        latency: TimeInterval,
        tokensGenerated: Int
    ) {
        guard performanceTrackingEnabled else { return }

        if modelPerformance[model.name] == nil {
            modelPerformance[model.name] = LocalModelPerformanceMetrics(modelName: model.name)
        }

        modelPerformance[model.name]?.record(
            taskType: taskType,
            success: success,
            latency: latency,
            tokens: tokensGenerated
        )

        // Persist periodically
        savePerformanceHistory()

        logger.debug("Recorded usage for \(model.name): success=\(success), latency=\(latency)s")
    }

    // MARK: - Autonomous Recommendations

    /// Get model recommendations based on usage patterns and hardware
    func getModelRecommendations() async -> [LocalModelSuggestion] {
        let engine = LocalModelRecommendationEngine.shared
        let recommendations = engine.recommendations

        return recommendations.map { rec in
            LocalModelSuggestion(
                modelId: rec.model.id,
                modelName: rec.model.name,
                reason: rec.reasons.first ?? "Recommended based on your usage",
                estimatedSizeGB: rec.model.estimatedSizeGB,
                priority: mapPriority(rec.priority),
                capabilities: rec.model.capabilities.map { $0.rawValue }
            )
        }
    }

    private func mapPriority(_ priority: RecommendationPriority) -> SuggestionPriority {
        switch priority {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    /// Check if a model should be recommended for download
    func shouldRecommendModel(_ modelId: String) async -> Bool {
        let engine = LocalModelRecommendationEngine.shared
        return engine.recommendations.contains { $0.model.id == modelId }
    }

    // MARK: - Integration with ModelRouter

    /// Register local models with the ProviderRegistry
    func registerWithProviderRegistry() async {
        // Delegate to ProviderRegistry's built-in local model refresh
        await ProviderRegistry.shared.refreshLocalProviders()
        logger.info("Refreshed local model registrations via ProviderRegistry")
    }

    // MARK: - Persistence

    private func loadPerformanceHistory() {
        guard let data = UserDefaults.standard.data(forKey: "LocalOrchestrator.performanceHistory"),
              let history = try? JSONDecoder().decode([String: LocalModelPerformanceMetrics].self, from: data) else {
            return
        }
        modelPerformance = history
        logger.debug("Loaded performance history for \(history.count) models")
    }

    private func savePerformanceHistory() {
        guard let data = try? JSONEncoder().encode(modelPerformance) else { return }
        UserDefaults.standard.set(data, forKey: "LocalOrchestrator.performanceHistory")
    }

    // MARK: - Cleanup

    func resetPerformanceHistory() {
        modelPerformance.removeAll()
        UserDefaults.standard.removeObject(forKey: "LocalOrchestrator.performanceHistory")
        logger.info("Reset local model performance history")
    }
}

// MARK: - Supporting Types

enum LocalRuntime: String, Codable, Sendable, CaseIterable {
    case mlx = "MLX"
    case ollama = "Ollama"
    case gguf = "GGUF"
    case coreML = "Core ML"

    var displayName: String { rawValue }

    /// Expected tokens per second on Apple Silicon
    var expectedThroughput: Int {
        switch self {
        case .mlx: return 230  // MLX is optimized for Apple Silicon
        case .ollama: return 80
        case .gguf: return 60
        case .coreML: return 150  // CoreML uses CPU+GPU+ANE
        }
    }
}

struct RuntimeStatus: Sendable {
    let isAvailable: Bool
    let version: String?
    let lastChecked: Date
    var errorMessage: String?
}

struct LocalModelSelection: Sendable {
    let model: LocalModel
    let runtime: LocalRuntime
    let score: Double
    let reason: String
    let alternatives: [LocalModel]
}

struct LocalRoutingContext: Sendable {
    var urgency: RoutingContext.Urgency = .normal
    var maxModelSizeGB: Double?
    var preferOffline: Bool = false
    var preferredQuantization: String?

    init(
        urgency: RoutingContext.Urgency = .normal,
        maxModelSizeGB: Double? = nil,
        preferOffline: Bool = false,
        preferredQuantization: String? = nil
    ) {
        self.urgency = urgency
        self.maxModelSizeGB = maxModelSizeGB
        self.preferOffline = preferOffline
        self.preferredQuantization = preferredQuantization
    }
}

struct LocalModelPerformanceMetrics: Codable, Sendable {
    let modelName: String
    var taskMetrics: [TaskType: TaskPerformanceMetrics] = [:]
    var totalUsageCount: Int = 0
    var lastUsed: Date?

    init(modelName: String) {
        self.modelName = modelName
    }

    mutating func record(taskType: TaskType, success: Bool, latency: TimeInterval, tokens: Int) {
        if taskMetrics[taskType] == nil {
            taskMetrics[taskType] = TaskPerformanceMetrics()
        }

        taskMetrics[taskType]?.record(success: success, latency: latency, tokens: tokens)
        totalUsageCount += 1
        lastUsed = Date()
    }
}

struct TaskPerformanceMetrics: Codable, Sendable {
    var successCount: Int = 0
    var failureCount: Int = 0
    var totalLatency: TimeInterval = 0
    var totalTokens: Int = 0

    var successRate: Double {
        let total = successCount + failureCount
        guard total > 0 else { return 0.5 }
        return Double(successCount) / Double(total)
    }

    var averageLatency: TimeInterval {
        let total = successCount + failureCount
        guard total > 0 else { return 0 }
        return totalLatency / Double(total)
    }

    var averageTokensPerSecond: Double {
        guard totalLatency > 0 else { return 0 }
        return Double(totalTokens) / totalLatency
    }

    mutating func record(success: Bool, latency: TimeInterval, tokens: Int) {
        if success {
            successCount += 1
        } else {
            failureCount += 1
        }
        totalLatency += latency
        totalTokens += tokens
    }
}

struct LocalModelSuggestion: Identifiable, Sendable {
    var id: String { modelId }
    let modelId: String
    let modelName: String
    let reason: String
    let estimatedSizeGB: Double
    let priority: SuggestionPriority
    let capabilities: [String]
}

enum SuggestionPriority: String, Codable, Sendable {
    case high
    case medium
    case low
}

// MARK: - ModelRouter Extension for Local Models

extension ModelRouter {
    /// Route with local model preference
    func routeWithLocalPreference(
        classification: ClassificationResult,
        preferLocal: Bool = false
    ) async -> RoutingDecision {
        let localOrchestrator = UnifiedLocalModelOrchestrator.shared

        // If preferring local and local models are available
        if preferLocal, let localSelection = await localOrchestrator.selectModel(for: classification.taskType) {
            let aiModel = AIModel(
                id: localSelection.model.name,
                name: localSelection.model.name,
                provider: "local",
                contextWindow: 4096,
                capabilities: [.chat],
                isLocal: true
            )

            return RoutingDecision(
                model: aiModel,
                provider: "local",
                taskType: classification.taskType,
                confidence: classification.confidence,
                reason: "Local model: \(localSelection.reason)",
                alternatives: [],
                timestamp: Date()
            )
        }

        // Fall back to standard routing
        return route(classification: classification)
    }
}
