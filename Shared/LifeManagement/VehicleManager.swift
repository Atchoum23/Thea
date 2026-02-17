// VehicleManager.swift
// Thea — Vehicle maintenance tracking
//
// Tracks vehicles, service records, fuel logs, and upcoming
// maintenance reminders with configurable intervals.

import Foundation
import OSLog

private let vehicleLogger = Logger(subsystem: "ai.thea.app", category: "VehicleManager")

// MARK: - Models

/// A vehicle with service history and fuel tracking.
struct Vehicle: Codable, Sendable, Identifiable, Hashable {
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: UUID
    var name: String
    var make: String
    var model: String
    var year: Int
    var licensePlate: String
    var vin: String?
    var currentMileage: Int
    var fuelType: FuelType
    var serviceRecords: [ServiceRecord]
    var fuelLogs: [FuelLog]
    var insuranceExpiryDate: Date?
    var inspectionDueDate: Date?
    var notes: String
    var createdAt: Date

    init(
        name: String, make: String, model: String, year: Int,
        licensePlate: String = "", vin: String? = nil,
        currentMileage: Int = 0, fuelType: FuelType = .gasoline,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.make = make
        self.model = model
        self.year = year
        self.licensePlate = licensePlate
        self.vin = vin
        self.currentMileage = currentMileage
        self.fuelType = fuelType
        self.serviceRecords = []
        self.fuelLogs = []
        self.insuranceExpiryDate = nil
        self.inspectionDueDate = nil
        self.notes = notes
        self.createdAt = Date()
    }

    var displayTitle: String { "\(year) \(make) \(model)" }

    var totalServiceCost: Double {
        serviceRecords.reduce(0) { $0 + $1.cost }
    }

    var averageFuelEconomy: Double? {
        let validLogs = fuelLogs.filter { $0.distance > 0 && $0.liters > 0 }
        guard !validLogs.isEmpty else { return nil }
        let totalLiters = validLogs.reduce(0.0) { $0 + $1.liters }
        let totalKm = validLogs.reduce(0.0) { $0 + $1.distance }
        return totalLiters / totalKm * 100 // L/100km
    }

    /// Services due within the next 30 days or past due.
    var upcomingMaintenance: [MaintenanceSchedule] {
        MaintenanceSchedule.defaults(for: fuelType).filter { schedule in
            guard let lastService = serviceRecords
                .filter({ $0.type == schedule.serviceType })
                .sorted(by: { $0.date > $1.date })
                .first else {
                return true // Never serviced — overdue
            }

            if let intervalKm = schedule.intervalKm {
                let kmSince = currentMileage - lastService.mileage
                if kmSince >= intervalKm { return true }
            }
            if let intervalMonths = schedule.intervalMonths {
                let monthsSince = Calendar.current.dateComponents([.month], from: lastService.date, to: Date()).month ?? 0
                if monthsSince >= intervalMonths { return true }
            }
            return false
        }
    }
}

enum FuelType: String, Codable, Sendable, CaseIterable {
    case gasoline, diesel, electric, hybrid, hydrogen, lpg

    var displayName: String {
        switch self {
        case .gasoline: "Gasoline"
        case .diesel: "Diesel"
        case .electric: "Electric"
        case .hybrid: "Hybrid"
        case .hydrogen: "Hydrogen"
        case .lpg: "LPG"
        }
    }
}

/// A service/maintenance record.
struct ServiceRecord: Codable, Sendable, Identifiable {
    let id: UUID
    var type: ServiceType
    var date: Date
    var mileage: Int
    var cost: Double
    var currency: String
    var provider: String
    var notes: String

    enum ServiceType: String, Codable, Sendable, CaseIterable {
        case oilChange, tireRotation, brakes, battery, inspection, airFilter
        case transmission, coolant, sparkPlugs, wipers, alignment, other

        var displayName: String {
            switch self {
            case .oilChange: "Oil Change"
            case .tireRotation: "Tire Rotation"
            case .brakes: "Brakes"
            case .battery: "Battery"
            case .inspection: "Inspection"
            case .airFilter: "Air Filter"
            case .transmission: "Transmission"
            case .coolant: "Coolant"
            case .sparkPlugs: "Spark Plugs"
            case .wipers: "Wipers"
            case .alignment: "Alignment"
            case .other: "Other"
            }
        }
    }

    init(type: ServiceType, date: Date = Date(), mileage: Int = 0, cost: Double = 0,
         currency: String = "CHF", provider: String = "", notes: String = "") {
        self.id = UUID()
        self.type = type
        self.date = date
        self.mileage = mileage
        self.cost = cost
        self.currency = currency
        self.provider = provider
        self.notes = notes
    }
}

/// A fuel log entry.
struct FuelLog: Codable, Sendable, Identifiable {
    let id: UUID
    var date: Date
    var liters: Double
    var cost: Double
    var currency: String
    var mileage: Int
    var distance: Double
    var isFullTank: Bool

    init(date: Date = Date(), liters: Double, cost: Double, currency: String = "CHF",
         mileage: Int = 0, distance: Double = 0, isFullTank: Bool = true) {
        self.id = UUID()
        self.date = date
        self.liters = liters
        self.cost = cost
        self.currency = currency
        self.mileage = mileage
        self.distance = distance
        self.isFullTank = isFullTank
    }

    var pricePerLiter: Double {
        guard liters > 0 else { return 0 }
        return cost / liters
    }
}

/// Maintenance schedule template.
struct MaintenanceSchedule: Codable, Sendable {
    let serviceType: ServiceRecord.ServiceType
    let intervalKm: Int?
    let intervalMonths: Int?

    static func defaults(for fuelType: FuelType) -> [MaintenanceSchedule] {
        var schedules = [
            MaintenanceSchedule(serviceType: .tireRotation, intervalKm: 10_000, intervalMonths: 12),
            MaintenanceSchedule(serviceType: .brakes, intervalKm: 30_000, intervalMonths: 24),
            MaintenanceSchedule(serviceType: .battery, intervalKm: nil, intervalMonths: 48),
            MaintenanceSchedule(serviceType: .wipers, intervalKm: nil, intervalMonths: 12),
            MaintenanceSchedule(serviceType: .airFilter, intervalKm: 20_000, intervalMonths: 24),
            MaintenanceSchedule(serviceType: .inspection, intervalKm: nil, intervalMonths: 12)
        ]
        if fuelType != .electric {
            schedules.append(MaintenanceSchedule(serviceType: .oilChange, intervalKm: 10_000, intervalMonths: 12))
            schedules.append(MaintenanceSchedule(serviceType: .sparkPlugs, intervalKm: 50_000, intervalMonths: nil))
        }
        if fuelType != .electric && fuelType != .hydrogen {
            schedules.append(MaintenanceSchedule(serviceType: .transmission, intervalKm: 60_000, intervalMonths: nil))
            schedules.append(MaintenanceSchedule(serviceType: .coolant, intervalKm: 40_000, intervalMonths: 36))
        }
        return schedules
    }
}

// MARK: - Manager

@MainActor
final class VehicleManager: ObservableObject {
    static let shared = VehicleManager()

    @Published private(set) var vehicles: [Vehicle] = []

    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/LifeManagement", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("vehicles.json")
        loadState()
    }

    // MARK: - CRUD

    func addVehicle(_ vehicle: Vehicle) {
        vehicles.append(vehicle)
        save()
        vehicleLogger.info("Added vehicle: \(vehicle.displayTitle)")
    }

    func updateVehicle(_ vehicle: Vehicle) {
        if let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            vehicles[idx] = vehicle
            save()
        }
    }

    func deleteVehicle(id: UUID) {
        vehicles.removeAll { $0.id == id }
        save()
    }

    func addServiceRecord(vehicleID: UUID, record: ServiceRecord) {
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
            vehicles[idx].serviceRecords.append(record)
            if record.mileage > vehicles[idx].currentMileage {
                vehicles[idx].currentMileage = record.mileage
            }
            save()
        }
    }

    func addFuelLog(vehicleID: UUID, log: FuelLog) {
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
            vehicles[idx].fuelLogs.append(log)
            if log.mileage > vehicles[idx].currentMileage {
                vehicles[idx].currentMileage = log.mileage
            }
            save()
        }
    }

    // MARK: - Queries

    var totalMaintenanceCost: Double {
        vehicles.reduce(0) { $0 + $1.totalServiceCost }
    }

    var vehiclesNeedingService: [Vehicle] {
        vehicles.filter { !$0.upcomingMaintenance.isEmpty }
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(vehicles) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([Vehicle].self, from: data) {
            vehicles = loaded
        }
    }
}
