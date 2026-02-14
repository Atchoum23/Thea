//
//  KeyboardShortcutsHelpView.swift
//  Thea
//
//  Keyboard shortcuts help overlay (Cmd+/)
//  Shows all available keyboard shortcuts organized by category.
//

import SwiftUI

struct KeyboardShortcutsSimpleView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // General shortcuts
                    shortcutSection(
                        title: "General",
                        icon: "command",
                        shortcuts: generalShortcuts
                    )

                    // Conversations
                    shortcutSection(
                        title: "Conversations",
                        icon: "bubble.left.and.bubble.right",
                        shortcuts: conversationShortcuts
                    )

                    // Input
                    shortcutSection(
                        title: "Input",
                        icon: "keyboard",
                        shortcuts: inputShortcuts
                    )

                    // Search
                    shortcutSection(
                        title: "Search",
                        icon: "magnifyingglass",
                        shortcuts: searchShortcuts
                    )

                    // Messages
                    shortcutSection(
                        title: "Messages",
                        icon: "text.bubble",
                        shortcuts: messageShortcuts
                    )

                    // Navigation
                    shortcutSection(
                        title: "Navigation",
                        icon: "arrow.up.arrow.down",
                        shortcuts: navigationShortcuts
                    )
                }
                .padding()
            }
            .navigationTitle("Keyboard Shortcuts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }

    // MARK: - Shortcut Section

    private func shortcutSection(
        title: String,
        icon: String,
        shortcuts: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TheaBrandColors.gold)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.headline)
            }

            VStack(spacing: 8) {
                ForEach(shortcuts, id: \.0) { shortcut, description in
                    HStack {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        shortcutBadge(shortcut)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.leading, 32)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func shortcutBadge(_ shortcut: String) -> some View {
        let parts = shortcut.components(separatedBy: "+")
        return HStack(spacing: 4) {
            ForEach(parts, id: \.self) { part in
                Text(symbolForKey(part))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func symbolForKey(_ key: String) -> String {
        switch key.lowercased() {
        case "cmd", "command": return "⌘"
        case "shift": return "⇧"
        case "alt", "option": return "⌥"
        case "ctrl", "control": return "⌃"
        case "enter", "return": return "↩︎"
        case "esc", "escape": return "⎋"
        case "delete", "backspace": return "⌫"
        case "tab": return "⇥"
        case "space": return "␣"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        default: return key.uppercased()
        }
    }

    // MARK: - Shortcut Lists

    private var generalShortcuts: [(String, String)] {
        [
            ("Cmd+,", "Open Settings"),
            ("Cmd+/", "Show Keyboard Shortcuts"),
            ("Cmd+Q", "Quit Thea"),
            ("Cmd+W", "Close Window"),
            ("Cmd+M", "Minimize Window")
        ]
    }

    private var conversationShortcuts: [(String, String)] {
        [
            ("Cmd+N", "New Conversation"),
            ("Cmd+P", "Pin/Unpin Conversation"),
            ("Cmd+R", "Rename Conversation"),
            ("Delete", "Delete Conversation"),
            ("Cmd+E", "Export Conversation")
        ]
    }

    private var inputShortcuts: [(String, String)] {
        let submitKey = settings.submitShortcut == "cmdEnter" ? "Cmd+Enter" : (settings.submitShortcut == "shiftEnter" ? "Shift+Enter" : "Enter")
        let newlineKey = settings.submitShortcut == "enter" ? "Shift+Enter" : "Enter"

        return [
            (submitKey, "Send Message"),
            (newlineKey, "New Line"),
            ("Cmd+V", "Paste (with image support)"),
            ("Esc", "Clear Input / Cancel")
        ]
    }

    private var searchShortcuts: [(String, String)] {
        [
            ("Cmd+F", "Search in Conversation"),
            ("Enter", "Next Search Result"),
            ("Shift+Enter", "Previous Search Result"),
            ("Esc", "Close Search"),
            ("Cmd+Shift+F", "Search All Conversations")
        ]
    }

    private var messageShortcuts: [(String, String)] {
        [
            ("Cmd+C", "Copy Message"),
            ("Cmd+Shift+C", "Copy as Markdown"),
            ("Cmd+Option+C", "Copy as RTF")
        ]
    }

    private var navigationShortcuts: [(String, String)] {
        [
            ("Cmd+1", "Go to Conversations"),
            ("Cmd+2", "Go to Projects"),
            ("Cmd+3", "Go to Knowledge"),
            ("Cmd+[", "Previous Conversation"),
            ("Cmd+]", "Next Conversation"),
            ("Cmd+↑", "Scroll to Top"),
            ("Cmd+↓", "Scroll to Bottom")
        ]
    }
}

// MARK: - Preview

#Preview {
    KeyboardShortcutsSimpleView()
}
