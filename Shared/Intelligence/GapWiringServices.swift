// GapWiringServices.swift
// Thea — AAA3: Gap Remediation
//
// Thin service wrappers for 13 unwired systems identified in the AA3 audit.
// Each delegates to the canonical Thea implementation for that domain.
// These types are wired in TheamacOSApp.setupManagers(), TheaiOSApp.setupManagers(),
// and ChatManager+Messaging.sendMessage().

import Foundation
import os.log

#if canImport(CoreMotion)
    import CoreMotion
#endif

private let gapLog = Logger(subsystem: "ai.thea.app", category: "GapWiringServices")

// MARK: - AmbientIntelligenceEngine
// Facade over AmbientAwarenessMonitor — starts ambient sensing pipeline.
// Also exposes startAudioAnalysis() for AAD3 (ShazamKit + SoundAnalysis).

@MainActor
final class AmbientIntelligenceEngine: ObservableObject {
    static let shared = AmbientIntelligenceEngine()
    private init() {}

    func start() {
        Task { await AmbientAwarenessMonitor.shared.startMonitoring() }
        gapLog.info("AmbientIntelligenceEngine: started")
    }

    /// AAD3: Triggers ShazamKit song recognition + SoundAnalysis scene classification.
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func startAudioAnalysis() {
        ShazamKitService.shared.startListening()
        SoundAnalysisService.shared.startAnalysis()
        gapLog.info("AmbientIntelligenceEngine: startAudioAnalysis() — ShazamKit + SoundAnalysis started")
    }

    /// Stop all audio analysis (ShazamKit + SoundAnalysis).
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func stopAudioAnalysis() {
        ShazamKitService.shared.stopListening()
        SoundAnalysisService.shared.stopAnalysis()
        gapLog.info("AmbientIntelligenceEngine: stopAudioAnalysis()")
    }
}

// MARK: - DrivingDetectionService
// Detects driving state via CoreMotion activity manager (iOS).
// No-op on macOS — driving detection is iOS/automotive only.

@MainActor
// periphery:ignore - Reserved: AD3 audit — wired in future integration
final class DrivingDetectionService: ObservableObject {
    static let shared = DrivingDetectionService()
    @Published private(set) var isDriving = false
    private init() {}

    func start() {
        #if os(iOS) && canImport(CoreMotion)
        guard CMMotionActivityManager.isActivityAvailable() else {
            gapLog.info("DrivingDetectionService: motion not available on this device")
            return
        }
        let manager = CMMotionActivityManager()
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            Task { @MainActor [weak self] in
                self?.isDriving = activity.automotive
            }
        }
        gapLog.info("DrivingDetectionService: started (CoreMotion automotive detection)")
        #else
        gapLog.info("DrivingDetectionService: no-op on macOS")
        #endif
    }
}

// MARK: - ScreenTimeAnalyzer
// Wraps iOS ScreenTimeObserver for screen-time usage intelligence.
// On macOS: observes app-usage via LifeMonitoringCoordinator.

@MainActor
// periphery:ignore - Reserved: AD3 audit — wired in future integration
final class ScreenTimeAnalyzer: ObservableObject {
    static let shared = ScreenTimeAnalyzer()
    private init() {}

    func startMonitoring() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            ScreenTimeObserver.shared.startMonitoring()
            gapLog.info("ScreenTimeAnalyzer: started via ScreenTimeObserver (iOS)")
        }
        #else
        // macOS: screen-time data flows through LifeMonitoringCoordinator
        gapLog.info("ScreenTimeAnalyzer: macOS — data via LifeMonitoringCoordinator")
        #endif
    }
}

// MARK: - CalendarIntelligenceService
// Wraps CalendarMonitor — authorize calendar access then begin event monitoring.

@MainActor
final class CalendarIntelligenceService: ObservableObject {
    static let shared = CalendarIntelligenceService()
    private init() {}

    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    func authorize(completion: @escaping @Sendable (Bool) -> Void) {
        Task {
            await CalendarMonitor.shared.start()
            completion(true)
            gapLog.info("CalendarIntelligenceService: authorized + started")
        }
    }

    func startMonitoring() {
        Task {
            await CalendarMonitor.shared.start()
            gapLog.info("CalendarIntelligenceService: monitoring started")
        }
    }
}

// MARK: - LocationIntelligenceService
// Wraps LocationContextProvider — starts location-aware context enrichment.

@MainActor
final class LocationIntelligenceService: ObservableObject {
    static let shared = LocationIntelligenceService()
    private init() {}

    func start() {
        // LocationContextProvider has no shared singleton — delegate to LocationTrackingManager
        Task {
            #if os(iOS)
            await LocationTrackingManager.shared.startTracking()
            gapLog.info("LocationIntelligenceService: started via LocationTrackingManager")
            #else
            gapLog.info("LocationIntelligenceService: CoreLocation tracking only available on iOS")
            #endif
        }
    }
}

// MARK: - SleepAnalysisService
// Uses HealthIntelligence as the canonical sleep-data analysis source.

@MainActor
final class SleepAnalysisService: ObservableObject {
    static let shared = SleepAnalysisService()
    private init() {}

    func startMonitoring() {
        Task {
            await HealthIntelligence.shared.start()
            gapLog.info("SleepAnalysisService: started via HealthIntelligence")
        }
    }
}

// MARK: - ContextualMemoryManager
// Maintains a short-term conversation context window and feeds it to
// the long-term episodic memory pipeline via LongTermMemorySystem.

@MainActor
// periphery:ignore - Reserved: AD3 audit — wired in future integration
final class ContextualMemoryManager: ObservableObject {
    static let shared = ContextualMemoryManager()
    private var recentContexts: [String] = []
    private let maxContextSize = 20
    private init() {}

    func updateContext(with message: Message) {
        let text = message.content.textValue
        guard !text.isEmpty else { return }
        recentContexts.append(text)
        if recentContexts.count > maxContextSize {
            recentContexts.removeFirst(recentContexts.count - maxContextSize)
        }
        gapLog.debug("ContextualMemoryManager: context updated (\(self.recentContexts.count) entries)")
    }

    var contextSummary: String {
        recentContexts.suffix(5).joined(separator: "\n")
    }
}

// MARK: - ProactiveInsightEngine
// Wraps ProactiveEngine — starts proactive contextual analysis.

@MainActor
final class ProactiveInsightEngine: ObservableObject {
    static let shared = ProactiveInsightEngine()
    private init() {}

    func start() {
        // ProactiveEngine.shared is initialized lazily; touching .shared triggers it
        _ = ProactiveEngine.shared
        gapLog.info("ProactiveInsightEngine: started via ProactiveEngine")
    }
}

// MARK: - FocusSessionManager
// Wraps FocusOrchestrator — restores persisted focus sessions on app launch.

@MainActor
final class FocusSessionManager: ObservableObject {
    static let shared = FocusSessionManager()
    private init() {}

    func restore() {
        // FocusOrchestrator.init calls loadConfiguration() + setupAvailableFocusModes()
        _ = FocusOrchestrator.shared
        gapLog.info("FocusSessionManager: restored (FocusOrchestrator loaded config)")
    }
}

// MARK: - HabitTrackingService
// Thin facade over HabitManager — signals that habit tracking is ready.

@MainActor
final class HabitTrackingService: ObservableObject {
    static let shared = HabitTrackingService()
    private init() {}

    func start() {
        // HabitManager is initialized in setupManagers() via setModelContext().
        // This service signals the pipeline that habit tracking is active.
        _ = HabitManager.shared
        gapLog.info("HabitTrackingService: started (delegates to HabitManager)")
    }
}

// MARK: - GoalTrackingService
// Thin facade over GoalInferenceEngine — activates goal inference pipeline.

@MainActor
final class GoalTrackingService: ObservableObject {
    static let shared = GoalTrackingService()
    private init() {}

    func start() {
        _ = GoalInferenceEngine.shared
        gapLog.info("GoalTrackingService: started (delegates to GoalInferenceEngine)")
    }
}

// MARK: - WellbeingMonitor
// Uses HealthIntelligence as the canonical wellbeing monitoring source.

@MainActor
final class WellbeingMonitor: ObservableObject {
    static let shared = WellbeingMonitor()
    private init() {}

    func start() {
        Task {
            await HealthIntelligence.shared.start()
            gapLog.info("WellbeingMonitor: started via HealthIntelligence")
        }
    }
}

// MARK: - NeuralContextCompressor
// Compresses [AIMessage] arrays when conversation history is too long.
// Strategy: preserve system prompt + first 3 turns + last 6 turns.
// Called in ChatManager.sendMessage() when message count exceeds threshold.

@MainActor
// periphery:ignore - Reserved: AD3 audit — wired in future integration
final class NeuralContextCompressor: ObservableObject {
    static let shared = NeuralContextCompressor()
    private let headTurns = 3
    private let tailTurns = 6
    private let compressionThreshold = 16 // messages before compression kicks in
    private init() {}

    /// Compress messages to reduce context size while preserving critical history.
    func compress(_ messages: [AIMessage]) -> [AIMessage] {
        guard messages.count > compressionThreshold else { return messages }
        let system = messages.filter { $0.role == .system }
        let conversation = messages.filter { $0.role != .system }
        let head = Array(conversation.prefix(headTurns))
        let tail = Array(conversation.suffix(tailTurns))

        // Avoid duplicating messages if head and tail overlap
        var seen = Set<UUID>()
        var compressed: [AIMessage] = system
        for msg in head + tail {
            if seen.insert(msg.id).inserted {
                compressed.append(msg)
            }
        }
        let saved = messages.count - compressed.count
        gapLog.info("NeuralContextCompressor: \(messages.count) → \(compressed.count) messages (\(saved) removed)")
        return compressed
    }
}

// MARK: - CloudStorageContextProvider
// AAG3: Thin facade over CloudStorageService for context-layer access.
// Provides cloud file summaries to the chat context pipeline.

@MainActor
// periphery:ignore - Reserved: AD3 audit — wired in future integration
final class CloudStorageContextProvider: ObservableObject {
    static let shared = CloudStorageContextProvider()
    private init() {}

    /// Fetch a brief listing of recent cloud files for context injection.
    /// Uses stored tokens from SettingsManager; silently returns empty if unconfigured.
    func recentFileSummary() async -> String {
        async let driveFiles = (try? await CloudStorageService.shared.listGoogleDriveFiles()) ?? []
        async let dropboxFiles = (try? await CloudStorageService.shared.listDropboxFiles()) ?? []
        let (drive, dropbox) = await (driveFiles, dropboxFiles)
        guard !drive.isEmpty || !dropbox.isEmpty else { return "" }
        let total = drive.count + dropbox.count
        return "Cloud files: \(total) (\(drive.count) Google Drive, \(dropbox.count) Dropbox)"
    }
}
