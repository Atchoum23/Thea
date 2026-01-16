// ConversationSettingsView.swift
import SwiftUI

@MainActor
public struct ConversationSettingsView: View {
    @State private var config = ConversationConfiguration.load()
    @State private var showingProviderInfo = false

    public init() {}

    public var body: some View {
        Form {
            // Context Window Section
            Section {
                contextWindowSettings
            } header: {
                Label("Context Window", systemImage: "rectangle.stack")
            } footer: {
                Text("Controls how much conversation history is sent to the AI.")
            }

            // Conversation History Section
            Section {
                historySettings
            } header: {
                Label("Conversation History", systemImage: "clock.arrow.circlepath")
            } footer: {
                Text("Controls how conversations are stored and retained.")
            }

            // Meta-AI Section
            Section {
                metaAISettings
            } header: {
                Label("Meta-AI Context", systemImage: "brain")
            } footer: {
                Text("Meta-AI orchestrates complex tasks and needs sufficient context.")
            }

            // Advanced Section
            Section {
                advancedSettings
            } header: {
                Label("Advanced", systemImage: "gearshape.2")
            }

            // Provider Context Sizes
            Section {
                providerInfoButton
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Conversation & Context")
        .onChange(of: config) { _, _ in
            config.save()
        }
        .sheet(isPresented: $showingProviderInfo) {
            providerContextSheet
        }
    }

    // MARK: - Context Window Settings

    private var contextWindowSettings: some View {
        Group {
            Picker("Context Strategy", selection: $config.contextStrategy) {
                ForEach(ConversationConfiguration.ContextStrategy.allCases, id: \.self) { strategy in
                    VStack(alignment: .leading) {
                        Text(strategy.rawValue)
                    }
                    .tag(strategy)
                }
            }

            Text(config.contextStrategy.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if config.contextStrategy != .unlimited {
                HStack {
                    Text("Max Context Tokens")
                    Spacer()
                    TextField("Unlimited", value: $config.maxContextTokens, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                if let max = config.maxContextTokens {
                    Text("\(max.formatted()) tokens ≈ \((max * 4).formatted()) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - History Settings

    private var historySettings: some View {
        Group {
            Toggle("Unlimited Conversation Length", isOn: Binding(
                get: { config.maxConversationLength == nil },
                set: { newValue in
                    config.maxConversationLength = newValue ? nil : 100
                }
            ))

            if config.maxConversationLength != nil {
                Stepper(
                    "Max Messages: \(config.maxConversationLength ?? 100)",
                    value: Binding(
                        get: { config.maxConversationLength ?? 100 },
                        set: { config.maxConversationLength = $0 }
                    ),
                    in: 10...1_000,
                    step: 10
                )
            }

            Toggle("Persist Full History", isOn: $config.persistFullHistory)
        }
    }

    // MARK: - Meta-AI Settings

    private var metaAISettings: some View {
        Group {
            Toggle("Allow Meta-AI Context Expansion", isOn: $config.allowMetaAIContextExpansion)

            if config.allowMetaAIContextExpansion {
                Picker("Meta-AI Priority", selection: $config.metaAIContextPriority) {
                    ForEach(ConversationConfiguration.MetaAIPriority.allCases, id: \.self) { priority in
                        Text(priority.rawValue).tag(priority)
                    }
                }

                HStack {
                    Text("Reserved Tokens for Meta-AI")
                    Spacer()
                    TextField("50000", value: $config.metaAIReservedTokens, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                Text("\(Int(config.metaAIContextPriority.allocationPercentage * 100))% of context allocated to Meta-AI operations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Advanced Settings

    private var advancedSettings: some View {
        Group {
            Picker("Token Counting", selection: $config.tokenCountingMethod) {
                Text("Estimate (Fast)").tag(ConversationConfiguration.TokenCountingMethod.estimate)
                Text("Accurate (Slower)").tag(ConversationConfiguration.TokenCountingMethod.accurate)
            }

            Toggle("Enable Streaming", isOn: $config.enableStreaming)

            if config.enableStreaming {
                Stepper(
                    "Streaming Buffer: \(config.streamingBufferSize) chars",
                    value: $config.streamingBufferSize,
                    in: 10...500,
                    step: 10
                )
            }
        }
    }

    // MARK: - Provider Info

    private var providerInfoButton: some View {
        Button {
            showingProviderInfo = true
        } label: {
            HStack {
                Text("View Provider Context Sizes")
                Spacer()
                Image(systemName: "info.circle")
            }
        }
    }

    private var providerContextSheet: some View {
        NavigationStack {
            List {
                ForEach(ConversationConfiguration.providerContextSizes.sorted { $0.value > $1.value }, id: \.key) { provider, size in
                    HStack {
                        Text(provider)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(formatTokens(size))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Provider Context Sizes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingProviderInfo = false
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return "\(count / 1_000_000)M tokens"
        } else {
            return "\(count / 1_000)K tokens"
        }
    }
}
