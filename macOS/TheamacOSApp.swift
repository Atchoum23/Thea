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
        let schema = Schema([Conversation.self, Message.self, Project.self])
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
            logger.warning("Store schema outdated (missing: \(missingColumns.joined(separator: ", "))). Deleting store.")
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
                    _ = ChatManager.shared.createConversation(title: "New Conversation")
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

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }

        // LIFE TRACKING DASHBOARD WINDOW
        // TODO: Restore LifeTrackingView once implemented
        WindowGroup("Life Tracking", id: "life-tracking") {
            if let container = modelContainer {
                Text("Life Tracking (Coming Soon)")
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

        // Debug: Write to file to verify this code is running
        let debugPath = FileManager.default.temporaryDirectory.appendingPathComponent("thea_startup.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        try? "[\(timestamp)] setupManagers called\n".write(to: debugPath, atomically: true, encoding: .utf8)

        // SKIP heavy initialization when running tests to prevent memory issues and timeouts
        guard !isUITesting && !isUnitTesting else {
            let mode = isUITesting ? "UI testing" : "unit testing"
            let logMsg = "[\(ISO8601DateFormatter().string(from: Date()))] Skipping MLX/model initialization (\(mode) mode)\n"
            if let handle = try? FileHandle(forWritingTo: debugPath) {
                handle.seekToEndOfFile()
                handle.write(logMsg.data(using: .utf8)!)
                handle.closeFile()
            }
            return
        }

        // PRIORITY: Initialize local model discovery FIRST (no Keychain required)
        // This ensures local models are available even if user hasn't approved Keychain access
        Task {
            // Give the UI a moment to appear before starting discovery
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Start local model discovery immediately (no Keychain needed)
            _ = LocalModelManager.shared
            _ = MLXModelManager.shared

            let logMsg1 = "[\(ISO8601DateFormatter().string(from: Date()))] Local model managers initialized\n"
            if let handle = try? FileHandle(forWritingTo: debugPath) {
                handle.seekToEndOfFile()
                handle.write(logMsg1.data(using: .utf8)!)
                handle.closeFile()
            }

            // Then initialize ProviderRegistry (which may trigger Keychain prompt)
            // Doing this in a Task allows the UI to remain responsive
            _ = ProviderRegistry.shared

            let logMsg2 = "[\(ISO8601DateFormatter().string(from: Date()))] ProviderRegistry initialized\n"
            if let handle = try? FileHandle(forWritingTo: debugPath) {
                handle.seekToEndOfFile()
                handle.write(logMsg2.data(using: .utf8)!)
                handle.closeFile()
            }
        }

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

        // TODO: Restore prompt engineering managers after Phase 5+
        // PromptOptimizer.shared.setModelContext(context)
        // ErrorKnowledgeBaseManager.shared.setModelContext(context)

        // TODO: Restore window management after implementation
        // WindowManager.shared.setModelContext(context)

        // TODO: Restore life tracking managers (macOS) after implementation
        // ScreenTimeTracker.shared.setModelContext(context)
        // InputTrackingManager.shared.setModelContext(context)
        // BrowserHistoryTracker.shared.setModelContext(context)
    }

    private func configureWindow() {
        if let window = NSApp.windows.first {
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            // Remove titlebar separator for seamless glass integration
            if #available(macOS 26, *) {
                window.titlebarSeparatorStyle = .none
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop/thea_debug.log")

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        // Always append to file - use Data append for reliability
        do {
            let data = line.data(using: .utf8)!
            if FileManager.default.fileExists(atPath: logFile.path) {
                let handle = try FileHandle(forUpdating: logFile)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: logFile)
            }
        } catch {
            // Fallback: print to stderr which shows in Xcode console
            fputs("LOG WRITE ERROR: \(error) - \(line)", stderr)
        }

        // Also send to unified log (view with: log stream --predicate 'subsystem == "ai.thea.app"')
        logger.notice("\(message, privacy: .public)")
    }

    func applicationDidFinishLaunching(_: Notification) {
        log("🚀 applicationDidFinishLaunching called")

        // Register for remote notifications (CloudKit subscriptions)
        NSApplication.shared.registerForRemoteNotifications()
        AppUpdateService.registerNotificationCategory()
        log("📡 Registered for remote notifications and update category")

        // Initialize AppUpdateService (triggers subscription setup + initial check)
        _ = AppUpdateService.shared

        // Enable native macOS window tabbing (View > Show Tab Bar, Cmd+T)
        NSWindow.allowsAutomaticWindowTabbing = true

        // SKIP heavy initialization when running tests to prevent memory issues and timeouts
        guard !isUITesting && !isUnitTesting else {
            log("⚡ Testing mode - skipping MLX/model initialization")
            return
        }

        // Initialize local model managers immediately (no Keychain needed)
        Task { @MainActor in
            self.log("📦 Starting local model discovery...")

            // Trigger LocalModelManager initialization and wait for discovery to complete
            await LocalModelManager.shared.waitForDiscovery()

            let localCount = LocalModelManager.shared.availableModels.count
            self.log("✅ LocalModelManager: \(localCount) models discovered")

            // Trigger MLXModelManager initialization and wait for scan
            await MLXModelManager.shared.waitForScan()

            let mlxCount = MLXModelManager.shared.scannedModels.count
            self.log("✅ MLXModelManager: \(mlxCount) models scanned")

            // Log the actual model names
            for model in LocalModelManager.shared.availableModels {
                self.log("  📂 Local model: \(model.name)")
            }

            // Initialize ProviderRegistry and register local models
            self.log("🔌 Initializing ProviderRegistry...")
            _ = ProviderRegistry.shared
            // Give it time to register local models
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            let registeredLocalModels = ProviderRegistry.shared.getAvailableLocalModels()
            self.log("📊 ProviderRegistry: \(registeredLocalModels.count) local models registered")

            for modelName in registeredLocalModels.prefix(5) {
                self.log("  ✅ Registered: \(modelName)")
            }
            if registeredLocalModels.count > 5 {
                self.log("  ... and \(registeredLocalModels.count - 5) more")
            }

            self.log("🏁 Startup complete - ready to chat!")
        }

        // Enable voice activation if configured
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
        log("📡 Registered for remote notifications: \(tokenString.prefix(12))...")
    }

    func application(_: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log("⚠️ Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        log("📩 Received remote notification")

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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        // Keep app running even after last window closes (user can reopen via dock)
        false
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }
}
