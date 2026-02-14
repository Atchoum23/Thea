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

        public func getCurrentState(for displayID: CGDirectDisplayID) async throws -> DisplayProfile {
            guard let display = displays[displayID], let profile = display.currentProfile else {
                // Return default profile
                return DisplayProfile(name: "Current")
            }

            return profile
        }

        // MARK: - Scheduling

        public func setSchedule(_ schedule: DisplaySchedule, for displayID: CGDirectDisplayID) async throws {
            schedules[displayID] = schedule
        }

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

    /// Service for DDC/CI communication via IOKit I2C
    public actor DDCService: DDCProtocol {
        /// Cache of I2C service ports per display
        private var servicePortCache: [CGDirectDisplayID: io_service_t] = [:]

        public init() {}

        public func sendCommand(displayID: CGDirectDisplayID, command: UInt8, value: UInt8) async throws {
            // DDC/CI set VCP feature: address 0x6E (display), length, opcode 0x03, command, value
            guard let service = getIOFramebufferService(for: displayID) else {
                throw DDCError.displayNotFound
            }

            var connect: io_connect_t = IO_OBJECT_NULL
            let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOI2COverAUXTag), &connect)
            guard result == kIOReturnSuccess, connect != IO_OBJECT_NULL else {
                throw DDCError.connectionFailed
            }
            defer { IOServiceClose(connect) }

            // Build DDC/CI SET VCP FEATURE message
            // Destination: 0x6E (DDC address), Source: 0x51 (host)
            // Length: 0x84 (4 bytes following), Command: 0x03 (Set VCP), VCP code, then high/low value bytes
            var sendData: [UInt8] = [
                0x6E,               // DDC address
                0x51,               // source address
                0x84,               // length (4 bytes follow)
                0x03,               // Set VCP Feature
                command,            // VCP opcode (e.g. 0x10 = brightness)
                value >> 4,         // high nibble
                value               // low byte
            ]
            // Compute checksum: XOR of all bytes starting from address
            let checksum = sendData.reduce(UInt8(0)) { $0 ^ $1 }
            sendData.append(checksum)

            // Send via IOKit I2C interface
            var request = IOI2CRequest()
            request.sendAddress = 0x6E
            request.sendTransactionType = UInt32(kIOI2CSimpleTransactionType)
            request.sendBuffer = vm_address_t(bitPattern: UnsafeRawPointer(sendData))
            request.sendBytes = UInt32(sendData.count)

            var size = IOByteCount(MemoryLayout<IOI2CRequest>.size)
            let sendResult = IOConnectCallStructMethod(
                connect,
                UInt32(0),
                &request,
                MemoryLayout<IOI2CRequest>.size,
                &request,
                &size
            )

            guard sendResult == kIOReturnSuccess else {
                throw DDCError.commandFailed
            }
        }

        public func readValue(displayID: CGDirectDisplayID, command: UInt8) async throws -> UInt8 {
            guard let service = getIOFramebufferService(for: displayID) else {
                throw DDCError.displayNotFound
            }

            var connect: io_connect_t = IO_OBJECT_NULL
            let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOI2COverAUXTag), &connect)
            guard result == kIOReturnSuccess, connect != IO_OBJECT_NULL else {
                throw DDCError.connectionFailed
            }
            defer { IOServiceClose(connect) }

            // Build DDC/CI GET VCP FEATURE request
            var sendData: [UInt8] = [0x6E, 0x51, 0x82, 0x01, command]
            let checksum = sendData.reduce(UInt8(0)) { $0 ^ $1 }
            sendData.append(checksum)

            var replyData = [UInt8](repeating: 0, count: 12)

            var request = IOI2CRequest()
            request.sendAddress = 0x6E
            request.sendTransactionType = UInt32(kIOI2CSimpleTransactionType)
            request.sendBuffer = vm_address_t(bitPattern: UnsafeRawPointer(sendData))
            request.sendBytes = UInt32(sendData.count)
            request.replyAddress = 0x6F
            request.replyTransactionType = UInt32(kIOI2CSimpleTransactionType)
            request.replyBuffer = vm_address_t(bitPattern: UnsafeMutableRawPointer(&replyData))
            request.replyBytes = UInt32(replyData.count)

            var size = IOByteCount(MemoryLayout<IOI2CRequest>.size)
            let readResult = IOConnectCallStructMethod(
                connect,
                UInt32(0),
                &request,
                MemoryLayout<IOI2CRequest>.size,
                &request,
                &size
            )

            guard readResult == kIOReturnSuccess, request.result == kIOReturnSuccess else {
                throw DDCError.readFailed
            }

            // Parse VCP reply: byte 8 = current value (low byte)
            return replyData.count > 8 ? replyData[8] : 0
        }

        public func supportsDDC(displayID: CGDirectDisplayID) async -> Bool {
            if CGDisplayIsBuiltin(displayID) != 0 {
                return false
            }
            return getIOFramebufferService(for: displayID) != nil
        }

        private func getIOFramebufferService(for displayID: CGDirectDisplayID) -> io_service_t? {
            if let cached = servicePortCache[displayID], cached != IO_OBJECT_NULL {
                return cached
            }

            let info = IODisplayCreateInfoDictionary(
                CGDisplayIOServicePort(displayID),
                IOOptionBits(kIODisplayOnlyPreferredName)
            )
            guard info != nil else { return nil }

            let service = CGDisplayIOServicePort(displayID)
            guard service != IO_OBJECT_NULL else { return nil }

            return service
        }
    }

    /// DDC communication errors
    enum DDCError: LocalizedError {
        case displayNotFound
        case connectionFailed
        case commandFailed
        case readFailed

        var errorDescription: String? {
            switch self {
            case .displayNotFound: "Display not found in IOKit registry"
            case .connectionFailed: "Failed to open I2C connection to display"
            case .commandFailed: "DDC/CI command failed"
            case .readFailed: "DDC/CI read failed"
            }
        }
    }

    private let kIOI2COverAUXTag = 0
    private let kIOI2CSimpleTransactionType = 1

    // MARK: - Ambient Light Adapter

    /// Adapter for ambient light sensor via IOKit AppleLMUController
    public actor AmbientLightAdapter: AmbientLightAdapterProtocol {
        private var isMonitoring = false
        private var currentCallback: (@Sendable (Int) -> Void)?
        private var monitoringTask: Task<Void, Never>?
        private var lmuService: io_connect_t = IO_OBJECT_NULL

        public init() {}

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

        public func startMonitoring(callback: @Sendable @escaping (Int) -> Void) async {
            currentCallback = callback
            isMonitoring = true

            // Poll ambient light sensor every 5 seconds
            monitoringTask = Task.detached { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    guard let self, await self.isMonitoring else { break }
                    if let level = try? await self.getCurrentLightLevel(),
                       let cb = await self.currentCallback {
                        cb(level)
                    }
                }
            }
        }

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

            if let props = IORegistryEntryCreateCFProperties(service, nil, kCFAllocatorDefault, 0) as? NSDictionary,
               let brightness = props["brightness"] as? Int {
                return min(100, max(0, brightness * 100 / 1024))
            }

            return 50
        }
    }

#endif
