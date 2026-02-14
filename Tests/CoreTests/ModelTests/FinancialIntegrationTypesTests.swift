// FinancialIntegrationTypesTests.swift
// Tests for FinancialIntegration types: accounts, transactions, budgets, categories, alerts

import Testing
import Foundation

// MARK: - Test Doubles: TransactionCategory

private enum TestTransactionCategory: String, Codable, Sendable, CaseIterable {
    case groceries, dining, transportation, entertainment, housing
    case utilities, healthcare, shopping, travel, income, other
}

// MARK: - Test Doubles: BudgetPeriod

private enum TestBudgetPeriod: String, Codable, Sendable, CaseIterable {
    case daily, weekly, monthly, yearly

    var dayCount: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .monthly: return 30
        case .yearly: return 365
        }
    }
}

// MARK: - Test Doubles: AccountType

private enum TestAccountType: String, Codable, Sendable, CaseIterable {
    case checking, savings, credit, crypto, investment
}

// MARK: - Test Doubles: AlertType

private enum TestAlertType: Sendable {
    case budgetExceeded, unusualSpending, lowBalance, recurringPayment
}

// MARK: - Test Doubles: AlertSeverity

private enum TestAlertSeverity: Sendable, CaseIterable {
    case info, warning, critical

    var rank: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
}

// MARK: - Test Doubles: InsightType

private enum TestInsightType: Sendable, CaseIterable {
    case spendingTrend, categoryAnalysis, unusualSpending, budgetRecommendation
}

// MARK: - Test Doubles: ProviderType

private enum TestProviderType: Sendable, CaseIterable {
    case bank, crypto, investment
}

// MARK: - Test Doubles: Transaction

private struct TestTransaction: Identifiable, Codable, Sendable {
    let id: UUID
    let accountId: UUID
    let amount: Double
    let description: String
    let date: Date
    let category: TestTransactionCategory

    init(id: UUID = UUID(), accountId: UUID = UUID(), amount: Double, description: String, date: Date = Date(), category: TestTransactionCategory = .other) {
        self.id = id
        self.accountId = accountId
        self.amount = amount
        self.description = description
        self.date = date
        self.category = category
    }
}

// MARK: - Test Doubles: Budget

private struct TestBudget: Identifiable, Codable, Sendable {
    let id: UUID
    let category: TestTransactionCategory
    let limit: Double
    let spent: Double
    let period: TestBudgetPeriod

    var remaining: Double { max(limit - spent, 0) }
    var utilizationRate: Double {
        guard limit > 0 else { return 0 }
        return spent / limit
    }
    var isOverBudget: Bool { spent > limit }

    init(id: UUID = UUID(), category: TestTransactionCategory, limit: Double, spent: Double, period: TestBudgetPeriod = .monthly) {
        self.id = id
        self.category = category
        self.limit = limit
        self.spent = spent
        self.period = period
    }
}

// MARK: - Test Doubles: ProviderAccount

private struct TestProviderAccount: Identifiable, Codable, Sendable {
    let id: UUID
    let provider: String
    let accountType: TestAccountType
    let name: String
    let balance: Double
    let currency: String
    let lastUpdated: Date

    init(id: UUID = UUID(), provider: String, accountType: TestAccountType, name: String, balance: Double, currency: String = "CHF", lastUpdated: Date = Date()) {
        self.id = id
        self.provider = provider
        self.accountType = accountType
        self.name = name
        self.balance = balance
        self.currency = currency
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Test Doubles: FinancialError

private enum TestFinancialError: Error, LocalizedError, Sendable {
    case providerNotFound
    case noAccountsFound
    case authenticationFailed
    case invalidCredentials(String)
    case connectionFailed(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .providerNotFound: return "Financial provider not found"
        case .noAccountsFound: return "No accounts found"
        case .authenticationFailed: return "Authentication failed"
        case .invalidCredentials(let msg): return "Invalid credentials: \(msg)"
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .unauthorized: return "Unauthorized access"
        }
    }
}

// MARK: - Test Doubles: CategoryClassifier

private enum TestCategoryClassifier {
    static func categorize(_ description: String) -> TestTransactionCategory {
        let lower = description.lowercased()
        if lower.contains("grocery") || lower.contains("supermarket") || lower.contains("coop") || lower.contains("migros") { return .groceries }
        if lower.contains("restaurant") || lower.contains("cafe") || lower.contains("coffee") || lower.contains("pizza") { return .dining }
        if lower.contains("uber") || lower.contains("taxi") || lower.contains("train") || lower.contains("sbb") || lower.contains("parking") { return .transportation }
        if lower.contains("netflix") || lower.contains("spotify") || lower.contains("cinema") || lower.contains("game") { return .entertainment }
        if lower.contains("rent") || lower.contains("mortgage") || lower.contains("apartment") { return .housing }
        if lower.contains("electric") || lower.contains("water") || lower.contains("gas") || lower.contains("internet") || lower.contains("phone") { return .utilities }
        if lower.contains("doctor") || lower.contains("pharmacy") || lower.contains("hospital") || lower.contains("dental") { return .healthcare }
        if lower.contains("amazon") || lower.contains("zalando") || lower.contains("digitec") || lower.contains("store") { return .shopping }
        if lower.contains("hotel") || lower.contains("flight") || lower.contains("airbnb") || lower.contains("booking") { return .travel }
        if lower.contains("salary") || lower.contains("income") || lower.contains("payment received") { return .income }
        return .other
    }
}

// MARK: - Test Doubles: SpendingAnalyzer

private enum TestSpendingAnalyzer {
    static func monthlySpending(from transactions: [TestTransaction]) -> Double {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        return transactions
            .filter { $0.date >= thirtyDaysAgo && $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }

    static func topCategories(from transactions: [TestTransaction], limit: Int = 5) -> [(TestTransactionCategory, Double)] {
        var categorySpending: [TestTransactionCategory: Double] = [:]
        for tx in transactions where tx.amount < 0 {
            categorySpending[tx.category, default: 0] += abs(tx.amount)
        }
        return categorySpending
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    static func detectUnusual(in transactions: [TestTransaction]) -> [TestTransaction] {
        let amounts = transactions.filter { $0.amount < 0 }.map { abs($0.amount) }
        guard !amounts.isEmpty else { return [] }
        let avg = amounts.reduce(0, +) / Double(amounts.count)
        let threshold = avg * 3
        return transactions.filter { $0.amount < 0 && abs($0.amount) > threshold }
    }
}

// MARK: - Tests: TransactionCategory

@Suite("Transaction Category")
struct TransactionCategoryTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestTransactionCategory.allCases.count == 11)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let values = Set(TestTransactionCategory.allCases.map(\.rawValue))
        #expect(values.count == TestTransactionCategory.allCases.count)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for cat in TestTransactionCategory.allCases {
            let data = try JSONEncoder().encode(cat)
            let decoded = try JSONDecoder().decode(TestTransactionCategory.self, from: data)
            #expect(decoded == cat)
        }
    }
}

// MARK: - Tests: BudgetPeriod

@Suite("Budget Period")
struct BudgetPeriodTests {
    @Test("Day counts are reasonable")
    func dayCounts() {
        #expect(TestBudgetPeriod.daily.dayCount == 1)
        #expect(TestBudgetPeriod.weekly.dayCount == 7)
        #expect(TestBudgetPeriod.monthly.dayCount == 30)
        #expect(TestBudgetPeriod.yearly.dayCount == 365)
    }

    @Test("Day counts increase")
    func dayCountsIncrease() {
        let counts = TestBudgetPeriod.allCases.map(\.dayCount)
        for i in 1..<counts.count {
            #expect(counts[i] > counts[i - 1])
        }
    }
}

// MARK: - Tests: AccountType

@Suite("Account Type")
struct AccountTypeTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestAccountType.allCases.count == 5)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let values = Set(TestAccountType.allCases.map(\.rawValue))
        #expect(values.count == TestAccountType.allCases.count)
    }
}

// MARK: - Tests: AlertSeverity

@Suite("Alert Severity")
struct AlertSeverityTests {
    @Test("Rank ordering")
    func rankOrdering() {
        #expect(TestAlertSeverity.info.rank < TestAlertSeverity.warning.rank)
        #expect(TestAlertSeverity.warning.rank < TestAlertSeverity.critical.rank)
    }
}

// MARK: - Tests: Budget

@Suite("Budget Logic")
struct BudgetLogicTests {
    @Test("Remaining budget")
    func remaining() {
        let budget = TestBudget(category: .groceries, limit: 500, spent: 300)
        #expect(budget.remaining == 200)
    }

    @Test("Remaining budget clamped to zero")
    func remainingClamped() {
        let budget = TestBudget(category: .dining, limit: 200, spent: 350)
        #expect(budget.remaining == 0)
    }

    @Test("Utilization rate")
    func utilizationRate() {
        let budget = TestBudget(category: .entertainment, limit: 100, spent: 75)
        #expect(budget.utilizationRate == 0.75)
    }

    @Test("Utilization rate with zero limit")
    func utilizationZeroLimit() {
        let budget = TestBudget(category: .other, limit: 0, spent: 50)
        #expect(budget.utilizationRate == 0)
    }

    @Test("Over budget detection")
    func overBudget() {
        let budget = TestBudget(category: .shopping, limit: 300, spent: 400)
        #expect(budget.isOverBudget)
    }

    @Test("Under budget")
    func underBudget() {
        let budget = TestBudget(category: .transportation, limit: 200, spent: 150)
        #expect(!budget.isOverBudget)
    }
}

// MARK: - Tests: ProviderAccount

@Suite("Provider Account")
struct ProviderAccountTests {
    @Test("Creation with defaults")
    func creation() {
        let account = TestProviderAccount(provider: "UBS", accountType: .checking, name: "Main Account", balance: 5000)
        #expect(account.provider == "UBS")
        #expect(account.accountType == .checking)
        #expect(account.currency == "CHF")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let account = TestProviderAccount(provider: "PostFinance", accountType: .savings, name: "Savings", balance: 10000, currency: "EUR")
        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(TestProviderAccount.self, from: data)
        #expect(decoded.provider == "PostFinance")
        #expect(decoded.balance == 10000)
        #expect(decoded.currency == "EUR")
    }
}

// MARK: - Tests: FinancialError

@Suite("Financial Error")
struct FinancialErrorTests {
    @Test("All errors have descriptions")
    func descriptions() {
        let errors: [TestFinancialError] = [.providerNotFound, .noAccountsFound, .authenticationFailed, .invalidCredentials("expired"), .connectionFailed("timeout"), .unauthorized]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Invalid credentials includes message")
    func invalidCredMsg() {
        let error = TestFinancialError.invalidCredentials("token expired")
        #expect(error.errorDescription!.contains("token expired"))
    }

    @Test("Connection failed includes message")
    func connectionFailedMsg() {
        let error = TestFinancialError.connectionFailed("DNS resolution failed")
        #expect(error.errorDescription!.contains("DNS resolution failed"))
    }
}

// MARK: - Tests: CategoryClassifier

@Suite("Category Classifier")
struct CategoryClassifierTests {
    @Test("Groceries detection")
    func groceries() {
        #expect(TestCategoryClassifier.categorize("Migros Lausanne") == .groceries)
        #expect(TestCategoryClassifier.categorize("COOP City") == .groceries)
        #expect(TestCategoryClassifier.categorize("Supermarket purchase") == .groceries)
    }

    @Test("Dining detection")
    func dining() {
        #expect(TestCategoryClassifier.categorize("Restaurant du Parc") == .dining)
        #expect(TestCategoryClassifier.categorize("Starbucks Coffee") == .dining)
        #expect(TestCategoryClassifier.categorize("Pizza Hut") == .dining)
    }

    @Test("Transportation detection")
    func transportation() {
        #expect(TestCategoryClassifier.categorize("SBB Ticket") == .transportation)
        #expect(TestCategoryClassifier.categorize("Uber ride") == .transportation)
        #expect(TestCategoryClassifier.categorize("Parking garage") == .transportation)
    }

    @Test("Entertainment detection")
    func entertainment() {
        #expect(TestCategoryClassifier.categorize("Netflix subscription") == .entertainment)
        #expect(TestCategoryClassifier.categorize("Spotify premium") == .entertainment)
    }

    @Test("Housing detection")
    func housing() {
        #expect(TestCategoryClassifier.categorize("Monthly rent") == .housing)
        #expect(TestCategoryClassifier.categorize("Mortgage payment") == .housing)
    }

    @Test("Healthcare detection")
    func healthcare() {
        #expect(TestCategoryClassifier.categorize("Doctor visit") == .healthcare)
        #expect(TestCategoryClassifier.categorize("Pharmacy purchase") == .healthcare)
    }

    @Test("Shopping detection")
    func shopping() {
        #expect(TestCategoryClassifier.categorize("Amazon order") == .shopping)
        #expect(TestCategoryClassifier.categorize("Digitec electronics") == .shopping)
    }

    @Test("Travel detection")
    func travel() {
        #expect(TestCategoryClassifier.categorize("Hotel booking") == .travel)
        #expect(TestCategoryClassifier.categorize("Flight to Paris") == .travel)
    }

    @Test("Income detection")
    func income() {
        #expect(TestCategoryClassifier.categorize("Monthly salary") == .income)
        #expect(TestCategoryClassifier.categorize("Payment received") == .income)
    }

    @Test("Unknown defaults to other")
    func unknownCategory() {
        #expect(TestCategoryClassifier.categorize("Random purchase XYZ") == .other)
    }
}

// MARK: - Tests: SpendingAnalyzer

@Suite("Spending Analyzer")
struct SpendingAnalyzerTests {
    @Test("Monthly spending: only negative transactions in last 30 days")
    func monthlySpending() {
        let now = Date()
        let transactions = [
            TestTransaction(amount: -50, description: "Food", date: now.addingTimeInterval(-86400)),
            TestTransaction(amount: -100, description: "Gas", date: now.addingTimeInterval(-172800)),
            TestTransaction(amount: 2000, description: "Salary", date: now.addingTimeInterval(-86400)), // Income, excluded
            TestTransaction(amount: -200, description: "Old purchase", date: now.addingTimeInterval(-86400 * 60)), // >30 days, excluded
        ]
        let spending = TestSpendingAnalyzer.monthlySpending(from: transactions)
        #expect(spending == 150)
    }

    @Test("Top categories sorted by spending")
    func topCategories() {
        let transactions = [
            TestTransaction(amount: -200, description: "Food", category: .groceries),
            TestTransaction(amount: -150, description: "Dinner", category: .dining),
            TestTransaction(amount: -50, description: "Uber", category: .transportation),
            TestTransaction(amount: -300, description: "Rent", category: .housing),
            TestTransaction(amount: 3000, description: "Salary", category: .income), // Positive, excluded
        ]
        let top = TestSpendingAnalyzer.topCategories(from: transactions)
        #expect(top.first?.0 == .housing)
        #expect(top.first?.1 == 300)
        #expect(top.count == 4)
    }

    @Test("Unusual spending detection: >3x average")
    func unusualSpending() {
        let transactions = [
            TestTransaction(amount: -50, description: "Normal"),
            TestTransaction(amount: -60, description: "Normal"),
            TestTransaction(amount: -40, description: "Normal"),
            TestTransaction(amount: -55, description: "Normal"),
            TestTransaction(amount: -500, description: "Unusual"), // >3x avg of 50
        ]
        let unusual = TestSpendingAnalyzer.detectUnusual(in: transactions)
        #expect(unusual.count == 1)
        #expect(unusual.first?.description == "Unusual")
    }

    @Test("No unusual spending when uniform")
    func noUnusual() {
        let transactions = [
            TestTransaction(amount: -50, description: "A"),
            TestTransaction(amount: -55, description: "B"),
            TestTransaction(amount: -45, description: "C")
        ]
        let unusual = TestSpendingAnalyzer.detectUnusual(in: transactions)
        #expect(unusual.isEmpty)
    }

    @Test("Empty transactions")
    func emptyTransactions() {
        let spending = TestSpendingAnalyzer.monthlySpending(from: [])
        #expect(spending == 0)
        let top = TestSpendingAnalyzer.topCategories(from: [])
        #expect(top.isEmpty)
        let unusual = TestSpendingAnalyzer.detectUnusual(in: [])
        #expect(unusual.isEmpty)
    }
}
