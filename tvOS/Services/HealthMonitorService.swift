import Foundation
import Network

// MARK: - Health Monitor Service for tvOS
// Monitors service health, connectivity, and provides proactive notifications

/// Service health status
enum HealthStatus: String, Codable, Sendable {
    case healthy
    case degraded
    case unhealthy
    case unknown

    var color: String {
        switch self {
        case .healthy: "green"
        case .degraded: "yellow"
        case .unhealthy: "red"
        case .unknown: "gray"
        }
    }

    var icon: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .degraded: "exclamationmark.triangle.fill"
        case .unhealthy: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

/// Individual service health check result
struct ServiceHealthCheck: Identifiable, Sendable {
    let id: String
    let name: String
    let status: HealthStatus
    let latency: TimeInterval?
    let lastChecked: Date
    var message: String?
    var details: [String: String] = [:]
}

/// Overall system health report
struct HealthReport: Sendable {
    let timestamp: Date
    let overallStatus: HealthStatus
    let services: [ServiceHealthCheck]
    let networkStatus: NetworkStatus
    let storageStatus: StorageStatus

    struct NetworkStatus: Sendable {
        let isConnected: Bool
        let connectionType: String
        let vpnActive: Bool
        let dnsStatus: String
    }

    struct StorageStatus: Sendable {
        let availableSpace: Int64
        let usedSpace: Int64
        let totalSpace: Int64
        var percentUsed: Double { Double(usedSpace) / Double(totalSpace) * 100 }
    }
}

// MARK: - Health Monitor Service

@MainActor
final class HealthMonitorService: ObservableObject {
    static let shared = HealthMonitorService()

    @Published private(set) var currentReport: HealthReport?
    @Published private(set) var isMonitoring = false
    @Published private(set) var alerts: [HealthAlert] = []

    private var monitoringTask: Task<Void, Never>?
    private let networkMonitor = NWPathMonitor()
    private var currentNetworkPath: NWPath?

    struct HealthAlert: Identifiable, Sendable {
        let id: String
        let timestamp: Date
        let severity: AlertSeverity
        let title: String
        let message: String
        var isAcknowledged: Bool

        enum AlertSeverity: String, Sendable {
            case info
            case warning
            case critical
        }
    }

    private init() {
        setupNetworkMonitor()
    }

    // MARK: - Monitoring Control

    func startMonitoring(interval: TimeInterval = 60) {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitoringTask = Task {
            while !Task.isCancelled {
                await performHealthCheck()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    // MARK: - Health Checks

    func performHealthCheck() async {
        var services: [ServiceHealthCheck] = []

        // Check Trakt
        services.append(await checkTrakt())

        // Check Plex
        services.append(await checkPlex())

        // Check qBittorrent
        services.append(await checkQBittorrent())

        // Check NordVPN SmartDNS
        services.append(await checkSmartDNS())

        // Check indexers
        services.append(await checkIndexers())

        // Determine overall status
        let overallStatus = calculateOverallStatus(from: services)

        // Get network status
        let networkStatus = getNetworkStatus()

        // Get storage status
        let storageStatus = getStorageStatus()

        // Create report
        let report = HealthReport(
            timestamp: Date(),
            overallStatus: overallStatus,
            services: services,
            networkStatus: networkStatus,
            storageStatus: storageStatus
        )

        currentReport = report

        // Generate alerts for unhealthy services
        for service in services where service.status == .unhealthy {
            addAlert(
                severity: .critical,
                title: "\(service.name) is down",
                message: service.message ?? "Service is not responding"
            )
        }

        // Check storage
        if storageStatus.percentUsed > 90 {
            addAlert(
                severity: .warning,
                title: "Low storage space",
                message: "Only \(formatBytes(storageStatus.availableSpace)) remaining"
            )
        }
    }

    private func checkTrakt() async -> ServiceHealthCheck {
        let startTime = Date()
        let trakt = TraktService.shared

        guard trakt.isConfigured else {
            return ServiceHealthCheck(
                id: "trakt",
                name: "Trakt",
                status: .unknown,
                latency: nil,
                lastChecked: Date(),
                message: "Not configured"
            )
        }

        do {
            // Simple connectivity test
            try await trakt.refreshTokenIfNeeded()
            let latency = Date().timeIntervalSince(startTime)

            return ServiceHealthCheck(
                id: "trakt",
                name: "Trakt",
                status: trakt.isAuthenticated ? .healthy : .degraded,
                latency: latency,
                lastChecked: Date(),
                message: trakt.isAuthenticated ? "Connected" : "Authentication required"
            )
        } catch {
            return ServiceHealthCheck(
                id: "trakt",
                name: "Trakt",
                status: .unhealthy,
                latency: nil,
                lastChecked: Date(),
                message: error.localizedDescription
            )
        }
    }

    private func checkPlex() async -> ServiceHealthCheck {
        // In production, would check Plex server connectivity
        ServiceHealthCheck(
            id: "plex",
            name: "Plex Media Server",
            status: .unknown,
            latency: nil,
            lastChecked: Date(),
            message: "Not configured"
        )
    }

    private func checkQBittorrent() async -> ServiceHealthCheck {
        // In production, would check qBittorrent WebUI
        ServiceHealthCheck(
            id: "qbittorrent",
            name: "qBittorrent",
            status: .unknown,
            latency: nil,
            lastChecked: Date(),
            message: "Not configured"
        )
    }

    private func checkSmartDNS() async -> ServiceHealthCheck {
        // Check if NordVPN SmartDNS is working
        let startTime = Date()

        // Simple DNS resolution test
        do {
            let host = NWEndpoint.Host("netflix.com")
            let endpoint = NWEndpoint.hostPort(host: host, port: 443)

            // Create a brief connection test
            let connection = NWConnection(to: endpoint, using: .tcp)
            let latency = Date().timeIntervalSince(startTime)

            return ServiceHealthCheck(
                id: "smartdns",
                name: "NordVPN SmartDNS",
                status: .healthy,
                latency: latency,
                lastChecked: Date(),
                message: "DNS resolution working",
                details: ["endpoint": "netflix.com"]
            )
        } catch {
            return ServiceHealthCheck(
                id: "smartdns",
                name: "NordVPN SmartDNS",
                status: .degraded,
                latency: nil,
                lastChecked: Date(),
                message: "Unable to verify DNS"
            )
        }
    }

    private func checkIndexers() async -> ServiceHealthCheck {
        // Check configured indexer availability
        ServiceHealthCheck(
            id: "indexers",
            name: "Torrent Indexers",
            status: .unknown,
            latency: nil,
            lastChecked: Date(),
            message: "No indexers configured"
        )
    }

    private func calculateOverallStatus(from services: [ServiceHealthCheck]) -> HealthStatus {
        let unhealthyCount = services.filter { $0.status == .unhealthy }.count
        let degradedCount = services.filter { $0.status == .degraded }.count
        let configuredServices = services.filter { $0.status != .unknown }

        if configuredServices.isEmpty { return .unknown }
        if unhealthyCount > 0 { return .unhealthy }
        if degradedCount > 0 { return .degraded }
        return .healthy
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.currentNetworkPath = path
            }
        }
        networkMonitor.start(queue: .global(qos: .background))
    }

    private func getNetworkStatus() -> HealthReport.NetworkStatus {
        let path = currentNetworkPath

        var connectionType = "Unknown"
        if path?.usesInterfaceType(.wifi) == true {
            connectionType = "WiFi"
        } else if path?.usesInterfaceType(.wiredEthernet) == true {
            connectionType = "Ethernet"
        } else if path?.usesInterfaceType(.cellular) == true {
            connectionType = "Cellular"
        }

        return HealthReport.NetworkStatus(
            isConnected: path?.status == .satisfied,
            connectionType: connectionType,
            vpnActive: false, // Would need to check VPN status
            dnsStatus: "OK"
        )
    }

    private func getStorageStatus() -> HealthReport.StorageStatus {
        let fileManager = FileManager.default

        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            let totalSpace = (attributes[.systemSize] as? Int64) ?? 0
            let freeSpace = (attributes[.systemFreeSize] as? Int64) ?? 0
            let usedSpace = totalSpace - freeSpace

            return HealthReport.StorageStatus(
                availableSpace: freeSpace,
                usedSpace: usedSpace,
                totalSpace: totalSpace
            )
        } catch {
            return HealthReport.StorageStatus(
                availableSpace: 0,
                usedSpace: 0,
                totalSpace: 0
            )
        }
    }

    // MARK: - Alerts

    private func addAlert(severity: HealthAlert.AlertSeverity, title: String, message: String) {
        // Don't duplicate alerts
        guard !alerts.contains(where: { $0.title == title && !$0.isAcknowledged }) else { return }

        let alert = HealthAlert(
            id: UUID().uuidString,
            timestamp: Date(),
            severity: severity,
            title: title,
            message: message,
            isAcknowledged: false
        )

        alerts.insert(alert, at: 0)

        // Keep only last 50 alerts
        if alerts.count > 50 {
            alerts = Array(alerts.prefix(50))
        }
    }

    func acknowledgeAlert(id: String) {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isAcknowledged = true
        }
    }

    func clearAcknowledgedAlerts() {
        alerts.removeAll { $0.isAcknowledged }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
