// DeadlineIntelligence.swift
// THEA - Proactive Deadline & Timeline Tracking
// Created by Claude - February 2026
//
// Monitors ALL sources for deadlines, due dates, timelines, and important dates
// Proactively reminds user before things become urgent

import Foundation
import OSLog
#if canImport(EventKit)
import EventKit
#endif

// MARK: - Module Logger
private let deadlineLogger = Logger(subsystem: "ai.thea.app", category: "DeadlineIntelligence")

// MARK: - Deadline Types

/// Source where a deadline was discovered
public enum DeadlineSource: String, Sendable, CaseIterable {
    // Calendar & Reminders
    case calendar
    case reminders

    // Communications
    case email
    case message
    case slack
    case teams

    // Documents
    case document
    case spreadsheet
    case pdf
    case scannedMail = "scanned_mail"

    // Financial
    case bill
    case invoice
    case taxDocument = "tax_document"
    case bankStatement = "bank_statement"

    // Work
    case projectManagement = "project_management"
    case jira
    case asana
    case github

    // Personal
    case subscriptionRenewal = "subscription_renewal"
    case warranty
    case medicalAppointment = "medical_appointment"
    case governmentDeadline = "government_deadline"

    // Inferred
    case patternBased = "pattern_based"
    case webContent = "web_content"
    case voiceCall = "voice_call"
}

/// Category of deadline importance
public enum DeadlineCategory: String, Sendable, CaseIterable {
    case financial           // Bills, taxes, payments
    case work                // Work deadlines, projects
    case health              // Medical appointments, medications
    case legal               // Legal deadlines, government
    case social              // Events, commitments
    case personal            // Personal goals, tasks
    case administrative      // Renewals, paperwork
    case educational         // Courses, certifications

    public var defaultPriority: Int {
        switch self {
        case .legal: return 10
        case .financial: return 9
        case .health: return 8
        case .work: return 7
        case .educational: return 6
        case .administrative: return 5
        case .social: return 4
        case .personal: return 3
        }
    }
}

/// Urgency level based on time remaining
public enum DeadlineUrgency: String, Sendable {
    case overdue
    case critical              // < 24 hours
    case urgent                // 1-3 days
    case approaching           // 3-7 days
    case upcoming              // 1-4 weeks
    case future                // > 4 weeks

    public var reminderFrequency: TimeInterval {
        switch self {
        case .overdue: return 3600        // Every hour
        case .critical: return 7200       // Every 2 hours
        case .urgent: return 21600        // Every 6 hours
        case .approaching: return 86400   // Daily
        case .upcoming: return 259200     // Every 3 days
        case .future: return 604800       // Weekly
        }
    }
}

// MARK: - Deadline Model

/// A detected deadline or important date
public struct Deadline: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let dueDate: Date
    public let source: DeadlineSource
    public let category: DeadlineCategory
    public let priority: Int // 1-10, higher = more important
    public let isRecurring: Bool
    public let recurrencePattern: RecurrencePattern?
    public let consequences: [String]? // What happens if missed
    public let relatedItems: [RelatedItem]
    public let extractedFrom: ExtractionContext
    public let confidence: Double // 0-1, how confident we are
    public let createdAt: Date
    public var lastRemindedAt: Date?
    public var isCompleted: Bool
    public var completedAt: Date?
    public var snoozedUntil: Date?

    public struct RecurrencePattern: Sendable {
        public let frequency: Frequency
        public let interval: Int
        public let endDate: Date?

        public enum Frequency: String, Sendable {
            case daily, weekly, biweekly, monthly, quarterly, yearly
        }

        public init(frequency: Frequency, interval: Int = 1, endDate: Date? = nil) {
            self.frequency = frequency
            self.interval = interval
            self.endDate = endDate
        }
    }

    public struct RelatedItem: Sendable {
        public let type: String
        public let identifier: String
        public let title: String?
    }

    public struct ExtractionContext: Sendable {
        public let sourceText: String?
        public let sourceURL: String?
        public let sourceFile: String?
        public let extractionMethod: String
        public let timestamp: Date
    }

    public var urgency: DeadlineUrgency {
        let now = Date()
        let timeRemaining = dueDate.timeIntervalSince(now)

        if timeRemaining < 0 {
            return .overdue
        } else if timeRemaining < 86400 { // 24 hours
            return .critical
        } else if timeRemaining < 259200 { // 3 days
            return .urgent
        } else if timeRemaining < 604800 { // 7 days
            return .approaching
        } else if timeRemaining < 2419200 { // 4 weeks
            return .upcoming
        } else {
            return .future
        }
    }

    public var timeRemaining: TimeInterval {
        dueDate.timeIntervalSince(Date())
    }

    public var formattedTimeRemaining: String {
        let remaining = timeRemaining
        if remaining < 0 {
            return "Overdue by \(formatDuration(abs(remaining)))"
        }
        return "\(formatDuration(remaining)) remaining"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let days = hours / 24

        if days > 30 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let minutes = Int(duration / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        dueDate: Date,
        source: DeadlineSource,
        category: DeadlineCategory,
        priority: Int? = nil,
        isRecurring: Bool = false,
        recurrencePattern: RecurrencePattern? = nil,
        consequences: [String]? = nil,
        relatedItems: [RelatedItem] = [],
        extractedFrom: ExtractionContext,
        confidence: Double = 0.8
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.source = source
        self.category = category
        self.priority = priority ?? category.defaultPriority
        self.isRecurring = isRecurring
        self.recurrencePattern = recurrencePattern
        self.consequences = consequences
        self.relatedItems = relatedItems
        self.extractedFrom = extractedFrom
        self.confidence = confidence
        self.createdAt = Date()
        self.lastRemindedAt = nil
        self.isCompleted = false
        self.completedAt = nil
        self.snoozedUntil = nil
    }
}

// MARK: - Reminder Configuration

/// How and when to remind about deadlines
public struct ReminderSchedule: Sendable {
    public let deadlineCategory: DeadlineCategory
    public let remindBefore: [TimeInterval] // How long before deadline to remind
    public let reminderChannels: [ReminderChannel]

    public enum ReminderChannel: String, Sendable {
        case notification
        case voice
        case email
        case calendar
        case widget
    }

    public static func defaultSchedule(for category: DeadlineCategory) -> ReminderSchedule {
        switch category {
        case .financial:
            return ReminderSchedule(
                deadlineCategory: category,
                remindBefore: [604800, 259200, 86400, 21600], // 7d, 3d, 1d, 6h
                reminderChannels: [.notification, .voice, .widget]
            )
        case .legal:
            return ReminderSchedule(
                deadlineCategory: category,
                remindBefore: [2592000, 604800, 259200, 86400, 21600], // 30d, 7d, 3d, 1d, 6h
                reminderChannels: [.notification, .voice, .email, .widget]
            )
        case .health:
            return ReminderSchedule(
                deadlineCategory: category,
                remindBefore: [604800, 86400, 7200], // 7d, 1d, 2h
                reminderChannels: [.notification, .calendar]
            )
        case .work:
            return ReminderSchedule(
                deadlineCategory: category,
                remindBefore: [259200, 86400, 21600, 3600], // 3d, 1d, 6h, 1h
                reminderChannels: [.notification, .widget]
            )
        default:
            return ReminderSchedule(
                deadlineCategory: category,
                remindBefore: [86400, 21600], // 1d, 6h
                reminderChannels: [.notification]
            )
        }
    }
}

// MARK: - Deadline Intelligence Engine

/// AI engine for detecting, tracking, and reminding about deadlines
public actor DeadlineIntelligence {
    // MARK: - Singleton

    public static let shared = DeadlineIntelligence()

    // MARK: - Properties

    private var deadlines: [UUID: Deadline] = [:]
    private var reminderSchedules: [DeadlineCategory: ReminderSchedule] = [:]
    private var extractors: [DeadlineExtractor] = [
        DatePatternExtractor(),
        KeywordExtractor(),
        FinancialExtractor(),
        LegalExtractor(),
        MedicalExtractor(),
        WorkExtractor()
    ]
    private var isRunning = false
    private var scanTask: Task<Void, Never>?
    private var reminderTask: Task<Void, Never>?

    // Callbacks
    private var onDeadlineDiscovered: ((Deadline) -> Void)?
    private var onReminderTriggered: ((Deadline, DeadlineUrgency) -> Void)?
    private var onDeadlineMissed: ((Deadline) -> Void)?

    private let logger = Logger(subsystem: "ai.thea.app", category: "DeadlineIntelligence")

    // MARK: - Initialization

    private init() {
        // Set up default reminder schedules
        for category in DeadlineCategory.allCases {
            reminderSchedules[category] = ReminderSchedule.defaultSchedule(for: category)
        }
        // Extractors are initialized in property declaration
    }

    // MARK: - Configuration

    /// Configure callbacks
    public func configure(
        onDeadlineDiscovered: @escaping @Sendable (Deadline) -> Void,
        onReminderTriggered: @escaping @Sendable (Deadline, DeadlineUrgency) -> Void,
        onDeadlineMissed: @escaping @Sendable (Deadline) -> Void
    ) {
        self.onDeadlineDiscovered = onDeadlineDiscovered
        self.onReminderTriggered = onReminderTriggered
        self.onDeadlineMissed = onDeadlineMissed
    }

    /// Set custom reminder schedule for a category
    public func setReminderSchedule(_ schedule: ReminderSchedule, for category: DeadlineCategory) {
        reminderSchedules[category] = schedule
    }

    // MARK: - Lifecycle

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // Start periodic scanning
        scanTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performPeriodicScan()
                do {
                    try await Task.sleep(nanoseconds: 3600_000_000_000) // Every hour
                } catch {
                    break // Task cancelled
                }
            }
        }

        // Start reminder checking
        reminderTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkReminders()
                do {
                    try await Task.sleep(nanoseconds: 900_000_000_000) // Every 15 minutes
                } catch {
                    break // Task cancelled
                }
            }
        }
    }

    public func stop() {
        isRunning = false
        scanTask?.cancel()
        reminderTask?.cancel()
    }

    // MARK: - Deadline Management

    /// Add a manually created deadline
    public func addDeadline(_ deadline: Deadline) {
        deadlines[deadline.id] = deadline
        onDeadlineDiscovered?(deadline)
    }

    /// Mark a deadline as completed
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

    /// Snooze a deadline reminder
    public func snoozeDeadline(_ id: UUID, until: Date) {
        guard var deadline = deadlines[id] else { return }
        deadline.snoozedUntil = until
        deadlines[id] = deadline
    }

    /// Get all active deadlines
    public func getActiveDeadlines() -> [Deadline] {
        deadlines.values
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    /// Get deadlines by urgency
    public func getDeadlines(urgency: DeadlineUrgency) -> [Deadline] {
        getActiveDeadlines().filter { $0.urgency == urgency }
    }

    /// Get deadlines by category
    public func getDeadlines(category: DeadlineCategory) -> [Deadline] {
        getActiveDeadlines().filter { $0.category == category }
    }

    /// Get overdue deadlines
    public func getOverdueDeadlines() -> [Deadline] {
        getActiveDeadlines().filter { $0.urgency == .overdue }
    }

    /// Get upcoming deadlines within time range
    public func getDeadlines(within: TimeInterval) -> [Deadline] {
        let cutoff = Date().addingTimeInterval(within)
        return getActiveDeadlines().filter { $0.dueDate <= cutoff }
    }

    // MARK: - Content Processing

    /// Process text content to extract deadlines
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
                // Check if we already have this deadline
                if !isDuplicate(deadline) {
                    extractedDeadlines.append(deadline)
                    deadlines[deadline.id] = deadline
                    onDeadlineDiscovered?(deadline)
                }
            }
        }

        return extractedDeadlines
    }

    /// Process an email for deadlines
    public func processEmail(
        subject: String,
        body: String,
        sender: String,
        receivedDate: Date
    ) async -> [Deadline] {
        let fullContent = "Subject: \(subject)\nFrom: \(sender)\n\n\(body)"
        return await processContent(fullContent, source: .email)
    }

    /// Process a scanned document for deadlines
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

    /// Process a call transcript for commitments
    public func processCallTranscript(
        transcript: String,
        participants: [String],
        callDate: Date
    ) async -> [Deadline] {
        await processContent(transcript, source: .voiceCall)
    }

    // MARK: - Private Methods

    private func performPeriodicScan() async {
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

    private func checkReminders() async {
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

    private func isDuplicate(_ newDeadline: Deadline) -> Bool {
        for existing in deadlines.values {
            // Same title and due date within 1 hour
            if existing.title.lowercased() == newDeadline.title.lowercased() &&
               abs(existing.dueDate.timeIntervalSince(newDeadline.dueDate)) < 3600 {
                return true
            }
        }
        return false
    }

    private func createNextOccurrence(_ deadline: Deadline, pattern: Deadline.RecurrencePattern) {
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

// MARK: - Deadline Extractors

/// Protocol for deadline extraction
protocol DeadlineExtractor: Sendable {
    var name: String { get }
    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline]
}

/// Extracts deadlines based on date patterns
struct DatePatternExtractor: DeadlineExtractor {
    let name = "DatePattern"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        var deadlines: [Deadline] = []

        // Patterns that indicate deadlines
        let deadlinePatterns = [
            (pattern: #"(?i)due\s+(by|on|before)\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Due"),
            (pattern: #"(?i)deadline[:\s]+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Deadline"),
            (pattern: #"(?i)must be (submitted|filed|completed) by\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Submit by"),
            (pattern: #"(?i)payment due[:\s]+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Payment due"),
            (pattern: #"(?i)expires?\s+(?:on\s+)?(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Expires"),
            (pattern: #"(?i)renew(?:al)?\s+(?:by|before)\s+(\w+\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{4})"#, prefix: "Renew by")
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")

        let dateFormats = [
            "MMMM d, yyyy",
            "MMMM d yyyy",
            "MMM d, yyyy",
            "MMM d yyyy",
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "yyyy-MM-dd"
        ]

        for (pattern, prefix) in deadlinePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches {
                    let dateRangeIndex = match.numberOfRanges > 2 ? 2 : 1
                    guard dateRangeIndex < match.numberOfRanges else { continue }

                    let dateString = nsContent.substring(with: match.range(at: dateRangeIndex))
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "st", with: "")
                        .replacingOccurrences(of: "nd", with: "")
                        .replacingOccurrences(of: "rd", with: "")
                        .replacingOccurrences(of: "th", with: "")

                    // Try parsing with different formats
                    var parsedDate: Date?
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            parsedDate = date
                            break
                        }
                    }

                    guard let dueDate = parsedDate else { continue }

                    // Extract surrounding context for title
                    let contextStart = max(0, match.range.location - 50)
                    let contextEnd = min(nsContent.length, match.range.location + match.range.length + 50)
                    let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)
                    let surrounding = nsContent.substring(with: contextRange)

                    // Determine category from context
                    let category = categorize(content: content, surrounding: surrounding)

                    let deadline = Deadline(
                        title: "\(prefix): \(dateString)",
                        description: surrounding.trimmingCharacters(in: .whitespacesAndNewlines),
                        dueDate: dueDate,
                        source: source,
                        category: category,
                        extractedFrom: context,
                        confidence: 0.7
                    )

                    deadlines.append(deadline)
                }
            } catch {
                deadlineLogger.error("Invalid deadline extraction pattern '\(pattern)': \(error.localizedDescription)")
            }
        }

        return deadlines
    }

    private func categorize(content: String, surrounding: String) -> DeadlineCategory {
        let lowercased = (content + " " + surrounding).lowercased()

        if lowercased.contains("tax") || lowercased.contains("irs") || lowercased.contains("1040") {
            return .financial
        } else if lowercased.contains("payment") || lowercased.contains("bill") || lowercased.contains("invoice") {
            return .financial
        } else if lowercased.contains("legal") || lowercased.contains("court") || lowercased.contains("lawsuit") {
            return .legal
        } else if lowercased.contains("doctor") || lowercased.contains("appointment") || lowercased.contains("medical") {
            return .health
        } else if lowercased.contains("project") || lowercased.contains("work") || lowercased.contains("meeting") {
            return .work
        } else if lowercased.contains("license") || lowercased.contains("registration") || lowercased.contains("renew") {
            return .administrative
        }

        return .personal
    }
}

/// Extracts deadlines based on keywords
struct KeywordExtractor: DeadlineExtractor {
    let name = "Keyword"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        var deadlines: [Deadline] = []

        // Keyword patterns with relative dates
        let relativePatterns = [
            (#"(?i)(need|must|have to|should)\s+(\w+(?:\s+\w+)?)\s+by\s+(tomorrow|today|next\s+\w+|this\s+\w+)"#, ""),
            (#"(?i)remind me to\s+(.+?)\s+(tomorrow|next week|next month|on \w+day)"#, "Reminder"),
            (#"(?i)(expires?|expiring)\s+(in\s+\d+\s+(?:days?|weeks?|months?))"#, "Expiring")
        ]

        for (pattern, prefix) in relativePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches {
                    // Extract action and time reference
                    guard match.numberOfRanges >= 3 else { continue }

                    let timeRef = nsContent.substring(with: match.range(at: match.numberOfRanges - 1))
                    guard let dueDate = parseRelativeDate(timeRef) else { continue }

                    let fullMatch = nsContent.substring(with: match.range)
                    let title = prefix.isEmpty ? fullMatch : "\(prefix): \(fullMatch)"

                    let deadline = Deadline(
                        title: title,
                        dueDate: dueDate,
                        source: source,
                        category: .personal,
                        extractedFrom: context,
                        confidence: 0.6
                    )

                    deadlines.append(deadline)
                }
            } catch {
                deadlineLogger.error("Invalid relative date pattern '\(pattern)': \(error.localizedDescription)")
            }
        }

        return deadlines
    }

    private func parseRelativeDate(_ text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lowercased == "today" {
            return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now)
        } else if lowercased == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercased.contains("next week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if lowercased.contains("next month") {
            return calendar.date(byAdding: .month, value: 1, to: now)
        } else if lowercased.contains("this week") {
            // End of this week (Friday)
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilFriday = (6 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilFriday, to: now)
        }

        // Parse "in X days/weeks/months"
        do {
            let regex = try NSRegularExpression(pattern: #"in\s+(\d+)\s+(days?|weeks?|months?)"#, options: .caseInsensitive)
            let nsText = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                let number = Int(nsText.substring(with: match.range(at: 1))) ?? 0
                let unit = nsText.substring(with: match.range(at: 2)).lowercased()

                if unit.starts(with: "day") {
                    return calendar.date(byAdding: .day, value: number, to: now)
                } else if unit.starts(with: "week") {
                    return calendar.date(byAdding: .weekOfYear, value: number, to: now)
                } else if unit.starts(with: "month") {
                    return calendar.date(byAdding: .month, value: number, to: now)
                }
            }
        } catch {
            deadlineLogger.error("Invalid relative time pattern: \(error.localizedDescription)")
        }

        return nil
    }
}

/// Extracts financial deadlines (bills, taxes)
struct FinancialExtractor: DeadlineExtractor {
    let name = "Financial"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        var deadlines: [Deadline] = []

        // Tax deadline patterns
        let taxPatterns = [
            (#"(?i)tax return.+due.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Tax Return Due", [
                "Late filing penalty",
                "Interest on unpaid taxes",
                "Possible audit flag"
            ]),
            (#"(?i)quarterly estimated tax.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Estimated Tax Payment", [
                "Underpayment penalty"
            ]),
            (#"(?i)(?:1099|W-2|W2).+(?:file|submit|send).+(\w+\s+\d{1,2},?\s*\d{4})"#, "Tax Form Submission", [])
        ]

        // Bill patterns
        let billPatterns = [
            (#"(?i)payment of \$[\d,]+(?:\.\d{2})? (?:is )?due.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Bill Payment", [
                "Late payment fee",
                "Service interruption"
            ]),
            (#"(?i)balance of \$[\d,]+(?:\.\d{2})?.+due by.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Balance Due", []),
            (#"(?i)minimum payment.+\$[\d,]+(?:\.\d{2})?.+due.+(\w+\s+\d{1,2},?\s*\d{4})"#, "Minimum Payment Due", [
                "Late fee",
                "Interest charges",
                "Credit score impact"
            ])
        ]

        // Process patterns
        deadlines.append(contentsOf: processPatterns(taxPatterns, in: content, source: source, context: context, category: .financial))
        deadlines.append(contentsOf: processPatterns(billPatterns, in: content, source: source, context: context, category: .financial))

        return deadlines
    }

    private func processPatterns(
        _ patterns: [(String, String, [String])],
        in content: String,
        source: DeadlineSource,
        context: Deadline.ExtractionContext,
        category: DeadlineCategory
    ) -> [Deadline] {
        var deadlines: [Deadline] = []

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        let dateFormats = ["MMMM d, yyyy", "MMMM d yyyy", "MMM d, yyyy"]

        for (pattern, title, consequences) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsContent = content as NSString
                let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))

                for match in matches {
                    guard match.numberOfRanges >= 2 else { continue }

                    let dateString = nsContent.substring(with: match.range(at: 1))
                        .trimmingCharacters(in: .whitespaces)

                    var parsedDate: Date?
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            parsedDate = date
                            break
                        }
                    }

                    guard let dueDate = parsedDate else { continue }

                    let deadline = Deadline(
                        title: title,
                        description: nsContent.substring(with: match.range),
                        dueDate: dueDate,
                        source: source,
                        category: category,
                        priority: category.defaultPriority,
                        consequences: consequences.isEmpty ? nil : consequences,
                        extractedFrom: context,
                        confidence: 0.85
                    )

                    deadlines.append(deadline)
                }
            } catch {
                deadlineLogger.error("Invalid financial deadline pattern '\(pattern)': \(error.localizedDescription)")
            }
        }

        return deadlines
    }
}

/// Extracts legal deadlines
struct LegalExtractor: DeadlineExtractor {
    let name = "Legal"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        // Legal deadline extraction (court dates, filing deadlines, statute of limitations)
        // Implementation would check for legal terminology and deadlines
        []
    }
}

/// Extracts medical/health deadlines
struct MedicalExtractor: DeadlineExtractor {
    let name = "Medical"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        // Medical deadline extraction (appointments, prescription refills, checkups)
        // Implementation would check for medical terminology
        []
    }
}

/// Extracts work-related deadlines
struct WorkExtractor: DeadlineExtractor {
    let name = "Work"

    func extract(from content: String, source: DeadlineSource, context: Deadline.ExtractionContext) async -> [Deadline] {
        // Work deadline extraction (project deadlines, meetings, reviews)
        // Implementation would check for work terminology
        []
    }
}
