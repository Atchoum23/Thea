// WorkflowPersistence.swift
import Foundation

/// Save/load workflows to disk with versioning support.
@MainActor
@Observable
public final class WorkflowPersistence {
    public static let shared = WorkflowPersistence()

    private let workflowsDirectory: URL
    private let workflowsFileName = "workflows.json"

    private init() {
        // Default workflows directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.workflowsDirectory = appSupport.appendingPathComponent("Thea/workflows")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: workflowsDirectory, withIntermediateDirectories: true)
    }

    /// Load workflows from disk
    public func load() async throws -> [Workflow] {
        let fileURL = workflowsDirectory.appendingPathComponent(workflowsFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        // For now, return empty array - full serialization implementation pending
        // TODO: Implement proper JSON serialization/deserialization for Workflow objects
        return []
    }
    
    /// Save workflows to disk
    public func save(_ workflows: [Workflow]) async throws {
        let fileURL = workflowsDirectory.appendingPathComponent(workflowsFileName)
        
        // For now, just create an empty file - full serialization implementation pending
        // TODO: Implement proper JSON serialization for Workflow objects
        try Data().write(to: fileURL)
    }
    
    /// Auto-save workflows (debounced save operation)
    public func autoSave(_ workflows: [Workflow]) async {
        do {
            try await save(workflows)
        } catch {
            print("Auto-save failed: \(error.localizedDescription)")
        }
    }
    
    // TODO: Implement workflow versioning
    // TODO: Implement default workflows management
}
