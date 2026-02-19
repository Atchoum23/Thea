//
//  AssertionManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import IOKit.pwr_mgt
import OSLog

// periphery:ignore - Reserved: logger global var reserved for future feature activation
private let logger = Logger(subsystem: "ai.thea.app", category: "AssertionManager")
#endif

// MARK: - Assertion Manager

/// Manages power assertions to prevent system sleep when needed
public actor AssertionManager {
    public static let shared = AssertionManager()

    // MARK: - State

    #if os(macOS)
        private var assertions: [AssertionType: IOPMAssertionID] = [:]
    #endif

    private var activeAssertions: Set<AssertionType> = []
    private var assertionReasons: [AssertionType: String] = [:]

    // MARK: - Configuration

    /// Maximum time (in seconds) an assertion can be held
    private let maxAssertionDuration: TimeInterval = 3600 // 1 hour

    /// Auto-release timers
    private var releaseTimers: [AssertionType: Task<Void, Never>] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Assertion Management

    /// Create an assertion to prevent sleep
    public func createAssertion(
        type: AssertionType,
        reason: String,
        duration: TimeInterval? = nil
    ) async throws {
        // Check if already active
        guard !activeAssertions.contains(type) else {
            // Update reason
            assertionReasons[type] = reason
            return
        }

        #if os(macOS)
            try createMacOSAssertion(type: type, reason: reason)
        #endif

        activeAssertions.insert(type)
        assertionReasons[type] = reason

        // Schedule auto-release if duration specified
        let effectiveDuration = min(duration ?? maxAssertionDuration, maxAssertionDuration)
        scheduleAutoRelease(type: type, after: effectiveDuration)
    }

    /// Release an assertion
    public func releaseAssertion(type: AssertionType) async {
        guard activeAssertions.contains(type) else { return }

        #if os(macOS)
            releaseMacOSAssertion(type: type)
        #endif

        activeAssertions.remove(type)
        assertionReasons.removeValue(forKey: type)

        // Cancel auto-release timer
        releaseTimers[type]?.cancel()
        releaseTimers.removeValue(forKey: type)
    }

    /// Release all assertions
    public func releaseAllAssertions() async {
        for type in activeAssertions {
            await releaseAssertion(type: type)
        }
    }

    // MARK: - macOS Implementation

    #if os(macOS)
        private func createMacOSAssertion(type: AssertionType, reason: String) throws {
            var assertionID: IOPMAssertionID = 0

            let result = IOPMAssertionCreateWithName(
                type.ioPMAssertionType as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &assertionID
            )

            guard result == kIOReturnSuccess else {
                throw AssertionError.creationFailed(code: result)
            }

            assertions[type] = assertionID
        }

        private func releaseMacOSAssertion(type: AssertionType) {
            guard let assertionID = assertions[type] else { return }

            IOPMAssertionRelease(assertionID)
            assertions.removeValue(forKey: type)
        }
    #endif

    // MARK: - Auto-Release

    private func scheduleAutoRelease(type: AssertionType, after duration: TimeInterval) {
        // Cancel existing timer
        releaseTimers[type]?.cancel()

        // Create new timer
        releaseTimers[type] = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            await releaseAssertion(type: type)
        }
    }

    // MARK: - Query

    /// Check if an assertion is active
    public func isAssertionActive(_ type: AssertionType) -> Bool {
        activeAssertions.contains(type)
    }

    /// Get all active assertions
    public func getActiveAssertions() -> [AssertionInfo] {
        activeAssertions.map { type in
            AssertionInfo(
                type: type,
                reason: assertionReasons[type] ?? "Unknown",
                isActive: true
            )
        }
    }

    /// Check if any assertion is preventing sleep
    public var isPreventingSleep: Bool {
        activeAssertions.contains(.preventUserIdleSystemSleep) ||
            activeAssertions.contains(.preventSystemSleep)
    }

    /// Check if any assertion is preventing display sleep
    public var isPreventingDisplaySleep: Bool {
        activeAssertions.contains(.preventUserIdleDisplaySleep) ||
            activeAssertions.contains(.preventDisplaySleep)
    }
}

// MARK: - Assertion Type

public enum AssertionType: String, Codable, Sendable, CaseIterable {
    case preventUserIdleSystemSleep
    case preventUserIdleDisplaySleep
    case preventSystemSleep
    case preventDisplaySleep
    case backgroundTask
    case externalMedia

    public var displayName: String {
        switch self {
        case .preventUserIdleSystemSleep:
            "Prevent Idle Sleep"
        case .preventUserIdleDisplaySleep:
            "Prevent Display Sleep"
        case .preventSystemSleep:
            "Prevent System Sleep"
        case .preventDisplaySleep:
            "Keep Display On"
        case .backgroundTask:
            "Background Task"
        case .externalMedia:
            "External Media"
        }
    }

    public var description: String {
        switch self {
        case .preventUserIdleSystemSleep:
            "Prevents the system from sleeping due to user inactivity"
        case .preventUserIdleDisplaySleep:
            "Prevents the display from sleeping due to user inactivity"
        case .preventSystemSleep:
            "Prevents any system sleep"
        case .preventDisplaySleep:
            "Keeps the display on regardless of activity"
        case .backgroundTask:
            "Allows background processing to continue"
        case .externalMedia:
            "Prevents sleep while accessing external media"
        }
    }

    public var icon: String {
        switch self {
        case .preventUserIdleSystemSleep:
            "moon.zzz"
        case .preventUserIdleDisplaySleep:
            "display"
        case .preventSystemSleep:
            "powersleep"
        case .preventDisplaySleep:
            "sun.max"
        case .backgroundTask:
            "arrow.triangle.2.circlepath"
        case .externalMedia:
            "externaldrive"
        }
    }

    #if os(macOS)
        var ioPMAssertionType: String {
            switch self {
            case .preventUserIdleSystemSleep:
                kIOPMAssertionTypePreventUserIdleSystemSleep as String
            case .preventUserIdleDisplaySleep:
                kIOPMAssertionTypePreventUserIdleDisplaySleep as String
            case .preventSystemSleep:
                kIOPMAssertionTypePreventSystemSleep as String
            case .preventDisplaySleep:
                kIOPMAssertionTypePreventUserIdleDisplaySleep as String
            case .backgroundTask:
                kIOPMAssertionTypePreventUserIdleSystemSleep as String
            case .externalMedia:
                kIOPMAssertionTypePreventUserIdleSystemSleep as String
            }
        }
    #endif
}

// MARK: - Assertion Info

public struct AssertionInfo: Sendable, Identifiable {
    public var id: String { type.rawValue }
    public let type: AssertionType
    public let reason: String
    public let isActive: Bool
}

// MARK: - Assertion Error

public enum AssertionError: Error, LocalizedError, Sendable {
    case creationFailed(code: Int32)
    case alreadyActive
    case notActive

    public var errorDescription: String? {
        switch self {
        case let .creationFailed(code):
            "Failed to create power assertion (code: \(code))"
        case .alreadyActive:
            "Assertion is already active"
        case .notActive:
            "Assertion is not active"
        }
    }
}

// MARK: - Convenience Extensions

public extension AssertionManager {
    /// Prevent sleep while executing a task
    func withPreventingSleep<T: Sendable>(
        reason: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await createAssertion(type: .preventUserIdleSystemSleep, reason: reason)
        defer {
            Task {
                await releaseAssertion(type: .preventUserIdleSystemSleep)
            }
        }
        return try await operation()
    }

    /// Prevent display sleep while executing a task
    func withDisplayOn<T: Sendable>(
        reason: String,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await createAssertion(type: .preventUserIdleDisplaySleep, reason: reason)
        defer {
            Task {
                await releaseAssertion(type: .preventUserIdleDisplaySleep)
            }
        }
        return try await operation()
    }

    /// Create assertion for AI task execution
    func createAITaskAssertion(taskName: String) async throws {
        try await createAssertion(
            type: .preventUserIdleSystemSleep,
            reason: "Thea AI Task: \(taskName)",
            duration: 1800 // 30 minutes max
        )
    }

    /// Release AI task assertion
    func releaseAITaskAssertion() async {
        await releaseAssertion(type: .preventUserIdleSystemSleep)
    }
}
