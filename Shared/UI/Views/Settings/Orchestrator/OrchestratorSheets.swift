//
//  OrchestratorSheets.swift
//  Thea
//
//  Sheet views for Orchestrator Settings (routing rule editor, execution history)
//  Extracted from OrchestratorSettingsView.swift for better code organization
//

import SwiftUI

#if os(macOS)

// MARK: - Routing Rule Editor Sheet

extension OrchestratorSettingsView {
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
}

// MARK: - Execution History Sheet

extension OrchestratorSettingsView {
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

#endif
