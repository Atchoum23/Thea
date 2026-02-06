// TaskIntelligence.swift
// THEA - Intelligent Task & Deadline Management
// Created by Claude - February 2026
//
// REPLACES external task managers (Todoist, Asana) with native Apple integration
// plus THEA's cross-system intelligence.
//
// Features:
// - Natural language task parsing ("call mom tomorrow at 5pm")
// - Smart deadline awareness affecting Focus Mode behavior
// - Integration with Apple Reminders & Calendar (via EventKit)
// - Project/context grouping with automatic categorization
// - Urgency scoring based on deadline proximity + task importance
// - Proactive notifications ("You have a deadline in 2 hours")
// - Learning from completion patterns

import Foundation
import EventKit
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

// MARK: - Task Model

/// A THEA-managed task with full intelligence context
public struct TheaTask: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var createdAt: Date
    public var dueDate: Date?
    public var dueTime: Date? // Specific time if set
    public var completedAt: Date?

    // Priority & Urgency
    public var priority: Priority
    public var urgencyScore: Double // 0.0 - 1.0, dynamically calculated
    public var isTimeBlocking: Bool // Should block time in calendar?

    // Categorization
    public var project: String?
    public var contexts: [String] // @home, @work, @phone, @computer
    public var tags: [String]

    // Recurrence
    public var recurrence: Recurrence?

    // Apple Integration
    public var reminderIdentifier: String? // EKReminder ID
    public var calendarEventIdentifier: String? // EKEvent ID

    // Intelligence
    public var estimatedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var relatedContactIds: [String] // People involved
    public var relatedMessageIds: [String] // Messages that spawned this task
    public var aiExtracted: Bool // Was this auto-extracted from a message?

    // Focus Mode Integration
    public var blocksFocusMode: Bool // If urgent, can break through Focus
    public var notifyBeforeMinutes: Int // Alert X minutes before due

    public enum Priority: Int, Codable, Sendable, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public struct Recurrence: Codable, Sendable {
        public let frequency: Frequency
        public let interval: Int // Every X days/weeks/months
        public let daysOfWeek: [Int]? // For weekly
        public let endDate: Date?
        public let maxOccurrences: Int?

        public enum Frequency: String, Codable, Sendable {
            case daily, weekly, monthly, yearly
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        dueTime: Date? = nil,
        priority: Priority = .medium,
        project: String? = nil,
        contexts: [String] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.completedAt = nil
        self.priority = priority
        self.urgencyScore = 0.5
        self.isTimeBlocking = false
        self.project = project
        self.contexts = contexts
        self.tags = tags
        self.recurrence = nil
        self.reminderIdentifier = nil
        self.calendarEventIdentifier = nil
        self.estimatedDuration = nil
        self.actualDuration = nil
        self.relatedContactIds = []
        self.relatedMessageIds = []
        self.aiExtracted = false
        self.blocksFocusMode = priority == .critical
        self.notifyBeforeMinutes = 30
    }
}

// MARK: - Task Intelligence Actor

public actor TaskIntelligence {
    public static let shared = TaskIntelligence()

    // MARK: - Properties

    private var tasks: [UUID: TheaTask] = [:]
    private var projects: [String: ProjectInfo] = [:]
    private var completionPatterns: [String: CompletionPattern] = [:]
    private let eventStore = EKEventStore()
    private var hasCalendarAccess = false
    private var hasRemindersAccess = false

    // Callbacks
    private var onTaskDueSoon: ((TheaTask, TimeInterval) -> Void)?
    private var onTaskOverdue: ((TheaTask) -> Void)?
    private var onUrgentTaskDetected: ((TheaTask) -> Void)?

    // MARK: - Types

    public struct ProjectInfo: Codable, Sendable {
        public let name: String
        public var taskCount: Int
        public var completedCount: Int
        public var averageCompletionTime: TimeInterval?
        public var color: String?
        public var icon: String?
    }

    public struct CompletionPattern: Codable, Sendable {
        public var totalTasks: Int
        public var completedOnTime: Int
        public var averageDelayDays: Double
        public var preferredCompletionHour: Int?
        public var preferredCompletionDay: Int? // Day of week
    }

    // MARK: - Initialization

    private init() {}

    public func configure(
        onTaskDueSoon: @escaping @Sendable (TheaTask, TimeInterval) -> Void,
        onTaskOverdue: @escaping @Sendable (TheaTask) -> Void,
        onUrgentTaskDetected: @escaping @Sendable (TheaTask) -> Void
    ) {
        self.onTaskDueSoon = onTaskDueSoon
        self.onTaskOverdue = onTaskOverdue
        self.onUrgentTaskDetected = onUrgentTaskDetected
    }

    // MARK: - EventKit Access

    public func requestAccess() async -> Bool {
        // Request calendar access
        do {
            hasCalendarAccess = try await eventStore.requestFullAccessToEvents()
            hasRemindersAccess = try await eventStore.requestFullAccessToReminders()
            return hasCalendarAccess && hasRemindersAccess
        } catch {
            print("[TaskIntelligence] Access request failed: \(error)")
            return false
        }
    }

    // MARK: - Natural Language Task Parsing

    /// Parse natural language into a task
    /// Examples:
    /// - "Call mom tomorrow at 5pm"
    /// - "Submit report by Friday high priority"
    /// - "Buy groceries @errands #shopping"
    /// - "Review PR every Monday"
    public func parseNaturalLanguage(_ input: String) async -> TheaTask {
        var task = TheaTask(title: input)

        let lowercased = input.lowercased()

        // Extract date/time
        if let (dueDate, dueTime) = extractDateTime(from: input) {
            task.dueDate = dueDate
            task.dueTime = dueTime
        }

        // Extract priority
        task.priority = extractPriority(from: lowercased)

        // Extract contexts (@home, @work, etc.)
        task.contexts = extractContexts(from: input)

        // Extract tags (#shopping, #urgent, etc.)
        task.tags = extractTags(from: input)

        // Extract project (project:name or [ProjectName])
        task.project = extractProject(from: input)

        // Extract recurrence
        task.recurrence = extractRecurrence(from: lowercased)

        // Clean up title (remove parsed elements)
        task.title = cleanTitle(input, task: task)

        // Extract related contacts
        task.relatedContactIds = await extractContacts(from: input)

        // Calculate initial urgency
        task.urgencyScore = calculateUrgencyScore(for: task)

        return task
    }

    private func extractDateTime(from input: String) -> (Date?, Date?)? {
        let lowercased = input.lowercased()
        let calendar = Calendar.current
        let now = Date()

        var date: Date?
        var time: Date?

        // Relative dates
        if lowercased.contains("today") {
            date = now
        } else if lowercased.contains("tomorrow") {
            date = calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercased.contains("next week") {
            date = calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if lowercased.contains("next month") {
            date = calendar.date(byAdding: .month, value: 1, to: now)
        }

        // Day names
        let days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in days.enumerated() {
            if lowercased.contains(day) {
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = index + 1 - currentWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                date = calendar.date(byAdding: .day, value: daysToAdd, to: now)
                break
            }
        }

        // Time extraction (e.g., "at 5pm", "by 3:30", "14:00")
        let timePatterns = [
            "at (\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?",
            "by (\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?",
            "(\\d{1,2}):(\\d{2})\\s*(am|pm)?"
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

                var hour = 0
                var minute = 0

                if let hourRange = Range(match.range(at: 1), in: input) {
                    hour = Int(input[hourRange]) ?? 0
                }
                if match.numberOfRanges > 2, let minuteRange = Range(match.range(at: 2), in: input) {
                    minute = Int(input[minuteRange]) ?? 0
                }
                if match.numberOfRanges > 3, let ampmRange = Range(match.range(at: 3), in: input) {
                    let ampm = String(input[ampmRange]).lowercased()
                    if ampm == "pm" && hour < 12 { hour += 12 }
                    if ampm == "am" && hour == 12 { hour = 0 }
                }

                var components = calendar.dateComponents([.year, .month, .day], from: date ?? now)
                components.hour = hour
                components.minute = minute
                time = calendar.date(from: components)
                break
            }
        }

        if date != nil || time != nil {
            return (date, time)
        }
        return nil
    }

    private func extractPriority(from input: String) -> TheaTask.Priority {
        if input.contains("critical") || input.contains("urgent") || input.contains("asap") || input.contains("!!!") {
            return .critical
        } else if input.contains("high priority") || input.contains("important") || input.contains("!!") {
            return .high
        } else if input.contains("low priority") || input.contains("whenever") || input.contains("someday") {
            return .low
        }
        return .medium
    }

    private func extractContexts(from input: String) -> [String] {
        var contexts: [String] = []
        let pattern = "@(\\w+)"

        if let regex = try? NSRegularExpression(pattern: pattern),
           let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input)) as [NSTextCheckingResult]? {
            for match in matches {
                if let range = Range(match.range(at: 1), in: input) {
                    contexts.append(String(input[range]))
                }
            }
        }

        return contexts
    }

    private func extractTags(from input: String) -> [String] {
        var tags: [String] = []
        let pattern = "#(\\w+)"

        if let regex = try? NSRegularExpression(pattern: pattern),
           let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input)) as [NSTextCheckingResult]? {
            for match in matches {
                if let range = Range(match.range(at: 1), in: input) {
                    tags.append(String(input[range]))
                }
            }
        }

        return tags
    }

    private func extractProject(from input: String) -> String? {
        // Match project:name or [ProjectName]
        let patterns = ["project:(\\w+)", "\\[([^\\]]+)\\]"]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
               let range = Range(match.range(at: 1), in: input) {
                return String(input[range])
            }
        }

        return nil
    }

    private func extractRecurrence(from input: String) -> TheaTask.Recurrence? {
        if input.contains("every day") || input.contains("daily") {
            return TheaTask.Recurrence(frequency: .daily, interval: 1, daysOfWeek: nil, endDate: nil, maxOccurrences: nil)
        } else if input.contains("every week") || input.contains("weekly") {
            return TheaTask.Recurrence(frequency: .weekly, interval: 1, daysOfWeek: nil, endDate: nil, maxOccurrences: nil)
        } else if input.contains("every month") || input.contains("monthly") {
            return TheaTask.Recurrence(frequency: .monthly, interval: 1, daysOfWeek: nil, endDate: nil, maxOccurrences: nil)
        }

        // "every Monday"
        let days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, day) in days.enumerated() {
            if input.contains("every \(day)") {
                return TheaTask.Recurrence(frequency: .weekly, interval: 1, daysOfWeek: [index + 1], endDate: nil, maxOccurrences: nil)
            }
        }

        return nil
    }

    private func cleanTitle(_ input: String, task: TheaTask) -> String {
        var title = input

        // Remove time expressions
        let timePatterns = [
            "\\s*(today|tomorrow|next week|next month)",
            "\\s*at \\d{1,2}(:\\d{2})?\\s*(am|pm)?",
            "\\s*by \\d{1,2}(:\\d{2})?\\s*(am|pm)?",
            "\\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday)",
            "\\s*(high priority|low priority|critical|urgent|important|asap)",
            "\\s*@\\w+",
            "\\s*#\\w+",
            "\\s*project:\\w+",
            "\\s*\\[[^\\]]+\\]",
            "\\s*(every day|daily|every week|weekly|every month|monthly)",
            "\\s*every (monday|tuesday|wednesday|thursday|friday|saturday|sunday)",
            "\\s*!{2,3}"
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                title = regex.stringByReplacingMatches(in: title, range: NSRange(title.startIndex..., in: title), withTemplate: "")
            }
        }

        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractContacts(from input: String) async -> [String] {
        // Would use Contacts framework to match names
        []
    }

    // MARK: - Urgency Calculation

    public func calculateUrgencyScore(for task: TheaTask) -> Double {
        var score: Double = 0.0

        // Base priority score
        switch task.priority {
        case .critical: score += 0.4
        case .high: score += 0.3
        case .medium: score += 0.2
        case .low: score += 0.1
        }

        // Time-based urgency
        if let dueDate = task.dueDate {
            let hoursUntilDue = dueDate.timeIntervalSinceNow / 3600

            if hoursUntilDue < 0 {
                // Overdue!
                score += 0.5
            } else if hoursUntilDue < 2 {
                score += 0.4
            } else if hoursUntilDue < 24 {
                score += 0.3
            } else if hoursUntilDue < 48 {
                score += 0.2
            } else if hoursUntilDue < 168 { // 1 week
                score += 0.1
            }
        }

        // Related to message (someone is waiting)
        if !task.relatedContactIds.isEmpty {
            score += 0.1
        }

        return min(1.0, score)
    }

    // MARK: - Task CRUD

    public func addTask(_ task: TheaTask) async -> TheaTask {
        var newTask = task
        newTask.urgencyScore = calculateUrgencyScore(for: task)

        // Sync to Apple Reminders
        if hasRemindersAccess {
            newTask.reminderIdentifier = await syncToReminders(task)
        }

        // If time-blocking, create calendar event
        if task.isTimeBlocking, hasCalendarAccess {
            newTask.calendarEventIdentifier = await syncToCalendar(task)
        }

        tasks[newTask.id] = newTask

        // Check if urgent
        if newTask.urgencyScore > 0.7 {
            onUrgentTaskDetected?(newTask)
        }

        await saveTasks()
        return newTask
    }

    public func updateTask(_ task: TheaTask) async {
        var updatedTask = task
        updatedTask.urgencyScore = calculateUrgencyScore(for: task)
        tasks[task.id] = updatedTask

        // Update in Reminders
        if let reminderId = task.reminderIdentifier {
            await updateReminder(reminderId, with: task)
        }

        await saveTasks()
    }

    public func completeTask(_ taskId: UUID) async {
        guard var task = tasks[taskId] else { return }

        task.completedAt = Date()

        // Calculate actual duration if we have estimate
        if let startTime = task.createdAt as Date?, task.estimatedDuration != nil {
            task.actualDuration = Date().timeIntervalSince(startTime)
        }

        // Update completion patterns
        await updateCompletionPatterns(for: task)

        // Handle recurrence
        if let recurrence = task.recurrence {
            let nextTask = await createNextRecurrence(from: task, recurrence: recurrence)
            tasks[nextTask.id] = nextTask
        }

        tasks[taskId] = task

        // Mark complete in Reminders
        if let reminderId = task.reminderIdentifier {
            await completeReminder(reminderId)
        }

        await saveTasks()
    }

    public func deleteTask(_ taskId: UUID) async {
        if let task = tasks[taskId], let reminderId = task.reminderIdentifier {
            await deleteReminder(reminderId)
        }
        tasks.removeValue(forKey: taskId)
        await saveTasks()
    }

    // MARK: - Apple Reminders Sync

    private func syncToReminders(_ task: TheaTask) async -> String? {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = task.title
        reminder.notes = task.notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let dueDate = task.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueTime ?? dueDate)
        }

        switch task.priority {
        case .critical: reminder.priority = 1
        case .high: reminder.priority = 5
        case .medium: reminder.priority = 5
        case .low: reminder.priority = 9
        }

        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            print("[TaskIntelligence] Failed to save reminder: \(error)")
            return nil
        }
    }

    private func updateReminder(_ identifier: String, with task: TheaTask) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }

        reminder.title = task.title
        reminder.notes = task.notes

        if let dueDate = task.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: task.dueTime ?? dueDate)
        }

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            print("[TaskIntelligence] Failed to update reminder: \(error)")
        }
    }

    private func completeReminder(_ identifier: String) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        reminder.isCompleted = true

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            print("[TaskIntelligence] Failed to complete reminder: \(error)")
        }
    }

    private func deleteReminder(_ identifier: String) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }

        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            print("[TaskIntelligence] Failed to delete reminder: \(error)")
        }
    }

    // MARK: - Apple Calendar Sync

    private func syncToCalendar(_ task: TheaTask) async -> String? {
        guard let dueDate = task.dueDate else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = task.title
        event.notes = task.notes
        event.startDate = task.dueTime ?? dueDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("[TaskIntelligence] Failed to save calendar event: \(error)")
            return nil
        }
    }

    // MARK: - Recurrence Handling

    private func createNextRecurrence(from task: TheaTask, recurrence: TheaTask.Recurrence) async -> TheaTask {
        var nextTask = task
        nextTask.id = UUID()
        nextTask.completedAt = nil
        nextTask.createdAt = Date()

        if let dueDate = task.dueDate {
            let calendar = Calendar.current
            switch recurrence.frequency {
            case .daily:
                nextTask.dueDate = calendar.date(byAdding: .day, value: recurrence.interval, to: dueDate)
            case .weekly:
                nextTask.dueDate = calendar.date(byAdding: .weekOfYear, value: recurrence.interval, to: dueDate)
            case .monthly:
                nextTask.dueDate = calendar.date(byAdding: .month, value: recurrence.interval, to: dueDate)
            case .yearly:
                nextTask.dueDate = calendar.date(byAdding: .year, value: recurrence.interval, to: dueDate)
            }
        }

        nextTask.reminderIdentifier = nil
        nextTask.calendarEventIdentifier = nil

        return nextTask
    }

    // MARK: - Completion Pattern Learning

    private func updateCompletionPatterns(for task: TheaTask) async {
        let key = task.project ?? "default"
        var pattern = completionPatterns[key] ?? CompletionPattern(
            totalTasks: 0,
            completedOnTime: 0,
            averageDelayDays: 0,
            preferredCompletionHour: nil,
            preferredCompletionDay: nil
        )

        pattern.totalTasks += 1

        if let dueDate = task.dueDate, let completedAt = task.completedAt {
            if completedAt <= dueDate {
                pattern.completedOnTime += 1
            }
            let delayDays = completedAt.timeIntervalSince(dueDate) / 86400
            pattern.averageDelayDays = (pattern.averageDelayDays * Double(pattern.totalTasks - 1) + delayDays) / Double(pattern.totalTasks)
        }

        // Track preferred completion time
        if let completedAt = task.completedAt {
            let hour = Calendar.current.component(.hour, from: completedAt)
            pattern.preferredCompletionHour = hour
            let day = Calendar.current.component(.weekday, from: completedAt)
            pattern.preferredCompletionDay = day
        }

        completionPatterns[key] = pattern
    }

    // MARK: - Deadline Monitoring

    public func startDeadlineMonitoring() async {
        // Check every minute for upcoming deadlines
        Task {
            while true {
                try? await Task.sleep(for: .seconds(60))
                await checkDeadlines()
            }
        }
    }

    private func checkDeadlines() async {
        let now = Date()

        for (_, task) in tasks where task.completedAt == nil {
            guard let dueDate = task.dueDate else { continue }

            let timeUntilDue = dueDate.timeIntervalSince(now)

            if timeUntilDue < 0 {
                // Overdue
                onTaskOverdue?(task)
            } else if timeUntilDue < Double(task.notifyBeforeMinutes) * 60 {
                // Due soon
                onTaskDueSoon?(task, timeUntilDue)
            }
        }
    }

    // MARK: - Queries

    public func getTasksDueToday() -> [TheaTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return tasks.values.filter { task in
            guard let dueDate = task.dueDate, task.completedAt == nil else { return false }
            return dueDate >= today && dueDate < tomorrow
        }.sorted { $0.urgencyScore > $1.urgencyScore }
    }

    public func getOverdueTasks() -> [TheaTask] {
        let now = Date()
        return tasks.values.filter { task in
            guard let dueDate = task.dueDate, task.completedAt == nil else { return false }
            return dueDate < now
        }.sorted { $0.urgencyScore > $1.urgencyScore }
    }

    public func getTasksByProject(_ project: String) -> [TheaTask] {
        tasks.values.filter { $0.project == project && $0.completedAt == nil }
            .sorted { $0.urgencyScore > $1.urgencyScore }
    }

    public func getUrgentTasks(threshold: Double = 0.7) -> [TheaTask] {
        tasks.values.filter { $0.urgencyScore >= threshold && $0.completedAt == nil }
            .sorted { $0.urgencyScore > $1.urgencyScore }
    }

    public func getAllActiveTasks() -> [TheaTask] {
        tasks.values.filter { $0.completedAt == nil }
            .sorted { $0.urgencyScore > $1.urgencyScore }
    }

    // MARK: - AI Task Extraction from Messages

    /// Extract potential tasks from incoming messages
    public func extractTasksFromMessage(_ message: String, from contactId: String?) async -> [TheaTask] {
        var extractedTasks: [TheaTask] = []

        // Patterns that indicate task-like content
        let taskIndicators = [
            "can you", "could you", "please", "need to", "have to", "must",
            "don't forget", "remember to", "make sure", "by tomorrow", "by friday",
            "deadline", "due", "submit", "send", "call", "email", "reply"
        ]

        let lowercased = message.lowercased()

        // Check if message contains task-like content
        var containsTaskIndicator = false
        for indicator in taskIndicators {
            if lowercased.contains(indicator) {
                containsTaskIndicator = true
                break
            }
        }

        if containsTaskIndicator {
            // Parse the message as a potential task
            var task = await parseNaturalLanguage(message)
            task.aiExtracted = true
            if let contactId = contactId {
                task.relatedContactIds = [contactId]
            }

            extractedTasks.append(task)
        }

        return extractedTasks
    }

    // MARK: - Persistence

    private func saveTasks() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let encoded = try? JSONEncoder().encode(Array(tasks.values)) {
            defaults.set(encoded, forKey: "theaTasks")
            defaults.synchronize()
        }
    }

    public func loadTasks() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe"),
           let data = defaults.data(forKey: "theaTasks"),
           let loadedTasks = try? JSONDecoder().decode([TheaTask].self, from: data) {
            for task in loadedTasks {
                tasks[task.id] = task
            }

            // Recalculate urgency scores (they change with time)
            for (id, var task) in tasks {
                task.urgencyScore = calculateUrgencyScore(for: task)
                tasks[id] = task
            }
        }
    }
}
