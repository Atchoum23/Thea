// DynamicModelRegistry.swift
// Thea
//
// Fetches and caches model metadata from provider APIs for dynamic routing.
// Refreshes daily and falls back to cached data when offline.

import Foundation
import os

@MainActor
final class DynamicModelRegistry: ObservableObject {
    static let shared = DynamicModelRegistry()

    @Published private(set) var availableModels: [AIModel] = AIModel.allKnownModels
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing = false

    private let logger = Logger(subsystem: "app.thea", category: "DynamicModelRegistry")
    private let cacheURL: URL
    private let refreshInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheURL = cacheDir.appendingPathComponent("thea_model_registry.json")

        // Load cached models on init
        loadCache()
    }

    // MARK: - Public API

    /// Refresh model metadata from online sources if stale.
    /// Called at app launch and periodically.
    func refreshIfNeeded() async {
        guard !isRefreshing else { return }

        if let last = lastRefresh, Date().timeIntervalSince(last) < refreshInterval {
            return // Still fresh
        }

        await refresh()
    }

    /// Force refresh model metadata from all available provider APIs.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        logger.info("Starting dynamic model registry refresh")

        var fetchedModels: [AIModel] = []

        // Fetch from OpenRouter (aggregates many providers)
        if let openRouterKey = SettingsManager.shared.getAPIKey(for: "openrouter"),
           !openRouterKey.isEmpty
        {
            do {
                let models = try await fetchOpenRouterModels(apiKey: openRouterKey)
                fetchedModels.append(contentsOf: models)
                logger.info("Fetched \(models.count) models from OpenRouter")
            } catch {
                logger.warning("OpenRouter fetch failed: \(error.localizedDescription)")
            }
        }

        // Merge: fetched models update pricing/capabilities, static models fill gaps
        let merged = mergeModels(fetched: fetchedModels, existing: AIModel.allKnownModels)
        availableModels = merged
        lastRefresh = Date()

        // Cache to disk
        saveCache(merged)

        // Update ModelRouter with fresh data (macOS only — ModelRouter excluded from iOS)
        #if os(macOS)
        ModelRouter.shared.updateAvailableModels(merged)
        #endif

        logger.info("Model registry refreshed: \(merged.count) models available")
    }

    // MARK: - OpenRouter Fetch

    private func fetchOpenRouterModels(apiKey: String) async throws -> [AIModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw RegistryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw RegistryError.fetchFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]]
        else {
            throw RegistryError.parseError
        }

        return modelsData.compactMap { parseOpenRouterModel($0) }
    }

    private func parseOpenRouterModel(_ data: [String: Any]) -> AIModel? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String
        else { return nil }

        let contextWindow = data["context_length"] as? Int ?? 128_000
        let pricing = data["pricing"] as? [String: Any]
        let inputPrice = (pricing?["prompt"] as? String)
            .flatMap { Double($0) }
            .map { Decimal($0 * 1000) } // Convert per-token to per-1K
        let outputPrice = (pricing?["completion"] as? String)
            .flatMap { Double($0) }
            .map { Decimal($0 * 1000) }

        let provider = detectProvider(from: id)
        let capabilities = detectCapabilities(from: id, data: data)
        let supportsVision = id.contains("vision") || id.contains("gpt-4o") || id.contains("claude")
            || (data["architecture"] as? [String: Any])?["modality"] as? String == "multimodal"
        let supportsFunctions = capabilities.contains(.functionCalling)

        let topProvider = (data["top_provider"] as? [String: Any])
        let maxOutputTokens = topProvider?["max_completion_tokens"] as? Int ?? 16_384

        return AIModel(
            id: id,
            name: name,
            provider: provider,
            description: data["description"] as? String,
            contextWindow: contextWindow,
            maxOutputTokens: maxOutputTokens,
            capabilities: capabilities,
            inputCostPer1K: inputPrice,
            outputCostPer1K: outputPrice,
            supportsStreaming: true,
            supportsVision: supportsVision,
            supportsFunctionCalling: supportsFunctions
        )
    }

    private func detectProvider(from modelID: String) -> String {
        if modelID.hasPrefix("anthropic/") || modelID.contains("claude") {
            return "anthropic"
        } else if modelID.hasPrefix("openai/") || modelID.contains("gpt") || modelID.contains("o1") {
            return "openai"
        } else if modelID.hasPrefix("google/") || modelID.contains("gemini") {
            return "google"
        } else if modelID.hasPrefix("deepseek/") || modelID.contains("deepseek") {
            return "deepseek"
        } else if modelID.hasPrefix("meta-llama/") || modelID.contains("llama") {
            return "groq"
        } else if modelID.hasPrefix("perplexity/") {
            return "perplexity"
        }
        return "openrouter"
    }

    private func detectCapabilities(from modelID: String, data: [String: Any]) -> [ModelCapability] {
        var caps: [ModelCapability] = [.chat]
        let id = modelID.lowercased()

        if id.contains("code") || id.contains("codestral") || id.contains("deepseek-coder") {
            caps.append(.codeGeneration)
        }
        if id.contains("vision") || id.contains("gpt-4o") || id.contains("claude") || id.contains("gemini") {
            caps.append(.vision)
        }
        if id.contains("o1") || id.contains("reasoning") || id.contains("r1") || id.contains("opus") {
            caps.append(.reasoning)
        }
        if id.contains("search") || id.contains("sonar") || id.contains("perplexity") {
            caps.append(.search)
        }
        // Function calling for major models
        if id.contains("claude") || id.contains("gpt-4") || id.contains("gemini") || id.contains("deepseek") {
            caps.append(.functionCalling)
        }

        return Array(Set(caps))
    }

    // MARK: - Merge

    /// Merge fetched models with existing static models.
    /// Fetched models update pricing/capabilities; static models fill in
    /// any models not available via API.
    private func mergeModels(fetched: [AIModel], existing: [AIModel]) -> [AIModel] {
        var modelsByID: [String: AIModel] = [:]

        // Start with static models
        for model in existing {
            modelsByID[model.id] = model
        }

        // Override with fetched models (fresher pricing/capabilities)
        for model in fetched {
            // For OpenRouter models with provider prefix, also check without prefix
            let baseID = model.id.components(separatedBy: "/").last ?? model.id
            if modelsByID[baseID] != nil {
                // Update existing model with fresh pricing but keep static capabilities
                let existingModel = modelsByID[baseID]
                modelsByID[baseID] = AIModel(
                    id: existingModel?.id ?? model.id,
                    name: existingModel?.name ?? model.name,
                    provider: existingModel?.provider ?? model.provider,
                    description: model.description ?? existingModel?.description,
                    contextWindow: model.contextWindow,
                    maxOutputTokens: model.maxOutputTokens,
                    capabilities: existingModel?.capabilities ?? model.capabilities,
                    inputCostPer1K: model.inputCostPer1K ?? existingModel?.inputCostPer1K,
                    outputCostPer1K: model.outputCostPer1K ?? existingModel?.outputCostPer1K,
                    isLocal: existingModel?.isLocal ?? false,
                    supportsStreaming: model.supportsStreaming,
                    supportsVision: existingModel?.supportsVision ?? model.supportsVision,
                    supportsFunctionCalling: existingModel?.supportsFunctionCalling ?? model.supportsFunctionCalling
                )
            } else {
                // New model not in static list — add it
                modelsByID[model.id] = model
            }
        }

        return Array(modelsByID.values).sorted { $0.name < $1.name }
    }

    // MARK: - Cache

    private func saveCache(_ models: [AIModel]) {
        do {
            let cacheData = CachedModels(models: models, timestamp: Date())
            let data = try JSONEncoder().encode(cacheData)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            logger.warning("Failed to save model cache: \(error.localizedDescription)")
        }
    }

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }

        do {
            let data = try Data(contentsOf: cacheURL)
            let cached = try JSONDecoder().decode(CachedModels.self, from: data)

            // Only use cache if less than 7 days old
            if Date().timeIntervalSince(cached.timestamp) < 7 * 24 * 60 * 60 {
                availableModels = cached.models
                lastRefresh = cached.timestamp
                logger.info("Loaded \(cached.models.count) models from cache (age: \(Int(Date().timeIntervalSince(cached.timestamp) / 3600))h)")
            }
        } catch {
            logger.warning("Failed to load model cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Types

    private struct CachedModels: Codable {
        let models: [AIModel]
        let timestamp: Date
    }

    enum RegistryError: Error {
        case invalidURL
        case fetchFailed
        case parseError
    }
}
