// TrackingCoordinator.swift
// Thea V2
//
// Coordinates all life tracking with privacy controls from TheaConfig

import Foundation
import OSLog

// MARK: - Tracking Coordinator

/// Central coordinator for all life tracking activities
/// Respects privacy settings from TheaConfig
@MainActor
public final class TrackingCoordinator: ObservableObject {
    public static let shared = TrackingCoordinator()

    private let logger = Logger(subsystem: "com.thea.v2", category: "Tracking")

    // MARK: - State

    @Published public private(set) var isTracking: Bool = false
    @Published public private(set) var activeTrackers: Set<TrackerType> = []
    @Published public private(set) var lastUpdate: Date?

    // MARK: - Initialization

    private init() {
        // Subscribe to config changes
        observeConfigChanges()
    }

    // MARK: - Configuration

    private func observeConfigChanges() {
        // Monitor EventBus for configuration changes
        EventBus.shared.subscribe(to: .configuration) { [weak self] event in
            if let stateEvent = event as? StateEvent,
               stateEvent.component == "Configuration" {
                Task { @MainActor in
                    self?.updateTrackersFromConfig()
                }
            }
        }
    }

    private func updateTrackersFromConfig() {
        let config = TheaConfig.shared.tracking

        // Update active trackers based on config
        var newTrackers: Set<TrackerType> = []

        if config.enableLocation { newTrackers.insert(.location) }
        if config.enableHealth { newTrackers.insert(.health) }
        if config.enableUsage { newTrackers.insert(.usage) }
        if config.enableBrowser { newTrackers.insert(.browser) }
        if config.enableInput { newTrackers.insert(.input) }

        // Start/stop trackers as needed
        let toStart = newTrackers.subtracting(activeTrackers)
        let toStop = activeTrackers.subtracting(newTrackers)

        for tracker in toStart {
            startTracker(tracker)
        }

        for tracker in toStop {
            stopTracker(tracker)
        }

        activeTrackers = newTrackers
    }

    // MARK: - Tracker Management

    public func startAllEnabled() {
        logger.info("Starting enabled trackers")
        updateTrackersFromConfig()
        isTracking = !activeTrackers.isEmpty
    }

    public func stopAll() {
        logger.info("Stopping all trackers")
        for tracker in activeTrackers {
            stopTracker(tracker)
        }
        activeTrackers.removeAll()
        isTracking = false
    }

    private func startTracker(_ type: TrackerType) {
        logger.debug("Starting tracker: \(type.rawValue)")

        // Publish tracking start event
        EventBus.shared.publish(StateEvent(
            source: .system,
            component: "Tracking.\(type.rawValue)",
            newState: "started"
        ))
    }

    private func stopTracker(_ type: TrackerType) {
        logger.debug("Stopping tracker: \(type.rawValue)")

        // Publish tracking stop event
        EventBus.shared.publish(StateEvent(
            source: .system,
            component: "Tracking.\(type.rawValue)",
            newState: "stopped"
        ))
    }

    // MARK: - Data Access

    /// Check if local-only mode is enabled
    public var isLocalOnly: Bool {
        TheaConfig.shared.tracking.localOnly
    }

    /// Get retention period in days
    public var retentionDays: Int {
        TheaConfig.shared.tracking.retentionDays
    }

    // MARK: - Privacy

    /// Delete all tracked data
    public func deleteAllData() async {
        logger.info("Deleting all tracked data")

        // Stop tracking first
        stopAll()

        // Delete data from each source
        // This would call into specific tracker implementations

        // Publish event
        EventBus.shared.publish(StateEvent(
            source: .user,
            component: "Tracking",
            newState: "dataDeleted",
            reason: "User requested data deletion"
        ))
    }

    /// Export all tracked data
    public func exportData() async -> Data? {
        logger.info("Exporting tracked data")

        // Collect data from all trackers
        // Return as JSON
        return nil // Placeholder
    }
}

// MARK: - Tracker Types

public enum TrackerType: String, Codable, Sendable, CaseIterable {
    case location
    case health
    case usage
    case browser
    case input

    public var displayName: String {
        switch self {
        case .location: return "Location"
        case .health: return "Health"
        case .usage: return "App Usage"
        case .browser: return "Browser History"
        case .input: return "Keyboard/Mouse"
        }
    }

    public var privacyDescription: String {
        switch self {
        case .location:
            return "GPS location and places visited"
        case .health:
            return "Steps, sleep, heart rate from HealthKit"
        case .usage:
            return "Time spent in each app"
        case .browser:
            return "Websites visited (Safari only)"
        case .input:
            return "Keyboard and mouse activity patterns"
        }
    }
}

// MARK: - Tracking Event

public struct TrackingEvent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: TrackerType
    public let timestamp: Date
    public let data: [String: String]

    public init(
        id: UUID = UUID(),
        type: TrackerType,
        timestamp: Date = Date(),
        data: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
}
