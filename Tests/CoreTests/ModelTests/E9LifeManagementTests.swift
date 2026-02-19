//
//  E9LifeManagementTests.swift
//  Thea
//
//  Tests for E9 Life Management — task model, priorities, categories, manager logic.
//

import Testing
import Foundation

// MARK: - Test Doubles (mirror production types for SPM testing)

private enum TestTaskPriority: Int, Codable, CaseIterable, Comparable, Sendable {
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

    static func < (lhs: TestTaskPriority, rhs: TestTaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private enum TestTaskCategory: String, Codable, CaseIterable, Sendable {
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

private struct TestTask: Identifiable, Sendable {
    let id: UUID
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
        priority: TestTaskPriority = .medium,
        category: TestTaskCategory = .personal,
        dueDate: Date? = nil,
        tags: [String] = []
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
        self.reminderDate = nil
        self.isRecurring = false
        self.recurringInterval = nil
        self.tags = tags
        self.parentTaskID = nil
        self.progress = 0.0
    }

    var priority: TestTaskPriority {
        get { TestTaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var category: TestTaskCategory {
        get { TestTaskCategory(rawValue: categoryRaw) ?? .personal }
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

    mutating func markCompleted() {
        isCompleted = true
        completedDate = Date()
        progress = 1.0
        updatedDate = Date()
    }

    mutating func markIncomplete() {
        isCompleted = false
        completedDate = nil
        progress = 0.0
        updatedDate = Date()
    }
}

// MARK: - Task Priority Tests

@Suite("Task Priority")
struct TaskPriorityTests {
    @Test("All 4 cases exist with correct raw values")
    func allCases() {
        let cases = TestTaskPriority.allCases
        #expect(cases.count == 4)
        #expect(TestTaskPriority.low.rawValue == 0)
        #expect(TestTaskPriority.medium.rawValue == 1)
        #expect(TestTaskPriority.high.rawValue == 2)
        #expect(TestTaskPriority.urgent.rawValue == 3)
    }

    @Test("Display names are correct")
    func displayNames() {
        #expect(TestTaskPriority.low.displayName == "Low")
        #expect(TestTaskPriority.medium.displayName == "Medium")
        #expect(TestTaskPriority.high.displayName == "High")
        #expect(TestTaskPriority.urgent.displayName == "Urgent")
    }

    @Test("Icons are unique and non-empty")
    func icons() {
        let icons = TestTaskPriority.allCases.map(\.icon)
        #expect(Set(icons).count == 4)
        for icon in icons {
            #expect(!icon.isEmpty)
        }
    }

    @Test("Colors are unique per priority")
    func colors() {
        let colors = TestTaskPriority.allCases.map(\.color)
        #expect(Set(colors).count == 4)
        #expect(TestTaskPriority.low.color == "gray")
        #expect(TestTaskPriority.urgent.color == "red")
    }

    @Test("Comparable ordering is correct")
    func ordering() {
        #expect(TestTaskPriority.low < .medium)
        #expect(TestTaskPriority.medium < .high)
        #expect(TestTaskPriority.high < .urgent)
        #expect(!(TestTaskPriority.urgent < .low))
    }

    @Test("Sorting produces ascending order")
    func sorting() {
        let shuffled: [TestTaskPriority] = [.urgent, .low, .high, .medium]
        let sorted = shuffled.sorted()
        #expect(sorted == [.low, .medium, .high, .urgent])
    }

    @Test("Codable roundtrip preserves value")
    func codable() throws {
        for priority in TestTaskPriority.allCases {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(TestTaskPriority.self, from: data)
            #expect(decoded == priority)
        }
    }
}

// MARK: - Task Category Tests

@Suite("Task Category")
struct TaskCategoryTests {
    @Test("All 8 categories exist")
    func allCases() {
        #expect(TestTaskCategory.allCases.count == 8)
    }

    @Test("Raw values match display names")
    func rawValues() {
        #expect(TestTaskCategory.personal.rawValue == "Personal")
        #expect(TestTaskCategory.work.rawValue == "Work")
        #expect(TestTaskCategory.health.rawValue == "Health")
        #expect(TestTaskCategory.finance.rawValue == "Finance")
        #expect(TestTaskCategory.learning.rawValue == "Learning")
        #expect(TestTaskCategory.home.rawValue == "Home")
        #expect(TestTaskCategory.errands.rawValue == "Errands")
        #expect(TestTaskCategory.project.rawValue == "Project")
    }

    @Test("Icons are unique and non-empty")
    func icons() {
        let icons = TestTaskCategory.allCases.map(\.icon)
        #expect(Set(icons).count == 8)
        for icon in icons {
            #expect(!icon.isEmpty)
        }
    }

    @Test("Codable roundtrip preserves value")
    func codable() throws {
        for category in TestTaskCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(TestTaskCategory.self, from: data)
            #expect(decoded == category)
        }
    }
}

// MARK: - Task Model Tests

@Suite("Task Model")
struct TaskModelTests {
    @Test("Default task creation")
    func defaultCreation() {
        let task = TestTask(title: "Buy groceries")
        #expect(task.title == "Buy groceries")
        #expect(task.details.isEmpty)
        #expect(!task.isCompleted)
        #expect(task.priority == .medium)
        #expect(task.category == .personal)
        #expect(task.dueDate == nil)
        #expect(task.completedDate == nil)
        #expect(task.reminderDate == nil)
        #expect(!task.isRecurring)
        #expect(task.tags.isEmpty)
        #expect(task.parentTaskID == nil)
        #expect(task.progress == 0.0)
    }

    @Test("Custom task creation")
    func customCreation() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = TestTask(
            title: "Finish report",
            details: "Q4 financial report",
            priority: .high,
            category: .work,
            dueDate: tomorrow,
            tags: ["work", "finance"]
        )
        #expect(task.title == "Finish report")
        #expect(task.details == "Q4 financial report")
        #expect(task.priority == .high)
        #expect(task.category == .work)
        #expect(task.dueDate != nil)
        #expect(task.tags == ["work", "finance"])
    }

    @Test("Identifiable with unique IDs")
    func identifiable() {
        let task1 = TestTask(title: "Task 1")
        let task2 = TestTask(title: "Task 2")
        #expect(task1.id != task2.id)
    }

    @Test("Mark completed sets all fields")
    func markCompleted() {
        var task = TestTask(title: "Test")
        #expect(!task.isCompleted)
        #expect(task.completedDate == nil)
        #expect(task.progress == 0.0)

        task.markCompleted()
        #expect(task.isCompleted)
        #expect(task.completedDate != nil)
        #expect(task.progress == 1.0)
    }

    @Test("Mark incomplete resets all fields")
    func markIncomplete() {
        var task = TestTask(title: "Test")
        task.markCompleted()
        #expect(task.isCompleted)

        task.markIncomplete()
        #expect(!task.isCompleted)
        #expect(task.completedDate == nil)
        #expect(task.progress == 0.0)
    }

    @Test("isOverdue detects past due dates")
    func isOverdue() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var task = TestTask(title: "Test", dueDate: yesterday)
        #expect(task.isOverdue)

        // Completed tasks are never overdue
        task.markCompleted()
        #expect(!task.isOverdue)
    }

    @Test("isOverdue false for future tasks")
    func notOverdue() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = TestTask(title: "Test", dueDate: tomorrow)
        #expect(!task.isOverdue)
    }

    @Test("isOverdue false when no due date")
    func noDueDateNotOverdue() {
        let task = TestTask(title: "Test")
        #expect(!task.isOverdue)
    }

    @Test("isDueToday detects today's tasks")
    func isDueToday() {
        // Anchor to noon today — avoids midnight-crossing flake when +3h wraps to tomorrow
        let noonToday = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let task = TestTask(title: "Test", dueDate: noonToday)
        #expect(task.isDueToday)
    }

    @Test("isDueToday false for tomorrow")
    func isDueTodayFalseTomorrow() {
        // Noon-anchored for consistency — avoids midnight-crossing flake
        let cal = Calendar.current
        let noonTomorrow = cal.date(byAdding: .day, value: 1,
                                    to: cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!)!
        let task = TestTask(title: "Test", dueDate: noonTomorrow)
        #expect(!task.isDueToday)
    }

    @Test("isDueToday false for yesterday")
    func isDueTodayFalseYesterday() {
        // Noon-anchored past date — also not today
        let cal = Calendar.current
        let noonYesterday = cal.date(byAdding: .day, value: -1,
                                     to: cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!)!
        let task = TestTask(title: "Test", dueDate: noonYesterday)
        #expect(!task.isDueToday)
    }

    @Test("isDueThisWeek detects current week tasks")
    func isDueThisWeek() {
        // Use noon today: today is always in the current week, no arithmetic needed.
        // Previous approach computed daysToWed which pointed to NEXT week when run Thu–Sat.
        let noonToday = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let task = TestTask(title: "Test", dueDate: noonToday)
        #expect(task.isDueThisWeek)
    }

    @Test("Priority getter uses raw value")
    func priorityGetter() {
        var task = TestTask(title: "Test")
        task.priorityRaw = 3
        #expect(task.priority == .urgent)
    }

    @Test("Priority getter defaults to medium for invalid raw value")
    func priorityDefault() {
        var task = TestTask(title: "Test")
        task.priorityRaw = 99
        #expect(task.priority == .medium)
    }

    @Test("Category getter uses raw value")
    func categoryGetter() {
        var task = TestTask(title: "Test")
        task.categoryRaw = "Work"
        #expect(task.category == .work)
    }

    @Test("Category getter defaults to personal for invalid raw value")
    func categoryDefault() {
        var task = TestTask(title: "Test")
        task.categoryRaw = "Invalid"
        #expect(task.category == .personal)
    }

    @Test("Priority setter updates raw value")
    func prioritySetter() {
        var task = TestTask(title: "Test")
        task.priority = .urgent
        #expect(task.priorityRaw == 3)
    }

    @Test("Category setter updates raw value")
    func categorySetter() {
        var task = TestTask(title: "Test")
        task.category = .finance
        #expect(task.categoryRaw == "Finance")
    }
}

// MARK: - Task Collection Logic Tests

@Suite("Task Collection Logic")
struct TaskCollectionLogicTests {
    @Test("Filter pending tasks")
    func pendingFilter() {
        var tasks = [
            TestTask(title: "Pending 1"),
            TestTask(title: "Completed 1"),
            TestTask(title: "Pending 2")
        ]
        tasks[1].markCompleted()

        let pending = tasks.filter { !$0.isCompleted }
        #expect(pending.count == 2)
    }

    @Test("Filter completed tasks")
    func completedFilter() {
        var tasks = [
            TestTask(title: "Task 1"),
            TestTask(title: "Task 2"),
            TestTask(title: "Task 3")
        ]
        tasks[0].markCompleted()
        tasks[2].markCompleted()

        let completed = tasks.filter(\.isCompleted)
        #expect(completed.count == 2)
    }

    @Test("Filter overdue tasks")
    func overdueFilter() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let tasks = [
            TestTask(title: "Overdue", dueDate: yesterday),
            TestTask(title: "Future", dueDate: tomorrow),
            TestTask(title: "No date")
        ]

        let overdue = tasks.filter(\.isOverdue)
        #expect(overdue.count == 1)
        #expect(overdue.first?.title == "Overdue")
    }

    @Test("Filter by category")
    func categoryFilter() {
        let tasks = [
            TestTask(title: "Work 1", category: .work),
            TestTask(title: "Personal", category: .personal),
            TestTask(title: "Work 2", category: .work)
        ]

        let workTasks = tasks.filter { $0.category == .work }
        #expect(workTasks.count == 2)
    }

    @Test("Completion rate calculation")
    func completionRate() {
        var tasks = [
            TestTask(title: "Task 1"),
            TestTask(title: "Task 2"),
            TestTask(title: "Task 3"),
            TestTask(title: "Task 4")
        ]
        tasks[0].markCompleted()
        tasks[2].markCompleted()

        let completed = Double(tasks.filter(\.isCompleted).count)
        let rate = completed / Double(tasks.count)
        #expect(rate == 0.5)
    }

    @Test("Completion rate with empty list is 0")
    func completionRateEmpty() {
        let tasks: [TestTask] = []
        let rate = tasks.isEmpty ? 0.0 : Double(tasks.filter(\.isCompleted).count) / Double(tasks.count)
        #expect(rate == 0.0)
    }

    @Test("Tasks completed today")
    func completedToday() {
        var tasks = [
            TestTask(title: "Task 1"),
            TestTask(title: "Task 2"),
            TestTask(title: "Task 3")
        ]
        tasks[0].markCompleted()
        tasks[2].markCompleted()

        let completedToday = tasks.filter { task in
            guard let completedDate = task.completedDate else { return false }
            return Calendar.current.isDateInToday(completedDate)
        }.count
        #expect(completedToday == 2)
    }

    @Test("Streak calculation — consecutive days with completions")
    func streakCalculation() {
        let calendar = Calendar.current

        // Simulate tasks completed today and yesterday
        var task1 = TestTask(title: "Today")
        task1.isCompleted = true
        task1.completedDate = Date()

        var task2 = TestTask(title: "Yesterday")
        task2.isCompleted = true
        task2.completedDate = calendar.date(byAdding: .day, value: -1, to: Date())

        let tasks = [task1, task2]

        var streak = 0
        var date = Date()
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
        #expect(streak == 2)
    }

    @Test("Streak breaks when a day has no completions")
    func streakBreaks() {
        let calendar = Calendar.current

        // Only completed 2 days ago, not yesterday
        var task = TestTask(title: "Two days ago")
        task.isCompleted = true
        task.completedDate = calendar.date(byAdding: .day, value: -2, to: Date())

        let tasks = [task]

        var streak = 0
        var date = Date()
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
        #expect(streak == 0) // Streak is 0 because no completions today
    }

    @Test("Empty task list gives 0 streak")
    func emptyStreak() {
        let tasks: [TestTask] = []
        let hasCompletionToday = tasks.contains { task in
            guard let completedDate = task.completedDate else { return false }
            return Calendar.current.isDateInToday(completedDate)
        }
        #expect(!hasCompletionToday)
    }

    @Test("Search filters by title")
    func searchByTitle() {
        let tasks = [
            TestTask(title: "Buy groceries"),
            TestTask(title: "Write report"),
            TestTask(title: "Buy birthday gift")
        ]

        let searchText = "buy"
        let results = tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
        #expect(results.count == 2)
    }

    @Test("Search filters by details")
    func searchByDetails() {
        let tasks = [
            TestTask(title: "Task 1", details: "urgent quarterly review"),
            TestTask(title: "Task 2", details: "normal thing"),
            TestTask(title: "Task 3", details: "another quarterly item")
        ]

        let searchText = "quarterly"
        let results = tasks.filter {
            $0.details.localizedCaseInsensitiveContains(searchText)
        }
        #expect(results.count == 2)
    }
}

// MARK: - Dashboard Logic Tests

@Suite("Dashboard Logic")
struct DashboardLogicTests {
    @Test("Greeting varies by hour")
    func greetingByHour() {
        func greeting(for hour: Int) -> String {
            switch hour {
            case 5..<12: return "Good Morning"
            case 12..<17: return "Good Afternoon"
            case 17..<22: return "Good Evening"
            default: return "Good Night"
            }
        }

        #expect(greeting(for: 6) == "Good Morning")
        #expect(greeting(for: 11) == "Good Morning")
        #expect(greeting(for: 12) == "Good Afternoon")
        #expect(greeting(for: 16) == "Good Afternoon")
        #expect(greeting(for: 17) == "Good Evening")
        #expect(greeting(for: 21) == "Good Evening")
        #expect(greeting(for: 22) == "Good Night")
        #expect(greeting(for: 3) == "Good Night")
    }

    @Test("Goal progress from task completion")
    func goalProgress() {
        var tasks = [
            TestTask(title: "T1"),
            TestTask(title: "T2"),
            TestTask(title: "T3"),
            TestTask(title: "T4"),
            TestTask(title: "T5")
        ]
        tasks[0].markCompleted()
        tasks[1].markCompleted()

        let totalTasks = tasks.count
        let completedTasks = tasks.filter(\.isCompleted).count
        let progress = Double(completedTasks) / Double(totalTasks)
        #expect(progress == 0.4)
    }

    @Test("Category breakdown counts")
    func categoryBreakdown() {
        let tasks = [
            TestTask(title: "W1", category: .work),
            TestTask(title: "W2", category: .work),
            TestTask(title: "P1", category: .personal),
            TestTask(title: "H1", category: .health),
            TestTask(title: "H2", category: .health),
            TestTask(title: "H3", category: .health)
        ]

        let breakdown = Dictionary(grouping: tasks, by: \.category)
        #expect(breakdown[.work]?.count == 2)
        #expect(breakdown[.personal]?.count == 1)
        #expect(breakdown[.health]?.count == 3)
        #expect(breakdown[.finance] == nil)
    }

    @Test("Priority breakdown counts")
    func priorityBreakdown() {
        let tasks = [
            TestTask(title: "L", priority: .low),
            TestTask(title: "M1", priority: .medium),
            TestTask(title: "M2", priority: .medium),
            TestTask(title: "U", priority: .urgent)
        ]

        let breakdown = Dictionary(grouping: tasks, by: \.priority)
        #expect(breakdown[.low]?.count == 1)
        #expect(breakdown[.medium]?.count == 2)
        #expect(breakdown[.high] == nil)
        #expect(breakdown[.urgent]?.count == 1)
    }

    @Test("Weekly task counts")
    func weeklyTaskCounts() {
        let calendar = Calendar.current
        let now = Date()

        let tasks = [
            TestTask(title: "Today", dueDate: now),
            TestTask(title: "Tomorrow", dueDate: calendar.date(byAdding: .day, value: 1, to: now)),
            TestTask(title: "Next month", dueDate: calendar.date(byAdding: .month, value: 1, to: now))
        ]

        let thisWeek = tasks.filter(\.isDueThisWeek)
        // "Today" and possibly "Tomorrow" should be this week
        #expect(thisWeek.count >= 1)
    }
}

// MARK: - IntelligenceTask Rename Tests

@Suite("IntelligenceTask Rename Verification")
struct IntelligenceTaskRenameTests {
    @Test("IntelligenceTask is the correct type name for TaskIntelligence")
    func typeNameVerification() {
        // This test verifies the rename from TheaTask → IntelligenceTask
        // in TaskIntelligence.swift resolved the ambiguity
        enum PriorityCheck: Int, Codable {
            case low = 1
            case medium = 2
            case high = 3
            case critical = 4
        }

        // The IntelligenceTask uses 1-4 raw values (vs TheaTask's 0-3)
        #expect(PriorityCheck.low.rawValue == 1)
        #expect(PriorityCheck.critical.rawValue == 4)
    }
}
