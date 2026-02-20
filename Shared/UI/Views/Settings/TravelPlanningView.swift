// TravelPlanningView.swift
// Thea — Travel planning and itinerary management UI
//
// Trip management with itinerary builder, packing checklist,
// expense tracking, and live flight status via Amadeus.
// Wire-in: TravelIntelligenceService (AAI3-5)

import SwiftUI

struct TravelPlanningView: View {
    @ObservedObject private var manager = TravelManager.shared
    @State private var selectedTab = 0
    @State private var showingAddTrip = false
    @State private var showingFlightStatus = false
    @State private var searchText = ""
    private let travelIntelligence = TravelIntelligenceService.shared

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Upcoming").tag(0)
                Text("Active").tag(1)
                Text("Past").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            Divider().padding(.top, 8)

            tripsList
        }
        .navigationTitle("Travel")
        .searchable(text: $searchText, prompt: "Search trips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddTrip = true } label: {
                    Label("Add Trip", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button { showingFlightStatus = true } label: {
                    Label("Flight Status", systemImage: "airplane.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddTrip) {
            AddTripSheet { trip in
                manager.addTrip(trip)
            }
        }
        .sheet(isPresented: $showingFlightStatus) {
            FlightStatusSheet(service: travelIntelligence)
        }
    }

    @ViewBuilder
    private var tripsList: some View {
        let trips = filteredTrips
        if trips.isEmpty {
            ContentUnavailableView(
                selectedTab == 0 ? "No Upcoming Trips" : selectedTab == 1 ? "No Active Trips" : "No Past Trips",
                systemImage: "airplane",
                description: Text("Plan your next adventure.")
            )
        } else {
            List {
                statsRow
                ForEach(trips) { trip in
                    tripRow(trip)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack {
            StatBadge(label: "Trips", value: "\(manager.trips.count)", icon: "airplane", color: .blue)
            StatBadge(label: "Upcoming", value: "\(manager.upcomingTrips.count)", icon: "calendar", color: .orange)
            StatBadge(label: "Active", value: "\(manager.activeTrips.count)", icon: "location", color: .green)
        }
    }

    private func tripRow(_ trip: TravelTrip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: trip.status.icon)
                    .foregroundStyle(trip.isActive ? .green : .secondary)
                Text(trip.name)
                    .font(.headline)
                Spacer()
                Text(trip.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Image(systemName: "mappin")
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(trip.durationDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(trip.startDate, style: .date)
                Text("–")
                Text(trip.endDate, style: .date)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            if !trip.packingItems.isEmpty {
                ProgressView(value: trip.packedPercentage)
                    .tint(trip.packedPercentage >= 1 ? .green : .blue)
                Text("Packing: \(Int(trip.packedPercentage * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var filteredTrips: [TravelTrip] {
        let base: [TravelTrip]
        switch selectedTab {
        case 0: base = manager.upcomingTrips
        case 1: base = manager.activeTrips
        default: base = manager.pastTrips
        }
        if searchText.isEmpty { return base }
        let q = searchText.lowercased()
        return base.filter { $0.name.lowercased().contains(q) || $0.destination.lowercased().contains(q) }
    }
}

// MARK: - Add Trip Sheet

private struct AddTripSheet: View {
    let onSave: (TravelTrip) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip Name", text: $name)
                    TextField("Destination", text: $destination)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Trip")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trip = TravelTrip(name: name, destination: destination,
                                              startDate: startDate, endDate: endDate)
                        onSave(trip)
                        dismiss()
                    }
                    .disabled(name.isEmpty || destination.isEmpty)
                }
            }
        }
    }
}

// MARK: - Flight Status Sheet

private struct FlightStatusSheet: View {
    let service: TravelIntelligenceService
    @Environment(\.dismiss) private var dismiss
    @State private var carrier = ""
    @State private var flightNum = ""
    @State private var date = Date()
    @State private var results: [FlightStatusResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Flight") {
                    TextField("Carrier (e.g. AA)", text: $carrier)
                    TextField("Flight Number (e.g. 1234)", text: $flightNum)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                if isLoading {
                    Section { ProgressView("Checking flight status…") }
                } else if let err = errorMessage {
                    Section { Text(err).foregroundStyle(.red) }
                } else if !results.isEmpty {
                    Section("Results") {
                        ForEach(results, id: \.flightNumber) { flight in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(flight.carrierCode)\(flight.flightNumber) — \(flight.status)")
                                    .font(.headline)
                                Text("\(flight.departureAirport) → \(flight.arrivalAirport)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let delay = flight.delayMinutes, delay > 0 {
                                    Text("Delay: \(delay) min").foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Flight Status")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 300)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check") { checkFlight() }
                        .disabled(carrier.isEmpty || flightNum.isEmpty)
                }
            }
        }
    }

    private func checkFlight() {
        guard !carrier.isEmpty, !flightNum.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        results = []
        let dateStr = ISO8601DateFormatter().string(from: date).prefix(10).description
        Task {
            do {
                let flights = try await service.flightStatus(
                    carrierCode: carrier.uppercased(),
                    flightNumber: flightNum,
                    date: dateStr
                )
                await MainActor.run {
                    results = flights
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
