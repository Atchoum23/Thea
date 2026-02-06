//
//  ActionPickerSheet.swift
//  Thea
//
//  Action picker sheet for selecting task actions
//  Extracted from AutonomousTaskSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Action Picker Sheet

struct ActionPickerSheet: View {
    let onSelect: (AutoTaskAction) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ActionType = .notification
    @State private var notificationTitle = ""
    @State private var notificationBody = ""
    @State private var shortcutName = ""
    @State private var appBundleId = ""
    @State private var urlString = ""
    @State private var replyMessage = ""
    @State private var appleScript = ""

    enum ActionType: String, CaseIterable {
        case notification = "Send Notification"
        case runShortcut = "Run Shortcut"
        case openApp = "Open App"
        case openURL = "Open URL"
        case lockScreen = "Lock Screen"
        case sendReply = "Send Reply"
        case appleScript = "AppleScript"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Configuration") {
                    actionConfiguration
                }
            }
            .navigationTitle("Add Action")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAction()
                    }
                    .disabled(!isValid)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 450)
        #endif
    }

    @ViewBuilder
    private var actionConfiguration: some View {
        switch selectedType {
        case .notification:
            TextField("Title", text: $notificationTitle)
            TextField("Body", text: $notificationBody, axis: .vertical)
                .lineLimit(2...4)

        case .runShortcut:
            TextField("Shortcut Name", text: $shortcutName)

        case .openApp:
            TextField("Bundle ID (e.g., com.apple.mail)", text: $appBundleId)

        case .openURL:
            TextField("URL", text: $urlString)

        case .lockScreen:
            Text("Locks the screen immediately")
                .foregroundStyle(.secondary)

        case .sendReply:
            TextField("App Bundle ID", text: $appBundleId)
            TextField("Reply Message", text: $replyMessage, axis: .vertical)
                .lineLimit(2...4)

        case .appleScript:
            TextField("AppleScript", text: $appleScript, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(.body, design: .monospaced))
        }
    }

    private var isValid: Bool {
        switch selectedType {
        case .notification:
            !notificationTitle.isEmpty
        case .runShortcut:
            !shortcutName.isEmpty
        case .openApp:
            !appBundleId.isEmpty
        case .openURL:
            !urlString.isEmpty
        case .lockScreen:
            true
        case .sendReply:
            !appBundleId.isEmpty && !replyMessage.isEmpty
        case .appleScript:
            !appleScript.isEmpty
        }
    }

    private func addAction() {
        let action: AutoTaskAction
        switch selectedType {
        case .notification:
            action = .sendNotification(title: notificationTitle, body: notificationBody)
        case .runShortcut:
            action = .runShortcut(name: shortcutName)
        case .openApp:
            action = .openApp(bundleId: appBundleId)
        case .openURL:
            action = .openURL(url: URL(string: urlString) ?? URL(string: "https://example.com")!)
        case .lockScreen:
            action = .lockScreen
        case .sendReply:
            action = .sendReply(appBundleId: appBundleId, message: replyMessage)
        case .appleScript:
            action = .executeAppleScript(script: appleScript)
        }
        onSelect(action)
        dismiss()
    }
}
