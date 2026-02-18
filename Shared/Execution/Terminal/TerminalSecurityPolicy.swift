#if os(macOS)
    import Foundation

    /// Security policy for terminal command execution
    struct TerminalSecurityPolicy: Codable, Equatable {
        var allowedCommands: [String] // Whitelist (empty = all allowed)
        var blockedCommands: [String] // Blacklist
        var blockedPatterns: [String] // Regex patterns to block
        var requireConfirmation: [String] // Commands requiring user approval
        var allowSudo: Bool // Whether sudo is permitted
        var allowNetworkCommands: Bool // curl, wget, ssh, etc.
        var allowFileModification: Bool // rm, mv, cp to system dirs
        var sandboxedDirectories: [URL] // Restrict to these directories (empty = no restriction)
        var maxExecutionTime: TimeInterval // Kill after timeout
        var logAllCommands: Bool // Log all executed commands
        var redactSensitiveOutput: Bool // Redact passwords, keys in output

        // SECURITY: Secure defaults - user must explicitly enable dangerous features
        static var `default`: TerminalSecurityPolicy {
            TerminalSecurityPolicy(
                allowedCommands: [],
                blockedCommands: [
                    // Catastrophic system damage
                    "rm -rf /",
                    "rm -rf /*",
                    ":(){ :|:& };:", // Fork bomb
                    "dd if=/dev/zero of=/dev/sda",
                    "mkfs",
                    "> /dev/sda",
                    "mv ~ /dev/null",
                    "chmod -R 777 /",
                    "chown -R nobody /",
                    // Data exfiltration
                    "base64 /etc/passwd",
                    "xxd /etc/shadow",
                    // Cryptominers
                    "xmrig",
                    "minerd",
                    "cpuminer"
                ],
                blockedPatterns: [
                    "rm\\s+-rf\\s+/(?!tmp|var/tmp)", // rm -rf on root dirs except tmp
                    "\\|\\s*rm\\s+-rf", // Piped rm -rf
                    "wget.*\\|.*bash", // Remote code execution
                    "curl.*\\|.*sh", // Remote code execution
                    "curl.*\\|.*python", // Remote code execution via Python
                    "\\|\\s*base64\\s+-d\\s*\\|", // Decode and execute patterns
                    "python.*-c.*exec", // Python exec injection
                    "eval\\s*\\(", // Shell eval
                    "\\$\\(.*\\).*\\|.*sh", // Command substitution to shell
                    "nc\\s+-e", // Netcat reverse shell
                    "bash\\s+-i.*>&", // Bash reverse shell
                    "/dev/tcp/", // Bash TCP device
                    "export\\s+.*PASSWORD", // Credential exposure
                    "echo.*>.*\\.ssh/authorized" // SSH key injection
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
                    "diskutil partitionDisk",
                    // SECURITY: Additional confirmation requirements
                    "chmod",
                    "chown",
                    "xattr",
                    "defaults write",
                    "security",
                    "codesign",
                    "spctl",
                    "osascript"
                ],
                allowSudo: false, // SECURITY: Require explicit opt-in
                allowNetworkCommands: true, // Allow for development workflows
                allowFileModification: true, // Allow for development workflows
                sandboxedDirectories: [], // No sandbox by default (user can configure)
                maxExecutionTime: 120, // SECURITY: 2 minutes default (was 5)
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
                // Safe: compile-time known block pattern; invalid regex → skip this pattern (allow-by-default for this pattern only)
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(trimmedCommand.startIndex..., in: trimmedCommand)
                    if regex.firstMatch(in: trimmedCommand, options: [], range: range) != nil {
                        return .blocked(reason: "Command matches blocked pattern")
                    }
                }
            }

            // Check sudo permission
            if !allowSudo, trimmedCommand.hasPrefix("sudo ") {
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

    /// Terminal security level presets
    enum TerminalSecurityLevel: String, CaseIterable, Codable {
        case unrestricted = "Unrestricted"
        case standard = "Standard"
        case sandboxed = "Sandboxed"

        var policy: TerminalSecurityPolicy {
            switch self {
            case .unrestricted: .unrestricted
            case .standard: .default
            case .sandboxed: .sandboxed
            }
        }

        var description: String {
            switch self {
            case .unrestricted:
                "Full access to all commands. Use with caution."
            case .standard:
                "Balanced security with dangerous commands blocked."
            case .sandboxed:
                "Restricted to safe commands in allowed directories only."
            }
        }
    }

#endif
