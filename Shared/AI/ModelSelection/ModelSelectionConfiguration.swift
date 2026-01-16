import Foundation

// MARK: - Model Selection Configuration
// Defines model categories, presets, and selection criteria

struct ModelSelectionConfiguration: Codable, Sendable, Equatable {
    // MARK: - Model Categories

    var fastModels: [String] = [
        "openai/gpt-4o-mini",
        "anthropic/claude-3-haiku",
        "google/gemini-flash-1.5",
        "meta-llama/llama-3.1-8b-instruct"
    ]

    var balancedModels: [String] = [
        "openai/gpt-4o",
        "anthropic/claude-3-5-sonnet",
        "google/gemini-pro-1.5",
        "meta-llama/llama-3.1-70b-instruct"
    ]

    var powerfulModels: [String] = [
        "openai/o1",
        "anthropic/claude-3-5-opus",
        "google/gemini-pro-1.5-exp",
        "meta-llama/llama-3.1-405b-instruct"
    ]

    var codeModels: [String] = [
        "anthropic/claude-3-5-sonnet",
        "openai/gpt-4o",
        "deepseek/deepseek-coder",
        "qwen/qwen-2.5-coder-32b-instruct"
    ]

    // MARK: - Selection Criteria

    var preferredCategory: ModelCategory = .balanced
    var selectedModelID: String?

    // MARK: - Category Helper

    enum ModelCategory: String, Codable, CaseIterable, Sendable {
        case fast = "Fast"
        case balanced = "Balanced"
        case powerful = "Powerful"
        case code = "Code"

        var icon: String {
            switch self {
            case .fast: return "hare"
            case .balanced: return "scale.3d"
            case .powerful: return "crown"
            case .code: return "chevron.left.forwardslash.chevron.right"
            }
        }

        var description: String {
            switch self {
            case .fast:
                return "Quick responses, lower cost"
            case .balanced:
                return "Good balance of speed and quality"
            case .powerful:
                return "Best quality, higher cost"
            case .code:
                return "Optimized for code generation"
            }
        }
    }

    // MARK: - Model Access

    func models(for category: ModelCategory) -> [String] {
        switch category {
        case .fast: return fastModels
        case .balanced: return balancedModels
        case .powerful: return powerfulModels
        case .code: return codeModels
        }
    }

    func category(for modelID: String) -> ModelCategory? {
        if fastModels.contains(modelID) { return .fast }
        if balancedModels.contains(modelID) { return .balanced }
        if powerfulModels.contains(modelID) { return .powerful }
        if codeModels.contains(modelID) { return .code }
        return nil
    }

    var allModels: [String] {
        var all: [String] = []
        all.append(contentsOf: fastModels)
        all.append(contentsOf: balancedModels)
        all.append(contentsOf: powerfulModels)
        all.append(contentsOf: codeModels)
        return Array(Set(all)).sorted()
    }
}

// MARK: - Model Information

struct ModelInfo: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let provider: String
    let description: String
    let contextWindow: Int
    let pricing: ModelPricing?
    let capabilities: ModelCapabilities

    var displayName: String {
        name.components(separatedBy: "/").last ?? name
    }

    var providerName: String {
        provider.capitalized
    }
}

struct ModelPricing: Codable, Sendable, Equatable {
    let promptTokenPrice: Double  // Per million tokens
    let completionTokenPrice: Double  // Per million tokens

    var formattedPromptPrice: String {
        "$\(String(format: "%.2f", promptTokenPrice))/1M tokens"
    }

    var formattedCompletionPrice: String {
        "$\(String(format: "%.2f", completionTokenPrice))/1M tokens"
    }
}

struct ModelCapabilities: Codable, Sendable, Equatable {
    var supportsVision: Bool = false
    var supportsAudio: Bool = false
    var supportsFunctionCalling: Bool = true
    var supportsStreaming: Bool = true
    var supportsSystemMessages: Bool = true
}

// MARK: - Model Extensions

extension AppConfiguration {
    var modelSelectionConfig: ModelSelectionConfiguration {
        get {
            if let data = UserDefaults.standard.data(forKey: "AppConfiguration.modelSelectionConfig"),
               let config = try? JSONDecoder().decode(ModelSelectionConfiguration.self, from: data) {
                return config
            }
            return ModelSelectionConfiguration()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "AppConfiguration.modelSelectionConfig")
            }
        }
    }
}
