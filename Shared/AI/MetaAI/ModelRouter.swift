// ModelRouter.swift
import Foundation

/// Routes tasks to optimal AI models based on task type, preferences, and availability.
/// Implements local model preference with cloud fallback logic.
@MainActor
@Observable
public final class ModelRouter {
    public static let shared = ModelRouter()

    private let config = OrchestratorConfiguration.load()
    private let providerRegistry = ProviderRegistry.shared
    private let localModelManager = LocalModelManager.shared

    private init() {}

    // MARK: - Public API

    /// Select the best model for a given task
    public func selectModel(
        for classification: TaskClassification,
        preference: OrchestratorConfiguration.LocalModelPreference? = nil
    ) async throws -> ModelSelection {
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
            throw ModelRoutingError.noModelsAvailable(taskType: classification.primaryType)
        }

        // 3. Apply local model preference logic
        let selected = try await applyPreference(
            available,
            preference: effectivePreference,
            taskType: classification.primaryType
        )

        if config.logModelRouting {
            print("[ModelRouter] Selected \(selected.modelID) for \(classification.primaryType.displayName)")
            print("[ModelRouter] Reasoning: \(selected.reasoning)")
        }

        return selected
    }

    /// Check if a specific model is available
    public func isModelAvailable(_ modelID: String) async -> Bool {
        // Check local models
        if modelID.hasPrefix("local-") {
            let localName = String(modelID.dropFirst(6)) // Remove "local-" prefix
            return localModelManager.availableModels.contains { $0.name == localName }
        }

        // Check cloud providers
        let parts = modelID.split(separator: "/")
        guard parts.count == 2 else { return false }

        let providerID = String(parts[0])
        return providerRegistry.availableProviders.contains { $0.id == providerID && $0.isConfigured }
    }

    /// Get estimated cost for using a model
    public func estimatedCost(for modelID: String, tokens: Int) -> Decimal {
        // Simplified cost estimation
        // TODO: Implement actual cost calculation based on model pricing

        if modelID.hasPrefix("local-") {
            return 0.0 // Local models are free
        }

        // Rough estimates (USD per 1M tokens)
        let costPer1M: Decimal
        if modelID.contains("gpt-4o-mini") || modelID.contains("gemini-flash") {
            costPer1M = 0.15 // Cheap models
        } else if modelID.contains("opus") || modelID.contains("o1") {
            costPer1M = 15.0 // Premium models
        } else {
            costPer1M = 3.0 // Mid-tier models
        }

        return costPer1M * Decimal(tokens) / 1_000_000
    }

    // MARK: - Candidate Selection

    private func getCandidateModels(for taskType: TaskType) -> [String] {
        return config.preferredModels(for: taskType)
    }

    private func selectDefaultModel(for taskType: TaskType) async throws -> ModelSelection {
        // Fallback logic when no routing rule exists
        let defaultModel: String

        switch taskType {
        case .simpleQA, .factual, .summarization:
            defaultModel = "openai/gpt-4o-mini"
        case .codeGeneration, .debugging:
            defaultModel = "anthropic/claude-sonnet-4"
        case .complexReasoning, .analysis, .planning:
            defaultModel = "anthropic/claude-opus-4"
        case .creativeWriting:
            defaultModel = "anthropic/claude-sonnet-4"
        case .mathLogic:
            defaultModel = "openai/o1"
        default:
            defaultModel = "anthropic/claude-sonnet-4"
        }

        // Check if default model is available
        if await isModelAvailable(defaultModel) {
            return ModelSelection(
                modelID: defaultModel,
                providerID: defaultModel.split(separator: "/").first.map(String.init) ?? "unknown",
                isLocal: false,
                estimatedCost: estimatedCost(for: defaultModel, tokens: 1000),
                reasoning: "Default model for \(taskType.displayName)"
            )
        }

        throw ModelRoutingError.noModelsAvailable(taskType: taskType)
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
    ) async throws -> ModelSelection {
        let localModels = models.filter { $0.hasPrefix("local-") }
        let cloudModels = models.filter { !$0.hasPrefix("local-") }

        switch preference {
        case .always:
            // Only use local models
            guard let localModel = localModels.first else {
                throw ModelRoutingError.localModelRequired(taskType: taskType)
            }
            return createSelection(for: localModel, reasoning: "Local-only preference")

        case .prefer:
            // Try local first, fallback to cloud
            if let localModel = localModels.first {
                return createSelection(for: localModel, reasoning: "Local model preferred")
            }
            guard let cloudModel = cloudModels.first else {
                throw ModelRoutingError.noModelsAvailable(taskType: taskType)
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
                    throw ModelRoutingError.noModelsAvailable(taskType: taskType)
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
                throw ModelRoutingError.noModelsAvailable(taskType: taskType)
            }
            return createSelection(for: localModel, reasoning: "Cloud unavailable, using local fallback")
        }
    }

    private func createSelection(for modelID: String, reasoning: String) -> ModelSelection {
        let isLocal = modelID.hasPrefix("local-")
        let providerID: String

        if isLocal {
            providerID = "local"
        } else {
            providerID = modelID.split(separator: "/").first.map(String.init) ?? "unknown"
        }

        let cost = estimatedCost(for: modelID, tokens: 1000)

        return ModelSelection(
            modelID: modelID,
            providerID: providerID,
            isLocal: isLocal,
            estimatedCost: cost,
            reasoning: reasoning
        )
    }

    // MARK: - Cost Optimization

    /// Select cheapest available model that can handle the task
    public func selectCheapestModel(for classification: TaskClassification) async throws -> ModelSelection {
        let candidates = getCandidateModels(for: classification.primaryType)
        let available = await filterAvailableModels(candidates)

        guard !available.isEmpty else {
            throw ModelRoutingError.noModelsAvailable(taskType: classification.primaryType)
        }

        // Sort by estimated cost (local models first, then cloud by cost)
        let sorted = available.sorted { model1, model2 in
            let cost1 = estimatedCost(for: model1, tokens: 1000)
            let cost2 = estimatedCost(for: model2, tokens: 1000)
            return cost1 < cost2
        }

        guard let cheapest = sorted.first else {
            throw ModelRoutingError.noModelsAvailable(taskType: classification.primaryType)
        }

        return createSelection(for: cheapest, reasoning: "Cheapest available model")
    }
}

// MARK: - Supporting Types

/// Result of model selection
public struct ModelSelection: Sendable {
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
        guard let budget = budget else { return true }
        return estimatedCost <= budget
    }
}

/// Model routing errors
public enum ModelRoutingError: Error, LocalizedError {
    case noModelsAvailable(taskType: TaskType)
    case localModelRequired(taskType: TaskType)
    case exceedsCostBudget(cost: Decimal, budget: Decimal)
    case modelNotFound(modelID: String)

    public var errorDescription: String? {
        switch self {
        case .noModelsAvailable(let taskType):
            return "No models available for task type: \(taskType.displayName)"
        case .localModelRequired(let taskType):
            return "Local model required for \(taskType.displayName) but none available"
        case .exceedsCostBudget(let cost, let budget):
            return "Estimated cost (\(cost)) exceeds budget (\(budget))"
        case .modelNotFound(let modelID):
            return "Model not found: \(modelID)"
        }
    }
}
