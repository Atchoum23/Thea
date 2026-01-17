import SwiftUI
import SwiftData

@main
struct TheaiPadOSApp: App {
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
        WindowGroup {
            if let container = modelContainer {
                iPadOSHomeView()
                    .modelContainer(container)
                    .onAppear {
                        setupManagers(container: container)
                    }
                    .alert("Running in Temporary Mode", isPresented: $showingFallbackAlert) {
                        Button("Continue") { showingFallbackAlert = false }
                    } message: {
                        Text("Data storage initialization failed. Your data will not be saved between sessions. Please restart Thea to resolve this issue.")
                    }
            } else {
                DataStorageErrorView(error: storageError)
            }
        }
    }

    private func setupManagers(container: ModelContainer) {
        let context = container.mainContext

        ChatManager.shared.setModelContext(context)
        ProjectManager.shared.setModelContext(context)
        KnowledgeManager.shared.setModelContext(context)
        FinancialManager.shared.setModelContext(context)
        MigrationManager.shared.setModelContext(context)
        MigrationEngine.shared.setModelContext(context)
    }
}
