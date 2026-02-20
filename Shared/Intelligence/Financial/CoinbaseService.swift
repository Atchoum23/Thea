// CoinbaseService.swift
// Thea — Financial Intelligence Hub (AAC3-4)
//
// URLSession REST actor for Coinbase Advanced Trade / Coinbase API v2.
// Header CB-VERSION: 2024-09-01. OAuth2 or API key authentication.
// Credentials stored in Keychain via FinancialCredentialStore.
// Required scopes: wallet:accounts:read, wallet:transactions:read

import Foundation
import OSLog

// MARK: - Coinbase Account Model

struct CoinbaseAccount: Sendable {
    let id: String
    let name: String
    let currency: String
    let balance: Double
    let nativeBalance: Double
    let nativeCurrency: String
}

// MARK: - Coinbase Transaction Model

struct CoinbaseTransaction: Sendable {
    let id: String
    let type: String      // "send", "receive", "buy", "sell", etc.
    let status: String
    let amount: Double
    let currency: String
    let nativeAmount: Double
    let nativeCurrency: String
    let description: String
    let createdAt: Date
}

// MARK: - CoinbaseService

actor CoinbaseService {
    static let shared = CoinbaseService()

    private let logger = Logger(subsystem: "com.thea.app", category: "CoinbaseService")
    private let baseURL = URL(string: "https://api.coinbase.com/v2")!
    private let apiVersion = "2024-09-01"

    private init() {}

    // MARK: - Credential Management

    /// Store API key and secret in Keychain.
    func saveCredentials(apiKey: String, apiSecret: String) {
        FinancialCredentialStore.save(token: apiKey,    for: FinancialAPIProvider.coinbase.rawValue, suffix: "apiKey")
        FinancialCredentialStore.save(token: apiSecret, for: FinancialAPIProvider.coinbase.rawValue, suffix: "apiSecret")
        logger.info("CoinbaseService: credentials saved")
    }

    /// Whether valid credentials are stored.
    func hasCredentials() -> Bool {
        FinancialCredentialStore.load(for: FinancialAPIProvider.coinbase.rawValue, suffix: "apiKey") != nil
    }

    // MARK: - Fetch Accounts

    /// Fetch all Coinbase wallets/accounts.
    func fetchAccounts() async throws -> [CoinbaseAccount] {
        let data = try await request(path: "/accounts")
        return try parseAccounts(from: data)
    }

    // MARK: - Fetch Transactions

    /// Fetch recent transactions for a specific account.
    /// - Parameter accountID: Coinbase account ID from `fetchAccounts()`.
    func fetchTransactions(accountID: String) async throws -> [CoinbaseTransaction] {
        let data = try await request(path: "/accounts/\(accountID)/transactions")
        return try parseTransactions(from: data)
    }

    // MARK: - HTTP Layer

    private func request(path: String) async throws -> Data {
        guard
            let apiKey = FinancialCredentialStore.load(for: FinancialAPIProvider.coinbase.rawValue, suffix: "apiKey"),
            !apiKey.isEmpty
        else {
            throw CoinbaseServiceError.missingCredentials
        }

        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(apiVersion, forHTTPHeaderField: "CB-VERSION")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw CoinbaseServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw CoinbaseServiceError.httpError(http.statusCode)
        }
        return data
    }

    // MARK: - Parsing

    private func parseAccounts(from data: Data) throws -> [CoinbaseAccount] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]] else { return [] }

        return dataArray.compactMap { item -> CoinbaseAccount? in
            guard
                let id   = item["id"]   as? String,
                let name = item["name"] as? String,
                let balance  = item["balance"]        as? [String: Any],
                let native   = item["native_balance"]  as? [String: Any],
                let currency = balance["currency"]     as? String,
                let balStr   = balance["amount"]       as? String,
                let nativeCur = native["currency"]    as? String,
                let nativeStr = native["amount"]      as? String
            else { return nil }
            return CoinbaseAccount(
                id:             id,
                name:           name,
                currency:       currency,
                balance:        Double(balStr)    ?? 0,
                nativeBalance:  Double(nativeStr) ?? 0,
                nativeCurrency: nativeCur
            )
        }
    }

    private func parseTransactions(from data: Data) throws -> [CoinbaseTransaction] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]] else { return [] }

        let iso = ISO8601DateFormatter()
        return dataArray.compactMap { item -> CoinbaseTransaction? in
            guard
                let id     = item["id"]     as? String,
                let type   = item["type"]   as? String,
                let status = item["status"] as? String,
                let amount = item["amount"]        as? [String: Any],
                let native = item["native_amount"] as? [String: Any],
                let cur    = amount["currency"]    as? String,
                let amtStr = amount["amount"]      as? String,
                let natCur = native["currency"]    as? String,
                let natStr = native["amount"]      as? String,
                let createdStr = item["created_at"] as? String
            else { return nil }
            let desc = (item["description"] as? String) ?? ""
            let date = iso.date(from: createdStr) ?? Date.distantPast
            return CoinbaseTransaction(
                id:             id,
                type:           type,
                status:         status,
                amount:         Double(amtStr) ?? 0,
                currency:       cur,
                nativeAmount:   Double(natStr) ?? 0,
                nativeCurrency: natCur,
                description:    desc,
                createdAt:      date
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Error

enum CoinbaseServiceError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:   return "Coinbase credentials not configured. Please add them in Settings → Financial."
        case .invalidResponse:      return "Coinbase returned an invalid response."
        case .httpError(let code):  return "Coinbase HTTP error \(code)."
        }
    }
}
