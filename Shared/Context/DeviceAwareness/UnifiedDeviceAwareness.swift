import Foundation
import Network
#if os(iOS) || os(watchOS)
import UIKit
import CoreMotion
import HealthKit
#elseif os(macOS)
import AppKit
import IOKit.ps
#endif

// MARK: - Unified Device Awareness
// Provides comprehensive device awareness across all Apple platforms
// Includes hardware, software, sensors, apps, and content awareness

@MainActor
@Observable
final class UnifiedDeviceAwareness {
    static let shared = UnifiedDeviceAwareness()

    // MARK: - Device Information

    private(set) var deviceInfo = DeviceHardwareInfo()
    private(set) var systemState = SystemState()
    private(set) var sensorData = SensorData()
    private(set) var installedApps: [DeviceInstalledApp] = []
    private(set) var runningProcesses: [RunningProcess] = []
    private(set) var storageInfo = StorageInfo()
    private(set) var networkInfo = NetworkInfo()

    // Self-awareness
    private(set) var theaInfo = TheaInfo()

    // Update tracking
    private(set) var lastUpdate: Date?
    private var updateTask: Task<Void, Never>?

    // Configuration
    struct Configuration: Codable, Sendable {
        var enableContinuousMonitoring: Bool = true
        var updateIntervalSeconds: TimeInterval = 30
        var enableSensorMonitoring: Bool = true
        var enableAppMonitoring: Bool = true
        var enableProcessMonitoring: Bool = true
        var enableContentAwareness: Bool = true
    }

    private(set) var configuration = Configuration()

    private init() {
        loadConfiguration()
        Task {
            await gatherInitialInfo()
            startContinuousMonitoring()
        }
    }

    // MARK: - Initial Gathering

    private func gatherInitialInfo() async {
        await gatherDeviceInfo()
        await gatherSystemState()
        await gatherStorageInfo()
        await gatherNetworkInfo()
        await gatherTheaInfo()

        if configuration.enableAppMonitoring {
            await gatherDeviceInstalledApps()
        }

        if configuration.enableProcessMonitoring {
            await gatherRunningProcesses()
        }

        lastUpdate = Date()
    }

    // MARK: - Device Info

    private func gatherDeviceInfo() async {
        #if os(macOS)
        deviceInfo = DeviceHardwareInfo(
            platform: .macOS,
            modelIdentifier: getMacModelIdentifier(),
            modelName: Host.current().localizedName ?? "Mac",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            processorType: getProcessorType(),
            processorCores: ProcessInfo.processInfo.processorCount,
            totalMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            thermalState: mapThermalState(ProcessInfo.processInfo.thermalState),
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            screenResolution: getScreenResolution(),
            screenCount: NSScreen.screens.count
        )
        #elseif os(iOS)
        let device = UIDevice.current
        deviceInfo = DeviceHardwareInfo(
            platform: .iOS,
            modelIdentifier: getDeviceModelIdentifier(),
            modelName: device.name,
            osVersion: device.systemVersion,
            processorType: getProcessorType(),
            processorCores: ProcessInfo.processInfo.processorCount,
            totalMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            thermalState: mapThermalState(ProcessInfo.processInfo.thermalState),
            isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            screenResolution: getScreenResolution(),
            screenCount: 1
        )
        #elseif os(watchOS)
        let device = WKInterfaceDevice.current()
        deviceInfo = DeviceHardwareInfo(
            platform: .watchOS,
            modelIdentifier: device.model,
            modelName: device.name,
            osVersion: device.systemVersion,
            processorType: "Apple Silicon",
            processorCores: ProcessInfo.processInfo.processorCount,
            totalMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            thermalState: .nominal,
            isLowPowerMode: false,
            screenResolution: "\(Int(device.screenBounds.width))x\(Int(device.screenBounds.height))",
            screenCount: 1
        )
        #elseif os(tvOS)
        let device = UIDevice.current
        deviceInfo = DeviceHardwareInfo(
            platform: .tvOS,
            modelIdentifier: getDeviceModelIdentifier(),
            modelName: device.name,
            osVersion: device.systemVersion,
            processorType: getProcessorType(),
            processorCores: ProcessInfo.processInfo.processorCount,
            totalMemoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            thermalState: mapThermalState(ProcessInfo.processInfo.thermalState),
            isLowPowerMode: false,
            screenResolution: getScreenResolution(),
            screenCount: 1
        )
        #endif
    }

    // MARK: - System State

    private func gatherSystemState() async {
        #if os(macOS)
        systemState = SystemState(
            batteryLevel: getBatteryLevel(),
            isCharging: isCharging(),
            uptime: ProcessInfo.processInfo.systemUptime,
            activeAppName: NSWorkspace.shared.frontmostApplication?.localizedName,
            activeAppBundleId: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            isFocusModeActive: false, // Would need Focus API
            currentLocale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            isDarkMode: isDarkModeEnabled()
        )
        #elseif os(iOS)
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        systemState = SystemState(
            batteryLevel: Double(device.batteryLevel) * 100,
            isCharging: device.batteryState == .charging || device.batteryState == .full,
            uptime: ProcessInfo.processInfo.systemUptime,
            activeAppName: nil,
            activeAppBundleId: nil,
            isFocusModeActive: false,
            currentLocale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            isDarkMode: UITraitCollection.current.userInterfaceStyle == .dark
        )
        #else
        systemState = SystemState(
            batteryLevel: nil,
            isCharging: nil,
            uptime: ProcessInfo.processInfo.systemUptime,
            activeAppName: nil,
            activeAppBundleId: nil,
            isFocusModeActive: false,
            currentLocale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            isDarkMode: false
        )
        #endif
    }

    // MARK: - Storage Info

    private func gatherStorageInfo() async {
        let fileManager = FileManager.default

        do {
            // Use document directory for iOS, home directory for macOS
            #if os(macOS)
            let directory = fileManager.homeDirectoryForCurrentUser
            #else
            guard let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            #endif

            let values = try directory.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])

            let total = values.volumeTotalCapacity ?? 0
            let available = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)

            storageInfo = StorageInfo(
                totalCapacityGB: Double(total) / 1_073_741_824,
                availableCapacityGB: Double(available) / 1_073_741_824,
                usedCapacityGB: Double(total - Int(available)) / 1_073_741_824,
                usagePercentage: Double(total - Int(available)) / Double(total) * 100
            )
        } catch {
            print("Failed to get storage info: \(error)")
        }
    }

    // MARK: - Network Info

    private func gatherNetworkInfo() async {
        // Basic network check
        #if os(macOS)
        let wifiName = getCurrentWiFiSSID()
        #else
        let wifiName: String? = nil
        #endif

        networkInfo = NetworkInfo(
            isConnected: checkNetworkConnectivity(),
            connectionType: detectConnectionType(),
            wifiSSID: wifiName,
            ipAddress: getIPAddress()
        )
    }

    // MARK: - Installed Apps

    private func gatherDeviceInstalledApps() async {
        #if os(macOS)
        let appDirectories = [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]

        var apps: [DeviceInstalledApp] = []

        for directory in appDirectories {
            let url = URL(fileURLWithPath: directory)
            let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in contents ?? [] {
                if fileURL.pathExtension == "app" {
                    if let bundle = Bundle(url: fileURL) {
                        let app = DeviceInstalledApp(
                            name: bundle.infoDictionary?["CFBundleName"] as? String ?? fileURL.deletingPathExtension().lastPathComponent,
                            bundleId: bundle.bundleIdentifier ?? "",
                            version: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                            path: fileURL.path
                        )
                        apps.append(app)
                    }
                }
            }
        }

        installedApps = apps.sorted { $0.name < $1.name }
        #endif
    }

    // MARK: - Running Processes

    private func gatherRunningProcesses() async {
        #if os(macOS)
        var processes: [RunningProcess] = []

        for app in NSWorkspace.shared.runningApplications {
            let process = RunningProcess(
                name: app.localizedName ?? "Unknown",
                bundleId: app.bundleIdentifier ?? "",
                pid: Int(app.processIdentifier),
                isActive: app.isActive,
                isHidden: app.isHidden
            )
            processes.append(process)
        }

        runningProcesses = processes.sorted { $0.name < $1.name }
        #endif
    }

    // MARK: - Thea Self-Awareness

    private func gatherTheaInfo() async {
        let bundle = Bundle.main

        theaInfo = TheaInfo(
            version: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            bundleId: bundle.bundleIdentifier ?? "app.thea",
            installDate: getAppInstallDate(),
            lastLaunchDate: Date(),
            totalConversations: UserDefaults.standard.integer(forKey: "Thea.totalConversations"),
            totalMessages: UserDefaults.standard.integer(forKey: "Thea.totalMessages"),
            preferredModel: UserDefaults.standard.string(forKey: "Thea.preferredModel"),
            isFirstLaunch: !UserDefaults.standard.bool(forKey: "Thea.hasLaunched"),
            enabledFeatures: getEnabledFeatures()
        )

        // Mark as launched
        UserDefaults.standard.set(true, forKey: "Thea.hasLaunched")
    }

    // MARK: - Continuous Monitoring

    private func startContinuousMonitoring() {
        guard configuration.enableContinuousMonitoring else { return }

        updateTask?.cancel()
        updateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(configuration.updateIntervalSeconds))

                await gatherSystemState()
                await gatherNetworkInfo()

                if configuration.enableProcessMonitoring {
                    await gatherRunningProcesses()
                }

                lastUpdate = Date()
            }
        }
    }

    func stopMonitoring() {
        updateTask?.cancel()
        updateTask = nil
    }

    func refreshNow() async {
        await gatherInitialInfo()
    }

    // MARK: - Helper Methods

    #if os(macOS)
    private func getMacModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        // Truncate at null terminator and decode as UTF8
        if let nullIndex = model.firstIndex(of: 0) {
            return String(decoding: model[..<nullIndex].map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return String(decoding: model.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func getBatteryLevel() -> Double? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any],
               let capacity = info[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey] as? Int
            {
                return Double(capacity) / Double(maxCapacity) * 100
            }
        }
        return nil
    }

    private func isCharging() -> Bool? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any],
               let isCharging = info[kIOPSIsChargingKey] as? Bool
            {
                return isCharging
            }
        }
        return nil
    }

    private func isDarkModeEnabled() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    private func getCurrentWiFiSSID() -> String? {
        // Requires CoreWLAN framework
        nil
    }

    private func getScreenResolution() -> String {
        if let screen = NSScreen.main {
            let frame = screen.frame
            return "\(Int(frame.width))x\(Int(frame.height))"
        }
        return "Unknown"
    }
    #endif

    #if os(iOS) || os(tvOS)
    private func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return String(
            cString: withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { $0 }
            }
        )
    }

    private func getScreenResolution() -> String {
        let screen = UIScreen.main
        let bounds = screen.nativeBounds
        return "\(Int(bounds.width))x\(Int(bounds.height))"
    }
    #endif

    private func getProcessorType() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel x86_64"
        #else
        return "Unknown"
        #endif
    }

    private func mapThermalState(_ state: ProcessInfo.ThermalState) -> DeviceThermalState {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    private func checkNetworkConnectivity() -> Bool {
        // Synchronous connectivity check using NWPathMonitor snapshot
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var isConnected = false

        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
            semaphore.signal()
        }

        let queue = DispatchQueue(label: "ai.thea.network.check")
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()

        return isConnected
    }

    private func detectConnectionType() -> String {
        // Would need Network framework for accurate detection
        "Unknown"
    }

    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let nameBuffer = withUnsafePointer(to: interface.ifa_name) { ptr in
                        ptr.withMemoryRebound(to: CChar.self, capacity: Int(IFNAMSIZ)) { $0 }
                    }
                    let name = String(cString: nameBuffer)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(
                            interface.ifa_addr,
                            socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        )
                        // Safe conversion: truncate at null and decode as UTF8
                        if let nullIndex = hostname.firstIndex(of: 0) {
                            address = String(decoding: hostname[..<nullIndex].map { UInt8(bitPattern: $0) }, as: UTF8.self)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }

    private func getAppInstallDate() -> Date? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: documentsPath.path)
        return attributes?[.creationDate] as? Date
    }

    private func getEnabledFeatures() -> [String] {
        var features: [String] = []

        if UserDefaults.standard.bool(forKey: "Thea.localModelsEnabled") {
            features.append("Local Models")
        }
        if UserDefaults.standard.bool(forKey: "Thea.cloudSyncEnabled") {
            features.append("Cloud Sync")
        }
        if UserDefaults.standard.bool(forKey: "Thea.automationEnabled") {
            features.append("Automation")
        }
        if UserDefaults.standard.bool(forKey: "Thea.voiceEnabled") {
            features.append("Voice")
        }

        return features
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()

        if config.enableContinuousMonitoring {
            startContinuousMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "UnifiedDeviceAwareness.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data)
        {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "UnifiedDeviceAwareness.config")
        }
    }

    // MARK: - Context Summary for AI

    /// Generate a context summary for the AI to understand the device state
    func generateContextSummary() -> String {
        var summary = """
        ## Device Context

        **Device:** \(deviceInfo.modelName) (\(deviceInfo.platform.rawValue))
        **OS:** \(deviceInfo.osVersion)
        **Processor:** \(deviceInfo.processorType) (\(deviceInfo.processorCores) cores)
        **Memory:** \(String(format: "%.1f", deviceInfo.totalMemoryGB)) GB

        """

        if let batteryLevel = systemState.batteryLevel {
            summary += "**Battery:** \(Int(batteryLevel))%"
            if systemState.isCharging == true {
                summary += " (charging)"
            }
            summary += "\n"
        }

        summary += """
        **Storage:** \(String(format: "%.1f", storageInfo.availableCapacityGB)) GB available of \(String(format: "%.1f", storageInfo.totalCapacityGB)) GB
        **Network:** \(networkInfo.isConnected ? "Connected" : "Disconnected")

        """

        if let activeApp = systemState.activeAppName {
            summary += "**Active App:** \(activeApp)\n"
        }

        summary += """

        **Thea Version:** \(theaInfo.version) (\(theaInfo.buildNumber))
        **Total Conversations:** \(theaInfo.totalConversations)
        """

        return summary
    }
}

// MARK: - Supporting Types
// Note: Uses Platform from PlatformFeaturesHub

enum DeviceThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

struct DeviceHardwareInfo: Sendable {
    var platform: Platform = .unknown
    var modelIdentifier: String = ""
    var modelName: String = ""
    var osVersion: String = ""
    var processorType: String = ""
    var processorCores: Int = 0
    var totalMemoryGB: Double = 0
    var thermalState: DeviceThermalState = .nominal
    var isLowPowerMode: Bool = false
    var screenResolution: String = ""
    var screenCount: Int = 1
}

struct SystemState: Sendable {
    var batteryLevel: Double?
    var isCharging: Bool?
    var uptime: TimeInterval = 0
    var activeAppName: String?
    var activeAppBundleId: String?
    var isFocusModeActive: Bool = false
    var currentLocale: String = ""
    var timezone: String = ""
    var isDarkMode: Bool = false
}

struct SensorData: Sendable {
    var accelerometerData: (x: Double, y: Double, z: Double)?
    var gyroscopeData: (x: Double, y: Double, z: Double)?
    var magnetometerData: (x: Double, y: Double, z: Double)?
    var altitude: Double?
    var pressure: Double?
    var ambientLight: Double?
}

struct StorageInfo: Sendable {
    var totalCapacityGB: Double = 0
    var availableCapacityGB: Double = 0
    var usedCapacityGB: Double = 0
    var usagePercentage: Double = 0
}

struct NetworkInfo: Sendable {
    var isConnected: Bool = false
    var connectionType: String = ""
    var wifiSSID: String?
    var ipAddress: String?
}

struct DeviceInstalledApp: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let bundleId: String
    let version: String
    let path: String
}

struct RunningProcess: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let bundleId: String
    let pid: Int
    let isActive: Bool
    let isHidden: Bool
}

struct TheaInfo: Sendable {
    var version: String = ""
    var buildNumber: String = ""
    var bundleId: String = ""
    var installDate: Date?
    var lastLaunchDate: Date?
    var totalConversations: Int = 0
    var totalMessages: Int = 0
    var preferredModel: String?
    var isFirstLaunch: Bool = true
    var enabledFeatures: [String] = []
}

#if os(watchOS)
import WatchKit
#endif
