import SwiftUI

struct IOSAdvancedSettingsView: View {
    @State private var config = IOSAdvancedConfig.load()

    var body: some View {
        Form {
            // Developer
            Section {
                Toggle("Debug Mode", isOn: $config.debugMode)
                Toggle("Verbose Logging", isOn: $config.verboseLogging)
            } header: {
                Text("Developer")
            }

            // Network
            Section {
                Toggle("Use Cellular Data", isOn: $config.useCellularData)
                Stepper("Timeout: \(config.networkTimeout)s", value: $config.networkTimeout, in: 10...120, step: 10)
            } header: {
                Text("Network")
            }

            // Performance
            Section {
                Toggle("Background Refresh", isOn: $config.backgroundRefresh)
                Toggle("Prefetch Content", isOn: $config.prefetchContent)
            } header: {
                Text("Performance")
            }

            // Cache
            Section {
                LabeledContent("Cache Size", value: "125 MB")

                Button("Clear Cache") {
                    // Clear cache
                }
            } header: {
                Text("Cache")
            }

            // Diagnostics
            Section {
                Button("Generate Diagnostic Report") {
                    // Generate report
                }

                Button("Send Feedback") {
                    // Send feedback
                }
            } header: {
                Text("Diagnostics")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSAdvancedConfig()
                }
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

struct IOSAdvancedConfig: Equatable, Codable {
    var debugMode: Bool = false
    var verboseLogging: Bool = false
    var useCellularData: Bool = true
    var networkTimeout: Int = 30
    var backgroundRefresh: Bool = true
    var prefetchContent: Bool = true

    private static let storageKey = "iOSAdvancedConfig"

    static func load() -> IOSAdvancedConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSAdvancedConfig.self, from: data) {
            return config
        }
        return IOSAdvancedConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct iOSAPIKeysView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingsManager = SettingsManager.shared

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var googleKey = ""
    @State private var perplexityKey = ""
    @State private var groqKey = ""
    @State private var openRouterKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $openAIKey)
                } header: {
                    Text("OpenAI")
                } footer: {
                    Text("Get your API key from platform.openai.com")
                }

                Section {
                    SecureField("API Key", text: $anthropicKey)
                } header: {
                    Text("Anthropic")
                } footer: {
                    Text("Get your API key from console.anthropic.com")
                }

                Section {
                    SecureField("API Key", text: $googleKey)
                } header: {
                    Text("Google AI")
                } footer: {
                    Text("Get your API key from makersuite.google.com")
                }

                Section {
                    SecureField("API Key", text: $perplexityKey)
                } header: {
                    Text("Perplexity")
                } footer: {
                    Text("Get your API key from perplexity.ai")
                }

                Section {
                    SecureField("API Key", text: $groqKey)
                } header: {
                    Text("Groq")
                } footer: {
                    Text("Get your API key from console.groq.com")
                }

                Section {
                    SecureField("API Key", text: $openRouterKey)
                } header: {
                    Text("OpenRouter")
                } footer: {
                    Text("Get your API key from openrouter.ai")
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAPIKeys()
                    }
                }
            }
            .onAppear {
                loadAPIKeys()
            }
        }
    }

    private func loadAPIKeys() {
        openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
        anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
        googleKey = settingsManager.getAPIKey(for: "google") ?? ""
        perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
        groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
        openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
    }

    private func saveAPIKeys() {
        if !openAIKey.isEmpty {
            settingsManager.setAPIKey(openAIKey, for: "openai")
        }
        if !anthropicKey.isEmpty {
            settingsManager.setAPIKey(anthropicKey, for: "anthropic")
        }
        if !googleKey.isEmpty {
            settingsManager.setAPIKey(googleKey, for: "google")
        }
        if !perplexityKey.isEmpty {
            settingsManager.setAPIKey(perplexityKey, for: "perplexity")
        }
        if !groqKey.isEmpty {
            settingsManager.setAPIKey(groqKey, for: "groq")
        }
        if !openRouterKey.isEmpty {
            settingsManager.setAPIKey(openRouterKey, for: "openrouter")
        }
        dismiss()
    }
}
