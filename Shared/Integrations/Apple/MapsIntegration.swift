// MapsIntegration.swift
// Thea V2
//
// Deep integration with Apple MapKit framework.
// Provides location search, directions, geocoding, and POI discovery.
//
// This file declares the actor and shared state. Functionality is split across:
//   - MapsIntegration+Models.swift     — Location models, enums, search criteria, errors
//   - MapsIntegration+Search.swift     — Location and POI search
//   - MapsIntegration+Geocoding.swift  — Forward and reverse geocoding
//   - MapsIntegration+Routing.swift    — Directions, ETA, and route calculation
//   - MapsIntegration+Utilities.swift  — Distance, Open in Maps, and internal helpers

import Foundation
import OSLog

#if canImport(MapKit)
@preconcurrency import MapKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Maps Integration Actor

/// Thread-safe actor for managing all MapKit operations.
///
/// Provides a unified interface for location search, geocoding, directions,
/// ETA estimation, distance calculation, and launching the system Maps app.
///
/// Usage:
/// ```swift
/// let maps = MapsIntegration.shared
/// let results = try await maps.searchLocations(criteria: .search("coffee"))
/// let route = try await maps.getDirections(from: origin, to: destination)
/// ```
@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
public actor MapsIntegration {
    /// Shared singleton instance.
    public static let shared = MapsIntegration()

    /// Logger for maps operations.
    let logger = Logger(subsystem: "com.thea.integrations", category: "Maps")

    private init() {}
}
