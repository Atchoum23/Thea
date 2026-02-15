import os.log
import SQLite3
@preconcurrency import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "ai.thea.app", category: "startup")

/// Check if running in testing mode (skip heavy initialization)
/// UI tests pass --uitesting flag, unit tests set XCTestConfigurationFilePath
private let isUITesting = CommandLine.arguments.contains("--uitesting")
private let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

@main
struct TheamacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var modelContainer: ModelContainer?
    @State private var storageError: Error?
    @State private var showingFallbackAlert = false

    init() {
        let schema = Schema([
            Conversation.self, Message.self, Project.self,
            TheaClipEntry.self, TheaClipPinboard.self, TheaClipPinboardEntry.self,
            TheaHabit.self, TheaHabitEntry.self
        ])
        let useInMemory = isUITesting || isUnitTesting

        // Pre-flight: delete incompatible store before SwiftData touches it
        if !useInMemory {
            Self.deleteStoreIfSchemaOutdated()
        }

        do {
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: useInMemory,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            _modelContainer = State(initialValue: container)
            if useInMemory {
                print("⚡ Testing mode: Using in-memory storage")
            }
        } catch {
            _storageError = State(initialValue: error)
            print("❌ Failed to initialize ModelContainer: \(error)")
        }
    }

    /// Check if the SQLite store has all required columns; delete if outdated.
    /// This runs BEFORE ModelContainer init to avoid CoreData caching failures.
    private static func deleteStoreIfSchemaOutdated() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.theathe"
        ) else { return }
        let storeURL = groupURL
            .appendingPathComponent("Library/Application Support")
            .appendingPathComponent("default.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        // Required columns that may be missing from older schemas
        let requiredColumns = ["ZISARCHIVED", "ZISREAD", "ZSTATUS"]

        // Open SQLite directly to inspect the schema
        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(ZCONVERSATION)", -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(stmt) }

        var existingColumns = Set<String>()
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let namePtr = sqlite3_column_text(stmt, 1) {
                existingColumns.insert(String(cString: namePtr))
            }
        }

        let missingColumns = requiredColumns.filter { !existingColumns.contains($0) }
        if !missingColumns.isEmpty {
            logger.warning("Store schema outdated (missing: \(missingColumns.joined(separator: ", "), privacy: .public)). Deleting store.")
            // Close DB before deleting
            sqlite3_close(db)
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: storeURL.deletingLastPathComponent()
                        .appendingPathComponent("default.store" + suffix)
                )
            }
        }
    }

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // MAIN WINDOW GROUP - Supports multiple windows and tabs
        WindowGroup(id: "main") {
            if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
                    .frame(minWidth: 900, minHeight: 600)
                    .onAppear {
                        setupManagers(container: container)
                        configureWindow()
                    }
                    .alert("Running in Temporary Mode", isPresented: $showingFallbackAlert) {
                        Button("Continue") { showingFallbackAlert = false }
                    } message: {
                        Text("Data storage initialization failed. Your data will not be saved between sessions. Please restart Thea to resolve this issue.")
                    }
            } else {
                Text("Storage initialization failed. Please restart Thea.")
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    openWindow(id: "main")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Tab") {
                    // macOS native tab: merge a new window into the current window as a tab
                    openWindow(id: "main")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.keyWindow?.mergeAllWindows(nil)
                    }
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("New Conversation") {
                    let conversation = ChatManager.shared.createConversation(title: "New Conversation")
                    NotificationCenter.default.post(
                        name: .selectNewConversation,
                        object: conversation
                    )
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Project") {
                    _ = ProjectManager.shared.createProject(title: "New Project")
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button("New Life Tracking Window") {
                    openWindow(id: "life-tracking")
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }

            CommandGroup(after: .pasteboard) {
                Button("Clipboard History") {
                    TheaClipWindowController.shared.togglePanel()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            CommandGroup(replacing: .help) {
                Button("Command Palette") {
                    NotificationCenter.default.post(name: .showCommandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }

        // LIFE TRACKING DASHBOARD WINDOW
        WindowGroup("Life Tracking", id: "life-tracking") {
            if let container = modelContainer {
                LifeTrackingView()
                    .modelContainer(container)
                    .frame(minWidth: 1000, minHeight: 700)
            }
        }
        .defaultSize(width: 1200, height: 800)

        // SETTINGS (SINGLE INSTANCE)
        Settings {
            if let container = modelContainer {
                MacSettingsView()
                    .modelContainer(container)
            }
        }
    }

    private func setupManagers(container: ModelContainer) {
        let context = container.mainContext

        logger.info("setupManagers called")

        // SKIP heavy initialization when running tests to prevent memory issues and timeouts
        guard !isUITesting && !isUnitTesting else {
            let mode = isUITesting ? "UI testing" : "unit testing"
            logger.info("Skipping MLX/model initialization (\(mode, privacy: .public) mode)")
            return
        }

        // PRIORITY: Initialize local model discovery FIRST (no Keychain required)
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            _ = LocalModelManager.shared
            _ = MLXModelManager.shared
            logger.info("Local model managers initialized")

            _ = ProviderRegistry.shared
            logger.info("ProviderRegistry initialized")

            // Refresh dynamic model registry (fetches fresh pricing/capabilities)
            await DynamicModelRegistry.shared.refreshIfNeeded()
        }

        // Pre-initialize StoreKit (starts transaction listener for in-app purchases)
        _ = StoreKitService.shared

        // Pre-initialize sync singletons so Settings > Sync doesn't beachball.
        // Their inits now defer heavy work to Tasks, so this is non-blocking.
        _ = CloudKitService.shared
        _ = PreferenceSyncEngine.shared
        _ = AppUpdateService.shared

        // Apply saved font-size preference to theme config on startup
        AppConfiguration.applyFontSize(SettingsManager.shared.fontSize)

        // Existing managers
        ChatManager.shared.setModelContext(context)
        ProjectManager.shared.setModelContext(context)
        KnowledgeManager.shared.setModelContext(context)
        FinancialManager.shared.setModelContext(context)
        MigrationManager.shared.setModelContext(context)
        MigrationEngine.shared.setModelContext(context)
        CodeIntelligenceManager.shared.setModelContext(context)
        ClipboardHistoryManager.shared.setModelContext(context)
        HabitManager.shared.setModelContext(context)
        ClipboardObserver.shared.start()

        // TODO: Restore prompt engineering managers after Phase 5+
        // PromptOptimizer.shared.setModelContext(context)
        // ErrorKnowledgeBaseManager.shared.setModelContext(context)

        // TODO: Restore window management after implementation
        // WindowManager.shared.setModelContext(context)

        // Privacy monitoring — auto-start network tracking and load daily snapshots
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await NetworkPrivacyMonitor.shared.loadDailySnapshots()
            await NetworkPrivacyMonitor.shared.startMonitoring()
            // Generate monthly transparency report if due (once per calendar month)
            if let report = await NetworkPrivacyMonitor.shared.generateMonthlyReportIfDue() {
                logger.info("Monthly privacy report generated: score \(report.privacyScore)/100, \(report.totalConnections) connections")
            }
            logger.info("NetworkPrivacyMonitor auto-started")
        }

        // Life Monitoring — deferred startup to avoid blocking app launch
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await LifeMonitoringCoordinator.shared.startMonitoring()
            logger.info("LifeMonitoringCoordinator started")
        }

        // Voice / Wake Word — deferred init (guarded by user preference)
        Task {
            try? await Task.sleep(for: .seconds(1))
            _ = VoiceFirstModeManager.shared // Initializes wake word listening if enabled
            logger.info("VoiceFirstModeManager initialized")
        }

        // Moltbook Agent — deferred init (guarded by user preference)
        Task {
            try? await Task.sleep(for: .seconds(2))
            let settings = SettingsManager.shared
            if settings.moltbookAgentEnabled {
                let agent = MoltbookAgent.shared
                await agent.configure(
                    previewMode: settings.moltbookPreviewMode,
                    maxDailyPosts: settings.moltbookMaxDailyPosts
                )
                await agent.enable()
                logger.info("MoltbookAgent enabled (preview: \(settings.moltbookPreviewMode, privacy: .public))")
            }
            // Wire OpenClaw message routing
            OpenClawBridge.shared.setup()
        }

        // Background service health monitoring — deferred startup
        Task {
            try? await Task.sleep(for: .seconds(3))
            BackgroundServiceMonitor.shared.startMonitoring()
            logger.info("BackgroundServiceMonitor started")
        }
    }

    private func configureWindow() {
        guard let window = NSApp.windows.first else { return }

        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        if #available(macOS 26, *) {
            window.titlebarSeparatorStyle = .none
        }

        let settings = SettingsManager.shared

        // Apply float-on-top setting
        window.level = settings.windowFloatOnTop ? .floating : .normal

        // Restore saved window position/size
        if settings.rememberWindowPosition {
            window.setFrameAutosaveName("TheaMainWindow")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        logger.info("applicationDidFinishLaunching")

        NSApplication.shared.registerForRemoteNotifications()
        AppUpdateService.registerNotificationCategory()

        _ = AppUpdateService.shared
        NSWindow.allowsAutomaticWindowTabbing = true

        guard !isUITesting && !isUnitTesting else {
            logger.info("Testing mode - skipping MLX/model initialization")
            return
        }

        // Model discovery runs in background — no blocking waits on main thread
        Task.detached(priority: .utility) {
            await LocalModelManager.shared.waitForDiscovery()
            let localCount = await LocalModelManager.shared.availableModels.count
            logger.info("LocalModelManager: \(localCount, privacy: .public) models discovered")

            await MLXModelManager.shared.waitForScan()
            let mlxCount = await MLXModelManager.shared.scannedModels.count
            logger.info("MLXModelManager: \(mlxCount, privacy: .public) models scanned")

            _ = await ProviderRegistry.shared.getAvailableLocalModels().count
            logger.info("Startup model discovery complete")
        }

        if VoiceActivationManager.shared.isEnabled {
            Task {
                try? await VoiceActivationManager.shared.requestPermissions()
                try? VoiceActivationManager.shared.startWakeWordDetection()
            }
        }
    }

    // MARK: - Remote Notifications

    func application(_: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        logger.info("Registered for remote notifications: \(tokenString.prefix(12), privacy: .private)")
    }

    func application(_: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.warning("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public)")
    }

    func application(
        _: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        logger.info("Received remote notification")

        let anyHashableUserInfo: [AnyHashable: Any] = Dictionary(
            uniqueKeysWithValues: userInfo.map { ($0.key as AnyHashable, $0.value) }
        )

        // Forward to AppUpdateService for update checks
        Task { @MainActor in
            await AppUpdateService.shared.handleRemoteNotification()
        }

        // Forward to CloudKitService for data sync
        Task {
            await CloudKitService.shared.handleNotification(anyHashableUserInfo)
        }

        // Forward to TheaClipSyncService for clipboard sync
        Task { @MainActor in
            await TheaClipSyncService.shared.handleRemoteNotification()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        // Keep app running even after last window closes (user can reopen via dock)
        false
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }
}
