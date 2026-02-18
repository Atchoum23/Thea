// TravelManager.swift
// Thea — Travel planning and itinerary management
//
// Manages trips, itineraries, packing lists, and travel notes.
// Integrates with Calendar for scheduling and provides
// trip-level expense tracking.

import Foundation
import OSLog

private let travelLogger = Logger(subsystem: "ai.thea.app", category: "TravelManager")

// MARK: - Models

/// A trip with itinerary, packing, and notes.
struct TravelTrip: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var status: TripStatus
    var legs: [TripLeg]
    var packingItems: [PackingItem]
    var notes: String
    var tags: [String]
    var budgetAmount: Double?
    var budgetCurrency: String
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        status: TripStatus = .planning,
        legs: [TripLeg] = [],
        packingItems: [PackingItem] = [],
        notes: String = "",
        tags: [String] = [],
        budgetAmount: Double? = nil,
        budgetCurrency: String = "CHF"
    ) {
        self.id = UUID()
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.legs = legs
        self.packingItems = packingItems
        self.notes = notes
        self.tags = tags
        self.budgetAmount = budgetAmount
        self.budgetCurrency = budgetCurrency
        self.createdAt = Date()
        self.updatedAt = Date()
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

/// Status of a trip.
enum TripStatus: String, Codable, Sendable, CaseIterable {
    case planning
    case booked
    case active
    case completed
    case cancelled

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

/// A leg of a trip (flight, hotel, activity).
struct TripLeg: Codable, Sendable, Identifiable {
    let id: UUID
    var type: LegType
    var title: String
    var location: String
    var startTime: Date
    var endTime: Date?
    var confirmationCode: String?
    var cost: Double?
    var currency: String
    var notes: String

    enum LegType: String, Codable, Sendable, CaseIterable {
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

    init(type: LegType, title: String, location: String = "", startTime: Date,
         endTime: Date? = nil, confirmationCode: String? = nil,
         cost: Double? = nil, currency: String = "CHF", notes: String = "") {
        self.id = UUID()
        self.type = type
        self.title = title
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.confirmationCode = confirmationCode
        self.cost = cost
        self.currency = currency
        self.notes = notes
    }
}

/// A packing list item.
struct PackingItem: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var category: PackingCategory
    var isPacked: Bool
    var quantity: Int

    enum PackingCategory: String, Codable, Sendable, CaseIterable {
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

    init(name: String, category: PackingCategory = .other, isPacked: Bool = false, quantity: Int = 1) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.isPacked = isPacked
        self.quantity = quantity
    }
}

// MARK: - Manager

@MainActor
final class TravelManager: ObservableObject {
    static let shared = TravelManager()

    @Published private(set) var trips: [TravelTrip] = []

    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/LifeManagement", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            travelLogger.error("Failed to create storage directory: \(error.localizedDescription)")
        }
        storageURL = dir.appendingPathComponent("travel.json")
        loadState()
    }

    // MARK: - CRUD

    func addTrip(_ trip: TravelTrip) {
        trips.append(trip)
        save()
        travelLogger.info("Added trip: \(trip.name) to \(trip.destination)")
    }

    func updateTrip(_ trip: TravelTrip) {
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            var updated = trip
            updated.updatedAt = Date()
            trips[idx] = updated
            save()
        }
    }

    func deleteTrip(id: UUID) {
        trips.removeAll { $0.id == id }
        save()
    }

    // MARK: - Queries

    var upcomingTrips: [TravelTrip] {
        trips.filter(\.isUpcoming).sorted { $0.startDate < $1.startDate }
    }

    var activeTrips: [TravelTrip] {
        trips.filter(\.isActive)
    }

    var pastTrips: [TravelTrip] {
        trips.filter { $0.status == .completed || ($0.endDate < Date() && $0.status != .cancelled) }
            .sorted { $0.endDate > $1.endDate }
    }

    var totalTripCost: Double {
        trips.flatMap(\.legs).compactMap(\.cost).reduce(0, +)
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(trips)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            travelLogger.error("Failed to save travel data: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        let data: Data
        do {
            data = try Data(contentsOf: storageURL)
        } catch {
            travelLogger.error("Failed to read travel data: \(error.localizedDescription)")
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            trips = try decoder.decode([TravelTrip].self, from: data)
        } catch {
            travelLogger.error("Failed to decode travel data: \(error.localizedDescription)")
        }
    }
}
