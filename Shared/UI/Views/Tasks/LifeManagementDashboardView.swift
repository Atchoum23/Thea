//
//  LifeManagementDashboardView.swift
//  Thea
//
//  Unified daily/weekly review with task overview, goals, and KG-powered suggestions.
//

import SwiftUI

// MARK: - Life Management Dashboard

struct LifeManagementDashboardView: View {
    @ObservedObject private var taskManager = TheaTaskManager.shared
    @State private var selectedTab: DashboardTab = .today
    @State private var suggestions: [KGSuggestion] = []
    @State private var goalProgress: [GoalEntry] = []
    @State private var isLoadingSuggestions = false

    enum DashboardTab: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case goals = "Goals"
        case suggestions = "AI Suggestions"
    }

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .today:
                        todayReview
                    case .week:
                        weeklyReview
                    case .goals:
                        goalsView
                    case .suggestions:
                        suggestionsView
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Life Dashboard")
        .task {
            loadSuggestions()
            loadGoals()
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            ForEach(DashboardTab.allCases, id: \.rawValue) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    // MARK: - Today Review

    private var todayReview: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Greeting
            Text(greetingText)
                .font(.title2.bold())

            // Quick Stats
            HStack(spacing: 12) {
                quickStat(
                    label: "Tasks Due",
                    value: "\(taskManager.todayTasks.count)",
                    icon: "checklist",
                    color: .blue
                )
                quickStat(
                    label: "Completed",
                    value: "\(taskManager.tasksCompletedToday)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                quickStat(
                    label: "Overdue",
                    value: "\(taskManager.overdueTasks.count)",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
                quickStat(
                    label: "Streak",
                    value: "\(taskManager.currentStreak)d",
                    icon: "flame.fill",
                    color: .orange
                )
            }

            // Today's Tasks
            if !taskManager.todayTasks.isEmpty {
                sectionHeader("Due Today")
                ForEach(taskManager.todayTasks, id: \.id) { task in
                    todayTaskRow(task)
                }
            }

            // Overdue Tasks
            if !taskManager.overdueTasks.isEmpty {
                sectionHeader("Overdue")
                ForEach(taskManager.overdueTasks, id: \.id) { task in
                    todayTaskRow(task)
                }
            }

            // Completion Progress
            if !taskManager.tasks.isEmpty {
                sectionHeader("Overall Progress")
                completionProgressBar
            }
        }
    }

    // MARK: - Weekly Review

    private var weeklyReview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Review")
                .font(.title2.bold())

            // Week stats
            let weekTasks = taskManager.thisWeekTasks
            let completedThisWeek = taskManager.completedTasks.filter { task in
                guard let completedDate = task.completedDate else { return false }
                return Calendar.current.isDate(completedDate, equalTo: Date(), toGranularity: .weekOfYear)
            }

            HStack(spacing: 12) {
                quickStat(
                    label: "This Week",
                    value: "\(weekTasks.count)",
                    icon: "calendar",
                    color: .blue
                )
                quickStat(
                    label: "Done",
                    value: "\(completedThisWeek.count)",
                    icon: "checkmark.circle",
                    color: .green
                )
                quickStat(
                    label: "Total Active",
                    value: "\(taskManager.pendingTasks.count)",
                    icon: "list.bullet",
                    color: .purple
                )
            }

            // Category breakdown
            sectionHeader("By Category")
            categoryBreakdown

            // Priority breakdown
            sectionHeader("By Priority")
            priorityBreakdown
        }
    }

    // MARK: - Goals View

    private var goalsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goals & Progress")
                .font(.title2.bold())

            if goalProgress.isEmpty {
                ContentUnavailableView {
                    Label("No Goals Yet", systemImage: "target")
                } description: {
                    Text("Goals are inferred from your tasks and conversations")
                }
            } else {
                ForEach(goalProgress) { goal in
                    goalRow(goal)
                }
            }
        }
    }

    // MARK: - Suggestions View

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Suggestions")
                    .font(.title2.bold())
                Spacer()
                if isLoadingSuggestions {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text("Based on your tasks, calendar, and knowledge graph")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if suggestions.isEmpty && !isLoadingSuggestions {
                ContentUnavailableView {
                    Label("No Suggestions", systemImage: "lightbulb")
                } description: {
                    Text("Add more tasks and conversations to get personalized suggestions")
                }
            } else {
                ForEach(suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func quickStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }

    private func todayTaskRow(_ task: TheaTask) -> some View {
        HStack(spacing: 12) {
            Button {
                taskManager.toggleCompletion(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                HStack(spacing: 4) {
                    Image(systemName: task.priority.icon)
                        .font(.caption2)
                    Text(task.category.rawValue)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if task.isOverdue {
                Text("Overdue")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
            }
        }
        .padding(8)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var completionProgressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(Int(taskManager.completionRate * 100))% Complete")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(taskManager.completedTasks.count)/\(taskManager.tasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: taskManager.completionRate)
                .tint(taskManager.completionRate >= 0.8 ? .green : .blue)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var categoryBreakdown: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
            ForEach(TheaTaskCategory.allCases, id: \.rawValue) { category in
                let count = taskManager.tasks(for: category).count
                if count > 0 {
                    HStack {
                        Image(systemName: category.icon)
                            .font(.caption)
                        Text(category.rawValue)
                            .font(.caption)
                        Spacer()
                        Text("\(count)")
                            .font(.caption.bold())
                    }
                    .padding(8)
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var priorityBreakdown: some View {
        HStack(spacing: 8) {
            ForEach(TheaTaskPriority.allCases, id: \.rawValue) { priority in
                let count = taskManager.pendingTasks.filter { $0.priority == priority }.count
                VStack(spacing: 4) {
                    Image(systemName: priority.icon)
                        .font(.caption)
                    Text("\(count)")
                        .font(.subheadline.bold())
                    Text(priority.displayName)
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func goalRow(_ goal: GoalEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.icon)
                    .foregroundStyle(.blue)
                Text(goal.title)
                    .font(.headline)
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(goal.progress >= 0.8 ? .green : .primary)
            }
            ProgressView(value: goal.progress)
                .tint(goal.progress >= 0.8 ? .green : .blue)
            Text(goal.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func suggestionCard(_ suggestion: KGSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.subheadline.bold())
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let action = suggestion.actionLabel {
                Button(action) {
                    // Action handled by suggestion type
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Data

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }

    private func loadSuggestions() {
        isLoadingSuggestions = true
        Task {
            // Query PersonalKnowledgeGraph for context-aware suggestions
            let kgEntities = PersonalKnowledgeGraph.shared.searchEntities(query: "")
            var result: [KGSuggestion] = []

            // Suggest based on overdue tasks
            let overdueCount = taskManager.overdueTasks.count
            if overdueCount > 0 {
                result.append(KGSuggestion(
                    title: "Address \(overdueCount) overdue task\(overdueCount == 1 ? "" : "s")",
                    description: "You have tasks past their due date that need attention",
                    icon: "exclamationmark.triangle.fill",
                    actionLabel: "View"
                ))
            }

            // Suggest based on KG entity relationships
            let projectEntities = kgEntities.filter { $0.type == .project }
            if !projectEntities.isEmpty {
                let projectName = projectEntities.first?.name ?? "your project"
                result.append(KGSuggestion(
                    title: "Continue working on \(projectName)",
                    description: "Based on your recent activity and knowledge graph",
                    icon: "folder.fill",
                    actionLabel: nil
                ))
            }

            // Suggest streak maintenance
            if taskManager.currentStreak > 0 {
                result.append(KGSuggestion(
                    title: "Keep your \(taskManager.currentStreak)-day streak going!",
                    description: "Complete at least one task today to maintain your streak",
                    icon: "flame.fill",
                    actionLabel: nil
                ))
            }

            // Suggest task creation if few pending
            if taskManager.pendingTasks.count < 3 {
                result.append(KGSuggestion(
                    title: "Plan ahead",
                    description: "You have few pending tasks. Consider planning your upcoming work.",
                    icon: "lightbulb.fill",
                    actionLabel: "Add Task"
                ))
            }

            suggestions = result
            isLoadingSuggestions = false
        }
    }

    private func loadGoals() {
        // Build goals from task categories and completion data
        var goals: [GoalEntry] = []

        // Task completion goal
        let totalTasks = taskManager.tasks.count
        if totalTasks > 0 {
            goals.append(GoalEntry(
                title: "Task Completion",
                description: "\(taskManager.completedTasks.count) of \(totalTasks) tasks completed",
                icon: "checkmark.circle",
                progress: taskManager.completionRate
            ))
        }

        // Category-specific goals
        for category in TheaTaskCategory.allCases {
            let categoryTasks = taskManager.tasks(for: category)
            let completed = categoryTasks.filter(\.isCompleted).count
            if categoryTasks.count >= 3 {
                let progress = Double(completed) / Double(categoryTasks.count)
                goals.append(GoalEntry(
                    title: "\(category.rawValue) Tasks",
                    description: "\(completed)/\(categoryTasks.count) completed",
                    icon: category.icon,
                    progress: progress
                ))
            }
        }

        // Streak goal
        if taskManager.currentStreak > 0 {
            let streakGoal = min(Double(taskManager.currentStreak) / 30.0, 1.0)
            goals.append(GoalEntry(
                title: "30-Day Streak",
                description: "\(taskManager.currentStreak) days and counting",
                icon: "flame.fill",
                progress: streakGoal
            ))
        }

        goalProgress = goals
    }
}

// MARK: - Supporting Types

struct KGSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let actionLabel: String?
}

struct GoalEntry: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let progress: Double
}
