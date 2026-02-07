//
//  AppStateMonitor.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

@preconcurrency import Foundation
#if os(macOS)
    import AppKit
    import ScreenCaptureKit
#endif

// MARK: - Observer Storage (MainActor isolated)

#if os(macOS)
    /// MainActor-isolated storage for notification observers
    @MainActor
    final class ObserverStorage {
        static let shared = ObserverStorage()
        private var observers: [NSObjectProtocol] = []

        private init() {}

        func add(_ observer: NSObjectProtocol) {
            observers.append(observer)
        }

        func removeAll() {
            for observer in observers {
                NSWorkspace.shared.notificationCenter.removeObserver(observer)
            }
            observers.removeAll()
        }
    }
#endif

// MARK: - App State Monitor

/// Monitors application state changes across the system
public actor AppStateMonitor {
    public static let shared = AppStateMonitor()

    // MARK: - State

    private var isMonitoring = false
    private var appStates: [String: AppState] = [:]

    // MARK: - Callbacks

    public var onAppLaunched: ((AppInfo) -> Void)?
    public var onAppTerminated: ((String) -> Void)?
    public var onAppActivated: ((AppInfo) -> Void)?
    public var onAppDeactivated: ((String) -> Void)?
    public var onAppHidden: ((String) -> Void)?
    public var onAppUnhidden: ((String) -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Monitoring

    /// Start monitoring app state changes
    public func startMonitoring() async {
        guard !isMonitoring else { return }
        isMonitoring = true

        #if os(macOS)
            await setupMacOSMonitoring()
        #endif

        // Initialize current app states
        await initializeAppStates()
    }

    /// Stop monitoring
    public func stopMonitoring() async {
        isMonitoring = false

        #if os(macOS)
            await ObserverStorage.shared.removeAll()
        #endif
    }

    /// Sendable struct for passing app notification data across actor boundaries
    private struct AppNotificationData: Sendable {
        let bundleIdentifier: String
        let name: String
        let isActive: Bool
        let isHidden: Bool
        let processIdentifier: Int32
    }

    /// Extract Sendable data from notification
    private static func extractAppData(from notification: Notification) -> AppNotificationData? {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier
        else {
            return nil
        }
        return AppNotificationData(
            bundleIdentifier: bundleId,
            name: app.localizedName ?? bundleId,
            isActive: app.isActive,
            isHidden: app.isHidden,
            processIdentifier: app.processIdentifier
        )
    }

    #if os(macOS)
        private func setupMacOSMonitoring() async {
            let notificationCenter = NSWorkspace.shared.notificationCenter

            // App launched
            await MainActor.run {
                let observer = notificationCenter.addObserver(
                    forName: NSWorkspace.didLaunchApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let appData = Self.extractAppData(from: notification) else { return }
                    Task { [weak self] in
                        await self?.handleAppLaunched(appData: appData)
                    }
                }
                ObserverStorage.shared.add(observer)
            }

            // App terminated
            await MainActor.run {
                let observer = notificationCenter.addObserver(
                    forName: NSWorkspace.didTerminateApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let appData = Self.extractAppData(from: notification) else { return }
                    Task { [weak self] in
                        await self?.handleAppTerminated(bundleId: appData.bundleIdentifier)
                    }
                }
                ObserverStorage.shared.add(observer)
            }

            // App activated
            await MainActor.run {
                let observer = notificationCenter.addObserver(
                    forName: NSWorkspace.didActivateApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let appData = Self.extractAppData(from: notification) else { return }
                    Task { [weak self] in
                        await self?.handleAppActivated(appData: appData)
                    }
                }
                ObserverStorage.shared.add(observer)
            }

            // App deactivated
            await MainActor.run {
                let observer = notificationCenter.addObserver(
                    forName: NSWorkspace.didDeactivateApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let appData = Self.extractAppData(from: notification) else { return }
                    Task { [weak self] in
                        await self?.handleAppDeactivated(bundleId: appData.bundleIdentifier)
                    }
                }
                ObserverStorage.shared.add(observer)
            }

            // App hidden
            await MainActor.run {
                let observer = notificationCenter.addObserver(
                    forName: NSWorkspace.didHideApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let appData = Self.extractAppData(from: notification) else { return }
                    Task { [weak self] in
                        await self?.handleAppHidden(bundleId: appData.bundleIdentifier)
                    }
                }
                ObserverStorage.shared.add(observer)
            }

            // App unhidden
            await MainActor.run {
                let observer = notificationCenter.addObserver(
                    forName: NSWorkspace.didUnhideApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let appData = Self.extractAppData(from: notification) else { return }
                    Task { [weak self] in
                        await self?.handleAppUnhidden(bundleId: appData.bundleIdentifier)
                    }
                }
                ObserverStorage.shared.add(observer)
            }
        }

        private func handleAppLaunched(appData: AppNotificationData) async {
            let info = AppInfo(
                bundleIdentifier: appData.bundleIdentifier,
                name: appData.name,
                isActive: appData.isActive,
                isHidden: appData.isHidden,
                processIdentifier: appData.processIdentifier
            )

            appStates[appData.bundleIdentifier] = AppState(
                bundleIdentifier: appData.bundleIdentifier,
                isRunning: true,
                isActive: appData.isActive,
                isHidden: appData.isHidden,
                launchTime: Date()
            )

            onAppLaunched?(info)
        }

        private func handleAppTerminated(bundleId: String) async {
            appStates.removeValue(forKey: bundleId)
            onAppTerminated?(bundleId)
        }

        private func handleAppActivated(appData: AppNotificationData) async {
            if var state = appStates[appData.bundleIdentifier] {
                state.isActive = true
                state.lastActivatedTime = Date()
                appStates[appData.bundleIdentifier] = state
            }

            let info = AppInfo(
                bundleIdentifier: appData.bundleIdentifier,
                name: appData.name,
                isActive: true,
                isHidden: appData.isHidden,
                processIdentifier: appData.processIdentifier
            )

            onAppActivated?(info)
        }

        private func handleAppDeactivated(bundleId: String) async {
            if var state = appStates[bundleId] {
                state.isActive = false
                appStates[bundleId] = state
            }

            onAppDeactivated?(bundleId)
        }

        private func handleAppHidden(bundleId: String) async {
            if var state = appStates[bundleId] {
                state.isHidden = true
                appStates[bundleId] = state
            }

            onAppHidden?(bundleId)
        }

        private func handleAppUnhidden(bundleId: String) async {
            if var state = appStates[bundleId] {
                state.isHidden = false
                appStates[bundleId] = state
            }

            onAppUnhidden?(bundleId)
        }
    #endif

    private func initializeAppStates() async {
        #if os(macOS)
            let apps = await MainActor.run {
                NSWorkspace.shared.runningApplications
            }

            for app in apps {
                guard let bundleId = app.bundleIdentifier else { continue }

                appStates[bundleId] = AppState(
                    bundleIdentifier: bundleId,
                    isRunning: true,
                    isActive: app.isActive,
                    isHidden: app.isHidden,
                    launchTime: nil
                )
            }
        #endif
    }

    // MARK: - Query

    /// Get current state of an app
    public func getAppState(_ bundleId: String) -> AppState? {
        appStates[bundleId]
    }

    /// Get all app states
    public func getAllAppStates() -> [String: AppState] {
        appStates
    }

    /// Check if an app is running
    public func isAppRunning(_ bundleId: String) -> Bool {
        appStates[bundleId]?.isRunning ?? false
    }

    /// Check if an app is active
    public func isAppActive(_ bundleId: String) -> Bool {
        appStates[bundleId]?.isActive ?? false
    }

    /// Get the currently active app
    public func getActiveApp() -> String? {
        appStates.first { $0.value.isActive }?.key
    }
}

// MARK: - App State

public struct AppState: Sendable {
    public var bundleIdentifier: String
    public var isRunning: Bool
    public var isActive: Bool
    public var isHidden: Bool
    public var launchTime: Date?
    public var lastActivatedTime: Date?

    public init(
        bundleIdentifier: String,
        isRunning: Bool,
        isActive: Bool,
        isHidden: Bool,
        launchTime: Date? = nil,
        lastActivatedTime: Date? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.isRunning = isRunning
        self.isActive = isActive
        self.isHidden = isHidden
        self.launchTime = launchTime
        self.lastActivatedTime = lastActivatedTime
    }
}

// MARK: - Visual Analysis Service

/// Service for visual analysis using screen capture and OCR
public actor VisualAnalysisService {
    public static let shared = VisualAnalysisService()

    // MARK: - Initialization

    private init() {}

    // MARK: - Screen Capture

    /// Capture the entire screen using ScreenCaptureKit
    public func captureScreen() async throws -> CGImage? {
        #if os(macOS)
            guard CGPreflightScreenCaptureAccess() else {
                CGRequestScreenCaptureAccess()
                throw IntegrationError.accessibilityNotGranted
            }

            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                throw IntegrationError.notSupported
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width * 2  // Retina
            config.height = display.height * 2
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        #else
            throw IntegrationError.notSupported
        #endif
    }

    /// Capture a specific screen region using ScreenCaptureKit
    public func captureRegion(_ rect: CGRect) async throws -> CGImage? {
        #if os(macOS)
            guard CGPreflightScreenCaptureAccess() else {
                throw IntegrationError.accessibilityNotGranted
            }

            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                throw IntegrationError.notSupported
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = rect
            config.width = Int(rect.width) * 2
            config.height = Int(rect.height) * 2
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        #else
            throw IntegrationError.notSupported
        #endif
    }

    /// Capture a specific window using ScreenCaptureKit
    public func captureWindow(windowId: CGWindowID) async throws -> CGImage? {
        #if os(macOS)
            guard CGPreflightScreenCaptureAccess() else {
                throw IntegrationError.accessibilityNotGranted
            }

            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                throw IntegrationError.notSupported
            }

            // Find the matching window
            guard let window = content.windows.first(where: { $0.windowID == windowId }) else {
                throw IntegrationError.notSupported
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width) * 2
            config.height = Int(window.frame.height) * 2
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        #else
            throw IntegrationError.notSupported
        #endif
    }

    // MARK: - Element Detection

    /// Find UI elements in an image using visual analysis
    public func detectElements(in _: CGImage) async throws -> [DetectedElement] {
        // This would use Vision framework for element detection
        // Simplified implementation
        []
    }

    /// Find text in an image using OCR
    public func detectText(in _: CGImage) async throws -> [DetectedText] {
        // This would use Vision framework for OCR
        // Simplified implementation
        []
    }
}

// MARK: - Detected Element

public struct DetectedElement: Sendable, Identifiable {
    public let id = UUID()
    public let type: ElementType
    public let bounds: CGRect
    public let confidence: Float

    public enum ElementType: String, Sendable {
        case button
        case textField
        case image
        case icon
        case text
        case unknown
    }
}

// MARK: - Detected Text

public struct DetectedText: Sendable, Identifiable {
    public let id = UUID()
    public let text: String
    public let bounds: CGRect
    public let confidence: Float
}
