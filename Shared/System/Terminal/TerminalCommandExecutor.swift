import Foundation

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
            case .commandBlocked(let reason):
                return "Command blocked: \(reason)"
            case .confirmationRequired(let reason):
                return "Confirmation required: \(reason)"
            case .timeout:
                return "Command execution timed out"
            case .processError(let message):
                return "Process error: \(message)"
            case .directoryNotAllowed(let url):
                return "Directory not allowed: \(url.path)"
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
    ) async throws -> CommandResult {
        // Validate command against security policy
        let validation = securityPolicy.isAllowed(command)
        switch validation {
        case .blocked(let reason):
            throw ExecutorError.commandBlocked(reason)
        case .requiresConfirmation(let reason):
            throw ExecutorError.confirmationRequired(reason)
        case .allowed:
            break
        }

        // Validate directory
        if let dir = workingDirectory, !securityPolicy.isDirectoryAllowed(dir) {
            throw ExecutorError.directoryNotAllowed(dir)
        }

        let startTime = Date()

        return try await withThrowingTaskGroup(of: CommandResult.self) { group in
            group.addTask {
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

                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                let duration = Date().timeIntervalSince(startTime)

                return CommandResult(
                    output: output,
                    errorOutput: errorOutput,
                    exitCode: process.terminationStatus,
                    command: command,
                    duration: duration
                )
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.securityPolicy.maxExecutionTime * 1_000_000_000))
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
    ) async throws -> [CommandResult] {
        var results: [CommandResult] = []
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

                if stopOnError && !result.wasSuccessful {
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
        case .blocked(let reason):
            throw ExecutorError.commandBlocked(reason)
        case .requiresConfirmation(let reason):
            throw ExecutorError.confirmationRequired(reason)
        case .allowed:
            break
        }

        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
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
        case .blocked(let reason):
            throw ExecutorError.commandBlocked(reason)
        case .requiresConfirmation(let reason):
            throw ExecutorError.confirmationRequired(reason)
        case .allowed:
            break
        }

        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
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
        case .blocked(let reason):
            throw ExecutorError.commandBlocked(reason)
        case .requiresConfirmation(let reason):
            throw ExecutorError.confirmationRequired(reason)
        case .allowed:
            break
        }

        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
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
            let escapedCommand = cmd.replacingOccurrences(of: "\"", with: "\\\"")
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
        if let cmd = command {
            let escapedCommand = cmd.replacingOccurrences(of: "\"", with: "\\\"")
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
    func clearTerminal() async throws {
        try await executeInFrontWindow("clear")
    }

    // MARK: - Private Helpers

    @discardableResult
    private func runAppleScript(_ source: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)
                let result = script?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    continuation.resume(throwing: ExecutorError.processError(message))
                    return
                }

                continuation.resume(returning: result?.stringValue)
            }
        }
    }
}
