import SwiftUI

// MARK: - Enhanced Chat View

struct TVEnhancedChatView: View {
    @ObservedObject var inferenceClient: RemoteInferenceClient
    @State private var messages: [TVChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var activeRequestId: String?
    @State private var suggestedPrompts: [String] = [
        "What's on my calendar today?",
        "Find new releases this week",
        "Check download queue status",
        "What should I watch tonight?"
    ]
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBanner

                if messages.isEmpty {
                    welcomeView
                } else {
                    messagesList
                }

                inputArea
            }
            .navigationTitle("Thea")
        }
        .onAppear { setupStreamCallbacks() }
    }

    // MARK: - Connection Banner

    @ViewBuilder
    private var connectionBanner: some View {
        if !inferenceClient.connectionState.isConnected {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Not connected to Mac -- responses are simulated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 120))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Welcome to THEA")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your AI Life Companion")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Text("Try asking:")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    ForEach(suggestedPrompts.prefix(4), id: \.self) { prompt in
                        Button {
                            inputText = prompt
                            sendMessage()
                        } label: {
                            Text(prompt)
                                .font(.callout)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(messages) { message in
                        TVChatMessageRow(message: message)
                            .id(message.id)
                    }

                    if isProcessing, !messages.contains(where: { $0.isStreaming }) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding(40)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputArea: some View {
        HStack(spacing: 16) {
            Button {
                // Trigger Siri voice input
            } label: {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            TextField("Ask Thea anything...", text: $inputText)
                .font(.title3)
                .focused($isInputFocused)
                .onSubmit(sendMessage)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    // MARK: - Send Message

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = TVChatMessage(content: text, isUser: true)
        messages.append(userMessage)
        inputText = ""
        isProcessing = true

        if inferenceClient.connectionState.isConnected {
            sendViaRelay()
        } else {
            sendSimulated(text: text)
        }
    }

    private func sendViaRelay() {
        let conversationMessages = messages.suffix(20).map { msg in
            (role: msg.isUser ? "user" : "assistant", content: msg.content)
        }

        let assistantMsg = TVChatMessage(content: "", isUser: false, isStreaming: true)
        messages.append(assistantMsg)

        Task {
            do {
                let reqId = try await inferenceClient.sendInferenceRequest(
                    messages: conversationMessages
                )
                activeRequestId = reqId
            } catch {
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx] = TVChatMessage(
                        content: "Failed to send: \(error.localizedDescription)",
                        isUser: false
                    )
                }
                isProcessing = false
            }
        }
    }

    private func sendSimulated(text: String) {
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            let response = TVChatMessage(
                content: generateFallbackResponse(for: text),
                isUser: false
            )
            messages.append(response)
            isProcessing = false
        }
    }

    // MARK: - Stream Callbacks

    private func setupStreamCallbacks() {
        inferenceClient.onStreamDelta = { _, delta in
            Task { @MainActor in
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx].content += delta
                }
            }
        }

        inferenceClient.onStreamComplete = { _, complete in
            Task { @MainActor in
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx].content = complete.fullText
                    messages[idx].isStreaming = false
                    messages[idx].modelName = complete.model
                }
                isProcessing = false
                activeRequestId = nil
            }
        }

        inferenceClient.onStreamError = { _, errorDesc in
            Task { @MainActor in
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx].content = "Error: \(errorDesc)"
                    messages[idx].isStreaming = false
                }
                isProcessing = false
                activeRequestId = nil
            }
        }
    }

    // MARK: - Fallback Response

    private func generateFallbackResponse(for query: String) -> String {
        let lower = query.lowercased()

        if lower.contains("calendar") || lower.contains("today") {
            return "I'm not connected to your Mac right now. " +
                "Connect via Settings -> Mac Connection to enable AI responses."
        }

        if lower.contains("watch") || lower.contains("recommend") {
            return "I need to be connected to your Mac server for AI inference. " +
                "Go to Settings -> Mac Connection to set up the connection."
        }

        return "I'm running in offline mode without AI inference. To get real AI responses:\n\n" +
            "1. Make sure Thea is running on your Mac\n" +
            "2. Enable Remote Server in Thea's Mac settings\n" +
            "3. Go to Settings -> Mac Connection on this Apple TV\n" +
            "4. Select your Mac from the list\n\n" +
            "Once connected, I'll route your questions through your Mac's AI models!"
    }
}

// MARK: - Chat Message Model

struct TVChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    let timestamp = Date()
    var isStreaming = false
    var modelName: String?
}

// MARK: - Chat Message Row

struct TVChatMessageRow: View {
    let message: TVChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if message.isUser { Spacer(minLength: 200) }

            if !message.isUser {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if message.content.isEmpty && message.isStreaming {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    HStack(spacing: 0) {
                        Text(message.content)
                            .font(.body)

                        if message.isStreaming {
                            Text("\u{2588}")
                                .foregroundStyle(.blue)
                                .opacity(0.8)
                        }
                    }
                    .padding(20)
                    .background(message.isUser ? Color.blue : Color.secondary.opacity(0.2))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                if let model = message.modelName {
                    Text(model)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if message.isUser {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }

            if !message.isUser { Spacer(minLength: 200) }
        }
    }
}
