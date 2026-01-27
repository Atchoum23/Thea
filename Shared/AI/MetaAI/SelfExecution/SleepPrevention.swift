// SleepPrevention.swift
import Foundation
#if canImport(IOKit)
    import IOKit
    import IOKit.pwr_mgt
#endif
import OSLog

/// Prevents system and display sleep during phase execution.
/// Uses IOPMAssertion to keep the system awake even when display turns off.
public actor SleepPrevention {
    public static let shared = SleepPrevention()

    private let logger = Logger(subsystem: "com.thea.app", category: "SleepPrevention")

    #if canImport(IOKit)
        private var assertionID: IOPMAssertionID = 0
    #endif
    private var isPreventingSleep = false

    // MARK: - Public API

    /// Start preventing sleep. Call when phase execution begins.
    public func startPreventingSleep(reason: String) async -> Bool {
        #if canImport(IOKit)
            guard !isPreventingSleep else {
                logger.info("Already preventing sleep")
                return true
            }

            let reasonCF = reason as CFString

            // Create assertion to prevent system sleep
            // kIOPMAssertionTypePreventUserIdleSystemSleep - Prevents system sleep
            // This allows display to turn off but keeps CPU running
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reasonCF,
                &assertionID
            )

            if result == kIOReturnSuccess {
                isPreventingSleep = true
                logger.info("✅ Sleep prevention started: \(reason)")
                return true
            } else {
                logger.error("❌ Failed to create sleep assertion: \(result)")
                return false
            }
        #else
            logger.warning("Sleep prevention not available on this platform")
            return false
        #endif
    }

    /// Stop preventing sleep. Call when phase execution completes.
    public func stopPreventingSleep() async {
        #if canImport(IOKit)
            guard isPreventingSleep else {
                logger.info("Not currently preventing sleep")
                return
            }

            let result = IOPMAssertionRelease(assertionID)

            if result == kIOReturnSuccess {
                isPreventingSleep = false
                assertionID = 0
                logger.info("✅ Sleep prevention stopped")
            } else {
                logger.error("❌ Failed to release sleep assertion: \(result)")
            }
        #else
            logger.info("Sleep prevention not available on this platform")
        #endif
    }

    /// Check if currently preventing sleep
    public func isPreventing() -> Bool {
        isPreventingSleep
    }

    /// Execute a block while preventing sleep
    public func withSleepPrevention<T: Sendable>(
        reason: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let started = await startPreventingSleep(reason: reason)
        if !started {
            logger.warning("Could not prevent sleep, continuing anyway")
        }

        defer {
            Task {
                await stopPreventingSleep()
            }
        }

        return try await operation()
    }
}
