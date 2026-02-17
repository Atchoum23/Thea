// DeadlineIntelligence+Model.swift
// THEA - Proactive Deadline & Timeline Tracking
// Created by Claude - February 2026
//
// Core Deadline data model with nested types and computed properties

import Foundation

// MARK: - Deadline Model

/// A detected deadline or important date.
///
/// Deadlines are discovered by ``DeadlineIntelligence`` from various sources
/// (emails, calendars, documents) and tracked until completed or expired.
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

    // MARK: - Nested Types

    /// Pattern describing how a recurring deadline repeats.
    public struct RecurrencePattern: Sendable {
        public let frequency: Frequency
        public let interval: Int
        public let endDate: Date?

        /// Recurrence frequency unit.
        public enum Frequency: String, Sendable {
            case daily, weekly, biweekly, monthly, quarterly, yearly
        }

        /// Creates a recurrence pattern.
        /// - Parameters:
        ///   - frequency: The recurrence frequency unit.
        ///   - interval: Number of frequency units between occurrences (default 1).
        ///   - endDate: Optional date after which recurrence stops.
        public init(frequency: Frequency, interval: Int = 1, endDate: Date? = nil) {
            self.frequency = frequency
            self.interval = interval
            self.endDate = endDate
        }
    }

    /// An item related to a deadline (e.g. a document, event, or task).
    public struct RelatedItem: Sendable {
        public let type: String
        public let identifier: String
        public let title: String?
    }

    /// Context describing how and where a deadline was extracted.
    public struct ExtractionContext: Sendable {
        public let sourceText: String?
        public let sourceURL: String?
        public let sourceFile: String?
        public let extractionMethod: String
        public let timestamp: Date
    }

    // MARK: - Computed Properties

    /// Current urgency level based on time remaining until the due date.
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

    /// Seconds remaining until the due date (negative if overdue).
    public var timeRemaining: TimeInterval {
        dueDate.timeIntervalSince(Date())
    }

    /// Human-readable string describing time remaining (e.g. "3 days remaining" or "Overdue by 2 hours").
    public var formattedTimeRemaining: String {
        let remaining = timeRemaining
        if remaining < 0 {
            return "Overdue by \(formatDuration(abs(remaining)))"
        }
        return "\(formatDuration(remaining)) remaining"
    }

    // MARK: - Private Helpers

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

    // MARK: - Initializer

    /// Creates a new deadline.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - title: Short description of the deadline.
    ///   - description: Optional longer description.
    ///   - dueDate: When the deadline expires.
    ///   - source: Where the deadline was discovered.
    ///   - category: Classification category.
    ///   - priority: Importance 1-10 (defaults to category's default).
    ///   - isRecurring: Whether this deadline repeats.
    ///   - recurrencePattern: How it repeats (required if `isRecurring` is true).
    ///   - consequences: What happens if the deadline is missed.
    ///   - relatedItems: Associated documents, events, or tasks.
    ///   - extractedFrom: Context about extraction origin.
    ///   - confidence: Extraction confidence score 0-1 (default 0.8).
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

/// Configuration for how and when to remind about deadlines in a given category.
public struct ReminderSchedule: Sendable {
    public let deadlineCategory: DeadlineCategory
    /// Time intervals (in seconds) before the deadline at which reminders fire.
    public let remindBefore: [TimeInterval]
    /// Channels through which reminders are delivered.
    public let reminderChannels: [ReminderChannel]

    /// Channel through which a reminder can be delivered.
    public enum ReminderChannel: String, Sendable {
        case notification
        case voice
        case email
        case calendar
        case widget
    }

    /// Returns the default reminder schedule for the given category.
    /// - Parameter category: The deadline category.
    /// - Returns: A `ReminderSchedule` with sensible defaults.
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
