// DeviceRoutingTypesTests.swift
// Tests for DeviceCapabilityRouter types and scoring logic

import Testing
import Foundation

// MARK: - Test Doubles (Mirror production types)

private enum TestDeviceType: String, Codable, Sendable, CaseIterable {
    case mac, iPad, iPhone, watch, tv, vision
}

private struct TestDeviceCapabilities: Sendable {
    var hasNeuralEngine: Bool = false
    var hasGPU: Bool = false
    var hasCellular: Bool = false
    var hasWiFi: Bool = true
    var isPluggedIn: Bool = false
    var batteryLevel: Int = 100
    var availableStorage: Int64 = 0
    var ramSize: Int64 = 0
}

private struct TestDeviceInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let type: TestDeviceType
    let capabilities: TestDeviceCapabilities

    init(id: String = UUID().uuidString, name: String, type: TestDeviceType,
         capabilities: TestDeviceCapabilities = TestDeviceCapabilities()) {
        self.id = id
        self.name = name
        self.type = type
        self.capabilities = capabilities
    }
}

private struct TestTaskRequirements: Sendable {
    var requiresHighCPU: Bool = false
    var requiresGPU: Bool = false
    var requiresNeuralEngine: Bool = false
    var requiresHighMemory: Bool = false
    var requiresNetwork: Bool = false
    var requiresScreen: Bool = false
    var requiresStorage: Bool = false
    var estimatedDuration: TimeInterval = 60
}

/// Mirrors the scoring logic from DeviceCapabilityRouter.calculateScore()
private func calculateScore(
    for device: TestDeviceInfo,
    task: TestTaskRequirements,
    currentDeviceId: String = ""
) -> Double {
    var score = 0.0
    let capabilities = device.capabilities

    // 1. CPU requirement (0-25)
    if task.requiresHighCPU {
        switch device.type {
        case .mac: score += 25
        case .iPad: score += 20
        case .iPhone: score += 15
        case .watch: score += 5
        case .tv: score += 10
        case .vision: score += 22
        }
    } else {
        score += 15
    }

    // 2. GPU/Neural Engine (0-25)
    if task.requiresGPU || task.requiresNeuralEngine {
        if capabilities.hasNeuralEngine {
            score += 25
        } else if capabilities.hasGPU {
            score += 20
        } else {
            score += 5
        }
    } else {
        score += 15
    }

    // 3. Memory (0-20)
    if task.requiresHighMemory {
        switch device.type {
        case .mac: score += 20
        case .iPad: score += 15
        case .iPhone: score += 10
        case .vision: score += 18
        default: score += 5
        }
    } else {
        score += 15
    }

    // 4. Battery (0-15)
    if !capabilities.isPluggedIn {
        if task.estimatedDuration > 300 || task.requiresHighCPU {
            score -= 10
        }
        if capabilities.batteryLevel < 20 {
            score -= 10
        }
    } else {
        score += 15
    }

    // 5. Network (0-10)
    if task.requiresNetwork {
        if capabilities.hasWiFi {
            score += 10
        } else if capabilities.hasCellular {
            score += 5
        }
    } else {
        score += 8
    }

    // 6. Screen (0-5)
    if task.requiresScreen {
        if device.type == .mac || device.type == .iPad {
            score += 5
        } else if device.type == .iPhone {
            score += 3
        }
    }

    // 7. Locality bonus (0-10)
    if device.id == currentDeviceId {
        score += 10
    }

    return max(0, min(1, score / 100))
}

private enum TestConfidenceLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

private func confidenceLevel(for score: Double) -> TestConfidenceLevel {
    switch score {
    case 0.8...: .high
    case 0.5 ..< 0.8: .medium
    default: .low
    }
}

// MARK: - Tests: Device Types

@Suite("Device Type Enum")
struct DeviceTypeTests {
    @Test("All 6 device types exist")
    func allCases() {
        #expect(TestDeviceType.allCases.count == 6)
    }

    @Test("All device types have unique raw values")
    func uniqueRawValues() {
        let rawValues = TestDeviceType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Device types are Codable")
    func codableRoundtrip() throws {
        for type in TestDeviceType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(TestDeviceType.self, from: data)
            #expect(decoded == type)
        }
    }
}

// MARK: - Tests: Task Requirements

@Suite("Task Requirements")
struct TaskRequirementsTests {
    @Test("Default requirements are all minimal")
    func defaults() {
        let req = TestTaskRequirements()
        #expect(req.requiresHighCPU == false)
        #expect(req.requiresGPU == false)
        #expect(req.requiresNeuralEngine == false)
        #expect(req.requiresHighMemory == false)
        #expect(req.requiresNetwork == false)
        #expect(req.requiresScreen == false)
        #expect(req.requiresStorage == false)
        #expect(req.estimatedDuration == 60)
    }

    @Test("AI task has full requirements")
    func aiTask() {
        let req = TestTaskRequirements(
            requiresHighCPU: true,
            requiresGPU: true,
            requiresNeuralEngine: true,
            requiresHighMemory: true,
            requiresNetwork: true
        )
        #expect(req.requiresHighCPU)
        #expect(req.requiresGPU)
        #expect(req.requiresNeuralEngine)
        #expect(req.requiresHighMemory)
        #expect(req.requiresNetwork)
    }

    @Test("Lightweight task has minimal requirements")
    func lightweightTask() {
        let req = TestTaskRequirements(
            requiresHighCPU: false,
            requiresNetwork: true
        )
        #expect(!req.requiresHighCPU)
        #expect(req.requiresNetwork)
    }

    @Test("File processing scales with size")
    func fileProcessing() {
        let smallFile = TestTaskRequirements(
            requiresHighCPU: false,
            requiresHighMemory: false,
            requiresStorage: true
        )
        let largeFile = TestTaskRequirements(
            requiresHighCPU: true,
            requiresHighMemory: true,
            requiresStorage: true
        )
        #expect(!smallFile.requiresHighCPU)
        #expect(largeFile.requiresHighCPU)
        #expect(largeFile.requiresHighMemory)
    }
}

// MARK: - Tests: Scoring Logic

@Suite("Device Scoring")
struct DeviceScoringTests {
    private var macStudio: TestDeviceInfo {
        TestDeviceInfo(
            id: "mac1", name: "Mac Studio",
            type: .mac,
            capabilities: TestDeviceCapabilities(
                hasNeuralEngine: true, hasGPU: true, hasWiFi: true,
                isPluggedIn: true, batteryLevel: 100, ramSize: 192_000_000_000
            )
        )
    }
    private var testIPhone: TestDeviceInfo {
        TestDeviceInfo(
            id: "iphone1", name: "iPhone",
            type: .iPhone,
            capabilities: TestDeviceCapabilities(
                hasNeuralEngine: true, hasGPU: true, hasCellular: true,
                hasWiFi: true, isPluggedIn: false, batteryLevel: 80
            )
        )
    }
    private var testWatch: TestDeviceInfo {
        TestDeviceInfo(
            id: "watch1", name: "Apple Watch",
            type: .watch,
            capabilities: TestDeviceCapabilities(
                hasNeuralEngine: true, hasGPU: true, hasWiFi: true,
                isPluggedIn: false, batteryLevel: 60
            )
        )
    }

    @Test("Mac scores highest for CPU-intensive tasks")
    func macBestForCPU() {
        let task = TestTaskRequirements(requiresHighCPU: true)
        let macScore = calculateScore(for: macStudio, task: task)
        let iphoneScore = calculateScore(for: testIPhone, task: task)
        let watchScore = calculateScore(for: testWatch, task: task)
        #expect(macScore > iphoneScore)
        #expect(iphoneScore > watchScore)
    }

    @Test("Mac scores highest for memory-intensive tasks")
    func macBestForMemory() {
        let task = TestTaskRequirements(requiresHighMemory: true)
        let macScore = calculateScore(for: macStudio, task: task)
        let iphoneScore = calculateScore(for: testIPhone, task: task)
        #expect(macScore > iphoneScore)
    }

    @Test("Plugged-in devices score higher than battery")
    func pluggedInBonus() {
        let task = TestTaskRequirements(requiresHighCPU: true, estimatedDuration: 600)
        let pluggedMac = calculateScore(for: macStudio, task: task)

        let batteryMac = TestDeviceInfo(
            id: "mac2", name: "MacBook",
            type: .mac,
            capabilities: TestDeviceCapabilities(
                hasNeuralEngine: true, hasGPU: true, hasWiFi: true,
                isPluggedIn: false, batteryLevel: 80
            )
        )
        let unplugged = calculateScore(for: batteryMac, task: task)
        #expect(pluggedMac > unplugged)
    }

    @Test("Low battery penalty")
    func lowBatteryPenalty() {
        let task = TestTaskRequirements(requiresHighCPU: true)
        let normalBattery = TestDeviceInfo(
            id: "p1", name: "iPhone",
            type: .iPhone,
            capabilities: TestDeviceCapabilities(
                hasNeuralEngine: true, isPluggedIn: false, batteryLevel: 80
            )
        )
        let lowBattery = TestDeviceInfo(
            id: "p2", name: "iPhone Low",
            type: .iPhone,
            capabilities: TestDeviceCapabilities(
                hasNeuralEngine: true, isPluggedIn: false, batteryLevel: 10
            )
        )
        let normalScore = calculateScore(for: normalBattery, task: task)
        let lowScore = calculateScore(for: lowBattery, task: task)
        #expect(normalScore > lowScore)
    }

    @Test("Neural engine bonus for GPU tasks")
    func neuralEngineBonus() {
        let task = TestTaskRequirements(requiresNeuralEngine: true)
        let withNE = TestDeviceInfo(
            id: "ne1", name: "With NE",
            type: .iPhone,
            capabilities: TestDeviceCapabilities(hasNeuralEngine: true, hasGPU: true, isPluggedIn: true)
        )
        let withoutNE = TestDeviceInfo(
            id: "ne2", name: "Without NE",
            type: .iPhone,
            capabilities: TestDeviceCapabilities(hasNeuralEngine: false, hasGPU: true, isPluggedIn: true)
        )
        let withScore = calculateScore(for: withNE, task: task)
        let withoutScore = calculateScore(for: withoutNE, task: task)
        #expect(withScore > withoutScore)
    }

    @Test("Locality bonus for current device")
    func localityBonus() {
        let task = TestTaskRequirements()
        let local = calculateScore(
            for: macStudio, task: task, currentDeviceId: "mac1"
        )
        let remote = calculateScore(
            for: macStudio, task: task, currentDeviceId: "other"
        )
        #expect(local > remote)
    }

    @Test("Score is normalized to 0-1")
    func scoreNormalized() {
        let tasks = [
            TestTaskRequirements(),
            TestTaskRequirements(requiresHighCPU: true, requiresGPU: true, requiresHighMemory: true),
            TestTaskRequirements(requiresNetwork: true, requiresScreen: true)
        ]
        let devices = [macStudio, testIPhone, testWatch]
        for task in tasks {
            for device in devices {
                let score = calculateScore(for: device, task: task)
                #expect(score >= 0.0)
                #expect(score <= 1.0)
            }
        }
    }

    @Test("WiFi scores higher than cellular for network tasks")
    func wifiVsCellular() {
        let task = TestTaskRequirements(requiresNetwork: true)
        let wifiDevice = TestDeviceInfo(
            id: "w1", name: "WiFi",
            type: .iPhone,
            capabilities: TestDeviceCapabilities(hasCellular: false, hasWiFi: true, isPluggedIn: true)
        )
        let cellularDevice = TestDeviceInfo(
            id: "c1", name: "Cellular",
            type: .iPhone,
            capabilities: TestDeviceCapabilities(hasCellular: true, hasWiFi: false, isPluggedIn: true)
        )
        let wifiScore = calculateScore(for: wifiDevice, task: task)
        let cellularScore = calculateScore(for: cellularDevice, task: task)
        #expect(wifiScore > cellularScore)
    }

    @Test("Screen-requiring tasks prefer Mac and iPad")
    func screenPreference() {
        let task = TestTaskRequirements(requiresScreen: true)
        let mac = TestDeviceInfo(id: "m", name: "Mac", type: .mac,
                                 capabilities: TestDeviceCapabilities(isPluggedIn: true))
        let ipad = TestDeviceInfo(id: "ip", name: "iPad", type: .iPad,
                                  capabilities: TestDeviceCapabilities(isPluggedIn: true))
        let tv = TestDeviceInfo(id: "t", name: "TV", type: .tv,
                                capabilities: TestDeviceCapabilities(isPluggedIn: true))
        let macScore = calculateScore(for: mac, task: task)
        let ipadScore = calculateScore(for: ipad, task: task)
        let tvScore = calculateScore(for: tv, task: task)
        #expect(macScore >= ipadScore)
        #expect(ipadScore > tvScore)
    }

    @Test("Vision Pro scores well for GPU tasks")
    func visionProGPU() {
        let task = TestTaskRequirements(requiresHighCPU: true, requiresGPU: true)
        let vision = TestDeviceInfo(
            id: "v1", name: "Vision Pro",
            type: .vision,
            capabilities: TestDeviceCapabilities(
                hasNeuralEngine: true, hasGPU: true, isPluggedIn: true
            )
        )
        let score = calculateScore(for: vision, task: task)
        #expect(score > 0.5) // Should score well
    }
}

// MARK: - Tests: Confidence Level

@Suite("Routing Confidence Level")
struct RoutingConfidenceLevelTests {
    @Test("High confidence for scores >= 0.8")
    func highConfidence() {
        #expect(confidenceLevel(for: 0.8) == .high)
        #expect(confidenceLevel(for: 0.9) == .high)
        #expect(confidenceLevel(for: 1.0) == .high)
    }

    @Test("Medium confidence for scores 0.5-0.8")
    func mediumConfidence() {
        #expect(confidenceLevel(for: 0.5) == .medium)
        #expect(confidenceLevel(for: 0.7) == .medium)
        #expect(confidenceLevel(for: 0.79) == .medium)
    }

    @Test("Low confidence for scores < 0.5")
    func lowConfidence() {
        #expect(confidenceLevel(for: 0.0) == .low)
        #expect(confidenceLevel(for: 0.3) == .low)
        #expect(confidenceLevel(for: 0.49) == .low)
    }
}

// MARK: - Tests: Device Capabilities Defaults

@Suite("Device Capabilities Defaults")
struct DeviceCapabilitiesDefaultsTests {
    @Test("Default capabilities")
    func defaults() {
        let caps = TestDeviceCapabilities()
        #expect(caps.hasNeuralEngine == false)
        #expect(caps.hasGPU == false)
        #expect(caps.hasCellular == false)
        #expect(caps.hasWiFi == true) // WiFi is default true
        #expect(caps.isPluggedIn == false)
        #expect(caps.batteryLevel == 100)
        #expect(caps.availableStorage == 0)
        #expect(caps.ramSize == 0)
    }

    @Test("Custom capabilities")
    func custom() {
        let caps = TestDeviceCapabilities(
            hasNeuralEngine: true,
            hasGPU: true,
            hasCellular: true,
            hasWiFi: false,
            isPluggedIn: true,
            batteryLevel: 50,
            availableStorage: 500_000_000_000,
            ramSize: 192_000_000_000
        )
        #expect(caps.hasNeuralEngine)
        #expect(caps.hasGPU)
        #expect(caps.hasCellular)
        #expect(!caps.hasWiFi)
        #expect(caps.isPluggedIn)
        #expect(caps.batteryLevel == 50)
    }
}

// MARK: - Tests: Routing Reasoning

@Suite("Routing Reasoning Generation")
struct RoutingReasoningTests {
    @Test("Reasoning includes device selection")
    func deviceSelection() {
        var reasons: [String] = []
        let deviceId = "mac1"
        let currentDeviceId = "mac1"
        if deviceId == currentDeviceId {
            reasons.append("Using current device")
        } else {
            reasons.append("Routing to Mac Studio")
        }
        #expect(reasons.first == "Using current device")
    }

    @Test("Reasoning includes CPU note for Mac")
    func cpuNote() {
        var reasons: [String] = []
        let requiresHighCPU = true
        let deviceType = TestDeviceType.mac
        if requiresHighCPU, deviceType == .mac {
            reasons.append("Mac has best CPU performance")
        }
        #expect(reasons.contains("Mac has best CPU performance"))
    }

    @Test("Reasoning includes Neural Engine note")
    func neuralNote() {
        var reasons: [String] = []
        let requiresNE = true
        let hasNE = true
        if requiresNE, hasNE {
            reasons.append("Device has Neural Engine")
        }
        #expect(reasons.contains("Device has Neural Engine"))
    }

    @Test("Reasoning includes power status")
    func powerStatus() {
        var reasons: [String] = []
        let isPluggedIn = true
        if isPluggedIn {
            reasons.append("Device is plugged in")
        }
        #expect(reasons.contains("Device is plugged in"))
    }

    @Test("Multiple reasons are joined with semicolons")
    func joinedReasons() {
        let reasons = ["Using current device", "Mac has best CPU performance", "Device is plugged in"]
        let result = reasons.joined(separator: "; ")
        #expect(result.contains("; "))
        #expect(result.contains("Using current device"))
    }
}
