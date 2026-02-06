//
//  SettingsView.swift
//  Thea
//
//  Main settings view with tab-based navigation
//  Configuration detail views are in Settings/SettingsConfigurationViews.swift
//  Privacy and About views are in Settings/SettingsPrivacyAboutViews.swift
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            ProvidersSettingsView()
                .tabItem {
                    Label("Providers", systemImage: "network")
                }

            MetaAISettingsView()
                .tabItem {
                    Label("Meta-AI", systemImage: "brain")
                }

            FeaturesSettingsView()
                .tabItem {
                    Label("Features", systemImage: "star")
                }

            ConfigurationAdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }

            #if os(macOS)
                TerminalSettingsView()
                    .tabItem {
                        Label("Terminal", systemImage: "terminal")
                    }

                CoworkSettingsView()
                    .tabItem {
                        Label("Cowork", systemImage: "person.2.badge.gearshape")
                    }
            #endif

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

// MARK: - Meta-AI Settings

struct MetaAISettingsView: View {
    @State private var config = AppConfiguration.shared.metaAIConfig

    var body: some View {
        Form {
            Section("Meta-AI Systems") {
                Text("Enable advanced AI capabilities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // AI-Powered Dynamic Features (NEW)
            Section("AI Intelligence") {
                NavigationLink {
                    AIFeaturesSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI-Powered Features")
                                .font(.subheadline)
                            Text("Semantic classification, adaptive routing, AI analysis")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Core Intelligence") {
                Toggle("Sub-Agent Orchestration", isOn: $config.enableSubAgents)
                Toggle("Reflection Engine", isOn: $config.enableReflection)
                Toggle("Knowledge Graph", isOn: $config.enableKnowledgeGraph)
                Toggle("Memory System", isOn: $config.enableMemorySystem)
                Toggle("Multi-Step Reasoning", isOn: $config.enableReasoning)
            }

            Section("Capabilities") {
                Toggle("Dynamic Tools", isOn: $config.enableDynamicTools)
                Toggle("Code Sandbox", isOn: $config.enableCodeSandbox)
                Toggle("Browser Automation", isOn: $config.enableBrowserAutomation)
            }

            Section("Advanced Features") {
                Toggle("Agent Swarms", isOn: $config.enableAgentSwarms)

                if config.enableAgentSwarms {
                    VStack(alignment: .leading) {
                        Text("Max Concurrent Agents: \(config.maxConcurrentSwarmAgents)")
                            .font(.caption)
                        Slider(
                            value: Binding(
                                get: { Double(config.maxConcurrentSwarmAgents) },
                                set: { config.maxConcurrentSwarmAgents = Int($0) }
                            ),
                            in: 1 ... 10,
                            step: 1
                        )
                    }
                }

                Toggle("Plugin System", isOn: $config.enablePlugins)
            }

            Section("AI Models") {
                TextField("Orchestrator Model", text: $config.orchestratorModel)
                    .help("Model for task coordination and agent management")
                TextField("Reflection Model", text: $config.reflectionModel)
                    .help("Model for self-critique and improvement")
                TextField("Knowledge Graph Model", text: $config.knowledgeGraphModel)
                    .help("Model for knowledge relationship analysis")
                TextField("Reasoning Model", text: $config.reasoningModel)
                    .help("Model for multi-step reasoning tasks")
                TextField("Planner Model", text: $config.plannerModel)
                    .help("Model for task planning and decomposition")
                TextField("Validator Model", text: $config.validatorModel)
                    .help("Model for output validation")
                TextField("Optimizer Model", text: $config.optimizerModel)
                    .help("Model for response optimization")
            }

            Section("Status") {
                LabeledContent("Total Systems", value: "15")
                LabeledContent("Active Systems", value: "\(activeSystemsCount())")
                LabeledContent("Framework Status", value: "Ready")
            }

            Section {
                NavigationLink("Workflow Builder") {
                    WorkflowBuilderView()
                }

                NavigationLink("Plugin Manager") {
                    PluginManagerView()
                }

                NavigationLink("Knowledge Graph Viewer") {
                    KnowledgeGraphViewer()
                }

                NavigationLink("Memory Inspector") {
                    MemoryInspectorView()
                }
            }

            Section {
                Button("Reset to Defaults") {
                    config = MetaAIConfiguration()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.metaAIConfig = newValue
        }
    }

    private func activeSystemsCount() -> Int {
        var count = 0
        if config.enableSubAgents { count += 1 }
        if config.enableReflection { count += 1 }
        if config.enableKnowledgeGraph { count += 1 }
        if config.enableMemorySystem { count += 1 }
        if config.enableReasoning { count += 1 }
        if config.enableDynamicTools { count += 1 }
        if config.enableCodeSandbox { count += 1 }
        if config.enableBrowserAutomation { count += 1 }
        if config.enableAgentSwarms { count += 1 }
        if config.enablePlugins { count += 1 }
        return count
    }
}

// MARK: - Features Settings

struct FeaturesSettingsView: View {
    @State private var enableOCR = false
    @State private var enableScreenCapture = false
    @State private var enableClipboardAccess = false
    @State private var enableBrowserIntegration = false
    @State private var enableFileSystemAccess = false
    @State private var enableCalendarAccess = false
    @State private var enableContactsAccess = false

    var body: some View {
        Form {
            Section("Optional Features") {
                Text("Enable additional capabilities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Computer Vision") {
                Toggle("OCR (Text Recognition)", isOn: $enableOCR)
                Toggle("Screen Capture", isOn: $enableScreenCapture)
            }

            Section("System Integration") {
                Toggle("Clipboard Access", isOn: $enableClipboardAccess)
                Toggle("Browser Integration", isOn: $enableBrowserIntegration)
                Toggle("File System Access", isOn: $enableFileSystemAccess)
            }

            Section("Personal Data") {
                Toggle("Calendar Access", isOn: $enableCalendarAccess)
                Toggle("Contacts Access", isOn: $enableContactsAccess)
            }

            Section("Navigation") {
                NavigationLink("Voice Settings") {
                    VoiceConfigurationView()
                }

                NavigationLink("Knowledge Scanner") {
                    KnowledgeScannerConfigurationView()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced Settings (Configuration Navigation)

struct ConfigurationAdvancedSettingsView: View {
    var body: some View {
        Form {
            Section("Advanced Configuration") {
                Text("Fine-tune system behavior")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("AI & Processing") {
                NavigationLink("Provider Configuration") {
                    ProviderConfigurationView()
                }

                NavigationLink("Agent Configuration") {
                    AgentConfigurationView()
                }

                NavigationLink("Memory Configuration") {
                    MemoryConfigurationView()
                }

                NavigationLink("Local Models") {
                    LocalModelConfigurationView()
                }
            }

            Section("Appearance") {
                NavigationLink("Theme Configuration") {
                    ThemeConfigurationView()
                }
            }

            Section("API Management") {
                NavigationLink("API Validation") {
                    APIValidationConfigurationView()
                }

                NavigationLink("External APIs") {
                    ExternalAPIsConfigurationView()
                }
            }

            #if os(macOS)
                Section("Development") {
                    NavigationLink("Code Intelligence") {
                        CodeIntelligenceConfigurationView()
                    }
                }
            #endif

            Section("Danger Zone") {
                Button("Reset All Settings", role: .destructive) {
                    AppConfiguration.shared.resetAllToDefaults()
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
}
