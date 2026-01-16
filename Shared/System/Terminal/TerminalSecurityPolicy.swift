import Foundation

/// Security policy for terminal command execution
struct TerminalSecurityPolicy: Codable, Equatable {
    var allowedCommands: [String]      // Whitelist (empty = all allowed)
    var blockedCommands: [String]      // Blacklist
    var blockedPatterns: [String]      // Regex patterns to block
    var requireConfirmation: [String]  // Commands requiring user approval
    var allowSudo: Bool                // Whether sudo is permitted
    var allowNetworkCommands: Bool     // curl, wget, ssh, etc.
    var allowFileModification: Bool    // rm, mv, cp to system dirs
    var sandboxedDirectories: [URL]    // Restrict to these directories (empty = no restriction)
    var maxExecutionTime: TimeInterval // Kill after timeout
    var logAllCommands: Bool           // Log all executed commands
    var redactSensitiveOutput: Bool    // Redact passwords, keys in output

    static var `default`: TerminalSecurityPolicy {
        TerminalSecurityPolicy(
            allowedCommands: [],
            blockedCommands: [
                "rm -rf /",
                "rm -rf /*",
                ":(){ :|:& };:",  // Fork bomb
                "dd if=/dev/zero of=/dev/sda",
                "mkfs",
                "> /dev/sda",
                "mv ~ /dev/null",
                "chmod -R 777 /",
                "chown -R nobody /"
            ],
            blockedPatterns: [
                "rm\\s+-rf\\s+/(?!tmp|var/tmp)",  // rm -rf on root dirs except tmp
                "\\|\\s*rm\\s+-rf",               // Piped rm -rf
                "wget.*\\|.*bash",                // Remote code execution
                "curl.*\\|.*sh"                   // Remote code execution
            ],
            requireConfirmation: [
                "sudo",
                "rm -rf",
                "rm -r",
                "shutdown",
                "reboot",
                "killall",
                "pkill",
                "launchctl",
                "systemsetup",
                "csrutil",
                "nvram",
                "diskutil eraseDisk",
                "diskutil partitionDisk"
            ],
            allowSudo: true,
            allowNetworkCommands: true,
            allowFileModification: true,
            sandboxedDirectories: [],
            maxExecutionTime: 300, // 5 minutes
            logAllCommands: true,
            redactSensitiveOutput: true
        )
    }

    static var sandboxed: TerminalSecurityPolicy {
        var policy = TerminalSecurityPolicy.default
        policy.allowSudo = false
        policy.allowNetworkCommands = false
        policy.allowFileModification = false
        policy.sandboxedDirectories = [FileManager.default.homeDirectoryForCurrentUser]
        policy.maxExecutionTime = 60 // 1 minute
        return policy
    }

    static var unrestricted: TerminalSecurityPolicy {
        TerminalSecurityPolicy(
            allowedCommands: [],
            blockedCommands: [":(){ :|:& };:"], // Only block obvious attacks
            blockedPatterns: [],
            requireConfirmation: [],
            allowSudo: true,
            allowNetworkCommands: true,
            allowFileModification: true,
            sandboxedDirectories: [],
            maxExecutionTime: 1800, // 30 minutes
            logAllCommands: true,
            redactSensitiveOutput: false
        )
    }

    /// Check if a command is allowed by this policy
    func isAllowed(_ command: String) -> CommandValidation {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check explicit blocklist
        for blocked in blockedCommands where trimmedCommand.contains(blocked) {
            return .blocked(reason: "Command contains blocked pattern: \(blocked)")
        }

        // Check regex patterns
        for pattern in blockedPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(trimmedCommand.startIndex..., in: trimmedCommand)
                if regex.firstMatch(in: trimmedCommand, options: [], range: range) != nil {
                    return .blocked(reason: "Command matches blocked pattern")
                }
            }
        }

        // Check sudo permission
        if !allowSudo && trimmedCommand.hasPrefix("sudo ") {
            return .blocked(reason: "Sudo commands are not allowed by current policy")
        }

        // Check network commands
        if !allowNetworkCommands {
            let networkCommands = ["curl", "wget", "ssh", "scp", "sftp", "nc", "netcat", "telnet", "ftp"]
            for netCmd in networkCommands where trimmedCommand.hasPrefix("\(netCmd) ") || trimmedCommand.contains("| \(netCmd)") {
                return .blocked(reason: "Network commands are not allowed by current policy")
            }
        }

        // Check whitelist (if not empty)
        if !allowedCommands.isEmpty {
            let commandName = trimmedCommand.components(separatedBy: " ").first ?? trimmedCommand
            if !allowedCommands.contains(where: { $0 == commandName || trimmedCommand.hasPrefix($0) }) {
                return .blocked(reason: "Command not in allowed list")
            }
        }

        // Check if confirmation required
        for confirmCmd in requireConfirmation where trimmedCommand.contains(confirmCmd) {
            return .requiresConfirmation(reason: "Command requires user confirmation: \(confirmCmd)")
        }

        return .allowed
    }

    /// Check if a directory is within sandbox (if sandboxing is enabled)
    func isDirectoryAllowed(_ directory: URL) -> Bool {
        guard !sandboxedDirectories.isEmpty else { return true }

        let dirPath = directory.standardizedFileURL.path
        return sandboxedDirectories.contains { sandbox in
            let sandboxPath = sandbox.standardizedFileURL.path
            return dirPath.hasPrefix(sandboxPath)
        }
    }

    enum CommandValidation: Equatable {
        case allowed
        case blocked(reason: String)
        case requiresConfirmation(reason: String)
    }
}

/// Security level presets
enum SecurityLevel: String, CaseIterable, Codable {
    case unrestricted = "Unrestricted"
    case standard = "Standard"
    case sandboxed = "Sandboxed"

    var policy: TerminalSecurityPolicy {
        switch self {
        case .unrestricted: return .unrestricted
        case .standard: return .default
        case .sandboxed: return .sandboxed
        }
    }

    var description: String {
        switch self {
        case .unrestricted:
            return "Full access to all commands. Use with caution."
        case .standard:
            return "Balanced security with dangerous commands blocked."
        case .sandboxed:
            return "Restricted to safe commands in allowed directories only."
        }
    }
}
