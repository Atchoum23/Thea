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

// TaskType is now defined in Intelligence/Classification/TaskType.swift
// Use that canonical version throughout the codebase

/// Extension to add icons used by MetaAI components
public extension TaskType {
    var icon: String {
        switch self {
        case .simpleQA: "questionmark.circle"
        case .codeGeneration: "chevron.left.forwardslash.chevron.right"
        case .complexReasoning: "brain.head.profile"
        case .creativeWriting: "pencil.and.outline"
        case .mathLogic, .math: "function"
        case .summarization: "text.alignleft"
        case .factual: "book"
        case .analysis: "chart.bar"
        case .planning: "list.bullet.clipboard"
        case .debugging, .codeDebugging: "ant"
        case .appDevelopment: "hammer"
        case .research: "magnifyingglass"
        case .contentCreation: "doc.text"
        case .workflowAutomation, .system: "gearshape.2"
        case .informationRetrieval: "doc.text.magnifyingglass"
        case .creation, .creative: "plus.circle"
        case .general, .conversation: "circle"
        case .codeAnalysis: "doc.text.magnifyingglass"
        case .codeExplanation: "text.bubble"
        case .codeRefactoring: "arrow.triangle.2.circlepath"
        case .translation: "globe"
        case .unknown: "questionmark"
        }
    }
}
