//
//  AssetInventoryService.swift
//  Thea
//
//  Apple Remote Desktop-style asset and inventory reporting for managed Macs
//

import Foundation

// MARK: - Asset Inventory Service

/// Collects hardware and software inventory data from remote Macs (Apple Remote Desktop style)
@MainActor
public class AssetInventoryService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var lastInventoryDate: Date?
    @Published public private(set) var isCollecting = false
    @Published public private(set) var cachedHardware: HardwareInventory?
    @Published public private(set) var cachedSoftware: SoftwareInventory?

    // MARK: - Initialization

    public init() {}

    // MARK: - Collect Inventory

    /// Collect full hardware and software inventory
    public func collectFullInventory() async -> (hardware: HardwareInventory, software: SoftwareInventory) {
        isCollecting = true
        defer {
            isCollecting = false
            lastInventoryDate = Date()
        }

        async let hw = collectHardwareInventory()
        async let sw = collectSoftwareInventory()

        let hardware = await hw
        let software = await sw

        cachedHardware = hardware
        cachedSoftware = software

        return (hardware, software)
    }

    // MARK: - Hardware Inventory

    /// Collect detailed hardware information via system_profiler
    public func collectHardwareInventory() async -> HardwareInventory {
        #if os(macOS)
            let hardwareData = await runSystemProfiler(dataType: "SPHardwareDataType")
            let storageData = await runSystemProfiler(dataType: "SPStorageDataType")
            let displayData = await runSystemProfiler(dataType: "SPDisplaysDataType")
            let networkData = await runSystemProfiler(dataType: "SPNetworkDataType")
            let memoryData = await runSystemProfiler(dataType: "SPMemoryDataType")
            let powerData = await runSystemProfiler(dataType: "SPPowerDataType")

            let hw = parseHardwareProfile(hardwareData)
            let storage = parseStorageDevices(storageData)
            let displays = parseDisplayDevices(displayData)
            let network = parseAssetNetworkInterfaces(networkData)
            let memoryDetails = parseMemoryDetails(memoryData)
            let battery = parseBatteryInfo(powerData)

            return HardwareInventory(
                modelName: hw["model_name"] ?? ProcessInfo.processInfo.hostName,
                modelIdentifier: hw["model_identifier"] ?? "Unknown",
                chipType: hw["chip_type"] ?? hw["cpu_type"] ?? "Unknown",
                totalCores: Int(hw["number_processors"] ?? "0") ?? ProcessInfo.processInfo.processorCount,
                performanceCores: Int(hw["performance_cores"] ?? "0"),
                efficiencyCores: Int(hw["efficiency_cores"] ?? "0"),
                memoryGB: Int(hw["physical_memory"]?.replacingOccurrences(of: " GB", with: "") ?? "0") ?? 0,
                memoryType: memoryDetails["type"] ?? "Unified",
                serialNumber: hw["serial_number"] ?? "Unknown",
                hardwareUUID: hw["platform_UUID"] ?? "Unknown",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                osBuild: hw["os_build"] ?? "",
                hostname: ProcessInfo.processInfo.hostName,
                uptimeSeconds: ProcessInfo.processInfo.systemUptime,
                storageDevices: storage,
                displays: displays,
                networkInterfaces: network,
                peripherals: [],
                batteryLevel: battery["level"],
                batteryHealth: battery["health"],
                isLaptop: battery["isLaptop"] != nil
            )
        #else
            return HardwareInventory(
                modelName: "iOS Device",
                modelIdentifier: "Unknown",
                chipType: "Apple Silicon",
                totalCores: ProcessInfo.processInfo.processorCount,
                performanceCores: nil,
                efficiencyCores: nil,
                memoryGB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824),
                memoryType: "LPDDR",
                serialNumber: "N/A",
                hardwareUUID: "N/A",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                osBuild: "",
                hostname: ProcessInfo.processInfo.hostName,
                uptimeSeconds: ProcessInfo.processInfo.systemUptime,
                storageDevices: [],
                displays: [],
                networkInterfaces: [],
                peripherals: [],
                batteryLevel: nil,
                batteryHealth: nil,
                isLaptop: true
            )
        #endif
    }

    // MARK: - Software Inventory

    /// Collect installed applications
    public func collectSoftwareInventory() async -> SoftwareInventory {
        #if os(macOS)
            let apps = await collectInstalledApps()
            return SoftwareInventory(
                installedApps: apps,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                kernelVersion: await getKernelVersion(),
                lastSoftwareUpdate: nil
            )
        #else
            return SoftwareInventory(
                installedApps: [],
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                kernelVersion: "",
                lastSoftwareUpdate: nil
            )
        #endif
    }

    // MARK: - Export

    /// Export inventory as JSON
    public func exportAsJSON() -> Data? {
        guard let hw = cachedHardware, let sw = cachedSoftware else { return nil }

        let report = InventoryReport(
            collectedAt: lastInventoryDate ?? Date(),
            hardware: hw,
            software: sw
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(report)
    }

    /// Export inventory as CSV (apps list)
    public func exportAppsAsCSV() -> String {
        guard let sw = cachedSoftware else { return "" }

        var csv = "Name,Version,Bundle ID,Location,Size (MB),Last Modified\n"
        let formatter = ISO8601DateFormatter()

        for app in sw.installedApps {
            let fields = [
                escapeCSV(app.name),
                app.version,
                app.bundleIdentifier ?? "",
                app.location,
                app.sizeBytes.map { String($0 / 1_048_576) } ?? "",
                app.lastModified.map { formatter.string(from: $0) } ?? ""
            ]
            csv += fields.joined(separator: ",") + "\n"
        }

        return csv
    }

    // MARK: - Private: system_profiler

    #if os(macOS)
        private func runSystemProfiler(dataType: String) async -> [String: Any] {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            task.arguments = [dataType, "-json"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return [:]
                }
                return json
            } catch {
                return [:]
            }
        }

        private func parseHardwareProfile(_ json: [String: Any]) -> [String: String] {
            guard let items = json["SPHardwareDataType"] as? [[String: Any]],
                  let hw = items.first
            else { return [:] }

            var result: [String: String] = [:]
            for (key, value) in hw {
                if let str = value as? String {
                    result[key] = str
                }
            }
            return result
        }

        private func parseStorageDevices(_ json: [String: Any]) -> [StorageDevice] {
            guard let items = json["SPStorageDataType"] as? [[String: Any]] else { return [] }

            return items.compactMap { item in
                guard let name = item["_name"] as? String else { return nil }
                let sizeStr = item["size_in_bytes"] as? Int64 ?? 0
                let freeStr = item["free_space_in_bytes"] as? Int64 ?? 0
                let fsType = item["file_system"] as? String ?? "Unknown"
                let mountPoint = item["mount_point"] as? String ?? ""

                return StorageDevice(
                    name: name,
                    totalBytes: sizeStr,
                    freeBytes: freeStr,
                    fileSystem: fsType,
                    mountPoint: mountPoint,
                    isInternal: mountPoint == "/" || mountPoint.hasPrefix("/System")
                )
            }
        }

        private func parseDisplayDevices(_ json: [String: Any]) -> [DisplayDevice] {
            guard let items = json["SPDisplaysDataType"] as? [[String: Any]] else { return [] }

            var displays: [DisplayDevice] = []
            for gpu in items {
                guard let ndrvs = gpu["spdisplays_ndrvs"] as? [[String: Any]] else { continue }
                for display in ndrvs {
                    let name = display["_name"] as? String ?? "Display"
                    let resolution = display["_spdisplays_resolution"] as? String ?? "Unknown"
                    let isBuiltIn = display["spdisplays_connection_type"] as? String == "spdisplays_builtin"

                    displays.append(DisplayDevice(
                        name: name,
                        resolution: resolution,
                        isBuiltIn: isBuiltIn,
                        displayID: nil
                    ))
                }
            }

            return displays
        }

        private func parseAssetNetworkInterfaces(_ json: [String: Any]) -> [AssetNetworkInterface] {
            guard let items = json["SPNetworkDataType"] as? [[String: Any]] else { return [] }

            return items.compactMap { item in
                guard let name = item["_name"] as? String else { return nil }
                let interface = item["interface"] as? String ?? ""
                let ipv4 = (item["IPv4"] as? [String: Any])?["Addresses"] as? [String]
                let macAddress = item["Ethernet"] as? [String: Any]

                return AssetNetworkInterface(
                    name: name,
                    interfaceName: interface,
                    ipAddress: ipv4?.first,
                    macAddress: (macAddress?["MAC Address"] as? String) ?? "",
                    isActive: item["ip_assigned"] as? String == "yes"
                )
            }
        }

        private func parseMemoryDetails(_ json: [String: Any]) -> [String: String] {
            guard let items = json["SPMemoryDataType"] as? [[String: Any]],
                  let mem = items.first
            else { return [:] }

            var result: [String: String] = [:]
            if let type = mem["dimm_type"] as? String { result["type"] = type }
            if let upgradeable = mem["is_memory_upgradeable"] as? String { result["upgradeable"] = upgradeable }
            return result
        }

        private func parseBatteryInfo(_ json: [String: Any]) -> [String: String] {
            guard let items = json["SPPowerDataType"] as? [[String: Any]] else { return [:] }

            var result: [String: String] = [:]
            for item in items {
                if let batteryInfo = item["sppower_battery_charge_info"] as? [String: Any] {
                    result["isLaptop"] = "true"
                    if let level = batteryInfo["sppower_battery_state_of_charge"] as? Int {
                        result["level"] = String(level)
                    }
                }
                if let healthInfo = item["sppower_battery_health_info"] as? [String: Any] {
                    if let health = healthInfo["sppower_battery_health"] as? String {
                        result["health"] = health
                    }
                }
            }

            return result
        }

        private func collectInstalledApps() async -> [InstalledApp] {
            let appDirs = [
                "/Applications",
                "/System/Applications",
                NSHomeDirectory() + "/Applications"
            ]

            var apps: [InstalledApp] = []
            let fm = FileManager.default

            for dir in appDirs {
                guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }

                for item in contents where item.hasSuffix(".app") {
                    let appPath = (dir as NSString).appendingPathComponent(item)
                    let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")

                    guard let plistData = fm.contents(atPath: plistPath),
                          let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
                    else { continue }

                    let name = plist["CFBundleDisplayName"] as? String
                        ?? plist["CFBundleName"] as? String
                        ?? item.replacingOccurrences(of: ".app", with: "")
                    let version = plist["CFBundleShortVersionString"] as? String ?? "Unknown"
                    let bundleId = plist["CFBundleIdentifier"] as? String

                    let attrs = try? fm.attributesOfItem(atPath: appPath)
                    let size = attrs?[.size] as? Int64
                    let modified = attrs?[.modificationDate] as? Date

                    apps.append(InstalledApp(
                        name: name,
                        version: version,
                        bundleIdentifier: bundleId,
                        location: appPath,
                        sizeBytes: size,
                        lastModified: modified
                    ))
                }
            }

            return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }

        private func getKernelVersion() async -> String {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/uname")
            task.arguments = ["-a"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } catch {
                return ""
            }
        }
    #endif

    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }
}

// MARK: - Inventory Report

public struct InventoryReport: Codable, Sendable {
    public let collectedAt: Date
    public let hardware: HardwareInventory
    public let software: SoftwareInventory
}
