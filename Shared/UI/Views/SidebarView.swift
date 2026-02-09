@preconcurrency import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: Conversation?
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Inline search field in the conversations list panel
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.theaCaption1)
                TextField("Search conversations", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.theaCaption1)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.theaCaption2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, TheaSpacing.md)
            .padding(.vertical, TheaSpacing.sm)
            .background(Color.theaSurface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
            .padding(.horizontal, TheaSpacing.md)
            .padding(.vertical, TheaSpacing.sm)

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
        }
        .navigationTitle("Conversations")
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
        // Only show non-archived conversations that have at least one message
        let active = conversations.filter { !$0.messages.isEmpty && !$0.isArchived }
        if searchText.isEmpty {
            return active
        }
        return active.filter {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var projectManager = ProjectManager.shared
    @State private var isRenaming = false
    @State private var renameText = ""

    var body: some View {
        HStack(spacing: TheaSpacing.sm) {
            VStack(alignment: .leading, spacing: scaledSpacing) {
                Text(conversation.title)
                    .font(.theaSubhead)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let lastMessage = conversation.messages.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    Text(lastMessage.content.textValue)
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(conversation.updatedAt, format: .dateTime.hour().minute())
                    .font(.theaCaption2)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }

                    if !conversation.isRead {
                        Circle()
                            .fill(Color.theaPrimaryDefault)
                            .frame(width: 8, height: 8)
                    }
                }

                // Show message count as a subtle badge
                Text("\(conversation.messages.count)")
                    .font(.theaCaption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, scaledVerticalPadding)
        .contextMenu {
            Button {
                ChatManager.shared.togglePin(conversation)
            } label: {
                Label(
                    conversation.isPinned ? "Unpin" : "Pin",
                    systemImage: conversation.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                renameText = conversation.title
                isRenaming = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                ChatManager.shared.toggleRead(conversation)
            } label: {
                Label(
                    conversation.isRead ? "Mark as Unread" : "Mark as Read",
                    systemImage: conversation.isRead ? "envelope.badge" : "envelope.open"
                )
            }

            Divider()

            Button {
                ChatManager.shared.toggleArchive(conversation)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            // Project/workspace operations
            if !projectManager.projects.isEmpty {
                Menu("Move to Project") {
                    ForEach(projectManager.projects) { project in
                        Button(project.title) {
                            projectManager.addConversation(conversation, to: project)
                        }
                    }

                    if let projectID = conversation.projectID,
                       let project = projectManager.projects.first(where: { $0.id == projectID }) {
                        Divider()
                        Button("Remove from \(project.title)") {
                            projectManager.removeConversation(conversation, from: project)
                        }
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                ChatManager.shared.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Rename Conversation", isPresented: $isRenaming) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                ChatManager.shared.updateConversationTitle(conversation, title: renameText)
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

    /// Vertical padding scales with dynamic type to prevent clipping
    private var scaledVerticalPadding: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: TheaSpacing.xxs
        case .medium: TheaSpacing.xs
        case .large, .xLarge: TheaSpacing.sm
        case .xxLarge, .xxxLarge: TheaSpacing.md
        default: TheaSpacing.sm
        }
    }

    /// Inner spacing between title and preview scales with font size
    private var scaledSpacing: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: TheaSpacing.xxs
        case .medium: TheaSpacing.xxs
        case .large, .xLarge: TheaSpacing.xs
        case .xxLarge, .xxxLarge: TheaSpacing.sm
        default: TheaSpacing.xs
        }
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
