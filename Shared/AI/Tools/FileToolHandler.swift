// FileToolHandler.swift
// Thea
//
// Tool handler for file system operations (B3)
// Security: path validation prevents traversal attacks; confined to allowed directories

import Foundation
import os.log

private let logger = Logger(subsystem: "ai.thea.app", category: "FileToolHandler")

enum FileToolHandler {

    /// Directories the AI is allowed to read/write.
    private static let allowedDirectories: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Desktop",
            "\(home)/.claude/projects",
            NSTemporaryDirectory()
        ]
    }()

    private static func isAllowed(_ path: String) -> Bool {
        let canonical = (path as NSString).standardizingPath
        return allowedDirectories.contains { canonical.hasPrefix($0) }
    }

    // MARK: - read_file

    static func read(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let path = input["path"] as? String ?? ""
        guard !path.isEmpty else {
            return ToolResult(toolUseId: id, content: "No path provided.", isError: true)
        }
        guard isAllowed(path) else {
            logger.warning("read_file: access denied '\(path)'")
            return ToolResult(toolUseId: id, content: "Access denied: \(path)", isError: true)
        }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            // Limit to 8 KB to stay within context budget
            let truncated = content.count > 8000 ? String(content.prefix(8000)) + "\n[…truncated]" : content
            logger.debug("read_file: '\(path)' (\(content.count) chars)")
            return ToolResult(toolUseId: id, content: truncated)
        } catch {
            return ToolResult(toolUseId: id, content: "Cannot read '\(path)': \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - write_file

    static func write(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let path = input["path"] as? String ?? ""
        let content = input["content"] as? String ?? ""
        guard !path.isEmpty else {
            return ToolResult(toolUseId: id, content: "No path provided.", isError: true)
        }
        guard isAllowed(path) else {
            logger.warning("write_file: access denied '\(path)'")
            return ToolResult(toolUseId: id, content: "Access denied: \(path)", isError: true)
        }
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            logger.info("write_file: wrote \(content.count) bytes to '\(path)'")
            return ToolResult(toolUseId: id, content: "Wrote \(content.count) bytes to \(path)")
        } catch {
            return ToolResult(toolUseId: id, content: "Cannot write '\(path)': \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - list_directory

    static func listDirectory(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let path = input["path"] as? String ?? FileManager.default.homeDirectoryForCurrentUser.path
        guard isAllowed(path) else {
            return ToolResult(toolUseId: id, content: "Access denied: \(path)", isError: true)
        }
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: path)
            let sorted = items.sorted().prefix(50)
            return ToolResult(toolUseId: id, content: sorted.joined(separator: "\n"))
        } catch {
            return ToolResult(toolUseId: id, content: "Cannot list '\(path)': \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - search_files

    static func searchFiles(_ input: [String: Any]) -> ToolResult {
        let id = input["_tool_use_id"] as? String ?? ""
        let query = input["query"] as? String ?? ""
        let dir = input["directory"] as? String ?? FileManager.default.homeDirectoryForCurrentUser.path
        guard !query.isEmpty else {
            return ToolResult(toolUseId: id, content: "No query provided.", isError: true)
        }
        guard isAllowed(dir) else {
            return ToolResult(toolUseId: id, content: "Access denied: \(dir)", isError: true)
        }
        let enumerator = FileManager.default.enumerator(atPath: dir)
        var matches: [String] = []
        while let file = enumerator?.nextObject() as? String {
            if file.localizedCaseInsensitiveContains(query) {
                matches.append(file)
            }
            if matches.count >= 20 { break }
        }
        if matches.isEmpty {
            return ToolResult(toolUseId: id, content: "No files matching '\(query)' in \(dir)")
        }
        return ToolResult(toolUseId: id, content: matches.joined(separator: "\n"))
    }
}
