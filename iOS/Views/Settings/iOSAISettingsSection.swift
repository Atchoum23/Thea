import SwiftUI

struct IOSAIProvidersSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var showingAPIKeys = false

    // Provider health simulation
    @State private var providerHealth: [String: IOSProviderHealthStatus] = [
        "OpenAI": .healthy,
        "Anthropic": .healthy,
        "Google": .healthy,
        "Perplexity": .unknown,
        "Groq": .healthy,
        "OpenRouter": .unknown
    ]

    var body: some View {
        Form {
            // Quick Actions
            Section {
                Button {
                    showingAPIKeys = true
                } label: {
                    Label("Configure API Keys", systemImage: "key.fill")
                }

                Picker("Default Provider", selection: $settingsManager.defaultProvider) {
                    ForEach(settingsManager.availableProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }

                Toggle("Stream Responses", isOn: $settingsManager.streamResponses)
            } header: {
                Text("Configuration")
            }

            // Provider Status
            Section {
                ForEach(Array(providerHealth.keys.sorted()), id: \.self) { provider in
                    HStack {
                        Circle()
                            .fill(statusColor(for: providerHealth[provider] ?? .unknown))
                            .frame(width: 10, height: 10)

                        Text(provider)

                        Spacer()

                        Text(providerHealth[provider]?.rawValue ?? "Unknown")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Refresh Status") {
                    refreshProviderStatus()
                }
            } header: {
                Text("Provider Health")
            } footer: {
                Text("Shows the current availability of each AI provider")
            }

            // Usage Summary
            Section {
                LabeledContent("Tokens Today", value: "12,450")
                LabeledContent("Tokens This Month", value: "345,678")
                LabeledContent("Estimated Cost", value: "$4.52")
            } header: {
                Text("Usage")
            }
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAPIKeys) {
            iOSAPIKeysView()
        }
    }

    private func statusColor(for status: IOSProviderHealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }

    private func refreshProviderStatus() {
        Task {
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

enum IOSProviderHealthStatus: String {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case down = "Down"
    case unknown = "Unknown"
}

struct IOSModelsSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var selectedModel = "gpt-4o"
    @State private var favoriteModels: Set<String> = ["gpt-4o", "claude-3-5-sonnet"]

    private let availableModels = [
        ("gpt-4o", "OpenAI", "128K context"),
        ("gpt-4o-mini", "OpenAI", "128K context"),
        ("claude-3-5-sonnet", "Anthropic", "200K context"),
        ("claude-3-5-haiku", "Anthropic", "200K context"),
        ("gemini-1.5-pro", "Google", "1M context"),
        ("gemini-1.5-flash", "Google", "1M context"),
        ("llama-3.1-70b", "Groq", "128K context"),
        ("mixtral-8x7b", "Groq", "32K context")
    ]

    var body: some View {
        Form {
            // Default Model
            Section {
                Picker("Default Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.0) { model in
                        Text(model.0).tag(model.0)
                    }
                }
            } header: {
                Text("Default")
            }

            // Favorite Models
            Section {
                ForEach(availableModels, id: \.0) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.0)
                                .font(.body)
                            Text("\(model.1) • \(model.2)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            if favoriteModels.contains(model.0) {
                                favoriteModels.remove(model.0)
                            } else {
                                favoriteModels.insert(model.0)
                            }
                        } label: {
                            Image(systemName: favoriteModels.contains(model.0) ? "star.fill" : "star")
                                .foregroundStyle(favoriteModels.contains(model.0) ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Available Models")
            } footer: {
                Text("Tap the star to add models to favorites")
            }

            // Model Info
            Section {
                LabeledContent("Favorite Count", value: "\(favoriteModels.count)")
                LabeledContent("Available Models", value: "\(availableModels.count)")
            } header: {
                Text("Statistics")
            }
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct IOSLocalModelsUnavailableView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("Local Models")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("On-device model inference using MLX is only available on macOS with Apple Silicon.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                Text("Why macOS only?")
                    .font(.headline)

                Text("MLX leverages Apple Silicon's unified memory architecture for efficient local inference. iOS devices don't support the full MLX runtime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 8) {
                Text("Alternative")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("Use cloud-based AI providers for full model access on iOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Local Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct IOSOrchestratorSettingsView: View {
    @State private var config = IOSOrchestratorConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("4")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Active Agents")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("12")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Tasks Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("98%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                        Text("Success Rate")
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
                Toggle("Enable Orchestration", isOn: $config.isEnabled)

                Stepper("Max Concurrent Tasks: \(config.maxConcurrentTasks)", value: $config.maxConcurrentTasks, in: 1...10)

                Stepper("Agent Timeout: \(config.agentTimeout)s", value: $config.agentTimeout, in: 30...300, step: 30)
            } header: {
                Text("Configuration")
            }

            // Routing
            Section {
                Toggle("Smart Routing", isOn: $config.smartRouting)

                Toggle("Auto Fallback", isOn: $config.autoFallback)

                Toggle("Cost Optimization", isOn: $config.costOptimization)
            } header: {
                Text("Routing")
            } footer: {
                Text("Smart routing automatically selects the best model for each task")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = IOSOrchestratorConfig()
                }
            }
        }
        .navigationTitle("Orchestrator")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

struct IOSOrchestratorConfig: Equatable, Codable {
    var isEnabled: Bool = true
    var maxConcurrentTasks: Int = 4
    var agentTimeout: Int = 60
    var smartRouting: Bool = true
    var autoFallback: Bool = true
    var costOptimization: Bool = false

    private static let storageKey = "iOSOrchestratorConfig"

    static func load() -> IOSOrchestratorConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(IOSOrchestratorConfig.self, from: data) {
            return config
        }
        return IOSOrchestratorConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
