import SwiftUI
import SwiftData

@main
struct TheamacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var modelContainer: ModelContainer?
    @State private var storageError: Error?
    @State private var showingFallbackAlert = false

    init() {
        do {
            let container = try ModelContainerFactory.shared.createContainer()
            _modelContainer = State(initialValue: container)

            // Check if we're running in fallback mode
            if ModelContainerFactory.shared.isInMemoryFallback {
                _showingFallbackAlert = State(initialValue: true)
            }
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
                DataStorageErrorView(error: storageError)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    WindowManager.shared.openNewChatWindow()
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
                    WindowManager.shared.openNewLifeTrackingWindow()
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
                SettingsView()
                    .modelContainer(container)
                    .frame(width: 600, height: 500)
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

        // New prompt engineering managers
        PromptOptimizer.shared.setModelContext(context)
        ErrorKnowledgeBaseManager.shared.setModelContext(context)

        // Window management
        WindowManager.shared.setModelContext(context)

        // Life tracking managers (macOS)
        ScreenTimeTracker.shared.setModelContext(context)
        InputTrackingManager.shared.setModelContext(context)
        BrowserHistoryTracker.shared.setModelContext(context)
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
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
