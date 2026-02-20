// FinancialModels.swift
// Thea — Financial Intelligence Hub (AAC3-1)
//
// SwiftData-backed models for financial accounts and transactions.
// All sensitive credentials are stored in Keychain via FinancialCredentialStore,
// NOT in SwiftData. These models store display/analytics data only.

import Foundation
import SwiftData

// MARK: - Financial Account

/// Represents a connected financial account (bank, crypto exchange, budget tool).
@Model
final class FinancialAccount {
    @Attribute(.unique) var id: UUID
    var provider: String          // e.g. "kraken", "coinbase", "ynab", "plaid"
    var accountName: String       // Human-readable name from provider
    var accountType: String       // e.g. "checking", "crypto", "budget", "investment"
    var currency: String          // ISO 4217 or crypto ticker (e.g. "USD", "BTC", "ETH")
    var balance: Double           // Current balance in `currency`
    var lastSyncedAt: Date
    var isActive: Bool
    var displayColor: String      // Hex color for UI differentiation

    init(
        id: UUID = UUID(),
        provider: String,
        accountName: String,
        accountType: String,
        currency: String,
        balance: Double = 0,
        lastSyncedAt: Date = .distantPast,
        isActive: Bool = true,
        displayColor: String = "#6366F1"
    ) {
        self.id = id
        self.provider = provider
        self.accountName = accountName
        self.accountType = accountType
        self.currency = currency
        self.balance = balance
        self.lastSyncedAt = lastSyncedAt
        self.isActive = isActive
        self.displayColor = displayColor
    }
}

// MARK: - Financial Transaction

/// A single financial transaction from any connected provider.
@Model
final class FinancialTransaction {
    @Attribute(.unique) var id: UUID
    var providerTransactionID: String  // Native ID from source provider
    var accountID: UUID                // FK → FinancialAccount.id
    var provider: String               // Source provider name
    var date: Date
    var amount: Double                 // Positive = credit, negative = debit
    var currency: String
    var memo: String                   // Payee or memo from provider (renamed from 'description' — conflicts with @Model macro)
    var category: String               // YNAB/Plaid category or empty string
    var isPending: Bool
    var importedAt: Date

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    init(
        id: UUID = UUID(),
        providerTransactionID: String,
        accountID: UUID,
        provider: String,
        date: Date,
        amount: Double,
        currency: String,
        memo: String,
        category: String = "",
        isPending: Bool = false,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.providerTransactionID = providerTransactionID
        self.accountID = accountID
        self.provider = provider
        self.date = date
        self.amount = amount
        self.currency = currency
        self.memo = memo
        self.category = category
        self.isPending = isPending
        self.importedAt = importedAt
    }
}

// MARK: - Provider Enum

/// Supported financial providers for type-safe routing.
enum FinancialAPIProvider: String, CaseIterable, Sendable {
    case kraken
    case coinbase
    case ynab
    case plaid

    var displayName: String { // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
        switch self {
        case .kraken:   return "Kraken"
        case .coinbase: return "Coinbase"
        case .ynab:     return "YNAB"
        case .plaid:    return "Plaid"
        }
    }

    /// Keychain identifier used by FinancialCredentialStore
    var keychainKey: String { "thea.financial.\(rawValue)" } // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
}
