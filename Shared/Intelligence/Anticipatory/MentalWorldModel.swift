// MentalWorldModel.swift
// Thea V2 - Mental World Model
//
// Models the user's mental state for intelligent interruption timing
// Based on Theory of Mind principles for AI assistants

import Foundation

// MARK: - Mental World Model

/// Represents the user's current mental/cognitive state
/// Used to determine if and when interruptions are appropriate
public struct MentalWorldModel: Sendable {
    public var focusLevel: Double
    public var stressLevel: Double
    public var isInMeeting: Bool
    public var isDriving: Bool
    public var isWorking: Bool
    public var lastInteraction: Date?

    public init(
        focusLevel: Double = 0.5,
        stressLevel: Double = 0.3,
        isInMeeting: Bool = false,
        isDriving: Bool = false,
        isWorking: Bool = false,
        lastInteraction: Date? = nil
    ) {
        self.focusLevel = focusLevel
        self.stressLevel = stressLevel
        self.isInMeeting = isInMeeting
        self.isDriving = isDriving
        self.isWorking = isWorking
        self.lastInteraction = lastInteraction
    }

    /// Determines if it's appropriate to interrupt the user now
    public func isInterruptionAppropriate() -> Bool {
        // Never interrupt during meetings or driving
        if isInMeeting || isDriving { return false }

        // High focus means less interruption tolerance
        if focusLevel > 0.8 { return false }

        // High stress means less interruption tolerance
        if stressLevel > 0.7 { return false }

        // Check time since last interaction
        if let lastInteraction = lastInteraction {
            let secondsSinceInteraction = Date().timeIntervalSince(lastInteraction)
            // Don't interrupt if very recently interacted (likely still focused)
            if secondsSinceInteraction < 60 { return false }
        }

        return true
    }

    /// Determines if user is likely to want help with current task
    public func isLikelyToWantHelp() -> Bool {
        // User is working and has moderate focus - good time for suggestions
        if isWorking && focusLevel > 0.3 && focusLevel < 0.7 {
            return true
        }

        // Low stress and moderate focus - receptive state
        if stressLevel < 0.4 && focusLevel < 0.6 {
            return true
        }

        return false
    }

    /// Estimated optimal interruption delay in seconds
    public var optimalInterruptionDelay: TimeInterval {
        if focusLevel > 0.7 {
            return 300 // 5 minutes for high focus
        } else if focusLevel > 0.5 {
            return 120 // 2 minutes for moderate focus
        } else {
            return 30 // 30 seconds for low focus
        }
    }
}
