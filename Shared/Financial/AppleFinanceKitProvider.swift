//
//  AppleFinanceKitProvider.swift
//  Thea
//
//  Apple FinanceKit integration — queries Apple Wallet accounts (Apple Cash,
//  Apple Card, Savings) via the on-device FinanceKit API (iOS 17.4+).
//

import Foundation

#if os(iOS)
    import FinanceKit

    /// Provides Apple Wallet financial data via FinanceKit (iOS 17.4+)
    struct AppleFinanceKitProvider: FinancialProvider {
        let providerName = "Apple Wallet"
        let providerType: FinancialProviderType = .bank

        func authenticate(credentials _: FinancialCredentials) async throws {
            guard FinanceStore.isDataAvailable(.financialData) else {
                throw FinancialError.connectionFailed("FinanceKit data not available on this device")
            }

            let store = FinanceStore.shared
            let status = try await store.requestAuthorization()

            guard status == .authorized else {
                throw FinancialError.authenticationFailed
            }
        }

        func fetchAccounts() async throws -> [ProviderAccount] {
            guard FinanceStore.isDataAvailable(.financialData) else {
                return []
            }

            let store = FinanceStore.shared
            let query = AccountQuery(
                sortDescriptors: [SortDescriptor(\Account.displayName)]
            )

            let accounts = try await store.accounts(query: query)

            return accounts.map { account in
                let accountType: ProviderProviderAccountType = switch account.institutionName {
                case _ where account.displayName.localizedCaseInsensitiveContains("savings"):
                    .savings
                case _ where account.displayName.localizedCaseInsensitiveContains("credit"):
                    .credit
                default:
                    .checking
                }

                return ProviderAccount(
                    id: UUID(),
                    provider: providerName,
                    accountType: accountType,
                    name: "\(account.displayName) (\(account.institutionName))",
                    balance: 0, // Updated via balance query
                    currency: account.currencyCode,
                    lastUpdated: Date()
                )
            }
        }

        func fetchTransactions(accountId: UUID, days: Int) async throws -> [Transaction] {
            guard FinanceStore.isDataAvailable(.financialData) else {
                return []
            }

            let store = FinanceStore.shared
            let query = AccountQuery(
                sortDescriptors: [SortDescriptor(\Account.displayName)]
            )

            let accounts = try await store.accounts(query: query)
            guard let account = accounts.first else {
                return []
            }

            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

            // Use non-monitoring transaction history for a one-shot fetch
            let sequence = store.transactionHistory(
                forAccountID: account.id,
                isMonitoring: false
            )

            var results: [Transaction] = []
            for try await change in sequence {
                for tx in change.inserted {
                    guard tx.transactionDate >= cutoffDate else { continue }

                    let rawAmount = NSDecimalNumber(decimal: tx.transactionAmount.amount).doubleValue
                    let amount: Double = tx.creditDebitIndicator == .debit ? -rawAmount : rawAmount

                    results.append(Transaction(
                        id: UUID(),
                        accountId: accountId,
                        amount: amount,
                        description: tx.merchantName ?? tx.transactionDescription,
                        date: tx.transactionDate,
                        category: categorize(merchantName: tx.merchantName)
                    ))
                }
            }

            return results.sorted { $0.date > $1.date }
        }

        // MARK: - Private Helpers

        private func categorize(merchantName: String?) -> TransactionCategory {
            guard let name = merchantName?.lowercased() else { return .other }

            if name.contains("grocery") || name.contains("market") || name.contains("whole foods") || name.contains("trader joe") {
                return .groceries
            } else if name.contains("restaurant") || name.contains("cafe") || name.contains("coffee") || name.contains("starbucks") || name.contains("mcdonald") {
                return .dining
            } else if name.contains("uber") || name.contains("lyft") || name.contains("gas") || name.contains("fuel") || name.contains("shell") || name.contains("chevron") {
                return .transportation
            } else if name.contains("netflix") || name.contains("spotify") || name.contains("hulu") || name.contains("disney") || name.contains("cinema") {
                return .entertainment
            } else if name.contains("rent") || name.contains("mortgage") || name.contains("lease") {
                return .housing
            } else if name.contains("electric") || name.contains("water") || name.contains("utility") || name.contains("internet") || name.contains("phone") {
                return .utilities
            } else if name.contains("pharmacy") || name.contains("hospital") || name.contains("doctor") || name.contains("health") || name.contains("medical") {
                return .healthcare
            } else if name.contains("amazon") || name.contains("walmart") || name.contains("target") || name.contains("shop") || name.contains("store") {
                return .shopping
            } else if name.contains("airline") || name.contains("hotel") || name.contains("airbnb") || name.contains("booking") || name.contains("flight") {
                return .travel
            }

            return .other
        }
    }

#else

    /// Stub for platforms without FinanceKit (macOS, watchOS, tvOS)
    struct AppleFinanceKitProvider: FinancialProvider {
        let providerName = "Apple Wallet"
        let providerType: FinancialProviderType = .bank

        func authenticate(credentials _: FinancialCredentials) async throws {
            throw FinancialError.connectionFailed("FinanceKit not available on this platform")
        }

        func fetchAccounts() async throws -> [ProviderAccount] {
            []
        }

        func fetchTransactions(accountId _: UUID, days _: Int) async throws -> [Transaction] {
            []
        }
    }

#endif
