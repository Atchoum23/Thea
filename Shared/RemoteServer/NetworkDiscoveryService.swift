//
//  NetworkDiscoveryService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Combine
import Foundation
import Network
#if os(macOS)
    import IOKit
#else
    import UIKit
#endif

// MARK: - Network Discovery Service

/// Handles Bonjour/mDNS service discovery and advertising
@MainActor
public class NetworkDiscoveryService: ObservableObject {
    // MARK: - Constants

    public static let serviceType = "_thea-remote._tcp"
    public static let serviceDomain = "local."

    // MARK: - Published State

    @Published public private(set) var isAdvertising = false
    @Published public private(set) var isSearching = false
    @Published public private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published public private(set) var advertisedName: String?

    // MARK: - Network Services

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var netService: NetService?
    // periphery:ignore - Reserved: listener property reserved for future feature activation
    private var netServiceBrowser: NetServiceBrowser?
    private var browserDelegate: NetServiceBrowserDelegateHandler?

// periphery:ignore - Reserved: netServiceBrowser property reserved for future feature activation

// periphery:ignore - Reserved: browserDelegate property reserved for future feature activation

    // MARK: - Initialization

    public init() {}

    // MARK: - Advertising

    /// Start advertising this device as a Thea remote server
    public func startAdvertising(serverName: String, port: UInt16) async {
        guard !isAdvertising else { return }

        // Use NetService for Bonjour advertising
        let service = NetService(
            domain: Self.serviceDomain,
            type: Self.serviceType,
            name: serverName,
            port: Int32(port)
        )

        // Set TXT record with device info
        let txtData: [String: Data] = [
            "version": Data("1.0".utf8),
            "platform": Data(getPlatform().utf8),
            "deviceId": Data(getDeviceId().utf8)
        ]

        service.setTXTRecord(NetService.data(fromTXTRecord: txtData))
        service.publish()

        netService = service
        advertisedName = serverName
        isAdvertising = true
    }

    /// Stop advertising
    public func stopAdvertising() async {
        netService?.stop()
        netService = nil
        advertisedName = nil
        isAdvertising = false
    }

    // MARK: - Discovery

    /// Start searching for Thea remote servers on the network
    public func startDiscovery() async {
        guard !isSearching else { return }

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: Self.serviceDomain), using: .tcp)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed, .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                await self?.handleBrowseResults(results)
            }
        }

        browser.start(queue: .global(qos: .userInitiated))
        self.browser = browser
    }

    /// Stop searching
    public func stopDiscovery() async {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) async {
        var devices: [DiscoveredDevice] = []

        for result in results {
            switch result.endpoint {
            case let .service(name, type, domain, _):
                // Resolve the service to get address and port
                if let device = await resolveService(name: name, type: type, domain: domain, metadata: result.metadata) {
                    devices.append(device)
                }
            default:
                break
            }
        }

        discoveredDevices = devices
    }

    private func resolveService(name: String, type: String, domain: String, metadata: NWBrowser.Result.Metadata?) async -> DiscoveredDevice? {
        // Parse TXT record
        var version = "unknown"
        var platform = "unknown"
        var deviceId = ""

        if case let .bonjour(txtRecord) = metadata {
            if let v = txtRecord.dictionary["version"] {
                version = v
            }
            if let p = txtRecord.dictionary["platform"] {
                platform = p
            }
            if let id = txtRecord.dictionary["deviceId"] {
                deviceId = id
            }
        }

        return DiscoveredDevice(
            id: deviceId.isEmpty ? UUID().uuidString : deviceId,
            name: name,
            serviceType: type,
            domain: domain,
            platform: platform,
            version: version,
            discoveredAt: Date(),
            isReachable: true
        )
    }

    // MARK: - Local Network Scan

    /// Scan the local network for devices
    public func discoverDevices() async -> [NetworkDevice] {
        var devices: [NetworkDevice] = []

        // Get local IP to determine subnet
        guard let localIP = getLocalIPAddress() else {
            return devices
        }

        // Parse subnet
        let components = localIP.split(separator: ".")
        guard components.count == 4 else { return devices }

        let subnet = "\(components[0]).\(components[1]).\(components[2])"

        // Scan common ports on subnet
        let portsToScan = [22, 80, 443, 445, 548, 3389, 5900, 8080, 9847]

        await withTaskGroup(of: NetworkDevice?.self) { group in
            for host in 1 ... 254 {
                let ip = "\(subnet).\(host)"

                group.addTask {
                    await self.probeHost(ip: ip, ports: portsToScan)
                }
            }

            for await device in group {
                if let device {
                    devices.append(device)
                }
            }
        }

        return devices.sorted { $0.ipAddress < $1.ipAddress }
    }

    private func probeHost(ip: String, ports: [Int]) async -> NetworkDevice? {
        var openServices: [NetworkDevice.NetworkService] = []

        for port in ports {
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { continue }
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: nwPort)
            let connection = NWConnection(to: endpoint, using: .tcp)

            let isOpen = await withCheckedContinuation { continuation in
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        continuation.resume(returning: true)
                        connection.cancel()
                    case .failed, .cancelled:
                        continuation.resume(returning: false)
                    default:
                        break
                    }
                }

                connection.start(queue: .global(qos: .utility))

                // Timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    connection.cancel()
                }
            }

            if isOpen {
                let serviceName = Self.serviceNameForPort(port)
                openServices.append(NetworkDevice.NetworkService(name: serviceName, type: "tcp", port: port))
            }
        }

        guard !openServices.isEmpty else { return nil }

        // Try to get hostname
        let hostname = await resolveHostname(for: ip)

        return NetworkDevice(
            id: ip,
            name: hostname ?? ip,
            ipAddress: ip,
            macAddress: nil,
            deviceType: Self.guessDeviceType(from: openServices),
            isOnline: true,
            lastSeen: Date(),
            services: openServices
        )
    }

    private func resolveHostname(for ip: String) async -> String? {
        var hints = addrinfo()
        hints.ai_flags = AI_NUMERICHOST

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(ip, nil, &hints, &result) == 0, let info = result else {
            return nil
        }
        defer { freeaddrinfo(result) }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let success = getnameinfo(info.pointee.ai_addr, info.pointee.ai_addrlen,
                                  &hostname, socklen_t(hostname.count),
                                  nil, 0, NI_NAMEREQD) == 0

        return success ? String(decoding: hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self) : nil
    }

    // MARK: - Helpers

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                guard let namePtr = interface.ifa_name else { continue }
                let nameLength = Int(strlen(namePtr))
                let nameData = Data(bytes: namePtr, count: nameLength)
                let name = String(decoding: nameData, as: UTF8.self)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    let hostnameData = hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                    address = String(decoding: hostnameData, as: UTF8.self)
                    break
                }
            }
        }

        return address
    }

    private func getPlatform() -> String {
        #if os(macOS)
            return "macOS"
        #elseif os(iOS)
            return "iOS"
        #elseif os(tvOS)
            return "tvOS"
        #elseif os(watchOS)
            return "watchOS"
        #else
            return "unknown"
        #endif
    }

    private func getDeviceId() -> String {
        #if os(macOS)
            // Use hardware UUID on macOS
            let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
            defer { IOObjectRelease(platformExpert) }

            if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
                return serialNumberAsCFString
            }
            return UUID().uuidString
        #else
            return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #endif
    }

    private static func serviceNameForPort(_ port: Int) -> String {
        switch port {
        case 22: "SSH"
        case 80: "HTTP"
        case 443: "HTTPS"
        case 445: "SMB"
        case 548: "AFP"
        case 3389: "RDP"
        case 5900: "VNC"
        case 8080: "HTTP Proxy"
        case 9847: "Thea Remote"
        default: "Port \(port)"
        }
    }

    private static func guessDeviceType(from services: [NetworkDevice.NetworkService]) -> String? {
        let ports = Set(services.map(\.port))

        if ports.contains(548) || ports.contains(445) {
            return "File Server"
        }
        if ports.contains(5900) || ports.contains(3389) {
            return "Remote Desktop"
        }
        if ports.contains(80) || ports.contains(443) {
            return "Web Server"
        }
        if ports.contains(22) {
            return "Server"
        }
        if ports.contains(9847) {
            return "Thea Device"
        }

        return nil
    }
}

// MARK: - Discovered Device

public struct DiscoveredDevice: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let serviceType: String
    public let domain: String
    public let platform: String
    public let version: String
    public let discoveredAt: Date
    public var isReachable: Bool
    public var address: String?
    public var port: UInt16?
}

// MARK: - NetService Browser Delegate Handler

// periphery:ignore - Reserved: NetServiceBrowserDelegateHandler type reserved for future feature activation
private class NetServiceBrowserDelegateHandler: NSObject, NetServiceBrowserDelegate {
    var didFindService: ((NetService) -> Void)?
    var didRemoveService: ((NetService) -> Void)?

    func netServiceBrowser(_: NetServiceBrowser, didFind service: NetService, moreComing _: Bool) {
        didFindService?(service)
    }

    func netServiceBrowser(_: NetServiceBrowser, didRemove service: NetService, moreComing _: Bool) {
        didRemoveService?(service)
    }
}
