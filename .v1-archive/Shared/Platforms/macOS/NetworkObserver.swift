//
//  NetworkObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(macOS)
    import Foundation
    import Network
    import os.log

    /// Observes network state and connections on macOS
    /// Uses NWPathMonitor for network state without requiring special entitlements
    @MainActor
    public final class NetworkObserver {
        public static let shared = NetworkObserver()

        private let logger = Logger(subsystem: "app.thea.network", category: "NetworkObserver")
        private let pathMonitor: NWPathMonitor
        private let monitorQueue = DispatchQueue(label: "app.thea.network.monitor")

        // Callbacks
        nonisolated(unsafe) public var onNetworkStateChanged: ((NetworkState) -> Void)?
        nonisolated(unsafe) public var onInterfaceChanged: ((NetworkInterface) -> Void)?

        // Current state
        nonisolated(unsafe) public private(set) var currentState: NetworkState = .unknown
        nonisolated(unsafe) public private(set) var activeInterfaces: [NetworkInterface] = []

        private init() {
            pathMonitor = NWPathMonitor()
        }

        // MARK: - Lifecycle

        public func start() {
            pathMonitor.pathUpdateHandler = { [weak self] path in
                self?.handlePathUpdate(path)
            }

            pathMonitor.start(queue: monitorQueue)
            logger.info("Network observer started")
        }

        public func stop() {
            pathMonitor.cancel()
            logger.info("Network observer stopped")
        }

        // MARK: - Path Handling

        nonisolated private func handlePathUpdate(_ path: NWPath) {
            let newState = NetworkState(from: path)
            let interfaces = extractInterfaces(from: path)

            Task { @MainActor in
                let stateChanged = currentState != newState
                let interfacesChanged = activeInterfaces != interfaces

                currentState = newState
                activeInterfaces = interfaces

                if stateChanged {
                    logger.info("Network state changed: \(newState.description)")
                    onNetworkStateChanged?(newState)
                }

                if interfacesChanged {
                    for interface in interfaces {
                        logger.info("Interface: \(interface.name) (\(interface.type.rawValue))")
                        onInterfaceChanged?(interface)
                    }
                }
            }
        }

        nonisolated private func extractInterfaces(from path: NWPath) -> [NetworkInterface] {
            var interfaces: [NetworkInterface] = []

            // Check available interface types
            if path.usesInterfaceType(.wifi) {
                interfaces.append(NetworkInterface(
                    name: "Wi-Fi",
                    type: .wifi,
                    isActive: path.status == .satisfied
                ))
            }

            if path.usesInterfaceType(.cellular) {
                interfaces.append(NetworkInterface(
                    name: "Cellular",
                    type: .cellular,
                    isActive: path.status == .satisfied
                ))
            }

            if path.usesInterfaceType(.wiredEthernet) {
                interfaces.append(NetworkInterface(
                    name: "Ethernet",
                    type: .wiredEthernet,
                    isActive: path.status == .satisfied
                ))
            }

            if path.usesInterfaceType(.loopback) {
                interfaces.append(NetworkInterface(
                    name: "Loopback",
                    type: .loopback,
                    isActive: true
                ))
            }

            return interfaces
        }

        // MARK: - Network Queries

        /// Check if network is available for a specific endpoint
        public func checkConnectivity(to host: String, port: UInt16 = 443) async -> Bool {
            await withCheckedContinuation { continuation in
                let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
                let connection = NWConnection(to: endpoint, using: .tcp)

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        connection.cancel()
                        continuation.resume(returning: true)
                    case .failed, .cancelled:
                        continuation.resume(returning: false)
                    default:
                        break
                    }
                }

                connection.start(queue: monitorQueue)

                // Timeout after 5 seconds
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                    if connection.state != .ready {
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                }
            }
        }

        /// Get current network metrics
        public func getNetworkMetrics() -> NetworkMetrics {
            let path = pathMonitor.currentPath

            return NetworkMetrics(
                isConnected: path.status == .satisfied,
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained,
                supportsIPv4: path.supportsIPv4,
                supportsIPv6: path.supportsIPv6,
                supportsDNS: path.supportsDNS,
                interfaceTypes: activeInterfaces.map(\.type)
            )
        }
    }

    // MARK: - Models

    public enum NetworkState: Equatable, Sendable {
        case unknown
        case disconnected
        case connecting
        case connected(isExpensive: Bool, isConstrained: Bool)

        init(from path: NWPath) {
            switch path.status {
            case .satisfied:
                self = .connected(isExpensive: path.isExpensive, isConstrained: path.isConstrained)
            case .unsatisfied:
                self = .disconnected
            case .requiresConnection:
                self = .connecting
            @unknown default:
                self = .unknown
            }
        }

        var description: String {
            switch self {
            case .unknown:
                return "Unknown"
            case .disconnected:
                return "Disconnected"
            case .connecting:
                return "Connecting"
            case let .connected(isExpensive, isConstrained):
                var desc = "Connected"
                if isExpensive { desc += " (Expensive)" }
                if isConstrained { desc += " (Constrained)" }
                return desc
            }
        }
    }

    public struct NetworkInterface: Equatable, Sendable {
        public let name: String
        public let type: InterfaceType
        public let isActive: Bool

        public enum InterfaceType: String, Sendable {
            case wifi = "Wi-Fi"
            case cellular = "Cellular"
            case wiredEthernet = "Ethernet"
            case loopback = "Loopback"
            case other = "Other"
        }
    }

    public struct NetworkMetrics: Sendable {
        public let isConnected: Bool
        public let isExpensive: Bool
        public let isConstrained: Bool
        public let supportsIPv4: Bool
        public let supportsIPv6: Bool
        public let supportsDNS: Bool
        public let interfaceTypes: [NetworkInterface.InterfaceType]
        public let timestamp: Date

        init(
            isConnected: Bool,
            isExpensive: Bool,
            isConstrained: Bool,
            supportsIPv4: Bool,
            supportsIPv6: Bool,
            supportsDNS: Bool,
            interfaceTypes: [NetworkInterface.InterfaceType]
        ) {
            self.isConnected = isConnected
            self.isExpensive = isExpensive
            self.isConstrained = isConstrained
            self.supportsIPv4 = supportsIPv4
            self.supportsIPv6 = supportsIPv6
            self.supportsDNS = supportsDNS
            self.interfaceTypes = interfaceTypes
            timestamp = Date()
        }
    }
#endif
