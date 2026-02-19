import Foundation
import OSLog
import Observation
@preconcurrency import SwiftData

#if os(iOS)
    import CoreLocation

    // MARK: - Location Tracking Manager

    // Tracks location for context-aware assistance and life insights

    @MainActor
    @Observable
    final class LocationTrackingManager: NSObject, CLLocationManagerDelegate {
        static let shared = LocationTrackingManager()

        private let logger = Logger(subsystem: "ai.thea.app", category: "LocationTrackingManager")
        private var modelContext: ModelContext?
        private let locationManager = CLLocationManager()

        private(set) var isTracking = false
        private(set) var currentLocation: CLLocation?
        private(set) var locationHistory: [LocationVisit] = []

        private var config: LifeTrackingConfiguration {
            AppConfiguration.shared.lifeTrackingConfig
        }

        override private init() {
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 100 // Update every 100 meters
        }

        func setModelContext(_ context: ModelContext) {
            modelContext = context
        }

        // MARK: - Permission

        func requestPermission() async -> CLAuthorizationStatus {
            locationManager.requestWhenInUseAuthorization()

            return await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume(returning: self.locationManager.authorizationStatus)
                }
            }
        }

        // MARK: - Tracking Control

        func startTracking() {
            guard config.locationTrackingEnabled, !isTracking else { return }

            let status = locationManager.authorizationStatus

            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                print("Location permission not granted")
                return
            }

            isTracking = true
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringVisits()
        }

        func stopTracking() {
            isTracking = false
            locationManager.stopUpdatingLocation()
            locationManager.stopMonitoringVisits()
        }

        // MARK: - CLLocationManagerDelegate

        nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            Task { @MainActor in
                guard let location = locations.last else { return }
                currentLocation = location
            }
        }

        nonisolated func locationManager(_: CLLocationManager, didVisit visit: CLVisit) {
            // Extract Sendable values before crossing isolation boundary
            let coordinate = visit.coordinate
            let arrivalDate = visit.arrivalDate
            let departureDate = visit.departureDate
            let horizontalAccuracy = visit.horizontalAccuracy

            Task { @MainActor in
                await handleVisitData(
                    coordinate: coordinate,
                    arrivalDate: arrivalDate,
                    departureDate: departureDate,
                    horizontalAccuracy: horizontalAccuracy
                )
            }
        }

        nonisolated func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            Task { @MainActor in
                if status == .denied || status == .restricted {
                    stopTracking()
                }
            }
        }

        nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
            print("Location manager error: \(error.localizedDescription)")
        }

        // MARK: - Visit Handling

        private func handleVisitData(
            coordinate: CLLocationCoordinate2D,
            arrivalDate: Date,
            departureDate: Date,
            horizontalAccuracy _: CLLocationAccuracy
        ) async {
            let locationVisit = LocationVisit(
                coordinate: coordinate,
                arrivalTime: arrivalDate,
                departureTime: departureDate != Date.distantFuture ? departureDate : nil,
                placeName: nil,
                category: .other
            )

            locationHistory.append(locationVisit)

            await saveVisit(locationVisit)
        }

        // MARK: - Data Persistence

        private func saveVisit(_ visit: LocationVisit) async {
            guard let context = modelContext else { return }

            let record = LocationVisitRecord(
                latitude: visit.coordinate.latitude,
                longitude: visit.coordinate.longitude,
                arrivalTime: visit.arrivalTime,
                departureTime: visit.departureTime,
                placeName: visit.placeName,
                category: visit.category.rawValue
            )

            context.insert(record)
            do {
                try context.save()
            } catch {
                logger.error("Failed to save location visit: \(error.localizedDescription)")
            }
        }

        // MARK: - Historical Data

        func getVisitsForDate(_ date: Date) async -> [LocationVisit] {
            guard let context = modelContext else { return [] }

            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

            // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<LocationVisitRecord>()
            let allRecords: [LocationVisitRecord]
            do {
                allRecords = try context.fetch(descriptor)
            } catch {
                logger.error("Failed to fetch location visits for date: \(error.localizedDescription)")
                return []
            }
            let records = allRecords
                .filter { $0.arrivalTime >= startOfDay && $0.arrivalTime < endOfDay }
                .sorted { $0.arrivalTime > $1.arrivalTime }

            return records.map { record in
                LocationVisit(
                    coordinate: CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude),
                    arrivalTime: record.arrivalTime,
                    departureTime: record.departureTime,
                    placeName: record.placeName,
                    category: PlaceCategory(rawValue: record.category) ?? .other
                )
            }
        }

        func getVisits(from start: Date, to end: Date) async -> [LocationVisitRecord] {
            guard let context = modelContext else { return [] }

            // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
            let descriptor = FetchDescriptor<LocationVisitRecord>()
            let allRecords: [LocationVisitRecord]
            do {
                allRecords = try context.fetch(descriptor)
            } catch {
                logger.error("Failed to fetch location visits for range: \(error.localizedDescription)")
                return []
            }
            return allRecords
                .filter { $0.arrivalTime >= start && $0.arrivalTime <= end }
                .sorted { $0.arrivalTime > $1.arrivalTime }
        }
    }

    // MARK: - Supporting Structures

    struct LocationVisit {
        let coordinate: CLLocationCoordinate2D
        let arrivalTime: Date
        let departureTime: Date?
        let placeName: String?
        let category: PlaceCategory
    }

    enum PlaceCategory: String {
        case home = "Home"
        case work = "Work"
        case gym = "Gym"
        case restaurant = "Restaurant"
        case shop = "Shop"
        case other = "Other"
    }

#else
    // Placeholder for non-iOS platforms
    @MainActor
    @Observable
    final class LocationTrackingManager {
        static let shared = LocationTrackingManager()
        // periphery:ignore - Reserved: shared static property reserved for future feature activation
        private init() {}
        // periphery:ignore - Reserved: setModelContext(_:) instance method reserved for future feature activation
        func setModelContext(_: ModelContext) {}
    }
#endif
