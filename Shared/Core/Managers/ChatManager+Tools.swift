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
            guard let key = try SecureStorage.shared.loadAPIKey(for: "anthropic") else {
                toolsLogger.warning("B3: no Anthropic key stored, falling back to standard stream")
                try await executeStream(provider: provider, model: model,
                                        messages: messages, assistantMessage: assistantMessage)
                return
            }
            apiKey = key
        } catch {
            toolsLogger.warning("B3: error loading Anthropic key, falling back to standard stream")
            try await executeStream(provider: provider, model: model,
                                    messages: messages, assistantMessage: assistantMessage)
            return
        }

        let tools = AnthropicToolCatalog.shared.buildToolsForAPI()
        toolsLogger.debug("B3: executing with \(tools.count) tools")

        let stream = ToolExecutionCoordinator.shared.executeWithTools(
            messages: messages,
            model: model,
            apiKey: apiKey,
            tools: tools
        ) { @MainActor [weak self] step in
            guard let self else { return }
            self.updateLiveToolStep(step, on: assistantMessage)
        }

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                streamingText += text
                assistantMessage.contentData = try JSONEncoder().encode(MessageContent.text(streamingText))

            case let .complete(finalMessage):
                assistantMessage.contentData = try JSONEncoder().encode(finalMessage.content)
                // Tool steps already stored in metadataData by updateLiveToolStep callbacks above

            case let .error(error):
                throw error
            }
        }
    }

    /// Update a single tool step in the message metadata. Reads current steps from metadata,
    /// updates in-place (or appends), then writes back. Called on MainActor from the B3 callback.
    @MainActor
    private func updateLiveToolStep(_ step: ToolUseStep, on message: Message) {
        var meta = message.metadata ?? MessageMetadata()
        var steps = meta.toolUseSteps ?? []
        if let idx = steps.firstIndex(where: { $0.id == step.id }) {
            steps[idx] = step
        } else {
            steps.append(step)
        }
        meta.toolUseSteps = steps
        if let encoded = try? JSONEncoder().encode(meta) {
            message.metadataData = encoded
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
        // Construct a minimal AIModel from the ID (sufficient for ModelRouter.recordOutcome tracking)
        let providerName = ProviderRegistry.shared.getProvider(for: modelId)?.metadata.name ?? "unknown"
        let aiModel = AIModel(id: modelId, name: modelId, provider: providerName)
        let syntheticDecision = RoutingDecision(
            model: aiModel,
            provider: aiModel.provider,
            taskType: taskType,
            confidence: confidenceScore,
            reason: "ConfidenceSystem feedback",
            alternatives: [],
            timestamp: Date()
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
