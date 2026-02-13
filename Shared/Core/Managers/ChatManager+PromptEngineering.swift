import Foundation

// MARK: - Automatic Prompt Engineering & Plan Extraction

extension ChatManager {

    /// Generates task-specific system prompt instructions based on the classified task type.
    /// This enables the AI to respond more effectively without the user needing to craft prompts.
    static func buildTaskSpecificPrompt(for taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration, .appDevelopment:
            return """
            You are a senior software engineer. Write clean, production-ready code. \
            Follow best practices for the language. Include error handling. \
            Explain your design decisions briefly.
            """
        case .codeAnalysis:
            return """
            Analyze the code thoroughly. Identify potential bugs, performance issues, \
            security vulnerabilities, and style improvements. Be specific with line references.
            """
        case .codeDebugging, .debugging:
            return """
            Debug systematically. Identify the root cause, not just symptoms. \
            Explain why the bug occurs and provide a targeted fix. \
            Verify the fix doesn't introduce regressions.
            """
        case .codeExplanation:
            return """
            Explain the code clearly at the appropriate level of detail. \
            Walk through the logic step by step. Highlight key patterns and design decisions.
            """
        case .codeRefactoring:
            return """
            Refactor for clarity, maintainability, and performance. \
            Preserve existing behavior. Explain each change and its benefit. \
            Follow SOLID principles where applicable.
            """
        case .factual, .simpleQA:
            return """
            Provide accurate, well-sourced factual information. \
            Distinguish between established facts and your reasoning. \
            If uncertain, say so.
            """
        case .creative, .creativeWriting, .contentCreation, .creation:
            return """
            Be creative and engaging. Match the requested tone and style. \
            Offer multiple options or approaches when appropriate.
            """
        case .analysis, .complexReasoning:
            return """
            Analyze thoroughly with structured reasoning. Consider multiple perspectives. \
            Support conclusions with evidence. Identify assumptions and limitations.
            """
        case .research, .informationRetrieval:
            return """
            Research comprehensively. Organize findings clearly. \
            Cite sources when possible. Distinguish between primary and secondary information. \
            Note gaps in available information.
            """
        case .conversation, .general:
            return "" // No special instructions for casual conversation
        case .system, .workflowAutomation:
            return """
            Provide precise system commands and configurations. \
            Warn about potentially destructive operations. \
            Include verification steps.
            """
        case .math, .mathLogic:
            return """
            Show your work step by step. Use precise mathematical notation. \
            Verify your answer with a sanity check. Explain the approach before calculating.
            """
        case .translation:
            return """
            Translate accurately while preserving meaning, tone, and cultural nuance. \
            Note any idioms or phrases that don't translate directly. \
            Provide context where the translation might be ambiguous.
            """
        case .summarization:
            return """
            Summarize concisely while preserving key information. \
            Organize by importance. Include the main conclusions and supporting points. \
            Note any critical details that shouldn't be omitted.
            """
        case .planning:
            return """
            Create actionable plans with clear steps, dependencies, and priorities. \
            Identify risks and mitigation strategies. \
            Include time estimates where possible. Consider resource constraints.
            """
        case .unknown:
            return ""
        }
    }

    /// Extract numbered steps from an AI response for plan creation.
    /// Matches lines like "1. Do something" or "1) Step one"
    static func extractPlanSteps(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var steps: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match "1. Step" or "1) Step"
            if let range = trimmed.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                let stepText = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !stepText.isEmpty {
                    steps.append(stepText)
                }
            }
        }

        return steps
    }
}
