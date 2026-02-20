// PlaidService.swift
// Thea — Financial Intelligence Hub (AAC3-6)
//
// URLSession REST actor for Plaid /transactions/sync delta endpoint.
// Credentials: PLAID-CLIENT-ID + PLAID-SECRET + access_token from Keychain.
// Uses cursor-based delta sync to efficiently fetch only new/modified/removed transactions.

import Foundation
import OSLog

// MARK: - Plaid Transaction Model

struct PlaidTransaction: Sendable {
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let transactionID: String
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let accountID: String
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let amount: Double          // Negative = debit, positive = credit (Plaid convention inverted)
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let date: String            // ISO date e.g. "2024-03-15"
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let name: String            // Payee name
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let merchantName: String?
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let category: [String]      // Hierarchical category e.g. ["Food and Drink", "Restaurants"]
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let pending: Bool
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let currencyCode: String
}

// MARK: - Plaid Sync Result

struct PlaidSyncResult: Sendable {
    let added: [PlaidTransaction]
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let modified: [PlaidTransaction]
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let removedIDs: [String]
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let nextCursor: String
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let hasMore: Bool
}

// MARK: - PlaidService

actor PlaidService {
    static let shared = PlaidService()

    private let logger = Logger(subsystem: "com.thea.app", category: "PlaidService")

    /// Plaid environment: "sandbox", "development", or "production"
    private let environment: String = "production"
    private var baseURL: URL {
        URL(string: "https://\(environment).plaid.com")!
    }

    /// Cursor cache for delta sync. Key: accessToken prefix (first 16 chars).
    private var cursorCache: [String: String] = [:]

    private init() {}

    // MARK: - Credential Management

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    /// Persist Plaid credentials in Keychain.
    /// - Parameters:
    ///   - clientID: Your Plaid client_id
    ///   - secret: Your Plaid secret for the configured environment
    ///   - accessToken: The item's access_token (obtained via Plaid Link)
    func saveCredentials(clientID: String, secret: String, accessToken: String) {
        FinancialCredentialStore.save(token: clientID, for: FinancialAPIProvider.plaid.rawValue, suffix: "clientID")
        FinancialCredentialStore.save(token: secret, for: FinancialAPIProvider.plaid.rawValue, suffix: "secret")
        FinancialCredentialStore.save(token: accessToken, for: FinancialAPIProvider.plaid.rawValue, suffix: "accessToken")
        logger.info("PlaidService: credentials saved")
    }

    /// Whether Plaid credentials are configured.
    func hasCredentials() -> Bool {
        FinancialCredentialStore.load(for: FinancialAPIProvider.plaid.rawValue, suffix: "clientID") != nil
    }

    // MARK: - Transactions Sync (Delta)

    /// Fetch new/modified/removed transactions using Plaid's /transactions/sync endpoint.
    /// Automatically pages through all results when hasMore is true.
    /// - Returns: Full sync result (all pages merged).
    func syncTransactions() async throws -> PlaidSyncResult {
        guard
            let clientID    = FinancialCredentialStore.load(for: FinancialAPIProvider.plaid.rawValue, suffix: "clientID"),
            let secret      = FinancialCredentialStore.load(for: FinancialAPIProvider.plaid.rawValue, suffix: "secret"),
            let accessToken = FinancialCredentialStore.load(for: FinancialAPIProvider.plaid.rawValue, suffix: "accessToken"),
            !clientID.isEmpty, !secret.isEmpty, !accessToken.isEmpty
        else {
            throw PlaidServiceError.missingCredentials
        }

        let cursorKey = String(accessToken.prefix(16))
        let cursor = cursorCache[cursorKey]

        var allAdded: [PlaidTransaction] = []
        var allModified: [PlaidTransaction] = []
        var allRemovedIDs: [String] = []
        var nextCursor = cursor ?? ""
        var hasMore = true

        while hasMore {
            let payload: [String: Any] = [
                "client_id": clientID,
                "secret": secret,
                "access_token": accessToken,
                "cursor": nextCursor,
                "count": 500
            ]

            let data = try await postJSON(path: "/transactions/sync", body: payload)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            if let errorDict = json["error"] as? [String: Any],
               let errorCode = errorDict["error_code"] as? String {
                throw PlaidServiceError.apiError(errorCode)
            }

            let added    = parsePlaidTransactions(from: json["added"]    as? [[String: Any]] ?? [])
            let modified = parsePlaidTransactions(from: json["modified"] as? [[String: Any]] ?? [])
            let removed  = (json["removed"] as? [[String: Any]] ?? []).compactMap { $0["transaction_id"] as? String }

            allAdded.append(contentsOf: added)
            allModified.append(contentsOf: modified)
            allRemovedIDs.append(contentsOf: removed)

            nextCursor = (json["next_cursor"] as? String) ?? nextCursor
            hasMore    = (json["has_more"] as? Bool) ?? false
        }

        // Persist cursor for next call
        cursorCache[cursorKey] = nextCursor

        logger.debug("PlaidService: +\(allAdded.count) added, ~\(allModified.count) modified, -\(allRemovedIDs.count) removed")

        return PlaidSyncResult(
            added: allAdded,
            modified: allModified,
            removedIDs: allRemovedIDs,
            nextCursor: nextCursor,
            hasMore: false
        )
    }

    // MARK: - Reset Delta Sync

    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    /// Clear the cursor cache to force a full sync on the next call.
    func resetSync() {
        cursorCache.removeAll()
        logger.info("PlaidService: cursor cache cleared")
    }

    // MARK: - HTTP Layer

    private func postJSON(path: String, body: [String: Any]) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw PlaidServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw PlaidServiceError.httpError(http.statusCode)
        }
        return data
    }

    // MARK: - Parsing

    private func parsePlaidTransactions(from array: [[String: Any]]) -> [PlaidTransaction] {
        array.compactMap { item -> PlaidTransaction? in
            guard
                let txID      = item["transaction_id"] as? String,
                let accountID = item["account_id"]     as? String,
                let amount    = item["amount"]          as? Double,
                let date      = item["date"]            as? String,
                let name      = item["name"]            as? String,
                let pending   = item["pending"]         as? Bool
            else { return nil }

            let merchantName = item["merchant_name"] as? String
            let category     = (item["category"] as? [String]) ?? []
            let currencyCode = (item["iso_currency_code"] as? String) ?? "USD"

            return PlaidTransaction(
                transactionID: txID,
                accountID: accountID,
                amount: amount,
                date: date,
                name: name,
                merchantName: merchantName,
                category: category,
                pending: pending,
                currencyCode: currencyCode
            )
        }
    }
}

// MARK: - Error

enum PlaidServiceError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:   return "Plaid credentials not configured. Please add them in Settings → Financial."
        case .invalidResponse:      return "Plaid returned an invalid response."
        case .httpError(let code):  return "Plaid HTTP error \(code)."
        case .apiError(let msg):    return "Plaid API error: \(msg)"
        }
    }
}
