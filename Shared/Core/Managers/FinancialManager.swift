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

    func addAccount(provider: String, accountName: String, accountType: String, currency: String = "USD") -> FinancialAccount {
        let account = FinancialAccount(
            provider: provider,
            accountName: accountName,
            accountType: accountType,
            currency: currency
        )
        modelContext?.insert(account)
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save new account: \(error.localizedDescription)") }
        accounts.append(account)
        return account
    }

    // periphery:ignore - Reserved for future feature activation
    func removeAccount(_ account: FinancialAccount) {
        modelContext?.delete(account)
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save after removing account: \(error.localizedDescription)") }
        accounts.removeAll { $0.id == account.id }
    }

    // MARK: - Transaction Management

    func addTransaction(
        providerTransactionID: String = UUID().uuidString,
        accountID: UUID,
        provider: String,
        date: Date = Date(),
        amount: Double,
        currency: String = "USD",
        memo: String,
        category: String = "",
        isPending: Bool = false
    ) -> FinancialTransaction {
        let transaction = FinancialTransaction(
            providerTransactionID: providerTransactionID,
            accountID: accountID,
            provider: provider,
            date: date,
            amount: amount,
            currency: currency,
            memo: memo,
            category: category,
            isPending: isPending
        )
        modelContext?.insert(transaction)
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save new transaction: \(error.localizedDescription)") }
        transactions.append(transaction)
        return transaction
    }

    // periphery:ignore - Reserved for future feature activation
    func removeTransaction(_ transaction: FinancialTransaction) {
        modelContext?.delete(transaction)
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save after removing transaction: \(error.localizedDescription)") }
        transactions.removeAll { $0.id == transaction.id }
    }

    // periphery:ignore - Reserved for future feature activation
    func clearAllData() {
        guard let context = modelContext else { return }
        for transaction in transactions { context.delete(transaction) }
        for account in accounts { context.delete(account) }
        do { try context.save() } catch { financialLogger.error("Failed to save after clearing all data: \(error.localizedDescription)") }
        transactions.removeAll()
        accounts.removeAll()
        isSyncing = false
    }

    // periphery:ignore - Reserved for future feature activation
    func syncAccount(_ account: FinancialAccount) async {
        isSyncing = true
        do {
            try await Task.sleep(for: .seconds(1))
        } catch {
            // Task cancelled — expected during shutdown
        }
        account.lastSyncedAt = Date()
        do { try modelContext?.save() } catch { financialLogger.error("Failed to save after syncing account: \(error.localizedDescription)") }
        isSyncing = false
    }

    // MARK: - Analytics

    // periphery:ignore - Reserved for future feature activation
    func getBalance(for accountID: UUID) -> Double {
        transactions
            .filter { $0.accountID == accountID }
            .reduce(0) { $0 + $1.amount }
    }

    // periphery:ignore - Reserved for future feature activation
    func getSpendingByCategory() -> [String: Double] {
        var result: [String: Double] = [:]
        for transaction in transactions where transaction.amount < 0 {
            let category = transaction.category.isEmpty ? "Uncategorized" : transaction.category
            result[category, default: 0] += abs(transaction.amount)
        }
        return result
    }

    private func loadData() {
        guard let context = modelContext else { return }
        var accountDescriptor = FetchDescriptor<FinancialAccount>()
        accountDescriptor.sortBy = [SortDescriptor(\.accountName)]
        do { accounts = try context.fetch(accountDescriptor) } catch {
            financialLogger.error("Failed to fetch accounts: \(error.localizedDescription)")
            accounts = []
        }
        var transactionDescriptor = FetchDescriptor<FinancialTransaction>()
        transactionDescriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        do { transactions = try context.fetch(transactionDescriptor) } catch {
            financialLogger.error("Failed to fetch transactions: \(error.localizedDescription)")
            transactions = []
        }
    }
}
