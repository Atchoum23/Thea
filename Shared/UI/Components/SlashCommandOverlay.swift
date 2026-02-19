//
//  SlashCommandOverlay.swift
//  Thea
//
//  Provides an overlay for slash commands in the chat input.
//  When the user types "/" the overlay appears with matching commands,
//  supporting keyboard navigation and selection.
//
//  CREATED: February 8, 2026
//

#if os(macOS) || os(iOS)

import SwiftUI

// MARK: - Slash Command Definition

/// Available slash commands for the chat input
enum SlashCommand: String, CaseIterable, Identifiable {
    case search
    case code
    case summarize
    case explain
    case translate
    case web
    case memory
    case clear
    case branch
    case export
    case help

    var id: String { rawValue }

    /// Display name shown in the overlay
    var name: String { rawValue }

    /// Brief description of what the command does
    var commandDescription: String {
        switch self {
        case .search: return "Search your conversations and memory"
        case .code: return "Generate, review, or explain code"
        case .summarize: return "Summarize text, articles, or conversations"
        case .explain: return "Explain a concept in simple terms"
        case .translate: return "Translate text to another language"
        case .web: return "Search the web for current information"
        case .memory: return "Recall or store information in memory"
        case .clear: return "Clear the current conversation"
        case .branch: return "Branch from the last message"
        case .export: return "Export this conversation"
        case .help: return "Show available commands and tips"
        }
    }

    /// SF Symbol icon for the command
    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .summarize: return "doc.text.magnifyingglass"
        case .explain: return "lightbulb"
        case .translate: return "globe"
        case .web: return "network"
        case .memory: return "brain.head.profile"
        case .clear: return "trash"
        case .branch: return "arrow.triangle.branch"
        case .export: return "square.and.arrow.up"
        case .help: return "questionmark.circle"
        }
    }
}

// MARK: - Slash Command Overlay

/// Overlay that displays matching slash commands as the user types "/"
struct SlashCommandOverlay: View {
    @Binding var inputText: String
    let onSelect: (SlashCommand) -> Void

    @State private var selectedIndex: Int = 0

    /// Whether the overlay should be visible based on current input
    var isVisible: Bool {
        inputText.hasPrefix("/") && !filteredCommands.isEmpty
    }

    /// Commands filtered by the text typed after "/"
    var filteredCommands: [SlashCommand] {
        let query = String(inputText.dropFirst()).lowercased()
            .trimmingCharacters(in: .whitespaces)

        if query.isEmpty {
            return SlashCommand.allCases
        }

        return SlashCommand.allCases.filter { command in
            command.name.localizedCaseInsensitiveContains(query)
                || command.commandDescription.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 0) {
                headerRow

                Divider()
                    .opacity(0.5)

                commandList
            }
            .liquidGlassRounded(cornerRadius: TheaCornerRadius.lg)
            .layeredDepth(TheaShadow.medium, cornerRadius: TheaCornerRadius.lg)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            ))
            .animation(TheaAnimation.entrance, value: isVisible)
            .onChange(of: filteredCommands.count) { _, _ in
                // Reset selection when filter changes
                selectedIndex = 0
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: TheaSpacing.sm) {
            Image(systemName: "command")
                .font(.caption)
                .foregroundStyle(TheaBrandColors.gold)
                .accessibilityHidden(true)

            Text("Commands")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            keyboardHint
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
    }

    private var keyboardHint: some View {
        HStack(spacing: TheaSpacing.xs) {
            keyHint("arrow.up")
            keyHint("arrow.down")
            Text("navigate")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            keyHint("return")
            Text("select")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func keyHint(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: TheaCornerRadius.sm)
                    .fill(Color.primary.opacity(0.06))
            )
            .accessibilityHidden(true)
    }

    // MARK: - Command List

    private var commandList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                SlashCommandRow(
                    command: command,
                    isSelected: index == selectedIndex
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(command)
                }
                #if os(macOS)
                .onHover { hovering in
                    if hovering {
                        selectedIndex = index
                    }
                }
                #endif
            }
        }
        .padding(.vertical, TheaSpacing.xs)
    }

    // MARK: - Keyboard Navigation

    // periphery:ignore - Reserved: moveSelectionUp() instance method — reserved for future feature activation
    /// Move selection up in the command list
    func moveSelectionUp() {
        guard !filteredCommands.isEmpty else { return }
        withAnimation(TheaAnimation.micro) {
            // periphery:ignore - Reserved: moveSelectionUp() instance method reserved for future feature activation
            selectedIndex = (selectedIndex - 1 + filteredCommands.count) % filteredCommands.count
        }
    }

    // periphery:ignore - Reserved: moveSelectionDown() instance method — reserved for future feature activation
    /// Move selection down in the command list
    func moveSelectionDown() {
        guard !filteredCommands.isEmpty else { return }
        // periphery:ignore - Reserved: moveSelectionDown() instance method reserved for future feature activation
        withAnimation(TheaAnimation.micro) {
            selectedIndex = (selectedIndex + 1) % filteredCommands.count
        }
    }

    // periphery:ignore - Reserved: confirmSelection() instance method — reserved for future feature activation
    /// Confirm the currently selected command
    func confirmSelection() {
        // periphery:ignore - Reserved: confirmSelection() instance method reserved for future feature activation
        guard !filteredCommands.isEmpty,
              selectedIndex < filteredCommands.count else { return }
        onSelect(filteredCommands[selectedIndex])
    }
}

// MARK: - Slash Command Row

private struct SlashCommandRow: View {
    let command: SlashCommand
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: TheaSpacing.md) {
            // Command icon
            Image(systemName: command.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? TheaBrandColors.gold : .secondary)
                .frame(width: TheaSize.iconLarge, height: TheaSize.iconLarge)
                .accessibilityHidden(true)

            // Command name and description
            VStack(alignment: .leading, spacing: TheaSpacing.xxs) {
                Text("/\(command.name)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(
                        isSelected
                            ? TheaBrandColors.gold
                            : TheaBrandColors.adaptiveText(colorScheme)
                    )

                Text(command.commandDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "return")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TheaBrandColors.gold.opacity(0.7))
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, TheaSpacing.md)
        .padding(.vertical, TheaSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: TheaCornerRadius.sm)
                .fill(isSelected ? TheaBrandColors.gold.opacity(0.1) : Color.clear)
                .padding(.horizontal, TheaSpacing.xs)
        )
        .animation(TheaAnimation.micro, value: isSelected)
    }
}

// MARK: - View Modifier for Easy Integration

extension View {
    // periphery:ignore - Reserved: withSlashCommands(inputText:onSelect:) instance method reserved for future feature activation
    /// Attach a slash command overlay above this view
    func withSlashCommands(
        inputText: Binding<String>,
        onSelect: @escaping (SlashCommand) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            SlashCommandOverlay(
                inputText: inputText,
                onSelect: onSelect
            )

            self
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Slash Command Overlay") {
    struct PreviewWrapper: View {
        @State private var text = "/"

        var body: some View {
            VStack {
                Spacer()

                SlashCommandOverlay(inputText: $text) { command in
                    text = "/\(command.name) "
                }
                .padding(.horizontal, TheaSpacing.lg)

                TextField("Message Thea...", text: $text)
                    .textFieldStyle(.plain)
                    .padding(TheaSpacing.lg)
                    .liquidGlassRounded(cornerRadius: TheaCornerRadius.xl)
                    .padding(.horizontal, TheaSpacing.lg)
                    .padding(.bottom, TheaSpacing.lg)
            }
            .frame(width: 480, height: 500)
            .background(TheaBrandColors.backgroundGradient)
        }
    }

    return PreviewWrapper()
}
#endif

#endif
