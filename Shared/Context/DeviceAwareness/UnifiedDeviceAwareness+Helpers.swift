import Foundation
import Network
import OSLog
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
import IOKit.ps
#endif

private let deviceAwarenessHelpersLogger = Logger(subsystem: "ai.thea.app", category: "UnifiedDeviceAwareness")

// MARK: - Helper Methods

extension UnifiedDeviceAwareness {

    #if os(macOS)
    func getMacModelIdentifier() -> String {
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

    func getBatteryLevel() -> Double? {
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

    func isCharging() -> Bool? {
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

    func isDarkModeEnabled() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    func getCurrentWiFiSSID() -> String? {
        // Requires CoreWLAN framework
        nil
    }

    func getScreenResolution() -> String {
        if let screen = NSScreen.main {
            let frame = screen.frame
            return "\(Int(frame.width))x\(Int(frame.height))"
        }
        return "Unknown"
    }
    #endif

    #if os(iOS) || os(tvOS)
    func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return String(
            cString: withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { $0 }
            }
        )
    }

    func getScreenResolution() -> String {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let screen = scenes.first?.screen {
            let bounds = screen.nativeBounds
            return "\(Int(bounds.width))x\(Int(bounds.height))"
        }
        return "unknown"
    }
    #endif

    func getProcessorType() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel x86_64"
        #else
        return "Unknown"
        #endif
    }

    func mapThermalState(_ state: ProcessInfo.ThermalState) -> DeviceThermalState {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    func checkNetworkConnectivity() -> Bool {
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

    func detectConnectionType() -> String {
        // Would need Network framework for accurate detection
        "Unknown"
    }

    func getIPAddress() -> String? {
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

    func getAppInstallDate() -> Date? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: documentsPath.path)
            return attributes[.creationDate] as? Date
        } catch {
            deviceAwarenessHelpersLogger.error("Failed to get app install date: \(error.localizedDescription)")
            return nil
        }
    }

    func getEnabledFeatures() -> [String] {
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

    // MARK: - Context Summary for AI

    /// Generate a context summary for the AI to understand the device state
    // periphery:ignore - Reserved: generateContextSummary() instance method reserved for future feature activation
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
