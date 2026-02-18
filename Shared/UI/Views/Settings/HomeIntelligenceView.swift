// HomeIntelligenceView.swift
// Thea — Smart home control and monitoring via HomeKit
//
// Provides a unified dashboard for managing smart home devices,
// scenes, and automations with AI-assisted natural language control.

import SwiftUI

struct HomeIntelligenceView: View {
    @ObservedObject private var homeService = HomeKitService.shared
    @State private var searchText = ""
    @State private var showingCommandInput = false
    @State private var commandText = ""
    @State private var commandResult: String?
    @State private var commandError: String?
    @State private var selectedRoom: String?

    private var filteredAccessories: [SmartAccessory] {
        let base: [SmartAccessory]
        if let room = selectedRoom {
            base = homeService.accessories.filter { $0.room == room }
        } else {
            base = homeService.accessories
        }
        if searchText.isEmpty { return base }
        return base.filter { accessory in
            accessory.name.localizedCaseInsensitiveContains(searchText)
                || (accessory.room?.localizedCaseInsensitiveContains(searchText) ?? false)
                || accessory.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var rooms: [String] {
        Array(Set(homeService.accessories.compactMap(\.room))).sorted()
    }

    var body: some View {
        Group {
            if homeService.isAvailable {
                availableContent
            } else {
                unavailableContent
            }
        }
        .navigationTitle("Home")
        .task {
            await homeService.refreshHomes()
        }
    }

    // MARK: - Available Content

    @ViewBuilder
    private var availableContent: some View {
        #if os(macOS)
        HSplitView {
            sidebarContent
                .frame(minWidth: 220, maxWidth: 320)
            detailContent
                .frame(minWidth: 400)
        }
        #else
        NavigationStack {
            detailContent
        }
        #endif
    }

    private var sidebarContent: some View {
        List {
            // Home summary
            if let primary = homeService.primaryHome {
                Section("Home") {
                    Label(primary.name, systemImage: "house.fill")
                    Label("\(primary.roomCount) rooms", systemImage: "square.split.2x2")
                    Label("\(primary.accessoryCount) devices", systemImage: "powerplug")
                }
            }

            // Room filter
            Section("Rooms") {
                Button {
                    selectedRoom = nil
                } label: {
                    Label("All Rooms", systemImage: "rectangle.grid.2x2")
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedRoom == nil ? .accentColor : .primary)

                ForEach(rooms, id: \.self) { room in
                    Button {
                        selectedRoom = room
                    } label: {
                        Label(room, systemImage: "door.left.hand.open")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedRoom == room ? .accentColor : .primary)
                }
            }

            // Scenes
            if !homeService.scenes.isEmpty {
                Section("Scenes") {
                    ForEach(homeService.scenes) { scene in
                        Button {
                            Task {
                                do {
                                    try await homeService.executeScene(sceneId: scene.id)
                                    commandResult = "Activated: \(scene.name)"
                                } catch {
                                    commandError = error.localizedDescription
                                }
                            }
                        } label: {
                            Label(scene.name, systemImage: "theatermask.and.paintbrush")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Stats bar
                statsBar

                // Command result/error banner
                if let result = commandResult {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(result)
                        Spacer()
                        Button {
                            commandResult = nil
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                if let error = commandError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                        Spacer()
                        Button {
                            commandError = nil
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Natural language command
                commandSection

                // Devices
                devicesSection
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Search devices")
    }

    // MARK: - Components

    private var statsBar: some View {
        HStack(spacing: 16) {
            statCard(
                title: "Devices",
                value: "\(homeService.accessories.count)",
                icon: "powerplug"
            )
            statCard(
                title: "Reachable",
                value: "\(homeService.accessories.filter(\.isReachable).count)",
                icon: "wifi"
            )
            statCard(
                title: "Rooms",
                value: "\(rooms.count)",
                icon: "square.split.2x2"
            )
            statCard(
                title: "Scenes",
                value: "\(homeService.scenes.count)",
                icon: "theatermask.and.paintbrush"
            )
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice Command")
                .font(.headline)

            HStack {
                TextField("e.g., Turn on living room lights", text: $commandText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        executeCommand()
                    }

                Button("Send") {
                    executeCommand()
                }
                .disabled(commandText.isEmpty)
            }

            Text("Try: \"Turn on the lights\", \"Set brightness to 50%\", \"Activate movie scene\"")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Devices")
                    .font(.headline)
                Spacer()
                if let room = selectedRoom {
                    Text(room)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if filteredAccessories.isEmpty {
                ContentUnavailableView(
                    "No Devices Found",
                    systemImage: "powerplug.fill",
                    description: Text(
                        homeService.accessories.isEmpty
                            ? "Add devices in the Home app to see them here"
                            : "No devices match your search"
                    )
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 180, maximum: 250)),
                ], spacing: 12) {
                    ForEach(filteredAccessories) { accessory in
                        accessoryCard(accessory)
                    }
                }
            }
        }
    }

    private func accessoryCard(_ accessory: SmartAccessory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconFor(accessory.category))
                    .font(.title2)
                    .foregroundColor(accessory.isReachable ? .accentColor : .secondary)
                Spacer()
                Circle()
                    .fill(accessory.isReachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            Text(accessory.name)
                .font(.headline)
                .lineLimit(1)

            if let room = accessory.room {
                Text(room)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(accessory.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                Spacer()
                if let manufacturer = accessory.manufacturer {
                    Text(manufacturer)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Quick action buttons for controllable devices
            if accessory.isReachable {
                HStack(spacing: 8) {
                    switch accessory.category {
                    case .light, .outlet:
                        Button("On") {
                            toggleAccessory(accessory, on: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Off") {
                            toggleAccessory(accessory, on: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    case .lock:
                        Button("Lock") {
                            lockAccessory(accessory, locked: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Unlock") {
                            lockAccessory(accessory, locked: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func executeCommand() {
        guard !commandText.isEmpty else { return }
        let command = commandText
        commandText = ""
        commandResult = nil
        commandError = nil

        Task {
            do {
                let result = try await homeService.processCommand(command)
                commandResult = result
            } catch {
                commandError = error.localizedDescription
            }
        }
    }

    private func toggleAccessory(_ accessory: SmartAccessory, on: Bool) {
        Task {
            do {
                try await homeService.setAccessoryPower(accessoryId: accessory.id, on: on)
                commandResult = on ? "Turned on \(accessory.name)" : "Turned off \(accessory.name)"
            } catch {
                commandError = error.localizedDescription
            }
        }
    }

    private func lockAccessory(_ accessory: SmartAccessory, locked: Bool) {
        Task {
            do {
                try await homeService.setLockState(accessoryId: accessory.id, locked: locked)
                commandResult = locked ? "Locked \(accessory.name)" : "Unlocked \(accessory.name)"
            } catch {
                commandError = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func iconFor(_ category: SmartAccessory.AccessoryCategory) -> String {
        switch category {
        case .light: "lightbulb.fill"
        case .thermostat: "thermometer"
        case .lock: "lock.fill"
        case .outlet: "poweroutlet.type.b"
        case .fan: "fan.fill"
        case .sensor: "sensor"
        case .camera: "video.fill"
        case .doorbell: "bell.fill"
        case .garageDoor: "door.garage.open"
        case .securitySystem: "shield.checkered"
        case .other: "powerplug"
        }
    }

    // MARK: - Unavailable Content

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label("HomeKit Not Available", systemImage: "house.fill")
        } description: {
            Text("HomeKit is not configured or accessible. Set up your smart home in the Home app first.")
        } actions: {
            Button("Refresh") {
                Task {
                    await homeService.refreshHomes()
                }
            }
        }
    }
}
