//
//  SystemIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
import IOKit.ps
#endif

// MARK: - System Integration

/// Integration module for system-level operations
public actor SystemIntegration: IntegrationModule {
    public static let shared = SystemIntegration()

    public let moduleId = "system"
    public let displayName = "System"
    public let bundleIdentifier = "com.apple.systempreferences"
    public let icon = "gearshape.2"

    private var isConnected = false

    private init() {}

    public func connect() async throws {
        isConnected = true
    }

    public func disconnect() async { isConnected = false }

    public func isAvailable() async -> Bool { true }

    // MARK: - System Info

    /// Get system information
    public func getSystemInfo() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo

        return SystemInfo(
            hostName: processInfo.hostName,
            osVersion: processInfo.operatingSystemVersionString,
            processorCount: processInfo.processorCount,
            physicalMemory: processInfo.physicalMemory,
            systemUptime: processInfo.systemUptime,
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled
        )
    }

    /// Get battery information
    public func getBatteryInfo() -> BatteryInfo? {
        #if os(macOS)
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        guard let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        return BatteryInfo(
            level: info[kIOPSCurrentCapacityKey] as? Int ?? 0,
            isCharging: (info[kIOPSIsChargingKey] as? Bool) ?? false,
            isPluggedIn: (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
            timeToEmpty: info[kIOPSTimeToEmptyKey] as? Int,
            timeToFullCharge: info[kIOPSTimeToFullChargeKey] as? Int
        )
        #else
        return nil
        #endif
    }

    // MARK: - Display Control

    /// Get display brightness (0-1)
    public func getDisplayBrightness() async throws -> Float {
        #if os(macOS)
        let script = "do shell script \"brightness -l | grep 'display' | head -1 | awk '{print $NF}'\""
        let result = try await executeAppleScript(script)
        return Float(result ?? "1") ?? 1.0
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Set display brightness (0-1)
    public func setDisplayBrightness(_ brightness: Float) async throws {
        #if os(macOS)
        let clampedBrightness = max(0, min(1, brightness))
        let script = "do shell script \"brightness \(clampedBrightness)\""
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Audio Control

    /// Get system volume (0-100)
    public func getVolume() async throws -> Int {
        #if os(macOS)
        let script = "output volume of (get volume settings)"
        let result = try await executeAppleScript(script)
        return Int(result ?? "50") ?? 50
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Set system volume (0-100)
    public func setVolume(_ volume: Int) async throws {
        #if os(macOS)
        let clampedVolume = max(0, min(100, volume))
        let script = "set volume output volume \(clampedVolume)"
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Mute/unmute
    public func setMuted(_ muted: Bool) async throws {
        #if os(macOS)
        let script = "set volume output muted \(muted)"
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Notifications

    /// Enable/disable Do Not Disturb
    public func setDoNotDisturb(_ enabled: Bool) async throws {
        #if os(macOS)
        let script = """
        tell application "System Events"
            tell process "Control Center"
                click menu bar item "Focus" of menu bar 1
                delay 0.5
                if \(enabled) then
                    click button "Do Not Disturb" of window 1
                else
                    click button "Do Not Disturb" of window 1
                end if
            end tell
        end tell
        """
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Power

    /// Put display to sleep
    public func sleepDisplay() async throws {
        #if os(macOS)
        let script = "do shell script \"pmset displaysleepnow\""
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Lock screen
    public func lockScreen() async throws {
        #if os(macOS)
        let script = """
        tell application "System Events"
            keystroke "q" using {command down, control down}
        end tell
        """
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Clipboard

    /// Get clipboard content
    public func getClipboardContent() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return nil
        #endif
    }

    /// Set clipboard content
    public func setClipboardContent(_ content: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        #endif
    }

    // MARK: - Apps

    /// Get running applications
    public func getRunningApplications() -> [RunningAppInfo] {
        #if os(macOS)
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(
                    bundleIdentifier: bundleId,
                    name: name,
                    isActive: app.isActive,
                    isHidden: app.isHidden
                )
            }
        #else
        return []
        #endif
    }

    /// Quit an application
    public func quitApplication(_ bundleId: String) async throws {
        #if os(macOS)
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw IntegrationModuleError.appNotRunning(bundleId)
        }
        app.terminate()
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Force quit an application
    public func forceQuitApplication(_ bundleId: String) async throws {
        #if os(macOS)
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw IntegrationModuleError.appNotRunning(bundleId)
        }
        app.forceTerminate()
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    #if os(macOS)
    private func executeAppleScript(_ source: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    let result = script.executeAndReturnError(&error)
                    if let error = error {
                        continuation.resume(throwing: IntegrationModuleError.scriptError(error.description))
                    } else {
                        continuation.resume(returning: result.stringValue)
                    }
                } else {
                    continuation.resume(throwing: IntegrationModuleError.scriptError("Failed to create script"))
                }
            }
        }
    }
    #endif
}

public struct SystemInfo: Sendable {
    public let hostName: String
    public let osVersion: String
    public let processorCount: Int
    public let physicalMemory: UInt64
    public let systemUptime: TimeInterval
    public let isLowPowerModeEnabled: Bool

    public var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory)
    }

    public var formattedUptime: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        return formatter.string(from: systemUptime) ?? ""
    }
}

public struct BatteryInfo: Sendable {
    public let level: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let timeToEmpty: Int?
    public let timeToFullCharge: Int?
}

public struct RunningAppInfo: Sendable, Identifiable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public let name: String
    public let isActive: Bool
    public let isHidden: Bool
}
