//
//  OrchestratorOverviewSections.swift
//  Thea
//
//  Overview and Agent Pool UI sections for OrchestratorSettingsView
//  Extracted from OrchestratorSettingsView.swift for better code organization
//

import SwiftUI

#if os(macOS)
// MARK: - Orchestrator Overview

extension OrchestratorSettingsView {
    var orchestratorOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                overviewCard(
                    title: "Status",
                    value: config.orchestratorEnabled ? "Active" : "Disabled",
                    icon: config.orchestratorEnabled ? "checkmark.circle.fill" : "xmark.circle",
                    color: config.orchestratorEnabled ? .theaSuccess : .gray
                )

                overviewCard(
                    title: "Model Preference",
                    value: config.localModelPreference.rawValue,
                    icon: preferenceIcon(config.localModelPreference),
                    color: .theaInfo
                )

                overviewCard(
                    title: "Parallel Agents",
                    value: "\(config.maxParallelAgents)",
                    icon: "person.3.fill",
                    color: .purple
                )

                overviewCard(
                    title: "Success Rate",
                    value: String(format: "%.0f%%", executionStats.successRate * 100),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            }
        }
    }

    func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    func preferenceIcon(_ preference: OrchestratorConfiguration.LocalModelPreference) -> String {
        switch preference {
        case .always: "cpu"
        case .prefer: "cpu.fill"
        case .balanced: "scale.3d"
        case .cloudFirst: "cloud.fill"
        }
    }
}

// MARK: - Agent Pool Section

extension OrchestratorSettingsView {
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
}
#endif
