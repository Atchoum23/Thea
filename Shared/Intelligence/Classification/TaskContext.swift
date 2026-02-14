import Foundation

// MARK: - Task Context

/// Task context for prompt optimization and deep agent integration
/// Contains all necessary state for multi-step execution, retries, and self-correction
public struct TaskContext: Sendable {
    public let instruction: String
    public var metadata: [String: String]

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
