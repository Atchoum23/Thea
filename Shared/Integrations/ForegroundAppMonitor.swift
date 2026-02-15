import AppKit
import Combine
import Foundation
import os.log

private let appMonitorLogger = Logger(subsystem: "ai.thea.app", category: "ForegroundAppMonitor")

/// Monitors foreground app changes and extracts context for AI assistance
@MainActor
final class ForegroundAppMonitor: ObservableObject {
    static let shared = ForegroundAppMonitor()

    // MARK: - Published Properties

    @Published var currentApp: NSRunningApplication?
    @Published var appContext: AppContext?
    @Published var isPairingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPairingEnabled, forKey: "appPairingEnabled")
            if isPairingEnabled && !isMonitoring {
                startMonitoring()
            } else if !isPairingEnabled && isMonitoring {
                stopMonitoring()
            }
        }
    }

    @Published var enabledApps: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledApps), forKey: "appPairingEnabledApps")
        }
    }

    @Published var includeSelectedText: Bool {
        didSet {
            UserDefaults.standard.set(includeSelectedText, forKey: "appPairingIncludeSelectedText")
        }
    }

    @Published var includeWindowContent: Bool {
        didSet {
            UserDefaults.standard.set(includeWindowContent, forKey: "appPairingIncludeWindowContent")
        }
    }

    // MARK: - Internal State

    private var isMonitoring = false
    private var observers: [NSObjectProtocol] = []
    private var contextExtractionTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        // Load saved settings
        self.isPairingEnabled = UserDefaults.standard.bool(forKey: "appPairingEnabled")

        if let savedApps = UserDefaults.standard.array(forKey: "appPairingEnabledApps") as? [String] {
            self.enabledApps = Set(savedApps)
        } else {
            // Default enabled apps
            self.enabledApps = [
                "com.apple.dt.Xcode",
                "com.microsoft.VSCode",
                "com.apple.Terminal",
                "com.googlecode.iterm2",
                "com.apple.Notes",
                "com.apple.Safari"
            ]
        }

        self.includeSelectedText = UserDefaults.standard.object(forKey: "appPairingIncludeSelectedText") as? Bool ?? true
        self.includeWindowContent = UserDefaults.standard.object(forKey: "appPairingIncludeWindowContent") as? Bool ?? true

        // Auto-start monitoring if enabled
        if isPairingEnabled {
            startMonitoring()
        }
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }

        // Check Accessibility permissions
        let trusted = AXIsProcessTrusted()
        if !trusted {
            appMonitorLogger.warning("⚠️ Accessibility permission not granted - app pairing will not work")
            return
        }

        isMonitoring = true

        // Observe foreground app changes
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                Task { @MainActor in
                    await self.handleForegroundAppChange(app)
                }
            }
        }

        observers.append(observer)

        // Extract context for currently active app
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            Task {
                await handleForegroundAppChange(activeApp)
            }
        }

        appMonitorLogger.info("✅ Foreground app monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false

        // Remove all observers
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()

        // Cancel ongoing extraction
        contextExtractionTask?.cancel()
        contextExtractionTask = nil

        appMonitorLogger.info("⏹️ Foreground app monitoring stopped")
    }

    // MARK: - Context Extraction

    private func handleForegroundAppChange(_ app: NSRunningApplication) async {
        guard isPairingEnabled else { return }

        currentApp = app

        // Cancel previous extraction if still running
        contextExtractionTask?.cancel()

        // Extract context asynchronously
        contextExtractionTask = Task {
            let context = await extractAppContext(app)

            if !Task.isCancelled {
                self.appContext = context

                // Notify ChatManager of context change
                NotificationCenter.default.post(
                    name: .foregroundAppContextChanged,
                    object: context
                )

                if let context = context {
                    appMonitorLogger.debug("📱 Extracted context for \(context.appName): \(context.windowTitle)")
                }
            }
        }
    }

    private func extractAppContext(_ app: NSRunningApplication) async -> AppContext? {
        guard let bundleID = app.bundleIdentifier else { return nil }

        // Check if this app is enabled for pairing
        guard enabledApps.contains(bundleID) else { return nil }

        // Route to app-specific extractor
        switch bundleID {
        case "com.apple.dt.Xcode":
            return await XcodeContextExtractor.extract(
                includeSelectedText: includeSelectedText,
                includeWindowContent: includeWindowContent
            )

        case "com.microsoft.VSCode":
            return await VSCodeContextExtractor.extract(
                includeSelectedText: includeSelectedText,
                includeWindowContent: includeWindowContent
            )

        case "com.googlecode.iterm2", "com.apple.Terminal", "dev.warp.Warp-Stable":
            return await TerminalContextExtractor.extract(
                includeSelectedText: includeSelectedText,
                includeWindowContent: includeWindowContent
            )

        case "com.apple.Notes", "com.apple.TextEdit":
            return await TextEditorContextExtractor.extract(
                includeSelectedText: includeSelectedText,
                includeWindowContent: includeWindowContent
            )

        case "com.apple.Safari":
            return await SafariContextExtractor.extract(
                includeSelectedText: includeSelectedText,
                includeWindowContent: includeWindowContent
            )

        default:
            // Generic fallback
            return await GenericContextExtractor.extract(
                app: app,
                includeSelectedText: includeSelectedText,
                includeWindowContent: includeWindowContent
            )
        }
    }

    // Note: stopMonitoring() should be called explicitly before app termination
    // deinit removed due to Swift 6 concurrency restrictions with @MainActor
}

// MARK: - AppContext Model

struct AppContext: Sendable {
    let bundleID: String
    let appName: String
    let windowTitle: String
    let selectedText: String?
    let visibleContent: String?
    let cursorPosition: CursorPosition?
    let additionalMetadata: [String: String]?

    struct CursorPosition: Sendable {
        let line: Int
        let column: Int
    }

    /// Format context for inclusion in AI prompts
    func formatForPrompt() -> String {
        var parts: [String] = []

        parts.append("App: \(appName) (\(bundleID))")
        parts.append("Window: \(windowTitle)")

        if let selectedText = selectedText, !selectedText.isEmpty {
            parts.append("Selected Text:\n\(selectedText)")
        }

        if let cursorPos = cursorPosition {
            parts.append("Cursor Position: Line \(cursorPos.line), Column \(cursorPos.column)")
        }

        if let content = visibleContent, !content.isEmpty {
            parts.append("Visible Content:\n\(content)")
        }

        if let metadata = additionalMetadata {
            for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
                parts.append("\(key): \(value)")
            }
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let foregroundAppContextChanged = Notification.Name("foregroundAppContextChanged")
}
