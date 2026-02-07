// UserInterventionDetector.swift
// Thea
//
// Lightweight detector for user mouse/keyboard activity during automation.
// When the user manually interacts (clicks, types, scrolls), automation
// pauses to let the user act, then resumes from the new state.
//
// This is separate from InputTrackingManager (which tracks for analytics
// and has SwiftData dependencies). This class is purpose-built for
// automation pause/resume with no persistence.

#if os(macOS)

    import AppKit
    import Foundation
    import os.log

    // MARK: - User Action

    /// Represents a user input action detected during automation.
    public enum UserAction: Sendable {
        case mouseClick(CGPoint)
        case mouseMove(CGPoint)
        case keyPress
        case scroll
        case drag(from: CGPoint, to: CGPoint)

        public var displayName: String {
            switch self {
            case let .mouseClick(point): return "Click at (\(Int(point.x)), \(Int(point.y)))"
            case let .mouseMove(point): return "Move to (\(Int(point.x)), \(Int(point.y)))"
            case .keyPress: return "Key press"
            case .scroll: return "Scroll"
            case let .drag(from, to): return "Drag from (\(Int(from.x)), \(Int(from.y))) to (\(Int(to.x)), \(Int(to.y)))"
            }
        }
    }

    // MARK: - User Intervention Detector

    /// Detects user mouse and keyboard activity to pause automation workflows.
    ///
    /// When the user manually clicks, types, or scrolls during an active
    /// automation session, `isUserActive` becomes true. After the user stops
    /// interacting for `activityTimeout` seconds, it resets to false and
    /// automation can resume.
    @MainActor
    public final class UserInterventionDetector {
        private let logger = Logger(subsystem: "ai.thea.app", category: "UserIntervention")

        // MARK: - State

        /// Whether the user is currently actively interacting
        public private(set) var isUserActive: Bool = false

        /// The most recent user action
        public private(set) var lastUserAction: UserAction?

        /// Timestamp of the most recent user action
        public private(set) var lastUserActionTime: Date?

        /// Total number of user actions detected in this session
        public private(set) var actionCount: Int = 0

        /// Whether detection is running
        public private(set) var isRunning: Bool = false

        // MARK: - Configuration

        /// How long after the last user action before marking as inactive (seconds)
        public var activityTimeout: TimeInterval = 2.0

        /// Minimum mouse movement distance to count as activity (pixels)
        public var mouseMovementThreshold: CGFloat = 20.0

        // MARK: - Internal

        private var eventMonitors: [Any] = []
        private var timeoutTask: Task<Void, Never>?
        private var lastMousePosition: CGPoint?

        // MARK: - Lifecycle

        public init(activityTimeout: TimeInterval = 2.0) {
            self.activityTimeout = activityTimeout
        }

        /// Start monitoring for user input events
        public func start() {
            guard !isRunning else { return }
            isRunning = true
            actionCount = 0

            // Monitor mouse clicks
            if let monitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                Task { @MainActor in
                    self?.handleUserEvent(.mouseClick(NSEvent.mouseLocation), event: event)
                }
            } {
                eventMonitors.append(monitor)
            }

            // Monitor keyboard
            if let monitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.keyDown]
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleUserEvent(.keyPress, event: nil)
                }
            } {
                eventMonitors.append(monitor)
            }

            // Monitor scrolling
            if let monitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.scrollWheel]
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleUserEvent(.scroll, event: nil)
                }
            } {
                eventMonitors.append(monitor)
            }

            // Monitor significant mouse movement
            if let monitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.mouseMoved]
            ) { [weak self] _ in
                Task { @MainActor in
                    let currentPos = NSEvent.mouseLocation
                    guard let self else { return }

                    if let lastPos = self.lastMousePosition {
                        let dx = currentPos.x - lastPos.x
                        let dy = currentPos.y - lastPos.y
                        let distance = sqrt(dx * dx + dy * dy)

                        if distance > self.mouseMovementThreshold {
                            self.handleUserEvent(.mouseMove(currentPos), event: nil)
                            self.lastMousePosition = currentPos
                        }
                    } else {
                        self.lastMousePosition = currentPos
                    }
                }
            } {
                eventMonitors.append(monitor)
            }

            logger.info("User intervention detection started")
        }

        /// Stop monitoring for user input events
        public func stop() {
            guard isRunning else { return }
            isRunning = false

            for monitor in eventMonitors {
                NSEvent.removeMonitor(monitor)
            }
            eventMonitors.removeAll()
            timeoutTask?.cancel()
            timeoutTask = nil

            isUserActive = false
            lastMousePosition = nil

            logger.info("User intervention detection stopped (detected \(self.actionCount) actions)")
        }

        /// Reset the activity state without stopping monitoring
        public func resetActivity() {
            isUserActive = false
            timeoutTask?.cancel()
            timeoutTask = nil
        }

        // MARK: - Event Handling

        private func handleUserEvent(_ action: UserAction, event: NSEvent?) {
            isUserActive = true
            lastUserAction = action
            lastUserActionTime = Date()
            actionCount += 1

            // Cancel existing timeout
            timeoutTask?.cancel()

            // Start new timeout
            timeoutTask = Task { [weak self, activityTimeout] in
                try? await Task.sleep(for: .seconds(activityTimeout))

                guard !Task.isCancelled else { return }
                self?.isUserActive = false
            }
        }
    }

#endif
