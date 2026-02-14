import Foundation
#if os(iOS) || os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
import IOKit.ps
#endif

// MARK: - Data Gathering Methods

extension UnifiedDeviceAwareness {

    // MARK: - Device Info

    func gatherDeviceInfo() async {
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

    func gatherSystemState() async {
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

    func gatherStorageInfo() async {
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

    func gatherNetworkInfo() async {
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

    func gatherDeviceInstalledApps() async {
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

    func gatherRunningProcesses() async {
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

    func gatherTheaInfo() async {
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
}
