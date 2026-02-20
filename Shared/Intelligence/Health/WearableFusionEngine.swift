// WearableFusionEngine.swift
// Thea — AAE3: Third-Party Health Wearables
//
// @MainActor weighted fusion of 3 readiness sources:
//   Oura Ring  45% | Whoop  35% | Apple Watch (HumanReadinessEngine)  20%
//
// Wiring: observes HumanReadinessEngine.$readinessScore as the Apple Watch
// component. Call refresh() to pull latest Oura + Whoop data.
// HumanReadinessEngine.computeMorningReadiness() returns the fused score
// when wearable data is available.

import Combine
import Foundation
import OSLog

// MARK: - WearableFusionEngine

@MainActor
final class WearableFusionEngine: ObservableObject {
    static let shared = WearableFusionEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "WearableFusionEngine")

    // MARK: - Published State

    @Published private(set) var fusedReadinessScore: Double = 0.5
    @Published private(set) var lastOura: OuraReadiness?
    @Published private(set) var lastWhoop: WhoopRecovery?
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastError: String?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        // Observe Apple Watch readiness from HumanReadinessEngine
        HumanReadinessEngine.shared.$readinessScore
            .sink { [weak self] appleWatchScore in
                guard let self else { return }
                self.updateScore(oura: self.lastOura, whoop: self.lastWhoop, appleWatch: appleWatchScore)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Pull latest Oura + Whoop data and recompute fused score.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        async let ouraResult = fetchOura()
        async let whoopResult = fetchWhoop()

        let (oura, whoop) = await (ouraResult, whoopResult)

        lastOura = oura
        lastWhoop = whoop
        lastRefreshed = .now

        let appleWatch = HumanReadinessEngine.shared.readinessScore
        updateScore(oura: oura, whoop: whoop, appleWatch: appleWatch)

        logger.info("WearableFusion refreshed — fused=\(self.fusedReadinessScore, format: .fixed(precision: 3)) oura=\(oura?.score ?? -1) whoop=\(whoop?.recovery_score ?? -1) apple=\(appleWatch, format: .fixed(precision: 2))")
    }

    // MARK: - Weighted Fusion

    /// Compute the weighted fusion score.
    /// Weights: Oura 45% | Whoop 35% | Apple Watch 20%.
    /// Missing sources are excluded and remaining weights renormalized.
    func updateScore(oura: OuraReadiness?, whoop: WhoopRecovery?, appleWatch: Double) {
        var score = 0.0
        var totalWeight = 0.0

        if let o = oura, o.score > 0 {
            score += Double(o.score) / 100.0 * 0.45
            totalWeight += 0.45
        }
        if let w = whoop, w.recovery_score > 0 {
            score += Double(w.recovery_score) / 100.0 * 0.35
            totalWeight += 0.35
        }
        if appleWatch > 0 {
            score += appleWatch * 0.20
            totalWeight += 0.20
        }

        fusedReadinessScore = totalWeight > 0 ? score / totalWeight : 0.5
    }

    // MARK: - Private Fetches

    private func fetchOura() async -> OuraReadiness? {
        do {
            return try await OuraService.shared.fetchReadiness()
        } catch OuraService.OuraError.missingToken {
            // Not configured — silently skip
            return nil
        } catch {
            logger.warning("Oura fetch failed: \(error.localizedDescription)")
            lastError = "Oura: \(error.localizedDescription)"
            return nil
        }
    }

    private func fetchWhoop() async -> WhoopRecovery? {
        do {
            return try await WhoopService.shared.fetchRecovery()
        } catch WhoopService.WhoopError.missingToken {
            // Not configured — silently skip
            return nil
        } catch {
            logger.warning("Whoop fetch failed: \(error.localizedDescription)")
            if lastError == nil {
                lastError = "Whoop: \(error.localizedDescription)"
            }
            return nil
        }
    }
}

// MARK: - HumanReadinessEngine Integration

extension HumanReadinessEngine {
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    /// Returns the tri-source fused readiness score when wearable data is available,
    /// falling back to the Apple Watch–only readinessScore.
    func computeMorningReadiness() -> Double {
        let fused = WearableFusionEngine.shared.fusedReadinessScore
        // Use fused only when it has been populated (lastRefreshed is set)
        if WearableFusionEngine.shared.lastRefreshed != nil {
            return fused
        }
        return readinessScore
    }
}
