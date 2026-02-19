import SwiftUI
import SwiftData

// MARK: - Thea Messaging Chat View
// Platform selector + conversation thread view for all messaging platforms.
// Accessible from macOS main navigation and iOS tab bar as "Messages".

// periphery:ignore - Reserved: TheaMessagingChatView type reserved for future feature activation
struct TheaMessagingChatView: View {
    @ObservedObject private var gateway = TheaMessagingGateway.shared
    @ObservedObject private var sessions = MessagingSessionManager.shared
    @State private var selectedSessionKey: String?
    @State private var replyText = ""
    @State private var selectedPlatform: MessagingPlatform? = nil

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .navigationTitle("Messages")
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(selection: $selectedSessionKey) {
            // Connected platforms header
            if !gateway.connectedPlatforms.isEmpty {
                Section {
                    ForEach(sortedPlatforms, id: \.self) { platform in
                        platformSection(platform)
                    }
                } header: {
                    Label("Active Platforms", systemImage: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.green)
                }
            }

            // Offline platforms
            let offlinePlatforms = MessagingPlatform.allCases.filter {
                !gateway.connectedPlatforms.contains($0) &&
                MessagingCredentialsStore.load(for: $0).isEnabled
            }
            if !offlinePlatforms.isEmpty {
                Section("Offline") {
                    ForEach(offlinePlatforms, id: \.self) { platform in
                        Label(platform.displayName, systemImage: platform.symbolName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedPlatform = nil
                    selectedSessionKey = nil
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Message")
            }
        }
    }

    private var sortedPlatforms: [MessagingPlatform] {
        gateway.connectedPlatforms.sorted(by: { $0.displayName < $1.displayName })
    }

    @ViewBuilder
    private func platformSection(_ platform: MessagingPlatform) -> some View {
        let platformSessions = sessions.activeSessions.filter { $0.platform == platform.rawValue }
        if !platformSessions.isEmpty {
            Section {
                ForEach(platformSessions) { session in
                    sessionRow(session)
                        .tag(session.key)
                }
            } header: {
                Label(platform.displayName, systemImage: platform.symbolName)
            }
        } else {
            Label(platform.displayName + " — no messages", systemImage: platform.symbolName)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func sessionRow(_ session: MessagingSession) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(session.senderName)
                    .font(.headline)
                Spacer()
                Text(session.lastActivity, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            let history = session.decodedHistory()
            if let last = history.last {
                Text(last.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if let key = selectedSessionKey,
           let session = sessions.activeSessions.first(where: { $0.key == key }) {
            conversationView(session: session)
        } else {
            ContentUnavailableView(
                "Select a Conversation",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Connect a platform in Settings → Messaging Gateway")
            )
        }
    }

    private func conversationView(session: MessagingSession) -> some View {
        let platformName = MessagingPlatform(rawValue: session.platform)?.displayName ?? session.platform
        return VStack(spacing: 0) {
            historyScrollView(session: session)
            Divider()
            replyComposer(session: session)
        }
        .navigationTitle(session.senderName)
        .navigationSubtitle(platformName)
    }

    @ViewBuilder
    private func historyScrollView(session: MessagingSession) -> some View {
        let history = session.decodedHistory()
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(history) { entry in
                        GatewayMessageBubble(entry: entry, senderName: session.senderName)
                            .id(entry.id)
                    }
                }
                .padding()
            }
            .onChange(of: history.count) { _, _ in
                if let last = session.decodedHistory().last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func replyComposer(session: MessagingSession) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Reply…", text: $replyText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onSubmit { sendReply(session: session) }

            Button {
                sendReply(session: session)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(replyText.isEmpty ? Color.gray : Color.blue)
            }
            .disabled(replyText.isEmpty)
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private func sendReply(session: MessagingSession) {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let platform = MessagingPlatform(rawValue: session.platform) else { return }
        replyText = ""

        Task {
            let message = OutboundMessagingMessage(chatId: session.chatId, content: text)
            do {
                try await TheaMessagingGateway.shared.send(message, via: platform)
                // Record in session
                await MainActor.run {
                    MessagingSessionManager.shared.appendOutbound(text: text, toSessionKey: session.key)
                }
            } catch {
                // Show error feedback
            }
        }
    }
}

// MARK: - Message Bubble

private struct GatewayMessageBubble: View {
    let entry: SessionMessageEntry
    let senderName: String

    var isUser: Bool { entry.role == "user" }

    var body: some View {
        HStack {
            if !isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .leading : .trailing, spacing: 4) {
                Text(isUser ? senderName : "Thea")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                Text(entry.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if isUser { Spacer(minLength: 40) }
        }
    }
}
