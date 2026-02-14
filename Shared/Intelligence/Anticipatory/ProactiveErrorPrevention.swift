// ProactiveErrorPrevention.swift
// Thea V2 - Proactive Error Prevention
//
// Predicts and prevents errors before they occur
// Learns from past failures to improve future interactions

import Foundation
import OSLog

// MARK: - Proactive Error Prevention

/// Prevents errors before they occur through predictive analysis
@MainActor
@Observable
public final class ProactiveErrorPrevention {

    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "ErrorPrevention")

    // MARK: - State

    /// Known error patterns
    public private(set) var errorPatterns: [ErrorPattern] = []

    /// Current risk assessments
    public private(set) var currentRisks: [RiskAssessment] = []

    /// Prevention suggestions
    public private(set) var preventionSuggestions: [PreventionSuggestion] = []

    // MARK: - Configuration

    public var configuration = PreventionConfiguration()

    // MARK: - Callbacks

    /// Called when a risk is detected
    public var onRiskDetected: ((RiskAssessment) -> Void)?

    /// Called when prevention is suggested
    public var onPreventionSuggested: ((PreventionSuggestion) -> Void)?

    // MARK: - Private State

    private var errorHistory: [RecordedError] = []
    private var contextHistory: [ErrorContext] = []

    // MARK: - Initialization

    public init() {
        loadErrorPatterns()
        loadDefaultPatterns()
    }

    // MARK: - Public API

    /// Record an error that occurred
    public func recordError(_ error: RecordedError) {
        errorHistory.append(error)

        // Learn from error
        learnFromError(error)

        // Keep last 500 errors
        if errorHistory.count > 500 {
            errorHistory.removeFirst()
        }

        saveErrorPatterns()
    }

    /// Analyze current context for potential errors
    public func analyzeContext(_ context: ErrorContext) async -> [RiskAssessment] {
        contextHistory.append(context)

        var risks: [RiskAssessment] = []

        // Check against known patterns
        for pattern in errorPatterns {
            if let risk = assessRisk(context: context, pattern: pattern) {
                risks.append(risk)
            }
        }

        // Check for common mistake indicators
        risks.append(contentsOf: checkCommonMistakes(context))

        currentRisks = risks

        // Generate prevention suggestions for high risks
        for risk in risks where risk.severity >= .medium {
            let suggestion = generatePreventionSuggestion(for: risk)
            preventionSuggestions.append(suggestion)
            onPreventionSuggested?(suggestion)
        }

        // Notify about high risks
        for risk in risks where risk.severity >= .high {
            onRiskDetected?(risk)
        }

        return risks
    }

    /// Validate user input proactively
    public func validateInput(_ input: String, type: InputType) -> InputValidationResult {
        var issues: [ValidationIssue] = []

        switch type {
        case .code:
            issues.append(contentsOf: validateCode(input))
        case .command:
            issues.append(contentsOf: validateCommand(input))
        case .query:
            issues.append(contentsOf: validateQuery(input))
        case .path:
            issues.append(contentsOf: validatePath(input))
        case .general:
            break
        }

        return InputValidationResult(
            isValid: issues.filter { $0.severity >= .warning }.isEmpty,
            issues: issues
        )
    }

    /// Get prevention advice for a specific action
    public func getPreventionAdvice(for action: String) -> [String] {
        var advice: [String] = []

        // Check action-specific patterns
        for pattern in errorPatterns where pattern.triggerActions.contains(action) {
            advice.append("⚠️ \(pattern.preventionTip)")
        }

        return advice
    }

    // MARK: - Private Methods

    private func assessRisk(context: ErrorContext, pattern: ErrorPattern) -> RiskAssessment? {
        // Check if context matches pattern triggers
        let matchScore = calculateMatchScore(context: context, pattern: pattern)

        guard matchScore > 0.5 else { return nil }

        return RiskAssessment(
            id: UUID(),
            pattern: pattern,
            context: context,
            probability: matchScore,
            severity: pattern.severity,
            suggestedPrevention: pattern.preventionTip
        )
    }

    private func calculateMatchScore(context: ErrorContext, pattern: ErrorPattern) -> Double {
        var score = 0.0
        var factors = 0

        // Check action match
        if pattern.triggerActions.contains(context.currentAction) {
            score += 1.0
            factors += 1
        }

        // Check time-based patterns
        let hour = Calendar.current.component(.hour, from: Date())
        if pattern.riskHours.contains(hour) {
            score += 0.3
            factors += 1
        }

        // Check context keywords
        let contextWords = context.additionalContext.lowercased().split(separator: " ")
        let matchingWords = pattern.contextKeywords.filter { keyword in
            contextWords.contains { $0.contains(keyword.lowercased()) }
        }
        if !matchingWords.isEmpty {
            score += Double(matchingWords.count) * 0.2
            factors += 1
        }

        return factors > 0 ? score / Double(factors) : 0
    }

    private func checkCommonMistakes(_ context: ErrorContext) -> [RiskAssessment] {
        var risks: [RiskAssessment] = []

        // Check for potentially dangerous commands
        if context.currentAction.contains("delete") || context.currentAction.contains("remove") {
            risks.append(RiskAssessment(
                id: UUID(),
                pattern: ErrorPattern(
                    id: UUID(),
                    name: "Destructive Action",
                    description: "Potentially destructive action detected",
                    triggerActions: ["delete", "remove", "drop"],
                    contextKeywords: [],
                    severity: .high,
                    preventionTip: "Make sure to backup before proceeding",
                    riskHours: []
                ),
                context: context,
                probability: 0.8,
                severity: .high,
                suggestedPrevention: "Consider creating a backup before this action"
            ))
        }

        // Check for late-night work (higher error rate)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 23 || hour <= 5 {
            risks.append(RiskAssessment(
                id: UUID(),
                pattern: ErrorPattern(
                    id: UUID(),
                    name: "Late Night Work",
                    description: "Working during high-fatigue hours",
                    triggerActions: [],
                    contextKeywords: [],
                    severity: .low,
                    preventionTip: "Consider reviewing changes tomorrow",
                    riskHours: [23, 0, 1, 2, 3, 4, 5]
                ),
                context: context,
                probability: 0.6,
                severity: .low,
                suggestedPrevention: "Late-night changes have higher error rates. Consider a final review."
            ))
        }

        return risks
    }

    private func validateCode(_ code: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for common code issues
        if code.contains("TODO") || code.contains("FIXME") {
            issues.append(ValidationIssue(
                type: .incomplete,
                severity: .info,
                message: "Code contains TODO/FIXME markers",
                suggestion: "Address marked items before proceeding"
            ))
        }

        if code.contains("print(") && !code.contains("logger") {
            issues.append(ValidationIssue(
                type: .style,
                severity: .info,
                message: "Using print statements",
                suggestion: "Consider using a proper logging framework"
            ))
        }

        // Check for potential security issues
        if code.contains("password") && code.contains("=") && !code.contains("hash") {
            issues.append(ValidationIssue(
                type: .security,
                severity: .warning,
                message: "Possible hardcoded password",
                suggestion: "Use secure credential storage"
            ))
        }

        return issues
    }

    private func validateCommand(_ command: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for dangerous commands
        let dangerousPatterns = ["rm -rf", "sudo", "> /dev/", "chmod 777"]
        for pattern in dangerousPatterns where command.contains(pattern) {
            issues.append(ValidationIssue(
                type: .danger,
                severity: .error,
                message: "Potentially dangerous command: \(pattern)",
                suggestion: "Review command carefully before execution"
            ))
        }

        return issues
    }

    private func validateQuery(_ query: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for ambiguous queries
        if query.split(separator: " ").count < 3 {
            issues.append(ValidationIssue(
                type: .ambiguous,
                severity: .info,
                message: "Query may be too brief",
                suggestion: "Add more context for better results"
            ))
        }

        return issues
    }

    private func validatePath(_ path: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Check for system paths
        let protectedPaths = ["/System", "/Library", "/bin", "/sbin", "/usr"]
        for protected in protectedPaths where path.hasPrefix(protected) {
            issues.append(ValidationIssue(
                type: .security,
                severity: .warning,
                message: "Path is in protected system directory",
                suggestion: "System paths require elevated permissions"
            ))
        }

        return issues
    }

    private func learnFromError(_ error: RecordedError) {
        // Check if this matches an existing pattern
        for index in errorPatterns.indices {
            if errorPatterns[index].name == error.type {
                errorPatterns[index].occurrenceCount += 1
                return
            }
        }

        // Create new pattern if error occurs frequently
        let similarErrors = errorHistory.filter { $0.type == error.type }
        if similarErrors.count >= 3 {
            let newPattern = ErrorPattern(
                id: UUID(),
                name: error.type,
                description: "Learned from \(similarErrors.count) occurrences",
                triggerActions: [error.context],
                contextKeywords: [],
                severity: .medium,
                preventionTip: "Be careful with this action - errors have occurred here before",
                riskHours: [],
                occurrenceCount: similarErrors.count
            )
            errorPatterns.append(newPattern)
            logger.info("Learned new error pattern: \(error.type)")
        }
    }

    private func generatePreventionSuggestion(for risk: RiskAssessment) -> PreventionSuggestion {
        PreventionSuggestion(
            id: UUID(),
            risk: risk,
            message: risk.suggestedPrevention,
            actions: ["Review", "Proceed Anyway", "Cancel"],
            autoPreventable: risk.severity <= .medium
        )
    }

    private func loadErrorPatterns() {
        if let data = UserDefaults.standard.data(forKey: "ErrorPatterns"),
           let decoded = try? JSONDecoder().decode([ErrorPattern].self, from: data) {
            errorPatterns = decoded
        }
    }

    private func saveErrorPatterns() {
        if let encoded = try? JSONEncoder().encode(errorPatterns) {
            UserDefaults.standard.set(encoded, forKey: "ErrorPatterns")
        }
    }

    private func loadDefaultPatterns() {
        guard errorPatterns.isEmpty else { return }

        errorPatterns = [
            ErrorPattern(
                id: UUID(),
                name: "Missing Backup",
                description: "Destructive action without recent backup",
                triggerActions: ["delete", "overwrite", "reset"],
                contextKeywords: ["database", "production", "main"],
                severity: .high,
                preventionTip: "Create a backup before proceeding",
                riskHours: []
            ),
            ErrorPattern(
                id: UUID(),
                name: "Rushed Decision",
                description: "Quick succession of major changes",
                triggerActions: ["commit", "deploy", "publish"],
                contextKeywords: ["quick", "fast", "hurry"],
                severity: .medium,
                preventionTip: "Take a moment to review before proceeding",
                riskHours: []
            ),
            ErrorPattern(
                id: UUID(),
                name: "Untested Change",
                description: "Code changes without running tests",
                triggerActions: ["commit", "push", "deploy"],
                contextKeywords: ["fix", "patch", "quick"],
                severity: .medium,
                preventionTip: "Run tests before committing",
                riskHours: []
            )
        ]

        saveErrorPatterns()
    }
}

// MARK: - Supporting Types

public struct PreventionConfiguration: Sendable {
    public var enableRealTimeValidation: Bool = true
    public var enableLateNightWarnings: Bool = true
    public var riskThreshold: RiskSeverity = .medium

    public init() {}
}

public struct ErrorPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var triggerActions: [String]
    public var contextKeywords: [String]
    public var severity: RiskSeverity
    public var preventionTip: String
    public var riskHours: [Int]
    public var occurrenceCount: Int = 0
}

public struct RecordedError: Sendable {
    public let type: String
    public let message: String
    public let context: String
    public let timestamp: Date
    public let wasRecovered: Bool

    public init(type: String, message: String, context: String, timestamp: Date = Date(), wasRecovered: Bool = false) {
        self.type = type
        self.message = message
        self.context = context
        self.timestamp = timestamp
        self.wasRecovered = wasRecovered
    }
}

public struct ErrorContext: Sendable {
    public let currentAction: String
    public let previousActions: [String]
    public let additionalContext: String
    public let timestamp: Date

    public init(currentAction: String, previousActions: [String] = [], additionalContext: String = "") {
        self.currentAction = currentAction
        self.previousActions = previousActions
        self.additionalContext = additionalContext
        self.timestamp = Date()
    }
}

public struct RiskAssessment: Identifiable, Sendable {
    public let id: UUID
    public let pattern: ErrorPattern
    public let context: ErrorContext
    public let probability: Double
    public let severity: RiskSeverity
    public let suggestedPrevention: String
}

public enum RiskSeverity: Int, Codable, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    public static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct PreventionSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let risk: RiskAssessment
    public let message: String
    public let actions: [String]
    public let autoPreventable: Bool
}

public struct InputValidationResult: Sendable {
    public let isValid: Bool
    public let issues: [ValidationIssue]
}

public struct ValidationIssue: Sendable {
    public let type: IssueType
    public let severity: IssueSeverity
    public let message: String
    public let suggestion: String

    public enum IssueType: String, Sendable {
        case syntax
        case security
        case style
        case incomplete
        case ambiguous
        case danger
    }

    public enum IssueSeverity: Int, Sendable, Comparable {
        case info = 0
        case warning = 1
        case error = 2

        public static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

public enum InputType: String, Sendable {
    case code
    case command
    case query
    case path
    case general
}
