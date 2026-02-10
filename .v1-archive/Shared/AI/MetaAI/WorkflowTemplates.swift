// WorkflowTemplates.swift
import Foundation

/// Pre-built workflow templates for common tasks.
@MainActor
@Observable
public final class WorkflowTemplates {
    public static let shared = WorkflowTemplates()

    private init() {}

    /// All available workflow templates
    public static var all: [Workflow] {
        [
            // Basic example template
            Workflow(
                id: UUID(),
                name: "Basic Workflow",
                description: "A simple workflow template to get started",
                nodes: [],
                edges: [],
                variables: [:],
                isActive: true,
                createdAt: Date(),
                modifiedAt: Date()
            )
        ]
    }

    // TODO: Implement template library (code review, research, analysis, etc.)
    // TODO: Implement template instantiation
    // TODO: Implement template customization
    // TODO: Implement template sharing/export
}
