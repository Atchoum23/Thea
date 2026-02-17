//
//  TheaTask.swift
//  Thea
//
//  SwiftData model for task/todo management with priorities, due dates, and tracking.
//

import Foundation
import SwiftData
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - Task Priority

enum TheaTaskPriority: Int, Codable, CaseIterable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var icon: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "minus"
        case .high: "arrow.up"
        case .urgent: "exclamationmark.2"
        }
    }

    var color: String {
        switch self {
        case .low: "gray"
        case .medium: "blue"
        case .high: "orange"
        case .urgent: "red"
        }
    }

    static func < (lhs: TheaTaskPriority, rhs: TheaTaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Task Category

enum TheaTaskCategory: String, Codable, CaseIterable, Sendable {
    case personal = "Personal"
    case work = "Work"
    case health = "Health"
    case finance = "Finance"
    case learning = "Learning"
    case home = "Home"
    case errands = "Errands"
    case project = "Project"

    var icon: String {
        switch self {
        case .personal: "person.fill"
        case .work: "briefcase.fill"
        case .health: "heart.fill"
        case .finance: "creditcard.fill"
        case .learning: "book.fill"
        case .home: "house.fill"
        case .errands: "cart.fill"
        case .project: "folder.fill"
        }
    }
}

// MARK: - Task Model

@Model
final class TheaTask {
    var id: UUID
    var title: String
    var details: String
    var isCompleted: Bool
    var priorityRaw: Int
    var categoryRaw: String
    var dueDate: Date?
    var completedDate: Date?
    var createdDate: Date
    var updatedDate: Date
    var reminderDate: Date?
    var isRecurring: Bool
    var recurringInterval: String?
    var tags: [String]
    var parentTaskID: UUID?
    var progress: Double

    init(
        title: String,
        details: String = "",
        priority: TheaTaskPriority = .medium,
        category: TheaTaskCategory = .personal,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        tags: [String] = [],
        parentTaskID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.isCompleted = false
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
        self.dueDate = dueDate
        self.completedDate = nil
        self.createdDate = Date()
        self.updatedDate = Date()
        self.reminderDate = reminderDate
        self.isRecurring = false
        self.recurringInterval = nil
        self.tags = tags
        self.parentTaskID = parentTaskID
        self.progress = 0.0
    }

    var priority: TheaTaskPriority {
        get { TheaTaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var category: TheaTaskCategory {
        get { TheaTaskCategory(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }

    var isDueToday: Bool {
        guard let dueDate, !isCompleted else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueThisWeek: Bool {
        guard let dueDate, !isCompleted else { return false }
        return Calendar.current.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    func markCompleted() {
        isCompleted = true
        completedDate = Date()
        progress = 1.0
        updatedDate = Date()
    }

    func markIncomplete() {
        isCompleted = false
        completedDate = nil
        progress = 0.0
        updatedDate = Date()
    }
}

// MARK: - Task Manager

@MainActor
final class TheaTaskManager: ObservableObject {
    static let shared = TheaTaskManager()

    @Published var tasks: [TheaTask] = []
    private var modelContext: ModelContext?

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchTasks()
    }

    func fetchTasks() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<TheaTask>(
            sortBy: [
                SortDescriptor(\.priorityRaw, order: .reverse),
                SortDescriptor(\.dueDate, order: .forward),
                SortDescriptor(\.createdDate, order: .reverse)
            ]
        )
        tasks = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addTask(
        title: String,
        details: String = "",
        priority: TheaTaskPriority = .medium,
        category: TheaTaskCategory = .personal,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        tags: [String] = []
    ) {
        guard let modelContext else { return }
        let task = TheaTask(
            title: title,
            details: details,
            priority: priority,
            category: category,
            dueDate: dueDate,
            reminderDate: reminderDate,
            tags: tags
        )
        modelContext.insert(task)
        try? modelContext.save()

        if let reminderDate {
            scheduleReminder(for: task, at: reminderDate)
        }

        fetchTasks()
    }

    func toggleCompletion(_ task: TheaTask) {
        if task.isCompleted {
            task.markIncomplete()
        } else {
            task.markCompleted()
        }
        try? modelContext?.save()
        fetchTasks()
    }

    func deleteTask(_ task: TheaTask) {
        guard let modelContext else { return }
        cancelReminder(for: task)
        modelContext.delete(task)
        try? modelContext.save()
        fetchTasks()
    }

    func updateTask(_ task: TheaTask) {
        task.updatedDate = Date()
        try? modelContext?.save()
        fetchTasks()
    }

    // MARK: - Filtered Access

    var pendingTasks: [TheaTask] {
        tasks.filter { !$0.isCompleted }
    }

    var completedTasks: [TheaTask] {
        tasks.filter(\.isCompleted)
    }

    var overdueTasks: [TheaTask] {
        tasks.filter(\.isOverdue)
    }

    var todayTasks: [TheaTask] {
        tasks.filter(\.isDueToday)
    }

    var thisWeekTasks: [TheaTask] {
        tasks.filter(\.isDueThisWeek)
    }

    func tasks(for category: TheaTaskCategory) -> [TheaTask] {
        tasks.filter { $0.category == category }
    }

    // MARK: - Statistics

    var completionRate: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = Double(tasks.filter(\.isCompleted).count)
        return completed / Double(tasks.count)
    }

    var tasksCompletedToday: Int {
        tasks.filter { task in
            guard let completedDate = task.completedDate else { return false }
            return Calendar.current.isDateInToday(completedDate)
        }.count
    }

    var currentStreak: Int {
        var streak = 0
        var date = Date()
        let calendar = Calendar.current

        while true {
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let completedInDay = tasks.contains { task in
                guard let completedDate = task.completedDate else { return false }
                return completedDate >= dayStart && completedDate < dayEnd
            }

            if completedInDay {
                streak += 1
                date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Reminders

    #if canImport(UserNotifications)
    private func scheduleReminder(for task: TheaTask, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.title
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task-\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule reminder: \(error.localizedDescription)")
            }
        }
    }

    private func cancelReminder(for task: TheaTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["task-\(task.id.uuidString)"]
        )
    }
    #else
    private func scheduleReminder(for _: TheaTask, at _: Date) {}
    private func cancelReminder(for _: TheaTask) {}
    #endif
}
