@preconcurrency import CoreLocation
import Foundation
import MapKit
import os.log

// MARK: - Sendable Wrapper

/// Wrapper to safely transfer non-Sendable types across isolation boundaries
/// Use with caution - caller must ensure thread safety
private struct UncheckedSendableWrapper<T>: @unchecked Sendable {
    let value: T
}

// MARK: - Geocoded Location Info

/// Holds geocoded location information extracted from MKMapItem
private struct GeocodedLocationInfo: Sendable {
    let name: String?
    let address: String?
    let locality: String?
    let administrativeArea: String?
    let country: String?
}

// MARK: - Location Context Provider

/// Provides location-based context including place names, movement, and significant locations
public actor LocationContextProvider: ContextProvider {
    public let providerId = "location"
    public let displayName = "Location"

    private let logger = Logger(subsystem: "app.thea", category: "LocationProvider")

    private var state: ContextProviderState = .idle
    private var currentLocation: CLLocation?
    private var currentGeocodedInfo: GeocodedLocationInfo?
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?

    // MainActor-isolated helper for CLLocationManager
    private var locationHelper: LocationManagerHelper?

    // Significant locations
    private var homeLocation: CLLocation?
    private var workLocation: CLLocation?

    public var isActive: Bool { state == .running }
    public var requiresPermission: Bool { true }

    public var hasPermission: Bool {
        get async {
            await locationHelper?.checkAuthorizationStatus() ?? false
        }
    }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        // Create helper on MainActor
        let helper = await MainActor.run {
            LocationManagerHelper()
        }
        locationHelper = helper

        // Setup with callback
        await helper.setup { [weak self] location in
            Task {
                await self?.handleLocationUpdate(location)
            }
        }

        await helper.startUpdating()

        state = .running
        logger.info("Location provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping

        if let helper = locationHelper {
            await helper.stopUpdating()
        }
        locationHelper = nil

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Location provider stopped")
    }

    public func requestPermission() async throws -> Bool {
        guard let helper = locationHelper else {
            let newHelper = await MainActor.run { LocationManagerHelper() }
            locationHelper = newHelper
            return await newHelper.requestPermission()
        }
        return await helper.requestPermission()
    }

    public func getCurrentContext() async -> ContextUpdate? {
        guard let location = currentLocation else { return nil }

        let context = await buildLocationContext(from: location)
        return ContextUpdate(
            providerId: providerId,
            updateType: .location(context),
            priority: .normal
        )
    }

    // MARK: - Private Methods

    private func handleLocationUpdate(_ location: CLLocation) async {
        currentLocation = location

        // Reverse geocode for place name
        await reverseGeocode(location)

        let context = await buildLocationContext(from: location)
        let update = ContextUpdate(
            providerId: providerId,
            updateType: .location(context),
            priority: .normal
        )

        continuation?.yield(update)
    }

    private func reverseGeocode(_ location: CLLocation) async {
        let result = await locationHelper?.reverseGeocode(location: location)
        currentGeocodedInfo = result
    }

    private func buildLocationContext(from location: CLLocation) async -> LocationContext {
        let isHome = homeLocation.map { location.distance(from: $0) < 100 }
        let isWork = workLocation.map { location.distance(from: $0) < 100 }

        return LocationContext(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            placeName: currentGeocodedInfo?.name,
            locality: currentGeocodedInfo?.locality,
            administrativeArea: currentGeocodedInfo?.administrativeArea,
            country: currentGeocodedInfo?.country,
            isHome: isHome,
            isWork: isWork,
            speed: location.speed >= 0 ? location.speed : nil,
            course: location.course >= 0 ? location.course : nil
        )
    }

    /// Set home location for context detection
    public func setHomeLocation(_ location: CLLocation) {
        homeLocation = location
    }

    /// Set work location for context detection
    public func setWorkLocation(_ location: CLLocation) {
        workLocation = location
    }
}

// MARK: - Location Manager Helper

/// MainActor-isolated helper to manage CLLocationManager
@MainActor
private final class LocationManagerHelper: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var onLocationUpdate: (@Sendable (CLLocation) -> Void)?

    override nonisolated init() {
        super.init()
    }

    func setup(onLocationUpdate: @escaping @Sendable (CLLocation) -> Void) {
        self.onLocationUpdate = onLocationUpdate
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50 // Update every 50 meters
    }

    func startUpdating() {
        locationManager.startUpdatingLocation()
        #if os(iOS)
            locationManager.startMonitoringSignificantLocationChanges()
        #endif
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
        #if os(iOS)
            locationManager.stopMonitoringSignificantLocationChanges()
        #endif
    }

    func checkAuthorizationStatus() -> Bool {
        let status = locationManager.authorizationStatus
        #if os(macOS)
            return status == .authorizedAlways
        #else
            return status == .authorizedAlways || status == .authorizedWhenInUse
        #endif
    }

    func requestPermission() async -> Bool {
        #if os(iOS) || os(watchOS)
            locationManager.requestWhenInUseAuthorization()
        #elseif os(macOS)
            locationManager.requestAlwaysAuthorization()
        #endif

        // Wait a moment for the permission dialog
        try? await Task.sleep(for: .seconds(1))
        return checkAuthorizationStatus()
    }

    func reverseGeocode(location: CLLocation) async -> GeocodedLocationInfo? {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }
        do {
            // Wrap the request to safely transfer across isolation boundaries
            let wrapper = UncheckedSendableWrapper(value: request)
            let geocodedInfo: GeocodedLocationInfo = try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    do {
                        let items = try await wrapper.value.mapItems
                        guard let mapItem = items.first else {
                            // Return empty info if no results
                            let emptyInfo = GeocodedLocationInfo(
                                name: nil, address: nil, locality: nil,
                                administrativeArea: nil, country: nil
                            )
                            continuation.resume(returning: emptyInfo)
                            return
                        }
                        // Extract info from MKMapItem using new APIs
                        // Use MKAddress for address information
                        let mkAddress = mapItem.address
                        let info = GeocodedLocationInfo(
                            name: mapItem.name,
                            address: mkAddress?.fullAddress,
                            locality: nil,
                            administrativeArea: nil,
                            country: nil
                        )
                        continuation.resume(returning: info)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            // Return nil if all fields are nil
            if geocodedInfo.name == nil, geocodedInfo.address == nil {
                return nil
            }
            return geocodedInfo
        } catch {
            return nil
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.onLocationUpdate?(location)
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
}
