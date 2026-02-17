// MapsIntegration+Geocoding.swift
// Thea V2
//
// Forward and reverse geocoding for MapsIntegration

import Foundation
import OSLog

#if canImport(MapKit)
@preconcurrency import MapKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Geocoding

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
extension MapsIntegration {

    /// Forward-geocodes an address string to a location with coordinates.
    ///
    /// Uses `MKLocalSearch` to resolve the address. On macOS/iOS 26+,
    /// extracts coordinates from `MKMapItem.location`; on earlier versions,
    /// falls back to `MKMapItem.placemark.coordinate`.
    ///
    /// - Parameter address: The address string to geocode (e.g. "1 Apple Park Way, Cupertino").
    /// - Returns: A ``TheaLocation`` with resolved coordinates, or `nil` if no match was found.
    /// - Throws: ``MapsError/unavailable`` if MapKit is not available;
    ///           `MKError` if the search fails.
    public func geocode(address: String) async throws -> TheaLocation? {
        #if canImport(MapKit)
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        if #available(macOS 12.0, iOS 15.0, *) {
            request.resultTypes = .address
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let mapItem = response.mapItems.first else {
            return nil
        }

        let coordinate: TheaCoordinate
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            coordinate = TheaCoordinate(
                latitude: mapItem.location.coordinate.latitude,
                longitude: mapItem.location.coordinate.longitude
            )
        } else {
            coordinate = TheaCoordinate(
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude
            )
        }

        return TheaLocation(
            name: mapItem.name ?? address,
            address: formatAddress(from: mapItem),
            coordinate: coordinate,
            timeZone: mapItem.timeZone?.identifier
        )
        #else
        throw MapsError.unavailable
        #endif
    }

    /// Reverse-geocodes a coordinate to a named location with address.
    ///
    /// On macOS/iOS 26+, uses `MKReverseGeocodingRequest`; on earlier versions,
    /// falls back to `CLGeocoder.reverseGeocodeLocation`.
    ///
    /// - Parameter coordinate: The geographic coordinate to reverse-geocode.
    /// - Returns: A ``TheaLocation`` with resolved name and address, or `nil` if no match was found.
    /// - Throws: ``MapsError/unavailable`` if MapKit is not available;
    ///           ``MapsError/geocodingFailed(_:)`` if the request cannot be created;
    ///           `CLError` or `MKError` if the underlying geocoding fails.
    public func reverseGeocode(coordinate: TheaCoordinate) async throws -> TheaLocation? {
        #if canImport(MapKit)
        let clLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: clLocation) else {
                throw MapsError.geocodingFailed("Could not create reverse geocoding request")
            }
            // MKReverseGeocodingRequest is not Sendable — extract data at nonisolated boundary
            nonisolated(unsafe) let items = try await request.mapItems
            guard let mapItem = items.first else {
                return nil
            }
            return TheaLocation(
                name: mapItem.name ?? "Unknown Location",
                address: formatAddress(from: mapItem),
                coordinate: coordinate,
                timeZone: mapItem.timeZone?.identifier
            )
        } else {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            guard let placemark = placemarks.first else {
                return nil
            }
            return TheaLocation(
                name: placemark.name ?? "Unknown Location",
                address: formatAddress(from: placemark),
                coordinate: coordinate,
                timeZone: placemark.timeZone?.identifier
            )
        }
        #else
        throw MapsError.unavailable
        #endif
    }
}
