// IntentAnticipatorStub.swift
// Thea V2 - Stub for IntentAnticipator while full implementation is disabled
//
// Provides minimal interface for AnticipatoryIntelligenceCore

import Foundation

/// Minimal stub for intent anticipation
@MainActor
@Observable
public final class IntentAnticipator {

    // MARK: - State

    public private(set) var isActive: Bool = false
    public private(set) var currentPredictions: [IntentPrediction] = []

    // MARK: - Public API

    public func start() {
        isActive = true
    }

    public func stop() {
        isActive = false
    }

    public func predictIntent(from context: AmbientContext) async -> [IntentPrediction] {
        // Minimal stub - returns empty predictions
        []
    }

    public init() {}
}

// MARK: - Supporting Types

public struct IntentPrediction: Identifiable, Sendable {
    public let id: UUID
    public let intent: String
    public let confidence: Double
    public let timestamp: Date

    public init(intent: String, confidence: Double) {
        self.id = UUID()
        self.intent = intent
        self.confidence = confidence
        self.timestamp = Date()
    }
}
