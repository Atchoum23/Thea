import Foundation
import os.log
#if os(macOS)
    import AppKit
    import ApplicationServices
#endif

// MARK: - App Activity Context Provider

/// Provides context about active applications, windows, and user activity (primarily macOS)
public actor AppActivityContextProvider: ContextProvider {
    public let providerId = "appActivity"
    public let displayName = "App Activity"

    private let logger = Logger(subsystem: "app.thea", category: "AppActivityProvider")

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?

    #if os(macOS)
        // Use a MainActor-isolated helper to manage observers
        private var observerHelper: WorkspaceObserverHelper?
    #endif

    // Cached values
    private var recentApps: [AppActivityContext.RecentApp] = []
    private var lastActiveApp: String?

    public var isActive: Bool { state == .running }

    #if os(macOS)
        public var requiresPermission: Bool { true }

        public var hasPermission: Bool {
            get async {
                await MainActor.run {
                    AXIsProcessTrusted()
                }
            }
        }
    #endif

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        #if os(macOS)
            // Create observer helper on MainActor
            let helper = await MainActor.run {
                WorkspaceObserverHelper()
            }
            observerHelper = helper

            // Setup observers with callback
            await helper.setup { [weak self] bundleID, name in
                Task {
                    await self?.handleAppActivation(bundleID: bundleID, name: name)
                }
            }
        #endif

        // Start periodic updates
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchAppActivity()
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    break // Task cancelled — stop periodic updates
                }
            }
        }

        state = .running
        logger.info("App activity provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        #if os(macOS)
            if let helper = observerHelper {
                await helper.teardown()
            }
            observerHelper = nil
        #endif

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("App activity provider stopped")
    }

    public func getCurrentContext() async -> ContextUpdate? {
        let context = await buildAppActivityContext()
        return ContextUpdate(
            providerId: providerId,
            updateType: .appActivity(context),
            priority: .normal
        )
    }

    // MARK: - Private Methods

    #if os(macOS)
        private func handleAppActivation(bundleID: String, name: String) async {
            lastActiveApp = bundleID
            updateRecentApps(bundleID: bundleID, name: name)
            await fetchAppActivity()
        }
    #endif

    private func updateRecentApps(bundleID: String, name: String) {
        // Remove existing entry for this app
        recentApps.removeAll { $0.bundleID == bundleID }

        // Add to front
        let recentApp = AppActivityContext.RecentApp(
            bundleID: bundleID,
            name: name,
            lastUsed: Date(),
            usageToday: nil
        )
        recentApps.insert(recentApp, at: 0)

        // Keep only last 10
        if recentApps.count > 10 {
            recentApps = Array(recentApps.prefix(10))
        }
    }

    private func fetchAppActivity() async {
        let context = await buildAppActivityContext()

        let update = ContextUpdate(
            providerId: providerId,
            updateType: .appActivity(context),
            priority: .normal
        )
        continuation?.yield(update)
    }

    private func buildAppActivityContext() async -> AppActivityContext {
        #if os(macOS)
            let macContext = await getMacOSContext()
            return AppActivityContext(
                activeAppBundleID: macContext.bundleID,
                activeAppName: macContext.appName,
                activeWindowTitle: macContext.windowTitle,
                activeDocumentPath: macContext.documentPath,
                recentApps: recentApps,
                screenTimeToday: nil
            )
        #else
            return AppActivityContext(recentApps: recentApps)
        #endif
    }

    #if os(macOS)
        private struct MacOSContextInfo: Sendable {
            let bundleID: String?
            let appName: String?
            let windowTitle: String?
            let documentPath: String?
        }

        private func getMacOSContext() async -> MacOSContextInfo {
            await MainActor.run {
                let workspace = NSWorkspace.shared
                let frontApp = workspace.frontmostApplication

                var windowTitle: String?
                var documentPath: String?

                // Get window title if accessibility is enabled
                if AXIsProcessTrusted(), let app = frontApp {
                    windowTitle = getActiveWindowTitle(for: app)
                    documentPath = getActiveDocumentPath(for: app)
                }

                return MacOSContextInfo(
                    bundleID: frontApp?.bundleIdentifier,
                    appName: frontApp?.localizedName,
                    windowTitle: windowTitle,
                    documentPath: documentPath
                )
            }
        }

        @MainActor
        private func getActiveWindowTitle(for app: NSRunningApplication) -> String? {
            let pid = app.processIdentifier
            let appRef = AXUIElementCreateApplication(pid)

            var focusedWindow: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)

            guard result == .success, let window = focusedWindow else { return nil }

            var title: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)

            guard titleResult == .success, let titleString = title as? String else { return nil }

            return titleString
        }

        @MainActor
        private func getActiveDocumentPath(for app: NSRunningApplication) -> String? {
            let pid = app.processIdentifier
            let appRef = AXUIElementCreateApplication(pid)

            var focusedWindow: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)

            guard result == .success, let window = focusedWindow else { return nil }

            var document: CFTypeRef?
            let docResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXDocumentAttribute as CFString, &document)

            guard docResult == .success, let docURL = document as? String else { return nil }

            // Convert file URL to path
            if docURL.hasPrefix("file://") {
                return URL(string: docURL)?.path
            }

            return docURL
        }
    #endif
}

// MARK: - Workspace Observer Helper (macOS)

#if os(macOS)
    /// MainActor-isolated helper to manage NSWorkspace observers
    /// Keeps all observer tokens on the MainActor to avoid Sendable issues
    @MainActor
    private final class WorkspaceObserverHelper {
        private var observerTokens: [any NSObjectProtocol] = []

        nonisolated init() {}

        func setup(onAppActivation: @escaping @Sendable (String, String) -> Void) {
            let workspace = NSWorkspace.shared
            let center = workspace.notificationCenter

            // App activated
            let activateToken = center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bundleID = app.bundleIdentifier else { return }
                let name = app.localizedName ?? bundleID
                onAppActivation(bundleID, name)
            }
            observerTokens.append(activateToken)

            // App launched
            let launchToken = center.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Just log for now
            }
            observerTokens.append(launchToken)
        }

        func teardown() {
            let center = NSWorkspace.shared.notificationCenter
            for token in observerTokens {
                center.removeObserver(token)
            }
            observerTokens.removeAll()
        }
    }
#endif
