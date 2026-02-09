// MapsIntegration.swift
// Thea V2
//
// Deep integration with Apple MapKit framework
// Provides location search, directions, and POI discovery

import Foundation
import OSLog

#if canImport(MapKit)
import MapKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Location Models

/// Represents a location/place in the system
public struct TheaLocation: Identifiable, Sendable, Codable {
    public let id: String
    public var name: String
    public var address: String
    public var coordinate: TheaCoordinate
    public var category: LocationCategory?
    public var phoneNumber: String?
    public var url: URL?
    public var timeZone: String?
    public var pointOfInterestCategory: String?
    public var distance: Double?  // Distance from search origin in meters

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

/// Coordinate representation
public struct TheaCoordinate: Sendable, Codable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var description: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }
}

/// Location categories
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

/// Represents a route/directions
public struct TheaRoute: Identifiable, Sendable {
    public let id: String
    public var name: String
    public let source: TheaLocation
    public let destination: TheaLocation
    public let distance: Double  // In meters
    public let expectedTravelTime: TimeInterval  // In seconds
    public let transportType: TransportType
    public let steps: [RouteStep]
    public let polylinePoints: [TheaCoordinate]

    public var distanceFormatted: String {
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    public var travelTimeFormatted: String {
        let hours = Int(expectedTravelTime) / 3600
        let minutes = (Int(expectedTravelTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes) min"
        }
    }

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

/// Route step/instruction
public struct RouteStep: Sendable, Identifiable {
    public let id: String
    public let instructions: String
    public let distance: Double
    public let transportType: TransportType

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

/// Transport types
public enum TransportType: String, Codable, Sendable, CaseIterable {
    case automobile
    case walking
    case transit
    case cycling
}

// MARK: - Search Criteria

/// Search criteria for locations
public struct LocationSearchCriteria: Sendable {
    public var query: String?
    public var center: TheaCoordinate?
    public var radius: Double?  // In meters
    public var category: LocationCategory?
    public var region: TheaMapRegion?
    public var resultTypes: Set<LocationResultType>
    public var limit: Int?

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

    public static func search(_ query: String) -> LocationSearchCriteria {
        LocationSearchCriteria(query: query)
    }

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

/// Result types for location search
public enum LocationResultType: String, Sendable {
    case address
    case pointOfInterest
    case query
}

/// Map region
public struct TheaMapRegion: Sendable, Codable {
    public let center: TheaCoordinate
    public let latitudeDelta: Double
    public let longitudeDelta: Double

    public init(center: TheaCoordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    public static func around(_ coordinate: TheaCoordinate, spanDegrees: Double = 0.1) -> TheaMapRegion {
        TheaMapRegion(
            center: coordinate,
            latitudeDelta: spanDegrees,
            longitudeDelta: spanDegrees
        )
    }
}

// MARK: - Maps Integration Actor

/// Actor for managing Maps operations
/// Thread-safe access to MapKit framework
@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
public actor MapsIntegration {
    public static let shared = MapsIntegration()

    private let logger = Logger(subsystem: "com.thea.integrations", category: "Maps")

    private init() {}

    // MARK: - Location Search

    /// Search for locations
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
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

    /// Search for a specific address
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    public func searchAddress(_ address: String) async throws -> [TheaLocation] {
        let criteria = LocationSearchCriteria(
            query: address,
            resultTypes: [.address]
        )
        return try await searchLocations(criteria: criteria)
    }

    /// Search for nearby places
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
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

    // MARK: - Geocoding

    /// Forward geocode an address to coordinates using MKLocalSearch
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
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

        let coordinate = TheaCoordinate(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )

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

    /// Reverse geocode coordinates to an address
    @available(macOS, deprecated: 26.0, message: "Migrate to MKReverseGeocodingRequest")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKReverseGeocodingRequest")
    public func reverseGeocode(coordinate: TheaCoordinate) async throws -> TheaLocation? {
        #if canImport(CoreLocation)
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

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
        #else
        throw MapsError.unavailable
        #endif
    }

    // MARK: - Directions

    /// Get directions between two locations
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    public func getDirections(
        from source: TheaCoordinate,
        to destination: TheaCoordinate,
        transportType: TransportType = .automobile
    ) async throws -> [TheaRoute] {
        #if canImport(MapKit)
        let request = MKDirections.Request()

        let sourcePlacemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: source.latitude,
                longitude: source.longitude
            )
        )
        let destPlacemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: destination.latitude,
                longitude: destination.longitude
            )
        )

        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destPlacemark)
        request.requestsAlternateRoutes = true

        request.transportType = mapTransportType(transportType)

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        let sourceLocation = TheaLocation(
            name: "Start",
            coordinate: source
        )
        let destLocation = TheaLocation(
            name: "Destination",
            coordinate: destination
        )

        return response.routes.map { route -> TheaRoute in
            let steps = route.steps.map { step -> RouteStep in
                RouteStep(
                    instructions: step.instructions,
                    distance: step.distance,
                    transportType: transportType
                )
            }

            // Extract polyline points
            var polylinePoints: [TheaCoordinate] = []
            let pointCount = route.polyline.pointCount
            let points = route.polyline.points()
            for i in 0..<pointCount {
                let coord = points[i].coordinate
                polylinePoints.append(TheaCoordinate(latitude: coord.latitude, longitude: coord.longitude))
            }

            return TheaRoute(
                name: route.name,
                source: sourceLocation,
                destination: destLocation,
                distance: route.distance,
                expectedTravelTime: route.expectedTravelTime,
                transportType: transportType,
                steps: steps,
                polylinePoints: polylinePoints
            )
        }
        #else
        throw MapsError.unavailable
        #endif
    }

    /// Get directions with named locations
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    public func getDirections(
        from sourceName: String,
        to destinationName: String,
        transportType: TransportType = .automobile
    ) async throws -> [TheaRoute] {
        // Geocode both locations
        guard let sourceLocation = try await geocode(address: sourceName) else {
            throw MapsError.locationNotFound("Could not find: \(sourceName)")
        }

        guard let destLocation = try await geocode(address: destinationName) else {
            throw MapsError.locationNotFound("Could not find: \(destinationName)")
        }

        return try await getDirections(
            from: sourceLocation.coordinate,
            to: destLocation.coordinate,
            transportType: transportType
        )
    }

    /// Get estimated travel time
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    public func getETA(
        from source: TheaCoordinate,
        to destination: TheaCoordinate,
        transportType: TransportType = .automobile
    ) async throws -> TimeInterval {
        #if canImport(MapKit)
        let request = MKDirections.Request()

        let sourcePlacemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: source.latitude,
                longitude: source.longitude
            )
        )
        let destPlacemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: destination.latitude,
                longitude: destination.longitude
            )
        )

        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destPlacemark)
        request.transportType = mapTransportType(transportType)

        let directions = MKDirections(request: request)
        let response = try await directions.calculateETA()

        return response.expectedTravelTime
        #else
        throw MapsError.unavailable
        #endif
    }

    // MARK: - Distance Calculation

    /// Calculate distance between two coordinates
    public func distance(from: TheaCoordinate, to: TheaCoordinate) -> Double {
        #if canImport(CoreLocation)
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
        #else
        // Haversine formula fallback
        let earthRadius = 6371000.0  // meters

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
        #endif
    }

    // MARK: - Open in Maps

    #if canImport(MapKit)
    /// Open location in Maps app
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @discardableResult
    public func openInMaps(location: TheaLocation) async -> Bool {
        let coordinate = CLLocationCoordinate2D(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        if #available(macOS 14.0, iOS 17.0, *) {
            return await mapItem.openInMaps(launchOptions: nil)
        } else {
            return await MainActor.run {
                mapItem.openInMaps(launchOptions: nil)
            }
        }
    }

    /// Open directions in Maps app
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @discardableResult
    public func openDirectionsInMaps(
        from source: TheaCoordinate?,
        to destination: TheaCoordinate,
        destinationName: String = "Destination",
        transportType: TransportType = .automobile
    ) async -> Bool {
        var mapItems: [MKMapItem] = []

        if let source = source {
            let sourcePlacemark = MKPlacemark(
                coordinate: CLLocationCoordinate2D(
                    latitude: source.latitude,
                    longitude: source.longitude
                )
            )
            mapItems.append(MKMapItem(placemark: sourcePlacemark))
        } else {
            mapItems.append(MKMapItem.forCurrentLocation())
        }

        let destPlacemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(
                latitude: destination.latitude,
                longitude: destination.longitude
            )
        )
        let destMapItem = MKMapItem(placemark: destPlacemark)
        destMapItem.name = destinationName
        mapItems.append(destMapItem)

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: mapTransportTypeToLaunchOption(transportType)
        ]

        if #available(macOS 14.0, iOS 17.0, *) {
            return await MKMapItem.openMaps(with: mapItems, launchOptions: launchOptions)
        } else {
            return await MainActor.run {
                MKMapItem.openMaps(with: mapItems, launchOptions: launchOptions)
            }
        }
    }
    #endif

    // MARK: - Helper Methods

    #if canImport(MapKit)
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    private func convertToTheaLocation(
        _ mapItem: MKMapItem,
        searchCenter: TheaCoordinate?
    ) -> TheaLocation {
        let coordinate = TheaCoordinate(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )

        var distanceFromCenter: Double?
        if let center = searchCenter {
            distanceFromCenter = distance(from: center, to: coordinate)
        }

        var category: LocationCategory?
        if #available(macOS 13.0, iOS 16.0, *) {
            if let mkCategory = mapItem.pointOfInterestCategory {
                category = mapMKCategoryToCategory(mkCategory)
            }
        }

        return TheaLocation(
            id: mapItem.placemark.coordinate.latitude.description +
                mapItem.placemark.coordinate.longitude.description,
            name: mapItem.name ?? "Unknown",
            address: formatAddress(from: mapItem),
            coordinate: coordinate,
            category: category,
            phoneNumber: mapItem.phoneNumber,
            url: mapItem.url,
            timeZone: mapItem.timeZone?.identifier,
            pointOfInterestCategory: mapItem.pointOfInterestCategory?.rawValue,
            distance: distanceFromCenter
        )
    }

    private func mapTransportType(_ type: TransportType) -> MKDirectionsTransportType {
        switch type {
        case .automobile:
            return .automobile
        case .walking:
            return .walking
        case .transit:
            return .transit
        case .cycling:
            if #available(macOS 14.0, iOS 17.0, *) {
                return .cycling
            }
            return .automobile
        }
    }

    private func mapTransportTypeToLaunchOption(_ type: TransportType) -> String {
        switch type {
        case .automobile:
            return MKLaunchOptionsDirectionsModeDriving
        case .walking:
            return MKLaunchOptionsDirectionsModeWalking
        case .transit:
            return MKLaunchOptionsDirectionsModeTransit
        case .cycling:
            if #available(macOS 14.0, iOS 17.0, *) {
                return MKLaunchOptionsDirectionsModeCycling
            }
            return MKLaunchOptionsDirectionsModeDriving
        }
    }

    @available(macOS 13.0, iOS 16.0, *)
    private func mapCategoryToMKCategory(_ category: LocationCategory) -> MKPointOfInterestCategory? {
        switch category {
        case .restaurant:
            return .restaurant
        case .cafe:
            return .cafe
        case .bar:
            return .nightlife
        case .hotel:
            return .hotel
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .grocery:
            return .foodMarket
        case .gasStation:
            return .gasStation
        case .parking:
            return .parking
        case .atm:
            return .atm
        case .bank:
            return .bank
        case .airport:
            return .airport
        case .trainStation:
            return .publicTransport
        case .busStation:
            return .publicTransport
        case .museum:
            return .museum
        case .park:
            return .park
        case .gym:
            return .fitnessCenter
        case .school:
            return .school
        case .university:
            return .university
        case .library:
            return .library
        case .movieTheater:
            return .movieTheater
        case .nightclub:
            return .nightlife
        case .spa:
            return .spa
        case .beach:
            return .beach
        case .campground:
            return .campground
        case .other:
            return nil
        }
    }

    @available(macOS 13.0, iOS 16.0, *)
    private func mapMKCategoryToCategory(_ mkCategory: MKPointOfInterestCategory) -> LocationCategory? {
        switch mkCategory {
        case .restaurant:
            return .restaurant
        case .cafe:
            return .cafe
        case .nightlife:
            return .bar
        case .hotel:
            return .hotel
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .foodMarket:
            return .grocery
        case .gasStation:
            return .gasStation
        case .parking:
            return .parking
        case .atm:
            return .atm
        case .bank:
            return .bank
        case .airport:
            return .airport
        case .publicTransport:
            return .trainStation
        case .museum:
            return .museum
        case .park:
            return .park
        case .fitnessCenter:
            return .gym
        case .school:
            return .school
        case .university:
            return .university
        case .library:
            return .library
        case .movieTheater:
            return .movieTheater
        case .spa:
            return .spa
        case .beach:
            return .beach
        case .campground:
            return .campground
        default:
            return .other
        }
    }
    #endif

    #if canImport(CoreLocation)
    @available(macOS, deprecated: 26.0, message: "Migrate to MKReverseGeocodingRequest")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKReverseGeocodingRequest")
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            var street = thoroughfare
            if let subThoroughfare = placemark.subThoroughfare {
                street = "\(subThoroughfare) \(thoroughfare)"
            }
            components.append(street)
        }

        if let locality = placemark.locality {
            components.append(locality)
        }

        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }

        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }

        if let country = placemark.country {
            components.append(country)
        }

        return components.joined(separator: ", ")
    }
    #endif

    #if canImport(MapKit)
    @available(macOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    @available(iOS, deprecated: 26.0, message: "Migrate to MKMapItem coordinate API")
    private func formatAddress(from mapItem: MKMapItem) -> String {
        // Use MKMapItem's placemark (CLPlacemark) properties for address formatting
        // This avoids direct MKPlacemark usage deprecated in iOS 26
        let placemark = mapItem.placemark as CLPlacemark
        var components: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            var street = thoroughfare
            if let subThoroughfare = placemark.subThoroughfare {
                street = "\(subThoroughfare) \(thoroughfare)"
            }
            components.append(street)
        }

        if let locality = placemark.locality {
            components.append(locality)
        }

        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }

        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }

        if let country = placemark.country {
            components.append(country)
        }

        return components.joined(separator: ", ")
    }
    #endif
}

// MARK: - Errors

/// Errors for maps operations
public enum MapsError: LocalizedError {
    case unavailable
    case locationNotFound(String)
    case directionsNotFound
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
