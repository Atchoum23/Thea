// AutomationSettingsView.swift
// Comprehensive automation and workflow settings for Thea

import SwiftUI

struct AutomationSettingsView: View {
    @State private var config = AppConfiguration.shared.executionMode
    @State private var settingsManager = SettingsManager.shared
    @State private var showingResetConfirmation = false
    @State private var showingWorkflowTemplates = false

    var body: some View {
        Form {
            // MARK: - Execution Mode
            Section("Execution Mode") {
                executionModeSection
            }

            // MARK: - Approval Settings
            Section("Approval Requirements") {
                approvalSettings
            }

            // MARK: - Autonomous Execution
            Section("Autonomous Execution") {
                autonomousSettings
            }

            // MARK: - Self-Execution Capabilities
            Section("Self-Execution Capabilities") {
                selfExecutionCapabilities
            }

            // MARK: - Safety & Rollback
            Section("Safety & Rollback") {
                safetySettings
            }

            // MARK: - Workflow Templates
            Section("Workflow Templates") {
                workflowTemplatesSection
            }

            // MARK: - Performance
            Section("Performance") {
                performanceSettings
            }

            // MARK: - Reset
            Section {
                Button("Reset to Safe Defaults", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .onChange(of: config) { _, newValue in
            AppConfiguration.shared.executionMode = newValue
        }
        .alert("Reset to Safe Defaults?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetToSafeDefaults()
            }
        } message: {
            Text("This will reset all automation settings to the safest configuration with manual approval for all operations.")
        }
        .sheet(isPresented: $showingWorkflowTemplates) {
            workflowTemplatesSheet
        }
    }

    // MARK: - Execution Mode Section

    private var executionModeSection: some View {
        Group {
            Picker("Execution Mode", selection: $config.mode) {
                ForEach(ExecutionMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    modeIcon(for: config.mode)
                        .font(.title2)
                        .foregroundStyle(modeColor(for: config.mode))

                    Text(config.mode.displayName)
                        .font(.headline)
                }

                Text(config.mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            if config.mode == .aggressive {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Aggressive mode allows AI to operate with minimal interruption. Use with caution.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func modeIcon(for mode: ExecutionMode) -> some View {
        switch mode {
        case .safe:
            Image(systemName: "shield.checkered")
        case .normal:
            Image(systemName: "checkmark.shield")
        case .aggressive:
            Image(systemName: "bolt.shield")
        }
    }

    private func modeColor(for mode: ExecutionMode) -> Color {
        switch mode {
        case .safe: .green
        case .normal: .blue
        case .aggressive: .orange
        }
    }

    // MARK: - Approval Settings

    private var approvalSettings: some View {
        Group {
            Toggle("File Edits", isOn: $config.requireApprovalForFileEdits)
            Toggle("Terminal Commands", isOn: $config.requireApprovalForTerminalCommands)
            Toggle("Browser Actions", isOn: $config.requireApprovalForBrowserActions)
            Toggle("System Automation", isOn: $config.requireApprovalForSystemAutomation)

            Divider()

            Toggle("Auto-Approve Read Operations", isOn: $config.autoApproveReadOperations)

            Text("When enabled, read-only operations (file reads, searches) don't require approval.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Show Plan Before Execution", isOn: $config.showPlanBeforeExecution)

            Text("When enabled, Thea will present a plan for approval before executing multi-step tasks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Autonomous Settings

    private var autonomousSettings: some View {
        Group {
            Toggle("Allow Autonomous Continuation", isOn: $config.allowAutonomousContinuation)

            Text("When enabled, Thea can continue working on approved tasks without waiting for approval between steps.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if config.allowAutonomousContinuation {
                Stepper("Max Autonomous Steps: \(config.maxAutonomousSteps)", value: $config.maxAutonomousSteps, in: 10...200, step: 10)

                Text("Thea will pause and ask for confirmation after this many steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Stepper("Execution Timeout: \(config.executionTimeoutMinutes) min", value: $config.executionTimeoutMinutes, in: 5...180, step: 5)

            Text("Maximum time for a single task execution before automatic pause.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Self-Execution Capabilities

    private var selfExecutionCapabilities: some View {
        Group {
            Toggle("Allow File Creation", isOn: $settingsManager.allowFileCreation)

            Toggle("Allow File Editing", isOn: $settingsManager.allowFileEditing)

            Toggle("Allow Code Execution", isOn: $settingsManager.allowCodeExecution)

            Toggle("Allow External API Calls", isOn: $settingsManager.allowExternalAPICalls)

            Text("These capabilities determine what Thea can do autonomously. Disable capabilities you don't need for added security.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Safety Settings

    private var safetySettings: some View {
        Group {
            Toggle("Require Destructive Operation Approval", isOn: $settingsManager.requireDestructiveApproval)

            Text("Always require approval for operations that delete, overwrite, or make irreversible changes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Enable Rollback", isOn: $settingsManager.enableRollback)

            Text("When enabled, Thea can undo changes if something goes wrong.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Create Backups Before Changes", isOn: $settingsManager.createBackups)

            Text("Automatically create backups before modifying files.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Prevent Sleep During Execution", isOn: $settingsManager.preventSleepDuringExecution)

            Text("Keep the system awake while Thea is executing long-running tasks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Workflow Templates Section

    private var workflowTemplatesSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pre-built Workflows")
                        .font(.body)

                    Text("\(WorkflowTemplates.all.count) templates available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingWorkflowTemplates = true
                } label: {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
            }

            Text("Workflow templates provide pre-configured automation patterns for common tasks like code review, research, analysis, and more.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Performance Settings

    private var performanceSettings: some View {
        Group {
            Stepper("Max Concurrent Tasks: \(settingsManager.maxConcurrentTasks)", value: $settingsManager.maxConcurrentTasks, in: 1...10)

            Text("Maximum number of automation tasks that can run simultaneously.")
                .font(.caption)
                .foregroundStyle(.secondary)

            executionModePicker
        }
    }

    private var executionModePicker: some View {
        Picker("Default Execution Mode", selection: $settingsManager.executionMode) {
            Text("Manual").tag("manual")
            Text("Semi-Auto").tag("semi-auto")
            Text("Fully Auto").tag("auto")
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Workflow Templates Sheet

    private var workflowTemplatesSheet: some View {
        NavigationStack {
            List {
                ForEach(WorkflowTemplates.all, id: \.id) { workflow in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workflow.name)
                            .font(.headline)

                        Text(workflow.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Label("\(workflow.nodes.count) nodes", systemImage: "circle.grid.2x2")
                                .font(.caption2)

                            Label(workflow.isActive ? "Active" : "Inactive", systemImage: workflow.isActive ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(workflow.isActive ? .green : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Text("More workflow templates coming soon!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Workflow Templates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingWorkflowTemplates = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 400)
        #endif
    }

    // MARK: - Helper Methods

    private func resetToSafeDefaults() {
        config = ExecutionModeConfiguration()
        config.mode = .safe
        config.requireApprovalForFileEdits = true
        config.requireApprovalForTerminalCommands = true
        config.requireApprovalForBrowserActions = true
        config.requireApprovalForSystemAutomation = true
        config.autoApproveReadOperations = false
        config.showPlanBeforeExecution = true
        config.allowAutonomousContinuation = false

        settingsManager.allowFileCreation = false
        settingsManager.allowFileEditing = false
        settingsManager.allowCodeExecution = false
        settingsManager.allowExternalAPICalls = false
        settingsManager.requireDestructiveApproval = true
        settingsManager.enableRollback = true
        settingsManager.createBackups = true
        settingsManager.executionMode = "manual"

        AppConfiguration.shared.executionMode = config
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    AutomationSettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        AutomationSettingsView()
            .navigationTitle("Automation")
    }
}
#endif
