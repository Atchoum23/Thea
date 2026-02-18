// VehicleMaintenanceView.swift
// Thea — Vehicle maintenance tracking UI
//
// Vehicle inventory with service records, fuel logs,
// upcoming maintenance reminders, and cost analytics.

import SwiftUI

struct VehicleMaintenanceView: View {
    @ObservedObject private var manager = VehicleManager.shared
    @State private var showingAddVehicle = false
    @State private var selectedVehicle: Vehicle?

    var body: some View {
        #if os(macOS)
        HSplitView {
            vehicleList
                .frame(minWidth: 250, maxWidth: 350)
            detailView
                .frame(minWidth: 400)
        }
        .navigationTitle("Vehicles")
        #else
        NavigationStack {
            vehicleList
                .navigationTitle("Vehicles")
        }
        #endif
    }

    private var vehicleList: some View {
        List(selection: $selectedVehicle) {
            Section {
                HStack {
                    VStatCard(label: "Vehicles", value: "\(manager.vehicles.count)", icon: "car", color: .blue)
                    VStatCard(label: "Need Service", value: "\(manager.vehiclesNeedingService.count)",
                              icon: "wrench", color: .orange)
                }
            }

            Section("My Vehicles") {
                if manager.vehicles.isEmpty {
                    ContentUnavailableView("No Vehicles", systemImage: "car",
                                           description: Text("Add a vehicle to start tracking."))
                } else {
                    ForEach(manager.vehicles) { vehicle in
                        vehicleRow(vehicle)
                            .tag(vehicle)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddVehicle = true } label: {
                    Label("Add Vehicle", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddVehicle) {
            AddVehicleSheet { vehicle in
                manager.addVehicle(vehicle)
            }
        }
    }

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: vehicle.fuelType == .electric ? "bolt.car" : "car")
                    .foregroundStyle(.blue)
                Text(vehicle.displayTitle)
                    .font(.headline)
            }
            HStack {
                Text(vehicle.licensePlate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(vehicle.currentMileage) km")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !vehicle.upcomingMaintenance.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("\(vehicle.upcomingMaintenance.count) service(s) due")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    #if os(macOS)
    @ViewBuilder
    private var detailView: some View {
        if let vehicle = selectedVehicle ?? manager.vehicles.first {
            vehicleDetail(vehicle)
        } else {
            ContentUnavailableView("Select a Vehicle", systemImage: "car",
                                   description: Text("Choose a vehicle to view details."))
        }
    }

    private func vehicleDetail(_ vehicle: Vehicle) -> some View {
        List {
            Section("Overview") {
                LabeledContent("Make & Model", value: vehicle.displayTitle)
                LabeledContent("License Plate", value: vehicle.licensePlate)
                LabeledContent("Fuel Type", value: vehicle.fuelType.displayName)
                LabeledContent("Mileage", value: "\(vehicle.currentMileage) km")
                if let avg = vehicle.averageFuelEconomy {
                    LabeledContent("Avg. Fuel Economy", value: String(format: "%.1f L/100km", avg))
                }
                LabeledContent("Total Service Cost", value: String(format: "CHF %.2f", vehicle.totalServiceCost))
            }

            if !vehicle.upcomingMaintenance.isEmpty {
                Section("Upcoming Maintenance") {
                    ForEach(vehicle.upcomingMaintenance, id: \.serviceType) { schedule in
                        HStack {
                            Image(systemName: "wrench")
                                .foregroundStyle(.orange)
                            Text(schedule.serviceType.displayName)
                            Spacer()
                            if let km = schedule.intervalKm {
                                Text("every \(km) km")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Service History (\(vehicle.serviceRecords.count))") {
                if vehicle.serviceRecords.isEmpty {
                    Text("No service records yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vehicle.serviceRecords.sorted(by: { $0.date > $1.date })) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.type.displayName)
                                    .font(.subheadline)
                                Text(record.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(record.currency) \(record.cost, specifier: "%.2f")")
                                .font(.subheadline)
                        }
                    }
                }
            }

            Section("Fuel Logs (\(vehicle.fuelLogs.count))") {
                if vehicle.fuelLogs.isEmpty {
                    Text("No fuel logs yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vehicle.fuelLogs.sorted(by: { $0.date > $1.date }).prefix(10)) { log in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(log.liters, specifier: "%.1f") L")
                                    .font(.subheadline)
                                Text(log.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(log.currency) \(log.cost, specifier: "%.2f")")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
    #endif
}

// MARK: - Add Vehicle Sheet

private struct AddVehicleSheet: View {
    let onSave: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var licensePlate = ""
    @State private var fuelType: FuelType = .gasoline
    @State private var mileage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Info") {
                    TextField("Name (e.g., My Car)", text: $name)
                    TextField("Make (e.g., Toyota)", text: $make)
                    TextField("Model (e.g., Corolla)", text: $model)
                    #if os(macOS)
                    TextField("Year", value: $year, format: .number)
                    #else
                    Stepper("Year: \(year)", value: $year, in: 1950...2030)
                    #endif
                }
                Section("Details") {
                    TextField("License Plate", text: $licensePlate)
                    Picker("Fuel Type", selection: $fuelType) {
                        ForEach(FuelType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    TextField("Current Mileage (km)", text: $mileage)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }
            .navigationTitle("Add Vehicle")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 350)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let vehicle = Vehicle(
                            name: name, make: make, model: model, year: year,
                            licensePlate: licensePlate,
                            currentMileage: Int(mileage) ?? 0,
                            fuelType: fuelType
                        )
                        onSave(vehicle)
                        dismiss()
                    }
                    .disabled(make.isEmpty || model.isEmpty)
                }
            }
        }
    }
}

// MARK: - V Stat Card

private struct VStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
