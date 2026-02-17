// MapsIntegration+Models.swift
// Thea V2
//
// Location models, enums, and search criteria types for MapsIntegration

import Foundation

// MARK: - Location Models

/// Represents a location or place in the system.
///
/// Wraps coordinate, address, and metadata for a geographic point of interest.
/// Conforms to `Identifiable`, `Sendable`, and `Codable` for use across
/// async boundaries, SwiftUI lists, and persistence.
public struct TheaLocation: Identifiable, Sendable, Codable {
    /// Unique identifier for this location.
    public let id: String
    /// Human-readable name (e.g. "Central Park").
    public var name: String
    /// Formatted street address.
    public var address: String
    /// Geographic coordinate (latitude/longitude).
    public var coordinate: TheaCoordinate
    /// Semantic category (restaurant, hospital, etc.), if known.
    public var category: LocationCategory?
    /// Contact phone number, if available.
    public var phoneNumber: String?
    /// Associated URL (website), if available.
    public var url: URL?
    /// IANA time zone identifier (e.g. "America/New_York"), if known.
    public var timeZone: String?
    /// Raw MapKit point-of-interest category string, if available.
    public var pointOfInterestCategory: String?
    /// Distance from the search origin in meters, if computed.
    public var distance: Double?

    /// Creates a new location.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID string.
    ///   - name: Human-readable name.
    ///   - address: Formatted street address. Defaults to empty string.
    ///   - coordinate: Geographic coordinate.
    ///   - category: Semantic category, if known.
    ///   - phoneNumber: Contact phone number, if available.
    ///   - url: Associated URL, if available.
    ///   - timeZone: IANA time zone identifier, if known.
    ///   - pointOfInterestCategory: Raw MapKit POI category string.
    ///   - distance: Distance from search origin in meters.
    public init(
        id: String = UUID().uuidString,
        name: String,
        address: String = "",
        coordinate: TheaCoordinate,
        category: LocationCategory? = nil,
        phoneNumber: String? = nil,
        url: URL? = nil,
        timeZone: String? = nil,
        pointOfInterestCategory: String? = nil,
        distance: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.category = category
        self.phoneNumber = phoneNumber
        self.url = url
        self.timeZone = timeZone
        self.pointOfInterestCategory = pointOfInterestCategory
        self.distance = distance
    }
}

// MARK: - Coordinate

/// A geographic coordinate represented as latitude and longitude.
public struct TheaCoordinate: Sendable, Codable, Equatable {
    /// Latitude in degrees (-90 to +90).
    public let latitude: Double
    /// Longitude in degrees (-180 to +180).
    public let longitude: Double

    /// Creates a coordinate from latitude and longitude.
    ///
    /// - Parameters:
    ///   - latitude: Latitude in degrees.
    ///   - longitude: Longitude in degrees.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Human-readable string representation with 6 decimal places.
    public var description: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}

// MARK: - Location Category

/// Semantic categories for points of interest.
///
/// Maps bidirectionally to `MKPointOfInterestCategory` via helper methods
/// in the `MapsIntegration` actor.
public enum LocationCategory: String, Codable, Sendable, CaseIterable {
    case restaurant
    case cafe
    case bar
    case hotel
    case hospital
    case pharmacy
    case grocery
    case gasStation
    case parking
    case atm
    case bank
    case airport
    case trainStation
    case busStation
    case museum
    case park
    case gym
    case school
    case university
    case library
    case movieTheater
    case nightclub
    case spa
    case beach
    case campground
    case other
}

// MARK: - Route Models

/// Represents a calculated route between two locations.
///
/// Contains distance, estimated travel time, turn-by-turn steps,
/// and polyline coordinates for map rendering.
public struct TheaRoute: Identifiable, Sendable {
    /// Unique identifier for this route.
    public let id: String
    /// Display name assigned by MapKit (e.g. "I-95 N").
    public var name: String
    /// Starting location.
    public let source: TheaLocation
    /// Ending location.
    public let destination: TheaLocation
    /// Total distance in meters.
    public let distance: Double
    /// Estimated travel time in seconds.
    public let expectedTravelTime: TimeInterval
    /// Mode of transportation used for this route.
    public let transportType: TransportType
    /// Turn-by-turn navigation steps.
    public let steps: [RouteStep]
    /// Polyline coordinates for rendering the route on a map.
    public let polylinePoints: [TheaCoordinate]

    /// Human-readable distance string (e.g. "450 m" or "12.3 km").
    public var distanceFormatted: String {
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    /// Human-readable travel time string (e.g. "25 min" or "1h 30min").
    public var travelTimeFormatted: String {
        let hours = Int(expectedTravelTime) / 3600
        let minutes = (Int(expectedTravelTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes) min"
        }
    }

    /// Creates a new route.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID string.
    ///   - name: Display name. Defaults to empty string.
    ///   - source: Starting location.
    ///   - destination: Ending location.
    ///   - distance: Total distance in meters.
    ///   - expectedTravelTime: Estimated travel time in seconds.
    ///   - transportType: Mode of transportation.
    ///   - steps: Turn-by-turn navigation steps.
    ///   - polylinePoints: Polyline coordinates for map rendering.
    public init(
        id: String = UUID().uuidString,
        name: String = "",
        source: TheaLocation,
        destination: TheaLocation,
        distance: Double,
        expectedTravelTime: TimeInterval,
        transportType: TransportType,
        steps: [RouteStep] = [],
        polylinePoints: [TheaCoordinate] = []
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.destination = destination
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.transportType = transportType
        self.steps = steps
        self.polylinePoints = polylinePoints
    }
}

/// A single turn-by-turn instruction within a route.
public struct RouteStep: Sendable, Identifiable {
    /// Unique identifier for this step.
    public let id: String
    /// Human-readable navigation instruction (e.g. "Turn right on Main St").
    public let instructions: String
    /// Distance for this step in meters.
    public let distance: Double
    /// Transport mode for this step.
    public let transportType: TransportType

    /// Creates a new route step.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID string.
    ///   - instructions: Navigation instruction text.
    ///   - distance: Distance in meters.
    ///   - transportType: Mode of transportation.
    public init(
        id: String = UUID().uuidString,
        instructions: String,
        distance: Double,
        transportType: TransportType
    ) {
        self.id = id
        self.instructions = instructions
        self.distance = distance
        self.transportType = transportType
    }
}

/// Supported modes of transportation for routing.
public enum TransportType: String, Codable, Sendable, CaseIterable {
    case automobile
    case walking
    case transit
    case cycling
}

// MARK: - Search Criteria

/// Criteria for searching locations via MapKit.
///
/// Supports natural language queries, coordinate-based nearby search,
/// category filtering, and result type constraints.
public struct LocationSearchCriteria: Sendable {
    /// Natural language search query (e.g. "coffee shops").
    public var query: String?
    /// Center coordinate for proximity-based search.
    public var center: TheaCoordinate?
    /// Search radius in meters from the center coordinate.
    public var radius: Double?
    /// Filter results to a specific category.
    public var category: LocationCategory?
    /// Map region to constrain the search.
    public var region: TheaMapRegion?
    /// Types of results to include.
    public var resultTypes: Set<LocationResultType>
    /// Maximum number of results to return.
    public var limit: Int?

    /// Creates search criteria with full customization.
    ///
    /// - Parameters:
    ///   - query: Natural language search query.
    ///   - center: Center coordinate for proximity search.
    ///   - radius: Search radius in meters.
    ///   - category: Filter by location category.
    ///   - region: Constrain to a map region.
    ///   - resultTypes: Types of results to include. Defaults to POIs and addresses.
    ///   - limit: Maximum number of results.
    public init(
        query: String? = nil,
        center: TheaCoordinate? = nil,
        radius: Double? = nil,
        category: LocationCategory? = nil,
        region: TheaMapRegion? = nil,
        resultTypes: Set<LocationResultType> = [.pointOfInterest, .address],
        limit: Int? = nil
    ) {
        self.query = query
        self.center = center
        self.radius = radius
        self.category = category
        self.region = region
        self.resultTypes = resultTypes
        self.limit = limit
    }

    /// Creates criteria for a simple text search.
    ///
    /// - Parameter query: Natural language search query.
    /// - Returns: Configured search criteria.
    public static func search(_ query: String) -> LocationSearchCriteria {
        LocationSearchCriteria(query: query)
    }

    /// Creates criteria for a nearby search around a coordinate.
    ///
    /// - Parameters:
    ///   - center: Center coordinate.
    ///   - radius: Search radius in meters. Defaults to 1000.
    ///   - category: Optional category filter.
    /// - Returns: Configured search criteria.
    public static func nearby(
        center: TheaCoordinate,
        radius: Double = 1000,
        category: LocationCategory? = nil
    ) -> LocationSearchCriteria {
        LocationSearchCriteria(
            center: center,
            radius: radius,
            category: category
        )
    }
}

/// Types of results returned by a location search.
public enum LocationResultType: String, Sendable {
    /// Street addresses.
    case address
    /// Points of interest (businesses, landmarks, etc.).
    case pointOfInterest
    /// General query results.
    case query
}

/// A rectangular geographic region defined by center and span.
public struct TheaMapRegion: Sendable, Codable {
    /// Center coordinate of the region.
    public let center: TheaCoordinate
    /// North-south span in degrees.
    public let latitudeDelta: Double
    /// East-west span in degrees.
    public let longitudeDelta: Double

    /// Creates a map region.
    ///
    /// - Parameters:
    ///   - center: Center coordinate.
    ///   - latitudeDelta: North-south span in degrees.
    ///   - longitudeDelta: East-west span in degrees.
    public init(center: TheaCoordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    /// Creates a square region centered on a coordinate.
    ///
    /// - Parameters:
    ///   - coordinate: Center coordinate.
    ///   - spanDegrees: Span in degrees for both axes. Defaults to 0.1.
    /// - Returns: A square map region.
    public static func around(_ coordinate: TheaCoordinate, spanDegrees: Double = 0.1) -> TheaMapRegion {
        TheaMapRegion(
            center: coordinate,
            latitudeDelta: spanDegrees,
            longitudeDelta: spanDegrees
        )
    }
}

// MARK: - Errors

/// Errors raised by ``MapsIntegration`` operations.
public enum MapsError: LocalizedError {
    /// MapKit framework is not available on this platform.
    case unavailable
    /// The specified location could not be found.
    case locationNotFound(String)
    /// No route could be calculated between the given points.
    case directionsNotFound
    /// Forward or reverse geocoding failed.
    case geocodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "MapKit framework not available on this platform"
        case .locationNotFound(let details):
            "Location not found: \(details)"
        case .directionsNotFound:
            "Could not calculate directions"
        case .geocodingFailed(let details):
            "Geocoding failed: \(details)"
        }
    }
}
