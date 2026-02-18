import Foundation
import OSLog
import Observation
@preconcurrency import SwiftData

// MARK: - Prompt Template Library

// Manages a curated library of prompt templates with versioning and success tracking

@MainActor
@Observable
final class PromptTemplateLibrary {
    static let shared = PromptTemplateLibrary()

    private var modelContext: ModelContext?
    private var templatesCache: [String: [PromptTemplate]] = [:]
    private var lastRefresh: Date?

    private var config: PromptEngineeringConfiguration {
        AppConfiguration.shared.promptEngineeringConfig
    }

    private let logger = Logger(subsystem: "ai.thea.app", category: "PromptTemplateLibrary")

    private init() {}

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        Task {
            await initializeDefaultTemplates()
        }
    }

    // MARK: - Template Selection

    func selectBestTemplate(for category: String, minSuccessRate: Float) async -> PromptTemplate? {
        await refreshCacheIfNeeded()

        guard let templates = templatesCache[category] else {
            return nil
        }

        // Filter by success rate and active status
        let candidates = templates.filter { $0.isActive && $0.successRate >= minSuccessRate }

        // Return template with highest success rate
        return candidates.max { a, b in
            a.successRate < b.successRate
        }
    }

    // MARK: - Cache Management

    private func refreshCacheIfNeeded() async {
        let shouldRefresh = lastRefresh == nil ||
            Date().timeIntervalSince(lastRefresh!) > config.templateRefreshInterval

        if shouldRefresh {
            await refreshCache()
        }
    }

    private func refreshCache() async {
        guard let context = modelContext else { return }

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<PromptTemplate>()

        do {
            let allTemplates = try context.fetch(descriptor)
            let templates = allTemplates.filter(\.isActive)

            templatesCache.removeAll()
            for template in templates {
                templatesCache[template.category, default: []].append(template)
            }

            lastRefresh = Date()
        } catch {
            print("Error refreshing template cache: \(error)")
        }
    }

    // MARK: - Default Templates Initialization

    private func initializeDefaultTemplates() async {
        guard let context = modelContext else { return }

        // Check if templates already exist
        let descriptor = FetchDescriptor<PromptTemplate>()
        let existingCount: Int
        do {
            existingCount = try context.fetchCount(descriptor)
        } catch {
            logger.error("Failed to fetch template count: \(error.localizedDescription)")
            existingCount = 0
        }

        if existingCount > 0 {
            return // Templates already initialized
        }

        // Create default templates for each agent type
        let templates = createDefaultTemplates()

        for template in templates {
            context.insert(template)
        }

        do {
            try context.save()
        } catch {
            logger.error("Failed to save default templates: \(error.localizedDescription)")
        }
    }

    private func createDefaultTemplates() -> [PromptTemplate] {
        var templates: [PromptTemplate] = []

        // MARK: - Coder Templates

        templates.append(PromptTemplate(
            name: "Swift Code Generation",
            category: "Coder",
            templateText: """
            You are an expert Swift 6.0 engineer. Generate production-ready code following these requirements:

            TASK:
            {{INSTRUCTION}}

            MANDATORY REQUIREMENTS:
            1. Swift 6.0 strict concurrency (@Sendable, @MainActor, actors)
            2. SwiftUI with @Observable macro (iOS 17+, macOS 14+)
            3. Zero compiler errors and warnings
            4. Self-documenting code with clear naming
            5. Comprehensive error handling
            6. Protocol-oriented design where appropriate

            CONTEXT:
            {{CONTEXT}}

            {{PREVIOUS_ERROR}}

            Provide only the code implementation. Ensure it compiles without errors.
            """
        ))

        templates.append(PromptTemplate(
            name: "Swift Bug Fix",
            category: "Coder",
            templateText: """
            You are a Swift debugging expert. Fix the following issue:

            ISSUE:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            PREVIOUS ERROR (avoid this):
            {{PREVIOUS_ERROR}}

            REQUIREMENTS:
            1. Identify root cause
            2. Provide minimal fix (don't refactor unnecessarily)
            3. Ensure fix doesn't introduce new issues
            4. Add comment explaining the fix if non-obvious
            5. Verify Swift 6.0 concurrency compliance

            Provide the corrected code.
            """
        ))

        templates.append(PromptTemplate(
            name: "Swift Refactoring",
            category: "Coder",
            templateText: """
            You are a Swift refactoring specialist. Improve the following code:

            REFACTORING REQUEST:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            GUIDELINES:
            1. Maintain existing functionality (no behavioral changes)
            2. Improve code quality, readability, maintainability
            3. Follow Swift best practices
            4. Update to modern Swift patterns (@Observable, async/await, etc.)
            5. Ensure thread safety and concurrency correctness

            Provide the refactored code with brief explanation of improvements.
            """
        ))

        // MARK: - Researcher Templates

        templates.append(PromptTemplate(
            name: "Comprehensive Research",
            category: "Researcher",
            templateText: """
            You are a research specialist. Conduct comprehensive research on:

            RESEARCH TOPIC:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            DELIVERABLES:
            1. Executive summary (2-3 sentences)
            2. Key findings (3-5 bullet points)
            3. Detailed analysis with sources
            4. Actionable recommendations
            5. Further reading suggestions

            Provide well-structured, cited research output.
            """
        ))

        // MARK: - Analyst Templates

        templates.append(PromptTemplate(
            name: "Data Analysis",
            category: "Analyst",
            templateText: """
            You are a data analyst. Analyze the following:

            ANALYSIS REQUEST:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            APPROACH:
            1. Identify patterns and trends
            2. Provide statistical insights
            3. Visualize key findings (describe charts/graphs)
            4. Draw actionable conclusions
            5. Highlight anomalies or outliers

            Provide structured analysis with clear insights.
            """
        ))

        // MARK: - Writer Templates

        templates.append(PromptTemplate(
            name: "Professional Writing",
            category: "Writer",
            templateText: """
            You are a professional writer. Create content for:

            WRITING REQUEST:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            REQUIREMENTS:
            1. Clear, engaging writing
            2. Appropriate tone for audience
            3. Well-structured with logical flow
            4. Correct grammar and style
            5. Compelling introduction and conclusion

            Provide polished, ready-to-use content.
            """
        ))

        // MARK: - Planner Templates

        templates.append(PromptTemplate(
            name: "Strategic Planning",
            category: "Planner",
            templateText: """
            You are a strategic planner. Create an execution plan for:

            PLANNING TASK:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            PLAN STRUCTURE:
            1. Goal definition and success criteria
            2. Task breakdown with dependencies
            3. Resource requirements
            4. Risk assessment and mitigation
            5. Timeline and milestones
            6. Validation checkpoints

            Provide detailed, actionable plan.
            """
        ))

        // MARK: - Critic Templates

        templates.append(PromptTemplate(
            name: "Constructive Critique",
            category: "Critic",
            templateText: """
            You are a constructive critic. Review the following:

            REVIEW SUBJECT:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            EVALUATION CRITERIA:
            1. Strengths (what works well)
            2. Weaknesses (what needs improvement)
            3. Missing elements
            4. Potential risks or issues
            5. Specific, actionable recommendations

            Provide balanced, constructive feedback.
            """
        ))

        // MARK: - Executor Templates

        templates.append(PromptTemplate(
            name: "Task Execution",
            category: "Executor",
            templateText: """
            You are an executor. Complete the following task:

            TASK:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            EXECUTION APPROACH:
            1. Understand requirements completely
            2. Execute step-by-step
            3. Verify each step before proceeding
            4. Handle errors gracefully
            5. Confirm completion with summary

            Provide execution results and confirmation.
            """
        ))

        // MARK: - Integrator Templates

        templates.append(PromptTemplate(
            name: "Result Integration",
            category: "Integrator",
            templateText: """
            You are an integrator. Combine the following outputs:

            INTEGRATION TASK:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            INTEGRATION REQUIREMENTS:
            1. Identify common themes
            2. Resolve conflicts or contradictions
            3. Create coherent narrative
            4. Eliminate redundancy
            5. Maintain all critical information

            Provide unified, coherent result.
            """
        ))

        // MARK: - Validator Templates

        templates.append(PromptTemplate(
            name: "Quality Validation",
            category: "Validator",
            templateText: """
            You are a validator. Verify the following:

            VALIDATION SUBJECT:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            VALIDATION CHECKLIST:
            1. Correctness (factual accuracy)
            2. Completeness (all requirements met)
            3. Quality (production-ready standard)
            4. Consistency (internal coherence)
            5. Compliance (follows guidelines)

            If invalid, provide corrected version. If valid, confirm with brief summary.
            """
        ))

        // MARK: - Optimizer Templates

        templates.append(PromptTemplate(
            name: "Performance Optimization",
            category: "Optimizer",
            templateText: """
            You are an optimizer. Improve the following:

            OPTIMIZATION TARGET:
            {{INSTRUCTION}}

            CONTEXT:
            {{CONTEXT}}

            OPTIMIZATION GOALS:
            1. Improve efficiency/performance
            2. Enhance clarity/usability
            3. Reduce complexity where possible
            4. Maintain functionality
            5. Quantify improvements

            Provide optimized version with explanation of improvements.
            """
        ))

        return templates
    }

    // MARK: - Template CRUD Operations

    func getAllTemplates() async -> [PromptTemplate] {
        guard let context = modelContext else { return [] }

        // Fetch all and sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<PromptTemplate>()
        let allTemplates: [PromptTemplate]
        do {
            allTemplates = try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch all templates: \(error.localizedDescription)")
            allTemplates = []
        }
        return allTemplates.sorted { ($0.category, $1.successRate) < ($1.category, $0.successRate) }
    }

    func getTemplatesByCategory(_ category: String) async -> [PromptTemplate] {
        guard let context = modelContext else { return [] }

        // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<PromptTemplate>()
        let allTemplates: [PromptTemplate]
        do {
            allTemplates = try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch templates for category: \(error.localizedDescription)")
            allTemplates = []
        }
        return allTemplates
            .filter { $0.category == category }
            .sorted { $0.successRate > $1.successRate }
    }

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
        do {
            try context.save()
        } catch {
            logger.error("Failed to save new template: \(error.localizedDescription)")
        }

        // Invalidate cache
        await refreshCache()
    }

    func updateTemplate(_ template: PromptTemplate, newText: String, createVersion: Bool) async {
        guard let context = modelContext else { return }

        if createVersion {
            let newTemplate = PromptTemplate(
                name: template.name,
                category: template.category,
                templateText: newText,
                version: template.version + 1
            )
            context.insert(newTemplate)
            template.isActive = false
        } else {
            template.templateText = newText
        }

        do {
            try context.save()
        } catch {
            logger.error("Failed to save template deletion: \(error.localizedDescription)")
        }

        // Invalidate cache
        await refreshCache()
    }

    func deleteTemplate(_ template: PromptTemplate) async {
        guard let context = modelContext else { return }

        template.isActive = false
        do {
            try context.save()
        } catch {
            logger.error("Failed to save template deletion: \(error.localizedDescription)")
        }

        // Invalidate cache
        await refreshCache()
    }

    // MARK: - Analytics

    func getTemplatePerformance() async -> [TemplatePerformance] {
        let templates = await getAllTemplates()

        return templates.map { template in
            TemplatePerformance(
                name: template.name,
                category: template.category,
                successRate: template.successRate,
                totalUses: template.successCount + template.failureCount,
                averageConfidence: template.averageConfidence,
                lastUsed: template.lastUsed
            )
        }
    }
}

// MARK: - Supporting Structures

struct TemplatePerformance {
    let name: String
    let category: String
    let successRate: Float
    let totalUses: Int
    let averageConfidence: Float
    let lastUsed: Date?
}
