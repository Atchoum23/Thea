// H8HomeIntelligenceTests.swift
// Tests for H8 Life Management: HomeKit / HomeIntelligence module
//
// Covers data models, enum conformance, computed properties, error types,
// and natural language command parsing for the HomeKit integration.

import Testing
import Foundation

// MARK: - Test Doubles (mirroring HomeKitService types)

private enum TestAccessoryCategory: String, CaseIterable, Sendable {
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

private struct TestSmartHome: Identifiable, Sendable {
    let id: String
    let name: String
    let isPrimary: Bool
    let roomCount: Int
    let accessoryCount: Int
}

private struct TestSmartAccessory: Identifiable, Sendable {
    let id: String
    let name: String
    let room: String?
    let category: TestAccessoryCategory
    let isReachable: Bool
    let manufacturer: String?
    let model: String?
}

private struct TestSmartScene: Identifiable, Sendable {
    let id: String
    let name: String
    let actionCount: Int
}

private struct TestSmartAutomation: Identifiable, Sendable {
    let id: String
    let name: String
    let isEnabled: Bool
    let triggerType: String
}

private enum TestHomeKitError: Error, LocalizedError, Sendable {
    case notAvailable
    case accessoryNotFound
    case sceneNotFound
    case characteristicNotFound
    case commandNotRecognized
    case permissionDenied
    case communicationFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable: "HomeKit is not available on this device"
        case .accessoryNotFound: "Accessory not found"
        case .sceneNotFound: "Scene not found"
        case .characteristicNotFound: "Device characteristic not found"
        case .commandNotRecognized: "Command not recognized"
        case .permissionDenied: "HomeKit permission denied"
        case .communicationFailed: "Failed to communicate with device"
        }
    }
}

// MARK: - NL Command Parser (mirrors HomeKitService logic)

private enum TestCommandParser {
    enum CommandIntent: Equatable {
        case turnOn(deviceName: String)
        case turnOff(deviceName: String)
        case setBrightness(deviceName: String, level: Int)
        case lock(deviceName: String)
        case unlock(deviceName: String)
        case activateScene(sceneName: String)
        case unknown
    }

    static func parse(_ command: String) -> CommandIntent {
        let lowercased = command.lowercased()

        if lowercased.contains("turn on") || lowercased.contains("switch on") {
            return .turnOn(deviceName: extractDeviceName(from: command))
        } else if lowercased.contains("turn off") || lowercased.contains("switch off") {
            return .turnOff(deviceName: extractDeviceName(from: command))
        } else if lowercased.contains("dim") || lowercased.contains("brightness") {
            return .setBrightness(
                deviceName: extractDeviceName(from: command),
                level: extractBrightness(from: command)
            )
        } else if lowercased.contains("unlock") {
            return .unlock(deviceName: extractDeviceName(from: command))
        } else if lowercased.contains("lock") {
            return .lock(deviceName: extractDeviceName(from: command))
        } else if lowercased.contains("scene") || lowercased.contains("activate") {
            return .activateScene(sceneName: extractSceneName(from: command))
        }

        return .unknown
    }

    static func extractDeviceName(from command: String) -> String {
        let words = command.components(separatedBy: " ")
        if let index = words.firstIndex(where: { $0.lowercased() == "the" }) {
            return words.dropFirst(index + 1).joined(separator: " ")
        }
        return command
    }

    static func extractBrightness(from command: String) -> Int {
        let numbers = command.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        return numbers.first ?? 50
    }

    static func extractSceneName(from command: String) -> String {
        command.replacingOccurrences(of: "activate scene", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "run scene", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
    }

    static func findAccessory(named name: String, in accessories: [TestSmartAccessory]) -> TestSmartAccessory? {
        accessories.first { $0.name.lowercased().contains(name.lowercased()) }
    }
}

// MARK: - Tests

@Suite("H8 Home — AccessoryCategory")
struct AccessoryCategoryTests {
    @Test("All 11 categories exist")
    func allCases() {
        #expect(TestAccessoryCategory.allCases.count == 11)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let rawValues = TestAccessoryCategory.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Display names are human-readable")
    func displayNames() {
        #expect(TestAccessoryCategory.light.rawValue == "Light")
        #expect(TestAccessoryCategory.thermostat.rawValue == "Thermostat")
        #expect(TestAccessoryCategory.garageDoor.rawValue == "Garage Door")
        #expect(TestAccessoryCategory.securitySystem.rawValue == "Security System")
    }
}

@Suite("H8 Home — SmartHome Model")
struct SmartHomeModelTests {
    @Test("Creation with all properties")
    func creation() {
        let home = TestSmartHome(id: "h1", name: "My House", isPrimary: true, roomCount: 5, accessoryCount: 12)
        #expect(home.id == "h1")
        #expect(home.name == "My House")
        #expect(home.isPrimary == true)
        #expect(home.roomCount == 5)
        #expect(home.accessoryCount == 12)
    }

    @Test("Non-primary home")
    func nonPrimary() {
        let home = TestSmartHome(id: "h2", name: "Vacation Home", isPrimary: false, roomCount: 3, accessoryCount: 6)
        #expect(home.isPrimary == false)
    }

    @Test("Identifiable — unique IDs")
    func identifiable() {
        let h1 = TestSmartHome(id: "a", name: "A", isPrimary: true, roomCount: 1, accessoryCount: 1)
        let h2 = TestSmartHome(id: "b", name: "B", isPrimary: false, roomCount: 1, accessoryCount: 1)
        #expect(h1.id != h2.id)
    }
}

@Suite("H8 Home — SmartAccessory Model")
struct SmartAccessoryModelTests {
    @Test("Light accessory creation")
    func lightAccessory() {
        let acc = TestSmartAccessory(
            id: "a1", name: "Living Room Light", room: "Living Room",
            category: .light, isReachable: true, manufacturer: "Philips", model: "Hue A19"
        )
        #expect(acc.name == "Living Room Light")
        #expect(acc.room == "Living Room")
        #expect(acc.category == .light)
        #expect(acc.isReachable == true)
        #expect(acc.manufacturer == "Philips")
        #expect(acc.model == "Hue A19")
    }

    @Test("Unreachable accessory")
    func unreachable() {
        let acc = TestSmartAccessory(
            id: "a2", name: "Garden Camera", room: "Garden",
            category: .camera, isReachable: false, manufacturer: nil, model: nil
        )
        #expect(acc.isReachable == false)
        #expect(acc.manufacturer == nil)
    }

    @Test("Accessory without room")
    func noRoom() {
        let acc = TestSmartAccessory(
            id: "a3", name: "Portable Sensor", room: nil,
            category: .sensor, isReachable: true, manufacturer: "Eve", model: nil
        )
        #expect(acc.room == nil)
    }

    @Test("Room filtering")
    func roomFiltering() {
        let accessories = [
            TestSmartAccessory(id: "1", name: "Lamp 1", room: "Bedroom", category: .light, isReachable: true, manufacturer: nil, model: nil),
            TestSmartAccessory(id: "2", name: "Lamp 2", room: "Kitchen", category: .light, isReachable: true, manufacturer: nil, model: nil),
            TestSmartAccessory(id: "3", name: "Thermostat", room: "Bedroom", category: .thermostat, isReachable: true, manufacturer: nil, model: nil)
        ]
        let bedroomDevices = accessories.filter { $0.room == "Bedroom" }
        #expect(bedroomDevices.count == 2)
    }

    @Test("Reachability filtering")
    func reachabilityFiltering() {
        let accessories = [
            TestSmartAccessory(id: "1", name: "Lamp", room: nil, category: .light, isReachable: true, manufacturer: nil, model: nil),
            TestSmartAccessory(id: "2", name: "Lock", room: nil, category: .lock, isReachable: false, manufacturer: nil, model: nil),
            TestSmartAccessory(id: "3", name: "Fan", room: nil, category: .fan, isReachable: true, manufacturer: nil, model: nil)
        ]
        let reachable = accessories.filter(\.isReachable)
        #expect(reachable.count == 2)
    }
}

@Suite("H8 Home — SmartScene Model")
struct SmartSceneModelTests {
    @Test("Scene creation")
    func creation() {
        let scene = TestSmartScene(id: "s1", name: "Movie Night", actionCount: 5)
        #expect(scene.id == "s1")
        #expect(scene.name == "Movie Night")
        #expect(scene.actionCount == 5)
    }

    @Test("Empty scene")
    func emptyScene() {
        let scene = TestSmartScene(id: "s2", name: "Empty", actionCount: 0)
        #expect(scene.actionCount == 0)
    }
}

@Suite("H8 Home — SmartAutomation Model")
struct SmartAutomationModelTests {
    @Test("Enabled automation")
    func enabled() {
        let auto = TestSmartAutomation(id: "auto1", name: "Sunset Lights", isEnabled: true, triggerType: "time")
        #expect(auto.isEnabled == true)
        #expect(auto.triggerType == "time")
    }

    @Test("Disabled automation")
    func disabled() {
        let auto = TestSmartAutomation(id: "auto2", name: "Morning Routine", isEnabled: false, triggerType: "location")
        #expect(auto.isEnabled == false)
    }
}

@Suite("H8 Home — HomeKitError")
struct HomeKitErrorTests {
    @Test("All 7 error cases have descriptions")
    func allDescriptions() {
        let errors: [TestHomeKitError] = [
            .notAvailable, .accessoryNotFound, .sceneNotFound,
            .characteristicNotFound, .commandNotRecognized,
            .permissionDenied, .communicationFailed
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Specific error messages")
    func specificMessages() {
        #expect(TestHomeKitError.notAvailable.errorDescription!.contains("not available"))
        #expect(TestHomeKitError.accessoryNotFound.errorDescription!.contains("not found"))
        #expect(TestHomeKitError.commandNotRecognized.errorDescription!.contains("not recognized"))
        #expect(TestHomeKitError.permissionDenied.errorDescription!.contains("denied"))
    }

    @Test("Errors are unique")
    func uniqueDescriptions() {
        let descriptions: [String] = [
            TestHomeKitError.notAvailable,
            .accessoryNotFound,
            .sceneNotFound,
            .characteristicNotFound,
            .commandNotRecognized,
            .permissionDenied,
            .communicationFailed
        ].compactMap(\.errorDescription)
        #expect(Set(descriptions).count == 7)
    }
}

@Suite("H8 Home — NL Command Parsing")
struct CommandParsingTests {
    @Test("Turn on command")
    func turnOn() {
        let intent = TestCommandParser.parse("Turn on the living room lights")
        #expect(intent == .turnOn(deviceName: "living room lights"))
    }

    @Test("Turn off command")
    func turnOff() {
        let intent = TestCommandParser.parse("Turn off the kitchen")
        #expect(intent == .turnOff(deviceName: "kitchen"))
    }

    @Test("Switch on command")
    func switchOn() {
        let intent = TestCommandParser.parse("Switch on the porch light")
        #expect(intent == .turnOn(deviceName: "porch light"))
    }

    @Test("Brightness with number")
    func brightness() {
        let intent = TestCommandParser.parse("Set brightness to 75 for the lamp")
        if case let .setBrightness(_, level) = intent {
            #expect(level == 75)
        } else {
            Issue.record("Expected setBrightness")
        }
    }

    @Test("Dim command defaults to 50")
    func dimDefault() {
        let intent = TestCommandParser.parse("Dim the hallway")
        if case let .setBrightness(_, level) = intent {
            #expect(level == 50)
        } else {
            Issue.record("Expected setBrightness")
        }
    }

    @Test("Lock command")
    func lock() {
        let intent = TestCommandParser.parse("Lock the front door")
        #expect(intent == .lock(deviceName: "front door"))
    }

    @Test("Unlock command")
    func unlock() {
        let intent = TestCommandParser.parse("Unlock the front door")
        #expect(intent == .unlock(deviceName: "front door"))
    }

    @Test("Activate scene")
    func activateScene() {
        let intent = TestCommandParser.parse("Activate scene Movie Night")
        if case let .activateScene(name) = intent {
            #expect(name == "Movie Night")
        } else {
            Issue.record("Expected activateScene")
        }
    }

    @Test("Unknown command")
    func unknown() {
        let intent = TestCommandParser.parse("What is the temperature?")
        #expect(intent == .unknown)
    }

    @Test("Case insensitive")
    func caseInsensitive() {
        let intent = TestCommandParser.parse("TURN ON THE lamp")
        #expect(intent == .turnOn(deviceName: "lamp"))
    }
}

@Suite("H8 Home — Device Name Extraction")
struct DeviceNameExtractionTests {
    @Test("Extract after 'the'")
    func afterThe() {
        let name = TestCommandParser.extractDeviceName(from: "Turn on the living room light")
        #expect(name == "living room light")
    }

    @Test("No 'the' returns full command")
    func noThe() {
        let name = TestCommandParser.extractDeviceName(from: "lamp on")
        #expect(name == "lamp on")
    }
}

@Suite("H8 Home — Brightness Extraction")
struct BrightnessExtractionTests {
    @Test("Extract number from string")
    func extractNumber() {
        let brightness = TestCommandParser.extractBrightness(from: "Set to 75 percent")
        #expect(brightness == 75)
    }

    @Test("No number defaults to 50")
    func noNumber() {
        let brightness = TestCommandParser.extractBrightness(from: "Dim the lights")
        #expect(brightness == 50)
    }

    @Test("Multiple numbers uses first")
    func multipleNumbers() {
        let brightness = TestCommandParser.extractBrightness(from: "Set 30 or 60")
        #expect(brightness == 30)
    }
}

@Suite("H8 Home — Accessory Search")
struct AccessorySearchTests {
    fileprivate let accessories: [TestSmartAccessory] = [
        TestSmartAccessory(id: "1", name: "Living Room Light", room: "Living Room", category: .light, isReachable: true, manufacturer: nil, model: nil),
        TestSmartAccessory(id: "2", name: "Kitchen Thermostat", room: "Kitchen", category: .thermostat, isReachable: true, manufacturer: nil, model: nil),
        TestSmartAccessory(id: "3", name: "Front Door Lock", room: "Hallway", category: .lock, isReachable: false, manufacturer: nil, model: nil)
    ]

    @Test("Find by exact name")
    func exactName() {
        let found = TestCommandParser.findAccessory(named: "Living Room Light", in: accessories)
        #expect(found?.id == "1")
    }

    @Test("Find by partial name")
    func partialName() {
        let found = TestCommandParser.findAccessory(named: "kitchen", in: accessories)
        #expect(found?.id == "2")
    }

    @Test("Case insensitive search")
    func caseInsensitive() {
        let found = TestCommandParser.findAccessory(named: "FRONT DOOR", in: accessories)
        #expect(found?.id == "3")
    }

    @Test("Not found returns nil")
    func notFound() {
        let found = TestCommandParser.findAccessory(named: "garage", in: accessories)
        #expect(found == nil)
    }

    @Test("Empty list returns nil")
    func emptyList() {
        let found = TestCommandParser.findAccessory(named: "lamp", in: [])
        #expect(found == nil)
    }
}

@Suite("H8 Home — Room Grouping")
struct RoomGroupingTests {
    @Test("Unique room extraction")
    func uniqueRooms() {
        let accessories = [
            TestSmartAccessory(id: "1", name: "L1", room: "Living Room", category: .light, isReachable: true, manufacturer: nil, model: nil),
            TestSmartAccessory(id: "2", name: "L2", room: "Living Room", category: .light, isReachable: true, manufacturer: nil, model: nil),
            TestSmartAccessory(id: "3", name: "T1", room: "Kitchen", category: .thermostat, isReachable: true, manufacturer: nil, model: nil),
            TestSmartAccessory(id: "4", name: "S1", room: nil, category: .sensor, isReachable: true, manufacturer: nil, model: nil)
        ]
        let rooms = Array(Set(accessories.compactMap(\.room))).sorted()
        #expect(rooms.count == 2)
        #expect(rooms.contains("Kitchen"))
        #expect(rooms.contains("Living Room"))
    }

    @Test("All nil rooms gives empty list")
    func allNilRooms() {
        let accessories = [
            TestSmartAccessory(id: "1", name: "S1", room: nil, category: .sensor, isReachable: true, manufacturer: nil, model: nil)
        ]
        let rooms = accessories.compactMap(\.room)
        #expect(rooms.isEmpty)
    }
}
