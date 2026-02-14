// AIProvidersSettingsView.swift
// Comprehensive AI provider management for Thea

import SwiftUI

// MARK: - Provider Status

enum ProviderStatus: String, CaseIterable {
    case connected
    case disconnected
    case testing
    case error

    var color: Color {
        switch self {
        case .connected: .green
        case .disconnected: .secondary
        case .testing: .orange
        case .error: .red
        }
    }

    var icon: String {
        switch self {
        case .connected: "checkmark.circle.fill"
        case .disconnected: "circle"
        case .testing: "arrow.triangle.2.circlepath"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Provider Info

struct ProviderDisplayInfo: Identifiable {
    let id: String
    let name: String
    let displayName: String
    let icon: String
    let websiteURL: URL?
    let description: String

    static let all: [ProviderDisplayInfo] = [
        ProviderDisplayInfo(
            id: "openai",
            name: "openai",
            displayName: "OpenAI",
            icon: "brain.head.profile",
            websiteURL: URL(string: "https://platform.openai.com"),
            description: "GPT-4, GPT-4o, o1 reasoning models"
        ),
        ProviderDisplayInfo(
            id: "anthropic",
            name: "anthropic",
            displayName: "Anthropic",
            icon: "sparkles",
            websiteURL: URL(string: "https://console.anthropic.com"),
            description: "Claude 4 Opus, Sonnet, Haiku"
        ),
        ProviderDisplayInfo(
            id: "google",
            name: "google",
            displayName: "Google AI",
            icon: "g.circle",
            websiteURL: URL(string: "https://makersuite.google.com"),
            description: "Gemini Pro, Gemini Ultra"
        ),
        ProviderDisplayInfo(
            id: "perplexity",
            name: "perplexity",
            displayName: "Perplexity",
            icon: "magnifyingglass.circle",
            websiteURL: URL(string: "https://www.perplexity.ai"),
            description: "Research-focused with web search"
        ),
        ProviderDisplayInfo(
            id: "groq",
            name: "groq",
            displayName: "Groq",
            icon: "bolt.circle",
            websiteURL: URL(string: "https://console.groq.com"),
            description: "Ultra-fast inference with LPU"
        ),
        ProviderDisplayInfo(
            id: "openrouter",
            name: "openrouter",
            displayName: "OpenRouter",
            icon: "network",
            websiteURL: URL(string: "https://openrouter.ai"),
            description: "200+ models, unified API gateway"
        )
    ]
}

// MARK: - Usage Statistics

struct ProviderUsageStats {
    let provider: String
    let tokensToday: Int
    let tokensThisMonth: Int
    let estimatedCostToday: Decimal
    let estimatedCostThisMonth: Decimal
    let requestsToday: Int
    let averageLatency: Double // ms
    let errorRate: Double // percentage
    let lastUsed: Date?
}

// MARK: - Main View

struct AIProvidersSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    // PerformanceMetricsManager is in excluded MetaAI — use placeholder for now

    // API Keys
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""
    @State private var perplexityKey: String = ""
    @State private var groqKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var apiKeysLoaded: Bool = false

    // Provider status
    @State private var providerStatuses: [String: ProviderStatus] = [:]
    @State private var providerLatencies: [String: Double] = [:]
    @State private var testingProvider: String?

    // UI State
    @State private var showingProviderDetail: ProviderDisplayInfo?
    @State private var showingUsageHistory = false

    // Fallback configuration
    @State private var fallbackOrder: [String] = []
    @State private var autoFallbackEnabled: Bool = true

    var body: some View {
        Form {
            // MARK: - Default Provider
            Section("Default Provider") {
                defaultProviderSection
            }

            // MARK: - Provider Status Overview
            Section("Provider Status") {
                providerStatusOverview
            }

            // MARK: - API Keys
            Section("API Keys") {
                apiKeysSection
            }

            // MARK: - Usage Statistics
            Section("Usage Statistics") {
                usageStatisticsSection
            }

            // MARK: - Fallback Configuration
            Section("Fallback Configuration") {
                fallbackConfigurationSection
            }

            // MARK: - Advanced Settings
            Section("Advanced") {
                advancedSection
            }

            // MARK: - Actions
            Section {
                Button("Test All Connections") {
                    testAllProviders()
                }
                .disabled(testingProvider != nil)

                Button("Refresh Provider Status") {
                    refreshProviderStatus()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .onAppear {
            loadAPIKeysIfNeeded()
            initializeProviderStatuses()
            loadFallbackOrder()
        }
        .sheet(item: $showingProviderDetail) { provider in
            providerDetailSheet(provider)
        }
    }

    // MARK: - Default Provider Section

    private var defaultProviderSection: some View {
        Group {
            Picker("Primary Provider", selection: $settingsManager.defaultProvider) {
                ForEach(ProviderDisplayInfo.all) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.displayName)
                    }
                    .tag(provider.id)
                }
            }

            Toggle("Stream Responses", isOn: $settingsManager.streamResponses)

            Text("The primary provider handles most requests. Other providers are used as fallbacks or for specific tasks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Provider Status Overview

    private var providerStatusOverview: some View {
        Group {
            ForEach(ProviderDisplayInfo.all) { provider in
                providerStatusRow(provider)
            }
        }
    }

    private func providerStatusRow(_ provider: ProviderDisplayInfo) -> some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: (providerStatuses[provider.id] ?? .disconnected).icon)
                .foregroundStyle((providerStatuses[provider.id] ?? .disconnected).color)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(provider.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    if settingsManager.defaultProvider == provider.id {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    if let latency = providerLatencies[provider.id] {
                        Text("\(Int(latency))ms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if testingProvider == provider.id {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button {
                    testProvider(provider.id)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                showingProviderDetail = provider
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - API Keys Section

    private var apiKeysSection: some View {
        Group {
            apiKeyField(
                provider: "openai",
                displayName: "OpenAI",
                key: $openAIKey,
                placeholder: "sk-..."
            )

            apiKeyField(
                provider: "anthropic",
                displayName: "Anthropic",
                key: $anthropicKey,
                placeholder: "sk-ant-..."
            )

            apiKeyField(
                provider: "google",
                displayName: "Google AI",
                key: $googleKey,
                placeholder: "AIza..."
            )

            apiKeyField(
                provider: "perplexity",
                displayName: "Perplexity",
                key: $perplexityKey,
                placeholder: "pplx-..."
            )

            apiKeyField(
                provider: "groq",
                displayName: "Groq",
                key: $groqKey,
                placeholder: "gsk_..."
            )

            apiKeyField(
                provider: "openrouter",
                displayName: "OpenRouter",
                key: $openRouterKey,
                placeholder: "sk-or-..."
            )

            Text("API keys are stored securely in your system Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func apiKeyField(
        provider: String,
        displayName: String,
        key: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack {
            Text(displayName)
                .frame(width: 100, alignment: .leading)

            SecureField(placeholder, text: key)
                .textFieldStyle(.roundedBorder)
                .onChange(of: key.wrappedValue) { _, newValue in
                    saveAPIKey(newValue, for: provider)
                }

            if settingsManager.hasAPIKey(for: provider) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if !key.wrappedValue.isEmpty {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Usage Statistics Section

    private var usageStatisticsSection: some View {
        Group {
            // Today's usage
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Today")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("No data")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Est. Cost")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("$0.00")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            // Performance metrics
            HStack(spacing: 16) {
                metricCard(
                    title: "Avg Latency",
                    value: formatLatency(nil),
                    icon: "clock",
                    color: .blue
                )

                metricCard(
                    title: "Tokens/sec",
                    value: formatTokensPerSecond(nil),
                    icon: "bolt",
                    color: .orange
                )

                metricCard(
                    title: "Error Rate",
                    value: formatErrorRate(nil),
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }

            Button("View Detailed History") {
                showingUsageHistory = true
            }
            .font(.caption)
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Fallback Configuration Section

    private var fallbackConfigurationSection: some View {
        Group {
            Toggle("Enable Auto-Fallback", isOn: $autoFallbackEnabled)

            Text("Automatically switch to backup providers if the primary fails.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if autoFallbackEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fallback Order")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Array(fallbackOrder.enumerated()), id: \.offset) { index, providerId in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            if let provider = ProviderDisplayInfo.all.first(where: { $0.id == providerId }) {
                                Image(systemName: provider.icon)
                                    .foregroundStyle(.secondary)
                                Text(provider.displayName)
                            }

                            Spacer()

                            // Move buttons
                            if index > 0 {
                                Button {
                                    moveFallback(from: index, direction: .up)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }

                            if index < fallbackOrder.count - 1 {
                                Button {
                                    moveFallback(from: index, direction: .down)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        Group {
            HStack {
                Text("Request Timeout")
                Spacer()
                Picker("", selection: .constant(30)) {
                    Text("15 sec").tag(15)
                    Text("30 sec").tag(30)
                    Text("60 sec").tag(60)
                    Text("120 sec").tag(120)
                }
                .frame(width: 100)
            }

            HStack {
                Text("Max Retries")
                Spacer()
                Stepper("3", value: .constant(3), in: 0...5)
                    .frame(width: 100)
            }

            Toggle("Log API Requests", isOn: .constant(false))

            Text("Logging requests may impact performance and storage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Provider Detail Sheet

    private func providerDetailSheet(_ provider: ProviderDisplayInfo) -> some View {
        NavigationStack {
            Form {
                Section("About") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: provider.icon)
                                .font(.largeTitle)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading) {
                                Text(provider.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(statusText(for: provider.id))
                                    .font(.caption)
                                    .foregroundStyle((providerStatuses[provider.id] ?? .disconnected).color)
                            }
                        }

                        Text(provider.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Image(systemName: (providerStatuses[provider.id] ?? .disconnected).icon)
                            .foregroundStyle((providerStatuses[provider.id] ?? .disconnected).color)
                        Text(statusText(for: provider.id))
                            .foregroundStyle(.secondary)
                    }

                    if let latency = providerLatencies[provider.id] {
                        HStack {
                            Text("Latency")
                            Spacer()
                            Text("\(Int(latency))ms")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let url = provider.websiteURL {
                        Link(destination: url) {
                            HStack {
                                Text("Get API Key")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }
                }

                Section("Capabilities") {
                    providerCapabilities(for: provider.id)
                }

                Section {
                    Button("Test Connection") {
                        testProvider(provider.id)
                    }
                    .disabled(testingProvider != nil)
                }
            }
            .navigationTitle(provider.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingProviderDetail = nil
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 500)
        #endif
    }

    @ViewBuilder
    private func providerCapabilities(for providerId: String) -> some View {
        switch providerId {
        case "openai":
            capabilityRow("Vision", supported: true)
            capabilityRow("Function Calling", supported: true)
            capabilityRow("Streaming", supported: true)
            capabilityRow("Web Search", supported: false)

        case "anthropic":
            capabilityRow("Vision", supported: true)
            capabilityRow("Function Calling", supported: true)
            capabilityRow("Streaming", supported: true)
            capabilityRow("Computer Use", supported: true)

        case "google":
            capabilityRow("Vision", supported: true)
            capabilityRow("Function Calling", supported: true)
            capabilityRow("Streaming", supported: true)
            capabilityRow("Grounding", supported: true)

        case "perplexity":
            capabilityRow("Web Search", supported: true)
            capabilityRow("Citations", supported: true)
            capabilityRow("Streaming", supported: true)
            capabilityRow("Vision", supported: false)

        case "groq":
            capabilityRow("Ultra-Fast Inference", supported: true)
            capabilityRow("Streaming", supported: true)
            capabilityRow("Function Calling", supported: true)
            capabilityRow("Vision", supported: false)

        case "openrouter":
            capabilityRow("200+ Models", supported: true)
            capabilityRow("Auto-Routing", supported: true)
            capabilityRow("Fallback Support", supported: true)
            capabilityRow("Usage Tracking", supported: true)

        default:
            Text("No capabilities information available")
                .foregroundStyle(.secondary)
        }
    }

    private func capabilityRow(_ name: String, supported: Bool) -> some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(supported ? .green : .secondary)
        }
    }

    // MARK: - Helper Methods

    private func loadAPIKeysIfNeeded() {
        guard !apiKeysLoaded else { return }
        apiKeysLoaded = true

        openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
        anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
        googleKey = settingsManager.getAPIKey(for: "google") ?? ""
        perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
        groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
        openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
    }

    private func saveAPIKey(_ key: String, for provider: String) {
        if !key.isEmpty {
            settingsManager.setAPIKey(key, for: provider)
            refreshProviderStatus()
        }
    }

    private func initializeProviderStatuses() {
        for provider in ProviderDisplayInfo.all {
            let hasKey = settingsManager.hasAPIKey(for: provider.id)
            providerStatuses[provider.id] = hasKey ? .connected : .disconnected
        }
    }

    private func loadFallbackOrder() {
        // Initialize with all providers in default order
        fallbackOrder = ProviderDisplayInfo.all
            .filter { settingsManager.hasAPIKey(for: $0.id) }
            .map { $0.id }

        // Put default provider first
        if let defaultIndex = fallbackOrder.firstIndex(of: settingsManager.defaultProvider) {
            fallbackOrder.remove(at: defaultIndex)
            fallbackOrder.insert(settingsManager.defaultProvider, at: 0)
        }
    }

    private func refreshProviderStatus() {
        for provider in ProviderDisplayInfo.all {
            let hasKey = settingsManager.hasAPIKey(for: provider.id)
            if !hasKey {
                providerStatuses[provider.id] = .disconnected
            }
        }
    }

    private func testProvider(_ providerId: String) {
        testingProvider = providerId
        providerStatuses[providerId] = .testing

        Task {
            let startTime = Date()

            // Simulate API test (in real implementation, make actual API call)
            try? await Task.sleep(for: .seconds(1))

            let latency = Date().timeIntervalSince(startTime) * 1000

            await MainActor.run {
                if settingsManager.hasAPIKey(for: providerId) {
                    providerStatuses[providerId] = .connected
                    providerLatencies[providerId] = latency
                } else {
                    providerStatuses[providerId] = .disconnected
                }
                testingProvider = nil
            }
        }
    }

    func testAllProviders() {
        for provider in ProviderDisplayInfo.all {
            if settingsManager.hasAPIKey(for: provider.id) {
                testProvider(provider.id)
            }
        }
    }

    private enum MoveDirection {
        case up, down
    }

    private func moveFallback(from index: Int, direction: MoveDirection) {
        let newIndex = direction == .up ? index - 1 : index + 1
        guard newIndex >= 0, newIndex < fallbackOrder.count else { return }
        fallbackOrder.swapAt(index, newIndex)
    }

    private func statusText(for providerId: String) -> String {
        switch providerStatuses[providerId] ?? .disconnected {
        case .connected: "Connected"
        case .disconnected: "Not Configured"
        case .testing: "Testing..."
        case .error: "Error"
        }
    }

    private func formatLatency(_ latency: Double?) -> String {
        guard let latency else { return "—" }
        return "\(Int(latency))ms"
    }

    private func formatTokensPerSecond(_ tps: Double?) -> String {
        guard let tps else { return "—" }
        return "\(Int(tps))"
    }

    private func formatErrorRate(_ rate: Double?) -> String {
        guard let rate else { return "0%" }
        return "\(String(format: "%.1f", rate))%"
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    AIProvidersSettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        AIProvidersSettingsView()
            .navigationTitle("AI Providers")
    }
}
#endif
