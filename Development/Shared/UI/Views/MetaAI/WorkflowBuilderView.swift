import SwiftUI

struct WorkflowBuilderView: View {
    @State private var workflowBuilder = WorkflowBuilder.shared
    @State private var selectedWorkflow: Workflow?
    @State private var showingNewWorkflow = false

    var body: some View {
        NavigationSplitView {
            WorkflowListView(
                workflows: workflowBuilder.workflows,
                selectedWorkflow: $selectedWorkflow,
                showingNewWorkflow: $showingNewWorkflow
            )
        } detail: {
            if let workflow = selectedWorkflow {
                WorkflowCanvasView(workflow: workflow)
            } else {
                WorkflowEmptyStateView()
            }
        }
        .sheet(isPresented: $showingNewWorkflow) {
            NewWorkflowSheet(workflowBuilder: workflowBuilder)
        }
        .navigationTitle("Workflow Builder")
    }
}

// MARK: - Workflow List

struct WorkflowListView: View {
    let workflows: [Workflow]
    @Binding var selectedWorkflow: Workflow?
    @Binding var showingNewWorkflow: Bool

    var body: some View {
        List(workflows, selection: $selectedWorkflow) { workflow in
            WorkflowRowView(workflow: workflow)
        }
        .navigationTitle("Workflows")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewWorkflow = true }) {
                    Label("New Workflow", systemImage: "plus")
                }
            }
        }
    }
}

struct WorkflowRowView: View {
    let workflow: Workflow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workflow.name)
                    .font(.headline)

                if workflow.isActive {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            Text(workflow.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Label("\(workflow.nodes.count) nodes", systemImage: "circle.grid.2x2")
                Spacer()
                Text(workflow.modifiedAt, style: .relative)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Workflow Canvas

struct WorkflowCanvasView: View {
    let workflow: Workflow
    @State private var selectedNode: WorkflowNode?
    @State private var showingNodeLibrary = false
    @State private var isExecuting = false
    @State private var executionProgress: Float = 0

    var body: some View {
        VStack(spacing: 0) {
            // Canvas
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    // Grid background
                    GridPattern()

                    // Edges
                    ForEach(workflow.edges) { edge in
                        EdgeView(edge: edge, workflow: workflow)
                    }

                    // Nodes
                    ForEach(workflow.nodes) { node in
                        NodeView(node: node, isSelected: selectedNode?.id == node.id)
                            .position(node.position)
                            .onTapGesture {
                                selectedNode = node
                            }
                    }
                }
                .frame(minWidth: 2000, minHeight: 2000)
            }

            // Bottom toolbar
            HStack {
                Button(action: { showingNodeLibrary.toggle() }) {
                    Label("Add Node", systemImage: "plus.circle")
                }

                Spacer()

                if isExecuting {
                    ProgressView(value: executionProgress)
                        .frame(width: 200)
                }

                Spacer()

                Button(action: executeWorkflow) {
                    Label("Execute", systemImage: "play.fill")
                }
                .disabled(workflow.nodes.isEmpty || isExecuting)
            }
            .padding()
            .background(.regularMaterial)
        }
        .sheet(isPresented: $showingNodeLibrary) {
            NodeLibrarySheet(workflow: workflow)
        }
        .inspector(isPresented: .constant(selectedNode != nil)) {
            if let node = selectedNode {
                NodeInspectorView(node: node, workflow: workflow)
            }
        }
    }

    private func executeWorkflow() {
        isExecuting = true
        executionProgress = 0

        Task {
            do {
                _ = try await WorkflowBuilder.shared.executeWorkflow(workflow.id) { progress in
                    Task { @MainActor in
                        executionProgress = progress.percentage
                    }
                }
                isExecuting = false
            } catch {
                isExecuting = false
            }
        }
    }
}

struct GridPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 50
                let width = geometry.size.width
                let height = geometry.size.height

                // Vertical lines
                for x in stride(from: 0, through: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                // Horizontal lines
                for y in stride(from: 0, through: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        }
    }
}

struct NodeView: View {
    let node: WorkflowNode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(node.type.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: iconForNodeType(node.type))
                .font(.title2)
        }
        .frame(width: 100, height: 80)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.controlBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
        )
    }

    private func iconForNodeType(_ type: WorkflowNodeType) -> String {
        switch type {
        case .input: return "arrow.down.circle"
        case .output: return "arrow.up.circle"
        case .aiInference: return "brain"
        case .toolExecution: return "wrench"
        case .conditional: return "arrow.triangle.branch"
        case .loop: return "arrow.clockwise"
        case .variable: return "v.square"
        case .transformation: return "wand.and.stars"
        case .merge: return "arrow.triangle.merge"
        case .split: return "arrow.triangle.split"
        }
    }
}

struct EdgeView: View {
    let edge: WorkflowEdge
    let workflow: Workflow

    var body: some View {
        if let sourceNode = workflow.nodes.first(where: { $0.id == edge.sourceNodeId }),
           let targetNode = workflow.nodes.first(where: { $0.id == edge.targetNodeId }) {
            Path { path in
                path.move(to: sourceNode.position)
                path.addLine(to: targetNode.position)
            }
            .stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
        }
    }
}

// MARK: - Node Library

struct NodeLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let workflow: Workflow
    @State private var nodeLibrary = WorkflowBuilder.shared.nodeLibrary

    var body: some View {
        NavigationStack {
            List(nodeLibrary) { template in
                Button(action: {
                    addNode(template)
                }) {
                    VStack(alignment: .leading) {
                        Text(template.name)
                            .font(.headline)
                        Text(template.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addNode(_ template: NodeTemplate) {
        let position = CGPoint(
            x: Double.random(in: 500...1500),
            y: Double.random(in: 500...1500)
        )

        _ = try? WorkflowBuilder.shared.addNode(
            to: workflow.id,
            type: template.type,
            position: position
        )

        dismiss()
    }
}

// MARK: - Node Inspector

struct NodeInspectorView: View {
    let node: WorkflowNode
    let workflow: Workflow

    var body: some View {
        Form {
            Section("Node Details") {
                LabeledContent("Type", value: node.type.rawValue)
                LabeledContent("ID", value: node.id.uuidString.prefix(8))
            }

            Section("Configuration") {
                Text("Node-specific configuration would go here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Connections") {
                Text("Inputs: \(node.inputs.count)")
                Text("Outputs: \(node.outputs.count)")
            }
        }
        .formStyle(.grouped)
        .frame(width: 300)
    }
}

// MARK: - Empty State

struct WorkflowEmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Workflow Selected",
            systemImage: "flowchart",
            description: Text("Select a workflow from the sidebar or create a new one")
        )
    }
}

// MARK: - New Workflow Sheet

struct NewWorkflowSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workflowBuilder: WorkflowBuilder

    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Workflow")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createWorkflow()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func createWorkflow() {
        _ = workflowBuilder.createWorkflow(name: name, description: description)
    }
}

extension NodeTemplate: Identifiable {
    var id: String { type.rawValue }
}

#Preview {
    WorkflowBuilderView()
}
