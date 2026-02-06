import Foundation

// MARK: - Logical Inference Engine

// Implements formal logical reasoning with propositions, rules, and inference chains

/// A logical proposition that can be true, false, or unknown
public struct Proposition: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public let statement: String
    public var truthValue: TruthValue
    public var confidence: Double
    public var source: PropositionSource

    public enum TruthValue: String, Codable, Sendable {
        case `true`
        case `false`
        case unknown
        case contradictory
    }

    public enum PropositionSource: String, Codable, Sendable {
        case premise // Given as input
        case derived // Derived through inference
        case assumption // Assumed for reasoning
        case contradiction // Result of contradiction detection
    }

    public init(
        id: UUID = UUID(),
        statement: String,
        truthValue: TruthValue = .unknown,
        confidence: Double = 0.5,
        source: PropositionSource = .premise
    ) {
        self.id = id
        self.statement = statement
        self.truthValue = truthValue
        self.confidence = confidence
        self.source = source
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Proposition, rhs: Proposition) -> Bool {
        lhs.id == rhs.id
    }
}

/// An inference rule that derives new propositions from existing ones
public struct InferenceRule: Sendable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let premises: [String] // Pattern templates for matching
    public let conclusion: String // Pattern template for conclusion
    public let ruleType: RuleType

    public enum RuleType: String, Codable, Sendable, CaseIterable {
        case modusPonens // If P and P→Q, then Q
        case modusTollens // If ¬Q and P→Q, then ¬P
        case hypotheticalSyllogism // If P→Q and Q→R, then P→R
        case disjunctiveSyllogism // If P∨Q and ¬P, then Q
        case constructiveDilemma // If (P→Q)∧(R→S) and P∨R, then Q∨S
        case conjunction // If P and Q, then P∧Q
        case simplification // If P∧Q, then P
        case addition // If P, then P∨Q
        case custom // User-defined rule

        public var displayName: String {
            switch self {
            case .modusPonens: "Modus Ponens"
            case .modusTollens: "Modus Tollens"
            case .hypotheticalSyllogism: "Hypothetical Syllogism"
            case .disjunctiveSyllogism: "Disjunctive Syllogism"
            case .constructiveDilemma: "Constructive Dilemma"
            case .conjunction: "Conjunction"
            case .simplification: "Simplification"
            case .addition: "Addition"
            case .custom: "Custom Rule"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        premises: [String],
        conclusion: String,
        ruleType: RuleType
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.premises = premises
        self.conclusion = conclusion
        self.ruleType = ruleType
    }
}

/// A single inference step showing how a conclusion was derived
public struct InferenceStep: Sendable, Codable, Identifiable {
    public let id: UUID
    public let stepNumber: Int
    public let premises: [Proposition]
    public let rule: InferenceRule
    public let conclusion: Proposition
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        premises: [Proposition],
        rule: InferenceRule,
        conclusion: Proposition,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.premises = premises
        self.rule = rule
        self.conclusion = conclusion
        self.timestamp = timestamp
    }
}

/// Result of a logical inference process
public struct InferenceResult: Sendable {
    public let query: String
    public let conclusion: Proposition
    public let steps: [InferenceStep]
    public let isValid: Bool
    public let confidence: Double
    public let contradictionsFound: [String]
    public let duration: TimeInterval

    public init(
        query: String,
        conclusion: Proposition,
        steps: [InferenceStep],
        isValid: Bool,
        confidence: Double,
        contradictionsFound: [String] = [],
        duration: TimeInterval
    ) {
        self.query = query
        self.conclusion = conclusion
        self.steps = steps
        self.isValid = isValid
        self.confidence = confidence
        self.contradictionsFound = contradictionsFound
        self.duration = duration
    }
}

/// Logical Inference Engine for formal reasoning
@MainActor
@Observable
public final class LogicalInferenceEngine {
    public static let shared = LogicalInferenceEngine()

    private(set) var knowledgeBase: [Proposition] = []
    private(set) var rules: [InferenceRule] = []
    private(set) var inferenceHistory: [InferenceResult] = []
    private(set) var isProcessing = false

    private init() {
        setupDefaultRules()
    }

    // MARK: - Knowledge Base Management

    public func addProposition(_ proposition: Proposition) {
        // Check for contradictions
        if let existing = knowledgeBase.first(where: { $0.statement == proposition.statement }) {
            if existing.truthValue != proposition.truthValue,
               existing.truthValue != .unknown,
               proposition.truthValue != .unknown
            {
                // Contradiction detected
                var contradicted = proposition
                contradicted.truthValue = .contradictory
                knowledgeBase.append(contradicted)
                return
            }
        }
        knowledgeBase.append(proposition)
    }

    public func removeProposition(_ id: UUID) {
        knowledgeBase.removeAll { $0.id == id }
    }

    public func clearKnowledgeBase() {
        knowledgeBase.removeAll()
    }

    // MARK: - Rule Management

    public func addRule(_ rule: InferenceRule) {
        rules.append(rule)
    }

    private func setupDefaultRules() {
        // Modus Ponens: If P and P→Q, then Q
        rules.append(InferenceRule(
            name: "Modus Ponens",
            description: "If P is true and P implies Q, then Q is true",
            premises: ["P", "P → Q"],
            conclusion: "Q",
            ruleType: .modusPonens
        ))

        // Modus Tollens: If ¬Q and P→Q, then ¬P
        rules.append(InferenceRule(
            name: "Modus Tollens",
            description: "If Q is false and P implies Q, then P is false",
            premises: ["¬Q", "P → Q"],
            conclusion: "¬P",
            ruleType: .modusTollens
        ))

        // Hypothetical Syllogism: If P→Q and Q→R, then P→R
        rules.append(InferenceRule(
            name: "Hypothetical Syllogism",
            description: "If P implies Q and Q implies R, then P implies R",
            premises: ["P → Q", "Q → R"],
            conclusion: "P → R",
            ruleType: .hypotheticalSyllogism
        ))

        // Disjunctive Syllogism: If P∨Q and ¬P, then Q
        rules.append(InferenceRule(
            name: "Disjunctive Syllogism",
            description: "If P or Q is true and P is false, then Q is true",
            premises: ["P ∨ Q", "¬P"],
            conclusion: "Q",
            ruleType: .disjunctiveSyllogism
        ))
    }

    // MARK: - Inference

    /// Perform logical inference to derive a conclusion
    public func infer(query: String) async throws -> InferenceResult {
        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()
        var steps: [InferenceStep] = []
        var derivedPropositions: [Proposition] = []
        var contradictions: [String] = []

        // Forward chaining: Apply rules to derive new facts
        var changed = true
        var iterationCount = 0
        let maxIterations = 100

        while changed, iterationCount < maxIterations {
            changed = false
            iterationCount += 1

            for rule in rules {
                if let derivation = tryApplyRule(rule, to: knowledgeBase + derivedPropositions) {
                    let step = InferenceStep(
                        stepNumber: steps.count + 1,
                        premises: derivation.premises,
                        rule: rule,
                        conclusion: derivation.conclusion
                    )
                    steps.append(step)
                    derivedPropositions.append(derivation.conclusion)
                    changed = true

                    // Check for contradictions
                    if derivation.conclusion.truthValue == .contradictory {
                        contradictions.append(derivation.conclusion.statement)
                    }
                }
            }
        }

        // Find the most relevant conclusion for the query
        let allPropositions = knowledgeBase + derivedPropositions
        let conclusion = findBestConclusion(for: query, in: allPropositions)

        let duration = Date().timeIntervalSince(startTime)
        let confidence = calculateConfidence(for: conclusion, steps: steps)

        let result = InferenceResult(
            query: query,
            conclusion: conclusion,
            steps: steps,
            isValid: contradictions.isEmpty,
            confidence: confidence,
            contradictionsFound: contradictions,
            duration: duration
        )

        inferenceHistory.append(result)
        return result
    }

    // MARK: - Private Helpers

    private func tryApplyRule(_ rule: InferenceRule, to propositions: [Proposition]) -> (premises: [Proposition], conclusion: Proposition)? {
        // Simplified rule application - in production would use pattern matching
        // This is a demonstration implementation

        switch rule.ruleType {
        case .modusPonens:
            // Look for P and P→Q patterns
            for p in propositions where p.truthValue == .true {
                for impl in propositions where impl.statement.contains("→") && impl.statement.hasPrefix(p.statement) {
                    let parts = impl.statement.components(separatedBy: " → ")
                    if parts.count == 2, parts[0] == p.statement {
                        let conclusionStatement = parts[1]
                        // Check if conclusion already exists
                        if !propositions.contains(where: { $0.statement == conclusionStatement && $0.truthValue == .true }) {
                            let conclusion = Proposition(
                                statement: conclusionStatement,
                                truthValue: .true,
                                confidence: min(p.confidence, 0.9),
                                source: .derived
                            )
                            return ([p, impl], conclusion)
                        }
                    }
                }
            }

        case .modusTollens:
            // Look for ¬Q and P→Q patterns
            for notQ in propositions where notQ.truthValue == .false || notQ.statement.hasPrefix("¬") {
                let qStatement = notQ.statement.hasPrefix("¬") ?
                    String(notQ.statement.dropFirst()) : notQ.statement

                for impl in propositions where impl.statement.contains("→") && impl.statement.hasSuffix(qStatement) {
                    let parts = impl.statement.components(separatedBy: " → ")
                    if parts.count == 2, parts[1] == qStatement {
                        let conclusionStatement = "¬\(parts[0])"
                        if !propositions.contains(where: { $0.statement == conclusionStatement }) {
                            let conclusion = Proposition(
                                statement: conclusionStatement,
                                truthValue: .true,
                                confidence: min(notQ.confidence, 0.9),
                                source: .derived
                            )
                            return ([notQ, impl], conclusion)
                        }
                    }
                }
            }

        default:
            break
        }

        return nil
    }

    private func findBestConclusion(for query: String, in propositions: [Proposition]) -> Proposition {
        // Find proposition most relevant to query
        let queryWords = Set(query.lowercased().components(separatedBy: .whitespaces))

        var bestMatch: Proposition?
        var bestScore = 0

        for prop in propositions {
            let propWords = Set(prop.statement.lowercased().components(separatedBy: .whitespaces))
            let overlap = queryWords.intersection(propWords).count
            if overlap > bestScore {
                bestScore = overlap
                bestMatch = prop
            }
        }

        return bestMatch ?? Proposition(
            statement: "No conclusion could be derived for: \(query)",
            truthValue: .unknown,
            confidence: 0.0,
            source: .derived
        )
    }

    private func calculateConfidence(for conclusion: Proposition, steps: [InferenceStep]) -> Double {
        if steps.isEmpty {
            return conclusion.confidence
        }

        // Confidence decreases with each inference step
        let stepPenalty = 0.95
        var confidence = conclusion.confidence

        for step in steps where step.conclusion.id == conclusion.id {
            confidence *= stepPenalty
        }

        return max(confidence, 0.1)
    }
}
