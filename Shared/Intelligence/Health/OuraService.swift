// OuraService.swift
// Thea — AAE3: Third-Party Health Wearables
//
// Oura Ring v2 REST integration. Fetches daily readiness from
// api.ouraring.com/v2/usercollection/daily_readiness.
// Personal Access Token stored in Keychain via SettingsManager (key: "oura").
//
// OAuth2 dev-tier token: https://cloud.ouraring.com/personal-access-tokens

import Foundation
import OSLog

// MARK: - OuraReadiness

struct OuraReadiness: Sendable {
    let score: Int      // 0..100 — overall readiness score
    let hrv: Int        // HRV balance contributor (0..100 scale)
    let date: String    // YYYY-MM-DD
}

// MARK: - OuraService

actor OuraService {
    static let shared = OuraService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "OuraService")
    private let baseURL = "https://api.ouraring.com/v2/usercollection/daily_readiness"

    // MARK: - Public API

    /// Fetch today's readiness from Oura Ring v2.
    /// - Throws: OuraError.missingToken if no PAT is configured.
    func fetchReadiness() async throws -> OuraReadiness {
        guard let token = await loadToken(), !token.isEmpty else {
            throw OuraError.missingToken
        }

        let today = todayDateString()
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: today),
            URLQueryItem(name: "end_date", value: today)
        ]

        guard let url = components.url else {
            throw OuraError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OuraError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Oura API HTTP \(httpResponse.statusCode)")
            throw OuraError.httpError(httpResponse.statusCode)
        }

        return try parseReadiness(from: data)
    }

    // MARK: - Private Helpers

    private func loadToken() async -> String? {
        await MainActor.run { SettingsManager.shared.getAPIKey(for: "oura") }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func parseReadiness(from data: Data) throws -> OuraReadiness {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["data"] as? [[String: Any]],
            let first = items.first
        else {
            throw OuraError.parseError
        }

        let score = first["score"] as? Int ?? 0
        let contributors = first["contributors"] as? [String: Any] ?? [:]
        let hrv = contributors["hrv_balance"] as? Int ?? 0
        let date = first["day"] as? String ?? ""

        logger.info("Oura readiness: score=\(score) hrv=\(hrv) date=\(date)")
        return OuraReadiness(score: score, hrv: hrv, date: date)
    }

    // MARK: - Errors

    enum OuraError: Error, LocalizedError {
        case missingToken
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case parseError

        var errorDescription: String? {
            switch self {
            case .missingToken:      return "Oura personal access token not configured"
            case .invalidURL:        return "Invalid Oura API URL"
            case .invalidResponse:   return "Invalid response from Oura API"
            case .httpError(let c):  return "Oura API returned HTTP \(c)"
            case .parseError:        return "Failed to parse Oura readiness data"
            }
        }
    }
}
