// WorkflowTemplates.swift
// Pre-built workflow templates for common AI-assisted tasks

import Foundation

/// Pre-built workflow templates for common tasks.
@MainActor
@Observable
public final class WorkflowTemplates {
    public static let shared = WorkflowTemplates()

    private var customTemplates: [WorkflowTemplate] = []

    private init() {
        loadCustomTemplates()
    }

    // MARK: - Template Library

    /// All available workflow templates (built-in + custom)
    public var allTemplates: [WorkflowTemplate] {
        builtInTemplates + customTemplates
    }

    /// Static accessor for all built-in workflows (instantiated from templates)
    /// Used for backward compatibility with WorkflowBuilder
    @MainActor
    public static var all: [Workflow] {
        shared.builtInTemplates.map { shared.instantiate($0) }
    }

    /// Built-in templates for common tasks
    public var builtInTemplates: [WorkflowTemplate] {
        [
            codeReviewTemplate,
            researchTemplate,
            analysisTemplate,
            debuggingTemplate,
            documentationTemplate,
            refactoringTemplate,
            testGenerationTemplate,
            architectureReviewTemplate
        ]
    }

    // MARK: - Code Review Template

    private var codeReviewTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
            name: "Code Review",
            description: "Comprehensive code review with quality checks, security analysis, and suggestions",
            category: .codeQuality,
            nodes: [
                createNode(type: .input, name: "Code Input", position: CGPoint(x: 100, y: 200)),
                createNode(type: .aiInference, name: "Static Analysis", position: CGPoint(x: 300, y: 100), config: ["prompt": "Analyze this code for potential bugs, code smells, and anti-patterns."]),
                createNode(type: .aiInference, name: "Security Check", position: CGPoint(x: 300, y: 200), config: ["prompt": "Review this code for security vulnerabilities (OWASP top 10, injection, auth issues)."]),
                createNode(type: .aiInference, name: "Performance Review", position: CGPoint(x: 300, y: 300), config: ["prompt": "Analyze this code for performance issues and optimization opportunities."]),
                createNode(type: .merge, name: "Combine Results", position: CGPoint(x: 500, y: 200)),
                createNode(type: .output, name: "Review Report", position: CGPoint(x: 700, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "severity_threshold", value: "medium"),
                TemplateVariable(key: "include_suggestions", value: "true")
            ])
        )
    }

    // MARK: - Research Template

    private var researchTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
            name: "Research Assistant",
            description: "Deep research on a topic with source gathering and synthesis",
            category: .research,
            nodes: [
                createNode(type: .input, name: "Research Topic", position: CGPoint(x: 100, y: 200)),
                createNode(type: .aiInference, name: "Query Decomposition", position: CGPoint(x: 300, y: 200), config: ["prompt": "Break down this research topic into specific sub-questions to investigate."]),
                createNode(type: .toolExecution, name: "Web Search", position: CGPoint(x: 500, y: 100), config: ["tool": "web_search"]),
                createNode(type: .aiInference, name: "Source Analysis", position: CGPoint(x: 500, y: 300), config: ["prompt": "Analyze and summarize the gathered sources, noting key findings and credibility."]),
                createNode(type: .aiInference, name: "Synthesis", position: CGPoint(x: 700, y: 200), config: ["prompt": "Synthesize all findings into a comprehensive research summary with citations."]),
                createNode(type: .output, name: "Research Report", position: CGPoint(x: 900, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "max_sources", value: "10"),
                TemplateVariable(key: "include_citations", value: "true")
            ])
        )
    }

    // MARK: - Analysis Template

    private var analysisTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000003")!,
            name: "Data Analysis",
            description: "Analyze data with statistical insights and visualizations",
            category: .analysis,
            nodes: [
                createNode(type: .input, name: "Data Input", position: CGPoint(x: 100, y: 200)),
                createNode(type: .toolExecution, name: "Data Validation", position: CGPoint(x: 300, y: 200), config: ["tool": "code_execution", "language": "python"]),
                createNode(type: .aiInference, name: "Statistical Analysis", position: CGPoint(x: 500, y: 100), config: ["prompt": "Perform statistical analysis on this data: descriptive stats, correlations, trends."]),
                createNode(type: .aiInference, name: "Insight Generation", position: CGPoint(x: 500, y: 300), config: ["prompt": "Generate actionable insights from this data analysis."]),
                createNode(type: .merge, name: "Combine Analysis", position: CGPoint(x: 700, y: 200)),
                createNode(type: .output, name: "Analysis Report", position: CGPoint(x: 900, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "confidence_level", value: "0.95")
            ])
        )
    }

    // MARK: - Debugging Template

    private var debuggingTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000004")!,
            name: "Bug Investigation",
            description: "Systematic debugging workflow with root cause analysis",
            category: .codeQuality,
            nodes: [
                createNode(type: .input, name: "Bug Report", position: CGPoint(x: 100, y: 200)),
                createNode(type: .aiInference, name: "Reproduce Steps", position: CGPoint(x: 300, y: 200), config: ["prompt": "Analyze this bug report and identify the exact steps to reproduce."]),
                createNode(type: .aiInference, name: "Root Cause Analysis", position: CGPoint(x: 500, y: 100), config: ["prompt": "Perform root cause analysis. Identify potential causes ranked by likelihood."]),
                createNode(type: .aiInference, name: "Fix Suggestions", position: CGPoint(x: 500, y: 300), config: ["prompt": "Generate potential fixes for each identified cause with code examples."]),
                createNode(type: .conditional, name: "Verify Fix", position: CGPoint(x: 700, y: 200), config: ["condition": "fix_verified"]),
                createNode(type: .output, name: "Debug Report", position: CGPoint(x: 900, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "include_stack_trace", value: "true")
            ])
        )
    }

    // MARK: - Documentation Template

    private var documentationTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000005")!,
            name: "Documentation Generator",
            description: "Generate comprehensive documentation from code",
            category: .documentation,
            nodes: [
                createNode(type: .input, name: "Source Code", position: CGPoint(x: 100, y: 200)),
                createNode(type: .aiInference, name: "API Extraction", position: CGPoint(x: 300, y: 100), config: ["prompt": "Extract all public APIs, functions, and types with their signatures."]),
                createNode(type: .aiInference, name: "Usage Examples", position: CGPoint(x: 300, y: 300), config: ["prompt": "Generate practical usage examples for each public API."]),
                createNode(type: .aiInference, name: "Documentation Writing", position: CGPoint(x: 500, y: 200), config: ["prompt": "Write clear, comprehensive documentation in markdown format."]),
                createNode(type: .output, name: "Documentation", position: CGPoint(x: 700, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "format", value: "markdown"),
                TemplateVariable(key: "include_examples", value: "true")
            ])
        )
    }

    // MARK: - Refactoring Template

    private var refactoringTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000006")!,
            name: "Refactoring Assistant",
            description: "Guided refactoring with safety checks and validation",
            category: .codeQuality,
            nodes: [
                createNode(type: .input, name: "Code to Refactor", position: CGPoint(x: 100, y: 200)),
                createNode(type: .aiInference, name: "Smell Detection", position: CGPoint(x: 300, y: 100), config: ["prompt": "Identify code smells and refactoring opportunities."]),
                createNode(type: .aiInference, name: "Refactoring Plan", position: CGPoint(x: 300, y: 300), config: ["prompt": "Create a step-by-step refactoring plan prioritized by impact."]),
                createNode(type: .aiInference, name: "Apply Refactoring", position: CGPoint(x: 500, y: 200), config: ["prompt": "Apply the refactoring plan and generate the improved code."]),
                createNode(type: .toolExecution, name: "Validate", position: CGPoint(x: 700, y: 200), config: ["tool": "code_execution", "language": "swift"]),
                createNode(type: .output, name: "Refactored Code", position: CGPoint(x: 900, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "preserve_behavior", value: "true")
            ])
        )
    }

    // MARK: - Test Generation Template

    private var testGenerationTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000007")!,
            name: "Test Generator",
            description: "Generate comprehensive unit and integration tests",
            category: .testing,
            nodes: [
                createNode(type: .input, name: "Code Under Test", position: CGPoint(x: 100, y: 200)),
                createNode(type: .aiInference, name: "Test Case Identification", position: CGPoint(x: 300, y: 200), config: ["prompt": "Identify all test cases needed: happy path, edge cases, error conditions."]),
                createNode(type: .aiInference, name: "Unit Test Generation", position: CGPoint(x: 500, y: 100), config: ["prompt": "Generate unit tests using XCTest framework."]),
                createNode(type: .aiInference, name: "Integration Tests", position: CGPoint(x: 500, y: 300), config: ["prompt": "Generate integration tests for component interactions."]),
                createNode(type: .merge, name: "Combine Tests", position: CGPoint(x: 700, y: 200)),
                createNode(type: .output, name: "Test Suite", position: CGPoint(x: 900, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "framework", value: "XCTest"),
                TemplateVariable(key: "coverage_target", value: "80")
            ])
        )
    }

    // MARK: - Architecture Review Template

    private var architectureReviewTemplate: WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000008")!,
            name: "Architecture Review",
            description: "Evaluate system architecture for scalability, maintainability, and best practices",
            category: .analysis,
            nodes: [
                createNode(type: .input, name: "Architecture Description", position: CGPoint(x: 100, y: 200)),
                createNode(type: .aiInference, name: "Pattern Analysis", position: CGPoint(x: 300, y: 100), config: ["prompt": "Identify architectural patterns used and evaluate their appropriateness."]),
                createNode(type: .aiInference, name: "Scalability Review", position: CGPoint(x: 300, y: 300), config: ["prompt": "Analyze scalability characteristics and potential bottlenecks."]),
                createNode(type: .aiInference, name: "SOLID Compliance", position: CGPoint(x: 500, y: 200), config: ["prompt": "Evaluate adherence to SOLID principles and clean architecture."]),
                createNode(type: .merge, name: "Combine Reviews", position: CGPoint(x: 700, y: 200)),
                createNode(type: .output, name: "Architecture Report", position: CGPoint(x: 900, y: 200))
            ],
            variables: TemplateVariables(entries: [
                TemplateVariable(key: "include_diagrams", value: "true")
            ])
        )
    }

    // MARK: - Template Instantiation

    /// Enable AI-powered dynamic prompt generation for workflow nodes
    public var useAIDynamicPrompts: Bool = true

    /// Create a new workflow from a template
    /// Optionally uses AI to generate context-aware prompts for AI nodes
    public func instantiate(_ template: WorkflowTemplate, context: AIWorkflowContext? = nil) -> Workflow {
        let nodes = template.nodes.map { nodeTemplate -> WorkflowNode in
            WorkflowNode(
                id: UUID(),
                type: nodeTemplate.type,
                position: nodeTemplate.position,
                config: nodeTemplate.config.toDictionary(),
                inputs: nodeTemplate.inputs.map { $0.toNodePort() },
                outputs: nodeTemplate.outputs.map { $0.toNodePort() }
            )
        }

        // Create edges based on sequential node order (simplified)
        var edges: [WorkflowEdge] = []
        for i in 0 ..< (nodes.count - 1) {
            if !nodes[i].outputs.isEmpty && !nodes[i + 1].inputs.isEmpty {
                edges.append(WorkflowEdge(
                    id: UUID(),
                    sourceNodeId: nodes[i].id,
                    sourcePort: nodes[i].outputs.first?.name ?? "output",
                    targetNodeId: nodes[i + 1].id,
                    targetPort: nodes[i + 1].inputs.first?.name ?? "input"
                ))
            }
        }

        return Workflow(
            id: UUID(),
            name: template.name,
            description: template.description,
            nodes: nodes,
            edges: edges,
            variables: template.variables.toDictionary(),
            isActive: true,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    /// Create a workflow with AI-optimized prompts for the given context
    public func instantiateWithAI(_ template: WorkflowTemplate, input: String, context: AIWorkflowContext) async throws -> Workflow {
        guard useAIDynamicPrompts else {
            return instantiate(template, context: context)
        }

        // Generate optimized prompts for each AI node based on context
        var optimizedNodes: [WorkflowNode] = []

        for nodeTemplate in template.nodes {
            var config = nodeTemplate.config.toDictionary()

            // For AI inference nodes, generate context-aware prompts
            if nodeTemplate.type == .aiInference, let staticPrompt = config["prompt"] as? String {
                let dynamicPrompt = try await generateDynamicPrompt(
                    basePrompt: staticPrompt,
                    input: input,
                    context: context,
                    nodeName: nodeTemplate.name
                )
                config["prompt"] = dynamicPrompt
                config["ai_generated"] = true
            }

            optimizedNodes.append(WorkflowNode(
                id: UUID(),
                type: nodeTemplate.type,
                position: nodeTemplate.position,
                config: config,
                inputs: nodeTemplate.inputs.map { $0.toNodePort() },
                outputs: nodeTemplate.outputs.map { $0.toNodePort() }
            ))
        }

        // Create edges
        var edges: [WorkflowEdge] = []
        for i in 0 ..< (optimizedNodes.count - 1) {
            if !optimizedNodes[i].outputs.isEmpty && !optimizedNodes[i + 1].inputs.isEmpty {
                edges.append(WorkflowEdge(
                    id: UUID(),
                    sourceNodeId: optimizedNodes[i].id,
                    sourcePort: optimizedNodes[i].outputs.first?.name ?? "output",
                    targetNodeId: optimizedNodes[i + 1].id,
                    targetPort: optimizedNodes[i + 1].inputs.first?.name ?? "input"
                ))
            }
        }

        return Workflow(
            id: UUID(),
            name: template.name,
            description: "\(template.description) [AI-Optimized]",
            nodes: optimizedNodes,
            edges: edges,
            variables: template.variables.toDictionary(),
            isActive: true,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    /// Generate a context-aware prompt using AI
    private func generateDynamicPrompt(basePrompt: String, input: String, context: AIWorkflowContext, nodeName: String) async throws -> String {
        let generated = try await AIIntelligence.shared.generatePrompt(
            for: "\(nodeName): \(basePrompt)",
            taskType: inferTaskType(from: nodeName),
            context: AIPromptContext(
                userSkillLevel: .intermediate,
                projectContext: "Workflow node: \(nodeName), Input type: \(context.inputType)",
                previousSuccessfulPrompts: []
            )
        )

        // Combine the base prompt with AI enhancements
        return """
        \(generated.systemPrompt)

        Task: \(basePrompt)

        Input Context:
        \(input.prefix(500))

        \(generated.userPrompt)
        """
    }

    private func inferTaskType(from nodeName: String) -> TaskType {
        let lowercased = nodeName.lowercased()
        if lowercased.contains("analysis") || lowercased.contains("review") {
            return .analysis
        } else if lowercased.contains("code") || lowercased.contains("refactor") {
            return .codeGeneration
        } else if lowercased.contains("debug") || lowercased.contains("fix") {
            return .debugging
        } else if lowercased.contains("test") {
            return .codeGeneration
        } else if lowercased.contains("research") || lowercased.contains("search") {
            return .complexReasoning
        } else {
            return .simpleQA
        }
    }

    // MARK: - Template Customization

    /// Customize a template before instantiation
    public func customize(
        _ template: WorkflowTemplate,
        name: String? = nil,
        description: String? = nil,
        variables: TemplateVariables? = nil
    ) -> WorkflowTemplate {
        var customized = template
        if let name { customized.name = name }
        if let description { customized.description = description }
        if let variables { customized.variables = variables }
        return customized
    }

    // MARK: - Template Sharing/Export

    /// Export template to JSON for sharing
    public func exportTemplate(_ template: WorkflowTemplate) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(template.toExportable())
    }

    /// Import template from JSON
    public func importTemplate(from data: Data) throws -> WorkflowTemplate {
        let decoder = JSONDecoder()
        let exportable = try decoder.decode(ExportableTemplate.self, from: data)
        return exportable.toTemplate()
    }

    /// Save template to custom library
    public func saveCustomTemplate(_ template: WorkflowTemplate) {
        if let index = customTemplates.firstIndex(where: { $0.id == template.id }) {
            customTemplates[index] = template
        } else {
            customTemplates.append(template)
        }
        persistCustomTemplates()
    }

    /// Delete custom template
    public func deleteCustomTemplate(_ template: WorkflowTemplate) {
        customTemplates.removeAll { $0.id == template.id }
        persistCustomTemplates()
    }

    // MARK: - Persistence

    private func loadCustomTemplates() {
        guard let data = UserDefaults.standard.data(forKey: "custom_workflow_templates") else { return }
        do {
            let exportables = try JSONDecoder().decode([ExportableTemplate].self, from: data)
            customTemplates = exportables.map { $0.toTemplate() }
        } catch {
            print("Failed to load custom templates: \(error)")
        }
    }

    private func persistCustomTemplates() {
        do {
            let exportables = customTemplates.map { $0.toExportable() }
            let data = try JSONEncoder().encode(exportables)
            UserDefaults.standard.set(data, forKey: "custom_workflow_templates")
        } catch {
            print("Failed to persist custom templates: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createNode(
        type: WorkflowNodeType,
        name: String,
        position: CGPoint,
        config: [String: String] = [:]
    ) -> WorkflowNodeTemplate {
        WorkflowNodeTemplate(
            type: type,
            name: name,
            position: position,
            config: NodeConfig(entries: config.map { NodeConfigEntry(key: $0.key, value: $0.value) }),
            inputs: type.defaultInputPorts,
            outputs: type.defaultOutputPorts
        )
    }
}

// MARK: - Supporting Types

/// Sendable wrapper for template variables
public struct TemplateVariables: Sendable, Equatable {
    public let entries: [TemplateVariable]

    public init(entries: [TemplateVariable]) {
        self.entries = entries
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        for entry in entries {
            dict[entry.key] = entry.value
        }
        return dict
    }
}

public struct TemplateVariable: Sendable, Equatable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Sendable wrapper for node configuration
public struct NodeConfig: Sendable, Equatable {
    public let entries: [NodeConfigEntry]

    public init(entries: [NodeConfigEntry]) {
        self.entries = entries
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        for entry in entries {
            dict[entry.key] = entry.value
        }
        return dict
    }
}

public struct NodeConfigEntry: Sendable, Equatable {
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Sendable wrapper for node ports
public struct SendableNodePort: Sendable, Equatable {
    public let name: String
    public let portType: String

    public init(name: String, portType: String) {
        self.name = name
        self.portType = portType
    }

    public init(from port: NodePort) {
        self.name = port.name
        self.portType = String(describing: port.type)
    }

    public func toNodePort() -> NodePort {
        let type: NodePort.PortType
        switch portType {
        case "string": type = .string
        case "number": type = .number
        case "boolean": type = .boolean
        case "array": type = .array
        case "object": type = .object
        default: type = .any
        }
        return NodePort(name: name, type: type)
    }
}

public struct WorkflowTemplate: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public let category: TemplateCategory
    public let nodes: [WorkflowNodeTemplate]
    public var variables: TemplateVariables

    public enum TemplateCategory: String, Codable, Sendable {
        case codeQuality = "Code Quality"
        case research = "Research"
        case analysis = "Analysis"
        case documentation = "Documentation"
        case testing = "Testing"
        case automation = "Automation"
    }

    public init(id: UUID, name: String, description: String, category: TemplateCategory, nodes: [WorkflowNodeTemplate], variables: TemplateVariables) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.nodes = nodes
        self.variables = variables
    }

    func toExportable() -> ExportableTemplate {
        ExportableTemplate(
            id: id.uuidString,
            name: name,
            description: description,
            category: category.rawValue,
            nodes: nodes.map { $0.toExportable() },
            variables: Dictionary(uniqueKeysWithValues: variables.entries.map { ($0.key, $0.value) })
        )
    }
}

public struct WorkflowNodeTemplate: Sendable, Equatable {
    public let type: WorkflowNodeType
    public let name: String
    public let position: CGPoint
    public let config: NodeConfig
    public let inputs: [SendableNodePort]
    public let outputs: [SendableNodePort]

    public init(type: WorkflowNodeType, name: String, position: CGPoint, config: NodeConfig, inputs: [SendableNodePort], outputs: [SendableNodePort]) {
        self.type = type
        self.name = name
        self.position = position
        self.config = config
        self.inputs = inputs
        self.outputs = outputs
    }

    func toExportable() -> ExportableNode {
        ExportableNode(
            type: type.rawValue,
            name: name,
            x: position.x,
            y: position.y,
            config: Dictionary(uniqueKeysWithValues: config.entries.map { ($0.key, $0.value) })
        )
    }
}

// Note: WorkflowNodeType is Sendable as declared in WorkflowBuilder.swift

extension WorkflowNodeType {
    var defaultInputPorts: [SendableNodePort] {
        switch self {
        case .input:
            return []
        case .output:
            return [SendableNodePort(name: "input", portType: "any")]
        case .aiInference:
            return [SendableNodePort(name: "input", portType: "string")]
        case .toolExecution:
            return [SendableNodePort(name: "input", portType: "any")]
        case .conditional:
            return [SendableNodePort(name: "input", portType: "any"), SendableNodePort(name: "condition", portType: "boolean")]
        case .loop:
            return [SendableNodePort(name: "items", portType: "array")]
        case .variable:
            return [SendableNodePort(name: "value", portType: "any")]
        case .transformation:
            return [SendableNodePort(name: "input", portType: "any")]
        case .merge:
            return [SendableNodePort(name: "input1", portType: "any"), SendableNodePort(name: "input2", portType: "any")]
        case .split:
            return [SendableNodePort(name: "input", portType: "any")]
        }
    }

    var defaultOutputPorts: [SendableNodePort] {
        switch self {
        case .input:
            return [SendableNodePort(name: "output", portType: "any")]
        case .output:
            return []
        case .aiInference:
            return [SendableNodePort(name: "response", portType: "string")]
        case .toolExecution:
            return [SendableNodePort(name: "result", portType: "any")]
        case .conditional:
            return [SendableNodePort(name: "true", portType: "any"), SendableNodePort(name: "false", portType: "any")]
        case .loop:
            return [SendableNodePort(name: "item", portType: "any")]
        case .variable:
            return [SendableNodePort(name: "output", portType: "any")]
        case .transformation:
            return [SendableNodePort(name: "output", portType: "any")]
        case .merge:
            return [SendableNodePort(name: "combined", portType: "any")]
        case .split:
            return [SendableNodePort(name: "output1", portType: "any"), SendableNodePort(name: "output2", portType: "any")]
        }
    }
}

// MARK: - Export/Import Types

struct ExportableTemplate: Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let nodes: [ExportableNode]
    let variables: [String: String]

    func toTemplate() -> WorkflowTemplate {
        WorkflowTemplate(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            description: description,
            category: WorkflowTemplate.TemplateCategory(rawValue: category) ?? .automation,
            nodes: nodes.map { $0.toNodeTemplate() },
            variables: TemplateVariables(entries: variables.map { TemplateVariable(key: $0.key, value: $0.value) })
        )
    }
}

struct ExportableNode: Codable {
    let type: String
    let name: String
    let x: Double
    let y: Double
    let config: [String: String]

    func toNodeTemplate() -> WorkflowNodeTemplate {
        let nodeType = WorkflowNodeType(rawValue: type) ?? .transformation
        return WorkflowNodeTemplate(
            type: nodeType,
            name: name,
            position: CGPoint(x: x, y: y),
            config: NodeConfig(entries: config.map { NodeConfigEntry(key: $0.key, value: $0.value) }),
            inputs: nodeType.defaultInputPorts,
            outputs: nodeType.defaultOutputPorts
        )
    }
}
