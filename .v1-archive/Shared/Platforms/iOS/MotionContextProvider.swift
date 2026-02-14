//
//  MotionContextProvider.swift
//  Thea
//
//  Created by Thea
//

#if os(iOS)
    import CoreMotion
    import Foundation
    import os.log

    /// Provides motion and activity context on iOS
    /// Uses CoreMotion for activity detection and motion data
    @MainActor
    public final class MotionContextProvider: ObservableObject {
        public static let shared = MotionContextProvider()

        private let logger = Logger(subsystem: "app.thea.motion", category: "MotionContext")

        // Motion manager
        private let motionManager = CMMotionActivityManager()
        private let pedometer = CMPedometer()
        private let altimeter = CMAltimeter()

        // Current state
        @Published public private(set) var currentActivity: MotionActivity = .unknown
        @Published public private(set) var todaySteps: Int = 0
        @Published public private(set) var todayDistance: Double = 0
        @Published public private(set) var todayFloors: Int = 0
        @Published public private(set) var relativeAltitude: Double = 0

        // Callbacks
        public var onActivityChanged: ((MotionActivity) -> Void)?
        public var onSignificantMotion: ((SignificantMotionEvent) -> Void)?

        private var isMonitoring = false

        private init() {}

        // MARK: - Authorization

        /// Check if motion activity is available
        public var isActivityAvailable: Bool {
            CMMotionActivityManager.isActivityAvailable()
        }

        /// Check if step counting is available
        public var isStepCountingAvailable: Bool {
            CMPedometer.isStepCountingAvailable()
        }

        /// Check if altitude tracking is available
        public var isAltitudeAvailable: Bool {
            CMAltimeter.isRelativeAltitudeAvailable()
        }

        // MARK: - Monitoring

        /// Start monitoring motion context
        public func startMonitoring() {
            guard !isMonitoring else { return }
            isMonitoring = true

            startActivityMonitoring()
            startPedometerMonitoring()
            startAltitudeMonitoring()
            fetchTodayStats()

            logger.info("Motion monitoring started")
        }

        /// Stop monitoring
        public func stopMonitoring() {
            guard isMonitoring else { return }
            isMonitoring = false

            motionManager.stopActivityUpdates()
            pedometer.stopUpdates()
            altimeter.stopRelativeAltitudeUpdates()

            logger.info("Motion monitoring stopped")
        }

        // MARK: - Activity Monitoring

        private func startActivityMonitoring() {
            guard CMMotionActivityManager.isActivityAvailable() else {
                logger.warning("Motion activity not available")
                return
            }

            motionManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let activity else { return }
                self?.processActivity(activity)
            }
        }

        private func processActivity(_ cmActivity: CMMotionActivity) {
            let newActivity = MotionActivity(from: cmActivity)

            if newActivity != currentActivity {
                let oldActivity = currentActivity
                currentActivity = newActivity

                logger.debug("Activity changed: \(oldActivity.rawValue) -> \(newActivity.rawValue)")
                onActivityChanged?(newActivity)

                // Check for significant transitions
                if let event = detectSignificantMotion(from: oldActivity, to: newActivity) {
                    onSignificantMotion?(event)
                }
            }
        }

        private func detectSignificantMotion(from old: MotionActivity, to new: MotionActivity) -> SignificantMotionEvent? {
            // Detect transitions that might be significant
            switch (old, new) {
            case (.stationary, .walking), (.stationary, .running):
                SignificantMotionEvent(type: .startedMoving, from: old, to: new)
            case (.walking, .stationary), (.running, .stationary):
                SignificantMotionEvent(type: .stoppedMoving, from: old, to: new)
            case (_, .automotive):
                SignificantMotionEvent(type: .startedDriving, from: old, to: new)
            case (.automotive, _):
                SignificantMotionEvent(type: .stoppedDriving, from: old, to: new)
            default:
                nil
            }
        }

        // MARK: - Pedometer

        private func startPedometerMonitoring() {
            guard CMPedometer.isStepCountingAvailable() else {
                logger.warning("Step counting not available")
                return
            }

            let midnight = Calendar.current.startOfDay(for: Date())

            pedometer.startUpdates(from: midnight) { [weak self] data, error in
                guard let data, error == nil else { return }

                Task { @MainActor in
                    self?.todaySteps = data.numberOfSteps.intValue
                    self?.todayDistance = data.distance?.doubleValue ?? 0
                    self?.todayFloors = data.floorsAscended?.intValue ?? 0
                }
            }
        }

        private func fetchTodayStats() {
            guard CMPedometer.isStepCountingAvailable() else { return }

            let midnight = Calendar.current.startOfDay(for: Date())

            pedometer.queryPedometerData(from: midnight, to: Date()) { [weak self] data, error in
                guard let data, error == nil else { return }

                Task { @MainActor in
                    self?.todaySteps = data.numberOfSteps.intValue
                    self?.todayDistance = data.distance?.doubleValue ?? 0
                    self?.todayFloors = data.floorsAscended?.intValue ?? 0
                }
            }
        }

        // MARK: - Altitude

        private func startAltitudeMonitoring() {
            guard CMAltimeter.isRelativeAltitudeAvailable() else {
                logger.warning("Altitude not available")
                return
            }

            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                guard let data, error == nil else { return }
                self?.relativeAltitude = data.relativeAltitude.doubleValue
            }
        }

        // MARK: - Historical Data

        /// Get step history for past days
        public func getStepHistory(days: Int) async -> [DailySteps] {
            guard CMPedometer.isStepCountingAvailable() else {
                return []
            }

            var history: [DailySteps] = []

            for dayOffset in 0 ..< days {
                let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
                let startOfDay = Calendar.current.startOfDay(for: date)
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

                if let steps = await fetchSteps(from: startOfDay, to: min(endOfDay, Date())) {
                    history.append(DailySteps(date: startOfDay, steps: steps))
                }
            }

            return history.reversed()
        }

        private func fetchSteps(from start: Date, to end: Date) async -> Int? {
            await withCheckedContinuation { continuation in
                pedometer.queryPedometerData(from: start, to: end) { data, _ in
                    continuation.resume(returning: data?.numberOfSteps.intValue)
                }
            }
        }

        // MARK: - Queries

        /// Get current motion summary
        public var motionSummary: MotionSummary {
            MotionSummary(
                activity: currentActivity,
                steps: todaySteps,
                distance: todayDistance,
                floors: todayFloors,
                relativeAltitude: relativeAltitude
            )
        }

        /// Check if user is currently active
        public var isActive: Bool {
            switch currentActivity {
            case .walking, .running, .cycling:
                true
            default:
                false
            }
        }

        /// Check if user is in a vehicle
        public var isInVehicle: Bool {
            currentActivity == .automotive
        }
    }

    // MARK: - Data Models

    public enum MotionActivity: String, Sendable {
        case unknown
        case stationary
        case walking
        case running
        case cycling
        case automotive

        init(from cmActivity: CMMotionActivity) {
            if cmActivity.automotive {
                self = .automotive
            } else if cmActivity.cycling {
                self = .cycling
            } else if cmActivity.running {
                self = .running
            } else if cmActivity.walking {
                self = .walking
            } else if cmActivity.stationary {
                self = .stationary
            } else {
                self = .unknown
            }
        }
    }

    public struct MotionSummary: Sendable {
        public let activity: MotionActivity
        public let steps: Int
        public let distance: Double
        public let floors: Int
        public let relativeAltitude: Double
        public let timestamp: Date

        init(
            activity: MotionActivity,
            steps: Int,
            distance: Double,
            floors: Int,
            relativeAltitude: Double
        ) {
            self.activity = activity
            self.steps = steps
            self.distance = distance
            self.floors = floors
            self.relativeAltitude = relativeAltitude
            timestamp = Date()
        }

        public var formattedDistance: String {
            if distance >= 1000 {
                String(format: "%.1f km", distance / 1000)
            } else {
                String(format: "%.0f m", distance)
            }
        }
    }

    public struct DailySteps: Identifiable, Sendable {
        public var id: Date { date }
        public let date: Date
        public let steps: Int
    }

    public struct SignificantMotionEvent: Sendable {
        public let type: EventType
        public let from: MotionActivity
        public let to: MotionActivity
        public let timestamp: Date

        public enum EventType: String, Sendable {
            case startedMoving
            case stoppedMoving
            case startedDriving
            case stoppedDriving
        }

        init(type: EventType, from: MotionActivity, to: MotionActivity) {
            self.type = type
            self.from = from
            self.to = to
            timestamp = Date()
        }
    }
#endif
