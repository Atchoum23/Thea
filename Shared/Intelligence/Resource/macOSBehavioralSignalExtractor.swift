// macOSBehavioralSignalExtractor.swift
// Thea — AJ3: macOS Behavioral Signal Extractor
//
// Extracts passive behavioral signals from the macOS environment:
// - System idle time (IOKit HIDIdleTime)
// - App switch frequency (NSWorkspace notifications)
// - Keyboard/mouse activity cadence (idle/active transitions)
//
// Accumulates ≥ PersonalParameters.ultradianMinSignals signals before
// declaring ultradian phase to HumanReadinessEngine.
//
// macOS only — uses IOKit for idle time measurement.

import Foundation
import OSLog

#if os(macOS)
import AppKit
import IOKit

// MARK: - macOSBehavioralSignalExtractor

@MainActor
public final class MacOSBehavioralSignalExtractor {
    public static let shared = MacOSBehavioralSignalExtractor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "BehavioralSignalExtractor")
    private let params = PersonalParameters.shared

    // MARK: - State

    private var idleObserverTimer: Timer?
    private var appSwitchObserver: NSObjectProtocol?
    private var appSwitchCount: Int = 0
    private var lastAppSwitchTime: Date = .distantPast
    private var wasIdle: Bool = false
    private var signalsSinceReset: Int = 0

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    public func start() {
        setupAppSwitchObserver()
        setupIdleObserver()
        logger.info("macOSBehavioralSignalExtractor started")
    }

    public func stop() {
        idleObserverTimer?.invalidate()
        idleObserverTimer = nil
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appSwitchObserver = nil
        }
        logger.info("macOSBehavioralSignalExtractor stopped")
    }

    // MARK: - Idle Time

    private func setupIdleObserver() {
        // Poll system idle time every 30s — transition triggers signal
        idleObserverTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdleTransition()
            }
        }
    }

    private func checkIdleTransition() {
        let idleSeconds = systemIdleTimeSeconds()
        let idleThreshold = params.idleBreakpointMinutes * 60

        let isNowIdle = idleSeconds >= idleThreshold

        if wasIdle && !isNowIdle {
            // Idle → active transition: user returned from a break
            recordSignal(type: "idle→active", value: idleSeconds)
        } else if !wasIdle && isNowIdle {
            // Active → idle: user paused — potential trough signal
            recordSignal(type: "active→idle", value: idleSeconds)
        }

        wasIdle = isNowIdle
    }

    /// Returns system HID idle time in seconds via IOKit.
    private func systemIdleTimeSeconds() -> TimeInterval {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem")
        )
        defer { IOObjectRelease(service) }

        var idleTime: TimeInterval = 0

        if let property = IORegistryEntryCreateCFProperty(
            service,
            "HIDIdleTime" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? UInt64 {
            // HIDIdleTime is in nanoseconds
            idleTime = TimeInterval(property) / 1_000_000_000
        }

        return idleTime
    }

    // MARK: - App Switch Tracking

    private func setupAppSwitchObserver() {
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordAppSwitch()
            }
        }
    }

    private func recordAppSwitch() {
        let now = Date.now
        let timeSinceLastSwitch = now.timeIntervalSince(lastAppSwitchTime)
        lastAppSwitchTime = now
        appSwitchCount += 1

        // Rapid app switching (< 30s) can indicate cognitive fragmentation — signal trough
        if timeSinceLastSwitch < 30 {
            recordSignal(type: "rapid-app-switch", value: timeSinceLastSwitch)
        }
    }

    // MARK: - Signal Dispatch

    private func recordSignal(type: String, value: Double) {
        signalsSinceReset += 1
        HumanReadinessEngine.shared.recordBehavioralSignal()

        logger.debug("Behavioral signal: \(type) value=\(value, format: .fixed(precision: 1)) total=\(self.signalsSinceReset)")
    }
}

#endif
