// WeatherMonitor.swift
// Thea - Weather Monitoring Service
//
// Polls WeatherKit every 30 minutes for current conditions at the user's location.
// Persists the latest snapshot to disk and feeds weather changes to LifeMonitoringCoordinator.

import CoreLocation
import Foundation
import os.log

#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Weather Snapshot

public struct WeatherSnapshot: Codable, Sendable {
    public let temperature: Double    // Celsius
    public let feelsLike: Double      // Celsius
    public let humidity: Double       // 0.0-1.0
    public let uvIndex: Int
    public let condition: String      // Human-readable description
    public let pressure: Double       // hPa
    public let windSpeed: Double      // m/s
    public let timestamp: Date
}

// MARK: - Weather Monitor Delegate

public protocol WeatherMonitorDelegate: AnyObject, Sendable {
    nonisolated func weatherMonitor(_ monitor: WeatherMonitor, didUpdate snapshot: WeatherSnapshot)
}

// MARK: - Weather Monitor

@MainActor
@Observable
public final class WeatherMonitor: NSObject, Sendable {
    public static let shared = WeatherMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "WeatherMonitor")

    // MARK: - Published State

    public private(set) var currentWeather: WeatherSnapshot?
    public private(set) var isRunning = false

    // MARK: - Delegate

    public weak var delegate: WeatherMonitorDelegate?

    // MARK: - Private State

    private let locationManager = CLLocationManager()
    private var pollTask: Task<Void, Never>?
    private let pollInterval: Duration = .seconds(1800) // 30 minutes

    private static let persistenceURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thea/Weather", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("weather.json")
    }()

    // MARK: - Init

    private override init() {
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        loadPersistedSnapshot()
    }

    // MARK: - Lifecycle

    public func start() {
        guard !isRunning else {
            logger.warning("Weather monitor already running")
            return
        }

        locationManager.requestWhenInUseAuthorization()
        isRunning = true

        pollTask = Task { [weak self] in
            guard let self else { return }
            // Fetch immediately, then poll
            await self.fetchWeather()
            while !Task.isCancelled {
                try? await Task.sleep(for: self.pollInterval)
                guard !Task.isCancelled else { break }
                await self.fetchWeather()
            }
        }

        logger.info("Weather monitor started (30-min interval)")
    }

    public func stop() {
        isRunning = false
        pollTask?.cancel()
        pollTask = nil
        logger.info("Weather monitor stopped")
    }

    // MARK: - Fetch

    private func fetchWeather() async {
        guard let location = locationManager.location else {
            locationManager.requestLocation()
            logger.debug("No location yet; requested update")
            return
        }

        #if canImport(WeatherKit)
        do {
            let service = WeatherService.shared
            let weather = try await service.weather(for: location)
            let current = weather.currentWeather

            let snapshot = WeatherSnapshot(
                temperature: current.temperature.converted(to: .celsius).value,
                feelsLike: current.apparentTemperature.converted(to: .celsius).value,
                humidity: current.humidity,
                uvIndex: current.uvIndex.value,
                condition: current.condition.description,
                pressure: current.pressure.converted(to: .hectopascals).value,
                windSpeed: current.wind.speed.converted(to: .metersPerSecond).value,
                timestamp: current.date
            )

            let previous = currentWeather
            currentWeather = snapshot
            persistSnapshot(snapshot)

            if hasSignificantChange(from: previous, to: snapshot) {
                delegate?.weatherMonitor(self, didUpdate: snapshot)
                submitLifeEvent(snapshot)
            }

            logger.info("Weather updated: \(snapshot.condition), \(String(format: "%.1f", snapshot.temperature))C")
        } catch {
            logger.error("WeatherKit fetch failed: \(error.localizedDescription)")
        }
        #else
        logger.debug("WeatherKit not available on this platform")
        #endif
    }

    // MARK: - Change Detection

    private func hasSignificantChange(from old: WeatherSnapshot?, to new: WeatherSnapshot) -> Bool {
        guard let old else { return true }
        let tempDelta = abs(new.temperature - old.temperature)
        let conditionChanged = new.condition != old.condition
        let uvDelta = abs(new.uvIndex - old.uvIndex)
        return tempDelta >= 2.0 || conditionChanged || uvDelta >= 2
    }

    // MARK: - Life Event Integration

    private func submitLifeEvent(_ snapshot: WeatherSnapshot) {
        let event = LifeEvent(
            type: .weatherChange,
            source: .weather,
            summary: "\(snapshot.condition), \(String(format: "%.1f", snapshot.temperature))C",
            data: [
                "temperature": String(format: "%.1f", snapshot.temperature),
                "feelsLike": String(format: "%.1f", snapshot.feelsLike),
                "humidity": String(format: "%.2f", snapshot.humidity),
                "uvIndex": String(snapshot.uvIndex),
                "condition": snapshot.condition,
                "pressure": String(format: "%.1f", snapshot.pressure),
                "windSpeed": String(format: "%.1f", snapshot.windSpeed),
            ],
            significance: .minor
        )
        LifeMonitoringCoordinator.shared.submitEvent(event)
    }

    // MARK: - Persistence

    private func persistSnapshot(_ snapshot: WeatherSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: Self.persistenceURL, options: .atomic)
        } catch {
            logger.error("Failed to persist weather: \(error.localizedDescription)")
        }
    }

    private func loadPersistedSnapshot() {
        guard FileManager.default.fileExists(atPath: Self.persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.persistenceURL)
            currentWeather = try JSONDecoder().decode(WeatherSnapshot.self, from: data)
            logger.info("Loaded persisted weather snapshot")
        } catch {
            logger.warning("Failed to load persisted weather: \(error.localizedDescription)")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherMonitor: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if currentWeather == nil {
                await fetchWeather()
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let logger = Logger(subsystem: "ai.thea.app", category: "WeatherMonitor")
        logger.error("Location error: \(error.localizedDescription)")
    }
}
