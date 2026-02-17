// MapsIntegration+Utilities.swift
// Thea V2
//
// Distance calculation, Open in Maps, and internal helper methods
// for MapsIntegration

import Foundation
import OSLog

#if canImport(MapKit)
@preconcurrency import MapKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Distance Calculation

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
extension MapsIntegration {

    /// Calculates the great-circle distance between two coordinates.
    ///
    /// Uses `CLLocation.distance(from:)` when CoreLocation is available;
    /// falls back to the Haversine formula otherwise.
    ///
    /// - Parameters:
    ///   - from: The first coordinate.
    ///   - to: The second coordinate.
    /// - Returns: Distance in meters.
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
}

// MARK: - Open in Maps

#if canImport(MapKit)
@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
extension MapsIntegration {

    /// Opens a location in the system Maps app.
    ///
    /// - Parameter location: The location to display.
    /// - Returns: `true` if the Maps app was opened successfully.
    @discardableResult
    public func openInMaps(location: TheaLocation) async -> Bool {
        let mapItem: MKMapItem
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            mapItem = MKMapItem(location: clLocation, address: nil)
        } else {
            let coordinate = CLLocationCoordinate2D(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let placemark = MKPlacemark(coordinate: coordinate)
            mapItem = MKMapItem(placemark: placemark)
        }
        mapItem.name = location.name
        if #available(macOS 14.0, iOS 17.0, *) {
            #if os(macOS)
                return await mapItem.openInMaps(launchOptions: nil)
            #else
                return mapItem.openInMaps(launchOptions: nil)
            #endif
        } else {
            return await MainActor.run {
                mapItem.openInMaps(launchOptions: nil)
            }
        }
    }

    /// Opens turn-by-turn directions in the system Maps app.
    ///
    /// If `source` is `nil`, the user's current location is used as the starting point.
    ///
    /// - Parameters:
    ///   - source: Starting coordinate, or `nil` to use current location.
    ///   - destination: Ending coordinate.
    ///   - destinationName: Display name for the destination pin. Defaults to "Destination".
    ///   - transportType: Mode of transportation. Defaults to `.automobile`.
    /// - Returns: `true` if the Maps app was opened successfully.
    @discardableResult
    public func openDirectionsInMaps(
        from source: TheaCoordinate?,
        to destination: TheaCoordinate,
        destinationName: String = "Destination",
        transportType: TransportType = .automobile
    ) async -> Bool {
        var mapItems: [MKMapItem] = []

        if let source = source {
            if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
                let sourceLocation = CLLocation(latitude: source.latitude, longitude: source.longitude)
                mapItems.append(MKMapItem(location: sourceLocation, address: nil))
            } else {
                let sourcePlacemark = MKPlacemark(
                    coordinate: CLLocationCoordinate2D(
                        latitude: source.latitude,
                        longitude: source.longitude
                    )
                )
                mapItems.append(MKMapItem(placemark: sourcePlacemark))
            }
        } else {
            mapItems.append(MKMapItem.forCurrentLocation())
        }

        let destMapItem: MKMapItem
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
            destMapItem = MKMapItem(location: destLocation, address: nil)
        } else {
            let destPlacemark = MKPlacemark(
                coordinate: CLLocationCoordinate2D(
                    latitude: destination.latitude,
                    longitude: destination.longitude
                )
            )
            destMapItem = MKMapItem(placemark: destPlacemark)
        }
        destMapItem.name = destinationName
        mapItems.append(destMapItem)

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: mapTransportTypeToLaunchOption(transportType)
        ]

        if #available(macOS 14.0, iOS 17.0, *) {
            #if os(macOS)
                return await MKMapItem.openMaps(with: mapItems, launchOptions: launchOptions)
            #else
                return MKMapItem.openMaps(with: mapItems, launchOptions: launchOptions)
            #endif
        } else {
            return await MainActor.run {
                MKMapItem.openMaps(with: mapItems, launchOptions: launchOptions)
            }
        }
    }
}
#endif

// MARK: - Internal Helpers

@available(macOS 10.15, iOS 13.0, watchOS 6.0, *)
extension MapsIntegration {

    #if canImport(MapKit)

    /// Converts an `MKMapItem` to a ``TheaLocation``, optionally computing distance from a search center.
    ///
    /// - Parameters:
    ///   - mapItem: The MapKit map item to convert.
    ///   - searchCenter: Optional coordinate to compute distance from.
    /// - Returns: A populated ``TheaLocation``.
    internal func convertToTheaLocation(
        _ mapItem: MKMapItem,
        searchCenter: TheaCoordinate?
    ) -> TheaLocation {
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

        let locationID: String
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            locationID = mapItem.location.coordinate.latitude.description +
                mapItem.location.coordinate.longitude.description
        } else {
            locationID = mapItem.placemark.coordinate.latitude.description +
                mapItem.placemark.coordinate.longitude.description
        }

        return TheaLocation(
            id: locationID,
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

    /// Maps a ``TransportType`` to its MapKit equivalent.
    ///
    /// - Parameter type: The Thea transport type.
    /// - Returns: The corresponding `MKDirectionsTransportType`.
    internal func mapTransportType(_ type: TransportType) -> MKDirectionsTransportType {
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

    /// Maps a ``TransportType`` to the corresponding Maps app launch option string.
    ///
    /// - Parameter type: The Thea transport type.
    /// - Returns: An `MKLaunchOptionsDirectionsMode*` constant.
    internal func mapTransportTypeToLaunchOption(_ type: TransportType) -> String {
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

    /// Maps a Thea ``LocationCategory`` to the corresponding MapKit POI category.
    ///
    /// - Parameter category: The Thea category.
    /// - Returns: The MapKit equivalent, or `nil` for `.other`.
    @available(macOS 13.0, iOS 16.0, *)
    internal func mapCategoryToMKCategory(_ category: LocationCategory) -> MKPointOfInterestCategory? {
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

    /// Maps a MapKit POI category to the corresponding Thea ``LocationCategory``.
    ///
    /// - Parameter mkCategory: The MapKit category.
    /// - Returns: The Thea equivalent, or `.other` for unrecognized categories.
    @available(macOS 13.0, iOS 16.0, *)
    internal func mapMKCategoryToCategory(_ mkCategory: MKPointOfInterestCategory) -> LocationCategory? {
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

    /// Formats a `CLPlacemark` into a human-readable comma-separated address string.
    ///
    /// - Parameter placemark: The CoreLocation placemark to format.
    /// - Returns: Formatted address string (e.g. "123 Main St, Springfield, IL, 62701, US").
    internal func formatAddress(from placemark: CLPlacemark) -> String {
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

    /// Formats an `MKMapItem` into a human-readable comma-separated address string.
    ///
    /// On macOS/iOS 26+, uses the new `MKAddress`/`MKAddressRepresentations` API;
    /// on earlier versions, falls back to manual extraction from `CLPlacemark` fields.
    ///
    /// - Parameter mapItem: The MapKit map item to format.
    /// - Returns: Formatted address string.
    internal func formatAddress(from mapItem: MKMapItem) -> String {
        if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *) {
            // Use new MKAddress / MKAddressRepresentations API
            if let representations = mapItem.addressRepresentations {
                if let full = representations.fullAddress(includingRegion: true, singleLine: true) {
                    return full
                }
            }
            if let address = mapItem.address {
                return address.fullAddress
            }
            return ""
        } else {
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
    }
    #endif
}
