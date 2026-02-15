// LearningDashboardView.swift
// Thea — Learning goal tracking and progress UI
//
// Dashboard for learning goals with progress tracking,
// study sessions, streak counts, and resource management.

import SwiftUI

struct LearningDashboardView: View {
    @ObservedObject private var manager = LearningTracker.shared
    @State private var showingAddGoal = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Active").tag(0)
                Text("Completed").tag(1)
                Text("All").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Divider().padding(.top, 8)

            List {
                statsSection
                goalsSection
            }
        }
        .navigationTitle("Learning")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddGoal = true } label: {
                    Label("Add Goal", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddTrackedLearningGoalSheet { goal in
                manager.addGoal(goal)
            }
        }
    }

    // MARK: - Sections

    private var statsSection: some View {
        Section {
            HStack {
                LrnStatCard(label: "Goals", value: "\(manager.goals.count)",
                            icon: "target", color: .blue)
                LrnStatCard(label: "Active", value: "\(manager.activeGoals.count)",
                            icon: "flame", color: .orange)
                LrnStatCard(label: "Hours", value: String(format: "%.0f", manager.totalStudyHours),
                            icon: "clock", color: .green)
                LrnStatCard(label: "Streak", value: "\(manager.longestStreak)d",
                            icon: "bolt", color: .purple)
            }
        }
    }

    private var goalsSection: some View {
        Section {
            let goals = displayedGoals
            if goals.isEmpty {
                ContentUnavailableView(
                    "No Learning Goals",
                    systemImage: "graduationcap",
                    description: Text("Set a goal to start learning.")
                )
            } else {
                ForEach(goals) { goal in
                    goalRow(goal)
                }
                .onDelete { offsets in
                    for idx in offsets {
                        manager.deleteGoal(id: goals[idx].id)
                    }
                }
            }
        } header: {
            Text(selectedTab == 0 ? "Active Goals" : selectedTab == 1 ? "Completed" : "All Goals")
        }
    }

    // MARK: - Goal Row

    private func goalRow(_ goal: TrackedLearningGoal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: goal.category.icon)
                    .foregroundStyle(.blue)
                Text(goal.title)
                    .font(.headline)
                Spacer()
                Text(goal.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !goal.description.isEmpty {
                Text(goal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label("\(goal.totalStudyMinutes) min", systemImage: "clock")
                Label("\(goal.resources.count) resources", systemImage: "link")
                if goal.currentStreak > 0 {
                    Label("\(goal.currentStreak)d streak", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
                if let target = goal.targetDate {
                    Text(target, format: .dateTime.month().day())
                        .foregroundStyle(goal.isOverdue ? .red : .secondary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            ProgressView(value: goal.progressPercent / 100)
                .tint(goal.progressPercent >= 100 ? .green : .blue)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var displayedGoals: [TrackedLearningGoal] {
        switch selectedTab {
        case 0: return manager.activeGoals
        case 1: return manager.completedGoals
        default: return manager.goals
        }
    }
}

// MARK: - Add Goal Sheet

private struct AddTrackedLearningGoalSheet: View {
    let onSave: (TrackedLearningGoal) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: LearningCategory = .technology
    @State private var priority: LearningPriority = .medium
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Title (e.g., Learn SwiftUI)", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3)
                }
                Section("Details") {
                    Picker("Category", selection: $category) {
                        ForEach(LearningCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(LearningPriority.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    Toggle("Target Date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Target", selection: $targetDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Learning Goal")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 350)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let goal = TrackedLearningGoal(
                            title: title, description: description, category: category,
                            targetDate: hasTargetDate ? targetDate : nil, priority: priority
                        )
                        onSave(goal)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Lrn Stat Card

private struct LrnStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
