// TaskType.swift
// Thea V2
//
// Task type definitions for AI-powered classification

import Foundation

// MARK: - Task Type

/// Represents the type of task a query represents
public enum TaskType: String, Codable, Sendable, CaseIterable {
    /// Writing new code from scratch.
    case codeGeneration
    /// Analyzing code structure, quality, or patterns.
    case codeAnalysis
    /// Fixing code issues (alias for debugging).
    case codeDebugging
    /// Fixing code issues.
    case debugging
    /// Explaining how code works.
    case codeExplanation
    /// Improving existing code without changing behavior.
    case codeRefactoring
    /// Questions with definitive factual answers.
    case factual
    /// Creative writing, brainstorming, or ideation.
    case creative
    /// Analyzing data, arguments, or complex topics.
    case analysis
    /// Searching for and synthesizing information.
    case research
    /// General conversational exchange.
    case conversation
    /// System operations (files, terminal, OS commands).
    case system
    /// Mathematical calculations or proofs.
    case math
    /// Language translation between human languages.
    case translation
    /// Summarizing or condensing content.
    case summarization
    /// Task planning, project management, or roadmapping.
    case planning
    /// Cannot determine the task type.
    case unknown

    /// Legacy alias: use `factual` instead.
    case simpleQA
    /// Legacy alias: use `analysis` instead.
    case complexReasoning
    /// Legacy alias: use `creative` instead.
    case creativeWriting
    /// Legacy alias: use `math` instead.
    case mathLogic
    /// Legacy alias: use `research` instead.
    case informationRetrieval
    /// Legacy alias: use `codeGeneration` instead.
    case appDevelopment
    /// Legacy alias: use `creative` instead.
    case contentCreation
    /// Legacy alias: use `system` instead.
    case workflowAutomation
    /// Legacy alias: use `creative` instead.
    case creation
    /// Legacy alias: use `conversation` instead.
    case general

    /// Human-readable display name (V1 compatibility alias).
    public var displayName: String {
        description
    }

    /// Human-readable description of this task type.
    public var description: String {
        switch self {
        case .codeGeneration, .appDevelopment: return "Code Generation"
        case .codeAnalysis: return "Code Analysis"
        case .codeDebugging, .debugging: return "Debugging"
        case .codeExplanation: return "Code Explanation"
        case .codeRefactoring: return "Code Refactoring"
        case .factual, .simpleQA: return "Factual Question"
        case .creative, .creativeWriting, .contentCreation, .creation: return "Creative Writing"
        case .analysis, .complexReasoning: return "Analysis"
        case .research, .informationRetrieval: return "Research"
        case .conversation, .general: return "Conversation"
        case .system, .workflowAutomation: return "System Operation"
        case .math, .mathLogic: return "Mathematics"
        case .translation: return "Translation"
        case .summarization: return "Summarization"
        case .planning: return "Planning"
        case .unknown: return "Unknown"
        }
    }

    /// Model capabilities recommended for handling this task type.
    public var preferredCapabilities: Set<ModelCapability> {
        switch self {
        case .codeGeneration, .debugging, .codeDebugging, .codeRefactoring, .appDevelopment:
            return [.codeGeneration, .chat]
        case .codeAnalysis, .codeExplanation:
            return [.codeGeneration, .chat]
        case .factual, .research, .simpleQA, .informationRetrieval:
            return [.chat, .search]
        case .creative, .creativeWriting, .contentCreation, .creation:
            return [.chat]
        case .analysis, .complexReasoning:
            return [.reasoning, .analysis, .chat]
        case .conversation, .general:
            return [.chat]
        case .system, .workflowAutomation:
            return [.functionCalling, .chat]
        case .math, .mathLogic:
            return [.reasoning, .chat]
        case .translation:
            return [.chat]
        case .summarization:
            return [.chat]
        case .planning:
            return [.reasoning, .chat]
        case .unknown:
            return [.chat]
        }
    }

    /// Whether this task type benefits from extended chain-of-thought reasoning.
    public var benefitsFromReasoning: Bool {
        switch self {
        case .debugging, .codeDebugging, .codeAnalysis, .analysis, .complexReasoning, .math, .mathLogic, .planning, .codeRefactoring:
            return true
        default:
            return false
        }
    }

    /// Whether this is a simple query suitable for a local or lightweight model.
    /// Simple tasks require short responses with no complex reasoning or code generation.
    public var isSimple: Bool {
        switch self {
        case .conversation, .general, .factual, .simpleQA, .translation:
            return true
        default:
            return false
        }
    }

    /// Whether this task type represents an actionable operation (code, system, planning).
    public var isActionable: Bool {
        switch self {
        case .codeGeneration, .appDevelopment, .codeRefactoring, .debugging, .codeDebugging,
             .system, .workflowAutomation, .planning:
            return true
        default:
            return false
        }
    }

    /// Whether this task type typically benefits from web search augmentation.
    public var needsWebSearch: Bool {
        switch self {
        case .research, .factual, .simpleQA, .informationRetrieval:
            return true
        default:
            return false
        }
    }

    /// Recommended LLM temperature for this task type.
    /// Lower values produce more deterministic output; higher values produce more creative output.
    public var recommendedTemperature: Double {
        switch self {
        case .codeGeneration, .codeDebugging, .debugging, .codeRefactoring, .appDevelopment:
            return 0.1 // Deterministic code generation
        case .factual, .simpleQA, .translation:
            return 0.2 // Precision
        case .math, .mathLogic:
            return 0.15 // Exact computation
        case .codeAnalysis, .codeExplanation:
            return 0.25 // Structured but readable
        case .analysis, .complexReasoning, .planning, .summarization:
            return 0.3 // Thoughtful reasoning
        case .research, .informationRetrieval:
            return 0.4 // Exploratory
        case .system, .workflowAutomation:
            return 0.2 // Deterministic system operations
        case .conversation, .general:
            return 0.7 // Natural conversation
        case .creative, .creativeWriting, .contentCreation, .creation:
            return 0.8 // Creative output
        case .unknown:
            return 0.5 // Balanced default
        }
    }

    /// Expected response length for this task type, used for token budgeting.
    public var expectedResponseLength: ResponseLength {
        switch self {
        case .conversation, .general:
            return .short
        case .factual, .simpleQA, .math, .mathLogic, .translation:
            return .medium
        case .codeGeneration, .appDevelopment, .debugging, .codeDebugging, .creative, .creativeWriting, .contentCreation, .creation, .analysis, .complexReasoning, .summarization, .planning:
            return .long
        case .codeAnalysis, .codeExplanation, .codeRefactoring, .research, .informationRetrieval, .system, .workflowAutomation, .unknown:
            return .medium
        }
    }
}

// MARK: - Response Length

/// Expected response length category, used for token budget estimation.
public enum ResponseLength: String, Codable, Sendable {
    /// Short response, under 100 tokens.
    case short
    /// Medium response, 100-500 tokens.
    case medium
    /// Long response, over 500 tokens.
    case long

    /// Suggested maxTokens value for this response length.
    public var suggestedMaxTokens: Int {
        switch self {
        case .short: return 500
        case .medium: return 2000
        case .long: return 8000
        }
    }

    /// Scaled max tokens proportional to the model's maximum output capacity.
    /// Caps at 50% of the model's `maxOutputTokens` to leave room for reasoning.
    /// - Parameter model: The AI model that will generate the response.
    /// - Returns: Token budget appropriate for this response length and model.
    public func scaledMaxTokens(for model: AIModel) -> Int {
        let modelMax = model.maxOutputTokens
        let cap = modelMax / 2 // 50% cap
        let base = suggestedMaxTokens
        // Scale proportionally: if model supports more output, give more tokens
        let scaled = Int(Double(base) * Double(modelMax) / 8000.0)
        return min(max(base, scaled), max(base, cap))
    }
}

// MARK: - Classification Result

/// V1 compatibility typealias for `ClassificationResult`.
public typealias TaskClassification = ClassificationResult

/// Method used to classify a query into a task type.
public enum ClassificationMethodType: String, Codable, Sendable {
    /// Full AI model classification.
    case ai
    /// Semantic embedding similarity matching.
    case embedding
    /// Learned pattern matching from prior classifications.
    case pattern
    /// Previously cached classification result.
    case cache
}

/// Result of classifying a user query into a task type.
public struct ClassificationResult: Codable, Sendable {
    /// Primary classified task type.
    public let taskType: TaskType
    /// Classification confidence score (0.0 - 1.0).
    public let confidence: Double
    /// Human-readable explanation of why this type was chosen.
    public let reasoning: String?
    /// Alternative task types with their confidence scores.
    public let alternativeTypes: [(TaskType, Double)]?
    /// Model suggested by the classifier for this task.
    public let suggestedModel: String?
    /// When the classification was performed.
    public let timestamp: Date
    /// Method used for classification.
    public let classificationMethod: ClassificationMethodType

    /// V1 compatibility alias for `taskType`.
    public var primaryType: TaskType { taskType }

    /// V1 compatibility: secondary types extracted from alternatives.
    public var secondaryTypes: [TaskType] {
        alternativeTypes?.map { $0.0 } ?? []
    }

    /// Creates a classification result.
    /// - Parameters:
    ///   - taskType: Primary classified task type.
    ///   - confidence: Confidence score (0.0 - 1.0).
    ///   - reasoning: Explanation of the classification.
    ///   - alternativeTypes: Other candidate types with scores.
    ///   - suggestedModel: Recommended model for the task.
    ///   - timestamp: When classification occurred.
    ///   - classificationMethod: Method used.
    public init(
        taskType: TaskType,
        confidence: Double,
        reasoning: String? = nil,
        alternativeTypes: [(TaskType, Double)]? = nil,
        suggestedModel: String? = nil,
        timestamp: Date = Date(),
        classificationMethod: ClassificationMethodType = .ai
    ) {
        self.taskType = taskType
        self.confidence = confidence
        self.reasoning = reasoning
        self.alternativeTypes = alternativeTypes
        self.suggestedModel = suggestedModel
        self.timestamp = timestamp
        self.classificationMethod = classificationMethod
    }

    // Custom Codable for alternativeTypes
    enum CodingKeys: String, CodingKey {
        case taskType, confidence, reasoning, suggestedModel, timestamp, classificationMethod
        case alternativeTypesEncoded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskType = try container.decode(TaskType.self, forKey: .taskType)
        confidence = try container.decode(Double.self, forKey: .confidence)
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
        suggestedModel = try container.decodeIfPresent(String.self, forKey: .suggestedModel)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        classificationMethod = try container.decodeIfPresent(ClassificationMethodType.self, forKey: .classificationMethod) ?? .ai

        if let encoded = try container.decodeIfPresent([[String]].self, forKey: .alternativeTypesEncoded) {
            alternativeTypes = encoded.compactMap { pair in
                guard pair.count == 2,
                      let type = TaskType(rawValue: pair[0]),
                      let conf = Double(pair[1]) else { return nil }
                return (type, conf)
            }
        } else {
            alternativeTypes = nil
        }
    }

    /// Encodes this classification result, converting `alternativeTypes` tuples into a serializable array-of-arrays format.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(reasoning, forKey: .reasoning)
        try container.encodeIfPresent(suggestedModel, forKey: .suggestedModel)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(classificationMethod, forKey: .classificationMethod)

        if let alternatives = alternativeTypes {
            let encoded = alternatives.map { [$0.0.rawValue, String($0.1)] }
            try container.encode(encoded, forKey: .alternativeTypesEncoded)
        }
    }

    /// Whether the classification confidence is high enough to act on (>= 0.7).
    public var isConfident: Bool {
        confidence >= 0.7
    }
}
