import Combine
import Foundation
import os.log
@preconcurrency import SwiftData

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

private let chatLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager")

private func debugLog(_ message: String) {
    chatLogger.debug("\(message)")
}

@MainActor
final class ChatManager: ObservableObject {
    static let shared = ChatManager()

    @Published var activeConversation: Conversation?
    @Published var isStreaming: Bool = false
    @Published var streamingText: String = ""
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var messageQueue: [(text: String, conversation: Conversation)] = []

    /// Agent execution state for the current conversation
    @Published var agentState = AgentExecutionState()

    private var modelContext: ModelContext?

    private init() {}

    /// Save model context with error logging instead of silent `try?`
    private func saveContext(operation: String = #function) {
        do {
            try modelContext?.save()
        } catch {
            chatLogger.error("❌ Save failed in \(operation): \(error.localizedDescription)")
        }
    }

    // MARK: - Setup

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadConversations()
    }

    func configure(modelContext: ModelContext) {
        setModelContext(modelContext)
    }

    // MARK: - Conversation Management

    func loadConversations() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<Conversation>()
        descriptor.sortBy = [SortDescriptor(\.updatedAt, order: .reverse)]
        do {
            conversations = try context.fetch(descriptor)
        } catch {
            chatLogger.error("❌ Failed to load conversations: \(error.localizedDescription)")
            conversations = []
        }
    }

    func selectConversation(_ conversation: Conversation) {
        activeConversation = conversation
    }

    func createConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        modelContext?.insert(conversation)
        saveContext()
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        modelContext?.delete(conversation)
        saveContext()
        conversations.removeAll { $0.id == conversation.id }

        if activeConversation?.id == conversation.id {
            activeConversation = nil
        }
    }

    func clearAllData() {
        guard let context = modelContext else { return }

        // Delete all conversations (messages are cascade deleted)
        for conversation in conversations {
            context.delete(conversation)
        }
        try? context.save()

        conversations.removeAll()
        activeConversation = nil
        isStreaming = false
        streamingText = ""
    }

    func updateConversationTitle(_ conversation: Conversation, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        saveContext()
    }

    func togglePin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        saveContext()
    }

    func toggleArchive(_ conversation: Conversation) {
        conversation.isArchived.toggle()
        saveContext()
    }

    func toggleRead(_ conversation: Conversation) {
        if conversation.isRead {
            conversation.markAsUnread()
        } else {
            conversation.markAsViewed()
        }
        saveContext()
    }

    // MARK: - Auto Title Generation

    /// Generates a short title from the first user message when conversation still has the default title.
    private func autoGenerateTitle(for conversation: Conversation) {
        guard conversation.title == "New Conversation" else { return }

        // Find the first user message
        guard let firstUserMessage = conversation.messages
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .first(where: { $0.messageRole == .user })
        else { return }

        let text = firstUserMessage.content.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Generate a concise title: take the first sentence or first ~50 chars
        let title: String
        let sentenceEnd = text.firstIndex { ".!?".contains($0) }
        if let sentenceEnd, text.distance(from: text.startIndex, to: sentenceEnd) < 60 {
            title = String(text[...sentenceEnd])
        } else if text.count <= 50 {
            title = text
        } else {
            // Truncate at word boundary
            let truncated = String(text.prefix(50))
            if let lastSpace = truncated.lastIndex(of: " ") {
                title = String(truncated[..<lastSpace]) + "…"
            } else {
                title = truncated + "…"
            }
        }

        conversation.title = title
        debugLog("📝 Auto-generated title: '\(title)'")
    }

    // MARK: - Message Management

    func sendMessage(_ text: String, in conversation: Conversation) async throws {
        debugLog("📤 sendMessage: Starting with text '\(text.prefix(50))...'")

        // Check if this message should modify an active plan
        if let activePlan = PlanManager.shared.activePlan, activePlan.isActive {
            let isPlanModifying = detectPlanModificationIntent(text)
            if isPlanModifying {
                debugLog("📋 Detected plan modification intent, updating plan")
                // For now, add as a new step in the last phase
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
            debugLog("❌ No model context!")
            throw ChatError.noModelContext
        }

        // Check if offline — queue the message for later if no network
        if !OfflineQueueService.shared.isOnline {
            debugLog("📴 Offline — queuing message for later")
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
            // Queue for retry when online
            messageQueue.append((text: text, conversation: conversation))
            return
        }

        // Use the orchestrator system: classify task → route to optimal model
        debugLog("🔄 Selecting provider and model...")
        let (provider, model, taskType) = try await selectProviderAndModel(for: text)
        debugLog("✅ Selected provider '\(provider.metadata.name)' with model '\(model)'")

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
            debugLog("🤖 Agent mode: \(recommendedMode.rawValue) for \(taskType.rawValue)")
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
            debugLog("🔄 Starting chat stream...")
            let responseStream = try await provider.chat(
                messages: messagesToSend,
                model: model,
                stream: true
            )
            debugLog("✅ Got response stream, iterating...")

            for try await chunk in responseStream {
                switch chunk.type {
                case let .delta(text):
                    streamingText += text
                    assistantMessage.contentData = try JSONEncoder().encode(MessageContent.text(streamingText))
                    debugLog("📝 Received delta: '\(text.prefix(20))...'")

                case let .complete(finalMessage):
                    assistantMessage.contentData = try JSONEncoder().encode(finalMessage.content)
                    assistantMessage.tokenCount = finalMessage.tokenCount
                    if let metadata = finalMessage.metadata {
                        assistantMessage.metadataData = try? JSONEncoder().encode(metadata)
                    }
                    debugLog("✅ Received complete message")

                case let .error(error):
                    debugLog("❌ Received error in stream: \(error)")
                    throw error
                }
            }

            conversation.updatedAt = Date()

            // Auto-generate title from first user message if still default
            autoGenerateTitle(for: conversation)

            try context.save()
            debugLog("✅ Message saved successfully")

            // Post-response verification: run ConfidenceSystem asynchronously
            // Doesn't block response delivery — updates message metadata when done
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
                    debugLog("🔍 Confidence: \(String(format: "%.0f%%", result.overallConfidence * 100)) (\(result.level.rawValue))")
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
                    riskLevel: .low,
                    execute: {
                        // Action execution is task-specific — handled by AgentMode pipeline
                        AutonomousAction.ActionResult(success: true, message: "Evaluated")
                    }
                )
                let decision = await AutonomyController.shared.requestAction(action)
                switch decision {
                case .autoExecute:
                    debugLog("🤖 Autonomy: auto-execute approved for \(taskType.rawValue)")
                case let .requiresApproval(reason):
                    AutonomyController.shared.queueForApproval(action, reason: reason)
                    debugLog("🤖 Autonomy: queued for approval — \(reason)")
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
                    debugLog("📋 Auto-created plan with \(planSteps.count) steps")
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
            debugLog("❌ Error during chat: \(error)")
            context.delete(assistantMessage)
            conversation.messages.removeLast()
            // Still process queue on error so queued messages aren't lost
            processQueue()
            throw error
        }
    }

    /// Queue a message for sending. If currently streaming, it will be sent after the
    /// current response completes. If idle, sends immediately.
    func queueOrSendMessage(_ text: String, in conversation: Conversation) {
        if isStreaming {
            messageQueue.append((text: text, conversation: conversation))
            chatLogger.info("Queued message (\(self.messageQueue.count) pending)")
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
    private func processQueue() {
        guard !messageQueue.isEmpty else { return }
        let next = messageQueue.removeFirst()
        Task {
            try? await sendMessage(next.text, in: next.conversation)
        }
    }

    func cancelStreaming() {
        // Cancel ongoing streaming
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

    // MARK: - Message Branching

    /// Edit a user message and create a new branch — re-sends to AI
    func editMessageAndBranch(
        _ message: Message,
        newContent: String,
        in conversation: Conversation
    ) async throws {
        guard let context = modelContext else { throw ChatError.noModelContext }
        guard message.messageRole == .user else { return }

        // Count existing branches for this parent
        let parentId = message.parentMessageId ?? message.id
        let existingBranches = conversation.messages.filter {
            $0.parentMessageId == parentId || $0.id == parentId
        }
        let branchIndex = existingBranches.count

        // Create branched message
        let branchedMessage = message.createBranch(
            newContent: .text(newContent),
            branchIndex: branchIndex
        )
        conversation.messages.append(branchedMessage)
        context.insert(branchedMessage)

        // Delete assistant messages that followed the original in the same branch
        let messagesAfter = conversation.messages.filter {
            $0.orderIndex > message.orderIndex && $0.branchIndex == message.branchIndex
        }
        for msg in messagesAfter {
            context.delete(msg)
        }

        try context.save()

        // Re-send to get a new AI response for the branched message
        try await sendMessage(newContent, in: conversation)
    }

    /// Get all branches (sibling messages) for a given message
    func getBranches(for message: Message, in conversation: Conversation) -> [Message] {
        let parentId = message.parentMessageId ?? message.id
        return conversation.messages
            .filter { $0.id == parentId || $0.parentMessageId == parentId }
            .sorted { $0.branchIndex < $1.branchIndex }
    }

    /// Switch the visible branch for a message position
    func switchToBranch(
        _ branchIndex: Int,
        for message: Message,
        in conversation: Conversation
    ) -> Message? {
        let branches = getBranches(for: message, in: conversation)
        guard branchIndex >= 0, branchIndex < branches.count else { return nil }
        return branches[branchIndex]
    }

    // MARK: - Plan Mode Integration

    /// Detect whether a user message during plan execution is modifying the plan
    /// Uses keyword heuristics; will be upgraded to AI-based detection
    private func detectPlanModificationIntent(_ text: String) -> Bool {
        let lower = text.lowercased()
        let modifiers = [
            "also ", "additionally ", "add ", "don't forget ",
            "skip ", "remove ", "change ", "update ",
            "instead ", "actually ", "wait ", "hold on",
            "before that", "after that", "and also"
        ]
        return modifiers.contains { lower.contains($0) }
    }

    // MARK: - Orchestrator Integration

    /// Select provider and model using TaskClassifier + ModelRouter orchestration (macOS).
    /// Returns the classification result for automatic prompt engineering.
    private func selectProviderAndModel(for query: String) async throws -> (AIProvider, String, TaskType?) {
        #if os(macOS)
        do {
            let classification = try await TaskClassifier.shared.classify(query)
            let decision = ModelRouter.shared.route(classification: classification)
            if let provider = ProviderRegistry.shared.getProvider(id: decision.model.provider) {
                return (provider, decision.model.id, classification.taskType)
            }
        } catch {
            debugLog("⚠️ Orchestrator fallback: \(error.localizedDescription)")
        }
        #else
        _ = query
        #endif
        let (provider, model) = try getDefaultProviderAndModel()
        return (provider, model, nil)
    }

    /// Fallback: get default provider and model (original behavior)
    private func getDefaultProviderAndModel() throws -> (AIProvider, String) {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw ChatError.providerNotAvailable
        }
        let model = AppConfiguration.shared.providerConfig.defaultModel
        return (provider, model)
    }

    // MARK: - Vision OCR for Image Attachments

    #if os(macOS) || os(iOS)
    /// Extracts text from image parts in a multimodal message using VisionOCR.
    private func extractOCRFromImageParts(_ parts: [ContentPart]) async -> [String] {
        var ocrTexts: [String] = []
        for part in parts {
            if case let .image(imageData) = part.type {
                guard let cgImage = Self.cgImageFromData(imageData) else { continue }
                do {
                    let text = try await VisionOCR.shared.extractAllText(from: cgImage)
                    if !text.isEmpty {
                        ocrTexts.append(text)
                    }
                } catch {
                    debugLog("⚠️ VisionOCR failed for image attachment: \(error.localizedDescription)")
                }
            }
        }
        return ocrTexts
    }

    private static func cgImageFromData(_ data: Data) -> CGImage? {
        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data), let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return cgImage
        #elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
            return nil
        }
        return cgImage
        #else
        return nil
        #endif
    }
    #endif

    // MARK: - Device Context for AI

    /// Builds a device-aware context supplement for the system prompt.
    /// Tells the AI which device the user is currently on and which devices are in the ecosystem.
    private func buildDeviceContextPrompt() -> String {
        let current = DeviceRegistry.shared.currentDevice
        let allDevices = DeviceRegistry.shared.registeredDevices
        let onlineDevices = DeviceRegistry.shared.onlineDevices

        var lines: [String] = []
        lines.append("DEVICE CONTEXT:")
        lines.append("- Current device: \(current.name) (\(current.type.displayName), \(current.osVersion))")

        if current.capabilities.supportsLocalModels {
            lines.append("- This device supports local AI models")
        }

        #if os(macOS)
        let totalRAM = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        lines.append("- RAM: \(totalRAM) GB")
        #endif

        if allDevices.count > 1 {
            let others = allDevices.filter { $0.id != current.id }
            let otherNames = others.map { device in
                let status = onlineDevices.contains { $0.id == device.id } ? "online" : "offline"
                return "\(device.name) (\(device.type.displayName), \(status))"
            }
            lines.append("- Other devices in ecosystem: \(otherNames.joined(separator: ", "))")
        }

        lines.append("- User prompts from this conversation may originate from different devices (check message context).")

        return lines.joined(separator: "\n")
    }

    // MARK: - Automatic Prompt Engineering

    /// Generates task-specific system prompt instructions based on the classified task type.
    /// This enables the AI to respond more effectively without the user needing to craft prompts.
    static func buildTaskSpecificPrompt(for taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration, .appDevelopment:
            return """
            You are a senior software engineer. Write clean, production-ready code. \
            Follow best practices for the language. Include error handling. \
            Explain your design decisions briefly.
            """
        case .codeAnalysis:
            return """
            Analyze the code thoroughly. Identify potential bugs, performance issues, \
            security vulnerabilities, and style improvements. Be specific with line references.
            """
        case .codeDebugging, .debugging:
            return """
            Debug systematically. Identify the root cause, not just symptoms. \
            Explain why the bug occurs and provide a targeted fix. \
            Verify the fix doesn't introduce regressions.
            """
        case .codeExplanation:
            return """
            Explain the code clearly at the appropriate level of detail. \
            Walk through the logic step by step. Highlight key patterns and design decisions.
            """
        case .codeRefactoring:
            return """
            Refactor for clarity, maintainability, and performance. \
            Preserve existing behavior. Explain each change and its benefit. \
            Follow SOLID principles where applicable.
            """
        case .factual, .simpleQA:
            return """
            Provide accurate, well-sourced factual information. \
            Distinguish between established facts and your reasoning. \
            If uncertain, say so.
            """
        case .creative, .creativeWriting, .contentCreation, .creation:
            return """
            Be creative and engaging. Match the requested tone and style. \
            Offer multiple options or approaches when appropriate.
            """
        case .analysis, .complexReasoning:
            return """
            Analyze thoroughly with structured reasoning. Consider multiple perspectives. \
            Support conclusions with evidence. Identify assumptions and limitations.
            """
        case .research, .informationRetrieval:
            return """
            Research comprehensively. Organize findings clearly. \
            Cite sources when possible. Distinguish between primary and secondary information. \
            Note gaps in available information.
            """
        case .conversation, .general:
            return "" // No special instructions for casual conversation
        case .system, .workflowAutomation:
            return """
            Provide precise system commands and configurations. \
            Warn about potentially destructive operations. \
            Include verification steps.
            """
        case .math, .mathLogic:
            return """
            Show your work step by step. Use precise mathematical notation. \
            Verify your answer with a sanity check. Explain the approach before calculating.
            """
        case .translation:
            return """
            Translate accurately while preserving meaning, tone, and cultural nuance. \
            Note any idioms or phrases that don't translate directly. \
            Provide context where the translation might be ambiguous.
            """
        case .summarization:
            return """
            Summarize concisely while preserving key information. \
            Organize by importance. Include the main conclusions and supporting points. \
            Note any critical details that shouldn't be omitted.
            """
        case .planning:
            return """
            Create actionable plans with clear steps, dependencies, and priorities. \
            Identify risks and mitigation strategies. \
            Include time estimates where possible. Consider resource constraints.
            """
        case .unknown:
            return ""
        }
    }

    /// Extract numbered steps from an AI response for plan creation.
    /// Matches lines like "1. Do something" or "- Step one"
    static func extractPlanSteps(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var steps: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match "1. Step" or "1) Step"
            if let range = trimmed.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                let stepText = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !stepText.isEmpty {
                    steps.append(stepText)
                }
            }
        }

        return steps
    }
}

// MARK: - AI Message (for provider communication)

struct AIMessage: Sendable {
    let id: UUID
    let conversationID: UUID
    let role: MessageRole
    let content: MessageContent
    let timestamp: Date
    let model: String
    var tokenCount: Int?
    var metadata: MessageMetadata?

    init(
        id: UUID,
        conversationID: UUID,
        role: MessageRole,
        content: MessageContent,
        timestamp: Date,
        model: String,
        tokenCount: Int? = nil,
        metadata: MessageMetadata? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.model = model
        self.tokenCount = tokenCount
        self.metadata = metadata
    }
}

// MARK: - Errors

enum ChatError: Error, LocalizedError {
    case noModelContext
    case noUserMessage
    case providerNotAvailable
    case invalidAPIKey

    var errorDescription: String? {
        switch self {
        case .noModelContext:
            "Model context not available"
        case .noUserMessage:
            "No user message found"
        case .providerNotAvailable:
            "AI provider not available"
        case .invalidAPIKey:
            "Invalid API key"
        }
    }
}
