import Foundation

// MARK: - Hypothesis Testing Engine

// Implements scientific method for hypothesis generation, testing, and validation

/// A hypothesis that can be tested
public struct Hypothesis: Sendable, Codable, Identifiable {
    public let id: UUID
    public let statement: String
    public let type: HypothesisType
    public var status: HypothesisStatus
    public var confidence: Double
    public var supportingEvidence: [Evidence]
    public var contradictingEvidence: [Evidence]
    public let createdAt: Date
    public var testedAt: Date?

    public enum HypothesisType: String, Codable, Sendable {
        case causal // X causes Y
        case correlational // X is related to Y
        case predictive // If X then Y
        case descriptive // X has property Y
        case explanatory // X explains Y
    }

    public enum HypothesisStatus: String, Codable, Sendable {
        case proposed // Initial hypothesis
        case testing // Currently being tested
        case supported // Evidence supports it
        case refuted // Evidence contradicts it
        case inconclusive // Mixed evidence
        case modified // Revised based on evidence
    }

    public init(
        id: UUID = UUID(),
        statement: String,
        type: HypothesisType = .predictive,
        status: HypothesisStatus = .proposed,
        confidence: Double = 0.5,
        supportingEvidence: [Evidence] = [],
        contradictingEvidence: [Evidence] = [],
        createdAt: Date = Date(),
        testedAt: Date? = nil
    ) {
        self.id = id
        self.statement = statement
        self.type = type
        self.status = status
        self.confidence = confidence
        self.supportingEvidence = supportingEvidence
        self.contradictingEvidence = contradictingEvidence
        self.createdAt = createdAt
        self.testedAt = testedAt
    }

    /// Calculate evidence ratio
    public var evidenceRatio: Double {
        let supporting = Double(supportingEvidence.count)
        let contradicting = Double(contradictingEvidence.count)
        guard supporting + contradicting > 0 else { return 0.5 }
        return supporting / (supporting + contradicting)
    }

    /// Calculate weighted evidence score
    public var weightedScore: Double {
        let supportingWeight = supportingEvidence.reduce(0.0) { $0 + $1.weight * $1.reliability }
        let contradictingWeight = contradictingEvidence.reduce(0.0) { $0 + $1.weight * $1.reliability }
        let total = supportingWeight + contradictingWeight
        guard total > 0 else { return 0.5 }
        return supportingWeight / total
    }
}

/// Evidence supporting or contradicting a hypothesis
public struct Evidence: Sendable, Codable, Identifiable {
    public let id: UUID
    public let description: String
    public let source: String
    public let type: EvidenceType
    public let weight: Double // 0-1, importance of evidence
    public let reliability: Double // 0-1, trustworthiness of source
    public let timestamp: Date

    public enum EvidenceType: String, Codable, Sendable {
        case observation // Direct observation
        case experiment // Experimental result
        case analysis // Data analysis
        case inference // Logical inference
        case testimony // External source
        case simulation // Simulated result
    }

    public init(
        id: UUID = UUID(),
        description: String,
        source: String,
        type: EvidenceType = .observation,
        weight: Double = 0.5,
        reliability: Double = 0.8,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.description = description
        self.source = source
        self.type = type
        self.weight = weight
        self.reliability = reliability
        self.timestamp = timestamp
    }
}

/// Test plan for validating a hypothesis
public struct TestPlan: Sendable, Codable, Identifiable {
    public let id: UUID
    public let hypothesis: Hypothesis
    public var tests: [Test]
    public var status: TestStatus
    public let createdAt: Date

    public enum TestStatus: String, Codable, Sendable {
        case planned
        case inProgress
        case completed
        case cancelled
    }

    public init(
        id: UUID = UUID(),
        hypothesis: Hypothesis,
        tests: [Test] = [],
        status: TestStatus = .planned,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.hypothesis = hypothesis
        self.tests = tests
        self.status = status
        self.createdAt = createdAt
    }
}

/// A single test within a test plan
public struct Test: Sendable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let expectedOutcome: String
    public var actualOutcome: String?
    public var passed: Bool?
    public var notes: String?
    public let createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        expectedOutcome: String,
        actualOutcome: String? = nil,
        passed: Bool? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.expectedOutcome = expectedOutcome
        self.actualOutcome = actualOutcome
        self.passed = passed
        self.notes = notes
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// Result of hypothesis testing
public struct HypothesisTestResult: Sendable {
    public let hypothesis: Hypothesis
    public let verdict: Verdict
    public let confidence: Double
    public let supportingEvidenceCount: Int
    public let contradictingEvidenceCount: Int
    public let testsRun: Int
    public let testsPassed: Int
    public let summary: String
    public let recommendations: [String]

    public enum Verdict: String, Sendable {
        case stronglySupported = "Strongly Supported"
        case supported = "Supported"
        case inconclusive = "Inconclusive"
        case weaklyRefuted = "Weakly Refuted"
        case stronglyRefuted = "Strongly Refuted"
    }

    public init(
        hypothesis: Hypothesis,
        verdict: Verdict,
        confidence: Double,
        supportingEvidenceCount: Int,
        contradictingEvidenceCount: Int,
        testsRun: Int,
        testsPassed: Int,
        summary: String,
        recommendations: [String]
    ) {
        self.hypothesis = hypothesis
        self.verdict = verdict
        self.confidence = confidence
        self.supportingEvidenceCount = supportingEvidenceCount
        self.contradictingEvidenceCount = contradictingEvidenceCount
        self.testsRun = testsRun
        self.testsPassed = testsPassed
        self.summary = summary
        self.recommendations = recommendations
    }
}

/// Hypothesis Testing Engine for scientific reasoning
@MainActor
@Observable
public final class HypothesisTestingEngine {
    public static let shared = HypothesisTestingEngine()

    private(set) var hypotheses: [Hypothesis] = []
    private(set) var testPlans: [TestPlan] = []
    private(set) var testResults: [HypothesisTestResult] = []
    private(set) var isProcessing = false

    private init() {}

    // MARK: - Hypothesis Management

    /// Generate hypotheses for a given observation or question
    public func generateHypotheses(for observation: String) async throws -> [Hypothesis] {
        isProcessing = true
        defer { isProcessing = false }

        // Generate multiple hypotheses to explain the observation
        let generated = [
            Hypothesis(
                statement: "The observation '\(observation)' is caused by direct factors",
                type: .causal,
                confidence: 0.6
            ),
            Hypothesis(
                statement: "The observation '\(observation)' correlates with related phenomena",
                type: .correlational,
                confidence: 0.5
            ),
            Hypothesis(
                statement: "If certain conditions are met, '\(observation)' will occur predictably",
                type: .predictive,
                confidence: 0.55
            )
        ]

        for h in generated {
            hypotheses.append(h)
        }

        return generated
    }

    /// Add supporting evidence to a hypothesis
    public func addSupportingEvidence(_ evidence: Evidence, to hypothesisId: UUID) {
        guard let index = hypotheses.firstIndex(where: { $0.id == hypothesisId }) else { return }
        hypotheses[index].supportingEvidence.append(evidence)
        updateHypothesisStatus(at: index)
    }

    /// Add contradicting evidence to a hypothesis
    public func addContradictingEvidence(_ evidence: Evidence, to hypothesisId: UUID) {
        guard let index = hypotheses.firstIndex(where: { $0.id == hypothesisId }) else { return }
        hypotheses[index].contradictingEvidence.append(evidence)
        updateHypothesisStatus(at: index)
    }

    private func updateHypothesisStatus(at index: Int) {
        let score = hypotheses[index].weightedScore

        if score >= 0.8 {
            hypotheses[index].status = .supported
            hypotheses[index].confidence = score
        } else if score <= 0.2 {
            hypotheses[index].status = .refuted
            hypotheses[index].confidence = 1.0 - score
        } else {
            hypotheses[index].status = .inconclusive
            hypotheses[index].confidence = 0.5
        }
    }

    // MARK: - Test Planning

    /// Create a test plan for a hypothesis
    public func createTestPlan(for hypothesis: Hypothesis) -> TestPlan {
        var tests: [Test] = []

        switch hypothesis.type {
        case .causal:
            tests = [
                Test(name: "Causation Test", description: "Verify causal relationship", expectedOutcome: "Direct cause identified"),
                Test(name: "Control Test", description: "Test without proposed cause", expectedOutcome: "Effect should not occur"),
                Test(name: "Dose Response", description: "Test varying intensity", expectedOutcome: "Proportional effect")
            ]
        case .correlational:
            tests = [
                Test(name: "Correlation Analysis", description: "Statistical correlation", expectedOutcome: "Significant correlation"),
                Test(name: "Confounding Check", description: "Check for confounders", expectedOutcome: "No major confounders"),
                Test(name: "Temporal Analysis", description: "Check temporal relationship", expectedOutcome: "Consistent temporal pattern")
            ]
        case .predictive:
            tests = [
                Test(name: "Prediction Test", description: "Test prediction accuracy", expectedOutcome: "Prediction confirmed"),
                Test(name: "Edge Case Test", description: "Test boundary conditions", expectedOutcome: "Handles edge cases"),
                Test(name: "Repeatability", description: "Test prediction consistency", expectedOutcome: "Consistent results")
            ]
        case .descriptive, .explanatory:
            tests = [
                Test(name: "Description Accuracy", description: "Verify description", expectedOutcome: "Accurate description"),
                Test(name: "Completeness Check", description: "Check for gaps", expectedOutcome: "Complete coverage")
            ]
        }

        let plan = TestPlan(hypothesis: hypothesis, tests: tests)
        testPlans.append(plan)
        return plan
    }

    // MARK: - Testing

    /// Execute tests and evaluate hypothesis
    public func testHypothesis(_ hypothesis: Hypothesis) async throws -> HypothesisTestResult {
        isProcessing = true
        defer { isProcessing = false }

        // Get or create test plan
        let plan = testPlans.first { $0.hypothesis.id == hypothesis.id } ?? createTestPlan(for: hypothesis)

        // Execute tests (simulated)
        var passedTests = 0
        for _ in plan.tests {
            // In production, this would execute actual tests
            let passed = Double.random(in: 0 ... 1) > 0.3 // Simulation
            if passed { passedTests += 1 }
        }

        // Calculate verdict
        let testScore = Double(passedTests) / Double(plan.tests.count)
        let evidenceScore = hypothesis.weightedScore
        let combinedScore = (testScore + evidenceScore) / 2

        let verdict: HypothesisTestResult.Verdict = if combinedScore >= 0.8 {
            .stronglySupported
        } else if combinedScore >= 0.6 {
            .supported
        } else if combinedScore >= 0.4 {
            .inconclusive
        } else if combinedScore >= 0.2 {
            .weaklyRefuted
        } else {
            .stronglyRefuted
        }

        // Generate recommendations
        var recommendations: [String] = []
        if combinedScore < 0.6 {
            recommendations.append("Gather more evidence to strengthen or refute the hypothesis")
        }
        if passedTests < plan.tests.count {
            recommendations.append("Investigate why some tests failed")
        }
        if hypothesis.supportingEvidence.isEmpty {
            recommendations.append("Collect supporting evidence from multiple sources")
        }

        let result = HypothesisTestResult(
            hypothesis: hypothesis,
            verdict: verdict,
            confidence: combinedScore,
            supportingEvidenceCount: hypothesis.supportingEvidence.count,
            contradictingEvidenceCount: hypothesis.contradictingEvidence.count,
            testsRun: plan.tests.count,
            testsPassed: passedTests,
            summary: "Hypothesis '\(hypothesis.statement)' is \(verdict.rawValue) with \(String(format: "%.0f%%", combinedScore * 100)) confidence",
            recommendations: recommendations
        )

        testResults.append(result)

        // Update hypothesis status
        if let index = hypotheses.firstIndex(where: { $0.id == hypothesis.id }) {
            hypotheses[index].status = combinedScore >= 0.6 ? .supported : combinedScore <= 0.4 ? .refuted : .inconclusive
            hypotheses[index].confidence = combinedScore
            hypotheses[index].testedAt = Date()
        }

        return result
    }

    // MARK: - Bayesian Update

    /// Update hypothesis confidence using Bayesian reasoning
    public func bayesianUpdate(hypothesisId: UUID, newEvidence: Evidence, likelihoodRatio: Double) {
        guard let index = hypotheses.firstIndex(where: { $0.id == hypothesisId }) else { return }

        let priorOdds = hypotheses[index].confidence / (1 - hypotheses[index].confidence)
        let posteriorOdds = priorOdds * likelihoodRatio
        let posteriorProbability = posteriorOdds / (1 + posteriorOdds)

        hypotheses[index].confidence = min(max(posteriorProbability, 0.01), 0.99)

        if likelihoodRatio > 1 {
            hypotheses[index].supportingEvidence.append(newEvidence)
        } else {
            hypotheses[index].contradictingEvidence.append(newEvidence)
        }

        updateHypothesisStatus(at: index)
    }
}
