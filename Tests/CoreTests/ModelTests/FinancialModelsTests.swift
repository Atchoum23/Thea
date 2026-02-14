@testable import TheaModels
import XCTest

/// Tests for FinancialModels — accounts, transactions, enums, and supporting types.
final class FinancialModelsTests: XCTestCase {

    // MARK: - FinancialAccount

    func testAccountCreation() {
        let account = FinancialAccount(
            name: "Main Checking",
            type: .checking,
            institution: "Chase"
        )
        XCTAssertEqual(account.name, "Main Checking")
        XCTAssertEqual(account.type, .checking)
        XCTAssertEqual(account.institution, "Chase")
    }

    func testAccountDefaults() {
        let account = FinancialAccount(name: "Test", type: .savings, institution: "Test Bank")
        XCTAssertEqual(account.balance, 0.0, accuracy: 0.001)
        XCTAssertEqual(account.currency, "USD")
        XCTAssertTrue(account.isActive)
    }

    func testAccountCustomValues() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let account = FinancialAccount(
            name: "EUR Savings",
            type: .savings,
            institution: "BNP Paribas",
            balance: 15_000.50,
            currency: "EUR",
            createdAt: date,
            updatedAt: date,
            isActive: false
        )
        XCTAssertEqual(account.balance, 15_000.50, accuracy: 0.01)
        XCTAssertEqual(account.currency, "EUR")
        XCTAssertFalse(account.isActive)
        XCTAssertEqual(account.createdAt, date)
    }

    func testAllAccountTypes() {
        let types: [AccountType] = [.checking, .savings, .credit, .investment, .crypto]
        for type in types {
            let account = FinancialAccount(name: "T", type: type, institution: "T")
            XCTAssertEqual(account.type, type)
        }
        XCTAssertEqual(types.count, 5, "Should cover all account types")
    }

    func testAccountTypeRawValues() {
        XCTAssertEqual(AccountType.checking.rawValue, "checking")
        XCTAssertEqual(AccountType.savings.rawValue, "savings")
        XCTAssertEqual(AccountType.credit.rawValue, "credit")
        XCTAssertEqual(AccountType.investment.rawValue, "investment")
        XCTAssertEqual(AccountType.crypto.rawValue, "crypto")
    }

    func testAccountTypeCodable() throws {
        let original = AccountType.investment
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AccountType.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAccountUniqueIDs() {
        let a1 = FinancialAccount(name: "A", type: .checking, institution: "B")
        let a2 = FinancialAccount(name: "A", type: .checking, institution: "B")
        XCTAssertNotEqual(a1.id, a2.id)
    }

    func testAccountCustomID() {
        let id = UUID()
        let account = FinancialAccount(id: id, name: "Test", type: .savings, institution: "X")
        XCTAssertEqual(account.id, id)
    }

    // MARK: - FinancialTransaction

    func testTransactionCreation() {
        let accountID = UUID()
        let tx = FinancialTransaction(
            accountId: accountID,
            amount: -42.50,
            transactionDescription: "Coffee shop"
        )
        XCTAssertEqual(tx.accountId, accountID)
        XCTAssertEqual(tx.amount, -42.50, accuracy: 0.01)
        XCTAssertEqual(tx.transactionDescription, "Coffee shop")
    }

    func testTransactionDefaults() {
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: 100,
            transactionDescription: "Test"
        )
        XCTAssertNil(tx.category)
        XCTAssertNil(tx.merchant)
        XCTAssertFalse(tx.isRecurring)
        XCTAssertTrue(tx.tags.isEmpty)
    }

    func testTransactionCustomValues() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: -1200.00,
            transactionDescription: "Monthly Rent",
            category: "housing",
            merchant: "Landlord",
            date: date,
            isRecurring: true,
            tags: ["essential", "monthly"]
        )
        XCTAssertEqual(tx.category, "housing")
        XCTAssertEqual(tx.merchant, "Landlord")
        XCTAssertTrue(tx.isRecurring)
        XCTAssertEqual(tx.tags, ["essential", "monthly"])
        XCTAssertEqual(tx.date, date)
    }

    func testTransactionNegativeAndPositiveAmounts() {
        let expense = FinancialTransaction(accountId: UUID(), amount: -500, transactionDescription: "Expense")
        let income = FinancialTransaction(accountId: UUID(), amount: 3000, transactionDescription: "Salary")
        XCTAssertLessThan(expense.amount, 0)
        XCTAssertGreaterThan(income.amount, 0)
    }

    func testTransactionUniqueIDs() {
        let tx1 = FinancialTransaction(accountId: UUID(), amount: 10, transactionDescription: "A")
        let tx2 = FinancialTransaction(accountId: UUID(), amount: 10, transactionDescription: "A")
        XCTAssertNotEqual(tx1.id, tx2.id)
    }

    // MARK: - TimePeriod

    func testTimePeriodRawValues() {
        XCTAssertEqual(TimePeriod.week.rawValue, "week")
        XCTAssertEqual(TimePeriod.month.rawValue, "month")
        XCTAssertEqual(TimePeriod.quarter.rawValue, "quarter")
        XCTAssertEqual(TimePeriod.year.rawValue, "year")
    }

    func testTimePeriodCodable() throws {
        for period in [TimePeriod.week, .month, .quarter, .year] {
            let data = try JSONEncoder().encode(period)
            let decoded = try JSONDecoder().decode(TimePeriod.self, from: data)
            XCTAssertEqual(decoded, period)
        }
    }

    // MARK: - AnomalySeverity

    func testAnomalySeverityRawValues() {
        XCTAssertEqual(AnomalySeverity.low.rawValue, "low")
        XCTAssertEqual(AnomalySeverity.medium.rawValue, "medium")
        XCTAssertEqual(AnomalySeverity.high.rawValue, "high")
    }

    func testAnomalySeverityCodable() throws {
        for severity in [AnomalySeverity.low, .medium, .high] {
            let data = try JSONEncoder().encode(severity)
            let decoded = try JSONDecoder().decode(AnomalySeverity.self, from: data)
            XCTAssertEqual(decoded, severity)
        }
    }

    // MARK: - MonthlyData

    func testMonthlyDataCreation() {
        let data = MonthlyData(month: "January", income: 5000.0, expenses: 3200.0)
        XCTAssertEqual(data.month, "January")
        XCTAssertEqual(data.income, 5000.0)
        XCTAssertEqual(data.expenses, 3200.0)
    }

    func testMonthlyDataUniqueIDs() {
        let d1 = MonthlyData(month: "Jan", income: 0, expenses: 0)
        let d2 = MonthlyData(month: "Jan", income: 0, expenses: 0)
        XCTAssertNotEqual(d1.id, d2.id)
    }

    // MARK: - BudgetRecommendation

    func testBudgetRecommendationCreation() {
        let rec = BudgetRecommendation(
            category: "Dining",
            reason: "Spending 40% above average",
            currentSpending: 800.0,
            recommendedBudget: 500.0
        )
        XCTAssertEqual(rec.category, "Dining")
        XCTAssertEqual(rec.reason, "Spending 40% above average")
        XCTAssertEqual(rec.currentSpending, 800.0)
        XCTAssertEqual(rec.recommendedBudget, 500.0)
    }

    // MARK: - TransactionAnomaly

    func testTransactionAnomalyCreation() {
        let tx = FinancialTransaction(
            accountId: UUID(),
            amount: -9999.99,
            transactionDescription: "Unusual purchase"
        )
        let anomaly = TransactionAnomaly(
            transaction: tx,
            reason: "Amount exceeds 3 standard deviations",
            severity: .high
        )
        XCTAssertEqual(anomaly.severity, .high)
        XCTAssertEqual(anomaly.reason, "Amount exceeds 3 standard deviations")
        XCTAssertEqual(anomaly.transaction.amount, -9999.99, accuracy: 0.01)
    }

    func testTransactionAnomalySeverityLevels() {
        let tx = FinancialTransaction(accountId: UUID(), amount: 0, transactionDescription: "T")
        for severity in [AnomalySeverity.low, .medium, .high] {
            let anomaly = TransactionAnomaly(transaction: tx, reason: "R", severity: severity)
            XCTAssertEqual(anomaly.severity, severity)
        }
    }

    // MARK: - Cross-Model

    func testAccountAndTransactionLink() {
        let account = FinancialAccount(name: "Main", type: .checking, institution: "Bank")
        let tx = FinancialTransaction(
            accountId: account.id,
            amount: -50,
            transactionDescription: "Groceries"
        )
        XCTAssertEqual(tx.accountId, account.id, "Transaction should link to account")
    }
}
