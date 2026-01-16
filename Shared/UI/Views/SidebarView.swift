import SwiftData
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

            Section("Recent") {
                ForEach(filteredConversations) { conversation in
                    ConversationRow(conversation: conversation)
                        .tag(conversation)
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
                    Label("New Conversation", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    private var pinnedConversations: [Conversation] {
        conversations.filter(\.isPinned)
    }

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations.filter { !$0.isPinned }
        } else {
            return conversations.filter { !$0.isPinned && $0.title.localizedCaseInsensitiveContains(searchText) }
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
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

            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Button(role: .destructive) {
                ChatManager.shared.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
