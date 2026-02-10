//
//  MonitoringService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

@preconcurrency import Foundation
#if os(macOS)
    import AppKit
#endif

// MARK: - Monitoring Service

/// Central service for always-on activity monitoring
public actor MonitoringService {
    public static let shared = MonitoringService()

    // MARK: - State

    private var isMonitoring = false
    private var monitors: [MonitorType: any ActivityMonitor] = [:]
    private var configuration: MonitoringConfiguration

    // MARK: - Dependencies

    private let activityLogger = ActivityLogger.shared
    private let privacyManager = PrivacyManager.shared

    // MARK: - Initialization

    private init() {
        configuration = MonitoringConfiguration.load()
    }

    // MARK: - Start/Stop

    /// Start all enabled monitors
    public func startMonitoring() async throws {
        guard !isMonitoring else { return }

        // Check privacy permissions
        let hasPermission = await privacyManager.checkAllPermissions()
        guard hasPermission else {
            throw MonitoringError.permissionDenied
        }

        isMonitoring = true

        // Start enabled monitors
        for monitorType in MonitorType.allCases {
            if configuration.enabledMonitors.contains(monitorType) {
                try await startMonitor(monitorType)
            }
        }
    }

    /// Stop all monitors
    public func stopMonitoring() async {
        isMonitoring = false

        for (_, monitor) in monitors {
            await monitor.stop()
        }
        monitors.removeAll()
    }

    /// Start a specific monitor
    public func startMonitor(_ type: MonitorType) async throws {
        guard isMonitoring else {
            throw MonitoringError.notMonitoring
        }

        guard monitors[type] == nil else { return }

        let monitor = createMonitor(for: type)
        monitors[type] = monitor
        try await monitor.start()
    }

    /// Stop a specific monitor
    public func stopMonitor(_ type: MonitorType) async {
        guard let monitor = monitors[type] else { return }
        await monitor.stop()
        monitors.removeValue(forKey: type)
    }

    // MARK: - Monitor Factory

    private func createMonitor(for type: MonitorType) -> any ActivityMonitor {
        switch type {
        case .appSwitch:
            AppSwitchMonitor(logger: activityLogger)
        case .idleTime:
            IdleTimeMonitor(logger: activityLogger)
        case .focusMode:
            FocusModeMonitor(logger: activityLogger)
        case .screenTime:
            ScreenTimeMonitor(logger: activityLogger)
        case .inputActivity:
            SystemInputActivityMonitor(logger: activityLogger)
        }
    }

    // MARK: - Configuration

    /// Update monitoring configuration
    public func updateConfiguration(_ config: MonitoringConfiguration) async {
        let previousConfig = configuration
        configuration = config
        config.save()

        // Handle changes in enabled monitors
        if isMonitoring {
            // Stop disabled monitors
            for type in MonitorType.allCases {
                if previousConfig.enabledMonitors.contains(type),
                   !config.enabledMonitors.contains(type)
                {
                    await stopMonitor(type)
                }
            }

            // Start newly enabled monitors
            for type in config.enabledMonitors {
                if !previousConfig.enabledMonitors.contains(type) {
                    try? await startMonitor(type)
                }
            }
        }
    }

    public func getConfiguration() -> MonitoringConfiguration {
        configuration
    }

    // MARK: - Status

    /// Get current monitoring status
    public func getStatus() -> MonitoringStatus {
        MonitoringStatus(
            isMonitoring: isMonitoring,
            activeMonitors: Set(monitors.keys),
            configuration: configuration
        )
    }

    /// Check if a specific monitor is active
    public func isMonitorActive(_ type: MonitorType) -> Bool {
        monitors[type] != nil
    }
}

// MARK: - Activity Monitor Protocol

public protocol ActivityMonitor: Actor {
    var type: MonitorType { get }
    var isActive: Bool { get }

    func start() async throws
    func stop() async
}

// MARK: - Monitor Type

public enum MonitorType: String, Codable, Sendable, CaseIterable {
    case appSwitch
    case idleTime
    case focusMode
    case screenTime
    case inputActivity

    public var displayName: String {
        switch self {
        case .appSwitch: "App Switching"
        case .idleTime: "Idle Time"
        case .focusMode: "Focus Mode"
        case .screenTime: "Screen Time"
        case .inputActivity: "Input Activity"
        }
    }

    public var description: String {
        switch self {
        case .appSwitch:
            "Track which apps you use and for how long"
        case .idleTime:
            "Detect when you're away from your computer"
        case .focusMode:
            "Monitor focus mode changes"
        case .screenTime:
            "Track total screen time"
        case .inputActivity:
            "Track keyboard and mouse usage patterns"
        }
    }

    public var icon: String {
        switch self {
        case .appSwitch: "square.on.square"
        case .idleTime: "moon.zzz"
        case .focusMode: "moon"
        case .screenTime: "desktopcomputer"
        case .inputActivity: "keyboard"
        }
    }

    public var requiredPermission: PrivacyPermission {
        switch self {
        case .appSwitch, .screenTime:
            .accessibility
        case .idleTime, .inputActivity:
            .inputMonitoring
        case .focusMode:
            .notifications
        }
    }
}

// MARK: - Monitoring Configuration

public struct MonitoringConfiguration: Codable, Sendable, Equatable {
    public var enabledMonitors: Set<MonitorType>
    public var samplingInterval: TimeInterval
    public var idleThresholdMinutes: Int
    public var retentionDays: Int
    public var encryptLogs: Bool
    public var syncToCloud: Bool

    public init(
        enabledMonitors: Set<MonitorType> = [.appSwitch, .idleTime],
        samplingInterval: TimeInterval = 60,
        idleThresholdMinutes: Int = 5,
        retentionDays: Int = 30,
        encryptLogs: Bool = true,
        syncToCloud: Bool = false
    ) {
        self.enabledMonitors = enabledMonitors
        self.samplingInterval = samplingInterval
        self.idleThresholdMinutes = idleThresholdMinutes
        self.retentionDays = retentionDays
        self.encryptLogs = encryptLogs
        self.syncToCloud = syncToCloud
    }

    private static let configKey = "MonitoringService.configuration"

    public static func load() -> MonitoringConfiguration {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(MonitoringConfiguration.self, from: data)
        {
            return config
        }
        return MonitoringConfiguration()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: MonitoringConfiguration.configKey)
        }
    }
}

// MARK: - Monitoring Status

public struct MonitoringStatus: Sendable {
    public let isMonitoring: Bool
    public let activeMonitors: Set<MonitorType>
    public let configuration: MonitoringConfiguration
}

// MARK: - Monitoring Error

public enum MonitoringError: Error, LocalizedError, Sendable {
    case permissionDenied
    case notMonitoring
    case monitorFailed(MonitorType, String)
    case alreadyMonitoring

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Required permissions not granted"
        case .notMonitoring:
            "Monitoring is not active"
        case let .monitorFailed(type, reason):
            "\(type.displayName) monitor failed: \(reason)"
        case .alreadyMonitoring:
            "Monitoring is already active"
        }
    }
}

// MARK: - Individual Monitors

#if os(macOS)
    /// MainActor-isolated helper for app switch monitoring
    @MainActor
    final class AppSwitchObserverHelper {
        static let shared = AppSwitchObserverHelper()
        private var observer: NSObjectProtocol?

        private init() {}

        func setup(handler: @escaping @Sendable (String?) -> Void) -> String? {
            let currentApp = NSWorkspace.shared.frontmostApplication?.localizedName

            observer = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                // Extract app name on MainActor, pass only Sendable String
                let appName = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.localizedName
                handler(appName)
            }

            return currentApp
        }

        func cleanup() {
            if let observer {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
            observer = nil
        }
    }
#endif

/// Monitors app switching activity
public actor AppSwitchMonitor: ActivityMonitor {
    public let type: MonitorType = .appSwitch
    public private(set) var isActive = false

    private let logger: ActivityLogger
    private var currentApp: String?
    private var appStartTime: Date?

    init(logger: ActivityLogger) {
        self.logger = logger
    }

    public func start() async throws {
        guard !isActive else { return }
        isActive = true

        #if os(macOS)
            let initialApp = await AppSwitchObserverHelper.shared.setup { [weak self] appName in
                guard self != nil else { return }
                Task { [weak self] in
                    await self?.handleAppSwitch(appName: appName)
                }
            }
            currentApp = initialApp
            appStartTime = Date()
        #endif
    }

    public func stop() async {
        isActive = false

        #if os(macOS)
            await AppSwitchObserverHelper.shared.cleanup()
        #endif

        // Log final session
        if let app = currentApp, let startTime = appStartTime {
            await logAppSession(app: app, startTime: startTime, endTime: Date())
        }
    }

    #if os(macOS)
        private func handleAppSwitch(appName: String?) async {
            guard let app = appName else {
                return
            }

            let now = Date()

            // Log previous app session
            if let previousApp = currentApp, let startTime = appStartTime {
                await logAppSession(app: previousApp, startTime: startTime, endTime: now)
            }

            // Start tracking new app
            currentApp = app
            appStartTime = now
        }
    #endif

    private func logAppSession(app: String, startTime: Date, endTime: Date) async {
        let entry = ActivityLogEntry(
            type: .appUsage,
            timestamp: startTime,
            duration: endTime.timeIntervalSince(startTime),
            metadata: ["app": .string(app)]
        )
        await logger.log(entry)
    }
}

/// Monitors idle time
public actor IdleTimeMonitor: ActivityMonitor {
    public let type: MonitorType = .idleTime
    public private(set) var isActive = false

    private let logger: ActivityLogger
    private var checkTask: Task<Void, Never>?
    private var lastActiveTime: Date?
    private var isCurrentlyIdle = false

    init(logger: ActivityLogger) {
        self.logger = logger
    }

    public func start() async throws {
        guard !isActive else { return }
        isActive = true
        lastActiveTime = Date()

        checkTask = Task {
            while !Task.isCancelled, isActive {
                await checkIdleState()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }

    public func stop() async {
        isActive = false
        checkTask?.cancel()
        checkTask = nil
    }

    private func checkIdleState() async {
        #if os(macOS)
            let idleTime = await MainActor.run {
                CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)
            }

            let idleThreshold: TimeInterval = 300 // 5 minutes

            if idleTime > idleThreshold, !isCurrentlyIdle {
                // Became idle
                isCurrentlyIdle = true
                let entry = ActivityLogEntry(
                    type: .idleStart,
                    timestamp: Date(),
                    metadata: ["idleSeconds": .int(Int(idleTime))]
                )
                await logger.log(entry)
            } else if idleTime < 10, isCurrentlyIdle {
                // Became active
                isCurrentlyIdle = false
                let entry = ActivityLogEntry(
                    type: .idleEnd,
                    timestamp: Date(),
                    metadata: ["idleSeconds": .int(Int(idleTime))]
                )
                await logger.log(entry)
                lastActiveTime = Date()
            }
        #endif
    }
}

/// Monitors focus mode changes
public actor FocusModeMonitor: ActivityMonitor {
    public let type: MonitorType = .focusMode
    public private(set) var isActive = false

    private let logger: ActivityLogger

    init(logger: ActivityLogger) {
        self.logger = logger
    }

    public func start() async throws {
        guard !isActive else { return }
        isActive = true
        // Focus mode monitoring would use Apple's Focus API
        // Currently a placeholder as the API requires specific entitlements
    }

    public func stop() async {
        isActive = false
    }
}

/// Monitors screen time
public actor ScreenTimeMonitor: ActivityMonitor {
    public let type: MonitorType = .screenTime
    public private(set) var isActive = false

    private let logger: ActivityLogger
    private var sessionStart: Date?

    init(logger: ActivityLogger) {
        self.logger = logger
    }

    public func start() async throws {
        guard !isActive else { return }
        isActive = true
        sessionStart = Date()
    }

    public func stop() async {
        isActive = false

        if let start = sessionStart {
            let duration = Date().timeIntervalSince(start)
            let entry = ActivityLogEntry(
                type: .screenTime,
                timestamp: start,
                duration: duration,
                metadata: [:]
            )
            await logger.log(entry)
        }
        sessionStart = nil
    }
}

/// Monitors input activity (keyboard/mouse patterns)
public actor SystemInputActivityMonitor: ActivityMonitor {
    public let type: MonitorType = .inputActivity
    public private(set) var isActive = false

    private let logger: ActivityLogger
    private var checkTask: Task<Void, Never>?

    init(logger: ActivityLogger) {
        self.logger = logger
    }

    public func start() async throws {
        guard !isActive else { return }
        isActive = true

        checkTask = Task {
            while !Task.isCancelled, isActive {
                await sampleActivity()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
            }
        }
    }

    public func stop() async {
        isActive = false
        checkTask?.cancel()
        checkTask = nil
    }

    private func sampleActivity() async {
        #if os(macOS)
            // Sample recent input activity
            let keyboardIdle = await MainActor.run {
                CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
            }
            let mouseIdle = await MainActor.run {
                CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved)
            }

            let entry = ActivityLogEntry(
                type: .inputSample,
                timestamp: Date(),
                metadata: [
                    "keyboardIdleSeconds": .int(Int(keyboardIdle)),
                    "mouseIdleSeconds": .int(Int(mouseIdle))
                ]
            )
            await logger.log(entry)
        #endif
    }
}
