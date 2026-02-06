// ShortcutsSettingsView.swift
// Settings for hardware shortcuts and triggers

import SwiftUI

struct ShortcutsSettingsView: View {
    @State private var shortcuts: [ShortcutSetting] = []
    @State private var showingNewShortcut = false
    @State private var f5TriggerEnabled = true
    @State private var actionButtonEnabled = true
    @State private var doubleTapCrownEnabled = false

    var body: some View {
        Form {
            Section("Hardware Shortcuts") {
                Text("Configure physical triggers to activate Thea")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            #if os(macOS)
            Section("Keyboard Shortcuts") {
                Toggle("F5 Key (Activate Thea)", isOn: $f5TriggerEnabled)
                    .help("Press F5 to activate Thea from anywhere")

                NavigationLink("Configure Hotkeys") {
                    HotkeyConfigurationView()
                }
            }
            #endif

            #if os(iOS)
            Section("iPhone Action Button") {
                Toggle("Action Button (iPhone 15 Pro+)", isOn: $actionButtonEnabled)
                    .help("Use the Action Button to activate Thea")

                if actionButtonEnabled {
                    Picker("Action Button Function", selection: .constant("activate")) {
                        Text("Activate Thea").tag("activate")
                        Text("Start Voice Input").tag("voice")
                        Text("Quick Ask").tag("quick")
                    }
                }
            }
            #endif

            #if os(watchOS)
            Section("Apple Watch") {
                Toggle("Double Tap Crown", isOn: $doubleTapCrownEnabled)
                    .help("Double-tap the Digital Crown to activate")
            }
            #endif

            Section("Custom Shortcuts") {
                if shortcuts.isEmpty {
                    Text("No custom shortcuts configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(shortcuts) { shortcut in
                        ShortcutRow(shortcut: shortcut)
                    }
                    .onDelete(perform: deleteShortcuts)
                }

                Button {
                    showingNewShortcut = true
                } label: {
                    Label("Add Shortcut", systemImage: "plus")
                }
            }

            Section("Siri Shortcuts") {
                NavigationLink("Siri Integration") {
                    SiriShortcutsSettingsView()
                }
            }

            Section("Actions") {
                NavigationLink("Configure Actions") {
                    HardwareShortcutActionsView()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shortcuts")
        .sheet(isPresented: $showingNewShortcut) {
            NewShortcutSheet()
        }
    }

    private func deleteShortcuts(at offsets: IndexSet) {
        shortcuts.remove(atOffsets: offsets)
    }
}

// MARK: - Shortcut Setting

struct ShortcutSetting: Identifiable {
    let id = UUID()
    let name: String
    let trigger: String
    let action: String
    let isEnabled: Bool
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let shortcut: ShortcutSetting

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.name)
                Text("\(shortcut.trigger) → \(shortcut.action)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(shortcut.isEnabled ? .green : .gray)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Hotkey Configuration (macOS)

struct HotkeyConfigurationView: View {
    @State private var activationHotkey = "⌘⇧Space"
    @State private var voiceHotkey = "⌘⇧V"
    @State private var quickAskHotkey = "⌘⇧A"
    @State private var isRecording = false
    @State private var recordingFor: String?

    var body: some View {
        Form {
            Section("Global Hotkeys") {
                HotkeyField(label: "Activate Thea", hotkey: $activationHotkey, isRecording: $isRecording, recordingFor: $recordingFor, identifier: "activate")
                HotkeyField(label: "Start Voice Input", hotkey: $voiceHotkey, isRecording: $isRecording, recordingFor: $recordingFor, identifier: "voice")
                HotkeyField(label: "Quick Ask", hotkey: $quickAskHotkey, isRecording: $isRecording, recordingFor: $recordingFor, identifier: "quickask")
            }

            Section("Function Keys") {
                Toggle("F5 - Activate Thea", isOn: .constant(true))
                Toggle("F6 - Toggle Listening", isOn: .constant(false))
            }

            Section {
                Button("Reset to Defaults") {
                    activationHotkey = "⌘⇧Space"
                    voiceHotkey = "⌘⇧V"
                    quickAskHotkey = "⌘⇧A"
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Hotkeys")
    }
}

struct HotkeyField: View {
    let label: String
    @Binding var hotkey: String
    @Binding var isRecording: Bool
    @Binding var recordingFor: String?
    let identifier: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                isRecording = true
                recordingFor = identifier
            } label: {
                Text(recordingFor == identifier ? "Press keys..." : hotkey)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(recordingFor == identifier ? Color.theaPrimary.opacity(0.2) : Color.secondary.opacity(0.2))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Siri Shortcuts Settings

struct SiriShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Available Shortcuts") {
                Text("Siri shortcuts allow you to trigger Thea actions with voice commands.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Phrases") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\"Hey Siri, ask Thea\"")
                        .font(.body)
                    Text("Opens Thea for a new conversation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\"Hey Siri, Thea quick ask\"")
                        .font(.body)
                    Text("Opens quick ask overlay")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Add to Siri") {
                    // Would open Siri shortcut setup
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Siri Integration")
    }
}

// MARK: - Shortcut Actions View

struct HardwareShortcutActionsView: View {
    var body: some View {
        Form {
            Section("Available Actions") {
                ForEach(HardwareShortcutAction.allCases, id: \.self) { action in
                    HStack {
                        Image(systemName: action.icon)
                            .frame(width: 24)
                            .foregroundStyle(.theaPrimary)
                        VStack(alignment: .leading) {
                            Text(action.rawValue)
                            Text(action.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Actions")
    }
}

extension HardwareShortcutAction {
    var icon: String {
        switch self {
        case .activateThea: return "sparkles"
        case .startVoiceInput: return "waveform"
        case .toggleListening: return "ear"
        case .quickAsk: return "text.bubble"
        case .newConversation: return "plus.message"
        case .runLastWorkflow: return "arrow.clockwise"
        case .takeScreenshot: return "camera"
        }
    }

    var description: String {
        switch self {
        case .activateThea: return "Bring Thea to front"
        case .startVoiceInput: return "Start listening for voice"
        case .toggleListening: return "Toggle voice activation"
        case .quickAsk: return "Open quick ask overlay"
        case .newConversation: return "Start a new chat"
        case .runLastWorkflow: return "Re-run the last workflow"
        case .takeScreenshot: return "Capture screen and ask about it"
        }
    }
}

// MARK: - New Shortcut Sheet

struct NewShortcutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedTrigger = "customHotkey"
    @State private var selectedAction = HardwareShortcutAction.activateThea

    var body: some View {
        NavigationStack {
            Form {
                Section("Shortcut Details") {
                    TextField("Name", text: $name)
                }

                Section("Trigger") {
                    Picker("Trigger Type", selection: $selectedTrigger) {
                        Text("Custom Hotkey").tag("customHotkey")
                        Text("Function Key").tag("functionKey")
                    }
                }

                Section("Action") {
                    Picker("Action", selection: $selectedAction) {
                        ForEach(HardwareShortcutAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Shortcut")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Save shortcut
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
