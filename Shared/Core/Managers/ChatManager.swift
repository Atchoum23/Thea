import Combine
import Foundation
import os.log
@preconcurrency import SwiftData

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

    private var modelContext: ModelContext?

    private init() {}

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
        conversations = (try? context.fetch(descriptor)) ?? []
    }

    func selectConversation(_ conversation: Conversation) {
        activeConversation = conversation
    }

    func createConversation(title: String = "New Conversation") -> Conversation {
        let conversation = Conversation(title: title)
        modelContext?.insert(conversation)
        try? modelContext?.save()
        conversations.insert(conversation, at: 0)
        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        modelContext?.delete(conversation)
        try? modelContext?.save()
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
        try? modelContext?.save()
    }

    func togglePin(_ conversation: Conversation) {
        conversation.isPinned.toggle()
        try? modelContext?.save()
    }

    func toggleArchive(_ conversation: Conversation) {
        conversation.isArchived.toggle()
        try? modelContext?.save()
    }

    func toggleRead(_ conversation: Conversation) {
        if conversation.isRead {
            conversation.markAsUnread()
        } else {
            conversation.markAsViewed()
        }
        try? modelContext?.save()
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
        let (provider, model) = try await selectProviderAndModel(for: text)
        debugLog("✅ Selected provider '\(provider.metadata.name)' with model '\(model)'")

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

        // Build system prompt: user's custom prompt + device context
        var systemPromptParts: [String] = []
        if let customPrompt = conversation.metadata.systemPrompt, !customPrompt.isEmpty {
            systemPromptParts.append(customPrompt)
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

        // Add conversation messages with per-message device annotations
        apiMessages += conversation.messages.map { msg in
            var content = msg.content
            // Annotate user messages with their origin device if different from current
            if msg.messageRole == .user, let msgDeviceName = msg.deviceName,
               msgDeviceName != currentDevice.name
            {
                let annotation = "[Sent from \(msgDeviceName)]"
                let originalText = msg.content.textValue
                content = .text("\(annotation) \(originalText)")
            }
            return AIMessage(
                id: msg.id,
                conversationID: msg.conversationID,
                role: msg.messageRole,
                content: content,
                timestamp: msg.timestamp,
                model: msg.model ?? model
            )
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
            debugLog("🔄 Starting chat stream...")
            let responseStream = try await provider.chat(
                messages: apiMessages,
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
        try? modelContext?.save()
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

    /// Select provider and model using TaskClassifier + ModelRouter orchestration (macOS)
    /// Falls back to default provider on other platforms
    private func selectProviderAndModel(for query: String) async throws -> (AIProvider, String) {
        #if os(macOS)
        do {
            let classification = try await TaskClassifier.shared.classify(query)
            let decision = ModelRouter.shared.route(classification: classification)
            if let provider = ProviderRegistry.shared.getProvider(id: decision.model.provider) {
                return (provider, decision.model.id)
            }
        } catch {
            debugLog("⚠️ Orchestrator fallback: \(error.localizedDescription)")
        }
        #else
        _ = query
        #endif
        return try getDefaultProviderAndModel()
    }

    /// Fallback: get default provider and model (original behavior)
    private func getDefaultProviderAndModel() throws -> (AIProvider, String) {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw ChatError.providerNotAvailable
        }
        let model = AppConfiguration.shared.providerConfig.defaultModel
        return (provider, model)
    }

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
