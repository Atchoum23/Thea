// DeadlineIntelligence+Engine.swift
// THEA - Proactive Deadline & Timeline Tracking
// Created by Claude - February 2026
//
// Lifecycle, configuration, deadline management,
// content processing, and internal scanning/reminder logic

import Foundation
#if canImport(EventKit)
import EventKit
#endif

// MARK: - Deadline Intelligence Engine

extension DeadlineIntelligence {

    // MARK: - Configuration

    /// Configure callbacks for deadline events.
    /// - Parameters:
    ///   - onDeadlineDiscovered: Called when a new deadline is detected.
    ///   - onReminderTriggered: Called when a reminder fires for a deadline at a given urgency.
    ///   - onDeadlineMissed: Called when a deadline passes its due date without completion.
    public func configure(
        onDeadlineDiscovered: @escaping @Sendable (Deadline) -> Void,
        onReminderTriggered: @escaping @Sendable (Deadline, DeadlineUrgency) -> Void,
        onDeadlineMissed: @escaping @Sendable (Deadline) -> Void
    ) {
        self.onDeadlineDiscovered = onDeadlineDiscovered
        self.onReminderTriggered = onReminderTriggered
        self.onDeadlineMissed = onDeadlineMissed
    }

    /// Set a custom reminder schedule for a specific category.
    /// - Parameters:
    ///   - schedule: The reminder schedule to use.
    ///   - category: The deadline category to configure.
    public func setReminderSchedule(_ schedule: ReminderSchedule, for category: DeadlineCategory) {
        reminderSchedules[category] = schedule
    }

    // MARK: - Lifecycle

    /// Start periodic scanning and reminder checking.
    ///
    /// Scanning runs every hour; reminder checks run every 15 minutes.
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // Start periodic scanning
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performPeriodicScan()
                try? await Task.sleep(for: .seconds(3600)) // Safe: sleep cancellation exits loop via Task.isCancelled; non-fatal // Every hour
            }
        }

        // Start reminder checking
        reminderTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkReminders()
                try? await Task.sleep(for: .seconds(900)) // Safe: sleep cancellation exits loop via Task.isCancelled; non-fatal // Every 15 minutes
            }
        }
    }

    /// Stop all scanning and reminder tasks.
    public func stop() {
        isRunning = false
        scanTask?.cancel()
        reminderTask?.cancel()
    }

    // MARK: - Deadline Management

    /// Add a manually created deadline.
    /// - Parameter deadline: The deadline to track.
    public func addDeadline(_ deadline: Deadline) {
        deadlines[deadline.id] = deadline
        onDeadlineDiscovered?(deadline)
    }

    /// Mark a deadline as completed.
    ///
    /// If the deadline is recurring, the next occurrence is automatically created.
    /// - Parameter id: The identifier of the deadline to complete.
    public func completeDeadline(_ id: UUID) {
        guard var deadline = deadlines[id] else { return }
        deadline.isCompleted = true
        deadline.completedAt = Date()
        deadlines[id] = deadline

        // If recurring, create next occurrence
        if deadline.isRecurring, let pattern = deadline.recurrencePattern {
            createNextOccurrence(deadline, pattern: pattern)
        }
    }

    /// Snooze a deadline's reminders until a specific date.
    /// - Parameters:
    ///   - id: The identifier of the deadline to snooze.
    ///   - until: The date until which reminders are suppressed.
    public func snoozeDeadline(_ id: UUID, until: Date) {
        guard var deadline = deadlines[id] else { return }
        deadline.snoozedUntil = until
        deadlines[id] = deadline
    }

    /// Returns all active (non-completed) deadlines sorted by due date.
    /// - Returns: Array of active deadlines, earliest due first.
    public func getActiveDeadlines() -> [Deadline] {
        deadlines.values
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    /// Returns active deadlines filtered by urgency level.
    /// - Parameter urgency: The urgency level to filter by.
    /// - Returns: Matching deadlines sorted by due date.
    public func getDeadlines(urgency: DeadlineUrgency) -> [Deadline] {
        getActiveDeadlines().filter { $0.urgency == urgency }
    }

    /// Returns active deadlines filtered by category.
    /// - Parameter category: The category to filter by.
    /// - Returns: Matching deadlines sorted by due date.
    public func getDeadlines(category: DeadlineCategory) -> [Deadline] {
        getActiveDeadlines().filter { $0.category == category }
    }

    /// Returns all overdue deadlines.
    /// - Returns: Active deadlines past their due date.
    public func getOverdueDeadlines() -> [Deadline] {
        getActiveDeadlines().filter { $0.urgency == .overdue }
    }

    /// Returns active deadlines due within the specified time interval from now.
    /// - Parameter within: Maximum time interval from now.
    /// - Returns: Deadlines due before `Date() + within`.
    public func getDeadlines(within: TimeInterval) -> [Deadline] {
        let cutoff = Date().addingTimeInterval(within)
        return getActiveDeadlines().filter { $0.dueDate <= cutoff }
    }

    // MARK: - Content Processing

    /// Process text content to extract deadlines.
    ///
    /// Runs all registered extractors against the content and stores
    /// any non-duplicate deadlines discovered.
    /// - Parameters:
    ///   - content: The text to analyze.
    ///   - source: The origin of the content.
    ///   - sourceURL: Optional URL where the content was found.
    ///   - sourceFile: Optional file path of the content.
    /// - Returns: Newly discovered deadlines (excludes duplicates).
    public func processContent(
        _ content: String,
        source: DeadlineSource,
        sourceURL: String? = nil,
        sourceFile: String? = nil
    ) async -> [Deadline] {
        var extractedDeadlines: [Deadline] = []

        for extractor in extractors {
            let results = await extractor.extract(
                from: content,
                source: source,
                context: Deadline.ExtractionContext(
                    sourceText: content.prefix(500).description,
                    sourceURL: sourceURL,
                    sourceFile: sourceFile,
                    extractionMethod: extractor.name,
                    timestamp: Date()
                )
            )

            for deadline in results {
                if !isDuplicate(deadline) {
                    extractedDeadlines.append(deadline)
                    deadlines[deadline.id] = deadline
                    onDeadlineDiscovered?(deadline)
                }
            }
        }

        return extractedDeadlines
    }

    /// Process an email for deadlines.
    /// - Parameters:
    ///   - subject: Email subject line.
    ///   - body: Email body text.
    ///   - sender: Sender address or name.
    ///   - receivedDate: When the email was received.
    /// - Returns: Deadlines extracted from the email.
    public func processEmail(
        subject: String,
        body: String,
        sender: String,
        receivedDate: Date
    ) async -> [Deadline] {
        let fullContent = "Subject: \(subject)\nFrom: \(sender)\n\n\(body)"
        return await processContent(fullContent, source: .email)
    }

    /// Process a scanned document for deadlines.
    /// - Parameters:
    ///   - ocrText: OCR-extracted text from the document.
    ///   - documentType: Type of document (e.g. "tax", "bill", "invoice").
    ///   - filePath: File system path to the scanned document.
    /// - Returns: Deadlines extracted from the document.
    public func processScannedDocument(
        ocrText: String,
        documentType: String,
        filePath: String
    ) async -> [Deadline] {
        let source: DeadlineSource = documentType.lowercased().contains("tax") ? .taxDocument :
                                     documentType.lowercased().contains("bill") ? .bill :
                                     documentType.lowercased().contains("invoice") ? .invoice :
                                     .scannedMail

        return await processContent(ocrText, source: source, sourceFile: filePath)
    }

    /// Process a call transcript for commitments and deadlines.
    /// - Parameters:
    ///   - transcript: Full transcript text.
    ///   - participants: Names or identifiers of call participants.
    ///   - callDate: When the call took place.
    /// - Returns: Deadlines extracted from the transcript.
    public func processCallTranscript(
        transcript: String,
        participants: [String],
        callDate: Date
    ) async -> [Deadline] {
        await processContent(transcript, source: .voiceCall)
    }

    // MARK: - Internal Methods

    func performPeriodicScan() async {
        #if canImport(EventKit)
        let store = EKEventStore()

        // Scan calendar events for upcoming deadlines (next 30 days)
        let now = Date()
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: thirtyDaysLater, calendars: nil)
        let events = store.events(matching: predicate)

        for event in events {
            let content = "Calendar event: \(event.title ?? "Untitled") on \(event.startDate?.description ?? "unknown date")"
            if let notes = event.notes {
                _ = await processContent("\(content)\n\(notes)", source: .calendar)
            } else {
                _ = await processContent(content, source: .calendar)
            }
        }

        // Scan reminders with due dates
        let reminderCalendars = store.calendars(for: .reminder)
        for calendar in reminderCalendars {
            let reminderPredicate = store.predicateForIncompleteReminders(
                withDueDateStarting: now,
                ending: thirtyDaysLater,
                calendars: [calendar]
            )
            // Extract Sendable titles inside the callback to avoid sending EKReminder across isolation
            let titles: [String] = await withCheckedContinuation { continuation in
                store.fetchReminders(matching: reminderPredicate) { reminders in
                    let extracted = (reminders ?? []).map { $0.title ?? "Untitled" }
                    continuation.resume(returning: extracted)
                }
            }
            for title in titles {
                _ = await processContent("Reminder: \(title)", source: .reminders)
            }
        }
        #endif
    }

    func checkReminders() async {
        let now = Date()

        for (id, deadline) in deadlines {
            guard !deadline.isCompleted else { continue }

            // Skip if snoozed
            if let snoozedUntil = deadline.snoozedUntil, snoozedUntil > now {
                continue
            }

            // Check if it's time for a reminder
            let schedule = reminderSchedules[deadline.category] ?? ReminderSchedule.defaultSchedule(for: deadline.category)

            for reminderOffset in schedule.remindBefore {
                let reminderTime = deadline.dueDate.addingTimeInterval(-reminderOffset)

                // If reminder time has passed and we haven't reminded recently
                if now >= reminderTime {
                    if let lastReminded = deadline.lastRemindedAt {
                        // Check if enough time has passed since last reminder
                        if now.timeIntervalSince(lastReminded) < deadline.urgency.reminderFrequency {
                            continue
                        }
                    }

                    // Trigger reminder
                    onReminderTriggered?(deadline, deadline.urgency)

                    // Update last reminded
                    var updated = deadline
                    updated.lastRemindedAt = now
                    deadlines[id] = updated

                    break // Only one reminder per check cycle
                }
            }

            // Check for missed deadlines
            if deadline.urgency == .overdue {
                onDeadlineMissed?(deadline)
            }
        }
    }

    func isDuplicate(_ newDeadline: Deadline) -> Bool {
        for existing in deadlines.values {
            // Same title and due date within 1 hour
            if existing.title.lowercased() == newDeadline.title.lowercased() &&
               abs(existing.dueDate.timeIntervalSince(newDeadline.dueDate)) < 3600 {
                return true
            }
        }
        return false
    }

    func createNextOccurrence(_ deadline: Deadline, pattern: Deadline.RecurrencePattern) {
        var nextDate = deadline.dueDate

        switch pattern.frequency {
        case .daily:
            nextDate = Calendar.current.date(byAdding: .day, value: pattern.interval, to: deadline.dueDate)!
        case .weekly:
            nextDate = Calendar.current.date(byAdding: .weekOfYear, value: pattern.interval, to: deadline.dueDate)!
        case .biweekly:
            nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 2 * pattern.interval, to: deadline.dueDate)!
        case .monthly:
            nextDate = Calendar.current.date(byAdding: .month, value: pattern.interval, to: deadline.dueDate)!
        case .quarterly:
            nextDate = Calendar.current.date(byAdding: .month, value: 3 * pattern.interval, to: deadline.dueDate)!
        case .yearly:
            nextDate = Calendar.current.date(byAdding: .year, value: pattern.interval, to: deadline.dueDate)!
        }

        // Check if we're past the end date
        if let endDate = pattern.endDate, nextDate > endDate {
            return
        }

        let nextDeadline = Deadline(
            title: deadline.title,
            description: deadline.description,
            dueDate: nextDate,
            source: deadline.source,
            category: deadline.category,
            priority: deadline.priority,
            isRecurring: true,
            recurrencePattern: pattern,
            consequences: deadline.consequences,
            relatedItems: deadline.relatedItems,
            extractedFrom: deadline.extractedFrom,
            confidence: deadline.confidence
        )

        deadlines[nextDeadline.id] = nextDeadline
    }
}
