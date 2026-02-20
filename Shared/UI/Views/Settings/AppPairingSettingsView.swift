import SwiftUI

#if os(macOS)

import AppKit

// MARK: - App Pairing Settings View

struct AppPairingSettingsView: View {
    @ObservedObject private var monitor = ForegroundAppMonitor.shared
    @State private var accessibilityGranted = AXIsProcessTrusted()

    private let knownApps: [(name: String, bundleID: String, icon: String)] = [
        ("Xcode", "com.apple.dt.Xcode", "hammer"),
        ("VS Code", "com.microsoft.VSCode", "curlybraces"),
        ("Terminal", "com.apple.Terminal", "terminal"),
        ("iTerm2", "com.googlecode.iterm2", "terminal"),
        ("Warp", "dev.warp.Warp-Stable", "terminal.fill"),
        ("Notes", "com.apple.Notes", "note.text"),
        ("TextEdit", "com.apple.TextEdit", "doc.text"),
        ("Safari", "com.apple.Safari", "safari"),
    ]

    var body: some View {
        Form {
            enableSection
            if monitor.isPairingEnabled {
                permissionsSection
                contextOptionsSection
                appsSection
                statusSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle("App Pairing")
    }

    // MARK: - Sections

    private var enableSection: some View {
        Section {
            Toggle(isOn: $monitor.isPairingEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable App Pairing")
                        .font(.theaBody)
                    Text("Automatically detect your foreground app and inject contextual information into AI conversations.")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack(spacing: 10) {
                Image(systemName: "app.connected.to.app.below.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue.gradient)
                VStack(alignment: .leading) {
                    Text("App Pairing")
                        .font(.theaTitle2)
                    Text("Context-aware assistance for your foreground apps")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            HStack {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(accessibilityGranted ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility Access")
                        .font(.theaBody)
                    Text(accessibilityGranted
                        ? "Thea can read foreground app context."
                        : "Required to read window titles, selected text, and app state.")
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !accessibilityGranted {
                    Button("Open Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .onAppear {
                accessibilityGranted = AXIsProcessTrusted()
            }
        }
    }

    private var contextOptionsSection: some View {
        Section("Context Options") {
            Toggle("Include Selected Text", isOn: $monitor.includeSelectedText)
            Toggle("Include Window Content", isOn: $monitor.includeWindowContent)

            Text("When enabled, Thea sends the foreground app's context (window title, selected text, visible content) to the AI with each message. This helps the AI understand what you're working on.")
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
        }
    }

    private var appsSection: some View {
        Section("Paired Apps") {
            ForEach(knownApps, id: \.bundleID) { app in
                let isEnabled = monitor.enabledApps.contains(app.bundleID)
                Toggle(isOn: Binding(
                    get: { isEnabled },
                    set: { enabled in
                        if enabled {
                            monitor.enabledApps.insert(app.bundleID)
                        } else {
                            monitor.enabledApps.remove(app.bundleID)
                        }
                    }
                )) {
                    Label(app.name, systemImage: app.icon)
                }
            }

            Text("Only enabled apps will have their context sent to the AI. Other foreground apps are ignored.")
                .font(.theaCaption1)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section("Status") {
            if let app = monitor.currentApp {
                HStack {
                    Text("Current App")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(app.localizedName ?? "Unknown")
                        .font(.theaBody)
                }
            }

            if let context = monitor.appContext {
                HStack {
                    Text("Window")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(context.windowTitle)
                        .font(.theaCaption1)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let selected = context.selectedText, !selected.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Text")
                            .foregroundStyle(.secondary)
                        Text(selected)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                            .truncationMode(.tail)
                    }
                }
            } else {
                Text("No app context detected yet.")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AppPairingSettingsView()
        .frame(width: 600, height: 600)
}

#endif
