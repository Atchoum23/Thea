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

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
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
        static let description = "Write content to a file (always requires user approval)"
        static let parameters = [
            ToolParameter(name: "path", type: .string, required: true, description: "File path to write"),
            ToolParameter(name: "content", type: .string, required: true, description: "Content to write")
            // SECURITY FIX: Removed "approved" parameter - AI cannot bypass approval gate
        ]

        // SECURITY: Paths that should never be written to
        private static let blockedPaths: [String] = [
            "/System", "/Library", "/private", "/var", "/etc", "/bin", "/sbin", "/usr",
            ".ssh", ".gnupg", ".aws", ".kube", "Keychain", ".env", ".credentials",
            "id_rsa", "id_ed25519", ".pem", ".key", "secrets"
        ]

        // SECURITY: Allowed file extensions for writing
        private static let allowedExtensions: Set<String> = [
            "txt", "md", "json", "yaml", "yml", "xml", "html", "css", "js", "ts",
            "swift", "py", "rb", "go", "rs", "java", "kt", "c", "cpp", "h", "hpp",
            "sh", "bash", "zsh", "fish", "csv", "log", "conf", "config", "ini"
        ]

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
            guard let path = arguments["path"] as? String,
                  let content = arguments["content"] as? String
            else {
                throw ToolError.invalidParameters
            }

            let expandedPath = NSString(string: path).expandingTildeInPath

            // SECURITY FIX: Block writes to sensitive paths
            for blockedPath in blockedPaths {
                if expandedPath.lowercased().contains(blockedPath.lowercased()) {
                    throw ToolError.pathBlocked("Cannot write to protected path containing '\(blockedPath)'")
                }
            }

            // SECURITY FIX: Validate file extension
            let fileExtension = (expandedPath as NSString).pathExtension.lowercased()
            guard !fileExtension.isEmpty else {
                throw ToolError.pathBlocked("Cannot write files without an extension")
            }
            guard allowedExtensions.contains(fileExtension) else {
                throw ToolError.pathBlocked("Cannot write files with extension '.\(fileExtension)'. Allowed: \(allowedExtensions.sorted().joined(separator: ", "))")
            }

            // SECURITY FIX: Limit file size to prevent disk exhaustion
            guard content.count <= 10_485_760 else { // 10MB max
                throw ToolError.pathBlocked("File content exceeds maximum allowed size (10MB)")
            }

            // SECURITY FIX: ALWAYS require user approval - removed "approved" bypass parameter
            // The AI cannot pre-approve its own file write operations
            let approvalResult = await ApprovalGate.shared.requestApproval(
                level: .fileCreation,
                description: "Write file to: \(path)",
                details: """
                Content length: \(content.count) characters
                File extension: .\(fileExtension)
                Full path: \(expandedPath)
                """
            )
            guard approvalResult.approved else {
                throw ToolError.commandBlocked("File write operation not approved by user")
            }

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

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
            guard let directory = arguments["directory"] as? String,
                  let pattern = arguments["pattern"] as? String
            else {
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

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
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
        static let description = "Execute a shell command (restricted to safe commands)"
        static let parameters = [
            ToolParameter(name: "command", type: .string, required: true, description: "Command to execute"),
            ToolParameter(name: "workingDirectory", type: .string, required: false, description: "Working directory")
        ]

        // SECURITY FIX (FINDING-003): Allowlist of safe commands
        // Only these commands can be executed through the AI tool
        private static let allowedCommands: Set<String> = [
            "ls", "pwd", "cat", "head", "tail", "grep", "find", "wc",
            "echo", "date", "whoami", "which", "file", "stat",
            "swift", "swiftc", "xcodebuild", "xcrun", "xcode-select",
            "git", "pod", "carthage", "mint",
            "npm", "node", "yarn", "pnpm",
            "python", "python3", "pip", "pip3",
            "brew", "xcodegen", "swiftlint", "swiftformat",
            "mkdir", "touch", "cp", "mv" // Safe file operations
        ]

        // SECURITY: Commands that are always blocked
        private static let blockedPatterns: [String] = [
            "rm -rf", "rm -fr", "sudo", "su ", "chmod 777", "chmod -R",
            "curl", "wget", "nc ", "netcat", "nmap",
            "osascript", "open -a", "killall", "pkill",
            "> /dev/", "| sh", "| bash", "| zsh",
            "eval ", "exec ", "`", "$(",
            "base64 -d", "xxd -r"
        ]

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
            guard let command = arguments["command"] as? String else {
                throw ToolError.invalidParameters
            }

            // SECURITY: Validate command against blocklist
            let lowercaseCommand = command.lowercased()
            for pattern in blockedPatterns {
                if lowercaseCommand.contains(pattern) {
                    throw ToolError.commandBlocked("Command contains blocked pattern: \(pattern)")
                }
            }

            // SECURITY: Extract base command and validate against allowlist
            let baseCommand = command.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces).first ?? ""
            let commandName = (baseCommand as NSString).lastPathComponent

            guard allowedCommands.contains(commandName) else {
                throw ToolError.commandBlocked("Command '\(commandName)' is not in the allowlist. Allowed commands: \(allowedCommands.sorted().joined(separator: ", "))")
            }

            // SECURITY: Validate working directory if provided
            if let workDir = arguments["workingDirectory"] as? String {
                let expandedDir = NSString(string: workDir).expandingTildeInPath
                // Ensure directory exists and is within allowed paths
                guard FileManager.default.fileExists(atPath: expandedDir) else {
                    throw ToolError.invalidParameters
                }
                // Block access to sensitive system directories
                let blockedPaths = ["/System", "/Library", "/private", "/var", "/etc", "/bin", "/sbin", "/usr"]
                for blockedPath in blockedPaths {
                    if expandedDir.hasPrefix(blockedPath), !expandedDir.hasPrefix("/usr/local") {
                        throw ToolError.commandBlocked("Working directory '\(expandedDir)' is in a protected system path")
                    }
                }
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

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
            guard let query = arguments["query"] as? String else {
                throw ToolError.invalidParameters
            }

            // Stub - would integrate with search API (DuckDuckGo, Google, etc.)
            return "Web search results for '\(query)' (not yet implemented)"
        }
    }

    struct HTTPRequestTool: Sendable {
        static let name = "http_request"
        static let description = "Make HTTP request (restricted to safe external URLs)"
        static let parameters = [
            ToolParameter(name: "url", type: .string, required: true, description: "URL to request"),
            ToolParameter(name: "method", type: .string, required: false, description: "HTTP method (GET, POST, etc.)"),
            ToolParameter(name: "headers", type: .object, required: false, description: "Request headers"),
            ToolParameter(name: "body", type: .string, required: false, description: "Request body")
        ]

        // SECURITY FIX (SSRF Prevention): Block internal/private network requests
        private static let blockedHosts: [String] = [
            "localhost", "127.0.0.1", "0.0.0.0", "::1",
            "169.254.", "10.", "172.16.", "172.17.", "172.18.", "172.19.",
            "172.20.", "172.21.", "172.22.", "172.23.", "172.24.", "172.25.",
            "172.26.", "172.27.", "172.28.", "172.29.", "172.30.", "172.31.",
            "192.168.", "fc00:", "fd00:", "fe80:",
            "metadata.google", "169.254.169.254", // Cloud metadata endpoints
            ".local", ".internal", ".corp", ".lan"
        ]

        // SECURITY: Only allow HTTPS for external requests
        private static let allowedSchemes = ["https"]

        // SECURITY: Block sensitive paths
        private static let blockedPaths: [String] = [
            "/admin", "/api/internal", "/.env", "/.git", "/config",
            "/metadata", "/latest/meta-data", "/computeMetadata"
        ]

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
            guard let urlString = arguments["url"] as? String,
                  let url = URL(string: urlString)
            else {
                throw ToolError.invalidParameters
            }

            // SECURITY FIX: Validate URL scheme (HTTPS only)
            guard let scheme = url.scheme?.lowercased(),
                  allowedSchemes.contains(scheme)
            else {
                throw ToolError.urlBlocked("Only HTTPS URLs are allowed for security reasons")
            }

            // SECURITY FIX: Validate host is not internal/private
            guard let host = url.host?.lowercased() else {
                throw ToolError.urlBlocked("Invalid URL: no host specified")
            }

            for blockedHost in blockedHosts {
                if host.contains(blockedHost) || host.hasPrefix(blockedHost) {
                    throw ToolError.urlBlocked("Cannot make requests to internal/private network addresses: \(host)")
                }
            }

            // SECURITY FIX: Block cloud metadata endpoints
            if host.contains("metadata") || host == "169.254.169.254" {
                throw ToolError.urlBlocked("Cannot access cloud metadata endpoints")
            }

            // SECURITY FIX: Validate path doesn't access sensitive endpoints
            let path = url.path.lowercased()
            for blockedPath in blockedPaths {
                if path.contains(blockedPath) {
                    throw ToolError.urlBlocked("Cannot access restricted path: \(blockedPath)")
                }
            }

            // SECURITY FIX: Resolve DNS and verify it's not a private IP
            // (prevents DNS rebinding attacks)
            let hostAddresses = try await resolveDNS(host: host)
            for address in hostAddresses {
                for blockedPrefix in blockedHosts {
                    if address.hasPrefix(blockedPrefix) {
                        throw ToolError.urlBlocked("DNS resolution returned private IP address: \(address)")
                    }
                }
            }

            var request = URLRequest(url: url)
            request.httpMethod = arguments["method"] as? String ?? "GET"

            // SECURITY: Limit allowed methods
            let allowedMethods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
            guard allowedMethods.contains(request.httpMethod?.uppercased() ?? "GET") else {
                throw ToolError.invalidParameters
            }

            if let headers = arguments["headers"] as? [String: String] {
                // SECURITY: Block sensitive headers
                let blockedHeaders = ["authorization", "cookie", "x-api-key", "api-key"]
                for (key, value) in headers {
                    if blockedHeaders.contains(key.lowercased()) {
                        throw ToolError.urlBlocked("Cannot set sensitive header: \(key)")
                    }
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }

            if let body = arguments["body"] as? String {
                request.httpBody = body.data(using: .utf8)
            }

            // SECURITY: Set timeout to prevent hanging
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                throw ToolError.executionFailed
            }

            // SECURITY: Limit response size to 1MB
            guard data.count <= 1_048_576 else {
                throw ToolError.executionFailed
            }

            return String(data: data, encoding: .utf8) ?? ""
        }

        // SECURITY: DNS resolution to detect DNS rebinding attacks
        private static func resolveDNS(host: String) async throws -> [String] {
            try await withCheckedThrowingContinuation { continuation in
                let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
                CFHostStartInfoResolution(host, .addresses, nil)

                var success: DarwinBoolean = false
                guard let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as? [Data],
                      success.boolValue
                else {
                    continuation.resume(returning: [])
                    return
                }

                var result: [String] = []
                for addressData in addresses {
                    addressData.withUnsafeBytes { ptr in
                        let sockaddr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(sockaddr, socklen_t(addressData.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                            result.append(String(decoding: hostname.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: .controlCharacters))
                        }
                    }
                }
                continuation.resume(returning: result)
            }
        }
    }

    struct JSONParseTool: Sendable {
        static let name = "json_parse"
        static let description = "Parse JSON string"
        static let parameters = [
            ToolParameter(name: "json", type: .string, required: true, description: "JSON string to parse")
        ]

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
            guard let jsonString = arguments["json"] as? String,
                  let data = jsonString.data(using: .utf8)
            else {
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

        @MainActor static func execute(arguments: [String: Any]) async throws -> Any {
            guard let text = arguments["text"] as? String,
                  let pattern = arguments["pattern"] as? String
            else {
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
            ) { args in
                try await FileReadTool.execute(arguments: args)
            })

            registerTool(Tool(
                id: UUID(),
                name: FileWriteTool.name,
                description: FileWriteTool.description,
                parameters: FileWriteTool.parameters,
                category: .fileSystem
            ) { args in
                try await FileWriteTool.execute(arguments: args)
            })

            registerTool(Tool(
                id: UUID(),
                name: FileSearchTool.name,
                description: FileSearchTool.description,
                parameters: FileSearchTool.parameters,
                category: .fileSystem
            ) { args in
                try await FileSearchTool.execute(arguments: args)
            })

            registerTool(Tool(
                id: UUID(),
                name: FileListTool.name,
                description: FileListTool.description,
                parameters: FileListTool.parameters,
                category: .fileSystem
            ) { args in
                try await FileListTool.execute(arguments: args)
            })

            // Terminal Tools
            registerTool(Tool(
                id: UUID(),
                name: TerminalTool.name,
                description: TerminalTool.description,
                parameters: TerminalTool.parameters,
                category: .code
            ) { args in
                try await TerminalTool.execute(arguments: args)
            })

            // Web Tools
            registerTool(Tool(
                id: UUID(),
                name: WebSearchTool.name,
                description: WebSearchTool.description,
                parameters: WebSearchTool.parameters,
                category: .web
            ) { args in
                try await WebSearchTool.execute(arguments: args)
            })

            registerTool(Tool(
                id: UUID(),
                name: HTTPRequestTool.name,
                description: HTTPRequestTool.description,
                parameters: HTTPRequestTool.parameters,
                category: .web
            ) { args in
                try await HTTPRequestTool.execute(arguments: args)
            })

            // Data Tools
            registerTool(Tool(
                id: UUID(),
                name: JSONParseTool.name,
                description: JSONParseTool.description,
                parameters: JSONParseTool.parameters,
                category: .data
            ) { args in
                try await JSONParseTool.execute(arguments: args)
            })

            registerTool(Tool(
                id: UUID(),
                name: RegexMatchTool.name,
                description: RegexMatchTool.description,
                parameters: RegexMatchTool.parameters,
                category: .data
            ) { args in
                try await RegexMatchTool.execute(arguments: args)
            })
        }
    }

#else

    // MARK: - iOS/watchOS/tvOS Stub Implementation

    extension ToolFramework {
        func registerSystemTools() {
            // System tools are not available on iOS
            // The tool framework will operate with limited functionality
        }
    }

#endif
