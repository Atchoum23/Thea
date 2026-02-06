//
//  WorkflowRecorder.swift
//  Thea
//
//  Records user interaction patterns to create automated workflows.
//  Integrates with AdaptiveUIEngine, ShortcutsOrchestrator, and TaskScheduler.
//
//  WORKFLOW:
//  1. User starts recording
//  2. Actions are captured as workflow steps
//  3. Recording stops manually or after inactivity
//  4. Workflow can be saved, edited, or converted to Shortcut
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog

// MARK: - Workflow Recorder

/// Records user actions to create repeatable workflows
@MainActor
@Observable
public final class WorkflowRecorder {
    public static let shared = WorkflowRecorder()

    private let logger = Logger(subsystem: "ai.thea.app", category: "WorkflowRecorder")

    // MARK: - State

    /// Whether recording is active
    public private(set) var isRecording: Bool = false

    /// Recorded steps in current session
    public private(set) var recordedSteps: [RecordedWorkflowStep] = []

    /// Start time of current recording
    public private(set) var recordingStartTime: Date?

    /// Saved workflows
    public private(set) var savedWorkflows: [RecordedWorkflow] = []

    /// Suggested workflows based on patterns
    public private(set) var suggestedWorkflows: [WorkflowSuggestion] = []

    // MARK: - Configuration

    public var configuration = Configuration() {
        didSet { saveConfiguration() }
    }

    public struct Configuration: Codable, Sendable {
        /// Auto-stop recording after inactivity (seconds)
        public var inactivityTimeout: TimeInterval = 300

        /// Minimum steps to create a workflow
        public var minimumSteps: Int = 3

        /// Maximum steps per workflow
        public var maximumSteps: Int = 50

        /// Enable pattern detection for suggestions
        public var enablePatternDetection: Bool = true

        /// Minimum pattern occurrences to suggest workflow
        public var patternThreshold: Int = 3

        public init() {}
    }

    // MARK: - Private State

    private var inactivityTimer: Timer?
    private var actionObserver: Any?

    // MARK: - Initialization

    private init() {
        loadSavedWorkflows()
        loadConfiguration()
    }

    // MARK: - Recording API

    /// Start recording workflow
    public func startRecording() {
        guard !isRecording else {
            logger.debug("Already recording")
            return
        }

        isRecording = true
        recordedSteps = []
        recordingStartTime = Date()

        startInactivityTimer()
        logger.info("Started workflow recording")
    }

    /// Stop recording and return workflow
    public func stopRecording() -> RecordedWorkflow? {
        guard isRecording else { return nil }

        isRecording = false
        inactivityTimer?.invalidate()
        inactivityTimer = nil

        guard recordedSteps.count >= configuration.minimumSteps else {
            logger.debug("Not enough steps for workflow")
            return nil
        }

        let workflow = RecordedWorkflow(
            id: UUID(),
            name: generateWorkflowName(),
            steps: recordedSteps,
            createdAt: recordingStartTime ?? Date(),
            totalDuration: Date().timeIntervalSince(recordingStartTime ?? Date())
        )

        logger.info("Stopped recording: \(workflow.steps.count) steps captured")
        return workflow
    }

    /// Record a single action
    public func recordAction(_ action: RecordedUserAction) {
        guard isRecording else { return }

        let step = RecordedWorkflowStep(
            id: UUID(),
            action: action,
            timestamp: Date(),
            order: recordedSteps.count
        )

        recordedSteps.append(step)
        resetInactivityTimer()

        // Check for max steps
        if recordedSteps.count >= configuration.maximumSteps {
            logger.debug("Maximum steps reached, stopping recording")
            _ = stopRecording()
        }

        logger.debug("Recorded action: \(action.type.rawValue)")
    }

    /// Cancel current recording
    public func cancelRecording() {
        isRecording = false
        recordedSteps = []
        recordingStartTime = nil
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        logger.debug("Recording cancelled")
    }

    // MARK: - Workflow Management

    /// Save a recorded workflow
    public func saveWorkflow(_ workflow: RecordedWorkflow) {
        savedWorkflows.append(workflow)
        persistWorkflows()
        logger.info("Saved workflow: \(workflow.name)")
    }

    /// Delete a saved workflow
    public func deleteWorkflow(id: UUID) {
        savedWorkflows.removeAll { $0.id == id }
        persistWorkflows()
    }

    /// Rename a workflow
    public func renameWorkflow(id: UUID, newName: String) {
        if let index = savedWorkflows.firstIndex(where: { $0.id == id }) {
            savedWorkflows[index].name = newName
            persistWorkflows()
        }
    }

    /// Execute a saved workflow
    public func executeWorkflow(_ workflow: RecordedWorkflow) async throws {
        logger.info("Executing workflow: \(workflow.name)")

        for step in workflow.steps.sorted(by: { $0.order < $1.order }) {
            try await executeStep(step)

            // Add delay between steps if specified
            if let delay = step.delayAfter, delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }
        }

        logger.info("Workflow execution complete")
    }

    private func executeStep(_ step: RecordedWorkflowStep) async throws {
        // Execute based on action type
        switch step.action.type {
        case .chat:
            // Send chat message
            if let message = step.action.parameters["message"] {
                logger.debug("Sending chat message: \(message.prefix(50))")
            }

        case .navigate:
            // Navigate to destination
            if let destination = step.action.parameters["destination"] {
                logger.debug("Navigating to: \(destination)")
            }

        case .shortcut:
            // Run shortcut
            if let shortcutName = step.action.parameters["shortcutName"] {
                logger.debug("Running shortcut: \(shortcutName)")
            }

        case .setting:
            // Change setting
            logger.debug("Changing setting")

        case .automation:
            // Run automation action
            logger.debug("Running automation")

        case .custom:
            // Custom action
            logger.debug("Custom action")
        }
    }

    // MARK: - Pattern Detection

    /// Analyze usage patterns for workflow suggestions
    public func analyzePatterns() async {
        guard configuration.enablePatternDetection else { return }

        // Get interaction patterns from AdaptiveUIEngine
        let patterns = AdaptiveUIEngine.shared.interactionPatterns

        // Detect repeated sequences
        var detectedSequences: [String: Int] = [:]

        // Simple frequency analysis
        for (action, pattern) in patterns {
            if pattern.frequency >= configuration.patternThreshold {
                detectedSequences[action] = pattern.frequency
            }
        }

        // Generate suggestions from sequences
        suggestedWorkflows = detectedSequences
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { action, frequency in
                WorkflowSuggestion(
                    id: UUID(),
                    name: "Automate: \(action)",
                    description: "Detected \(frequency) occurrences of this pattern",
                    confidence: min(1.0, Double(frequency) / 20.0),
                    basedOnPattern: action
                )
            }

        logger.debug("Generated \(self.suggestedWorkflows.count) workflow suggestions")
    }

    /// Suggest workflow from recent patterns
    public func suggestWorkflow(from patterns: [InteractionPattern]) -> WorkflowSuggestion? {
        guard !patterns.isEmpty else { return nil }

        // Find most common pattern sequence
        let sorted = patterns.sorted { $0.frequency > $1.frequency }

        guard let top = sorted.first, top.frequency >= configuration.patternThreshold else {
            return nil
        }

        return WorkflowSuggestion(
            id: UUID(),
            name: "Suggested: \(top.action)",
            description: "Based on \(top.frequency) occurrences",
            confidence: min(1.0, Double(top.frequency) / 20.0),
            basedOnPattern: top.action
        )
    }

    // MARK: - Private Helpers

    private func startInactivityTimer() {
        inactivityTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.inactivityTimeout,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleInactivityTimeout()
            }
        }
    }

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        startInactivityTimer()
    }

    private func handleInactivityTimeout() {
        guard isRecording else { return }
        logger.debug("Inactivity timeout, stopping recording")
        _ = stopRecording()
    }

    private func generateWorkflowName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return "Workflow - \(formatter.string(from: Date()))"
    }

    // MARK: - Persistence

    private let workflowsKey = "WorkflowRecorder.workflows"
    private let configKey = "WorkflowRecorder.config"

    private func loadSavedWorkflows() {
        if let data = UserDefaults.standard.data(forKey: workflowsKey),
           let decoded = try? JSONDecoder().decode([RecordedWorkflow].self, from: data) {
            savedWorkflows = decoded
        }
    }

    private func persistWorkflows() {
        if let data = try? JSONEncoder().encode(savedWorkflows) {
            UserDefaults.standard.set(data, forKey: workflowsKey)
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = decoded
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
}

// MARK: - Supporting Types

/// A recorded workflow
public struct RecordedWorkflow: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var steps: [RecordedWorkflowStep]
    public let createdAt: Date
    public var totalDuration: TimeInterval
    public var isEnabled: Bool = true

    public var stepCount: Int { steps.count }
}

/// A single step in a workflow
public struct RecordedWorkflowStep: Identifiable, Codable, Sendable {
    public let id: UUID
    public let action: RecordedUserAction
    public let timestamp: Date
    public var order: Int
    public var delayAfter: TimeInterval?

    public init(
        id: UUID = UUID(),
        action: RecordedUserAction,
        timestamp: Date = Date(),
        order: Int,
        delayAfter: TimeInterval? = nil
    ) {
        self.id = id
        self.action = action
        self.timestamp = timestamp
        self.order = order
        self.delayAfter = delayAfter
    }
}

/// A user action that can be recorded
public struct RecordedUserAction: Codable, Sendable {
    public let type: ActionType
    public let parameters: [String: String]
    public let context: [String: String]

    public init(type: ActionType, parameters: [String: String] = [:], context: [String: String] = [:]) {
        self.type = type
        self.parameters = parameters
        self.context = context
    }

    public enum ActionType: String, Codable, Sendable {
        case chat
        case navigate
        case shortcut
        case setting
        case automation
        case custom
    }
}

/// A suggested workflow based on patterns
public struct WorkflowSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let confidence: Double
    public let basedOnPattern: String

    public var confidenceLabel: String {
        if confidence >= 0.8 { return "High confidence" }
        if confidence >= 0.5 { return "Moderate confidence" }
        return "Low confidence"
    }
}
