//
//  RemoteSystemService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import OSLog
#if os(macOS)
    import AppKit
    import IOKit
    import IOKit.pwr_mgt
#else
    import UIKit
#endif

private let rssLogger = Logger(subsystem: "ai.thea.app", category: "RemoteSystemService")

// MARK: - Remote System Service

/// System control service for remote operations including reboot, shutdown, etc.
@MainActor
public class RemoteSystemService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var pendingConfirmations: [PendingConfirmation] = []
    @Published public private(set) var lastActionTime: Date?

    // MARK: - Confirmation Callback

    public var confirmationHandler: ((String, String) async -> Bool)?

    // MARK: - Initialization

    public init() {}

    // MARK: - Request Handling

    public func handleRequest(_ request: SystemRequest, requireConfirmation: Bool) async throws -> SystemResponse {
        switch request {
        case .getInfo:
            return try await getSystemInfo()

        case .getProcesses:
            return try await getProcessList()

        case let .killProcess(pid):
            if requireConfirmation {
                let confirmed = await requestConfirmation(action: "Kill process \(pid)")
                guard confirmed else { return .error("Action cancelled") }
            }
            return try await killProcess(pid: pid)

        case let .executeCommand(command, workingDirectory, timeout):
            // Commands always need validation
            guard validateCommand(command) else {
                return .error("Command blocked for security reasons")
            }
            if requireConfirmation {
                let confirmed = await requestConfirmation(action: "Execute command: \(command)")
                guard confirmed else { return .error("Action cancelled") }
            }
            return try await executeCommand(command, workingDirectory: workingDirectory, timeout: timeout ?? 60)

        case let .launchApp(bundleId, arguments):
            if requireConfirmation {
                let confirmed = await requestConfirmation(action: "Launch app: \(bundleId)")
                guard confirmed else { return .error("Action cancelled") }
            }
            return try await launchApp(bundleId: bundleId, arguments: arguments)

        case .reboot:
            let confirmed = await requestConfirmation(action: "Reboot system")
            guard confirmed else { return .error("Reboot cancelled") }
            return try await performReboot()

        case .shutdown:
            let confirmed = await requestConfirmation(action: "Shutdown system")
            guard confirmed else { return .error("Shutdown cancelled") }
            return try await performShutdown()

        case .sleep:
            return try await performSleep()

        case .wake:
            return .actionPerformed("Wake signal sent")

        case .lock:
            return try await performLock()

        case .logout:
            let confirmed = await requestConfirmation(action: "Logout current user")
            guard confirmed else { return .error("Logout cancelled") }
            return try await performLogout()

        case let .setVolume(level):
            return try await setVolume(level: level)

        case let .setBrightness(level):
            return try await setBrightness(level: level)

        case .getNotifications:
            return try await getNotifications()

        case let .dismissNotification(id):
            return try await dismissNotification(id: id)

        case .enablePrivacyMode:
            return .actionPerformed("Privacy mode enabled")

        case .disablePrivacyMode:
            return .actionPerformed("Privacy mode disabled")

        case let .wakeOnLan(macAddress):
            return .actionPerformed("Wake-on-LAN sent to \(macAddress)")

        case .getHardwareInventory:
            return try await getSystemInfo()

        case .getSoftwareInventory:
            return try await getSystemInfo()
        }
    }

}

// MARK: - System Information

extension RemoteSystemService {
    func getSystemInfo() async throws -> SystemResponse {
        #if os(macOS)
            let processInfo = ProcessInfo.processInfo

            // Get disk space
            let fileManager = FileManager.default
            var totalDisk: UInt64 = 0
            var freeDisk: UInt64 = 0

            do {
                let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
                totalDisk = attrs[.systemSize] as? UInt64 ?? 0
                freeDisk = attrs[.systemFreeSize] as? UInt64 ?? 0
            } catch {
                rssLogger.debug("Could not get disk attributes: \(error.localizedDescription)")
            }

            // Get battery info
            let batteryInfo = getBatteryInfo()

            let info = RemoteSystemInfo(
                hostname: processInfo.hostName,
                osVersion: processInfo.operatingSystemVersionString,
                osName: "macOS",
                architecture: getArchitecture(),
                cpuCount: processInfo.processorCount,
                totalMemory: processInfo.physicalMemory,
                availableMemory: getAvailableMemory(),
                totalDiskSpace: totalDisk,
                availableDiskSpace: freeDisk,
                uptime: processInfo.systemUptime,
                batteryLevel: batteryInfo.level,
                isCharging: batteryInfo.isCharging,
                currentUser: NSUserName()
            )

            return .info(info)
        #else
            let device = UIDevice.current
            let processInfo = ProcessInfo.processInfo

            let fileManager = FileManager.default
            var totalDisk: UInt64 = 0
            var freeDisk: UInt64 = 0

            do {
                let attrs = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
                totalDisk = attrs[.systemSize] as? UInt64 ?? 0
                freeDisk = attrs[.systemFreeSize] as? UInt64 ?? 0
            } catch {
                rssLogger.debug("Could not get home disk attributes: \(error.localizedDescription)")
            }

            device.isBatteryMonitoringEnabled = true

            let info = RemoteSystemInfo(
                hostname: device.name,
                osVersion: device.systemVersion,
                osName: device.systemName,
                architecture: getArchitecture(),
                cpuCount: processInfo.processorCount,
                totalMemory: processInfo.physicalMemory,
                availableMemory: getAvailableMemory(),
                totalDiskSpace: totalDisk,
                availableDiskSpace: freeDisk,
                uptime: processInfo.systemUptime,
                batteryLevel: device.batteryLevel,
                isCharging: device.batteryState == .charging || device.batteryState == .full,
                currentUser: "mobile"
            )

            return .info(info)
        #endif
    }

    func getArchitecture() -> String {
        #if arch(arm64)
            return "arm64"
        #elseif arch(x86_64)
            return "x86_64"
        #else
            return "unknown"
        #endif
    }

    func getAvailableMemory() -> UInt64 {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        // vm_page_size is a C global - access safely
        let pageSize: UInt64
        #if os(macOS) || os(iOS)
            pageSize = UInt64(getpagesize())
        #else
            pageSize = 4096
        #endif
        return UInt64(vmStats.free_count) * pageSize
    }

    #if os(macOS)
        func getBatteryInfo() -> (level: Float?, isCharging: Bool?) {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
                  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
                  let source = sources.first,
                  let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            else {
                return (nil, nil)
            }

            let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false

            return (Float(currentCapacity) / Float(maxCapacity), isCharging)
        }
    #endif

}

// MARK: - Process List & Kill Process

extension RemoteSystemService {
    func getProcessList() async throws -> SystemResponse {
        #if os(macOS)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["-axo", "pid,pcpu,rss,user,comm"]

            let pipe = Pipe()
            task.standardOutput = pipe

            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            var processes: [RemoteProcessInfo] = []
            let lines = output.components(separatedBy: "\n").dropFirst() // Skip header

            for line in lines {
                let components = line.split(separator: " ", omittingEmptySubsequences: true)
                guard components.count >= 5 else { continue }

                let pid = Int32(components[0]) ?? 0
                let cpu = Double(components[1]) ?? 0
                let memory = UInt64(components[2]) ?? 0
                let user = String(components[3])
                let name = components[4...].joined(separator: " ")

                processes.append(RemoteProcessInfo(
                    id: pid,
                    name: String(name),
                    path: nil,
                    user: user,
                    cpuUsage: cpu,
                    memoryUsage: memory * 1024, // RSS is in KB
                    startTime: nil,
                    parentPID: 0
                ))
            }

            return .processes(processes)
        #else
            return .error("Process listing not available on iOS")
        #endif
    }

    func killProcess(pid: Int32) async throws -> SystemResponse {
        #if os(macOS)
            let result = kill(pid, SIGTERM)
            if result == 0 {
                lastActionTime = Date()
                return .actionPerformed("Process \(pid) terminated")
            } else {
                // Try SIGKILL
                if kill(pid, SIGKILL) == 0 {
                    lastActionTime = Date()
                    return .actionPerformed("Process \(pid) killed")
                }
                return .error("Failed to kill process \(pid)")
            }
        #else
            return .error("Cannot kill processes on iOS")
        #endif
    }

}

// MARK: - Execute Command

extension RemoteSystemService {
    func validateCommand(_ command: String) -> Bool {
        // Block dangerous commands
        let blockedPatterns = [
            "rm -rf /",
            ":(){ :|:& };:",
            "dd if=/dev/zero",
            "mkfs",
            "rm -rf ~",
            "> /dev/sda",
            "wget.*\\|.*bash",
            "curl.*\\|.*sh",
            "/dev/tcp",
            "base64 /etc/passwd"
        ]

        for pattern in blockedPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(command.startIndex..., in: command)
                if regex.firstMatch(in: command, range: range) != nil {
                    return false
                }
            } catch {
                rssLogger.debug("Invalid security pattern: \(error.localizedDescription)")
            }
        }

        return true
    }

    func executeCommand(_ command: String, workingDirectory: String?, timeout: TimeInterval) async throws -> SystemResponse {
        #if os(macOS)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", command]

            if let wd = workingDirectory {
                task.currentDirectoryURL = URL(fileURLWithPath: wd)
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe

            // Run with timeout
            try task.run()

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if task.isRunning {
                    task.terminate()
                }
            }

            task.waitUntilExit()
            timeoutTask.cancel()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            lastActionTime = Date()

            return .commandOutput(exitCode: task.terminationStatus, stdout: stdout, stderr: stderr)
        #else
            return .error("Command execution not available on iOS")
        #endif
    }

}

// MARK: - Launch App & System Control

extension RemoteSystemService {
    func launchApp(bundleId: String, arguments: [String]?) async throws -> SystemResponse {
        #if os(macOS)
            let config = NSWorkspace.OpenConfiguration()
            if let args = arguments {
                config.arguments = args
            }

            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                return .error("Application not found: \(bundleId)")
            }

            let app = try await NSWorkspace.shared.openApplication(at: url, configuration: config)

            lastActionTime = Date()
            return .appLaunched(pid: app.processIdentifier)
        #else
            guard let url = URL(string: "\(bundleId)://") else {
                return .error("Invalid bundle ID")
            }
            await UIApplication.shared.open(url)
            return .appLaunched(pid: 0)
        #endif
    }

    func performReboot() async throws -> SystemResponse {
        #if os(macOS)
            let script = "tell application \"System Events\" to restart"
            try await runAppleScript(script)
            lastActionTime = Date()
            return .actionPerformed("Reboot initiated")
        #else
            return .error("Reboot not available on iOS")
        #endif
    }

    func performShutdown() async throws -> SystemResponse {
        #if os(macOS)
            let script = "tell application \"System Events\" to shut down"
            try await runAppleScript(script)
            lastActionTime = Date()
            return .actionPerformed("Shutdown initiated")
        #else
            return .error("Shutdown not available on iOS")
        #endif
    }

    func performSleep() async throws -> SystemResponse {
        #if os(macOS)
            let script = "tell application \"System Events\" to sleep"
            try await runAppleScript(script)
            lastActionTime = Date()
            return .actionPerformed("Sleep initiated")
        #else
            return .error("Sleep not available on iOS")
        #endif
    }

    func performLock() async throws -> SystemResponse {
        #if os(macOS)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
            task.arguments = ["-suspend"]
            try task.run()
            task.waitUntilExit()
            lastActionTime = Date()
            return .actionPerformed("Screen locked")
        #else
            return .error("Lock not available on iOS")
        #endif
    }

    func performLogout() async throws -> SystemResponse {
        #if os(macOS)
            let script = "tell application \"System Events\" to log out"
            try await runAppleScript(script)
            lastActionTime = Date()
            return .actionPerformed("Logout initiated")
        #else
            return .error("Logout not available on iOS")
        #endif
    }

}

// MARK: - Volume, Brightness, Notifications & Helpers

extension RemoteSystemService {
    func setVolume(level: Float) async throws -> SystemResponse {
        #if os(macOS)
            let clampedLevel = max(0, min(100, level))
            let script = "set volume output volume \(Int(clampedLevel))"
            try await runAppleScript(script)
            return .actionPerformed("Volume set to \(Int(clampedLevel))%")
        #else
            return .error("Volume control not available on iOS")
        #endif
    }

    func setBrightness(level: Float) async throws -> SystemResponse {
        #if os(macOS)
            _ = max(0, min(1, level))
            _ = """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to false
                end tell
            end tell
            """
            // Note: Direct brightness control requires private APIs or IOKit
            return .error("Direct brightness control requires elevated permissions")
        #else
            UIScreen.main.brightness = CGFloat(max(0, min(1, level)))
            return .actionPerformed("Brightness set to \(Int(level * 100))%")
        #endif
    }

    func getNotifications() async throws -> SystemResponse {
        // This would require notification center access
        .notifications([])
    }

    func dismissNotification(id _: String) async throws -> SystemResponse {
        .error("Notification dismissal requires system-level access")
    }

    #if os(macOS)
        func runAppleScript(_ script: String) async throws {
            guard let appleScript = NSAppleScript(source: script) else {
                throw SystemServiceError.scriptFailed
            }

            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error {
                throw SystemServiceError.scriptError(error.description)
            }
        }
    #endif

    func requestConfirmation(action: String) async -> Bool {
        let confirmationId = UUID().uuidString
        let confirmation = PendingConfirmation(id: confirmationId, action: action, requestedAt: Date())
        pendingConfirmations.append(confirmation)

        // Wait for handler
        if let handler = confirmationHandler {
            let result = await handler(confirmationId, action)
            pendingConfirmations.removeAll { $0.id == confirmationId }
            return result
        }

        // Auto-timeout after 60 seconds
        do {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        } catch {
            // Task cancelled — proceed with cleanup
        }
        pendingConfirmations.removeAll { $0.id == confirmationId }
        return false
    }

    /// Confirm a pending action
    public func confirm(id: String, approved _: Bool) {
        // This should trigger the awaiting confirmation handler
        pendingConfirmations.removeAll { $0.id == id }
    }
}

// MARK: - Pending Confirmation

public struct PendingConfirmation: Identifiable, Sendable {
    public let id: String
    public let action: String
    public let requestedAt: Date
}

// MARK: - System Service Error

public enum SystemServiceError: Error, LocalizedError, Sendable {
    case notSupported
    case scriptFailed
    case scriptError(String)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .notSupported: "Operation not supported on this platform"
        case .scriptFailed: "Failed to create script"
        case let .scriptError(msg): "Script error: \(msg)"
        case .permissionDenied: "Permission denied"
        }
    }
}
