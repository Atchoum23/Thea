//
//  AppPairingSettingsView.swift
//  Thea
//
//  Created by Claude on 2026-02-15.
//

import SwiftUI

#if os(macOS)

/// Settings view for automatic foreground app pairing
struct AppPairingSettingsView: View {
    @ObservedObject private var monitor = ForegroundAppMonitor.shared

    /// Available apps that can be paired
    private let supportedApps: [(bundleID: String, name: String, icon: String)] = [
        ("com.apple.dt.Xcode", "Xcode", "hammer.fill"),
        ("com.microsoft.VSCode", "Visual Studio Code", "chevron.left.forwardslash.chevron.right"),
        ("com.apple.Terminal", "Terminal", "terminal.fill"),
        ("com.googlecode.iterm2", "iTerm2", "terminal"),
        ("com.apple.Notes", "Notes", "note.text"),
        ("com.apple.TextEdit", "TextEdit", "doc.text"),
        ("com.apple.Safari", "Safari", "safari"),
        ("dev.warp.Warp-Stable", "Warp", "terminal")
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Enable Foreground App Pairing", isOn: $monitor.isPairingEnabled)
                    .toggleStyle(.switch)

                Text("When enabled, Thea automatically detects which app you're using and includes relevant context in your queries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("General", systemImage: "app.connected.to.app.below.fill")
            }

            if monitor.isPairingEnabled {
                Section {
                    ForEach(supportedApps, id: \.bundleID) { app in
                        Toggle(isOn: Binding(
                            get: { monitor.enabledApps.contains(app.bundleID) },
                            set: { enabled in
                                if enabled {
                                    monitor.enabledApps.insert(app.bundleID)
                                } else {
                                    monitor.enabledApps.remove(app.bundleID)
                                }
                            }
                        )) {
                            Label {
                                Text(app.name)
                            } icon: {
                                Image(systemName: app.icon)
                                    .foregroundStyle(.theaPrimary)
                            }
                        }
                    }
                } header: {
                    Label("Enabled Apps", systemImage: "checklist")
                } footer: {
                    Text("Select which apps should automatically provide context to Thea.")
                        .font(.caption)
                }

                Section {
                    Toggle("Include Selected Text", isOn: $monitor.includeSelectedText)
                        .toggleStyle(.switch)

                    Toggle("Include Window Content", isOn: $monitor.includeWindowContent)
                        .toggleStyle(.switch)

                    Text("Window content may include source code, terminal output, or document text depending on the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("Context Options", systemImage: "text.document")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy & Permissions")
                            .font(.headline)

                        Text("App pairing requires **Accessibility** permission to read window content and selected text from other applications.")
                            .font(.body)

                        Text("To grant permission:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Open System Settings → Privacy & Security → Accessibility")
                            Text("2. Click the lock icon to make changes")
                            Text("3. Enable Thea in the list")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)

                        // Permission status indicator
                        HStack {
                            Image(systemName: AXIsProcessTrusted() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(AXIsProcessTrusted() ? .green : .orange)

                            Text(AXIsProcessTrusted() ? "Accessibility permission granted" : "Accessibility permission required")
                                .font(.caption)
                                .foregroundStyle(AXIsProcessTrusted() ? .green : .orange)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keyboard Shortcut")
                            .font(.headline)

                        Text("You can activate Thea with foreground app context using a global keyboard shortcut.")
                            .font(.body)

                        Text("Recommended: **Option+Space**")
                            .font(.subheadline)
                            .padding(.top, 4)

                        Text("To configure:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Open System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts")
                            Text("2. Click the + button to add a new shortcut")
                            Text("3. Select Thea from the Application dropdown")
                            Text("4. Enter 'Show Thea' as the menu title")
                            Text("5. Press Option+Space (or your preferred shortcut)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("Keyboard Shortcut", systemImage: "keyboard")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("App Pairing")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    AppPairingSettingsView()
        .frame(width: 600, height: 800)
}

#endif
