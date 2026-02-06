//
//  TaskEditorSheet.swift
//  Thea
//
//  Task editor sheet for creating/editing autonomous tasks
//  Extracted from AutonomousTaskSettingsView.swift for better code organization
//

import SwiftUI

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
