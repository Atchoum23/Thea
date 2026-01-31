// AutonomousTaskSettingsView.swift
// Comprehensive UI for configuring autonomous tasks with multiple triggers and actions

import SwiftUI

struct AutonomousTaskSettingsView: View {
    @State private var executor = AutonomousTaskExecutor.shared
    @State private var showingNewTaskSheet = false
    @State private var showingEditTaskSheet: AutonomousTask?
    @State private var showingDeleteConfirmation = false
    @State private var taskToDelete: AutonomousTask?

    var body: some View {
        Form {
            globalSettingsSection
            registeredTasksSection
            quickTemplatesSection
            executionHistorySection
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .sheet(isPresented: $showingNewTaskSheet) {
            TaskEditorSheet(task: nil) { newTask in
                executor.registerTask(newTask)
            }
        }
        .sheet(item: $showingEditTaskSheet) { task in
            TaskEditorSheet(task: task) { updatedTask in
                executor.unregisterTask(id: task.id)
                executor.registerTask(updatedTask)
            }
        }
        .confirmationDialog(
            "Delete Task",
            isPresented: $showingDeleteConfirmation,
            presenting: taskToDelete
        ) { task in
            Button("Delete", role: .destructive) {
                executor.unregisterTask(id: task.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text("Delete '\(task.name)'? This cannot be undone.")
        }
    }

    // MARK: - Global Settings Section

    private var globalSettingsSection: some View {
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

    // MARK: - Registered Tasks Section

    private var registeredTasksSection: some View {
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

    private func taskRow(_ task: AutonomousTask) -> some View {
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
                        .background(Color.blue.opacity(0.2))
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

    // MARK: - Quick Templates Section

    private var quickTemplatesSection: some View {
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

    private func templateCard(icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
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

    // MARK: - Execution History Section

    private var executionHistorySection: some View {
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

    private func statusIcon(_ status: AutoExecutionStatus) -> String {
        switch status {
        case .running: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }

    private func statusColor(_ status: AutoExecutionStatus) -> Color {
        switch status {
        case .running: .blue
        case .completed: .green
        case .failed: .red
        case .cancelled: .orange
        }
    }

    // MARK: - Template Creation

    private func createAutoReplyTemplate() {
        let task = AutonomousTaskExecutor.createAutoReplyTask(
            appBundleId: "net.whatsapp.WhatsApp",
            appName: "WhatsApp",
            replyMessage: "I'm currently unavailable. I'll get back to you soon!",
            whenFocusModeActive: true,
            whenUserAway: true
        )
        executor.registerTask(task)
    }

    private func createNightModeTemplate() {
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

    private func createLowBatteryTemplate() {
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

    private func createDailyDigestTemplate() {
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

    private func createAppMonitorTemplate() {
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

// MARK: - Task Editor Sheet

struct TaskEditorSheet: View {
    let existingTask: AutonomousTask?
    let onSave: (AutonomousTask) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isEnabled = true
    @State private var isDestructive = false
    @State private var conditionLogic: ConditionLogic = .all
    @State private var conditions: [TaskCondition] = []
    @State private var actions: [AutoTaskAction] = []

    @State private var showingAddCondition = false
    @State private var showingAddAction = false

    init(task: AutonomousTask?, onSave: @escaping (AutonomousTask) -> Void) {
        self.existingTask = task
        self.onSave = onSave

        if let task {
            _name = State(initialValue: task.name)
            _description = State(initialValue: task.description)
            _isEnabled = State(initialValue: task.isEnabled)
            _isDestructive = State(initialValue: task.isDestructive)
            _conditionLogic = State(initialValue: task.conditionLogic)
            _conditions = State(initialValue: task.triggerConditions)
            _actions = State(initialValue: task.actions)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                conditionsSection
                actionsSection
                optionsSection
            }
            .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(name.isEmpty || conditions.isEmpty || actions.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddCondition) {
                ConditionPickerSheet { condition in
                    conditions.append(condition)
                }
            }
            .sheet(isPresented: $showingAddAction) {
                ActionPickerSheet { action in
                    actions.append(action)
                }
            }
        }
        #if os(macOS)
        .frame(width: 550, height: 650)
        #endif
    }

    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Task Name", text: $name)
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var conditionsSection: some View {
        Section {
            if conditions.isEmpty {
                Text("No conditions added")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(conditions.enumerated()), id: \.offset) { index, condition in
                    conditionRow(condition, at: index)
                }
                .onDelete { indexSet in
                    conditions.remove(atOffsets: indexSet)
                }
            }

            Button {
                showingAddCondition = true
            } label: {
                Label("Add Condition", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Trigger Conditions")
                Spacer()
                Picker("Logic", selection: $conditionLogic) {
                    Text("ALL").tag(ConditionLogic.all)
                    Text("ANY").tag(ConditionLogic.any)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        } footer: {
            Text(conditionLogic == .all
                 ? "Task triggers when ALL conditions are met"
                 : "Task triggers when ANY condition is met")
                .font(.caption)
        }
    }

    private func conditionRow(_ condition: TaskCondition, at index: Int) -> some View {
        HStack {
            Image(systemName: conditionIcon(condition))
                .foregroundStyle(.blue)

            Text(conditionDescription(condition))
                .font(.subheadline)

            Spacer()

            Button {
                conditions.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var actionsSection: some View {
        Section {
            if actions.isEmpty {
                Text("No actions added")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                    actionRow(action, at: index)
                }
                .onDelete { indexSet in
                    actions.remove(atOffsets: indexSet)
                }
            }

            Button {
                showingAddAction = true
            } label: {
                Label("Add Action", systemImage: "plus.circle")
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("Actions execute in order when conditions are met")
                .font(.caption)
        }
    }

    private func actionRow(_ action: AutoTaskAction, at index: Int) -> some View {
        HStack {
            Image(systemName: actionIcon(action))
                .foregroundStyle(.green)

            Text(actionDescription(action))
                .font(.subheadline)

            Spacer()

            Button {
                actions.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Enabled", isOn: $isEnabled)
            Toggle("Mark as Destructive", isOn: $isDestructive)

            if isDestructive {
                Text("Destructive tasks require user approval before execution")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func saveTask() {
        let task = AutonomousTask(
            id: existingTask?.id ?? UUID(),
            name: name,
            description: description,
            triggerConditions: conditions,
            conditionLogic: conditionLogic,
            actions: actions,
            priority: .normal,
            isEnabled: isEnabled,
            isDestructive: isDestructive
        )
        onSave(task)
        dismiss()
    }

    // MARK: - Helper Methods

    private func conditionIcon(_ condition: TaskCondition) -> String {
        switch condition {
        case .scheduled: "clock"
        case .focusModeActive: "moon.fill"
        case .userAway: "person.slash"
        case .appNotification: "app.badge"
        case .appRunning: "app"
        case .appNotRunning: "app.dashed"
        case .batteryLevel: "battery.25"
        case .deviceLocked: "lock.fill"
        case .networkConnected: "wifi"
        case .timeRange: "clock.arrow.2.circlepath"
        case .custom: "gearshape"
        }
    }

    private func conditionDescription(_ condition: TaskCondition) -> String {
        switch condition {
        case .scheduled(let schedule):
            switch schedule {
            case .daily(let hour, let minute):
                "Daily at \(String(format: "%02d:%02d", hour, minute))"
            case .weekly(let weekday, let hour, let minute):
                "Weekly on day \(weekday) at \(String(format: "%02d:%02d", hour, minute))"
            case .interval(let seconds):
                "Every \(Int(seconds / 60)) minutes"
            }
        case .focusModeActive:
            "Focus mode is active"
        case .userAway(let minutes):
            "User away for \(minutes) minutes"
        case .appNotification(let bundleId):
            "Notification from \(bundleId.components(separatedBy: ".").last ?? bundleId)"
        case .appRunning(let bundleId):
            "\(bundleId.components(separatedBy: ".").last ?? bundleId) is running"
        case .appNotRunning(let bundleId):
            "\(bundleId.components(separatedBy: ".").last ?? bundleId) is not running"
        case .batteryLevel(let below):
            "Battery below \(below)%"
        case .deviceLocked:
            "Device is locked"
        case .networkConnected(let type):
            "Network: \(type.rawValue)"
        case .timeRange(let start, let end):
            "Between \(start.hour ?? 0):00 and \(end.hour ?? 0):00"
        case .custom(let id):
            "Custom: \(id)"
        }
    }

    private func actionIcon(_ action: AutoTaskAction) -> String {
        switch action {
        case .sendReply: "message"
        case .runShortcut: "shortcuts"
        case .executeAppleScript: "applescript"
        case .sendNotification: "bell"
        case .openApp: "app"
        case .openURL: "link"
        case .lockScreen: "lock"
        case .custom: "gearshape"
        }
    }

    private func actionDescription(_ action: AutoTaskAction) -> String {
        switch action {
        case .sendReply(let bundleId, let message):
            "Reply to \(bundleId.components(separatedBy: ".").last ?? bundleId): \"\(message.prefix(30))...\""
        case .runShortcut(let name):
            "Run shortcut: \(name)"
        case .executeAppleScript(let script):
            "AppleScript: \(script.prefix(30))..."
        case .sendNotification(let title, _):
            "Notification: \(title)"
        case .openApp(let bundleId):
            "Open \(bundleId.components(separatedBy: ".").last ?? bundleId)"
        case .openURL(let url):
            "Open URL: \(url.absoluteString.prefix(30))..."
        case .lockScreen:
            "Lock screen"
        case .custom(let id):
            "Custom: \(id)"
        }
    }
}

// MARK: - Condition Picker Sheet

struct ConditionPickerSheet: View {
    let onSelect: (TaskCondition) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ConditionType = .focusMode
    @State private var scheduleHour = 9
    @State private var scheduleMinute = 0
    @State private var awayMinutes = 5
    @State private var batteryThreshold = 20
    @State private var appBundleId = ""
    @State private var networkType: NetworkType = .any

    enum ConditionType: String, CaseIterable {
        case focusMode = "Focus Mode Active"
        case userAway = "User Away"
        case deviceLocked = "Device Locked"
        case dailySchedule = "Daily Schedule"
        case batteryLevel = "Battery Level"
        case appRunning = "App Running"
        case networkConnected = "Network Connected"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Condition Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ConditionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Configuration") {
                    conditionConfiguration
                }
            }
            .navigationTitle("Add Condition")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCondition()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 400)
        #endif
    }

    @ViewBuilder
    private var conditionConfiguration: some View {
        switch selectedType {
        case .focusMode:
            Text("Triggers when any Focus mode is active")
                .foregroundStyle(.secondary)

        case .userAway:
            Stepper("Minutes away: \(awayMinutes)", value: $awayMinutes, in: 1...60)

        case .deviceLocked:
            Text("Triggers when device screen is locked")
                .foregroundStyle(.secondary)

        case .dailySchedule:
            HStack {
                Picker("Hour", selection: $scheduleHour) {
                    ForEach(0..<24, id: \.self) { Text("\($0)").tag($0) }
                }
                .frame(width: 80)
                Text(":")
                Picker("Minute", selection: $scheduleMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                .frame(width: 80)
            }

        case .batteryLevel:
            Stepper("Below \(batteryThreshold)%", value: $batteryThreshold, in: 5...50, step: 5)

        case .appRunning:
            TextField("Bundle ID (e.g., com.apple.mail)", text: $appBundleId)

        case .networkConnected:
            Picker("Network Type", selection: $networkType) {
                Text("Any").tag(NetworkType.any)
                Text("WiFi").tag(NetworkType.wifi)
                Text("Cellular").tag(NetworkType.cellular)
            }
        }
    }

    private func addCondition() {
        let condition: TaskCondition
        switch selectedType {
        case .focusMode:
            condition = .focusModeActive
        case .userAway:
            condition = .userAway(durationMinutes: awayMinutes)
        case .deviceLocked:
            condition = .deviceLocked
        case .dailySchedule:
            condition = .scheduled(.daily(hour: scheduleHour, minute: scheduleMinute))
        case .batteryLevel:
            condition = .batteryLevel(below: batteryThreshold)
        case .appRunning:
            condition = .appRunning(bundleId: appBundleId.isEmpty ? "com.apple.mail" : appBundleId)
        case .networkConnected:
            condition = .networkConnected(type: networkType)
        }
        onSelect(condition)
        dismiss()
    }
}

// MARK: - Action Picker Sheet

struct ActionPickerSheet: View {
    let onSelect: (AutoTaskAction) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ActionType = .notification
    @State private var notificationTitle = ""
    @State private var notificationBody = ""
    @State private var shortcutName = ""
    @State private var appBundleId = ""
    @State private var urlString = ""
    @State private var replyMessage = ""
    @State private var appleScript = ""

    enum ActionType: String, CaseIterable {
        case notification = "Send Notification"
        case runShortcut = "Run Shortcut"
        case openApp = "Open App"
        case openURL = "Open URL"
        case lockScreen = "Lock Screen"
        case sendReply = "Send Reply"
        case appleScript = "AppleScript"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Configuration") {
                    actionConfiguration
                }
            }
            .navigationTitle("Add Action")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAction()
                    }
                    .disabled(!isValid)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 450)
        #endif
    }

    @ViewBuilder
    private var actionConfiguration: some View {
        switch selectedType {
        case .notification:
            TextField("Title", text: $notificationTitle)
            TextField("Body", text: $notificationBody, axis: .vertical)
                .lineLimit(2...4)

        case .runShortcut:
            TextField("Shortcut Name", text: $shortcutName)

        case .openApp:
            TextField("Bundle ID (e.g., com.apple.mail)", text: $appBundleId)

        case .openURL:
            TextField("URL", text: $urlString)

        case .lockScreen:
            Text("Locks the screen immediately")
                .foregroundStyle(.secondary)

        case .sendReply:
            TextField("App Bundle ID", text: $appBundleId)
            TextField("Reply Message", text: $replyMessage, axis: .vertical)
                .lineLimit(2...4)

        case .appleScript:
            TextField("AppleScript", text: $appleScript, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(.body, design: .monospaced))
        }
    }

    private var isValid: Bool {
        switch selectedType {
        case .notification:
            !notificationTitle.isEmpty
        case .runShortcut:
            !shortcutName.isEmpty
        case .openApp:
            !appBundleId.isEmpty
        case .openURL:
            !urlString.isEmpty
        case .lockScreen:
            true
        case .sendReply:
            !appBundleId.isEmpty && !replyMessage.isEmpty
        case .appleScript:
            !appleScript.isEmpty
        }
    }

    private func addAction() {
        let action: AutoTaskAction
        switch selectedType {
        case .notification:
            action = .sendNotification(title: notificationTitle, body: notificationBody)
        case .runShortcut:
            action = .runShortcut(name: shortcutName)
        case .openApp:
            action = .openApp(bundleId: appBundleId)
        case .openURL:
            action = .openURL(url: URL(string: urlString) ?? URL(string: "https://example.com")!)
        case .lockScreen:
            action = .lockScreen
        case .sendReply:
            action = .sendReply(appBundleId: appBundleId, message: replyMessage)
        case .appleScript:
            action = .executeAppleScript(script: appleScript)
        }
        onSelect(action)
        dismiss()
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    AutonomousTaskSettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        AutonomousTaskSettingsView()
            .navigationTitle("Autonomous Tasks")
    }
}
#endif
