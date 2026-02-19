import XCTest
import Foundation
import CoreGraphics
import AppKit

#if os(macOS)
@testable import Thea

/// Integration tests for G1: Live Screen Monitoring + Interactive Voice Guidance
///
/// NOTE: All G1 types (ScreenCaptureManager, PointerTracker, SystemActionExecutor,
/// LocalVisionGuidance, MLXVisionEngine) are excluded from the macOS build target
/// in project.yml. These tests are disabled until those exclusions are lifted.
@MainActor
final class G1IntegrationTests: XCTestCase {

    // All G1 component tests are currently disabled because the referenced types
    // (ScreenCaptureManager, PointerTracker, SystemActionExecutor, LocalVisionGuidance,
    // MLXVisionEngine) are excluded from the active macOS build target in project.yml.
    //
    // To re-enable: remove the exclusions from project.yml, run xcodegen generate,
    // and restore the test implementations.

    func testG1TypesExcludedFromBuildPlaceholder() {
        // This test exists only to keep the file compilable.
        // Real G1 tests are gated on build target inclusion of the G1 components.
        XCTAssertTrue(true, "G1 test file compiles successfully")
    }

}

#endif
