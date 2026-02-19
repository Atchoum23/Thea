// AmbientLifeJournal.swift
// Thea — Automatic Daily Narrative Generator
//
// Creates a searchable daily journal from all passive life data sources.
// No user input required: aggregates HealthKit, BehavioralFingerprint,
// MoodTracker, CalendarMonitor, WeatherMonitor, and LifeMonitoringCoordinator
// into a natural-language daily story persisted as individual JSON files.

import Foundation
import os.log

// MARK: - Journal Metrics

struct JournalMetrics: Codable, Sendable {
    var sleepHours: Double?
    var stepCount: Int?
    var exerciseMinutes: Int?
    var screenTimeMinutes: Int?
    var messagesExchanged: Int?
    var meetingsAttended: Int?
    var deepWorkMinutes: Int?
    var weatherSummary: String?
}

// MARK: - Journal Entry

struct JournalEntry: Codable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    var narrative: String
    var highlights: [String]
    var metrics: JournalMetrics
    var mood: Double?
    var userAnnotation: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        narrative: String,
        highlights: [String],
        metrics: JournalMetrics,
        mood: Double? = nil,
        userAnnotation: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.narrative = narrative
        self.highlights = highlights
        self.metrics = metrics
        self.mood = mood
        self.userAnnotation = userAnnotation
        self.createdAt = createdAt
    }
}

// MARK: - Ambient Life Journal

// @unchecked Sendable: @MainActor provides isolation for all mutable state; NSObject
// bridging requires explicit @unchecked Sendable to cross actor boundaries in callbacks
@MainActor
@Observable
final class AmbientLifeJournal: @unchecked Sendable {
    static let shared = AmbientLifeJournal()

    private let logger = Logger(subsystem: "ai.thea.app", category: "AmbientLifeJournal")

    // MARK: - State

    private(set) var entries: [JournalEntry] = []
    private(set) var todayEntry: JournalEntry?

    // MARK: - Persistence

    private static let journalDirectory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thea/Journal", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) // Safe: directory may already exist; error means journal not persisted (works in-memory)
        return dir
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.locale = Locale.current
        return formatter
    }()

    // MARK: - Init

    private init() {
        loadAllEntries()
        updateTodayEntry()
    }

    // MARK: - Entry Generation

    /// Aggregate all passive data sources and produce a daily journal entry.
    func generateDailyEntry(for date: Date = Date()) async -> JournalEntry {
        logger.info("Generating daily journal entry for \(Self.dateFormatter.string(from: date))")

        var metrics = JournalMetrics()
        var highlights: [String] = []

        // --- HealthKit data via BehavioralFingerprint wake/sleep times ---
        let fingerprint = BehavioralFingerprint.shared
        let wakeHour = fingerprint.typicalWakeTime
        let sleepHour = fingerprint.typicalSleepTime

        // Estimate sleep from wake/sleep boundaries
        let estimatedSleep = wakeHour <= sleepHour
            ? Double(24 - sleepHour + wakeHour)
            : Double(wakeHour - sleepHour)
        if estimatedSleep > 0 && estimatedSleep < 16 {
            metrics.sleepHours = estimatedSleep
        }

        // --- Deep work and activity from BehavioralFingerprint ---
        let calendar = Calendar.current
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7 // Monday = 0
        let dayIndex = max(0, min(weekday, 6))

        if let dayOfWeek = DayOfWeek.allCases.first(where: { $0.index == dayIndex }) {
            let hourlySummary = fingerprint.dailySummary(for: dayOfWeek)
            let deepWorkHours = hourlySummary.filter { $0.dominantActivity == .deepWork }
            let meetingHours = hourlySummary.filter { $0.dominantActivity == .meetings }
            let commHours = hourlySummary.filter { $0.dominantActivity == .communication }

            if !deepWorkHours.isEmpty {
                metrics.deepWorkMinutes = deepWorkHours.count * 60
                highlights.append("Deep focus work during \(deepWorkHours.count) hour(s) of the day")
            }
            if !meetingHours.isEmpty {
                metrics.meetingsAttended = meetingHours.count
                highlights.append("Attended \(meetingHours.count) meeting(s)")
            }
            if !commHours.isEmpty {
                metrics.messagesExchanged = commHours.count * 5 // Estimate ~5 msgs per comm hour
            }
        }

        // --- Weather from WeatherMonitor ---
        if let weather = WeatherMonitor.shared.currentWeather {
            let tempStr = String(format: "%.0f", weather.temperature)
            metrics.weatherSummary = "\(weather.condition), \(tempStr) C"
            if weather.uvIndex >= 8 {
                highlights.append("High UV index (\(weather.uvIndex)) — sun protection recommended")
            }
        }

        // --- Mood from MoodTracker ---
        let moodTracker = MoodTracker.shared
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let averageMood = moodTracker.averageMood(from: dayStart, to: dayEnd)
        let moodScore = averageMood ?? Double(moodTracker.currentMoodScore)

        // --- Build narrative ---
        let narrative = buildNarrative(metrics: metrics, highlights: highlights, date: date)

        let entry = JournalEntry(
            date: dayStart,
            narrative: narrative,
            highlights: highlights,
            metrics: metrics,
            mood: moodScore
        )

        // Store and persist
        if let existingIndex = entries.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        }) {
            // Preserve any user annotation from the existing entry
            var updatedEntry = entry
            updatedEntry.userAnnotation = entries[existingIndex].userAnnotation
            entries[existingIndex] = updatedEntry
        } else {
            entries.append(entry)
        }

        // Sort entries by date descending (most recent first)
        entries.sort { $0.date > $1.date }
        updateTodayEntry()
        saveEntry(entry)

        logger.info("Journal entry generated with \(highlights.count) highlights")
        return entry
    }

    // MARK: - Narrative Builder

    /// Produces a template-based natural-language daily narrative (~150-250 words).
    func buildNarrative(metrics: JournalMetrics, highlights: [String], date: Date) -> String {
        let dateString = Self.displayDateFormatter.string(from: date)
        var sections: [String] = []

        // Header
        sections.append("\(dateString):")

        // Morning section: sleep
        if let sleep = metrics.sleepHours {
            let quality = sleepQualityDescription(hours: sleep)
            sections.append("You slept \(String(format: "%.1f", sleep)) hours with \(quality) rest.")
        }

        // Daytime section: productivity, meetings, communications
        var daytimeParts: [String] = []

        if let deepWork = metrics.deepWorkMinutes, deepWork > 0 {
            let hours = Double(deepWork) / 60.0
            if hours >= 1.0 {
                daytimeParts.append("\(String(format: "%.1f", hours)) hours of deep focus work")
            } else {
                daytimeParts.append("\(deepWork) minutes of focused work")
            }
        }

        if let meetings = metrics.meetingsAttended, meetings > 0 {
            daytimeParts.append("\(meetings) meeting\(meetings == 1 ? "" : "s")")
        }

        if let messages = metrics.messagesExchanged, messages > 0 {
            daytimeParts.append("\(messages) messages exchanged")
        }

        if !daytimeParts.isEmpty {
            let productivity = daytimeParts.joined(separator: ", ")
            sections.append("Your day included \(productivity).")
        }

        // Health section: steps, exercise, mood
        var healthParts: [String] = []

        if let steps = metrics.stepCount, steps > 0 {
            let formatted = NumberFormatter.localizedString(
                from: NSNumber(value: steps),
                number: .decimal
            )
            healthParts.append("walked \(formatted) steps")
        }

        if let exercise = metrics.exerciseMinutes, exercise > 0 {
            healthParts.append("exercised for \(exercise) minutes")
        }

        if !healthParts.isEmpty {
            sections.append("You \(healthParts.joined(separator: " and ")).")
        }

        // Screen time
        if let screenTime = metrics.screenTimeMinutes, screenTime > 0 {
            let hours = screenTime / 60
            let minutes = screenTime % 60
            if hours > 0 {
                sections.append("Screen time totaled \(hours)h \(minutes)m.")
            } else {
                sections.append("Screen time totaled \(minutes) minutes.")
            }
        }

        // Weather section
        if let weather = metrics.weatherSummary {
            sections.append("Weather was \(weather.lowercased()).")
        }

        // Mood summary
        sections.append(moodSummaryDescription(mood: nil))

        // Highlights
        if !highlights.isEmpty {
            let notable = highlights.prefix(3).joined(separator: ". ")
            sections.append("Notable: \(notable).")
        }

        return sections.joined(separator: " ")
    }

    // MARK: - Search

    /// Search all journal entries by text content in narrative, highlights, and annotations.
    func searchEntries(query: String) -> [JournalEntry] {
        let lowered = query.lowercased()
        return entries.filter { entry in
            entry.narrative.lowercased().contains(lowered)
                || entry.highlights.contains(where: { $0.lowercased().contains(lowered) })
                || (entry.userAnnotation?.lowercased().contains(lowered) ?? false)
        }
    }

    /// Find the journal entry for a specific date.
    // periphery:ignore - Reserved: entryFor(date:) instance method — reserved for future feature activation
    func entryFor(date: Date) -> JournalEntry? {
        let calendar = Calendar.current
        // periphery:ignore - Reserved: entryFor(date:) instance method reserved for future feature activation
        return entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    /// Return the most recent N entries (sorted by date descending).
    // periphery:ignore - Reserved: recentEntries(limit:) instance method — reserved for future feature activation
    func recentEntries(limit: Int = 7) -> [JournalEntry] {
        // periphery:ignore - Reserved: recentEntries(limit:) instance method reserved for future feature activation
        Array(entries.prefix(limit))
    }

    // MARK: - User Annotation

    /// Allow the user to add or edit a personal note on a journal entry.
    // periphery:ignore - Reserved: annotateEntry(for:annotation:) instance method reserved for future feature activation
    func annotateEntry(for date: Date, annotation: String) {
        let calendar = Calendar.current
        guard let index = entries.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: date)
        }) else {
            logger.warning("No entry found for annotation on \(Self.dateFormatter.string(from: date))")
            return
        }
        entries[index].userAnnotation = annotation.isEmpty ? nil : annotation
        saveEntry(entries[index])
        updateTodayEntry()
        logger.info("User annotation updated for \(Self.dateFormatter.string(from: date))")
    }

    // MARK: - Persistence

    private func fileURL(for date: Date) -> URL {
        let dateString = Self.dateFormatter.string(from: date)
        return Self.journalDirectory.appendingPathComponent("journal_\(dateString).json")
    }

    private func saveEntry(_ entry: JournalEntry) {
        let url = fileURL(for: entry.date)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(entry)
            try data.write(to: url, options: .atomic)
            logger.debug("Saved journal entry to \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to save journal entry: \(error.localizedDescription)")
        }
    }

    private func loadAllEntries() {
        let fm = FileManager.default
        let dir = Self.journalDirectory

        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { // Safe: directory missing or unreadable → start fresh; non-fatal
            logger.info("No journal directory contents found — starting fresh")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var loaded: [JournalEntry] = []
        for file in files where file.pathExtension == "json" && file.lastPathComponent.hasPrefix("journal_") {
            do {
                let data = try Data(contentsOf: file)
                let entry = try decoder.decode(JournalEntry.self, from: data)
                loaded.append(entry)
            } catch {
                logger.warning("Failed to decode \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Sort by date descending
        loaded.sort { $0.date > $1.date }
        entries = loaded
        logger.info("Loaded \(loaded.count) journal entries from disk")
    }

    private func updateTodayEntry() {
        let calendar = Calendar.current
        todayEntry = entries.first { calendar.isDateInToday($0.date) }
    }

    // MARK: - Narrative Helpers

    private func sleepQualityDescription(hours: Double) -> String {
        switch hours {
        case ..<5:
            return "poor"
        case 5..<6.5:
            return "fair"
        case 6.5..<8:
            return "good"
        case 8..<9.5:
            return "excellent"
        default:
            return "extended"
        }
    }

    private func moodSummaryDescription(mood: Double?) -> String {
        guard let mood else {
            return "Your mood averaged moderate throughout the day."
        }
        switch mood {
        case ..<0.2:
            return "Your mood was low for much of the day."
        case 0.2..<0.4:
            return "Your mood was somewhat subdued throughout the day."
        case 0.4..<0.6:
            return "Your mood averaged moderate throughout the day."
        case 0.6..<0.8:
            return "Your mood was generally positive throughout the day."
        default:
            return "Your mood was excellent throughout the day."
        }
    }
}
