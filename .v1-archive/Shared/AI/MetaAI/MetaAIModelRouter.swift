// MetaAIModelRouter.swift
// Thea - MetaAI
//
// Routes tasks to optimal AI models based on task type, preferences, and availability.
// For advanced routing with learning, use Intelligence/Routing/ModelRouter.

import Foundation

/// Routes tasks to optimal AI models based on task type, preferences, and availability.
/// Implements local model preference with cloud fallback logic.
@MainActor
@Observable
public final class MetaAIModelRouter {
    public static let shared = MetaAIModelRouter()

    private let config = OrchestratorConfiguration.load()
    private let providerRegistry = ProviderRegistry.shared
    private let localModelManager = LocalModelManager.shared

    private init() {}

    // MARK: - Public API

    /// Select the best model for a given task
    public func selectModel(
        for classification: MetaAIClassificationResult,
        preference: OrchestratorConfiguration.LocalModelPreference? = nil
    ) async throws -> MetaAIModelSelection {
        let effectivePreference = preference ?? config.localModelPreference

        // 1. Get candidate models from routing rules
        let candidates = getCandidateModels(for: classification.primaryType)

        guard !candidates.isEmpty else {
            // Fallback to default models if no routing rule exists
            return try await selectDefaultModel(for: classification.primaryType)
        }

        // 2. Filter candidates by availability
        let available = await filterAvailableModels(candidates)

        guard !available.isEmpty else {
            throw MetaAIModelRoutingError.noModelsAvailable(taskType: classification.primaryType)
        }

        // 3. Apply local model preference logic
        let selected = try await applyPreference(
            available,
            preference: effectivePreference,
            taskType: classification.primaryType
        )

        if config.logModelRouting {
            print("[MetaAIModelRouter] Selected \(selected.modelID) for \(classification.primaryType.displayName)")
            print("[MetaAIModelRouter] Reasoning: \(selected.reasoning)")
        }

        return selected
    }

    /// Check if a specific model is available
    public func isModelAvailable(_ modelID: String) async -> Bool {
        // Check local models - support generic patterns like "local-7b" or specific names like "local-qwen2.5"
        if modelID.hasPrefix("local-") {
            let localSuffix = String(modelID.dropFirst(6)) // Remove "local-" prefix
            let models = localModelManager.availableModels

            // No local models available
            guard !models.isEmpty else { return false }

            // First try exact match
            if models.contains(where: { $0.name == localSuffix }) {
                return true
            }

            // Handle generic patterns
            let pattern = localSuffix.lowercased()
            switch pattern {
            case "any", "default":
                return true // Any local model will work

            case "large":
                // Check if we have a large model (>30B parameters)
                return models.contains { extractModelSize($0.name) > 30 }

            case "7b", "8b":
                // Check if we have a model in the 6-10B range
                return models.contains { size in
                    let s = extractModelSize(size.name)
                    return s >= 6 && s <= 10
                }

            case "code":
                // Check for code-specialized models
                return models.contains {
                    $0.name.lowercased().contains("code") ||
                    $0.name.lowercased().contains("deepseek") ||
                    $0.name.lowercased().contains("coder")
                } || !models.isEmpty // Fallback to any model

            case "math":
                // Check for math-specialized models
                return models.contains {
                    $0.name.lowercased().contains("math") ||
                    $0.name.lowercased().contains("qwen")
                } || !models.isEmpty // Fallback to any model

            default:
                // Try pattern matching
                return models.contains { $0.name.lowercased().contains(pattern) } || !models.isEmpty
            }
        }

        // Check cloud providers
        let parts = modelID.split(separator: "/")
        guard parts.count == 2 else { return false }

        let providerID = String(parts[0])
        return providerRegistry.availableProviders.contains { $0.id == providerID && $0.isConfigured }
    }

    /// Get an actual local model name for a generic pattern
    /// Supports patterns: local-any, local-7b, local-8b, local-large, local-code, local-math
    public func resolveLocalModel(_ pattern: String) -> String? {
        let suffix = pattern.hasPrefix("local-") ? String(pattern.dropFirst(6)) : pattern
        let lowercased = suffix.lowercased()

        let models = localModelManager.availableModels

        // First try exact match
        if let exact = models.first(where: { $0.name == suffix }) {
            return exact.name
        }

        // Then try pattern matching
        if let match = models.first(where: { $0.name.lowercased().contains(lowercased) }) {
            return match.name
        }

        // Handle generic patterns with intelligent model selection
        switch lowercased {
        case "any", "default":
            // Return any available model, preferring smaller ones for efficiency
            return models.sorted { extractModelSize($0.name) < extractModelSize($1.name) }.first?.name

        case "large":
            // Return the largest model (72B, 70B, etc.) for complex tasks
            return models.sorted { extractModelSize($0.name) > extractModelSize($1.name) }.first?.name

        case "7b":
            // Find a ~7B model
            return models.first { name in
                let size = extractModelSize(name.name)
                return size >= 6 && size <= 8
            }?.name ?? models.first?.name

        case "8b":
            // Find a ~8B model
            return models.first { name in
                let size = extractModelSize(name.name)
                return size >= 7 && size <= 10
            }?.name ?? models.first?.name

        case "code":
            // Prefer models with "code" in name, or DeepSeek, or Qwen
            return models.first {
                $0.name.lowercased().contains("code") ||
                $0.name.lowercased().contains("deepseek") ||
                $0.name.lowercased().contains("coder")
            }?.name ?? models.first?.name

        case "math":
            // Prefer models with "math" in name, or Qwen (good at math)
            return models.first {
                $0.name.lowercased().contains("math") ||
                $0.name.lowercased().contains("qwen")
            }?.name ?? models.first?.name

        default:
            // Try to find a model containing the pattern
            return models.first { $0.name.lowercased().contains(lowercased) }?.name ?? models.first?.name
        }
    }

    /// Extract model size in billions from model name (e.g., "Qwen2.5-72B" -> 72)
    private func extractModelSize(_ name: String) -> Double {
        let patterns = ["(\\d+\\.?\\d*)b", "(\\d+\\.?\\d*)B"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
               let range = Range(match.range(at: 1), in: name),
               let size = Double(name[range]) {
                return size
            }
        }
        return 0 // Unknown size
    }

    /// Get estimated cost for using a model
    public func estimatedCost(for modelID: String, tokens: Int) -> Decimal {
        // Simplified cost estimation
        // TODO: Implement actual cost calculation based on model pricing

        if modelID.hasPrefix("local-") {
            return 0.0 // Local models are free
        }

        // Rough estimates (USD per 1M tokens)
        let costPer1M: Decimal = if modelID.contains("gpt-4o-mini") || modelID.contains("gemini-flash") {
            0.15 // Cheap models
        } else if modelID.contains("opus") || modelID.contains("o1") {
            15.0 // Premium models
        } else {
            3.0 // Mid-tier models
        }

        return costPer1M * Decimal(tokens) / 1_000_000
    }

    // MARK: - Candidate Selection

    private func getCandidateModels(for taskType: TaskType) -> [String] {
        config.preferredModels(for: taskType)
    }

    private func selectDefaultModel(for taskType: TaskType) async throws -> MetaAIModelSelection {
        // Fallback logic when no routing rule exists
        let defaultModel = switch taskType {
        case .simpleQA, .factual, .summarization:
            "openai/gpt-4o-mini"
        case .codeGeneration, .debugging:
            "anthropic/claude-sonnet-4"
        case .complexReasoning, .analysis, .planning:
            "anthropic/claude-opus-4"
        case .creativeWriting:
            "anthropic/claude-sonnet-4"
        case .mathLogic:
            "openai/o1"
        default:
            "anthropic/claude-sonnet-4"
        }

        // Check if default model is available
        if await isModelAvailable(defaultModel) {
            return MetaAIModelSelection(
                modelID: defaultModel,
                providerID: defaultModel.split(separator: "/").first.map(String.init) ?? "unknown",
                isLocal: false,
                estimatedCost: estimatedCost(for: defaultModel, tokens: 1000),
                reasoning: "Default model for \(taskType.displayName)"
            )
        }

        throw MetaAIModelRoutingError.noModelsAvailable(taskType: taskType)
    }

    // MARK: - Availability Filtering

    private func filterAvailableModels(_ candidates: [String]) async -> [String] {
        var available: [String] = []

        for modelID in candidates {
            if await isModelAvailable(modelID) {
                available.append(modelID)
            }
        }

        return available
    }

    // MARK: - Preference Logic

    private func applyPreference(
        _ models: [String],
        preference: OrchestratorConfiguration.LocalModelPreference,
        taskType: TaskType
    ) async throws -> MetaAIModelSelection {
        let localModels = models.filter { $0.hasPrefix("local-") }
        let cloudModels = models.filter { !$0.hasPrefix("local-") }

        switch preference {
        case .always:
            // Only use local models
            guard let localModel = localModels.first else {
                throw MetaAIModelRoutingError.localModelRequired(taskType: taskType)
            }
            return createSelection(for: localModel, reasoning: "Local-only preference")

        case .prefer:
            // Try local first, fallback to cloud
            if let localModel = localModels.first {
                return createSelection(for: localModel, reasoning: "Local model preferred")
            }
            guard let cloudModel = cloudModels.first else {
                throw MetaAIModelRoutingError.noModelsAvailable(taskType: taskType)
            }
            return createSelection(for: cloudModel, reasoning: "Local unavailable, using cloud fallback")

        case .balanced:
            // Use local for simple tasks, cloud for complex
            if taskType == .simpleQA || taskType == .summarization || taskType == .factual {
                if let localModel = localModels.first {
                    return createSelection(for: localModel, reasoning: "Simple task, using local model")
                }
            }
            guard let cloudModel = cloudModels.first else {
                guard let localModel = localModels.first else {
                    throw MetaAIModelRoutingError.noModelsAvailable(taskType: taskType)
                }
                return createSelection(for: localModel, reasoning: "Cloud unavailable, using local fallback")
            }
            return createSelection(for: cloudModel, reasoning: "Balanced preference: cloud for quality")

        case .cloudFirst:
            // Prefer cloud, use local only if cloud unavailable
            if let cloudModel = cloudModels.first {
                return createSelection(for: cloudModel, reasoning: "Cloud-first preference")
            }
            guard let localModel = localModels.first else {
                throw MetaAIModelRoutingError.noModelsAvailable(taskType: taskType)
            }
            return createSelection(for: localModel, reasoning: "Cloud unavailable, using local fallback")
        }
    }

    private func createSelection(for modelID: String, reasoning: String) -> MetaAIModelSelection {
        let isLocal = modelID.hasPrefix("local-")

        // For local models, resolve the pattern to an actual model name
        let resolvedModelID: String
        if isLocal {
            if let actualName = resolveLocalModel(modelID) {
                resolvedModelID = "local-\(actualName)"
            } else {
                resolvedModelID = modelID
            }
        } else {
            resolvedModelID = modelID
        }

        let providerID: String = if isLocal {
            "local"
        } else {
            resolvedModelID.split(separator: "/").first.map(String.init) ?? "unknown"
        }

        let cost = estimatedCost(for: resolvedModelID, tokens: 1000)

        return MetaAIModelSelection(
            modelID: resolvedModelID,
            providerID: providerID,
            isLocal: isLocal,
            estimatedCost: cost,
            reasoning: reasoning
        )
    }

    // MARK: - Cost Optimization

    /// Select cheapest available model that can handle the task
    public func selectCheapestModel(for classification: MetaAIClassificationResult) async throws -> MetaAIModelSelection {
        let candidates = getCandidateModels(for: classification.primaryType)
        let available = await filterAvailableModels(candidates)

        guard !available.isEmpty else {
            throw MetaAIModelRoutingError.noModelsAvailable(taskType: classification.primaryType)
        }

        // Sort by estimated cost (local models first, then cloud by cost)
        let sorted = available.sorted { model1, model2 in
            let cost1 = estimatedCost(for: model1, tokens: 1000)
            let cost2 = estimatedCost(for: model2, tokens: 1000)
            return cost1 < cost2
        }

        guard let cheapest = sorted.first else {
            throw MetaAIModelRoutingError.noModelsAvailable(taskType: classification.primaryType)
        }

        return createSelection(for: cheapest, reasoning: "Cheapest available model")
    }
}

// MARK: - MetaAI Model Selection

/// Result of MetaAI model selection
public struct MetaAIModelSelection: Sendable {
    public let modelID: String
    public let providerID: String
    public let isLocal: Bool
    public let estimatedCost: Decimal
    public let reasoning: String

    public init(
        modelID: String,
        providerID: String,
        isLocal: Bool,
        estimatedCost: Decimal,
        reasoning: String
    ) {
        self.modelID = modelID
        self.providerID = providerID
        self.isLocal = isLocal
        self.estimatedCost = estimatedCost
        self.reasoning = reasoning
    }

    /// Display name for UI
    public var displayName: String {
        if isLocal {
            return modelID.replacingOccurrences(of: "local-", with: "Local: ")
        }
        return modelID
    }

    /// Check if within cost budget
    public func isWithinBudget(_ budget: Decimal?) -> Bool {
        guard let budget else { return true }
        return estimatedCost <= budget
    }

    /// Convert to standard ModelSelection for compatibility
    public func toModelSelection() -> ModelSelection {
        ModelSelection(
            modelID: modelID,
            providerID: providerID,
            reasoning: reasoning,
            isLocal: isLocal,
            estimatedCost: Double(truncating: estimatedCost as NSNumber)
        )
    }
}

// MARK: - MetaAI Model Routing Errors

/// MetaAI model routing errors
public enum MetaAIModelRoutingError: Error, LocalizedError {
    case noModelsAvailable(taskType: TaskType)
    case localModelRequired(taskType: TaskType)
    case exceedsCostBudget(cost: Decimal, budget: Decimal)
    case modelNotFound(modelID: String)

    public var errorDescription: String? {
        switch self {
        case let .noModelsAvailable(taskType):
            "No models available for task type: \(taskType.displayName)"
        case let .localModelRequired(taskType):
            "Local model required for \(taskType.displayName) but none available"
        case let .exceedsCostBudget(cost, budget):
            "Estimated cost (\(cost)) exceeds budget (\(budget))"
        case let .modelNotFound(modelID):
            "Model not found: \(modelID)"
        }
    }
}
