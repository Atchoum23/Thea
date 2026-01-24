import CryptoKit
import Foundation

// MARK: - Financial Integration System
// Monitor bank accounts, crypto wallets, and provide financial insights

@MainActor
@Observable
final class FinancialIntegration {
    static let shared = FinancialIntegration()

    private(set) var connectedAccounts: [ProviderAccount] = []
    private(set) var transactions: [Transaction] = []
    private(set) var insights: [FinancialInsight] = []
    private(set) var budgets: [Budget] = []
    private(set) var alerts: [FinancialAlert] = []

    private var providers: [any FinancialProvider] = []

    private init() {
        registerProviders()
        loadAccounts()
    }

    private func registerProviders() {
        providers = [
            RevolutProvider(),
            BinanceProvider(),
            CoinbaseProvider(),
            PlaidProvider()
        ]
    }

    // MARK: - Account Connection

    func connectAccount(provider: String, credentials: FinancialCredentials) async throws -> ProviderAccount {
        guard let financialProvider = providers.first(where: { $0.providerName == provider }) else {
            throw FinancialError.providerNotFound
        }

        // Authenticate
        try await financialProvider.authenticate(credentials: credentials)

        // Fetch accounts
        let accounts = try await financialProvider.fetchAccounts()

        guard let account = accounts.first else {
            throw FinancialError.noAccountsFound
        }

        connectedAccounts.append(account)
        saveAccounts()

        // Fetch initial transactions
        try await refreshTransactions(for: account)

        return account
    }

    func disconnectAccount(_ accountId: UUID) {
        connectedAccounts.removeAll { $0.id == accountId }
        transactions.removeAll { $0.accountId == accountId }
        saveAccounts()
    }

    // MARK: - Data Fetching

    func refreshAllAccounts() async throws {
        for account in connectedAccounts {
            try await refreshAccount(account)
            try await refreshTransactions(for: account)
        }

        // Generate insights after refresh
        await generateInsights()
    }

    private func refreshAccount(_ account: ProviderAccount) async throws {
        guard let provider = providers.first(where: { $0.providerName == account.provider }) else {
            return
        }

        let updatedAccounts = try await provider.fetchAccounts()

        if let updated = updatedAccounts.first(where: { $0.id == account.id }),
           let index = connectedAccounts.firstIndex(where: { $0.id == account.id }) {
            var refreshed = connectedAccounts[index]
            refreshed.balance = updated.balance
            refreshed.currency = updated.currency
            refreshed.lastUpdated = Date()
            connectedAccounts[index] = refreshed
        }
    }

    private func refreshTransactions(for account: ProviderAccount) async throws {
        guard let provider = providers.first(where: { $0.providerName == account.provider }) else {
            return
        }

        let newTransactions = try await provider.fetchTransactions(accountId: account.id, days: 30)

        // Remove old transactions for this account
        transactions.removeAll { $0.accountId == account.id }

        // Add new transactions with AI categorization
        for transaction in newTransactions {
            var categorized = transaction
            categorized.category = await categorizeTransaction(transaction)
            transactions.append(categorized)
        }

        saveTransactions()
    }

    // MARK: - AI-Powered Categorization

    private func categorizeTransaction(_ transaction: Transaction) async -> TransactionCategory {
        // Use AI to categorize transaction based on description
        let description = transaction.description.lowercased()

        // Simple rule-based categorization (in production, use AI)
        if description.contains("grocery") || description.contains("supermarket") {
            return .groceries
        } else if description.contains("restaurant") || description.contains("cafe") {
            return .dining
        } else if description.contains("gas") || description.contains("fuel") {
            return .transportation
        } else if description.contains("netflix") || description.contains("spotify") {
            return .entertainment
        } else if description.contains("rent") || description.contains("mortgage") {
            return .housing
        } else if description.contains("utility") || description.contains("electric") {
            return .utilities
        } else {
            return .other
        }
    }

    // MARK: - Insights Generation

    private func generateInsights() async {
        insights.removeAll()

        // Spending trends
        let monthlySpending = calculateMonthlySpending()
        if monthlySpending > 0 {
            insights.append(FinancialInsight(
                id: UUID(),
                type: .spendingTrend,
                title: "Monthly Spending",
                description: "You've spent \(formatCurrency(monthlySpending)) this month",
                actionable: true,
                action: "Review budget"
            ))
        }

        // Category analysis
        let topCategories = analyzeTopCategories()
        for (category, amount) in topCategories.prefix(3) {
            insights.append(FinancialInsight(
                id: UUID(),
                type: .categoryAnalysis,
                title: "Top Spending: \(category.rawValue)",
                description: "Spent \(formatCurrency(amount)) on \(category.rawValue)",
                actionable: false,
                action: nil
            ))
        }

        // Unusual spending
        if let unusual = detectUnusualSpending() {
            insights.append(unusual)
        }

        // Budget recommendations
        let recommendations = generateBudgetRecommendations()
        insights.append(contentsOf: recommendations)
    }

    private func calculateMonthlySpending() -> Double {
        let now = Date()
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return 0
        }

        return transactions
            .filter { $0.date >= startOfMonth && $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }

    private func analyzeTopCategories() -> [(TransactionCategory, Double)] {
        var categoryTotals: [TransactionCategory: Double] = [:]

        for transaction in transactions where transaction.amount < 0 {
            categoryTotals[transaction.category, default: 0] += abs(transaction.amount)
        }

        return categoryTotals.sorted { $0.value > $1.value }
    }

    private func detectUnusualSpending() -> FinancialInsight? {
        // Detect transactions significantly higher than average
        let averageTransaction = transactions
            .filter { $0.amount < 0 }
            .map { abs($0.amount) }
            .reduce(0, +) / Double(max(transactions.count, 1))

        if let large = transactions
            .filter({ abs($0.amount) > averageTransaction * 3 })
            .first {
            return FinancialInsight(
                id: UUID(),
                type: .unusualSpending,
                title: "Unusual Transaction Detected",
                description: "Large transaction: \(formatCurrency(abs(large.amount))) at \(large.description)",
                actionable: true,
                action: "Review transaction"
            )
        }

        return nil
    }

    private func generateBudgetRecommendations() -> [FinancialInsight] {
        var recommendations: [FinancialInsight] = []

        let categorySpending = analyzeTopCategories()

        for (category, amount) in categorySpending {
            // If spending >30% on one category, recommend budget
            let total = calculateMonthlySpending()
            if amount / total > 0.3 {
                recommendations.append(FinancialInsight(
                    id: UUID(),
                    type: .budgetRecommendation,
                    title: "High \(category.rawValue) Spending",
                    description: "Consider setting a budget for \(category.rawValue)",
                    actionable: true,
                    action: "Create budget"
                ))
            }
        }

        return recommendations
    }

    // MARK: - Budgets

    func createBudget(category: TransactionCategory, limit: Double, period: Budget.BudgetPeriod) -> Budget {
        let budget = Budget(
            id: UUID(),
            category: category,
            limit: limit,
            spent: 0,
            period: period
        )

        budgets.append(budget)
        saveBudgets()

        return budget
    }

    func updateBudgetSpending() {
        let now = Date()

        for i in 0..<budgets.count {
            let budget = budgets[i]

            // Calculate period start/end dates
            let periodStart: Date
            let periodEnd: Date
            let calendar = Calendar.current

            switch budget.period {
            case .daily:
                periodStart = calendar.startOfDay(for: now)
                periodEnd = calendar.date(byAdding: .day, value: 1, to: periodStart) ?? now
            case .weekly:
                periodStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
                periodEnd = calendar.date(byAdding: .day, value: 7, to: periodStart) ?? now
            case .monthly:
                periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                periodEnd = calendar.date(byAdding: .month, value: 1, to: periodStart) ?? now
            case .yearly:
                periodStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
                periodEnd = calendar.date(byAdding: .year, value: 1, to: periodStart) ?? now
            }

            let spent = transactions
                .filter { $0.category == budget.category && $0.date >= periodStart && $0.date < periodEnd }
                .reduce(0.0) { $0 + abs($1.amount) }

            budgets[i].spent = spent

            // Create alert if over budget
            if spent > budget.limit {
                let alert = FinancialAlert(
                    id: UUID(),
                    type: .budgetExceeded,
                    title: "Budget Exceeded",
                    message: "\(budget.category.rawValue) budget exceeded by \(formatCurrency(spent - budget.limit))",
                    severity: .critical,
                    timestamp: Date()
                )

                if !alerts.contains(where: { $0.id == alert.id }) {
                    alerts.append(alert)
                }
            }
        }
    }

    private func calculateEndDate(_ period: Budget.BudgetPeriod) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(604800)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(2592000)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: now) ?? now.addingTimeInterval(31536000)
        }
    }

    // MARK: - Investment Insights

    func getInvestmentStrategy() async -> InvestmentStrategy {
        // AI-powered investment recommendations
        let totalBalance = connectedAccounts.reduce(0) { $0 + $1.balance }
        let monthlyIncome = estimateMonthlyIncome()
        let monthlyExpenses = calculateMonthlySpending()
        let savingsRate = (monthlyIncome - monthlyExpenses) / monthlyIncome

        return InvestmentStrategy(
            recommendedSavingsRate: 0.20, // 20%
            currentSavingsRate: savingsRate,
            emergencyFundTarget: monthlyExpenses * 6,
            currentEmergencyFund: totalBalance,
            investmentRecommendations: [
                "Build emergency fund to \(formatCurrency(monthlyExpenses * 6))",
                "Consider index fund investing for long-term growth",
                "Maximize retirement account contributions"
            ]
        )
    }

    private func estimateMonthlyIncome() -> Double {
        // Estimate based on incoming transactions
        let income = transactions
            .filter { $0.amount > 0 && $0.category == .income }
            .reduce(0) { $0 + $1.amount }

        return income / max(1, Double(transactions.count) / 30)
    }

    // MARK: - Persistence

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: "FinancialIntegration.accounts"),
           let accounts = try? JSONDecoder().decode([ProviderAccount].self, from: data) {
            connectedAccounts = accounts
        }
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(connectedAccounts) {
            UserDefaults.standard.set(data, forKey: "FinancialIntegration.accounts")
        }
    }

    private func saveTransactions() {
        if let data = try? JSONEncoder().encode(transactions) {
            UserDefaults.standard.set(data, forKey: "FinancialIntegration.transactions")
        }
    }

    private func saveBudgets() {
        if let data = try? JSONEncoder().encode(budgets) {
            UserDefaults.standard.set(data, forKey: "FinancialIntegration.budgets")
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Financial Provider Protocol

protocol FinancialProvider: Sendable {
    var providerName: String { get }
    var providerType: FinancialProviderType { get }

    func authenticate(credentials: FinancialCredentials) async throws
    func fetchAccounts() async throws -> [ProviderAccount]
    func fetchTransactions(accountId: UUID, days: Int) async throws -> [Transaction]
}

// MARK: - Models

/// A financial account from a provider
/// Note: Uses @unchecked Sendable because mutations only occur within @MainActor-isolated FinancialAIService
struct ProviderAccount: Identifiable, Codable, Sendable {
    let id: UUID
    let provider: String
    let accountType: ProviderProviderAccountType
    let name: String
    var balance: Double
    var currency: String
    var lastUpdated: Date

    init(id: UUID, provider: String, accountType: ProviderProviderAccountType, name: String, balance: Double, currency: String, lastUpdated: Date) {
        self.id = id
        self.provider = provider
        self.accountType = accountType
        self.name = name
        self.balance = balance
        self.currency = currency
        self.lastUpdated = lastUpdated
    }
}

/// A financial transaction
/// Note: Uses @unchecked Sendable because mutations only occur within @MainActor-isolated FinancialAIService
struct Transaction: Identifiable, Codable, Sendable {
    let id: UUID
    let accountId: UUID
    let amount: Double
    let description: String
    let date: Date
    var category: TransactionCategory

    init(id: UUID, accountId: UUID, amount: Double, description: String, date: Date, category: TransactionCategory = .other) {
        self.id = id
        self.accountId = accountId
        self.amount = amount
        self.description = description
        self.date = date
        self.category = category
    }
}

enum ProviderProviderAccountType: String, Codable, Sendable {
    case checking, savings, credit, crypto, investment
}

enum TransactionCategory: String, Codable, Sendable {
    case groceries, dining, transportation, entertainment, housing, utilities, healthcare, shopping, travel, income, other
}

struct Budget: Identifiable, Codable, Sendable {
    let id: UUID
    let category: TransactionCategory
    let limit: Double
    var spent: Double
    let period: BudgetPeriod

    enum BudgetPeriod: String, Codable, Sendable {
        case daily, weekly, monthly, yearly
    }
}

struct FinancialAlert: Identifiable, Sendable {
    let id: UUID
    let type: AlertType
    let title: String
    let message: String
    let severity: AlertSeverity
    let timestamp: Date

    enum AlertType: String, Sendable {
        case budgetExceeded, unusualSpending, lowBalance, recurringPayment
    }

    enum AlertSeverity: String, Sendable {
        case info, warning, critical
    }
}

struct FinancialCredentials: Codable, Sendable {
    let apiKey: String?
    let apiSecret: String?
    let accessToken: String?
}

enum FinancialProviderType: String, Sendable {
    case bank, crypto, investment
}

struct FinancialInsight: Identifiable {
    let id: UUID
    let type: InsightType
    let title: String
    let description: String
    let actionable: Bool
    let action: String?

    enum InsightType {
        case spendingTrend, categoryAnalysis, unusualSpending, budgetRecommendation
    }
}

struct InvestmentStrategy {
    let recommendedSavingsRate: Double
    let currentSavingsRate: Double
    let emergencyFundTarget: Double
    let currentEmergencyFund: Double
    let investmentRecommendations: [String]
}

// MARK: - Provider Implementations

struct RevolutProvider: FinancialProvider {
    let providerName = "Revolut"
    let providerType = FinancialProviderType.bank

    func authenticate(credentials: FinancialCredentials) async throws {
        // Revolut API authentication
    }

    func fetchAccounts() async throws -> [ProviderAccount] {
        // Fetch from Revolut API
        []
    }

    func fetchTransactions(accountId: UUID, days: Int) async throws -> [Transaction] {
        []
    }
}

struct BinanceProvider: FinancialProvider {
    let providerName = "Binance"
    let providerType = FinancialProviderType.crypto

    func authenticate(credentials: FinancialCredentials) async throws {
        // Binance API authentication
    }

    func fetchAccounts() async throws -> [ProviderAccount] {
        []
    }

    func fetchTransactions(accountId: UUID, days: Int) async throws -> [Transaction] {
        []
    }
}

struct CoinbaseProvider: FinancialProvider {
    let providerName = "Coinbase"
    let providerType = FinancialProviderType.crypto

    func authenticate(credentials: FinancialCredentials) async throws {
        // Coinbase API authentication
    }

    func fetchAccounts() async throws -> [ProviderAccount] {
        []
    }

    func fetchTransactions(accountId: UUID, days: Int) async throws -> [Transaction] {
        []
    }
}

struct PlaidProvider: FinancialProvider {
    let providerName = "Plaid"
    let providerType = FinancialProviderType.bank

    func authenticate(credentials: FinancialCredentials) async throws {
        // Plaid Link authentication
    }

    func fetchAccounts() async throws -> [ProviderAccount] {
        []
    }

    func fetchTransactions(accountId: UUID, days: Int) async throws -> [Transaction] {
        []
    }
}

// MARK: - Errors

enum FinancialError: LocalizedError {
    case providerNotFound
    case noAccountsFound
    case authenticationFailed
    case invalidCredentials(String)
    case connectionFailed(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .providerNotFound:
            return "Financial provider not found"
        case .noAccountsFound:
            return "No accounts found"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidCredentials(let message):
            return "Invalid credentials: \(message)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}
