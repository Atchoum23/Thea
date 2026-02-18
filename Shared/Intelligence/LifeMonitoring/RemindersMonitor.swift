//
//  RemindersMonitor.swift
//  Thea
//
//  Reminders monitoring for life tracking
//  Emits LifeEvents when reminders are created, completed, or due
//

@preconcurrency import EventKit
import Combine
import Foundation
import os.log

// MARK: - Reminders Monitor

/// Monitors reminders for life event tracking
/// Emits LifeEvents for reminder creation, completion, and due dates
public actor RemindersMonitor {
    public static let shared = RemindersMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "RemindersMonitor")
    private let eventStore = EKEventStore()

    private var isRunning = false
    private var eventStoreObserver: NSObjectProtocol?
    private var dueReminderTimers: [String: Task<Void, Never>] = [:]
    private var knownReminderIds: Set<String> = []
    private var completedReminderIds: Set<String> = []

    // Track reminders we've already notified about
    private var notifiedDueReminders: Set<String> = []

    private init() {}

    // MARK: - Lifecycle

    /// Start monitoring reminders
    public func start() async {
        guard !isRunning else { return }

        // Request reminders access
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            guard granted else {
                logger.warning("Reminders access denied")
                return
            }
        } catch {
            logger.error("Failed to request reminders access: \(error.localizedDescription)")
            return
        }

        isRunning = true
        logger.info("Reminders monitor started")

        // Load initial reminders
        await loadInitialReminders()

        // Observe reminder changes
        setupEventStoreObserver()

        // Schedule notifications for due reminders
        await scheduleDueReminderNotifications()
    }

    /// Stop monitoring
    public func stop() async {
        guard isRunning else { return }

        isRunning = false

        // Remove observer
        if let observer = eventStoreObserver {
            NotificationCenter.default.removeObserver(observer)
            eventStoreObserver = nil
        }

        // Cancel all timers
        for (_, task) in dueReminderTimers {
            task.cancel()
        }
        dueReminderTimers.removeAll()
        notifiedDueReminders.removeAll()

        logger.info("Reminders monitor stopped")
    }

    // MARK: - Initial Load

    private func loadInitialReminders() async {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                // Extract data on the callback thread before crossing task boundary
                let reminderData: [(id: String, completed: Bool)] = (reminders ?? []).map {
                    (id: $0.calendarItemIdentifier, completed: $0.isCompleted)
                }

                Task { [weak self] in
                    await self?.processInitialReminderData(reminderData)
                    continuation.resume()
                }
            }
        }
    }

    private func processInitialReminderData(_ reminders: [(id: String, completed: Bool)]) {
        for reminder in reminders {
            knownReminderIds.insert(reminder.id)
            if reminder.completed {
                completedReminderIds.insert(reminder.id)
            }
        }

        logger.info("Loaded \(reminders.count) reminders")
    }

    // MARK: - Event Store Observer

    private func setupEventStoreObserver() {
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleEventStoreChange()
            }
        }
    }

    private func handleEventStoreChange() async {
        // Fetch all reminders (both complete and incomplete for tracking)
        let incompletePredicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let completedPredicate = eventStore.predicateForCompletedReminders(
            withCompletionDateStarting: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            ending: Date(),
            calendars: nil
        )

        // Fetch incomplete reminders and extract data
        let incompleteData = await withCheckedContinuation { (continuation: CheckedContinuation<[ReminderData], Never>) in
            eventStore.fetchReminders(matching: incompletePredicate) { reminders in
                let data = (reminders ?? []).map { ReminderData(from: $0) }
                continuation.resume(returning: data)
            }
        }

        // Fetch recently completed reminders and extract data
        let completedData = await withCheckedContinuation { (continuation: CheckedContinuation<[ReminderData], Never>) in
            eventStore.fetchReminders(matching: completedPredicate) { reminders in
                let data = (reminders ?? []).map { ReminderData(from: $0) }
                continuation.resume(returning: data)
            }
        }

        let allData = incompleteData + completedData
        let currentReminderIds = Set(allData.map(\.id))

        // Find new reminders
        let newReminderIds = currentReminderIds.subtracting(knownReminderIds)
        for reminderId in newReminderIds {
            if let reminderData = allData.first(where: { $0.id == reminderId }) {
                await emitReminderEventFromData(reminderData, action: .created)
            }
        }

        // Find newly completed reminders
        for reminderData in completedData {
            if !completedReminderIds.contains(reminderData.id) {
                await emitReminderEventFromData(reminderData, action: .completed)
                completedReminderIds.insert(reminderData.id)
            }
        }

        // Find deleted reminders
        let deletedReminderIds = knownReminderIds.subtracting(currentReminderIds)
        for reminderId in deletedReminderIds {
            await emitReminderDeleted(reminderId: reminderId)
        }

        // Update known reminders
        knownReminderIds = currentReminderIds

        // Reschedule due reminder notifications
        await scheduleDueReminderNotifications()
    }

    // MARK: - Due Reminder Notifications

    private func scheduleDueReminderNotifications() async {
        // Cancel existing timers
        for (_, task) in dueReminderTimers {
            task.cancel()
        }
        dueReminderTimers.removeAll()

        let now = Date()
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: now,
            ending: endOfDay,
            calendars: nil
        )

        let upcomingData = await withCheckedContinuation { (continuation: CheckedContinuation<[ReminderData], Never>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let data = (reminders ?? []).map { ReminderData(from: $0) }
                continuation.resume(returning: data)
            }
        }

        await processUpcomingReminders(upcomingData, now: now)
    }

    private func processUpcomingReminders(_ reminders: [ReminderData], now: Date) async {
        for reminderData in reminders {
            guard let dueDate = reminderData.dueDate else { continue }

            let reminderId = reminderData.id

            // Skip if already notified
            guard !notifiedDueReminders.contains(reminderId) else { continue }

            let timeUntilDue = dueDate.timeIntervalSince(now)

            // Only schedule if reminder is due in the future
            guard timeUntilDue > 0 else {
                // Reminder already due - emit immediately
                await emitReminderEventFromData(reminderData, action: .due)
                notifiedDueReminders.insert(reminderId)
                continue
            }

            // Schedule notification when reminder is due - using Sendable reminderData
            let task = Task { [weak self, reminderData] in
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeUntilDue * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.reminderDueFromData(reminderData)
            }

            dueReminderTimers[reminderId] = task
        }

        logger.debug("Scheduled notifications for \(reminders.count) upcoming reminders")
    }

    private func reminderDueFromData(_ reminderData: ReminderData) async {
        let reminderId = reminderData.id

        // Double-check we haven't already notified
        guard !notifiedDueReminders.contains(reminderId) else { return }

        notifiedDueReminders.insert(reminderId)
        await emitReminderEventFromData(reminderData, action: .due)
    }

    // MARK: - Event Emission

    private func emitReminderEvent(_ reminder: EKReminder, action: ReminderAction) async {
        let eventType: LifeEventType
        let significance: EventSignificance
        var summary: String

        switch action {
        case .created:
            eventType = .reminderCreated
            significance = .minor
            summary = "Created reminder: \(reminder.title ?? "Untitled")"
        case .completed:
            eventType = .reminderCompleted
            significance = .moderate
            summary = "Completed reminder: \(reminder.title ?? "Untitled")"
        case .due:
            eventType = .reminderDue
            significance = .significant
            summary = "Reminder due: \(reminder.title ?? "Untitled")"
        case .deleted:
            eventType = .reminderDeleted
            significance = .trivial
            summary = "Deleted reminder"
        }

        var eventData: [String: String] = [
            "reminderId": reminder.calendarItemIdentifier,
            "title": reminder.title ?? "Untitled",
            "isCompleted": String(reminder.isCompleted),
            "priority": String(reminder.priority),
            "list": reminder.calendar?.title ?? "Reminders",
            "action": action.rawValue
        ]

        if let dueDate = reminder.dueDateComponents?.date {
            eventData["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }

        if let completionDate = reminder.completionDate {
            eventData["completionDate"] = ISO8601DateFormatter().string(from: completionDate)
        }

        if let notes = reminder.notes {
            eventData["notes"] = String(notes.prefix(200))
        }

        // Map priority to readable form
        switch reminder.priority {
        case 1...4:
            eventData["priorityLevel"] = "high"
        case 5:
            eventData["priorityLevel"] = "medium"
        case 6...9:
            eventData["priorityLevel"] = "low"
        default:
            eventData["priorityLevel"] = "none"
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .reminders,
            summary: summary,
            data: eventData,
            significance: significance
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }

        logger.info("Reminder event: \(action.rawValue) - \(reminder.title ?? "Untitled")")
    }

    /// Emit reminder event from Sendable ReminderData
    private func emitReminderEventFromData(_ data: ReminderData, action: ReminderAction) async {
        let eventType: LifeEventType
        let significance: EventSignificance
        var summary: String

        switch action {
        case .created:
            eventType = .reminderCreated
            significance = .minor
            summary = "Created reminder: \(data.title)"
        case .completed:
            eventType = .reminderCompleted
            significance = .moderate
            summary = "Completed reminder: \(data.title)"
        case .due:
            eventType = .reminderDue
            significance = .significant
            summary = "Reminder due: \(data.title)"
        case .deleted:
            eventType = .reminderDeleted
            significance = .trivial
            summary = "Deleted reminder"
        }

        var eventData: [String: String] = [
            "reminderId": data.id,
            "title": data.title,
            "isCompleted": String(data.isCompleted),
            "priority": String(data.priority),
            "list": data.listName,
            "action": action.rawValue,
            "priorityLevel": data.priorityLevel
        ]

        if let dueDate = data.dueDate {
            eventData["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }

        if let completionDate = data.completionDate {
            eventData["completionDate"] = ISO8601DateFormatter().string(from: completionDate)
        }

        if let notes = data.notes {
            eventData["notes"] = String(notes.prefix(200))
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .reminders,
            summary: summary,
            data: eventData,
            significance: significance
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }

        logger.info("Reminder event: \(action.rawValue) - \(data.title)")
    }

    private func emitReminderDeleted(reminderId: String) async {
        let lifeEvent = LifeEvent(
            type: .reminderDeleted,
            source: .reminders,
            summary: "Reminder deleted",
            data: ["reminderId": reminderId, "action": "deleted"],
            significance: .trivial
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }
    }

    // MARK: - Manual Refresh

    /// Force refresh reminders
    public func refresh() async {
        await handleEventStoreChange()
    }

    // MARK: - Query Methods

    /// Get incomplete reminders
    public func getIncompleteReminders() async -> [ReminderEventInfo] {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let infos = (reminders ?? []).map { ReminderEventInfo(from: $0) }
                continuation.resume(returning: infos)
            }
        }
    }

    /// Get reminders due today
    public func getTodayReminders() async -> [ReminderEventInfo] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: startOfDay,
            ending: endOfDay,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let infos = (reminders ?? []).map { ReminderEventInfo(from: $0) }
                continuation.resume(returning: infos)
            }
        }
    }

    /// Get overdue reminders
    public func getOverdueReminders() async -> [ReminderEventInfo] {
        let now = Date()
        let distantPast = Date.distantPast

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: distantPast,
            ending: now,
            calendars: nil
        )

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let infos = (reminders ?? []).map { ReminderEventInfo(from: $0) }
                continuation.resume(returning: infos)
            }
        }
    }
}

// MARK: - Supporting Types

private enum ReminderAction: String {
    case created
    case completed
    case due
    case deleted
}

/// Sendable reminder data extracted from EKReminder for cross-task usage
private struct ReminderData: Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let completionDate: Date?
    let priority: Int
    let listName: String
    let notes: String?

    var priorityLevel: String {
        switch priority {
        case 1...4: return "high"
        case 5: return "medium"
        case 6...9: return "low"
        default: return "none"
        }
    }

    init(from reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? "Untitled"
        isCompleted = reminder.isCompleted
        dueDate = reminder.dueDateComponents?.date
        completionDate = reminder.completionDate
        priority = reminder.priority
        listName = reminder.calendar?.title ?? "Reminders"
        notes = reminder.notes
    }
}

/// Reminder info for UI display
public struct ReminderEventInfo: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let isCompleted: Bool
    public let dueDate: Date?
    public let priority: Int
    public let priorityLevel: String
    public let listName: String
    public let notes: String?
    public let isOverdue: Bool

    init(from reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? "Untitled"
        isCompleted = reminder.isCompleted
        dueDate = reminder.dueDateComponents?.date
        priority = reminder.priority
        listName = reminder.calendar?.title ?? "Reminders"
        notes = reminder.notes

        switch reminder.priority {
        case 1...4:
            priorityLevel = "high"
        case 5:
            priorityLevel = "medium"
        case 6...9:
            priorityLevel = "low"
        default:
            priorityLevel = "none"
        }

        if let due = dueDate {
            isOverdue = due < Date() && !isCompleted
        } else {
            isOverdue = false
        }
    }
}

// MARK: - LifeEventType & DataSourceType
// Note: LifeEventType cases (.reminderCreated, .reminderCompleted, .reminderDeleted, .reminderDue)
// and DataSourceType.reminders are defined in LifeMonitoringCoordinator.swift
