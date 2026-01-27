//
//  HomeKitService.swift
//  Thea
//
//  HomeKit integration for smart home control
//

import Combine
import Foundation
#if canImport(HomeKit)
    import HomeKit
#endif

// MARK: - HomeKit Service

/// Service for controlling smart home devices via HomeKit
@MainActor
public class HomeKitService: NSObject, ObservableObject {
    public static let shared = HomeKitService()

    // MARK: - Published State

    @Published public private(set) var isAvailable = false
    @Published public private(set) var homes: [SmartHome] = []
    @Published public private(set) var primaryHome: SmartHome?
    @Published public private(set) var accessories: [SmartAccessory] = []
    @Published public private(set) var scenes: [SmartScene] = []
    @Published public private(set) var automations: [SmartAutomation] = []
    @Published public private(set) var lastError: HomeKitError?

    // MARK: - HomeKit Manager

    #if canImport(HomeKit)
        private var homeManager: HMHomeManager?
    #endif

    // MARK: - Initialization

    override private init() {
        super.init()
        #if canImport(HomeKit)
            setupHomeKit()
        #endif
    }

    #if canImport(HomeKit)
        private func setupHomeKit() {
            homeManager = HMHomeManager()
            homeManager?.delegate = self
        }
    #endif

    // MARK: - Home Management

    /// Get all available homes
    public func refreshHomes() async {
        #if canImport(HomeKit)
            guard let manager = homeManager else { return }

            homes = manager.homes.map { SmartHome(from: $0) }
            // Use first home as primary (primaryHome was deprecated in iOS 16.1)
            let firstHome = manager.homes.first
            primaryHome = firstHome.map { SmartHome(from: $0) }

            // Refresh accessories for primary home
            if let primary = firstHome {
                accessories = primary.accessories.map { SmartAccessory(from: $0) }
                // Filter to user-created scenes (exclude built-in types)
                scenes = primary.actionSets.filter { actionSet in
                    actionSet.actionSetType == HMActionSetTypeUserDefined
                }.map { SmartScene(from: $0) }
            }

            isAvailable = true
        #endif
    }

    // MARK: - Accessory Control

    /// Turn on/off an accessory
    public func setAccessoryPower(accessoryId: String, on: Bool) async throws {
        #if canImport(HomeKit)
            guard let manager = homeManager,
                  let home = manager.homes.first,
                  let accessory = home.accessories.first(where: { $0.uniqueIdentifier.uuidString == accessoryId })
            else {
                throw HomeKitError.accessoryNotFound
            }

            // Find power characteristic
            for service in accessory.services {
                for characteristic in service.characteristics where characteristic.characteristicType == HMCharacteristicTypePowerState {
                    try await characteristic.writeValue(on)
                    return
                }
            }

            throw HomeKitError.characteristicNotFound
        #else
            throw HomeKitError.notAvailable
        #endif
    }

    /// Set brightness for a light
    public func setLightBrightness(accessoryId: String, brightness: Int) async throws {
        #if canImport(HomeKit)
            guard let manager = homeManager,
                  let home = manager.homes.first,
                  let accessory = home.accessories.first(where: { $0.uniqueIdentifier.uuidString == accessoryId })
            else {
                throw HomeKitError.accessoryNotFound
            }

            for service in accessory.services {
                for characteristic in service.characteristics where characteristic.characteristicType == HMCharacteristicTypeBrightness {
                    try await characteristic.writeValue(brightness)
                    return
                }
            }

            throw HomeKitError.characteristicNotFound
        #else
            throw HomeKitError.notAvailable
        #endif
    }

    /// Set thermostat temperature
    public func setThermostatTemperature(accessoryId: String, temperature: Double) async throws {
        #if canImport(HomeKit)
            guard let manager = homeManager,
                  let home = manager.homes.first,
                  let accessory = home.accessories.first(where: { $0.uniqueIdentifier.uuidString == accessoryId })
            else {
                throw HomeKitError.accessoryNotFound
            }

            for service in accessory.services {
                for characteristic in service.characteristics where characteristic.characteristicType == HMCharacteristicTypeTargetTemperature {
                    try await characteristic.writeValue(temperature)
                    return
                }
            }

            throw HomeKitError.characteristicNotFound
        #else
            throw HomeKitError.notAvailable
        #endif
    }

    /// Lock/unlock a door lock
    public func setLockState(accessoryId: String, locked: Bool) async throws {
        #if canImport(HomeKit)
            guard let manager = homeManager,
                  let home = manager.homes.first,
                  let accessory = home.accessories.first(where: { $0.uniqueIdentifier.uuidString == accessoryId })
            else {
                throw HomeKitError.accessoryNotFound
            }

            // Lock mechanism target state: 0 = unsecured, 1 = secured
            let targetState = locked ? 1 : 0

            for service in accessory.services {
                for characteristic in service.characteristics where characteristic.characteristicType == HMCharacteristicTypeTargetLockMechanismState {
                    try await characteristic.writeValue(targetState)
                    return
                }
            }

            throw HomeKitError.characteristicNotFound
        #else
            throw HomeKitError.notAvailable
        #endif
    }

    // MARK: - Scene Control

    /// Execute a scene
    public func executeScene(sceneId: String) async throws {
        #if canImport(HomeKit)
            guard let manager = homeManager,
                  let home = manager.homes.first,
                  let actionSet = home.actionSets.first(where: { $0.uniqueIdentifier.uuidString == sceneId })
            else {
                throw HomeKitError.sceneNotFound
            }

            try await home.executeActionSet(actionSet)
        #else
            throw HomeKitError.notAvailable
        #endif
    }

    // MARK: - Room Management

    /// Get accessories in a specific room
    public func getAccessoriesInRoom(roomName: String) -> [SmartAccessory] {
        #if canImport(HomeKit)
            guard let manager = homeManager,
                  let home = manager.homes.first,
                  let room = home.rooms.first(where: { $0.name == roomName })
            else {
                return []
            }

            return room.accessories.map { SmartAccessory(from: $0) }
        #else
            return []
        #endif
    }

    // MARK: - Natural Language Commands

    /// Process a natural language home command
    public func processCommand(_ command: String) async throws -> String {
        let lowercased = command.lowercased()

        // Parse command intent
        if lowercased.contains("turn on") || lowercased.contains("switch on") {
            let deviceName = extractDeviceName(from: command)
            if let accessory = findAccessoryByName(deviceName) {
                try await setAccessoryPower(accessoryId: accessory.id, on: true)
                return "Turned on \(accessory.name)"
            }
        } else if lowercased.contains("turn off") || lowercased.contains("switch off") {
            let deviceName = extractDeviceName(from: command)
            if let accessory = findAccessoryByName(deviceName) {
                try await setAccessoryPower(accessoryId: accessory.id, on: false)
                return "Turned off \(accessory.name)"
            }
        } else if lowercased.contains("dim") || lowercased.contains("brightness") {
            // Extract brightness level
            let brightness = extractBrightness(from: command)
            let deviceName = extractDeviceName(from: command)
            if let accessory = findAccessoryByName(deviceName) {
                try await setLightBrightness(accessoryId: accessory.id, brightness: brightness)
                return "Set \(accessory.name) brightness to \(brightness)%"
            }
        } else if lowercased.contains("lock") {
            let deviceName = extractDeviceName(from: command)
            if let accessory = findAccessoryByName(deviceName) {
                let shouldLock = !lowercased.contains("unlock")
                try await setLockState(accessoryId: accessory.id, locked: shouldLock)
                return shouldLock ? "Locked \(accessory.name)" : "Unlocked \(accessory.name)"
            }
        } else if lowercased.contains("scene") || lowercased.contains("activate") {
            let sceneName = extractSceneName(from: command)
            if let scene = findSceneByName(sceneName) {
                try await executeScene(sceneId: scene.id)
                return "Activated scene: \(scene.name)"
            }
        }

        throw HomeKitError.commandNotRecognized
    }

    // MARK: - Helpers

    private func extractDeviceName(from command: String) -> String {
        // Simple extraction - in production use NLP
        let words = command.components(separatedBy: " ")
        if let index = words.firstIndex(where: { $0.lowercased() == "the" }) {
            return words.dropFirst(index + 1).joined(separator: " ")
        }
        return command
    }

    private func extractBrightness(from command: String) -> Int {
        let numbers = command.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        return numbers.first ?? 50
    }

    private func extractSceneName(from command: String) -> String {
        command.replacingOccurrences(of: "activate scene", with: "")
            .replacingOccurrences(of: "run scene", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func findAccessoryByName(_ name: String) -> SmartAccessory? {
        accessories.first { $0.name.lowercased().contains(name.lowercased()) }
    }

    private func findSceneByName(_ name: String) -> SmartScene? {
        scenes.first { $0.name.lowercased().contains(name.lowercased()) }
    }
}

// MARK: - HomeKit Delegate

#if canImport(HomeKit)
    extension HomeKitService: HMHomeManagerDelegate {
        nonisolated public func homeManagerDidUpdateHomes(_: HMHomeManager) {
            Task { @MainActor in
                await refreshHomes()
            }
        }

        nonisolated public func homeManagerDidUpdatePrimaryHome(_: HMHomeManager) {
            Task { @MainActor in
                await refreshHomes()
            }
        }
    }
#endif

// MARK: - Data Models

public struct SmartHome: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let isPrimary: Bool
    public let roomCount: Int
    public let accessoryCount: Int

    #if canImport(HomeKit)
        init(from home: HMHome) {
            id = home.uniqueIdentifier.uuidString
            name = home.name
            isPrimary = home.isPrimary
            roomCount = home.rooms.count
            accessoryCount = home.accessories.count
        }
    #endif

    public init(id: String, name: String, isPrimary: Bool, roomCount: Int, accessoryCount: Int) {
        self.id = id
        self.name = name
        self.isPrimary = isPrimary
        self.roomCount = roomCount
        self.accessoryCount = accessoryCount
    }
}

public struct SmartAccessory: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let room: String?
    public let category: AccessoryCategory
    public let isReachable: Bool
    public let manufacturer: String?
    public let model: String?

    public enum AccessoryCategory: String, Sendable {
        case light = "Light"
        case thermostat = "Thermostat"
        case lock = "Lock"
        case outlet = "Outlet"
        case fan = "Fan"
        case sensor = "Sensor"
        case camera = "Camera"
        case doorbell = "Doorbell"
        case garageDoor = "Garage Door"
        case securitySystem = "Security System"
        case other = "Other"
    }

    #if canImport(HomeKit)
        init(from accessory: HMAccessory) {
            id = accessory.uniqueIdentifier.uuidString
            name = accessory.name
            room = accessory.room?.name
            isReachable = accessory.isReachable
            manufacturer = accessory.manufacturer
            model = accessory.model

            // Determine category using string constants
            let categoryType = accessory.category.categoryType
            if categoryType == HMAccessoryCategoryTypeLightbulb {
                category = .light
            } else if categoryType == HMAccessoryCategoryTypeThermostat {
                category = .thermostat
            } else if categoryType == HMAccessoryCategoryTypeDoorLock {
                category = .lock
            } else if categoryType == HMAccessoryCategoryTypeOutlet {
                category = .outlet
            } else if categoryType == HMAccessoryCategoryTypeFan {
                category = .fan
            } else if categoryType == HMAccessoryCategoryTypeSensor {
                category = .sensor
            } else if categoryType == HMAccessoryCategoryTypeVideoDoorbell {
                category = .doorbell
            } else if categoryType == HMAccessoryCategoryTypeGarageDoorOpener {
                category = .garageDoor
            } else if categoryType == HMAccessoryCategoryTypeSecuritySystem {
                category = .securitySystem
            } else {
                category = .other
            }
        }
    #endif

    public init(id: String, name: String, room: String?, category: AccessoryCategory, isReachable: Bool, manufacturer: String?, model: String?) {
        self.id = id
        self.name = name
        self.room = room
        self.category = category
        self.isReachable = isReachable
        self.manufacturer = manufacturer
        self.model = model
    }
}

public struct SmartScene: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let actionCount: Int

    #if canImport(HomeKit)
        init(from actionSet: HMActionSet) {
            id = actionSet.uniqueIdentifier.uuidString
            name = actionSet.name
            actionCount = actionSet.actions.count
        }
    #endif

    public init(id: String, name: String, actionCount: Int) {
        self.id = id
        self.name = name
        self.actionCount = actionCount
    }
}

public struct SmartAutomation: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let isEnabled: Bool
    public let triggerType: String

    public init(id: String, name: String, isEnabled: Bool, triggerType: String) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.triggerType = triggerType
    }
}

// MARK: - Errors

public enum HomeKitError: Error, LocalizedError, Sendable {
    case notAvailable
    case accessoryNotFound
    case sceneNotFound
    case characteristicNotFound
    case commandNotRecognized
    case permissionDenied
    case communicationFailed

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "HomeKit is not available on this device"
        case .accessoryNotFound:
            "Accessory not found"
        case .sceneNotFound:
            "Scene not found"
        case .characteristicNotFound:
            "Device characteristic not found"
        case .commandNotRecognized:
            "Command not recognized"
        case .permissionDenied:
            "HomeKit permission denied"
        case .communicationFailed:
            "Failed to communicate with device"
        }
    }
}
