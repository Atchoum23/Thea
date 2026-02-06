// AITypesStub.swift
// Thea V2 - Stub types for excluded dependencies
//
// These types are needed by providers and other components

import Foundation

// MARK: - AI Message

/// Represents a message in an AI conversation
public struct AIMessage: Sendable, Identifiable, Codable {
    public let id: UUID
    public let role: Role
    public let content: Content
    public let timestamp: Date

    public enum Role: String, Sendable, Codable {
        case system
        case user
        case assistant
        case function
        case tool
    }

    public enum Content: Sendable, Codable {
        case text(String)
        case image(Data)
        case functionCall(name: String, arguments: String)
        case functionResult(name: String, result: String)
        case toolUse(id: String, name: String, input: String)
        case toolResult(id: String, content: String)
    }

    public init(id: UUID = UUID(), role: Role, content: Content, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    // Convenience initializer for text messages
    public init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.content = .text(text)
        self.timestamp = Date()
    }
}

// MARK: - Task Classifier Stub

/// Stub for TaskClassifier used by excluded files
public struct TaskClassifier {
    public static let shared = TaskClassifier()

    public func classify(_ query: String) async -> ClassificationResult {
        ClassificationResult(
            taskType: .general,
            complexity: .simple,
            confidence: 0.5
        )
    }

    public init() {}
}

// MARK: - Query Decomposer Stub

/// Stub for QueryDecomposer
public struct QueryDecomposer {
    public static let shared = QueryDecomposer()

    public func decompose(_ query: String) async -> [String] {
        [query]
    }

    public init() {}
}
