@preconcurrency import SwiftData
import SwiftUI

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
                        ForEach(conversation.messages.sorted { $0.orderIndex < $1.orderIndex }) { message in
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
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal)

                Button(action: sendMessage) {
                    Image(systemName: chatManager.isStreaming ? "stop.circle.fill" : "paperplane.fill")
                        .foregroundStyle(inputText.isEmpty && !chatManager.isStreaming ? .secondary : .primary)
                }
                .buttonStyle(.borderless)
                .disabled(inputText.isEmpty && !chatManager.isStreaming)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle(conversation.title)
        #if os(macOS)
            .navigationSubtitle("\(conversation.messages.count) messages")
        #endif
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
        // The orchestrator handles provider selection automatically.
        // Local models don't need API keys, so we only show the setup
        // dialog if NO providers are available at all.

        // Check if we have any local models available
        let hasLocalModels = !ProviderRegistry.shared.getAvailableLocalModels().isEmpty

        // Try to get OpenAI API key from Keychain
        if let apiKey = try? SecureStorage.shared.loadAPIKey(for: "openai") {
            selectedProvider = OpenAIProvider(apiKey: apiKey)
        } else if hasLocalModels {
            // Local models available - no need for API key setup
            // The orchestrator will route to local models
            selectedProvider = ProviderRegistry.shared.getLocalProvider()
        } else {
            // No local models AND no cloud API key - prompt for setup
            showingAPIKeySetup = true
        }
    }

    private func sendMessage() {
        // Debug logging helper - platform-aware
        func log(_ msg: String) {
            #if os(macOS)
            let logFile = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/thea_debug.log")
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] [ChatView] \(msg)\n"
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let handle = try? FileHandle(forUpdating: logFile) {
                        _ = try? handle.seekToEnd()
                        _ = try? handle.write(contentsOf: data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: logFile)
                }
            }
            #else
            print("[ChatView] \(msg)")
            #endif
        }

        log("📤 sendMessage() called, inputText='\(inputText.prefix(30))...'")

        guard !inputText.isEmpty else {
            log("⚠️ inputText is empty, returning early")
            return
        }

        // Note: We no longer require selectedProvider to be set here.
        // The orchestrator in ChatManager.sendMessage() handles provider selection,
        // including routing to local MLX models when appropriate.

        let text = inputText
        log("✅ Captured text, clearing inputText...")
        inputText = ""

        Task {
            do {
                log("🔄 Starting chatManager.sendMessage...")
                try await chatManager.sendMessage(
                    text,
                    in: conversation
                )
                log("✅ chatManager.sendMessage completed")
            } catch {
                log("❌ Error: \(error)")
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

    init(configuration _: ReadConfiguration) throws {
        // Reading from file not supported - this is an export-only document type
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
