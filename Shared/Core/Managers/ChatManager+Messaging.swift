// ChatManager+Messaging.swift
// Thea V4 — Message sending, streaming, queue management
//
// Extracted from ChatManager.swift for file size compliance.

import Foundation
import os.log

private let msgLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager+Messaging")

extension ChatManager {

    // MARK: - Message Sending

    func sendMessage(_ text: String, in conversation: Conversation) async throws {
        msgLogger.debug("📤 sendMessage: Starting with text '\(text.prefix(50))...'")

        // Check if this message should modify an active plan
        if let activePlan = PlanManager.shared.activePlan, activePlan.isActive {
            let isPlanModifying = detectPlanModificationIntent(text)
            if isPlanModifying {
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
        }

        guard let context = modelContext else {
            msgLogger.error("❌ No model context!")
            throw ChatError.noModelContext
        }

        // Check if offline — queue the message for later if no network
        if !OfflineQueueService.shared.isOnline {
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
            return
        }

        // Use the orchestrator system: classify task → route to optimal model
        msgLogger.debug("🔄 Selecting provider and model...")
        let (provider, model, taskType) = try await selectProviderAndModel(for: text)
        msgLogger.debug("✅ Selected provider '\(provider.metadata.name)' with model '\(model)'")

        // Set agent mode based on task classification
        if let taskType {
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

        // Calculate next order index for proper message ordering
        let existingIndices = conversation.messages.map(\.orderIndex)
        let nextUserIndex = (existingIndices.max() ?? -1) + 1

        // Create user message with orderIndex and device origin
        let currentDevice = DeviceRegistry.shared.currentDevice
        let userMessage = Message(
            conversationID: conversation.id,
            role: .user,
            content: .text(text),
            orderIndex: nextUserIndex,
            deviceID: currentDevice.id,
            deviceName: currentDevice.name,
            deviceType: currentDevice.type.rawValue
        )
        conversation.messages.append(userMessage)
        context.insert(userMessage)
        try context.save()

        // Prepare messages for API with device context
        let deviceContext = buildDeviceContextPrompt()
        var apiMessages: [AIMessage] = []

        // Build system prompt: task-specific instructions + user's custom prompt + device context
        var systemPromptParts: [String] = []

        // Automatic prompt engineering: add task-specific instructions based on classification
        if let taskType {
            let taskPrompt = Self.buildTaskSpecificPrompt(for: taskType)
            if !taskPrompt.isEmpty {
                systemPromptParts.append(taskPrompt)
            }

            // Plan Mode: ask AI to structure response with numbered steps
            if taskType == .planning {
                systemPromptParts.append(
                    """
                    IMPORTANT: Structure your response as a numbered plan with clear steps.
                    Start each step on its own line with a number and period (e.g., "1. Step description").
                    Keep each step concise and actionable.
                    """
                )
            }
        }

        if let customPrompt = conversation.metadata.systemPrompt, !customPrompt.isEmpty {
            systemPromptParts.append(customPrompt)
        }

        // Multilingual: inject language instruction when a preferred language is set
        // Security: validate language code to prevent injection (BCP-47, max 10 chars, letters+hyphens)
        if let preferredLanguage = conversation.metadata.preferredLanguage,
           !preferredLanguage.isEmpty,
           preferredLanguage.count <= 10,
           preferredLanguage.allSatisfy({ $0.isLetter || $0 == "-" }),
           Locale.current.localizedString(forLanguageCode: preferredLanguage) != nil
        {
            let languageName = Locale.current.localizedString(forLanguageCode: preferredLanguage) ?? preferredLanguage
            systemPromptParts.append(
                "LANGUAGE: Respond entirely in \(languageName). " +
                    "Maintain technical accuracy and use language-appropriate formatting. " +
                    "If the user writes in a different language, still respond in \(languageName) unless asked otherwise."
            )
        }

        systemPromptParts.append(deviceContext)
        let fullSystemPrompt = systemPromptParts.joined(separator: "\n\n")

        // Inject combined system message at the start
        apiMessages.append(AIMessage(
            id: UUID(),
            conversationID: conversation.id,
            role: .system,
            content: .text(fullSystemPrompt),
            timestamp: Date.distantPast,
            model: model
        ))

        // Add conversation messages with per-message device annotations and OCR
        for msg in conversation.messages {
            var content = msg.content

            // For user messages with image attachments, extract OCR text as context
            #if os(macOS) || os(iOS)
            if msg.messageRole == .user, case let .multimodal(parts) = msg.content {
                let ocrTexts = await extractOCRFromImageParts(parts)
                if !ocrTexts.isEmpty {
                    let ocrContext = "[Image text (OCR):\n\(ocrTexts.joined(separator: "\n---\n"))]"
                    let originalText = msg.content.textValue
                    content = .text("\(originalText)\n\n\(ocrContext)")
                }
            }
            #endif

            // Annotate user messages with their origin device if different from current
            if msg.messageRole == .user, let msgDeviceName = msg.deviceName,
               msgDeviceName != currentDevice.name
            {
                let annotation = "[Sent from \(msgDeviceName)]"
                let originalText = content.textValue
                content = .text("\(annotation) \(originalText)")
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

        // Stream response - use defer to ALWAYS reset streaming state
        isStreaming = true
        streamingText = ""

        defer {
            isStreaming = false
            streamingText = ""
        }

        // Calculate order index for assistant message (after user message was added)
        let assistantOrderIndex = (conversation.messages.map(\.orderIndex).max() ?? -1) + 1

        let assistantMessage = Message(
            conversationID: conversation.id,
            role: .assistant,
            content: .text(""),
            orderIndex: assistantOrderIndex,
            deviceID: currentDevice.id,
            deviceName: currentDevice.name,
            deviceType: currentDevice.type.rawValue
        )
        assistantMessage.model = model
        conversation.messages.append(assistantMessage)
        context.insert(assistantMessage)

        do {
            // Optional cloud API privacy guard: sanitize messages before sending to provider
            var messagesToSend = apiMessages
            if SettingsManager.shared.cloudAPIPrivacyGuardEnabled {
                messagesToSend = await OutboundPrivacyGuard.shared.sanitizeMessages(apiMessages, channel: "cloud_api")
            }

            agentState.transition(to: .takeAction)
            msgLogger.debug("🔄 Starting chat stream...")
            let responseStream = try await provider.chat(
                messages: messagesToSend,
                model: model,
                stream: true
            )
            msgLogger.debug("✅ Got response stream, iterating...")

            for try await chunk in responseStream {
                switch chunk.type {
                case let .delta(text):
                    streamingText += text
                    assistantMessage.contentData = try JSONEncoder().encode(MessageContent.text(streamingText))
                    msgLogger.debug("📝 Received delta: '\(text.prefix(20))...'")

                case let .complete(finalMessage):
                    assistantMessage.contentData = try JSONEncoder().encode(finalMessage.content)
                    assistantMessage.tokenCount = finalMessage.tokenCount
                    if let metadata = finalMessage.metadata {
                        assistantMessage.metadataData = try? JSONEncoder().encode(metadata)
                    }
                    msgLogger.debug("✅ Received complete message")

                case let .error(error):
                    msgLogger.debug("❌ Received error in stream: \(error)")
                    throw error
                }
            }

            conversation.updatedAt = Date()

            // Auto-generate title from first user message if still default
            autoGenerateTitle(for: conversation)

            try context.save()
            msgLogger.debug("✅ Message saved successfully")

            // Post-response verification: run ConfidenceSystem asynchronously
            #if os(macOS) || os(iOS)
            do {
                let verificationQuery = text
                let verificationResponse = streamingText
                let verificationTaskType = taskType ?? .general
                let messageToVerify = assistantMessage
                Task { @MainActor in
                    let result = await ConfidenceSystem.shared.validateResponse(
                        verificationResponse,
                        query: verificationQuery,
                        taskType: verificationTaskType
                    )
                    var meta = messageToVerify.metadata ?? MessageMetadata()
                    meta.confidence = result.overallConfidence
                    messageToVerify.metadataData = try? JSONEncoder().encode(meta)
                    try? messageToVerify.modelContext?.save()
                    msgLogger.debug("🔍 Confidence: \(String(format: "%.0f%%", result.overallConfidence * 100)) (\(result.level.rawValue))")
                }
            }
            #endif

            // Update agent state: transition to verification phase
            agentState.transition(to: .verifyResults)

            // Autonomy evaluation: check if response contains actionable tasks
            if AutonomyController.shared.autonomyLevel != .disabled,
               let taskType, taskType.isActionable
            {
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
                    msgLogger.debug("🤖 Autonomy: queued for approval — \(reason)")
                }
            }

            // Mark agent task complete
            agentState.transition(to: .done)
            agentState.currentTask?.status = .completed
            agentState.updateProgress(1.0, message: "Response complete")

            // Plan Mode: auto-create plan from planning-classified responses
            if taskType == .planning, PlanManager.shared.activePlan == nil {
                let responseText = streamingText
                let planSteps = Self.extractPlanSteps(from: responseText)
                if planSteps.count >= 2 {
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
            }

            // Route response through voice if BT audio device is active
            if AudioOutputRouter.shared.isVoiceOutputActive {
                AudioOutputRouter.shared.routeResponse(streamingText)
            }

            // Notify when response is complete (local + cross-device)
            let responsePreview = streamingText
            Task {
                await ResponseNotificationHandler.shared.notifyResponseComplete(
                    conversationId: conversation.id,
                    conversationTitle: conversation.title,
                    previewText: responsePreview
                )
                try? await CrossDeviceNotificationService.shared.notifyAIResponseReady(
                    conversationId: conversation.id.uuidString,
                    preview: responsePreview
                )
            }

            // Process next queued message if any
            processQueue()
        } catch {
            msgLogger.debug("❌ Error during chat: \(error)")
            context.delete(assistantMessage)
            conversation.messages.removeLast()
            processQueue()
            throw error
        }
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
