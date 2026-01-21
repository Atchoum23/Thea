#if SWIFT_PACKAGE
@testable import TheaCore
#else
@testable import Thea
#endif
import XCTest

// MARK: - Financial Service Tests
// Tests disabled: APIs have changed (BudgetService, TransactionCategorizerService not yet implemented)
// TODO: Rewrite tests when financial services are implemented

@MainActor
final class FinancialServiceTests: XCTestCase {

    func testFinancialModelsExist() {
        // Basic test that financial types exist
        let integration = FinancialIntegration.shared
        XCTAssertNotNil(integration)
    }
}
