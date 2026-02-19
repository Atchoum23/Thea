#if os(macOS)
    import Foundation

    // @unchecked Sendable: securityPolicy is a let constant set at init; the executor spawns
    // a fresh Process per command; no shared mutable state between concurrent invocations
    /// Executes terminal commands either directly via Process or through Terminal.app
    final class TerminalCommandExecutor: @unchecked Sendable {
        enum ExecutorError: LocalizedError {
            case commandBlocked(String)
            case confirmationRequired(String)
            case timeout
            case processError(String)
            case directoryNotAllowed(URL)

            var errorDescription: String? {
                switch self {
                case let .commandBlocked(reason):
                    "Command blocked: \(reason)"
                case let .confirmationRequired(reason):
                    "Confirmation required: \(reason)"
                case .timeout:
                    "Command execution timed out"
                case let .processError(message):
                    "Process error: \(message)"
                case let .directoryNotAllowed(url):
                    "Directory not allowed: \(url.path)"
                }
            }
        }

        private let securityPolicy: TerminalSecurityPolicy

        init(securityPolicy: TerminalSecurityPolicy = .default) {
            self.securityPolicy = securityPolicy
        }

        // MARK: - Direct Execution (No Terminal.app Window)

        /// Execute a command directly using Process/NSTask
        /// This is faster and captures output directly
        func executeDirect(
            _ command: String,
            workingDirectory: URL? = nil,
            environment: [String: String]? = nil,
            shell: TerminalSession.ShellType = .zsh
        ) async throws -> ShellCommandResult {
            // Validate command against security policy
            let validation = securityPolicy.isAllowed(command)
            switch validation {
            case let .blocked(reason):
                throw ExecutorError.commandBlocked(reason)
            case let .requiresConfirmation(reason):
                throw ExecutorError.confirmationRequired(reason)
            case .allowed:
                break
            }

            // Validate directory
            if let dir = workingDirectory, !securityPolicy.isDirectoryAllowed(dir) {
                throw ExecutorError.directoryNotAllowed(dir)
            }

            let startTime = Date()
            let timeoutSeconds = securityPolicy.maxExecutionTime

            // Execute with timeout using Task and withTimeout pattern
            return try await withThrowingTaskGroup(of: ShellCommandResult.self) { group in
                // Main execution task
                group.addTask {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ShellCommandResult, Error>) in
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: shell.rawValue)
                        process.arguments = ["-c", command]

                        if let dir = workingDirectory {
                            process.currentDirectoryURL = dir
                        }

                        if let env = environment {
                            var processEnv = ProcessInfo.processInfo.environment
                            for (key, value) in env {
                                processEnv[key] = value
                            }
                            process.environment = processEnv
                        }

                        let outputPipe = Pipe()
                        let errorPipe = Pipe()
                        process.standardOutput = outputPipe
                        process.standardError = errorPipe

                        process.terminationHandler = { terminatedProcess in
                            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                            let output = String(data: outputData, encoding: .utf8) ?? ""
                            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                            let duration = Date().timeIntervalSince(startTime)

                            continuation.resume(returning: ShellCommandResult(
                                output: output,
                                errorOutput: errorOutput,
                                exitCode: terminatedProcess.terminationStatus,
                                command: command,
                                duration: duration
                            ))
                        }

                        do {
                            try process.run()
                        } catch {
                            continuation.resume(throwing: ExecutorError.processError(error.localizedDescription))
                        }
                    }
                }

                // Timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    throw ExecutorError.timeout
                }

                // Return first result (either completion or timeout)
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }

        /// Execute multiple commands in sequence
        func executeSequence(
            _ commands: [String],
            workingDirectory: URL? = nil,
            stopOnError: Bool = true
        // periphery:ignore - Reserved: executeSequence(_:workingDirectory:stopOnError:) instance method reserved for future feature activation
        ) async throws -> [ShellCommandResult] {
            var results: [ShellCommandResult] = []
            var currentDir = workingDirectory

            for command in commands {
                do {
                    let result = try await executeDirect(command, workingDirectory: currentDir)
                    results.append(result)

                    // Update directory if cd was used
                    if command.hasPrefix("cd ") {
                        let newDir = command.dropFirst(3).trimmingCharacters(in: .whitespaces)
                        if newDir.hasPrefix("/") {
                            currentDir = URL(fileURLWithPath: String(newDir))
                        } else if newDir == "~" {
                            currentDir = FileManager.default.homeDirectoryForCurrentUser
                        } else if let current = currentDir {
                            currentDir = current.appendingPathComponent(String(newDir))
                        }
                    }

                    if stopOnError, !result.wasSuccessful {
                        break
                    }
                } catch {
                    if stopOnError {
                        throw error
                    }
                }
            }

            return results
        }

        // MARK: - Terminal.app Execution

        /// Execute command in Terminal.app (opens new window if needed)
        func executeInTerminalApp(_ command: String) async throws {
            let validation = securityPolicy.isAllowed(command)
            switch validation {
            case let .blocked(reason):
                throw ExecutorError.commandBlocked(reason)
            case let .requiresConfirmation(reason):
                throw ExecutorError.confirmationRequired(reason)
            case .allowed:
                break
            }

            // SECURITY FIX (FINDING-004): Use proper escaping
            let escapedCommand = escapeForAppleScript(command)
            let script = """
            tell application "Terminal"
                activate
                do script "\(escapedCommand)"
            end tell
            """

            try await runAppleScript(script)
        }

        /// Execute command in a specific Terminal.app window/tab
        func executeInTerminalTab(_ command: String, windowIndex: Int, tabIndex: Int) async throws {
            let validation = securityPolicy.isAllowed(command)
            switch validation {
            case let .blocked(reason):
                throw ExecutorError.commandBlocked(reason)
            case let .requiresConfirmation(reason):
                throw ExecutorError.confirmationRequired(reason)
            case .allowed:
                break
            }

            // SECURITY FIX (FINDING-004): Use proper escaping
            let escapedCommand = escapeForAppleScript(command)
            let script = """
            tell application "Terminal"
                activate
                do script "\(escapedCommand)" in tab \(tabIndex) of window \(windowIndex)
            end tell
            """

            try await runAppleScript(script)
        }

        /// Execute command in the front Terminal window
        func executeInFrontWindow(_ command: String) async throws {
            let validation = securityPolicy.isAllowed(command)
            switch validation {
            // periphery:ignore - Reserved: executeInFrontWindow(_:) instance method reserved for future feature activation
            case let .blocked(reason):
                throw ExecutorError.commandBlocked(reason)
            case let .requiresConfirmation(reason):
                throw ExecutorError.confirmationRequired(reason)
            case .allowed:
                break
            }

            // SECURITY FIX (FINDING-004): Use proper escaping
            let escapedCommand = escapeForAppleScript(command)
            let script = """
            tell application "Terminal"
                activate
                if (count windows) > 0 then
                    do script "\(escapedCommand)" in front window
                else
                    do script "\(escapedCommand)"
                end if
            end tell
            """

            try await runAppleScript(script)
        }

        // MARK: - Terminal.app Control

        /// Open a new Terminal window
        func openNewWindow(withCommand command: String? = nil) async throws {
            var script = """
            tell application "Terminal"
                activate
            """

            if let cmd = command {
                // SECURITY FIX (FINDING-004): Use proper escaping
                let escapedCommand = escapeForAppleScript(cmd)
                script += """
                    do script "\(escapedCommand)"
                """
            } else {
                script += """
                    do script ""
                """
            }

            script += """
            end tell
            """

            try await runAppleScript(script)
        }

        /// Open a new tab in the front window
        func openNewTab(withCommand command: String? = nil) async throws {
            let script: String
            // periphery:ignore - Reserved: openNewTab(withCommand:) instance method reserved for future feature activation
            if let cmd = command {
                // SECURITY FIX (FINDING-004): Use proper escaping
                let escapedCommand = escapeForAppleScript(cmd)
                script = """
                tell application "Terminal"
                    activate
                    tell application "System Events" to keystroke "t" using command down
                    delay 0.2
                    do script "\(escapedCommand)" in front window
                end tell
                """
            } else {
                script = """
                tell application "Terminal"
                    activate
                    tell application "System Events" to keystroke "t" using command down
                end tell
                """
            }

            try await runAppleScript(script)
        }

        /// Close the front Terminal window
        func closeFrontWindow() async throws {
            // periphery:ignore - Reserved: closeFrontWindow() instance method reserved for future feature activation
            let script = """
            tell application "Terminal"
                if (count windows) > 0 then
                    close front window
                end if
            end tell
            """

            try await runAppleScript(script)
        }

        /// Clear the current Terminal buffer
        // periphery:ignore - Reserved: clearTerminal() instance method reserved for future feature activation
        func clearTerminal() async throws {
            try await executeInFrontWindow("clear")
        }

        // MARK: - Private Helpers

        // SECURITY FIX (FINDING-004): Proper AppleScript string escaping
        // Escapes all characters that could break out of AppleScript strings or enable injection
        private func escapeForAppleScript(_ input: String) -> String {
            var result = ""
            for scalar in input.unicodeScalars {
                switch scalar {
                case "\\":
                    result += "\\\\"
                case "\"":
                    result += "\\\""
                case "\n":
                    result += "\\n"
                case "\r":
                    result += "\\r"
                case "\t":
                    result += "\\t"
                default:
                    // Escape control characters and high unicode
                    if scalar.value < 32 || scalar.value == 127 {
                        result += String(format: "\\u%04X", scalar.value)
                    } else {
                        result += String(scalar)
                    }
                }
            }
            return result
        }

        @discardableResult
        private func runAppleScript(_ source: String) async throws -> Any? {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var error: NSDictionary?
                    let script = NSAppleScript(source: source)
                    let result = script?.executeAndReturnError(&error)

                    if let error {
                        let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                        continuation.resume(throwing: ExecutorError.processError(message))
                        return
                    }

                    continuation.resume(returning: result?.stringValue)
                }
            }
        }
    }
#endif
