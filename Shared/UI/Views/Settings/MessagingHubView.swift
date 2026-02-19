// MessagingHubView.swift
// Thea — Messaging Hub settings and dashboard view
//
// Shows all registered messaging channels, their status,
// recent messages, and configuration options.

import SwiftUI
import OSLog
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct MessagingHubView: View {
    @ObservedObject private var hub = MessagingHub.shared

    @State private var selectedChannel: MessagingChannelType?
    @State private var searchText = ""
    @State private var showingChannelDetail = false

    var body: some View {
        // periphery:ignore - Reserved: searchText property reserved for future feature activation
        // periphery:ignore - Reserved: showingChannelDetail property reserved for future feature activation
        #if os(macOS)
        HSplitView {
            channelListView
                .frame(minWidth: 250, maxWidth: 350)
            detailView
                .frame(minWidth: 400)
        }
        .navigationTitle("Messaging Hub")
        #else
        NavigationStack {
            List {
                statsSection
                channelsSection
                recentMessagesSection
                settingsSection
            }
            .navigationTitle("Messaging Hub")
            .searchable(text: $searchText, prompt: "Search messages")
        }
        #endif
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        Section {
            HStack {
                MsgStatCard(
                    title: "Channels",
                    value: "\(hub.channels.count)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                MsgStatCard(
                    title: "Active",
                    value: "\(hub.activeChannels.count)",
                    icon: "checkmark.circle",
                    color: .green
                )
                MsgStatCard(
                    title: "Unread",
                    value: "\(hub.unreadTotal)",
                    icon: "envelope.badge",
                    color: hub.unreadTotal > 0 ? .red : .gray
                )
                MsgStatCard(
                    title: "Messages",
                    value: "\(hub.recentMessages.count)",
                    icon: "message",
                    color: .purple
                )
            }
        } header: {
            Text("Overview")
        }
    }

    // MARK: - Channels Section

    private var channelsSection: some View {
        Section {
            ForEach(MessagingChannelType.allCases, id: \.rawValue) { type in
                let channels = hub.channels.filter { $0.type == type }
                if !channels.isEmpty {
                    ForEach(channels) { channel in
                        channelRow(channel)
                    }
                } else {
                    disabledChannelRow(type)
                }
            }
        } header: {
            Text("Channels")
        }
    }

    private func channelRow(_ channel: RegisteredChannel) -> some View {
        HStack {
            Image(systemName: channel.type.icon)
                .foregroundStyle(channel.status.isActive ? Color.theaAccent : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.body)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(channel.status))
                        .frame(width: 8, height: 8)
                    Text(channel.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if channel.unreadCount > 0 {
                        Text("(\(channel.unreadCount) unread)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            if channel.autoReplyEnabled {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.blue)
                    .help("Auto-reply enabled")
            }

            Toggle("", isOn: Binding(
                get: { channel.isEnabled },
                set: { hub.enableChannel(channel.type, name: channel.name, enabled: $0) }
            ))
            .labelsHidden()
        }
        .accessibilityLabel("\(channel.type.displayName) channel, \(channel.status.rawValue)")
    }

    private func disabledChannelRow(_ type: MessagingChannelType) -> some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(type.usesBridge ? "Via OpenClaw Gateway" : "Native integration")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("Not configured")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Recent Messages Section

    private var recentMessagesSection: some View {
        Section {
            // periphery:ignore - Reserved: recentMessagesSection property reserved for future feature activation
            let messages = filteredMessages
            if messages.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Messages from connected channels will appear here.")
                )
            } else {
                ForEach(Array(messages.suffix(20))) { message in
                    messageRow(message)
                }
            }
        } header: {
            Text("Recent Messages")
        }
    }

    private func messageRow(_ message: UnifiedMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.channelType.icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.senderName ?? message.senderID)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(message.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)

                if !message.attachments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                        Text("\(message.attachments.count) attachment(s)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        // periphery:ignore - Reserved: settingsSection property reserved for future feature activation
        Section {
            Toggle("Global Auto-Reply", isOn: Binding(
                get: { hub.autoReplyGlobalEnabled },
                set: { hub.autoReplyGlobalEnabled = $0 }
            ))

            Toggle("Message Comprehension", isOn: Binding(
                get: { hub.comprehensionEnabled },
                set: { hub.comprehensionEnabled = $0 }
            ))
        } header: {
            Text("Settings")
        }
    }

    // MARK: - macOS Split View

    #if os(macOS)
    private var channelListView: some View {
        List(selection: $selectedChannel) {
            statsSection
            channelsSection
        }
        .listStyle(.sidebar)
    }

    private var detailView: some View {
        Group {
            if let selected = selectedChannel {
                channelDetailView(selected)
            } else {
                ContentUnavailableView(
                    "Select a Channel",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a messaging channel to view details.")
                )
            }
        }
    }

    private func channelDetailView(_ type: MessagingChannelType) -> some View {
        List {
            // Platform-specific stats
            switch type {
            case .whatsApp:
                whatsAppDetailSection
            case .telegram:
                telegramDetailSection
            default:
                EmptyView()
            }

            Section("Messages") {
                let messages = hub.messages(for: type, limit: 50)
                if messages.isEmpty {
                    Text("No messages in \(type.displayName)")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(messages) { message in
                        messageRow(message)
                    }
                }
            }

            Section("Channel Info") {
                if let channel = hub.channels.first(where: { $0.type == type }) {
                    LabeledContent("Status", value: channel.status.rawValue.capitalized)
                    LabeledContent("Unread", value: "\(channel.unreadCount)")
                    if let lastActivity = channel.lastActivityAt {
                        LabeledContent("Last Activity", value: lastActivity, format: .dateTime)
                    }
                    Toggle("Auto-Reply", isOn: Binding(
                        get: { channel.autoReplyEnabled },
                        set: { hub.setAutoReply(type, name: channel.name, enabled: $0) }
                    ))

                    Button("Mark All as Read") {
                        hub.markAsRead(channelType: type)
                    }
                } else {
                    Text("Channel not configured")
                        .foregroundStyle(.secondary)
                    if type.usesBridge {
                        Text("Requires OpenClaw Gateway")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle(type.displayName)
    }

    // MARK: - WhatsApp Detail

    @ObservedObject private var whatsApp = WhatsAppChannel.shared

    private var whatsAppDetailSection: some View {
        Section("WhatsApp") {
            LabeledContent("Connected", value: whatsApp.isConnected ? "Yes" : "No")
            LabeledContent("Contacts", value: "\(whatsApp.totalContacts)")
            LabeledContent("Groups", value: "\(whatsApp.totalGroups)")
            LabeledContent("Total Messages", value: "\(whatsApp.totalMessages)")
            LabeledContent("Conversations", value: "\(whatsApp.conversationCount)")

            if let error = whatsApp.connectionError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Toggle("Voice Note Transcription", isOn: Binding(
                get: { whatsApp.autoTranscribeVoiceNotes },
                set: { whatsApp.autoTranscribeVoiceNotes = $0 }
            ))

            Button("Import Chat Export") {
                importWhatsAppExport()
            }
        }
    }

    // MARK: - Telegram Detail

    @ObservedObject private var telegram = TelegramChannel.shared

    private var telegramDetailSection: some View {
        Section("Telegram") {
            LabeledContent("Connected", value: telegram.isConnected ? "Yes" : "No")
            if let bot = telegram.botUsername {
                LabeledContent("Bot", value: "@\(bot)")
            }
            LabeledContent("Contacts", value: "\(telegram.totalContacts)")
            LabeledContent("Groups", value: "\(telegram.totalGroups)")
            LabeledContent("Channels", value: "\(telegram.totalChannels)")
            LabeledContent("Total Messages", value: "\(telegram.totalMessages)")

            if let error = telegram.connectionError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Toggle("Monitor Subscribed Channels", isOn: Binding(
                get: { telegram.monitorSubscribedChannels },
                set: { telegram.monitorSubscribedChannels = $0 }
            ))

            Button("Import Desktop Export") {
                importTelegramExport()
            }
        }
    }

    // MARK: - Import Actions

    private func importWhatsAppExport() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.title = "Import WhatsApp Chat Export"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let messages = WhatsAppChannel.shared.importChatExport(from: url)
            logger.info("Imported \(messages.count) WhatsApp messages")
        }
        #endif
    }

    private func importTelegramExport() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = "Import Telegram Desktop Export"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let messages = TelegramChannel.shared.importDesktopExport(from: url)
            logger.info("Imported \(messages.count) Telegram messages")
        }
        #endif
    }

    private let logger = Logger(subsystem: "com.thea.app", category: "MessagingHubView")
    #endif

    // MARK: - Helpers

    // periphery:ignore - Reserved: filteredMessages property reserved for future feature activation
    private var filteredMessages: [UnifiedMessage] {
        if searchText.isEmpty {
            return hub.recentMessages
        }
        return hub.searchMessages(query: searchText)
    }

    private func statusColor(_ status: MessagingChannelStatus) -> Color {
        switch status {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .gray
        case .error: .red
        case .disabled: .secondary
        }
    }
}

// MARK: - Stat Card

private struct MsgStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
