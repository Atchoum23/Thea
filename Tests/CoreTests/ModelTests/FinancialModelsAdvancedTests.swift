@preconcurrency import SwiftData
@testable import TheaModels
import XCTest

/// Advanced tests for FinancialModels: accounts, transactions, budget
/// recommendations, anomalies, and supporting enums.
@MainActor
final class FinancialModelsAdvancedTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let schema = Schema([FinancialAccount.self, FinancialTransaction.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - AccountType

    func testAllAccountTypes() {
        let types: [AccountType] = [.checking, .savings, .credit, .investment, .crypto]
        XCTAssertEqual(types.count, 5)
    }

    func testAccountTypeCodable() throws {
        for accountType in [AccountType.checking, .savings, .credit, .investment, .crypto] {
            let data = try JSONEncoder().encode(accountType)
            let decoded = try JSONDecoder().decode(AccountType.self, from: data)
            XCTAssertEqual(decoded, accountType)
        }
    }

    func testAccountTypeRawValues() {
        XCTAssertEqual(AccountType.checking.rawValue, "checking")
        XCTAssertEqual(AccountType.savings.rawValue, "savings")
        XCTAssertEqual(AccountType.credit.rawValue, "credit")
        XCTAssertEqual(AccountType.investment.rawValue, "investment")
        XCTAssertEqual(AccountType.crypto.rawValue, "crypto")
    }

    // MARK: - FinancialAccount

    func testAccountDefaults() {
        let account = FinancialAccount(
            name: "Main Checking",
            type: .checking,
            institution: "UBS"
        )
        XCTAssertEqual(account.name, "Main Checking")
        XCTAssertEqual(account.type, .checking)
        XCTAssertEqual(account.institution, "UBS")
        XCTAssertEqual(account.balance, 0)
        XCTAssertEqual(account.currency, "USD")
        XCTAssertTrue(account.isActive)
    }

    func testAccountCustomValues() {
        let account = FinancialAccount(
            name: "Savings",
            type: .savings,
            institution: "PostFinance",
            balance: 15_000.50,
            currency: "CHF",
            isActive: true
        )
        XCTAssertEqual(account.balance, 15_000.50)
        XCTAssertEqual(account.currency, "CHF")
    }

    func testAccountNegativeBalance() {
        let account = FinancialAccount(
            name: "Credit Card",
            type: .credit,
            institution: "Visa",
            balance: -2500.75
        )
        XCTAssertLessThan(account.balance, 0)
    }

    func testAccountDeactivation() {
        let account = FinancialAccount(
            name: "Old Account",
            type: .savings,
            institution: "Bank",
            isActive: false
        )
        XCTAssertFalse(account.isActive)
    }

    func testAccountPersists() throws {
        let account = FinancialAccount(
            name: "Persist Test",
            type: .investment,
            institution: "Vanguard",
            balance: 50_000
        )
        modelContext.insert(account)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<FinancialAccount>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Persist Test")
        XCTAssertEqual(fetched[0].balance, 50_000)
    }

    // MARK: - FinancialTransaction

    func testTransactionDefaults() {
        let accountID = UUID()
        let tx = FinancialTransaction(
            accountId: accountID,
            amount: 42.50,
            transactionDescription: "Coffee"
        )
        XCTAssertEqual(tx.accountId, accountID)
        XCTAssertEqual(tx.amount, 42.50)
        XCTAssertEqual(tx.transactionDescription, "Coffee")
        XCTAssertNil(tx.category)
        XCTAssertNil(tx.merchant)
        XCTAssertFalse(tx.isRecurring)
        XCTAssertTrue(tx.tags.isEmpty)
    }

    func testTransactionFullValues() {
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: -150.00,
            transactionDescription: "Monthly Gym",
            category: "Health",
            merchant: "Fitness First",
            isRecurring: true,
            tags: ["fitness", "health", "monthly"]
        )
        XCTAssertEqual(tx.amount, -150.00)
        XCTAssertEqual(tx.category, "Health")
        XCTAssertEqual(tx.merchant, "Fitness First")
        XCTAssertTrue(tx.isRecurring)
        XCTAssertEqual(tx.tags.count, 3)
    }

    func testTransactionNegativeAmount() {
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: -999.99,
            transactionDescription: "Payment"
        )
        XCTAssertLessThan(tx.amount, 0)
    }

    func testTransactionZeroAmount() {
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: 0,
            transactionDescription: "Adjustment"
        )
        XCTAssertEqual(tx.amount, 0)
    }

    func testTransactionPersists() throws {
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: 250.00,
            transactionDescription: "Salary",
            category: "Income",
            tags: ["salary"]
        )
        modelContext.insert(tx)
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<FinancialTransaction>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].transactionDescription, "Salary")
    }

    // MARK: - TimePeriod

    func testTimePeriodCases() {
        let cases: [TimePeriod] = [.week, .month, .quarter, .year]
        XCTAssertEqual(cases.count, 4)
    }

    func testTimePeriodCodable() throws {
        for period in [TimePeriod.week, .month, .quarter, .year] {
            let data = try JSONEncoder().encode(period)
            let decoded = try JSONDecoder().decode(TimePeriod.self, from: data)
            XCTAssertEqual(decoded, period)
        }
    }

    // MARK: - MonthlyData

    func testMonthlyDataCreation() {
        let data = MonthlyData(
            month: "January",
            income: Decimal(string: "5000.00")!,
            expenses: Decimal(string: "3500.00")!
        )
        XCTAssertEqual(data.month, "January")
        XCTAssertEqual(data.income, Decimal(string: "5000.00"))
        XCTAssertEqual(data.expenses, Decimal(string: "3500.00"))
    }

    func testMonthlyDataIdentifiable() {
        let d1 = MonthlyData(month: "Jan", income: 100, expenses: 50)
        let d2 = MonthlyData(month: "Jan", income: 100, expenses: 50)
        XCTAssertNotEqual(d1.id, d2.id, "Each instance should have unique ID")
    }

    func testMonthlyDataProfitCalculation() {
        let data = MonthlyData(
            month: "Feb",
            income: Decimal(string: "8000")!,
            expenses: Decimal(string: "6000")!
        )
        let profit = data.income - data.expenses
        XCTAssertEqual(profit, Decimal(string: "2000"))
    }

    // MARK: - BudgetRecommendation

    func testBudgetRecommendationCreation() {
        let rec = BudgetRecommendation(
            category: "Dining",
            reason: "Spending exceeds average",
            currentSpending: Decimal(string: "800")!,
            recommendedBudget: Decimal(string: "500")!
        )
        XCTAssertEqual(rec.category, "Dining")
        XCTAssertEqual(rec.reason, "Spending exceeds average")
        XCTAssertGreaterThan(rec.currentSpending, rec.recommendedBudget)
    }

    func testBudgetRecommendationIdentifiable() {
        let r1 = BudgetRecommendation(
            category: "A", reason: "R",
            currentSpending: 0, recommendedBudget: 0
        )
        let r2 = BudgetRecommendation(
            category: "A", reason: "R",
            currentSpending: 0, recommendedBudget: 0
        )
        XCTAssertNotEqual(r1.id, r2.id)
    }

    // MARK: - AnomalySeverity

    func testAnomalySeverityCases() {
        let cases: [AnomalySeverity] = [.low, .medium, .high]
        XCTAssertEqual(cases.count, 3)
    }

    func testAnomalySeverityCodable() throws {
        for severity in [AnomalySeverity.low, .medium, .high] {
            let data = try JSONEncoder().encode(severity)
            let decoded = try JSONDecoder().decode(AnomalySeverity.self, from: data)
            XCTAssertEqual(decoded, severity)
        }
    }

    // MARK: - TransactionAnomaly

    func testTransactionAnomalyCreation() {
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: -5000.00,
            transactionDescription: "Large withdrawal"
        )
        let anomaly = TransactionAnomaly(
            transaction: tx,
            reason: "Amount exceeds 3x average",
            severity: .high
        )
        XCTAssertEqual(anomaly.reason, "Amount exceeds 3x average")
        XCTAssertEqual(anomaly.severity, .high)
        XCTAssertEqual(anomaly.transaction.amount, -5000.00)
    }

    // MARK: - Multi-Account Scenarios

    func testMultipleAccountTypes() throws {
        let accounts = [
            FinancialAccount(name: "Checking", type: .checking, institution: "Bank A"),
            FinancialAccount(name: "Savings", type: .savings, institution: "Bank A"),
            FinancialAccount(name: "Crypto", type: .crypto, institution: "Coinbase"),
            FinancialAccount(name: "Investment", type: .investment, institution: "Vanguard")
        ]
        for account in accounts {
            modelContext.insert(account)
        }
        try modelContext.save()

        let fetched = try modelContext.fetch(FetchDescriptor<FinancialAccount>())
        XCTAssertEqual(fetched.count, 4)

        let types = Set(fetched.map(\.type))
        XCTAssertTrue(types.contains(.checking))
        XCTAssertTrue(types.contains(.savings))
        XCTAssertTrue(types.contains(.crypto))
        XCTAssertTrue(types.contains(.investment))
    }
}
