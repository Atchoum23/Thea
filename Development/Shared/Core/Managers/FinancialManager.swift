import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class FinancialManager {
    static let shared = FinancialManager()
    
    private(set) var accounts: [FinancialAccount] = []
    private(set) var transactions: [FinancialTransaction] = []
    private(set) var isSyncing: Bool = false
    
    private var modelContext: ModelContext?
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }
    
    // MARK: - Account Management
    
    func addAccount(name: String, type: AccountType, institution: String) -> FinancialAccount {
        let account = FinancialAccount(
            id: UUID(),
            name: name,
            type: type,
            institution: institution,
            balance: 0,
            currency: "USD"
        )
        modelContext?.insert(account)
        try? modelContext?.save()
        accounts.append(account)
        return account
    }
    
    func removeAccount(_ account: FinancialAccount) {
        modelContext?.delete(account)
        try? modelContext?.save()
        accounts.removeAll { $0.id == account.id }
    }
    
    // MARK: - Transaction Management
    
    func addTransaction(
        accountId: UUID,
        amount: Double,
        description: String,
        category: String,
        date: Date = Date()
    ) -> FinancialTransaction {
        let transaction = FinancialTransaction(
            id: UUID(),
            accountId: accountId,
            amount: amount,
            transactionDescription: description,
            category: category,
            date: date
        )
        modelContext?.insert(transaction)
        try? modelContext?.save()
        transactions.append(transaction)
        return transaction
    }
    
    func removeTransaction(_ transaction: FinancialTransaction) {
        modelContext?.delete(transaction)
        try? modelContext?.save()
        transactions.removeAll { $0.id == transaction.id }
    }
    
    // MARK: - Analytics
    
    func getBalance(for accountId: UUID) -> Double {
        transactions
            .filter { $0.accountId == accountId }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getSpendingByCategory() -> [String: Double] {
        var result: [String: Double] = [:]
        for transaction in transactions where transaction.amount < 0 {
            let category = transaction.category ?? "Uncategorized"
            result[category, default: 0] += abs(transaction.amount)
        }
        return result
    }
    
    private func loadData() {
        guard let context = modelContext else { return }
        
        let accountDescriptor = FetchDescriptor<FinancialAccount>(
            sortBy: [SortDescriptor(\.name)]
        )
        accounts = (try? context.fetch(accountDescriptor)) ?? []
        
        let transactionDescriptor = FetchDescriptor<FinancialTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        transactions = (try? context.fetch(transactionDescriptor)) ?? []
    }
}
