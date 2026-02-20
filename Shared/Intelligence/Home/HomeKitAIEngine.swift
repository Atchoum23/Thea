//
//  HomeKitAIEngine.swift
//  Thea
//
//  AAF3-1: HomeKit AI Engine — predictive scene activation + home state intelligence.
//  Wired into TheamacOSApp.setupManagers() at 8s delay.
//
//  HomeKit is available on iOS, watchOS, tvOS only.
//  macOS 26+ removed HomeKit from the SDK — a no-op stub is provided for macOS.
//

import Foundation
import os.log

// MARK: - Supporting Types

enum HomeState {
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    case unknown, morning, day, evening, sleeping
}

// MARK: - Platform Implementation

// HomeKit is available on iOS/watchOS/tvOS. macOS 26+ removed HomeKit from SDK.
// Use OS conditional (not canImport) to avoid "module not found" in explicit-module-build mode.
#if os(iOS) || os(watchOS) || os(tvOS)
import HomeKit

@MainActor
final class HomeKitAIEngine: NSObject, ObservableObject {
    static let shared = HomeKitAIEngine()

    // MARK: - Published State

    @Published var homes: [HMHome] = []
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    @Published var currentHomeState: HomeState = .unknown
    @Published var lastActivatedScene: String?

    // MARK: - Private

    private let homeManager = HMHomeManager()
    private let logger = Logger(subsystem: "app.theathe", category: "HomeKitAIEngine")
    private var predictiveCheckTask: Task<Void, Never>?

    // MARK: - Lifecycle

    override init() {
        super.init()
        homeManager.delegate = self
        logger.info("HomeKitAIEngine initialized")
    }

    // MARK: - Scene Execution

    /// Executes a named action set (scene) across all homes.
    func executeScene(named name: String) async {
        for home in homes {
            if let scene = home.actionSets.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                do {
                    try await home.executeActionSet(scene)
                    lastActivatedScene = name
                    logger.info("Executed scene '\(name)' in home '\(home.name)'")
                    return
                } catch {
                    logger.error("Failed to execute scene '\(name)': \(error.localizedDescription)")
                }
            }
        }
        logger.warning("Scene '\(name)' not found in any home")
    }

    // MARK: - Predictive Activation

    /// Checks current hour and activates predictive scenes (Sleep at 22:00, Morning at 07:00).
    func checkPredictiveActivation() async {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22:
            logger.info("Predictive: triggering Sleep scene at hour \(hour)")
            await executeScene(named: "Sleep")
            currentHomeState = .sleeping
        case 7:
            logger.info("Predictive: triggering Morning scene at hour \(hour)")
            await executeScene(named: "Morning")
            currentHomeState = .morning
        default:
            break
        }
    }

    // MARK: - Periodic Check Loop

    func startPredictiveLoop() {
        predictiveCheckTask?.cancel()
        predictiveCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkPredictiveActivation()
                // Check every 30 minutes
                try? await Task.sleep(for: .seconds(1800))
            }
        }
        logger.info("HomeKitAIEngine predictive loop started")
    }

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    func stopPredictiveLoop() {
        predictiveCheckTask?.cancel()
        predictiveCheckTask = nil
    }

    // MARK: - Home State Query

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    /// Returns a summary of current home state for AI context injection.
    func homeContextSummary() -> String {
        guard !homes.isEmpty else { return "HomeKit not authorized or no homes configured." }
        let homeNames = homes.map(\.name).joined(separator: ", ")
        let sceneNames = homes.flatMap { $0.actionSets.map(\.name) }.joined(separator: ", ")
        let last = lastActivatedScene.map { "Last scene: \($0)." } ?? ""
        return "Homes: \(homeNames). Available scenes: \(sceneNames). \(last)"
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeKitAIEngine: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.homes = manager.homes
            self.logger.info("HomeKit homes updated: \(manager.homes.count) home(s)")
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor in
            self.homes = manager.homes
            self.logger.info("HomeKit home added: \(home.name)")
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor in
            self.homes = manager.homes
            self.logger.info("HomeKit home removed: \(home.name)")
        }
    }
}

#else

// MARK: - macOS Stub (HomeKit not available in macOS 26 SDK)

@MainActor
final class HomeKitAIEngine: ObservableObject {
    static let shared = HomeKitAIEngine()

    @Published var currentHomeState: HomeState = .unknown
    @Published var lastActivatedScene: String?

    private let logger = Logger(subsystem: "app.theathe", category: "HomeKitAIEngine")

    private init() {
        logger.info("HomeKitAIEngine stub initialized (HomeKit unavailable on this platform)")
    }

    func executeScene(named name: String) async {
        logger.info("HomeKitAIEngine stub: executeScene '\(name)' — HomeKit not available")
    }

    func checkPredictiveActivation() async {}

    func startPredictiveLoop() {
        logger.info("HomeKitAIEngine stub: predictive loop not started (HomeKit unavailable)")
    }

    func stopPredictiveLoop() {}

    func homeContextSummary() -> String {
        "HomeKit not available on this platform."
    }
}

#endif
