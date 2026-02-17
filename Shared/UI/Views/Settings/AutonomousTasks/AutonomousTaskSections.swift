//
//  AutonomousTaskSections.swift
//  Thea
//
//  UI sections for AutonomousTaskSettingsView
//  Extracted from AutonomousTaskSettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Global Settings Section

extension AutonomousTaskSettingsView {
    var globalSettingsSection: some View {
        Section("Autonomous Execution") {
            Toggle("Enable Autonomous Tasks", isOn: Binding(
                get: { executor.configuration.enableAutonomousExecution },
                set: { newValue in
                    var config = executor.configuration
                    config.enableAutonomousExecution = newValue
                    executor.updateConfiguration(config)
                }
            ))

            Toggle("Execute While Device Locked", isOn: Binding(
                get: { executor.configuration.enableWhileDeviceLocked },
                set: { newValue in
                    var config = executor.configuration
                    config.enableWhileDeviceLocked = newValue
                    executor.updateConfiguration(config)
                }
            ))

            Toggle("Execute While User Away", isOn: Binding(
                get: { executor.configuration.enableWhileUserAway },
                set: { newValue in
                    var config = executor.configuration
                    config.enableWhileUserAway = newValue
                    executor.updateConfiguration(config)
                }
            ))

            Stepper(
                "Max Concurrent Tasks: \(executor.configuration.maxConcurrentTasks)",
                value: Binding(
                    get: { executor.configuration.maxConcurrentTasks },
                    set: { newValue in
                        var config = executor.configuration
                        config.maxConcurrentTasks = newValue
                        executor.updateConfiguration(config)
                    }
                ),
                in: 1...10
            )

            Toggle("Require Approval for Destructive Actions", isOn: Binding(
                get: { executor.configuration.requireUserApprovalForDestructive },
                set: { newValue in
                    var config = executor.configuration
                    config.requireUserApprovalForDestructive = newValue
                    executor.updateConfiguration(config)
                }
            ))

            Text("Autonomous tasks run in the background based on conditions you define.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Registered Tasks Section

extension AutonomousTaskSettingsView {
    var registeredTasksSection: some View {
        Section {
            if executor.registeredTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No Autonomous Tasks")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Create tasks that run automatically based on conditions like Focus mode, time of day, or app activity.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(executor.registeredTasks) { task in
                    taskRow(task)
                }
            }
        } header: {
            HStack {
                Text("Registered Tasks")
                Spacer()
                Button {
                    showingNewTaskSheet = true
                } label: {
                    Label("New Task", systemImage: "plus.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    func taskRow(_ task: AutonomousTask) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: task.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isEnabled ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.name)
                        .font(.headline)

                    if task.isDestructive {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(task.triggerConditions.count) triggers", systemImage: "bolt")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Label("\(task.actions.count) actions", systemImage: "play.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(task.conditionLogic == .all ? "ALL" : "ANY")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.theaInfo.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            Spacer()

            Menu {
                Button {
                    executor.setTaskEnabled(task.id, enabled: !task.isEnabled)
                } label: {
                    Label(task.isEnabled ? "Disable" : "Enable",
                          systemImage: task.isEnabled ? "pause.circle" : "play.circle")
                }

                Button {
                    showingEditTaskSheet = task
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    taskToDelete = task
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Quick Templates Section

extension AutonomousTaskSettingsView {
    var quickTemplatesSection: some View {
        Section("Quick Templates") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pre-built task templates for common scenarios")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        templateCard(
                            icon: "message.badge",
                            title: "Auto-Reply",
                            description: "Reply to messages when in Focus mode"
                        ) {
                            createAutoReplyTemplate()
                        }

                        templateCard(
                            icon: "moon.fill",
                            title: "Night Mode",
                            description: "Actions when device locks at night"
                        ) {
                            createNightModeTemplate()
                        }

                        templateCard(
                            icon: "battery.25",
                            title: "Low Battery",
                            description: "Actions when battery is low"
                        ) {
                            createLowBatteryTemplate()
                        }

                        templateCard(
                            icon: "clock",
                            title: "Daily Digest",
                            description: "Morning summary notification"
                        ) {
                            createDailyDigestTemplate()
                        }

                        templateCard(
                            icon: "app.badge",
                            title: "App Monitor",
                            description: "Actions when apps launch/quit"
                        ) {
                            createAppMonitorTemplate()
                        }
                    }
                }
            }
        }
    }

    func templateCard(icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)

            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button("Add") {
                action()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(width: 140, height: 140)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Execution History Section

extension AutonomousTaskSettingsView {
    var executionHistorySection: some View {
        Section("Recent Executions") {
            if executor.executionHistory.isEmpty {
                Text("No executions yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(executor.executionHistory.suffix(10).reversed()) { execution in
                    HStack {
                        Image(systemName: statusIcon(execution.status))
                            .foregroundStyle(statusColor(execution.status))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(execution.taskName)
                                .font(.caption)

                            Text(execution.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(execution.status.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    func statusIcon(_ status: AutoExecutionStatus) -> String {
        switch status {
        case .running: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }

    func statusColor(_ status: AutoExecutionStatus) -> Color {
        switch status {
        case .running: .blue
        case .completed: .green
        case .failed: .red
        case .cancelled: .orange
        }
    }
}

// MARK: - Template Creation

extension AutonomousTaskSettingsView {
    func createAutoReplyTemplate() {
        let task = AutonomousTaskExecutor.createAutoReplyTask(
            appBundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            replyMessage: "I'm currently unavailable. I'll get back to you soon!",
            whenFocusModeActive: true,
            whenUserAway: true
        )
        executor.registerTask(task)
    }

    func createNightModeTemplate() {
        let task = AutonomousTask(
            name: "Night Mode Actions",
            description: "Run actions when device locks after 10 PM",
            triggerConditions: [
                .deviceLocked,
                .timeRange(
                    start: DateComponents(hour: 22, minute: 0),
                    end: DateComponents(hour: 6, minute: 0)
                )
            ],
            conditionLogic: .all,
            actions: [
                .sendNotification(title: "Good Night", body: "Device locked for the night")
            ]
        )
        executor.registerTask(task)
    }

    func createLowBatteryTemplate() {
        let task = AutonomousTask(
            name: "Low Battery Alert",
            description: "Notify and take action when battery is below 20%",
            triggerConditions: [
                .batteryLevel(below: 20)
            ],
            conditionLogic: .all,
            actions: [
                .sendNotification(title: "Low Battery", body: "Battery below 20%. Consider charging.")
            ]
        )
        executor.registerTask(task)
    }

    func createDailyDigestTemplate() {
        let task = AutonomousTaskExecutor.createScheduledTask(
            name: "Morning Digest",
            description: "Daily morning summary at 8 AM",
            schedule: .daily(hour: 8, minute: 0),
            actions: [
                .sendNotification(title: "Good Morning", body: "Your daily summary is ready")
            ]
        )
        executor.registerTask(task)
    }

    func createAppMonitorTemplate() {
        let task = AutonomousTask(
            name: "App Activity Monitor",
            description: "Track when specific apps are running",
            triggerConditions: [
                .appRunning(bundleId: "com.apple.mail")
            ],
            conditionLogic: .any,
            actions: [
                .sendNotification(title: "App Active", body: "Mail app is now running")
            ]
        )
        executor.registerTask(task)
    }
}
