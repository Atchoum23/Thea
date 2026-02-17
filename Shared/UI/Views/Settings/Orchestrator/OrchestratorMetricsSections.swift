//
//  OrchestratorMetricsSections.swift
//  Thea
//
//  Performance metrics and execution history UI components for Orchestrator Settings
//  Extracted from OrchestratorSettingsView.swift for better code organization
//

import SwiftUI

#if os(macOS)

// MARK: - Performance Metrics Section

extension OrchestratorSettingsView {
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
                            .foregroundStyle(executionStats.avgResponseTime < 2.0 ? Color.theaSuccess : executionStats.avgResponseTime < 5.0 ? Color.theaWarning : Color.theaError)
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
                            .foregroundStyle(executionStats.successRate > 0.95 ? Color.theaSuccess : executionStats.successRate > 0.8 ? Color.theaWarning : Color.theaError)
                    }

                    Spacer()

                    // Success/Failure breakdown
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(executionStats.successfulTasks) successful")
                            .font(.caption)
                            .foregroundStyle(Color.theaSuccess)

                        Text("\(executionStats.failedTasks) failed")
                            .font(.caption)
                            .foregroundStyle(Color.theaError)
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
                                    .fill(model.hasPrefix("local-") ? Color.theaSuccess : Color.theaInfo)
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
                    .fill(time < 2.0 ? Color.theaSuccess : time < 5.0 ? Color.theaWarning : Color.theaError)
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
}

// MARK: - Execution History Section

extension OrchestratorSettingsView {
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
                .foregroundStyle(execution.success ? Color.theaSuccess : Color.theaError)

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
                    .background(Color.theaInfo.opacity(0.2))
                    .cornerRadius(4)

                Text("\(String(format: "%.2f", execution.responseTime))s")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#endif
