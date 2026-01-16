import SwiftUI

/// View for managing the Cowork task queue
struct CoworkQueueView: View {
    @State private var manager = CoworkManager.shared
    @State private var newTaskInstruction = ""
    @State private var newTaskPriority: CoworkTask.TaskPriority = .normal
    @State private var showingAddTask = false
    @State private var selectedFilter: QueueFilter = .all

    enum QueueFilter: String, CaseIterable {
        case all = "All"
        case queued = "Queued"
        case inProgress = "In Progress"
        case completed = "Completed"
        case failed = "Failed"

        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .queued: return "clock"
            case .inProgress: return "play.circle"
            case .completed: return "checkmark.circle"
            case .failed: return "xmark.circle"
            }
        }
    }

    private var filteredTasks: [CoworkTask] {
        guard let session = manager.currentSession else { return [] }

        switch selectedFilter {
        case .all:
            return session.taskQueue.tasks
        case .queued:
            return session.taskQueue.queuedTasks
        case .inProgress:
            return session.taskQueue.inProgressTasks
        case .completed:
            return session.taskQueue.completedTasks
        case .failed:
            return session.taskQueue.failedTasks
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Filter tabs
            filterTabs

            Divider()

            // Task list
            if filteredTasks.isEmpty {
                emptyStateView
            } else {
                taskList
            }

            Divider()

            // Add task area
            addTaskArea
        }
        .sheet(isPresented: $showingAddTask) {
            addTaskSheet
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            if let session = manager.currentSession {
                // Queue stats
                HStack(spacing: 16) {
                    statBadge(label: "Queued", value: session.taskQueue.pendingCount, color: .blue)
                    statBadge(label: "Active", value: session.taskQueue.activeCount, color: .green)
                    statBadge(label: "Completed", value: session.taskQueue.completedTasks.count, color: .secondary)
                }

                Spacer()

                // Queue controls
                if session.taskQueue.isProcessing {
                    Button {
                        session.taskQueue.pause()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                } else if !session.taskQueue.queuedTasks.isEmpty {
                    Button {
                        Task {
                            await manager.processQueue()
                        }
                    } label: {
                        Label("Process Queue", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !session.taskQueue.tasks.isEmpty {
                    Menu {
                        Button {
                            session.taskQueue.clearCompleted()
                        } label: {
                            Label("Clear Completed", systemImage: "trash")
                        }

                        Button(role: .destructive) {
                            session.taskQueue.cancelAll()
                        } label: {
                            Label("Cancel All", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .padding()
    }

    private func statBadge(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QueueFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                            Text(filter.rawValue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFilter == filter ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            ForEach(filteredTasks) { task in
                taskRow(task)
            }
            .onMove { _, _ in
                // Reorder tasks
            }
        }
        .listStyle(.inset)
    }

    private func taskRow(_ task: CoworkTask) -> some View {
        HStack(spacing: 12) {
            // Priority indicator
            priorityIndicator(task.priority)

            // Status icon
            statusIcon(task.status)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.instruction)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(task.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(colorForStatus(task.status))

                    if let duration = task.duration {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(task.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Actions
            if task.isActive {
                Menu {
                    ForEach(CoworkTask.TaskPriority.allCases, id: \.self) { priority in
                        Button {
                            manager.currentSession?.taskQueue.changePriority(task.id, to: priority)
                        } label: {
                            Label(priority.displayName, systemImage: priority.icon)
                        }
                    }

                    Divider()

                    Button {
                        manager.currentSession?.taskQueue.moveToFront(task.id)
                    } label: {
                        Label("Move to Front", systemImage: "arrow.up.to.line")
                    }

                    Divider()

                    Button(role: .destructive) {
                        manager.currentSession?.taskQueue.cancelTask(task.id)
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func priorityIndicator(_ priority: CoworkTask.TaskPriority) -> some View {
        Rectangle()
            .fill(colorForPriority(priority))
            .frame(width: 4, height: 40)
            .cornerRadius(2)
    }

    @ViewBuilder
    private func statusIcon(_ status: CoworkTask.TaskStatus) -> some View {
        Group {
            switch status {
            case .inProgress:
                ProgressView()
                    .scaleEffect(0.7)
            default:
                Image(systemName: status.icon)
                    .foregroundStyle(colorForStatus(status))
            }
        }
        .frame(width: 20)
    }

    // MARK: - Add Task Area

    private var addTaskArea: some View {
        HStack(spacing: 12) {
            TextField("Add a task to the queue...", text: $newTaskInstruction)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    addTask()
                }

            Picker("Priority", selection: $newTaskPriority) {
                ForEach(CoworkTask.TaskPriority.allCases, id: \.self) { priority in
                    Label(priority.displayName, systemImage: priority.icon).tag(priority)
                }
            }
            .frame(width: 120)

            Button {
                addTask()
            } label: {
                Label("Add", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(newTaskInstruction.isEmpty)
        }
        .padding()
    }

    // MARK: - Add Task Sheet

    private var addTaskSheet: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextEditor(text: $newTaskInstruction)
                        .frame(minHeight: 100)
                }

                Section("Priority") {
                    Picker("Priority", selection: $newTaskPriority) {
                        ForEach(CoworkTask.TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                    .foregroundStyle(colorForPriority(priority))
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddTask = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTask()
                        showingAddTask = false
                    }
                    .disabled(newTaskInstruction.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 400)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Tasks", systemImage: "tray")
        } description: {
            Text("Add tasks to the queue to process them in sequence")
        } actions: {
            Button {
                showingAddTask = true
            } label: {
                Label("Add Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func addTask() {
        guard !newTaskInstruction.isEmpty else { return }
        manager.queueTask(newTaskInstruction, priority: newTaskPriority)
        newTaskInstruction = ""
        newTaskPriority = .normal
    }

    // MARK: - Helpers

    private func colorForPriority(_ priority: CoworkTask.TaskPriority) -> Color {
        switch priority {
        case .low: return .secondary
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private func colorForStatus(_ status: CoworkTask.TaskStatus) -> Color {
        switch status {
        case .queued: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

#Preview {
    CoworkQueueView()
        .frame(width: 600, height: 500)
}
