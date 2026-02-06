import Foundation
import SwiftData

// MARK: - Automatic Prompt Engineering System
// Based on 2026 best practices: Chain-of-Thought, Tree-of-Thoughts, Self-Consistency,
// Automatic Prompt Engineer (APE), and context-driven optimization

/// Advanced automatic prompt engineering that handles all optimization transparently
@MainActor
@Observable
final class AutomaticPromptEngineering {
    static let shared = AutomaticPromptEngineering()

    private var modelContext: ModelContext?

    // MARK: - Configuration

    struct Configuration: Codable, Sendable {
        // Reasoning Techniques
        var enableChainOfThought: Bool = true
        var enableTreeOfThoughts: Bool = true
        var enableSelfConsistency: Bool = true
        var enableReActPattern: Bool = true

        // Optimization Settings
        var enableAutomaticOptimization: Bool = true
        var enableContextInjection: Bool = true
        var enableFewShotSelection: Bool = true
        var enableRoleAssignment: Bool = true
        var enableOutputFormatting: Bool = true

        // Self-Consistency Settings
        var selfConsistencyPaths: Int = 3
        var majorityVotingThreshold: Double = 0.6

        // Tree-of-Thoughts Settings
        var totBranchFactor: Int = 3
        var totMaxDepth: Int = 3
        var totEvaluationStrategy: EvaluationStrategy = .bestFirst

        // Learning
        var enableOutcomeTracking: Bool = true
        var enablePatternLearning: Bool = true
        var learningRate: Double = 0.1

        enum EvaluationStrategy: String, Codable, Sendable {
            case bestFirst
            case breadthFirst
            case depthFirst
        }
    }

    private(set) var configuration = Configuration()
    private(set) var lastOptimizationDetails: OptimizationDetails?

    // Cache for frequently used patterns
    private var patternCache: [String: CachedPattern] = [:]
    private let patternCacheLimit = 100

    private init() {
        loadConfiguration()
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Main Entry Point

    /// Automatically engineers the optimal prompt for any user input
    /// This is the main method users should call - handles everything automatically
    func engineerPrompt(
        userInput: String,
        taskType: TaskType? = nil,
        additionalContext: [String: Any] = [:]
    ) async -> EngineeredPrompt {
        // 1. Classify task if not provided
        let classification: TaskType
        if let providedType = taskType {
            classification = providedType
        } else if let classifiedResult = try? await TaskClassifier.shared.classify(userInput) {
            classification = classifiedResult.primaryType
        } else {
            classification = .simpleQA
        }

        // 2. Gather context
        let context = await gatherContext(for: userInput, taskType: classification, additional: additionalContext)

        // 3. Select reasoning strategy
        let strategy = selectReasoningStrategy(for: classification, complexity: context.estimatedComplexity)

        // 4. Build optimized prompt
        let optimizedPrompt = await buildOptimizedPrompt(
            input: userInput,
            taskType: classification,
            context: context,
            strategy: strategy
        )

        // 5. Store optimization details for transparency
        lastOptimizationDetails = OptimizationDetails(
            originalInput: userInput,
            taskType: classification,
            strategyUsed: strategy,
            contextsApplied: context.appliedContextTypes,
            estimatedComplexity: context.estimatedComplexity
        )

        return optimizedPrompt
    }

    // MARK: - Context Gathering

    private struct GatheredContext {
        var systemContext: String = ""
        var domainContext: String = ""
        var userPreferences: [String: String] = [:]
        var relevantExamples: [String] = []
        var errorPatterns: [String] = []
        var appliedContextTypes: [String] = []
        var estimatedComplexity: PromptComplexityLevel = .medium
    }

    private func gatherContext(
        for input: String,
        taskType: TaskType,
        additional: [String: Any]
    ) async -> GatheredContext {
        var context = GatheredContext()

        // 1. System/Environment Context
        if configuration.enableContextInjection {
            context.systemContext = await getSystemContext()
            context.appliedContextTypes.append("system")
        }

        // 2. Domain-specific Context
        context.domainContext = getDomainContext(for: taskType)
        context.appliedContextTypes.append("domain:\(taskType.rawValue)")

        // 3. User Preferences
        if let prefs = await getUserPreferences(for: taskType) {
            context.userPreferences = prefs
            context.appliedContextTypes.append("preferences")
        }

        // 4. Few-shot Examples
        if configuration.enableFewShotSelection {
            context.relevantExamples = await selectRelevantExamples(for: input, taskType: taskType)
            if !context.relevantExamples.isEmpty {
                context.appliedContextTypes.append("examples:\(context.relevantExamples.count)")
            }
        }

        // 5. Error Prevention Patterns
        context.errorPatterns = await getRelevantErrorPatterns(for: taskType)
        if !context.errorPatterns.isEmpty {
            context.appliedContextTypes.append("error_prevention")
        }

        // 6. Estimate Complexity
        context.estimatedComplexity = estimateComplexity(input: input, taskType: taskType)

        // 7. Additional context from caller
        if let extraContext = additional["context"] as? String {
            context.domainContext += "\n\nAdditional Context: \(extraContext)"
        }

        return context
    }

    private func getSystemContext() async -> String {
        var parts: [String] = []

        // Current time context
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        parts.append("Current time: \(formatter.string(from: Date()))")

        // Platform context
        #if os(macOS)
        parts.append("Platform: macOS")
        #elseif os(iOS)
        parts.append("Platform: iOS")
        #elseif os(watchOS)
        parts.append("Platform: watchOS")
        #elseif os(tvOS)
        parts.append("Platform: tvOS")
        #endif

        // Device capabilities (simplified)
        parts.append("Swift version: 6.0")

        return parts.joined(separator: "\n")
    }

    private func getDomainContext(for taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration, .debugging:
            return """
            Domain: Software Development
            - Use Swift 6.0 best practices
            - Apply strict concurrency with actors and async/await
            - Prefer composition over inheritance
            - Follow SOLID principles
            - Include error handling
            """
        case .mathLogic:
            return """
            Domain: Mathematical and Logical Reasoning
            - Show step-by-step work
            - Verify calculations
            - Consider edge cases
            - Provide clear explanations
            """
        case .creativeWriting:
            return """
            Domain: Creative Writing
            - Match requested tone and style
            - Use vivid, engaging language
            - Maintain consistency
            - Consider audience
            """
        case .summarization:
            return """
            Domain: Summarization
            - Capture key points
            - Maintain accuracy
            - Be concise but complete
            - Preserve important details
            """
        case .complexReasoning:
            return """
            Domain: Complex Reasoning
            - Break down the problem
            - Consider multiple perspectives
            - Evaluate evidence
            - Draw logical conclusions
            """
        case .planning:
            return """
            Domain: Planning and Strategy
            - Define clear objectives
            - Consider constraints and resources
            - Identify risks and mitigations
            - Create actionable steps
            """
        case .analysis:
            return """
            Domain: Analysis
            - Examine data systematically
            - Identify patterns and trends
            - Consider context
            - Support conclusions with evidence
            """
        case .factual:
            return """
            Domain: Factual Information
            - Verify accuracy
            - Cite sources when possible
            - Acknowledge uncertainty
            - Distinguish facts from opinions
            """
        default:
            return ""
        }
    }

    private func getUserPreferences(for taskType: TaskType) async -> [String: String]? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<UserPromptPreference>()
        let allPreferences = (try? context.fetch(descriptor)) ?? []

        let filtered = allPreferences
            .filter { $0.category == taskType.rawValue && $0.confidence > 0.5 }
            .reduce(into: [String: String]()) { result, pref in
                result[pref.preferenceKey] = pref.preferenceValue
            }

        return filtered.isEmpty ? nil : filtered
    }

    private func selectRelevantExamples(for input: String, taskType: TaskType) async -> [String] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CodeFewShotExample>()
        let allExamples = (try? context.fetch(descriptor)) ?? []

        // Simple keyword matching for relevance
        let inputWords = Set(input.lowercased().split(separator: " ").map(String.init))

        // Filter by task type
        let taskTypeExamples = allExamples.filter { $0.taskType == taskType.rawValue }

        // Score each example by keyword overlap
        var scoredExamples: [(example: CodeFewShotExample, score: Double)] = []
        for example in taskTypeExamples {
            let exampleWords = Set(example.inputExample.lowercased().split(separator: " ").map(String.init))
            let overlap = Double(inputWords.intersection(exampleWords).count)
            let score = overlap / max(1.0, Double(inputWords.count))
            if score > 0.1 {
                scoredExamples.append((example, score))
            }
        }

        // Sort by combined score and quality
        scoredExamples.sort { first, second in
            let firstScore = first.score * Double(first.example.quality)
            let secondScore = second.score * Double(second.example.quality)
            return firstScore > secondScore
        }

        // Take top 3 and format
        let topExamples = scoredExamples.prefix(3)
        return topExamples.map { "Input: \($0.example.inputExample)\nOutput: \($0.example.outputExample)" }
    }

    private func getRelevantErrorPatterns(for taskType: TaskType) async -> [String] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CodeErrorRecord>()
        let allRecords = (try? context.fetch(descriptor)) ?? []

        // Filter by language if task type is code-related
        let isCodeTask = taskType == .codeGeneration || taskType == .debugging || taskType == .appDevelopment
        let relevantLanguage = isCodeTask ? "swift" : nil

        return allRecords
            .filter { record in
                record.occurrenceCount > 2 &&
                (relevantLanguage == nil || record.language.lowercased() == relevantLanguage)
            }
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
            .prefix(5)
            .map { $0.preventionRule.isEmpty ? "Avoid: \($0.errorMessage)" : $0.preventionRule }
    }

    private func estimateComplexity(input: String, taskType: TaskType) -> PromptComplexityLevel {
        let wordCount = input.split(separator: " ").count

        // Base complexity from word count
        var score = 0
        if wordCount > 100 {
            score += 2
        } else if wordCount > 50 {
            score += 1
        }

        // Task-type complexity bonus
        switch taskType {
        case .complexReasoning, .planning:
            score += 2
        case .codeGeneration, .debugging, .analysis:
            score += 1
        default:
            break
        }

        // Multi-step indicators
        let multiStepKeywords = ["then", "after", "next", "finally", "first", "second", "step"]
        let hasMultiStep = multiStepKeywords.contains { input.lowercased().contains($0) }
        if hasMultiStep {
            score += 1
        }

        switch score {
        case 0...1:
            return .simple
        case 2...3:
            return .medium
        default:
            return .complex
        }
    }

    // MARK: - Reasoning Strategy Selection

    enum ReasoningStrategy: String, Sendable {
        case direct           // Simple direct response
        case chainOfThought   // Step-by-step reasoning
        case treeOfThoughts   // Multiple reasoning paths
        case selfConsistency  // Multiple paths with voting
        case reAct            // Reasoning + Acting pattern
    }

    private func selectReasoningStrategy(
        for taskType: TaskType,
        complexity: PromptComplexityLevel
    ) -> ReasoningStrategy {
        // Complex tasks need advanced strategies
        if complexity == .complex {
            if configuration.enableTreeOfThoughts {
                return .treeOfThoughts
            } else if configuration.enableSelfConsistency {
                return .selfConsistency
            }
        }

        // Task-specific strategies
        switch taskType {
        case .mathLogic:
            return configuration.enableChainOfThought ? .chainOfThought : .direct
        case .complexReasoning, .planning:
            if configuration.enableTreeOfThoughts {
                return .treeOfThoughts
            }
            return configuration.enableChainOfThought ? .chainOfThought : .direct
        case .codeGeneration, .debugging:
            return configuration.enableReActPattern ? .reAct : .chainOfThought
        default:
            return complexity == .simple ? .direct : .chainOfThought
        }
    }

    // MARK: - Prompt Building

    private func buildOptimizedPrompt(
        input: String,
        taskType: TaskType,
        context: GatheredContext,
        strategy: ReasoningStrategy
    ) async -> EngineeredPrompt {
        var sections: [String] = []

        // 1. Role Assignment
        if configuration.enableRoleAssignment {
            sections.append(buildRoleSection(for: taskType))
        }

        // 2. System/Domain Context
        if !context.systemContext.isEmpty {
            sections.append("## Context\n\(context.systemContext)")
        }

        if !context.domainContext.isEmpty {
            sections.append("## Domain Guidelines\n\(context.domainContext)")
        }

        // 3. User Preferences
        if !context.userPreferences.isEmpty {
            var prefSection = "## Your Preferences (apply these):\n"
            for (key, value) in context.userPreferences {
                prefSection += "- \(key): \(value)\n"
            }
            sections.append(prefSection)
        }

        // 4. Few-shot Examples
        if !context.relevantExamples.isEmpty {
            var exampleSection = "## Examples of Expected Quality:\n"
            for (index, example) in context.relevantExamples.enumerated() {
                exampleSection += "\n### Example \(index + 1):\n\(example)\n"
            }
            sections.append(exampleSection)
        }

        // 5. Error Prevention
        if !context.errorPatterns.isEmpty {
            var errorSection = "## Common Pitfalls to Avoid:\n"
            for pattern in context.errorPatterns {
                errorSection += "- \(pattern)\n"
            }
            sections.append(errorSection)
        }

        // 6. Reasoning Instructions
        sections.append(buildReasoningInstructions(for: strategy))

        // 7. The Actual Task
        sections.append("## Your Task:\n\(input)")

        // 8. Output Format Instructions
        if configuration.enableOutputFormatting {
            sections.append(buildOutputFormatSection(for: taskType))
        }

        let fullPrompt = sections.joined(separator: "\n\n")

        return EngineeredPrompt(
            prompt: fullPrompt,
            taskType: taskType,
            strategy: strategy,
            complexity: context.estimatedComplexity,
            appliedTechniques: context.appliedContextTypes
        )
    }

    private func buildRoleSection(for taskType: TaskType) -> String {
        let role: String
        switch taskType {
        case .codeGeneration, .debugging:
            role = "You are an expert Swift 6.0 developer with deep knowledge of Apple platforms (macOS, iOS, watchOS, tvOS, visionOS). You write clean, efficient, and well-documented code following the latest best practices."
        case .mathLogic:
            role = "You are a mathematician and logician who solves problems step-by-step, showing all work and verifying solutions."
        case .creativeWriting:
            role = "You are a skilled creative writer who crafts engaging, well-structured content tailored to the audience and purpose."
        case .summarization:
            role = "You are an expert summarizer who distills complex information into clear, accurate, and concise summaries."
        case .complexReasoning:
            role = "You are a critical thinker who analyzes problems from multiple angles, considers evidence carefully, and draws well-reasoned conclusions."
        case .planning:
            role = "You are a strategic planner who creates comprehensive, actionable plans with clear goals, milestones, and contingencies."
        case .analysis:
            role = "You are a data analyst who examines information systematically, identifies patterns, and provides evidence-based insights."
        default:
            role = "You are a helpful, accurate, and thoughtful assistant."
        }

        return "## Your Role\n\(role)"
    }

    private func buildReasoningInstructions(for strategy: ReasoningStrategy) -> String {
        switch strategy {
        case .direct:
            return "## Approach\nProvide a direct, focused response."

        case .chainOfThought:
            return """
            ## Reasoning Approach
            Think through this step-by-step:
            1. Understand the core problem/request
            2. Break it down into components
            3. Address each component systematically
            4. Verify your reasoning at each step
            5. Synthesize into a final answer

            Show your thinking process before giving the final answer.
            """

        case .treeOfThoughts:
            return """
            ## Reasoning Approach (Tree of Thoughts)
            Explore multiple approaches before committing:

            1. **Generate Options**: Consider \(configuration.totBranchFactor) different approaches
            2. **Evaluate Each**: Assess pros and cons of each approach
            3. **Select Best**: Choose the most promising path
            4. **Develop Further**: Elaborate on the selected approach
            5. **Verify**: Check for completeness and correctness

            Document your exploration briefly before the final answer.
            """

        case .selfConsistency:
            return """
            ## Reasoning Approach (Self-Consistency)
            Consider multiple reasoning paths and find consensus:

            1. Approach the problem from \(configuration.selfConsistencyPaths) different angles
            2. Note where the approaches converge
            3. Identify the most consistent answer
            4. Explain why this answer is most reliable
            """

        case .reAct:
            return """
            ## Reasoning + Acting Approach
            For each step:
            1. **Thought**: What do I need to do/consider?
            2. **Action**: What specific action will I take?
            3. **Observation**: What was the result?
            4. **Repeat** until task is complete

            Interleave reasoning with actions for best results.
            """
        }
    }

    private func buildOutputFormatSection(for taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration:
            return """
            ## Output Format
            Provide:
            1. Brief explanation of the approach
            2. Complete, working code with comments
            3. Usage example if applicable
            4. Any important notes or caveats
            """
        case .debugging:
            return """
            ## Output Format
            Provide:
            1. Root cause analysis
            2. Step-by-step fix
            3. Corrected code
            4. Prevention tips for the future
            """
        case .summarization:
            return """
            ## Output Format
            Provide:
            - Key points (bullet list)
            - Brief narrative summary
            - Important details to note
            """
        case .planning:
            return """
            ## Output Format
            Provide:
            1. Clear objective statement
            2. Numbered action items with owners/timelines if applicable
            3. Key milestones
            4. Potential risks and mitigations
            """
        default:
            return """
            ## Output Format
            Provide a clear, well-organized response.
            """
        }
    }

    // MARK: - Configuration Management

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "AutomaticPromptEngineering.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data)
        {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "AutomaticPromptEngineering.config")
        }
    }

    // MARK: - Pattern Caching

    private struct CachedPattern: Sendable {
        let pattern: String
        let successRate: Double
        let lastUsed: Date
    }

    func cachePattern(for key: String, pattern: String, successRate: Double) {
        // LRU eviction if at limit
        if patternCache.count >= patternCacheLimit {
            if let oldestKey = patternCache.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
                patternCache.removeValue(forKey: oldestKey)
            }
        }

        patternCache[key] = CachedPattern(
            pattern: pattern,
            successRate: successRate,
            lastUsed: Date()
        )
    }

    func getCachedPattern(for key: String) -> String? {
        patternCache[key]?.pattern
    }

    // MARK: - Outcome Tracking

    func recordOutcome(
        prompt: EngineeredPrompt,
        success: Bool,
        userFeedback: String? = nil
    ) async {
        guard configuration.enableOutcomeTracking else { return }

        // Update pattern learning
        if configuration.enablePatternLearning {
            let key = "\(prompt.taskType.rawValue)_\(prompt.strategy.rawValue)"
            let currentRate = patternCache[key]?.successRate ?? 0.5
            let newRate = currentRate + (success ? configuration.learningRate : -configuration.learningRate)
            cachePattern(for: key, pattern: prompt.prompt, successRate: min(1, max(0, newRate)))
        }

        // Record in PromptOptimizer for persistent storage
        await PromptOptimizer.shared.recordOutcome(
            promptTemplate: nil,
            taskType: prompt.taskType.rawValue,
            success: success,
            confidence: success ? 1.0 : 0.0,
            output: userFeedback
        )
    }
}

// MARK: - Supporting Types

enum PromptComplexityLevel: String, Codable, Sendable {
    case simple
    case medium
    case complex
}

struct EngineeredPrompt: Sendable {
    let prompt: String
    let taskType: TaskType
    let strategy: AutomaticPromptEngineering.ReasoningStrategy
    let complexity: PromptComplexityLevel
    let appliedTechniques: [String]

    var summary: String {
        """
        Task: \(taskType.rawValue)
        Strategy: \(strategy.rawValue)
        Complexity: \(complexity.rawValue)
        Techniques: \(appliedTechniques.joined(separator: ", "))
        """
    }
}

struct OptimizationDetails: Sendable {
    let originalInput: String
    let taskType: TaskType
    let strategyUsed: AutomaticPromptEngineering.ReasoningStrategy
    let contextsApplied: [String]
    let estimatedComplexity: PromptComplexityLevel
}
