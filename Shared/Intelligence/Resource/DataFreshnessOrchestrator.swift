// DataFreshnessOrchestrator.swift
// Thea — AL3: Data Freshness Orchestrator
//
// Tracks freshness for 8 data categories (HRV, sleep, activity, location,
// behavioral, calendar, weather, biometrics). Triggers background refresh
// notifications when staleness crosses per-category thresholds.
//
// Composite staleness score feeds ResourceOrchestrator.
// HealthCoachingPipeline calls recordRefresh() after each HealthKit query.

import Combine
import Foundation
import OSLog

// MARK: - DataCategory

public enum DataCategory: String, CaseIterable, Sendable {
    case hrv
    case sleep
    case activity
    case location
    case behavioral
    case calendar
    case weather
    case biometrics

    /// Maximum allowed staleness before a refresh notification is posted (minutes)
    public var maxStalenessMinutes: Double {
        switch self {
        case .hrv:         return 5
        case .sleep:       return 60
        case .activity:    return 15
        case .location:    return 2
        case .behavioral:  return 10
        case .calendar:    return 30
        case .weather:     return 60
        case .biometrics:  return 120
        }
    }

    public var displayName: String {
        switch self {
        case .hrv:         return "HRV"
        case .sleep:       return "Sleep"
        case .activity:    return "Activity"
        case .location:    return "Location"
        case .behavioral:  return "Behavioral"
        case .calendar:    return "Calendar"
        case .weather:     return "Weather"
        case .biometrics:  return "Biometrics"
        }
    }
}

// MARK: - DataFreshnessOrchestrator

@MainActor
public final class DataFreshnessOrchestrator: ObservableObject {
    public static let shared = DataFreshnessOrchestrator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "DataFreshnessOrchestrator")

    // MARK: - Published State

    @Published public private(set) var freshnessMap: [DataCategory: Date] = [:]

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        scheduleChecks()
    }

    // MARK: - Public API

    /// Record that a category was just refreshed.
    public func recordRefresh(_ category: DataCategory) {
        freshnessMap[category] = .now
        logger.debug("Freshness recorded: \(category.rawValue)")
    }

    /// Whether a category's data is still within its staleness threshold.
    public func isFresh(_ category: DataCategory) -> Bool {
        guard let last = freshnessMap[category] else { return false }
        return Date.now.timeIntervalSince(last) < category.maxStalenessMinutes * 60
    }

    /// Last refresh date for a category (nil if never refreshed).
    public func lastRefresh(_ category: DataCategory) -> Date? { freshnessMap[category] }

    /// Staleness fraction for a category (0 = fresh, 1 = maximally stale).
    public func stalenessFraction(_ category: DataCategory) -> Double {
        guard let last = freshnessMap[category] else { return 1.0 }
        let elapsed = Date.now.timeIntervalSince(last)
        let maxSeconds = category.maxStalenessMinutes * 60
        return min(1.0, elapsed / maxSeconds)
    }

    /// Composite staleness score across all categories (0 = all fresh, 1 = all stale).
    public func stalenessScore() -> Double {
        let staleCount = DataCategory.allCases.filter { !isFresh($0) }.count
        return Double(staleCount) / Double(DataCategory.allCases.count)
    }

    // MARK: - Background Staleness Check

    private func scheduleChecks() {
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let stale = DataCategory.allCases.filter { !self.isFresh($0) }
                for category in stale {
                    NotificationCenter.default.post(name: .theaDataStale, object: category)
                    self.logger.debug("Stale notification posted: \(category.rawValue)")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Notification Name

public extension Notification.Name {
    /// Posted when a data category becomes stale. `object` is the `DataCategory`.
    static let theaDataStale = Notification.Name("ai.thea.dataStale")
}
