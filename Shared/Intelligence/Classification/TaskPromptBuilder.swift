// TaskPromptBuilder.swift
// Thea V4 — Task-specific system prompt generation
//
// Extracted from ChatManager+Intelligence.swift (SRP: prompt engineering
// is a separate concern from orchestrator integration and message branching).
//
// Maps TaskType classifications to tailored system prompt instructions
// that guide AI providers toward optimal response quality.

import Foundation

/// Builds task-specific system prompt instructions based on classified task type.
/// Stateless utility — all methods are static.
enum TaskPromptBuilder {

    // MARK: - Public API

    /// Generates task-specific system prompt instructions for the given task type.
    /// Returns an empty string for conversational/general tasks that need no special prompting.
    static func buildPrompt(for taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration, .appDevelopment:
            codingPrompt(.generation)
        case .codeAnalysis:
            codingPrompt(.analysis)
        case .codeDebugging, .debugging:
            codingPrompt(.debugging)
        case .codeExplanation:
            codingPrompt(.explanation)
        case .codeRefactoring:
            codingPrompt(.refactoring)
        case .factual, .simpleQA:
            knowledgePrompt(.factual)
        case .creative, .creativeWriting, .contentCreation, .creation:
            knowledgePrompt(.creative)
        case .analysis, .complexReasoning:
            knowledgePrompt(.analysis)
        case .research, .informationRetrieval:
            knowledgePrompt(.research)
        case .conversation, .general:
            ""
        case .system, .workflowAutomation:
            knowledgePrompt(.system)
        case .math, .mathLogic:
            knowledgePrompt(.math)
        case .translation:
            knowledgePrompt(.translation)
        case .summarization:
            knowledgePrompt(.summarization)
        case .planning:
            knowledgePrompt(.planning)
        case .unknown:
            ""
        }
    }

    /// Extract numbered steps from an AI response for plan creation.
    static func extractPlanSteps(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var steps: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                let stepText = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !stepText.isEmpty {
                    steps.append(stepText)
                }
            }
        }

        return steps
    }

    // MARK: - Coding Prompts

    private enum CodingCategory {
        case generation, analysis, debugging, explanation, refactoring
    }

    private static func codingPrompt(_ category: CodingCategory) -> String {
        switch category {
        case .generation:
            return """
            You are a senior software engineer. Write clean, production-ready, self-documenting code. \
            Prefer composition over inheritance. Use dependency injection for testability. \
            Use proper types, enums, and protocols — never Any or force casts. \
            Include error handling and edge cases. Keep files under 500 lines. \
            Explain your design decisions briefly.
            """
        case .analysis:
            return """
            Analyze the code thoroughly. Identify potential bugs, performance issues, \
            security vulnerabilities, and style improvements. Be specific with line references.
            """
        case .debugging:
            return """
            Debug systematically. Identify the root cause, not just symptoms. \
            Explain why the bug occurs and provide a targeted fix. \
            Verify the fix doesn't introduce regressions. \
            Fix issues immediately — no deferring or "pre-existing" excuses.
            """
        case .explanation:
            return """
            Explain the code clearly at the appropriate level of detail. \
            Walk through the logic step by step. Highlight key patterns and design decisions.
            """
        case .refactoring:
            return """
            Refactor for clarity, maintainability, and performance. \
            Preserve existing behavior. Explain each change and its benefit. \
            Prefer composition over inheritance. Respect existing patterns — extend, don't hack. \
            Design for extensibility. Follow SOLID principles where applicable.
            """
        }
    }

    // MARK: - Knowledge Prompts

    private enum KnowledgeCategory {
        case factual, creative, analysis, research, system, math, translation, summarization, planning
    }

    private static func knowledgePrompt(_ category: KnowledgeCategory) -> String {
        switch category {
        case .factual:
            return """
            Provide accurate, well-sourced factual information. \
            Distinguish between established facts and your reasoning. \
            If uncertain, say so.
            """
        case .creative:
            return """
            Be creative and engaging. Match the requested tone and style. \
            Offer multiple options or approaches when appropriate.
            """
        case .analysis:
            return """
            Analyze thoroughly with structured reasoning. Consider multiple perspectives. \
            Support conclusions with evidence. Identify assumptions and limitations.
            """
        case .research:
            return """
            Research comprehensively. Organize findings clearly. \
            Cite sources when possible. Distinguish between primary and secondary information. \
            Note gaps in available information.
            """
        case .system:
            return """
            Provide precise system commands and configurations. \
            Warn about potentially destructive operations. \
            Include verification steps.
            """
        case .math:
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
        }
    }
}
