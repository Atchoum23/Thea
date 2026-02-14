// SubagentAndToolCompositionTypesTests.swift
// Tests for SubagentDefinition + ToolComposition types (standalone test doubles)

import Testing
import Foundation

// MARK: - Subagent Test Doubles

private enum TestSubagentModel: Sendable {
    case inherit
    case specific(String)
    case fast
    case reasoning

    var displayName: String {
        switch self {
        case .inherit: "Inherit from parent"
        case .specific(let model): model
        case .fast: "Fast model"
        case .reasoning: "Reasoning model"
        }
    }
}

private enum TestSubagentTools: Sendable {
    case all
    case readOnly
    case specific([String])
    case except([String])

    var displayName: String {
        switch self {
        case .all: "All tools"
        case .readOnly: "Read-only"
        case .specific(let tools): "\(tools.count) specific tools"
        case .except(let tools): "All except \(tools.count)"
        }
    }
}

private enum TestSubagentExecutionMode: String, Sendable, CaseIterable {
    case foreground, background, parallel

    var displayName: String {
        switch self {
        case .foreground: "Foreground"
        case .background: "Background"
        case .parallel: "Parallel"
        }
    }
}

private enum TestSubagentScope: String, Sendable, CaseIterable {
    case builtin, global, workspace
}

private enum TestSubagentThoroughness: String, Sendable, CaseIterable {
    case quick, medium, veryThorough

    var displayName: String {
        switch self {
        case .quick: "Quick"
        case .medium: "Medium"
        case .veryThorough: "Very Thorough"
        }
    }

    var description: String {
        switch self {
        case .quick: "Basic searches and targeted lookups"
        case .medium: "Balanced exploration with moderate depth"
        case .veryThorough: "Comprehensive analysis across multiple locations and naming conventions"
        }
    }
}

private struct TestSubagentDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let systemPrompt: String
    let model: TestSubagentModel
    let tools: TestSubagentTools
    let executionMode: TestSubagentExecutionMode
    let scope: TestSubagentScope
    let thoroughness: TestSubagentThoroughness?

    init(
        id: String, name: String, description: String, systemPrompt: String,
        model: TestSubagentModel = .inherit, tools: TestSubagentTools = .all,
        executionMode: TestSubagentExecutionMode = .foreground,
        scope: TestSubagentScope = .builtin, thoroughness: TestSubagentThoroughness? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.model = model
        self.tools = tools
        self.executionMode = executionMode
        self.scope = scope
        self.thoroughness = thoroughness
    }
}

private struct TestSubagentExecutionContext: Sendable {
    let parentConversationId: String?
    let taskDescription: String
    let thoroughness: TestSubagentThoroughness
    let maxTurns: Int
    let timeout: TimeInterval

    init(
        parentConversationId: String? = nil, taskDescription: String,
        thoroughness: TestSubagentThoroughness = .medium,
        maxTurns: Int = 10, timeout: TimeInterval = 300
    ) {
        self.parentConversationId = parentConversationId
        self.taskDescription = taskDescription
        self.thoroughness = thoroughness
        self.maxTurns = maxTurns
        self.timeout = timeout
    }
}

private struct TestSubagentResult: Sendable {
    let subagentId: String
    let success: Bool
    let output: String
    let turnsUsed: Int
    let duration: TimeInterval
    let error: String?

    init(
        subagentId: String, success: Bool, output: String,
        turnsUsed: Int = 0, duration: TimeInterval = 0, error: String? = nil
    ) {
        self.subagentId = subagentId
        self.success = success
        self.output = output
        self.turnsUsed = turnsUsed
        self.duration = duration
        self.error = error
    }
}

// MARK: - Tool Composition Test Doubles

private enum TestParameterType: String, Sendable, CaseIterable {
    case string, number, boolean, array, object, file, any
}

private enum TestToolCategory: String, Sendable, CaseIterable {
    case fileSystem, codeAnalysis, webSearch, execution, communication, ai, utility
}

private enum TestPermission: String, Sendable, CaseIterable {
    case readFile, writeFile, executeCode, networkAccess, systemAccess
}

private struct TestParameterSchema: Sendable {
    let name: String
    let type: TestParameterType
    let isRequired: Bool
    let defaultValue: String?
    let description: String

    init(name: String, type: TestParameterType, isRequired: Bool = true,
         defaultValue: String? = nil, description: String = "") {
        self.name = name
        self.type = type
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.description = description
    }
}

private struct TestComposableTool: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let category: TestToolCategory
    let inputSchema: [TestParameterSchema]
    let outputSchema: [TestParameterSchema]
    let isIdempotent: Bool
    let isCacheable: Bool
    let estimatedDuration: TimeInterval
    let requiredPermissions: Set<TestPermission>

    init(
        id: String, name: String, description: String, category: TestToolCategory,
        inputSchema: [TestParameterSchema] = [], outputSchema: [TestParameterSchema] = [],
        isIdempotent: Bool = false, isCacheable: Bool = false,
        estimatedDuration: TimeInterval = 1.0, requiredPermissions: Set<TestPermission> = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.isIdempotent = isIdempotent
        self.isCacheable = isCacheable
        self.estimatedDuration = estimatedDuration
        self.requiredPermissions = requiredPermissions
    }
}

private enum TestErrorHandlingStrategy: String, Sendable, CaseIterable {
    case stopOnError, continueOnError, retryThenContinue, fallbackStep
}

private struct TestToolRetryPolicy: Sendable {
    let maxRetries: Int
    let delaySeconds: Double
    let backoffMultiplier: Double

    static let `default` = TestToolRetryPolicy(maxRetries: 2, delaySeconds: 1.0, backoffMultiplier: 2.0)
    static let none = TestToolRetryPolicy(maxRetries: 0, delaySeconds: 0, backoffMultiplier: 1.0)
    static let aggressive = TestToolRetryPolicy(maxRetries: 5, delaySeconds: 0.5, backoffMultiplier: 1.5)
}

private struct TestStepResult: Sendable {
    let stepId: UUID
    let success: Bool
    let outputs: [String: String]
    let duration: TimeInterval
    let retryCount: Int
    let error: String?

    init(stepId: UUID, success: Bool, outputs: [String: String] = [:],
         duration: TimeInterval = 0, retryCount: Int = 0, error: String? = nil) {
        self.stepId = stepId
        self.success = success
        self.outputs = outputs
        self.duration = duration
        self.retryCount = retryCount
        self.error = error
    }
}

private struct TestToolPipelineError: Identifiable, Sendable {
    let id: UUID
    let stepId: UUID?
    let message: String
    let isRecoverable: Bool
    let timestamp: Date

    init(id: UUID = UUID(), stepId: UUID? = nil, message: String,
         isRecoverable: Bool = true, timestamp: Date = Date()) {
        self.id = id
        self.stepId = stepId
        self.message = message
        self.isRecoverable = isRecoverable
        self.timestamp = timestamp
    }
}

// MARK: - Subagent Model Tests

@Suite("Subagent Model — Display Names")
struct SubagentModelDisplayTests {
    @Test("Inherit display name")
    func inheritDisplay() {
        #expect(TestSubagentModel.inherit.displayName == "Inherit from parent")
    }

    @Test("Specific model shows model name")
    func specificDisplay() {
        #expect(TestSubagentModel.specific("claude-3-opus").displayName == "claude-3-opus")
    }

    @Test("Fast display name")
    func fastDisplay() {
        #expect(TestSubagentModel.fast.displayName == "Fast model")
    }

    @Test("Reasoning display name")
    func reasoningDisplay() {
        #expect(TestSubagentModel.reasoning.displayName == "Reasoning model")
    }
}

// MARK: - Subagent Tools Tests

@Suite("Subagent Tools — Display Names")
struct SubagentToolsDisplayTests {
    @Test("All tools display")
    func allDisplay() {
        #expect(TestSubagentTools.all.displayName == "All tools")
    }

    @Test("Read-only display")
    func readOnlyDisplay() {
        #expect(TestSubagentTools.readOnly.displayName == "Read-only")
    }

    @Test("Specific tools shows count")
    func specificDisplay() {
        let tools = TestSubagentTools.specific(["read", "grep", "glob"])
        #expect(tools.displayName == "3 specific tools")
    }

    @Test("Except tools shows count")
    func exceptDisplay() {
        let tools = TestSubagentTools.except(["write", "edit"])
        #expect(tools.displayName == "All except 2")
    }

    @Test("Empty specific tools shows 0")
    func emptySpecific() {
        #expect(TestSubagentTools.specific([]).displayName == "0 specific tools")
    }
}

// MARK: - Execution Mode Tests

@Suite("Subagent Execution Mode — Enum")
struct SubagentExecutionModeTests {
    @Test("All 3 modes exist")
    func allCases() {
        #expect(TestSubagentExecutionMode.allCases.count == 3)
    }

    @Test("Display names are capitalized")
    func displayNames() {
        #expect(TestSubagentExecutionMode.foreground.displayName == "Foreground")
        #expect(TestSubagentExecutionMode.background.displayName == "Background")
        #expect(TestSubagentExecutionMode.parallel.displayName == "Parallel")
    }
}

// MARK: - Subagent Scope Tests

@Suite("Subagent Scope — Enum")
struct SubagentScopeTests {
    @Test("All 3 scopes exist")
    func allCases() {
        #expect(TestSubagentScope.allCases.count == 3)
    }

    @Test("All scopes have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestSubagentScope.allCases.map(\.rawValue))
        #expect(rawValues.count == 3)
    }
}

// MARK: - Thoroughness Tests

@Suite("Subagent Thoroughness — Levels")
struct SubagentThoroughnessTests {
    @Test("All 3 levels exist")
    func allCases() {
        #expect(TestSubagentThoroughness.allCases.count == 3)
    }

    @Test("Display names match expected")
    func displayNames() {
        #expect(TestSubagentThoroughness.quick.displayName == "Quick")
        #expect(TestSubagentThoroughness.medium.displayName == "Medium")
        #expect(TestSubagentThoroughness.veryThorough.displayName == "Very Thorough")
    }

    @Test("Descriptions are non-empty")
    func descriptions() {
        for level in TestSubagentThoroughness.allCases {
            #expect(!level.description.isEmpty)
        }
    }

    @Test("Very thorough description mentions comprehensive")
    func veryThoroughDescription() {
        #expect(TestSubagentThoroughness.veryThorough.description.contains("Comprehensive"))
    }
}

// MARK: - Subagent Definition Tests

@Suite("Subagent Definition — Construction")
struct SubagentDefinitionTests {
    @Test("Defaults: inherit model, all tools, foreground, builtin")
    func defaults() {
        let sa = TestSubagentDefinition(id: "test", name: "Test", description: "D", systemPrompt: "P")
        #expect(sa.executionMode == .foreground)
        #expect(sa.scope == .builtin)
        #expect(sa.thoroughness == nil)
    }

    @Test("Explore subagent with read-only tools")
    func exploreSubagent() {
        let sa = TestSubagentDefinition(
            id: "explore", name: "Explore", description: "Fast explorer",
            systemPrompt: "You are the Explore subagent",
            model: .fast, tools: .readOnly, thoroughness: .medium
        )
        #expect(sa.id == "explore")
        #expect(sa.thoroughness == .medium)
    }

    @Test("Research subagent with specific tools")
    func researchSubagent() {
        let sa = TestSubagentDefinition(
            id: "research", name: "Research", description: "Web research",
            systemPrompt: "You are the Research subagent",
            model: .fast,
            tools: .specific(["web_search", "web_fetch", "read"]),
            executionMode: .background
        )
        #expect(sa.executionMode == .background)
        if case .specific(let tools) = sa.tools {
            #expect(tools.count == 3)
        } else {
            Issue.record("Expected .specific tools")
        }
    }
}

// MARK: - Execution Context Tests

@Suite("Subagent Execution Context — Defaults")
struct SubagentExecutionContextTests {
    @Test("Default context values")
    func defaults() {
        let ctx = TestSubagentExecutionContext(taskDescription: "Find files")
        #expect(ctx.parentConversationId == nil)
        #expect(ctx.thoroughness == .medium)
        #expect(ctx.maxTurns == 10)
        #expect(ctx.timeout == 300)
    }

    @Test("Custom context")
    func custom() {
        let ctx = TestSubagentExecutionContext(
            parentConversationId: "conv-123", taskDescription: "Deep analysis",
            thoroughness: .veryThorough, maxTurns: 50, timeout: 600
        )
        #expect(ctx.parentConversationId == "conv-123")
        #expect(ctx.thoroughness == .veryThorough)
        #expect(ctx.maxTurns == 50)
        #expect(ctx.timeout == 600)
    }
}

// MARK: - Subagent Result Tests

@Suite("Subagent Result — Success/Failure")
struct SubagentResultTests {
    @Test("Successful result")
    func success() {
        let result = TestSubagentResult(subagentId: "explore", success: true, output: "Found 5 files",
                                         turnsUsed: 3, duration: 2.5)
        #expect(result.success)
        #expect(result.turnsUsed == 3)
        #expect(result.error == nil)
    }

    @Test("Failed result with error")
    func failure() {
        let result = TestSubagentResult(subagentId: "bash", success: false, output: "",
                                         error: "Command not found")
        #expect(!result.success)
        #expect(result.error == "Command not found")
    }

    @Test("Default turnsUsed is 0")
    func defaultTurns() {
        let result = TestSubagentResult(subagentId: "test", success: true, output: "ok")
        #expect(result.turnsUsed == 0)
        #expect(result.duration == 0)
    }
}

// MARK: - Parameter Type Tests

@Suite("Parameter Type — Completeness")
struct ParameterTypeTests {
    @Test("All 7 parameter types exist")
    func allCases() {
        #expect(TestParameterType.allCases.count == 7)
    }

    @Test("All types have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestParameterType.allCases.map(\.rawValue))
        #expect(rawValues.count == 7)
    }
}

// MARK: - Tool Category Tests

@Suite("Tool Category — Completeness")
struct ToolCategoryCompTests {
    @Test("All 7 categories exist")
    func allCases() {
        #expect(TestToolCategory.allCases.count == 7)
    }

    @Test("All categories have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestToolCategory.allCases.map(\.rawValue))
        #expect(rawValues.count == 7)
    }
}

// MARK: - Permission Tests

@Suite("Tool Permission — Completeness")
struct ToolPermissionTests {
    @Test("All 5 permissions exist")
    func allCases() {
        #expect(TestPermission.allCases.count == 5)
    }

    @Test("All permissions have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestPermission.allCases.map(\.rawValue))
        #expect(rawValues.count == 5)
    }
}

// MARK: - Composable Tool Tests

@Suite("Composable Tool — Construction")
struct ComposableToolTests {
    @Test("Minimal tool with defaults")
    func defaults() {
        let tool = TestComposableTool(id: "read", name: "Read", description: "Read file", category: .fileSystem)
        #expect(!tool.isIdempotent)
        #expect(!tool.isCacheable)
        #expect(tool.estimatedDuration == 1.0)
        #expect(tool.requiredPermissions.isEmpty)
        #expect(tool.inputSchema.isEmpty)
        #expect(tool.outputSchema.isEmpty)
    }

    @Test("Tool with permissions and schema")
    func withPermissions() {
        let input = TestParameterSchema(name: "path", type: .string, description: "File path")
        let output = TestParameterSchema(name: "content", type: .string, isRequired: false)
        let tool = TestComposableTool(
            id: "write", name: "Write", description: "Write file",
            category: .fileSystem,
            inputSchema: [input], outputSchema: [output],
            isIdempotent: true, isCacheable: false,
            estimatedDuration: 0.5,
            requiredPermissions: [.readFile, .writeFile]
        )
        #expect(tool.isIdempotent)
        #expect(tool.inputSchema.count == 1)
        #expect(tool.outputSchema.count == 1)
        #expect(tool.requiredPermissions.count == 2)
        #expect(tool.requiredPermissions.contains(.writeFile))
    }
}

// MARK: - Parameter Schema Tests

@Suite("Parameter Schema — Defaults")
struct ParameterSchemaTests {
    @Test("Required by default, no default value")
    func defaults() {
        let param = TestParameterSchema(name: "input", type: .string)
        #expect(param.isRequired)
        #expect(param.defaultValue == nil)
        #expect(param.description.isEmpty)
    }

    @Test("Optional with default value")
    func optional() {
        let param = TestParameterSchema(name: "format", type: .string, isRequired: false,
                                         defaultValue: "json", description: "Output format")
        #expect(!param.isRequired)
        #expect(param.defaultValue == "json")
    }
}

// MARK: - Error Handling Strategy Tests

@Suite("Error Handling Strategy — Cases")
struct ErrorHandlingStrategyTests {
    @Test("All 4 strategies exist")
    func allCases() {
        #expect(TestErrorHandlingStrategy.allCases.count == 4)
    }

    @Test("All strategies have unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestErrorHandlingStrategy.allCases.map(\.rawValue))
        #expect(rawValues.count == 4)
    }
}

// MARK: - Retry Policy Tests

@Suite("Tool Retry Policy — Presets")
struct RetryPolicyTests {
    @Test("Default policy: 2 retries, 1s delay, 2x backoff")
    func defaultPolicy() {
        let p = TestToolRetryPolicy.default
        #expect(p.maxRetries == 2)
        #expect(p.delaySeconds == 1.0)
        #expect(p.backoffMultiplier == 2.0)
    }

    @Test("None policy: 0 retries")
    func nonePolicy() {
        let p = TestToolRetryPolicy.none
        #expect(p.maxRetries == 0)
        #expect(p.delaySeconds == 0)
        #expect(p.backoffMultiplier == 1.0)
    }

    @Test("Aggressive policy: 5 retries, 0.5s delay, 1.5x backoff")
    func aggressivePolicy() {
        let p = TestToolRetryPolicy.aggressive
        #expect(p.maxRetries == 5)
        #expect(p.delaySeconds == 0.5)
        #expect(p.backoffMultiplier == 1.5)
    }

    @Test("Aggressive retries more than default")
    func aggressiveVsDefault() {
        #expect(TestToolRetryPolicy.aggressive.maxRetries > TestToolRetryPolicy.default.maxRetries)
    }

    @Test("Aggressive delay is shorter than default")
    func aggressiveFaster() {
        #expect(TestToolRetryPolicy.aggressive.delaySeconds < TestToolRetryPolicy.default.delaySeconds)
    }
}

// MARK: - Step Result Tests

@Suite("Step Result — Construction")
struct StepResultTests {
    @Test("Successful step with outputs")
    func success() {
        let id = UUID()
        let result = TestStepResult(stepId: id, success: true, outputs: ["content": "hello"], duration: 0.3)
        #expect(result.success)
        #expect(result.outputs["content"] == "hello")
        #expect(result.retryCount == 0)
        #expect(result.error == nil)
    }

    @Test("Failed step with error")
    func failure() {
        let result = TestStepResult(stepId: UUID(), success: false, error: "File not found")
        #expect(!result.success)
        #expect(result.error == "File not found")
    }

    @Test("Step with retries")
    func withRetries() {
        let result = TestStepResult(stepId: UUID(), success: true, duration: 5.0, retryCount: 3)
        #expect(result.retryCount == 3)
    }
}

// MARK: - Pipeline Error Tests

@Suite("Pipeline Error — Construction")
struct PipelineErrorTests {
    @Test("Error with step ID")
    func withStep() {
        let stepId = UUID()
        let err = TestToolPipelineError(stepId: stepId, message: "Timeout")
        #expect(err.stepId == stepId)
        #expect(err.isRecoverable)
    }

    @Test("Non-recoverable error")
    func nonRecoverable() {
        let err = TestToolPipelineError(message: "Permission denied", isRecoverable: false)
        #expect(!err.isRecoverable)
        #expect(err.stepId == nil)
    }

    @Test("Errors have unique IDs")
    func uniqueIDs() {
        let a = TestToolPipelineError(message: "A")
        let b = TestToolPipelineError(message: "A")
        #expect(a.id != b.id)
    }
}
