import EventKit
import Foundation
import os.log

// MARK: - Calendar Context Provider

/// Provides calendar-based context including current and upcoming events
public actor CalendarContextProvider: ContextProvider {
    public let providerId = "calendar"
    public let displayName = "Calendar"

    private let logger = Logger(subsystem: "app.thea", category: "CalendarProvider")
    nonisolated(unsafe) private let eventStore = EKEventStore()

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?
    private var notificationObserver: Any?

    public var isActive: Bool { state == .running }
    public var requiresPermission: Bool { true }

    public var hasPermission: Bool {
        get async {
            let status = EKEventStore.authorizationStatus(for: .event)
            #if os(iOS) || os(watchOS)
                if #available(iOS 17.0, watchOS 10.0, *) {
                    return status == .fullAccess
                } else {
                    return status == .authorized
                }
            #elseif os(macOS)
                if #available(macOS 14.0, *) {
                    return status == .fullAccess
                } else {
                    return status == .authorized
                }
            #else
                return status == .authorized
            #endif
        }
    }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        // Listen for calendar changes
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.fetchCalendarData() }
        }

        // Start periodic updates
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchCalendarData()
                try? await Task.sleep(for: .seconds(60))
            }
        }

        state = .running
        logger.info("Calendar provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Calendar provider stopped")
    }

    public func requestPermission() async throws -> Bool {
        #if os(iOS) || os(watchOS)
            if #available(iOS 17.0, watchOS 10.0, *) {
                do {
                    return try await eventStore.requestFullAccessToEvents()
                } catch {
                    logger.error("Failed to request calendar permission: \(error.localizedDescription)")
                    return false
                }
            } else {
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            self.logger.error("Failed to request calendar permission: \(error.localizedDescription)")
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        #elseif os(macOS)
            if #available(macOS 14.0, *) {
                do {
                    return try await eventStore.requestFullAccessToEvents()
                } catch {
                    logger.error("Failed to request calendar permission: \(error.localizedDescription)")
                    return false
                }
            } else {
                return await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            self.logger.error("Failed to request calendar permission: \(error.localizedDescription)")
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        #else
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        self.logger.error("Failed to request calendar permission: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        #endif
    }

    public func getCurrentContext() async -> ContextUpdate? {
        let context = await buildCalendarContext()
        return ContextUpdate(
            providerId: providerId,
            updateType: .calendar(context),
            priority: .normal
        )
    }

    // MARK: - Private Methods

    private func fetchCalendarData() async {
        let context = await buildCalendarContext()

        // Determine priority based on upcoming events
        let priority: ContextUpdate.Priority = {
            if let next = context.upcomingEvents.first {
                let timeUntil = next.startDate.timeIntervalSinceNow
                if timeUntil < 600 { return .high } // Within 10 minutes
                if timeUntil < 1800 { return .normal } // Within 30 minutes
            }
            return .low
        }()

        let update = ContextUpdate(
            providerId: providerId,
            updateType: .calendar(context),
            priority: priority
        )
        continuation?.yield(update)
    }

    private func buildCalendarContext() async -> CalendarContext {
        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: endOfDay) ?? endOfDay

        let predicate = eventStore.predicateForEvents(withStart: now, end: tomorrow, calendars: nil)
        let events = eventStore.events(matching: predicate)

        // Find current event
        let currentEvent = events.first { event in
            event.startDate <= now && event.endDate > now
        }

        // Get upcoming events (excluding current)
        let upcomingEvents = events
            .filter { $0.startDate > now }
            .prefix(5)
            .map { convertToCalendarEvent($0) }

        // Calculate free time until next event
        let freeTimeUntilNext = upcomingEvents.first.map { $0.startDate.timeIntervalSince(now) }

        // Determine busy level
        let busyLevel = determineBusyLevel(events: events, now: now)

        return CalendarContext(
            currentEvent: currentEvent.map { convertToCalendarEvent($0) },
            upcomingEvents: Array(upcomingEvents),
            freeTimeUntilNextEvent: freeTimeUntilNext,
            busyLevel: busyLevel
        )
    }

    private func convertToCalendarEvent(_ event: EKEvent) -> CalendarContext.CalendarEvent {
        let hasVideoCall = event.location?.contains("zoom") == true ||
            event.location?.contains("meet.google") == true ||
            event.location?.contains("teams") == true ||
            event.notes?.contains("zoom") == true ||
            event.notes?.contains("meet.google") == true

        return CalendarContext.CalendarEvent(
            id: event.eventIdentifier,
            title: event.title ?? "Untitled",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            isAllDay: event.isAllDay,
            attendeeCount: event.attendees?.count ?? 0,
            hasVideoCall: hasVideoCall,
            calendarName: event.calendar.title
        )
    }

    private func determineBusyLevel(events: [EKEvent], now: Date) -> CalendarContext.BusyLevel {
        let upcomingCount = events.count { $0.startDate > now && $0.startDate < now.addingTimeInterval(3600 * 4) }

        let isInMeeting = events.contains { $0.startDate <= now && $0.endDate > now }

        if isInMeeting && upcomingCount >= 3 { return .veryBusy }
        if isInMeeting || upcomingCount >= 3 { return .busy }
        if upcomingCount >= 2 { return .moderate }
        if upcomingCount >= 1 { return .light }
        return .free
    }
}
