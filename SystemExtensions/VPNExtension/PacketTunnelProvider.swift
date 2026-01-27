//
//  PacketTunnelProvider.swift
//  Thea VPN Extension
//
//  Created by Thea
//  Packet tunnel provider for VPN functionality
//

import NetworkExtension
import os.log

/// Packet tunnel provider for Thea VPN
/// Requires com.apple.developer.networking.networkextension entitlement with packet-tunnel-provider
@available(macOS 11.0, iOS 15.0, *)
class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "app.thea.vpn", category: "PacketTunnelProvider")

    // MARK: - Configuration

    private var tunnelConfiguration: TunnelConfiguration?
    private var connectionStartTime: Date?

    // MARK: - Statistics

    private var bytesReceived: UInt64 = 0
    private var bytesSent: UInt64 = 0
    private var packetsReceived: UInt64 = 0
    private var packetsSent: UInt64 = 0

    // MARK: - Lifecycle

    override func startTunnel(options _: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting VPN tunnel")

        // Load configuration
        guard let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration
        else {
            completionHandler(VPNError.invalidConfiguration)
            return
        }

        // Parse configuration
        do {
            tunnelConfiguration = try parseTunnelConfiguration(providerConfiguration)
        } catch {
            logger.error("Failed to parse tunnel configuration: \(error)")
            completionHandler(error)
            return
        }

        // Configure tunnel network settings
        let networkSettings = createNetworkSettings()

        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            if let error {
                self?.logger.error("Failed to set tunnel network settings: \(error)")
                completionHandler(error)
                return
            }

            self?.connectionStartTime = Date()
            self?.startReadingPackets()

            self?.logger.info("VPN tunnel started successfully")
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping VPN tunnel: \(String(describing: reason))")

        // Log statistics
        if let startTime = connectionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            logger.info("VPN session duration: \(duration) seconds")
            logger.info("Bytes sent: \(bytesSent), received: \(bytesReceived)")
        }

        // Save statistics to app group
        saveStatistics()

        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Handle messages from the main app
        guard let message = try? JSONDecoder().decode(AppMessage.self, from: messageData) else {
            completionHandler?(nil)
            return
        }

        switch message.type {
        case .getStatistics:
            let stats = VPNStatistics(
                bytesReceived: bytesReceived,
                bytesSent: bytesSent,
                packetsReceived: packetsReceived,
                packetsSent: packetsSent,
                connectedSince: connectionStartTime
            )
            if let data = try? JSONEncoder().encode(stats) {
                completionHandler?(data)
            } else {
                completionHandler?(nil)
            }

        case .updateConfiguration:
            if let config = message.configuration {
                do {
                    tunnelConfiguration = try parseTunnelConfiguration(config)
                    completionHandler?(Data([0x01])) // Success
                } catch {
                    completionHandler?(Data([0x00])) // Failure
                }
            } else {
                completionHandler?(nil)
            }
        }
    }

    // MARK: - Packet Handling

    private func startReadingPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            self?.handlePackets(packets, protocols: protocols)
            self?.startReadingPackets() // Continue reading
        }
    }

    private func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
        for (index, packet) in packets.enumerated() {
            let proto = protocols[index]

            packetsReceived += 1
            bytesReceived += UInt64(packet.count)

            // Process packet based on protocol
            if proto.int32Value == AF_INET {
                processIPv4Packet(packet)
            } else if proto.int32Value == AF_INET6 {
                processIPv6Packet(packet)
            }
        }
    }

    private func processIPv4Packet(_ packet: Data) {
        // In a real VPN, you would:
        // 1. Encrypt the packet
        // 2. Send it to the VPN server
        // 3. Handle the response

        // For now, we'll just pass through (split tunnel demo)
        writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
    }

    private func processIPv6Packet(_ packet: Data) {
        writePackets([packet], withProtocols: [NSNumber(value: AF_INET6)])
    }

    private func writePackets(_ packets: [Data], withProtocols protocols: [NSNumber]) {
        packetFlow.writePackets(packets, withProtocols: protocols)

        for packet in packets {
            packetsSent += 1
            bytesSent += UInt64(packet.count)
        }
    }

    // MARK: - Configuration

    private func parseTunnelConfiguration(_ config: [String: Any]) throws -> TunnelConfiguration {
        guard let serverAddress = config["serverAddress"] as? String else {
            throw VPNError.missingServerAddress
        }

        return TunnelConfiguration(
            serverAddress: serverAddress,
            serverPort: config["serverPort"] as? UInt16 ?? 443,
            tunnelAddress: config["tunnelAddress"] as? String ?? "10.0.0.1",
            tunnelSubnetMask: config["tunnelSubnetMask"] as? String ?? "255.255.255.0",
            dns: config["dns"] as? [String] ?? ["1.1.1.1", "8.8.8.8"],
            mtu: config["mtu"] as? Int ?? 1400,
            includedRoutes: config["includedRoutes"] as? [String] ?? [],
            excludedRoutes: config["excludedRoutes"] as? [String] ?? [],
            splitTunnel: config["splitTunnel"] as? Bool ?? true
        )
    }

    private func createNetworkSettings() -> NEPacketTunnelNetworkSettings {
        guard let config = tunnelConfiguration else {
            return NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "0.0.0.0")
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: config.serverAddress)

        // IPv4 settings
        let ipv4Settings = NEIPv4Settings(
            addresses: [config.tunnelAddress],
            subnetMasks: [config.tunnelSubnetMask]
        )

        // Configure routing
        if config.splitTunnel {
            // Only route specific traffic through VPN
            ipv4Settings.includedRoutes = config.includedRoutes.map { route in
                NEIPv4Route(destinationAddress: route, subnetMask: "255.255.255.0")
            }
            ipv4Settings.excludedRoutes = config.excludedRoutes.map { route in
                NEIPv4Route(destinationAddress: route, subnetMask: "255.255.255.0")
            }
        } else {
            // Route all traffic through VPN
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        }

        settings.ipv4Settings = ipv4Settings

        // DNS settings
        let dnsSettings = NEDNSSettings(servers: config.dns)
        settings.dnsSettings = dnsSettings

        // MTU
        settings.mtu = NSNumber(value: config.mtu)

        return settings
    }

    // MARK: - Statistics

    private func saveStatistics() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.thea"
        ) else { return }

        let stats = VPNStatistics(
            bytesReceived: bytesReceived,
            bytesSent: bytesSent,
            packetsReceived: packetsReceived,
            packetsSent: packetsSent,
            connectedSince: connectionStartTime
        )

        let statsURL = containerURL.appendingPathComponent("vpn_statistics.json")

        if let data = try? JSONEncoder().encode(stats) {
            try? data.write(to: statsURL)
        }
    }
}

// MARK: - Supporting Types

struct TunnelConfiguration {
    let serverAddress: String
    let serverPort: UInt16
    let tunnelAddress: String
    let tunnelSubnetMask: String
    let dns: [String]
    let mtu: Int
    let includedRoutes: [String]
    let excludedRoutes: [String]
    let splitTunnel: Bool
}

struct VPNStatistics: Codable {
    let bytesReceived: UInt64
    let bytesSent: UInt64
    let packetsReceived: UInt64
    let packetsSent: UInt64
    let connectedSince: Date?
}

struct AppMessage: Codable {
    enum MessageType: String, Codable {
        case getStatistics
        case updateConfiguration
    }

    let type: MessageType
    let configuration: [String: String]?
}

enum VPNError: Error, LocalizedError {
    case invalidConfiguration
    case missingServerAddress
    case connectionFailed
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Invalid VPN configuration"
        case .missingServerAddress:
            "Server address is missing"
        case .connectionFailed:
            "Failed to connect to VPN server"
        case .authenticationFailed:
            "VPN authentication failed"
        }
    }
}
