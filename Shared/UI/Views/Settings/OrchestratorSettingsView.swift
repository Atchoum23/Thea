import SwiftUI

// MARK: - Orchestrator Settings View

// Configure AI orchestration, model routing, and query decomposition

struct OrchestratorSettingsView: View {
    @State private var config = OrchestratorConfiguration.load()
    @State private var showingSaveConfirmation = false

    var body: some View {
        Form {
            enableSection
            modelPreferenceSection
            taskRoutingSection
            costManagementSection
            executionSettingsSection
            debugSection
        }
        .formStyle(.grouped)
        .padding()
        .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
            Button("OK") { showingSaveConfirmation = false }
        } message: {
            Text("Orchestrator settings have been saved.")
        }
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        Section("AI Orchestration") {
            Toggle("Enable Orchestrator", isOn: $config.orchestratorEnabled)
                .onChange(of: config.orchestratorEnabled) { _, _ in
                    saveConfig()
                }

            if config.orchestratorEnabled {
                Text("AI orchestrator will decompose complex queries and route tasks to optimal models.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Orchestrator disabled. Queries will use the default model directly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Model Preference Section

    private var modelPreferenceSection: some View {
        Section("Model Preference") {
            Picker("Local Model Preference", selection: $config.localModelPreference) {
                ForEach(OrchestratorConfiguration.LocalModelPreference.allCases, id: \.self) { preference in
                    Text(preference.rawValue).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: config.localModelPreference) { _, _ in
                saveConfig()
            }

            Text(config.localModelPreference.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            // Preference details
            VStack(alignment: .leading, spacing: 8) {
                preferenceDetail(
                    icon: "cpu",
                    title: "Local Models",
                    description: config.localModelPreference == .always || config.localModelPreference == .prefer
                        ? "Prioritized"
                        : "Available as fallback"
                )

                preferenceDetail(
                    icon: "cloud",
                    title: "Cloud Models",
                    description: config.localModelPreference == .cloudFirst
                        ? "Prioritized"
                        : "Used for complex tasks"
                )
            }
            .padding(.top, 8)
        }
    }

    private func preferenceDetail(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Task Routing Section

    private var taskRoutingSection: some View {
        Section("Task Routing") {
            Toggle("Use AI for Classification", isOn: $config.useAIForClassification)
                .onChange(of: config.useAIForClassification) { _, _ in
                    saveConfig()
                }

            if config.useAIForClassification {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Classification Confidence Threshold")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Low")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Slider(value: Binding(
                            get: { Double(config.classificationConfidenceThreshold) },
                            set: { config.classificationConfidenceThreshold = Float($0) }
                        ), in: 0.5 ... 1.0, step: 0.05)
                            .onChange(of: config.classificationConfidenceThreshold) { _, _ in
                                saveConfig()
                            }
                        Text("High")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(String(format: "%.0f%% confidence required", config.classificationConfidenceThreshold * 100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Keyword-based classification (faster, less accurate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Cost Management Section

    private var costManagementSection: some View {
        Section("Cost Management") {
            Toggle("Prefer Cheaper Models", isOn: $config.preferCheaperModels)
                .onChange(of: config.preferCheaperModels) { _, _ in
                    saveConfig()
                }

            Text("When multiple models can handle a task, choose the most cost-effective option.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Execution Settings Section

    private var executionSettingsSection: some View {
        Section("Execution Settings") {
            HStack {
                Text("Max Parallel Agents")
                Spacer()
                Stepper("\(config.maxParallelAgents)", value: $config.maxParallelAgents, in: 1 ... 10)
                    .onChange(of: config.maxParallelAgents) { _, _ in
                        saveConfig()
                    }
            }

            HStack {
                Text("Agent Timeout")
                Spacer()
                Picker("", selection: $config.agentTimeoutSeconds) {
                    Text("30s").tag(30.0)
                    Text("60s").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                }
                .pickerStyle(.menu)
                .onChange(of: config.agentTimeoutSeconds) { _, _ in
                    saveConfig()
                }
            }

            Toggle("Enable Retry on Failure", isOn: $config.enableRetryOnFailure)
                .onChange(of: config.enableRetryOnFailure) { _, _ in
                    saveConfig()
                }

            if config.enableRetryOnFailure {
                HStack {
                    Text("Max Retry Attempts")
                    Spacer()
                    Stepper("\(config.maxRetryAttempts)", value: $config.maxRetryAttempts, in: 1 ... 5)
                        .onChange(of: config.maxRetryAttempts) { _, _ in
                            saveConfig()
                        }
                }
            }
        }
    }

    // MARK: - Debug Section

    private var debugSection: some View {
        Section("Debug & Monitoring") {
            Toggle("Show Decomposition Details", isOn: $config.showDecompositionDetails)
                .onChange(of: config.showDecompositionDetails) { _, _ in
                    saveConfig()
                }

            Toggle("Log Model Routing", isOn: $config.logModelRouting)
                .onChange(of: config.logModelRouting) { _, _ in
                    saveConfig()
                }

            Toggle("Show Agent Coordination", isOn: $config.showAgentCoordination)
                .onChange(of: config.showAgentCoordination) { _, _ in
                    saveConfig()
                }

            Toggle("Enable Result Validation", isOn: $config.enableResultValidation)
                .onChange(of: config.enableResultValidation) { _, _ in
                    saveConfig()
                }

            Text("Enable these options to see detailed information about orchestrator decisions and execution.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func saveConfig() {
        config.save()
        showingSaveConfirmation = true
    }
}

// MARK: - Preview

#Preview {
    OrchestratorSettingsView()
        .frame(width: 600, height: 700)
}
