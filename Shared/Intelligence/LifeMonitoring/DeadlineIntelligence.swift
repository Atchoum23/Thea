// DeadlineIntelligence.swift
// THEA - Proactive Deadline & Timeline Tracking
// Created by Claude - February 2026
//
// Core actor definition for deadline detection, tracking, and reminder management.
//
// Extensions:
// - DeadlineIntelligence+Engine.swift:     Lifecycle, configuration, deadline management, content processing
// - DeadlineIntelligence+Extractors.swift: Extractor protocol and concrete implementations
// - DeadlineIntelligence+Model.swift:      Deadline data model with nested types and computed properties
// - DeadlineIntelligence+Types.swift:      DeadlineSource, DeadlineCategory, DeadlineUrgency enums

import Foundation
#if canImport(EventKit)
import EventKit
#endif

// MARK: - Deadline Intelligence Actor

/// AI engine for detecting, tracking, and reminding about deadlines.
///
/// `DeadlineIntelligence` monitors calendars, emails, documents, and other
/// sources for deadlines. It deduplicates discoveries, manages recurrence,
/// and triggers reminders via configurable callbacks.
///
/// Usage:
/// ```swift
/// let engine = DeadlineIntelligence.shared
/// await engine.configure(
///     onDeadlineDiscovered: { deadline in ... },
///     onReminderTriggered: { deadline, urgency in ... },
///     onDeadlineMissed: { deadline in ... }
/// )
/// await engine.start()
/// ```
public actor DeadlineIntelligence {
    // MARK: - Singleton

    public static let shared = DeadlineIntelligence()

    // MARK: - Stored Properties

    /// Active deadlines keyed by their unique identifier.
    var deadlines: [UUID: Deadline] = [:]

    /// Reminder schedules per deadline category.
    var reminderSchedules: [DeadlineCategory: ReminderSchedule] = [:]

    /// Registered deadline extractors run against incoming content.
    var extractors: [DeadlineExtractor] = [
        DatePatternExtractor(),
        KeywordExtractor(),
        FinancialExtractor(),
        LegalExtractor(),
        MedicalExtractor(),
        WorkExtractor()
    ]

    /// Whether the engine is actively scanning and checking reminders.
    var isRunning = false

    /// Background task that performs periodic calendar/reminder scans.
    var scanTask: Task<Void, Never>?

    /// Background task that checks for due reminders.
    var reminderTask: Task<Void, Never>?

    // MARK: - Callbacks

    /// Called when a new deadline is discovered from any source.
    var onDeadlineDiscovered: ((Deadline) -> Void)?

    /// Called when a reminder fires for a deadline at a given urgency level.
    var onReminderTriggered: ((Deadline, DeadlineUrgency) -> Void)?

    /// Called when a deadline passes its due date without being completed.
    var onDeadlineMissed: ((Deadline) -> Void)?

    // MARK: - Initialization

    init() {
        for category in DeadlineCategory.allCases {
            reminderSchedules[category] = ReminderSchedule.defaultSchedule(for: category)
        }
    }
}
