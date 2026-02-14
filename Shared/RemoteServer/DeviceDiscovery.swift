// DeviceDiscovery.swift
// Bonjour/mDNS device discovery for Thea remote sessions
// Enables discovery of other Thea instances on local network

import Foundation
import Network
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Discovered Device

/// Represents a discovered Thea device on the network
struct BonjourDiscoveredDevice: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let name: String
    let hostName: String
    let port: Int
    let platform: DevicePlatform
    let capabilities: DeviceCapabilities
    var lastSeen: Date
    var isOnline: Bool

    enum DevicePlatform: String, Codable, Sendable {
        case macOS = "macOS"
        case iOS = "iOS"
        case iPadOS = "iPadOS"
        case watchOS = "watchOS"
        case tvOS = "tvOS"
        case unknown = "Unknown"
    }

    struct DeviceCapabilities: Codable, Sendable, Hashable {
        var supportsLocalModels: Bool
        var supportsScreenSharing: Bool
        var supportsAudioMonitoring: Bool
        var supportsRemoteExecution: Bool
        var maxModelMemoryGB: Double
        var gpuCores: Int

        static let `default` = DeviceCapabilities(
            supportsLocalModels: true,
            supportsScreenSharing: true,
            supportsAudioMonitoring: true,
            supportsRemoteExecution: true,
            maxModelMemoryGB: 16,
            gpuCores: 8
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BonjourDiscoveredDevice, rhs: BonjourDiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Device Discovery Service

/// Service for discovering Thea devices on the network using Bonjour/mDNS
@MainActor
@Observable
final class DeviceDiscoveryService {
    static let shared = DeviceDiscoveryService()

    // Service type for Thea discovery
    static let serviceType = "_thea._tcp"
    static let serviceDomain = "local."

    // State
    private(set) var isDiscovering = false
    private(set) var discoveredDevices: [BonjourDiscoveredDevice] = []
    private(set) var lastError: Error?

    // Callbacks
    var onDeviceDiscovered: ((BonjourDiscoveredDevice) -> Void)?
    var onDeviceLost: ((BonjourDiscoveredDevice) -> Void)?
    var onError: ((Error) -> Void)?

    // Internal
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var deviceTimeouts: [UUID: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Discovery

    /// Start discovering Thea devices on the network
    func startDiscovery() {
        guard !isDiscovering else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: Self.serviceDomain), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleBrowserStateChange(state)
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleBrowseResults(results, changes: changes)
            }
        }

        browser?.start(queue: .main)
        isDiscovering = true
    }

    /// Stop discovery
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isDiscovering = false

        // Cancel all timeout tasks
        deviceTimeouts.values.forEach { $0.cancel() }
        deviceTimeouts.removeAll()
    }

    /// Refresh discovery
    func refresh() {
        stopDiscovery()
        discoveredDevices.removeAll()
        startDiscovery()
    }

    // MARK: - Advertising

    /// Start advertising this device on the network
    func startAdvertising(port: UInt16, name: String, capabilities: BonjourDiscoveredDevice.DeviceCapabilities) throws {
        let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        parameters.includePeerToPeer = true

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

        // Create TXT record with device info
        let txtRecord = createTXTRecord(name: name, capabilities: capabilities)

        listener?.service = NWListener.Service(
            name: name,
            type: Self.serviceType,
            domain: Self.serviceDomain,
            txtRecord: txtRecord
        )

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleListenerStateChange(state)
            }
        }

        listener?.start(queue: .main)
    }

    /// Stop advertising
    func stopAdvertising() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Browser Handlers

    private func handleBrowserStateChange(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            break
        case .failed(let error):
            lastError = error
            onError?(error)
        case .cancelled:
            isDiscovering = false
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                handleDeviceAdded(result)
            case .removed(let result):
                handleDeviceRemoved(result)
            case .changed(old: _, new: let result, flags: _):
                handleDeviceChanged(result)
            case .identical:
                break
            @unknown default:
                break
            }
        }
    }

    private func handleDeviceAdded(_ result: NWBrowser.Result) {
        // Resolve the endpoint to get full device info
        resolveDevice(result)
    }

    private func handleDeviceRemoved(_ result: NWBrowser.Result) {
        if case .service(let name, _, _, _) = result.endpoint {
            if let device = discoveredDevices.first(where: { $0.name == name }) {
                discoveredDevices.removeAll { $0.name == name }
                onDeviceLost?(device)
            }
        }
    }

    private func handleDeviceChanged(_ result: NWBrowser.Result) {
        resolveDevice(result)
    }

    // MARK: - Device Resolution

    private func resolveDevice(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint else { return }

        // Parse TXT record if available
        let capabilities: BonjourDiscoveredDevice.DeviceCapabilities
        let platform: BonjourDiscoveredDevice.DevicePlatform

        if case .bonjour(let txtRecord) = result.metadata {
            capabilities = parseCapabilities(from: txtRecord)
            platform = parsePlatform(from: txtRecord)
        } else {
            capabilities = .default
            platform = .unknown
        }

        // Create connection to resolve host
        let parameters = NWParameters()
        let connection = NWConnection(to: result.endpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let path = connection.currentPath,
                   let remoteEndpoint = path.remoteEndpoint,
                   case .hostPort(let host, let port) = remoteEndpoint {

                    let hostName: String
                    switch host {
                    case .name(let name, _):
                        hostName = name
                    case .ipv4(let addr):
                        hostName = "\(addr)"
                    case .ipv6(let addr):
                        hostName = "\(addr)"
                    @unknown default:
                        hostName = name
                    }

                    let device = BonjourDiscoveredDevice(
                        id: UUID(),
                        name: name,
                        hostName: hostName,
                        port: Int(port.rawValue),
                        platform: platform,
                        capabilities: capabilities,
                        lastSeen: Date(),
                        isOnline: true
                    )

                    Task { @MainActor in
                        self?.addOrUpdateDevice(device)
                    }
                }
                connection.cancel()
            }
        }

        connection.start(queue: .main)

        // Timeout after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            connection.cancel()
        }
    }

    private func addOrUpdateDevice(_ device: BonjourDiscoveredDevice) {
        if let index = discoveredDevices.firstIndex(where: { $0.name == device.name }) {
            var updated = device
            updated = BonjourDiscoveredDevice(
                id: discoveredDevices[index].id,  // Preserve ID
                name: device.name,
                hostName: device.hostName,
                port: device.port,
                platform: device.platform,
                capabilities: device.capabilities,
                lastSeen: Date(),
                isOnline: true
            )
            discoveredDevices[index] = updated
        } else {
            discoveredDevices.append(device)
            onDeviceDiscovered?(device)
        }

        // Set up timeout for device
        setupDeviceTimeout(device)
    }

    private func setupDeviceTimeout(_ device: BonjourDiscoveredDevice) {
        // Cancel existing timeout
        deviceTimeouts[device.id]?.cancel()

        // Set new timeout - mark offline after 60 seconds without update
        deviceTimeouts[device.id] = Task {
            try? await Task.sleep(for: .seconds(60))
            if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                var updated = discoveredDevices[index]
                updated = BonjourDiscoveredDevice(
                    id: updated.id,
                    name: updated.name,
                    hostName: updated.hostName,
                    port: updated.port,
                    platform: updated.platform,
                    capabilities: updated.capabilities,
                    lastSeen: updated.lastSeen,
                    isOnline: false
                )
                discoveredDevices[index] = updated
            }
        }
    }

    // MARK: - TXT Record Handling

    private func createTXTRecord(name: String, capabilities: BonjourDiscoveredDevice.DeviceCapabilities) -> NWTXTRecord {
        var dict: [String: String] = [:]
        dict["name"] = name
        dict["platform"] = currentPlatform().rawValue
        dict["localModels"] = capabilities.supportsLocalModels ? "1" : "0"
        dict["screenShare"] = capabilities.supportsScreenSharing ? "1" : "0"
        dict["audio"] = capabilities.supportsAudioMonitoring ? "1" : "0"
        dict["remote"] = capabilities.supportsRemoteExecution ? "1" : "0"
        dict["memory"] = String(Int(capabilities.maxModelMemoryGB))
        dict["gpu"] = String(capabilities.gpuCores)

        return NWTXTRecord.fromDictionary(dict)
    }

    private func parseCapabilities(from record: NWTXTRecord) -> BonjourDiscoveredDevice.DeviceCapabilities {
        let dict = record.dictionary

        return BonjourDiscoveredDevice.DeviceCapabilities(
            supportsLocalModels: dict["localModels"] == "1",
            supportsScreenSharing: dict["screenShare"] == "1",
            supportsAudioMonitoring: dict["audio"] == "1",
            supportsRemoteExecution: dict["remote"] == "1",
            maxModelMemoryGB: Double(dict["memory"] ?? "16") ?? 16,
            gpuCores: Int(dict["gpu"] ?? "8") ?? 8
        )
    }

    private func parsePlatform(from record: NWTXTRecord) -> BonjourDiscoveredDevice.DevicePlatform {
        let dict = record.dictionary
        return BonjourDiscoveredDevice.DevicePlatform(rawValue: dict["platform"] ?? "Unknown") ?? .unknown
    }

    private func currentPlatform() -> BonjourDiscoveredDevice.DevicePlatform {
        #if os(macOS)
        return .macOS
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPadOS
        }
        return .iOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(tvOS)
        return .tvOS
        #else
        return .unknown
        #endif
    }

    // MARK: - Listener Handlers

    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            break
        case .failed(let error):
            lastError = error
            onError?(error)
        default:
            break
        }
    }
}

// MARK: - TXT Record Extension

extension NWTXTRecord {
    var dictionary: [String: String] {
        var result: [String: String] = [:]

        // NWTXTRecord is a sequence, iterate through entries
        for (key, value) in self.keyValueSequence {
            result[key] = value ?? ""
        }

        return result
    }

    /// Creates key-value pairs from the TXT record
    private var keyValueSequence: [(String, String?)] {
        var pairs: [(String, String?)] = []
        // Access keys via the subscript
        for key in ["name", "platform", "localModels", "screenShare", "audio", "remote", "memory", "gpu"] {
            if let entry = self[key] {
                pairs.append((key, entry))
            }
        }
        return pairs
    }

    /// Factory method to create TXT record from dictionary
    static func fromDictionary(_ dict: [String: String]) -> NWTXTRecord {
        var record = NWTXTRecord()
        for (key, value) in dict {
            record[key] = value
        }
        return record
    }
}
