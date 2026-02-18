import Foundation
import OSLog
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif
#if canImport(IOKit)
    import IOKit.ps
#endif

// MARK: - Device State Context Provider

/// Provides device state context including battery, thermal, network, and memory
public actor DeviceStateContextProvider: ContextProvider {
    public let providerId = "deviceState"
    public let displayName = "Device State"

    private let logger = Logger(subsystem: "app.thea", category: "DeviceStateProvider")

    private var state: ContextProviderState = .idle
    private var continuation: AsyncStream<ContextUpdate>.Continuation?
    private var _updates: AsyncStream<ContextUpdate>?
    private var updateTask: Task<Void, Never>?

    public var isActive: Bool { state == .running }

    public var updates: AsyncStream<ContextUpdate> {
        if let existing = _updates {
            return existing
        }
        let (stream, cont) = AsyncStream<ContextUpdate>.makeStream()
        _updates = stream
        continuation = cont
        return stream
    }

    public init() {}

    public func start() async throws {
        guard state != .running else {
            throw ContextProviderError.alreadyRunning
        }

        state = .starting

        #if os(iOS)
            await MainActor.run {
                UIDevice.current.isBatteryMonitoringEnabled = true
            }
        #endif

        // Start periodic updates
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateDeviceState()
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break // Task cancelled — stop periodic updates
                }
            }
        }

        state = .running
        logger.info("Device state provider started")
    }

    public func stop() async {
        guard state == .running else { return }

        state = .stopping
        updateTask?.cancel()
        updateTask = nil

        #if os(iOS)
            await MainActor.run {
                UIDevice.current.isBatteryMonitoringEnabled = false
            }
        #endif

        continuation?.finish()
        continuation = nil
        _updates = nil

        state = .stopped
        logger.info("Device state provider stopped")
    }

    public func getCurrentContext() async -> ContextUpdate? {
        let context = await buildDeviceStateContext()
        return ContextUpdate(
            providerId: providerId,
            updateType: .deviceState(context),
            priority: .normal
        )
    }

    // MARK: - Private Methods

    private func updateDeviceState() async {
        let context = await buildDeviceStateContext()
        let update = ContextUpdate(
            providerId: providerId,
            updateType: .deviceState(context),
            priority: context.batteryLevel < 0.1 ? .high : .normal
        )
        continuation?.yield(update)
    }

    private func buildDeviceStateContext() async -> DeviceStateContext {
        #if os(iOS)
            return await buildIOSContext()
        #elseif os(macOS)
            return buildMacOSContext()
        #elseif os(watchOS)
            return buildWatchOSContext()
        #else
            return DeviceStateContext()
        #endif
    }

    #if os(iOS)
        private func buildIOSContext() async -> DeviceStateContext {
            // Get UI-dependent values on MainActor
            let (batteryLevel, batteryState, orientation, screenBrightness) = await MainActor.run {
                let device = UIDevice.current

                let batteryState: DeviceStateContext.BatteryState = {
                    switch device.batteryState {
                    case .unknown: return .unknown
                    case .unplugged: return .unplugged
                    case .charging: return .charging
                    case .full: return .full
                    @unknown default: return .unknown
                    }
                }()

                let orientation: DeviceStateContext.DeviceOrientation = switch device.orientation {
                case .portrait: .portrait
                case .portraitUpsideDown: .portraitUpsideDown
                case .landscapeLeft: .landscapeLeft
                case .landscapeRight: .landscapeRight
                case .faceUp: .faceUp
                case .faceDown: .faceDown
                default: .unknown
                }

                // Get brightness from the first connected scene's screen
                let brightness: Float = {
                    guard let windowScene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first
                    else {
                        return 0.5 // Default brightness if no scene available
                    }
                    return Float(windowScene.screen.brightness)
                }()
                return (device.batteryLevel, batteryState, orientation, brightness)
            }

            let thermalState: DeviceStateContext.ThermalState = {
                switch ProcessInfo.processInfo.thermalState {
                case .nominal: return .nominal
                case .fair: return .fair
                case .serious: return .serious
                case .critical: return .critical
                @unknown default: return .nominal
                }
            }()

            // Get non-UI dependent values
            let networkType = getNetworkType()
            let wifiConnected = isConnectedToWiFi()
            let cellularConnected = isConnectedToCellular()
            let wifiSSID = getCurrentWiFiSSID()
            let storageAvailable = getAvailableStorage()
            let memoryPressure = getMemoryPressure()

            return DeviceStateContext(
                batteryLevel: batteryLevel,
                batteryState: batteryState,
                isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                thermalState: thermalState,
                networkType: networkType,
                isWiFiConnected: wifiConnected,
                isCellularConnected: cellularConnected,
                wifiSSID: wifiSSID,
                storageAvailableGB: storageAvailable,
                memoryPressure: memoryPressure,
                screenBrightness: screenBrightness,
                volumeLevel: nil, // Requires AVAudioSession
                isHeadphonesConnected: false, // Would require AVAudioSession
                orientation: orientation
            )
        }
    #endif

    #if os(macOS)
        private func buildMacOSContext() -> DeviceStateContext {
            let (batteryLevel, batteryState) = getBatteryInfo()

            let thermalState: DeviceStateContext.ThermalState = {
                switch ProcessInfo.processInfo.thermalState {
                case .nominal: return .nominal
                case .fair: return .fair
                case .serious: return .serious
                case .critical: return .critical
                @unknown default: return .nominal
                }
            }()

            return DeviceStateContext(
                batteryLevel: batteryLevel,
                batteryState: batteryState,
                isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                thermalState: thermalState,
                networkType: getNetworkType(),
                isWiFiConnected: isConnectedToWiFi(),
                isCellularConnected: false,
                wifiSSID: getCurrentWiFiSSID(),
                storageAvailableGB: getAvailableStorage(),
                memoryPressure: getMemoryPressure(),
                screenBrightness: nil,
                volumeLevel: nil,
                isHeadphonesConnected: false,
                orientation: .unknown
            )
        }

        private func getBatteryInfo() -> (Float, DeviceStateContext.BatteryState) {
            guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
                  let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
                  let source = sources.first,
                  let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            else {
                return (1.0, .unknown)
            }

            let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int ?? 100
            let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            let isPluggedIn = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

            let level = Float(currentCapacity) / Float(maxCapacity)
            let state: DeviceStateContext.BatteryState = {
                if level >= 0.99, isPluggedIn { return .full }
                if isCharging { return .charging }
                if isPluggedIn { return .charging }
                return .unplugged
            }()

            return (level, state)
        }
    #endif

    #if os(watchOS)
        private func buildWatchOSContext() -> DeviceStateContext {
            let thermalState: DeviceStateContext.ThermalState = {
                switch ProcessInfo.processInfo.thermalState {
                case .nominal: return .nominal
                case .fair: return .fair
                case .serious: return .serious
                case .critical: return .critical
                @unknown default: return .nominal
                }
            }()

            return DeviceStateContext(
                batteryLevel: 1.0, // WKInterfaceDevice doesn't expose battery
                batteryState: .unknown,
                isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                thermalState: thermalState,
                networkType: .unknown,
                isWiFiConnected: false,
                isCellularConnected: false,
                wifiSSID: nil,
                storageAvailableGB: nil,
                memoryPressure: .normal,
                screenBrightness: nil,
                volumeLevel: nil,
                isHeadphonesConnected: false,
                orientation: .unknown
            )
        }
    #endif

    // MARK: - Helpers (nonisolated for use from MainActor)

    nonisolated private func getNetworkType() -> DeviceStateContext.NetworkType {
        // Simplified - full implementation would use NWPathMonitor
        if isConnectedToWiFi() { return .wifi }
        #if os(iOS)
            if isConnectedToCellular() { return .cellular }
        #endif
        return .unknown
    }

    nonisolated private func isConnectedToWiFi() -> Bool {
        // Would use NWPathMonitor for accurate detection
        true
    }

    #if os(iOS)
        nonisolated private func isConnectedToCellular() -> Bool {
            // Would use NWPathMonitor
            false
        }
    #endif

    nonisolated private func getCurrentWiFiSSID() -> String? {
        // Requires NEHotspotNetwork on iOS, CoreWLAN on macOS
        nil
    }

    nonisolated private func getAvailableStorage() -> Double? {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return Double(capacity) / 1_000_000_000 // Convert to GB
            }
        } catch {
            // Can't use logger here as it's nonisolated
        }
        return nil
    }

    nonisolated private func getMemoryPressure() -> DeviceStateContext.MemoryPressure {
        // Simplified - would use dispatch_source for accurate monitoring
        let info = ProcessInfo.processInfo
        let physicalMemory = info.physicalMemory
        // This is a rough estimate
        if physicalMemory > 0 {
            return .normal
        }
        return .normal
    }
}
