@preconcurrency import SwiftData
import SwiftUI

@main
struct TheaiOSApp: App {
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
                AdaptiveHomeView()
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
        ClipboardHistoryManager.shared.setModelContext(context)
        HabitManager.shared.setModelContext(context)

        // Initialize StoreKit (starts transaction listener for in-app purchases)
        _ = StoreKitService.shared

        // Initialize sync singletons (non-blocking, defers heavy work to Tasks)
        _ = CloudKitService.shared
        _ = PreferenceSyncEngine.shared

        // Life Monitoring — deferred startup to avoid blocking app launch
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await LifeMonitoringCoordinator.shared.startMonitoring()
        }

        // Voice / Wake Word — deferred init (guarded by user preference)
        Task {
            try? await Task.sleep(for: .seconds(1))
            _ = VoiceFirstModeManager.shared
        }

        // Messaging Gateway — deferred startup (connects enabled platform connectors)
        Task {
            try? await Task.sleep(for: .seconds(2))
            OpenClawBridge.shared.setup()
            await TheaMessagingGateway.shared.start()
        }

        // U3/AE3: PlatformFeaturesHub — activates iOS-specific intelligence foundation:
        // HealthKitProvider, MotionContextProvider, ScreenTimeObserver, etc.
        Task {
            try? await Task.sleep(for: .seconds(3))
            await PlatformFeaturesHub.shared.initialize()
        }

        // U3/AE3: TheaIntelligenceOrchestrator — top-level intelligence coordinator
        Task {
            try? await Task.sleep(for: .seconds(4))
            TheaIntelligenceOrchestrator.shared.start()
        }

        // AAA3 Gap Wiring — 13 previously disconnected systems (iOS-aware subset).
        // DrivingDetectionService + ScreenTimeAnalyzer start iOS-only code paths internally.
        Task {
            try? await Task.sleep(for: .seconds(8))
            AmbientIntelligenceEngine.shared.start()
            DrivingDetectionService.shared.start()
            ScreenTimeAnalyzer.shared.startMonitoring()
            CalendarIntelligenceService.shared.startMonitoring()
            LocationIntelligenceService.shared.start()
            SleepAnalysisService.shared.startMonitoring()
            ProactiveInsightEngine.shared.start()
            FocusSessionManager.shared.restore()
            HabitTrackingService.shared.start()
            GoalTrackingService.shared.start()
            WellbeingMonitor.shared.start()
        }

        // AAC3: FinancialIntelligenceService — initial sync on launch (non-blocking)
        Task {
            try? await Task.sleep(for: .seconds(12))
            let hasProvider = await FinancialIntelligenceService.shared.isAnyProviderConfigured()
            if hasProvider {
                await FinancialIntelligenceService.shared.syncAll()
            }
        }

        // AAH3: HeadphoneMotionService — start AirPods/Beats motion monitoring for readiness signals.
        // FoundationModelsService — check Apple Intelligence availability.
        // MusicKitIntelligenceService — fetch recent tracks.
        Task {
            try? await Task.sleep(for: .seconds(9))
            HeadphoneMotionService.shared.startMonitoring()
            await FoundationModelsService.shared.refreshAvailability()
            await MusicKitIntelligenceService.shared.fetchRecentTracks()
        }
    }
}
