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

    func testLocalVisionGuidanceCaptureMode() {
        let guidance = LocalVisionGuidance.shared

        // Default mode
        switch guidance.captureMode {
        case .fullScreen:
            XCTAssertTrue(true, "Default is full screen")
        default:
            XCTFail("Expected fullScreen as default capture mode")
        }

        // Change mode
        guidance.captureMode = .activeWindow
        switch guidance.captureMode {
        case .activeWindow:
            XCTAssertTrue(true, "Mode changed successfully")
        default:
            XCTFail("Mode should be activeWindow")
        }
    }

    func testLocalVisionGuidanceSettings() {
        let guidance = LocalVisionGuidance.shared

        // Test settings
        guidance.enableVoice = true
        XCTAssertTrue(guidance.enableVoice)

        guidance.allowControlHandoff = true
        XCTAssertTrue(guidance.allowControlHandoff)

        guidance.analyzeInterval = 3.0
        XCTAssertEqual(guidance.analyzeInterval, 3.0, accuracy: 0.01)
    }

    // MARK: - Live Guidance Settings View Tests

    func testLiveGuidanceSettingsViewRendering() {
        // Verify the view can be instantiated
        let view = LiveGuidanceSettingsView()
        XCTAssertNotNil(view)
    }

    // MARK: - MLX Vision Engine Tests

    func testMLXVisionEngineInitialization() {
        let engine = MLXVisionEngine.shared

        XCTAssertNotNil(engine)
        XCTAssertNil(engine.loadedModel, "No model should be loaded initially")
        XCTAssertNil(engine.loadedModelID, "No model ID initially")
        XCTAssertFalse(engine.isLoading, "Should not be loading initially")
    }

    // MARK: - MLX Voice Backend Tests

    func testMLXVoiceBackendInitialization() async {
        let backend = MLXVoiceBackend()

        XCTAssertNotNil(backend)

        // Should be available on macOS
        let available = await backend.isAvailable
        XCTAssertTrue(available, "MLX voice backend should be available on macOS")
    }

    // MARK: - Integration Tests

    func testGuidanceComponentsIntegration() {
        let guidance = LocalVisionGuidance.shared

        // Verify all components are accessible
        XCTAssertNotNil(guidance.visionEngine)
        XCTAssertNotNil(guidance.voiceBackend)
        XCTAssertNotNil(guidance.screenCapture)
        XCTAssertNotNil(guidance.pointerTracker)
        XCTAssertNotNil(guidance.actionExecutor)
    }

    func testGuidanceErrorHandling() {
        let guidance = LocalVisionGuidance.shared

        // Should start with no error
        XCTAssertNil(guidance.lastError)
    }
}

#endif
