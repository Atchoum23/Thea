// FinancialTests.swift
// Thea — ABA3: QA v2 — Wave 10 Financial services
//
// Tests: FinancialCredentialStore (Keychain round-trip) + WearableFusionEngine weighted math

import XCTest
import Foundation

#if os(macOS)
@testable import Thea

// MARK: - FinancialCredentialStore Tests

final class FinancialCredentialStoreTests: XCTestCase {

    private let testProvider = "thea.test.financial.aba3"

    override func tearDown() {
        super.tearDown()
        // Clean up any test credential
        FinancialCredentialStore.delete(for: testProvider)
    }

    func testSaveAndLoadToken() {
        let token = "test-api-key-\(UUID().uuidString)"
        let saved = FinancialCredentialStore.save(token: token, for: testProvider)
        XCTAssertTrue(saved, "save() should return true on success")

        let loaded = FinancialCredentialStore.load(for: testProvider)
        XCTAssertEqual(loaded, token, "load() should return the same token that was saved")
    }

    func testDeleteToken() {
        FinancialCredentialStore.save(token: "to-delete", for: testProvider)
        let deleted = FinancialCredentialStore.delete(for: testProvider)
        XCTAssertTrue(deleted, "delete() should return true")

        let loaded = FinancialCredentialStore.load(for: testProvider)
        XCTAssertNil(loaded, "load() after delete should return nil")
    }

    func testLoadNonExistentReturnsNil() {
        let result = FinancialCredentialStore.load(for: "thea.test.nonexistent.\(UUID().uuidString)")
        XCTAssertNil(result, "load() for missing key should return nil")
    }

    func testSaveOverwritesPrevious() {
        FinancialCredentialStore.save(token: "first-token", for: testProvider)
        FinancialCredentialStore.save(token: "second-token", for: testProvider)
        let loaded = FinancialCredentialStore.load(for: testProvider)
        XCTAssertEqual(loaded, "second-token", "Second save should overwrite first")
    }

    func testSuffixRoundTrip() {
        let provider = "thea.test.aba3"
        let suffix = "apiKey"
        let token = "key-\(UUID().uuidString)"
        FinancialCredentialStore.save(token: token, for: provider, suffix: suffix)
        let loaded = FinancialCredentialStore.load(for: provider, suffix: suffix)
        XCTAssertEqual(loaded, token, "Suffix-based round-trip should return exact token")
        FinancialCredentialStore.delete(for: provider, suffix: suffix)
    }
}

// MARK: - WearableFusionEngine Math Tests

@MainActor
final class WearableFusionMathTests: XCTestCase {

    // Weights: Oura 45%, Whoop 35%, Apple Watch 20%

    func testAllSourcesPresent() async {
        let engine = WearableFusionEngine.shared
        let oura = OuraReadiness(score: 80, hrv: 75, date: "2026-02-20")
        let whoop = WhoopRecovery(recovery_score: 60, hrv_rmssd_milli: 60.0)
        let appleWatch: Double = 0.70 // 70%

        engine.updateScore(oura: oura, whoop: whoop, appleWatch: appleWatch)

        // Expected: (80/100 * 0.45 + 60/100 * 0.35 + 0.70 * 0.20) / 1.0
        // = (0.36 + 0.21 + 0.14) / 1.0 = 0.71
        let expected = (0.80 * 0.45 + 0.60 * 0.35 + 0.70 * 0.20) / 1.0
        XCTAssertEqual(engine.fusedReadinessScore, expected, accuracy: 0.001,
                       "Fused score should match weighted average")
    }

    func testOuraOnlyNormalizesWeight() async {
        let engine = WearableFusionEngine.shared
        let oura = OuraReadiness(score: 90, hrv: 85, date: "2026-02-20")

        engine.updateScore(oura: oura, whoop: nil, appleWatch: 0)

        // Only Oura: totalWeight = 0.45, score = (90/100 * 0.45) / 0.45 = 0.90
        XCTAssertEqual(engine.fusedReadinessScore, 0.90, accuracy: 0.001,
                       "Oura-only score should normalize to Oura score")
    }

    func testNoSourcesReturnsDefault() async {
        let engine = WearableFusionEngine.shared
        engine.updateScore(oura: nil, whoop: nil, appleWatch: 0)
        XCTAssertEqual(engine.fusedReadinessScore, 0.5, accuracy: 0.001,
                       "No sources should return default 0.5")
    }

    func testWhoopAndAppleWatchOnly() async {
        let engine = WearableFusionEngine.shared
        let whoop = WhoopRecovery(recovery_score: 70, hrv_rmssd_milli: 70.0)
        let appleWatch: Double = 0.80

        engine.updateScore(oura: nil, whoop: whoop, appleWatch: appleWatch)

        // totalWeight = 0.35 + 0.20 = 0.55
        // score = (70/100 * 0.35 + 0.80 * 0.20) / 0.55
        let expected = (0.70 * 0.35 + 0.80 * 0.20) / 0.55
        XCTAssertEqual(engine.fusedReadinessScore, expected, accuracy: 0.001,
                       "Whoop+AppleWatch score should renormalize correctly")
    }
}
#endif
