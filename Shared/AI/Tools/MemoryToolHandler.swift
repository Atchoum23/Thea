// MemoryToolHandler.swift
// Thea
//
// Tool handler for memory and knowledge graph operations (B3)
// Wraps PersonalKnowledgeGraph for AI tool use execution

import Foundation
import os.log

private let logger = Logger(subsystem: "ai.thea.app", category: "MemoryToolHandler")

enum MemoryToolHandler {

    // MARK: - search_memory / search_knowledge_graph

    static func search(_ input: [String: Any]) async -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let query = input["query"] as? String ?? ""
        guard !query.isEmpty else {
            return ToolResult(toolUseId: id, content: "No query provided.", isError: true)
        }
        let results = PersonalKnowledgeGraph.shared.searchEntities(query: query)
        if results.isEmpty {
            return ToolResult(toolUseId: id, content: "No memories found for '\(query)'.")
        }
        let text = results.prefix(5).map { entity in
            let desc = entity.attributes["description"] ?? entity.attributes.values.joined(separator: ", ")
            return "• \(entity.name) [\(entity.type.rawValue)]: \(desc.prefix(120))"
        }.joined(separator: "\n")
        logger.debug("search_memory: \(results.count) results for '\(query)'")
        return ToolResult(toolUseId: id, content: text)
    }

    // MARK: - add_memory / add_knowledge

    static func add(_ input: [String: Any]) async -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let name = input["name"] as? String ?? input["key"] as? String ?? ""
        let typeStr = input["type"] as? String ?? "topic"
        let description = input["description"] as? String ?? input["value"] as? String ?? ""
        guard !name.isEmpty else {
            return ToolResult(toolUseId: id, content: "No name provided.", isError: true)
        }
        let entityType = KGEntityType(rawValue: typeStr) ?? .topic
        let entity = KGEntity(
            name: name,
            type: entityType,
            attributes: description.isEmpty ? [:] : ["description": description]
        )
        PersonalKnowledgeGraph.shared.addOrMergeEntity(entity)
        logger.debug("add_memory: added '\(name)' [\(typeStr)]")
        return ToolResult(toolUseId: id, content: "Memory saved: \(name)")
    }

    // MARK: - list_memories

    static func list(_ input: [String: Any]) async -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let typeFilter = (input["type"] as? String).flatMap { KGEntityType(rawValue: $0) }
        let limit = input["limit"] as? Int ?? 15
        let entities = PersonalKnowledgeGraph.shared.searchEntities(
            query: "", type: typeFilter
        )
        let top = Array(entities.prefix(limit))
        guard !top.isEmpty else {
            return ToolResult(toolUseId: id, content: "No memories stored.")
        }
        let list = top.map { "• \($0.name) [\($0.type.rawValue)]" }.joined(separator: "\n")
        return ToolResult(toolUseId: id, content: "\(top.count) memories:\n\(list)")
    }

    // MARK: - update_memory

    static func update(_ input: [String: Any]) async -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let name = input["name"] as? String ?? ""
        let newDesc = input["description"] as? String ?? input["value"] as? String ?? ""
        guard !name.isEmpty else {
            return ToolResult(toolUseId: id, content: "No name provided.", isError: true)
        }
        let typeStr = input["type"] as? String ?? "topic"
        let entityType = KGEntityType(rawValue: typeStr) ?? .topic
        var updated = KGEntity(
            name: name,
            type: entityType,
            attributes: newDesc.isEmpty ? [:] : ["description": newDesc]
        )
        updated = updated  // silence unused warning
        PersonalKnowledgeGraph.shared.addOrMergeEntity(updated)
        return ToolResult(toolUseId: id, content: "Memory updated: \(name)")
    }
}
