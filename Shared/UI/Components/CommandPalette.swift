//
//  CommandPalette.swift
//  Thea
//
//  Quick action command palette (Cmd+K)
//  Inspired by VS Code, Cursor.app, and Claude Desktop
//

import SwiftUI

// MARK: - Command Model

/// A command that can be executed from the palette
struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let shortcut: String?
    let category: CommandCategory
    let action: () -> Void

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        shortcut: String? = nil,
        category: CommandCategory = .general,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.category = category
        self.action = action
    }
}

/// Categories for organizing commands
enum CommandCategory: String, CaseIterable {
    case general = "General"
    case conversation = "Conversation"
    case navigation = "Navigation"
    case settings = "Settings"
    case model = "Model"
    case file = "File"

    var icon: String {
        switch self {
        case .general: return "command"
        case .conversation: return "bubble.left.and.bubble.right"
        case .navigation: return "arrow.triangle.turn.up.right.diamond"
        case .settings: return "gear"
        case .model: return "cpu"
        // periphery:ignore - Reserved: icon property reserved for future feature activation
        case .file: return "doc"
        }
    }
}

// MARK: - Command Palette View

/// The main command palette overlay
struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let commands: [PaletteCommand]

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var filteredCommands: [PaletteCommand] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedCommands: [(CommandCategory, [PaletteCommand])] {
        let grouped = Dictionary(grouping: filteredCommands, by: \.category)
        return CommandCategory.allCases.compactMap { category in
            if let commands = grouped[category], !commands.isEmpty {
                return (category, commands)
            }
            return nil
        }
    }

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Palette panel
            VStack(spacing: 0) {
                // Search field
                searchField

                Divider()

                // Commands list
                if filteredCommands.isEmpty {
                    emptyState
                } else {
                    commandsList
                }
            }
            .frame(width: 500)
            .frame(maxHeight: 400)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .onAppear {
                isSearchFocused = true
            }
        }
        .onKeyPress(keys: [.upArrow, .downArrow, .return, .escape]) { press in
            handleKeyPress(press.key)
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search commands...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFocused)
                .onChange(of: searchText) { _, _ in
                    selectedIndex = 0
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Keyboard hint
            Text("⌘K")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(16)
    }

    // MARK: - Commands List

    private var commandsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedCommands, id: \.0) { category, commands in
                        // Category header
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 6)

                        // Commands in category
                        ForEach(commands) { command in
                            let globalIndex = getGlobalIndex(for: command)
                            CommandRow(
                                command: command,
                                isSelected: globalIndex == selectedIndex
                            )
                            .id(command.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                executeCommand(command)
                            }
                            .onHover { hovering in
                                if hovering {
                                    selectedIndex = globalIndex
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                if let command = filteredCommands[safe: newIndex] {
                    proxy.scrollTo(command.id, anchor: .center)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No commands found")
                .font(.headline)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Helpers

    private func getGlobalIndex(for command: PaletteCommand) -> Int {
        filteredCommands.firstIndex { $0.id == command.id } ?? 0
    }

    private func handleKeyPress(_ key: KeyEquivalent) -> KeyPress.Result {
        switch key {
        case .upArrow:
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        case .downArrow:
            selectedIndex = min(filteredCommands.count - 1, selectedIndex + 1)
            return .handled
        case .return:
            if let command = filteredCommands[safe: selectedIndex] {
                executeCommand(command)
            }
            return .handled
        case .escape:
            dismiss()
            return .handled
        default:
            return .ignored
        }
    }

    private func executeCommand(_ command: PaletteCommand) {
        dismiss()
        command.action()
    }

    private func dismiss() {
        isPresented = false
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: command.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 24)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)

                if let subtitle = command.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }

            Spacer()

            // Keyboard shortcut
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.theaPrimaryDefault : Color.clear)
    }
}

// MARK: - Command Palette Manager

/// Manager for registering and showing the command palette
@MainActor
class CommandPaletteManager: ObservableObject {
    static let shared = CommandPaletteManager()

    @Published var isPresented = false
    @Published private(set) var commands: [PaletteCommand] = []

    private init() {
        registerDefaultCommands()
    }

    func toggle() {
        isPresented.toggle()
    }

    func show() {
        isPresented = true
    // periphery:ignore - Reserved: toggle() instance method reserved for future feature activation
    }

    func hide() {
        // periphery:ignore - Reserved: show() instance method reserved for future feature activation
        isPresented = false
    }

    // periphery:ignore - Reserved: hide() instance method reserved for future feature activation
    func registerCommand(_ command: PaletteCommand) {
        commands.removeAll { $0.id == command.id }
        commands.append(command)
    // periphery:ignore - Reserved: registerCommand(_:) instance method reserved for future feature activation
    }

    func registerCommands(_ newCommands: [PaletteCommand]) {
        for command in newCommands {
            // periphery:ignore - Reserved: registerCommands(_:) instance method reserved for future feature activation
            registerCommand(command)
        }
    }

    private func registerDefaultCommands() {
        commands = conversationCommands + navigationCommands + modelCommands + settingsCommands + generalCommands
    }

    private var conversationCommands: [PaletteCommand] {
        [
            PaletteCommand(
                id: "new-conversation", title: "New Conversation",
                subtitle: "Start a fresh chat", icon: "plus.bubble",
                shortcut: "⌘N", category: .conversation
            ) { NotificationCenter.default.post(name: .newConversation, object: nil) },
            PaletteCommand(
                id: "clear-conversation", title: "Clear Conversation",
                subtitle: "Clear the current chat history", icon: "trash",
                category: .conversation
            ) { NotificationCenter.default.post(name: .clearConversation, object: nil) },
            PaletteCommand(
                id: "export-conversation", title: "Export Conversation",
                subtitle: "Save chat as Markdown or JSON", icon: "square.and.arrow.up",
                category: .conversation
            ) { NotificationCenter.default.post(name: .exportConversation, object: nil) }
        ]
    }

    private var navigationCommands: [PaletteCommand] {
        [
            PaletteCommand(
                id: "go-to-chat", title: "Go to Chat",
                icon: "bubble.left.and.bubble.right", shortcut: "⌘1", category: .navigation
            ) { NotificationCenter.default.post(name: .navigateToSection, object: "chat") },
            PaletteCommand(
                id: "go-to-projects", title: "Go to Projects",
                icon: "folder", shortcut: "⌘2", category: .navigation
            ) { NotificationCenter.default.post(name: .navigateToSection, object: "projects") },
            PaletteCommand(
                id: "go-to-settings", title: "Go to Settings",
                icon: "gear", shortcut: "⌘,", category: .navigation
            ) { NotificationCenter.default.post(name: .navigateToSection, object: "settings") }
        ]
    }

    private var modelCommands: [PaletteCommand] {
        [
            PaletteCommand(
                id: "switch-model-gpt4", title: "Switch to GPT-4",
                subtitle: "OpenAI's most capable model", icon: "cpu", category: .model
            ) { NotificationCenter.default.post(name: .switchModel, object: "gpt-4") },
            PaletteCommand(
                id: "switch-model-claude", title: "Switch to Claude",
                subtitle: "Anthropic's Claude model", icon: "cpu", category: .model
            ) { NotificationCenter.default.post(name: .switchModel, object: "claude") },
            PaletteCommand(
                id: "switch-model-local", title: "Switch to Local Model",
                subtitle: "On-device MLX model", icon: "desktopcomputer", category: .model
            ) { NotificationCenter.default.post(name: .switchModel, object: "local") }
        ]
    }

    private var settingsCommands: [PaletteCommand] {
        [
            PaletteCommand(
                id: "toggle-dark-mode", title: "Toggle Dark Mode",
                icon: "moon", category: .settings
            ) { NotificationCenter.default.post(name: .toggleDarkMode, object: nil) }
        ]
    }

    private var generalCommands: [PaletteCommand] {
        [
            PaletteCommand(
                id: "show-keyboard-shortcuts", title: "Show Keyboard Shortcuts",
                subtitle: "View all available shortcuts", icon: "keyboard",
                shortcut: "⌘/", category: .general
            ) { NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil) }
        ]
    }
}

// MARK: - Notification Names (extends existing ones in TheaApp.swift)

extension Notification.Name {
    // Note: newConversation is defined in TheaApp.swift
    static let clearConversation = Notification.Name("commandPalette.clearConversation")
    static let exportConversation = Notification.Name("commandPalette.exportConversation")
    static let navigateToSection = Notification.Name("commandPalette.navigateToSection")
    static let switchModel = Notification.Name("commandPalette.switchModel")
    static let toggleDarkMode = Notification.Name("commandPalette.toggleDarkMode")
    static let showKeyboardShortcuts = Notification.Name("commandPalette.showKeyboardShortcuts")
    static let showCommandPalette = Notification.Name("commandPalette.show")
    static let selectNewConversation = Notification.Name("thea.selectNewConversation")
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - View Modifier

/// View modifier to add command palette overlay (shortcut is registered in app commands)
struct CommandPaletteModifier: ViewModifier {
    // periphery:ignore - Reserved: CommandPaletteModifier type reserved for future feature activation
    @StateObject private var manager = CommandPaletteManager.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if manager.isPresented {
                    CommandPaletteView(
                        isPresented: $manager.isPresented,
                        commands: manager.commands
                    )
                }
            }
    }
}

extension View {
    /// Add command palette overlay support
    // periphery:ignore - Reserved: commandPalette() instance method reserved for future feature activation
    func commandPalette() -> some View {
        modifier(CommandPaletteModifier())
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Command Palette") {
        ZStack {
            Color.gray.opacity(0.3)

            CommandPaletteView(
                isPresented: .constant(true),
                commands: [
                    PaletteCommand(id: "1", title: "New Conversation", icon: "plus.bubble", shortcut: "⌘N", category: .conversation) {},
                    PaletteCommand(id: "2", title: "Clear History", icon: "trash", category: .conversation) {},
                    PaletteCommand(id: "3", title: "Go to Settings", icon: "gear", shortcut: "⌘,", category: .navigation) {},
                    PaletteCommand(id: "4", title: "Switch Model", subtitle: "Change AI model", icon: "cpu", category: .model) {}
                ]
            )
        }
        .frame(width: 600, height: 500)
    }
#endif
