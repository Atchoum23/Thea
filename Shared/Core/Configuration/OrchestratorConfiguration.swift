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
                "Only use local models (fail if unavailable)"
            case .prefer:
                "Try local first, fallback to cloud"
            case .balanced:
                "Use local for simple tasks, cloud for complex"
            case .cloudFirst:
                "Prefer cloud models, use local only offline"
            }
        }
    }

    // MARK: - Task Routing Rules

    /// Default model preferences for each task type
    /// Format: TaskType.rawValue -> [ordered list of model preferences]
    /// - "local-*" patterns: local-7b, local-8b, local-large (72B+), local-any
    /// - Cloud models: "provider/model-name"
    public var taskRoutingRules: [String: [String]] = [
        // Simple tasks - prefer local, fallback to cheap cloud
        "simpleQA": ["local-any", "openai/gpt-4o-mini", "google/gemini-flash-1.5"],
        "factual": ["local-any", "openai/gpt-4o-mini", "google/gemini-flash-1.5"],
        "summarization": ["local-any", "openai/gpt-4o-mini", "anthropic/claude-3-haiku"],

        // Code tasks - prefer powerful models
        "codeGeneration": ["anthropic/claude-sonnet-4", "openai/gpt-4o", "local-large"],
        "debugging": ["anthropic/claude-sonnet-4", "openai/gpt-4o", "local-large"],

        // Complex reasoning - use most capable models
        "complexReasoning": ["anthropic/claude-opus-4", "openai/o1", "openai/gpt-4o"],
        "analysis": ["anthropic/claude-opus-4", "openai/gpt-4o", "local-large"],
        "planning": ["anthropic/claude-sonnet-4", "openai/gpt-4o", "local-large"],

        // Math and logic - specialized models
        "mathLogic": ["openai/o1", "anthropic/claude-opus-4", "local-large"],

        // Creative tasks - balanced approach
        "creativeWriting": ["anthropic/claude-sonnet-4", "openai/gpt-4o", "local-any"],

        // Research tasks
        "research": ["anthropic/claude-opus-4", "openai/gpt-4o", "perplexity/llama-3.1-sonar-large-128k-online"],
        "informationRetrieval": ["local-any", "openai/gpt-4o-mini", "perplexity/llama-3.1-sonar-small-128k-online"],

        // Content creation
        "contentCreation": ["anthropic/claude-sonnet-4", "openai/gpt-4o", "local-large"],

        // General/default - balanced
        "general": ["local-any", "anthropic/claude-sonnet-4", "openai/gpt-4o-mini"]
    ]

    /// Get preferred models for a task type
    public func preferredModels(for taskType: TaskType) -> [String] {
        taskRoutingRules[taskType.rawValue] ?? []
    }

    // MARK: - Cost Management

    /// Maximum cost allowed per query (nil = unlimited)
    public var costBudgetPerQuery: Decimal?

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
              let config = try? JSONDecoder().decode(OrchestratorConfiguration.self, from: data)
        else {
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
            .direct
        case .moderate:
            .decompose
        case .complex:
            .deepAgent
        }
    }
}

// MARK: - Supporting Types

// Note: TaskType is defined in Intelligence/Classification/TaskType.swift
// QueryComplexity is defined in Core/Orchestration/OrchestrationTypes.swift

/// Execution strategies
public enum ExecutionStrategy: String, Codable, Sendable {
    case direct // Single model, direct execution
    case decompose // Query decomposition, parallel execution
    case deepAgent // Full DeepAgent with verification
}
