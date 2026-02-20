//
//  HomeKitMonitor.swift
//  Thea
//
//  HomeKit device activity monitoring for life tracking
//  Emits LifeEvents when smart home devices change state
//

import Combine
import Foundation
import os.log
#if canImport(HomeKit) && !os(macOS)
    import HomeKit
#endif

// MARK: - HomeKit Monitor

/// Monitors HomeKit smart home device activity
/// Emits LifeEvents for device state changes, scene executions, and automations
@MainActor
public class HomeKitMonitor: NSObject, ObservableObject {
    public static let shared = HomeKitMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "HomeKitMonitor")

    @Published public private(set) var isRunning = false
    @Published public private(set) var monitoredAccessories: Int = 0

    #if canImport(HomeKit) && !os(macOS)
        private var homeManager: HMHomeManager?
        private var accessoryDelegates: [UUID: AccessoryDelegate] = [:]
    #endif

    // Track last known states to detect changes
    private var lastKnownStates: [String: [String: Any]] = [:]

    override private init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Start monitoring HomeKit devices
    public func start() async {
        guard !isRunning else { return }

        #if canImport(HomeKit) && !os(macOS)
            homeManager = HMHomeManager()
            homeManager?.delegate = self

            isRunning = true
            logger.info("HomeKit monitor started")
        #else
            logger.warning("HomeKit not available on this platform")
        #endif
    }

    /// Stop monitoring
    public func stop() async {
        guard isRunning else { return }

        isRunning = false

        #if canImport(HomeKit) && !os(macOS)
            // Remove all accessory delegates
            accessoryDelegates.removeAll()
            homeManager = nil
        #endif

        lastKnownStates.removeAll()
        monitoredAccessories = 0

        logger.info("HomeKit monitor stopped")
    }

    // MARK: - Accessory Monitoring

    #if canImport(HomeKit) && !os(macOS)
        private func setupAccessoryMonitoring() {
            guard let manager = homeManager else { return }

            var totalAccessories = 0

            for home in manager.homes {
                for accessory in home.accessories {
                    setupAccessoryDelegate(accessory, homeName: home.name)
                    captureInitialState(accessory)
                    totalAccessories += 1
                }
            }

            monitoredAccessories = totalAccessories
            logger.info("Monitoring \(totalAccessories) HomeKit accessories")
        }

        private func setupAccessoryDelegate(_ accessory: HMAccessory, homeName: String) {
            let delegate = AccessoryDelegate(
                accessory: accessory,
                homeName: homeName
            )                { [weak self] accessoryId, characteristicType, oldValue, newValue in
                    self?.handleAccessoryStateChange(
                        accessoryId: accessoryId,
                        characteristicType: characteristicType,
                        oldValue: oldValue,
                        newValue: newValue
                    )
                }

            accessory.delegate = delegate
            accessoryDelegates[accessory.uniqueIdentifier] = delegate
        }

        private func captureInitialState(_ accessory: HMAccessory) {
            var state: [String: Any] = [:]

            for service in accessory.services {
                for characteristic in service.characteristics {
                    if let value = characteristic.value {
                        state[characteristic.characteristicType] = value
                    }
                }
            }

            lastKnownStates[accessory.uniqueIdentifier.uuidString] = state
        }
    #endif

    // MARK: - State Change Handling

    // periphery:ignore - Reserved: handleAccessoryStateChange(accessoryId:characteristicType:oldValue:newValue:) instance method — reserved for future feature activation
    private func handleAccessoryStateChange(
        // periphery:ignore - Reserved: handleAccessoryStateChange(accessoryId:characteristicType:oldValue:newValue:) instance method reserved for future feature activation
        accessoryId: String,
        characteristicType: String,
        oldValue: Any?,
        newValue: Any?
    ) {
        #if canImport(HomeKit) && !os(macOS)
            guard let manager = homeManager else { return }

            // Find the accessory
            var accessoryName = "Unknown"
            var roomName: String?
            var categoryType = "unknown"
            var homeName = "Home"

            for home in manager.homes {
                for accessory in home.accessories where accessory.uniqueIdentifier.uuidString == accessoryId {
                    accessoryName = accessory.name
                    roomName = accessory.room?.name
                    categoryType = accessoryCategoryName(accessory.category.categoryType)
                    homeName = home.name
                    break
                }
            }

            // Determine the type of change
            let (eventType, summary, significance) = classifyStateChange(
                characteristicType: characteristicType,
                accessoryName: accessoryName,
                oldValue: oldValue,
                newValue: newValue
            )

            var eventData: [String: String] = [
                "accessoryId": accessoryId,
                "accessoryName": accessoryName,
                "characteristicType": characteristicType,
                "categoryType": categoryType,
                "homeName": homeName
            ]

            if let room = roomName {
                eventData["room"] = room
            }

            if let old = oldValue {
                eventData["oldValue"] = String(describing: old)
            }

            if let new = newValue {
                eventData["newValue"] = String(describing: new)
            }

            let lifeEvent = LifeEvent(
                type: eventType,
                source: .homeKit,
                summary: summary,
                data: eventData,
                significance: significance
            )

            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
            logger.info("HomeKit: \(summary)")
        #endif
    }

    // periphery:ignore - Reserved: classifyStateChange(characteristicType:accessoryName:oldValue:newValue:) instance method reserved for future feature activation
    private func classifyStateChange(
        characteristicType: String,
        accessoryName: String,
        oldValue: Any?,
        newValue: Any?
    ) -> (LifeEventType, String, EventSignificance) {
        #if canImport(HomeKit) && !os(macOS)
            switch characteristicType {
            case HMCharacteristicTypePowerState:
                let isOn = (newValue as? Bool) == true
                return (
                    .homeKitPowerChange,
                    "\(accessoryName) turned \(isOn ? "on" : "off")",
                    .minor
                )

            case HMCharacteristicTypeBrightness:
                let brightness = newValue as? Int ?? 0
                return (
                    .homeKitBrightnessChange,
                    "\(accessoryName) brightness set to \(brightness)%",
                    .trivial
                )

            case HMCharacteristicTypeTargetTemperature:
                let temp = newValue as? Double ?? 0
                return (
                    .homeKitThermostatChange,
                    "\(accessoryName) temperature set to \(Int(temp))°",
                    .minor
                )

            case HMCharacteristicTypeCurrentTemperature:
                let temp = newValue as? Double ?? 0
                return (
                    .homeKitSensorReading,
                    "\(accessoryName) temperature: \(Int(temp))°",
                    .trivial
                )

            case HMCharacteristicTypeTargetLockMechanismState,
                 HMCharacteristicTypeCurrentLockMechanismState:
                let locked = (newValue as? Int) == 1
                return (
                    .homeKitLockChange,
                    "\(accessoryName) \(locked ? "locked" : "unlocked")",
                    .significant // Security-related
                )

            case HMCharacteristicTypeMotionDetected:
                let detected = (newValue as? Bool) == true
                return (
                    .homeKitMotionDetected,
                    "Motion \(detected ? "detected" : "cleared") at \(accessoryName)",
                    detected ? .moderate : .trivial
                )

            // Contact sensor state (uses string constant as HMCharacteristicTypeContactSensorState doesn't exist)
            case "8F":  // Contact State characteristic type UUID
                let open = (newValue as? Int) == 1
                return (
                    .homeKitContactSensorChange,
                    "\(accessoryName) \(open ? "opened" : "closed")",
                    .minor
                )

            case HMCharacteristicTypeCurrentDoorState,
                 HMCharacteristicTypeTargetDoorState:
                let open = (newValue as? Int) == 0
                return (
                    .homeKitDoorChange,
                    "\(accessoryName) \(open ? "opened" : "closed")",
                    .moderate
                )

            case HMCharacteristicTypeActive:
                let active = (newValue as? Int) == 1
                return (
                    .homeKitDeviceActive,
                    "\(accessoryName) \(active ? "activated" : "deactivated")",
                    .minor
                )

            default:
                return (
                    .homeKitStateChange,
                    "\(accessoryName) state changed",
                    .trivial
                )
            }
        #else
            return (.homeKitStateChange, "HomeKit state changed", .trivial)
        #endif
    }

    #if canImport(HomeKit) && !os(macOS)
        private func accessoryCategoryName(_ categoryType: String) -> String {
            switch categoryType {
            case HMAccessoryCategoryTypeLightbulb: return "light"
            case HMAccessoryCategoryTypeThermostat: return "thermostat"
            case HMAccessoryCategoryTypeDoorLock: return "lock"
            case HMAccessoryCategoryTypeOutlet: return "outlet"
            case HMAccessoryCategoryTypeFan: return "fan"
            case HMAccessoryCategoryTypeSensor: return "sensor"
            case HMAccessoryCategoryTypeVideoDoorbell: return "doorbell"
            case HMAccessoryCategoryTypeGarageDoorOpener: return "garage_door"
            case HMAccessoryCategoryTypeSecuritySystem: return "security"
            default: return "other"
            }
        }
    #endif

    // MARK: - Scene Execution Tracking

    #if canImport(HomeKit) && !os(macOS)
        /// Track when a scene is executed
        public func trackSceneExecution(sceneName: String, homeName: String) {
            let lifeEvent = LifeEvent(
                type: .homeKitSceneExecuted,
                source: .homeKit,
                summary: "Executed scene: \(sceneName)",
                data: [
                    "sceneName": sceneName,
                    "homeName": homeName
                ],
                significance: .moderate
            )

            LifeMonitoringCoordinator.shared.submitEvent(lifeEvent)
            logger.info("HomeKit scene executed: \(sceneName)")
        }
    #endif
}

// MARK: - HomeKit Manager Delegate

#if canImport(HomeKit) && !os(macOS)
    extension HomeKitMonitor: HMHomeManagerDelegate {
        nonisolated public func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
            Task { @MainActor in
                setupAccessoryMonitoring()
            }
        }

        nonisolated public func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) {
            Task { @MainActor in
                setupAccessoryMonitoring()
            }
        }
    }
#endif

// MARK: - Accessory Delegate

#if canImport(HomeKit) && !os(macOS)
    // @unchecked Sendable: NSObject subclass required for HMAccessoryDelegate; HomeKit delivers
    // callbacks on its own private queue; lastKnownValues only mutated from those callbacks
    private final class AccessoryDelegate: NSObject, HMAccessoryDelegate, @unchecked Sendable {
        let accessoryId: String
        // periphery:ignore - Reserved: Wave 10 service — wired in future integration phase
        let homeName: String
        let onStateChange: (String, String, Any?, Any?) -> Void

        private var lastKnownValues: [String: Any] = [:]

        init(
            accessory: HMAccessory,
            homeName: String,
            onStateChange: @escaping (String, String, Any?, Any?) -> Void
        ) {
            accessoryId = accessory.uniqueIdentifier.uuidString
            self.homeName = homeName
            self.onStateChange = onStateChange

            super.init()

            // Capture initial values
            for service in accessory.services {
                for characteristic in service.characteristics {
                    if let value = characteristic.value {
                        lastKnownValues[characteristic.characteristicType] = value
                    }
                }
            }
        }

        func accessory(
            _ accessory: HMAccessory,
            service: HMService,
            didUpdateValueFor characteristic: HMCharacteristic
        ) {
            let characteristicType = characteristic.characteristicType
            let oldValue = lastKnownValues[characteristicType]
            let newValue = characteristic.value

            // Update stored value
            if let value = newValue {
                lastKnownValues[characteristicType] = value
            }

            // Only emit if value actually changed
            guard !valuesEqual(oldValue, newValue) else { return }

            onStateChange(accessoryId, characteristicType, oldValue, newValue)
        }

        private func valuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
            switch (lhs, rhs) {
            case let (l as Bool, r as Bool): return l == r
            case let (l as Int, r as Int): return l == r
            case let (l as Double, r as Double): return abs(l - r) < 0.01
            case let (l as String, r as String): return l == r
            case (nil, nil): return true
            default: return false
            }
        }
    }
#endif

// MARK: - LifeEventType & DataSourceType
// Note: DataSourceType.homeKit and LifeEventType cases are defined in LifeMonitoringCoordinator.swift
// These extensions have been removed to avoid duplicate declarations
