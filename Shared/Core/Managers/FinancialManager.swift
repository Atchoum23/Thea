import Foundation
import Observation
import os.log
@preconcurrency import SwiftData

private let financialLogger = Logger(subsystem: "ai.thea.app", category: "FinancialManager")

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
        modelContext = context
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
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save new account: \(error.localizedDescription)") }
        accounts.append(account)
        return account
    }

    func removeAccount(_ account: FinancialAccount) {
        modelContext?.delete(account)
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save after removing account: \(error.localizedDescription)") }
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
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save new transaction: \(error.localizedDescription)") }
        transactions.append(transaction)
        return transaction
    }

    func removeTransaction(_ transaction: FinancialTransaction) {
        modelContext?.delete(transaction)
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save after removing transaction: \(error.localizedDescription)") }
        transactions.removeAll { $0.id == transaction.id }
    }

    func clearAllData() {
        guard let context = modelContext else { return }

        for transaction in transactions {
            context.delete(transaction)
        }
        for account in accounts {
            context.delete(account)
        }
        do { try context.save() } catch { financialLogger.error("Failed to save after clearing all data: \(error.localizedDescription)") }

        transactions.removeAll()
        accounts.removeAll()
        isSyncing = false
    }

    func syncAccount(_ account: FinancialAccount) async {
        isSyncing = true

        // Simulate sync delay
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            // Task cancelled — expected during shutdown
        }

        // Update the account's last sync time
        account.updatedAt = Date()
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save after syncing account: \(error.localizedDescription)") }

        isSyncing = false
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

        var accountDescriptor = FetchDescriptor<FinancialAccount>()
        accountDescriptor.sortBy = [SortDescriptor(\.name)]
        do {
            accounts = try context.fetch(accountDescriptor)
        } catch {
            financialLogger.error("Failed to fetch accounts: \(error.localizedDescription)")
            accounts = []
        }

        var transactionDescriptor = FetchDescriptor<FinancialTransaction>()
        transactionDescriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        do {
            transactions = try context.fetch(transactionDescriptor)
        } catch {
            financialLogger.error("Failed to fetch transactions: \(error.localizedDescription)")
            transactions = []
        }
    }
}
