// OrchestratorSettingsView.swift
// Comprehensive AI orchestration configuration for Thea

import SwiftUI

// MARK: - Orchestrator Settings View

#if os(macOS)
struct OrchestratorSettingsView: View {
    @State private var config = OrchestratorConfiguration.load()
    @State private var showingSaveConfirmation = false
    @State private var benchmarkService = ModelBenchmarkService.shared
    @State private var isRefreshingBenchmarks = false
    @State private var showingRoutingRuleEditor = false
    @State private var showingExecutionHistory = false
    @State private var selectedTaskType: String?
    @State private var executionStats = ExecutionStatistics()

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

    // MARK: - Agent Pool Section

    private var agentPoolSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Agents")
                        .font(.headline)

                    Spacer()

                    Text("\(executionStats.activeAgents)/\(config.maxParallelAgents)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Agent Pool Visualization
                HStack(spacing: 4) {
                    ForEach(0..<config.maxParallelAgents, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index < executionStats.activeAgents ? Color.green : Color.gray.opacity(0.3))
                            .frame(height: 24)
                    }
                }

                Divider()

                // Task Queue
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Task Queue")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(executionStats.queuedTasks) tasks waiting")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Queue status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(executionStats.queuedTasks > 5 ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)

                        Text(executionStats.queuedTasks > 5 ? "Busy" : "Normal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Current Tasks
                if !executionStats.currentTasks.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Running Tasks")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ForEach(executionStats.currentTasks, id: \.id) { task in
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)

                                Text(task.description)
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer()

                                Text(task.model)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
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

    private func shortModelName(_ model: String) -> String {
        if model.hasPrefix("local-") {
            return "🖥️ " + model.replacingOccurrences(of: "local-", with: "")
        }
        let parts = model.split(separator: "/")
        return String(parts.last ?? Substring(model))
    }

    private func formatTaskType(_ taskType: String) -> String {
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

    // MARK: - Performance Metrics Section

    private var performanceMetricsSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                // Response Time
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Average Response Time")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(String(format: "%.2f", executionStats.avgResponseTime))s")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(executionStats.avgResponseTime < 2.0 ? .green : executionStats.avgResponseTime < 5.0 ? .orange : .red)
                    }

                    Spacer()

                    // Mini chart representation
                    responseTimeChart
                }

                Divider()

                // Success Rate
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Success Rate")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("\(Int(executionStats.successRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(executionStats.successRate > 0.95 ? .green : executionStats.successRate > 0.8 ? .orange : .red)
                    }

                    Spacer()

                    // Success/Failure breakdown
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(executionStats.successfulTasks) successful")
                            .font(.caption)
                            .foregroundStyle(.green)

                        Text("\(executionStats.failedTasks) failed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Divider()

                // Cost Tracking
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost Today")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("$\(String(format: "%.4f", executionStats.costToday))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("This Month: $\(String(format: "%.2f", executionStats.costThisMonth))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Tokens: \(formatNumber(executionStats.tokensUsedToday))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Model Usage Distribution
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Usage Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(executionStats.modelUsage.sorted { $0.value > $1.value }.prefix(5), id: \.key) { model, count in
                        HStack {
                            Text(shortModelName(model))
                                .font(.caption)
                                .frame(width: 120, alignment: .leading)

                            GeometryReader { geometry in
                                let maxCount = executionStats.modelUsage.values.max() ?? 1
                                let width = geometry.size.width * CGFloat(count) / CGFloat(maxCount)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(model.hasPrefix("local-") ? Color.green : Color.blue)
                                    .frame(width: width, height: 12)
                            }
                            .frame(height: 12)

                            Text("\(count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var responseTimeChart: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(executionStats.recentResponseTimes.suffix(10).indices, id: \.self) { index in
                let time = executionStats.recentResponseTimes[index]
                let maxTime = executionStats.recentResponseTimes.max() ?? 1.0
                let height = CGFloat(time / maxTime) * 30

                RoundedRectangle(cornerRadius: 1)
                    .fill(time < 2.0 ? Color.green : time < 5.0 ? Color.orange : Color.red)
                    .frame(width: 6, height: max(4, height))
            }
        }
        .frame(height: 30)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }

    // MARK: - Execution History Section

    private var executionHistorySection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Executions")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(executionStats.totalExecutions) total executions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingExecutionHistory = true
                } label: {
                    Label("View All", systemImage: "list.bullet")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            // Recent history preview
            if !executionStats.recentExecutions.isEmpty {
                ForEach(executionStats.recentExecutions.prefix(3), id: \.id) { execution in
                    executionHistoryRow(execution)
                }
            } else {
                Text("No recent executions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    private func executionHistoryRow(_ execution: ExecutionRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: execution.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(execution.success ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(execution.taskType)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(execution.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(shortModelName(execution.model))
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)

                Text("\(String(format: "%.2f", execution.responseTime))s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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

    // MARK: - Routing Rule Editor Sheet

    private var routingRuleEditorSheet: some View {
        NavigationStack {
            List {
                Section("Task Types") {
                    ForEach(Array(config.taskRoutingRules.keys.sorted()), id: \.self) { taskType in
                        NavigationLink {
                            taskTypeEditorView(taskType: taskType)
                        } label: {
                            HStack {
                                Text(formatTaskType(taskType))
                                    .font(.body)

                                Spacer()

                                if let models = config.taskRoutingRules[taskType] {
                                    Text("\(models.count) models")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        addNewTaskType()
                    } label: {
                        Label("Add Custom Task Type", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Routing Rules")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingRoutingRuleEditor = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 500)
        #endif
    }

    @ViewBuilder
    private func taskTypeEditorView(taskType: String) -> some View {
        Form {
            Section("Task Type") {
                Text(formatTaskType(taskType))
                    .font(.headline)
            }

            Section("Model Priority (Drag to Reorder)") {
                if let models = config.taskRoutingRules[taskType] {
                    ForEach(models, id: \.self) { model in
                        HStack {
                            Image(systemName: model.hasPrefix("local-") ? "cpu" : "cloud")
                                .foregroundStyle(model.hasPrefix("local-") ? .green : .blue)

                            Text(model)
                                .font(.body)

                            Spacer()

                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onMove { from, to in
                        var models = config.taskRoutingRules[taskType] ?? []
                        models.move(fromOffsets: from, toOffset: to)
                        config.taskRoutingRules[taskType] = models
                        saveConfig()
                    }
                }
            }

            Section {
                Button {
                    addModelToTaskType(taskType)
                } label: {
                    Label("Add Model", systemImage: "plus")
                }
            }
        }
        .navigationTitle(formatTaskType(taskType))
    }

    private func addNewTaskType() {
        let newType = "custom\(config.taskRoutingRules.count + 1)"
        config.taskRoutingRules[newType] = ["local-any"]
        saveConfig()
    }

    private func addModelToTaskType(_ taskType: String) {
        var models = config.taskRoutingRules[taskType] ?? []
        models.append("openai/gpt-4o-mini")
        config.taskRoutingRules[taskType] = models
        saveConfig()
    }

    // MARK: - Execution History Sheet

    private var executionHistorySheet: some View {
        NavigationStack {
            List {
                if executionStats.recentExecutions.isEmpty {
                    Text("No execution history available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(executionStats.recentExecutions, id: \.id) { execution in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: execution.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(execution.success ? .green : .red)

                                Text(execution.taskType)
                                    .font(.headline)

                                Spacer()

                                Text(execution.timestamp, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Label(execution.model, systemImage: execution.model.hasPrefix("local-") ? "cpu" : "cloud")
                                    .font(.caption)

                                Spacer()

                                Text("Time: \(String(format: "%.2f", execution.responseTime))s")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("Tokens: \(execution.tokensUsed)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if !execution.errorMessage.isEmpty {
                                Text(execution.errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Execution History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingExecutionHistory = false
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear History", role: .destructive) {
                        executionStats.recentExecutions = []
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 700, height: 500)
        #endif
    }

    // MARK: - Actions

    private func saveConfig() {
        config.save()
    }

    private func resetToDefaults() {
        config = OrchestratorConfiguration()
        saveConfig()
    }
}

// MARK: - Supporting Types

/// Statistics for orchestrator execution
struct ExecutionStatistics {
    var activeAgents: Int = 0
    var queuedTasks: Int = 0
    var currentTasks: [CurrentTask] = []
    var avgResponseTime: Double = 1.85
    var successRate: Double = 0.96
    var successfulTasks: Int = 142
    var failedTasks: Int = 6
    var costToday: Double = 0.0234
    var costThisMonth: Double = 1.87
    var tokensUsedToday: Int = 45_230
    var recentResponseTimes: [Double] = [1.2, 0.8, 2.1, 1.5, 0.9, 3.2, 1.1, 0.7, 1.8, 1.3]
    var modelUsage: [String: Int] = [
        "local-any": 45,
        "anthropic/claude-sonnet-4": 38,
        "openai/gpt-4o-mini": 32,
        "openai/gpt-4o": 18,
        "local-large": 15
    ]
    var totalExecutions: Int = 148
    var recentExecutions: [ExecutionRecord] = [
        ExecutionRecord(id: UUID(), taskType: "Code Generation", model: "anthropic/claude-sonnet-4", responseTime: 2.3, tokensUsed: 1250, success: true, timestamp: Date().addingTimeInterval(-300), errorMessage: ""),
        ExecutionRecord(id: UUID(), taskType: "Simple QA", model: "local-any", responseTime: 0.8, tokensUsed: 320, success: true, timestamp: Date().addingTimeInterval(-600), errorMessage: ""),
        ExecutionRecord(id: UUID(), taskType: "Analysis", model: "openai/gpt-4o", responseTime: 4.1, tokensUsed: 2100, success: true, timestamp: Date().addingTimeInterval(-900), errorMessage: "")
    ]
}

struct CurrentTask: Identifiable {
    let id = UUID()
    let description: String
    let model: String
}

struct ExecutionRecord: Identifiable {
    let id: UUID
    let taskType: String
    let model: String
    let responseTime: Double
    let tokensUsed: Int
    let success: Bool
    let timestamp: Date
    let errorMessage: String
}

// MARK: - Preview

// macOS Preview
#Preview {
    OrchestratorSettingsView()
        .frame(width: 700, height: 900)
}
#endif // end os(macOS)
