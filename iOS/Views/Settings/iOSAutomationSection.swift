import SwiftUI

struct IOSAutomationSettingsView: View {
    @State private var config = IOSAutomationConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("5")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Workflows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("23")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Runs Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Configuration
            Section {
                Toggle("Enable Automation", isOn: $config.isEnabled)

                Picker("Execution Mode", selection: $config.executionMode) {
                    Text("Safe").tag("safe")
                    Text("Normal").tag("normal")
                    Text("Aggressive").tag("aggressive")
                }
            } header: {
                Text("Configuration")
            }

            // Approvals
            Section {
                Toggle("Require Approval for Actions", isOn: $config.requireApproval)

                Toggle("Auto-run Scheduled Tasks", isOn: $config.autoRunScheduled)
            } header: {
                Text("Approvals")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSAutomationConfig()
                }
            }
        }
        .navigationTitle("Automation")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

struct IOSAutomationConfig: Equatable, Codable {
    var isEnabled: Bool = true
    var executionMode: String = "normal"
    var requireApproval: Bool = true
    var autoRunScheduled: Bool = false

    private static let storageKey = "iOSAutomationConfig"

    static func load() -> IOSAutomationConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSAutomationConfig.self, from: data) {
            return config
        }
        return IOSAutomationConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
