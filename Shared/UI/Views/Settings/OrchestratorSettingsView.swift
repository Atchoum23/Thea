// OrchestratorSettingsView.swift
// Comprehensive AI orchestration configuration for Thea

import SwiftUI

// MARK: - Benchmark Service Stub (ModelBenchmarkService is in excluded MetaAI folder)

#if os(macOS)

/// Lightweight stub replacing excluded MetaAI/ModelBenchmarkService
/// Provides the same interface used by OrchestratorSettingsView
@MainActor
@Observable
private final class BenchmarkServiceStub {
    static let shared = BenchmarkServiceStub()

    struct BenchmarkEntry {
        let isLocal: Bool
    }

    private(set) var benchmarks: [String: BenchmarkEntry] = [:]
    private(set) var lastUpdateDate: Date?
    private(set) var updateError: Error?

    private init() {}

    func updateBenchmarks() async {
        // No-op stub — real benchmarks require MetaAI infrastructure
        lastUpdateDate = Date()
    }
}

// MARK: - Orchestrator Settings View

struct OrchestratorSettingsView: View {
    @State var config = OrchestratorConfiguration.load()
    @State private var benchmarkService = BenchmarkServiceStub.shared
    @State private var isRefreshingBenchmarks = false
    @State var showingRoutingRuleEditor = false
    @State var showingExecutionHistory = false
    @State var executionStats = ExecutionStatistics()

    var body: some View {
        Form {
            // MARK: - Overview
            Section("Orchestrator Overview") {
                orchestratorOverview
            }

            // MARK: - Agent Pool Monitoring
            Section("Agent Pool & Status") {
                agentPoolSection
            }

            enableSection
            modelPreferenceSection
            benchmarkSection

            // MARK: - Task Routing with Editor
            Section("Task Classification & Routing") {
                taskRoutingSection
            }

            // MARK: - Performance Metrics
            Section("Performance Metrics") {
                performanceMetricsSection
            }

            // MARK: - Execution History
            Section("Execution History") {
                executionHistorySection
            }

            costManagementSection
            executionSettingsSection
            debugSection

            // MARK: - Reset Section
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .sheet(isPresented: $showingRoutingRuleEditor) {
            routingRuleEditorSheet
        }
        .sheet(isPresented: $showingExecutionHistory) {
            executionHistorySheet
        }
    }

    // MARK: - Orchestrator Overview

    private var orchestratorOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "Status",
                    value: config.orchestratorEnabled ? "Active" : "Disabled",
                    icon: config.orchestratorEnabled ? "checkmark.circle.fill" : "xmark.circle.fill",
                    color: config.orchestratorEnabled ? .green : .red
                )

                overviewCard(
                    title: "Mode",
                    value: config.localModelPreference.rawValue,
                    icon: modeIcon(for: config.localModelPreference),
                    color: .blue
                )

                overviewCard(
                    title: "Routing Rules",
                    value: "\(config.taskRoutingRules.count)",
                    icon: "arrow.triangle.branch",
                    color: .orange
                )

                overviewCard(
                    title: "Max Agents",
                    value: "\(config.maxParallelAgents)",
                    icon: "person.3.fill",
                    color: .purple
                )
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(
                    title: "Status",
                    value: config.orchestratorEnabled ? "Active" : "Disabled",
                    icon: config.orchestratorEnabled ? "checkmark.circle.fill" : "xmark.circle.fill",
                    color: config.orchestratorEnabled ? .green : .red
                )

                overviewCard(
                    title: "Mode",
                    value: config.localModelPreference.rawValue,
                    icon: modeIcon(for: config.localModelPreference),
                    color: .blue
                )

                overviewCard(
                    title: "Routing Rules",
                    value: "\(config.taskRoutingRules.count)",
                    icon: "arrow.triangle.branch",
                    color: .orange
                )

                overviewCard(
                    title: "Max Agents",
                    value: "\(config.maxParallelAgents)",
                    icon: "person.3.fill",
                    color: .purple
                )
            }
            #endif
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func modeIcon(for preference: OrchestratorConfiguration.LocalModelPreference) -> String {
        switch preference {
        case .always: "cpu"
        case .prefer: "cpu.fill"
        case .balanced: "scale.3d"
        case .cloudFirst: "cloud.fill"
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

    // MARK: - Benchmark Section

    private var benchmarkSection: some View {
        Section("Model Benchmarks") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dynamic Model Routing")
                            .font(.headline)

                        if let lastUpdate = benchmarkService.lastUpdateDate {
                            Text("Last updated: \(lastUpdate, style: .relative) ago")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never updated")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    Button {
                        refreshBenchmarks()
                    } label: {
                        HStack(spacing: 4) {
                            if isRefreshingBenchmarks {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRefreshingBenchmarks ? "Refreshing..." : "Refresh Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshingBenchmarks)
                }

                // Benchmark stats
                if !benchmarkService.benchmarks.isEmpty {
                    Divider()

                    HStack(spacing: 20) {
                        benchmarkStat(
                            icon: "cpu",
                            title: "Local Models",
                            value: "\(benchmarkService.benchmarks.values.filter(\.isLocal).count)"
                        )

                        benchmarkStat(
                            icon: "cloud",
                            title: "Cloud Models",
                            value: "\(benchmarkService.benchmarks.values.filter { !$0.isLocal }.count)"
                        )

                        benchmarkStat(
                            icon: "chart.bar",
                            title: "Total Benchmarked",
                            value: "\(benchmarkService.benchmarks.count)"
                        )
                    }
                }

                // Update error
                if let error = benchmarkService.updateError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Update failed: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Benchmarks are fetched from OpenRouter and HuggingFace to keep routing rules up-to-date with latest model performance data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func benchmarkStat(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func refreshBenchmarks() {
        isRefreshingBenchmarks = true
        Task {
            await benchmarkService.updateBenchmarks()
            isRefreshingBenchmarks = false
        }
    }

    // MARK: - Task Routing Section

    private var taskRoutingSection: some View {
        Group {
            Toggle("AI-Powered Classification", isOn: $config.useAIForClassification)
                .onChange(of: config.useAIForClassification) { _, _ in
                    saveConfig()
                }

            if config.useAIForClassification {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confidence Threshold: \(Int(config.classificationConfidenceThreshold * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: Binding(
                        get: { Double(config.classificationConfidenceThreshold) },
                        set: { config.classificationConfidenceThreshold = Float($0) }
                    ), in: 0.5 ... 1.0, step: 0.05)
                        .onChange(of: config.classificationConfidenceThreshold) { _, _ in
                            saveConfig()
                        }

                    Text("Higher = more accurate but slower")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Text("Fast keyword-based classification")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Routing rules with edit capability
            HStack {
                Text("Routing Rules")
                    .font(.subheadline)

                Spacer()

                Text("\(config.taskRoutingRules.count) configured")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingRoutingRuleEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            // Routing rules summary
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(config.taskRoutingRules.keys.sorted()), id: \.self) { taskKey in
                        if let models = config.taskRoutingRules[taskKey] {
                            routingRuleRow(taskType: taskKey, models: models)
                        }
                    }
                }
            } label: {
                Text("View All Rules")
                    .font(.caption)
            }
        }
    }

    private func routingRuleRow(taskType: String, models: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formatTaskType(taskType))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(models.prefix(2), id: \.self) { model in
                    Text(shortModelName(model))
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(model.hasPrefix("local-") ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .foregroundStyle(model.hasPrefix("local-") ? .green : .blue)
                        .cornerRadius(4)
                }
                if models.count > 2 {
                    Text("+\(models.count - 2)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    func shortModelName(_ model: String) -> String {
        if model.hasPrefix("local-") {
            return "🖥️ " + model.replacingOccurrences(of: "local-", with: "")
        }
        let parts = model.split(separator: "/")
        return String(parts.last ?? Substring(model))
    }

    func formatTaskType(_ taskType: String) -> String {
        // Convert camelCase to Title Case with spaces
        var result = ""
        for char in taskType {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    // MARK: - Cost Management Section

    private var costManagementSection: some View {
        Section("Cost Optimization") {
            Toggle("Prefer Cost-Effective Models", isOn: $config.preferCheaperModels)
                .onChange(of: config.preferCheaperModels) { _, _ in
                    saveConfig()
                }

            HStack {
                Image(systemName: config.preferCheaperModels ? "leaf.fill" : "bolt.fill")
                    .foregroundStyle(config.preferCheaperModels ? .green : .orange)
                Text(config.preferCheaperModels
                    ? "Optimizing for cost - local and cheaper models preferred"
                    : "Optimizing for performance - best model for each task")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Cost budget
            if let budget = config.costBudgetPerQuery {
                HStack {
                    Text("Budget per Query")
                    Spacer()
                    Text("$\(budget as NSDecimalNumber)")
                        .foregroundStyle(.secondary)
                }
            }
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

    func saveConfig() {
        config.save()
    }

    private func resetToDefaults() {
        config = OrchestratorConfiguration()
        saveConfig()
    }
}

// MARK: - Preview

// macOS Preview
#Preview {
    OrchestratorSettingsView()
        .frame(width: 700, height: 900)
}
#endif // end os(macOS)
