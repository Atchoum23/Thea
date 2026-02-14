import SwiftUI

struct IOSPrivacySettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var config = IOSPrivacyConfig.load()
    @State private var showingExportOptions = false

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("Protected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)

                    VStack {
                        Text("\(privacyScore)%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(privacyScoreColor)
                        Text("Privacy Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Data Collection
            Section {
                Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)
                    .accessibilityHint("Shares anonymous usage data to help improve Thea")
                Toggle("Crash Reports", isOn: $config.crashReportsEnabled)
                    .accessibilityHint("Sends crash reports to help fix issues")
            } header: {
                Text("Data Collection")
            } footer: {
                Text("Help improve THEA by sharing anonymous usage data")
            }

            // Data Retention
            Section {
                Picker("Keep History", selection: $config.dataRetention) {
                    Text("7 days").tag("7")
                    Text("30 days").tag("30")
                    Text("90 days").tag("90")
                    Text("Forever").tag("forever")
                }
            } header: {
                Text("Data Retention")
            }

            // Security
            Section {
                Toggle("Require Face ID", isOn: $config.requireBiometric)
                    .accessibilityHint("Requires biometric authentication to open Thea")
                Toggle("Lock on Background", isOn: $config.lockOnBackground)
                    .accessibilityHint("Locks Thea when the app moves to the background")
            } header: {
                Text("Security")
            }

            // Data Management
            Section {
                Button {
                    showingExportOptions = true
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }

                Button("Delete All Data", role: .destructive) {
                    // Delete action
                }
            } header: {
                Text("Data Management")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSPrivacyConfig()
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
        .sheet(isPresented: $showingExportOptions) {
            IOSExportOptionsView()
        }
    }

    private var privacyScore: Int {
        var score = 70
        if !settingsManager.analyticsEnabled { score += 10 }
        if !config.crashReportsEnabled { score += 5 }
        if config.requireBiometric { score += 10 }
        if config.lockOnBackground { score += 5 }
        return min(score, 100)
    }

    private var privacyScoreColor: Color {
        if privacyScore >= 80 { return .green }
        if privacyScore >= 60 { return .yellow }
        return .red
    }
}

struct IOSPrivacyConfig: Equatable, Codable {
    var crashReportsEnabled: Bool = true
    var dataRetention: String = "30"
    var requireBiometric: Bool = false
    var lockOnBackground: Bool = false

    private static let storageKey = "iOSPrivacyConfig"

    static func load() -> IOSPrivacyConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSPrivacyConfig.self, from: data) {
            return config
        }
        return IOSPrivacyConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct IOSExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        // Export JSON
                        dismiss()
                    } label: {
                        Label("Export as JSON", systemImage: "curlybraces")
                    }

                    Button {
                        // Export archive
                        dismiss()
                    } label: {
                        Label("Export as Archive", systemImage: "archivebox")
                    }
                } header: {
                    Text("Format")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
