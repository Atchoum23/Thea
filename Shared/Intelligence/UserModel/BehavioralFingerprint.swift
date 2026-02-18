// BehavioralFingerprint.swift
// Thea — Temporal Behavioral Fingerprint
//
// Compressed, queryable model of the user's daily/weekly rhythms.
// Updated incrementally from existing monitors.
// Other systems query it: "When does the user typically do deep work?"

import Foundation
import OSLog

// MARK: - Behavioral Fingerprint

@MainActor
@Observable
final class BehavioralFingerprint {
    static let shared = BehavioralFingerprint()

    private let logger = Logger(subsystem: "com.thea.app", category: "BehavioralFingerprint")

    /// 7 days x 24 hours = 168 time slots
    private(set) var timeSlots: [[TimeSlot]]  // [dayOfWeek][hour]

    /// User's preferred wake/sleep times (learned)
    private(set) var typicalWakeTime: Int = 7   // hour (0-23)
    private(set) var typicalSleepTime: Int = 23

    /// Overall responsiveness score (0.0-1.0)
    private(set) var overallResponsiveness: Double = 0.5

    /// Data points collected
    private(set) var totalObservations: Int = 0

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Logger(subsystem: "ai.thea.app", category: "BehavioralFingerprint").error("Failed to create storage directory: \(error.localizedDescription)")
        }
        return dir.appendingPathComponent("behavioral_fingerprint.json")
    }()

    private init() {
        timeSlots = (0..<7).map { _ in
            (0..<24).map { _ in TimeSlot() }
        }
        loadFromDisk()
    }

    // MARK: - Observation Recording

    /// Record an activity observation at the current time
    func recordActivity(_ activity: BehavioralActivityType) {
        let calendar = Calendar.current
        let now = Date()
        let weekday = (calendar.component(.weekday, from: now) + 5) % 7 // Monday=0
        let hour = calendar.component(.hour, from: now)

        guard weekday < 7, hour < 24 else { return }

        timeSlots[weekday][hour].recordActivity(activity)
        totalObservations += 1

        // Update wake/sleep estimates
        if activity != .sleep, activity != .idle {
            if hour < typicalWakeTime || (hour < 6 && totalObservations > 100) {
                typicalWakeTime = hour
            }
            if hour > typicalSleepTime || (hour > 20 && totalObservations > 100) {
                typicalSleepTime = hour
            }
        }

        // Save periodically
        if totalObservations % 50 == 0 {
            saveToDisk()
        }
    }

    /// Record notification engagement
    func recordNotificationEngagement(engaged: Bool) {
        let calendar = Calendar.current
        let now = Date()
        let weekday = (calendar.component(.weekday, from: now) + 5) % 7
        let hour = calendar.component(.hour, from: now)

        guard weekday < 7, hour < 24 else { return }

        timeSlots[weekday][hour].recordNotificationResponse(engaged: engaged)

        // Update overall responsiveness
        let total = timeSlots.flatMap { $0 }
        let responded = total.reduce(0) { $0 + $1.notificationsEngaged }
        let sent = total.reduce(0) { $0 + $1.notificationsSent }
        overallResponsiveness = sent > 0 ? Double(responded) / Double(sent) : 0.5
    }

    // MARK: - Convenience Aliases

    /// Alias for saveToDisk() — used by orchestrator
    func save() { saveToDisk() }

    /// Alias for loadFromDisk() — used by orchestrator
    func load() { loadFromDisk() }

    /// Total number of time slots with recorded data
    var totalRecordedSlots: Int {
        timeSlots.flatMap { $0 }.filter { !$0.activityCounts.isEmpty }.count
    }

    // MARK: - Querying

    /// Get the dominant activity for a specific time
    func dominantActivity(day: DayOfWeek, hour: Int) -> BehavioralActivityType {
        guard hour >= 0, hour < 24 else { return .idle }
        return timeSlots[day.index][hour].dominantActivity
    }

    /// Get receptivity score for a specific time (0.0-1.0)
    func receptivity(day: DayOfWeek, hour: Int) -> Double {
        guard hour >= 0, hour < 24 else { return 0.0 }
        return timeSlots[day.index][hour].receptivityScore
    }

    /// Find the best time for a specific activity type on a given day
    func bestTimeFor(_ activity: BehavioralActivityType, on day: DayOfWeek) -> Int? {
        let daySlots = timeSlots[day.index]
        var bestHour: Int?
        var bestScore: Double = 0

        for hour in typicalWakeTime...min(typicalSleepTime, 23) {
            let slot = daySlots[hour]
            let score = slot.activityScore(for: activity)
            if score > bestScore {
                bestScore = score
                bestHour = hour
            }
        }

        return bestHour
    }

    /// Find the best time to send a notification
    func bestNotificationTime(on day: DayOfWeek) -> Int {
        let daySlots = timeSlots[day.index]
        var bestHour = 9 // Default: 9 AM
        var bestReceptivity: Double = 0

        for hour in typicalWakeTime...min(typicalSleepTime, 23) {
            let receptivity = daySlots[hour].receptivityScore
            if receptivity > bestReceptivity {
                bestReceptivity = receptivity
                bestHour = hour
            }
        }

        return bestHour
    }

    /// Get a summary of the user's typical day
    func dailySummary(for day: DayOfWeek) -> [BehavioralHourSummary] {
        timeSlots[day.index].enumerated().map { hour, slot in
            BehavioralHourSummary(
                hour: hour,
                dominantActivity: slot.dominantActivity,
                receptivity: slot.receptivityScore,
                cognitiveLoad: slot.averageCognitiveLoad
            )
        }
    }

    /// Is the user likely awake at this time?
    func isLikelyAwake(at hour: Int) -> Bool {
        hour >= typicalWakeTime && hour <= typicalSleepTime
    }

    /// Current time context
    func currentContext() -> BehavioralTimeContext {
        let calendar = Calendar.current
        let now = Date()
        let weekday = (calendar.component(.weekday, from: now) + 5) % 7
        let hour = calendar.component(.hour, from: now)

        guard weekday < 7, hour < 24 else {
            return BehavioralTimeContext(activity: .idle, receptivity: 0.5, cognitiveLoad: 0.5, isAwake: true)
        }

        let slot = timeSlots[weekday][hour]
        return BehavioralTimeContext(
            activity: slot.dominantActivity,
            receptivity: slot.receptivityScore,
            cognitiveLoad: slot.averageCognitiveLoad,
            isAwake: isLikelyAwake(at: hour)
        )
    }

    // MARK: - Persistence

    func saveToDisk() {
        let data = FingerprintData(
            timeSlots: timeSlots,
            typicalWakeTime: typicalWakeTime,
            typicalSleepTime: typicalSleepTime,
            overallResponsiveness: overallResponsiveness,
            totalObservations: totalObservations
        )

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save fingerprint: \(error.localizedDescription)")
        }
    }

    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let fingerprint = try JSONDecoder().decode(FingerprintData.self, from: data)
            timeSlots = fingerprint.timeSlots
            typicalWakeTime = fingerprint.typicalWakeTime
            typicalSleepTime = fingerprint.typicalSleepTime
            overallResponsiveness = fingerprint.overallResponsiveness
            totalObservations = fingerprint.totalObservations
            logger.info("Behavioral fingerprint loaded (\(self.totalObservations) observations)")
        } catch {
            logger.error("Failed to load fingerprint: \(error.localizedDescription)")
        }
    }
}

// MARK: - Time Slot

struct TimeSlot: Codable, Sendable {
    var activityCounts: [String: Int] = [:]
    var notificationsSent: Int = 0
    var notificationsEngaged: Int = 0
    var cognitiveLoadSamples: [Double] = []

    var dominantActivity: BehavioralActivityType {
        guard let (activity, _) = activityCounts.max(by: { $0.value < $1.value }) else {
            return .idle
        }
        return BehavioralActivityType(rawValue: activity) ?? .idle
    }

    var receptivityScore: Double {
        guard notificationsSent > 0 else { return 0.5 } // Unknown = neutral
        return Double(notificationsEngaged) / Double(notificationsSent)
    }

    var averageCognitiveLoad: Double {
        guard !cognitiveLoadSamples.isEmpty else { return 0.5 }
        return cognitiveLoadSamples.reduce(0, +) / Double(cognitiveLoadSamples.count)
    }

    mutating func recordActivity(_ activity: BehavioralActivityType) {
        activityCounts[activity.rawValue, default: 0] += 1
    }

    mutating func recordNotificationResponse(engaged: Bool) {
        notificationsSent += 1
        if engaged { notificationsEngaged += 1 }
    }

    func activityScore(for activity: BehavioralActivityType) -> Double {
        let total = activityCounts.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(activityCounts[activity.rawValue, default: 0]) / Double(total)
    }
}

// MARK: - Types

enum BehavioralActivityType: String, Codable, Sendable, CaseIterable {
    case deepWork       // Coding, writing, focused tasks
    case meetings       // Calendar events, video calls
    case browsing       // Web browsing, reading
    case communication  // Email, messaging, chat
    case exercise       // Physical activity
    case leisure        // Entertainment, social media
    case sleep          // Sleeping / device off
    case idle           // No significant activity detected
    case healthSuggestion // Health coaching intervention
}

enum DayOfWeek: String, Sendable, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var index: Int {
        switch self {
        case .monday: 0
        case .tuesday: 1
        case .wednesday: 2
        case .thursday: 3
        case .friday: 4
        case .saturday: 5
        case .sunday: 6
        }
    }
}

struct BehavioralHourSummary: Sendable {
    let hour: Int
    let dominantActivity: BehavioralActivityType
    let receptivity: Double
    let cognitiveLoad: Double
}

struct BehavioralTimeContext: Sendable {
    let activity: BehavioralActivityType
    let receptivity: Double
    let cognitiveLoad: Double
    let isAwake: Bool
}

private struct FingerprintData: Codable {
    let timeSlots: [[TimeSlot]]
    let typicalWakeTime: Int
    let typicalSleepTime: Int
    let overallResponsiveness: Double
    let totalObservations: Int
}
