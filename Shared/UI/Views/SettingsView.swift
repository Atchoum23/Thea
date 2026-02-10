import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            ProvidersSettingsView()
                .tabItem {
                    Label("Providers", systemImage: "network")
                }

            ConfigurationAdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }

            ConfigurationPrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield")
                }

            #if os(macOS)
                QASettingsView()
                    .tabItem {
                        Label("QA Tools", systemImage: "checkmark.seal")
                    }
            #endif

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Providers Settings

struct ProvidersSettingsView: View {
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var googleKey = ""
    @State private var perplexityKey = ""
    @State private var openRouterKey = ""
    @State private var groqKey = ""
    @State private var showingSuccessMessage = false
    @State private var showingErrorMessage = false
    @State private var errorText = ""
    @State private var successText = ""

    var body: some View {
        Form {
            Section("AI Providers") {
                Text("Add API keys to enable AI providers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("OpenAI (ChatGPT)") {
                SecureField("API Key", text: $openAIKey)
                Button("Save") {
                    saveAPIKey(openAIKey, for: "openai")
                }
                .disabled(openAIKey.isEmpty)
            }

            Section("Anthropic (Claude)") {
                SecureField("API Key", text: $anthropicKey)
                Button("Save") {
                    saveAPIKey(anthropicKey, for: "anthropic")
                }
                .disabled(anthropicKey.isEmpty)
            }

            Section("Google (Gemini)") {
                SecureField("API Key", text: $googleKey)
                Button("Save") {
                    saveAPIKey(googleKey, for: "google")
                }
                .disabled(googleKey.isEmpty)
            }

            Section("Perplexity") {
                SecureField("API Key", text: $perplexityKey)
                Button("Save") {
                    saveAPIKey(perplexityKey, for: "perplexity")
                }
                .disabled(perplexityKey.isEmpty)
            }

            Section("OpenRouter") {
                SecureField("API Key", text: $openRouterKey)
                Button("Save") {
                    saveAPIKey(openRouterKey, for: "openrouter")
                }
                .disabled(openRouterKey.isEmpty)
            }

            Section("Groq") {
                SecureField("API Key", text: $groqKey)
                Button("Save") {
                    saveAPIKey(groqKey, for: "groq")
                }
                .disabled(groqKey.isEmpty)
            }
        }
        .formStyle(.grouped)
        .alert("Success", isPresented: $showingSuccessMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successText)
        }
        .alert("Error", isPresented: $showingErrorMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    private func saveAPIKey(_ key: String, for provider: String) {
        do {
            try SecureStorage.shared.saveAPIKey(key, for: provider)
            successText = "API key for \(provider) saved successfully"
            showingSuccessMessage = true

            // Clear the field after successful save
            switch provider {
            case "openai": openAIKey = ""
            case "anthropic": anthropicKey = ""
            case "google": googleKey = ""
            case "perplexity": perplexityKey = ""
            case "openrouter": openRouterKey = ""
            case "groq": groqKey = ""
            default: break
            }
        } catch {
            errorText = "Failed to save API key: \(error.localizedDescription)"
            showingErrorMessage = true
        }
    }
}

// MARK: - Advanced Settings (Configuration Navigation)

struct ConfigurationAdvancedSettingsView: View {
    var body: some View {
        Form {
            Section("Advanced Configuration") {
                Text("Fine-tune THEA's behavior and performance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Provider Settings") {
                NavigationLink("API Endpoints & Timeouts") {
                    ProviderConfigurationView()
                }
            }

            Section("Voice Settings") {
                NavigationLink("Voice Recognition & Synthesis") {
                    VoiceConfigurationView()
                }
            }

            Section("Knowledge Scanner") {
                NavigationLink("File Indexing Settings") {
                    KnowledgeScannerConfigurationView()
                }
            }

            Section("Memory System") {
                NavigationLink("Memory Capacity & Decay") {
                    MemoryConfigurationView()
                }
            }

            Section("Agent System") {
                NavigationLink("Agent Behavior & Limits") {
                    AgentConfigurationView()
                }
            }

            Section("Local Models") {
                NavigationLink("Local Model Paths & Defaults") {
                    LocalModelConfigurationView()
                }
            }

            #if os(macOS)
                Section("Code Intelligence") {
                    NavigationLink("Code Models & Executables") {
                        CodeIntelligenceConfigurationView()
                    }
                }
            #endif

            Section("API Validation") {
                NavigationLink("Test Models for Key Validation") {
                    APIValidationConfigurationView()
                }
            }

            Section("External APIs") {
                NavigationLink("Third-Party API Endpoints") {
                    ExternalAPIsConfigurationView()
                }
            }

            Section("Theme") {
                NavigationLink("Colors & Typography") {
                    ThemeConfigurationView()
                }
            }

            Section {
                Button("Reset All Settings to Defaults") {
                    AppConfiguration.shared.resetAllToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// Configuration sub-views are defined in SettingsConfigurationViews.swift
// Privacy, About, and DataExport views are defined in SettingsPrivacyAboutViews.swift

#Preview {
    SettingsView()
}
