// IntelligenceOrchestrator.swift
// Thea V2
//
// Central coordinator that ties together all intelligence systems:
// - AgentMode (execution)
// - Skills (capabilities)
// - Knowledge (context)
// - Learning (personalization)
// - Activity (tracking)
// - Devices (smart home)
//
// This solves the critical integration gap where these systems were
// operating in isolation.

import Foundation
import OSLog

// MARK: - Intelligence Orchestrator

/// Central coordinator for all Thea intelligence systems
/// Ensures skills, knowledge, learning, and activity tracking work together
@MainActor
public final class IntelligenceOrchestrator: ObservableObject {
    public static let shared = IntelligenceOrchestrator()

    private let logger = Logger(subsystem: "com.thea.v2", category: "IntelligenceOrchestrator")

    // MARK: - Connected Systems

    private let agentState: AgentExecutionState
    private let skillRegistry: SkillRegistry
    private let knowledgeManager: ProjectKnowledgeManager
    private let knowledgeSourceManager: KnowledgeSourceManager
    private let learningManager: LearningManager
    private let activityTracker: ActivityTracker
    private let autonomousAgent: AutonomousAgent
    private let deviceManager: SmartDeviceManager

    // MARK: - Published State

    @Published public private(set) var currentContext: IntelligenceTaskContext?
    @Published public private(set) var isPreparingContext: Bool = false
    @Published public private(set) var lastError: OrchestratorError?

    // MARK: - Initialization

    private init() {
        self.agentState = AgentExecutionState()
        self.skillRegistry = SkillRegistry.shared
        self.knowledgeManager = ProjectKnowledgeManager.shared
        self.knowledgeSourceManager = KnowledgeSourceManager.shared
        self.learningManager = LearningManager.shared
        self.activityTracker = ActivityTracker.shared
        self.autonomousAgent = AutonomousAgent.shared
        self.deviceManager = SmartDeviceManager.shared

        setupEventHandlers()
        logger.info("IntelligenceOrchestrator initialized - all systems connected")
    }

    // MARK: - Context Preparation

    /// Prepare a complete task context combining all intelligence systems
    /// This is the main entry point for starting any task
    public func prepareIntelligenceTaskContext(
        task: String,
        taskType: TaskType,
        currentFile: String? = nil,
        projectPath: String? = nil
    ) async -> IntelligenceTaskContext {
        isPreparingContext = true
        defer { isPreparingContext = false }

        logger.info("Preparing task context for: \(task)")

        // 1. Start activity session if not already active
        let session = activityTracker.startSession(context: task)

        // 2. Find matching skills for this task
        let matchingSkills = await loadMatchingSkills(
            taskType: taskType,
            currentFile: currentFile,
            query: task
        )

        // 3. Load applicable knowledge
        let knowledgeAdditions = await loadKnowledgeAdditions(
            projectPath: projectPath,
            taskType: taskType
        )

        // 4. Get user's learning context for personalization
        let learningContext = await loadLearningContext()

        // 5. Get response style based on user profile
        let responseStyle = learningManager.getResponseStyle()

        // 6. Build the enhanced system prompt
        let enhancedPrompt = buildEnhancedSystemPrompt(
            basePrompt: getBasePromptForTaskType(taskType),
            skills: matchingSkills,
            knowledge: knowledgeAdditions,
            learningContext: learningContext,
            responseStyle: responseStyle
        )

        // 7. Create the context
        let context = IntelligenceTaskContext(
            id: UUID(),
            task: task,
            taskType: taskType,
            sessionId: session.id,
            matchingSkills: matchingSkills,
            knowledgeItems: knowledgeAdditions,
            learningContext: learningContext,
            responseStyle: responseStyle,
            enhancedSystemPrompt: enhancedPrompt,
            createdAt: Date()
        )

        currentContext = context

        // 8. Record the task start as an interaction
        activityTracker.recordInteraction(Interaction(
            type: .query,
            details: InteractionDetails(
                query: task,
                taskType: taskType.rawValue
            )
        ))

        logger.info("Task context prepared with \(matchingSkills.count) skills, \(knowledgeAdditions.count) knowledge items")

        // 9. Publish event for other systems
        EventBus.shared.publish(ComponentEvent(
            source: .system,
            action: "taskContextPrepared",
            component: "IntelligenceOrchestrator",
            details: [
                "taskType": taskType.rawValue,
                "skillCount": String(matchingSkills.count),
                "knowledgeCount": String(knowledgeAdditions.count)
            ]
        ))

        return context
    }

    // MARK: - Task Completion

    /// Record task completion and update all relevant systems
    public func recordTaskCompletion(
        context: IntelligenceTaskContext,
        result: IntelligenceTaskResult,
        tokensUsed: Int,
        responseTime: TimeInterval
    ) async {
        logger.info("Recording task completion: \(result.status.rawValue)")

        // 1. Record the completion interaction
        activityTracker.recordQuery(
            query: context.task,
            taskType: context.taskType,
            model: result.modelUsed ?? "unknown",
            tokensUsed: tokensUsed,
            responseTime: responseTime
        )

        // 2. Update learning based on result
        await updateLearningFromResult(context: context, result: result)

        // 3. Track tool usage if any
        for toolUse in result.toolsUsed {
            activityTracker.recordToolUse(
                toolName: toolUse.name,
                input: toolUse.input,
                output: toolUse.output,
                success: toolUse.success
            )
        }

        // 4. Record skill practice for matching skills
        for skill in context.matchingSkills {
            if let skillCategory = mapSkillToCategory(skill) {
                await recordSkillPractice(category: skillCategory)
            }
        }

        // 5. Update knowledge if new insights discovered
        if let newKnowledge = result.discoveredKnowledge {
            await addDiscoveredKnowledge(newKnowledge)
        }

        // 6. End session if task is complete
        if result.status == .completed || result.status == .failed {
            activityTracker.endSession()
        }

        // 7. Publish completion event
        EventBus.shared.publish(ComponentEvent(
            source: .system,
            action: "taskCompleted",
            component: "IntelligenceOrchestrator",
            details: [
                "status": result.status.rawValue,
                "tokensUsed": String(tokensUsed)
            ]
        ))

        currentContext = nil
    }

    // MARK: - Skill Integration

    private func loadMatchingSkills(
        taskType: TaskType,
        currentFile: String?,
        query: String
    ) async -> [SkillDefinition] {
        var allMatches: [SkillDefinition] = []

        // 1. Match by task type
        let taskTypeMatches = skillRegistry.findMatchingSkills(for: taskType)
        allMatches.append(contentsOf: taskTypeMatches)

        // 2. Match by current file pattern
        if let file = currentFile {
            let fileMatches = skillRegistry.findMatchingSkills(forFile: file)
            for match in fileMatches where !allMatches.contains(where: { $0.id == match.id }) {
                allMatches.append(match)
            }
        }

        // 3. Match by keywords in query
        let keywordMatches = skillRegistry.findMatchingSkills(forQuery: query)
        for match in keywordMatches where !allMatches.contains(where: { $0.id == match.id }) {
            allMatches.append(match)
        }

        logger.debug("Found \(allMatches.count) matching skills")
        return allMatches
    }

    private func loadKnowledgeAdditions(
        projectPath: String?,
        taskType: TaskType
    ) async -> [ProjectKnowledgeItem] {
        var items: [ProjectKnowledgeItem] = []

        // Get enabled knowledge items for this task type
        let allItems = knowledgeManager.activeKnowledge(for: projectPath)

        // Filter by relevance to task type
        let categoryForTask = mapTaskTypeToKnowledgeCategory(taskType)
        items = allItems.filter { item in
            item.category == categoryForTask || item.category == .guidelines
        }

        return items
    }

    private func loadLearningContext() async -> LearningContext {
        let profile = learningManager.userProfile
        let recommendations = learningManager.recommendedContent

        return LearningContext(
            experienceLevel: profile.experienceLevel,
            preferredStyle: profile.preferredLearningStyle,
            currentGoals: profile.learningGoals.filter { $0.status == .inProgress },
            relevantSkills: profile.skills,
            recommendations: Array(recommendations.prefix(3))
        )
    }

    // MARK: - Prompt Building

    private func buildEnhancedSystemPrompt(
        basePrompt: String,
        skills: [SkillDefinition],
        knowledge: [ProjectKnowledgeItem],
        learningContext: LearningContext,
        responseStyle: ResponseStyle
    ) -> String {
        var prompt = basePrompt

        // Add skill instructions
        if !skills.isEmpty {
            prompt += "\n\n## Applicable Skills\n"
            for skill in skills {
                prompt += "\n### \(skill.name)\n"
                prompt += skill.instructions
                prompt += "\n"
            }
        }

        // Add knowledge context
        if !knowledge.isEmpty {
            prompt += "\n\n## Project Knowledge\n"
            for item in knowledge {
                prompt += "\n### \(item.title)\n"
                prompt += item.content
                prompt += "\n"
            }
        }

        // Add response style guidance
        prompt += "\n\n## Response Guidelines\n"
        switch responseStyle.verbosity {
        case .concise:
            prompt += "- Be concise and direct\n"
        case .moderate:
            prompt += "- Provide moderate detail\n"
        case .detailed:
            prompt += "- Provide detailed explanations\n"
        }

        if responseStyle.codeExamples {
            prompt += "- Include code examples when relevant\n"
        }

        if responseStyle.visualAids {
            prompt += "- Suggest diagrams or visual representations when helpful\n"
        }

        // Add learning context if relevant
        if !learningContext.currentGoals.isEmpty {
            prompt += "\n## User Learning Goals\n"
            for goal in learningContext.currentGoals.prefix(2) {
                prompt += "- \(goal.title)\n"
            }
        }

        return prompt
    }

    private func getBasePromptForTaskType(_ taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration:
            return "You are an expert programmer. Write clean, maintainable code."
        case .codeRefactoring:
            return "You are a code quality expert. Improve code while preserving functionality."
        case .debugging:
            return "You are a debugging specialist. Identify and fix issues methodically."
        case .research:
            return "You are a thorough researcher. Gather comprehensive information."
        case .analysis:
            return "You are an analytical expert. Provide deep insights and recommendations."
        case .creative:
            return "You are a creative assistant. Generate innovative and engaging content."
        default:
            return "You are a helpful AI assistant."
        }
    }

    // MARK: - Learning Updates

    private func updateLearningFromResult(context: IntelligenceTaskContext, result: IntelligenceTaskResult) async {
        guard result.status == .completed else { return }

        // Update skill proficiency based on successful task completion
        for skill in context.matchingSkills {
            if let category = mapSkillToCategory(skill) {
                // Find or create skill in user profile
                if let existingSkill = learningManager.userProfile.skills.first(where: {
                    $0.category == category
                }) {
                    learningManager.recordPractice(skillId: existingSkill.id)
                }
            }
        }
    }

    private func recordSkillPractice(category: LearningSkillCategory) async {
        if let skill = learningManager.userProfile.skills.first(where: { $0.category == category }) {
            learningManager.recordPractice(skillId: skill.id)
        }
    }

    private func addDiscoveredKnowledge(_ knowledge: DiscoveredKnowledge) async {
        let item = ProjectKnowledgeItem(
            id: UUID(),
            title: knowledge.title,
            content: knowledge.content,
            scope: .project,
            category: knowledge.category,
            isEnabled: true,
            createdAt: Date(),
            updatedAt: Date(),
            tags: knowledge.tags,
            appliesTo: []
        )

        knowledgeManager.add(item)
        logger.info("Added discovered knowledge: \(knowledge.title)")
    }

    // MARK: - Event Handlers

    private func setupEventHandlers() {
        // Listen for autonomous agent events
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AutonomousAgentTestCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let result = notification.userInfo?["result"] as? TestResult else { return }
            Task { @MainActor in
                await self?.handleTestCompletion(result)
            }
        }

        // Listen for device command events
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VoiceCommandProcessed"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let command = notification.userInfo?["command"] as? DeviceVoiceCommand,
                  let result = notification.userInfo?["result"] as? DeviceVoiceCommandResult else { return }
            Task { @MainActor in
                await self?.handleVoiceCommand(command, result: result)
            }
        }
    }

    private func handleTestCompletion(_ result: TestResult) async {
        // Record test result as interaction
        activityTracker.recordInteraction(Interaction(
            type: .toolUse,
            details: InteractionDetails(
                toolName: "TestRunner",
                output: result.passed ? "All tests passed" : "\(result.failures.count) failures",
                success: result.passed
            )
        ))

        // Update learning if tests passed
        if result.passed {
            // Record practice for testing skills
            if let testingSkill = learningManager.userProfile.skills.first(where: {
                $0.name.lowercased().contains("testing") || $0.name.lowercased().contains("qa")
            }) {
                learningManager.recordPractice(skillId: testingSkill.id)
            }
        }
    }

    private func handleVoiceCommand(_ command: DeviceVoiceCommand, result: DeviceVoiceCommandResult) async {
        activityTracker.recordInteraction(Interaction(
            type: .query,
            details: InteractionDetails(
                query: command.utterance,
                success: result.success
            )
        ))
    }

    // MARK: - Utility Mappings

    private func mapSkillToCategory(_ skill: SkillDefinition) -> LearningSkillCategory? {
        // Map skill to learning category based on name/triggers
        let name = skill.name.lowercased()

        if name.contains("code") || name.contains("program") || name.contains("swift") {
            return .programming
        } else if name.contains("data") || name.contains("analytics") {
            return .dataScience
        } else if name.contains("ai") || name.contains("ml") || name.contains("model") {
            return .aiMl
        } else if name.contains("devops") || name.contains("deploy") || name.contains("ci") {
            return .devOps
        } else if name.contains("design") || name.contains("ui") || name.contains("ux") {
            return .design
        }

        return nil
    }

    private func mapTaskTypeToKnowledgeCategory(_ taskType: TaskType) -> ProjectKnowledgeCategory {
        switch taskType {
        case .codeGeneration, .codeRefactoring, .debugging:
            return .coding
        case .research, .analysis:
            return .guidelines
        case .creative:
            return .personas
        default:
            return .guidelines
        }
    }
}

// MARK: - Supporting Types

/// Complete context for a task, combining all intelligence systems
/// Prefixed to avoid conflict with TaskTypesProtocol.IntelligenceTaskContext
public struct IntelligenceTaskContext: Identifiable, Sendable {
    public let id: UUID
    public let task: String
    public let taskType: TaskType
    public let sessionId: UUID
    public let matchingSkills: [SkillDefinition]
    public let knowledgeItems: [ProjectKnowledgeItem]
    public let learningContext: LearningContext
    public let responseStyle: ResponseStyle
    public let enhancedSystemPrompt: String
    public let createdAt: Date
}

/// Learning context for personalization
public struct LearningContext: Sendable {
    public let experienceLevel: ExperienceLevel
    public let preferredStyle: LearningStyle
    public let currentGoals: [LearningGoal]
    public let relevantSkills: [LearningSkill]
    public let recommendations: [LearningContent]
}

/// Result of a completed task
/// Prefixed to avoid conflict with existing TaskResult types
public struct IntelligenceTaskResult: Sendable {
    public let status: IntelligenceTaskResultStatus
    public let modelUsed: String?
    public let toolsUsed: [ToolUsage]
    public let discoveredKnowledge: DiscoveredKnowledge?

    public init(
        status: IntelligenceTaskResultStatus,
        modelUsed: String? = nil,
        toolsUsed: [ToolUsage] = [],
        discoveredKnowledge: DiscoveredKnowledge? = nil
    ) {
        self.status = status
        self.modelUsed = modelUsed
        self.toolsUsed = toolsUsed
        self.discoveredKnowledge = discoveredKnowledge
    }
}

public enum IntelligenceTaskResultStatus: String, Sendable {
    case completed
    case failed
    case cancelled
    case inProgress
}

/// Record of a tool being used during task execution
public struct ToolUsage: Sendable {
    public let name: String
    public let input: String
    public let output: String
    public let success: Bool

    public init(name: String, input: String, output: String, success: Bool) {
        self.name = name
        self.input = input
        self.output = output
        self.success = success
    }
}

/// Knowledge discovered during task execution
public struct DiscoveredKnowledge: Sendable {
    public let title: String
    public let content: String
    public let category: ProjectKnowledgeCategory
    public let tags: [String]

    public init(title: String, content: String, category: ProjectKnowledgeCategory, tags: [String] = []) {
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
    }
}

/// Errors that can occur in the orchestrator
public enum OrchestratorError: Error, Sendable {
    case contextPreparationFailed(String)
    case skillLoadingFailed(String)
    case knowledgeLoadingFailed(String)
    case taskCompletionFailed(String)
}

// MARK: - Skill Enhancement Protocol

/// Protocol for any component that can be enhanced with skills
public protocol SkillEnhanceable {
    /// Apply skills to enhance this component's capabilities
    func applySkills(_ skills: [SkillDefinition]) async

    /// Get the current skill-enhanced configuration
    var appliedSkills: [SkillDefinition] { get }
}

// MARK: - Activity Recording Protocol

/// Protocol for components that should record their activity
public protocol ActivityRecordable {
    /// Record an activity interaction
    func recordActivity(type: InteractionType, details: InteractionDetails)
}

extension ActivityRecordable {
    public func recordActivity(type: InteractionType, details: InteractionDetails) {
        Task { @MainActor in
            ActivityTracker.shared.recordInteraction(Interaction(
                type: type,
                details: details
            ))
        }
    }
}
