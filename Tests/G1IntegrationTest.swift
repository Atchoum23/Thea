import XCTest
import Foundation
import CoreGraphics
import AppKit

#if os(macOS)
@testable import Thea

/// Integration tests for G1: Live Screen Monitoring + Interactive Voice Guidance
@MainActor
final class G1IntegrationTests: XCTestCase {

    // MARK: - Screen Capture Tests

    func testScreenCaptureManagerInitialization() async throws {
        let manager = ScreenCaptureManager()

        // Authorization status should be checkable
        await manager.checkAuthorization()

        // Should not crash when checking authorization
        XCTAssertNotNil(manager)
    }

    func testScreenCapturePermissionFlow() async throws {
        let manager = ScreenCaptureManager()

        // Initial state
        XCTAssertFalse(manager.isAuthorized, "Should start not authorized (unless already granted)")

        // Note: Actual authorization requires user interaction
        // Just verify the method doesn't crash
        do {
            try await manager.requestAuthorization()
        } catch ScreenCaptureError.notAuthorized {
            // Expected if permission not granted
            print("⚠️ Screen Recording permission not granted - expected in test environment")
        }
    }

    // MARK: - Pointer Tracker Tests

    func testPointerTrackerInitialization() {
        let tracker = PointerTracker()

        XCTAssertNotNil(tracker)
        XCTAssertFalse(tracker.isTracking, "Should start not tracking")
        XCTAssertEqual(tracker.currentPosition, .zero, "Should start at zero position")
    }

    func testPointerTrackerAuthorizationCheck() {
        let tracker = PointerTracker()

        // Should be able to check authorization without crashing
        let authorized = tracker.checkAuthorization()

        // May or may not be authorized depending on system state
        print("ℹ️ Accessibility authorized: \(authorized)")
    }

    // MARK: - Action Executor Tests

    func testActionExecutorInitialization() async {
        let executor = SystemActionExecutor()

        XCTAssertNotNil(executor)

        // Should be able to check authorization
        let authorized = executor.isAuthorized()
        print("ℹ️ Accessibility (for actions) authorized: \(authorized)")
    }

    // MARK: - Local Vision Guidance Tests

    func testLocalVisionGuidanceInitialization() {
        let guidance = LocalVisionGuidance.shared

        XCTAssertNotNil(guidance)
        XCTAssertFalse(guidance.isGuiding, "Should start not guiding")
        XCTAssertFalse(guidance.isVisionModelLoaded, "Vision model should not be loaded initially")
        XCTAssertEqual(guidance.currentInstruction, "", "Should have empty instruction initially")
    }

    // MARK: - MLX Vision Engine Tests
    // Note: LocalVisionGuidance, LiveGuidanceSettingsView, MLXVoiceBackend tests removed
    // — those types are excluded from the current macOS build target.

    func testMLXVisionEngineInitialization() {
        let engine = MLXVisionEngine.shared

        XCTAssertNotNil(engine)
        XCTAssertNil(engine.loadedModel, "No model should be loaded initially")
        XCTAssertNil(engine.loadedModelID, "No model ID initially")
        XCTAssertFalse(engine.isLoading, "Should not be loading initially")
    }

}

#endif
