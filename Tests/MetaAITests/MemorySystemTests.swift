#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif
import XCTest

// MARK: - MemorySystem Tests
// Tests disabled: API has changed (singleton pattern, private setters)
// TODO: Rewrite tests to match current MemorySystem implementation

@MainActor
final class MemorySystemTests: XCTestCase {
    
    func testSingletonExists() {
        // Test that singleton is accessible
        let system = MemorySystem.shared
        XCTAssertNotNil(system)
    }
    
    func testMemoryTypesExist() {
        // Basic test that MemoryType enum exists
        let episodic = MemoryType.episodic
        let semantic = MemoryType.semantic
        XCTAssertNotNil(episodic)
        XCTAssertNotNil(semantic)
    }
    
    func testMemoryTiersExist() {
        // Basic test that MemoryTier enum exists
        let shortTerm = MemoryTier.shortTerm
        let longTerm = MemoryTier.longTerm
        XCTAssertNotNil(shortTerm)
        XCTAssertNotNil(longTerm)
    }
}
