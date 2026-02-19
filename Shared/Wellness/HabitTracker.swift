// HabitTracker.swift
// Thea
//
// Universal habit tracking — create/track any habit with streaks,
// reminders, statistics, calendar heatmap, and behavioral integration.
// Replaces: Liven, Try Dry, NOMO apps.

import Foundation
import OSLog
import SwiftData
import UserNotifications

private let habitLogger = Logger(subsystem: "ai.thea.app", category: "HabitTracker")

// MARK: - Data Models

enum HabitFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekdays
    case weekends
    case weekly
    case biweekly
    case monthly
    case custom

    var displayName: String {
        switch self {
        case .daily: "Every day"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .custom: "Custom"
        }
    }

    var daysPerWeek: Double {
        switch self {
        case .daily: 7
        case .weekdays: 5
        case .weekends: 2
        case .weekly: 1
        case .biweekly: 0.5
        case .monthly: 0.23
        case .custom: 7
        }
    }
}

enum HabitCategory: String, Codable, CaseIterable, Sendable {
    case health
    case fitness
    case mindfulness
    case nutrition
    case productivity
    case learning
    case creativity
    case social
    case finance
    case selfCare
    case custom

    var displayName: String {
        switch self {
        case .health: "Health"
        case .fitness: "Fitness"
        case .mindfulness: "Mindfulness"
        case .nutrition: "Nutrition"
        case .productivity: "Productivity"
        case .learning: "Learning"
        case .creativity: "Creativity"
        case .social: "Social"
        case .finance: "Finance"
        case .selfCare: "Self Care"
        case .custom: "Custom"
        }
    }

    var icon: String {
        switch self {
        case .health: "heart.fill"
        case .fitness: "figure.run"
        case .mindfulness: "brain.head.profile"
        case .nutrition: "fork.knife"
        case .productivity: "checkmark.circle"
        case .learning: "book.fill"
        case .creativity: "paintbrush.fill"
        case .social: "person.2.fill"
        case .finance: "banknote"
        case .selfCare: "sparkles"
        case .custom: "star.fill"
        }
    }

    var defaultColor: String {
        switch self {
        case .health: "#FF3B30"
        case .fitness: "#FF9500"
        case .mindfulness: "#5856D6"
        case .nutrition: "#34C759"
        case .productivity: "#007AFF"
        case .learning: "#AF52DE"
        case .creativity: "#FF2D55"
        case .social: "#5AC8FA"
        case .finance: "#30D158"
        case .selfCare: "#FFD60A"
        case .custom: "#8E8E93"
        }
    }
}

@Model
final class TheaHabit {
    var id: UUID
    var name: String
    var details: String
    var frequencyRaw: String
    var categoryRaw: String
    var colorHex: String
    var icon: String
    var createdDate: Date
    var updatedDate: Date
    var startDate: Date
    var targetEndDate: Date?
    var isActive: Bool
    var isArchived: Bool
    var currentStreak: Int
    var longestStreak: Int
    var totalCompletions: Int
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var targetCount: Int
    var customDaysRaw: String
    var notes: String

    init(
        name: String,
        details: String = "",
        frequency: HabitFrequency = .daily,
        category: HabitCategory = .custom,
        colorHex: String? = nil,
        icon: String = "checkmark.circle",
        startDate: Date = Date(),
        targetEndDate: Date? = nil,
        reminderEnabled: Bool = false,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        targetCount: Int = 1,
        customDays: [Int] = []
    ) {
        self.id = UUID()
        self.name = name
        self.details = details
        self.frequencyRaw = frequency.rawValue
        self.categoryRaw = category.rawValue
        self.colorHex = colorHex ?? category.defaultColor
        self.icon = icon
        self.createdDate = Date()
        self.updatedDate = Date()
        self.startDate = startDate
        self.targetEndDate = targetEndDate
        self.isActive = true
        self.isArchived = false
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalCompletions = 0
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.targetCount = targetCount
        self.customDaysRaw = customDays.map(String.init).joined(separator: ",")
        self.notes = ""
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    var customDays: [Int] {
        get {
            customDaysRaw.split(separator: ",").compactMap { Int($0) }
        }
        set {
            customDaysRaw = newValue.map(String.init).joined(separator: ",")
        }
    }

    func isDueOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        switch frequency {
        case .daily:
            return true
        case .weekdays:
            return weekday >= 2 && weekday <= 6
        case .weekends:
            return weekday == 1 || weekday == 7
        case .weekly:
            let startWeekday = calendar.component(.weekday, from: startDate)
            return weekday == startWeekday
        case .biweekly:
            let startWeekday = calendar.component(.weekday, from: startDate)
            guard weekday == startWeekday else { return false }
            let weeks = calendar.dateComponents([.weekOfYear], from: startDate, to: date).weekOfYear ?? 0
            return weeks % 2 == 0
        case .monthly:
            let startDay = calendar.component(.day, from: startDate)
            return calendar.component(.day, from: date) == startDay
        case .custom:
            return customDays.contains(weekday)
        }
    }
}

@Model
final class TheaHabitEntry {
    var id: UUID
    var habitID: UUID
    var completedDate: Date
    var count: Int
    var notes: String
    var rating: Int
    var createdDate: Date

    init(
        habitID: UUID,
        completedDate: Date = Date(),
        count: Int = 1,
        notes: String = "",
        rating: Int = 0
    ) {
        self.id = UUID()
        self.habitID = habitID
        self.completedDate = completedDate
        self.count = count
        self.notes = notes
        self.rating = rating
        self.createdDate = Date()
    }
}

// MARK: - Habit Manager

@MainActor
@Observable
final class HabitManager {
    static let shared = HabitManager()

    private(set) var habits: [TheaHabit] = []
    private(set) var entries: [TheaHabitEntry] = []
    private var modelContext: ModelContext?

    // MARK: - Error State (observable for UI alerts)
    var errorMessage: String?
    var showError: Bool = false

    private init() {}

    private func handleSaveError(_ error: Error, context: String) {
        let message = "Failed to save: \(error.localizedDescription)"
        errorMessage = message
        showError = true
        habitLogger.error("[\(context)] \(message)")
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadData()
    }

    // MARK: - CRUD

    func addHabit(_ habit: TheaHabit) {
        modelContext?.insert(habit)
        do {
            try modelContext?.save()
        } catch {
            handleSaveError(error, context: "HabitManager.addHabit(\(habit.name))")
        }
        loadData()
        if habit.reminderEnabled {
            scheduleReminder(for: habit)
        }
    }

    func createHabit(
        name: String,
        details: String = "",
        frequency: HabitFrequency = .daily,
        category: HabitCategory = .custom,
        colorHex: String? = nil,
        icon: String = "checkmark.circle",
        reminderEnabled: Bool = false,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        targetCount: Int = 1
    ) -> TheaHabit {
        let habit = TheaHabit(
            name: name,
            details: details,
            frequency: frequency,
            category: category,
            colorHex: colorHex,
            icon: icon,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            targetCount: targetCount
        )
        addHabit(habit)
        return habit
    }

    func updateHabit(_ habit: TheaHabit) {
        habit.updatedDate = Date()
        do {
            try modelContext?.save()
        } catch {
            handleSaveError(error, context: "HabitManager.updateHabit(\(habit.name))")
        }
        loadData()
        if habit.reminderEnabled {
            scheduleReminder(for: habit)
        } else {
            cancelReminder(for: habit)
        }
    }

    func deleteHabit(_ habit: TheaHabit) {
        cancelReminder(for: habit)
        let habitID = habit.id
        let entriesToDelete = entries.filter { $0.habitID == habitID }
        for entry in entriesToDelete {
            modelContext?.delete(entry)
        }
        modelContext?.delete(habit)
        do {
            try modelContext?.save()
        } catch {
            handleSaveError(error, context: "HabitManager.deleteHabit(\(habit.name))")
        }
        loadData()
    }

    func archiveHabit(_ habit: TheaHabit) {
        habit.isArchived = true
        habit.isActive = false
        habit.updatedDate = Date()
        do {
            try modelContext?.save()
        } catch {
            handleSaveError(error, context: "HabitManager.archiveHabit(\(habit.name))")
        }
        cancelReminder(for: habit)
        loadData()
    }

    // MARK: - Completions

    func completeHabit(_ habit: TheaHabit, date: Date = Date(), notes: String = "", rating: Int = 0) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let existingToday = entries.first { entry in
            entry.habitID == habit.id &&
            calendar.isDate(entry.completedDate, inSameDayAs: dayStart)
        }

        if let existing = existingToday {
            existing.count += 1
            if !notes.isEmpty { existing.notes = notes }
            if rating > 0 { existing.rating = rating }
        } else {
            let entry = TheaHabitEntry(
                habitID: habit.id,
                completedDate: dayStart,
                count: 1,
                notes: notes,
                rating: rating
            )
            modelContext?.insert(entry)
        }

        habit.totalCompletions += 1
        habit.updatedDate = Date()
        recalculateStreak(for: habit)
        do {
            try modelContext?.save()
        } catch {
            handleSaveError(error, context: "HabitManager.completeHabit(\(habit.name))")
        }
        loadData()
    }

    func uncompleteHabit(_ habit: TheaHabit, date: Date = Date()) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        if let entry = entries.first(where: { entry in
            entry.habitID == habit.id &&
            calendar.isDate(entry.completedDate, inSameDayAs: dayStart)
        }) {
            if entry.count > 1 {
                entry.count -= 1
            } else {
                modelContext?.delete(entry)
            }
            habit.totalCompletions = max(0, habit.totalCompletions - 1)
            habit.updatedDate = Date()
            recalculateStreak(for: habit)
            do {
                try modelContext?.save()
            } catch {
                handleSaveError(error, context: "HabitManager.uncompleteHabit(\(habit.name))")
            }
            loadData()
        }
    }

    func isCompleted(_ habit: TheaHabit, on date: Date) -> Bool {
        let calendar = Calendar.current
        return entries.contains { entry in
            entry.habitID == habit.id &&
            calendar.isDate(entry.completedDate, inSameDayAs: date) &&
            entry.count >= habit.targetCount
        }
    }

    func completionCount(_ habit: TheaHabit, on date: Date) -> Int {
        let calendar = Calendar.current
        return entries.first { entry in
            entry.habitID == habit.id &&
            calendar.isDate(entry.completedDate, inSameDayAs: date)
        }?.count ?? 0
    }

    // MARK: - Streaks

    func recalculateStreak(for habit: TheaHabit) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var current = 0
        var longest = 0
        var checkDate = today

        while true {
            if habit.isDueOn(date: checkDate) {
                if isCompleted(habit, on: checkDate) {
                    current += 1
                } else {
                    if checkDate != today { break }
                    break
                }
            }

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay

            if checkDate < habit.startDate { break }
            if current > 366 { break }
        }

        habit.currentStreak = current
        if current > habit.longestStreak {
            habit.longestStreak = current
        }

        longest = habit.longestStreak
        _ = longest
    }

    // MARK: - Statistics

    var activeHabits: [TheaHabit] {
        habits.filter { $0.isActive && !$0.isArchived }
    }

    var archivedHabits: [TheaHabit] {
        habits.filter { $0.isArchived }
    }

    func completionRate(for habit: TheaHabit, days: Int = 30) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var dueCount = 0
        var completedCount = 0

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            if date < habit.startDate { break }
            if habit.isDueOn(date: date) {
                dueCount += 1
                if isCompleted(habit, on: date) {
                    completedCount += 1
                }
            }
        }

        guard dueCount > 0 else { return 0 }
        return Double(completedCount) / Double(dueCount)
    }

    func overallCompletionRate(days: Int = 30) -> Double {
        let rates = activeHabits.map { completionRate(for: $0, days: days) }
        guard !rates.isEmpty else { return 0 }
        return rates.reduce(0, +) / Double(rates.count)
    }

    func heatmapData(for habit: TheaHabit, days: Int = 90) -> [(date: Date, level: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [(date: Date, level: Int)] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let count = completionCount(habit, on: date)
            let target = habit.targetCount
            let level: Int
            if count == 0 {
                level = 0
            } else if count < target {
                level = 1
            } else if count == target {
                level = 2
            } else {
                level = 3
            }
            result.append((date: date, level: level))
        }

        return result
    }

    func todayProgress() -> (completed: Int, total: Int) {
        let today = Date()
        let dueToday = activeHabits.filter { $0.isDueOn(date: today) }
        let completedToday = dueToday.filter { isCompleted($0, on: today) }
        return (completedToday.count, dueToday.count)
    }

    func weeklyCompletions(for habit: TheaHabit) -> [Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return completionCount(habit, on: date)
        }
    }

    func entriesFor(habit: TheaHabit) -> [TheaHabitEntry] {
        entries.filter { $0.habitID == habit.id }
            .sorted { $0.completedDate > $1.completedDate }
    }

    // MARK: - Reminders

    func scheduleReminder(for habit: TheaHabit) {
        let center = UNUserNotificationCenter.current()
        let identifier = "habit-\(habit.id.uuidString)"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body = "Time for: \(habit.name)"
        content.sound = .default
        content.categoryIdentifier = "HABIT_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = habit.reminderHour
        dateComponents.minute = habit.reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                ErrorLogger.log(error, context: "HabitManager.scheduleReminder")
            }
        }
    }

    func cancelReminder(for habit: TheaHabit) {
        let identifier = "habit-\(habit.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Private

    private func loadData() {
        guard let modelContext else { return }

        let habitDescriptor = FetchDescriptor<TheaHabit>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        habits = ErrorLogger.tryOrDefault([], context: "HabitManager.loadData.fetchHabits") {
            try modelContext.fetch(habitDescriptor)
        }

        let entryDescriptor = FetchDescriptor<TheaHabitEntry>(
            sortBy: [SortDescriptor(\.completedDate, order: .reverse)]
        )
        entries = ErrorLogger.tryOrDefault([], context: "HabitManager.loadData.fetchEntries") {
            try modelContext.fetch(entryDescriptor)
        }
    }
}
