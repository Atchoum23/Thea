//
//  PowerObserver.swift
//  Thea
//
//  Created by Thea
//

#if os(macOS)
    import Foundation
    import IOKit.ps
    import os.log

    /// Observes power state and battery information on macOS
    /// Uses IOKit for battery status and power source monitoring
    @MainActor
    public final class PowerObserver {
        public static let shared = PowerObserver()

        private let logger = Logger(subsystem: "app.thea.power", category: "PowerObserver")

        // Callbacks
        public var onPowerStateChanged: ((PowerState) -> Void)?
        public var onBatteryLevelChanged: ((Int) -> Void)?
        public var onChargingStateChanged: ((ChargingState) -> Void)?

        // State
        public private(set) var currentPowerState: PowerState = .init()
        private var runLoopSource: CFRunLoopSource?
        private var pollingTimer: Timer?

        private init() {}

        // MARK: - Lifecycle

        public func start() {
            // Get initial state
            updatePowerState()

            // Poll for battery changes (IOKit notifications can be unreliable)
            pollingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updatePowerState()
                }
            }

            // Listen for power source changes
            let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                let observer = Unmanaged<PowerObserver>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in
                    observer.updatePowerState()
                }
            }, context).takeRetainedValue()

            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
            }

            logger.info("Power observer started")
        }

        public func stop() {
            pollingTimer?.invalidate()
            pollingTimer = nil

            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            }
            runLoopSource = nil

            logger.info("Power observer stopped")
        }

        // MARK: - Power State Updates

        private func updatePowerState() {
            let newState = fetchPowerState()

            let levelChanged = currentPowerState.batteryLevel != newState.batteryLevel
            let chargingChanged = currentPowerState.chargingState != newState.chargingState
            let stateChanged = currentPowerState != newState

            currentPowerState = newState

            if stateChanged {
                onPowerStateChanged?(newState)
            }

            if levelChanged {
                onBatteryLevelChanged?(newState.batteryLevel)
                logger.debug("Battery level: \(newState.batteryLevel)%")
            }

            if chargingChanged {
                onChargingStateChanged?(newState.chargingState)
                logger.info("Charging state: \(newState.chargingState.rawValue)")
            }
        }

        private func fetchPowerState() -> PowerState {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
                  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
                  let source = sources.first,
                  let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
            else {
                // No battery (desktop Mac)
                return PowerState(
                    hasBattery: false,
                    batteryLevel: 100,
                    chargingState: .pluggedIn,
                    isLowPowerMode: false,
                    timeToEmpty: nil,
                    timeToFullCharge: nil,
                    powerSource: .ac,
                    health: nil,
                    cycleCount: nil,
                    temperature: nil
                )
            }

            let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let batteryLevel = maxCapacity > 0 ? (currentCapacity * 100) / maxCapacity : 0

            let isCharging = description[kIOPSIsChargingKey as String] as? Bool ?? false
            let isPluggedIn = description[kIOPSPowerSourceStateKey as String] as? String == kIOPSACPowerValue

            let chargingState: ChargingState = if isCharging {
                .charging
            } else if isPluggedIn {
                .pluggedIn
            } else {
                .discharging
            }

            let timeToEmpty = description[kIOPSTimeToEmptyKey as String] as? Int
            let timeToFullCharge = description[kIOPSTimeToFullChargeKey as String] as? Int

            let powerSource: MacPowerSource = isPluggedIn ? .ac : .battery

            // Health and cycle count (may not be available on all Macs)
            let health = description["BatteryHealth"] as? String
            let cycleCount = description["CycleCount"] as? Int

            return PowerState(
                hasBattery: true,
                batteryLevel: batteryLevel,
                chargingState: chargingState,
                isLowPowerMode: isLowPowerModeEnabled(),
                timeToEmpty: timeToEmpty,
                timeToFullCharge: timeToFullCharge,
                powerSource: powerSource,
                health: health,
                cycleCount: cycleCount,
                temperature: nil
            )
        }

        private func isLowPowerModeEnabled() -> Bool {
            // Check if Low Power Mode is enabled on macOS
            if let mode = UserDefaults.standard.object(forKey: "LowPowerModeEnabled") as? Bool {
                return mode
            }

            // Try to read from system preferences
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            task.arguments = ["-g"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    return output.contains("lowpowermode") && output.contains("1")
                }
            } catch {
                logger.error("Failed to check low power mode: \(error)")
            }

            return false
        }

        // MARK: - Queries

        /// Check if battery level is critical (< 10%)
        public var isCriticalBattery: Bool {
            currentPowerState.hasBattery && currentPowerState.batteryLevel < 10
        }

        /// Check if battery level is low (< 20%)
        public var isLowBattery: Bool {
            currentPowerState.hasBattery && currentPowerState.batteryLevel < 20
        }

        /// Get formatted time remaining
        public var timeRemainingString: String? {
            if currentPowerState.chargingState == .charging {
                if let minutes = currentPowerState.timeToFullCharge, minutes > 0 {
                    let hours = minutes / 60
                    let mins = minutes % 60
                    return hours > 0 ? "\(hours)h \(mins)m until full" : "\(mins)m until full"
                }
            } else if currentPowerState.chargingState == .discharging {
                if let minutes = currentPowerState.timeToEmpty, minutes > 0 {
                    let hours = minutes / 60
                    let mins = minutes % 60
                    return hours > 0 ? "\(hours)h \(mins)m remaining" : "\(mins)m remaining"
                }
            }
            return nil
        }
    }

    // MARK: - Models

    public struct PowerState: Equatable, Sendable {
        public let hasBattery: Bool
        public let batteryLevel: Int
        public let chargingState: ChargingState
        public let isLowPowerMode: Bool
        public let timeToEmpty: Int?
        public let timeToFullCharge: Int?
        public let powerSource: MacPowerSource
        public let health: String?
        public let cycleCount: Int?
        public let temperature: Double?

        init(
            hasBattery: Bool = false,
            batteryLevel: Int = 100,
            chargingState: ChargingState = .pluggedIn,
            isLowPowerMode: Bool = false,
            timeToEmpty: Int? = nil,
            timeToFullCharge: Int? = nil,
            powerSource: MacPowerSource = .ac,
            health: String? = nil,
            cycleCount: Int? = nil,
            temperature: Double? = nil
        ) {
            self.hasBattery = hasBattery
            self.batteryLevel = batteryLevel
            self.chargingState = chargingState
            self.isLowPowerMode = isLowPowerMode
            self.timeToEmpty = timeToEmpty
            self.timeToFullCharge = timeToFullCharge
            self.powerSource = powerSource
            self.health = health
            self.cycleCount = cycleCount
            self.temperature = temperature
        }
    }

    public enum ChargingState: String, Sendable {
        case charging = "Charging"
        case discharging = "Discharging"
        case pluggedIn = "Plugged In"
    }

    public enum MacPowerSource: String, Sendable {
        case ac = "AC Power"
        case battery = "Battery"
        case ups = "UPS"
    }
#endif
