// DeadlineIntelligence.swift
// THEA - Proactive Deadline & Timeline Tracking
// Created by Claude - February 2026
//
// Monitors ALL sources for deadlines, due dates, timelines, and important dates
// Proactively reminds user before things become urgent
//
// Types are in DeadlineIntelligence+Types.swift and DeadlineIntelligence+Model.swift
// Engine methods are in DeadlineIntelligence+Engine.swift
// Extractor implementations are in DeadlineIntelligence+Extractors.swift

import Foundation
import OSLog
#if canImport(EventKit)
import EventKit
#endif

// MARK: - Module Logger
let deadlineLogger = Logger(subsystem: "ai.thea.app", category: "DeadlineIntelligence")

// periphery:ignore - Reserved: deadlineLogger global var reserved for future feature activation

// MARK: - Deadline Intelligence Engine

/// AI engine for detecting, tracking, and reminding about deadlines
public actor DeadlineIntelligence {
    // MARK: - Singleton

    public static let shared = DeadlineIntelligence()

    // MARK: - Properties

    var deadlines: [UUID: Deadline] = [:]
    var reminderSchedules: [DeadlineCategory: ReminderSchedule] = [:]
    var extractors: [DeadlineExtractor] = [
        DatePatternExtractor(),
        KeywordExtractor(),
        FinancialExtractor(),
        LegalExtractor(),
        MedicalExtractor(),
        WorkExtractor()
    ]
    var isRunning = false
    var scanTask: Task<Void, Never>?
    var reminderTask: Task<Void, Never>?

    // Callbacks
    var onDeadlineDiscovered: ((Deadline) -> Void)?
    var onReminderTriggered: ((Deadline, DeadlineUrgency) -> Void)?
    var onDeadlineMissed: ((Deadline) -> Void)?

    // periphery:ignore - Reserved: logger property reserved for future feature activation
    let logger = Logger(subsystem: "ai.thea.app", category: "DeadlineIntelligence")

    // MARK: - Initialization

    private init() {
        // Set up default reminder schedules
        for category in DeadlineCategory.allCases {
            reminderSchedules[category] = ReminderSchedule.defaultSchedule(for: category)
        }
        // Extractors are initialized in property declaration
    }
}
