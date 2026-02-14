//
//  KeyboardShortcutsTypes.swift
//  Thea
//
//  Supporting types and views for KeyboardShortcutsSystem
//

import Foundation
import SwiftUI

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

        if modifiers.contains(.control) { parts.append("\u{2303}") }
        if modifiers.contains(.option) { parts.append("\u{2325}") }
        if modifiers.contains(.shift) { parts.append("\u{21E7}") }
        if modifiers.contains(.command) { parts.append("\u{2318}") }

        // Map special keys
        let keyDisplay: String = switch key.lowercased() {
        case " ": "Space"
        case "\r", "return": "\u{21A9}"
        case "\t", "tab": "\u{21E5}"
        case "delete", "\u{7f}": "\u{232B}"
        case "escape", "\u{1b}": "\u{238B}"
        case "\u{2191}", "up": "\u{2191}"
        case "\u{2193}", "down": "\u{2193}"
        case "\u{2190}", "left": "\u{2190}"
        case "\u{2192}", "right": "\u{2192}"
        default: key.uppercased()
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

public struct KeyboardShortcutCategory: Identifiable {
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

#if os(macOS)
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
#else
    public struct KeyboardShortcutsView: View {
        @ObservedObject var system = KeyboardShortcutsSystem.shared
        @State private var selectedCategory: String?
        @State private var editingShortcut: KeyboardShortcut?

        public init() {}

        public var body: some View {
            NavigationStack {
                List {
                    ForEach(system.categories) { category in
                        NavigationLink {
                            List {
                                ForEach(system.shortcuts(in: category.id)) { shortcut in
                                    ShortcutRowView(shortcut: shortcut) {
                                        editingShortcut = shortcut
                                    }
                                }
                            }
                            .navigationTitle(category.name)
                        } label: {
                            Label(category.name, systemImage: category.icon)
                        }
                    }
                }
                .navigationTitle("Keyboard Shortcuts")
            }
            .sheet(item: $editingShortcut) { shortcut in
                ShortcutEditorView(shortcut: shortcut)
            }
        }
    }
#endif

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
