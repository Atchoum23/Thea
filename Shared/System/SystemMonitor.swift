// SystemMonitor.swift
// Thea — Real-time system metrics monitoring
// Replaces: iStat Menus
//
// CPU, memory, disk, network, GPU, thermal state via sysctl/host_statistics/IOKit.
// Historical trend storage. AI anomaly detection via threshold breach alerts.

import Foundation
import OSLog

#if os(macOS)
import Darwin
import IOKit
#endif

private let smLogger = Logger(subsystem: "ai.thea.app", category: "SystemMonitor")

// MARK: - Data Types

struct SystemSnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let disk: DiskMetrics
    let network: SystemNetworkMetrics
    let thermal: SystemThermalState
    let uptime: TimeInterval

    init(
        cpu: CPUMetrics,
        memory: MemoryMetrics,
        disk: DiskMetrics,
        network: SystemNetworkMetrics,
        thermal: SystemThermalState,
        uptime: TimeInterval
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.thermal = thermal
        self.uptime = uptime
    }
}

struct CPUMetrics: Codable, Sendable {
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
    let coreCount: Int
    let activeProcessors: Int

    var totalUsage: Double { userPercent + systemPercent }
}

struct MemoryMetrics: Codable, Sendable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let freeBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let swapUsedBytes: UInt64

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var formattedTotal: String { formatBytes(totalBytes) }
    var formattedUsed: String { formatBytes(usedBytes) }
    var formattedFree: String { formatBytes(freeBytes) }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

struct DiskMetrics: Codable, Sendable {
    let totalBytes: UInt64
    let availableBytes: UInt64
    let usedBytes: UInt64

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var formattedTotal: String { formatBytes(totalBytes) }
    var formattedAvailable: String { formatBytes(availableBytes) }
    var formattedUsed: String { formatBytes(usedBytes) }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 100 {
            return String(format: "%.0f GB", gb)
        } else if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

struct SystemNetworkMetrics: Codable, Sendable {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let packetsIn: UInt64
    let packetsOut: UInt64

    var formattedBytesIn: String { formatBytes(bytesIn) }
    var formattedBytesOut: String { formatBytes(bytesOut) }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        let kb = Double(bytes) / 1024
        return String(format: "%.1f KB", kb)
    }
}

enum SystemThermalState: String, Codable, Sendable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    var icon: String {
        switch self {
        case .nominal: "thermometer.low"
        case .fair: "thermometer.medium"
        case .serious: "thermometer.high"
        case .critical: "thermometer.sun.fill"
        }
    }

    var color: String {
        switch self {
        case .nominal: "green"
        case .fair: "yellow"
        case .serious: "orange"
        case .critical: "red"
        }
    }
}

// MARK: - Anomaly

struct SystemAnomaly: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let metric: String
    let currentValue: Double
    let threshold: Double
    let severity: SystemAnomalySeverity
    let message: String

    init(metric: String, currentValue: Double, threshold: Double, severity: SystemAnomalySeverity, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.metric = metric
        self.currentValue = currentValue
        self.threshold = threshold
        self.severity = severity
        self.message = message
    }
}

enum SystemAnomalySeverity: String, Codable, Sendable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"

    var icon: String {
        switch self {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .critical: "exclamationmark.octagon"
        }
    }
}

// MARK: - Monitor Configuration

struct MonitorThresholds: Codable, Sendable {
    var cpuWarning: Double = 80
    var cpuCritical: Double = 95
    var memoryWarning: Double = 80
    var memoryCritical: Double = 95
    var diskWarning: Double = 85
    var diskCritical: Double = 95
    var thermalWarning: SystemThermalState = .serious
}

// MARK: - System Monitor

@MainActor
final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    @Published private(set) var latestSnapshot: SystemSnapshot?
    @Published private(set) var anomalies: [SystemAnomaly] = []
    @Published private(set) var isMonitoring = false
    @Published var thresholds = MonitorThresholds()

    private var snapshots: [SystemSnapshot] = []
    private var monitorTask: Task<Void, Never>?
    private let storageURL: URL
    private let maxSnapshots = 1440 // 24h of 1-minute intervals

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Thea/SystemMonitor", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            smLogger.debug("Failed to create SystemMonitor directory: \(error.localizedDescription)")
        }
        self.storageURL = dir.appendingPathComponent("snapshots.json")
        loadHistory()
    }

    // MARK: - Monitoring Control

    func startMonitoring(interval: TimeInterval = 60) {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.captureSnapshot()
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    break
                }
            }
        }
        smLogger.info("System monitoring started (interval: \(interval)s)")
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
        smLogger.info("System monitoring stopped")
    }

    func captureSnapshot() async {
        let snapshot = SystemSnapshot(
            cpu: captureCPU(),
            memory: captureMemory(),
            disk: captureDisk(),
            network: captureNetwork(),
            thermal: captureThermal(),
            uptime: captureUptime()
        )

        latestSnapshot = snapshot
        snapshots.append(snapshot)

        // Trim to max history
        if snapshots.count > maxSnapshots {
            snapshots = Array(snapshots.suffix(maxSnapshots))
        }

        // Check for anomalies
        let newAnomalies = detectAnomalies(snapshot)
        if !newAnomalies.isEmpty {
            anomalies.append(contentsOf: newAnomalies)
            // Keep last 100 anomalies
            if anomalies.count > 100 {
                anomalies = Array(anomalies.suffix(100))
            }
        }

        saveHistory()
    }

    // MARK: - Trend Data

    var cpuHistory: [(Date, Double)] {
        snapshots.map { ($0.timestamp, $0.cpu.totalUsage) }
    }

    var memoryHistory: [(Date, Double)] {
        // periphery:ignore - Reserved: cpuHistory property reserved for future feature activation
        snapshots.map { ($0.timestamp, $0.memory.usagePercent) }
    }

    // periphery:ignore - Reserved: memoryHistory property reserved for future feature activation
    var diskHistory: [(Date, Double)] {
        snapshots.map { ($0.timestamp, $0.disk.usagePercent) }
    }

// periphery:ignore - Reserved: diskHistory property reserved for future feature activation

    var recentSnapshots: [SystemSnapshot] {
        Array(snapshots.suffix(60)) // Last hour
    // periphery:ignore - Reserved: recentSnapshots property reserved for future feature activation
    }

    // MARK: - Platform-Specific Capture

    private func captureCPU() -> CPUMetrics {
        #if os(macOS)
        var cpuInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        if result == KERN_SUCCESS {
            let user = Double(cpuInfo.cpu_ticks.0)
            let system = Double(cpuInfo.cpu_ticks.1)
            let idle = Double(cpuInfo.cpu_ticks.2)
            let nice = Double(cpuInfo.cpu_ticks.3)
            let total = user + system + idle + nice
            guard total > 0 else {
                return CPUMetrics(userPercent: 0, systemPercent: 0, idlePercent: 100,
                                  coreCount: ProcessInfo.processInfo.processorCount,
                                  activeProcessors: ProcessInfo.processInfo.activeProcessorCount)
            }
            return CPUMetrics(
                userPercent: (user / total) * 100,
                systemPercent: (system / total) * 100,
                idlePercent: (idle / total) * 100,
                coreCount: ProcessInfo.processInfo.processorCount,
                activeProcessors: ProcessInfo.processInfo.activeProcessorCount
            )
        }
        #endif

        return CPUMetrics(
            userPercent: 0, systemPercent: 0, idlePercent: 100,
            coreCount: ProcessInfo.processInfo.processorCount,
            activeProcessors: ProcessInfo.processInfo.activeProcessorCount
        )
    }

    private func captureMemory() -> MemoryMetrics {
        let totalBytes = ProcessInfo.processInfo.physicalMemory

        #if os(macOS)
        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(getpagesize())
            let freePages = UInt64(vmStats.free_count)
            let activePages = UInt64(vmStats.active_count)
            let inactivePages = UInt64(vmStats.inactive_count)
            let wiredPages = UInt64(vmStats.wire_count)
            let compressedPages = UInt64(vmStats.compressor_page_count)

            let freeBytes = freePages * pageSize
            let wiredBytes = wiredPages * pageSize
            let compressedBytes = compressedPages * pageSize
            let usedBytes = (activePages + wiredPages + compressedPages) * pageSize
            _ = inactivePages // included in free conceptually

            // Get swap info
            var swapUsage = xsw_usage()
            var swapSize = MemoryLayout<xsw_usage>.size
            sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)

            return MemoryMetrics(
                totalBytes: totalBytes,
                usedBytes: usedBytes,
                freeBytes: freeBytes,
                wiredBytes: wiredBytes,
                compressedBytes: compressedBytes,
                swapUsedBytes: UInt64(swapUsage.xsu_used)
            )
        }
        #endif

        return MemoryMetrics(
            totalBytes: totalBytes,
            usedBytes: 0,
            freeBytes: totalBytes,
            wiredBytes: 0,
            compressedBytes: 0,
            swapUsedBytes: 0
        )
    }

    private func captureDisk() -> DiskMetrics {
        let volumeURL = URL(filePath: NSHomeDirectory())
        do {
            let values = try volumeURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let available = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            return DiskMetrics(
                totalBytes: total,
                availableBytes: available,
                usedBytes: total > available ? total - available : 0
            )
        } catch {
            return DiskMetrics(totalBytes: 0, availableBytes: 0, usedBytes: 0)
        }
    }

    private func captureNetwork() -> SystemNetworkMetrics {
        #if os(macOS)
        // Use netstat-style data from sysctl
        var ifaddrs: UnsafeMutablePointer<Darwin.ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let first = ifaddrs else {
            return SystemNetworkMetrics(bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0)
        }
        defer { freeifaddrs(ifaddrs) }

        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0
        var totalPacketsIn: UInt64 = 0
        var totalPacketsOut: UInt64 = 0

        var current: UnsafeMutablePointer<Darwin.ifaddrs>? = first
        while let addr = current {
            if addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(addr.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                totalBytesIn += UInt64(data.pointee.ifi_ibytes)
                totalBytesOut += UInt64(data.pointee.ifi_obytes)
                totalPacketsIn += UInt64(data.pointee.ifi_ipackets)
                totalPacketsOut += UInt64(data.pointee.ifi_opackets)
            }
            current = addr.pointee.ifa_next
        }

        return SystemNetworkMetrics(
            bytesIn: totalBytesIn,
            bytesOut: totalBytesOut,
            packetsIn: totalPacketsIn,
            packetsOut: totalPacketsOut
        )
        #else
        return SystemNetworkMetrics(bytesIn: 0, bytesOut: 0, packetsIn: 0, packetsOut: 0)
        #endif
    }

    private func captureThermal() -> SystemThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    private func captureUptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Anomaly Detection

    private func detectAnomalies(_ snapshot: SystemSnapshot) -> [SystemAnomaly] {
        var anomalies: [SystemAnomaly] = []

        // CPU anomalies
        if snapshot.cpu.totalUsage >= thresholds.cpuCritical {
            anomalies.append(SystemAnomaly(
                metric: "CPU",
                currentValue: snapshot.cpu.totalUsage,
                threshold: thresholds.cpuCritical,
                severity: .critical,
                message: String(format: "CPU usage at %.0f%% (critical threshold: %.0f%%)", snapshot.cpu.totalUsage, thresholds.cpuCritical)
            ))
        } else if snapshot.cpu.totalUsage >= thresholds.cpuWarning {
            anomalies.append(SystemAnomaly(
                metric: "CPU",
                currentValue: snapshot.cpu.totalUsage,
                threshold: thresholds.cpuWarning,
                severity: .warning,
                message: String(format: "CPU usage at %.0f%% (warning threshold: %.0f%%)", snapshot.cpu.totalUsage, thresholds.cpuWarning)
            ))
        }

        // Memory anomalies
        if snapshot.memory.usagePercent >= thresholds.memoryCritical {
            anomalies.append(SystemAnomaly(
                metric: "Memory",
                currentValue: snapshot.memory.usagePercent,
                threshold: thresholds.memoryCritical,
                severity: .critical,
                message: String(format: "Memory usage at %.0f%% (%@ of %@)", snapshot.memory.usagePercent, snapshot.memory.formattedUsed, snapshot.memory.formattedTotal)
            ))
        } else if snapshot.memory.usagePercent >= thresholds.memoryWarning {
            anomalies.append(SystemAnomaly(
                metric: "Memory",
                currentValue: snapshot.memory.usagePercent,
                threshold: thresholds.memoryWarning,
                severity: .warning,
                message: String(format: "Memory usage at %.0f%% (%@ of %@)", snapshot.memory.usagePercent, snapshot.memory.formattedUsed, snapshot.memory.formattedTotal)
            ))
        }

        // Disk anomalies
        if snapshot.disk.usagePercent >= thresholds.diskCritical {
            anomalies.append(SystemAnomaly(
                metric: "Disk",
                currentValue: snapshot.disk.usagePercent,
                threshold: thresholds.diskCritical,
                severity: .critical,
                message: String(format: "Disk usage at %.0f%% (%@ available)", snapshot.disk.usagePercent, snapshot.disk.formattedAvailable)
            ))
        } else if snapshot.disk.usagePercent >= thresholds.diskWarning {
            anomalies.append(SystemAnomaly(
                metric: "Disk",
                currentValue: snapshot.disk.usagePercent,
                threshold: thresholds.diskWarning,
                severity: .warning,
                message: String(format: "Disk usage at %.0f%% (%@ available)", snapshot.disk.usagePercent, snapshot.disk.formattedAvailable)
            ))
        }

        // Thermal anomalies
        if snapshot.thermal == .critical || snapshot.thermal == .serious {
            anomalies.append(SystemAnomaly(
                metric: "Thermal",
                currentValue: snapshot.thermal == .critical ? 4 : 3,
                threshold: 3,
                severity: snapshot.thermal == .critical ? .critical : .warning,
                message: "Thermal state: \(snapshot.thermal.rawValue)"
            ))
        }

        return anomalies
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            snapshots = try JSONDecoder().decode([SystemSnapshot].self, from: data)
            latestSnapshot = snapshots.last
        } catch {
            smLogger.error("Failed to load snapshot history: \(error.localizedDescription)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            smLogger.error("Failed to save snapshot history: \(error.localizedDescription)")
        }
    }

    func clearAnomalies() {
        anomalies.removeAll()
    }

    func clearHistory() {
        // periphery:ignore - Reserved: clearHistory() instance method reserved for future feature activation
        snapshots.removeAll()
        anomalies.removeAll()
        latestSnapshot = nil
        do {
            try FileManager.default.removeItem(at: storageURL)
        } catch {
            smLogger.debug("Failed to remove snapshot storage file: \(error.localizedDescription)")
        }
    }

    // MARK: - Summary

    // periphery:ignore - Reserved: statusSummary property reserved for future feature activation
    var statusSummary: String {
        guard let snap = latestSnapshot else { return "No data" }
        return String(format: "CPU: %.0f%% | RAM: %.0f%% | Disk: %.0f%% | %@",
                      snap.cpu.totalUsage,
                      snap.memory.usagePercent,
                      snap.disk.usagePercent,
                      snap.thermal.rawValue)
    }

    var formattedUptime: String {
        guard let uptime = latestSnapshot?.uptime else { return "Unknown" }
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
