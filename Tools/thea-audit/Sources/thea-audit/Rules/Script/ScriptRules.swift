// ScriptRules.swift
// Security rules for shell scripts

import Foundation

/// Rule that detects curl pipe to shell patterns
final class CurlPipeRule: RegexRule {
    init() {
        super.init(
            id: "SCRIPT-CURL-001",
            name: "Curl Pipe to Shell",
            description: """
                Detects dangerous curl|sh patterns that execute remote code:
                - curl URL | sh
                - wget URL | bash
                - curl URL | python
                These patterns execute untrusted code and are a major security risk.
                """,
            severity: .critical,
            category: .injection,
            cweID: "CWE-94",
            recommendation: """
                Never pipe untrusted content directly to a shell.
                Instead:
                1. Download the script first
                2. Review its contents
                3. Verify checksums if available
                4. Execute only after verification
                """,
            patterns: [
                "curl.*\\|.*sh",
                "curl.*\\|.*bash",
                "curl.*\\|.*zsh",
                "wget.*\\|.*sh",
                "wget.*\\|.*bash",
                "curl.*\\|.*python",
                "curl.*\\|.*perl",
                "fetch.*\\|.*sh"
            ],
            excludePatterns: [
                "^\\s*#"  // Comments
            ]
        )
    }
}

/// Rule that detects sudo usage
final class SudoUsageRule: RegexRule {
    init() {
        super.init(
            id: "SCRIPT-SUDO-001",
            name: "Sudo Usage Detected",
            description: """
                Detects sudo commands in scripts which grant elevated privileges.
                sudo in automated scripts can lead to privilege escalation.
                """,
            severity: .medium,
            category: .authorization,
            cweID: "CWE-269",
            recommendation: """
                Avoid sudo in scripts where possible.
                If required:
                - Document why root is needed
                - Limit scope of sudo commands
                - Consider using specific sudoers rules
                - Don't store sudo passwords in scripts
                """,
            patterns: [
                "\\bsudo\\b",
                "\\bsu\\s+-",
                "\\bsu\\s+root"
            ],
            excludePatterns: [
                "^\\s*#"  // Comments
            ]
        )
    }
}

/// Rule that detects hardcoded credentials
final class HardcodedCredsRule: RegexRule {
    init() {
        super.init(
            id: "SCRIPT-CREDS-001",
            name: "Hardcoded Credentials",
            description: """
                Detects potentially hardcoded credentials in scripts:
                - API keys
                - Passwords
                - Tokens
                - Private keys
                """,
            severity: .critical,
            category: .dataExposure,
            cweID: "CWE-798",
            recommendation: """
                Never hardcode credentials in scripts.
                Instead:
                - Use environment variables
                - Use secure credential stores (Keychain, Vault)
                - Use CI/CD secrets management
                - Use short-lived tokens where possible
                """,
            patterns: [
                "(?i)api[_-]?key\\s*=\\s*[\"'][^\"']+[\"']",
                "(?i)password\\s*=\\s*[\"'][^\"']+[\"']",
                "(?i)secret\\s*=\\s*[\"'][^\"']+[\"']",
                "(?i)token\\s*=\\s*[\"'][^\"']+[\"']",
                "(?i)auth\\s*=\\s*[\"'][^\"']+[\"']",
                "AKIA[A-Z0-9]{16}",  // AWS Access Key
                "-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----",
                "ghp_[A-Za-z0-9_]{36}",  // GitHub PAT
                "sk-[A-Za-z0-9]{48}"     // OpenAI API Key
            ],
            excludePatterns: [
                "\\$\\{?[A-Z_]+\\}?",  // Environment variable reference
                "\\$[A-Z_]+",          // Shell variable
                "\\bexample\\b",       // Example values
                "\\bplaceholder\\b",
                "\\bXXX\\b",
                "\\byour[-_]"
            ]
        )
    }
}

/// Rule that detects unsafe eval usage
final class UnsafeEvalRule: RegexRule {
    init() {
        super.init(
            id: "SCRIPT-EVAL-001",
            name: "Unsafe Eval Usage",
            description: """
                Detects dangerous eval and exec patterns:
                - eval with user input
                - exec with dynamic content
                - $() command substitution with variables
                These patterns can lead to command injection.
                """,
            severity: .high,
            category: .injection,
            cweID: "CWE-78",
            recommendation: """
                Avoid eval and exec where possible.
                If required:
                - Validate and sanitize all inputs
                - Use allow-list validation
                - Quote all variables properly
                - Consider safer alternatives
                """,
            patterns: [
                "\\beval\\s+[\"']?\\$",
                "\\beval\\s+\\$\\(",
                "\\bexec\\s+[\"']?\\$",
                "`\\$.*`",  // Backtick command substitution with variable
                "\\$\\(.*\\$.*\\)"  // Nested command substitution
            ],
            excludePatterns: [
                "^\\s*#"  // Comments
            ]
        )
    }
}

/// Rule that detects unquoted variables
final class UnquotedVariableRule: RegexRule {
    init() {
        super.init(
            id: "SCRIPT-QUOTE-001",
            name: "Unquoted Variable",
            description: """
                Detects unquoted variables that can lead to:
                - Word splitting attacks
                - Glob expansion attacks
                - Command injection via special characters
                """,
            severity: .medium,
            category: .injection,
            cweID: "CWE-78",
            recommendation: """
                Always quote variables in shell scripts:
                - Use "$variable" instead of $variable
                - Use "${variable}" for clarity
                - Use arrays for multiple values
                Consider using shellcheck for automated checking.
                """,
            patterns: [
                "\\s\\$[A-Za-z_][A-Za-z0-9_]*(?![\"'])",  // Unquoted variable after space
                "\\[\\s*\\$[^\"\\[]",  // Unquoted in test
                "=\\s*\\$[A-Za-z][^\"\\s]*\\s"  // Unquoted in assignment used later
            ],
            excludePatterns: [
                "\\$\\{",     // Braced variables are often properly handled
                "\\$\\(",     // Command substitution
                "\\$\\?",     // Exit status
                "\\$\\$",     // PID
                "\\$#",       // Argument count
                "\\$@",       // All arguments
                "\\$\\*",     // All arguments
                "^\\s*#"      // Comments
            ]
        )
    }
}

/// Rule that detects dangerous file operations
final class DangerousFileOpsRule: RegexRule {
    init() {
        super.init(
            id: "SCRIPT-FILE-001",
            name: "Dangerous File Operation",
            description: """
                Detects potentially dangerous file operations:
                - rm -rf without safeguards
                - chmod 777
                - Writing to system directories
                """,
            severity: .high,
            category: .accessControl,
            cweID: "CWE-732",
            recommendation: """
                Add safeguards to file operations:
                - Use variables for paths, verify before rm -rf
                - Avoid chmod 777, use minimal permissions
                - Don't write to /etc, /usr, /bin without good reason
                - Add dry-run options for destructive scripts
                """,
            patterns: [
                "rm\\s+-rf\\s+/(?!tmp)",  // rm -rf on root-level paths
                "rm\\s+-rf\\s+\\$",       // rm -rf with variable (potentially dangerous)
                "chmod\\s+777",
                "chmod\\s+-R\\s+777",
                ">\\s*/etc/",
                ">\\s*/usr/",
                "mv\\s+.*\\s+/bin/"
            ],
            excludePatterns: [
                "^\\s*#",     // Comments
                "\\|\\|",     // Error handling
                "&&\\s*rm"    // Conditional removal
            ]
        )
    }
}
