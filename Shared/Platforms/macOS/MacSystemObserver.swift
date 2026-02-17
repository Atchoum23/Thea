//
//  MacSystemObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(macOS)
    import AppKit
    import Foundation
    import os.log

    /// Unified system observer for macOS
    /// Coordinates all macOS-specific observers and provides a single entry point
    @MainActor
    public final class MacSystemObserver {
        public static let shared = MacSystemObserver()

        private let logger = Logger(subsystem: "app.thea.system", category: "MacSystemObserver")

        // Individual observers - non-actor based
        public let accessibility = AccessibilityObserver.shared
        public let network = NetworkObserver.shared
        public let media = MediaObserver.shared
        public let clipboard = ClipboardObserver.shared
        public let display = DisplayObserver.shared
        public let power = PowerObserver.shared
        public let services = ServicesHandler.shared

        // Aggregated state
        public private(set) var systemSnapshot: MacSystemSnapshot = .init()

        // Callbacks for aggregated changes
        public var onSystemSnapshotUpdated: ((MacSystemSnapshot) -> Void)?

        private var isRunning = false
        private var snapshotUpdateTask: Task<Void, Never>?

        private init() {}

        // MARK: - Lifecycle

        public func start() {
            guard !isRunning else {
                logger.warning("MacSystemObserver already running")
                return
            }

            logger.info("Starting MacSystemObserver...")

            // Start all non-actor observers
            accessibility.start()
            network.start()
            media.start()
            clipboard.start()
            display.start()
            power.start()
            services.register()

            // Start actor-based observers
            Task {
                await FileSystemObserver.shared.watch(path: FileManager.default.currentDirectoryPath)
                await FileSystemObserver.shared.start()
                await ProcessObserver.shared.start()
            }

            // Wire up callbacks to update snapshot
            setupCallbacks()

            // Start periodic snapshot updates
            startSnapshotUpdates()

            isRunning = true
            logger.info("MacSystemObserver started successfully")
        }

        public func stop() {
            guard isRunning else { return }

            logger.info("Stopping MacSystemObserver...")

            // Stop snapshot updates
            snapshotUpdateTask?.cancel()
            snapshotUpdateTask = nil

            // Stop non-actor observers
            accessibility.stop()
            network.stop()
            media.stop()
            clipboard.stop()
            display.stop()
            power.stop()

            // Stop actor-based observers
            Task {
                await FileSystemObserver.shared.stop()
                await ProcessObserver.shared.stop()
            }

            isRunning = false
            logger.info("MacSystemObserver stopped")
        }

        // MARK: - Snapshot Management

        private func setupCallbacks() {
            // Network changes
            network.onNetworkStateChanged = { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()
                }
            }

            // Power changes
            power.onPowerStateChanged = { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()
                }
            }

            // Display changes
            display.onDisplayConfigurationChanged = { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()
                }
            }

            // Media changes
            media.onPlaybackStateChanged = { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()
                }
            }

            // Accessibility changes (focused app)
            accessibility.onAppFocusChanged = { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSnapshotUpdate()
                }
            }
        }

        private var pendingSnapshotUpdate = false

        private func scheduleSnapshotUpdate() {
            guard !pendingSnapshotUpdate else { return }
            pendingSnapshotUpdate = true

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100)) // 100ms debounce
                self.pendingSnapshotUpdate = false
                await self.updateSnapshot()
            }
        }

        private func startSnapshotUpdates() {
            snapshotUpdateTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5)) // 5 seconds
                    await self?.updateSnapshot()
                }
            }
        }

        public func updateSnapshot() async {
            // Get data from actor-based observers
            let runningProcesses = await ProcessObserver.shared.getRunningProcesses()
            let recentFileEvents = await FileSystemObserver.shared.getRecentEvents(limit: 10)
            let projectType = FileSystemObserver.shared.detectProjectType(FileManager.default.currentDirectoryPath)

            let newSnapshot = MacSystemSnapshot(
                // Accessibility
                focusedApp: accessibility.getCurrentAppName(),
                focusedAppBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                focusedWindow: accessibility.getCurrentWindowTitle(),
                selectedText: accessibility.getSelectedText(),

                // Processes
                runningProcesses: runningProcesses.count,
                topProcesses: Array(runningProcesses.prefix(10)),

                // Network
                networkState: network.currentState,
                networkMetrics: network.getNetworkMetrics(),

                // Media
                nowPlaying: media.currentNowPlaying,
                playbackState: media.currentPlaybackState,

                // Display
                displays: display.displays,
                mainDisplay: display.mainDisplay,

                // Power
                powerState: power.currentPowerState,

                // Clipboard
                recentClipboardItems: Array(clipboard.history.prefix(5)),

                // File System
                recentFileEvents: recentFileEvents,
                activeProjectType: projectType
            )

            if newSnapshot != systemSnapshot {
                systemSnapshot = newSnapshot
                onSystemSnapshotUpdated?(newSnapshot)
            }
        }

        // MARK: - Convenience Methods

        /// Get a summary of current system state
        public var stateSummary: String {
            var summary: [String] = []

            if let app = accessibility.getCurrentAppName() {
                summary.append("App: \(app)")
            }

            if let window = accessibility.getCurrentWindowTitle() {
                summary.append("Window: \(window)")
            }

            if let nowPlaying = media.currentNowPlaying?.displayTitle {
                summary.append("Playing: \(nowPlaying)")
            }

            if power.currentPowerState.hasBattery {
                summary.append("Battery: \(power.currentPowerState.batteryLevel)%")
            }

            summary.append("Displays: \(display.displays.count)")

            return summary.joined(separator: " | ")
        }
    }

    // MARK: - Snapshot Model

    public struct MacSystemSnapshot: Equatable, Sendable {
        // Accessibility
        public let focusedApp: String?
        public let focusedAppBundleID: String?
        public let focusedWindow: String?
        public let selectedText: String?

        // Processes
        public let runningProcesses: Int
        public let topProcesses: [AppProcessInfo]

        // Network
        public let networkState: NetworkState
        public let networkMetrics: NetworkMetrics

        // Media
        public let nowPlaying: NowPlayingInfo?
        public let playbackState: PlaybackState

        // Display
        public let displays: [MacDisplayInfo]
        public let mainDisplay: MacDisplayInfo?

        // Power
        public let powerState: PowerState

        // Clipboard
        public let recentClipboardItems: [ClipboardItem]

        // File System
        public let recentFileEvents: [FileSystemEvent]
        public let activeProjectType: ProjectType?

        public let timestamp: Date

        init(
            focusedApp: String? = nil,
            focusedAppBundleID: String? = nil,
            focusedWindow: String? = nil,
            selectedText: String? = nil,
            runningProcesses: Int = 0,
            topProcesses: [AppProcessInfo] = [],
            networkState: NetworkState = .unknown,
            networkMetrics: NetworkMetrics = NetworkMetrics(
                isConnected: false,
                isExpensive: false,
                isConstrained: false,
                supportsIPv4: false,
                supportsIPv6: false,
                supportsDNS: false,
                interfaceTypes: []
            ),
            nowPlaying: NowPlayingInfo? = nil,
            playbackState: PlaybackState = .unknown,
            displays: [MacDisplayInfo] = [],
            mainDisplay: MacDisplayInfo? = nil,
            powerState: PowerState = PowerState(),
            recentClipboardItems: [ClipboardItem] = [],
            recentFileEvents: [FileSystemEvent] = [],
            activeProjectType: ProjectType? = nil
        ) {
            self.focusedApp = focusedApp
            self.focusedAppBundleID = focusedAppBundleID
            self.focusedWindow = focusedWindow
            self.selectedText = selectedText
            self.runningProcesses = runningProcesses
            self.topProcesses = topProcesses
            self.networkState = networkState
            self.networkMetrics = networkMetrics
            self.nowPlaying = nowPlaying
            self.playbackState = playbackState
            self.displays = displays
            self.mainDisplay = mainDisplay
            self.powerState = powerState
            self.recentClipboardItems = recentClipboardItems
            self.recentFileEvents = recentFileEvents
            self.activeProjectType = activeProjectType
            timestamp = Date()
        }

        public static func == (lhs: MacSystemSnapshot, rhs: MacSystemSnapshot) -> Bool {
            // Compare key fields for meaningful changes
            lhs.focusedApp == rhs.focusedApp &&
                lhs.focusedWindow == rhs.focusedWindow &&
                lhs.runningProcesses == rhs.runningProcesses &&
                lhs.networkState == rhs.networkState &&
                lhs.playbackState == rhs.playbackState &&
                lhs.displays.count == rhs.displays.count &&
                lhs.powerState == rhs.powerState
        }
    }
#endif
