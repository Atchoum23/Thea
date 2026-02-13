import Combine
import Foundation
import os.log
@preconcurrency import SwiftData

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private let messagingLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager+Messaging")

// MARK: - Message Sending & Queue

extension ChatManager {

    // MARK: - Send Message

    func sendMessage(_ text: String, in conversation: Conversation) async throws {
        messagingLogger.debug("sendMessage: Starting with text '\(text.prefix(50))...'")

        handlePlanModificationIfNeeded(text)

        guard let context = chatModelContext else {
            messagingLogger.debug("No model context!")
            throw ChatError.noModelContext
        }

        // Check if offline — queue the message for later if no network
        if try handleOfflineQueuing(text: text, conversation: conversation, context: context) {
            return
        }

        // Use the orchestrator system: classify task -> route to optimal model
        messagingLogger.debug("Selecting provider and model...")
        let (provider, model, taskType) = try await selectProviderAndModel(for: text)
        messagingLogger.debug("Selected provider '\(provider.metadata.name)' with model '\(model)'")

        // Create user message and insert into conversation
        let userMessage = createUserMessage(text: text, in: conversation, context: context)
        try context.save()

        // Build the full API message array (system prompt + conversation history)
        let apiMessages = await buildAPIMessages(
            for: conversation,
            model: model,
            taskType: taskType
        )

        // Stream the response from the AI provider
        try await streamResponse(
            provider: provider,
            model: model,
            taskType: taskType,
            apiMessages: apiMessages,
            userText: text,
            conversation: conversation,
            context: context
        )
    }

    /// Queue a message for sending. If currently streaming, it will be sent after the
    /// current response completes. If idle, sends immediately.
    func queueOrSendMessage(_ text: String, in conversation: Conversation) {
        if isStreaming {
            messageQueue.append((text: text, conversation: conversation))
            messagingLogger.info("Queued message (\(self.messageQueue.count) pending)")
        } else {
            Task {
                try? await sendMessage(text, in: conversation)
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
            try? await sendMessage(next.text, in: next.conversation)
        }
    }

    func cancelStreaming() {
        isStreaming = false
        streamingText = ""
    }

    func deleteMessage(_ message: Message, from _: Conversation) {
        chatModelContext?.delete(message)
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

    // MARK: - Send Message Helpers

    /// Check if the message should modify an active plan and apply modifications.
    func handlePlanModificationIfNeeded(_ text: String) {
        if let activePlan = PlanManager.shared.activePlan, activePlan.isActive {
            let isPlanModifying = detectPlanModificationIntent(text)
            if isPlanModifying {
                messagingLogger.debug("Detected plan modification intent, updating plan")
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
    }

    /// Queue message for later delivery if offline. Returns true if queued (caller should return).
    func handleOfflineQueuing(
        text: String,
        conversation: Conversation,
        context: ModelContext
    ) throws -> Bool {
        guard !OfflineQueueService.shared.isOnline else { return false }

        messagingLogger.debug("Offline — queuing message for later")
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
        return true
    }

    /// Create the user message, insert it into the conversation and context.
    @discardableResult
    func createUserMessage(
        text: String,
        in conversation: Conversation,
        context: ModelContext
    ) -> Message {
        let existingIndices = conversation.messages.map(\.orderIndex)
        let nextUserIndex = (existingIndices.max() ?? -1) + 1
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
        return userMessage
    }

    /// Build the full API message array including system prompt and conversation history.
    func buildAPIMessages(
        for conversation: Conversation,
        model: String,
        taskType: TaskType?
    ) async -> [AIMessage] {
        let deviceContext = buildDeviceContextPrompt()
        var apiMessages: [AIMessage] = []

        let fullSystemPrompt = buildSystemPrompt(
            conversation: conversation,
            taskType: taskType,
            deviceContext: deviceContext
        )

        apiMessages.append(AIMessage(
            id: UUID(),
            conversationID: conversation.id,
            role: .system,
            content: .text(fullSystemPrompt),
            timestamp: Date.distantPast,
            model: model
        ))

        let currentDevice = DeviceRegistry.shared.currentDevice

        for msg in conversation.messages {
            var content = msg.content

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

        return apiMessages
    }

    /// Assemble the system prompt from task-specific instructions, user prompt, language, and device context.
    func buildSystemPrompt(
        conversation: Conversation,
        taskType: TaskType?,
        deviceContext: String
    ) -> String {
        var systemPromptParts: [String] = []

        if let taskType {
            let taskPrompt = Self.buildTaskSpecificPrompt(for: taskType)
            if !taskPrompt.isEmpty {
                systemPromptParts.append(taskPrompt)
            }

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
        return systemPromptParts.joined(separator: "\n\n")
    }

    /// Stream the AI response, update the assistant message, and handle post-response actions.
    func streamResponse(
        provider: AIProvider,
        model: String,
        taskType: TaskType?,
        apiMessages: [AIMessage],
        userText: String,
        conversation: Conversation,
        context: ModelContext
    ) async throws {
        isStreaming = true
        streamingText = ""

        defer {
            isStreaming = false
            streamingText = ""
        }

        let assistantOrderIndex = (conversation.messages.map(\.orderIndex).max() ?? -1) + 1
        let currentDevice = DeviceRegistry.shared.currentDevice

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
            messagingLogger.debug("Starting chat stream...")
            let responseStream = try await provider.chat(
                messages: apiMessages,
                model: model,
                stream: true
            )
            messagingLogger.debug("Got response stream, iterating...")

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
                    messagingLogger.debug("Received error in stream: \(error)")
                    throw error
                }
            }

            conversation.updatedAt = Date()
            autoGenerateTitle(for: conversation)
            try context.save()
            messagingLogger.debug("Message saved successfully")

            handlePostResponseActions(
                taskType: taskType,
                userText: userText,
                conversation: conversation
            )

            processQueue()
        } catch {
            messagingLogger.debug("Error during chat: \(error)")
            context.delete(assistantMessage)
            conversation.messages.removeLast()
            processQueue()
            throw error
        }
    }

    /// Handle plan creation, voice routing, and notifications after a successful response.
    func handlePostResponseActions(
        taskType: TaskType?,
        userText: String,
        conversation: Conversation
    ) {
        if taskType == .planning, PlanManager.shared.activePlan == nil {
            let responseText = streamingText
            let planSteps = Self.extractPlanSteps(from: responseText)
            if planSteps.count >= 2 {
                let planTitle = String(userText.prefix(60))
                _ = PlanManager.shared.createSimplePlan(
                    title: planTitle,
                    steps: planSteps,
                    conversationId: conversation.id
                )
                PlanManager.shared.startExecution()
                PlanManager.shared.showPanel()
                messagingLogger.debug("Auto-created plan with \(planSteps.count) steps")
            }
        }

        if AudioOutputRouter.shared.isVoiceOutputActive {
            AudioOutputRouter.shared.routeResponse(streamingText)
        }

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
    }
}
