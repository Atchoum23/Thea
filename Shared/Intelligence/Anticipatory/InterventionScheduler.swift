// InterventionScheduler.swift
// Thea V2 - Proactive Intervention Scheduling
//
// Schedules and manages proactive interventions
// Learns optimal timing from user feedback

import Foundation
import OSLog

// MARK: - Intervention Scheduler

/// Schedules and manages proactive interventions
@MainActor
@Observable
public final class InterventionScheduler {

    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "InterventionScheduler")

    // MARK: - State

    /// Scheduled interventions
    public private(set) var scheduledInterventions: [ScheduledIntervention] = []

    /// Intervention history
    private var interventionHistory: [InterventionRecord] = []

    /// Learned optimal times
    private var learnedOptimalTimes: [String: [Int]] = [:]

    // MARK: - Callbacks

    public var onInterventionReady: ((ProactiveIntervention) -> Void)?

    // MARK: - Initialization

    public init() {
        loadLearnedTimes()
    }

    // MARK: - Public API

    /// Schedule an intervention
    public func schedule(_ intervention: ProactiveIntervention) {
        let scheduled = ScheduledIntervention(
            intervention: intervention,
            scheduledAt: Date(),
            attemptCount: 0
        )
        scheduledInterventions.append(scheduled)
        logger.debug("Scheduled intervention: \(intervention.id)")
    }

    /// Postpone an intervention
    public func postpone(_ intervention: ProactiveIntervention, by seconds: TimeInterval) {
        guard let index = scheduledInterventions.firstIndex(where: { $0.intervention.id == intervention.id }) else { return }

        var updated = scheduledInterventions[index]
        updated.intervention.expiresAt = updated.intervention.expiresAt.addingTimeInterval(seconds)
        updated.attemptCount += 1
        scheduledInterventions[index] = updated

        logger.debug("Postponed intervention \(intervention.id) by \(seconds) seconds")
    }

    /// Check for interventions that should be triggered
    public func checkScheduledInterventions(
        context: AmbientContext,
        mentalModel: MentalWorldModel
    ) async {
        let now = Date()

        for scheduled in scheduledInterventions {
            // Skip if too many attempts
            guard scheduled.attemptCount < 5 else {
                removeIntervention(scheduled.intervention.id)
                continue
            }

            // Skip if expired
            guard scheduled.intervention.expiresAt > now else {
                removeIntervention(scheduled.intervention.id)
                continue
            }

            // Check if conditions are met
            if shouldTrigger(scheduled, context: context, mentalModel: mentalModel) {
                onInterventionReady?(scheduled.intervention)
            }
        }
    }

    /// Learn from feedback
    public func learnFromFeedback(_ feedback: AnticipationFeedback) {
        let hour = Calendar.current.component(.hour, from: feedback.timestamp)

        if feedback.wasAccepted {
            // This was a good time for intervention
            learnedOptimalTimes["general", default: []].append(hour)
        }

        saveLearnedTimes()
    }

    // MARK: - Private Methods

    private func shouldTrigger(
        _ scheduled: ScheduledIntervention,
        context: AmbientContext,
        mentalModel: MentalWorldModel
    ) -> Bool {
        let intervention = scheduled.intervention

        switch intervention.triggerCondition {
        case .patternMatch:
            return mentalModel.isInterruptionAppropriate()

        case .timeOfDay(let hour):
            let currentHour = Calendar.current.component(.hour, from: Date())
            return currentHour == hour && mentalModel.isInterruptionAppropriate()

        case .userIdle(let seconds):
            if let lastInteraction = mentalModel.lastInteraction {
                return Date().timeIntervalSince(lastInteraction) >= seconds
            }
            return false

        case .contextChange(let expectedContext):
            return context.recentActivityTypes.contains(expectedContext)
        }
    }

    private func removeIntervention(_ id: UUID) {
        scheduledInterventions.removeAll { $0.intervention.id == id }
    }

    private func loadLearnedTimes() {
        if let data = UserDefaults.standard.data(forKey: "InterventionOptimalTimes") {
            do {
                learnedOptimalTimes = try JSONDecoder().decode([String: [Int]].self, from: data)
            } catch {
                logger.error("Failed to decode intervention optimal times: \(error.localizedDescription)")
            }
        }
    }

    private func saveLearnedTimes() {
        do {
            let encoded = try JSONEncoder().encode(learnedOptimalTimes)
            UserDefaults.standard.set(encoded, forKey: "InterventionOptimalTimes")
        } catch {
            logger.error("Failed to encode intervention optimal times: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

public struct ScheduledIntervention: Sendable {
    public var intervention: ProactiveIntervention
    public let scheduledAt: Date
    public var attemptCount: Int
}

struct InterventionRecord: Sendable {
    // periphery:ignore - Reserved: interventionId property — reserved for future feature activation
    let interventionId: UUID
    // periphery:ignore - Reserved: type property — reserved for future feature activation
    let type: String
    // periphery:ignore - Reserved: triggeredAt property — reserved for future feature activation
    let triggeredAt: Date
    // periphery:ignore - Reserved: wasAccepted property — reserved for future feature activation
    let wasAccepted: Bool
    // periphery:ignore - Reserved: interventionId property reserved for future feature activation
    // periphery:ignore - Reserved: type property reserved for future feature activation
    // periphery:ignore - Reserved: triggeredAt property reserved for future feature activation
    // periphery:ignore - Reserved: wasAccepted property reserved for future feature activation
    // periphery:ignore - Reserved: responseTime property reserved for future feature activation
    let responseTime: TimeInterval?
}
