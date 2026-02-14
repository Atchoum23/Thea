// SmartTransportManager.swift
// Detects and selects optimal transport between Thea instances
// Supports: Thunderbolt bridge, local network (Bonjour), Tailscale VPN, iCloud (CloudKit)

import Foundation
import Network
import os.log

// MARK: - Transport Types

/// Available transport methods for cross-device communication, ordered by preference
enum TheaTransport: Int, Comparable, CaseIterable, Sendable, Codable {
    case thunderbolt = 0   // 10-40 Gbps, <1ms — direct bridge interface
    case localNetwork = 1  // WiFi/Ethernet LAN, ~2ms — Bonjour discovery
    case tailscale = 2     // WireGuard VPN, ~20ms — Tailscale IP
    case cloudKit = 3      // iCloud, ~200ms+ — always available fallback

    static func < (lhs: TheaTransport, rhs: TheaTransport) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .thunderbolt: return "Thunderbolt"
        case .localNetwork: return "Local Network"
        case .tailscale: return "Tailscale"
        case .cloudKit: return "iCloud"
        }
    }

    var estimatedLatencyMs: Double {
        switch self {
        case .thunderbolt: return 0.5
        case .localNetwork: return 2.0
        case .tailscale: return 20.0
        case .cloudKit: return 200.0
        }
    }

    var sfSymbol: String {
        switch self {
        case .thunderbolt: return "bolt.fill"
        case .localNetwork: return "wifi"
        case .tailscale: return "globe"
        case .cloudKit: return "icloud.fill"
        }
    }
}

/// Result of a transport probe
struct TransportProbeResult: Sendable {
    let transport: TheaTransport
    let isAvailable: Bool
    let latencyMs: Double?
    let endpoint: String?
    let probedAt: Date

    static func unavailable(_ transport: TheaTransport) -> TransportProbeResult {
        TransportProbeResult(transport: transport, isAvailable: false, latencyMs: nil, endpoint: nil, probedAt: Date())
    }

    static func available(_ transport: TheaTransport, latency: Double, endpoint: String) -> TransportProbeResult {
        TransportProbeResult(transport: transport, isAvailable: true, latencyMs: latency, endpoint: endpoint, probedAt: Date())
    }
}

/// Transport health status for monitoring
struct TransportHealthStatus: Sendable {
    let transport: TheaTransport
    let isHealthy: Bool
    let lastCheckedAt: Date
    let consecutiveFailures: Int
    let averageLatencyMs: Double?
}

// MARK: - SmartTransportManager

/// Detects and selects the optimal transport between Thea instances.
/// Probes Thunderbolt, local network, Tailscale, and iCloud in priority order.
/// Continuously monitors transport health and fails over automatically.
actor SmartTransportManager {
    static let shared = SmartTransportManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "SmartTransport")

    // MARK: - Published State

    /// The currently active transport (best available)
    private(set) var activeTransport: TheaTransport = .cloudKit

    /// All transports currently available
    private(set) var availableTransports: Set<TheaTransport> = [.cloudKit]

    /// Probe results from the most recent scan
    private(set) var latestProbes: [TheaTransport: TransportProbeResult] = [:]

    /// Health status per transport
    private(set) var healthStatus: [TheaTransport: TransportHealthStatus] = [:]

    /// Discovered peer endpoints per transport
    private(set) var peerEndpoints: [TheaTransport: String] = [:]

    // MARK: - Monitoring

    private var monitoringTask: Task<Void, Never>?
    private var bonjourBrowser: NWBrowser?
    private var bonjourListener: NWListener?
    private let syncPort: UInt16 = 18790

    /// Known Tailscale hostnames for the two Macs
    private let tailscaleHostnames = ["msm3u", "mbam2"]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Probe all transports and select the best available one
    func probeAndSelect() async -> TheaTransport {
        logger.info("Probing all transports...")

        let results = await probeAllTransports()

        for result in results {
            latestProbes[result.transport] = result
            if result.isAvailable {
                availableTransports.insert(result.transport)
                if let endpoint = result.endpoint {
                    peerEndpoints[result.transport] = endpoint
                }
            } else {
                availableTransports.remove(result.transport)
                peerEndpoints.removeValue(forKey: result.transport)
            }
        }

        let best = selectBestTransport()
        if best != activeTransport {
            logger.info("Transport changed: \(self.activeTransport.displayName) → \(best.displayName)")
            activeTransport = best
        }

        return best
    }

    /// Start continuous health monitoring with automatic failover
    func startMonitoring() {
        guard monitoringTask == nil else { return }

        logger.info("Starting transport monitoring")
        startBonjourDiscovery()
        startBonjourAdvertising()

        monitoringTask = Task { [weak self] in
            guard let self = self else { return }

            // Initial probe
            _ = await self.probeAndSelect()

            // Continuous monitoring loop
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { break }

                await self.healthCheck()
            }
        }
    }

    /// Stop monitoring and release resources
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        bonjourBrowser?.cancel()
        bonjourBrowser = nil
        bonjourListener?.cancel()
        bonjourListener = nil
        logger.info("Transport monitoring stopped")
    }

    /// Get the endpoint for the active transport
    func activeEndpoint() -> String? {
        peerEndpoints[activeTransport]
    }

    /// Get a summary of transport status for UI display
    func transportSummary() -> [(transport: TheaTransport, available: Bool, latency: Double?, active: Bool)] {
        TheaTransport.allCases.map { transport in
            let probe = latestProbes[transport]
            return (
                transport: transport,
                available: availableTransports.contains(transport),
                latency: probe?.latencyMs,
                active: transport == activeTransport
            )
        }
    }

    // MARK: - Transport Probing

    private func probeAllTransports() async -> [TransportProbeResult] {
        await withTaskGroup(of: TransportProbeResult.self, returning: [TransportProbeResult].self) { group in
            group.addTask { await self.probeThunderbolt() }
            group.addTask { await self.probeLocalNetwork() }
            group.addTask { await self.probeTailscale() }

            // CloudKit is always available as fallback
            group.addTask {
                TransportProbeResult.available(.cloudKit, latency: 200.0, endpoint: "iCloud.app.theathe")
            }

            var results: [TransportProbeResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    // MARK: - Thunderbolt Detection

    private func probeThunderbolt() async -> TransportProbeResult {
        #if os(macOS)
        // Check for Thunderbolt bridge interface
        // On macOS, when two Macs are connected via Thunderbolt, a bridge interface
        // appears with link-local addresses (169.254.x.x)
        let interfaces = listNetworkInterfaces()
        let bridgeInterfaces = interfaces.filter { $0.name.hasPrefix("bridge") }

        for iface in bridgeInterfaces {
            guard let address = iface.address, iface.isUp else { continue }

            // Check if a peer is reachable on the bridge
            if let latency = await measureLatency(host: address, port: syncPort, timeout: 1.0) {
                logger.info("Thunderbolt peer found on \(iface.name) at \(address)")
                return .available(.thunderbolt, latency: latency, endpoint: "\(address):\(self.syncPort)")
            }
        }

        // Also check for direct Thunderbolt Ethernet interfaces (en5, en6 on modern Macs)
        let tbInterfaces = interfaces.filter {
            $0.name.hasPrefix("en") && $0.isUp && $0.isLinkLocal
        }
        for iface in tbInterfaces {
            guard let address = iface.address else { continue }
            // Link-local addresses on non-WiFi interfaces could be Thunderbolt
            if let latency = await measureLatency(host: address, port: syncPort, timeout: 1.0) {
                // Sub-1ms latency strongly suggests Thunderbolt
                if latency < 2.0 {
                    logger.info("Possible Thunderbolt on \(iface.name) at \(address), latency: \(latency)ms")
                    return .available(.thunderbolt, latency: latency, endpoint: "\(address):\(self.syncPort)")
                }
            }
        }
        #endif

        return .unavailable(.thunderbolt)
    }

    // MARK: - Local Network (Bonjour)

    private func probeLocalNetwork() async -> TransportProbeResult {
        // Check if we already have a discovered LAN peer from the Bonjour browser
        if let endpoint = peerEndpoints[.localNetwork] {
            let components = endpoint.split(separator: ":")
            if components.count == 2, let port = UInt16(components[1]) {
                if let latency = await measureLatency(host: String(components[0]), port: port, timeout: 3.0) {
                    return .available(.localNetwork, latency: latency, endpoint: endpoint)
                }
            }
        }

        // Try mDNS names (.local)
        let currentHostname = ProcessInfo.processInfo.hostName.lowercased()
        let peerHostnames = tailscaleHostnames.filter { !currentHostname.contains($0) }

        for peer in peerHostnames {
            let host = "\(peer).local"
            if let latency = await measureLatency(host: host, port: syncPort, timeout: 3.0) {
                let endpoint = "\(host):\(syncPort)"
                logger.info("LAN peer found: \(host), latency: \(latency)ms")
                return .available(.localNetwork, latency: latency, endpoint: endpoint)
            }
        }

        return .unavailable(.localNetwork)
    }

    private func startBonjourDiscovery() {
        guard bonjourBrowser == nil else { return }

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: "_thea-sync._tcp", domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                Task { await self.logger.debug("Bonjour browser ready") }
            case .failed(let error):
                Task { await self.logger.error("Bonjour browser failed: \(error.localizedDescription)") }
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint {
                    Task {
                        await self.handleBonjourDiscovery(name: name, endpoint: result.endpoint)
                    }
                }
            }
        }

        browser.start(queue: .global(qos: .utility))
        bonjourBrowser = browser
    }

    private func startBonjourAdvertising() {
        guard bonjourListener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: syncPort) ?? 18790)
            listener.service = NWListener.Service(
                name: ProcessInfo.processInfo.hostName,
                type: "_thea-sync._tcp"
            )

            listener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    Task { await self.logger.debug("Bonjour advertising started") }
                case .failed(let error):
                    Task { await self.logger.error("Bonjour advertising failed: \(error.localizedDescription)") }
                default:
                    break
                }
            }

            listener.newConnectionHandler = { connection in
                // Accept incoming connections for transport probing
                connection.start(queue: .global(qos: .utility))
            }

            listener.start(queue: .global(qos: .utility))
            bonjourListener = listener
        } catch {
            logger.error("Failed to create Bonjour listener: \(error.localizedDescription)")
        }
    }

    private func handleBonjourDiscovery(name: String, endpoint: NWEndpoint) {
        // Don't discover ourselves
        let currentHost = ProcessInfo.processInfo.hostName
        guard !name.lowercased().contains(currentHost.lowercased()) else { return }

        logger.info("Bonjour discovered peer: \(name)")

        // Resolve the endpoint to get actual IP
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            if case .ready = state {
                if let path = connection.currentPath,
                   let remoteEndpoint = path.remoteEndpoint,
                   case .hostPort(let host, let port) = remoteEndpoint {
                    let endpointStr = "\(host):\(port)"
                    Task {
                        await self.registerLANEndpoint(endpointStr)
                    }
                }
                connection.cancel()
            }
        }
        connection.start(queue: .global(qos: .utility))
    }

    private func registerLANEndpoint(_ endpoint: String) {
        peerEndpoints[.localNetwork] = endpoint
        availableTransports.insert(.localNetwork)
        logger.info("LAN endpoint registered: \(endpoint)")

        // Re-evaluate best transport
        let best = selectBestTransport()
        if best != activeTransport {
            logger.info("Transport upgraded: \(self.activeTransport.displayName) → \(best.displayName)")
            activeTransport = best
        }
    }

    // MARK: - Tailscale Detection

    private func probeTailscale() async -> TransportProbeResult {
        // Check known Tailscale hostnames
        let currentHostname = ProcessInfo.processInfo.hostName.lowercased()
        let peerHostnames = tailscaleHostnames.filter { !currentHostname.contains($0) }

        for peer in peerHostnames {
            // Tailscale uses the hostname directly (resolved by Tailscale's MagicDNS)
            if let latency = await measureLatency(host: peer, port: syncPort, timeout: 5.0) {
                let endpoint = "\(peer):\(syncPort)"
                logger.info("Tailscale peer found: \(peer), latency: \(latency)ms")
                return .available(.tailscale, latency: latency, endpoint: endpoint)
            }
        }

        return .unavailable(.tailscale)
    }

    // MARK: - Transport Selection

    /// Select the best available transport (lowest rawValue = highest priority)
    func selectBestTransport() -> TheaTransport {
        availableTransports.min() ?? .cloudKit
    }

    // MARK: - Health Monitoring

    private func healthCheck() async {
        let current = activeTransport

        // Check current transport health
        if current != .cloudKit {
            guard let endpoint = peerEndpoints[current] else {
                // Endpoint lost — failover
                availableTransports.remove(current)
                let newTransport = selectBestTransport()
                activeTransport = newTransport
                logger.warning("Transport \(current.displayName) endpoint lost, failing over to \(newTransport.displayName)")
                updateHealthStatus(current, healthy: false)
                return
            }

            let components = endpoint.split(separator: ":")
            if components.count == 2, let port = UInt16(components[1]) {
                if let latency = await measureLatency(host: String(components[0]), port: port, timeout: 5.0) {
                    updateHealthStatus(current, healthy: true, latency: latency)
                } else {
                    updateHealthStatus(current, healthy: false)
                    let failures = healthStatus[current]?.consecutiveFailures ?? 0
                    if failures >= 3 {
                        availableTransports.remove(current)
                        let newTransport = selectBestTransport()
                        activeTransport = newTransport
                        logger.warning("Transport \(current.displayName) failed \(failures) times, failing over to \(newTransport.displayName)")
                    }
                }
            }
        }

        // Opportunistically probe better transports
        if current.rawValue > TheaTransport.thunderbolt.rawValue {
            let betterResult = await probeThunderbolt()
            if betterResult.isAvailable {
                availableTransports.insert(.thunderbolt)
                if let endpoint = betterResult.endpoint {
                    peerEndpoints[.thunderbolt] = endpoint
                }
                activeTransport = .thunderbolt
                logger.info("Upgraded to Thunderbolt transport")
            }
        }

        if current.rawValue > TheaTransport.localNetwork.rawValue {
            let lanResult = await probeLocalNetwork()
            if lanResult.isAvailable {
                availableTransports.insert(.localNetwork)
                if let endpoint = lanResult.endpoint {
                    peerEndpoints[.localNetwork] = endpoint
                }
                if activeTransport.rawValue > TheaTransport.localNetwork.rawValue {
                    activeTransport = .localNetwork
                    logger.info("Upgraded to Local Network transport")
                }
            }
        }
    }

    private func updateHealthStatus(_ transport: TheaTransport, healthy: Bool, latency: Double? = nil) {
        let existing = healthStatus[transport]
        let failures = healthy ? 0 : (existing?.consecutiveFailures ?? 0) + 1
        healthStatus[transport] = TransportHealthStatus(
            transport: transport,
            isHealthy: healthy,
            lastCheckedAt: Date(),
            consecutiveFailures: failures,
            averageLatencyMs: latency ?? existing?.averageLatencyMs
        )
    }

    // MARK: - Network Utilities

    private func measureLatency(host: String, port: UInt16, timeout: TimeInterval) async -> Double? {
        let startTime = CFAbsoluteTimeGetCurrent()

        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 18790)!
        let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        let guard_ = ContinuationGuard()

        let connectResult: Double? = await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            connection.stateUpdateHandler = { [guard_] state in
                switch state {
                case .ready:
                    guard guard_.tryResume() else { return }
                    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                    connection.cancel()
                    continuation.resume(returning: elapsed)

                case .failed, .cancelled:
                    guard guard_.tryResume() else { return }
                    continuation.resume(returning: nil)

                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            // Schedule timeout on a detached task
            Task.detached { [guard_] in
                try? await Task.sleep(for: .seconds(timeout))
                guard guard_.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: nil)
            }
        }

        return connectResult
    }

    /// Thread-safe one-shot guard for continuation resumption
    private final class ContinuationGuard: @unchecked Sendable {
        private let lock = NSLock()
        private var resumed = false

        func tryResume() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !resumed else { return false }
            resumed = true
            return true
        }
    }

    #if os(macOS)
    private struct NetworkInterfaceInfo: Sendable {
        let name: String
        let address: String?
        let isUp: Bool
        let isLinkLocal: Bool
    }

    private func listNetworkInterfaces() -> [NetworkInterfaceInfo] {
        var interfaces: [NetworkInterfaceInfo] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0

            var address: String?
            var isLinkLocal = false

            if let addr = current.pointee.ifa_addr {
                if addr.pointee.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        address = ip
                        isLinkLocal = ip.hasPrefix("169.254.")
                    }
                }
            }

            interfaces.append(NetworkInterfaceInfo(
                name: name,
                address: address,
                isUp: isUp,
                isLinkLocal: isLinkLocal
            ))

            ptr = current.pointee.ifa_next
        }

        return interfaces
    }
    #endif
}
