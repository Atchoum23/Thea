import Foundation

#if os(macOS)
    import CoreGraphics

    // MARK: - Display Service Protocol

    /// Protocol for display management service
    public protocol DisplayServiceProtocol: Actor {
        /// Fetch all connected displays
        func fetchDisplays() async throws -> [Display]

        /// Apply profile to display
        func applyProfile(_ profile: DisplayProfile, to displayID: CGDirectDisplayID) async throws

        /// Set brightness (0-100)
        func setBrightness(_ value: Int, for displayID: CGDirectDisplayID) async throws

        /// Set contrast (0-100)
        func setContrast(_ value: Int, for displayID: CGDirectDisplayID) async throws

        /// Get current display state
        func getCurrentState(for displayID: CGDirectDisplayID) async throws -> DisplayProfile

        /// Schedule profile changes
        func setSchedule(_ schedule: DisplaySchedule, for displayID: CGDirectDisplayID) async throws
    }

    // MARK: - DDC Protocol

    /// Protocol for DDC/CI hardware communication
    public protocol DDCProtocol: Actor {
        /// Send DDC command to display
        func sendCommand(displayID: CGDirectDisplayID, command: UInt8, value: UInt8) async throws

        /// Read DDC value from display
        func readValue(displayID: CGDirectDisplayID, command: UInt8) async throws -> UInt8

        /// Check if display supports DDC/CI
        func supportsDDC(displayID: CGDirectDisplayID) async -> Bool
    }

    // MARK: - Ambient Light Adapter Protocol

    /// Protocol for ambient light detection
    public protocol AmbientLightAdapterProtocol: Actor {
        /// Get current ambient light level (0-100)
        func getCurrentLightLevel() async throws -> Int

        /// Start monitoring ambient light
        func startMonitoring(callback: @Sendable @escaping (Int) -> Void) async

        /// Stop monitoring
        func stopMonitoring() async
    }

#endif
