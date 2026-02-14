//
//  MentionAutocomplete.swift
//  Thea
//
//  @ mention system with autocomplete for chat input
//  Supports @file: @web: @project: mentions like Claude Desktop
//

import SwiftUI

// MARK: - Mention Types

/// Types of @ mentions supported in the chat input
enum MentionType: String, CaseIterable, Identifiable {
    case file
    case web
    case project
    case conversation

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .file: return "doc"
        case .web: return "globe"
        case .project: return "folder"
        case .conversation: return "bubble.left.and.bubble.right"
        }
    }

    var displayName: String {
        switch self {
        case .file: return "File"
        case .web: return "Web Search"
        case .project: return "Project"
        case .conversation: return "Conversation"
        }
    }

    var description: String {
        switch self {
        case .file: return "Reference a file from your project"
        case .web: return "Search the web for information"
        case .project: return "Reference project context"
        case .conversation: return "Reference a previous conversation"
        }
    }

    var placeholder: String {
        switch self {
        case .file: return "filename or path"
        case .web: return "search query"
        case .project: return "project name"
        case .conversation: return "conversation title"
        }
    }
}

// MARK: - Mention Item

/// A resolved mention item that can be inserted into the input
struct MentionItem: Identifiable, Equatable {
    let id: UUID
    let type: MentionType
    let title: String
    let subtitle: String?
    let value: String // The actual value to insert

    init(type: MentionType, title: String, subtitle: String? = nil, value: String? = nil) {
        id = UUID()
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.value = value ?? title
    }
}

// MARK: - Mention Parser

/// Parses text to detect @ mention triggers
struct MentionParser {
    // Pattern for detecting mentions - parsed at runtime to avoid concurrency issues

    /// Check if the cursor is in a mention context
    static func detectMentionContext(text: String, cursorPosition: Int) -> MentionContext? {
        guard cursorPosition > 0, cursorPosition <= text.count else { return nil }

        let prefix = String(text.prefix(cursorPosition))

        // Find the last @ symbol before cursor
        guard let atIndex = prefix.lastIndex(of: "@") else { return nil }

        let startIndex = text.index(atIndex, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
        let mentionText = String(prefix[startIndex...])

        // Don't show autocomplete if there's a space after @
        if mentionText.contains(" ") { return nil }

        // Parse the mention type and query
        if let colonIndex = mentionText.firstIndex(of: ":") {
            let typeStr = String(mentionText[..<colonIndex])
            let query = String(mentionText[mentionText.index(after: colonIndex)...])

            if let type = MentionType(rawValue: typeStr.lowercased()) {
                return MentionContext(
                    type: type,
                    query: query,
                    range: atIndex..<prefix.endIndex
                )
            }
        } else {
            // Just @ or @partial - show type suggestions
            return MentionContext(
                type: nil,
                query: mentionText,
                range: atIndex..<prefix.endIndex
            )
        }

        return nil
    }

    /// Context information about a detected mention
    struct MentionContext {
        let type: MentionType? // nil means show type picker
        let query: String
        let range: Range<String.Index>
    }
}

// MARK: - Mention Autocomplete View

/// Autocomplete popup for @ mentions
struct MentionAutocompleteView: View {
    let context: MentionParser.MentionContext
    let onSelect: (MentionItem) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex = 0
    @State private var items: [MentionItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "at")
                    .foregroundStyle(.secondary)
                Text(context.type?.displayName ?? "Mention")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("↑↓ to navigate, ↵ to select, esc to dismiss")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Items list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        MentionItemRow(
                            item: item,
                            isSelected: index == selectedIndex
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(item)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .onAppear {
            updateItems()
        }
        .onChange(of: context.query) { _, _ in
            updateItems()
            selectedIndex = 0
        }
    }

    private func updateItems() {
        if let type = context.type {
            // Show items for specific type
            items = generateItems(for: type, query: context.query)
        } else {
            // Show type picker
            items = MentionType.allCases
                .filter { context.query.isEmpty || $0.rawValue.contains(context.query.lowercased()) }
                .map { type in
                    MentionItem(
                        type: type,
                        title: "@\(type.rawValue):",
                        subtitle: type.description,
                        value: "@\(type.rawValue):"
                    )
                }
        }
    }

    private func generateItems(for type: MentionType, query: String) -> [MentionItem] {
        // In a real implementation, this would query the appropriate data source
        // For now, return placeholder items
        switch type {
        case .file:
            return [
                MentionItem(type: type, title: "README.md", subtitle: "Documentation"),
                MentionItem(type: type, title: "Package.swift", subtitle: "Swift Package"),
                MentionItem(type: type, title: "ContentView.swift", subtitle: "macOS/Views")
            ].filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }

        case .web:
            if query.isEmpty {
                return [
                    MentionItem(type: type, title: "Search the web...", subtitle: "Type your query")
                ]
            } else {
                return [
                    MentionItem(type: type, title: query, subtitle: "Search for: \(query)", value: query)
                ]
            }

        case .project:
            return [
                MentionItem(type: type, title: "Current Project", subtitle: "Use current project context")
            ]

        case .conversation:
            return [
                MentionItem(type: type, title: "Previous conversation", subtitle: "Reference earlier chat")
            ]
        }
    }

    func handleKeyPress(_ key: KeyEquivalent) -> Bool {
        switch key {
        case .upArrow:
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case .downArrow:
            selectedIndex = min(items.count - 1, selectedIndex + 1)
            return true
        case .return:
            if selectedIndex < items.count {
                onSelect(items[selectedIndex])
            }
            return true
        case .escape:
            onDismiss()
            return true
        default:
            return false
        }
    }
}

// MARK: - Mention Item Row

struct MentionItemRow: View {
    let item: MentionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.theaPrimaryDefault : Color.clear)
    }
}

// MARK: - Mention Chip

/// Displays an inserted mention as a styled chip
struct MentionChip: View {
    let type: MentionType
    let value: String
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10))

            Text(value)
                .font(.system(size: 12))
                .lineLimit(1)

            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove mention")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipBackground)
        .foregroundStyle(chipForeground)
        .clipShape(Capsule())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var chipBackground: Color {
        switch type {
        case .file: return Color.blue.opacity(0.15)
        case .web: return Color.green.opacity(0.15)
        case .project: return Color.purple.opacity(0.15)
        case .conversation: return Color.orange.opacity(0.15)
        }
    }

    private var chipForeground: Color {
        switch type {
        case .file: return .blue
        case .web: return .green
        case .project: return .purple
        case .conversation: return .orange
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Mention Autocomplete - Types") {
        MentionAutocompleteView(
            context: MentionParser.MentionContext(
                type: nil,
                query: "",
                range: "".startIndex..<"".endIndex
            ),
            onSelect: { _ in },
            onDismiss: {}
        )
        .padding()
    }

    #Preview("Mention Autocomplete - Files") {
        MentionAutocompleteView(
            context: MentionParser.MentionContext(
                type: .file,
                query: "read",
                range: "".startIndex..<"".endIndex
            ),
            onSelect: { _ in },
            onDismiss: {}
        )
        .padding()
    }

    #Preview("Mention Chips") {
        HStack {
            MentionChip(type: .file, value: "README.md") {}
            MentionChip(type: .web, value: "Swift concurrency") {}
            MentionChip(type: .project, value: "Thea") {}
        }
        .padding()
    }
#endif
