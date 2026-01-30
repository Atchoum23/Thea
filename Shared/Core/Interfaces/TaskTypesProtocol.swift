// TaskTypesProtocol.swift
// Interface module - Task types for AI orchestration
// Following 2025/2026 best practices: Pure Foundation types in interface layer

import Foundation

// MARK: - Task Type Classification

/// Task classification for decomposition and orchestration.
/// Used by the AI orchestration system to route queries to appropriate models.
public enum TaskTypeSnapshot: String, Codable, Sendable, CaseIterable {
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

// MARK: - Task Context

/// Task context for deep agent integration.
/// Contains all necessary state for multi-step execution, retries, and self-correction.
public struct TaskContextSnapshot: Sendable, Codable {
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

// MARK: - Subtask Result

/// Lightweight snapshot of subtask result for tracking previous attempts.
/// Used to avoid circular dependencies with full SubtaskResult.
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

// MARK: - Task Classifier Protocol

/// Protocol for task classification services.
/// Enables dependency injection for classifying user queries.
public protocol TaskClassifierProtocol: Sendable {
    /// Classifies a user query into a task type
    func classify(_ query: String) async throws -> TaskTypeSnapshot

    /// Classifies with additional context
    func classify(_ query: String, context: TaskContextSnapshot) async throws -> TaskTypeSnapshot
}

// MARK: - Model Router Protocol

/// Protocol for model routing services.
/// Routes tasks to optimal models based on classification and preferences.
public protocol ModelRouterProtocol: Sendable {
    /// Gets the recommended model for a task type
    func recommendedModel(for taskType: TaskTypeSnapshot) async throws -> String

    /// Gets the recommended model with context
    func recommendedModel(
        for taskType: TaskTypeSnapshot,
        context: TaskContextSnapshot
    ) async throws -> String
}
