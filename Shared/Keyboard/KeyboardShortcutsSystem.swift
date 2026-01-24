// KeyboardShortcutsSystem.swift
// Comprehensive keyboard shortcuts with customization

import Foundation
import OSLog
import Combine
import SwiftUI
#if os(macOS)
import AppKit
import Carbon.HIToolbox
#endif

// MARK: - Keyboard Shortcuts Manager

/// Manages all keyboard shortcuts with customization support
@MainActor
public final class KeyboardShortcutsSystem: ObservableObject {
    public static let shared = KeyboardShortcutsSystem()

    private let logger = Logger(subsystem: "com.thea.app", category: "Keyboard")

    // MARK: - Published State

    @Published public private(set) var shortcuts: [KeyboardShortcut] = []
    @Published public private(set) var categories: [ShortcutCategory] = []
    @Published public private(set) var conflicts: [ShortcutConflict] = []
    @Published public var isListening = false
    @Published public var recordedShortcut: RecordedShortcut?

    // MARK: - Handlers

    private var handlers: [String: () -> Void] = [:]

    // MARK: - Initialization

    private init() {
        registerDefaultShortcuts()
        loadCustomizations()
        checkForConflicts()
    }

    // MARK: - Registration

    private func registerDefaultShortcuts() {
        categories = [
            ShortcutCategory(id: "navigation", name: "Navigation", icon: "arrow.left.arrow.right"),
            ShortcutCategory(id: "conversations", name: "Conversations", icon: "bubble.left.and.bubble.right"),
            ShortcutCategory(id: "editing", name: "Editing", icon: "pencil"),
            ShortcutCategory(id: "ai", name: "AI Actions", icon: "sparkles"),
            ShortcutCategory(id: "window", name: "Window", icon: "macwindow"),
            ShortcutCategory(id: "tools", name: "Tools", icon: "wrench.and.screwdriver")
        ]

        shortcuts = [
            // Navigation
            KeyboardShortcut(
                id: "new-conversation",
                name: "New Conversation",
                description: "Start a new conversation",
                category: "conversations",
                defaultKey: KeyCombo(key: "n", modifiers: [.command]),
                action: "newConversation"
            ),
            KeyboardShortcut(
                id: "close-conversation",
                name: "Close Conversation",
                description: "Close current conversation",
                category: "conversations",
                defaultKey: KeyCombo(key: "w", modifiers: [.command]),
                action: "closeConversation"
            ),
            KeyboardShortcut(
                id: "next-conversation",
                name: "Next Conversation",
                description: "Switch to next conversation",
                category: "navigation",
                defaultKey: KeyCombo(key: "]", modifiers: [.command, .shift]),
                action: "nextConversation"
            ),
            KeyboardShortcut(
                id: "previous-conversation",
                name: "Previous Conversation",
                description: "Switch to previous conversation",
                category: "navigation",
                defaultKey: KeyCombo(key: "[", modifiers: [.command, .shift]),
                action: "previousConversation"
            ),
            KeyboardShortcut(
                id: "search",
                name: "Search",
                description: "Search conversations and content",
                category: "navigation",
                defaultKey: KeyCombo(key: "f", modifiers: [.command]),
                action: "search"
            ),
            KeyboardShortcut(
                id: "command-palette",
                name: "Command Palette",
                description: "Open command palette",
                category: "navigation",
                defaultKey: KeyCombo(key: "k", modifiers: [.command]),
                action: "commandPalette"
            ),
            KeyboardShortcut(
                id: "quick-switcher",
                name: "Quick Switcher",
                description: "Quickly switch between conversations",
                category: "navigation",
                defaultKey: KeyCombo(key: "p", modifiers: [.command]),
                action: "quickSwitcher"
            ),

            // AI Actions
            KeyboardShortcut(
                id: "quick-ask",
                name: "Quick Ask",
                description: "Open quick ask overlay",
                category: "ai",
                defaultKey: KeyCombo(key: " ", modifiers: [.command, .shift]),
                action: "quickAsk",
                isGlobal: true
            ),
            KeyboardShortcut(
                id: "voice-mode",
                name: "Toggle Voice Mode",
                description: "Start or stop voice input",
                category: "ai",
                defaultKey: KeyCombo(key: "v", modifiers: [.command, .shift]),
                action: "toggleVoice"
            ),
            KeyboardShortcut(
                id: "regenerate",
                name: "Regenerate Response",
                description: "Ask AI to regenerate last response",
                category: "ai",
                defaultKey: KeyCombo(key: "r", modifiers: [.command, .shift]),
                action: "regenerate"
            ),
            KeyboardShortcut(
                id: "stop-generation",
                name: "Stop Generation",
                description: "Stop AI response generation",
                category: "ai",
                defaultKey: KeyCombo(key: ".", modifiers: [.command]),
                action: "stopGeneration"
            ),
            KeyboardShortcut(
                id: "explain-selection",
                name: "Explain Selection",
                description: "Ask AI to explain selected text",
                category: "ai",
                defaultKey: KeyCombo(key: "e", modifiers: [.command, .shift]),
                action: "explainSelection"
            ),

            // Editing
            KeyboardShortcut(
                id: "edit-message",
                name: "Edit Last Message",
                description: "Edit your last message",
                category: "editing",
                defaultKey: KeyCombo(key: "↑", modifiers: [.command]),
                action: "editLastMessage"
            ),
            KeyboardShortcut(
                id: "copy-response",
                name: "Copy Response",
                description: "Copy AI response to clipboard",
                category: "editing",
                defaultKey: KeyCombo(key: "c", modifiers: [.command, .shift]),
                action: "copyResponse"
            ),
            KeyboardShortcut(
                id: "copy-code",
                name: "Copy Code Block",
                description: "Copy focused code block",
                category: "editing",
                defaultKey: KeyCombo(key: "c", modifiers: [.command, .option]),
                action: "copyCode"
            ),
            KeyboardShortcut(
                id: "insert-code",
                name: "Insert Code Block",
                description: "Insert a code block",
                category: "editing",
                defaultKey: KeyCombo(key: "`", modifiers: [.command]),
                action: "insertCode"
            ),

            // Window
            KeyboardShortcut(
                id: "toggle-sidebar",
                name: "Toggle Sidebar",
                description: "Show or hide sidebar",
                category: "window",
                defaultKey: KeyCombo(key: "s", modifiers: [.command, .control]),
                action: "toggleSidebar"
            ),
            KeyboardShortcut(
                id: "toggle-fullscreen",
                name: "Toggle Fullscreen",
                description: "Enter or exit fullscreen",
                category: "window",
                defaultKey: KeyCombo(key: "f", modifiers: [.command, .control]),
                action: "toggleFullscreen"
            ),
            KeyboardShortcut(
                id: "zoom-in",
                name: "Zoom In",
                description: "Increase text size",
                category: "window",
                defaultKey: KeyCombo(key: "=", modifiers: [.command]),
                action: "zoomIn"
            ),
            KeyboardShortcut(
                id: "zoom-out",
                name: "Zoom Out",
                description: "Decrease text size",
                category: "window",
                defaultKey: KeyCombo(key: "-", modifiers: [.command]),
                action: "zoomOut"
            ),
            KeyboardShortcut(
                id: "reset-zoom",
                name: "Reset Zoom",
                description: "Reset text size to default",
                category: "window",
                defaultKey: KeyCombo(key: "0", modifiers: [.command]),
                action: "resetZoom"
            ),

            // Tools
            KeyboardShortcut(
                id: "open-settings",
                name: "Open Settings",
                description: "Open app settings",
                category: "tools",
                defaultKey: KeyCombo(key: ",", modifiers: [.command]),
                action: "openSettings"
            ),
            KeyboardShortcut(
                id: "open-agents",
                name: "Open Agents",
                description: "Open agents panel",
                category: "tools",
                defaultKey: KeyCombo(key: "a", modifiers: [.command, .shift]),
                action: "openAgents"
            ),
            KeyboardShortcut(
                id: "open-artifacts",
                name: "Open Artifacts",
                description: "Open artifacts panel",
                category: "tools",
                defaultKey: KeyCombo(key: "o", modifiers: [.command, .shift]),
                action: "openArtifacts"
            ),
            KeyboardShortcut(
                id: "open-memories",
                name: "Open Memories",
                description: "Open memories panel",
                category: "tools",
                defaultKey: KeyCombo(key: "m", modifiers: [.command, .shift]),
                action: "openMemories"
            ),
            KeyboardShortcut(
                id: "sync-now",
                name: "Sync Now",
                description: "Trigger manual sync",
                category: "tools",
                defaultKey: KeyCombo(key: "s", modifiers: [.command, .shift]),
                action: "syncNow"
            )
        ]

        logger.info("Registered \(self.shortcuts.count) default shortcuts")
    }

    // MARK: - Handler Registration

    /// Register a handler for a shortcut action
    public func registerHandler(for action: String, handler: @escaping () -> Void) {
        handlers[action] = handler
    }

    /// Execute a shortcut action
    public func executeAction(_ action: String) {
        if let handler = handlers[action] {
            handler()
            logger.debug("Executed action: \(action)")

            AnalyticsManager.shared.track("keyboard_shortcut_used", properties: [
                "action": action
            ])
        } else {
            logger.warning("No handler registered for action: \(action)")
        }
    }

    // MARK: - Customization

    /// Set custom key combination for a shortcut
    public func setCustomKey(_ shortcutId: String, keyCombo: KeyCombo?) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcutId }) else {
            return
        }

        shortcuts[index].customKey = keyCombo
        saveCustomizations()
        checkForConflicts()

        logger.info("Updated shortcut \(shortcutId) to \(keyCombo?.displayString ?? "disabled")")
    }

    /// Reset shortcut to default
    public func resetToDefault(_ shortcutId: String) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcutId }) else {
            return
        }

        shortcuts[index].customKey = nil
        saveCustomizations()
        checkForConflicts()

        logger.info("Reset shortcut \(shortcutId) to default")
    }

    /// Reset all shortcuts to defaults
    public func resetAllToDefaults() {
        for i in shortcuts.indices {
            shortcuts[i].customKey = nil
        }
        saveCustomizations()
        checkForConflicts()

        logger.info("Reset all shortcuts to defaults")
    }

    // MARK: - Persistence

    private func saveCustomizations() {
        let customizations = shortcuts.compactMap { shortcut -> (String, KeyCombo)? in
            if let custom = shortcut.customKey {
                return (shortcut.id, custom)
            }
            return nil
        }

        let dict = customizations.reduce(into: [String: [String: Any]]()) { result, item in
            result[item.0] = [
                "key": item.1.key,
                "modifiers": item.1.modifiers.map { $0.rawValue }
            ]
        }

        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: "keyboard.customizations")
        }
    }

    private func loadCustomizations() {
        guard let data = UserDefaults.standard.data(forKey: "keyboard.customizations"),
              let dict = try? JSONDecoder().decode([String: [String: Any]].self, from: data) else {
            return
        }

        for (id, value) in dict {
            if let index = shortcuts.firstIndex(where: { $0.id == id }),
               let key = value["key"] as? String,
               let modifierRaw = value["modifiers"] as? [Int] {
                let modifiers = Set(modifierRaw.compactMap { KeyModifier(rawValue: $0) })
                shortcuts[index].customKey = KeyCombo(key: key, modifiers: modifiers)
            }
        }
    }

    // MARK: - Conflict Detection

    private func checkForConflicts() {
        var newConflicts: [ShortcutConflict] = []
        var seen: [String: String] = [:] // keyCombo string -> shortcut id

        for shortcut in shortcuts {
            let keyCombo = shortcut.effectiveKeyCombo
            let comboString = keyCombo.displayString

            if let existingId = seen[comboString] {
                newConflicts.append(ShortcutConflict(
                    shortcut1Id: existingId,
                    shortcut2Id: shortcut.id,
                    keyCombo: keyCombo
                ))
            } else {
                seen[comboString] = shortcut.id
            }
        }

        conflicts = newConflicts

        if !conflicts.isEmpty {
            logger.warning("Found \(conflicts.count) shortcut conflicts")
        }
    }

    // MARK: - Key Recording

    /// Start recording a new key combination
    public func startRecording() {
        isListening = true
        recordedShortcut = nil
    }

    /// Stop recording
    public func stopRecording() {
        isListening = false
    }

    /// Record a key event
    public func recordKey(key: String, modifiers: Set<KeyModifier>) {
        guard isListening else { return }

        recordedShortcut = RecordedShortcut(
            keyCombo: KeyCombo(key: key, modifiers: modifiers),
            timestamp: Date()
        )

        isListening = false
    }

    // MARK: - macOS Global Shortcuts

    #if os(macOS)
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// Setup global keyboard monitoring
    public func setupGlobalMonitoring() {
        // Global monitor for global shortcuts
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, isGlobal: true)
        }

        // Local monitor for app shortcuts
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event, isGlobal: false)
            return event
        }

        logger.info("Global keyboard monitoring enabled")
    }

    /// Stop global monitoring
    public func stopGlobalMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        logger.info("Global keyboard monitoring disabled")
    }

    private func handleKeyEvent(_ event: NSEvent, isGlobal: Bool) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        let modifiers = modifiersFromEvent(event)

        // Check for recording
        if isListening {
            Task { @MainActor in
                recordKey(key: characters, modifiers: modifiers)
            }
            return
        }

        // Find matching shortcut
        for shortcut in shortcuts {
            // Skip non-global shortcuts in global context
            if isGlobal && !shortcut.isGlobal { continue }

            let keyCombo = shortcut.effectiveKeyCombo
            if keyCombo.key.lowercased() == characters.lowercased() &&
               keyCombo.modifiers == modifiers {
                Task { @MainActor in
                    executeAction(shortcut.action)
                }
                break
            }
        }
    }

    private func modifiersFromEvent(_ event: NSEvent) -> Set<KeyModifier> {
        var modifiers: Set<KeyModifier> = []

        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }

        return modifiers
    }
    #endif

    // MARK: - Lookup

    /// Get shortcut by ID
    public func shortcut(for id: String) -> KeyboardShortcut? {
        shortcuts.first { $0.id == id }
    }

    /// Get shortcuts for a category
    public func shortcuts(in category: String) -> [KeyboardShortcut] {
        shortcuts.filter { $0.category == category }
    }

    /// Find shortcut by key combination
    public func shortcut(for keyCombo: KeyCombo) -> KeyboardShortcut? {
        shortcuts.first { $0.effectiveKeyCombo == keyCombo }
    }
}

// MARK: - Types

public struct KeyboardShortcut: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let category: String
    public let defaultKey: KeyCombo
    public let action: String
    public var isGlobal: Bool = false
    public var customKey: KeyCombo?

    public var effectiveKeyCombo: KeyCombo {
        customKey ?? defaultKey
    }

    public var isCustomized: Bool {
        customKey != nil
    }
}

public struct KeyCombo: Equatable, Codable {
    public let key: String
    public let modifiers: Set<KeyModifier>

    public init(key: String, modifiers: Set<KeyModifier>) {
        self.key = key
        self.modifiers = modifiers
    }

    public var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        // Map special keys
        let keyDisplay: String
        switch key.lowercased() {
        case " ": keyDisplay = "Space"
        case "\r", "return": keyDisplay = "↩"
        case "\t", "tab": keyDisplay = "⇥"
        case "delete", "\u{7f}": keyDisplay = "⌫"
        case "escape", "\u{1b}": keyDisplay = "⎋"
        case "↑", "up": keyDisplay = "↑"
        case "↓", "down": keyDisplay = "↓"
        case "←", "left": keyDisplay = "←"
        case "→", "right": keyDisplay = "→"
        default: keyDisplay = key.uppercased()
        }

        parts.append(keyDisplay)

        return parts.joined()
    }
}

public enum KeyModifier: Int, Codable, Hashable {
    case command = 1
    case option = 2
    case control = 3
    case shift = 4
}

public struct ShortcutCategory: Identifiable {
    public let id: String
    public let name: String
    public let icon: String
}

public struct ShortcutConflict: Identifiable {
    public let id = UUID()
    public let shortcut1Id: String
    public let shortcut2Id: String
    public let keyCombo: KeyCombo
}

public struct RecordedShortcut {
    public let keyCombo: KeyCombo
    public let timestamp: Date
}

// MARK: - SwiftUI Views

public struct KeyboardShortcutsView: View {
    @ObservedObject var system = KeyboardShortcutsSystem.shared
    @State private var selectedCategory: String?
    @State private var editingShortcut: KeyboardShortcut?

    public init() {}

    public var body: some View {
        HSplitView {
            // Categories list
            List(selection: $selectedCategory) {
                ForEach(system.categories) { category in
                    Label(category.name, systemImage: category.icon)
                        .tag(category.id)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 150)

            // Shortcuts list
            List {
                if let category = selectedCategory {
                    ForEach(system.shortcuts(in: category)) { shortcut in
                        ShortcutRowView(shortcut: shortcut) {
                            editingShortcut = shortcut
                        }
                    }
                } else {
                    Text("Select a category")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 400)
        }
        .sheet(item: $editingShortcut) { shortcut in
            ShortcutEditorView(shortcut: shortcut)
        }
        .toolbar {
            ToolbarItem {
                Button("Reset All") {
                    system.resetAllToDefaults()
                }
            }
        }
        .onAppear {
            selectedCategory = system.categories.first?.id
        }
    }
}

struct ShortcutRowView: View {
    let shortcut: KeyboardShortcut
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(shortcut.name)
                    .font(.headline)
                Text(shortcut.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Key combo display
            Text(shortcut.effectiveKeyCombo.displayString)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Customization indicator
            if shortcut.isCustomized {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.blue)
            }

            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct ShortcutEditorView: View {
    let shortcut: KeyboardShortcut
    @ObservedObject var system = KeyboardShortcutsSystem.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Shortcut")
                .font(.headline)

            Text(shortcut.name)
                .font(.title2)

            // Current shortcut
            VStack {
                Text("Current: \(shortcut.effectiveKeyCombo.displayString)")
                    .font(.system(.title, design: .monospaced))

                if shortcut.isCustomized {
                    Text("Default: \(shortcut.defaultKey.displayString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Recording
            if system.isListening {
                Text("Press new shortcut...")
                    .foregroundStyle(.blue)
            } else if let recorded = system.recordedShortcut {
                Text("New: \(recorded.keyCombo.displayString)")
                    .font(.system(.title2, design: .monospaced))
            }

            // Actions
            HStack(spacing: 16) {
                Button("Record New") {
                    system.startRecording()
                }
                .buttonStyle(.borderedProminent)

                if shortcut.isCustomized {
                    Button("Reset to Default") {
                        system.resetToDefault(shortcut.id)
                        dismiss()
                    }
                }

                Button("Cancel") {
                    system.stopRecording()
                    dismiss()
                }

                if let recorded = system.recordedShortcut {
                    Button("Save") {
                        system.setCustomKey(shortcut.id, keyCombo: recorded.keyCombo)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}
