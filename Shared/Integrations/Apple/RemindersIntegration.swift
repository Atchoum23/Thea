// RemindersIntegration.swift
// Thea V2
//
// Deep integration with Apple Reminders via EventKit
// Provides full CRUD operations for reminders and lists

import Foundation
import OSLog

#if canImport(EventKit)
import EventKit
#endif

// MARK: - Reminder Models

/// Represents a reminder in the system
public struct TheaReminder: Identifiable, Sendable, Codable {
    public let id: String
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var completionDate: Date?
    public var dueDate: Date?
    public var dueDateComponents: DateComponents?
    public var priority: ReminderPriority
    public var listId: String?
    public var listName: String?
    public var url: URL?
    public var location: ReminderLocation?
    public var recurrenceRule: RecurrenceRule?
    public var alarms: [ReminderAlarm]
    public var creationDate: Date?
    public var lastModifiedDate: Date?

    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        completionDate: Date? = nil,
        dueDate: Date? = nil,
        dueDateComponents: DateComponents? = nil,
        priority: ReminderPriority = .none,
        listId: String? = nil,
        listName: String? = nil,
        url: URL? = nil,
        location: ReminderLocation? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        alarms: [ReminderAlarm] = [],
        creationDate: Date? = nil,
        lastModifiedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.completionDate = completionDate
        self.dueDate = dueDate
        self.dueDateComponents = dueDateComponents
        self.priority = priority
        self.listId = listId
        self.listName = listName
        self.url = url
        self.location = location
        self.recurrenceRule = recurrenceRule
        self.alarms = alarms
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
    }
}

/// Reminder priority levels
public enum ReminderPriority: Int, Codable, Sendable, CaseIterable {
    case none = 0
    case high = 1
    case medium = 5
    case low = 9
}

/// Location for location-based reminders
public struct ReminderLocation: Codable, Sendable {
    public var title: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double  // In meters
    public var proximity: LocationProximity

    public init(
        title: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 100,
        proximity: LocationProximity = .enter
    ) {
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.proximity = proximity
    }
}

/// Location proximity type
public enum LocationProximity: String, Codable, Sendable {
    case enter
    case leave
}

/// Recurrence rule for repeating reminders
public struct RecurrenceRule: Codable, Sendable {
    public var frequency: RecurrenceFrequency
    public var interval: Int
    public var endDate: Date?
    public var occurrenceCount: Int?
    public var daysOfWeek: [Int]?  // 1 = Sunday, 7 = Saturday

    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        endDate: Date? = nil,
        occurrenceCount: Int? = nil,
        daysOfWeek: [Int]? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
        self.daysOfWeek = daysOfWeek
    }

    public static var daily: RecurrenceRule {
        RecurrenceRule(frequency: .daily)
    }

    public static var weekly: RecurrenceRule {
        RecurrenceRule(frequency: .weekly)
    }

    public static var monthly: RecurrenceRule {
        RecurrenceRule(frequency: .monthly)
    }

    public static var yearly: RecurrenceRule {
        RecurrenceRule(frequency: .yearly)
    }
}

/// Recurrence frequency
public enum RecurrenceFrequency: String, Codable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
}

/// Alarm for reminders
public struct ReminderAlarm: Codable, Sendable {
    public var absoluteDate: Date?
    public var relativeOffset: TimeInterval?  // Seconds before due date

    public init(absoluteDate: Date) {
        self.absoluteDate = absoluteDate
        self.relativeOffset = nil
    }

    public init(relativeOffset: TimeInterval) {
        self.absoluteDate = nil
        self.relativeOffset = relativeOffset
    }

    public static func before(minutes: Int) -> ReminderAlarm {
        ReminderAlarm(relativeOffset: TimeInterval(-minutes * 60))
    }

    public static func before(hours: Int) -> ReminderAlarm {
        ReminderAlarm(relativeOffset: TimeInterval(-hours * 3600))
    }

    public static func before(days: Int) -> ReminderAlarm {
        ReminderAlarm(relativeOffset: TimeInterval(-days * 86400))
    }
}

/// Reminder list (calendar in EventKit terminology)
public struct TheaReminderList: Identifiable, Sendable, Codable {
    public let id: String
    public var title: String
    public var color: String?  // Hex color string
    public var isDefault: Bool
    public var reminderCount: Int

    public init(
        id: String = UUID().uuidString,
        title: String,
        color: String? = nil,
        isDefault: Bool = false,
        reminderCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.isDefault = isDefault
        self.reminderCount = reminderCount
    }
}

// MARK: - Search Criteria

/// Search criteria for reminders
public struct ReminderSearchCriteria: Sendable {
    public var listIds: [String]?
    public var isCompleted: Bool?
    public var dueBefore: Date?
    public var dueAfter: Date?
    public var titleContains: String?
    public var priority: ReminderPriority?
    public var includeCompletedSince: Date?

    public init(
        listIds: [String]? = nil,
        isCompleted: Bool? = nil,
        dueBefore: Date? = nil,
        dueAfter: Date? = nil,
        titleContains: String? = nil,
        priority: ReminderPriority? = nil,
        includeCompletedSince: Date? = nil
    ) {
        self.listIds = listIds
        self.isCompleted = isCompleted
        self.dueBefore = dueBefore
        self.dueAfter = dueAfter
        self.titleContains = titleContains
        self.priority = priority
        self.includeCompletedSince = includeCompletedSince
    }

    public static var incomplete: ReminderSearchCriteria {
        ReminderSearchCriteria(isCompleted: false)
    }

    public static var completed: ReminderSearchCriteria {
        ReminderSearchCriteria(isCompleted: true)
    }

    public static func dueWithin(days: Int) -> ReminderSearchCriteria {
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
        return ReminderSearchCriteria(
            isCompleted: false,
            dueBefore: endDate
        )
    }
}

// MARK: - Reminders Integration Actor

/// Actor for managing reminder operations
/// Thread-safe access to EventKit reminders
@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
public actor RemindersIntegration {
    public static let shared = RemindersIntegration()

    private let logger = Logger(subsystem: "com.thea.integrations", category: "Reminders")

    #if canImport(EventKit)
    private let eventStore = EKEventStore()
    #endif

    private init() {}

    // MARK: - Authorization

    /// Check current authorization status
    public var authorizationStatus: ReminderAuthorizationStatus {
        #if canImport(EventKit)
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    /// Request access to reminders
    public func requestAccess() async -> Bool {
        #if canImport(EventKit)
        do {
            // Use requestFullAccessToReminders for iOS 17+ / macOS 14+
            if #available(iOS 17.0, macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToReminders()
                logger.info("Reminder access \(granted ? "granted" : "denied")")
                return granted
            } else {
                // Fallback for older versions
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .reminder) { granted, error in
                        if let error = error {
                            self.logger.error("Reminder access error: \(error.localizedDescription)")
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        } catch {
            logger.error("Failed to request reminder access: \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: - List Operations

    /// Fetch all reminder lists
    public func fetchLists() async throws -> [TheaReminderList] {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        let calendars = eventStore.calendars(for: .reminder)
        let defaultCalendar = eventStore.defaultCalendarForNewReminders()

        return calendars.map { calendar in
            TheaReminderList(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: calendar.cgColor.map { colorToHex($0) },
                isDefault: calendar.calendarIdentifier == defaultCalendar?.calendarIdentifier,
                reminderCount: 0  // Would need separate fetch
            )
        }
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Create a new reminder list
    public func createList(title: String) async throws -> TheaReminderList {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = title

        // Find a source for the calendar
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = iCloudSource
        } else if let source = eventStore.sources.first {
            calendar.source = source
        } else {
            throw RemindersError.createFailed("No available source for reminder list")
        }

        try eventStore.saveCalendar(calendar, commit: true)

        logger.info("Created reminder list: \(title)")

        return TheaReminderList(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            color: calendar.cgColor.map { colorToHex($0) },
            isDefault: false
        )
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Delete a reminder list
    public func deleteList(id: String) async throws {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        guard let calendar = eventStore.calendar(withIdentifier: id) else {
            throw RemindersError.listNotFound
        }

        try eventStore.removeCalendar(calendar, commit: true)

        logger.info("Deleted reminder list: \(id)")
        #else
        throw RemindersError.unavailable
        #endif
    }

    // MARK: - Reminder Fetch Operations

    /// Fetch all reminders
    public func fetchAllReminders() async throws -> [TheaReminder] {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let theaReminders = (reminders ?? []).map { self.convertToTheaReminder($0) }
                continuation.resume(returning: theaReminders)
            }
        }
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Fetch reminders by criteria
    public func fetchReminders(criteria: ReminderSearchCriteria) async throws -> [TheaReminder] {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        var calendars: [EKCalendar]

        if let listIds = criteria.listIds {
            calendars = listIds.compactMap { eventStore.calendar(withIdentifier: $0) }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        let predicate: NSPredicate

        if let dueBefore = criteria.dueBefore, let dueAfter = criteria.dueAfter {
            if criteria.isCompleted == false {
                predicate = eventStore.predicateForIncompleteReminders(
                    withDueDateStarting: dueAfter,
                    ending: dueBefore,
                    calendars: calendars
                )
            } else if criteria.isCompleted == true {
                predicate = eventStore.predicateForCompletedReminders(
                    withCompletionDateStarting: dueAfter,
                    ending: dueBefore,
                    calendars: calendars
                )
            } else {
                predicate = eventStore.predicateForReminders(in: calendars)
            }
        } else if criteria.isCompleted == false {
            predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: criteria.dueBefore,
                calendars: calendars
            )
        } else if criteria.isCompleted == true {
            let startDate = criteria.includeCompletedSince ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())
            predicate = eventStore.predicateForCompletedReminders(
                withCompletionDateStarting: startDate,
                ending: Date(),
                calendars: calendars
            )
        } else {
            predicate = eventStore.predicateForReminders(in: calendars)
        }

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                var results = (reminders ?? []).map { self.convertToTheaReminder($0) }

                // Apply additional filters
                if let titleContains = criteria.titleContains?.lowercased(), !titleContains.isEmpty {
                    results = results.filter { $0.title.lowercased().contains(titleContains) }
                }

                if let priority = criteria.priority {
                    results = results.filter { $0.priority == priority }
                }

                continuation.resume(returning: results)
            }
        }
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Fetch a single reminder by ID
    public func fetchReminder(id: String) async throws -> TheaReminder? {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            return nil
        }

        return convertToTheaReminder(ekReminder)
        #else
        throw RemindersError.unavailable
        #endif
    }

    // MARK: - Reminder CRUD Operations

    /// Create a new reminder
    public func createReminder(_ reminder: TheaReminder) async throws -> TheaReminder {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        let ekReminder = EKReminder(eventStore: eventStore)
        populateEKReminder(ekReminder, from: reminder)

        // Set calendar
        if let listId = reminder.listId,
           let calendar = eventStore.calendar(withIdentifier: listId) {
            ekReminder.calendar = calendar
        } else {
            ekReminder.calendar = eventStore.defaultCalendarForNewReminders()
        }

        try eventStore.save(ekReminder, commit: true)

        logger.info("Created reminder: \(reminder.title)")

        return convertToTheaReminder(ekReminder)
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Update an existing reminder
    public func updateReminder(_ reminder: TheaReminder) async throws {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminder.id) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }

        populateEKReminder(ekReminder, from: reminder)

        try eventStore.save(ekReminder, commit: true)

        logger.info("Updated reminder: \(reminder.title)")
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Mark reminder as complete
    public func completeReminder(id: String, completionDate: Date = Date()) async throws {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }

        ekReminder.isCompleted = true
        ekReminder.completionDate = completionDate

        try eventStore.save(ekReminder, commit: true)

        logger.info("Completed reminder: \(id)")
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Mark reminder as incomplete
    public func uncompleteReminder(id: String) async throws {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }

        ekReminder.isCompleted = false
        ekReminder.completionDate = nil

        try eventStore.save(ekReminder, commit: true)

        logger.info("Uncompleted reminder: \(id)")
        #else
        throw RemindersError.unavailable
        #endif
    }

    /// Delete a reminder
    public func deleteReminder(id: String) async throws {
        #if canImport(EventKit)
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else {
            throw RemindersError.notAuthorized
        }

        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }

        try eventStore.remove(ekReminder, commit: true)

        logger.info("Deleted reminder: \(id)")
        #else
        throw RemindersError.unavailable
        #endif
    }

    // MARK: - Batch Operations

    /// Complete multiple reminders
    public func completeReminders(ids: [String]) async throws {
        for id in ids {
            try await completeReminder(id: id)
        }
    }

    /// Delete all completed reminders in a list
    public func deleteCompletedReminders(listId: String? = nil) async throws {
        let criteria = ReminderSearchCriteria(
            listIds: listId.map { [$0] },
            isCompleted: true
        )
        let completed = try await fetchReminders(criteria: criteria)

        for reminder in completed {
            try await deleteReminder(id: reminder.id)
        }

        logger.info("Deleted \(completed.count) completed reminders")
    }

    // MARK: - Helper Methods

    #if canImport(EventKit)
    private func convertToTheaReminder(_ ekReminder: EKReminder) -> TheaReminder {
        var recurrenceRule: RecurrenceRule?
        if let rule = ekReminder.recurrenceRules?.first {
            let frequency: RecurrenceFrequency
            switch rule.frequency {
            case .daily:
                frequency = .daily
            case .weekly:
                frequency = .weekly
            case .monthly:
                frequency = .monthly
            case .yearly:
                frequency = .yearly
            @unknown default:
                frequency = .daily
            }
            recurrenceRule = RecurrenceRule(
                frequency: frequency,
                interval: rule.interval,
                endDate: rule.recurrenceEnd?.endDate,
                occurrenceCount: rule.recurrenceEnd?.occurrenceCount
            )
        }

        let alarms: [ReminderAlarm] = ekReminder.alarms?.compactMap { alarm in
            if let absoluteDate = alarm.absoluteDate {
                return ReminderAlarm(absoluteDate: absoluteDate)
            } else {
                return ReminderAlarm(relativeOffset: alarm.relativeOffset)
            }
        } ?? []

        var location: ReminderLocation?
        if let structuredLocation = ekReminder.alarms?.first?.structuredLocation,
           let geoLocation = structuredLocation.geoLocation {
            location = ReminderLocation(
                title: structuredLocation.title ?? "",
                latitude: geoLocation.coordinate.latitude,
                longitude: geoLocation.coordinate.longitude,
                radius: structuredLocation.radius
            )
        }

        return TheaReminder(
            id: ekReminder.calendarItemIdentifier,
            title: ekReminder.title ?? "",
            notes: ekReminder.notes,
            isCompleted: ekReminder.isCompleted,
            completionDate: ekReminder.completionDate,
            dueDate: ekReminder.dueDateComponents?.date,
            dueDateComponents: ekReminder.dueDateComponents,
            priority: ReminderPriority(rawValue: ekReminder.priority) ?? .none,
            listId: ekReminder.calendar?.calendarIdentifier,
            listName: ekReminder.calendar?.title,
            url: ekReminder.url,
            location: location,
            recurrenceRule: recurrenceRule,
            alarms: alarms,
            creationDate: ekReminder.creationDate,
            lastModifiedDate: ekReminder.lastModifiedDate
        )
    }

    private func populateEKReminder(_ ekReminder: EKReminder, from reminder: TheaReminder) {
        ekReminder.title = reminder.title
        ekReminder.notes = reminder.notes
        ekReminder.isCompleted = reminder.isCompleted
        ekReminder.completionDate = reminder.completionDate
        ekReminder.priority = reminder.priority.rawValue
        ekReminder.url = reminder.url

        // Set due date
        if let dueDateComponents = reminder.dueDateComponents {
            ekReminder.dueDateComponents = dueDateComponents
        } else if let dueDate = reminder.dueDate {
            ekReminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }

        // Set recurrence
        if let rule = reminder.recurrenceRule {
            let ekFrequency: EKRecurrenceFrequency
            switch rule.frequency {
            case .daily:
                ekFrequency = .daily
            case .weekly:
                ekFrequency = .weekly
            case .monthly:
                ekFrequency = .monthly
            case .yearly:
                ekFrequency = .yearly
            }

            var recurrenceEnd: EKRecurrenceEnd?
            if let endDate = rule.endDate {
                recurrenceEnd = EKRecurrenceEnd(end: endDate)
            } else if let count = rule.occurrenceCount {
                recurrenceEnd = EKRecurrenceEnd(occurrenceCount: count)
            }

            let ekRule = EKRecurrenceRule(
                recurrenceWith: ekFrequency,
                interval: rule.interval,
                end: recurrenceEnd
            )
            ekReminder.recurrenceRules = [ekRule]
        }

        // Set alarms
        ekReminder.alarms = reminder.alarms.map { alarm in
            if let absoluteDate = alarm.absoluteDate {
                return EKAlarm(absoluteDate: absoluteDate)
            } else if let offset = alarm.relativeOffset {
                return EKAlarm(relativeOffset: offset)
            } else {
                return EKAlarm(relativeOffset: 0)
            }
        }
    }

    private func colorToHex(_ cgColor: CGColor) -> String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
    #endif
}

// MARK: - Supporting Types

/// Authorization status for reminders
public enum ReminderAuthorizationStatus: String, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case fullAccess
    case writeOnly
    case unavailable
}

/// Errors for reminder operations
public enum RemindersError: LocalizedError {
    case notAuthorized
    case unavailable
    case reminderNotFound
    case listNotFound
    case createFailed(String)
    case updateFailed(String)
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Reminder access not authorized"
        case .unavailable:
            "EventKit framework not available on this platform"
        case .reminderNotFound:
            "Reminder not found"
        case .listNotFound:
            "Reminder list not found"
        case .createFailed(let reason):
            "Failed to create reminder: \(reason)"
        case .updateFailed(let reason):
            "Failed to update reminder: \(reason)"
        case .deleteFailed(let reason):
            "Failed to delete reminder: \(reason)"
        }
    }
}
