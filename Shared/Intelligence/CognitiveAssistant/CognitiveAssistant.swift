// CognitiveAssistant.swift
// Thea V2
//
// Cognitive Assistant - Proactive help based on user cognitive state
// Monitors cognitive load, fatigue, and provides timely interventions

import Foundation
import OSLog

// MARK: - Cognitive Assistant

/// Monitors user cognitive state and provides proactive assistance
@MainActor
public final class CognitiveAssistant: ObservableObject {

    public static let shared = CognitiveAssistant()

    private let logger = Logger(subsystem: "app.thea.intelligence", category: "CognitiveAssistant")

    // MARK: - State

    @Published public private(set) var cognitiveState = CognitiveState()
    @Published public private(set) var activeInterventions: [CognitiveIntervention] = []
    @Published public private(set) var sessionMetrics = SessionMetrics()

    // MARK: - Configuration

    public var fatigueThreshold: Float = 0.7
    public var overloadThreshold: Float = 0.8
    public var sessionBreakInterval: TimeInterval = 5400 // 90 minutes

    // MARK: - Monitoring

    private var monitoringTask: Task<Void, Never>?

    public func startMonitoring() {
        sessionMetrics.startTime = Date()
        monitoringTask = Task {
            while !Task.isCancelled {
                await updateCognitiveState()
                await checkForInterventions()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        logger.info("Cognitive monitoring started")
    }

    public func stopMonitoring() {
        monitoringTask?.cancel()
        sessionMetrics.endTime = Date()
    }

    private func updateCognitiveState() async {
        var state = CognitiveState()
        state.lastUpdated = Date()
        state.cognitiveLoad = assessCognitiveLoad()
        state.fatigueLevel = detectFatigue()
        state.focusState = assessFocusState()
        state.overallState = determineOverallState(state)
        cognitiveState = state
    }

    private func assessCognitiveLoad() -> Float {
        let sessionDuration = Date().timeIntervalSince(sessionMetrics.startTime)
        return min(1.0, Float(sessionDuration / sessionBreakInterval))
    }

    private func detectFatigue() -> Float {
        let sessionDuration = Date().timeIntervalSince(sessionMetrics.startTime)
        return min(1.0, Float(sessionDuration / 14400)) // 4 hours = max fatigue
    }

    private func assessFocusState() -> CognitiveFocusState {
        let timeSinceLastAction = Date().timeIntervalSince(sessionMetrics.lastActionAt ?? Date())
        if timeSinceLastAction > 300 { return .distracted } else if sessionMetrics.recentActions > 5 { return .deepFocus } else if sessionMetrics.recentActions > 2 { return .focused } else { return .shallow }
    }

    private func determineOverallState(_ state: CognitiveState) -> OverallCognitiveState {
        if state.fatigueLevel >= fatigueThreshold && state.cognitiveLoad >= overloadThreshold { return .overloaded } else if state.fatigueLevel >= fatigueThreshold { return .fatigued } else if state.focusState == .deepFocus { return .optimal } else if state.focusState == .distracted { return .unfocused } else { return .normal }
    }

    private func checkForInterventions() async {
        if cognitiveState.fatigueLevel >= fatigueThreshold && !activeInterventions.contains(where: { $0.type == .fatigueWarning }) {
            activeInterventions.append(CognitiveIntervention(
                id: UUID(), type: .fatigueWarning, priority: .high,
                title: "You might need a break",
                message: "You've been working for a while. Consider taking a short break.",
                suggestions: ["Take a 5-minute break", "Grab some water"],
                actions: [CognitiveAction(id: "break", title: "Start break", type: .startBreak),
                         CognitiveAction(id: "snooze", title: "Later", type: .dismiss)],
                createdAt: Date(), expiresAt: Date().addingTimeInterval(600)
            ))
        }
    }

    public func handleInterventionAction(_ intervention: CognitiveIntervention, action: CognitiveAction) async {
        activeInterventions.removeAll { $0.id == intervention.id }
        if action.type == .startBreak { sessionMetrics.breaksTaken += 1 }
    }

    public func recordAction() {
        sessionMetrics.totalActions += 1
        sessionMetrics.recentActions += 1
        sessionMetrics.lastActionAt = Date()
    }
}

// MARK: - Supporting Types

public struct CognitiveState: Sendable {
    public var cognitiveLoad: Float = 0.0
    public var fatigueLevel: Float = 0.0
    public var focusState: CognitiveFocusState = .shallow
    public var overallState: OverallCognitiveState = .normal
    public var lastUpdated = Date()
}

public enum CognitiveFocusState: String, Sendable { case deepFocus, focused, shallow, distracted }
public enum OverallCognitiveState: String, Sendable { case optimal, normal, unfocused, struggling, fatigued, overloaded }

public struct CognitiveIntervention: Identifiable, Sendable {
    public let id: UUID
    public let type: InterventionType
    public let priority: InterventionPriority
    public let title: String
    public let message: String
    public let suggestions: [String]
    public let actions: [CognitiveAction]
    public let createdAt: Date
    public var expiresAt: Date

    public enum InterventionType: String, Sendable { case fatigueWarning, overloadWarning, breakReminder, stressIntervention, focusAssistance }
    public enum InterventionPriority: String, Sendable, Comparable {
        case low, medium, high
        public static func < (lhs: Self, rhs: Self) -> Bool {
            [.low, .medium, .high].firstIndex(of: lhs)! < [.low, .medium, .high].firstIndex(of: rhs)!
        }
    }
}

public struct CognitiveAction: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let type: ActionType
    public enum ActionType: String, Sendable { case dismiss, snooze, startBreak, assistFocus, offerHelp, resumeContext, newTask }
}

public struct SessionMetrics: Sendable {
    public var startTime = Date()
    public var endTime: Date?
    public var lastActionAt: Date?
    public var totalActions: Int = 0
    public var recentActions: Int = 0
    public var breaksTaken: Int = 0
}
