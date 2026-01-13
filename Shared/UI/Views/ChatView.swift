import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: Conversation

    @State private var chatManager = ChatManager.shared
    @State private var inputText = ""
    @State private var selectedProvider: AIProvider?
    @State private var selectedModel = AppConfiguration.shared.providerConfig.defaultModel
    @State private var showingError: Error?
    @State private var showingRenameDialog = false
    @State private var showingExportDialog = false
    @State private var showingAPIKeySetup = false
    @State private var newTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(conversation.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if chatManager.isStreaming {
                            MessageBubble(
                                message: Message(
                                    conversationID: conversation.id,
                                    role: .assistant,
                                    content: .text(chatManager.streamingText)
                                )
                            )
                            .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatManager.isStreaming) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // Input
            ChatInputView(
                text: $inputText,
                isStreaming: chatManager.isStreaming,
                onSend: sendMessage
            )
        }
        .navigationTitle(conversation.title)
        .navigationSubtitle("\(conversation.messages.count) messages")
        .toolbar {
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
            Button("Cancel", role: .cancel) { }
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
            if case .failure(let error) = result {
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

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if chatManager.isStreaming {
            withAnimation {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        } else if let lastMessage = conversation.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func setupProvider() async {
        // Get OpenAI API key from Keychain
        guard let apiKey = try? SecureStorage.shared.loadAPIKey(for: "openai") else {
            showingAPIKeySetup = true
            return
        }

        selectedProvider = OpenAIProvider(apiKey: apiKey)
    }

    private func sendMessage() {
        guard !inputText.isEmpty, selectedProvider != nil else { return }

        let text = inputText
        inputText = ""

        Task {
            do {
                try await chatManager.sendMessage(
                    text,
                    in: conversation
                )
            } catch {
                showingError = error
            }
        }
    }
}

// MARK: - Conversation Document

import UniformTypeIdentifiers

struct ConversationDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.json] }

    let conversation: Conversation

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    init(configuration: ReadConfiguration) throws {
        // Not implementing reading for now
        fatalError("Reading not supported")
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let exportData = ExportedConversation(
            title: conversation.title,
            messages: conversation.messages.map { message in
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("API Key") {
                    SecureField("Enter your OpenAI API key", text: $apiKey)

                    if let url = URL(string: "https://platform.openai.com/api-keys") {
                        Link("Get API Key →", destination: url)
                            .font(.caption)
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
        .frame(width: 450, height: 300)
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
