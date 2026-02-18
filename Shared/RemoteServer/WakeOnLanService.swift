//
//  WakeOnLanService.swift
//  Thea
//
//  Wake-on-LAN magic packet support for waking remote machines
//

import Foundation
import os.log
import Network

// MARK: - Wake-on-LAN Service

/// Send Wake-on-LAN magic packets to wake sleeping or powered-down machines
@MainActor
public class WakeOnLanService: ObservableObject {
    private let logger = Logger(subsystem: "ai.thea.app", category: "WakeOnLanService")
    // MARK: - Published State

    @Published public private(set) var knownDevices: [WoLDevice] = []
    @Published public private(set) var lastWakeAttempt: Date?
    @Published public private(set) var lastWakeResult: WakeResult?

    // MARK: - Constants

    private static let storageKey = "thea.remote.wol.devices"
    private static let magicPacketPort: UInt16 = 9

    // MARK: - Initialization

    public init() {
        loadDevices()
    }

    // MARK: - Send Magic Packet

    /// Send a Wake-on-LAN magic packet to the specified MAC address
    public func wake(macAddress: String) async -> WakeResult {
        lastWakeAttempt = Date()

        // Parse and validate MAC address
        guard let macBytes = parseMACAddress(macAddress) else {
            let result = WakeResult(success: false, macAddress: macAddress, error: "Invalid MAC address format")
            lastWakeResult = result
            return result
        }

        // Build magic packet: 6 bytes of 0xFF followed by target MAC repeated 16 times
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0 ..< 16 {
            packet.append(contentsOf: macBytes)
        }

        // Send via UDP broadcast
        do {
            try await sendUDPBroadcast(data: packet, port: Self.magicPacketPort)
            let result = WakeResult(success: true, macAddress: macAddress)
            lastWakeResult = result

            // Update last wake time for device
            if let index = knownDevices.firstIndex(where: { $0.macAddress.lowercased() == macAddress.lowercased() }) {
                knownDevices[index].lastWakeAttempt = Date()
                saveDevices()
            }

            return result
        } catch {
            let result = WakeResult(success: false, macAddress: macAddress, error: error.localizedDescription)
            lastWakeResult = result
            return result
        }
    }

    /// Send a magic packet to a known device by name
    public func wake(deviceName: String) async -> WakeResult {
        guard let device = knownDevices.first(where: { $0.name == deviceName }) else {
            return WakeResult(success: false, macAddress: "", error: "Device not found: \(deviceName)")
        }
        return await wake(macAddress: device.macAddress)
    }

    // MARK: - Device Management

    /// Add a known device for Wake-on-LAN
    public func addDevice(_ device: WoLDevice) {
        if let index = knownDevices.firstIndex(where: { $0.macAddress.lowercased() == device.macAddress.lowercased() }) {
            knownDevices[index] = device
        } else {
            knownDevices.append(device)
        }
        saveDevices()
    }

    /// Remove a known device
    public func removeDevice(macAddress: String) {
        knownDevices.removeAll { $0.macAddress.lowercased() == macAddress.lowercased() }
        saveDevices()
    }

    /// Discover MAC addresses from ARP table
    public func discoverMACAddresses() async -> [ARPEntry] {
        #if os(macOS)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
            task.arguments = ["-a"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                return parseARPOutput(output)
            } catch {
                return []
            }
        #else
            return []
        #endif
    }

    // MARK: - UDP Broadcast

    private func sendUDPBroadcast(data: Data, port: UInt16) async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw RemoteServerError.networkError("Invalid port: \(port)")
        }
        let connection = NWConnection(
            host: .ipv4(.broadcast),
            port: nwPort,
            using: .udp
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                        connection.cancel()
                    })
                case let .failed(error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    // MARK: - MAC Address Parsing

    private func parseMACAddress(_ mac: String) -> [UInt8]? {
        let separators = CharacterSet(charactersIn: ":-")
        let components = mac.components(separatedBy: separators)

        guard components.count == 6 else { return nil }

        var bytes: [UInt8] = []
        for component in components {
            guard let byte = UInt8(component, radix: 16) else { return nil }
            bytes.append(byte)
        }

        return bytes
    }

    private func parseARPOutput(_ output: String) -> [ARPEntry] {
        var entries: [ARPEntry] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            // Format: hostname (ip) at mac on interface
            let parts = line.components(separatedBy: " ")
            guard parts.count >= 4 else { continue }

            let hostname = parts[0]
            let ipWithParens = parts[1]
            let ip = ipWithParens.trimmingCharacters(in: CharacterSet(charactersIn: "()"))

            if let atIndex = parts.firstIndex(of: "at"), atIndex + 1 < parts.count {
                let mac = parts[atIndex + 1]
                guard mac.contains(":"), mac != "(incomplete)" else { continue }

                entries.append(ARPEntry(
                    hostname: hostname,
                    ipAddress: ip,
                    macAddress: mac
                ))
            }
        }

        return entries
    }

    // MARK: - Persistence

    private func loadDevices() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            knownDevices = try JSONDecoder().decode([WoLDevice].self, from: data)
        } catch {
            logger.error("WakeOnLanService: failed to decode WoL devices: \(error.localizedDescription)")
        }
    }

    private func saveDevices() {
        do {
            let data = try JSONEncoder().encode(knownDevices)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            logger.error("WakeOnLanService: failed to encode WoL devices: \(error.localizedDescription)")
        }
    }
}

// MARK: - WoL Device

public struct WoLDevice: Codable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var macAddress: String
    public var ipAddress: String?
    public var lastWakeAttempt: Date?
    public var notes: String?

    public init(name: String, macAddress: String, ipAddress: String? = nil, notes: String? = nil) {
        id = UUID().uuidString
        self.name = name
        self.macAddress = macAddress
        self.ipAddress = ipAddress
        self.notes = notes
    }
}

// MARK: - Wake Result

public struct WakeResult: Sendable {
    public let success: Bool
    public let macAddress: String
    public let error: String?
    public let timestamp: Date

    public init(success: Bool, macAddress: String, error: String? = nil) {
        self.success = success
        self.macAddress = macAddress
        self.error = error
        timestamp = Date()
    }
}

// MARK: - ARP Entry

public struct ARPEntry: Sendable {
    public let hostname: String
    public let ipAddress: String
    public let macAddress: String
}
