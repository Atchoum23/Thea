// TheaClipSettingsView.swift
// Thea — Clipboard History Settings

import SwiftUI

struct TheaClipSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var clipManager = ClipboardHistoryManager.shared

    @State private var newExcludedApp: String = ""

    var body: some View {
        Form {
            recordingSection
            privacySection
            aiFeaturesSection
            syncSection
            dataSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Recording

    private var recordingSection: some View {
        Section("Recording") {
            Toggle("Enable Clipboard History", isOn: $settings.clipboardHistoryEnabled)
                .onChange(of: settings.clipboardHistoryEnabled) { _, newValue in
                    clipManager.isRecording = newValue
                }

            Toggle("Record Images", isOn: $settings.clipboardRecordImages)
                .help("Store copied images in clipboard history")

            LabeledContent("Max History Items") {
                Picker("Max Items", selection: $settings.clipboardMaxHistory) {
                    Text("1,000").tag(1000)
                    Text("2,500").tag(2500)
                    Text("5,000").tag(5000)
                    Text("10,000").tag(10000)
                }
                .labelsHidden()
                .frame(width: 140)
            }

            LabeledContent("Retention Period") {
                Picker("Retention", selection: $settings.clipboardRetentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("365 days").tag(365)
                }
                .labelsHidden()
                .frame(width: 140)
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Auto-Detect Sensitive Content", isOn: $settings.clipboardAutoDetectSensitive)
                .help("Automatically detect passwords, API keys, credit card numbers, etc.")

            if settings.clipboardAutoDetectSensitive {
                LabeledContent("Sensitive Item Expiry") {
                    Picker("Expiry", selection: $settings.clipboardSensitiveExpiryHours) {
                        Text("1 hour").tag(1)
                        Text("6 hours").tag(6)
                        Text("24 hours").tag(24)
                        Text("72 hours").tag(72)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }

            DisclosureGroup("Excluded Apps (\(settings.clipboardExcludedApps.count))") {
                ForEach(settings.clipboardExcludedApps, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            settings.clipboardExcludedApps.removeAll { $0 == bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Bundle ID (e.g. com.app.name)", text: $newExcludedApp)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let trimmed = newExcludedApp.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, !settings.clipboardExcludedApps.contains(trimmed) else { return }
                        settings.clipboardExcludedApps.append(trimmed)
                        newExcludedApp = ""
                    }
                    .disabled(newExcludedApp.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Text("Copies from excluded apps are not recorded. Password managers are excluded by default.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - AI Features

    private var aiFeaturesSection: some View {
        Section("AI Features") {
            Toggle("Auto-Summarize Clips", isOn: $settings.clipboardAutoSummarize)
                .help("Generate AI summaries for long clipboard entries")

            Toggle("Auto-Categorize Clips", isOn: $settings.clipboardAutoCategorize)
                .help("Automatically categorize clips using AI")

            Text("AI features use your configured AI provider and may incur API costs.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        Section("Sync") {
            Toggle("Sync Clipboard History", isOn: $settings.clipboardSyncEnabled)
            Toggle("Sync Pinboards", isOn: $settings.clipboardSyncPinboards)

            Text("Synced via iCloud across your devices.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            LabeledContent("Total Entries", value: "\(clipManager.totalEntryCount)")
            LabeledContent("Pinboards", value: "\(clipManager.pinboards.count)")
            LabeledContent("Favorites", value: "\(clipManager.favoriteCount)")

            Button("Clear History (Keep Pinned)", role: .destructive) {
                clipManager.clearHistory(keepPinned: true)
            }

            Button("Clear All History", role: .destructive) {
                clipManager.clearHistory(keepPinned: false)
            }

            Button("Delete Expired Sensitive Items") {
                clipManager.deleteExpiredSensitiveEntries()
            }
        }
    }
}
