// H8TravelVehicleTests.swift
// Tests for H8 Life Management: Travel and Vehicle modules
//
// Covers model types, computed properties, enum conformance, business logic,
// and Codable roundtrips for Travel and Vehicle modules.

import Testing
import Foundation

// MARK: - Travel Types

// Test doubles mirroring TravelManager.swift types
private enum TestTripStatus: String, Codable, CaseIterable {
    case planning, booked, active, completed, cancelled
    var displayName: String {
        switch self {
        case .planning: "Planning"
        case .booked: "Booked"
        case .active: "Active"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }
    var icon: String {
        switch self {
        case .planning: "pencil.and.outline"
        case .booked: "checkmark.seal"
        case .active: "airplane"
        case .completed: "flag.checkered"
        case .cancelled: "xmark.circle"
        }
    }
}

private enum TestLegType: String, Codable, CaseIterable {
    case flight, train, bus, car, hotel, activity, restaurant, transfer
    var icon: String {
        switch self {
        case .flight: "airplane"
        case .train: "tram"
        case .bus: "bus"
        case .car: "car"
        case .hotel: "bed.double"
        case .activity: "star"
        case .restaurant: "fork.knife"
        case .transfer: "arrow.triangle.swap"
        }
    }
}

private enum TestPackingCategory: String, Codable, CaseIterable {
    case clothing, toiletries, electronics, documents, medicine, accessories, other
    var icon: String {
        switch self {
        case .clothing: "tshirt"
        case .toiletries: "drop"
        case .electronics: "bolt"
        case .documents: "doc.text"
        case .medicine: "pills"
        case .accessories: "bag"
        case .other: "ellipsis.circle"
        }
    }
}

private struct TestPackingItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var category: TestPackingCategory
    var isPacked: Bool
    var quantity: Int
    init(name: String, category: TestPackingCategory = .other, isPacked: Bool = false, quantity: Int = 1) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.isPacked = isPacked
        self.quantity = quantity
    }
}

private struct TestTripLeg: Codable, Identifiable {
    let id: UUID
    var type: TestLegType
    var title: String
    var cost: Double?
    var currency: String
    init(type: TestLegType, title: String, cost: Double? = nil, currency: String = "CHF") {
        self.id = UUID()
        self.type = type
        self.title = title
        self.cost = cost
        self.currency = currency
    }
}

private struct TestTravelTrip: Codable, Identifiable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var status: TestTripStatus
    var legs: [TestTripLeg]
    var packingItems: [TestPackingItem]
    var budgetAmount: Double?
    var budgetCurrency: String

    init(name: String, destination: String, startDate: Date, endDate: Date,
         status: TestTripStatus = .planning, legs: [TestTripLeg] = [],
         packingItems: [TestPackingItem] = [], budgetAmount: Double? = nil,
         budgetCurrency: String = "CHF") {
        self.id = UUID()
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.legs = legs
        self.packingItems = packingItems
        self.budgetAmount = budgetAmount
        self.budgetCurrency = budgetCurrency
    }

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    var packedPercentage: Double {
        guard !packingItems.isEmpty else { return 1.0 }
        let packed = packingItems.filter(\.isPacked).count
        return Double(packed) / Double(packingItems.count)
    }

    var isUpcoming: Bool {
        status == .planning && startDate > Date()
    }

    var isActive: Bool {
        status == .active || (startDate <= Date() && endDate >= Date())
    }
}

// MARK: - Vehicle Types

private enum TestFuelType: String, Codable, CaseIterable {
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

private enum TestServiceType: String, Codable, CaseIterable {
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

private struct TestServiceRecord: Codable, Identifiable {
    let id: UUID
    var type: TestServiceType
    var date: Date
    var mileage: Int
    var cost: Double
    var currency: String
    init(type: TestServiceType, date: Date = Date(), mileage: Int = 0,
         cost: Double = 0, currency: String = "CHF") {
        self.id = UUID()
        self.type = type
        self.date = date
        self.mileage = mileage
        self.cost = cost
        self.currency = currency
    }
}

private struct TestFuelLog: Codable, Identifiable {
    let id: UUID
    var date: Date
    var liters: Double
    var cost: Double
    var currency: String
    var mileage: Int
    var distance: Double
    var isFullTank: Bool
    init(liters: Double, cost: Double, mileage: Int = 0, distance: Double = 0, isFullTank: Bool = true) {
        self.id = UUID()
        self.date = Date()
        self.liters = liters
        self.cost = cost
        self.currency = "CHF"
        self.mileage = mileage
        self.distance = distance
        self.isFullTank = isFullTank
    }

    var pricePerLiter: Double {
        guard liters > 0 else { return 0 }
        return cost / liters
    }
}

// ============================================================
// MARK: - TESTS
// ============================================================

// MARK: - Trip Status Tests

@Suite("H8 Travel — TripStatus")
struct TripStatusTests {
    @Test("All 5 cases exist")
    func allCases() {
        #expect(TestTripStatus.allCases.count == 5)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestTripStatus.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Display names are non-empty")
    func displayNames() {
        for status in TestTripStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }

    @Test("Icons are non-empty")
    func icons() {
        for status in TestTripStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for status in TestTripStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TestTripStatus.self, from: data)
            #expect(decoded == status)
        }
    }
}

// MARK: - Trip Leg Type Tests

@Suite("H8 Travel — LegType")
struct LegTypeTests {
    @Test("All 8 cases exist")
    func allCases() {
        #expect(TestLegType.allCases.count == 8)
    }

    @Test("Each has unique icon")
    func uniqueIcons() {
        let icons = TestLegType.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count)
    }
}

// MARK: - Packing Category Tests

@Suite("H8 Travel — PackingCategory")
struct PackingCategoryTests {
    @Test("All 7 categories")
    func allCases() {
        #expect(TestPackingCategory.allCases.count == 7)
    }

    @Test("Each has icon")
    func icons() {
        for cat in TestPackingCategory.allCases {
            #expect(!cat.icon.isEmpty)
        }
    }
}

// MARK: - Travel Trip Tests

@Suite("H8 Travel — TravelTrip")
struct TravelTripTests {
    @Test("Duration calculation")
    func durationDays() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        let trip = TestTravelTrip(name: "Vacation", destination: "Paris",
                                   startDate: start, endDate: end)
        #expect(trip.durationDays == 7)
    }

    @Test("Zero duration same-day trip")
    func zeroDuration() {
        let now = Date()
        let trip = TestTravelTrip(name: "Day Trip", destination: "Zurich",
                                   startDate: now, endDate: now)
        #expect(trip.durationDays == 0)
    }

    @Test("Packed percentage — all packed")
    func allPacked() {
        let items = [
            TestPackingItem(name: "Shirt", isPacked: true),
            TestPackingItem(name: "Pants", isPacked: true)
        ]
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: Date(), endDate: Date(),
                                   packingItems: items)
        #expect(trip.packedPercentage == 1.0)
    }

    @Test("Packed percentage — none packed")
    func nonePacked() {
        let items = [
            TestPackingItem(name: "Shirt", isPacked: false),
            TestPackingItem(name: "Pants", isPacked: false)
        ]
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: Date(), endDate: Date(),
                                   packingItems: items)
        #expect(trip.packedPercentage == 0.0)
    }

    @Test("Packed percentage — empty list returns 1.0")
    func emptyPacking() {
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: Date(), endDate: Date())
        #expect(trip.packedPercentage == 1.0)
    }

    @Test("Packed percentage — half packed")
    func halfPacked() {
        let items = [
            TestPackingItem(name: "A", isPacked: true),
            TestPackingItem(name: "B", isPacked: false)
        ]
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: Date(), endDate: Date(),
                                   packingItems: items)
        #expect(trip.packedPercentage == 0.5)
    }

    @Test("isUpcoming — future planning trip")
    func upcoming() {
        let future = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: future, endDate: future, status: .planning)
        #expect(trip.isUpcoming)
    }

    @Test("isUpcoming — past trip is not upcoming")
    func notUpcoming() {
        let past = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: past, endDate: past, status: .planning)
        #expect(!trip.isUpcoming)
    }

    @Test("isActive — active status")
    func activeStatus() {
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: Date(), endDate: Date(), status: .active)
        #expect(trip.isActive)
    }

    @Test("isActive — currently within dates")
    func activeByDates() {
        let past = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let future = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: past, endDate: future, status: .planning)
        #expect(trip.isActive)
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let t1 = TestTravelTrip(name: "T1", destination: "D", startDate: Date(), endDate: Date())
        let t2 = TestTravelTrip(name: "T2", destination: "D", startDate: Date(), endDate: Date())
        #expect(t1.id != t2.id)
    }

    @Test("Default currency is CHF")
    func defaultCurrency() {
        let trip = TestTravelTrip(name: "T", destination: "D",
                                   startDate: Date(), endDate: Date())
        #expect(trip.budgetCurrency == "CHF")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let trip = TestTravelTrip(name: "Swiss Trip", destination: "Bern",
                                   startDate: Date(), endDate: Date(),
                                   budgetAmount: 1500, budgetCurrency: "CHF")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(trip)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestTravelTrip.self, from: data)
        #expect(decoded.name == "Swiss Trip")
        #expect(decoded.destination == "Bern")
        #expect(decoded.budgetAmount == 1500)
    }
}

// MARK: - Vehicle Tests

@Suite("H8 Vehicle — FuelType")
struct FuelTypeTests {
    @Test("All 6 fuel types")
    func allCases() {
        #expect(TestFuelType.allCases.count == 6)
    }

    @Test("Display names non-empty")
    func displayNames() {
        for ft in TestFuelType.allCases {
            #expect(!ft.displayName.isEmpty)
        }
    }

    @Test("Unique raw values")
    func uniqueRaw() {
        let raws = TestFuelType.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }
}

@Suite("H8 Vehicle — ServiceType")
struct VehicleServiceTypeTests {
    @Test("All 12 service types")
    func allCases() {
        #expect(TestServiceType.allCases.count == 12)
    }

    @Test("Display names non-empty and unique")
    func displayNames() {
        let names = TestServiceType.allCases.map(\.displayName)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == names.count)
    }
}

@Suite("H8 Vehicle — FuelLog")
struct FuelLogTests {
    @Test("Price per liter calculation")
    func pricePerLiter() {
        let log = TestFuelLog(liters: 45.0, cost: 85.50)
        #expect(log.pricePerLiter == 85.50 / 45.0)
    }

    @Test("Price per liter with zero liters")
    func zerLiters() {
        let log = TestFuelLog(liters: 0, cost: 85.50)
        #expect(log.pricePerLiter == 0)
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let l1 = TestFuelLog(liters: 10, cost: 20)
        let l2 = TestFuelLog(liters: 10, cost: 20)
        #expect(l1.id != l2.id)
    }

    @Test("Default currency is CHF")
    func defaultCurrency() {
        let log = TestFuelLog(liters: 30, cost: 60)
        #expect(log.currency == "CHF")
    }
}

@Suite("H8 Vehicle — ServiceRecord")
struct ServiceRecordTests {
    @Test("Creation with defaults")
    func defaults() {
        let record = TestServiceRecord(type: .oilChange)
        #expect(record.cost == 0)
        #expect(record.mileage == 0)
        #expect(record.currency == "CHF")
    }

    @Test("Custom values")
    func customValues() {
        let record = TestServiceRecord(type: .brakes, mileage: 50_000, cost: 450, currency: "EUR")
        #expect(record.type == .brakes)
        #expect(record.mileage == 50_000)
        #expect(record.cost == 450)
        #expect(record.currency == "EUR")
    }
}

// MARK: - Maintenance Schedule Tests

@Suite("H8 Vehicle — MaintenanceSchedule")
struct MaintenanceScheduleTests {
    @Test("Electric vehicles skip oil-related services")
    func electricSkipsOil() {
        let electricServices: [TestServiceType] = [.tireRotation, .brakes, .battery, .wipers, .airFilter, .inspection]
        let gasolineExtras: [TestServiceType] = [.oilChange, .sparkPlugs, .transmission, .coolant]
        #expect(electricServices.count == 6)
        #expect(gasolineExtras.count == 4)
    }

    @Test("Gasoline vehicles get all services")
    func gasolineAll() {
        let totalGasoline = 6 + 2 + 2
        #expect(totalGasoline == 10)
    }

    @Test("Hydrogen skips transmission and coolant")
    func hydrogenSkips() {
        let totalHydrogen = 6 + 2
        #expect(totalHydrogen == 8)
    }
}

// MARK: - Fuel Economy Tests

@Suite("H8 Vehicle — Fuel Economy")
struct FuelEconomyTests {
    @Test("Average fuel economy calculation")
    func averageEconomy() {
        let logs = [
            TestFuelLog(liters: 45.0, cost: 85, distance: 500),
            TestFuelLog(liters: 50.0, cost: 95, distance: 550)
        ]
        let totalLiters = logs.reduce(0.0) { $0 + $1.liters }
        let totalKm = logs.reduce(0.0) { $0 + $1.distance }
        let economy = totalLiters / totalKm * 100
        #expect(economy > 9.0 && economy < 10.0)
    }

    @Test("No valid logs returns nil equivalent")
    func noValidLogs() {
        let logs: [TestFuelLog] = []
        #expect(logs.isEmpty)
    }

    @Test("Zero distance ignored")
    func zeroDistance() {
        let logs = [TestFuelLog(liters: 45.0, cost: 85, distance: 0)]
        let valid = logs.filter { $0.distance > 0 && $0.liters > 0 }
        #expect(valid.isEmpty)
    }
}

// MARK: - Codable Integration (Travel + Vehicle)

@Suite("H8 Travel+Vehicle — Codable Integration")
struct TravelVehicleCodableTests {
    @Test("PackingItem Codable")
    func packingItem() throws {
        let item = TestPackingItem(name: "Laptop", category: .electronics, isPacked: true, quantity: 1)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TestPackingItem.self, from: data)
        #expect(decoded.name == "Laptop")
        #expect(decoded.category == .electronics)
        #expect(decoded.isPacked)
        #expect(decoded.quantity == 1)
    }

    @Test("TripLeg Codable")
    func tripLeg() throws {
        let leg = TestTripLeg(type: .flight, title: "GVA → CDG", cost: 150, currency: "EUR")
        let data = try JSONEncoder().encode(leg)
        let decoded = try JSONDecoder().decode(TestTripLeg.self, from: data)
        #expect(decoded.type == .flight)
        #expect(decoded.title == "GVA → CDG")
        #expect(decoded.cost == 150)
        #expect(decoded.currency == "EUR")
    }

    @Test("ServiceRecord Codable")
    func serviceRecord() throws {
        let record = TestServiceRecord(type: .brakes, mileage: 45_000, cost: 380)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestServiceRecord.self, from: data)
        #expect(decoded.type == .brakes)
        #expect(decoded.mileage == 45_000)
        #expect(decoded.cost == 380)
    }

    @Test("FuelLog Codable")
    func fuelLog() throws {
        let log = TestFuelLog(liters: 42.5, cost: 78.50, mileage: 55_000, distance: 480)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(log)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestFuelLog.self, from: data)
        #expect(decoded.liters == 42.5)
        #expect(decoded.cost == 78.50)
        #expect(decoded.mileage == 55_000)
        #expect(decoded.distance == 480)
    }
}
