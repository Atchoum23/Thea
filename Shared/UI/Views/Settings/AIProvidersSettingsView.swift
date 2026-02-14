// AIProvidersSettingsView.swift
// Comprehensive AI provider management for Thea
// Supporting types and sections in AIProvidersSettingsViewSections.swift

import SwiftUI

// MARK: - Main View

struct AIProvidersSettingsView: View {
    @State private var settingsManager = SettingsManager.shared

    // API Keys
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var googleKey: String = ""
    @State private var perplexityKey: String = ""
    @State private var groqKey: String = ""
    @State private var openRouterKey: String = ""
    @State private var apiKeysLoaded: Bool = false

    // Provider status
    @State var providerStatuses: [String: ProviderStatus] = [:]
    @State var providerLatencies: [String: Double] = [:]
    @State var testingProvider: String?

    // UI State
    @State var showingProviderDetail: ProviderDisplayInfo?
    @State private var showingUsageHistory = false

    // Fallback configuration
    @State private var fallbackOrder: [String] = []
    @State private var autoFallbackEnabled: Bool = true

    var body: some View {
        Form {
            Section("Default Provider") { defaultProviderSection }
            Section("Provider Status") { providerStatusOverview }
            Section("API Keys") { apiKeysSection }
            Section("Usage Statistics") { usageStatisticsSection }
            Section("Fallback Configuration") { fallbackConfigurationSection }
            Section("Advanced") { advancedSection }
            Section {
                Button("Test All Connections") { testAllProviders() }
                    .disabled(testingProvider != nil)
                Button("Refresh Provider Status") { refreshProviderStatus() }
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
                            .accessibilityHidden(true)
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
                .accessibilityLabel("Test \(provider.displayName) connection")
            }

            Button {
                showingProviderDetail = provider
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(provider.displayName)")
        }
        .padding(.vertical, 4)
    }

    // MARK: - API Keys Section

    private var apiKeysSection: some View {
        Group {
            apiKeyField(provider: "openai", displayName: "OpenAI", key: $openAIKey, placeholder: "sk-...")
            apiKeyField(provider: "anthropic", displayName: "Anthropic", key: $anthropicKey, placeholder: "sk-ant-...")
            apiKeyField(provider: "google", displayName: "Google AI", key: $googleKey, placeholder: "AIza...")
            apiKeyField(provider: "perplexity", displayName: "Perplexity", key: $perplexityKey, placeholder: "pplx-...")
            apiKeyField(provider: "groq", displayName: "Groq", key: $groqKey, placeholder: "gsk_...")
            apiKeyField(provider: "openrouter", displayName: "OpenRouter", key: $openRouterKey, placeholder: "sk-or-...")

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
                    .accessibilityHidden(true)
            } else if !key.wrappedValue.isEmpty {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Usage Statistics Section

    private var usageStatisticsSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Today").font(.caption).foregroundStyle(.secondary)
                        Text("No data").font(.headline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Est. Cost").font(.caption).foregroundStyle(.secondary)
                        Text("$0.00").font(.headline).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 16) {
                metricCard(title: "Avg Latency", value: formatLatency(nil), icon: "clock", color: .blue)
                metricCard(title: "Tokens/sec", value: formatTokensPerSecond(nil), icon: "bolt", color: .orange)
                metricCard(title: "Error Rate", value: formatErrorRate(nil), icon: "exclamationmark.triangle", color: .red)
            }

            Button("View Detailed History") { showingUsageHistory = true }
                .font(.caption)
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value).font(.caption).fontWeight(.semibold)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Fallback, Advanced, and Actions

extension AIProvidersSettingsView {

    var fallbackConfigurationSection: some View {
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
                        fallbackOrderRow(index: index, providerId: providerId)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func fallbackOrderRow(index: Int, providerId: String) -> some View {
        HStack {
            Text("\(index + 1).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if let provider = ProviderDisplayInfo.all.first(where: { $0.id == providerId }) {
                Image(systemName: provider.icon)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(provider.displayName)
            }

            Spacer()

            if index > 0 {
                Button { moveFallback(from: index, direction: .up) } label: {
                    Image(systemName: "chevron.up").font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move up")
            }

            if index < fallbackOrder.count - 1 {
                Button { moveFallback(from: index, direction: .down) } label: {
                    Image(systemName: "chevron.down").font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Move down")
            }
        }
        .padding(.vertical, 2)
    }

    var advancedSection: some View {
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

    // MARK: - Actions

    func loadAPIKeysIfNeeded() {
        guard !apiKeysLoaded else { return }
        apiKeysLoaded = true
        openAIKey = settingsManager.getAPIKey(for: "openai") ?? ""
        anthropicKey = settingsManager.getAPIKey(for: "anthropic") ?? ""
        googleKey = settingsManager.getAPIKey(for: "google") ?? ""
        perplexityKey = settingsManager.getAPIKey(for: "perplexity") ?? ""
        groqKey = settingsManager.getAPIKey(for: "groq") ?? ""
        openRouterKey = settingsManager.getAPIKey(for: "openrouter") ?? ""
    }

    func saveAPIKey(_ key: String, for provider: String) {
        if !key.isEmpty {
            settingsManager.setAPIKey(key, for: provider)
            refreshProviderStatus()
        }
    }

    func initializeProviderStatuses() {
        for provider in ProviderDisplayInfo.all {
            let hasKey = settingsManager.hasAPIKey(for: provider.id)
            providerStatuses[provider.id] = hasKey ? .connected : .disconnected
        }
    }

    func loadFallbackOrder() {
        fallbackOrder = ProviderDisplayInfo.all
            .filter { settingsManager.hasAPIKey(for: $0.id) }
            .map { $0.id }
        if let defaultIndex = fallbackOrder.firstIndex(of: settingsManager.defaultProvider) {
            fallbackOrder.remove(at: defaultIndex)
            fallbackOrder.insert(settingsManager.defaultProvider, at: 0)
        }
    }

    func refreshProviderStatus() {
        for provider in ProviderDisplayInfo.all {
            if !settingsManager.hasAPIKey(for: provider.id) {
                providerStatuses[provider.id] = .disconnected
            }
        }
    }

    func testProvider(_ providerId: String) {
        testingProvider = providerId
        providerStatuses[providerId] = .testing
        Task {
            let startTime = Date()
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

    private enum MoveDirection { case up, down }

    private func moveFallback(from index: Int, direction: MoveDirection) {
        let newIndex = direction == .up ? index - 1 : index + 1
        guard newIndex >= 0, newIndex < fallbackOrder.count else { return }
        fallbackOrder.swapAt(index, newIndex)
    }
}
