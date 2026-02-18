// MapsIntegration.swift
// Thea V2
//
// Deep integration with Apple MapKit framework
// Provides location search, directions, and POI discovery
//
// Methods are in split files:
// - MapsIntegration+Search.swift: searchLocations, searchAddress, searchNearby
// - MapsIntegration+Geocoding.swift: geocode, reverseGeocode
// - MapsIntegration+Routing.swift: getDirections, getETA
// - MapsIntegration+Utilities.swift: distance, openInMaps, openDirectionsInMaps, helpers
// - MapsIntegration+Models.swift: types (TheaLocation, TheaRoute, etc.)

import Foundation
import OSLog

#if canImport(MapKit)
import MapKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Maps Integration Actor

/// Actor for managing Maps operations
/// Thread-safe access to MapKit framework
@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
public actor MapsIntegration {
    public static let shared = MapsIntegration()

    let logger = Logger(subsystem: "com.thea.integrations", category: "Maps")

    private init() {}
}
