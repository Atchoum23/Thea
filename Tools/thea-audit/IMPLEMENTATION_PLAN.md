# thea-audit Implementation Plan

## Repository Reconnaissance Summary

### 1. Project Structure

```
Thea/
├── Package.swift                     # SPM package definition (Swift 6.0)
├── Shared/                           # Main source code
│   ├── AI/MetaAI/                    # AI agent code
│   │   ├── SelfExecution/            # Autonomous execution
│   │   │   ├── ApprovalGate.swift    # Approval system
│   │   │   └── SelfExecutionService.swift
│   │   ├── SystemToolBridge.swift    # Tool definitions (FileRead/Write/Terminal/HTTP)
│   │   ├── ToolFramework.swift       # Tool registration & execution
│   │   └── FileOperations.swift      # File operations (no security checks)
│   ├── System/Terminal/              # Terminal execution
│   │   ├── TerminalSecurityPolicy.swift  # Security policy (blocklists, sandboxing)
│   │   └── TerminalCommandExecutor.swift
│   └── RemoteServer/                 # Remote server capabilities
│       ├── TheaRemoteServer.swift    # Main server (SSRF risk via network proxy)
│       └── SecureConnectionManager.swift
├── Tests/                            # XCTest test targets
│   ├── MetaAITests/                  # Existing tests (minimal)
│   └── ...
├── Tools/                            # External tools
│   └── terminal-mcp-server/          # MCP server (TypeScript)
├── Scripts/                          # Shell scripts (25 files)
└── .github/workflows/                # CI/CD
    ├── ci.yml                        # Main CI (has security scanning)
    └── release.yml                   # Release workflow
```

### 2. Existing Security Policy Code

| File | Purpose | Key Types |
|------|---------|-----------|
| `TerminalSecurityPolicy.swift` | Command validation | `TerminalSecurityPolicy`, `CommandValidation`, `SecurityLevel` |
| `ApprovalGate.swift` | Human approval gates | `ApprovalGate`, `ApprovalLevel`, `ApprovalRequest` |
| `SystemToolBridge.swift` | Tool security wrappers | `FileWriteTool`, `TerminalTool`, `HTTPRequestTool` |
| `ToolFramework.swift` | Tool execution | `ToolError` (commandBlocked, pathBlocked) |

### 3. Test Patterns

- **Framework**: XCTest with `@testable import TheaCore`
- **Location**: `Tests/` directory with subdirectories by module
- **Pattern**: `@MainActor final class XxxTests: XCTestCase`
- **Current state**: Minimal tests, many marked as TODO

### 4. Identified Security Enforcement Points

1. **Terminal Execution**: `TerminalSecurityPolicy.isAllowed()` → `TerminalCommandExecutor`
2. **File Operations**: `FileWriteTool.blockedPaths` → hardcoded check
3. **Approval Gates**: `ApprovalGate.requestApproval()` → conditional auto-approve
4. **HTTP Requests**: `HTTPRequestTool` → no URL validation
5. **MCP Server**: `isPathAllowed()` → allowlist/blocklist

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        thea-audit CLI                                │
├─────────────────────────────────────────────────────────────────────┤
│  ArgumentParser                                                      │
│  ├── --path <path>       # Repository path                          │
│  ├── --format yaml|json  # Output format                            │
│  ├── --output <file>     # Output file                              │
│  ├── --severity critical|high|medium|low                            │
│  ├── --delta             # PR delta mode (changed files only)       │
│  └── --strict            # Fail on any high+ finding                │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        AuditEngine                                   │
├─────────────────────────────────────────────────────────────────────┤
│  1. Load scanners from ScannerRegistry                              │
│  2. For each scanner:                                               │
│     - Collect files matching scanner's glob pattern                 │
│     - Run scanner rules on each file                                │
│     - Collect findings                                              │
│  3. Aggregate findings                                              │
│  4. Evaluate against AgentSec policy                                │
│  5. Generate outputs (YAML/JSON + Markdown)                         │
└─────────────────────────────────────────────────────────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│   SwiftScanner      │ │  WorkflowScanner    │ │   ScriptScanner     │
├─────────────────────┤ ├─────────────────────┤ ├─────────────────────┤
│ Rules:              │ │ Rules:              │ │ Rules:              │
│ - ApprovalBypass    │ │ - SecretsInEnv      │ │ - CurlPipe          │
│ - AllowlistGap      │ │ - UntrustedAction   │ │ - SudoUsage         │
│ - URLValidation     │ │ - MissingPinning    │ │ - HardcodedCreds    │
│ - PathValidation    │ │ - PermissionEscal   │ │ - UnsafeEval        │
└─────────────────────┘ └─────────────────────┘ └─────────────────────┘
              │                     │                     │
              └─────────────────────┼─────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   AgentSecPolicyEvaluator                            │
├─────────────────────────────────────────────────────────────────────┤
│  Policy: thea-policy.json                                            │
│  ├── network.blockedHosts: [169.254.*, localhost, 127.0.0.1, ...]   │
│  ├── filesystem.blockedPaths: [/System, /Library, .ssh, ...]        │
│  ├── terminal.blockedPatterns: [rm -rf /, sudo, ...]                │
│  ├── approval.requiredForTypes: [fileWrite, terminalExec, ...]      │
│  └── killSwitch: {enabled: true, triggerOnCritical: true}           │
│                                                                      │
│  Evaluates findings against policy invariants                        │
│  Returns: {compliant: bool, violations: [...]}                       │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Output Writers                                │
├─────────────────────────────────────────────────────────────────────┤
│  YAMLWriter.write(findings, to: path)                               │
│  JSONWriter.write(findings, to: path)                               │
│  MarkdownWriter.write(findings, to: path)  # PR summary             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## File Tree (to be created)

```
Tools/thea-audit/
├── Package.swift                    # SPM executable package
├── Sources/
│   └── thea-audit/
│       ├── main.swift               # Entry point
│       ├── Commands/
│       │   └── AuditCommand.swift   # ArgumentParser command
│       ├── Core/
│       │   ├── AuditEngine.swift    # Main orchestrator
│       │   ├── Finding.swift        # Finding model
│       │   ├── Severity.swift       # Severity enum
│       │   └── FileCollector.swift  # Glob-based file collection
│       ├── Scanners/
│       │   ├── Scanner.swift        # Scanner protocol
│       │   ├── Rule.swift           # Rule protocol
│       │   ├── ScannerRegistry.swift
│       │   ├── SwiftScanner.swift
│       │   ├── WorkflowScanner.swift
│       │   ├── ScriptScanner.swift
│       │   └── MCPServerScanner.swift
│       ├── Rules/
│       │   ├── Swift/
│       │   │   ├── ApprovalBypassRule.swift
│       │   │   ├── AllowlistGapRule.swift
│       │   │   ├── URLValidationRule.swift
│       │   │   └── PathValidationRule.swift
│       │   ├── Workflow/
│       │   │   ├── SecretsInEnvRule.swift
│       │   │   ├── UntrustedActionRule.swift
│       │   │   └── MissingPinningRule.swift
│       │   ├── Script/
│       │   │   ├── CurlPipeRule.swift
│       │   │   ├── SudoUsageRule.swift
│       │   │   └── HardcodedCredsRule.swift
│       │   └── MCP/
│       │       ├── PathRestrictionRule.swift
│       │       └── CommandInjectionRule.swift
│       ├── AgentSec/
│       │   ├── AgentSecPolicy.swift       # Policy model
│       │   ├── PolicyEvaluator.swift      # Enforcement
│       │   └── StrictModeConfig.swift     # Strict mode settings
│       └── Writers/
│           ├── YAMLWriter.swift
│           ├── JSONWriter.swift
│           └── MarkdownWriter.swift
└── Tests/
    └── thea-auditTests/
        ├── SwiftScannerTests.swift
        ├── WorkflowScannerTests.swift
        ├── ScriptScannerTests.swift
        ├── MCPServerScannerTests.swift
        ├── PolicyEvaluatorTests.swift
        └── AgentSecStrictModeTests.swift

Shared/AgentSec/                      # AgentSec Strict Mode (main app)
├── AgentSecPolicy.swift              # Central policy model
├── AgentSecEnforcer.swift            # Runtime enforcement
├── AgentSecKillSwitch.swift          # Emergency stop
└── AgentSecAuditLog.swift            # Audit logging

.github/workflows/
├── thea-audit-pr.yml                 # PR delta mode
└── thea-audit-main.yml               # Full audit on main
```

---

## Implementation Checklist

### Prompt 2: CLI Skeleton
- [ ] Create `Tools/thea-audit/Package.swift` with ArgumentParser dependency
- [ ] Implement `main.swift` entry point
- [ ] Implement `AuditCommand.swift` with all flags
- [ ] Create stub `Scanner` protocol
- [ ] Create stub `Rule` protocol
- [ ] Create `Finding` model
- [ ] Create `Severity` enum
- [ ] Implement `YAMLWriter` and `JSONWriter`
- [ ] Implement `MarkdownWriter`
- [ ] Verify: `swift build` succeeds

### Prompt 3: Core Scanners
- [ ] Implement `FileCollector` with glob support
- [ ] Implement `ScannerRegistry`
- [ ] Implement `SwiftScanner` with rules:
  - [ ] `ApprovalBypassRule` - detect `!verboseMode` auto-approve
  - [ ] `AllowlistGapRule` - detect missing blocked patterns
  - [ ] `URLValidationRule` - detect HTTPRequestTool without URL validation
  - [ ] `PathValidationRule` - detect file operations without path checks
- [ ] Implement `WorkflowScanner` with rules:
  - [ ] `SecretsInEnvRule` - detect ${{ secrets.* }} in env
  - [ ] `UntrustedActionRule` - detect third-party actions without pinning
  - [ ] `MissingPinningRule` - detect @main/@latest tags
- [ ] Implement `ScriptScanner` with rules:
  - [ ] `CurlPipeRule` - detect curl|sh patterns
  - [ ] `SudoUsageRule` - detect sudo usage
  - [ ] `HardcodedCredsRule` - detect API keys, tokens
- [ ] Implement `MCPServerScanner` with rules:
  - [ ] `PathRestrictionRule` - verify isPathAllowed implementation
  - [ ] `CommandInjectionRule` - detect shell injection risks
- [ ] Verify: `swift test` passes for all scanners

### Prompt 4: AgentSec Strict Mode
- [ ] Create `Shared/AgentSec/AgentSecPolicy.swift`:
  - [ ] `network.blockedHosts` invariant
  - [ ] `filesystem.blockedPaths` invariant
  - [ ] `terminal.blockedPatterns` invariant
  - [ ] `approval.requiredForTypes` invariant
  - [ ] `killSwitch` settings
- [ ] Create `Shared/AgentSec/AgentSecEnforcer.swift`:
  - [ ] Hook into `HTTPRequestTool.execute()`
  - [ ] Hook into `FileWriteTool.execute()`
  - [ ] Hook into `TerminalTool.execute()`
  - [ ] Hook into `ApprovalGate.requestApproval()`
- [ ] Create `Shared/AgentSec/AgentSecKillSwitch.swift`:
  - [ ] Emergency stop on critical violation
  - [ ] Notification to user
- [ ] Create `Shared/AgentSec/AgentSecAuditLog.swift`:
  - [ ] Log all security-relevant operations
- [ ] Write tests:
  - [ ] `testPromptInjectionBlocked`
  - [ ] `testMetadataEndpointBlocked`
  - [ ] `testFileWriteOutsideWorkspaceBlocked`
  - [ ] `testShellCommandSanitized`
  - [ ] `testKillSwitchTriggered`
- [ ] Verify: All AgentSec tests pass

### Prompt 5: Wire thea-audit to AgentSec
- [ ] Add thea-audit rules for AgentSec invariants:
  - [ ] `NetworkBlocklistRule` - verify blockedHosts are enforced
  - [ ] `FilesystemBlocklistRule` - verify blockedPaths are enforced
  - [ ] `TerminalBlocklistRule` - verify blockedPatterns are enforced
  - [ ] `ApprovalRequirementRule` - verify approval gates exist
- [ ] Implement `PolicyEvaluator`:
  - [ ] Load policy from `thea-policy.json`
  - [ ] Evaluate findings against policy
  - [ ] Return compliance status
- [ ] Generate `thea-policy.json` from scan
- [ ] Generate `thea-pr-summary.md` for PRs
- [ ] Verify: End-to-end audit produces valid outputs

### Prompt 6: GitHub Actions
- [ ] Create `.github/workflows/thea-audit-pr.yml`:
  - [ ] Trigger on PR to main/develop
  - [ ] Run `thea-audit --delta` on changed files
  - [ ] Post PR comment with summary
  - [ ] Fail on critical/high findings
- [ ] Create `.github/workflows/thea-audit-main.yml`:
  - [ ] Trigger on push to main
  - [ ] Run full `thea-audit` scan
  - [ ] Upload artifacts (YAML, Markdown)
  - [ ] Create issue on critical findings
- [ ] Verify: Workflows validate and run successfully

---

## Key Security Invariants (AgentSec Strict Mode)

### 1. Network Security
```swift
// MUST block localhost, metadata endpoints, internal IPs
let blockedHosts = [
    "localhost", "127.0.0.1", "::1",
    "169.254.169.254",  // AWS metadata
    "metadata.google.internal",
    "10.*", "172.16.*", "192.168.*"
]
```

### 2. Filesystem Security
```swift
// MUST block writes outside workspace
let blockedPaths = [
    "/System", "/Library", "/private", "/var", "/etc",
    "/bin", "/sbin", "/usr",
    ".ssh", ".gnupg", ".aws", ".kube", "Keychain"
]
```

### 3. Terminal Security
```swift
// MUST block dangerous command patterns
let blockedPatterns = [
    "rm -rf /", "sudo", "chmod 777",
    "curl|sh", "wget|bash",
    "eval", "exec", "`"
]
```

### 4. Approval Requirements
```swift
// MUST require human approval for:
let requiredApprovalTypes: [ApprovalType] = [
    .fileWrite,        // Any file write
    .terminalExec,     // Terminal commands
    .networkRequest,   // External HTTP requests
    .systemConfig      // System configuration changes
]
```

### 5. Kill Switch
```swift
// MUST halt on critical violations
struct KillSwitch {
    var enabled = true
    var triggerOnCritical = true
    var notifyUser = true
    var logToAudit = true
}
```

---

## Dependencies

### thea-audit Package.swift
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "thea-audit",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "thea-audit", targets: ["thea-audit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "thea-audit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .testTarget(
            name: "thea-auditTests",
            dependencies: ["thea-audit"]
        )
    ]
)
```

---

## Next Steps

Proceed to **Prompt 2**: Implement the thea-audit CLI skeleton with ArgumentParser, stub protocols, and output writers.
