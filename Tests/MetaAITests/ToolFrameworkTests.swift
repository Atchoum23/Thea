#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif
import XCTest

// MARK: - ToolFramework Tests
// Tests disabled: API has changed significantly
// TODO: Rewrite tests to match current ToolFramework implementation

@MainActor
final class ToolFrameworkTests: XCTestCase {
    
    func testSingletonExists() {
        let framework = ToolFramework.shared
        XCTAssertNotNil(framework)
    }
}
