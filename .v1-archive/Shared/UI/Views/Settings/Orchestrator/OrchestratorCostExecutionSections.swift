//
//  OrchestratorCostExecutionSections.swift
//  Thea
//
//  Cost management, execution settings, and debug UI components for Orchestrator Settings
//  Extracted from OrchestratorSettingsView.swift for better code organization
//

import SwiftUI

#if os(macOS)

// MARK: - Cost Management Section

extension OrchestratorSettingsView {
    var costManagementSection: some View {
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
}

// MARK: - Execution Settings Section

extension OrchestratorSettingsView {
    var executionSettingsSection: some View {
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
}

// MARK: - Debug Section

extension OrchestratorSettingsView {
    var debugSection: some View {
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
}

#endif
