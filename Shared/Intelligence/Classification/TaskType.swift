// TaskType.swift
// Thea V2
//
// Task type definitions for AI-powered classification

import Foundation

// MARK: - Task Type

/// Represents the type of task a query represents
public enum TaskType: String, Codable, Sendable, CaseIterable {
    case codeGeneration      // Writing new code
    case codeAnalysis        // Analyzing code structure/quality
    case codeDebugging       // Fixing code issues (alias for debugging)
    case debugging           // Fixing code issues
    case codeExplanation     // Explaining code
    case codeRefactoring     // Improving existing code
    case factual             // Questions with factual answers
    case creative            // Creative writing, brainstorming
    case analysis            // Analyzing data or code
    case research            // Searching for information
    case conversation        // General chat
    case system              // System operations (files, terminal)
    case math                // Mathematical calculations
    case translation         // Language translation
    case summarization       // Summarizing content
    case planning            // Task planning, project management
    case unknown             // Cannot determine

    // V1 compatibility aliases (legacy names)
    case simpleQA            // Legacy: use factual
    case complexReasoning    // Legacy: use analysis
    case creativeWriting     // Legacy: use creative
    case mathLogic           // Legacy: use math
    case informationRetrieval // Legacy: use research
    case appDevelopment      // Legacy: use codeGeneration
    case contentCreation     // Legacy: use creative
    case workflowAutomation  // Legacy: use system
    case creation            // Legacy: use creative
    case general             // Legacy: use conversation

    /// Human-readable display name (V1 compatibility alias)
    public var displayName: String {
        description
    }

    /// Human-readable description
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

    /// Suggested model capabilities for this task type
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

    /// Whether this task type benefits from extended reasoning
    public var benefitsFromReasoning: Bool {
        switch self {
        case .debugging, .codeDebugging, .codeAnalysis, .analysis, .complexReasoning, .math, .mathLogic, .planning, .codeRefactoring:
            return true
        default:
            return false
        }
    }

    /// Whether this is a simple query that can be handled by a local model
    /// Simple = short response, no complex reasoning, no code generation
    public var isSimple: Bool {
        switch self {
        case .conversation, .general, .factual, .simpleQA, .translation:
            return true
        default:
            return false
        }
    }

    /// Whether this task type represents an actionable operation (code, system, planning)
    public var isActionable: Bool {
        switch self {
        case .codeGeneration, .appDevelopment, .codeRefactoring, .debugging, .codeDebugging,
             .system, .workflowAutomation, .planning:
            return true
        default:
            return false
        }
    }

    /// Whether this task type typically needs web search
    public var needsWebSearch: Bool {
        switch self {
        case .research, .factual, .simpleQA, .informationRetrieval:
            return true
        default:
            return false
        }
    }

    /// Typical response length expectation
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

/// Expected length category for a model response, used to set max token limits.
public enum ResponseLength: String, Codable, Sendable {
    case short   // < 100 tokens
    case medium  // 100-500 tokens
    case long    // > 500 tokens

    public var suggestedMaxTokens: Int {
        switch self {
        case .short: return 500
        case .medium: return 2000
        case .long: return 8000
        }
    }
}

// MARK: - Classification Result

/// V1 compatibility typealias
public typealias TaskClassification = ClassificationResult

/// Classification method used to classify the query
public enum ClassificationMethodType: String, Codable, Sendable {
    case ai         // Full AI classification
    case embedding  // Semantic embedding similarity
    case pattern    // Learned pattern matching
    case cache      // Cache hit
}

/// Result of task classification
public struct ClassificationResult: Codable, Sendable {
    public let taskType: TaskType
    public let confidence: Double
    public let reasoning: String?
    public let alternativeTypes: [(TaskType, Double)]?
    public let suggestedModel: String?
    public let timestamp: Date
    public let classificationMethod: ClassificationMethodType

    /// V1 compatibility alias for taskType
    public var primaryType: TaskType { taskType }

    /// V1 compatibility - secondary types from alternatives
    public var secondaryTypes: [TaskType] {
        alternativeTypes?.map { $0.0 } ?? []
    }

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

    /// Whether the classification is confident enough to act on
    public var isConfident: Bool {
        confidence >= 0.7
    }
}
