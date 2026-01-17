@preconcurrency import SwiftData
import SwiftUI

@main
struct TheamacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var modelContainer: ModelContainer?
    @State private var storageError: Error?
    @State private var showingFallbackAlert = false

    init() {
        do {
            // TODO: Restore ModelContainerFactory once implemented
            // let container = try ModelContainerFactory.shared.createContainer()
            let schema = Schema([Conversation.self, Message.self, Project.self])
            let container = try ModelContainer(for: schema)
            _modelContainer = State(initialValue: container)

            // Check if we're running in fallback mode
            // TODO: Restore after ModelContainerFactory implementation
            // if ModelContainerFactory.shared.isInMemoryFallback {
            //     _showingFallbackAlert = State(initialValue: true)
            // }
        } catch {
            _storageError = State(initialValue: error)
            print("❌ Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        // MAIN WINDOW GROUP - Can open multiple instances
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
                // TODO: Restore DataStorageErrorView once implemented
                Text("Storage initialization failed. Please restart Thea.")
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    // TODO: Restore WindowManager.shared.openNewChatWindow()
                    NSApp.keyWindow?.makeKeyAndOrderFront(nil)
                }
                .keyboardShortcut("n", modifiers: .command)

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
                    // TODO: Restore WindowManager.shared.openNewLifeTrackingWindow()
                    // Placeholder action
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
                    .frame(minWidth: 1_000, minHeight: 700)
            }
        }
        .defaultSize(width: 1_200, height: 800)

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
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable voice activation if configured
        if VoiceActivationManager.shared.isEnabled {
            Task {
                try? await VoiceActivationManager.shared.requestPermissions()
                try? VoiceActivationManager.shared.startWakeWordDetection()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
