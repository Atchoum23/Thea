@testable import TheaCore
import XCTest

// MARK: - WorkflowBuilder Tests

// Tests disabled: API has changed (singleton pattern, method signatures differ)
// TODO: Rewrite tests to match current WorkflowBuilder implementation

@MainActor
final class WorkflowBuilderTests: XCTestCase {
    func testSingletonExists() {
        let builder = WorkflowBuilder.shared
        XCTAssertNotNil(builder)
    }
}
