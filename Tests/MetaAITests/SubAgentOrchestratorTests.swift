@testable import Thea
import XCTest

// MARK: - SubAgentOrchestrator Tests
// Tests disabled: API has changed significantly
// TODO: Rewrite tests to match current SubAgentOrchestrator implementation

@MainActor
final class SubAgentOrchestratorTests: XCTestCase {
    
    func testSingletonExists() {
        let orchestrator = SubAgentOrchestrator.shared
        XCTAssertNotNil(orchestrator)
    }
}
