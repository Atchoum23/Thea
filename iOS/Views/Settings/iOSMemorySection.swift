import SwiftUI

struct IOSMemorySettingsView: View {
    @State private var config = IOSMemoryConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("1,234")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Memories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("45")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Recent")
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
                Toggle("Enable Memory", isOn: $config.isEnabled)

                Stepper("Short-term: \(config.shortTermCapacity)", value: $config.shortTermCapacity, in: 10...100, step: 10)

                Stepper("Long-term: \(config.longTermCapacity)", value: $config.longTermCapacity, in: 1000...50000, step: 1000)
            } header: {
                Text("Capacity")
            }

            // Learning
            Section {
                Toggle("Learn from Conversations", isOn: $config.learnFromConversations)

                Toggle("Remember Preferences", isOn: $config.rememberPreferences)

                Toggle("Context Awareness", isOn: $config.contextAwareness)
            } header: {
                Text("Learning")
            }

            // Management
            Section {
                Button("Clear Short-term Memory") {
                    // Clear action
                }

                Button("Clear All Memory", role: .destructive) {
                    // Clear all action
                }
            } header: {
                Text("Management")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSMemoryConfig()
                }
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

struct IOSMemoryConfig: Equatable, Codable {
    var isEnabled: Bool = true
    var shortTermCapacity: Int = 50
    var longTermCapacity: Int = 10000
    var learnFromConversations: Bool = true
    var rememberPreferences: Bool = true
    var contextAwareness: Bool = true

    private static let storageKey = "iOSMemoryConfig"

    static func load() -> IOSMemoryConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSMemoryConfig.self, from: data) {
            return config
        }
        return IOSMemoryConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
