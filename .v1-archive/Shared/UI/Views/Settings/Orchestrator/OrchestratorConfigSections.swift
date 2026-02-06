//
//  OrchestratorConfigSections.swift
//  Thea
//
//  Configuration sections for OrchestratorSettingsView
//  Includes Enable, Model Preference, and Benchmark sections
//

import SwiftUI

#if os(macOS)
// MARK: - Enable Section

extension OrchestratorSettingsView {
    var enableSection: some View {
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
}

// MARK: - Model Preference Section

extension OrchestratorSettingsView {
    var modelPreferenceSection: some View {
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

    func preferenceDetail(icon: String, title: String, description: String) -> some View {
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
}

// MARK: - Benchmark Section

extension OrchestratorSettingsView {
    var benchmarkSection: some View {
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

    func benchmarkStat(icon: String, title: String, value: String) -> some View {
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

    func refreshBenchmarks() {
        isRefreshingBenchmarks = true
        Task {
            await benchmarkService.updateBenchmarks()
            isRefreshingBenchmarks = false
        }
    }
}
#endif
