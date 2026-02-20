// KrakenService.swift
// Thea — Financial Intelligence Hub (AAC3-3)
//
// Swift actor wrapping lukepistrol/KrakenAPI for Kraken crypto exchange.
// Fetches account balances and recent trade history.
// Credentials: apiKey + privateKey stored in Keychain via FinancialCredentialStore.

import Foundation
import KrakenAPI
import OSLog

// MARK: - Kraken Balance Model

struct KrakenBalance: Sendable {
    let asset: String       // e.g. "XXBT", "ZUSD", "XETH"
    let amount: Double
}

// MARK: - Kraken Trade Summary

struct KrakenTrade: Sendable {
    let txid: String
    let pair: String
    let time: Double        // Unix timestamp
    let type: String        // "buy" or "sell"
    let price: Double
    let volume: Double
    let cost: Double
}

// MARK: - KrakenService

actor KrakenService {
    static let shared = KrakenService()

    private let logger = Logger(subsystem: "com.thea.app", category: "KrakenService")

    // MARK: - Configuration

    /// Credential suffix constants for FinancialCredentialStore
    private enum CredentialKey {
        static let apiKey    = "apiKey"
        static let secretKey = "secretKey"
    }

    private var client: Kraken? {
        guard
            let apiKey = FinancialCredentialStore.load(for: FinancialProvider.kraken.rawValue, suffix: CredentialKey.apiKey),
            let secretKey = FinancialCredentialStore.load(for: FinancialProvider.kraken.rawValue, suffix: CredentialKey.secretKey),
            !apiKey.isEmpty, !secretKey.isEmpty
        else { return nil }

        let creds = Kraken.Credentials(apiKey: apiKey, privateKey: secretKey)
        return Kraken(credentials: creds)
    }

    private init() {}

    // MARK: - Credential Management

    /// Store Kraken API credentials in Keychain.
    func saveCredentials(apiKey: String, secretKey: String) {
        FinancialCredentialStore.save(token: apiKey, for: FinancialProvider.kraken.rawValue, suffix: CredentialKey.apiKey)
        FinancialCredentialStore.save(token: secretKey, for: FinancialProvider.kraken.rawValue, suffix: CredentialKey.secretKey)
        logger.info("KrakenService: credentials saved")
    }

    /// Whether valid credentials are stored.
    func hasCredentials() -> Bool {
        FinancialCredentialStore.load(for: FinancialProvider.kraken.rawValue, suffix: CredentialKey.apiKey) != nil
    }

    // MARK: - Fetch Balances

    /// Fetch account balances for all assets.
    /// - Returns: Array of `KrakenBalance`, or throws on missing credentials / API error.
    func fetchBalances() async throws -> [KrakenBalance] {
        guard let kraken = client else {
            logger.warning("KrakenService: no credentials configured")
            throw KrakenServiceError.missingCredentials
        }

        let result = await kraken.accountBalance()
        switch result {
        case .success(let dict):
            return dict.compactMap { key, value -> KrakenBalance? in
                guard let amountString = value as? String,
                      let amount = Double(amountString) else { return nil }
                return KrakenBalance(asset: key, amount: amount)
            }
            .filter { $0.amount > 0 }
            .sorted { $0.asset < $1.asset }

        case .failure(let error):
            logger.error("KrakenService fetchBalances failed: \(error.localizedDescription)")
            throw KrakenServiceError.apiError(error.localizedDescription)
        }
    }

    // MARK: - Fetch Recent Trades

    /// Fetch recent trade history (up to 50 most recent trades).
    /// - Returns: Array of `KrakenTrade` sorted by time descending.
    func fetchRecentTrades() async throws -> [KrakenTrade] {
        guard let kraken = client else {
            throw KrakenServiceError.missingCredentials
        }

        let result = await kraken.tradesHistory()
        switch result {
        case .success(let dict):
            guard let trades = dict["trades"] as? [String: [String: Any]] else {
                return []
            }
            return trades.compactMap { txid, info -> KrakenTrade? in
                guard
                    let pair    = info["pair"]    as? String,
                    let time    = info["time"]    as? Double,
                    let type    = info["type"]    as? String,
                    let price   = info["price"]   as? String,
                    let volume  = info["vol"]     as? String,
                    let cost    = info["cost"]    as? String
                else { return nil }
                return KrakenTrade(
                    txid:   txid,
                    pair:   pair,
                    time:   time,
                    type:   type,
                    price:  Double(price)  ?? 0,
                    volume: Double(volume) ?? 0,
                    cost:   Double(cost)   ?? 0
                )
            }
            .sorted { $0.time > $1.time }
            .prefix(50)
            .map { $0 }

        case .failure(let error):
            logger.error("KrakenService fetchRecentTrades failed: \(error.localizedDescription)")
            throw KrakenServiceError.apiError(error.localizedDescription)
        }
    }
}

// MARK: - Error

enum KrakenServiceError: LocalizedError {
    case missingCredentials
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Kraken API credentials not configured. Please add them in Settings → Financial."
        case .apiError(let msg):  return "Kraken API error: \(msg)"
        }
    }
}
