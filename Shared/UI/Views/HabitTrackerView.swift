// HabitTrackerView.swift
// Thea
//
// Full habit tracking UI with stats bar, habit list, add/edit sheet,
// calendar heatmap, streak visualization, and category filters.

import SwiftUI

struct HabitTrackerView: View {
    @State private var manager = HabitManager.shared
    @State private var showingAddSheet = false
    @State private var selectedHabit: TheaHabit?
    @State private var showArchived = false
    @State private var searchText = ""
    @State private var filterCategory: HabitCategory?

    private var filteredHabits: [TheaHabit] {
        let base = showArchived ? manager.archivedHabits : manager.activeHabits
        var result = base
        if let category = filterCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.details.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            statsBar
            Divider()
            habitList
        }
        .searchable(text: $searchText, prompt: "Search habits")
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Habit", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showArchived) {
                    Label("Archived", systemImage: "archivebox")
                }
                .toggleStyle(.button)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            HabitEditSheet(habit: nil)
        }
        .sheet(item: $selectedHabit) { habit in
            HabitDetailSheet(habit: habit)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        let progress = manager.todayProgress()
        let rate = manager.overallCompletionRate()

        return HStack(spacing: 16) {
            HabitStatCard(
                title: "Today",
                value: "\(progress.completed)/\(progress.total)",
                icon: "checkmark.circle",
                color: progress.completed == progress.total && progress.total > 0 ? .green : .blue
            )

            HabitStatCard(
                title: "30-Day Rate",
                value: "\(Int(rate * 100))%",
                icon: "chart.line.uptrend.xyaxis",
                color: rate >= 0.8 ? .green : rate >= 0.5 ? .orange : .red
            )

            HabitStatCard(
                title: "Active",
                value: "\(manager.activeHabits.count)",
                icon: "flame",
                color: .orange
            )

            HabitStatCard(
                title: "Best Streak",
                value: "\(manager.activeHabits.map(\.longestStreak).max() ?? 0)",
                icon: "trophy",
                color: .yellow
            )
        }
        .padding()
    }

    // MARK: - Habit List

    private var habitList: some View {
        Group {
            if filteredHabits.isEmpty {
                ContentUnavailableView(
                    showArchived ? "No Archived Habits" : "No Habits Yet",
                    systemImage: showArchived ? "archivebox" : "target",
                    description: Text(showArchived
                        ? "Archived habits will appear here"
                        : "Tap + to create your first habit")
                )
            } else {
                List {
                    categoryFilterRow

                    ForEach(filteredHabits, id: \.id) { habit in
                        HabitRowView(habit: habit) {
                            manager.completeHabit(habit)
                        } onTap: {
                            selectedHabit = habit
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                manager.deleteHabit(habit)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                manager.archiveHabit(habit)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.gray)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "All",
                    isSelected: filterCategory == nil,
                    color: .secondary
                ) {
                    filterCategory = nil
                }

                ForEach(usedCategories, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        isSelected: filterCategory == category,
                        color: Color(hex: category.defaultColor)
                    ) {
                        filterCategory = filterCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
    }

    private var usedCategories: [HabitCategory] {
        Array(Set(manager.activeHabits.map(\.category))).sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Subviews

private struct HabitStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontDesign(.rounded)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color.clear)
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct HabitRowView: View {
    let habit: TheaHabit
    let onComplete: () -> Void
    let onTap: () -> Void
    @State private var manager = HabitManager.shared

    private var isCompletedToday: Bool {
        manager.isCompleted(habit, on: Date())
    }

    private var todayCount: Int {
        manager.completionCount(habit, on: Date())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Button(action: onComplete) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: habit.colorHex), lineWidth: 2)
                            .frame(width: 28, height: 28)

                        if isCompletedToday {
                            Circle()
                                .fill(Color(hex: habit.colorHex))
                                .frame(width: 28, height: 28)

                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(habit.name)
                            .font(.body)
                            .strikethrough(isCompletedToday, color: .secondary)
                            .foregroundStyle(isCompletedToday ? .secondary : .primary)

                        if habit.targetCount > 1 {
                            Text("\(todayCount)/\(habit.targetCount)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: habit.colorHex).opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Label(habit.frequency.displayName, systemImage: "clock")
                        if habit.currentStreak > 0 {
                            Label("\(habit.currentStreak) day streak", systemImage: "flame")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                weeklyDotsView
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name), \(isCompletedToday ? "completed" : "not completed")")
    }

    private var weeklyDotsView: some View {
        let weekly = manager.weeklyCompletions(for: habit)
        return HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(weekly[index] > 0 ? Color(hex: habit.colorHex) : Color.secondary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Calendar Heatmap

struct HabitHeatmapView: View {
    let habit: TheaHabit
    let days: Int
    @State private var manager = HabitManager.shared

    var body: some View {
        let data = manager.heatmapData(for: habit, days: days)
        let columns = Array(repeating: GridItem(.fixed(14), spacing: 2), count: 7)

        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                RoundedRectangle(cornerRadius: 2)
                    .fill(heatmapColor(level: item.level))
                    .frame(width: 14, height: 14)
            }
        }
    }

    private func heatmapColor(level: Int) -> Color {
        let baseColor = Color(hex: habit.colorHex)
        switch level {
        case 0: return Color.secondary.opacity(0.1)
        case 1: return baseColor.opacity(0.3)
        case 2: return baseColor.opacity(0.7)
        case 3: return baseColor
        default: return Color.secondary.opacity(0.1)
        }
    }
}

// MARK: - Detail Sheet

struct HabitDetailSheet: View {
    let habit: TheaHabit
    @State private var manager = HabitManager.shared
    @State private var showEditSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    statsSection
                    heatmapSection
                    historySection
                }
                .padding()
            }
            .navigationTitle(habit.name)
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditSheet = true }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                HabitEditSheet(habit: habit)
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: habit.icon)
                .font(.largeTitle)
                .foregroundStyle(Color(hex: habit.colorHex))
                .frame(width: 60, height: 60)
                .background(Color(hex: habit.colorHex).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.title2.bold())
                if !habit.details.isEmpty {
                    Text(habit.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label(habit.category.displayName, systemImage: habit.category.icon)
                    Label(habit.frequency.displayName, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            HabitDetailStat(title: "Current Streak", value: "\(habit.currentStreak)", icon: "flame", color: .orange)
            HabitDetailStat(title: "Best Streak", value: "\(habit.longestStreak)", icon: "trophy", color: .yellow)
            HabitDetailStat(title: "Total", value: "\(habit.totalCompletions)", icon: "checkmark.circle", color: .green)
            HabitDetailStat(
                title: "30-Day Rate",
                value: "\(Int(manager.completionRate(for: habit) * 100))%",
                icon: "chart.bar",
                color: .blue
            )
        }
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity (90 days)")
                .font(.headline)
            HabitHeatmapView(habit: habit, days: 90)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Completions")
                .font(.headline)

            let recentEntries = manager.entriesFor(habit: habit).prefix(10)
            if recentEntries.isEmpty {
                Text("No completions yet")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(Array(recentEntries), id: \.id) { entry in
                    HStack {
                        Text(entry.completedDate, style: .date)
                            .font(.subheadline)
                        Spacer()
                        if entry.count > 1 {
                            Text("\(entry.count)x")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if entry.rating > 0 {
                            HStack(spacing: 1) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= entry.rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct HabitDetailStat: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontDesign(.rounded)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Edit Sheet

struct HabitEditSheet: View {
    let habit: TheaHabit?
    @State private var manager = HabitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var details = ""
    @State private var frequency: HabitFrequency = .daily
    @State private var category: HabitCategory = .custom
    @State private var colorHex = "#007AFF"
    @State private var icon = "checkmark.circle"
    @State private var reminderEnabled = false
    @State private var reminderHour = 9
    @State private var reminderMinute = 0
    @State private var targetCount = 1

    private var isEditing: Bool { habit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Habit name", text: $name)
                    TextField("Description (optional)", text: $details)
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }

                    Stepper("Target: \(targetCount) per day", value: $targetCount, in: 1...100)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Reminder") {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        HStack {
                            Text("Time")
                            Spacer()
                            Picker("Hour", selection: $reminderHour) {
                                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)) }
                            }
                            .labelsHidden()
                            .frame(width: 60)
                            Text(":")
                            Picker("Minute", selection: $reminderMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)) }
                            }
                            .labelsHidden()
                            .frame(width: 60)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 400)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let habit {
                    name = habit.name
                    details = habit.details
                    frequency = habit.frequency
                    category = habit.category
                    colorHex = habit.colorHex
                    icon = habit.icon
                    reminderEnabled = habit.reminderEnabled
                    reminderHour = habit.reminderHour
                    reminderMinute = habit.reminderMinute
                    targetCount = habit.targetCount
                }
            }
        }
    }

    private func save() {
        if let habit {
            habit.name = name.trimmingCharacters(in: .whitespaces)
            habit.details = details.trimmingCharacters(in: .whitespaces)
            habit.frequency = frequency
            habit.category = category
            habit.colorHex = colorHex.isEmpty ? category.defaultColor : colorHex
            habit.icon = icon
            habit.reminderEnabled = reminderEnabled
            habit.reminderHour = reminderHour
            habit.reminderMinute = reminderMinute
            habit.targetCount = targetCount
            manager.updateHabit(habit)
        } else {
            _ = manager.createHabit(
                name: name.trimmingCharacters(in: .whitespaces),
                details: details.trimmingCharacters(in: .whitespaces),
                frequency: frequency,
                category: category,
                colorHex: colorHex.isEmpty ? nil : colorHex,
                icon: icon,
                reminderEnabled: reminderEnabled,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                targetCount: targetCount
            )
        }
    }
}

// Color(hex:) is defined in Shared/UI/Theme/Colors.swift
