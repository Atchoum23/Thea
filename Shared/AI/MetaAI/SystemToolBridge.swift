#if os(macOS)
import Foundation

// MARK: - Built-in System Tools
// Native filesystem, terminal, and system tools

struct FileReadTool: Sendable {
    static let name = "file_read"
    static let description = "Read contents of a file"
    static let parameters = [
        ToolParameter(name: "path", type: .string, required: true, description: "File path to read")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let path = arguments["path"] as? String else {
            throw ToolError.invalidParameters
        }
        
        let expandedPath = NSString(string: path).expandingTildeInPath
        let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
        return content
    }
}

struct FileWriteTool: Sendable {
    static let name = "file_write"
    static let description = "Write content to a file"
    static let parameters = [
        ToolParameter(name: "path", type: .string, required: true, description: "File path to write"),
        ToolParameter(name: "content", type: .string, required: true, description: "Content to write")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let path = arguments["path"] as? String,
              let content = arguments["content"] as? String else {
            throw ToolError.invalidParameters
        }
        
        let expandedPath = NSString(string: path).expandingTildeInPath
        try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
        return "File written successfully to \(path)"
    }
}

struct FileSearchTool: Sendable {
    static let name = "file_search"
    static let description = "Search for files matching a pattern"
    static let parameters = [
        ToolParameter(name: "directory", type: .string, required: true, description: "Directory to search"),
        ToolParameter(name: "pattern", type: .string, required: true, description: "Search pattern (glob or regex)")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let directory = arguments["directory"] as? String,
              let pattern = arguments["pattern"] as? String else {
            throw ToolError.invalidParameters
        }
        
        let expandedDir = NSString(string: directory).expandingTildeInPath
        let fm = FileManager.default
        var matches: [String] = []
        
        if let enumerator = fm.enumerator(atPath: expandedDir) {
            while let file = enumerator.nextObject() as? String {
                if file.contains(pattern) {
                    matches.append(file)
                }
            }
        }
        
        return matches.joined(separator: "\n")
    }
}

struct FileListTool: Sendable {
    static let name = "file_list"
    static let description = "List files in a directory"
    static let parameters = [
        ToolParameter(name: "path", type: .string, required: true, description: "Directory path"),
        ToolParameter(name: "recursive", type: .boolean, required: false, description: "List recursively")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let path = arguments["path"] as? String else {
            throw ToolError.invalidParameters
        }
        
        let expandedPath = NSString(string: path).expandingTildeInPath
        let recursive = arguments["recursive"] as? Bool ?? false
        let fm = FileManager.default
        
        if recursive {
            guard let enumerator = fm.enumerator(atPath: expandedPath) else {
                throw ToolError.executionFailed
            }
            
            var files: [String] = []
            while let file = enumerator.nextObject() as? String {
                files.append(file)
            }
            return files.joined(separator: "\n")
        } else {
            let contents = try fm.contentsOfDirectory(atPath: expandedPath)
            return contents.joined(separator: "\n")
        }
    }
}

struct TerminalTool: Sendable {
    static let name = "terminal"
    static let description = "Execute a shell command"
    static let parameters = [
        ToolParameter(name: "command", type: .string, required: true, description: "Command to execute"),
        ToolParameter(name: "workingDirectory", type: .string, required: false, description: "Working directory")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let command = arguments["command"] as? String else {
            throw ToolError.invalidParameters
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        if let workDir = arguments["workingDirectory"] as? String {
            let expandedDir = NSString(string: workDir).expandingTildeInPath
            process.currentDirectoryURL = URL(fileURLWithPath: expandedDir)
        }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw ToolError.executionFailed
        }
        
        return output
    }
}

struct WebSearchTool: Sendable {
    static let name = "web_search"
    static let description = "Search the web (stub - requires API integration)"
    static let parameters = [
        ToolParameter(name: "query", type: .string, required: true, description: "Search query")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let query = arguments["query"] as? String else {
            throw ToolError.invalidParameters
        }
        
        // Stub - would integrate with search API (DuckDuckGo, Google, etc.)
        return "Web search results for '\(query)' (not yet implemented)"
    }
}

struct HTTPRequestTool: Sendable {
    static let name = "http_request"
    static let description = "Make HTTP request"
    static let parameters = [
        ToolParameter(name: "url", type: .string, required: true, description: "URL to request"),
        ToolParameter(name: "method", type: .string, required: false, description: "HTTP method (GET, POST, etc.)"),
        ToolParameter(name: "headers", type: .object, required: false, description: "Request headers"),
        ToolParameter(name: "body", type: .string, required: false, description: "Request body")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let urlString = arguments["url"] as? String,
              let url = URL(string: urlString) else {
            throw ToolError.invalidParameters
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = arguments["method"] as? String ?? "GET"
        
        if let headers = arguments["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = arguments["body"] as? String {
            request.httpBody = body.data(using: .utf8)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ToolError.executionFailed
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct JSONParseTool: Sendable {
    static let name = "json_parse"
    static let description = "Parse JSON string"
    static let parameters = [
        ToolParameter(name: "json", type: .string, required: true, description: "JSON string to parse")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let jsonString = arguments["json"] as? String,
              let data = jsonString.data(using: .utf8) else {
            throw ToolError.invalidParameters
        }
        
        let json = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        return String(data: prettyData, encoding: .utf8) ?? ""
    }
}

struct RegexMatchTool: Sendable {
    static let name = "regex_match"
    static let description = "Match text against regex pattern"
    static let parameters = [
        ToolParameter(name: "text", type: .string, required: true, description: "Text to search"),
        ToolParameter(name: "pattern", type: .string, required: true, description: "Regex pattern")
    ]

    static func execute(arguments: [String: Any]) async throws -> Any {
        guard let text = arguments["text"] as? String,
              let pattern = arguments["pattern"] as? String else {
            throw ToolError.invalidParameters
        }
        
        let regex = try NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        var results: [String] = []
        for match in matches {
            if let range = Range(match.range, in: text) {
                results.append(String(text[range]))
            }
        }
        
        return results.joined(separator: "\n")
    }
}

// MARK: - System Tool Registration Helper

extension ToolFramework {
    func registerSystemTools() {
        // File System Tools
        registerTool(Tool(
            id: UUID(),
            name: FileReadTool.name,
            description: FileReadTool.description,
            parameters: FileReadTool.parameters,
            category: .fileSystem
        ) { @Sendable args in
            try await FileReadTool.execute(arguments: args)
        })

        registerTool(Tool(
            id: UUID(),
            name: FileWriteTool.name,
            description: FileWriteTool.description,
            parameters: FileWriteTool.parameters,
            category: .fileSystem
        ) { @Sendable args in
            try await FileWriteTool.execute(arguments: args)
        })

        registerTool(Tool(
            id: UUID(),
            name: FileSearchTool.name,
            description: FileSearchTool.description,
            parameters: FileSearchTool.parameters,
            category: .fileSystem
        ) { @Sendable args in
            try await FileSearchTool.execute(arguments: args)
        })

        registerTool(Tool(
            id: UUID(),
            name: FileListTool.name,
            description: FileListTool.description,
            parameters: FileListTool.parameters,
            category: .fileSystem
        ) { @Sendable args in
            try await FileListTool.execute(arguments: args)
        })

        // Terminal Tools
        registerTool(Tool(
            id: UUID(),
            name: TerminalTool.name,
            description: TerminalTool.description,
            parameters: TerminalTool.parameters,
            category: .code
        ) { @Sendable args in
            try await TerminalTool.execute(arguments: args)
        })

        // Web Tools
        registerTool(Tool(
            id: UUID(),
            name: WebSearchTool.name,
            description: WebSearchTool.description,
            parameters: WebSearchTool.parameters,
            category: .web
        ) { @Sendable args in
            try await WebSearchTool.execute(arguments: args)
        })

        registerTool(Tool(
            id: UUID(),
            name: HTTPRequestTool.name,
            description: HTTPRequestTool.description,
            parameters: HTTPRequestTool.parameters,
            category: .web
        ) { @Sendable args in
            try await HTTPRequestTool.execute(arguments: args)
        })

        // Data Tools
        registerTool(Tool(
            id: UUID(),
            name: JSONParseTool.name,
            description: JSONParseTool.description,
            parameters: JSONParseTool.parameters,
            category: .data
        ) { @Sendable args in
            try await JSONParseTool.execute(arguments: args)
        })

        registerTool(Tool(
            id: UUID(),
            name: RegexMatchTool.name,
            description: RegexMatchTool.description,
            parameters: RegexMatchTool.parameters,
            category: .data
        ) { @Sendable args in
            try await RegexMatchTool.execute(arguments: args)
        })
    }
}

#endif
