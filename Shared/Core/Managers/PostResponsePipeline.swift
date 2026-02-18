// PostResponsePipeline.swift
// Thea V4 — Post-response processing coordinator
//
// Extracted from ChatManager+Messaging.swift (SRP violation).
// ChatManager+Messaging was doing 8+ unrelated things after receiving an AI response:
// confidence verification, autonomy evaluation, plan creation, voice routing,
// follow-up suggestions, behavioral fingerprinting, memory extraction, notifications.
//
// This coordinator owns the post-response pipeline, keeping ChatManager focused
// on message sending and streaming.

import Foundation
import os.log

private let pipelineLogger = Logger(subsystem: "ai.thea.app", category: "PostResponsePipeline")

/// Coordinates all post-response processing actions after an AI response completes.
/// Each action is independent and failure-isolated — one action failing does not block others.
@MainActor
enum PostResponsePipeline {

    /// Context needed by the post-response pipeline.
    struct ResponseContext {
        let userQuery: String
        let responseText: String
        let taskType: TaskType?
        let assistantMessage: Message
        let conversation: Conversation
    }

    // MARK: - Pipeline Entry Point

    /// Run all post-response actions. Each action is failure-isolated.
    static func run(_ context: ResponseContext, agentState: AgentExecutionState) async {
        // 1. Confidence verification + hallucination detection
        runConfidenceVerification(context)

        // 2. Autonomy evaluation
        agentState.transition(to: .verifyResults)
        await evaluateAutonomy(for: context.taskType)

        // 3. Complete agent state
        agentState.transition(to: .done)
        agentState.currentTask?.status = .completed
        agentState.updateProgress(1.0, message: "Response complete")

        // 4. Auto-create plan from planning responses
        autoCreatePlanIfNeeded(context)

        // 5. Voice output routing
        routeToVoice(context.responseText)

        // 6. Follow-up suggestion generation
        generateFollowUpSuggestions(context)

        // 7. Record behavioral activity
        BehavioralFingerprint.shared.recordActivity(.communication)

        // 8. Extract entities into knowledge graph
        extractMemory(context.conversation)

        // 9. Send response notifications
        notifyResponseComplete(context)

        // 10. Record classification for TaskClassifier learning feedback loop
        recordClassificationLearning(context)
    }

    // MARK: - Individual Pipeline Stages

    private static func runConfidenceVerification(_ context: ResponseContext) {
        #if os(macOS) || os(iOS)
        let responseText = context.responseText
        let userQuery = context.userQuery
        let verificationTaskType = context.taskType ?? .general
        let assistantMessage = context.assistantMessage

        Task { @MainActor in
            let confidenceSystem = ConfidenceSystem.shared
            let result = await confidenceSystem.validateResponse(
                responseText, query: userQuery, taskType: verificationTaskType
            )

            let hallucinationFlags = await confidenceSystem.detectHallucinations(
                responseText, query: userQuery
            )

            var meta = assistantMessage.metadata ?? MessageMetadata()
            meta.confidence = result.overallConfidence
            if !hallucinationFlags.isEmpty {
                meta.hallucinationFlags = hallucinationFlags
            }
            do {
                assistantMessage.metadataData = try JSONEncoder().encode(meta)
                try assistantMessage.modelContext?.save()
            } catch {
                pipelineLogger.error("Failed to save confidence: \(error.localizedDescription)")
            }
            let flagCount = hallucinationFlags.count
            pipelineLogger.debug("Confidence: \(String(format: "%.0f%%", result.overallConfidence * 100)), hallucination flags: \(flagCount)")
        }
        #endif
    }

    private static func evaluateAutonomy(for taskType: TaskType?) async {
        guard AutonomyController.shared.autonomyLevel != .disabled,
              let taskType, taskType.isActionable
        else { return }

        let action = AutonomousAction(
            category: .analysis,
            title: "Execute suggested action from \(taskType.rawValue) response",
            description: "AI response for \(taskType.description) may contain actionable steps",
            riskLevel: .low
        ) {
            AutonomousAction.ActionResult(success: true, message: "Evaluated")
        }
        let decision = await AutonomyController.shared.requestAction(action)
        switch decision {
        case .autoExecute:
            pipelineLogger.debug("Autonomy: auto-execute approved for \(taskType.rawValue)")
        case let .requiresApproval(reason):
            AutonomyController.shared.queueForApproval(action, reason: reason)
        }
    }

    private static func autoCreatePlanIfNeeded(_ context: ResponseContext) {
        guard context.taskType == .planning, PlanManager.shared.activePlan == nil else { return }
        let planSteps = TaskPromptBuilder.extractPlanSteps(from: context.responseText)
        guard planSteps.count >= 2 else { return }

        let planTitle = String(context.userQuery.prefix(60))
        _ = PlanManager.shared.createSimplePlan(
            title: planTitle,
            steps: planSteps,
            conversationId: context.conversation.id
        )
        PlanManager.shared.startExecution()
        PlanManager.shared.showPanel()

        // Also register in TaskPlanDAG for DAG-based execution tracking
        Task { @MainActor in
            do {
                _ = try await TaskPlanDAG.shared.createPlan(
                    goal: context.userQuery,
                    context: context.responseText.prefix(2000).description
                )
            } catch {
                pipelineLogger.error("TaskPlanDAG.createPlan failed: \(error)")
            }
        }

        pipelineLogger.debug("Auto-created plan with \(planSteps.count) steps")
    }

    private static func routeToVoice(_ responseText: String) {
        if AudioOutputRouter.shared.isVoiceOutputActive {
            AudioOutputRouter.shared.routeResponse(responseText)
        }
    }

    private static func generateFollowUpSuggestions(_ context: ResponseContext) {
        let responseText = context.responseText
        let userQuery = context.userQuery
        let taskTypeRaw = context.taskType?.rawValue
        let assistantMessage = context.assistantMessage

        Task { @MainActor in
            let suggestions = FollowUpSuggestionService.shared.generate(
                response: responseText,
                query: userQuery,
                taskType: taskTypeRaw
            )
            if !suggestions.isEmpty {
                var meta = assistantMessage.metadata ?? MessageMetadata()
                meta.followUpSuggestions = suggestions
                do {
                    assistantMessage.metadataData = try JSONEncoder().encode(meta)
                    try assistantMessage.modelContext?.save()
                } catch {
                    pipelineLogger.error("Failed to save follow-up suggestions: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func extractMemory(_ conversation: Conversation) {
        Task { @MainActor in
            await ConversationMemoryExtractor.shared.extractFromConversation(conversation)
        }
    }

    private static func recordClassificationLearning(_ context: ResponseContext) {
        #if os(macOS)
        guard let taskType = context.taskType else { return }
        let result = ClassificationResult(
            taskType: taskType,
            confidence: 1.0,
            reasoning: "Post-response recording"
        )
        TaskClassifier.shared.recordClassification(
            query: context.userQuery,
            result: result
        )
        #endif
    }

    private static func notifyResponseComplete(_ context: ResponseContext) {
        let preview = context.responseText
        let conversationId = context.conversation.id
        let conversationTitle = context.conversation.title

        Task {
            await ResponseNotificationHandler.shared.notifyResponseComplete(
                conversationId: conversationId,
                conversationTitle: conversationTitle,
                previewText: preview
            )
            do {
                try await CrossDeviceNotificationService.shared.notifyAIResponseReady(
                    conversationId: conversationId.uuidString,
                    preview: preview
                )
            } catch {
                pipelineLogger.debug("Cross-device notification skipped: \(error.localizedDescription)")
            }
        }
    }
}
