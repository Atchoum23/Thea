//
//  KeyboardShortcutsHelpView.swift
//  Thea
//
//  Beautiful keyboard shortcuts help overlay (Cmd+/)
//  Displays all available keyboard shortcuts organized by category.
//
//  Features:
//  - Modal overlay with blur background
//  - Organized by category with SF Symbol icons
//  - Searchable shortcuts list
//  - Platform-aware key symbols
//  - Animated appearance/dismissal
//  - Accessibility support
//  - Dismiss with Escape or clicking outside
//

import SwiftUI

// MARK: - Keyboard Shortcut Model

/// Represents a single keyboard shortcut
struct KeyboardShortcutItem: Identifiable, Equatable {
    let id = UUID()
    let keys: String
    let description: String
    let isContextual: Bool

    init(_ keys: String, _ description: String, isContextual: Bool = false) {
        self.keys = keys
        self.description = description
        self.isContextual = isContextual
    }
}

/// Represents a category of keyboard shortcuts
struct ShortcutCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let shortcuts: [KeyboardShortcutItem]
}

// MARK: - Main View

struct KeyboardShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    @State private var searchText = ""
    @State private var hasAppeared = false
    @State private var selectedCategory: String?

    // MARK: - Body

    var body: some View {
        ZStack {
            // Blur background - dismisses on tap
            backgroundLayer

            // Content card
            contentCard
                .scaleEffect(hasAppeared ? 1.0 : 0.9)
                .opacity(hasAppeared ? 1.0 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(TheaAnimation.entrance) {
                hasAppeared = true
            }
        }
        #if os(macOS) || os(tvOS)
        .onExitCommand {
            dismissWithAnimation()
        }
        #endif
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Keyboard Shortcuts Help")
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .background(
                TheaBrandColors.deepNavy.opacity(colorScheme == .dark ? 0.7 : 0.3)
            )
            .onTapGesture {
                dismissWithAnimation()
            }
    }

    // MARK: - Content Card

    private var contentCard: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(TheaBrandColors.gold.opacity(0.3))

            // Search bar
            searchBar
                .padding(.horizontal, TheaSpacing.lg)
                .padding(.vertical, TheaSpacing.md)

            // Shortcuts list
            shortcutsList
        }
        .frame(width: 580, height: 680)
        .background(
            RoundedRectangle(cornerRadius: TheaRadius.xl)
                .fill(colorScheme == .dark ? TheaBrandColors.softDark : TheaBrandColors.warmWhite)
                .shadow(color: TheaBrandColors.gold.opacity(0.15), radius: 30, y: 10)
        )
        .clipShape(RoundedRectangle(cornerRadius: TheaRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: TheaRadius.xl)
                .stroke(TheaBrandColors.gold.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Icon and title
            HStack(spacing: TheaSpacing.md) {
                Image(systemName: "keyboard")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(TheaBrandColors.spiralGradient)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Press ⌘/ anytime to show this help")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Close button
            Button {
                dismissWithAnimation()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, TheaSpacing.xl)
        .padding(.vertical, TheaSpacing.lg)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Search shortcuts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: TheaRadius.md)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TheaRadius.md)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Shortcuts List

    private var shortcutsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TheaSpacing.lg) {
                ForEach(filteredCategories) { category in
                    shortcutSection(category)
                        .entranceAnimation(delay: Double(filteredCategories.firstIndex { $0.id == category.id } ?? 0) * 0.05)
                }

                if filteredCategories.isEmpty {
                    emptySearchView
                }
            }
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.md)
            .padding(.bottom, TheaSpacing.xl)
        }
    }

    // MARK: - Shortcut Section

    private func shortcutSection(_ category: ShortcutCategory) -> some View {
        VStack(alignment: .leading, spacing: TheaSpacing.md) {
            // Category header
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TheaBrandColors.gold)
                    .frame(width: 20)

                Text(category.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            // Shortcuts grid
            VStack(spacing: 0) {
                ForEach(category.shortcuts) { shortcut in
                    shortcutRow(shortcut)

                    if shortcut != category.shortcuts.last {
                        Divider()
                            .padding(.leading, TheaSpacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: TheaRadius.md)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TheaRadius.md)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Shortcut Row

    private func shortcutRow(_ shortcut: KeyboardShortcutItem) -> some View {
        HStack {
            Text(shortcut.description)
                .font(.system(size: 13))
                .foregroundStyle(shortcut.isContextual ? .secondary : .primary)

            if shortcut.isContextual {
                Text("(contextual)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            shortcutBadge(shortcut.keys)
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm + 2)
        .contentShape(Rectangle())
    }

    // MARK: - Shortcut Badge

    private func shortcutBadge(_ shortcut: String) -> some View {
        let parts = shortcut.components(separatedBy: "+")
        return HStack(spacing: 3) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(symbolForKey(part))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : TheaBrandColors.deepNavy)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
            }
        }
    }

    // MARK: - Empty Search View

    private var emptySearchView: some View {
        VStack(spacing: TheaSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No shortcuts found")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TheaSpacing.xxxl)
    }

    // MARK: - Key Symbol Mapping

    private func symbolForKey(_ key: String) -> String {
        switch key.lowercased().trimmingCharacters(in: .whitespaces) {
        case "cmd", "command", "⌘": return "⌘"
        case "shift", "⇧": return "⇧"
        case "alt", "option", "opt", "⌥": return "⌥"
        case "ctrl", "control", "⌃": return "⌃"
        case "enter", "return", "↩︎": return "↩︎"
        case "esc", "escape", "⎋": return "⎋"
        case "delete", "backspace", "⌫": return "⌫"
        case "tab", "⇥": return "⇥"
        case "space", "␣": return "␣"
        case "up", "↑": return "↑"
        case "down", "↓": return "↓"
        case "left", "←": return "←"
        case "right", "→": return "→"
        case "fn": return "fn"
        default: return key.uppercased()
        }
    }

    // MARK: - Dismiss Animation

    private func dismissWithAnimation() {
        withAnimation(TheaAnimation.standard) {
            hasAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }

    // MARK: - Filtered Categories

    private var filteredCategories: [ShortcutCategory] {
        if searchText.isEmpty {
            return allCategories
        }

        let query = searchText.lowercased()
        return allCategories.compactMap { category in
            let matchingShortcuts = category.shortcuts.filter { shortcut in
                shortcut.description.lowercased().contains(query) ||
                shortcut.keys.lowercased().contains(query)
            }
            if matchingShortcuts.isEmpty {
                return nil
            }
            return ShortcutCategory(
                title: category.title,
                icon: category.icon,
                shortcuts: matchingShortcuts
            )
        }
    }

    // MARK: - All Categories

    private var allCategories: [ShortcutCategory] {
        [
            generalCategory,
            navigationCategory,
            chatCategory,
            searchCategory,
            editingCategory,
            aiCategory,
            windowCategory
        ]
    }

    // MARK: - Category Definitions

    private var generalCategory: ShortcutCategory {
        ShortcutCategory(
            title: "General",
            icon: "command",
            shortcuts: [
                KeyboardShortcutItem("Cmd+N", "New Window"),
                KeyboardShortcutItem("Cmd+T", "New Tab"),
                KeyboardShortcutItem("Cmd+Shift+N", "New Conversation"),
                KeyboardShortcutItem("Cmd+Shift+P", "New Project"),
                KeyboardShortcutItem("Cmd+W", "Close Window"),
                KeyboardShortcutItem("Cmd+,", "Open Settings"),
                KeyboardShortcutItem("Cmd+/", "Show Keyboard Shortcuts"),
                KeyboardShortcutItem("Cmd+Q", "Quit Thea")
            ]
        )
    }

    private var navigationCategory: ShortcutCategory {
        ShortcutCategory(
            title: "Navigation",
            icon: "arrow.up.arrow.down",
            shortcuts: [
                KeyboardShortcutItem("Cmd+1", "Go to Conversations"),
                KeyboardShortcutItem("Cmd+2", "Go to Projects"),
                KeyboardShortcutItem("Cmd+3", "Go to Knowledge"),
                KeyboardShortcutItem("Cmd+4", "Go to Settings"),
                KeyboardShortcutItem("Cmd+[", "Previous Conversation"),
                KeyboardShortcutItem("Cmd+]", "Next Conversation"),
                KeyboardShortcutItem("Cmd+↑", "Scroll to Top"),
                KeyboardShortcutItem("Cmd+↓", "Scroll to Bottom")
            ]
        )
    }

    private var chatCategory: ShortcutCategory {
        // Dynamic based on user's submit shortcut preference
        let submitKey = settings.submitShortcut == "cmdEnter" ? "Cmd+Enter" :
                       (settings.submitShortcut == "shiftEnter" ? "Shift+Enter" : "Enter")
        let newlineKey = settings.submitShortcut == "enter" ? "Shift+Enter" : "Enter"

        return ShortcutCategory(
            title: "Chat",
            icon: "bubble.left.and.bubble.right",
            shortcuts: [
                KeyboardShortcutItem(submitKey, "Send Message"),
                KeyboardShortcutItem(newlineKey, "Insert New Line"),
                KeyboardShortcutItem("Cmd+Enter", "Send with Line Break", isContextual: true),
                KeyboardShortcutItem("Esc", "Clear Input / Cancel"),
                KeyboardShortcutItem("Cmd+V", "Paste (with image support)"),
                KeyboardShortcutItem("Cmd+P", "Pin/Unpin Conversation"),
                KeyboardShortcutItem("Cmd+Shift+E", "Export Conversation")
            ]
        )
    }

    private var searchCategory: ShortcutCategory {
        ShortcutCategory(
            title: "Search",
            icon: "magnifyingglass",
            shortcuts: [
                KeyboardShortcutItem("Cmd+F", "Search in Conversation"),
                KeyboardShortcutItem("Cmd+Shift+F", "Search All Conversations"),
                KeyboardShortcutItem("Cmd+K", "Command Palette"),
                KeyboardShortcutItem("Enter", "Next Search Result", isContextual: true),
                KeyboardShortcutItem("Shift+Enter", "Previous Search Result", isContextual: true),
                KeyboardShortcutItem("Esc", "Close Search", isContextual: true)
            ]
        )
    }

    private var editingCategory: ShortcutCategory {
        ShortcutCategory(
            title: "Editing",
            icon: "pencil",
            shortcuts: [
                KeyboardShortcutItem("Cmd+Z", "Undo"),
                KeyboardShortcutItem("Cmd+Shift+Z", "Redo"),
                KeyboardShortcutItem("Cmd+A", "Select All"),
                KeyboardShortcutItem("Cmd+C", "Copy"),
                KeyboardShortcutItem("Cmd+V", "Paste"),
                KeyboardShortcutItem("Cmd+X", "Cut"),
                KeyboardShortcutItem("Cmd+Shift+C", "Copy as Markdown"),
                KeyboardShortcutItem("Cmd+Option+C", "Copy as RTF")
            ]
        )
    }

    private var aiCategory: ShortcutCategory {
        ShortcutCategory(
            title: "AI Features",
            icon: "sparkles",
            shortcuts: [
                KeyboardShortcutItem("Cmd+R", "Regenerate Response"),
                KeyboardShortcutItem("Cmd+B", "Branch from Message"),
                KeyboardShortcutItem("Cmd+E", "Edit Last Message"),
                KeyboardShortcutItem("Cmd+.", "Stop Generation"),
                KeyboardShortcutItem("Cmd+Shift+R", "Retry with Different Model"),
                KeyboardShortcutItem("Cmd+Shift+T", "Toggle Extended Thinking")
            ]
        )
    }

    private var windowCategory: ShortcutCategory {
        ShortcutCategory(
            title: "Window",
            icon: "macwindow",
            shortcuts: [
                KeyboardShortcutItem("Cmd+0", "Actual Size"),
                KeyboardShortcutItem("Cmd++", "Zoom In"),
                KeyboardShortcutItem("Cmd+-", "Zoom Out"),
                KeyboardShortcutItem("Cmd+Ctrl+F", "Toggle Full Screen"),
                KeyboardShortcutItem("Cmd+Ctrl+S", "Toggle Sidebar"),
                KeyboardShortcutItem("Cmd+M", "Minimize Window")
            ]
        )
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    KeyboardShortcutsHelpView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    KeyboardShortcutsHelpView()
        .preferredColorScheme(.dark)
}

#Preview("With Search") {
    KeyboardShortcutsHelpView()
        .preferredColorScheme(.dark)
}
