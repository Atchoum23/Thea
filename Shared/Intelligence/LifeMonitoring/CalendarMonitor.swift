//
//  CalendarMonitor.swift
//  Thea
//
//  Calendar event monitoring for life tracking
//  Emits LifeEvents when calendar events are created, modified, or started
//

@preconcurrency import EventKit
import Combine
import Foundation
import os.log

// MARK: - Calendar Monitor

/// Monitors calendar for life event tracking
/// Emits LifeEvents for event creation, modifications, and when events start
public actor CalendarMonitor {
    public static let shared = CalendarMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "CalendarMonitor")
    private let eventStore = EKEventStore()

    private var isRunning = false
    private var eventStoreObserver: NSObjectProtocol?
    private var upcomingEventTimers: [String: Task<Void, Never>] = [:]
    private var knownEventIds: Set<String> = []

    // Track events we've already notified about to avoid duplicates
    private var notifiedStartedEvents: Set<String> = []

    private init() {}

    // MARK: - Lifecycle

    /// Start monitoring calendar events
    public func start() async {
        guard !isRunning else { return }

        // Request calendar access
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted else {
                logger.warning("Calendar access denied")
                return
            }
        } catch {
            logger.error("Failed to request calendar access: \(error.localizedDescription)")
            return
        }

        isRunning = true
        logger.info("Calendar monitor started")

        // Load initial events
        await loadInitialEvents()

        // Observe calendar changes
        setupEventStoreObserver()

        // Schedule notifications for upcoming events
        await scheduleUpcomingEventNotifications()
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
        for (_, task) in upcomingEventTimers {
            task.cancel()
        }
        upcomingEventTimers.removeAll()
        notifiedStartedEvents.removeAll()

        logger.info("Calendar monitor stopped")
    }

    // MARK: - Initial Load

    private func loadInitialEvents() async {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfDay) ?? startOfDay

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfWeek, calendars: nil)
        let events = eventStore.events(matching: predicate)

        for event in events {
            knownEventIds.insert(event.eventIdentifier)
        }

        logger.info("Loaded \(events.count) calendar events for the week")
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
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfDay) ?? startOfDay

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfMonth, calendars: nil)
        let currentEvents = eventStore.events(matching: predicate)
        let currentEventIds = Set(currentEvents.compactMap(\.eventIdentifier))

        // Find new events
        let newEventIds = currentEventIds.subtracting(knownEventIds)
        for eventId in newEventIds {
            if let event = currentEvents.first(where: { $0.eventIdentifier == eventId }) {
                await emitCalendarEvent(event, action: .created)
            }
        }

        // Find deleted events
        let deletedEventIds = knownEventIds.subtracting(currentEventIds)
        for eventId in deletedEventIds {
            await emitCalendarEventDeleted(eventId: eventId)
        }

        // Check for modified events (simplified - just check if events changed)
        for event in currentEvents {
            guard let eventId = event.eventIdentifier else { continue }
            guard knownEventIds.contains(eventId) else { continue }
            // We'd need to track more state to detect modifications accurately
            // For now, we'll rely on the EKEventStoreChanged notification
        }

        // Update known events
        knownEventIds = currentEventIds

        // Reschedule upcoming event notifications
        await scheduleUpcomingEventNotifications()
    }

    // MARK: - Upcoming Event Notifications

    private func scheduleUpcomingEventNotifications() async {
        // Cancel existing timers
        for (_, task) in upcomingEventTimers {
            task.cancel()
        }
        upcomingEventTimers.removeAll()

        let now = Date()
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

        let predicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let upcomingEvents = eventStore.events(matching: predicate)

        for event in upcomingEvents {
            let eventId = event.eventIdentifier ?? UUID().uuidString

            // Skip if already notified
            guard !notifiedStartedEvents.contains(eventId) else { continue }

            let timeUntilStart = event.startDate.timeIntervalSince(now)

            // Extract Sendable data before crossing task boundary
            let eventData = CalendarEventData(from: event)

            // Only schedule if event is in the future (within 24 hours)
            guard timeUntilStart > 0 else {
                // Event already started - emit immediately if not all-day
                if !event.isAllDay {
                    await emitCalendarEventFromData(eventData, action: .started)
                    notifiedStartedEvents.insert(eventId)
                }
                continue
            }

            // Schedule notification when event starts - using Sendable eventData
            let task = Task { [eventData] in
                try? await Task.sleep(nanoseconds: UInt64(timeUntilStart * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self.eventStartedFromData(eventData)
            }

            upcomingEventTimers[eventId] = task
        }

        logger.debug("Scheduled notifications for \(upcomingEvents.count) upcoming events")
    }

    private func eventStarted(_ event: EKEvent) async {
        let eventId = event.eventIdentifier ?? UUID().uuidString

        // Double-check we haven't already notified
        guard !notifiedStartedEvents.contains(eventId) else { return }

        notifiedStartedEvents.insert(eventId)
        await emitCalendarEvent(event, action: .started)
    }

    // MARK: - Event Emission

    private func emitCalendarEvent(_ event: EKEvent, action: CalendarEventAction) async {
        let eventType: LifeEventType
        let significance: EventSignificance
        var summary: String

        switch action {
        case .created:
            eventType = .calendarEventCreated
            significance = .moderate
            summary = "Created event: \(event.title ?? "Untitled")"
        case .modified:
            eventType = .calendarEventModified
            significance = .minor
            summary = "Modified event: \(event.title ?? "Untitled")"
        case .started:
            eventType = .eventStart
            significance = .significant
            summary = "Event starting: \(event.title ?? "Untitled")"
        case .deleted:
            eventType = .calendarEventDeleted
            significance = .minor
            summary = "Deleted event"
        }

        var eventData: [String: String] = [
            "eventId": event.eventIdentifier ?? "",
            "title": event.title ?? "Untitled",
            "startDate": ISO8601DateFormatter().string(from: event.startDate),
            "endDate": ISO8601DateFormatter().string(from: event.endDate),
            "isAllDay": String(event.isAllDay),
            "calendar": event.calendar?.title ?? "Unknown",
            "action": action.rawValue
        ]

        if let location = event.location {
            eventData["location"] = location
        }

        if let notes = event.notes {
            eventData["notes"] = String(notes.prefix(200))
        }

        // Check for attendees (meetings)
        if let attendees = event.attendees, !attendees.isEmpty {
            eventData["attendeeCount"] = String(attendees.count)
            eventData["isMeeting"] = "true"
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .calendar,
            summary: summary,
            data: eventData,
            significance: significance
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }

        logger.info("Calendar event: \(action.rawValue) - \(event.title ?? "Untitled")")
    }

    private func emitCalendarEventDeleted(eventId: String) async {
        let lifeEvent = LifeEvent(
            type: .calendarEventDeleted,
            source: .calendar,
            summary: "Calendar event deleted",
            data: ["eventId": eventId, "action": "deleted"],
            significance: .minor
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }
    }

    /// Emit calendar event from Sendable CalendarEventData
    private func emitCalendarEventFromData(_ data: CalendarEventData, action: CalendarEventAction) async {
        let eventType: LifeEventType
        let significance: EventSignificance
        var summary: String

        switch action {
        case .created:
            eventType = .calendarEventCreated
            significance = .moderate
            summary = "Created event: \(data.title)"
        case .modified:
            eventType = .calendarEventModified
            significance = .minor
            summary = "Modified event: \(data.title)"
        case .started:
            eventType = .eventStart
            significance = .significant
            summary = "Event starting: \(data.title)"
        case .deleted:
            eventType = .calendarEventDeleted
            significance = .minor
            summary = "Deleted event"
        }

        var eventData: [String: String] = [
            "eventId": data.id,
            "title": data.title,
            "startDate": ISO8601DateFormatter().string(from: data.startDate),
            "endDate": ISO8601DateFormatter().string(from: data.endDate),
            "isAllDay": String(data.isAllDay),
            "calendar": data.calendarName,
            "action": action.rawValue
        ]

        if let location = data.location {
            eventData["location"] = location
        }

        if let notes = data.notes {
            eventData["notes"] = String(notes.prefix(200))
        }

        if data.isMeeting {
            eventData["attendeeCount"] = String(data.attendeeCount)
            eventData["isMeeting"] = "true"
        }

        let lifeEvent = LifeEvent(
            type: eventType,
            source: .calendar,
            summary: summary,
            data: eventData,
            significance: significance
        )

        await MainActor.run {
            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
        }

        logger.info("Calendar event: \(action.rawValue) - \(data.title)")
    }

    /// Handle event started from Sendable data
    private func eventStartedFromData(_ eventData: CalendarEventData) async {
        let eventId = eventData.id

        // Double-check we haven't already notified
        guard !notifiedStartedEvents.contains(eventId) else { return }

        notifiedStartedEvents.insert(eventId)
        await emitCalendarEventFromData(eventData, action: .started)
    }

    // MARK: - Manual Refresh

    /// Force refresh calendar events
    public func refresh() async {
        await handleEventStoreChange()
    }

    // MARK: - Query Methods

    /// Get today's events
    public func getTodayEvents() -> [CalendarEventInfo] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate).map { CalendarEventInfo(from: $0) }
    }

    /// Get upcoming events for the next N hours
    public func getUpcomingEvents(hours: Int = 24) -> [CalendarEventInfo] {
        let now = Date()
        let future = Calendar.current.date(byAdding: .hour, value: hours, to: now) ?? now

        let predicate = eventStore.predicateForEvents(withStart: now, end: future, calendars: nil)
        return eventStore.events(matching: predicate).map { CalendarEventInfo(from: $0) }
    }
}

// MARK: - Supporting Types

private enum CalendarEventAction: String {
    case created
    case modified
    case started
    case deleted
}

/// Sendable calendar event data extracted from EKEvent for cross-task usage
private struct CalendarEventData: Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarName: String
    let attendeeCount: Int
    let isMeeting: Bool

    init(from event: EKEvent) {
        id = event.eventIdentifier ?? UUID().uuidString
        title = event.title ?? "Untitled"
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        location = event.location
        notes = event.notes
        calendarName = event.calendar?.title ?? "Unknown"
        attendeeCount = event.attendees?.count ?? 0
        isMeeting = (event.attendees?.count ?? 0) > 0
    }
}

/// Calendar event info for UI display
public struct CalendarEventInfo: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let calendarName: String
    public let calendarColor: String?
    public let isMeeting: Bool

    init(from event: EKEvent) {
        id = event.eventIdentifier ?? UUID().uuidString
        title = event.title ?? "Untitled"
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        location = event.location
        calendarName = event.calendar?.title ?? "Calendar"
        calendarColor = event.calendar?.cgColor?.components?.map { String(format: "%.2f", $0) }.joined(separator: ",")
        isMeeting = (event.attendees?.count ?? 0) > 0
    }
}

// MARK: - LifeEventType & DataSourceType
// Note: LifeEventType cases (.calendarEventCreated, .calendarEventModified, .calendarEventDeleted)
// and DataSourceType.calendar are defined in LifeMonitoringCoordinator.swift
