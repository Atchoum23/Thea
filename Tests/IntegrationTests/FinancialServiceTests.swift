@testable import TheaCore
import XCTest

// MARK: - Financial Service Tests

@MainActor
final class FinancialServiceTests: XCTestCase {
    func testFinancialIntegrationSingleton() {
        let integration = FinancialIntegration.shared
        XCTAssertNotNil(integration)
        // Verify initial state
        XCTAssertTrue(integration.connectedAccounts.isEmpty)
        XCTAssertTrue(integration.transactions.isEmpty)
    }

    func testFinancialManagerSingleton() {
        let manager = FinancialManager.shared
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager.accounts.isEmpty)
        XCTAssertTrue(manager.transactions.isEmpty)
        XCTAssertFalse(manager.isSyncing)
    }

    func testFinancialModuleFeatureFlag() {
        let flags = FeatureFlags.shared
        // financialEnabled defaults to true
        XCTAssertTrue(flags.financialEnabled)
    }
}
