import SwiftUI

/// Main cognitive/ADHD dashboard view
public struct CognitiveDashboardView: View {
    @State private var viewModel = CognitiveDashboardViewModel()

    public init() {}

    public var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            taskBreakdownTab
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet.rectangle")
                }
                .tag(0)

            pomodoroTimerTab
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
                .tag(1)

            focusForestTab
                .tabItem {
                    Label("Forest", systemImage: "tree")
                }
                .tag(2)

            timelineTab
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(3)
        }
        .navigationTitle("Cognitive Tools")
        .task {
            await viewModel.refreshData()
        }
    }

    // MARK: - Task Breakdown Tab

    private var taskBreakdownTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                taskInputSection

                if let breakdown = viewModel.currentBreakdown {
                    currentBreakdownSection(breakdown)
                }

                if !viewModel.breakdownHistory.isEmpty {
                    breakdownHistorySection
                }

                if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }
            .padding()
        }
    }

    private var taskInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Break Down a Task")
                .font(.headline)

            TextField("Describe your task...", text: $viewModel.taskInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3 ... 6)

            Button(action: {
                Task {
                    await viewModel.breakdownTask()
                }
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Break Down Task")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.taskInput.isEmpty || viewModel.isLoading)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private func currentBreakdownSection(_ breakdown: TaskBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Task Breakdown")
                    .font(.headline)

                Spacer()

                Text(breakdown.difficulty.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: breakdown.difficulty.color).opacity(0.2))
                    .foregroundColor(Color(hex: breakdown.difficulty.color))
                    .cornerRadius(8)
            }

            Text(breakdown.originalTask)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(viewModel.completedSubtasksCount)/\(viewModel.totalSubtasksCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                ProgressView(value: viewModel.breakdownProgress, total: 100)
            }

            Divider()

            // Subtasks
            ForEach(breakdown.subtasks) { subtask in
                SubtaskRow(
                    subtask: subtask
                ) {
                    Task {
                        await viewModel.completeSubtask(
                            breakdownId: breakdown.id,
                            subtaskId: subtask.id
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private var breakdownHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Breakdowns")
                .font(.headline)

            ForEach(viewModel.breakdownHistory.prefix(5)) { breakdown in
                BreakdownHistoryRow(breakdown: breakdown) {
                    viewModel.currentBreakdown = breakdown
                }
            }
        }
    }

    // MARK: - Pomodoro Timer Tab

    private var pomodoroTimerTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let session = viewModel.activePomodoro {
                    activePomodoroSection(session)
                } else {
                    startPomodoroSection
                }

                if let stats = viewModel.pomodoroStats {
                    pomodoroStatsSection(stats)
                }

                if !viewModel.pomodoroHistory.isEmpty {
                    pomodoroHistorySection
                }
            }
            .padding()
        }
    }

    private func activePomodoroSection(_ session: PomodoroSession) -> some View {
        VStack(spacing: 20) {
            Text(session.type.displayName)
                .font(.title2)
                .fontWeight(.bold)

            if let taskName = session.taskName {
                Text(taskName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: viewModel.pomodoroProgress / 100)
                    .stroke(Color(hex: session.type.color), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text(viewModel.pomodoroElapsedTime)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))

                    Text(viewModel.pomodoroTimeRemaining)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding()

            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        await viewModel.endPomodoro(completed: false)
                    }
                }) {
                    Label("Cancel", systemImage: "xmark")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    Task {
                        await viewModel.endPomodoro(completed: true)
                    }
                }) {
                    Label("Complete", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private var startPomodoroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Pomodoro")
                .font(.headline)

            HStack(spacing: 12) {
                PomodoroTypeButton(type: .work) {
                    Task {
                        await viewModel.startPomodoro(type: .work)
                    }
                }

                PomodoroTypeButton(type: .shortBreak) {
                    Task {
                        await viewModel.startPomodoro(type: .shortBreak)
                    }
                }

                PomodoroTypeButton(type: .longBreak) {
                    Task {
                        await viewModel.startPomodoro(type: .longBreak)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private func pomodoroStatsSection(_ stats: PomodoroStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Stats")
                .font(.headline)

            HStack(spacing: 12) {
                PomodoroStatCard(
                    title: "Sessions",
                    value: "\(stats.totalSessions)",
                    color: .theaInfo
                )

                PomodoroStatCard(
                    title: "Completed",
                    value: "\(stats.completedSessions)",
                    color: .theaSuccess
                )

                PomodoroStatCard(
                    title: "Minutes",
                    value: "\(stats.totalMinutes)",
                    color: .theaWarning
                )
            }
        }
    }

    private var pomodoroHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            ForEach(viewModel.pomodoroHistory.prefix(5)) { session in
                PomodoroHistoryRow(session: session)
            }
        }
    }

    // MARK: - Focus Forest Tab

    private var focusForestTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let tree = viewModel.currentTree {
                    currentTreeSection(tree)
                } else {
                    plantTreeSection
                }

                if let forest = viewModel.forest {
                    forestStatsSection(forest)
                }

                if let stats = viewModel.forestStats {
                    detailedForestStatsSection(stats)
                }
            }
            .padding()
        }
    }

    private func currentTreeSection(_ tree: FocusTree) -> some View {
        VStack(spacing: 16) {
            Text("Growing: \(tree.treeType.displayName)")
                .font(.title2)
                .fontWeight(.bold)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)

                Circle()
                    .trim(from: 0, to: viewModel.treeGrowthProgress / 100)
                    .stroke(Color.theaSuccess, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack {
                    Image(systemName: tree.treeType.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.theaSuccess)

                    Text("\(Int(viewModel.treeGrowthProgress))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .frame(width: 180, height: 180)

            Text("\(tree.minutesGrown) / \(tree.treeType.minutesToGrow) minutes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.theaSuccess.opacity(0.1))
        .cornerRadius(16)
    }

    private var plantTreeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plant a Tree")
                .font(.headline)

            Picker("Tree Type", selection: $viewModel.selectedTreeType) {
                ForEach(FocusTree.TreeType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Button(action: {
                Task {
                    await viewModel.plantTree(type: viewModel.selectedTreeType)
                }
            }) {
                HStack {
                    Image(systemName: "tree")
                    Text("Plant \(viewModel.selectedTreeType.displayName)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.theaSuccess)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private func forestStatsSection(_ forest: FocusForest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Forest")
                .font(.headline)

            HStack(spacing: 16) {
                ForestStatCard(
                    title: "Trees Grown",
                    value: "\(forest.totalTreesGrown)",
                    icon: "tree.fill",
                    color: .theaSuccess
                )

                ForestStatCard(
                    title: "Current Streak",
                    value: "\(forest.currentStreak)",
                    icon: "flame.fill",
                    color: .theaWarning
                )
            }
        }
    }

    private func detailedForestStatsSection(_ stats: ForestStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Statistics")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(stats.totalMinutesFocused)")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Longest Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(stats.longestStreak) days")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            if let favorite = stats.favoriteTreeType {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.theaWarning)

                    Text("Favorite: \(favorite.displayName)")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.theaWarning.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Timeline Tab

    private var timelineTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Today's Timeline")
                    .font(.title2)
                    .fontWeight(.bold)

                if viewModel.timelineEvents.isEmpty {
                    Text("No events scheduled for today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(viewModel.timelineEvents) { event in
                        TimelineEventRow(event: event)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.theaError)

            Text(message)
                .font(.caption)
                .foregroundStyle(Color.theaError)

            Spacer()

            Button("Dismiss") {
                viewModel.errorMessage = nil
            }
            .font(.caption)
        }
        .padding()
        .background(Color.theaError.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Subtask Row

private struct SubtaskRow: View {
    let subtask: CognitiveSubtask
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: subtask.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(subtask.completed ? .theaSuccess : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(subtask.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(subtask.completed)

                Text(subtask.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(subtask.estimatedMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Breakdown History Row

private struct BreakdownHistoryRow: View {
    let breakdown: TaskBreakdown
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakdown.originalTask)
                        .font(.subheadline)
                        .lineLimit(2)

                    Text("\(breakdown.subtasks.count) subtasks • \(breakdown.estimatedTotalMinutes) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pomodoro Type Button

private struct PomodoroTypeButton: View {
    let type: PomodoroSession.SessionType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("\(type.defaultDuration)m")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: type.color).opacity(0.2))
            .foregroundColor(Color(hex: type.color))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pomodoro Stat Card

private struct PomodoroStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Pomodoro History Row

private struct PomodoroHistoryRow: View {
    let session: PomodoroSession

    var body: some View {
        HStack {
            Image(systemName: session.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(session.completed ? .theaSuccess : .theaError)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let taskName = session.taskName {
                    Text(taskName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(session.startTime, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let minutes = session.actualMinutes {
                Text("\(minutes)m")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Forest Stat Card

private struct ForestStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Timeline Event Row

private struct TimelineEventRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(hex: event.color))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Text(event.startTime, style: .time)
                    Text("-")
                    Text(event.endTime, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(event.category.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: event.color).opacity(0.2))
                    .foregroundColor(Color(hex: event.color))
                    .cornerRadius(4)
            }

            Spacer()

            if event.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.theaSuccess)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CognitiveDashboardView()
    }
}
