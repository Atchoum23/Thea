import Foundation
import Observation
import OSLog

// MARK: - Model Catalog Manager

// Fetches and caches available models from OpenRouter API

@MainActor
@Observable
final class ModelCatalogManager {
    static let shared = ModelCatalogManager()

    private(set) var models: [OpenRouterModel] = []
    private(set) var isLoading: Bool = false
    private(set) var lastFetchDate: Date?
    private(set) var fetchError: Error?

    private let logger = Logger(subsystem: "ai.thea.app", category: "ModelCatalogManager")
    private let cacheKey = "ModelCatalogManager.cachedModels"
    private let cacheExpirationSeconds: TimeInterval = 3600 // 1 hour

    private init() {
        loadCachedModels()
    }

    // MARK: - Public Methods

    func fetchModels() async {
        isLoading = true
        fetchError = nil

        do {
            let fetchedModels = try await fetchModelsFromAPI()
            models = fetchedModels
            lastFetchDate = Date()
            cacheModels(fetchedModels)
        } catch {
            print("⚠️ Failed to fetch models: \(error)")
            fetchError = error
        }

        isLoading = false
    }

    func refreshIfNeeded() async {
        guard shouldRefresh else { return }
        await fetchModels()
    }

    func getModel(byID id: String) -> OpenRouterModel? {
        models.first { $0.id == id }
    }

    func getModels(in category: ModelSelectionConfiguration.ModelCategory) -> [OpenRouterModel] {
        let config = AppConfiguration.shared.modelSelectionConfig
        let categoryModels = config.models(for: category)
        return models.filter { categoryModels.contains($0.id) }
    }

    // MARK: - Private Methods

    private func fetchModelsFromAPI() async throws -> [OpenRouterModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw CatalogError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get OpenRouter API key if available
        do {
            let apiKey = try SecureStorage.shared.loadAPIKey(for: "openrouter")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } catch {
            logger.debug("No OpenRouter API key available — fetching models without auth: \(error.localizedDescription)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw CatalogError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let catalog = try decoder.decode(OpenRouterCatalog.self, from: data)

        return catalog.data
    }

    private var shouldRefresh: Bool {
        guard let lastFetch = lastFetchDate else { return true }
        return Date().timeIntervalSince(lastFetch) > cacheExpirationSeconds
    }

    // MARK: - Caching

    private func loadCachedModels() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        let cached: CachedModels
        do {
            cached = try JSONDecoder().decode(CachedModels.self, from: data)
        } catch {
            logger.error("Failed to decode cached models: \(error.localizedDescription)")
            return
        }

        // Check if cache is still valid
        guard Date().timeIntervalSince(cached.timestamp) < cacheExpirationSeconds else {
            return
        }

        models = cached.models
        lastFetchDate = cached.timestamp
    }

    private func cacheModels(_ models: [OpenRouterModel]) {
        let cached = CachedModels(models: models, timestamp: Date())
        do {
            let data = try JSONEncoder().encode(cached)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            logger.error("Failed to encode models for caching: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Structures

struct OpenRouterCatalog: Codable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let contextLength: Int
    let pricing: OpenRouterPricing
    let topProvider: OpenRouterModelProvider?
    let architecture: OpenRouterArchitecture?

    var displayName: String {
        // Extract model name from ID (e.g., "openai/gpt-4o" -> "GPT-4o")
        let components = id.split(separator: "/")
        guard let modelName = components.last else { return name }
        return String(modelName)
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var providerName: String {
        // Extract provider from ID (e.g., "openai/gpt-4o" -> "OpenAI")
        let components = id.split(separator: "/")
        guard let provider = components.first else { return "Unknown" }
        return String(provider).capitalized
    }

    var formattedContextLength: String {
        if contextLength >= 1_000_000 {
            "\(contextLength / 1_000_000)M tokens"
        } else if contextLength >= 1000 {
            "\(contextLength / 1000)K tokens"
        } else {
            "\(contextLength) tokens"
        }
    }
}

struct OpenRouterPricing: Codable, Sendable {
    let prompt: String
    let completion: String

    var promptPrice: Double {
        Double(prompt) ?? 0
    }

    var completionPrice: Double {
        Double(completion) ?? 0
    }

    var formattedPromptPrice: String {
        let price = promptPrice * 1_000_000
        return "$\(String(format: "%.2f", price))/1M"
    }

    var formattedCompletionPrice: String {
        let price = completionPrice * 1_000_000
        return "$\(String(format: "%.2f", price))/1M"
    }
}

struct OpenRouterModelProvider: Codable, Sendable {
    let maxCompletionTokens: Int?
    let isModerated: Bool?
}

struct OpenRouterArchitecture: Codable, Sendable {
    let modality: String?
    let tokenizer: String?
    let instructType: String?
}

struct CachedModels: Codable {
    let models: [OpenRouterModel]
    let timestamp: Date
}

// MARK: - Errors

enum CatalogError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid API URL"
        case .invalidResponse:
            "Invalid response from server"
        case let .httpError(code):
            "HTTP error: \(code)"
        case .decodingError:
            "Failed to decode response"
        }
    }
}
