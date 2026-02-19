// AIProvidersSettingsViewSections.swift
// Supporting types and extension sections for AIProvidersSettingsView

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

// MARK: - Extension Sections

extension AIProvidersSettingsView {

    // MARK: - Provider Detail Sheet

    func providerDetailSheet(_ provider: ProviderDisplayInfo) -> some View {
        NavigationStack {
            Form {
                Section("About") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: provider.icon)
                                .font(.largeTitle)
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)

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
                    providerConnectionDetails(provider)
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
    func providerConnectionDetails(_ provider: ProviderDisplayInfo) -> some View {
        HStack {
            Text("Status")
            Spacer()
            Image(systemName: (providerStatuses[provider.id] ?? .disconnected).icon)
                .foregroundStyle((providerStatuses[provider.id] ?? .disconnected).color)
                .accessibilityHidden(true)
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
                        .accessibilityHidden(true)
                }
            }
        }
    }

    @ViewBuilder
    func providerCapabilities(for providerId: String) -> some View {
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

    func capabilityRow(_ name: String, supported: Bool) -> some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(supported ? .green : .secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(supported ? "supported" : "not supported")")
    }

    // MARK: - Helper Methods

    func statusText(for providerId: String) -> String {
        switch providerStatuses[providerId] ?? .disconnected {
        case .connected: "Connected"
        case .disconnected: "Not Configured"
        case .testing: "Testing..."
        case .error: "Error"
        }
    }

    func formatLatency(_ latency: Double?) -> String {
        guard let latency else { return "\u{2014}" }
        return "\(Int(latency))ms"
    }

    func formatTokensPerSecond(_ tps: Double?) -> String {
        guard let tps else { return "\u{2014}" }
        return "\(Int(tps))"
    }

    func formatErrorRate(_ rate: Double?) -> String {
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
