//
//  CalendarIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
import EventKit

// MARK: - Calendar Integration

/// Integration module for Calendar app
public actor CalendarIntegration: AppIntegrationModule {
    public static let shared = CalendarIntegration()

    public let moduleId = "calendar"
    public let displayName = "Calendar"
    public let bundleIdentifier = "com.apple.iCal"
    public let icon = "calendar"

    private let eventStore = EKEventStore()
    private var isConnected = false

    private init() {}

    public func connect() async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw AppIntegrationModuleError.permissionDenied("Calendar access denied")
        }
        isConnected = true
    }

    public func disconnect() async { isConnected = false }

    public func isAvailable() async -> Bool {
        EKEventStore.authorizationStatus(for: .event) != .restricted
    }

    /// Create a new event
    public func createEvent(title: String, startDate: Date, endDate: Date, calendar: EKCalendar? = nil, notes: String? = nil) async throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    /// Get events for a date range
    public func getEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate).map { event in
            CalendarEvent(
                id: event.eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.notes,
                calendarName: event.calendar.title
            )
        }
    }

    /// Get today's events
    public func getTodayEvents() async throws -> [CalendarEvent] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return try await getEvents(from: startOfDay, to: endOfDay)
    }

    /// Delete an event
    public func deleteEvent(_ eventId: String) async throws {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw AppIntegrationModuleError.operationFailed("Event not found")
        }
        try eventStore.remove(event, span: .thisEvent)
    }

    /// Get all calendars
    public func getCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }
}

// MARK: - Calendar Event

public struct CalendarEvent: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let calendarName: String
}
