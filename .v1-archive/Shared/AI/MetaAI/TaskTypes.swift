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
        case .simpleQA: "Simple Q&A"
        case .codeGeneration: "Code Generation"
        case .complexReasoning: "Complex Reasoning"
        case .creativeWriting: "Creative Writing"
        case .mathLogic: "Math & Logic"
        case .summarization: "Summarization"
        case .factual: "Factual Lookup"
        case .analysis: "Analysis"
        case .planning: "Planning"
        case .debugging: "Debugging"
        case .appDevelopment: "App Development"
        case .research: "Research"
        case .contentCreation: "Content Creation"
        case .workflowAutomation: "Workflow Automation"
        case .informationRetrieval: "Information Retrieval"
        case .creation: "Creation"
        case .general: "General"
        }
    }

    public var icon: String {
        switch self {
        case .simpleQA: "questionmark.circle"
        case .codeGeneration: "chevron.left.forwardslash.chevron.right"
        case .complexReasoning: "brain.head.profile"
        case .creativeWriting: "pencil.and.outline"
        case .mathLogic: "function"
        case .summarization: "text.alignleft"
        case .factual: "book"
        case .analysis: "chart.bar"
        case .planning: "list.bullet.clipboard"
        case .debugging: "ant"
        case .appDevelopment: "hammer"
        case .research: "magnifyingglass"
        case .contentCreation: "doc.text"
        case .workflowAutomation: "gearshape.2"
        case .informationRetrieval: "doc.text.magnifyingglass"
        case .creation: "plus.circle"
        case .general: "circle"
        }
    }
}
