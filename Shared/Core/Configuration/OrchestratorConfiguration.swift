// OrchestratorConfiguration.swift
import Foundation

/// Configuration for the AI Orchestration Engine.
/// Controls query decomposition, model routing, and multi-agent coordination.
public struct OrchestratorConfiguration: Codable, Sendable, Equatable {

    // MARK: - Enable/Disable

    /// Master switch for orchestration features
    public var orchestratorEnabled: Bool = true

    // MARK: - Local Model Preference

    /// Preference level for local vs cloud model usage
    public var localModelPreference: LocalModelPreference = .balanced

    public enum LocalModelPreference: String, Codable, CaseIterable, Sendable {
        case always = "Always"
        case prefer = "Prefer"
        case balanced = "Balanced"
        case cloudFirst = "Cloud-First"

        public var description: String {
            switch self {
            case .always:
                return "Only use local models (fail if unavailable)"
            case .prefer:
                return "Try local first, fallback to cloud"
            case .balanced:
                return "Use local for simple tasks, cloud for complex"
            case .cloudFirst:
                return "Prefer cloud models, use local only offline"
            }
        }
    }

    // MARK: - Task Routing Rules

    /// Default model preferences for each task type
    public var taskRoutingRules: [String: [String]] = [
        "simpleQA": ["local-7b", "gpt-4o-mini"],
        "codeGeneration": ["anthropic/claude-sonnet-4", "local-code"],
        "complexReasoning": ["anthropic/claude-opus-4", "openai/o1"],
        "creativeWriting": ["anthropic/claude-sonnet-4", "openai/gpt-4o"],
        "mathLogic": ["openai/o1", "local-math"],
        "summarization": ["local-7b", "gpt-4o-mini"]
    ]

    /// Get preferred models for a task type
    public func preferredModels(for taskType: TaskType) -> [String] {
        return taskRoutingRules[taskType.rawValue] ?? []
    }

    // MARK: - Cost Management

    /// Maximum cost allowed per query (nil = unlimited)
    public var costBudgetPerQuery: Decimal? = nil

    /// When multiple models can handle a task, prefer cheaper ones
    public var preferCheaperModels: Bool = true

    // MARK: - Debug & Monitoring

    /// Show query decomposition details in UI
    public var showDecompositionDetails: Bool = false

    /// Log model routing decisions
    public var logModelRouting: Bool = true

    /// Show agent coordination details
    public var showAgentCoordination: Bool = false

    // MARK: - Execution Settings

    /// Maximum parallel agents for swarm execution
    public var maxParallelAgents: Int = 5

    /// Timeout for agent execution (seconds)
    public var agentTimeoutSeconds: TimeInterval = 120

    /// Enable retry on agent failure
    public var enableRetryOnFailure: Bool = true

    /// Maximum retry attempts
    public var maxRetryAttempts: Int = 3

    // MARK: - Advanced Settings

    /// Use AI for task classification (vs keyword-based)
    public var useAIForClassification: Bool = false

    /// Minimum confidence for AI classification (0.0-1.0)
    public var classificationConfidenceThreshold: Float = 0.7

    /// Enable result validation and verification
    public var enableResultValidation: Bool = true

    // MARK: - Persistence

    private static let storageKey = "com.thea.orchestrator.configuration"

    public static func load() -> OrchestratorConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(OrchestratorConfiguration.self, from: data) else {
            return OrchestratorConfiguration()
        }
        return config
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Convenience Methods

    /// Check if orchestrator should handle a query
    public func shouldOrchestrate(complexity: QueryComplexity) -> Bool {
        guard orchestratorEnabled else { return false }

        switch complexity {
        case .simple:
            return false // Direct execution for simple queries
        case .moderate, .complex:
            return true
        }
    }

    /// Get execution strategy based on complexity
    public func executionStrategy(for complexity: QueryComplexity) -> ExecutionStrategy {
        switch complexity {
        case .simple:
            return .direct
        case .moderate:
            return .decompose
        case .complex:
            return .deepAgent
        }
    }
}

// MARK: - Supporting Types

// Note: TaskType is defined in TaskTypes.swift to avoid duplicates

/// Query complexity levels
public enum QueryComplexity: String, Codable, Sendable {
    case simple
    case moderate
    case complex

    public var description: String {
        switch self {
        case .simple: return "Single-task, straightforward query"
        case .moderate: return "Multi-step or requires decomposition"
        case .complex: return "Complex reasoning, verification needed"
        }
    }
}

/// Execution strategies
public enum ExecutionStrategy: String, Codable, Sendable {
    case direct // Single model, direct execution
    case decompose // Query decomposition, parallel execution
    case deepAgent // Full DeepAgent with verification
}
