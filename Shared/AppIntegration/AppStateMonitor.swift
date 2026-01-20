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
                Task { [weak self] in
                    await self?.handleAppLaunched(notification)
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
                Task { [weak self] in
                    await self?.handleAppTerminated(notification)
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
                Task { [weak self] in
                    await self?.handleAppActivated(notification)
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
                Task { [weak self] in
                    await self?.handleAppDeactivated(notification)
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
                Task { [weak self] in
                    await self?.handleAppHidden(notification)
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
                Task { [weak self] in
                    await self?.handleAppUnhidden(notification)
                }
            }
            ObserverStorage.shared.add(observer)
        }
    }

    private func handleAppLaunched(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        let info = AppInfo(
            bundleIdentifier: bundleId,
            name: app.localizedName ?? bundleId,
            isActive: app.isActive,
            isHidden: app.isHidden,
            processIdentifier: app.processIdentifier
        )

        appStates[bundleId] = AppState(
            bundleIdentifier: bundleId,
            isRunning: true,
            isActive: app.isActive,
            isHidden: app.isHidden,
            launchTime: Date()
        )

        onAppLaunched?(info)
    }

    private func handleAppTerminated(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        appStates.removeValue(forKey: bundleId)
        onAppTerminated?(bundleId)
    }

    private func handleAppActivated(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        if var state = appStates[bundleId] {
            state.isActive = true
            state.lastActivatedTime = Date()
            appStates[bundleId] = state
        }

        let info = AppInfo(
            bundleIdentifier: bundleId,
            name: app.localizedName ?? bundleId,
            isActive: true,
            isHidden: app.isHidden,
            processIdentifier: app.processIdentifier
        )

        onAppActivated?(info)
    }

    private func handleAppDeactivated(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        if var state = appStates[bundleId] {
            state.isActive = false
            appStates[bundleId] = state
        }

        onAppDeactivated?(bundleId)
    }

    private func handleAppHidden(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        if var state = appStates[bundleId] {
            state.isHidden = true
            appStates[bundleId] = state
        }

        onAppHidden?(bundleId)
    }

    private func handleAppUnhidden(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

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

    /// Capture the entire screen
    public func captureScreen() async throws -> CGImage? {
        #if os(macOS)
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw IntegrationError.accessibilityNotGranted
        }

        let displayId = CGMainDisplayID()
        return CGDisplayCreateImage(displayId)
        #else
        throw IntegrationError.notSupported
        #endif
    }

    /// Capture a specific region
    public func captureRegion(_ rect: CGRect) async throws -> CGImage? {
        #if os(macOS)
        guard CGPreflightScreenCaptureAccess() else {
            throw IntegrationError.accessibilityNotGranted
        }

        let displayId = CGMainDisplayID()
        return CGDisplayCreateImage(displayId, rect: rect)
        #else
        throw IntegrationError.notSupported
        #endif
    }

    /// Capture a specific window
    public func captureWindow(windowId: CGWindowID) async throws -> CGImage? {
        #if os(macOS)
        guard CGPreflightScreenCaptureAccess() else {
            throw IntegrationError.accessibilityNotGranted
        }

        return CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowId,
            [.boundsIgnoreFraming]
        )
        #else
        throw IntegrationError.notSupported
        #endif
    }

    // MARK: - Element Detection

    /// Find UI elements in an image using visual analysis
    public func detectElements(in image: CGImage) async throws -> [DetectedElement] {
        // This would use Vision framework for element detection
        // Simplified implementation
        []
    }

    /// Find text in an image using OCR
    public func detectText(in image: CGImage) async throws -> [DetectedText] {
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
