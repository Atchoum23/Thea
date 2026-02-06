// ProactiveEngine.swift
// Thea V2
//
// Proactive and anticipatory AI behavior engine
// Predicts user needs, offers suggestions, monitors context for triggers

import Foundation
import OSLog

// MARK: - Proactive Suggestion

/// A proactive suggestion offered to the user
public struct AnticipatoryEngineSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let action: ProactiveEngineAction
    public let confidence: Float  // 0.0 - 1.0
    public let priority: SuggestionPriorityLevel
    public let context: AnticipatoryEngineSuggestionContext
    public let expiresAt: Date?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        type: SuggestionType,
        title: String,
        description: String,
        action: ProactiveEngineAction,
        confidence: Float,
        priority: SuggestionPriorityLevel = .normal,
        context: AnticipatoryEngineSuggestionContext = AnticipatoryEngineSuggestionContext(),
        expiresAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.action = action
        self.confidence = confidence
        self.priority = priority
        self.context = context
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

public enum SuggestionType: String, Codable, Sendable {
    case taskCompletion       // Complete an unfinished task
    case relatedAction        // Related to current work
    case patternBased         // Based on observed patterns
    case timeBased           // Time-triggered (e.g., morning standup)
    case errorResolution     // Resolve detected errors
    case optimization        // Performance/quality improvement
    case reminder            // Reminder for pending items
    case learningOpportunity // Teach something new
    case automation          // Automate repetitive task
}

public enum SuggestionPriorityLevel: Int, Comparable, Sendable {
    case low = 0
    case normal = 50
    case high = 75
    case urgent = 100

    public static func < (lhs: SuggestionPriorityLevel, rhs: SuggestionPriorityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Action to take when suggestion is accepted
public enum ProactiveEngineAction: Sendable {
    case executeTask(taskDescription: String)
    case openFile(path: String)
    case runCommand(command: String)
    case showInformation(content: String)
    case askQuestion(question: String)
    case startWorkflow(workflowId: String)
    case triggerSkill(skillId: String)
    case navigateTo(destination: String)
    case custom(actionId: String, parameters: [String: String])
}

/// Context for why suggestion was made
public struct AnticipatoryEngineSuggestionContext: Sendable {
    public let triggerReason: String
    public let relatedFiles: [String]
    public let relatedTasks: [String]
    public let confidenceFactors: [String: Float]

    public init(
        triggerReason: String = "",
        relatedFiles: [String] = [],
        relatedTasks: [String] = [],
        confidenceFactors: [String: Float] = [:]
    ) {
        self.triggerReason = triggerReason
        self.relatedFiles = relatedFiles
        self.relatedTasks = relatedTasks
        self.confidenceFactors = confidenceFactors
    }
}

// MARK: - Intent Prediction

/// Predicted user intent
public struct PredictedIntent: Sendable {
    public let intent: String
    public let confidence: Float
    public let suggestedActions: [ProactiveEngineAction]
    public let reasoning: String

    public init(intent: String, confidence: Float, suggestedActions: [ProactiveEngineAction] = [], reasoning: String = "") {
        self.intent = intent
        self.confidence = confidence
        self.suggestedActions = suggestedActions
        self.reasoning = reasoning
    }
}

// MARK: - Contextual Trigger

/// A trigger that monitors for specific conditions
public struct ContextualTrigger: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let condition: AnticipatoryTriggerCondition
    public let action: ProactiveEngineAction
    public let isEnabled: Bool
    public let cooldownSeconds: Int  // Minimum seconds between triggers
    public var lastTriggeredAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        condition: AnticipatoryTriggerCondition,
        action: ProactiveEngineAction,
        isEnabled: Bool = true,
        cooldownSeconds: Int = 300,
        lastTriggeredAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.condition = condition
        self.action = action
        self.isEnabled = isEnabled
        self.cooldownSeconds = cooldownSeconds
        self.lastTriggeredAt = lastTriggeredAt
    }
}

public enum AnticipatoryTriggerCondition: Sendable {
    case fileChanged(pattern: String)
    case timeOfDay(hour: Int, minute: Int)
    case errorDetected(pattern: String)
    case taskCompleted(taskType: String)
    case idleFor(seconds: Int)
    case repeatPattern(count: Int, action: String)
    case calendarEvent(keyword: String)
    case buildFailed
    case testFailed
    case highCPUUsage(threshold: Double)
    case custom(evaluator: @Sendable () -> Bool)
}

// MARK: - User Pattern

/// Observed user behavior pattern
public struct UserPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public let patternType: PatternType
    public let description: String
    public let frequency: Int  // How many times observed
    public let confidence: Float
    public let timeOfDay: Int?  // Hour (0-23) if time-based
    public let dayOfWeek: Int?  // 1-7 if day-based
    public let contextTags: [String]
    public let lastObserved: Date
    public let firstObserved: Date

    public init(
        id: UUID = UUID(),
        patternType: PatternType,
        description: String,
        frequency: Int = 1,
        confidence: Float = 0.5,
        timeOfDay: Int? = nil,
        dayOfWeek: Int? = nil,
        contextTags: [String] = [],
        lastObserved: Date = Date(),
        firstObserved: Date = Date()
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.frequency = frequency
        self.confidence = confidence
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.contextTags = contextTags
        self.lastObserved = lastObserved
        self.firstObserved = firstObserved
    }
}

public enum PatternType: String, Codable, Sendable {
    case workflow          // Sequence of actions
    case timeBasedAction   // Action at specific time
    case fileAccess        // Files commonly accessed together
    case taskSequence      // Tasks done in sequence
    case errorResolution   // How errors are typically resolved
    case searchBehavior    // What/how user searches
    case preferredTools    // Tool preferences
    case communicationStyle // How user phrases requests
}

// MARK: - Proactive Engine

/// Main engine for proactive behavior
@MainActor
public final class ProactiveEngine: ObservableObject, Sendable {
    public static let shared = ProactiveEngine()

    private let logger = Logger(subsystem: "com.thea.proactive", category: "Engine")
    private let storageURL: URL

    @Published public private(set) var suggestions: [AnticipatoryEngineSuggestion] = []
    @Published public private(set) var patterns: [UserPattern] = []
    @Published public private(set) var triggers: [ContextualTrigger] = []
    @Published public private(set) var isAnalyzing: Bool = false

    // Configuration
    public var maxSuggestions: Int = 5
    public var minConfidenceThreshold: Float = 0.4
    public var isEnabled: Bool = true

    // State
    private var lastAnalysis: Date = Date.distantPast
    private var actionHistory: [(action: String, timestamp: Date)] = []
    private var fileAccessHistory: [(file: String, timestamp: Date)] = []

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = documentsPath.appendingPathComponent("thea_patterns.json")
        loadPatterns()
        setupDefaultTriggers()
    }

    // MARK: - Analysis

    /// Analyze current context and generate suggestions
    public func analyzeContext(
        currentFile: String? = nil,
        recentQuery: String? = nil,
        recentErrors: [String] = []
    ) async -> [AnticipatoryEngineSuggestion] {
        guard isEnabled else { return [] }

        isAnalyzing = true
        defer { isAnalyzing = false }

        var newSuggestions: [AnticipatoryEngineSuggestion] = []

        // 1. Check time-based patterns
        let timeBasedSuggestions = await checkTimeBasedPatterns()
        newSuggestions.append(contentsOf: timeBasedSuggestions)

        // 2. Check file-related suggestions
        if let file = currentFile {
            let fileSuggestions = await checkFileRelatedSuggestions(file: file)
            newSuggestions.append(contentsOf: fileSuggestions)
        }

        // 3. Check for error resolution suggestions
        if !recentErrors.isEmpty {
            let errorSuggestions = await checkErrorPatterns(errors: recentErrors)
            newSuggestions.append(contentsOf: errorSuggestions)
        }

        // 4. Check workflow patterns
        let workflowSuggestions = await checkWorkflowPatterns()
        newSuggestions.append(contentsOf: workflowSuggestions)

        // 5. Check for automation opportunities
        let automationSuggestions = await checkAutomationOpportunities()
        newSuggestions.append(contentsOf: automationSuggestions)

        // Filter by confidence and limit
        suggestions = newSuggestions
            .filter { $0.confidence >= minConfidenceThreshold }
            .sorted { $0.priority > $1.priority || ($0.priority == $1.priority && $0.confidence > $1.confidence) }
            .prefix(maxSuggestions)
            .map { $0 }

        lastAnalysis = Date()
        logger.info("Generated \(self.suggestions.count) proactive suggestions")

        return suggestions
    }

    // MARK: - Pattern Learning

    /// Record an action for pattern learning
    public func recordAction(_ action: String, context: [String: String] = [:]) {
        let now = Date()
        actionHistory.append((action, now))

        // Keep last 1000 actions
        if actionHistory.count > 1000 {
            actionHistory = Array(actionHistory.suffix(1000))
        }

        // Look for patterns
        Task {
            await detectActionPatterns()
        }
    }

    /// Record a file access
    public func recordFileAccess(_ file: String) {
        let now = Date()
        fileAccessHistory.append((file, now))

        // Keep last 500 accesses
        if fileAccessHistory.count > 500 {
            fileAccessHistory = Array(fileAccessHistory.suffix(500))
        }
    }

    // MARK: - Intent Prediction

    /// Predict user's likely intent based on context
    public func predictIntent(
        currentFile: String? = nil,
        recentQuery: String? = nil,
        timeOfDay: Int = Calendar.current.component(.hour, from: Date())
    ) -> [PredictedIntent] {
        var predictions: [PredictedIntent] = []

        // 1. Time-based predictions
        let timePatterns = patterns.filter { $0.patternType == .timeBasedAction && $0.timeOfDay == timeOfDay }
        for pattern in timePatterns {
            predictions.append(PredictedIntent(
                intent: pattern.description,
                confidence: pattern.confidence,
                reasoning: "You usually do this around \(timeOfDay):00"
            ))
        }

        // 2. File-based predictions
        if let file = currentFile {
            let filePatterns = patterns.filter {
                $0.patternType == .fileAccess && $0.contextTags.contains(file)
            }
            for pattern in filePatterns {
                predictions.append(PredictedIntent(
                    intent: pattern.description,
                    confidence: pattern.confidence,
                    reasoning: "Based on your work with similar files"
                ))
            }
        }

        // 3. Workflow predictions
        if let lastAction = actionHistory.last?.action {
            let workflowPatterns = patterns.filter {
                $0.patternType == .workflow && $0.description.contains(lastAction)
            }
            for pattern in workflowPatterns {
                // Extract next likely action from pattern
                predictions.append(PredictedIntent(
                    intent: "Continue workflow: \(pattern.description)",
                    confidence: pattern.confidence,
                    reasoning: "This typically follows \(lastAction)"
                ))
            }
        }

        return predictions.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Trigger Management

    /// Add a contextual trigger
    public func addTrigger(_ trigger: ContextualTrigger) {
        triggers.append(trigger)
        logger.info("Added trigger: \(trigger.name)")
    }

    /// Remove a trigger
    public func removeTrigger(id: UUID) {
        triggers.removeAll { $0.id == id }
    }

    /// Check all triggers and return fired ones
    public func checkTriggers() async -> [AnticipatoryEngineSuggestion] {
        var fired: [AnticipatoryEngineSuggestion] = []

        for (index, trigger) in triggers.enumerated() {
            guard trigger.isEnabled else { continue }

            // Check cooldown
            if let lastTriggered = trigger.lastTriggeredAt {
                let elapsed = Date().timeIntervalSince(lastTriggered)
                if elapsed < Double(trigger.cooldownSeconds) {
                    continue
                }
            }

            // Evaluate condition
            let shouldFire = await evaluateAnticipatoryTriggerCondition(trigger.condition)

            if shouldFire {
                let suggestion = AnticipatoryEngineSuggestion(
                    type: .patternBased,
                    title: trigger.name,
                    description: "Triggered: \(trigger.name)",
                    action: trigger.action,
                    confidence: 0.9,
                    priority: .high
                )
                fired.append(suggestion)

                // Update last triggered
                var updatedTrigger = trigger
                updatedTrigger = ContextualTrigger(
                    id: trigger.id,
                    name: trigger.name,
                    condition: trigger.condition,
                    action: trigger.action,
                    isEnabled: trigger.isEnabled,
                    cooldownSeconds: trigger.cooldownSeconds,
                    lastTriggeredAt: Date()
                )
                triggers[index] = updatedTrigger

                logger.info("Trigger fired: \(trigger.name)")
            }
        }

        return fired
    }

    // MARK: - Suggestion Feedback

    /// Record user response to suggestion
    public func recordSuggestionFeedback(suggestionId: UUID, accepted: Bool, helpful: Bool) {
        // Use this feedback to improve future suggestions
        if accepted {
            // Increase confidence in similar patterns
            logger.info("Suggestion \(suggestionId) accepted - will reinforce pattern")
        } else if !helpful {
            // Decrease confidence or remove pattern
            logger.info("Suggestion \(suggestionId) marked unhelpful - will adjust")
        }

        // Remove the suggestion
        suggestions.removeAll { $0.id == suggestionId }
    }

    // MARK: - Private Helpers

    private func checkTimeBasedPatterns() async -> [AnticipatoryEngineSuggestion] {
        var suggestions: [AnticipatoryEngineSuggestion] = []

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let dayOfWeek = calendar.component(.weekday, from: Date())

        // Check for morning standup (9-10 AM on weekdays)
        if hour >= 9 && hour < 10 && dayOfWeek >= 2 && dayOfWeek <= 6 {
            let standupPattern = patterns.first {
                $0.patternType == .timeBasedAction && $0.description.contains("standup")
            }

            if standupPattern != nil || hour == 9 {
                suggestions.append(AnticipatoryEngineSuggestion(
                    type: .timeBased,
                    title: "Morning Standup",
                    description: "Would you like me to prepare your standup notes?",
                    action: .executeTask(taskDescription: "Prepare standup notes summarizing yesterday's work and today's plan"),
                    confidence: 0.7,
                    priority: .normal,
                    expiresAt: Date().addingTimeInterval(3600)  // Expires in 1 hour
                ))
            }
        }

        // Check for end-of-day review (5-6 PM)
        if hour >= 17 && hour < 18 {
            suggestions.append(AnticipatoryEngineSuggestion(
                type: .timeBased,
                title: "End of Day Review",
                description: "Ready to review today's accomplishments?",
                action: .executeTask(taskDescription: "Summarize today's completed tasks and prepare tomorrow's priorities"),
                confidence: 0.6,
                priority: .low,
                expiresAt: Date().addingTimeInterval(3600)
            ))
        }

        return suggestions
    }

    private func checkFileRelatedSuggestions(file: String) async -> [AnticipatoryEngineSuggestion] {
        var suggestions: [AnticipatoryEngineSuggestion] = []

        // Suggest related files
        let relatedPatterns = patterns.filter {
            $0.patternType == .fileAccess && $0.contextTags.contains(file)
        }

        for pattern in relatedPatterns.prefix(2) {
            let otherFiles = pattern.contextTags.filter { $0 != file }
            if let relatedFile = otherFiles.first {
                suggestions.append(AnticipatoryEngineSuggestion(
                    type: .relatedAction,
                    title: "Related File",
                    description: "You often work with \(relatedFile) alongside this file",
                    action: .openFile(path: relatedFile),
                    confidence: pattern.confidence,
                    priority: .low,
                    context: AnticipatoryEngineSuggestionContext(
                        triggerReason: "File access pattern",
                        relatedFiles: [file, relatedFile]
                    )
                ))
            }
        }

        // Suggest tests if editing source file
        if file.hasSuffix(".swift") && !file.contains("Test") {
            let testFile = file.replacingOccurrences(of: ".swift", with: "Tests.swift")
            suggestions.append(AnticipatoryEngineSuggestion(
                type: .relatedAction,
                title: "Update Tests?",
                description: "Don't forget to update tests for your changes",
                action: .openFile(path: testFile),
                confidence: 0.5,
                priority: .low
            ))
        }

        return suggestions
    }

    private func checkErrorPatterns(errors: [String]) async -> [AnticipatoryEngineSuggestion] {
        var suggestions: [AnticipatoryEngineSuggestion] = []

        for error in errors {
            // Check if we've seen this error before
            let errorPatterns = patterns.filter {
                $0.patternType == .errorResolution &&
                error.lowercased().contains($0.description.lowercased())
            }

            if let pattern = errorPatterns.first {
                suggestions.append(AnticipatoryEngineSuggestion(
                    type: .errorResolution,
                    title: "Known Error Pattern",
                    description: "I've seen this error before. \(pattern.description)",
                    action: .showInformation(content: "Previous resolution: \(pattern.contextTags.joined(separator: ", "))"),
                    confidence: pattern.confidence,
                    priority: .high
                ))
            }
        }

        return suggestions
    }

    private func checkWorkflowPatterns() async -> [AnticipatoryEngineSuggestion] {
        var suggestions: [AnticipatoryEngineSuggestion] = []

        // Check for incomplete workflows
        let recentActions = actionHistory.suffix(5).map { $0.action }

        for pattern in patterns where pattern.patternType == .workflow {
            // Simple check: if pattern starts with recent actions but has more steps
            let patternSteps = pattern.contextTags
            if patternSteps.count > recentActions.count {
                var matchCount = 0
                for (index, action) in recentActions.enumerated() where index < patternSteps.count {
                    if patternSteps[index].contains(action) {
                        matchCount += 1
                    }
                }

                if matchCount >= 2 && matchCount < patternSteps.count {
                    let nextStep = patternSteps[matchCount]
                    suggestions.append(AnticipatoryEngineSuggestion(
                        type: .taskCompletion,
                        title: "Continue Workflow",
                        description: "Next step: \(nextStep)",
                        action: .executeTask(taskDescription: nextStep),
                        confidence: pattern.confidence * Float(matchCount) / Float(patternSteps.count),
                        priority: .normal
                    ))
                }
            }
        }

        return suggestions
    }

    private func checkAutomationOpportunities() async -> [AnticipatoryEngineSuggestion] {
        var suggestions: [AnticipatoryEngineSuggestion] = []

        // Find repeated actions
        let actionCounts = Dictionary(grouping: actionHistory.suffix(100).map { $0.action }) { $0 }
            .mapValues { $0.count }

        for (action, count) in actionCounts where count >= 5 {
            suggestions.append(AnticipatoryEngineSuggestion(
                type: .automation,
                title: "Automate Repetitive Task",
                description: "You've done '\(action)' \(count) times recently. Want to automate it?",
                action: .custom(actionId: "create_automation", parameters: ["action": action]),
                confidence: min(0.9, Float(count) / 10.0),
                priority: .low
            ))
        }

        return suggestions
    }

    private func detectActionPatterns() async {
        // Detect workflow patterns from action sequences
        let recentActions = actionHistory.suffix(20).map { $0.action }

        // Look for repeated sequences of 2-4 actions
        for sequenceLength in 2...4 {
            if recentActions.count >= sequenceLength * 2 {
                for start in 0...(recentActions.count - sequenceLength) {
                    let sequence = Array(recentActions[start..<(start + sequenceLength)])

                    // Count occurrences
                    var occurrences = 0
                    var index = 0
                    while index <= recentActions.count - sequenceLength {
                        let candidate = Array(recentActions[index..<(index + sequenceLength)])
                        if candidate == sequence {
                            occurrences += 1
                            index += sequenceLength
                        } else {
                            index += 1
                        }
                    }

                    if occurrences >= 2 {
                        let patternDescription = sequence.joined(separator: " → ")
                        if !patterns.contains(where: { $0.description == patternDescription }) {
                            let pattern = UserPattern(
                                patternType: .workflow,
                                description: patternDescription,
                                frequency: occurrences,
                                confidence: min(0.9, Float(occurrences) / 5.0),
                                contextTags: sequence
                            )
                            patterns.append(pattern)
                            savePatterns()
                            logger.info("Detected new workflow pattern: \(patternDescription)")
                        }
                    }
                }
            }
        }
    }

    private func evaluateAnticipatoryTriggerCondition(_ condition: AnticipatoryTriggerCondition) async -> Bool {
        switch condition {
        case .timeOfDay(let hour, let minute):
            let now = Date()
            let calendar = Calendar.current
            return calendar.component(.hour, from: now) == hour &&
                   calendar.component(.minute, from: now) == minute

        case .idleFor(let seconds):
            if let lastAction = actionHistory.last?.timestamp {
                return Date().timeIntervalSince(lastAction) >= Double(seconds)
            }
            return false

        case .repeatPattern(let count, let action):
            let recent = actionHistory.suffix(count * 2).map { $0.action }
            let matchCount = recent.filter { $0 == action }.count
            return matchCount >= count

        case .custom(let evaluator):
            return evaluator()

        default:
            // Other conditions require external context
            return false
        }
    }

    private func setupDefaultTriggers() {
        // Morning greeting
        triggers.append(ContextualTrigger(
            name: "Morning Greeting",
            condition: .timeOfDay(hour: 9, minute: 0),
            action: .showInformation(content: "Good morning! Ready to start the day?"),
            cooldownSeconds: 86400  // Once per day
        ))

        // Idle reminder
        triggers.append(ContextualTrigger(
            name: "Idle Reminder",
            condition: .idleFor(seconds: 1800),  // 30 minutes
            action: .askQuestion(question: "You've been idle for a while. Need any help?"),
            cooldownSeconds: 3600  // Once per hour max
        ))
    }

    // MARK: - Persistence

    private func loadPatterns() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            patterns = try JSONDecoder().decode([UserPattern].self, from: data)
            logger.info("Loaded \(self.patterns.count) user patterns")
        } catch {
            logger.error("Failed to load patterns: \(error.localizedDescription)")
        }
    }

    private func savePatterns() {
        do {
            let data = try JSONEncoder().encode(patterns)
            try data.write(to: storageURL)
        } catch {
            logger.error("Failed to save patterns: \(error.localizedDescription)")
        }
    }
}

// MARK: - Ambient Awareness Monitor

/// Monitors system state for ambient awareness
public actor AmbientAwarenessMonitor {
    public static let shared = AmbientAwarenessMonitor()

    private let logger = Logger(subsystem: "com.thea.proactive", category: "Ambient")

    private var isMonitoring: Bool = false
    private var lastBuildStatus: BuildStatus = .unknown
    private var errorBuffer: [String] = []

    public enum BuildStatus: Sendable {
        case unknown
        case building
        case succeeded
        case failed(errors: [String])
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        logger.info("Started ambient monitoring")
    }

    public func stopMonitoring() {
        isMonitoring = false
        logger.info("Stopped ambient monitoring")
    }

    // MARK: - Event Recording

    public func recordBuildStatus(_ status: BuildStatus) {
        lastBuildStatus = status

        if case .failed(let errors) = status {
            errorBuffer.append(contentsOf: errors)
            // Keep last 50 errors
            if errorBuffer.count > 50 {
                errorBuffer = Array(errorBuffer.suffix(50))
            }
        }
    }

    public func recordError(_ error: String) {
        errorBuffer.append(error)
        if errorBuffer.count > 50 {
            errorBuffer = Array(errorBuffer.suffix(50))
        }
    }

    public func recentErrors() -> [String] {
        errorBuffer
    }

    public func currentBuildStatus() -> BuildStatus {
        lastBuildStatus
    }
}
