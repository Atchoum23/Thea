// BackgroundServiceMonitor.swift
// Thea — Persistent background monitoring & self-healing
//
// Monitors all Thea services: sync, AI providers, system resources, OpenClaw.
// Detects failures, auto-recovers where possible, alerts the user otherwise.
// macOS: runs as continuous Task loop. iOS: BGTaskScheduler for periodic checks.

import Foundation
import OSLog

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

private let bsmLogger = Logger(subsystem: "ai.thea.app", category: "BackgroundServiceMonitor")

// MARK: - Background Service Monitor

@MainActor
final class BackgroundServiceMonitor: ObservableObject {
    static let shared = BackgroundServiceMonitor()

    // MARK: - Published State

    @Published private(set) var latestSnapshot: TheaHealthSnapshot?
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastCheckTime: Date?
    @Published private(set) var consecutiveFailures: [String: Int] = [:]
    @Published private(set) var recoveryHistory: [TheaRecoveryAction] = []
    @Published private(set) var snapshotHistory: [TheaHealthSnapshot] = []

    // MARK: - Configuration

    var checkInterval: TimeInterval = 120 // 2 minutes
    var maxConsecutiveFailuresBeforeRecovery = 3
    var maxRecoveryHistory = 100
    var maxSnapshotHistory = 720 // 24h at 2-minute intervals

    // MARK: - Private

    private var monitorTask: Task<Void, Never>?
    private let storageURL: URL

    #if os(iOS)
    static let bgTaskIdentifier = "app.thea.ios.backgroundHealthCheck"
    #endif

    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/ServiceHealth", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("health_history.json")
        loadHistory()
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performHealthCheck()
                let interval = self?.checkInterval ?? 120
                try? await Task.sleep(for: .seconds(interval))
            }
        }

        bsmLogger.info("Background service monitoring started (interval: \(self.checkInterval)s)")
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
        bsmLogger.info("Background service monitoring stopped")
    }

    /// Perform a single health check cycle
    func performHealthCheck() async {
        var checks: [TheaServiceCheckResult] = []

        // 1. Check sync services
        checks.append(contentsOf: await checkSyncServices())

        // 2. Check AI provider health
        checks.append(contentsOf: await checkAIProviders())

        // 3. Check system resources
        checks.append(contentsOf: checkSystemResources())

        // 4. Check integration services
        checks.append(contentsOf: await checkIntegrations())

        // 5. Check privacy services
        checks.append(contentsOf: await checkPrivacyServices())

        let snapshot = TheaHealthSnapshot(checks: checks)
        self.latestSnapshot = snapshot
        self.lastCheckTime = Date()

        snapshotHistory.append(snapshot)
        if snapshotHistory.count > maxSnapshotHistory {
            snapshotHistory = Array(snapshotHistory.suffix(maxSnapshotHistory))
        }

        // Track consecutive failures and attempt recovery
        for check in checks where check.status == .unhealthy {
            let count = (consecutiveFailures[check.serviceID] ?? 0) + 1
            consecutiveFailures[check.serviceID] = count

            if count >= maxConsecutiveFailuresBeforeRecovery {
                await attemptRecovery(for: check)
            }
        }

        // Reset failure count for healthy services
        for check in checks where check.status == .healthy {
            consecutiveFailures.removeValue(forKey: check.serviceID)
        }

        saveHistory()

        if snapshot.overallStatus == .unhealthy {
            bsmLogger.warning("Health check: \(snapshot.unhealthyCount) unhealthy services")
        } else {
            bsmLogger.info("Health check: \(snapshot.healthyCount)/\(checks.count) healthy")
        }
    }

    // MARK: - Service Checks

    private func checkSyncServices() async -> [TheaServiceCheckResult] {
        var results: [TheaServiceCheckResult] = []

        // CloudKit sync status
        let cloudKitStatus: TheaServiceStatus
        let cloudKitMsg: String

        let syncEnabled = CloudKitService.shared.syncEnabled
        if syncEnabled {
            let lastSync = CloudKitService.shared.lastSyncDate
            let interval = lastSync.map { Date().timeIntervalSince($0) } ?? .infinity
            // Guard against infinity/NaN before Int conversion — crashes if lastSyncDate is nil
            if !interval.isFinite {
                cloudKitStatus = .unknown
                cloudKitMsg = "Never synced"
            } else if interval < 600 { // Within 10 minutes
                cloudKitStatus = .healthy
                cloudKitMsg = "Last sync \(Int(interval))s ago"
            } else if interval < 3600 { // Within 1 hour
                cloudKitStatus = .degraded
                cloudKitMsg = "Last sync \(Int(interval / 60))m ago"
            } else {
                cloudKitStatus = .unhealthy
                cloudKitMsg = "Sync stale: \(Int(interval / 3600))h since last sync"
            }
        } else {
            cloudKitStatus = .unknown
            cloudKitMsg = "CloudKit sync disabled"
        }

        results.append(TheaServiceCheckResult(
            serviceID: "cloudkit_sync",
            serviceName: "CloudKit Sync",
            category: .sync,
            status: cloudKitStatus,
            message: cloudKitMsg
        ))

        #if os(macOS)
        // Smart transport status
        let transport = await SmartTransportManager.shared.activeTransport
        let transportStatus: TheaServiceStatus
        let transportMsg: String

        if transport != .cloudKit {
            transportStatus = .healthy
            transportMsg = "Active: \(transport.displayName)"
        } else {
            transportStatus = .degraded
            transportMsg = "CloudKit fallback only — no direct transport"
        }

        results.append(TheaServiceCheckResult(
            serviceID: "smart_transport",
            serviceName: "Smart Transport",
            category: .sync,
            status: transportStatus,
            message: transportMsg
        ))
        #endif

        return results
    }

    private func checkAIProviders() async -> [TheaServiceCheckResult] {
        var results: [TheaServiceCheckResult] = []

        let registry = ProviderRegistry.shared
        let providers = registry.configuredProviders

        if providers.isEmpty {
            results.append(TheaServiceCheckResult(
                serviceID: "ai_providers",
                serviceName: "AI Providers",
                category: .aiProvider,
                status: .unhealthy,
                message: "No providers configured"
            ))
        } else {
            // Check if at least one provider has an API key
            let configuredCount = providers.count
            results.append(TheaServiceCheckResult(
                serviceID: "ai_providers",
                serviceName: "AI Providers",
                category: .aiProvider,
                status: configuredCount > 0 ? .healthy : .degraded,
                message: "\(configuredCount) provider(s) configured"
            ))
        }

        #if os(macOS)
        // Local model availability
        let localModels = MLXModelManager.shared.scannedModels
        let localStatus: TheaServiceStatus = localModels.isEmpty ? .degraded : .healthy
        let localMsg = localModels.isEmpty ? "No local models found" : "\(localModels.count) local model(s) available"

        results.append(TheaServiceCheckResult(
            serviceID: "local_models",
            serviceName: "Local Models (MLX)",
            category: .aiProvider,
            status: localStatus,
            message: localMsg
        ))
        #endif

        return results
    }

    private func checkSystemResources() -> [TheaServiceCheckResult] {
        var results: [TheaServiceCheckResult] = []

        // Memory pressure
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let availableRAM = getAvailableMemory()
        let usedPercent = totalRAM > 0 ? 100.0 - (Double(availableRAM) / Double(totalRAM) * 100.0) : 0

        let memStatus: TheaServiceStatus
        let memMsg: String
        if usedPercent < 70 {
            memStatus = .healthy
            memMsg = String(format: "%.0f%% used (%.1f GB available)", usedPercent, Double(availableRAM) / 1_073_741_824)
        } else if usedPercent < 85 {
            memStatus = .degraded
            memMsg = String(format: "%.0f%% used — memory pressure", usedPercent)
        } else {
            memStatus = .unhealthy
            memMsg = String(format: "%.0f%% used — critical memory pressure", usedPercent)
        }

        results.append(TheaServiceCheckResult(
            serviceID: "system_memory",
            serviceName: "System Memory",
            category: .system,
            status: memStatus,
            message: memMsg
        ))

        // Disk space
        #if os(macOS)
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        #else
        let homeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/")
        #endif
        if let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage {
            let availableGB = Double(available) / 1_073_741_824
            let diskStatus: TheaServiceStatus
            let diskMsg: String

            if availableGB > 20 {
                diskStatus = .healthy
                diskMsg = String(format: "%.1f GB available", availableGB)
            } else if availableGB > 5 {
                diskStatus = .degraded
                diskMsg = String(format: "%.1f GB available — low space", availableGB)
            } else {
                diskStatus = .unhealthy
                diskMsg = String(format: "%.1f GB available — critical", availableGB)
            }

            results.append(TheaServiceCheckResult(
                serviceID: "disk_space",
                serviceName: "Disk Space",
                category: .system,
                status: diskStatus,
                message: diskMsg
            ))
        }

        // Thermal state
        let thermal = ProcessInfo.processInfo.thermalState
        let thermalStatus: TheaServiceStatus
        let thermalMsg: String

        switch thermal {
        case .nominal:
            thermalStatus = .healthy
            thermalMsg = "Normal operating temperature"
        case .fair:
            thermalStatus = .healthy
            thermalMsg = "Slightly elevated temperature"
        case .serious:
            thermalStatus = .degraded
            thermalMsg = "Performance may be reduced"
        case .critical:
            thermalStatus = .unhealthy
            thermalMsg = "Critical — system may throttle or shut down"
        @unknown default:
            thermalStatus = .unknown
            thermalMsg = "Unknown thermal state"
        }

        results.append(TheaServiceCheckResult(
            serviceID: "thermal_state",
            serviceName: "Thermal State",
            category: .system,
            status: thermalStatus,
            message: thermalMsg
        ))

        return results
    }

    private func checkIntegrations() async -> [TheaServiceCheckResult] {
        var results: [TheaServiceCheckResult] = []

        #if os(macOS)
        // OpenClaw Gateway
        let openClawState = OpenClawIntegration.shared.connectionState
        let openClawHealthy = openClawState == .connected
        results.append(TheaServiceCheckResult(
            serviceID: "openclaw_gateway",
            serviceName: "OpenClaw Gateway",
            category: .integration,
            status: openClawHealthy ? .healthy : .degraded,
            message: openClawHealthy ? "Connected" : "Not connected (\(openClawState.rawValue))"
        ))
        #endif

        // Notification intelligence
        let notifEnabled = UserDefaults.standard.bool(forKey: "notificationIntelligenceEnabled")
        results.append(TheaServiceCheckResult(
            serviceID: "notification_intelligence",
            serviceName: "Notification Intelligence",
            category: .integration,
            status: notifEnabled ? .healthy : .unknown,
            message: notifEnabled ? "Active" : "Disabled"
        ))

        return results
    }

    private func checkPrivacyServices() async -> [TheaServiceCheckResult] {
        var results: [TheaServiceCheckResult] = []

        // Outbound Privacy Guard
        let guardEnabled = await OutboundPrivacyGuard.shared.isEnabled
        let guardMode = await OutboundPrivacyGuard.shared.mode
        results.append(TheaServiceCheckResult(
            serviceID: "privacy_guard",
            serviceName: "Privacy Guard",
            category: .privacy,
            status: guardEnabled ? .healthy : .degraded,
            message: guardEnabled ? "Active (\(guardMode.rawValue) mode)" : "Disabled — data may leak"
        ))

        // Network Privacy Monitor
        let networkMonitoring = await NetworkPrivacyMonitor.shared.isMonitoring
        results.append(TheaServiceCheckResult(
            serviceID: "network_privacy",
            serviceName: "Network Monitor",
            category: .privacy,
            status: networkMonitoring ? .healthy : .degraded,
            message: networkMonitoring ? "Monitoring active" : "Not monitoring network traffic"
        ))

        return results
    }

    // MARK: - Recovery

    private func attemptRecovery(for check: TheaServiceCheckResult) async {
        bsmLogger.warning("Attempting recovery for \(check.serviceName) after \(self.consecutiveFailures[check.serviceID] ?? 0) consecutive failures")

        var succeeded = false
        var errorMsg: String?
        var actionName = "auto-recovery"

        switch check.serviceID {
        case "cloudkit_sync":
            actionName = "force-sync"
            do {
                try await CloudKitService.shared.syncAll()
                succeeded = true
            } catch {
                errorMsg = error.localizedDescription
            }

        case "system_memory":
            actionName = "clear-caches"
            // Clear URLSession caches
            URLCache.shared.removeAllCachedResponses()
            succeeded = true

        case "disk_space":
            actionName = "suggest-cleanup"
            // Cannot auto-delete user data; mark as advisory
            succeeded = false
            errorMsg = "Low disk space requires user action — open System Cleaner"

        case "ai_providers":
            actionName = "refresh-registry"
            await ProviderRegistry.shared.refreshLocalProviders()
            succeeded = true

        #if os(macOS)
        case "smart_transport":
            actionName = "re-probe"
            _ = await SmartTransportManager.shared.probeAndSelect()
            succeeded = true

        case "openclaw_gateway":
            actionName = "reconnect"
            OpenClawIntegration.shared.disable()
            OpenClawIntegration.shared.enable()
            succeeded = true
        #endif

        default:
            errorMsg = "No recovery procedure defined for \(check.serviceID)"
        }

        let action = TheaRecoveryAction(
            serviceID: check.serviceID,
            actionName: actionName,
            description: "Auto-recovery for \(check.serviceName)",
            succeeded: succeeded,
            errorMessage: errorMsg
        )

        recoveryHistory.append(action)
        if recoveryHistory.count > maxRecoveryHistory {
            recoveryHistory = Array(recoveryHistory.suffix(maxRecoveryHistory))
        }

        // Reset failure count on success
        if succeeded {
            consecutiveFailures[check.serviceID] = 0
            bsmLogger.info("Recovery succeeded for \(check.serviceName): \(actionName)")
        } else {
            bsmLogger.error("Recovery failed for \(check.serviceName): \(errorMsg ?? "unknown error")")
        }
    }

    // MARK: - Statistics

    var healthyPercentage: Double {
        guard let snapshot = latestSnapshot, !snapshot.checks.isEmpty else { return 0 }
        return Double(snapshot.healthyCount) / Double(snapshot.checks.count) * 100
    }

    var servicesByCategory: [TheaServiceCategory: [TheaServiceCheckResult]] {
        guard let snapshot = latestSnapshot else { return [:] }
        return Dictionary(grouping: snapshot.checks, by: \.category)
    }

    var recentRecoveries: [TheaRecoveryAction] {
        Array(recoveryHistory.suffix(10))
    }

    var uptimeString: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        if hours > 24 {
            return "\(hours / 24)d \(hours % 24)h"
        }
        return "\(hours)h \(minutes)m"
    }

    // MARK: - Memory Helper

    /// Cross-platform available memory query using Mach host_statistics
    private func getAvailableMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize: UInt64 = 16384 // Apple Silicon uses 16KB pages
        return (UInt64(stats.free_count) + UInt64(stats.inactive_count)) * pageSize
    }

    // MARK: - iOS Background Task Registration

    #if os(iOS)
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier,
            using: nil
        ) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            Task { @MainActor in
                await BackgroundServiceMonitor.shared.performHealthCheck()
                bgTask.setTaskCompleted(success: true)
            }
            bgTask.expirationHandler = {
                bgTask.setTaskCompleted(success: false)
            }
        }
    }

    func scheduleBackgroundHealthCheck() {
        let request = BGProcessingTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
    }
    #endif

    // MARK: - Persistence

    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let saveable = SaveableHealthHistory(
            snapshots: Array(snapshotHistory.suffix(50)),
            recoveries: Array(recoveryHistory.suffix(maxRecoveryHistory)),
            consecutiveFailures: consecutiveFailures
        )
        if let data = try? encoder.encode(saveable) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let history = try? decoder.decode(SaveableHealthHistory.self, from: data) {
            self.snapshotHistory = history.snapshots
            self.recoveryHistory = history.recoveries
            self.consecutiveFailures = history.consecutiveFailures
            self.latestSnapshot = history.snapshots.last
        }
    }
}
