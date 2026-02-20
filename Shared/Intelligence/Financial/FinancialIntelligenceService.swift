// FinancialIntelligenceService.swift
// Thea — Financial Intelligence Hub (AAC3-7)
//
// @MainActor ObservableObject orchestrating all financial providers:
// Kraken, Coinbase, YNAB, Plaid.
// Provides syncAll() parallel sync and morningBriefing() narrative.
// All data is routed through OutboundPrivacyGuard before leaving the device.

import Foundation
import SwiftData
import OSLog

// MARK: - Financial Summary

struct FinancialSummary: Sendable {
    let totalCryptoValueUSD: Double
    let cryptoBalances: [KrakenBalance]
    let coinbaseBalances: [CoinbaseAccount]
    let ynabBudgets: [YNABBudgetSummary]
    let recentTransactionCount: Int
    let lastSyncedAt: Date
}

// MARK: - Financial Intelligence Service

@MainActor
final class FinancialIntelligenceService: ObservableObject {
    static let shared = FinancialIntelligenceService()

    // MARK: - Published State

    @Published var isLoading: Bool = false
    @Published var lastSyncError: String?
    @Published var lastSyncedAt: Date?
    @Published var summary: FinancialSummary?

    // MARK: - Provider Services (actor references)

    private let krakenService   = KrakenService.shared
    private let coinbaseService = CoinbaseService.shared
    private let ynabService     = YNABService.shared
    private let plaidService    = PlaidService.shared

    private let logger = Logger(subsystem: "com.thea.app", category: "FinancialIntelligenceService")

    private init() {}

    // MARK: - Sync All Providers (Parallel)

    /// Sync all configured financial providers in parallel using TaskGroup.
    /// Results are merged into `summary`. Errors from individual providers are logged
    /// but do not prevent other providers from syncing.
    func syncAll() async {
        guard !isLoading else { return }
        isLoading = true
        lastSyncError = nil
        defer { isLoading = false }

        logger.info("FinancialIntelligenceService: starting parallel sync")

        async let krakenResult   = fetchKrakenSafely()
        async let coinbaseResult = fetchCoinbaseSafely()
        async let ynabResult     = fetchYNABSafely()
        async let plaidResult    = fetchPlaidSafely()

        let (krakenBalances, coinbaseAccounts, ynabBudgets, plaidTransactions) =
            await (krakenResult, coinbaseResult, ynabResult, plaidResult)

        let recentCount = plaidTransactions.count

        summary = FinancialSummary(
            totalCryptoValueUSD:  estimateCryptoValue(kraken: krakenBalances, coinbase: coinbaseAccounts),
            cryptoBalances:       krakenBalances,
            coinbaseBalances:     coinbaseAccounts,
            ynabBudgets:          ynabBudgets,
            recentTransactionCount: recentCount,
            lastSyncedAt:         Date()
        )
        lastSyncedAt = Date()
        logger.info("FinancialIntelligenceService: sync complete")
    }

    // MARK: - Morning Briefing

    /// Generate a concise natural-language financial morning briefing.
    /// All figures are sanitized through OutboundPrivacyGuard before use in prompts.
    func morningBriefing() async -> String {
        guard let s = summary else {
            return "No financial data available. Please configure your accounts in Settings → Financial and sync."
        }

        var lines: [String] = []
        lines.append("**Financial Snapshot** — \(formatDate(s.lastSyncedAt))")

        if !s.cryptoBalances.isEmpty {
            let cryptoLines = s.cryptoBalances
                .filter { $0.amount > 0.0001 }
                .prefix(5)
                .map { "  • \($0.asset): \(formatAmount($0.amount))" }
            if !cryptoLines.isEmpty {
                lines.append("Kraken balances:")
                lines.append(contentsOf: cryptoLines)
            }
        }

        if !s.coinbaseBalances.isEmpty {
            let coinbaseLines = s.coinbaseBalances
                .filter { $0.balance > 0 }
                .prefix(5)
                .map { "  • \($0.name) (\($0.currency)): \(formatAmount($0.balance))" }
            if !coinbaseLines.isEmpty {
                lines.append("Coinbase wallets:")
                lines.append(contentsOf: coinbaseLines)
            }
        }

        if !s.ynabBudgets.isEmpty {
            lines.append("YNAB budgets: \(s.ynabBudgets.map(\.name).joined(separator: ", "))")
        }

        if s.recentTransactionCount > 0 {
            lines.append("Recent Plaid transactions: \(s.recentTransactionCount) new since last sync.")
        }

        let text = lines.joined(separator: "\n")

        // Sanitize through OutboundPrivacyGuard before exposing to AI prompts
        let sanitized = await OutboundPrivacyGuard.shared.sanitize(text, channel: "financial_briefing")
        switch sanitized {
        case .clean(let t), .redacted(let t, _): return t
        case .blocked(let reason):
            logger.warning("FinancialIntelligenceService: briefing blocked by privacy guard: \(reason)")
            return "Financial briefing blocked by privacy policy."
        }
    }

    // MARK: - Provider Configuration Check

    func isAnyProviderConfigured() async -> Bool {
        let hasKraken   = await krakenService.hasCredentials()
        let hasCoinbase = await coinbaseService.hasCredentials()
        let hasYNAB     = await ynabService.hasCredentials()
        let hasPlaid    = await plaidService.hasCredentials()
        return hasKraken || hasCoinbase || hasYNAB || hasPlaid
    }

    // MARK: - Private Fetch Helpers (error-isolated)

    private func fetchKrakenSafely() async -> [KrakenBalance] {
        guard await krakenService.hasCredentials() else { return [] }
        do {
            return try await krakenService.fetchBalances()
        } catch {
            logger.error("KrakenService sync error: \(error.localizedDescription)")
            await MainActor.run { lastSyncError = "Kraken: \(error.localizedDescription)" }
            return []
        }
    }

    private func fetchCoinbaseSafely() async -> [CoinbaseAccount] {
        guard await coinbaseService.hasCredentials() else { return [] }
        do {
            return try await coinbaseService.fetchAccounts()
        } catch {
            logger.error("CoinbaseService sync error: \(error.localizedDescription)")
            await MainActor.run { lastSyncError = "Coinbase: \(error.localizedDescription)" }
            return []
        }
    }

    private func fetchYNABSafely() async -> [YNABBudgetSummary] {
        guard await ynabService.hasCredentials() else { return [] }
        do {
            return try await ynabService.fetchBudgetSummaries()
        } catch {
            logger.error("YNABService sync error: \(error.localizedDescription)")
            await MainActor.run { lastSyncError = "YNAB: \(error.localizedDescription)" }
            return []
        }
    }

    private func fetchPlaidSafely() async -> [PlaidTransaction] {
        guard await plaidService.hasCredentials() else { return [] }
        do {
            let result = try await plaidService.syncTransactions()
            return result.added
        } catch {
            logger.error("PlaidService sync error: \(error.localizedDescription)")
            await MainActor.run { lastSyncError = "Plaid: \(error.localizedDescription)" }
            return []
        }
    }

    // MARK: - Utilities

    private func estimateCryptoValue(kraken: [KrakenBalance], coinbase: [CoinbaseAccount]) -> Double {
        // Rough USD estimation: USD-labelled balances only (ZUSD = Kraken's USD)
        let krakenUSD = kraken.first(where: { $0.asset == "ZUSD" })?.amount ?? 0
        let coinbaseUSD = coinbase.first(where: { $0.nativeCurrency == "USD" })?.nativeBalance ?? 0
        return krakenUSD + coinbaseUSD
    }

    private func formatAmount(_ value: Double) -> String {
        if value >= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.8f", value)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
