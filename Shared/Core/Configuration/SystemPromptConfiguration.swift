// SystemPromptConfiguration.swift
// User-configurable system prompts for different task types

import Foundation

/// Configuration for user-editable system prompts
public struct SystemPromptConfiguration: Codable, Sendable {
    public var basePrompt: String
    public var taskPrompts: [String: String]
    public var useDynamicPrompts: Bool

    private static let storageKey = "SystemPromptConfiguration"

    // MARK: - Initialization

    public init(basePrompt: String, taskPrompts: [String: String], useDynamicPrompts: Bool) {
        self.basePrompt = basePrompt
        self.taskPrompts = taskPrompts
        self.useDynamicPrompts = useDynamicPrompts
    }

    public static func defaults() -> SystemPromptConfiguration {
        SystemPromptConfiguration(
            basePrompt: """
            You are THEA, a helpful AI assistant. You provide accurate, helpful, and concise responses. \
            Be direct and focus on answering the user's question. If you don't know something, say so honestly.
            """,
            taskPrompts: [
                TaskType.codeGeneration.rawValue: """
                CODE GENERATION GUIDELINES:
                - Write clean, well-documented, production-ready code
                - Follow language-specific best practices and conventions
                - Include error handling and edge cases
                - Use meaningful variable and function names
                - Add brief comments for complex logic only
                - Prefer modern syntax and patterns
                """,

                TaskType.debugging.rawValue: """
                DEBUGGING GUIDELINES:
                - Analyze the error message and context carefully
                - Identify the root cause, not just symptoms
                - Explain why the bug occurred
                - Provide a clear, tested fix
                - Suggest ways to prevent similar issues
                """,

                TaskType.mathLogic.rawValue: """
                MATHEMATICAL REASONING GUIDELINES:
                - Show your work step-by-step
                - Clearly state any assumptions
                - Verify your answer when possible
                - Use proper mathematical notation
                - Explain the reasoning behind each step
                """,

                TaskType.creativeWriting.rawValue: """
                CREATIVE WRITING GUIDELINES:
                - Be imaginative and engaging
                - Use vivid descriptions and varied sentence structures
                - Maintain consistent tone and style
                - Develop compelling characters and narratives
                - Balance creativity with the user's specific requests
                """,

                TaskType.analysis.rawValue: """
                ANALYSIS GUIDELINES:
                - Examine the topic from multiple perspectives
                - Identify key factors and relationships
                - Support conclusions with evidence and reasoning
                - Consider potential counterarguments
                - Provide actionable insights when applicable
                """,

                TaskType.complexReasoning.rawValue: """
                COMPLEX REASONING GUIDELINES:
                - Break down the problem into components
                - Consider multiple angles and implications
                - Use logical steps to reach conclusions
                - Acknowledge uncertainty where appropriate
                - Validate reasoning with examples when possible
                """,

                TaskType.summarization.rawValue: """
                SUMMARIZATION GUIDELINES:
                - Identify and prioritize the most important information
                - Maintain accuracy while being concise
                - Preserve the original meaning and intent
                - Organize information logically
                - Use bullet points for clarity when appropriate
                """,

                TaskType.planning.rawValue: """
                PLANNING GUIDELINES:
                - Break down complex goals into actionable steps
                - Identify dependencies and prerequisites
                - Consider potential risks and mitigation strategies
                - Provide realistic timelines when relevant
                - Prioritize tasks by importance and urgency
                """,

                TaskType.factual.rawValue: """
                FACTUAL RESPONSE GUIDELINES:
                - Provide accurate, verifiable information
                - Cite sources or knowledge limitations when appropriate
                - Distinguish between facts and opinions
                - Be concise and direct
                - Acknowledge uncertainty when present
                """,

                TaskType.simpleQA.rawValue: """
                SIMPLE Q&A GUIDELINES:
                - Answer directly and concisely
                - Provide context only when helpful
                - Use clear, accessible language
                """
            ],
            useDynamicPrompts: true
        )
    }

    // MARK: - Public API

    public func prompt(for taskType: TaskType) -> String {
        taskPrompts[taskType.rawValue] ?? ""
    }

    public mutating func setPrompt(_ prompt: String, for taskType: TaskType) {
        taskPrompts[taskType.rawValue] = prompt
    }

    public func isCustomized(for taskType: TaskType) -> Bool {
        guard let current = taskPrompts[taskType.rawValue] else { return false }
        let defaults = Self.defaults()
        guard let defaultPrompt = defaults.taskPrompts[taskType.rawValue] else { return !current.isEmpty }
        return current != defaultPrompt
    }

    public mutating func resetToDefault(for taskType: TaskType) {
        let defaults = Self.defaults()
        taskPrompts[taskType.rawValue] = defaults.taskPrompts[taskType.rawValue]
    }

    /// Get the full system prompt for a task type
    public func fullPrompt(for taskType: TaskType?) -> String {
        guard useDynamicPrompts, let taskType = taskType else {
            return basePrompt
        }

        let taskSpecific = prompt(for: taskType)
        if taskSpecific.isEmpty {
            return basePrompt
        }

        return "\(basePrompt)\n\n\(taskSpecific)"
    }

    // MARK: - Persistence

    public static func load() -> SystemPromptConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(SystemPromptConfiguration.self, from: data) else {
            return defaults()
        }
        return config
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
