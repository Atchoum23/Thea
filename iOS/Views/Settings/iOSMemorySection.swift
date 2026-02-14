import SwiftUI

struct IOSMemorySettingsView: View {
    @State private var config = IOSMemoryConfig.load()
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("1,234")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentColor)
                        Text("Memories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("45")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.green.opacity(0.8))
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
                    .accessibilityHint("Enables Thea to remember context across conversations")

                Stepper("Short-term: \(config.shortTermCapacity)", value: $config.shortTermCapacity, in: 10...100, step: 10)
                    .accessibilityHint("Adjusts short-term memory capacity from 10 to 100 items")

                Stepper("Long-term: \(config.longTermCapacity)", value: $config.longTermCapacity, in: 1000...50000, step: 1000)
                    .accessibilityHint("Adjusts long-term memory capacity from 1000 to 50000 items")
            } header: {
                Text("Capacity")
            }

            // Learning
            Section {
                Toggle("Learn from Conversations", isOn: $config.learnFromConversations)
                    .accessibilityHint("Allows Thea to learn from your conversation patterns")

                Toggle("Remember Preferences", isOn: $config.rememberPreferences)
                    .accessibilityHint("Saves your preferences for future interactions")

                Toggle("Context Awareness", isOn: $config.contextAwareness)
                    .accessibilityHint("Enables awareness of time, location, and activity context")
            } header: {
                Text("Learning")
            }

            // Management
            Section {
                Button("Clear Short-term Memory") {
                    // Clear action
                }

                Button("Clear All Memory", role: .destructive) {
                    showingClearConfirmation = true
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
        .alert("Clear All Memory?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                // Clear all memory action
            }
        } message: {
            Text("This will permanently delete all stored memories and learned preferences. This action cannot be undone.")
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
