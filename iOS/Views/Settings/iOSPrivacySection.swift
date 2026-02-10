import SwiftUI

struct iOSPrivacySettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var config = iOSPrivacyConfig.load()
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
                        Text("Protected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

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
                Toggle("Crash Reports", isOn: $config.crashReportsEnabled)
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
                Toggle("Lock on Background", isOn: $config.lockOnBackground)
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
                    config = iOSPrivacyConfig()
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
        .sheet(isPresented: $showingExportOptions) {
            iOSExportOptionsView()
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

struct iOSPrivacyConfig: Equatable, Codable {
    var crashReportsEnabled: Bool = true
    var dataRetention: String = "30"
    var requireBiometric: Bool = false
    var lockOnBackground: Bool = false

    private static let storageKey = "iOSPrivacyConfig"

    static func load() -> iOSPrivacyConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(iOSPrivacyConfig.self, from: data) {
            return config
        }
        return iOSPrivacyConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct iOSExportOptionsView: View {
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
