import SwiftUI

struct IOSIntegrationsSettingsView: View {
    @State private var config = IOSIntegrationsConfig.load()

    var body: some View {
        Form {
            // Health & Fitness
            Section {
                Toggle("Apple Health", isOn: $config.healthEnabled)
                Toggle("Apple Fitness", isOn: $config.fitnessEnabled)
            } header: {
                Text("Health & Fitness")
            }

            // Productivity
            Section {
                Toggle("Calendar", isOn: $config.calendarEnabled)
                Toggle("Reminders", isOn: $config.remindersEnabled)
                Toggle("Notes", isOn: $config.notesEnabled)
            } header: {
                Text("Productivity")
            }

            // Smart Home
            Section {
                Toggle("HomeKit", isOn: $config.homeKitEnabled)
            } header: {
                Text("Smart Home")
            }

            // Communication
            Section {
                Toggle("Contacts", isOn: $config.contactsEnabled)
            } header: {
                Text("Communication")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSIntegrationsConfig()
                }
            }
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

struct IOSIntegrationsConfig: Equatable, Codable {
    var healthEnabled: Bool = false
    var fitnessEnabled: Bool = false
    var calendarEnabled: Bool = true
    var remindersEnabled: Bool = true
    var notesEnabled: Bool = false
    var homeKitEnabled: Bool = false
    var contactsEnabled: Bool = false

    private static let storageKey = "iOSIntegrationsConfig"

    static func load() -> IOSIntegrationsConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSIntegrationsConfig.self, from: data) {
            return config
        }
        return IOSIntegrationsConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
