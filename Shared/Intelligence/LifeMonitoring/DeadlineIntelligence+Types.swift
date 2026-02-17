// DeadlineIntelligence+Types.swift
// THEA - Proactive Deadline & Timeline Tracking
// Created by Claude - February 2026
//
// Deadline source, category, and urgency enums

import Foundation

// MARK: - Deadline Source

/// Source where a deadline was discovered.
///
/// Covers calendar, communication, document, financial, work,
/// personal, and inferred origins.
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

// MARK: - Deadline Category

/// Category of deadline importance.
///
/// Each category carries a default priority used when no explicit
/// priority is specified for a ``Deadline``.
public enum DeadlineCategory: String, Sendable, CaseIterable {
    case financial           // Bills, taxes, payments
    case work                // Work deadlines, projects
    case health              // Medical appointments, medications
    case legal               // Legal deadlines, government
    case social              // Events, commitments
    case personal            // Personal goals, tasks
    case administrative      // Renewals, paperwork
    case educational         // Courses, certifications

    /// Default priority for this category (1-10 scale, higher = more important).
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

// MARK: - Deadline Urgency

/// Urgency level based on time remaining until a deadline.
///
/// Determines how frequently reminders are sent.
public enum DeadlineUrgency: String, Sendable {
    case overdue
    case critical              // < 24 hours
    case urgent                // 1-3 days
    case approaching           // 3-7 days
    case upcoming              // 1-4 weeks
    case future                // > 4 weeks

    /// Minimum interval between consecutive reminders for this urgency level.
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
