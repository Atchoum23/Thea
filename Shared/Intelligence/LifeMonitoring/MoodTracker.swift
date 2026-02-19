// MoodTracker.swift
// Thea — Mood Aggregation Service
//
// Aggregates mood signals from life monitoring events (message sentiment,
// app usage patterns, time-of-day patterns) into a rolling mood score.
// Feeds low-mood signals into BehavioralFingerprint as healthSuggestion.

import Combine
import Foundation
import OSLog

// MARK: - Types

struct MoodSample: Codable, Sendable {
    let timestamp: Date
    let score: Double // 0.0 (very negative) to 1.0 (very positive)
    let source: MoodSource
}

enum MoodSource: String, Codable, Sendable {
    case messageSentiment
    case appUsage
    case healthData
    case userReported
    case timePattern
}

enum MoodTrendDirection: String, Sendable {
    case improving, stable, declining
}

// periphery:ignore - Reserved: MoodTrendDirection type reserved for future feature activation
// MARK: - Mood Tracker

@MainActor
@Observable
final class MoodTracker {
    static let shared = MoodTracker()

    private let logger = Logger(subsystem: "com.thea.app", category: "MoodTracker")

    // MARK: - State

    private(set) var currentMoodScore: Double = 0.5
    private(set) var samples: [MoodSample] = []

    /// Exponential moving average weight for new samples
    private let emaAlpha = 0.3

    /// Maximum samples retained in memory (7 days at ~1/hour)
    private let maxSamples = 168

    private var cancellables = Set<AnyCancellable>()

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea", isDirectory: true)
            .appendingPathComponent("MoodTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) // Safe: directory may already exist; error means mood history not persisted (works in-memory)
        return dir.appendingPathComponent("mood_history.json")
    }()

    // MARK: - Productivity app bundles (focused = positive mood signal)

    private let productivityBundles: Set<String> = [
        "xcode", "terminal", "vscode", "sublime", "notes", "pages", "numbers", "keynote"
    ]

    private let socialBundles: Set<String> = [
        "instagram", "facebook", "twitter", "tiktok", "reddit", "whatsapp", "telegram", "discord"
    ]

    // MARK: - Init

    private init() {
        loadFromDisk()
        subscribeToEvents()
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() {
        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor in
                    self?.handleEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: LifeEvent) {
        switch event.type {
        case .messageSent, .messageReceived, .emailReceived, .emailSent:
            // Map sentiment (-1...1) to mood score (0...1)
            let score = (event.sentiment + 1.0) / 2.0
            recordSample(score: score, source: .messageSentiment)

        case .appSwitch:
            let appName = (event.data["appName"] ?? "").lowercased()
            if productivityBundles.contains(where: { appName.contains($0) }) {
                recordSample(score: 0.65, source: .appUsage) // Focused
            } else if socialBundles.contains(where: { appName.contains($0) }) {
                recordSample(score: 0.5, source: .appUsage) // Neutral
            }

        case .healthMetric:
            if let valueStr = event.data["value"], let value = Double(valueStr) {
                let category = event.data["category"] ?? ""
                if category == "mood" || category == "mindfulness" {
                    recordSample(score: min(max(value, 0), 1), source: .healthData)
                }
            }

        default:
            break
        }
    }

    // MARK: - Recording

    func recordSample(score: Double, source: MoodSource) {
        let clamped = min(max(score, 0), 1)
        let sample = MoodSample(timestamp: Date(), score: clamped, source: source)
        samples.append(sample)

        // Trim old samples
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }

        // Update EMA
        currentMoodScore = emaAlpha * clamped + (1.0 - emaAlpha) * currentMoodScore

        // Feed low mood into BehavioralFingerprint
        if currentMoodScore < 0.35 {
            BehavioralFingerprint.shared.recordActivity(.healthSuggestion)
        }

        // Persist periodically (every 10 samples)
        if samples.count % 10 == 0 {
            saveToDisk()
        }
    }

    /// Record a user-reported mood (e.g. from a mood check-in prompt)
    func reportMood(score: Double) {
        recordSample(score: score, source: .userReported)
    }

// periphery:ignore - Reserved: reportMood(score:) instance method reserved for future feature activation

    // MARK: - Querying

    /// Current mood as a clamped 0...1 value
    var currentMood: Double { currentMoodScore }

    // periphery:ignore - Reserved: currentMood property reserved for future feature activation
    /// Trend over the last N hours (default 6)
    func moodTrend(hours: Int = 6) -> MoodTrendDirection {
        // periphery:ignore - Reserved: moodTrend(hours:) instance method reserved for future feature activation
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let recent = samples.filter { $0.timestamp >= cutoff }
        guard recent.count >= 2 else { return .stable }

        let midpoint = recent.count / 2
        let firstHalf = recent.prefix(midpoint)
        let secondHalf = recent.suffix(from: midpoint)

        let avgFirst = firstHalf.reduce(0.0) { $0 + $1.score } / Double(firstHalf.count)
        let avgSecond = secondHalf.reduce(0.0) { $0 + $1.score } / Double(secondHalf.count)
        let delta = avgSecond - avgFirst

        if delta > 0.05 { return .improving }
        if delta < -0.05 { return .declining }
        return .stable
    }

    /// Average mood for a date range
    func averageMood(from start: Date, to end: Date) -> Double? {
        let filtered = samples.filter { $0.timestamp >= start && $0.timestamp <= end }
        guard !filtered.isEmpty else { return nil }
        return filtered.reduce(0.0) { $0 + $1.score } / Double(filtered.count)
    }

    // periphery:ignore - Reserved: hourlySamples(hours:) instance method reserved for future feature activation
    /// Hourly breakdown for the last N hours
    func hourlySamples(hours: Int = 24) -> [(hour: Int, average: Double)] {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let recent = samples.filter { $0.timestamp >= cutoff }
        let calendar = Calendar.current

        var buckets: [Int: [Double]] = [:]
        for sample in recent {
            let hour = calendar.component(.hour, from: sample.timestamp)
            buckets[hour, default: []].append(sample.score)
        }

        return buckets.map { hour, scores in
            (hour: hour, average: scores.reduce(0, +) / Double(scores.count))
        }.sorted { $0.hour < $1.hour }
    }

    // MARK: - Persistence

    private struct PersistedMoodState: Codable {
        let currentScore: Double
        let samples: [MoodSample]
    }

    func saveToDisk() {
        let state = PersistedMoodState(currentScore: currentMoodScore, samples: samples)
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error("Failed to save mood history: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let state = try JSONDecoder().decode(PersistedMoodState.self, from: data)
            currentMoodScore = state.currentScore
            samples = state.samples
            logger.info("Loaded \(self.samples.count) mood samples from disk")
        } catch {
            logger.error("Failed to load mood history: \(error.localizedDescription)")
        }
    }
}
