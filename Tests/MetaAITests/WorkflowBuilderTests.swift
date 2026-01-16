import XCTest

@testable import TheaCore

@MainActor
final class WorkflowBuilderTests: XCTestCase {
  var workflowBuilder: WorkflowBuilder!

  override func setUp() async throws {
    workflowBuilder = WorkflowBuilder()
    workflowBuilder.workflows.removeAll()
  }

  func testCreateWorkflow() {
    let workflow = workflowBuilder.createWorkflow(
      name: "Test Workflow",
      description: "A test workflow"
    )

    XCTAssertEqual(workflow.name, "Test Workflow")
    XCTAssertEqual(workflow.description, "A test workflow")
    XCTAssertTrue(workflow.nodes.isEmpty)
    XCTAssertTrue(workflow.edges.isEmpty)
    XCTAssertEqual(workflowBuilder.workflows.count, 1)
  }

  func testAddNode() throws {
    let workflow = workflowBuilder.createWorkflow(name: "Test")

    let node = try workflowBuilder.addNode(
      to: workflow.id,
      type: .input,
      position: CGPoint(x: 100, y: 100)
    )

    XCTAssertEqual(node.type, .input)
    XCTAssertEqual(node.position.x, 100)
    XCTAssertEqual(node.position.y, 100)
    XCTAssertEqual(workflow.nodes.count, 1)
  }

  func testConnectNodes() throws {
    let workflow = workflowBuilder.createWorkflow(name: "Test")

    let inputNode = try workflowBuilder.addNode(
      to: workflow.id,
      type: .input,
      position: CGPoint(x: 0, y: 0)
    )

    let outputNode = try workflowBuilder.addNode(
      to: workflow.id,
      type: .output,
      position: CGPoint(x: 200, y: 0)
    )

    try workflowBuilder.connectNodes(
      in: workflow.id,
      from: inputNode.id,
      outputPort: "output",
      to: outputNode.id,
      inputPort: "input"
    )

    XCTAssertEqual(workflow.edges.count, 1)
    XCTAssertEqual(workflow.edges[0].sourceNodeId, inputNode.id)
    XCTAssertEqual(workflow.edges[0].targetNodeId, outputNode.id)
  }

  func testCycleDetection() throws {
    let workflow = workflowBuilder.createWorkflow(name: "Test")

    let node1 = try workflowBuilder.addNode(to: workflow.id, type: .aiInference, position: .zero)
    let node2 = try workflowBuilder.addNode(to: workflow.id, type: .aiInference, position: .zero)

    try workflowBuilder.connectNodes(
      in: workflow.id,
      from: node1.id,
      outputPort: "output",
      to: node2.id,
      inputPort: "input"
    )

    XCTAssertThrowsError(
      try workflowBuilder.connectNodes(
        in: workflow.id,
        from: node2.id,
        outputPort: "output",
        to: node1.id,
        inputPort: "input"
      )
    ) { error in
      XCTAssertEqual(error as? WorkflowError, .cyclicConnection)
    }
  }

  func testNodeTypes() {
    let nodeTypes: [NodeType] = [
      .input, .output, .aiInference, .toolExecution,
      .conditional, .loop, .variable, .transformation,
      .merge, .split,
    ]

    XCTAssertEqual(nodeTypes.count, 10, "Should have 10 node types")

    for nodeType in nodeTypes {
      XCTAssertFalse(nodeType.rawValue.isEmpty)
    }
  }

  func testWorkflowDuplication() throws {
    let original = workflowBuilder.createWorkflow(name: "Original")
    _ = try workflowBuilder.addNode(to: original.id, type: .input, position: .zero)

    let duplicate = try workflowBuilder.duplicateWorkflow(original.id)

    XCTAssertNotEqual(duplicate.id, original.id)
    XCTAssertTrue(duplicate.name.contains("Copy"))
    XCTAssertEqual(duplicate.nodes.count, original.nodes.count)
  }

  func testDeleteWorkflow() throws {
    let workflow = workflowBuilder.createWorkflow(name: "Test")
    XCTAssertEqual(workflowBuilder.workflows.count, 1)

    try workflowBuilder.deleteWorkflow(workflow.id)
    XCTAssertEqual(workflowBuilder.workflows.count, 0)
  }

  func testNodePositioning() throws {
    let workflow = workflowBuilder.createWorkflow(name: "Test")
    let node = try workflowBuilder.addNode(
      to: workflow.id,
      type: .input,
      position: CGPoint(x: 100, y: 200)
    )

    try workflowBuilder.updateNodePosition(
      in: workflow.id,
      nodeId: node.id,
      position: CGPoint(x: 300, y: 400)
    )

    XCTAssertEqual(node.position.x, 300)
    XCTAssertEqual(node.position.y, 400)
  }
}
