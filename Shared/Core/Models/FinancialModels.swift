import Foundation
@preconcurrency import SwiftData

@Model
final class FinancialAccount {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: AccountType
    var institution: String
    var balance: Double
    var currency: String
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        institution: String,
        balance: Double = 0,
        currency: String = "USD",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.institution = institution
        self.balance = balance
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }
}

@Model
final class FinancialTransaction {
    @Attribute(.unique) var id: UUID
    var accountId: UUID
    var amount: Double
    var transactionDescription: String
    var category: String?
    var merchant: String?
    var date: Date
    var isRecurring: Bool
    var tags: [String]

    init(
        id: UUID = UUID(),
        accountId: UUID,
        amount: Double,
        // periphery:ignore - Reserved: init(id:accountId:amount:transactionDescription:category:merchant:date:isRecurring:tags:) initializer reserved for future feature activation
        transactionDescription: String,
        category: String? = nil,
        merchant: String? = nil,
        date: Date = Date(),
        isRecurring: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.accountId = accountId
        self.amount = amount
        self.transactionDescription = transactionDescription
        self.category = category
        self.merchant = merchant
        self.date = date
        self.isRecurring = isRecurring
        self.tags = tags
    }
}

extension FinancialAccount: Identifiable {}
extension FinancialTransaction: Identifiable {}

// MARK: - Supporting Types

// periphery:ignore - Reserved: TimePeriod enum — reserved for future feature activation
enum TimePeriod: String, Codable {
    case week
    case month
    // periphery:ignore - Reserved: TimePeriod type reserved for future feature activation
    case quarter
    case year
}

// periphery:ignore - Reserved: MonthlyData type — reserved for future feature activation
struct MonthlyData: Identifiable {
    let id = UUID()
    // periphery:ignore - Reserved: MonthlyData type reserved for future feature activation
    let month: String
    let income: Decimal
    let expenses: Decimal
}

// periphery:ignore - Reserved: BudgetRecommendation type — reserved for future feature activation
struct BudgetRecommendation: Identifiable {
    // periphery:ignore - Reserved: BudgetRecommendation type reserved for future feature activation
    let id = UUID()
    let category: String
    let reason: String
    let currentSpending: Decimal
    let recommendedBudget: Decimal
}

// periphery:ignore - Reserved: TransactionAnomaly type reserved for future feature activation
struct TransactionAnomaly: Identifiable {
    let id = UUID()
    let transaction: FinancialTransaction
    let reason: String
    let severity: AnomalySeverity
}

enum AnomalySeverity: String, Codable {
    case low
    case medium
    case high
}

// MARK: - Account Type

enum AccountType: String, Codable {
    case checking
    case savings
    case credit
    case investment
    case crypto
}
