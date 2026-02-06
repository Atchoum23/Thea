// ConnectivityMonitor.swift
// Network connectivity monitoring for graceful degradation
import Foundation
import Network
import OSLog

/// Monitors network connectivity and provides status for resilience decisions.
/// Enables graceful degradation to local models when cloud is unavailable.
@MainActor
@Observable
public final class ConnectivityMonitor {
    public static let shared = ConnectivityMonitor()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "ConnectivityMonitor")
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.thea.connectivity")

    /// Current connectivity status
    public private(set) var status: ConnectivityStatus = .unknown

    /// Whether we have any network connection
    public var isConnected: Bool {
        status == .connected || status == .constrained
    }

    /// Whether we have full connectivity (not constrained)
    public var hasFullConnectivity: Bool {
        status == .connected
    }

    /// Whether cloud providers are likely available
    public var canUseCloudProviders: Bool {
        isConnected && !isOfflineMode
    }

    /// Manual offline mode override
    public var isOfflineMode: Bool = false {
        didSet {
            if isOfflineMode {
                logger.info("Offline mode enabled manually")
            } else {
                logger.info("Offline mode disabled")
            }
        }
    }

    /// Last connectivity change time
    public private(set) var lastStatusChange = Date()

    /// Connectivity history for analysis
    private var connectivityHistory: [ConnectivityEvent] = []

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
        logger.info("Connectivity monitoring started")
    }

    private func handlePathUpdate(_ path: NWPath) {
        let newStatus: ConnectivityStatus

        switch path.status {
        case .satisfied:
            if path.isExpensive || path.isConstrained {
                newStatus = .constrained
            } else {
                newStatus = .connected
            }
        case .unsatisfied:
            newStatus = .disconnected
        case .requiresConnection:
            newStatus = .unknown
        @unknown default:
            newStatus = .unknown
        }

        if newStatus != status {
            let oldStatus = status
            status = newStatus
            lastStatusChange = Date()

            // Record history
            connectivityHistory.append(ConnectivityEvent(
                timestamp: Date(),
                from: oldStatus,
                to: newStatus,
                interfaces: path.availableInterfaces.map { $0.type.debugDescription }
            ))

            // Limit history size
            if connectivityHistory.count > 100 {
                connectivityHistory.removeFirst()
            }

            logger.info("Connectivity changed: \(oldStatus.rawValue) → \(newStatus.rawValue)")

            // Notify observers
            NotificationCenter.default.post(
                name: .connectivityStatusChanged,
                object: nil,
                userInfo: ["status": newStatus]
            )
        }
    }

    // MARK: - Provider Recommendations

    /// Get recommended execution mode based on connectivity
    public var recommendedExecutionMode: NetworkExecutionMode {
        if isOfflineMode || !isConnected {
            return .localOnly
        }

        if status == .constrained {
            return .preferLocal
        }

        return .normal
    }

    /// Check if a specific provider endpoint is reachable
    public func checkEndpointReachable(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...399).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    /// Check provider availability
    public func checkProviderAvailable(_ providerId: String) async -> Bool {
        let endpoints: [String: String] = [
            "openai": "https://api.openai.com",
            "anthropic": "https://api.anthropic.com",
            "google": "https://generativelanguage.googleapis.com",
            "openrouter": "https://openrouter.ai",
            "perplexity": "https://api.perplexity.ai",
            "groq": "https://api.groq.com"
        ]

        guard let endpoint = endpoints[providerId] else {
            return true // Local providers are always "available"
        }

        return await checkEndpointReachable(endpoint)
    }

    // MARK: - Statistics

    /// Get connectivity uptime percentage (last 24 hours based on history)
    public var uptimePercentage: Double {
        guard !connectivityHistory.isEmpty else { return 100.0 }

        let connectedEvents = connectivityHistory.filter {
            $0.to == .connected || $0.to == .constrained
        }.count

        return Double(connectedEvents) / Double(connectivityHistory.count) * 100.0
    }

    /// Get recent disconnection events
    public var recentDisconnections: [ConnectivityEvent] {
        connectivityHistory.filter { $0.to == .disconnected }
    }

    // MARK: - Cleanup

    deinit {
        monitor.cancel()
    }
}

// MARK: - Supporting Types

public enum ConnectivityStatus: String, Sendable {
    case unknown = "Unknown"
    case connected = "Connected"
    case constrained = "Constrained"  // Expensive/limited connection
    case disconnected = "Disconnected"
}

public enum NetworkExecutionMode: String, Sendable {
    case normal = "Normal"           // Use cloud freely
    case preferLocal = "Prefer Local" // Use local when possible
    case localOnly = "Local Only"     // No cloud access
}

public struct ConnectivityEvent: Sendable {
    public let timestamp: Date
    public let from: ConnectivityStatus
    public let to: ConnectivityStatus
    public let interfaces: [String]
}

// MARK: - Notifications

extension Notification.Name {
    static let connectivityStatusChanged = Notification.Name("TheaConnectivityStatusChanged")
}

// MARK: - NWInterface.InterfaceType Extension

extension NWInterface.InterfaceType {
    var debugDescription: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}
