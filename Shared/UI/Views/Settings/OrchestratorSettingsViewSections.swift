// OrchestratorSettingsViewSections.swift
// Extracted sub-views and supporting types for OrchestratorSettingsView

import SwiftUI

#if os(macOS)

// MARK: - Agent Pool & Performance Sections

extension OrchestratorSettingsView {

    // MARK: - Agent Pool Section

    var agentPoolSection: some View {
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

    // MARK: - Performance Metrics Section

    var performanceMetricsSection: some View {
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

    var responseTimeChart: some View {
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

    func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }

    // MARK: - Execution History Section

    var executionHistorySection: some View {
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

    func executionHistoryRow(_ execution: ExecutionRecord) -> some View {
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

    // MARK: - Routing Rule Editor Sheet

    var routingRuleEditorSheet: some View {
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
    func taskTypeEditorView(taskType: String) -> some View {
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

    func addNewTaskType() {
        let newType = "custom\(config.taskRoutingRules.count + 1)"
        config.taskRoutingRules[newType] = ["local-any"]
        saveConfig()
    }

    func addModelToTaskType(_ taskType: String) {
        var models = config.taskRoutingRules[taskType] ?? []
        models.append("openai/gpt-4o-mini")
        config.taskRoutingRules[taskType] = models
        saveConfig()
    }

    // MARK: - Execution History Sheet

    var executionHistorySheet: some View {
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

#Preview {
    OrchestratorSettingsView()
        .frame(width: 700, height: 900)
}

#endif // end os(macOS)
