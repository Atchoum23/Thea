// AAnticipatoryCommonTypes.swift
// Thea V2 - Common Types for Anticipatory Intelligence
//
// Named with AA prefix to ensure compilation before other anticipatory files
// These types are shared across multiple anticipatory subsystems

import Foundation

// MARK: - Anticipation Feedback

/// User feedback about prediction/anticipation accuracy
public struct AnticipationFeedback: Sendable {
    public let anticipationId: UUID
    public let wasAccepted: Bool
    public let wasHelpful: Bool?
    public let timestamp: Date

    public init(anticipationId: UUID, wasAccepted: Bool, wasHelpful: Bool? = nil) {
        self.anticipationId = anticipationId
        self.wasAccepted = wasAccepted
        self.wasHelpful = wasHelpful
        self.timestamp = Date()
    }
}
