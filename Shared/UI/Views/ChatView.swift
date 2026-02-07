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

    @Query private var allMessages: [Message]

    private var messages: [Message] {
        allMessages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }

    init(conversation: Conversation) {
        self.conversation = conversation
        _allMessages = Query(sort: \Message.timestamp)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                    LazyVStack(spacing: TheaSpacing.lg) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
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
                    .padding(.vertical, TheaSpacing.lg)
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
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
