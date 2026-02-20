// ChatManager+Tools.swift
// Thea
//
// B3: Tool execution pipeline integration
// C3: Semantic context injection (RAG)
// D3: Confidence feedback loop

import Foundation
import os.log
import SwiftData

private let toolsLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager+Tools")

extension ChatManager {

    // MARK: - B3: Tool Use Configuration

    /// Whether to use tool execution for this request.
    /// Enabled for Anthropic (Claude) models; disabled for agent team tasks.
    func shouldUseTools(for provider: any AIProvider, taskType: TaskType?) -> Bool {
        let isAnthropicProvider = provider.metadata.name.lowercased() == "anthropic"
        guard isAnthropicProvider else { return false }
        guard taskType != .workflowAutomation else { return false }
        return true
    }

    // MARK: - B3: Execute Stream With Tools

    /// Execute a streaming AI response with tool use support via ToolExecutionCoordinator.
    /// Falls back to standard streaming if API key unavailable or tools disabled.
    func executeStreamWithTools(
        provider: any AIProvider,
        model: String,
        messages: [AIMessage],
        assistantMessage: Message
    ) async throws {
        let apiKey: String
        do {
            apiKey = try SecureStorage.shared.loadAPIKey(for: "anthropic")
        } catch {
            toolsLogger.warning("B3: no Anthropic key, falling back to standard stream")
            try await executeStream(provider: provider, model: model,
                                    messages: messages, assistantMessage: assistantMessage)
            return
        }

        let tools = AnthropicToolCatalog.shared.buildToolsForAPI()
        toolsLogger.debug("B3: executing with \(tools.count) tools")

        var toolSteps: [ToolUseStep] = []

        let stream = await ToolExecutionCoordinator.shared.executeWithTools(
            messages: messages,
            model: model,
            apiKey: apiKey,
            tools: tools
        ) { [weak self] step in
            guard let self else { return }
            await self.handleToolStepUpdate(step, toolSteps: &toolSteps, assistantMessage: assistantMessage)
        }

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                streamingText += text
                assistantMessage.contentData = try JSONEncoder().encode(MessageContent.text(streamingText))

            case let .complete(finalMessage):
                assistantMessage.contentData = try JSONEncoder().encode(finalMessage.content)
                if !toolSteps.isEmpty {
                    var meta = assistantMessage.metadata ?? MessageMetadata()
                    meta.toolUseSteps = toolSteps
                    if let encoded = try? JSONEncoder().encode(meta) {
                        assistantMessage.metadataData = encoded
                    }
                }

            case let .error(error):
                throw error
            }
        }
    }

    @MainActor
    private func handleToolStepUpdate(
        _ step: ToolUseStep,
        toolSteps: inout [ToolUseStep],
        assistantMessage: Message
    ) {
        if let idx = toolSteps.firstIndex(where: { $0.id == step.id }) {
            toolSteps[idx] = step
        } else {
            toolSteps.append(step)
        }
        // Live metadata update so ChatView can observe tool steps as they run
        var meta = assistantMessage.metadata ?? MessageMetadata()
        meta.toolUseSteps = toolSteps
        if let encoded = try? JSONEncoder().encode(meta) {
            assistantMessage.metadataData = encoded
        }
        toolsLogger.debug("B3 tool step: \(step.toolName) running=\(step.isRunning)")
    }

    // MARK: - C3: Semantic Context Injection

    /// Inject semantically relevant past messages into the system prompt.
    /// Non-blocking; returns original prompt if search unavailable.
    func enrichSystemPromptWithSemanticContext(
        _ systemPrompt: String,
        for query: String,
        excluding currentConversation: Conversation
    ) async -> String {
        #if os(macOS)
        // Search across all conversations except the current one
        let otherConversations = conversations.filter { $0.id != currentConversation.id }
        guard !otherConversations.isEmpty else { return systemPrompt }

        let results = await SemanticSearchService.shared.search(
            query: query,
            in: otherConversations,
            mode: .hybrid,
            limit: 3
        )
        guard !results.isEmpty else { return systemPrompt }

        let snippets = results.map { r in
            "Past context (\(Int(r.score * 100))% relevant): \(String(r.messageContent.prefix(300)))"
        }.joined(separator: "\n")

        toolsLogger.debug("C3: injecting \(results.count) semantic snippets")
        return systemPrompt + "\n\n---\nRelevant past context:\n\(snippets)"
        #else
        return systemPrompt
        #endif
    }

    // MARK: - C3: Background Indexing

    /// Index all existing conversations for semantic search.
    /// Called once at app startup.
    func indexExistingConversationsForSemanticSearch() {
        #if os(macOS)
        Task(priority: .background) {
            for conversation in self.conversations {
                for message in conversation.messages where !message.content.textValue.isEmpty {
                    await SemanticSearchService.shared.indexMessage(message, in: conversation)
                }
            }
            toolsLogger.info("C3: background semantic indexing complete (\(self.conversations.count) conversations)")
        }
        #endif
    }

    // MARK: - D3: Confidence Feedback Loop

    /// Record confidence outcome to improve future routing.
    /// Called from runPostResponseActions after ConfidenceSystem scores a response.
    func recordConfidenceFeedback(
        taskType: TaskType?,
        modelId: String,
        confidenceScore: Double,
        originalQuery: String
    ) async {
        guard let taskType else { return }
        toolsLogger.debug("D3: confidence=\(String(format: "%.0f%%", confidenceScore * 100)) model=\(modelId) task=\(taskType.rawValue)")

        // Feed back to ModelRouter via synthetic RoutingDecision
        if let aiModel = AppConfiguration.shared.availableModels.first(where: { $0.id == modelId }) {
            let syntheticDecision = RoutingDecision(
                model: aiModel,
                provider: aiModel.provider,
                taskType: taskType,
                confidence: confidenceScore,
                reason: "ConfidenceSystem feedback",
                alternatives: []
            )
            await MainActor.run {
                ModelRouter.shared.recordOutcome(
                    for: syntheticDecision,
                    success: confidenceScore >= 0.5,
                    quality: confidenceScore,
                    latency: 0,
                    tokens: 0,
                    cost: 0
                )
            }
        }

        // Log misclassification if confidence is very low
        if confidenceScore < 0.4 {
            toolsLogger.warning("D3: low confidence for \(taskType.rawValue) → \(modelId). Consider reclassification.")
        }

        // Persist outcome for long-term learning
        if let context = modelContext {
            await MainActor.run {
                let outcome = ClassificationOutcome(
                    query: String(originalQuery.prefix(200)),
                    taskType: taskType.rawValue,
                    modelId: modelId,
                    confidenceScore: confidenceScore
                )
                context.insert(outcome)
                try? context.save()
            }
        }
    }
}
