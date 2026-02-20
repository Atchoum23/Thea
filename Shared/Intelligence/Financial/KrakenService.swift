// KrakenService.swift
// Thea — Financial Intelligence Hub (AAC3-3)
//
// Swift actor for Kraken crypto exchange REST API.
// Uses URLSession + CryptoKit (HMAC-SHA512) for authenticated requests.
// No SPM dependency — avoids CryptoSwift RawSpan incompatibility on macOS 26 SDK.
//
// API Reference: https://docs.kraken.com/rest/
// Credentials: apiKey + secretKey stored in Keychain via FinancialCredentialStore.

import Foundation
import CryptoKit
import OSLog

// MARK: - Kraken Balance Model

struct KrakenBalance: Sendable {
    let asset: String       // e.g. "XXBT" (BTC), "ZUSD" (USD), "XETH" (ETH)
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

    private let logger = Logger(subsystem: "com.thea.app", category: "KrakenService") // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    private let baseURL = "https://api.kraken.com"
    private let apiVersion = "0"

    private init() {}

    // MARK: - Credential Management

    /// Persist Kraken API credentials in Keychain.
    func saveCredentials(apiKey: String, secretKey: String) {
        FinancialCredentialStore.save(token: apiKey, for: FinancialAPIProvider.kraken.rawValue, suffix: "apiKey")
        FinancialCredentialStore.save(token: secretKey, for: FinancialAPIProvider.kraken.rawValue, suffix: "secretKey")
        logger.info("KrakenService: credentials saved")
    }

    /// Whether valid Kraken credentials are stored.
    func hasCredentials() -> Bool {
        FinancialCredentialStore.load(for: FinancialAPIProvider.kraken.rawValue, suffix: "apiKey") != nil
    }

    // MARK: - Fetch Balances

    /// Fetch account balances for all assets.
    func fetchBalances() async throws -> [KrakenBalance] {
        let response = try await privateRequest(path: "/Balance", params: [:])
        guard let result = response["result"] as? [String: Any] else {
            throw KrakenServiceError.invalidResponse
        }
        return result.compactMap { key, value -> KrakenBalance? in
            guard let amountStr = value as? String, let amount = Double(amountStr) else { return nil }
            return KrakenBalance(asset: key, amount: amount)
        }
        .filter { $0.amount > 0 }
        .sorted { $0.asset < $1.asset }
    }

    // MARK: - Fetch Recent Trades

    /// Fetch recent trade history (up to 50 most recent trades).
    func fetchRecentTrades() async throws -> [KrakenTrade] {
        let response = try await privateRequest(path: "/TradesHistory", params: [:])
        guard let result = response["result"] as? [String: Any],
              let trades = result["trades"] as? [String: [String: Any]] else {
            return []
        }
        return trades.compactMap { txid, info -> KrakenTrade? in
            guard
                let pair   = info["pair"]  as? String,
                let time   = info["time"]  as? Double,
                let type   = info["type"]  as? String,
                let price  = info["price"] as? String,
                let volume = info["vol"]   as? String,
                let cost   = info["cost"]  as? String
            else { return nil }
            return KrakenTrade(
                txid: txid,
                pair: pair,
                time: time,
                type: type,
                price: Double(price)  ?? 0,
                volume: Double(volume) ?? 0,
                cost: Double(cost)   ?? 0
            )
        }
        .sorted { $0.time > $1.time }
        .prefix(50)
        .map { $0 }
    }

    // MARK: - Signed Private Request

    private func privateRequest(path: String, params: [String: String]) async throws -> [String: Any] {
        guard
            let apiKey    = FinancialCredentialStore.load(for: FinancialAPIProvider.kraken.rawValue, suffix: "apiKey"),
            let secretKey = FinancialCredentialStore.load(for: FinancialAPIProvider.kraken.rawValue, suffix: "secretKey"),
            !apiKey.isEmpty, !secretKey.isEmpty
        else {
            throw KrakenServiceError.missingCredentials
        }

        let nonce = String(UInt64(Date().timeIntervalSince1970 * 1000000))
        var postParams = params
        postParams["nonce"] = nonce
        let postData = postParams.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "&")

        let urlPath = "/\(apiVersion)/private\(path)"
        let signature = try makeSignature(path: urlPath, nonce: nonce, postData: postData, secretKey: secretKey)

        var req = URLRequest(url: URL(string: "\(baseURL)\(urlPath)")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "API-Key")
        req.setValue(signature, forHTTPHeaderField: "API-Sign")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = postData.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw KrakenServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let errors = json["error"] as? [String], !errors.isEmpty {
            throw KrakenServiceError.apiError(errors.joined(separator: ", "))
        }
        return json
    }

    // MARK: - HMAC-SHA512 Signature (CryptoKit — no CryptoSwift dependency)

    private func makeSignature(path: String, nonce: String, postData: String, secretKey: String) throws -> String {
        // Kraken signature: Base64(HMAC-SHA512(path + SHA256(nonce + postData), Base64Decode(secret)))
        guard let secretData = Data(base64Encoded: secretKey) else {
            throw KrakenServiceError.signatureError("Invalid Base64 secret key")
        }

        // SHA256(nonce + postData)
        let nonceAndData = (nonce + postData).data(using: .utf8)!
        let sha256Hash = SHA256.hash(data: nonceAndData)

        // path bytes + sha256 bytes
        let pathData = path.data(using: .utf8)!
        var messageData = pathData
        messageData.append(contentsOf: sha256Hash)

        // HMAC-SHA512 with Base64-decoded secret
        let key = SymmetricKey(data: secretData)
        let mac = HMAC<SHA512>.authenticationCode(for: messageData, using: key)
        return Data(mac).base64EncodedString()
    }
}

// MARK: - Error

enum KrakenServiceError: LocalizedError {
    case missingCredentials
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case signatureError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:   return "Kraken API credentials not configured. Please add them in Settings → Financial."
        case .invalidResponse:      return "Kraken returned an unexpected response format."
        case .httpError(let code):  return "Kraken HTTP error \(code)."
        case .apiError(let msg):    return "Kraken API error: \(msg)"
        case .signatureError(let m): return "Kraken signature error: \(m)"
        }
    }
}
