import Foundation
import OSLog
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(EventKit)
import EventKit
#endif
#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Morning Briefing Engine

/// Generates daily morning briefings at the user's preferred wake time.
/// Combines: calendar events, tasks, health summary, weather, and AI insights.
/// Delivered as a notification and accessible in-app via Life Dashboard.
@MainActor
final class MorningBriefingEngine: ObservableObject {
    static let shared = MorningBriefingEngine()

    @Published var latestBriefing: TheaDailyBriefing?
    @Published var isGenerating = false

    private var lastGeneratedDate: Date?
    private let eventStore = EKEventStore()
    private let logger = Logger(subsystem: "ai.thea.app", category: "MorningBriefingEngine")

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "briefing.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "briefing.enabled") }
    }

    var preferredHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "briefing.hour")
            return stored > 0 ? stored : 7 // Default 7 AM
        }
        set { UserDefaults.standard.set(newValue, forKey: "briefing.hour") }
    }

    private init() {}

    // MARK: - Briefing Generation

    /// Generate the daily briefing if not already generated today.
    func generateIfNeeded() async {
        guard isEnabled else { return }
        let calendar = Calendar.current
        if let last = lastGeneratedDate, calendar.isDateInToday(last) {
            return // Already generated today
        }
        await generate()
    }

    /// Generate a fresh daily briefing.
    func generate() async {
        isGenerating = true
        defer { isGenerating = false }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        var sections: [BriefingSection] = []

        // 1. Date & greeting
        let greeting = TemporalValidator.timeOfDayGreeting(for: now)
        let dateStr = TemporalValidator.formattedToday()
        sections.append(BriefingSection(
            title: "Today",
            icon: "sun.max",
            items: [BriefingItem(text: "\(greeting). It's \(dateStr).", priority: .info)]
        ))

        // 2. Calendar events
        #if canImport(EventKit)
        let calendarItems = await fetchTodayCalendarEvents(from: today)
        if !calendarItems.isEmpty {
            sections.append(BriefingSection(
                title: "Calendar",
                icon: "calendar",
                items: calendarItems
            ))
        }
        #endif

        // 3. Tasks
        let taskItems = fetchTaskSummary()
        if !taskItems.isEmpty {
            sections.append(BriefingSection(
                title: "Tasks",
                icon: "checklist",
                items: taskItems
            ))
        }

        // 4. Health summary
        let healthItems = await fetchHealthSummary()
        if !healthItems.isEmpty {
            sections.append(BriefingSection(
                title: "Health",
                icon: "heart",
                items: healthItems
            ))
        }

        // 5. Financial snapshot
        let financeItems = fetchFinancialSnapshot()
        if !financeItems.isEmpty {
            sections.append(BriefingSection(
                title: "Finance",
                icon: "chart.line.uptrend.xyaxis",
                items: financeItems
            ))
        }

        let briefing = TheaDailyBriefing(
            id: UUID(),
            date: now,
            sections: sections,
            generatedAt: now
        )

        latestBriefing = briefing
        lastGeneratedDate = now
        saveBriefing(briefing)

        // Deliver as notification
        await deliverNotification(briefing)
    }

    // MARK: - Calendar

    #if canImport(EventKit)
    private func fetchTodayCalendarEvents(from startOfDay: Date) async -> [BriefingItem] {
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        do {
            let granted: Bool
            if #available(macOS 14.0, iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            guard granted else { return [] }
        } catch {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            return [BriefingItem(text: "No events scheduled today.", priority: .info)]
        }

        var items: [BriefingItem] = []
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        for event in events.prefix(8) {
            let time = event.isAllDay ? "All day" : timeFormatter.string(from: event.startDate)
            let priority: BriefingItemPriority = event.startDate.timeIntervalSince(Date()) < 3600 ? .high : .normal
            items.append(BriefingItem(
                text: "\(time): \(event.title ?? "Event")",
                priority: priority
            ))
        }

        if events.count > 8 {
            items.append(BriefingItem(text: "... and \(events.count - 8) more events", priority: .info))
        }

        return items
    }
    #endif

    // MARK: - Tasks

    private func fetchTaskSummary() -> [BriefingItem] {
        let manager = TheaTaskManager.shared
        var items: [BriefingItem] = []

        let overdue = manager.overdueTasks
        let today = manager.todayTasks
        let pending = manager.pendingTasks

        if !overdue.isEmpty {
            items.append(BriefingItem(
                text: "\(overdue.count) overdue task\(overdue.count == 1 ? "" : "s") — needs attention",
                priority: .high
            ))
            for task in overdue.prefix(3) {
                items.append(BriefingItem(
                    text: "  • \(task.title) (\(task.priority.displayName))",
                    priority: .high
                ))
            }
        }

        if !today.isEmpty {
            items.append(BriefingItem(
                text: "\(today.count) task\(today.count == 1 ? "" : "s") due today",
                priority: .normal
            ))
            for task in today.prefix(3) {
                items.append(BriefingItem(
                    text: "  • \(task.title)",
                    priority: .normal
                ))
            }
        }

        if items.isEmpty {
            if pending.isEmpty {
                items.append(BriefingItem(text: "All tasks completed! Great job.", priority: .info))
            } else {
                items.append(BriefingItem(text: "\(pending.count) pending task\(pending.count == 1 ? "" : "s"), none due today.", priority: .info))
            }
        }

        let streak = manager.currentStreak
        if streak > 1 {
            items.append(BriefingItem(text: "\(streak)-day completion streak!", priority: .info))
        }

        return items
    }

    // MARK: - Health

    private func fetchHealthSummary() async -> [BriefingItem] {
        #if canImport(HealthKit)
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        var items: [BriefingItem] = []
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        // Steps from yesterday
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now)
            do {
                let steps = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double, Error>) in
                    let query = HKStatisticsQuery(
                        quantityType: stepType,
                        quantitySamplePredicate: predicate,
                        options: .cumulativeSum
                    ) { _, result, error in
                        if let error {
                            cont.resume(throwing: error)
                        } else {
                            let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                            cont.resume(returning: sum)
                        }
                    }
                    store.execute(query)
                }
                if steps > 0 {
                    let formatted = NumberFormatter.localizedString(from: NSNumber(value: Int(steps)), number: .decimal)
                    items.append(BriefingItem(
                        text: "Yesterday: \(formatted) steps",
                        priority: steps < 5000 ? .normal : .info
                    ))
                }
            } catch {
                // HealthKit unavailable — skip silently
            }
        }

        return items
        #else
        return []
        #endif
    }

    // MARK: - Finance

    private func fetchFinancialSnapshot() -> [BriefingItem] {
        let manager = FinancialManager.shared
        var items: [BriefingItem] = []

        // Get recent transactions (last 7 days)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = manager.transactions.filter { $0.date >= weekAgo }

        if !recent.isEmpty {
            let spending = recent.filter { $0.amount < 0 }
            let totalSpent = spending.reduce(0.0) { $0 + abs($1.amount) }
            let formatted = String(format: "%.2f", totalSpent)
            items.append(BriefingItem(
                text: "Last 7 days: \(formatted) spent across \(spending.count) transactions",
                priority: .info
            ))
        }

        let accountCount = manager.accounts.count
        if accountCount > 0 {
            items.append(BriefingItem(
                text: "\(accountCount) account\(accountCount == 1 ? "" : "s") tracked",
                priority: .info
            ))
        }

        return items
    }

    // MARK: - Notification Delivery

    private func deliverNotification(_ briefing: TheaDailyBriefing) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = briefingSummaryText(briefing)
        content.sound = .default
        content.categoryIdentifier = "MORNING_BRIEFING"

        let request = UNNotificationRequest(
            identifier: "morning-briefing-\(briefing.id.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to schedule morning briefing notification: \(error.localizedDescription)")
        }
        #endif
    }

    private func briefingSummaryText(_ briefing: TheaDailyBriefing) -> String {
        var parts: [String] = []

        for section in briefing.sections {
            let highItems = section.items.filter { $0.priority == .high }
            if !highItems.isEmpty {
                parts.append("\(section.title): \(highItems.first?.text ?? "")")
            } else if let first = section.items.first {
                parts.append("\(section.title): \(first.text)")
            }
        }

        return parts.prefix(3).joined(separator: " | ")
    }

    // MARK: - Persistence

    private var briefingURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create briefing directory: \(error.localizedDescription)")
        }
        return dir.appendingPathComponent("latest_briefing.json")
    }

    private func saveBriefing(_ briefing: TheaDailyBriefing) {
        do {
            let data = try JSONEncoder().encode(briefing)
            try data.write(to: briefingURL)
        } catch {
            logger.error("Failed to save briefing to disk: \(error.localizedDescription)")
        }
    }

    func loadSavedBriefing() {
        do {
            let data = try Data(contentsOf: briefingURL)
            let briefing = try JSONDecoder().decode(TheaDailyBriefing.self, from: data)
            latestBriefing = briefing
            lastGeneratedDate = briefing.generatedAt
        } catch {
            logger.error("Failed to load saved briefing: \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

struct TheaDailyBriefing: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let sections: [BriefingSection]
    let generatedAt: Date
}

struct BriefingSection: Codable, Sendable, Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    let items: [BriefingItem]
}

struct BriefingItem: Codable, Sendable, Identifiable {
    let id: UUID
    let text: String
    let priority: BriefingItemPriority

    init(text: String, priority: BriefingItemPriority) {
        self.id = UUID()
        self.text = text
        self.priority = priority
    }
}

enum BriefingItemPriority: String, Codable, Sendable {
    case high
    case normal
    case info
}
