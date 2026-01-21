# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.4.x   | :white_check_mark: |
| 1.3.x   | :white_check_mark: |
| < 1.3   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in Thea, please report it responsibly:

1. **Do NOT** create a public GitHub issue for security vulnerabilities
2. Email security concerns to the maintainers directly
3. Include a detailed description of the vulnerability
4. Include steps to reproduce if possible
5. Allow reasonable time for a fix before public disclosure

## Security Features

### Credential Storage
- **API Keys**: Stored in macOS Keychain via `SecureStorage` (never in UserDefaults)
- **Encryption Keys**: 256-bit keys generated with `SecRandomCopyBytes` and stored in Keychain
- **Migration**: Automatic migration from legacy UserDefaults storage to Keychain

### Data Encryption
- **Activity Logs**: Encrypted with AES-256-GCM (CryptoKit)
- **Authentication**: Keys managed through secure Keychain storage
- **At Rest**: Sensitive data encrypted before disk storage

### Path Security
- **Traversal Prevention**: All file paths validated against base directory
- **Null Byte Injection**: Rejected
- **Suspicious Patterns**: Blocked (`...`, `//`, URL-encoded sequences)
- **Symlink Resolution**: Paths resolved before validation

### Terminal Security (Default Policy)
- **sudo**: Disabled by default (opt-in required)
- **Confirmation Required**: chmod, chown, rm -rf, shutdown, reboot, osascript
- **Blocked Patterns**:
  - Remote code execution: `curl | sh`, `wget | bash`
  - Reverse shells: `nc -e`, `bash -i`, `/dev/tcp`
  - Data exfiltration: encoded password dumps
  - Cryptominers: xmrig, minerd, cpuminer
- **Timeout**: 2-minute default execution limit
- **Logging**: All commands logged by default

### CI/CD Security
- **Tokens**: Passed via environment variables, never command-line arguments
- **Secrets**: Not logged or exposed in build outputs
- **Hardcoded Paths**: None - all paths resolved at runtime

## Security Best Practices for Users

### API Key Management
1. Use Settings > Providers to manage API keys
2. Keys are automatically stored in Keychain
3. Never store API keys in code or configuration files
4. Rotate keys periodically

### Terminal Usage
1. Review commands before execution when prompted
2. Keep sudo disabled unless specifically needed
3. Use sandboxed security level for untrusted workflows
4. Monitor command logs for suspicious activity

### Data Privacy
1. Activity logs are encrypted but contain usage patterns
2. Disable logging in Settings if privacy is a concern
3. Use "Clear All Data" to remove stored information
4. iCloud sync is opt-in and can be disabled

## Security Audit

Last comprehensive security audit: January 2026

### Findings Addressed
- [x] CRITICAL: QA tokens in command arguments
- [x] HIGH: API keys in UserDefaults
- [x] HIGH: Weak XOR encryption
- [x] HIGH: Hardcoded developer paths
- [x] MEDIUM: Path traversal vulnerabilities
- [x] MEDIUM: Permissive terminal defaults

## Compliance

Thea follows security best practices including:
- OWASP guidelines for secure coding
- Apple's App Security Guide
- CWE/SANS Top 25 vulnerability prevention
