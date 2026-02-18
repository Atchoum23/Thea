//
//  iOSSystemObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(iOS)
    import Foundation
    import os.log
    import UIKit

    /// Unified system observer for iOS
    /// Coordinates all iOS-specific observers and provides a single entry point
    @MainActor
    public final class iOSSystemObserver: ObservableObject { // swiftlint:disable:this type_name
        public static let shared = iOSSystemObserver()

        private let logger = Logger(subsystem: "app.thea.system", category: "iOSSystemObserver")

        // Individual observers
        @available(iOS 16.0, *)
        public var screenTime: ScreenTimeObserver { ScreenTimeObserver.shared }

        public let motion = MotionContextProvider.shared
        public let photos = PhotoIntelligenceProvider.shared
        public let health = HealthKitProvider.shared
        public let notifications = NotificationObserver.shared

        // Aggregated state
        @Published public private(set) var systemSnapshot: iOSSystemSnapshot = .init()

        // Callbacks
        public var onSystemSnapshotUpdated: ((iOSSystemSnapshot) -> Void)?
        public var onSignificantEvent: ((SystemEvent) -> Void)?

        private var isRunning = false
        private var snapshotUpdateTask: Task<Void, Never>?

        private init() {}

        // MARK: - Lifecycle

        /// Start all iOS system observers
        public func start() async {
            guard !isRunning else {
                logger.warning("iOSSystemObserver already running")
                return
            }

            logger.info("Starting iOSSystemObserver...")

            // Request authorizations
            await requestAuthorizations()

            // Start individual observers
            motion.startMonitoring()
            notifications.startObserving()
            health.startMonitoring()

            if #available(iOS 16.0, *) {
                screenTime.startMonitoring()
            }

            // Wire up callbacks
            setupCallbacks()

            // Start periodic snapshot updates
            startSnapshotUpdates()

            isRunning = true
            logger.info("iOSSystemObserver started successfully")
        }

        /// Stop all observers
        public func stop() {
            guard isRunning else { return }

            logger.info("Stopping iOSSystemObserver...")

            // Stop snapshot updates
            snapshotUpdateTask?.cancel()
            snapshotUpdateTask = nil

            // Stop individual observers
            motion.stopMonitoring()
            notifications.stopObserving()
            health.stopMonitoring()

            if #available(iOS 16.0, *) {
                screenTime.stopMonitoring()
            }

            isRunning = false
            logger.info("iOSSystemObserver stopped")
        }

        // MARK: - Authorization

        private func requestAuthorizations() async {
            // Health authorization
            do {
                try await health.requestAuthorization()
            } catch {
                logger.warning("HealthKit authorization failed: \(error)")
            }

            // Notification authorization
            do {
                try await notifications.requestAuthorization()
            } catch {
                logger.warning("Notification authorization failed: \(error)")
            }

            // Screen Time authorization (iOS 16+)
            if #available(iOS 16.0, *) {
                do {
                    try await screenTime.requestAuthorization()
                } catch {
                    logger.warning("Screen Time authorization failed: \(error)")
                }
            }

            // Photo library authorization
            _ = await photos.requestAuthorization()
        }

        // MARK: - Callbacks

        private func setupCallbacks() {
            // Motion activity changes
            motion.onActivityChanged = { [weak self] activity in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()

                    // Emit significant events
                    if activity == .automotive {
                        self?.emitEvent(.startedDriving)
                    }
                }
            }

            motion.onSignificantMotion = { [weak self] event in
                Task { @MainActor in
                    switch event.type {
                    case .startedMoving:
                        self?.emitEvent(.startedExercising)
                    case .stoppedMoving:
                        self?.emitEvent(.stoppedExercising)
                    case .startedDriving:
                        self?.emitEvent(.startedDriving)
                    case .stoppedDriving:
                        self?.emitEvent(.stoppedDriving)
                    }
                }
            }

            // Health events
            health.onWorkoutStarted = { [weak self] workout in
                Task { @MainActor in
                    self?.emitEvent(.workoutStarted(workout.activityName))
                    self?.scheduleSnapshotUpdate()
                }
            }

            health.onWorkoutEnded = { [weak self] workout in
                Task { @MainActor in
                    self?.emitEvent(.workoutEnded(workout.activityName))
                    self?.scheduleSnapshotUpdate()
                }
            }

            health.onHealthAnomalyDetected = { [weak self] anomaly in
                Task { @MainActor in
                    self?.emitEvent(.healthAnomaly(anomaly.message))
                }
            }

            // Notification events
            notifications.onNotificationReceived = { [weak self] (_: TheaNotificationInfo) in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()
                }
            }

            notifications.onNotificationPatternDetected = { [weak self] pattern in
                Task { @MainActor in
                    self?.emitEvent(.notificationBurst(pattern.appBundleID ?? "Unknown"))
                }
            }

            // Photo events
            photos.onPhotoCaptured = { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()
                }
            }
        }

        private func emitEvent(_ event: SystemEvent) {
            logger.info("System event: \(event.description)")
            onSignificantEvent?(event)
        }

        // MARK: - Snapshot Management

        private var pendingSnapshotUpdate = false

        private func scheduleSnapshotUpdate() {
            guard !pendingSnapshotUpdate else { return }
            pendingSnapshotUpdate = true

            Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
                } catch {
                    self.pendingSnapshotUpdate = false
                    return
                }
                self.pendingSnapshotUpdate = false
                self.updateSnapshot()
            }
        }

        private func startSnapshotUpdates() {
            snapshotUpdateTask = Task { [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    } catch {
                        break
                    }
                    await MainActor.run {
                        self?.updateSnapshot()
                    }
                }
            }
        }

        private func updateSnapshot() {
            let newSnapshot = iOSSystemSnapshot(
                // Motion
                activity: motion.currentActivity,
                todaySteps: motion.todaySteps,
                todayDistance: motion.todayDistance,

                // Health
                heartRate: health.latestHeartRate,
                todayActiveEnergy: health.todayActiveEnergy,
                todaySleepHours: health.todaySleepHours,
                currentWorkout: health.currentWorkout,

                // Notifications
                todayNotificationCount: notifications.todayCount,
                pendingNotifications: notifications.pendingNotifications.count,

                // Photos
                recentPhotoCount: photos.recentPhotos.count,
                todayPhotoCount: photos.todayPhotoCount,

                // Device state
                batteryLevel: UIDevice.current.batteryLevel,
                batteryState: UIDevice.current.batteryState,
                isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            )

            if newSnapshot != systemSnapshot {
                systemSnapshot = newSnapshot
                onSystemSnapshotUpdated?(newSnapshot)
            }
        }

        // MARK: - Convenience Methods

        /// Get current context summary
        public var contextSummary: String {
            var parts: [String] = []

            // Activity
            parts.append("Activity: \(motion.currentActivity.rawValue)")

            // Steps
            parts.append("Steps: \(motion.todaySteps)")

            // Health
            if let hr = health.latestHeartRate {
                parts.append("HR: \(Int(hr)) bpm")
            }

            // Notifications
            parts.append("Notifications: \(notifications.todayCount) today")

            // Battery
            let batteryPercent = Int(UIDevice.current.batteryLevel * 100)
            if batteryPercent > 0 {
                parts.append("Battery: \(batteryPercent)%")
            }

            return parts.joined(separator: " | ")
        }

        /// Check if user is likely busy
        public var isLikelyBusy: Bool {
            // In a workout
            if health.currentWorkout != nil { return true }

            // Actively moving
            if motion.isActive { return true }

            // Driving
            if motion.isInVehicle { return true }

            return false
        }

        /// Check if user is likely available
        public var isLikelyAvailable: Bool {
            // Stationary
            guard motion.currentActivity == .stationary else { return false }

            // Not in a workout
            guard health.currentWorkout == nil else { return false }

            // Not sleeping
            guard !health.isLikelySleeping else { return false }

            return true
        }

        /// Get authorization status summary
        public var authorizationSummary: AuthorizationSummary {
            AuthorizationSummary(
                healthKit: health.isAuthorized,
                notifications: notifications.isAuthorized,
                motion: motion.isActivityAvailable,
                photos: photos.isAuthorized
            )
        }
    }

    // MARK: - Data Models

    public struct iOSSystemSnapshot: Equatable, Sendable { // swiftlint:disable:this type_name
        // Motion
        public let activity: MotionActivity
        public let todaySteps: Int
        public let todayDistance: Double

        // Health
        public let heartRate: Double?
        public let todayActiveEnergy: Double
        public let todaySleepHours: Double
        public let currentWorkout: WorkoutInfo?

        // Notifications
        public let todayNotificationCount: Int
        public let pendingNotifications: Int

        // Photos
        public let recentPhotoCount: Int
        public let todayPhotoCount: Int

        // Device
        public let batteryLevel: Float
        public let batteryState: UIDevice.BatteryState
        public let isLowPowerModeEnabled: Bool

        public let timestamp: Date

        init(
            activity: MotionActivity = .unknown,
            todaySteps: Int = 0,
            todayDistance: Double = 0,
            heartRate: Double? = nil,
            todayActiveEnergy: Double = 0,
            todaySleepHours: Double = 0,
            currentWorkout: WorkoutInfo? = nil,
            todayNotificationCount: Int = 0,
            pendingNotifications: Int = 0,
            recentPhotoCount: Int = 0,
            todayPhotoCount: Int = 0,
            batteryLevel: Float = -1,
            batteryState: UIDevice.BatteryState = .unknown,
            isLowPowerModeEnabled: Bool = false
        ) {
            self.activity = activity
            self.todaySteps = todaySteps
            self.todayDistance = todayDistance
            self.heartRate = heartRate
            self.todayActiveEnergy = todayActiveEnergy
            self.todaySleepHours = todaySleepHours
            self.currentWorkout = currentWorkout
            self.todayNotificationCount = todayNotificationCount
            self.pendingNotifications = pendingNotifications
            self.recentPhotoCount = recentPhotoCount
            self.todayPhotoCount = todayPhotoCount
            self.batteryLevel = batteryLevel
            self.batteryState = batteryState
            self.isLowPowerModeEnabled = isLowPowerModeEnabled
            timestamp = Date()
        }

        public static func == (lhs: iOSSystemSnapshot, rhs: iOSSystemSnapshot) -> Bool {
            // Compare key fields
            lhs.activity == rhs.activity &&
                lhs.todaySteps == rhs.todaySteps &&
                lhs.heartRate == rhs.heartRate &&
                lhs.todayNotificationCount == rhs.todayNotificationCount &&
                lhs.batteryLevel == rhs.batteryLevel &&
                lhs.isLowPowerModeEnabled == rhs.isLowPowerModeEnabled
        }
    }

    public enum SystemEvent: CustomStringConvertible, Sendable {
        case startedMoving
        case stoppedMoving
        case startedDriving
        case stoppedDriving
        case startedExercising
        case stoppedExercising
        case workoutStarted(String)
        case workoutEnded(String)
        case healthAnomaly(String)
        case notificationBurst(String)
        case locationChanged(String)
        case batteryLow
        case batteryCharging

        public var description: String {
            switch self {
            case .startedMoving: "Started moving"
            case .stoppedMoving: "Stopped moving"
            case .startedDriving: "Started driving"
            case .stoppedDriving: "Stopped driving"
            case .startedExercising: "Started exercising"
            case .stoppedExercising: "Stopped exercising"
            case let .workoutStarted(type): "Workout started: \(type)"
            case let .workoutEnded(type): "Workout ended: \(type)"
            case let .healthAnomaly(message): "Health anomaly: \(message)"
            case let .notificationBurst(app): "Notification burst from \(app)"
            case let .locationChanged(place): "Location changed: \(place)"
            case .batteryLow: "Battery low"
            case .batteryCharging: "Battery charging"
            }
        }
    }

    public struct AuthorizationSummary: Sendable {
        public let healthKit: Bool
        public let notifications: Bool
        public let motion: Bool
        public let photos: Bool

        public var allGranted: Bool {
            healthKit && notifications && motion && photos
        }

        public var grantedCount: Int {
            [healthKit, notifications, motion, photos].count { $0 }
        }
    }

    // Extension for Sendable conformance
    extension UIDevice.BatteryState: @retroactive @unchecked Sendable {}
#endif
