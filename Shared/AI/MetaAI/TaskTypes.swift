import Foundation

// MARK: - Task Types for ReasoningEngine
// Full implementation for DeepAgentEngine and AI Orchestration integration

/// Task context for deep agent integration
/// Contains all necessary state for multi-step execution, retries, and self-correction
public struct TaskContext: Sendable {
    public let instruction: String
    public var metadata: [String: String]

    // DeepAgentEngine requirements for self-correction
    public var retryCount: Int
    public var previousError: String?
    public var previousAttempts: [SubtaskResultSnapshot]
    public var verificationIssues: [String]
    public var userPreferences: [String: String]

    public init(
        instruction: String = "",
        metadata: [String: String] = [:],
        retryCount: Int = 0,
        previousError: String? = nil,
        previousAttempts: [SubtaskResultSnapshot] = [],
        verificationIssues: [String] = [],
        userPreferences: [String: String] = [:]
    ) {
        self.instruction = instruction
        self.metadata = metadata
        self.retryCount = retryCount
        self.previousError = previousError
        self.previousAttempts = previousAttempts
        self.verificationIssues = verificationIssues
        self.userPreferences = userPreferences
    }
}

/// Lightweight snapshot of subtask result for tracking previous attempts
/// Used to avoid circular dependencies with full SubtaskResult
public struct SubtaskResultSnapshot: Sendable, Codable {
    public let step: Int
    public let output: String
    public let success: Bool
    public let executionTime: TimeInterval

    public init(step: Int, output: String, success: Bool, executionTime: TimeInterval) {
        self.step = step
        self.output = output
        self.success = success
        self.executionTime = executionTime
    }
}

/// Task classification for decomposition and orchestration
public enum TaskType: String, Codable, Sendable, CaseIterable {
    // Orchestration task types
    case simpleQA
    case codeGeneration
    case complexReasoning
    case creativeWriting
    case mathLogic
    case summarization
    case factual
    case analysis
    case planning
    case debugging

    // Legacy task types
    case appDevelopment
    case research
    case contentCreation
    case workflowAutomation
    case informationRetrieval
    case creation
    case general

    public var displayName: String {
        switch self {
        case .simpleQA: return "Simple Q&A"
        case .codeGeneration: return "Code Generation"
        case .complexReasoning: return "Complex Reasoning"
        case .creativeWriting: return "Creative Writing"
        case .mathLogic: return "Math & Logic"
        case .summarization: return "Summarization"
        case .factual: return "Factual Lookup"
        case .analysis: return "Analysis"
        case .planning: return "Planning"
        case .debugging: return "Debugging"
        case .appDevelopment: return "App Development"
        case .research: return "Research"
        case .contentCreation: return "Content Creation"
        case .workflowAutomation: return "Workflow Automation"
        case .informationRetrieval: return "Information Retrieval"
        case .creation: return "Creation"
        case .general: return "General"
        }
    }

    public var icon: String {
        switch self {
        case .simpleQA: return "questionmark.circle"
        case .codeGeneration: return "chevron.left.forwardslash.chevron.right"
        case .complexReasoning: return "brain.head.profile"
        case .creativeWriting: return "pencil.and.outline"
        case .mathLogic: return "function"
        case .summarization: return "text.alignleft"
        case .factual: return "book"
        case .analysis: return "chart.bar"
        case .planning: return "list.bullet.clipboard"
        case .debugging: return "ant"
        case .appDevelopment: return "hammer"
        case .research: return "magnifyingglass"
        case .contentCreation: return "doc.text"
        case .workflowAutomation: return "gearshape.2"
        case .informationRetrieval: return "doc.text.magnifyingglass"
        case .creation: return "plus.circle"
        case .general: return "circle"
        }
    }
}
