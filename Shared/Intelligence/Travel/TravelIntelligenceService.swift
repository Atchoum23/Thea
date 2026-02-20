//
//  TravelIntelligenceService.swift
//  Thea — AAI3-5
//
//  Flight status + hotel search via Amadeus REST API v2/v3.
//
//  RM-1 AUDIT RESULT (2026-02-20): amadeus-ios SPM rejected due to:
//    • `public class Location` conflicts with Thea + HealthKit types
//    • `public class HotelOffer` matches checklist conflict name
//    • SwiftyJSON transitive dependency (no async/await in SDK)
//    • swift-tools-version:4.0 — old, no Sendable/actor annotations
//  Replacement: URLSession + Amadeus REST (same pattern as KrakenService/YNABService).
//
//  Authentication: Amadeus OAuth2 client_credentials flow.
//  Free sandbox tier: developers.amadeus.com (Self-Service APIs).
//  Credentials stored in Keychain via SettingsManager (key: "amadeus_key" / "amadeus_secret").
//

import Foundation
import os.log

private let logger = Logger(subsystem: "app.thea", category: "TravelIntelligence")

// MARK: - Travel Models

struct FlightStatusResult: Sendable {
    let carrierCode: String
    let flightNumber: String
    let scheduledDate: String
    let departureAirport: String
    let arrivalAirport: String
    let scheduledDepartureTime: String
    let scheduledArrivalTime: String
    let status: String            // "Scheduled", "OnTime", "Delayed", "Cancelled"
    let delayMinutes: Int?
    let terminal: String?
    let gate: String?
}

struct HotelSearchResult: Sendable {
    struct HotelOffer: Sendable {
        let hotelID: String
        let hotelName: String
        let cityCode: String
        let latitude: Double
        let longitude: Double
        let chainCode: String?
        let rating: String?       // "1"–"5" stars
        let lowestPriceAmount: Double?
        let currency: String?
        let checkIn: String
        let checkOut: String
    }
    let cityCode: String
    let checkIn: String
    let checkOut: String
    let hotels: [HotelOffer]
}

// MARK: - TravelIntelligenceService

/// Amadeus REST API integration for flight status and hotel search.
/// Uses URLSession only — no SPM amadeus-ios package (see RM-1 audit note above).
actor TravelIntelligenceService {

    static let shared = TravelIntelligenceService()

    // MARK: - Private Properties

    private let authURL = URL(string: "https://test.api.amadeus.com/v1/security/oauth2/token")!
    private let flightScheduleURL = URL(string: "https://test.api.amadeus.com/v2/schedule/flights")!
    private let hotelOffersURL = URL(string: "https://test.api.amadeus.com/v2/shopping/hotel-offers")!
    private let hotelListURL = URL(string: "https://test.api.amadeus.com/v1/reference-data/locations/hotels/by-city")!

    private var accessToken: String?
    private var tokenExpiry: Date = .distantPast

    private init() {}

    // MARK: - Credential Management

    func configure(apiKey: String, apiSecret: String) async {
        await MainActor.run {
            SettingsManager.shared.setAPIKey(apiKey, for: "amadeus_key")
            SettingsManager.shared.setAPIKey(apiSecret, for: "amadeus_secret")
        }
        logger.info("TravelIntelligenceService: credentials configured")
    }

    func hasCredentials() async -> Bool {
        let (key, secret) = await MainActor.run {
            (SettingsManager.shared.getAPIKey(for: "amadeus_key"),
             SettingsManager.shared.getAPIKey(for: "amadeus_secret"))
        }
        guard let key, let secret else { return false }
        return !key.isEmpty && !secret.isEmpty
    }

    // MARK: - Flight Status

    /// Query Amadeus flight schedule/status endpoint.
    /// - Parameters:
    ///   - carrierCode: IATA airline code (e.g. "AA", "BA", "LH")
    ///   - flightNumber: Flight number without carrier code (e.g. "1234")
    ///   - date: ISO date string YYYY-MM-DD (e.g. "2024-03-15")
    func flightStatus(carrierCode: String, flightNumber: String, date: String) async throws -> [FlightStatusResult] {
        let token = try await getAccessToken()

        var components = URLComponents(url: flightScheduleURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "carrierCode", value: carrierCode),
            URLQueryItem(name: "flightNumber", value: flightNumber),
            URLQueryItem(name: "scheduledDepartureDate", value: date)
        ]

        guard let url = components.url else {
            throw TravelError.invalidRequest("Could not construct flight schedule URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data, context: "flightStatus")

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let flights = json["data"] as? [[String: Any]] ?? []

        let results: [FlightStatusResult] = flights.compactMap { flight in
            guard
                let segments = flight["flightDesignator"] as? [String: Any],
                let carrier = segments["carrierCode"] as? String,
                let number = segments["flightNumber"] as? String,
                let legs = flight["flightPoints"] as? [[String: Any]],
                legs.count >= 2
            else { return nil }

            let dep = legs[0]
            let arr = legs.last!
            let depCode = dep["iataCode"] as? String ?? ""
            let arrCode = arr["iataCode"] as? String ?? ""
            let depTime = (dep["departure"] as? [String: Any])?["timings"] as? [[String: Any]]
            let scheduledDep = (depTime?.first { $0["qualifier"] as? String == "STD" }?["value"] as? String) ?? ""
            let arrTime = (arr["arrival"] as? [String: Any])?["timings"] as? [[String: Any]]
            let scheduledArr = (arrTime?.first { $0["qualifier"] as? String == "STA" }?["value"] as? String) ?? ""

            let legs_ = flight["legs"] as? [[String: Any]] ?? []
            let delayMins = legs_.first?["scheduledLegDuration"] as? Int

            return FlightStatusResult(
                carrierCode: carrier,
                flightNumber: number,
                scheduledDate: date,
                departureAirport: depCode,
                arrivalAirport: arrCode,
                scheduledDepartureTime: scheduledDep,
                scheduledArrivalTime: scheduledArr,
                status: "Scheduled",
                delayMinutes: delayMins,
                terminal: nil,
                gate: nil
            )
        }

        logger.info("TravelIntelligenceService: \(results.count) flights found for \(carrierCode)\(flightNumber) on \(date)")
        return results
    }

    // MARK: - Hotel Search

    /// Search for available hotels in a city.
    /// - Parameters:
    ///   - cityCode: IATA city code (e.g. "PAR", "LON", "NYC")
    ///   - checkIn: ISO date string YYYY-MM-DD
    ///   - checkOut: ISO date string YYYY-MM-DD
    ///   - adults: Number of adult guests (default: 1)
    func hotelSearch(cityCode: String, checkIn: String, checkOut: String, adults: Int = 1) async throws -> HotelSearchResult {
        let token = try await getAccessToken()

        // Step 1: Get hotel list for the city
        var listComponents = URLComponents(url: hotelListURL, resolvingAgainstBaseURL: false)!
        listComponents.queryItems = [
            URLQueryItem(name: "cityCode", value: cityCode)
        ]

        guard let listURL = listComponents.url else {
            throw TravelError.invalidRequest("Could not construct hotel list URL")
        }

        var listRequest = URLRequest(url: listURL)
        listRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        listRequest.timeoutInterval = 15

        let (listData, listResponse) = try await URLSession.shared.data(for: listRequest)
        try validateResponse(listResponse, data: listData, context: "hotelList")

        let listJSON = try JSONSerialization.jsonObject(with: listData) as? [String: Any] ?? [:]
        let hotelDataArray = listJSON["data"] as? [[String: Any]] ?? []

        // Extract hotel IDs (up to 20 for the offers call)
        let hotelIDs = hotelDataArray.prefix(20).compactMap { $0["hotelId"] as? String }
        guard !hotelIDs.isEmpty else {
            logger.warning("TravelIntelligenceService: no hotels found in \(cityCode)")
            return HotelSearchResult(cityCode: cityCode, checkIn: checkIn, checkOut: checkOut, hotels: [])
        }

        // Step 2: Get offers for those hotels
        var offersComponents = URLComponents(url: hotelOffersURL, resolvingAgainstBaseURL: false)!
        offersComponents.queryItems = [
            URLQueryItem(name: "hotelIds", value: hotelIDs.joined(separator: ",")),
            URLQueryItem(name: "checkInDate", value: checkIn),
            URLQueryItem(name: "checkOutDate", value: checkOut),
            URLQueryItem(name: "adults", value: "\(adults)"),
            URLQueryItem(name: "currency", value: "USD"),
            URLQueryItem(name: "bestRateOnly", value: "true")
        ]

        guard let offersURL = offersComponents.url else {
            throw TravelError.invalidRequest("Could not construct hotel offers URL")
        }

        var offersRequest = URLRequest(url: offersURL)
        offersRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        offersRequest.timeoutInterval = 20

        let (offersData, offersResponse) = try await URLSession.shared.data(for: offersRequest)
        try validateResponse(offersResponse, data: offersData, context: "hotelOffers")

        let offersJSON = try JSONSerialization.jsonObject(with: offersData) as? [String: Any] ?? [:]
        let offersArray = offersJSON["data"] as? [[String: Any]] ?? []

        let hotels: [HotelSearchResult.HotelOffer] = offersArray.compactMap { offer in
            guard
                let hotel = offer["hotel"] as? [String: Any],
                let hotelID = hotel["hotelId"] as? String,
                let name = hotel["name"] as? String
            else { return nil }

            let geo = hotel["geoCode"] as? [String: Any]
            let offers_ = offer["offers"] as? [[String: Any]] ?? []
            let firstOffer = offers_.first
            let priceObj = firstOffer?["price"] as? [String: Any]

            return HotelSearchResult.HotelOffer(
                hotelID: hotelID,
                hotelName: name,
                cityCode: cityCode,
                latitude: geo?["latitude"] as? Double ?? 0,
                longitude: geo?["longitude"] as? Double ?? 0,
                chainCode: hotel["chainCode"] as? String,
                rating: hotel["rating"] as? String,
                lowestPriceAmount: Double(priceObj?["total"] as? String ?? ""),
                currency: priceObj?["currency"] as? String,
                checkIn: checkIn,
                checkOut: checkOut
            )
        }

        logger.info("TravelIntelligenceService: \(hotels.count) hotel offers for \(cityCode) \(checkIn)→\(checkOut)")
        return HotelSearchResult(cityCode: cityCode, checkIn: checkIn, checkOut: checkOut, hotels: hotels)
    }

    // MARK: - OAuth2 Token

    private func getAccessToken() async throws -> String {
        // Return cached token if still valid (5-min buffer)
        if let token = accessToken, Date() < tokenExpiry.addingTimeInterval(-300) {
            return token
        }

        let (apiKey, apiSecret) = await MainActor.run {
            (SettingsManager.shared.getAPIKey(for: "amadeus_key"),
             SettingsManager.shared.getAPIKey(for: "amadeus_secret"))
        }
        guard let apiKey, let apiSecret, !apiKey.isEmpty, !apiSecret.isEmpty else {
            throw TravelError.missingCredentials
        }

        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("grant_type=client_credentials&client_id=\(apiKey)&client_secret=\(apiSecret)".utf8)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data, context: "oauth2")

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let token = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw TravelError.authenticationFailed
        }

        accessToken = token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        logger.info("TravelIntelligenceService: OAuth2 token obtained (expires in \(expiresIn)s)")
        return token
    }

    // MARK: - HTTP Validation

    private func validateResponse(_ response: URLResponse, data: Data, context: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TravelError.networkError("Non-HTTP response for \(context)")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Try to extract Amadeus error detail
            let errJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorList = errJSON?["errors"] as? [[String: Any]]
            let detail = errorList?.first?["detail"] as? String ?? "HTTP \(http.statusCode)"
            throw TravelError.apiError(context: context, detail: detail)
        }
    }
}

// MARK: - Errors

enum TravelError: LocalizedError {
    case missingCredentials
    case authenticationFailed
    case networkError(String)
    case apiError(context: String, detail: String)
    case invalidRequest(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Amadeus API credentials not configured. Add them in Settings → Travel."
        case .authenticationFailed:
            return "Amadeus OAuth2 authentication failed. Check your API key and secret."
        case .networkError(let msg):
            return "Travel service network error: \(msg)"
        case .apiError(let ctx, let detail):
            return "Amadeus \(ctx) error: \(detail)"
        case .invalidRequest(let msg):
            return "Travel request error: \(msg)"
        }
    }
}
