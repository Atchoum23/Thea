@preconcurrency import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: Conversation?
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var searchText = ""

    var body: some View {
        List(selection: $selection) {
            if !pinnedConversations.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation)
                    }
                }
            }

            if !todayConversations.isEmpty {
                Section("Today") {
                    ForEach(todayConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation)
                    }
                }
            }

            if !yesterdayConversations.isEmpty {
                Section("Yesterday") {
                    ForEach(yesterdayConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation)
                    }
                }
            }

            if !thisWeekConversations.isEmpty {
                Section("Previous 7 Days") {
                    ForEach(thisWeekConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation)
                    }
                }
            }

            if !olderConversations.isEmpty {
                Section("Older") {
                    ForEach(olderConversations) { conversation in
                        ConversationRow(conversation: conversation)
                            .tag(conversation)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations")
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewConversation()
                } label: {
                    Label("New Chat", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    // MARK: - Grouped Conversations

    private var pinnedConversations: [Conversation] {
        filteredConversations.filter(\.isPinned)
    }

    private var unpinnedConversations: [Conversation] {
        filteredConversations.filter { !$0.isPinned }
    }

    private var todayConversations: [Conversation] {
        unpinnedConversations.filter { Calendar.current.isDateInToday($0.updatedAt) }
    }

    private var yesterdayConversations: [Conversation] {
        unpinnedConversations.filter { Calendar.current.isDateInYesterday($0.updatedAt) }
    }

    private var thisWeekConversations: [Conversation] {
        let cal = Calendar.current
        return unpinnedConversations.filter { conversation in
            !cal.isDateInToday(conversation.updatedAt)
                && !cal.isDateInYesterday(conversation.updatedAt)
                && conversation.updatedAt > cal.date(byAdding: .day, value: -7, to: Date())!
        }
    }

    private var olderConversations: [Conversation] {
        let cal = Calendar.current
        return unpinnedConversations.filter {
            $0.updatedAt <= cal.date(byAdding: .day, value: -7, to: Date())!
        }
    }

    private var filteredConversations: [Conversation] {
        // Only show conversations that have at least one message
        let withMessages = conversations.filter { !$0.messages.isEmpty }
        if searchText.isEmpty {
            return withMessages
        }
        return withMessages.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func createNewConversation() {
        let conversation = ChatManager.shared.createConversation()
        selection = conversation
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: TheaSpacing.md) {
            VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
                Text(conversation.title)
                    .font(.theaBody)
                    .lineLimit(1)

                if let lastMessage = conversation.messages.last {
                    Text(lastMessage.content.textValue)
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: TheaSpacing.xxs) {
                Text(conversation.updatedAt, format: .dateTime.hour().minute())
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)

                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button {
                ChatManager.shared.togglePin(conversation)
            } label: {
                Label(
                    conversation.isPinned ? "Unpin" : "Pin",
                    systemImage: conversation.isPinned ? "pin.slash" : "pin"
                )
            }

            Divider()

            Button(role: .destructive) {
                ChatManager.shared.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                ChatManager.shared.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                ChatManager.shared.togglePin(conversation)
            } label: {
                Label(
                    conversation.isPinned ? "Unpin" : "Pin",
                    systemImage: conversation.isPinned ? "pin.slash" : "pin"
                )
            }
            .tint(.orange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(conversationAccessibilityLabel)
        .accessibilityHint("Double-tap to open conversation")
    }

    private var conversationAccessibilityLabel: String {
        var label = conversation.title
        if conversation.isPinned {
            label += ", pinned"
        }
        let time = conversation.updatedAt.formatted(.dateTime.hour().minute())
        label += ", updated \(time)"
        if let lastMessage = conversation.messages.last {
            let preview = lastMessage.content.textValue
            let truncated = preview.count > 100 ? String(preview.prefix(100)) + "…" : preview
            label += ". Last message: \(truncated)"
        }
        return label
    }
}
