//
//  MentionAutocompleteView.swift
//  Thea
//
//  @-mention autocomplete with live data from ChatManager,
//  grouped by type, keyboard navigation, and Thea design tokens.
//

#if os(macOS) || os(iOS)

import SwiftUI
import Combine

// MARK: - Mention Type

/// Categories of mentionable items in the chat input.
enum MentionType: String, CaseIterable, Identifiable, Sendable, Hashable {
    case conversation
    case project
    case memoryEntry
    case file

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conversation: return "Conversations"
        case .project:      return "Projects"
        case .memoryEntry:  return "Memories"
        case .file:         return "Files"
        }
    }

    /// SF Symbol name for each mention type.
    var icon: String {
        switch self {
        case .conversation: return "bubble.left.and.bubble.right"
        case .project:      return "folder"
        case .memoryEntry:  return "brain.head.profile"
        case .file:         return "doc"
        }
    }

    /// Sort priority — lower value shows first.
    var sortOrder: Int {
        switch self {
        case .conversation: return 0
        case .project:      return 1
        case .memoryEntry:  return 2
        case .file:         return 3
        }
    }
}

// MARK: - Mention Item

/// A single mentionable entity displayed in the autocomplete list.
struct MentionItem: Identifiable, Sendable, Hashable {
    let id: UUID
    let type: MentionType
    let name: String
    let subtitle: String?
    let icon: String

    init(
        id: UUID = UUID(),
        type: MentionType,
        name: String,
        subtitle: String? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.subtitle = subtitle
        self.icon = icon ?? type.icon
    }
}

// MARK: - Mention Data Provider

/// Searches conversations, projects, and memories to produce `MentionItem` results.
@MainActor
final class MentionDataProvider: ObservableObject {

    @Published private(set) var items: [MentionItem] = []

    private let maxResults = 8
    private var searchTask: Task<Void, Never>?

    // MARK: - Search

    func search(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        searchTask = Task { @MainActor in
            var results: [MentionItem] = []

            // --- Conversations (live data from ChatManager) ---
            let conversations = ChatManager.shared.conversations
            let matchingConversations: [MentionItem] = conversations
                .filter { conv in
                    trimmed.isEmpty || conv.title.lowercased().contains(trimmed)
                }
                .prefix(maxResults)
                .map { conv in
                    MentionItem(
                        id: conv.id,
                        type: .conversation,
                        name: conv.title,
                        subtitle: "Conversation",
                        icon: MentionType.conversation.icon
                    )
                }
            results.append(contentsOf: matchingConversations)

            // --- Projects (stub — return empty for now) ---
            let matchingProjects: [MentionItem] = []
            results.append(contentsOf: matchingProjects)

            // --- Memories (stub — return empty for now) ---
            let matchingMemories: [MentionItem] = []
            results.append(contentsOf: matchingMemories)

            guard !Task.isCancelled else { return }

            // Limit total items
            items = Array(results.prefix(maxResults))
        }
    }

    func clear() {
        searchTask?.cancel()
        items = []
    }
}

// MARK: - Grouped items helper

/// Groups mention items by type for section display.
private struct MentionSection: Identifiable {
    let type: MentionType
    let items: [MentionItem]
    var id: String { type.rawValue }
}

// MARK: - Mention Autocomplete View

/// Autocomplete popup shown when the user types "@" in the chat input.
struct MentionAutocompleteView: View {

    let query: String
    let onSelect: (MentionItem) -> Void
    let onDismiss: () -> Void

    @StateObject private var provider = MentionDataProvider()
    @State private var selectedIndex: Int = 0

    // MARK: - Derived state

    private var flatItems: [MentionItem] {
        provider.items
    }

    private var sections: [MentionSection] {
        let grouped = Dictionary(grouping: flatItems, by: \.type)
        return grouped
            .map { MentionSection(type: $0.key, items: $0.value) }
            .sorted { $0.type.sortOrder < $1.type.sortOrder }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            itemsListView
        }
        .frame(width: 320)
        .frame(maxHeight: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .onAppear {
            provider.search(query: query)
        }
        .onChange(of: query) { _, newValue in
            provider.search(query: newValue)
            selectedIndex = 0
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "at")
                .foregroundStyle(.secondary)
            Text("Mention")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\u{2191}\u{2193} navigate  \u{21B5} select  esc dismiss")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
    }

    private var itemsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if flatItems.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(sections) { section in
                            sectionHeaderView(section.type)

                            ForEach(section.items) { item in
                                let globalIndex = flatItemIndex(for: item)
                                MentionAutocompleteRow(
                                    item: item,
                                    isSelected: globalIndex == selectedIndex
                                )
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(item)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
            .onChange(of: selectedIndex) { _, newIndex in
                if newIndex < flatItems.count {
                    withAnimation(TheaAnimation.micro) {
                        proxy.scrollTo(flatItems[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func sectionHeaderView(_ type: MentionType) -> some View {
        Text(type.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, TheaSpacing.md)
            .padding(.top, TheaSpacing.sm)
            .padding(.bottom, TheaSpacing.xs)
    }

    private var emptyStateView: some View {
        HStack {
            Spacer()
            Text("No matches")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, TheaSpacing.xl)
    }

    // MARK: - Keyboard navigation

    /// Call this from the parent's key handler.
    /// Returns `true` if the key was consumed.
    func handleKeyPress(_ key: KeyEquivalent) -> Bool {
        switch key {
        case .upArrow:
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case .downArrow:
            selectedIndex = min(flatItems.count - 1, selectedIndex + 1)
            return true
        case .return:
            if selectedIndex < flatItems.count {
                onSelect(flatItems[selectedIndex])
            }
            return true
        case .escape:
            onDismiss()
            return true
        default:
            return false
        }
    }

    // MARK: - Helpers

    private func flatItemIndex(for item: MentionItem) -> Int {
        flatItems.firstIndex { $0.id == item.id } ?? 0
    }
}

// MARK: - Row View

/// A single row inside the autocomplete list.
struct MentionAutocompleteRow: View {

    let item: MentionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
                Text(item.name)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
        .background(isSelected ? Color.theaPrimaryDefault : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.sm))
        .animation(TheaAnimation.micro, value: isSelected)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Mention Autocomplete") {
    MentionAutocompleteView(
        query: "",
        onSelect: { item in print("Selected: \(item.name)") },
        onDismiss: { print("Dismissed") }
    )
    .padding()
    .frame(width: 400, height: 400)
}
#endif

#endif // os(macOS) || os(iOS)
