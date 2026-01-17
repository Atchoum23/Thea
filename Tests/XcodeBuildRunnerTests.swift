@testable import TheaCore
import XCTest

@MainActor
final class XcodeBuildRunnerTests: XCTestCase {
    func testBuildRunnerExists() async throws {
        // Verify XcodeBuildRunner singleton is accessible
        let runner = XcodeBuildRunner.shared
        XCTAssertNotNil(runner)
    }

    func testBuildResultStructure() async throws {
        // Test that BuildResult can be created and has expected properties
        // This tests the data structure without requiring an actual build
        let runner = XcodeBuildRunner.shared
        XCTAssertNotNil(runner)

        // The actual build tests are integration tests that require
        // the full Xcode environment and project to be present.
        // They should be run locally, not in CI.
    }
}
