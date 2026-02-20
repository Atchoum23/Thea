// HeadphoneMotionService.swift
// Thea — AAH3: Headphone Motion Intelligence
//
// Monitors AirPods/Beats headphone motion via CMHeadphoneMotionManager.
// iOS 14+ only — the headphone motion manager is iOS-exclusive.
//
// Integration: motion signals feed HumanReadinessEngine via recordBehavioralSignal().
// Active head movement → user is alert/engaged.
// Prolonged stillness → user may be resting; different signal.
//
// Usage:
//   HeadphoneMotionService.shared.startMonitoring()
//   // Automatically wired into HumanReadinessEngine

import Foundation
import os.log

#if os(iOS)
    import CoreMotion

    // MARK: - HeadphoneMotionService

    /// Monitors AirPods/Beats headphone motion to inform HumanReadinessEngine.
    /// Uses CMHeadphoneMotionManager to detect attitude, rotation, and acceleration.
    @MainActor
    public final class HeadphoneMotionService: ObservableObject {
        public static let shared = HeadphoneMotionService()

        private let logger = Logger(subsystem: "ai.thea.app", category: "HeadphoneMotion")
        private let motionManager = CMHeadphoneMotionManager()
        private let motionQueue = OperationQueue()

        // MARK: - Published State

        @Published public private(set) var isAvailable: Bool = false
        @Published public private(set) var isMonitoring: Bool = false
        @Published public private(set) var latestAttitude: HeadphoneAttitude?
        @Published public private(set) var activityLevel: HeadphoneActivity = .unknown
        @Published public private(set) var lastMotionDate: Date?

        // MARK: - Configuration

        /// Rotation rate magnitude threshold (rad/s) to classify as active movement.
        public var activeRotationThreshold: Double = 0.3

        /// Seconds of stillness before classifying as resting.
        public var restingDurationThreshold: TimeInterval = 120

        // MARK: - Private State

        private var stillnessTimer: Timer?
        // periphery:ignore - Reserved: AD3 audit — wired in future integration
        private var lastActiveDate: Date?

        // MARK: - Init

        private init() {
            motionQueue.name = "ai.thea.headphoneMotion"
            motionQueue.qualityOfService = .utility
            isAvailable = motionManager.isDeviceMotionAvailable
        }

        // MARK: - Monitoring Lifecycle

        /// Start headphone motion updates. No-op if hardware unavailable or already active.
        public func startMonitoring() {
            guard motionManager.isDeviceMotionAvailable else {
                logger.info("HeadphoneMotion: CMHeadphoneMotionManager unavailable (no AirPods connected?)")
                return
            }
            guard !motionManager.isDeviceMotionActive else { return }

            isMonitoring = true
            logger.info("HeadphoneMotion: starting device motion updates")

            motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
                if let error {
                    Task { @MainActor [weak self] in
                        self?.logger.error("HeadphoneMotion: update error — \(error.localizedDescription)")
                    }
                    return
                }
                guard let motion else { return }
                Task { @MainActor [weak self] in
                    self?.process(motion)
                }
            }
        }

        /// Stop headphone motion updates.
        public func stopMonitoring() {
            motionManager.stopDeviceMotionUpdates()
            stillnessTimer?.invalidate()
            stillnessTimer = nil
            isMonitoring = false
            logger.info("HeadphoneMotion: stopped")
        }

        // MARK: - Motion Processing

        private func process(_ motion: CMDeviceMotion) {
            let attitude = HeadphoneAttitude(from: motion)
            latestAttitude = attitude
            lastMotionDate = .now

            // Classify movement intensity
            let rotMag = sqrt(
                pow(motion.rotationRate.x, 2) +
                pow(motion.rotationRate.y, 2) +
                pow(motion.rotationRate.z, 2)
            )

            let userAccMag = sqrt(
                pow(motion.userAcceleration.x, 2) +
                pow(motion.userAcceleration.y, 2) +
                pow(motion.userAcceleration.z, 2)
            )

            let isActive = rotMag > activeRotationThreshold || userAccMag > 0.15

            if isActive {
                handleActiveMovement()
            } else {
                handleStillness()
            }
        }

        private func handleActiveMovement() {
            guard activityLevel != .active else { return }
            activityLevel = .active
            lastActiveDate = .now

            // Reset stillness timer
            stillnessTimer?.invalidate()
            stillnessTimer = nil

            // Notify HumanReadinessEngine: user is alert and moving
            HumanReadinessEngine.shared.recordBehavioralSignal()
            logger.debug("HeadphoneMotion: active movement detected → recordBehavioralSignal()")
        }

        private func handleStillness() {
            guard activityLevel != .resting else { return }

            // Only switch to resting after prolonged stillness
            if stillnessTimer == nil {
                stillnessTimer = Timer.scheduledTimer(
                    withTimeInterval: restingDurationThreshold,
                    repeats: false
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.activityLevel = .resting
                        self?.logger.debug("HeadphoneMotion: resting state confirmed")
                        // Resting → HumanReadiness may want to reduce interrupt budget
                        // No explicit API for this; recordBehavioralSignal() not called
                    }
                }
            }
        }

        // MARK: - Convenience

        /// Current head pitch angle in degrees (negative = looking down).
        public var headPitchDegrees: Double {
            guard let attitude = latestAttitude else { return 0 }
            return attitude.pitch * (180 / .pi)
        }

        /// Returns a compact context summary suitable for PersonalParameters.snapshot().
        public func buildContextSummary() -> String {
            guard isMonitoring else { return "" }
            let actStr = activityLevel.rawValue
            let pitchStr = String(format: "%.1f°", headPitchDegrees)
            return "headphones=\(actStr) pitch=\(pitchStr)"
        }
    }

    // MARK: - Supporting Types

    /// Headphone attitude snapshot (pitch/roll/yaw in radians).
    public struct HeadphoneAttitude: Sendable {
        public let pitch: Double   // Nose up/down
        public let roll: Double    // Head tilt left/right
        public let yaw: Double     // Head turn left/right
        public let timestamp: Date

        init(from motion: CMDeviceMotion) {
            pitch = motion.attitude.pitch
            roll = motion.attitude.roll
            yaw = motion.attitude.yaw
            timestamp = .now
        }
    }

    /// Broad activity classification from headphone motion.
    public enum HeadphoneActivity: String, Sendable {
        case active   // User is moving / nodding / looking around
        case resting  // User still for > restingDurationThreshold
        case unknown  // Not yet classified
    }

#else

    // MARK: - macOS / watchOS / tvOS Stub

    /// CMHeadphoneMotionManager is iOS-only. This stub satisfies the type system
    /// on other platforms without dead-code compiler warnings.
    @MainActor
    public final class HeadphoneMotionService: ObservableObject {
        public static let shared = HeadphoneMotionService()
        public private(set) var isAvailable: Bool = false
        public private(set) var isMonitoring: Bool = false
        private init() {}
        public func startMonitoring() {}
        public func stopMonitoring() {}
        public func buildContextSummary() -> String { "" }
    }

    public enum HeadphoneActivity: String, Sendable {
        case active
        case resting
        case unknown
    }

    public struct HeadphoneAttitude: Sendable {
        public let pitch: Double
        public let roll: Double
        public let yaw: Double
        public let timestamp: Date
    }

#endif
