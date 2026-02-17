// MapsIntegration+Routing.swift
// Thea V2
//
// Directions, ETA, and route calculation for MapsIntegration

import Foundation
import OSLog

#if canImport(MapKit)
@preconcurrency import MapKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Directions & ETA

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
extension MapsIntegration {

    /// Calculates driving/walking/transit/cycling routes between two coordinates.
    ///
    /// Requests alternate routes from MapKit and returns all options, each
    /// containing turn-by-turn steps and polyline coordinates.
    ///
    /// - Parameters:
    ///   - source: Starting coordinate.
    ///   - destination: Ending coordinate.
    ///   - transportType: Mode of transportation. Defaults to `.automobile`.
    /// - Returns: An array of ``TheaRoute`` options (typically 1-3).
    /// - Throws: ``MapsError/unavailable`` if MapKit is not available;
    ///           `MKError` if MapKit cannot calculate a route.
    public func getDirections(
        from source: TheaCoordinate,
        to destination: TheaCoordinate,
        transportType: TransportType = .automobile
    ) async throws -> [TheaRoute] {
        #if canImport(MapKit)
        let request = MKDirections.Request()

        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
            let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
            request.source = MKMapItem(location: sourceLocation, address: nil)
            request.destination = MKMapItem(location: destLocation, address: nil)
        } else {
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
        }
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

    /// Calculates routes between two named locations.
    ///
    /// Geocodes both location names first, then delegates to
    /// ``getDirections(from:to:transportType:)``.
    ///
    /// - Parameters:
    ///   - sourceName: Human-readable name or address of the starting location.
    ///   - destinationName: Human-readable name or address of the ending location.
    ///   - transportType: Mode of transportation. Defaults to `.automobile`.
    /// - Returns: An array of ``TheaRoute`` options.
    /// - Throws: ``MapsError/locationNotFound(_:)`` if either location cannot be geocoded.
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

    /// Calculates the estimated travel time between two coordinates.
    ///
    /// Uses `MKDirections.calculateETA()` for a lightweight time estimate
    /// without full route details.
    ///
    /// - Parameters:
    ///   - source: Starting coordinate.
    ///   - destination: Ending coordinate.
    ///   - transportType: Mode of transportation. Defaults to `.automobile`.
    /// - Returns: Estimated travel time in seconds.
    /// - Throws: ``MapsError/unavailable`` if MapKit is not available;
    ///           `MKError` if MapKit cannot calculate the ETA.
    public func getETA(
        from source: TheaCoordinate,
        to destination: TheaCoordinate,
        transportType: TransportType = .automobile
    ) async throws -> TimeInterval {
        #if canImport(MapKit)
        let request = MKDirections.Request()

        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
            let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
            request.source = MKMapItem(location: sourceLocation, address: nil)
            request.destination = MKMapItem(location: destLocation, address: nil)
        } else {
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
        }
        request.transportType = mapTransportType(transportType)

        let directions = MKDirections(request: request)
        let response = try await directions.calculateETA()

        return response.expectedTravelTime
        #else
        throw MapsError.unavailable
        #endif
    }
}
