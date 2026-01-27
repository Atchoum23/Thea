//
//  DisplayObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(macOS)
    import AppKit
    import os.log

    /// Observes display configuration changes on macOS
    /// Tracks connected displays, screen dimensions, and display arrangement
    @MainActor
    public final class DisplayObserver {
        public static let shared = DisplayObserver()

        private let logger = Logger(subsystem: "app.thea.display", category: "DisplayObserver")

        // Callbacks
        public var onDisplayConfigurationChanged: (([MacDisplayInfo]) -> Void)?
        public var onDisplayAdded: ((MacDisplayInfo) -> Void)?
        public var onDisplayRemoved: ((CGDirectDisplayID) -> Void)?

        // State
        public private(set) var displays: [MacDisplayInfo] = []
        private var observers: [NSObjectProtocol] = []

        private init() {}

        // MARK: - Lifecycle

        public func start() {
            // Initial state
            refreshDisplays()

            // Observe screen configuration changes
            let configObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleScreenParametersChanged()
                }
            }
            observers.append(configObserver)

            // Observe sleep/wake for display changes
            let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshDisplays()
                }
            }
            observers.append(wakeObserver)

            logger.info("Display observer started with \(self.displays.count) displays")
        }

        public func stop() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
            observers.removeAll()
            logger.info("Display observer stopped")
        }

        // MARK: - Display Handling

        private func handleScreenParametersChanged() {
            let oldDisplays = displays
            refreshDisplays()

            // Detect added/removed displays
            let oldIDs = Set(oldDisplays.map(\.displayID))
            let newIDs = Set(displays.map(\.displayID))

            let addedIDs = newIDs.subtracting(oldIDs)
            let removedIDs = oldIDs.subtracting(newIDs)

            for id in addedIDs {
                if let display = displays.first(where: { $0.displayID == id }) {
                    logger.info("Display added: \(display.name)")
                    onDisplayAdded?(display)
                }
            }

            for id in removedIDs {
                logger.info("Display removed: ID \(id)")
                onDisplayRemoved?(id)
            }

            if addedIDs.isEmpty, removedIDs.isEmpty {
                // Configuration changed but same displays (resolution/arrangement change)
                logger.info("Display configuration changed")
            }

            onDisplayConfigurationChanged?(displays)
        }

        public func refreshDisplays() {
            displays = NSScreen.screens.enumerated().compactMap { index, screen -> MacDisplayInfo? in
                guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                    return nil
                }

                let isMain = CGDisplayIsMain(displayID) != 0
                let isBuiltin = CGDisplayIsBuiltin(displayID) != 0

                return MacDisplayInfo(
                    displayID: displayID,
                    index: index,
                    name: screen.localizedName,
                    frame: screen.frame,
                    visibleFrame: screen.visibleFrame,
                    backingScaleFactor: screen.backingScaleFactor,
                    colorSpace: screen.colorSpace?.localizedName ?? "Unknown",
                    isMain: isMain,
                    isBuiltin: isBuiltin,
                    refreshRate: getRefreshRate(displayID: displayID)
                )
            }
        }

        private func getRefreshRate(displayID: CGDirectDisplayID) -> Double? {
            if let mode = CGDisplayCopyDisplayMode(displayID) {
                return mode.refreshRate
            }
            return nil
        }

        // MARK: - Queries

        /// Get the main display
        public var mainDisplay: MacDisplayInfo? {
            displays.first { $0.isMain }
        }

        /// Get built-in display (laptop screen)
        public var builtinDisplay: MacDisplayInfo? {
            displays.first { $0.isBuiltin }
        }

        /// Get external displays only
        public var externalDisplays: [MacDisplayInfo] {
            displays.filter { !$0.isBuiltin }
        }

        /// Get total screen real estate
        public var totalScreenArea: CGSize {
            let maxX = displays.map(\.frame.maxX).max() ?? 0
            let maxY = displays.map(\.frame.maxY).max() ?? 0
            let minX = displays.map(\.frame.minX).min() ?? 0
            let minY = displays.map(\.frame.minY).min() ?? 0
            return CGSize(width: maxX - minX, height: maxY - minY)
        }

        /// Get display containing a point
        public func displayContaining(point: NSPoint) -> MacDisplayInfo? {
            displays.first { $0.frame.contains(point) }
        }

        /// Get display containing a window
        public func displayContaining(window: NSWindow) -> MacDisplayInfo? {
            let windowCenter = NSPoint(
                x: window.frame.midX,
                y: window.frame.midY
            )
            return displayContaining(point: windowCenter)
        }
    }

    // MARK: - Models

    public struct MacDisplayInfo: Identifiable, Sendable {
        public var id: CGDirectDisplayID { displayID }

        public let displayID: CGDirectDisplayID
        public let index: Int
        public let name: String
        public let frame: CGRect
        public let visibleFrame: CGRect
        public let backingScaleFactor: CGFloat
        public let colorSpace: String
        public let isMain: Bool
        public let isBuiltin: Bool
        public let refreshRate: Double?

        public var resolution: String {
            "\(Int(frame.width))×\(Int(frame.height))"
        }

        public var effectiveResolution: String {
            let effectiveWidth = Int(frame.width * backingScaleFactor)
            let effectiveHeight = Int(frame.height * backingScaleFactor)
            return "\(effectiveWidth)×\(effectiveHeight)"
        }

        public var isRetina: Bool {
            backingScaleFactor >= 2.0
        }

        public var displayType: String {
            if isBuiltin {
                "Built-in"
            } else {
                "External"
            }
        }
    }
#endif
