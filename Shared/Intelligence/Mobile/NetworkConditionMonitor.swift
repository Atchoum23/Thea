// NetworkConditionMonitor.swift
// Thea - Mobile Intelligence
//
// Monitors network conditions for intelligent inference routing.
// Weak cellular uses 10x more power than strong WiFi.

import Foundation
import Network
import Observation

// MARK: - Network Condition

/// Current network condition for routing decisions
public struct NetworkCondition: Sendable {
    public let connectionType: ConnectionType
    public let signalStrength: SignalStrength
    public let isExpensive: Bool           // Metered connection
    public let isConstrained: Bool         // Low data mode
    public let estimatedBandwidth: Double? // Mbps
    public let latency: TimeInterval?      // Seconds

    public enum ConnectionType: String, Sendable {
        case wifi
        case cellular
        case wired
        case none

        public var powerMultiplier: Float {
            switch self {
            case .wifi: return 1.0
            case .wired: return 0.8
            case .cellular: return 3.0  // Base cellular cost
            case .none: return 0
            }
        }
    }

    public enum SignalStrength: String, Sendable {
        case excellent  // -50 dBm or better
        case good       // -60 dBm
        case fair       // -70 dBm
        case weak       // -80 dBm or worse
        case unknown

        public var powerMultiplier: Float {
            switch self {
            case .excellent: return 1.0
            case .good: return 1.5
            case .fair: return 3.0
            case .weak: return 10.0  // Weak signal uses 10x power
            case .unknown: return 2.0
            }
        }
    }

    /// Total power cost multiplier for this network condition
    public var powerCost: Float {
        connectionType.powerMultiplier * signalStrength.powerMultiplier
    }

    /// Whether this connection is suitable for cloud inference
    public var canUseCloud: Bool {
        guard connectionType != .none else { return false }
        guard !isConstrained else { return false }
        return true
    }

    /// Whether this connection is suitable for large model downloads
    public var canDownloadModels: Bool {
        guard connectionType == .wifi || connectionType == .wired else { return false }
        guard !isExpensive else { return false }
        guard !isConstrained else { return false }
        return true
    }

    /// Whether local inference is preferred due to network cost
    public var shouldPreferLocal: Bool {
        isExpensive || isConstrained || signalStrength == .weak || connectionType == .none
    }
}

// MARK: - Network Condition Monitor

/// Monitors network conditions for intelligent routing decisions
@MainActor
@Observable
public final class NetworkConditionMonitor {
    public static let shared = NetworkConditionMonitor()

    // MARK: - State

    public private(set) var currentCondition: NetworkCondition
    public private(set) var isMonitoring = false

    /// Callback for network condition changes
    public var onConditionChanged: (@Sendable (NetworkCondition) -> Void)?

    // MARK: - Internal

    private let pathMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "ai.thea.network-monitor")

    private init() {
        self.pathMonitor = NWPathMonitor()
        self.currentCondition = NetworkCondition(
            connectionType: .none,
            signalStrength: .unknown,
            isExpensive: false,
            isConstrained: false,
            estimatedBandwidth: nil,
            latency: nil
        )
    }

    // MARK: - Lifecycle

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }

        pathMonitor.start(queue: monitorQueue)
    }

    public func stopMonitoring() {
        pathMonitor.cancel()
        isMonitoring = false
    }

    // MARK: - Path Handling

    private func handlePathUpdate(_ path: NWPath) {
        let connectionType = determineConnectionType(path)
        let signalStrength = estimateSignalStrength(for: connectionType)

        let newCondition = NetworkCondition(
            connectionType: connectionType,
            signalStrength: signalStrength,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            estimatedBandwidth: estimateBandwidth(for: path),
            latency: nil
        )

        let oldCondition = currentCondition
        currentCondition = newCondition

        if significantChange(from: oldCondition, to: newCondition) {
            onConditionChanged?(newCondition)
        }
    }

    private func determineConnectionType(_ path: NWPath) -> NetworkCondition.ConnectionType {
        guard path.status == .satisfied else {
            return .none
        }

        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        }

        return .wifi // Default assumption
    }

    private func estimateSignalStrength(for type: NetworkCondition.ConnectionType) -> NetworkCondition.SignalStrength {
        // Note: iOS doesn't expose signal strength directly
        // We would need CoreTelephony for cellular or use heuristics
        switch type {
        case .wifi:
            return .good // Assume good WiFi unless we can measure
        case .wired:
            return .excellent
        case .cellular:
            return .fair // Conservative estimate for cellular
        case .none:
            return .unknown
        }
    }

    private func estimateBandwidth(for path: NWPath) -> Double? {
        // NWPath doesn't directly expose bandwidth
        // We could measure it, but for now return estimates
        guard path.status == .satisfied else { return nil }

        if path.usesInterfaceType(.wiredEthernet) {
            return 1000.0 // Assume gigabit
        } else if path.usesInterfaceType(.wifi) {
            return 100.0 // Conservative WiFi estimate
        } else if path.usesInterfaceType(.cellular) {
            return 20.0 // LTE estimate
        }

        return nil
    }

    private func significantChange(from old: NetworkCondition, to new: NetworkCondition) -> Bool {
        if old.connectionType != new.connectionType { return true }
        if old.signalStrength != new.signalStrength { return true }
        if old.isExpensive != new.isExpensive { return true }
        if old.isConstrained != new.isConstrained { return true }
        return false
    }

    // MARK: - Latency Measurement

    /// Measure latency to a specific endpoint
    public func measureLatency(to url: URL) async -> TimeInterval? {
        let start = Date()

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return nil
            }

            return Date().timeIntervalSince(start)
        } catch {
            return nil
        }
    }

    /// Measure latency to remote Mac
    public nonisolated func measureMacLatency(host: String, port: Int) async -> TimeInterval? {
        let start = Date()

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )

        // Serial queue ensures hasResumed is thread-safe (state handler + timeout both run here)
        let probeQueue = DispatchQueue(label: "ai.thea.latency-probe")

        return await withCheckedContinuation { continuation in
            // nonisolated(unsafe): safe because probeQueue is serial and all accesses happen on it
            nonisolated(unsafe) var hasResumed = false

            connection.stateUpdateHandler = { state in
                guard !hasResumed else { return }
                switch state {
                case .ready:
                    hasResumed = true
                    let latency = Date().timeIntervalSince(start)
                    connection.cancel()
                    continuation.resume(returning: latency)
                case .failed, .cancelled:
                    hasResumed = true
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }

            connection.start(queue: probeQueue)

            // Timeout after 3 seconds (same serial queue for thread safety)
            probeQueue.asyncAfter(deadline: .now() + 3) {
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Routing Recommendation

public extension NetworkConditionMonitor {
    /// Get recommended inference route based on network conditions
    func recommendedRoute(powerState: MobilePowerState) -> InferenceRoute {
        let network = currentCondition

        // No network - must use local
        if network.connectionType == .none {
            return .localOnly
        }

        // Low power mode or low battery - prefer local to save power
        if powerState.isLowPowerMode || powerState.batteryLevel < 0.20 {
            if network.shouldPreferLocal {
                return .localOnly
            }
            return .cloudPreferred // Cloud uses less device power
        }

        // Weak cellular - definitely prefer local
        if network.connectionType == .cellular && network.signalStrength == .weak {
            return .localPreferred
        }

        // Constrained/expensive network - prefer local
        if network.isConstrained || network.isExpensive {
            return .localPreferred
        }

        // Good conditions - balanced approach
        return .balanced
    }

    enum InferenceRoute: String, Sendable {
        case localOnly          // Only use local models
        case localPreferred     // Prefer local, fallback to cloud
        case balanced           // Balance based on task
        case cloudPreferred     // Prefer cloud, fallback to local
        case remoteMacPreferred // Prefer remote Mac when available
    }
}
