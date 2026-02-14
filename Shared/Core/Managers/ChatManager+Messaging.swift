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
        let responseStream = try await provider.chat(
            messages: messagesToSend,
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
                    assistantMessage.metadataData = try? JSONEncoder().encode(metadata)
                }

            case let .error(error):
                throw error
            }
        }
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
                assistantMessage.metadataData = try? JSONEncoder().encode(meta)
                try? assistantMessage.modelContext?.save()
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
            try? await CrossDeviceNotificationService.shared.notifyAIResponseReady(
                conversationId: conversation.id.uuidString,
                preview: preview
            )
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
