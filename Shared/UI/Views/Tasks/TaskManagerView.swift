//
//  TaskManagerView.swift
//  Thea
//
//  Native task management UI with priorities, due dates, categories, and completion tracking.
//

import SwiftUI

// MARK: - Task Manager View

struct TaskManagerView: View {
    @ObservedObject private var taskManager = TheaTaskManager.shared
    @State private var showAddTask = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var searchText = ""

    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case upcoming = "Upcoming"
        case overdue = "Overdue"
        case completed = "Completed"
    }

    var body: some View {
        VStack(spacing: 0) {
            taskStatsBar
            Divider()
            filterBar
            taskList
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddTask = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView { title, details, priority, category, dueDate in
                taskManager.addTask(
                    title: title,
                    details: details,
                    priority: priority,
                    category: category,
                    dueDate: dueDate,
                    reminderDate: dueDate
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks")
    }

    // MARK: - Stats Bar

    private var taskStatsBar: some View {
        HStack(spacing: 16) {
            statCard(
                title: "Pending",
                value: "\(taskManager.pendingTasks.count)",
                icon: "circle",
                color: .blue
            )
            statCard(
                title: "Overdue",
                value: "\(taskManager.overdueTasks.count)",
                icon: "exclamationmark.circle.fill",
                color: .red
            )
            statCard(
                title: "Today",
                value: "\(taskManager.tasksCompletedToday)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            statCard(
                title: "Streak",
                value: "\(taskManager.currentStreak)d",
                icon: "flame.fill",
                color: .orange
            )
        }
        .padding()
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.bold())
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases, id: \.rawValue) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedFilter == filter
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        Group {
            if filteredTasks.isEmpty {
                ContentUnavailableView {
                    Label("No Tasks", systemImage: "checkmark.circle")
                } description: {
                    Text("Tap + to add your first task")
                }
            } else {
                List {
                    ForEach(filteredTasks, id: \.id) { task in
                        TaskRow(task: task) {
                            taskManager.toggleCompletion(task)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                taskManager.deleteTask(task)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var filteredTasks: [TheaTask] {
        var result: [TheaTask]
        switch selectedFilter {
        case .all: result = taskManager.pendingTasks
        case .today: result = taskManager.todayTasks
        case .upcoming: result = taskManager.thisWeekTasks
        case .overdue: result = taskManager.overdueTasks
        case .completed: result = taskManager.completedTasks
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.details.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: TheaTask
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    Label(task.priority.displayName, systemImage: task.priority.icon)
                        .font(.caption2)
                        .foregroundStyle(priorityColor)

                    Label(task.category.rawValue, systemImage: task.category.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let dueDate = task.dueDate {
                        Text(dueDate, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }
            }

            Spacer()

            if !task.tags.isEmpty {
                Text(task.tags.first ?? "")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: .gray
        case .medium: .blue
        case .high: .orange
        case .urgent: .red
        }
    }
}

// MARK: - Add Task View

private struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var priority: TheaTaskPriority = .medium
    @State private var category: TheaTaskCategory = .personal
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    let onAdd: (String, String, TheaTaskPriority, TheaTaskCategory, Date?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TheaTaskPriority.allCases, id: \.rawValue) { p in
                            Label(p.displayName, systemImage: p.icon)
                                .tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(TheaTaskCategory.allCases, id: \.rawValue) { c in
                            Label(c.rawValue, systemImage: c.icon)
                                .tag(c)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(title, details, priority, category, hasDueDate ? dueDate : nil)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}
