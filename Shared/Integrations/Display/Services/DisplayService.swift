import Foundation

#if os(macOS)
    import AppKit
    import CoreGraphics
    import IOKit

    // MARK: - Display Service

    /// Service for managing displays
    public actor DisplayService: DisplayServiceProtocol {
        // MARK: - Properties

        private var displays: [CGDirectDisplayID: Display] = [:]
        private var schedules: [CGDirectDisplayID: DisplaySchedule] = [:]
        private let ddcService: DDCService

        // MARK: - Initialization

        public init(ddcService: DDCService = DDCService()) {
            self.ddcService = ddcService
        }

        // MARK: - Display Management

        /// Fetches all active displays and populates the internal display cache.
        public func fetchDisplays() async throws -> [Display] {
            var displayList: [Display] = []

            // Get all active displays
            var displayCount: UInt32 = 0
            var activeDisplays: [CGDirectDisplayID] = Array(repeating: 0, count: 16)

            let error = CGGetActiveDisplayList(16, &activeDisplays, &displayCount)
            guard error == .success else {
                throw DisplayError.noDisplaysFound
            }

            for i in 0 ..< Int(displayCount) {
                let displayID = activeDisplays[i]

                // Get display info
                let name = getDisplayName(displayID)
                let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
                let supportsDDC = await ddcService.supportsDDC(displayID: displayID)

                let display = Display(
                    displayID: displayID,
                    name: name,
                    isBuiltIn: isBuiltIn,
                    supportsHardwareControl: supportsDDC
                )

                displays[displayID] = display
                displayList.append(display)
            }

            return displayList
        }

        // MARK: - Profile Management

        /// Applies a display profile (brightness, contrast) to the specified display.
        public func applyProfile(_ profile: DisplayProfile, to displayID: CGDirectDisplayID) async throws {
            guard displays[displayID] != nil else {
                throw DisplayError.displayNotFound(displayID)
            }

            // Apply brightness
            try await setBrightness(profile.brightness, for: displayID)

            // Apply contrast
            try await setContrast(profile.contrast, for: displayID)

            // Update current profile
            displays[displayID]?.currentProfile = profile
        }

        /// Sets the brightness (0-100) for the specified display via DDC/CI or IOKit.
        public func setBrightness(_ value: Int, for displayID: CGDirectDisplayID) async throws {
            guard (0 ... 100).contains(value) else {
                throw DisplayError.invalidBrightnessValue
            }

            guard let display = displays[displayID] else {
                throw DisplayError.displayNotFound(displayID)
            }

            if display.isBuiltIn {
                // Use CoreDisplay for built-in displays
                try await setBuiltInBrightness(value, for: displayID)
            } else if display.supportsHardwareControl {
                // Use DDC/CI for external displays
                let ddcValue = UInt8((Double(value) / 100.0) * 255.0)
                try await ddcService.sendCommand(displayID: displayID, command: 0x10, value: ddcValue)
            } else {
                throw DisplayError.hardwareControlNotSupported
            }
        }

        /// Sets the contrast (0-100) for the specified display via DDC/CI. No-op for built-in displays.
        public func setContrast(_ value: Int, for displayID: CGDirectDisplayID) async throws {
            guard (0 ... 100).contains(value) else {
                throw DisplayError.invalidBrightnessValue
            }

            guard let display = displays[displayID] else {
                throw DisplayError.displayNotFound(displayID)
            }

            if display.supportsHardwareControl {
                let ddcValue = UInt8((Double(value) / 100.0) * 255.0)
                try await ddcService.sendCommand(displayID: displayID, command: 0x12, value: ddcValue)
            } else {
                // Built-in displays don't support contrast control
                if display.isBuiltIn {
                    return // Silently succeed
                }
                throw DisplayError.hardwareControlNotSupported
            }
        }

        /// Returns the current display profile for the specified display, or a default if none is set.
        public func getCurrentState(for displayID: CGDirectDisplayID) async throws -> DisplayProfile {
            guard let display = displays[displayID], let profile = display.currentProfile else {
                // Return default profile
                return DisplayProfile(name: "Current")
            }

            return profile
        }

        // MARK: - Scheduling

        /// Assigns a profile schedule to the specified display.
        public func setSchedule(_ schedule: DisplaySchedule, for displayID: CGDirectDisplayID) async throws {
            schedules[displayID] = schedule
        }

        /// Evaluates all active schedules and applies matching profiles based on the current time.
        public func executeScheduledProfiles() async throws {
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: now)
            let currentTime = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)

            for (displayID, schedule) in schedules where schedule.isEnabled {
                // Find matching rule
                if let rule = schedule.rules.first(where: { $0.time == currentTime }) {
                    try await applyProfile(rule.profile, to: displayID)
                }
            }
        }

        // MARK: - Private Helpers

        private func getDisplayName(_ displayID: CGDirectDisplayID) -> String {
            // Try to get display name from IOKit
            // Simplified - production would use IODisplayCreateInfoDictionary
            "Display \(displayID)"
        }

        private func setBuiltInBrightness(_ value: Int, for displayID: CGDirectDisplayID) async throws {
            let brightness = Float(value) / 100.0

            // Use IOKit to set built-in display brightness via AppleBacklightDisplay
            let service = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleBacklightDisplay")
            )

            guard service != IO_OBJECT_NULL else {
                // Fallback: try setting via CoreGraphics gamma tables
                // This adjusts perceived brightness via software
                let gamma = max(0.1, brightness)
                var redTable = [CGGammaValue](repeating: gamma, count: 256)
                var greenTable = [CGGammaValue](repeating: gamma, count: 256)
                var blueTable = [CGGammaValue](repeating: gamma, count: 256)
                for i in 0 ..< 256 {
                    let normalized = CGGammaValue(i) / 255.0
                    redTable[i] = normalized * gamma
                    greenTable[i] = normalized * gamma
                    blueTable[i] = normalized * gamma
                }
                CGSetDisplayTransferByTable(displayID, 256, &redTable, &greenTable, &blueTable)
                return
            }
            defer { IOObjectRelease(service) }

            // Set brightness via IOKit property
            let brightnessDict: NSDictionary = [
                "brightness": Int(brightness * 1024)
            ]
            IORegistryEntrySetCFProperties(service, brightnessDict)
        }
    }

    // MARK: - DDC Service

    /// Service for DDC/CI communication via IOKit IOAVService
    ///
    /// Uses IOAVService (the modern macOS approach for I2C communication with external displays).
    /// This replaces the deprecated CGDisplayIOServicePort and private IOI2CRequest API.
    public actor DDCService: DDCProtocol {
        public init() {}

        /// Sends a DDC/CI SET VCP FEATURE command to an external display via IOAVService I2C.
        public func sendCommand(displayID: CGDirectDisplayID, command: UInt8, value: UInt8) async throws {
            guard let avService = findIOAVService(for: displayID) else {
                throw DDCError.displayNotFound
            }
            defer { IOObjectRelease(avService) }

            // Build DDC/CI SET VCP FEATURE message
            // Format: [length | 0x03 | VCP code | high byte | low byte | checksum]
            var data: [UInt8] = [
                0x84,     // length (4 bytes follow)
                0x03,     // Set VCP Feature opcode
                command,  // VCP code (e.g. 0x10 = brightness, 0x12 = contrast)
                0x00,     // high byte
                value     // low byte
            ]
            // Checksum: XOR of source address (0x51) + all data bytes
            var checksum: UInt8 = 0x6E ^ 0x51
            for byte in data { checksum ^= byte }
            data.append(checksum)

            // Write via IOAVService using IOConnectCallMethod
            var connect: io_connect_t = IO_OBJECT_NULL
            let openResult = IOServiceOpen(avService, mach_task_self_, 0, &connect)
            guard openResult == kIOReturnSuccess else { throw DDCError.connectionFailed }
            defer { IOServiceClose(connect) }

            let writeResult = data.withUnsafeBufferPointer { buffer in
                IOConnectCallMethod(
                    connect,
                    2,      // I2C write selector
                    nil, 0, // no scalar inputs
                    buffer.baseAddress, data.count,
                    nil, nil, // no scalar outputs
                    nil, nil  // no struct output
                )
            }

            guard writeResult == kIOReturnSuccess else { throw DDCError.commandFailed }
        }

        /// Reads a VCP value from a display. Currently throws ``DDCError/readNotSupported`` due to macOS entitlement restrictions.
        public func readValue(displayID _: CGDirectDisplayID, command _: UInt8) async throws -> UInt8 {
            // DDC/CI read requires a write-then-read I2C transaction
            // On modern macOS, IOAVService read is limited and may not support
            // arbitrary VCP reads. Return a reasonable default for display info.
            //
            // Real DDC read would require:
            // 1. Send GET VCP request (opcode 0x01) to address 0x6E
            // 2. Read reply from address 0x6F
            // 3. Parse reply bytes [length | 0x02 | result | VCP code | type | max_h | max_l | cur_h | cur_l]
            //
            // This is a protocol-level limitation documented by Apple —
            // full I2C bidirectional communication requires entitlements
            // that are only available to system-level services.
            throw DDCError.readNotSupported
        }

        /// Returns whether the specified display supports DDC/CI (always `false` for built-in displays).
        public func supportsDDC(displayID: CGDirectDisplayID) async -> Bool {
            if CGDisplayIsBuiltin(displayID) != 0 {
                return false
            }
            return findIOAVService(for: displayID) != nil
        }

        /// Find the IOAVService matching a CGDirectDisplayID
        private func findIOAVService(for displayID: CGDirectDisplayID) -> io_service_t? {
            // Search IOKit for IOAVService entries (used by external displays)
            let matching = IOServiceMatching("IOAVService")
            var iterator: io_iterator_t = 0

            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
                return nil
            }
            defer { IOObjectRelease(iterator) }

            var service = IOIteratorNext(iterator)
            while service != IO_OBJECT_NULL {
                // Match by display vendor/product ID from the registry
                if let info = IORegistryEntryCreateCFProperty(
                    service,
                    "DisplayAttributes" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? NSDictionary {
                    // Check if this service matches our display
                    if let productAttrs = info["ProductAttributes"] as? NSDictionary {
                        let vendorID = productAttrs["ManufacturerID"] as? Int ?? 0
                        let productID = productAttrs["ProductID"] as? Int ?? 0

                        // Compare with CGDisplay properties
                        let cgVendor = Int(CGDisplayVendorNumber(displayID))
                        let cgProduct = Int(CGDisplayModelNumber(displayID))

                        if vendorID == cgVendor && productID == cgProduct {
                            return service
                        }
                    }
                }

                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            return nil
        }
    }

    /// DDC communication errors
    enum DDCError: LocalizedError {
        case displayNotFound
        case connectionFailed
        case commandFailed
        case readNotSupported

        var errorDescription: String? {
            switch self {
            case .displayNotFound: "Display not found in IOKit registry"
            case .connectionFailed: "Failed to open I2C connection to display"
            case .commandFailed: "DDC/CI command failed"
            case .readNotSupported: "DDC/CI read requires system-level entitlements on modern macOS"
            }
        }
    }

    // MARK: - Ambient Light Adapter

    /// Adapter for ambient light sensor via IOKit AppleLMUController
    public actor AmbientLightAdapter: AmbientLightAdapterProtocol {
        private var isMonitoring = false
        private var currentCallback: (@Sendable (Int) -> Void)?
        private var monitoringTask: Task<Void, Never>?
        private var lmuService: io_connect_t = IO_OBJECT_NULL

        public init() {}

        /// Returns the current ambient light level (0-100) from the AppleLMUController sensor, or an estimate from display brightness.
        public func getCurrentLightLevel() async throws -> Int {
            let service = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleLMUController")
            )

            guard service != IO_OBJECT_NULL else {
                // No ambient light sensor available (e.g. Mac Studio, external monitor setups)
                // Return estimated level based on display brightness
                return estimateLightFromBrightness()
            }
            defer { IOObjectRelease(service) }

            var connect: io_connect_t = IO_OBJECT_NULL
            let result = IOServiceOpen(service, mach_task_self_, 0, &connect)
            guard result == kIOReturnSuccess, connect != IO_OBJECT_NULL else {
                return estimateLightFromBrightness()
            }
            defer { IOServiceClose(connect) }

            // Read ambient light value via IOKit
            var outputCount: UInt32 = 2
            var values = [UInt64](repeating: 0, count: 2)
            let readResult = IOConnectCallMethod(
                connect,
                0, // selector for ALSRead
                nil, 0,
                nil, 0,
                &values, &outputCount,
                nil, nil
            )

            guard readResult == kIOReturnSuccess else {
                return estimateLightFromBrightness()
            }

            // Values[0] and values[1] are left and right sensor readings
            // Combine and normalize to 0-100 range
            let combined = (values[0] + values[1]) / 2
            return min(100, max(0, Int(combined / 10))) // Raw values can be 0-1000+
        }

        /// Starts polling the ambient light sensor every 5 seconds, invoking the callback with the current level.
        public func startMonitoring(callback: @Sendable @escaping (Int) -> Void) async {
            currentCallback = callback
            isMonitoring = true

            // Poll ambient light sensor every 5 seconds
            monitoringTask = Task.detached { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5)) // 5 seconds
                    guard let self, await self.isMonitoring else { break }
                    if let level = try? await self.getCurrentLightLevel(),
                       let cb = await self.currentCallback {
                        cb(level)
                    }
                }
            }
        }

        /// Stops polling the ambient light sensor and cancels the monitoring task.
        public func stopMonitoring() async {
            isMonitoring = false
            currentCallback = nil
            monitoringTask?.cancel()
            monitoringTask = nil
        }

        /// Estimate ambient light from current display brightness setting
        private func estimateLightFromBrightness() -> Int {
            // Use display brightness as a proxy — users tend to set brightness
            // to match ambient conditions
            let service = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleBacklightDisplay")
            )
            guard service != IO_OBJECT_NULL else { return 50 }
            defer { IOObjectRelease(service) }

            var properties: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
            guard result == kIOReturnSuccess,
                  let props = properties?.takeRetainedValue() as? [String: Any],
                  let brightness = props["brightness"] as? Int else {
                return 50
            }

            return min(100, max(0, brightness * 100 / 1024))
        }
    }

#endif
