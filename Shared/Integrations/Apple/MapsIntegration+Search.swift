// MapsIntegration+Search.swift
// Thea V2
//
// Location search capabilities for MapsIntegration

import Foundation
import OSLog

#if canImport(MapKit)
@preconcurrency import MapKit
#endif

// MARK: - Location Search

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
extension MapsIntegration {

    /// Searches for locations matching the given criteria.
    ///
    /// Uses MapKit's `MKLocalSearch` to find places by natural language query,
    /// coordinate proximity, category, or a combination. Results are optionally
    /// capped by the criteria's `limit`.
    ///
    /// - Parameter criteria: Search parameters (query, center, radius, category, etc.).
    /// - Returns: An array of matching ``TheaLocation`` instances.
    /// - Throws: ``MapsError/unavailable`` if MapKit is not available.
    public func searchLocations(criteria: LocationSearchCriteria) async throws -> [TheaLocation] {
        #if canImport(MapKit)
        let request = MKLocalSearch.Request()

        if let query = criteria.query {
            request.naturalLanguageQuery = query
        }

        if let region = criteria.region {
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: region.latitudeDelta,
                    longitudeDelta: region.longitudeDelta
                )
            )
        } else if let center = criteria.center {
            let radius = criteria.radius ?? 5000
            let span = radius / 111000  // Approximate degrees
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: center.latitude,
                    longitude: center.longitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: span,
                    longitudeDelta: span
                )
            )
        }

        // Set result types
        if #available(macOS 12.0, iOS 15.0, *) {
            var resultTypes: MKLocalSearch.ResultType = []
            if criteria.resultTypes.contains(.address) {
                resultTypes.insert(.address)
            }
            if criteria.resultTypes.contains(.pointOfInterest) {
                resultTypes.insert(.pointOfInterest)
            }
            request.resultTypes = resultTypes
        }

        // Set point of interest filter if category specified
        if let category = criteria.category {
            if #available(macOS 13.0, iOS 16.0, *) {
                if let mkCategory = mapCategoryToMKCategory(category) {
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [mkCategory])
                }
            }
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        var locations = response.mapItems.map { mapItem -> TheaLocation in
            convertToTheaLocation(mapItem, searchCenter: criteria.center)
        }

        // Apply limit
        if let limit = criteria.limit, locations.count > limit {
            locations = Array(locations.prefix(limit))
        }

        logger.info("Found \(locations.count) locations for query: \(criteria.query ?? "nearby")")
        return locations
        #else
        throw MapsError.unavailable
        #endif
    }

    /// Searches for locations matching a street address.
    ///
    /// Convenience wrapper around ``searchLocations(criteria:)`` that restricts
    /// results to the `.address` type.
    ///
    /// - Parameter address: The address string to search for.
    /// - Returns: An array of matching ``TheaLocation`` instances.
    /// - Throws: ``MapsError/unavailable`` if MapKit is not available.
    public func searchAddress(_ address: String) async throws -> [TheaLocation] {
        let criteria = LocationSearchCriteria(
            query: address,
            resultTypes: [.address]
        )
        return try await searchLocations(criteria: criteria)
    }

    /// Searches for nearby points of interest around a coordinate.
    ///
    /// Convenience wrapper around ``searchLocations(criteria:)`` that restricts
    /// results to the `.pointOfInterest` type within the given radius.
    ///
    /// - Parameters:
    ///   - center: The center coordinate to search around.
    ///   - category: Optional category filter. Pass `nil` for all categories.
    ///   - radius: Search radius in meters. Defaults to 1000.
    ///   - limit: Maximum number of results. Defaults to 20.
    /// - Returns: An array of matching ``TheaLocation`` instances.
    /// - Throws: ``MapsError/unavailable`` if MapKit is not available.
    public func searchNearby(
        center: TheaCoordinate,
        category: LocationCategory? = nil,
        radius: Double = 1000,
        limit: Int? = 20
    ) async throws -> [TheaLocation] {
        let criteria = LocationSearchCriteria(
            center: center,
            radius: radius,
            category: category,
            resultTypes: [.pointOfInterest],
            limit: limit
        )
        return try await searchLocations(criteria: criteria)
    }
}
