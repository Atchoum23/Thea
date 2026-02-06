// ModelBenchmarkService.swift
// Fetches and maintains up-to-date model performance benchmarks from multiple sources
// Used to dynamically update routing rules based on latest model capabilities

import Foundation

/// Service that fetches model benchmarks from online sources to keep routing rules current
@MainActor
@Observable
public final class ModelBenchmarkService {
    public static let shared = ModelBenchmarkService()

    // MARK: - State

    private(set) var benchmarks: [String: ModelBenchmark] = [:]
    private(set) var lastUpdateDate: Date?
    private(set) var isUpdating = false
    private(set) var updateError: Error?

    // MARK: - Configuration

    /// How often to refresh benchmarks (default: daily)
    private let refreshInterval: TimeInterval = 86400 // 24 hours

    /// Storage key for cached benchmarks
    private let cacheKey = "ModelBenchmarkService.benchmarks"

    private init() {
        loadCachedBenchmarks()
    }

    // MARK: - Public API

    /// Update benchmarks from all sources if needed
    public func updateIfNeeded() async {
        guard shouldUpdate else { return }
        await updateBenchmarks()
    }

    /// Force update benchmarks from all sources
    public func updateBenchmarks() async {
        isUpdating = true
        updateError = nil

        do {
            // Fetch from multiple sources in parallel
            async let openRouterModels = fetchOpenRouterBenchmarks()
            async let huggingFaceScores = fetchHuggingFaceBenchmarks()
            async let providerModels = fetchConfiguredProviderModels()

            let (orModels, hfScores, configuredModels) = try await (openRouterModels, huggingFaceScores, providerModels)

            // Merge benchmarks from all sources
            var merged: [String: ModelBenchmark] = [:]

            // OpenRouter provides pricing and context length (most comprehensive)
            for model in orModels {
                merged[model.id] = ModelBenchmark(
                    modelID: model.id,
                    provider: model.providerName,
                    contextLength: model.contextLength,
                    inputCostPer1M: model.pricing.promptPrice * 1_000_000,
                    outputCostPer1M: model.pricing.completionPrice * 1_000_000,
                    qualityScore: hfScores[model.id] ?? estimateQualityScore(for: model.id),
                    speedScore: estimateSpeedScore(for: model),
                    capabilities: inferCapabilities(from: model),
                    lastUpdated: Date()
                )
            }

            // Add models from configured providers (direct API access)
            for (providerID, models) in configuredModels {
                for modelInfo in models {
                    let fullID = "\(providerID)/\(modelInfo.id)"
                    // Only add if not already from OpenRouter (avoid duplicates)
                    if merged[fullID] == nil {
                        merged[fullID] = ModelBenchmark(
                            modelID: fullID,
                            provider: providerID,
                            contextLength: modelInfo.contextLength,
                            inputCostPer1M: modelInfo.inputCostPer1M,
                            outputCostPer1M: modelInfo.outputCostPer1M,
                            qualityScore: hfScores[fullID] ?? estimateQualityScore(for: fullID),
                            speedScore: estimateSpeedFromProvider(providerID: providerID, modelID: modelInfo.id),
                            capabilities: inferCapabilitiesFromProvider(providerID: providerID, modelID: modelInfo.id),
                            lastUpdated: Date()
                        )
                    }
                }
            }

            // Add local models with zero cost
            #if os(macOS)
            let localModels = LocalModelManager.shared.availableModels
            for local in localModels {
                let localID = "local-\(local.name)"
                merged[localID] = ModelBenchmark(
                    modelID: localID,
                    provider: "local",
                    contextLength: 8192, // Default, could be read from config.json
                    inputCostPer1M: 0,
                    outputCostPer1M: 0,
                    qualityScore: estimateLocalQualityScore(for: local),
                    speedScore: 0.7, // Local models are generally fast on Apple Silicon
                    capabilities: inferLocalCapabilities(from: local),
                    lastUpdated: Date()
                )
            }
            let localModelCount = localModels.count
            #else
            let localModelCount = 0
            #endif

            benchmarks = merged
            lastUpdateDate = Date()
            cacheBenchmarks()

            print("✅ ModelBenchmarkService: Updated \(merged.count) model benchmarks")
            print("   - OpenRouter: \(orModels.count) models")
            print("   - Direct providers: \(configuredModels.map { "\($0.key):\($0.value.count)" }.joined(separator: ", "))")
            print("   - Local: \(localModelCount) models")

        } catch {
            updateError = error
            print("❌ ModelBenchmarkService: Update failed: \(error)")
        }

        isUpdating = false
    }

    /// Get benchmark for a specific model
    public func getBenchmark(for modelID: String) -> ModelBenchmark? {
        benchmarks[modelID]
    }

    /// Get best models for a task type, sorted by suitability
    public func getBestModels(for taskType: TaskType, limit: Int = 5) -> [ModelBenchmark] {
        let scored = benchmarks.values.map { benchmark -> (ModelBenchmark, Double) in
            let score = calculateTaskSuitability(benchmark: benchmark, taskType: taskType)
            return (benchmark, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// Generate dynamic routing rules based on current benchmarks
    public func generateRoutingRules() -> [String: [String]] {
        var rules: [String: [String]] = [:]

        for taskType in TaskType.allCases {
            let bestModels = getBestModels(for: taskType, limit: 5)
            rules[taskType.rawValue] = bestModels.map(\.modelID)
        }

        return rules
    }

    // MARK: - Data Fetching

    private func fetchOpenRouterBenchmarks() async throws -> [OpenRouterModel] {
        // Use existing ModelCatalogManager
        await ModelCatalogManager.shared.refreshIfNeeded()
        return ModelCatalogManager.shared.models
    }

    /// Fetch models from all configured providers (OpenAI, Anthropic, Google, etc.)
    private func fetchConfiguredProviderModels() async throws -> [String: [ProviderModelInfo]] {
        var results: [String: [ProviderModelInfo]] = [:]

        // Get all configured providers
        let providerRegistry = ProviderRegistry.shared
        let configuredProviders = providerRegistry.configuredProviders

        for provider in configuredProviders {
            let providerName = provider.metadata.name

            // Skip OpenRouter (already fetched separately with more data)
            guard providerName != "openrouter" else { continue }

            do {
                let models = try await fetchModelsFromProvider(provider)
                if !models.isEmpty {
                    results[providerName] = models
                }
            } catch {
                print("⚠️ Failed to fetch models from \(providerName): \(error)")
                // Continue with other providers
            }
        }

        return results
    }

    private func fetchModelsFromProvider(_ provider: AIProvider) async throws -> [ProviderModelInfo] {
        // Each provider has different API endpoints for listing models
        // We use known model lists for major providers

        let providerName = provider.metadata.name
        var models: [ProviderModelInfo] = []

        switch providerName {
        case "openai":
            models = openAIKnownModels()
        case "anthropic":
            models = anthropicKnownModels()
        case "google":
            models = googleKnownModels()
        case "groq":
            models = groqKnownModels()
        case "perplexity":
            models = perplexityKnownModels()
        default:
            break
        }

        return models
    }

    // MARK: - Known Provider Models

    private func openAIKnownModels() -> [ProviderModelInfo] {
        [
            ProviderModelInfo(id: "gpt-4o", contextLength: 128000, inputCostPer1M: 2.50, outputCostPer1M: 10.00),
            ProviderModelInfo(id: "gpt-4o-mini", contextLength: 128000, inputCostPer1M: 0.15, outputCostPer1M: 0.60),
            ProviderModelInfo(id: "gpt-4-turbo", contextLength: 128000, inputCostPer1M: 10.00, outputCostPer1M: 30.00),
            ProviderModelInfo(id: "gpt-4", contextLength: 8192, inputCostPer1M: 30.00, outputCostPer1M: 60.00),
            ProviderModelInfo(id: "gpt-3.5-turbo", contextLength: 16385, inputCostPer1M: 0.50, outputCostPer1M: 1.50),
            ProviderModelInfo(id: "o1-preview", contextLength: 128000, inputCostPer1M: 15.00, outputCostPer1M: 60.00),
            ProviderModelInfo(id: "o1-mini", contextLength: 128000, inputCostPer1M: 3.00, outputCostPer1M: 12.00)
        ]
    }

    private func anthropicKnownModels() -> [ProviderModelInfo] {
        [
            ProviderModelInfo(id: "claude-3-5-sonnet-20241022", contextLength: 200000, inputCostPer1M: 3.00, outputCostPer1M: 15.00),
            ProviderModelInfo(id: "claude-3-opus-20240229", contextLength: 200000, inputCostPer1M: 15.00, outputCostPer1M: 75.00),
            ProviderModelInfo(id: "claude-3-sonnet-20240229", contextLength: 200000, inputCostPer1M: 3.00, outputCostPer1M: 15.00),
            ProviderModelInfo(id: "claude-3-haiku-20240307", contextLength: 200000, inputCostPer1M: 0.25, outputCostPer1M: 1.25)
        ]
    }

    private func googleKnownModels() -> [ProviderModelInfo] {
        [
            ProviderModelInfo(id: "gemini-1.5-pro", contextLength: 2000000, inputCostPer1M: 1.25, outputCostPer1M: 5.00),
            ProviderModelInfo(id: "gemini-1.5-flash", contextLength: 1000000, inputCostPer1M: 0.075, outputCostPer1M: 0.30),
            ProviderModelInfo(id: "gemini-1.0-pro", contextLength: 32000, inputCostPer1M: 0.50, outputCostPer1M: 1.50)
        ]
    }

    private func groqKnownModels() -> [ProviderModelInfo] {
        [
            ProviderModelInfo(id: "llama-3.3-70b-versatile", contextLength: 128000, inputCostPer1M: 0.59, outputCostPer1M: 0.79),
            ProviderModelInfo(id: "llama-3.1-8b-instant", contextLength: 128000, inputCostPer1M: 0.05, outputCostPer1M: 0.08),
            ProviderModelInfo(id: "mixtral-8x7b-32768", contextLength: 32768, inputCostPer1M: 0.24, outputCostPer1M: 0.24),
            ProviderModelInfo(id: "gemma2-9b-it", contextLength: 8192, inputCostPer1M: 0.20, outputCostPer1M: 0.20)
        ]
    }

    private func perplexityKnownModels() -> [ProviderModelInfo] {
        [
            ProviderModelInfo(id: "llama-3.1-sonar-huge-128k-online", contextLength: 128000, inputCostPer1M: 5.00, outputCostPer1M: 5.00),
            ProviderModelInfo(id: "llama-3.1-sonar-large-128k-online", contextLength: 128000, inputCostPer1M: 1.00, outputCostPer1M: 1.00),
            ProviderModelInfo(id: "llama-3.1-sonar-small-128k-online", contextLength: 128000, inputCostPer1M: 0.20, outputCostPer1M: 0.20)
        ]
    }

    // MARK: - Provider-Specific Inference

    private func estimateSpeedFromProvider(providerID: String, modelID: String) -> Double {
        // Groq is known for speed
        if providerID == "groq" {
            return 0.95
        }
        // Smaller models are faster
        let id = modelID.lowercased()
        if id.contains("mini") || id.contains("flash") || id.contains("haiku") || id.contains("small") {
            return 0.85
        }
        if id.contains("8b") || id.contains("7b") {
            return 0.80
        }
        if id.contains("opus") || id.contains("huge") || id.contains("70b") {
            return 0.50
        }
        return 0.65
    }

    private func inferCapabilitiesFromProvider(providerID: String, modelID: String) -> Set<BenchmarkCapability> {
        var caps: Set<BenchmarkCapability> = [.textGeneration]
        let id = modelID.lowercased()

        // Vision capability
        if id.contains("vision") || id.contains("4o") || id.contains("gemini") {
            caps.insert(.vision)
        }

        // Code capability
        if id.contains("code") || providerID == "anthropic" || id.contains("gpt-4") {
            caps.insert(.codeGeneration)
        }

        // Advanced reasoning
        if id.contains("o1") || id.contains("opus") || id.contains("pro") {
            caps.insert(.advancedReasoning)
        }

        // Web search (Perplexity specialty)
        if providerID == "perplexity" || id.contains("online") || id.contains("sonar") {
            caps.insert(.webSearch)
        }

        // Long context
        if id.contains("gemini") || id.contains("claude-3") {
            caps.insert(.longContext)
        }

        // Function calling
        if providerID == "openai" || providerID == "anthropic" || id.contains("gpt-4") {
            caps.insert(.functionCalling)
        }

        return caps
    }

    private func fetchHuggingFaceBenchmarks() async throws -> [String: Double] {
        // Fetch from HuggingFace Open LLM Leaderboard API
        // This provides quality scores based on standardized benchmarks
        guard let url = URL(string: "https://huggingface.co/api/spaces/open-llm-leaderboard/open_llm_leaderboard/api/v2/leaderboard") else {
            return [:]
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return [:]
            }

            // Parse leaderboard data
            // The actual API structure may vary - this is a simplified version
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var scores: [String: Double] = [:]
                for entry in json {
                    if let modelName = entry["model_name"] as? String,
                       let avgScore = entry["average"] as? Double {
                        // Map HuggingFace model names to OpenRouter IDs
                        let normalizedID = normalizeModelID(modelName)
                        scores[normalizedID] = avgScore / 100.0 // Normalize to 0-1
                    }
                }
                return scores
            }
        } catch {
            print("⚠️ HuggingFace leaderboard fetch failed: \(error)")
        }

        return [:]
    }

    // MARK: - Score Estimation

    private func estimateQualityScore(for modelID: String) -> Double {
        // Estimate based on model family and size
        let id = modelID.lowercased()

        // Top tier models
        if id.contains("opus") || id.contains("o1") || id.contains("gpt-4o") && !id.contains("mini") {
            return 0.95
        }

        // High tier
        if id.contains("sonnet") || id.contains("gpt-4") || id.contains("claude-3") {
            return 0.85
        }

        // Mid tier
        if id.contains("gpt-3.5") || id.contains("haiku") || id.contains("gemini") {
            return 0.70
        }

        // Open source large
        if id.contains("70b") || id.contains("72b") || id.contains("65b") {
            return 0.75
        }

        // Open source medium
        if id.contains("13b") || id.contains("14b") {
            return 0.60
        }

        // Open source small
        if id.contains("7b") || id.contains("8b") {
            return 0.50
        }

        return 0.40 // Unknown models
    }

    private func estimateSpeedScore(for model: OpenRouterModel) -> Double {
        // Smaller context = usually faster
        // Lower price = usually faster (smaller models)
        let contextFactor = min(1.0, 32000.0 / Double(model.contextLength))
        let priceFactor = min(1.0, 0.001 / max(0.0001, model.pricing.promptPrice))

        return (contextFactor + priceFactor) / 2.0
    }

    #if os(macOS)
    private func estimateLocalQualityScore(for model: LocalModel) -> Double {
        let name = model.name.lowercased()

        // Estimate based on model size
        if name.contains("72b") || name.contains("70b") {
            return 0.80
        }
        if name.contains("32b") || name.contains("34b") {
            return 0.70
        }
        if name.contains("13b") || name.contains("14b") {
            return 0.60
        }
        if name.contains("7b") || name.contains("8b") {
            return 0.50
        }

        // Check for specialized models
        if name.contains("code") || name.contains("coder") {
            return 0.65 // Code-specialized often perform well on code
        }

        return 0.45
    }
    #endif

    // MARK: - Capability Inference

    private func inferCapabilities(from model: OpenRouterModel) -> Set<BenchmarkCapability> {
        var caps: Set<BenchmarkCapability> = [.textGeneration]
        let id = model.id.lowercased()

        if model.architecture?.modality?.contains("image") == true || id.contains("vision") || id.contains("4o") {
            caps.insert(.vision)
        }

        if id.contains("code") || id.contains("deepseek") || id.contains("starcoder") {
            caps.insert(.codeGeneration)
        }

        if id.contains("o1") || id.contains("opus") {
            caps.insert(.advancedReasoning)
        }

        if id.contains("sonar") || id.contains("perplexity") {
            caps.insert(.webSearch)
        }

        if model.contextLength >= 100000 {
            caps.insert(.longContext)
        }

        return caps
    }

    #if os(macOS)
    private func inferLocalCapabilities(from model: LocalModel) -> Set<BenchmarkCapability> {
        var caps: Set<BenchmarkCapability> = [.textGeneration]
        let name = model.name.lowercased()

        if name.contains("code") || name.contains("deepseek") || name.contains("coder") {
            caps.insert(.codeGeneration)
        }

        if name.contains("vision") || name.contains("llava") {
            caps.insert(.vision)
        }

        if name.contains("72b") || name.contains("70b") {
            caps.insert(.advancedReasoning)
        }

        return caps
    }
    #endif

    // MARK: - Task Suitability Scoring

    private func calculateTaskSuitability(benchmark: ModelBenchmark, taskType: TaskType) -> Double {
        var score = benchmark.qualityScore

        // Adjust based on task requirements
        switch taskType {
        case .codeGeneration, .debugging:
            if benchmark.capabilities.contains(.codeGeneration) {
                score += 0.2
            }
            // Prefer higher quality for code
            score *= benchmark.qualityScore

        case .complexReasoning, .analysis, .mathLogic:
            if benchmark.capabilities.contains(.advancedReasoning) {
                score += 0.3
            }
            // Quality is paramount
            score *= benchmark.qualityScore * 1.5

        case .simpleQA, .factual:
            // Speed matters more, quality less critical
            score = (benchmark.qualityScore * 0.5 + benchmark.speedScore * 0.5)
            // Prefer cheaper models
            if benchmark.inputCostPer1M == 0 {
                score += 0.2 // Local models get bonus
            } else if benchmark.inputCostPer1M < 1.0 {
                score += 0.1
            }

        case .summarization:
            // Context length matters
            if benchmark.capabilities.contains(.longContext) {
                score += 0.2
            }

        case .creativeWriting:
            // Quality important but not as critical as reasoning
            score = benchmark.qualityScore * 0.8 + benchmark.speedScore * 0.2

        case .research, .informationRetrieval:
            if benchmark.capabilities.contains(.webSearch) {
                score += 0.4
            }

        default:
            break
        }

        // Cost consideration (prefer local/cheaper when quality is similar)
        if benchmark.inputCostPer1M == 0 {
            score += 0.1
        }

        return min(1.0, score)
    }

    // MARK: - Helpers

    private var shouldUpdate: Bool {
        guard let lastUpdate = lastUpdateDate else { return true }
        return Date().timeIntervalSince(lastUpdate) > refreshInterval
    }

    private func normalizeModelID(_ name: String) -> String {
        // Convert HuggingFace model names to OpenRouter format
        let lowercased = name.lowercased()

        if lowercased.contains("llama") {
            return "meta-llama/\(name)"
        }
        if lowercased.contains("qwen") {
            return "qwen/\(name)"
        }
        if lowercased.contains("mistral") {
            return "mistralai/\(name)"
        }

        return name
    }

    // MARK: - Caching

    private func loadCachedBenchmarks() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(CachedBenchmarks.self, from: data) else {
            return
        }

        // Check if cache is still valid
        guard Date().timeIntervalSince(cached.timestamp) < refreshInterval else {
            return
        }

        benchmarks = cached.benchmarks
        lastUpdateDate = cached.timestamp
    }

    private func cacheBenchmarks() {
        let cached = CachedBenchmarks(benchmarks: benchmarks, timestamp: Date())
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

// MARK: - Supporting Types

/// Benchmark data for a single model
public struct ModelBenchmark: Codable, Identifiable, Sendable {
    public var id: String { modelID }

    public let modelID: String
    public let provider: String
    public let contextLength: Int
    public let inputCostPer1M: Double
    public let outputCostPer1M: Double
    public let qualityScore: Double // 0-1, based on benchmarks
    public let speedScore: Double // 0-1, based on latency
    public let capabilities: Set<BenchmarkCapability>
    public let lastUpdated: Date

    /// Total cost estimate for 1K tokens (input + output)
    public var estimatedCostPer1K: Double {
        (inputCostPer1M + outputCostPer1M) / 1000.0
    }

    /// Is this a local model (zero cost)?
    public var isLocal: Bool {
        inputCostPer1M == 0 && outputCostPer1M == 0
    }
}

/// Model capabilities
public enum BenchmarkCapability: String, Codable, Sendable {
    case textGeneration
    case codeGeneration
    case vision
    case advancedReasoning
    case webSearch
    case longContext
    case functionCalling
}

/// Cached benchmarks structure
private struct CachedBenchmarks: Codable {
    let benchmarks: [String: ModelBenchmark]
    let timestamp: Date
}

/// Model info from a specific provider
struct ProviderModelInfo {
    let id: String
    let contextLength: Int
    let inputCostPer1M: Double
    let outputCostPer1M: Double
}
