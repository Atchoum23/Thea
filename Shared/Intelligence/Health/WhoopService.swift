// WhoopService.swift
// Thea — AAE3: Third-Party Health Wearables
//
// Whoop REST integration. Fetches the latest recovery score from
// api.prod.whoop.com/developer/v1/cycle/collection.
// OAuth2 Bearer token stored in Keychain via SettingsManager (key: "whoop").
//
// Whoop Developer Portal: https://developer.whoop.com/

import Foundation
import OSLog

// MARK: - WhoopRecovery

struct WhoopRecovery: Sendable {
    let recovery_score: Int         // 0..100 — overall recovery %
    // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
    let hrv_rmssd_milli: Double     // HRV RMSSD in milliseconds
}

// MARK: - WhoopService

actor WhoopService {
    static let shared = WhoopService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "WhoopService")
    private let baseURL = "https://api.prod.whoop.com/developer/v1/cycle/collection"

    // MARK: - Public API

    /// Fetch the most recent Whoop recovery score.
    /// - Throws: WhoopError.missingToken if no OAuth2 token is configured.
    func fetchRecovery() async throws -> WhoopRecovery {
        guard let token = await loadToken(), !token.isEmpty else {
            throw WhoopError.missingToken
        }

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "nextToken", value: nil)
        ]

        guard let url = components.url else {
            throw WhoopError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Whoop API HTTP \(httpResponse.statusCode)")
            throw WhoopError.httpError(httpResponse.statusCode)
        }

        return try parseRecovery(from: data)
    }

    // MARK: - Private Helpers

    private func loadToken() async -> String? {
        await MainActor.run { SettingsManager.shared.getAPIKey(for: "whoop") }
    }

    private func parseRecovery(from data: Data) throws -> WhoopRecovery {
        // Whoop cycle response: { "records": [ { "score": { "recovery_score": 85, "hrv_rmssd_milli": 62.5, ... }, ... } ] }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let records = json["records"] as? [[String: Any]],
            let first = records.first,
            let score = first["score"] as? [String: Any]
        else {
            throw WhoopError.parseError
        }

        let recoveryScore = score["recovery_score"] as? Int ?? 0
        let hrv = score["hrv_rmssd_milli"] as? Double ?? 0.0

        logger.info("Whoop recovery: score=\(recoveryScore) hrv_rmssd=\(hrv, format: .fixed(precision: 1))ms")
        return WhoopRecovery(recovery_score: recoveryScore, hrv_rmssd_milli: hrv)
    }

    // MARK: - Errors

    enum WhoopError: Error, LocalizedError {
        case missingToken
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case parseError

        var errorDescription: String? {
            switch self {
            case .missingToken:      return "Whoop OAuth2 token not configured"
            case .invalidURL:        return "Invalid Whoop API URL"
            case .invalidResponse:   return "Invalid response from Whoop API"
            case .httpError(let c):  return "Whoop API returned HTTP \(c)"
            case .parseError:        return "Failed to parse Whoop recovery data"
            }
        }
    }
}
