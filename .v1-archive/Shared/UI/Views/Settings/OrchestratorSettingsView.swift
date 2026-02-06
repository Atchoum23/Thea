// OrchestratorSettingsView.swift
// Comprehensive AI orchestration configuration for Thea

import SwiftUI

// MARK: - Orchestrator Settings View

#if os(macOS)
struct OrchestratorSettingsView: View {
    @State var config = OrchestratorConfiguration.load()
    @State var showingSaveConfirmation = false
    @State var benchmarkService = ModelBenchmarkService.shared
    @State var isRefreshingBenchmarks = false
    @State var showingRoutingRuleEditor = false
    @State var showingExecutionHistory = false
    @State var selectedTaskType: String?
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

    // MARK: - Actions

    func saveConfig() {
        config.save()
    }

    func resetToDefaults() {
        config = OrchestratorConfiguration()
        saveConfig()
    }
}

// MARK: - Preview

#Preview {
    OrchestratorSettingsView()
        .frame(width: 700, height: 900)
}
#endif // end os(macOS)
