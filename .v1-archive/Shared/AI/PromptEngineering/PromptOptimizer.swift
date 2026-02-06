import Foundation
import Observation
@preconcurrency import SwiftData

// MARK: - Prompt Optimizer

// Automatically optimizes prompts for maximum accuracy and effectiveness

@MainActor
@Observable
final class PromptOptimizer {
    static let shared = PromptOptimizer()

    private var modelContext: ModelContext?
    private var templateLibrary = PromptTemplateLibrary.shared
    private var userPreferenceModel = UserPreferenceModel.shared

    // Configuration accessor
    private var config: PromptEngineeringConfiguration {
        AppConfiguration.shared.promptEngineeringConfig
    }

    private init() {}

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        templateLibrary.setModelContext(context)
        userPreferenceModel.setModelContext(context)
    }

    // MARK: - Main Optimization Method

    /// Optimizes a prompt for a given task type and agent type
    func optimizePrompt(
        for taskInstruction: String,
        agentType: SubAgentOrchestrator.AgentType,
        context: TaskContext,
        originalPrompt: String? = nil
    ) async -> String {
        guard config.enableAutoOptimization else {
            return originalPrompt ?? taskInstruction
        }

        var optimizedPrompt = originalPrompt ?? ""

        // 1. Select best template for task type
        if let template = await selectBestTemplate(for: agentType, taskInstruction: taskInstruction) {
            optimizedPrompt = interpolateTemplate(template.templateText, with: taskInstruction, context: context)
        } else {
            optimizedPrompt = taskInstruction
        }

        // 2. Inject few-shot examples if enabled
        if config.enableFewShotLearning {
            let examples = await getCodeFewShotExamples(for: agentType, limit: config.maxFewShotExamples)
            if !examples.isEmpty {
                optimizedPrompt = injectCodeFewShotExamples(optimizedPrompt, examples: examples)
            }
        }

        // 3. Apply user preference learning
        if config.enableUserPreferenceLearning {
            let preferences = await userPreferenceModel.getPreferences(for: agentType.rawValue)
            optimizedPrompt = applyUserPreferences(optimizedPrompt, preferences: preferences)
        }

        // 4. Add error prevention guidance from previous attempts
        if !context.verificationIssues.isEmpty {
            optimizedPrompt = addErrorPrevention(optimizedPrompt, issues: context.verificationIssues)
        }

        return optimizedPrompt
    }

    // MARK: - Template Selection

    private func selectBestTemplate(
        for agentType: SubAgentOrchestrator.AgentType,
        taskInstruction _: String
    ) async -> PromptTemplate? {
        await templateLibrary.selectBestTemplate(
            for: agentType.rawValue,
            minSuccessRate: config.minTemplateSuccessRate
        )
    }

    private func interpolateTemplate(_ template: String, with instruction: String, context: TaskContext) -> String {
        var result = template
        result = result.replacingOccurrences(of: "{{INSTRUCTION}}", with: instruction)
        result = result.replacingOccurrences(of: "{{CONTEXT}}", with: formatContext(context))

        if let previousError = context.previousError {
            result = result.replacingOccurrences(of: "{{PREVIOUS_ERROR}}", with: previousError)
        }

        return result
    }

    private func formatContext(_ context: TaskContext) -> String {
        var contextParts: [String] = []

        if context.retryCount > 0 {
            contextParts.append("This is attempt #\(context.retryCount + 1)")
        }

        if !context.previousAttempts.isEmpty {
            contextParts.append("Previous attempts: \(context.previousAttempts.count)")
        }

        if !context.verificationIssues.isEmpty {
            contextParts.append("Known issues to avoid: \(context.verificationIssues.joined(separator: ", "))")
        }

        return contextParts.isEmpty ? "" : contextParts.joined(separator: "\n")
    }

    // MARK: - Few-Shot Learning

    private func getCodeFewShotExamples(for agentType: SubAgentOrchestrator.AgentType, limit: Int) async -> [CodeFewShotExample] {
        guard let context = modelContext else { return [] }

        // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<CodeFewShotExample>()

        do {
            let allExamples = try context.fetch(descriptor)
            let examples = allExamples
                .filter { $0.taskType == agentType.rawValue }
                .sorted { ($0.quality, $0.usageCount) > ($1.quality, $1.usageCount) }
            return Array(examples.prefix(limit))
        } catch {
            print("Error fetching few-shot examples: \(error)")
            return []
        }
    }

    private func injectCodeFewShotExamples(_ prompt: String, examples: [CodeFewShotExample]) -> String {
        guard !examples.isEmpty else { return prompt }

        var enhancedPrompt = prompt + "\n\nHere are some examples of high-quality outputs:\n\n"

        for (index, example) in examples.enumerated() {
            enhancedPrompt += """
            Example \(index + 1):
            Input: \(example.inputExample)
            Output: \(example.outputExample)

            """
        }

        enhancedPrompt += "\nPlease provide a similar high-quality output for the current task.\n"

        return enhancedPrompt
    }

    // MARK: - User Preference Learning

    private func applyUserPreferences(_ prompt: String, preferences: [UserPromptPreference]) -> String {
        var enhancedPrompt = prompt

        if !preferences.isEmpty {
            enhancedPrompt += "\n\nUser Preferences (apply these to your response):\n"

            for preference in preferences where preference.confidence > config.confidenceThreshold {
                enhancedPrompt += "- \(preference.preferenceKey): \(preference.preferenceValue)\n"
            }
        }

        return enhancedPrompt
    }

    // MARK: - Error Prevention

    private func addErrorPrevention(_ prompt: String, issues: [String]) -> String {
        var enhancedPrompt = prompt

        if !issues.isEmpty {
            enhancedPrompt += "\n\n⚠️ CRITICAL: Avoid these issues from previous attempts:\n"

            for (index, issue) in issues.enumerated() {
                enhancedPrompt += "\(index + 1). \(issue)\n"
            }

            enhancedPrompt += "\nDouble-check your output to ensure none of these issues are present.\n"
        }

        return enhancedPrompt
    }

    // MARK: - Outcome Recording

    /// Records the outcome of a prompt execution for A/B testing and learning
    func recordOutcome(
        promptTemplate: PromptTemplate?,
        taskType: String,
        success: Bool,
        confidence: Double,
        output: String? = nil
    ) async {
        guard config.autoRecordOutcomes, let context = modelContext else { return }

        // Update template statistics
        if let template = promptTemplate {
            if success {
                template.successCount += 1
            } else {
                template.failureCount += 1
            }

            let totalAttempts = template.successCount + template.failureCount
            template.averageConfidence = Float(
                (Double(template.averageConfidence) * Double(totalAttempts - 1) + confidence) / Double(totalAttempts)
            )
            template.lastUsed = Date()

            try? context.save()
        }

        // Create few-shot example if highly successful
        if success, confidence > 0.9, let output {
            let example = CodeFewShotExample(
                taskType: taskType,
                inputExample: "Task type: \(taskType)",
                outputExample: output,
                quality: Float(confidence)
            )
            context.insert(example)
            try? context.save()
        }
    }

    /// Records user feedback to improve preference learning
    func recordUserFeedback(
        category: String,
        preferenceKey: String,
        preferenceValue: String,
        positive: Bool
    ) async {
        await userPreferenceModel.updatePreference(
            category: category,
            key: preferenceKey,
            value: preferenceValue,
            reinforcement: positive ? 0.1 : -0.1
        )
    }

    // MARK: - A/B Testing

    /// Selects a template variant for A/B testing
    func selectTemplateForABTest(
        variants: [PromptTemplate]
    ) -> PromptTemplate? {
        guard config.enableABTesting, !variants.isEmpty else {
            return variants.first
        }

        // Implement epsilon-greedy strategy
        let epsilon = 0.1 // 10% exploration

        if Double.random(in: 0 ... 1) < epsilon {
            // Explore: random selection
            return variants.randomElement()
        } else {
            // Exploit: select best performing
            return variants.max { a, b in
                a.successRate < b.successRate
            }
        }
    }

    // MARK: - Template Management

    /// Creates a new prompt template
    func createTemplate(
        name: String,
        category: String,
        templateText: String
    ) async {
        guard let context = modelContext else { return }

        let template = PromptTemplate(
            name: name,
            category: category,
            templateText: templateText
        )

        context.insert(template)
        try? context.save()
    }

    /// Updates an existing template
    func updateTemplate(
        _ template: PromptTemplate,
        newText: String
    ) async {
        guard let context = modelContext else { return }

        if config.enableTemplateVersioning {
            // Create new version
            let newTemplate = PromptTemplate(
                name: template.name,
                category: template.category,
                templateText: newText,
                version: template.version + 1
            )
            context.insert(newTemplate)

            // Deactivate old version
            template.isActive = false
        } else {
            // Update in place
            template.templateText = newText
        }

        try? context.save()
    }

    /// Gets all templates for a category
    func getTemplates(for category: String) async -> [PromptTemplate] {
        guard let context = modelContext else { return [] }

        // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<PromptTemplate>()
        let allTemplates = (try? context.fetch(descriptor)) ?? []
        return allTemplates
            .filter { $0.category == category && $0.isActive }
            .sorted { $0.successRate > $1.successRate }
    }

    // MARK: - Analytics

    /// Gets optimization statistics
    func getOptimizationStats() async -> OptimizationStats {
        guard let context = modelContext else {
            return OptimizationStats(
                totalTemplates: 0,
                averageSuccessRate: 0,
                totalOptimizations: 0,
                fewShotExamplesCount: 0
            )
        }

        let templateDescriptor = FetchDescriptor<PromptTemplate>()
        let exampleDescriptor = FetchDescriptor<CodeFewShotExample>()

        let templates = (try? context.fetch(templateDescriptor)) ?? []
        let examples = (try? context.fetch(exampleDescriptor)) ?? []

        let avgSuccessRate = templates.isEmpty ? 0 : templates.map(\.successRate).reduce(0, +) / Float(templates.count)
        let totalOptimizations = templates.reduce(0) { $0 + $1.successCount + $1.failureCount }

        return OptimizationStats(
            totalTemplates: templates.count,
            averageSuccessRate: avgSuccessRate,
            totalOptimizations: totalOptimizations,
            fewShotExamplesCount: examples.count
        )
    }
}

// MARK: - Supporting Structures

struct OptimizationStats {
    let totalTemplates: Int
    let averageSuccessRate: Float
    let totalOptimizations: Int
    let fewShotExamplesCount: Int
}

// MARK: - Context Extension

extension TaskContext {
    var categoryHint: String {
        if let error = previousError {
            if error.contains("syntax") || error.contains("compile") {
                return "code"
            } else if error.contains("format") || error.contains("style") {
                return "formatting"
            }
        }
        return "general"
    }
}
