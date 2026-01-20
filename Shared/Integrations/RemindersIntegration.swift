//
//  RemindersIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import EventKit

// MARK: - Reminders Integration

/// Integration module for Reminders app
public actor RemindersIntegration: AppIntegrationModule {
    public static let shared = RemindersIntegration()

    public let moduleId = "reminders"
    public let displayName = "Reminders"
    public let bundleIdentifier = "com.apple.reminders"
    public let icon = "checklist"

    private let eventStore = EKEventStore()
    private var isConnected = false

    private init() {}

    public func connect() async throws {
        let granted = try await eventStore.requestFullAccessToReminders()
        guard granted else {
            throw AppIntegrationModuleError.permissionDenied("Reminders access denied")
        }
        isConnected = true
    }

    public func disconnect() async { isConnected = false }

    public func isAvailable() async -> Bool {
        EKEventStore.authorizationStatus(for: .reminder) != .restricted
    }

    /// Create a new reminder
    public func createReminder(title: String, dueDate: Date? = nil, notes: String? = nil, priority: Int = 0, list: EKCalendar? = nil) async throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority
        reminder.calendar = list ?? eventStore.defaultCalendarForNewReminders()

        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    /// Get incomplete reminders
    public func getIncompleteReminders() async throws -> [ReminderInfo] {
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let infos = (reminders ?? []).map { reminder in
                    ReminderInfo(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title,
                        isCompleted: reminder.isCompleted,
                        dueDate: reminder.dueDateComponents?.date,
                        priority: reminder.priority,
                        notes: reminder.notes,
                        listName: reminder.calendar.title
                    )
                }
                continuation.resume(returning: infos)
            }
        }
    }

    /// Complete a reminder
    public func completeReminder(_ reminderId: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw AppIntegrationModuleError.operationFailed("Reminder not found")
        }
        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)
    }

    /// Delete a reminder
    public func deleteReminder(_ reminderId: String) async throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw AppIntegrationModuleError.operationFailed("Reminder not found")
        }
        try eventStore.remove(reminder, commit: true)
    }

    /// Get all reminder lists
    public func getReminderLists() -> [EKCalendar] {
        eventStore.calendars(for: .reminder)
    }
}

public struct ReminderInfo: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let isCompleted: Bool
    public let dueDate: Date?
    public let priority: Int
    public let notes: String?
    public let listName: String
}
