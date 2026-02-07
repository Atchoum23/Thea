// BluetoothDeviceManager.swift
// Thea
//
// Monitors connected audio devices using AVAudioSession (iOS) and
// CoreAudio HAL (macOS). Categorizes devices and signals when Thea
// should switch to voice output (car stereo, headphones, earbuds).
// NOT using CoreBluetooth — that only discovers nearby BLE peripherals,
// not connected audio devices.

import Foundation
import os.log

#if canImport(AVFoundation)
    import AVFoundation
#endif

#if os(macOS)
    import CoreAudio
#endif

// MARK: - Audio Device Category

/// Category of a connected audio device, used to determine
/// whether Thea should automatically activate voice output.
public enum AudioDeviceCategory: String, Sendable, CaseIterable {
    case carAudio
    case headphones
    case earbuds
    case speaker
    case hearingAid
    case handsfree
    case builtIn
    case wiredHeadphones
    case other

    /// Human-readable name for display
    public var displayName: String {
        switch self {
        case .carAudio: return "Car Audio"
        case .headphones: return "Headphones"
        case .earbuds: return "Earbuds"
        case .speaker: return "Speaker"
        case .hearingAid: return "Hearing Aid"
        case .handsfree: return "Handsfree"
        case .builtIn: return "Built-in"
        case .wiredHeadphones: return "Wired Headphones"
        case .other: return "Other"
        }
    }
}

// MARK: - Audio Device Model

/// Represents a connected audio output device with categorization metadata.
public struct TheaAudioDevice: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let category: AudioDeviceCategory
    public let portType: String
    public let isBluetooth: Bool
    public let isOutput: Bool

    public init(
        id: String,
        name: String,
        category: AudioDeviceCategory,
        portType: String,
        isBluetooth: Bool,
        isOutput: Bool
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.portType = portType
        self.isBluetooth = isBluetooth
        self.isOutput = isOutput
    }
}

// MARK: - Bluetooth Device Manager

/// Monitors connected audio devices and determines whether Thea
/// should automatically switch to voice output mode.
///
/// - iOS: Uses `AVAudioSession.routeChangeNotification`
/// - macOS: Uses CoreAudio HAL property listeners
@MainActor
@Observable
public final class BluetoothDeviceManager {
    public static let shared = BluetoothDeviceManager()

    private let logger = Logger(subsystem: "ai.thea.app", category: "BluetoothDeviceManager")

    // MARK: - Published State

    /// All currently connected audio output devices
    public private(set) var connectedAudioDevices: [TheaAudioDevice] = []

    /// Category of the current primary output device
    public private(set) var activeOutputCategory: AudioDeviceCategory = .builtIn

    /// Whether voice output should be active based on connected devices
    public private(set) var shouldUseVoiceOutput: Bool = false

    // MARK: - Configuration

    /// Set of device categories that trigger automatic voice output
    public var voiceOutputCategories: Set<AudioDeviceCategory> = [
        .carAudio, .headphones, .earbuds, .handsfree
    ]

    /// Master toggle for automatic voice switching
    public var autoVoiceEnabled: Bool = true

    // MARK: - Callbacks

    /// Called when voice output state changes
    public var onVoiceOutputStateChanged: (@Sendable (Bool) -> Void)?

    /// Called when connected devices change
    public var onDevicesChanged: (@Sendable ([TheaAudioDevice]) -> Void)?

    // MARK: - Private

    #if os(macOS)
        private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
        private var defaultOutputListenerBlock: AudioObjectPropertyListenerBlock?
    #endif

    private init() {
        logger.info("BluetoothDeviceManager initializing")
        startMonitoring()
        scanCurrentDevices()
    }

    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #elseif os(macOS)
        // macOS listeners are cleaned up automatically
        #endif
    }

    // MARK: - Monitoring Lifecycle

    private func startMonitoring() {
        #if os(iOS)
            startIOSMonitoring()
        #elseif os(macOS)
            startMacOSMonitoring()
        #endif
    }

    /// Stop all monitoring (cleanup)
    public func stopMonitoring() {
        #if os(iOS)
        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)
        #elseif os(macOS)
        removeMacOSListeners()
        #endif
    }

    // MARK: - iOS Audio Route Monitoring

    #if os(iOS)
        private func startIOSMonitoring() {
            // Observe audio route changes (device connected/disconnected)
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                // Extract the sendable data before crossing actor boundary
                let userInfo = notification.userInfo
                Task { @MainActor in
                    self?.handleiOSRouteChange(userInfo: userInfo)
                }
            }

            logger.info("iOS audio route monitoring started")
        }

        private func handleiOSRouteChange(userInfo: [AnyHashable: Any]?) {
            guard let reasonValue = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
            else {
                scanCurrentDevices()
                return
            }

            switch reason {
            case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
                logger.info("iOS route changed: \(reason.rawValue)")
                scanCurrentDevices()
            default:
                break
            }
        }

        private func scaniOSAudioRoutes() {
            let session = AVAudioSession.sharedInstance()
            let route = session.currentRoute
            var devices: [TheaAudioDevice] = []

            for output in route.outputs {
                let category = categorizeIOSPort(output)
                let isBluetooth = isBluetoothPort(output.portType)

                let device = TheaAudioDevice(
                    id: output.uid,
                    name: output.portName,
                    category: category,
                    portType: output.portType.rawValue,
                    isBluetooth: isBluetooth,
                    isOutput: true
                )
                devices.append(device)
            }

            updateDevices(devices)
        }

        private func categorizeIOSPort(_ port: AVAudioSessionPortDescription) -> AudioDeviceCategory {
            // Check port type first
            switch port.portType {
            case .bluetoothA2DP, .bluetoothLE:
                return categorizeByName(port.portName, defaultCategory: .headphones)
            case .bluetoothHFP:
                return .handsfree
            case .carAudio:
                return .carAudio
            case .headphones:
                return .wiredHeadphones
            case .builtInSpeaker, .builtInReceiver:
                return .builtIn
            default:
                return categorizeByName(port.portName, defaultCategory: .other)
            }
        }

        private func isBluetoothPort(_ portType: AVAudioSession.Port) -> Bool {
            [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(portType)
        }
    #endif

    // MARK: - macOS CoreAudio Monitoring

    #if os(macOS)
        private func startMacOSMonitoring() {
            // Listen for device list changes
            var deviceListAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let deviceBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    self?.scanCurrentDevices()
                }
            }
            deviceListenerBlock = deviceBlock

            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &deviceListAddress,
                DispatchQueue.main,
                deviceBlock
            )

            // Listen for default output device changes
            var defaultOutputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let outputBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in
                    self?.scanCurrentDevices()
                }
            }
            defaultOutputListenerBlock = outputBlock

            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultOutputAddress,
                DispatchQueue.main,
                outputBlock
            )

            logger.info("macOS CoreAudio monitoring started")
        }

        private func removeMacOSListeners() {
            var deviceListAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            if let block = deviceListenerBlock {
                AudioObjectRemovePropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject),
                    &deviceListAddress,
                    DispatchQueue.main,
                    block
                )
            }

            var defaultOutputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            if let block = defaultOutputListenerBlock {
                AudioObjectRemovePropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject),
                    &defaultOutputAddress,
                    DispatchQueue.main,
                    block
                )
            }

            deviceListenerBlock = nil
            defaultOutputListenerBlock = nil
        }

        private func scanMacOSAudioDevices() {
            var devices: [TheaAudioDevice] = []

            // Get default output device
            var defaultDeviceID = AudioDeviceID()
            var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0, nil,
                &propertySize,
                &defaultDeviceID
            )

            guard status == noErr else {
                logger.warning("Failed to get default output device: \(status)")
                return
            }

            // Get device name
            let name = getMacOSDeviceName(defaultDeviceID)

            // Get transport type to determine if Bluetooth
            let transportType = getMacOSTransportType(defaultDeviceID)
            let isBluetooth = transportType == kAudioDeviceTransportTypeBluetooth
                || transportType == kAudioDeviceTransportTypeBluetoothLE

            // Categorize
            let category: AudioDeviceCategory
            if isBluetooth {
                category = categorizeByName(name, defaultCategory: .headphones)
            } else if transportType == kAudioDeviceTransportTypeBuiltIn {
                category = .builtIn
            } else {
                category = categorizeByName(name, defaultCategory: .other)
            }

            let device = TheaAudioDevice(
                id: "\(defaultDeviceID)",
                name: name,
                category: category,
                portType: transportTypeName(transportType),
                isBluetooth: isBluetooth,
                isOutput: true
            )
            devices.append(device)

            updateDevices(devices)
        }

        private func getMacOSDeviceName(_ deviceID: AudioDeviceID) -> String {
            var name: CFString = "" as CFString
            var propertySize = UInt32(MemoryLayout<CFString>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0, nil,
                &propertySize,
                &name
            )

            return name as String
        }

        private func getMacOSTransportType(_ deviceID: AudioDeviceID) -> UInt32 {
            var transportType: UInt32 = 0
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectGetPropertyData(
                deviceID,
                &address,
                0, nil,
                &propertySize,
                &transportType
            )

            return transportType
        }

        private func transportTypeName(_ type: UInt32) -> String {
            switch type {
            case kAudioDeviceTransportTypeBluetooth: return "Bluetooth"
            case kAudioDeviceTransportTypeBluetoothLE: return "BluetoothLE"
            case kAudioDeviceTransportTypeBuiltIn: return "BuiltIn"
            case kAudioDeviceTransportTypeUSB: return "USB"
            case kAudioDeviceTransportTypeVirtual: return "Virtual"
            case kAudioDeviceTransportTypeAggregate: return "Aggregate"
            default: return "Unknown"
            }
        }
    #endif

    // MARK: - Device Scanning (Platform Dispatch)

    private func scanCurrentDevices() {
        #if os(iOS)
            scaniOSAudioRoutes()
        #elseif os(macOS)
            scanMacOSAudioDevices()
        #else
            // watchOS/tvOS — no audio device monitoring
            updateDevices([])
        #endif
    }

    // MARK: - Device Categorization

    /// Categorize a device by name heuristics when port type is ambiguous
    private func categorizeByName(_ name: String, defaultCategory: AudioDeviceCategory) -> AudioDeviceCategory {
        let lower = name.lowercased()

        // Car audio
        if lower.contains("car") || lower.contains("vehicle")
            || lower.contains("carplay") || lower.contains("automotive")
        {
            return .carAudio
        }

        // Earbuds (check before headphones — AirPods are earbuds)
        if lower.contains("airpods") && !lower.contains("max") {
            return .earbuds
        }
        if lower.contains("earbud") || lower.contains("galaxy buds")
            || lower.contains("ear ") || lower.contains("pods")
        {
            return .earbuds
        }

        // Headphones
        if lower.contains("airpods max") || lower.contains("headphone")
            || lower.contains("over-ear") || lower.contains("beats solo")
            || lower.contains("beats studio") || lower.contains("wh-1000")
            || lower.contains("qc35") || lower.contains("qc45")
            || lower.contains("bose 700") || lower.contains("sennheiser")
        {
            return .headphones
        }

        // Speakers
        if lower.contains("homepod") || lower.contains("speaker")
            || lower.contains("jbl") || lower.contains("sonos")
            || lower.contains("bose soundlink") || lower.contains("echo")
            || lower.contains("marshall") || lower.contains("ue boom")
        {
            return .speaker
        }

        // Hearing aids
        if lower.contains("hearing") || lower.contains("mfi") {
            return .hearingAid
        }

        // Handsfree
        if lower.contains("handsfree") || lower.contains("hands-free")
            || lower.contains("speakerphone")
        {
            return .handsfree
        }

        return defaultCategory
    }

    // MARK: - State Update

    private func updateDevices(_ devices: [TheaAudioDevice]) {
        let previous = connectedAudioDevices
        connectedAudioDevices = devices

        // Determine primary output category
        activeOutputCategory = devices.first?.category ?? .builtIn

        // Check if voice output should be active
        let shouldVoice = autoVoiceEnabled && devices.contains { device in
            voiceOutputCategories.contains(device.category)
        }

        let voiceChanged = shouldVoice != shouldUseVoiceOutput
        shouldUseVoiceOutput = shouldVoice

        // Notify changes
        if voiceChanged {
            logger.info("Voice output state changed: \(shouldVoice)")
            onVoiceOutputStateChanged?(shouldVoice)
        }

        if previous != devices {
            let deviceNames = devices.map(\.name).joined(separator: ", ")
            logger.info("Audio devices updated: [\(deviceNames)]")
            onDevicesChanged?(devices)
        }
    }
}
