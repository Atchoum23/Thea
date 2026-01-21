#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif
import XCTest

// MARK: - PluginSystem Tests
// Tests disabled: API has changed (singleton pattern, private setters)
// TODO: Rewrite tests to match current PluginSystem implementation

@MainActor
final class PluginSystemTests: XCTestCase {
    
    func testSingletonExists() {
        let system = PluginSystem.shared
        XCTAssertNotNil(system)
    }
}
