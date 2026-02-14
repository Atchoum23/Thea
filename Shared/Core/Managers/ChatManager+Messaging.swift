// ChatManager+Messaging.swift
// Thea V4 — Message sending, streaming, queue management
//
// Extracted from ChatManager.swift for file size compliance.

import Foundation
import os.log
import SwiftData

private let msgLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager+Messaging")

extension ChatManager {

    // MARK: - Message Sending

    func sendMessage(_ text: String, in conversation: Conversation) async throws {
        msgLogger.debug("📤 sendMessage: Starting with text '\(text.prefix(50))...'")

        handlePlanModificationIfNeeded(text)

        guard let context = modelContext else {
            msgLogger.error("❌ No model context!")
            throw ChatError.noModelContext
        }

        // Offline — queue for later
        if !OfflineQueueService.shared.isOnline {
            try queueOfflineMessage(text, in: conversation, context: context)
            return
        }

        // Classify task → route to optimal provider/model
        let (provider, model, taskType) = try await selectProviderAndModel(for: text)
        msgLogger.debug("✅ Selected provider '\(provider.metadata.name)' with model '\(model)'")

        // Auto-delegate complex tasks to sub-agents if enabled
        if shouldAutoDelegate(taskType: taskType, text: text) {
            if let session = await delegateToAgent(
                text: text, conversationID: conversation.id, taskType: taskType
            ) {
                // Create a user message to record the delegation in the conversation
                let currentDevice = DeviceRegistry.shared.currentDevice
                let userMessage = createUserMessage(text, in: conversation, device: currentDevice)
                conversation.messages.append(userMessage)
                context.insert(userMessage)

                // Create an assistant message indicating delegation
                let delegationText = "I've delegated this task to a specialized **\(session.agentType.displayName)** agent. "
                    + "You can monitor its progress in the Agents panel. "
                    + "I'll continue to be available for other requests while the agent works."
                let orderIndex = (conversation.messages.map(\.orderIndex).max() ?? -1) + 1
                let delegationMsg = Message(
                    conversationID: conversation.id,
                    role: .assistant,
                    content: .text(delegationText),
                    orderIndex: orderIndex,
                    deviceID: currentDevice.id,
                    deviceName: currentDevice.name,
                    deviceType: currentDevice.type.rawValue
                )
                delegationMsg.model = model
                conversation.messages.append(delegationMsg)
                context.insert(delegationMsg)
                try context.save()
                return
            }
        }

        configureAgentMode(for: taskType, text: text)

        // Create and persist user message
        let currentDevice = DeviceRegistry.shared.currentDevice
        let userMessage = createUserMessage(text, in: conversation, device: currentDevice)
        conversation.messages.append(userMessage)
        context.insert(userMessage)
        try context.save()

        // Build API messages (system prompt + conversation history)
        let apiMessages = await buildAPIMessages(
            for: conversation, model: model, taskType: taskType, device: currentDevice
        )

        // Stream AI response
        isStreaming = true
        streamingText = ""
        defer {
            isStreaming = false
            streamingText = ""
        }

        let assistantMessage = createAssistantMessage(in: conversation, model: model, device: currentDevice)
        conversation.messages.append(assistantMessage)
        context.insert(assistantMessage)

        do {
            try await streamResponse(
                provider: provider, model: model,
                apiMessages: apiMessages, assistantMessage: assistantMessage
            )

            conversation.updatedAt = Date()
            autoGenerateTitle(for: conversation)
            try context.save()

            await runPostResponseActions(
                text: text, taskType: taskType,
                assistantMessage: assistantMessage, conversation: conversation
            )

            processQueue()
        } catch {
            msgLogger.debug("❌ Error during chat: \(error)")
            context.delete(assistantMessage)
            conversation.messages.removeLast()
            processQueue()
            throw error
        }
    }

    // MARK: - Send Message Helpers

    private func handlePlanModificationIfNeeded(_ text: String) {
        guard let activePlan = PlanManager.shared.activePlan, activePlan.isActive else { return }
        guard detectPlanModificationIntent(text) else { return }

        msgLogger.debug("📋 Detected plan modification intent, updating plan")
        let newStep = PlanStep(
            title: String(text.prefix(80)),
            activeDescription: "Working on \(text.prefix(60).lowercased())...",
            taskType: "general"
        )
        let modification = PlanModification(
            type: .insertSteps([newStep], afterStepId: nil),
            reason: "User added new instruction mid-execution"
        )
        PlanManager.shared.applyModification(modification)
    }

    private func queueOfflineMessage(
        _ text: String, in conversation: Conversation, context: ModelContext
    ) throws {
        msgLogger.debug("📴 Offline — queuing message for later")
        let nextIndex = (conversation.messages.map(\.orderIndex).max() ?? -1) + 1
        let currentDevice = DeviceRegistry.shared.currentDevice
        let userMessage = Message(
            conversationID: conversation.id,
            role: .user,
            content: .text(text),
            orderIndex: nextIndex,
            deviceID: currentDevice.id,
            deviceName: currentDevice.name,
            deviceType: currentDevice.type.rawValue
        )
        conversation.messages.append(userMessage)
        context.insert(userMessage)
        try context.save()
        messageQueue.append((text: text, conversation: conversation))
    }

    private func configureAgentMode(for taskType: TaskType?, text: String) {
        guard let taskType else { return }
        let recommendedMode = AgentMode.recommended(for: taskType)
        agentState.mode = recommendedMode
        agentState.currentTask = AgentModeTask(
            title: String(text.prefix(80)),
            userQuery: text,
            taskType: taskType,
            mode: recommendedMode,
            status: .running
        )
        agentState.transition(to: .gatherContext)
        msgLogger.debug("🤖 Agent mode: \(recommendedMode.rawValue) for \(taskType.rawValue)")
    }

    private func createUserMessage(
        _ text: String, in conversation: Conversation, device: DeviceInfo
    ) -> Message {
        let nextIndex = (conversation.messages.map(\.orderIndex).max() ?? -1) + 1
        return Message(
            conversationID: conversation.id,
            role: .user,
            content: .text(text),
            orderIndex: nextIndex,
            deviceID: device.id,
            deviceName: device.name,
            deviceType: device.type.rawValue
        )
    }

    private func createAssistantMessage(
        in conversation: Conversation, model: String, device: DeviceInfo
    ) -> Message {
        let orderIndex = (conversation.messages.map(\.orderIndex).max() ?? -1) + 1
        let message = Message(
            conversationID: conversation.id,
            role: .assistant,
            content: .text(""),
            orderIndex: orderIndex,
            deviceID: device.id,
            deviceName: device.name,
            deviceType: device.type.rawValue
        )
        message.model = model
        return message
    }

    private func buildAPIMessages(
        for conversation: Conversation,
        model: String,
        taskType: TaskType?,
        device: DeviceInfo
    ) async -> [AIMessage] {
        var apiMessages: [AIMessage] = []
        let systemPrompt = buildFullSystemPrompt(for: conversation, taskType: taskType)

        apiMessages.append(AIMessage(
            id: UUID(),
            conversationID: conversation.id,
            role: .system,
            content: .text(systemPrompt),
            timestamp: Date.distantPast,
            model: model
        ))

        for msg in conversation.messages {
            var content = msg.content

            #if os(macOS) || os(iOS)
            if msg.messageRole == .user, case let .multimodal(parts) = msg.content {
                let ocrTexts = await extractOCRFromImageParts(parts)
                if !ocrTexts.isEmpty {
                    let ocrContext = "[Image text (OCR):\n\(ocrTexts.joined(separator: "\n---\n"))]"
                    content = .text("\(msg.content.textValue)\n\n\(ocrContext)")
                }
            }
            #endif

            if msg.messageRole == .user, let msgDeviceName = msg.deviceName,
               msgDeviceName != device.name
            {
                content = .text("[Sent from \(msgDeviceName)] \(content.textValue)")
            }

            apiMessages.append(AIMessage(
                id: msg.id,
                conversationID: msg.conversationID,
                role: msg.messageRole,
                content: content,
                timestamp: msg.timestamp,
                model: msg.model ?? model
            ))
        }
        return apiMessages
    }

    private func buildFullSystemPrompt(for conversation: Conversation, taskType: TaskType?) -> String {
        var parts: [String] = []

        if let taskType {
            let taskPrompt = Self.buildTaskSpecificPrompt(for: taskType)
            if !taskPrompt.isEmpty { parts.append(taskPrompt) }

            if taskType == .planning {
                parts.append(
                    """
                    IMPORTANT: Structure your response as a numbered plan with clear steps.
                    Start each step on its own line with a number and period (e.g., "1. Step description").
                    Keep each step concise and actionable.
                    """
                )
            }
        }

        if let customPrompt = conversation.metadata.systemPrompt, !customPrompt.isEmpty {
            parts.append(customPrompt)
        }

        if let preferredLanguage = conversation.metadata.preferredLanguage,
           !preferredLanguage.isEmpty,
           preferredLanguage.count <= 10,
           preferredLanguage.allSatisfy({ $0.isLetter || $0 == "-" }),
           let languageName = Locale.current.localizedString(forLanguageCode: preferredLanguage)
        {
            parts.append(
                "LANGUAGE: Respond entirely in \(languageName). " +
                    "Maintain technical accuracy and use language-appropriate formatting. " +
                    "If the user writes in a different language, still respond in \(languageName) unless asked otherwise."
            )
        }

        parts.append(buildDeviceContextPrompt())
        return parts.joined(separator: "\n\n")
    }

    private func streamResponse(
        provider: any AIProvider,
        model: String,
        apiMessages: [AIMessage],
        assistantMessage: Message
    ) async throws {
        var messagesToSend = apiMessages
        if SettingsManager.shared.cloudAPIPrivacyGuardEnabled {
            messagesToSend = await OutboundPrivacyGuard.shared.sanitizeMessages(apiMessages, channel: "cloud_api")
        }

        agentState.transition(to: .takeAction)

        // Retry with exponential backoff, then fallback to alternative provider
        let maxRetries = 2
        var lastError: Error?

        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = Self.retryDelay(attempt: attempt)
                msgLogger.info("⏳ Retrying stream (attempt \(attempt + 1)/\(maxRetries + 1)) after \(String(format: "%.1f", delay))s delay")
                try await Task.sleep(for: .seconds(delay))
                streamingText = "" // Reset accumulated text for retry
            }

            do {
                try await executeStream(
                    provider: provider, model: model,
                    messages: messagesToSend, assistantMessage: assistantMessage
                )
                return // Success — exit retry loop
            } catch {
                lastError = error
                if Self.isRetryableError(error) {
                    msgLogger.warning("⚠️ Stream failed with retryable error (attempt \(attempt + 1)): \(error.localizedDescription)")
                    continue
                } else {
                    msgLogger.error("❌ Stream failed with non-retryable error: \(error.localizedDescription)")
                    throw error
                }
            }
        }

        // All retries exhausted on primary provider — try fallback chain
        msgLogger.warning("⚠️ Primary provider exhausted, trying fallback chain")
        do {
            streamingText = ""
            let fallbackResult = try await ResilientAIFallbackChain.shared.chat(
                messages: messagesToSend, preferredModel: model, stream: false
            )
            let responseText = fallbackResult.response
            streamingText = responseText
            assistantMessage.contentData = try JSONEncoder().encode(MessageContent.text(responseText))
            msgLogger.info("✅ Fallback chain succeeded via \(fallbackResult.tier.rawValue)")
            return
        } catch {
            msgLogger.error("❌ Fallback chain also failed: \(error.localizedDescription)")
        }

        // Everything failed — throw the original error
        throw lastError ?? ChatError.providerNotAvailable
    }

    private func executeStream(
        provider: any AIProvider,
        model: String,
        messages: [AIMessage],
        assistantMessage: Message
    ) async throws {
        let responseStream = try await provider.chat(
            messages: messages,
            model: model,
            stream: true
        )

        for try await chunk in responseStream {
            switch chunk.type {
            case let .delta(text):
                streamingText += text
                assistantMessage.contentData = try JSONEncoder().encode(MessageContent.text(streamingText))

            case let .complete(finalMessage):
                assistantMessage.contentData = try JSONEncoder().encode(finalMessage.content)
                assistantMessage.tokenCount = finalMessage.tokenCount
                if let metadata = finalMessage.metadata {
                    do {
                        assistantMessage.metadataData = try JSONEncoder().encode(metadata)
                    } catch {
                        msgLogger.error("❌ Failed to encode message metadata: \(error.localizedDescription)")
                    }
                }

            case let .error(error):
                throw error
            }
        }
    }

    /// Exponential backoff with jitter: 1s, 2s, 4s (capped at 10s)
    static func retryDelay(attempt: Int) -> TimeInterval {
        let base = min(pow(2.0, Double(attempt)), 10.0)
        let jitter = Double.random(in: 0...0.5)
        return base + jitter
    }

    /// Determines if an error is retryable (timeouts, server errors, rate limits).
    static func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // URLSession timeout
        if nsError.domain == NSURLErrorDomain,
           [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost]
            .contains(nsError.code)
        {
            return true
        }
        // AnthropicError or similar provider errors with HTTP status
        let description = error.localizedDescription.lowercased()
        if description.contains("429") || description.contains("rate limit") { return true }
        if description.contains("500") || description.contains("502") ||
            description.contains("503") || description.contains("504")
        {
            return true
        }
        if description.contains("timeout") || description.contains("timed out") { return true }
        return false
    }

    private func runPostResponseActions(
        text: String, taskType: TaskType?,
        assistantMessage: Message, conversation: Conversation
    ) async {
        // Confidence verification
        #if os(macOS) || os(iOS)
        do {
            let responseText = streamingText
            let verificationTaskType = taskType ?? .general
            Task { @MainActor in
                let result = await ConfidenceSystem.shared.validateResponse(
                    responseText, query: text, taskType: verificationTaskType
                )
                var meta = assistantMessage.metadata ?? MessageMetadata()
                meta.confidence = result.overallConfidence
                do {
                    assistantMessage.metadataData = try JSONEncoder().encode(meta)
                    try assistantMessage.modelContext?.save()
                } catch {
                    msgLogger.error("❌ Failed to save confidence: \(error.localizedDescription)")
                }
                msgLogger.debug("🔍 Confidence: \(String(format: "%.0f%%", result.overallConfidence * 100))")
            }
        }
        #endif

        agentState.transition(to: .verifyResults)

        // Autonomy evaluation
        await evaluateAutonomy(for: taskType)

        agentState.transition(to: .done)
        agentState.currentTask?.status = .completed
        agentState.updateProgress(1.0, message: "Response complete")

        // Auto-create plan from planning responses
        autoCreatePlanIfNeeded(text: text, taskType: taskType, conversation: conversation)

        // Voice output routing
        if AudioOutputRouter.shared.isVoiceOutputActive {
            AudioOutputRouter.shared.routeResponse(streamingText)
        }

        // Response notifications
        let preview = streamingText
        Task {
            await ResponseNotificationHandler.shared.notifyResponseComplete(
                conversationId: conversation.id,
                conversationTitle: conversation.title,
                previewText: preview
            )
            do {
                try await CrossDeviceNotificationService.shared.notifyAIResponseReady(
                    conversationId: conversation.id.uuidString,
                    preview: preview
                )
            } catch {
                msgLogger.debug("Cross-device notification skipped: \(error.localizedDescription)")
            }
        }
    }

    private func evaluateAutonomy(for taskType: TaskType?) async {
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
            msgLogger.debug("🤖 Autonomy: auto-execute approved for \(taskType.rawValue)")
        case let .requiresApproval(reason):
            AutonomyController.shared.queueForApproval(action, reason: reason)
        }
    }

    private func autoCreatePlanIfNeeded(text: String, taskType: TaskType?, conversation: Conversation) {
        guard taskType == .planning, PlanManager.shared.activePlan == nil else { return }
        let planSteps = Self.extractPlanSteps(from: streamingText)
        guard planSteps.count >= 2 else { return }

        let planTitle = String(text.prefix(60))
        _ = PlanManager.shared.createSimplePlan(
            title: planTitle,
            steps: planSteps,
            conversationId: conversation.id
        )
        PlanManager.shared.startExecution()
        PlanManager.shared.showPanel()
        msgLogger.debug("📋 Auto-created plan with \(planSteps.count) steps")
    }

    // MARK: - Message Queue

    /// Queue a message for sending. If currently streaming, it will be sent after the
    /// current response completes. If idle, sends immediately.
    func queueOrSendMessage(_ text: String, in conversation: Conversation) {
        if isStreaming {
            messageQueue.append((text: text, conversation: conversation))
            msgLogger.info("Queued message (\(self.messageQueue.count) pending)")
        } else {
            Task {
                do {
                    try await sendMessage(text, in: conversation)
                } catch {
                    msgLogger.error("Failed to send message: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Remove a queued message at the given index
    func removeQueuedMessage(at index: Int) {
        guard messageQueue.indices.contains(index) else { return }
        messageQueue.remove(at: index)
    }

    /// Process the next queued message after streaming completes
    func processQueue() {
        guard !messageQueue.isEmpty else { return }
        let next = messageQueue.removeFirst()
        Task {
            do {
                try await sendMessage(next.text, in: next.conversation)
            } catch {
                msgLogger.error("Failed to process queued message: \(error.localizedDescription)")
            }
        }
    }

    func cancelStreaming() {
        isStreaming = false
        streamingText = ""
    }

    func deleteMessage(_ message: Message, from _: Conversation) {
        modelContext?.delete(message)
        saveContext()
    }

    func regenerateLastMessage(in conversation: Conversation) async throws {
        if let lastMessage = conversation.messages.last,
           lastMessage.messageRole == .assistant
        {
            deleteMessage(lastMessage, from: conversation)
        }

        guard let lastUserMessage = conversation.messages.last(where: { $0.messageRole == .user }) else {
            throw ChatError.noUserMessage
        }

        try await sendMessage(lastUserMessage.content.textValue, in: conversation)
    }
}
