@preconcurrency import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Unified Chat View

/// Cross-platform chat view using shared components.
/// Adapts horizontal padding via environment size class.
/// Uses shared MessageBubble, ChatInputView, StreamingMessageView, and WelcomeView.
struct ChatView: View {
    let conversation: Conversation

    @State private var chatManager = ChatManager.shared
    @State private var planManager = PlanManager.shared
    @State private var inputText = ""
    @State private var selectedProvider: AIProvider?
    @State private var showingError: Error?
    @State private var showingRenameDialog = false
    @State private var showingExportDialog = false
    @State private var showingAPIKeySetup = false
    @State private var newTitle = ""
    @StateObject private var settingsManager = SettingsManager.shared

    /// Message being edited (triggers edit sheet)
    @State private var editingMessage: Message?

    /// Tracks which branch index is selected for each parent message ID
    @State private var selectedBranches: [UUID: Int] = [:]

    /// Search state
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchMatchIndex = 0

    @Query private var allMessages: [Message]

    /// All messages for this conversation, sorted by time
    private var allConversationMessages: [Message] {
        allMessages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Messages filtered to show only the currently-selected branch for each message position
    private var messages: [Message] {
        var result: [Message] = []
        var seenParents = Set<UUID>()

        for msg in allConversationMessages {
            let parentId = msg.parentMessageId ?? msg.id

            // Skip if we already picked a branch for this parent
            guard !seenParents.contains(parentId) else { continue }

            // Find all siblings (branches) for this parent
            let siblings = allConversationMessages.filter {
                $0.id == parentId || $0.parentMessageId == parentId
            }

            if siblings.count <= 1 {
                // No branching — just show the message
                result.append(msg)
            } else {
                // Pick the branch the user selected (default 0 = original)
                let selectedIdx = selectedBranches[parentId] ?? 0
                let sorted = siblings.sorted { $0.branchIndex < $1.branchIndex }
                if selectedIdx < sorted.count {
                    result.append(sorted[selectedIdx])
                } else {
                    result.append(sorted[0])
                }
            }

            seenParents.insert(parentId)
        }

        return result
    }

    init(conversation: Conversation) {
        self.conversation = conversation
        _allMessages = Query(sort: \Message.timestamp)
    }

    /// Messages matching the current search query
    private var searchMatches: [Message] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return messages.filter { $0.content.textValue.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            if isSearching {
                chatSearchBar
            }
            #endif
            messageList
            chatInput
        }
        .overlay(alignment: .bottomTrailing) {
            if planManager.isPanelCollapsed && planManager.activePlan?.isActive == true {
                CompactPlanBar()
                    .padding(TheaSpacing.lg)
            }
        }
        #if os(macOS) || os(iOS)
        .inspector(isPresented: $planManager.isPanelVisible) {
            PlanPanel()
                .inspectorColumnWidth(min: 300, ideal: 400, max: 500)
        }
        #endif
        .navigationTitle(conversation.title)
        #if os(macOS)
            .navigationSubtitle("\(messages.count) messages")
        #endif
            .toolbar {
                ToolbarItem {
                    // Plan toggle — only visible when a plan exists
                    if planManager.activePlan != nil {
                        Button {
                            planManager.togglePanel()
                        } label: {
                            Label("Plan", systemImage: "list.bullet.clipboard")
                        }
                        .help("Toggle plan panel")
                    }
                }

                #if os(macOS)
                ToolbarItem {
                    Button {
                        isSearching.toggle()
                        if !isSearching {
                            searchText = ""
                            searchMatchIndex = 0
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    .help("Search in conversation (⌘F)")
                }
                #endif

                ToolbarItem {
                    ConversationLanguagePickerView(conversation: conversation)
                        .help("Set conversation language")
                }

                ToolbarItem {
                    Menu {
                        Button("Rename") {
                            newTitle = conversation.title
                            showingRenameDialog = true
                        }

                        Button("Export") {
                            showingExportDialog = true
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            ChatManager.shared.deleteConversation(conversation)
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .alert("Rename Conversation", isPresented: $showingRenameDialog) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    conversation.title = newTitle
                }
            } message: {
                Text("Enter a new name for this conversation")
            }
            .fileExporter(
                isPresented: $showingExportDialog,
                document: ConversationDocument(conversation: conversation),
                contentType: .json,
                defaultFilename: "\(conversation.title).json"
            ) { result in
                if case let .failure(error) = result {
                    showingError = error
                }
            }
            .sheet(isPresented: $showingAPIKeySetup) {
                APIKeySetupView()
            }
            .alert(error: $showingError)
            .task {
                await setupProvider()
            }
            .sheet(item: $editingMessage) { message in
                MessageEditSheet(
                    originalMessage: message,
                    onSave: { newText in
                        editingMessage = nil
                        Task {
                            try? await chatManager.editMessageAndBranch(
                                message, newContent: newText, in: conversation
                            )
                        }
                    },
                    onCancel: {
                        editingMessage = nil
                    }
                )
            }
    }

    // MARK: - Density-Aware Spacing

    private var messageSpacing: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.xxl
        default: TheaSpacing.lg
        }
    }

    private var messagePadding: CGFloat {
        switch settingsManager.messageDensity {
        case "compact": TheaSpacing.sm
        case "spacious": TheaSpacing.xxl
        default: TheaSpacing.lg
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !chatManager.isStreaming {
                    WelcomeView { prompt in
                        inputText = prompt
                        sendMessage()
                    }
                } else {
                    LazyVStack(spacing: messageSpacing) {
                        // When streaming, hide the last assistant message to avoid duplicate display
                        let displayMessages = chatManager.isStreaming
                            ? messages.filter { msg in
                                if msg.messageRole == .assistant, msg.id == messages.last(where: { $0.messageRole == .assistant })?.id {
                                    return false
                                }
                                return true
                            }
                            : messages

                        ForEach(displayMessages) { message in
                            MessageBubble(
                                message: message,
                                onEdit: { msg in
                                    editingMessage = msg
                                },
                                onRegenerate: { msg in
                                    Task {
                                        try? await chatManager.editMessageAndBranch(
                                            msg, newContent: msg.content.textValue,
                                            in: conversation
                                        )
                                    }
                                },
                                onAction: { action, msg in
                                    handleMessageAction(action, message: msg)
                                },
                                branchInfo: branchInfo(for: message)
                            )
                            .id(message.id)
                            #if os(macOS)
                            .overlay(
                                RoundedRectangle(cornerRadius: TheaCornerRadius.lg)
                                    .stroke(
                                        isCurrentSearchMatch(message) ? Color.accentColor : .clear,
                                        lineWidth: 2
                                    )
                            )
                            .opacity(searchDimOpacity(for: message))
                            #endif
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }

                        if chatManager.isStreaming {
                            StreamingMessageView(
                                streamingText: chatManager.streamingText,
                                status: chatManager.streamingText.isEmpty ? .thinking : .generating
                            )
                            .id("streaming")
                        }
                    }
                    .padding(.horizontal, TheaSpacing.xxl)
                    .padding(.vertical, messagePadding)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: searchMatchIndex) { _, newIndex in
                if newIndex < searchMatches.count {
                    withAnimation(TheaAnimation.smooth) {
                        proxy.scrollTo(searchMatches[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Chat Input

    private var chatInput: some View {
        #if os(macOS)
            ChatInputView(
                text: $inputText,
                isStreaming: chatManager.isStreaming
            ) {
                if chatManager.isStreaming {
                    chatManager.cancelStreaming()
                } else {
                    sendMessage()
                }
            }
        #else
            HStack(spacing: TheaSpacing.md) {
                TextField("Message Thea...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1 ... 6)
                    .disabled(chatManager.isStreaming)
                    .onSubmit {
                        if !inputText.isEmpty {
                            sendMessage()
                        }
                    }
                    .padding(.horizontal, TheaSpacing.lg)
                    .padding(.vertical, TheaSpacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.xl))

                Button {
                    if chatManager.isStreaming {
                        chatManager.cancelStreaming()
                    } else {
                        sendMessage()
                    }
                } label: {
                    Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isStreaming
                                ? Color.theaPrimaryDefault : .secondary
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatManager.isStreaming)
                .accessibilityLabel(chatManager.isStreaming ? "Stop generating" : "Send message")
            }
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.md)
        #endif
    }

    // MARK: - Search

    #if os(macOS)
    private var chatSearchBar: some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search messages…", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    navigateSearch(forward: true)
                }

            if !searchText.isEmpty {
                Text("\(searchMatches.isEmpty ? 0 : searchMatchIndex + 1)/\(searchMatches.count)")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button { navigateSearch(forward: false) } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(searchMatches.isEmpty)

                Button { navigateSearch(forward: true) } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(searchMatches.isEmpty)
            }

            Button {
                isSearching = false
                searchText = ""
                searchMatchIndex = 0
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, TheaSpacing.lg)
        .padding(.vertical, TheaSpacing.sm)
        .background(.bar)
    }

    private func navigateSearch(forward: Bool) {
        guard !searchMatches.isEmpty else { return }
        if forward {
            searchMatchIndex = (searchMatchIndex + 1) % searchMatches.count
        } else {
            searchMatchIndex = (searchMatchIndex - 1 + searchMatches.count) % searchMatches.count
        }
    }

    private func isCurrentSearchMatch(_ message: Message) -> Bool {
        !searchMatches.isEmpty
            && searchMatchIndex < searchMatches.count
            && searchMatches[searchMatchIndex].id == message.id
    }

    private func searchDimOpacity(for message: Message) -> Double {
        guard isSearching, !searchText.isEmpty else { return 1.0 }
        let isMatch = message.content.textValue.localizedCaseInsensitiveContains(searchText)
        return isMatch ? 1.0 : 0.4
    }
    #endif

    // MARK: - Branching

    /// Compute branch info for a message (nil if no branches exist)
    private func branchInfo(for message: Message) -> MessageBubble.BranchInfo? {
        let branches = chatManager.getBranches(for: message, in: conversation)
        guard branches.count > 1 else { return nil }

        let currentIdx = selectedBranches[message.parentMessageId ?? message.id] ?? 0
        let parentId = message.parentMessageId ?? message.id

        return MessageBubble.BranchInfo(
            currentIndex: currentIdx,
            totalCount: branches.count
        ) { newIndex in
            selectedBranches[parentId] = newIndex
        }
    }

    /// Handle message actions from the MessageBubble context menu / hover bar
    private func handleMessageAction(_ action: MessageAction, message: Message) {
        switch action {
        case .copy:
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content.textValue, forType: .string)
            #else
            UIPasteboard.general.string = message.content.textValue
            #endif

        case .edit:
            editingMessage = message

        case .regenerate:
            Task {
                try? await chatManager.editMessageAndBranch(
                    message, newContent: message.content.textValue, in: conversation
                )
            }

        case .deleteMessage:
            chatManager.deleteMessage(message, from: conversation)

        case .continueFromHere:
            Task {
                try? await chatManager.sendMessage("Continue", in: conversation)
            }

        default:
            break
        }
    }

    // MARK: - Actions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(TheaAnimation.smooth) {
            if chatManager.isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func setupProvider() async {
        let hasLocalModels = !ProviderRegistry.shared.getAvailableLocalModels().isEmpty

        if let apiKey = try? SecureStorage.shared.loadAPIKey(for: "openai") {
            selectedProvider = OpenAIProvider(apiKey: apiKey)
        } else if hasLocalModels {
            selectedProvider = ProviderRegistry.shared.getLocalProvider()
        } else {
            showingAPIKeySetup = true
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""

        Task {
            do {
                try await chatManager.sendMessage(text, in: conversation)
            } catch {
                showingError = error
                inputText = text
            }
        }
    }
}

// MARK: - Conversation Document

struct ConversationDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.json] }

    let conversation: Conversation

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    init(configuration _: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme, userInfo: [
            NSLocalizedDescriptionKey: "Reading conversation files is not supported. This document type is for export only."
        ])
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        let exportData = ExportedConversation(
            title: conversation.title,
            messages: conversation.messages.sorted { $0.orderIndex < $1.orderIndex }.map { message in
                ExportedMessage(
                    role: message.role,
                    content: message.content.textValue,
                    timestamp: message.timestamp
                )
            },
            createdAt: conversation.createdAt
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportData)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ExportedConversation: Codable {
    let title: String
    let messages: [ExportedMessage]
    let createdAt: Date
}

struct ExportedMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date
}

// MARK: - API Key Setup View

struct APIKeySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("To use THEA's chat features, you need to add an OpenAI API key.")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }

                Section("API Key") {
                    SecureField("Enter your OpenAI API key", text: $apiKey)

                    if let url = URL(string: "https://platform.openai.com/api-keys") {
                        Link("Get API Key →", destination: url)
                            .font(.theaCaption1)
                    }
                }

                Section {
                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Setup API Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 450, height: 300)
        #endif
    }

    private func saveAPIKey() {
        Task {
            do {
                try SecureStorage.shared.saveAPIKey(apiKey, for: "openai")
                dismiss()
            } catch {
                print("Failed to save API key: \(error)")
            }
        }
    }
}

// MARK: - Error Alert

extension View {
    func alert(error: Binding<Error?>) -> some View {
        alert(
            "Error",
            isPresented: .constant(error.wrappedValue != nil),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK") {
                error.wrappedValue = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
