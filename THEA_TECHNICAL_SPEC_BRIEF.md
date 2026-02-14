# THEA: Technical Specification Brief for External Architect

**Purpose:** Enable design of Thea Audit Agent, Git-triggered audits, risk-trend dashboard, and LLM/agent security extension
**Date:** January 23, 2026
**Status:** Extracted from codebase analysis

---

## 1. THEA: CURRENT STATE

### 1.1 Code & Runtime

- **Primary language:** Swift 6.0 (strict concurrency enabled)
- **Secondary languages:** TypeScript (MCP server tooling)
- **Invocation methods:**
  - Native macOS/iOS application (SwiftUI-based)
  - Swift Package Manager CLI (`swift build`, `swift test`)
  - Xcode project (generated via XcodeGen from `project.yml`)
  - MCP server (`Tools/terminal-mcp-server/`) - Node.js standalone
- **Current execution environments:**
  - **Locally:** Yes - primary development and runtime environment
  - **In CI:** Yes - GitHub Actions (`ci.yml`, `release.yml`, `dependencies.yml`)
  - **Both confirmed**

### 1.2 Execution Model

- **Application type:** Multi-platform GUI application with embedded agentic capabilities
- **Runtime pattern:**
  - Long-running application (macOS/iOS app)
  - Autonomous task execution via `SelfExecutionService` (actor-based)
  - MCP server component runs as separate process (Node.js)
- **Execution characteristics:**
  - **Asynchronous:** Yes - Swift async/await throughout, actor isolation
  - **Event-driven:** Yes - NotificationCenter for approval gates, SwiftUI reactivity
  - **Autonomous phases:** Multi-phase task decomposition with optional human gates

### 1.3 Repository Layout

```
Thea/
├── Shared/                    # Cross-platform Swift code
│   ├── AI/                   # AI providers, MetaAI systems, agentic components
│   │   ├── MetaAI/          # 60 files - agent orchestration, tools, self-execution
│   │   │   └── SelfExecution/  # Autonomous task execution subsystem
│   │   ├── Providers/        # OpenAI, Anthropic, etc. API clients
│   │   └── PromptEngineering/
│   ├── Core/                 # Services, managers, models
│   ├── System/               # Terminal execution, OS integration
│   │   └── Terminal/         # TerminalCommandExecutor, SecurityPolicy
│   ├── Monitoring/           # Privacy, activity logging
│   ├── Tracking/             # Browser history, input, location, screen time
│   ├── RemoteServer/         # Remote control/proxy server (CRITICAL RISK)
│   ├── Cowork/               # File operations, folder access
│   └── UI/                   # SwiftUI views
├── macOS/                    # macOS-specific code and entitlements
├── iOS/                      # iOS-specific code and entitlements
├── Tools/
│   └── terminal-mcp-server/  # TypeScript MCP server for terminal access
├── Tests/                    # Unit and integration tests
├── Scripts/                  # Build, deployment, validation scripts (27 files)
├── .github/workflows/        # CI/CD pipelines
├── Planning/                 # THEA_SPECIFICATION.md (85KB master spec)
└── Documentation/            # Architecture, guides
```

- **Monorepo:** Yes - single repo containing app, MCP server, scripts, CI
- **Analysis scope:** Analyzes its own repo (self-execution) and can analyze arbitrary directories via tools

---

## 2. CI / AUTOMATION ASSUMPTIONS

### Current CI Platform

- **Platform:** GitHub Actions (confirmed)
- **Runner:** macOS 14 (`macos-14`) for builds, Ubuntu for analysis jobs
- **Xcode:** 16.2 (configured via `DEVELOPER_DIR`)

### Technology Requirements

| Technology | Already Used | Installation Acceptable |
|------------|--------------|------------------------|
| Node.js    | Yes (MCP server) | Yes |
| Python     | No (in app) | Unknown - not in current CI |
| Docker     | No | Unknown - not in current CI |
| Swift/Xcode| Yes | Yes |
| Homebrew   | Yes (SwiftLint, XcodeGen) | Yes |

### Git-Triggered Audit Expectations

- **Current triggers:** `push` to main/develop/feature/release branches; `pull_request` to main/develop
- **Existing behaviors:**
  - SwiftLint runs with `continue-on-error: true` (non-blocking)
  - Build failures block merge (`fail if critical checks failed`)
  - Test failures non-blocking (`continue-on-error: true`)
- **Audit expectations:** **Unknown** - no security audit gate currently exists in CI
  - **Decision needed:** Should audits block PRs, comment, or artifact-only?

### Local vs CI Parity

- **Unknown** - Current CI uses `swift build` and `xcodebuild`, matches local
- XcodeGen generates project at CI time, may differ from local .xcodeproj state
- MCP server not tested in CI

---

## 3. AUDIT INTENT & RIGOR

### Evidence from Existing Audit Report

The `SECURITY_AUDIT_REPORT.md` (January 23, 2026) provides precedent:

- **Audit purpose:** Release blocker (explicit "NO-GO" recommendation)
- **Finding severity levels:** CRITICAL, HIGH, MEDIUM
- **Approach:** Comprehensive static analysis with explicit risk ranking

### Inferred Audit Philosophy

- **False-positive tolerance:** Low to Medium
  - Audit report uses "confirmed" confidence level
  - Clear verification steps specified per finding
- **Uncertainty handling:** **Conservative** - flags risks explicitly
  - 15 findings documented with explicit confidence markers
- **Gate behavior:** Based on existing audit:
  - CRITICAL findings = release blocker
  - HIGH findings = require remediation plan
  - MEDIUM = tracked, not blocking

---

## 4. DATA & OUTPUT EXPECTATIONS

### Current Outputs

| Output Type | Format | Location |
|-------------|--------|----------|
| Security audit | Markdown | `SECURITY_AUDIT_REPORT.md` (root) |
| Build logs | Text | `build.log`, `build_output.txt`, `analyze_output.txt` |
| SwiftLint report | JSON | CI artifact (`swiftlint-report.json`) |
| Coverage | XML/JSON/LCOV | CI artifacts |
| Test results | `.xcresult` | CI artifacts |

### Existing External Integrations

- **CodeCov:** Coverage upload (token: `CODECOV_TOKEN`)
- **SonarCloud:** Static analysis (token: `SONAR_TOKEN`)
- **DeepSource:** Code analysis (token: `DEEPSOURCE_DSN`)

### Output Storage Strategy

- **Committed to repo:** Yes - `SECURITY_AUDIT_REPORT.md` is committed
- **CI artifacts:** Yes - test results, coverage, lint reports
- **External storage:** CodeCov, SonarCloud, DeepSource cloud

### Long-term Trend Analysis

- **Desired:** Likely yes (CodeCov/SonarCloud track trends)
- **Decision needed:** Should audit findings be tracked over time? What granularity?

---

## 5. RISK & POLICY MODEL

### Current Governance Evidence

From `TerminalSecurityPolicy.swift`:
- Explicit blocked commands list
- Regex patterns for dangerous operations
- `requireConfirmation` list for human approval
- Three preset levels: `unrestricted`, `standard`, `sandboxed`

From `ApprovalGate.swift`:
- Approval levels: `phaseStart`, `fileCreation`, `buildFix`, `phaseComplete`, `dmgCreation`
- Auto-approval for non-critical operations (FINDING-005 vulnerability)
- Verbose mode for step-by-step approval

### Gate Enforcement

- **Hard gates:** Not currently enforced in CI
- **Existing audit recommendation:** Block release on CRITICAL findings

### Override/Allowlist Mechanism

- **Policy file:** `TerminalSecurityPolicy` supports allowlists and blocklists
- **SECURITY.md:** Documents accepted risk checklist
- **Decision needed:** Should "accepted risk" be formalized with sign-off?

### Authority Model

- **Current:** Human reviewer (manual audit report creation)
- **Potential:** Policy file + agent consensus (not implemented)
- **Kill switch:** Cancellation flag exists but not enforced in loops (FINDING noted)

---

## 6. AGENTIC / LLM CHARACTERISTICS (CRITICAL)

### LLM Usage

- **Direct LLM calls:** Yes
  - Anthropic (Claude) via `AnthropicProvider.swift`
  - OpenAI (GPT-4) via `OpenAIProvider.swift`
  - Google (Gemini), Groq, Perplexity, OpenRouter
  - Local models (Ollama, MLX)
- **Provider abstraction:** `AIProviderProtocol.swift`

### Agent Orchestration

| Component | Purpose | Location |
|-----------|---------|----------|
| `SelfExecutionService` | Multi-phase autonomous task execution | `Shared/AI/MetaAI/SelfExecution/` |
| `SubAgentOrchestrator` | Task distribution to sub-agents | `SubAgentOrchestrator.swift` |
| `AgentSwarm` | Multi-agent coordination | `AgentSwarm.swift` |
| `AgentCommunicationHub` | Inter-agent messaging | `AgentCommunicationHub.swift` |
| `DeepAgentEngine` | Extended reasoning/planning | `DeepAgentEngine.swift` |

### Autonomous Tool Invocation

**Yes - Critical capability with insufficient controls:**

| Tool | Capability | Security Status |
|------|------------|-----------------|
| `TerminalTool` | Arbitrary shell execution | **CRITICAL** - No command validation |
| `FileReadTool` | Read any file | No path restrictions |
| `FileWriteTool` | Write any file | No path restrictions |
| `HTTPRequestTool` | Arbitrary network requests | No URL validation |
| `BrowserAutomation` | Web automation | Unknown sandboxing |

### Memory & State

- **Memory system:** `MemorySystem.swift` (21KB)
- **Persistent state:**
  - SwiftData for conversations and tracking
  - Encrypted JSON for activity logs
  - UserDefaults for configuration (insecure per audit)
  - Keychain for secrets
- **Cross-run learning:**
  - `KnowledgeGraph.swift` - persistent knowledge storage
  - `ErrorKnowledgeBase.swift` - learns from compilation errors
  - `ModelTraining.swift` - fine-tuning capabilities

### Dangerous Capabilities

| Capability | Implementation | Risk |
|------------|---------------|------|
| File writes | `FileWriteTool`, `FileCreator` | Auto-approved, no sandboxing |
| Network calls | `HTTPRequestTool`, Remote proxy | SSRF vulnerability |
| Command execution | `TerminalCommandExecutor`, MCP server | Arbitrary code execution |
| AppleScript | Via terminal with simple escaping | Command injection |

### Guardrails

| Guardrail | Status |
|-----------|--------|
| Blocked command patterns | Partial - bypassable |
| Approval gates | Bypassed for file operations |
| Execution timeouts | Configured (2 min default) but unenforced in loops |
| Human-in-the-loop | Only for phase transitions, not actions |
| Kill switch | Flag exists, not enforced |
| Audit logging | OSLog (ephemeral), no tamper evidence |

---

## 7. SECURITY SENSITIVITY

### Data Handled

| Data Type | Sensitivity | Storage |
|-----------|-------------|---------|
| AI API keys | CRITICAL | Keychain (SecureStorage) |
| Browser history | CRITICAL | SwiftData |
| Keystrokes | CRITICAL | InputTrackingManager (unfiltered) |
| Location | CRITICAL | CoreLocation |
| Health data | CRITICAL | HealthKit |
| Conversations | HIGH | SwiftData/Memory |
| Activity logs | HIGH | Encrypted JSON |
| Financial data | CRITICAL | In-memory (planned) |

### Production Access

- **Private repos:** Can access via Git commands
- **Production configs:** Can read any file on system
- **Secrets:** Expected to handle API keys (Keychain storage)

### Audit Data Sensitivity

- **Browser history URLs logged with query parameters** (FINDING-009)
- **Keystroke data includes password fields** (FINDING-008)
- **Commands logged but may contain secrets**

### Required Redactions in Audit Output

- Secrets (API keys, tokens)
- PII (if location/health data exposed)
- Prompts/responses containing user data
- URL query parameters (may contain auth tokens)

---

## 8. CONSTRAINTS & NON-GOALS

### Explicit Non-Goals (Current Scope)

- iOS build disabled in CI (macOS-first development)
- watchOS/tvOS/visionOS - present but not CI-tested
- No SAST/DAST in CI pipeline (FINDING-013)
- No security scanning in CI

### Thea Should NOT Do (Per Audit)

1. Execute arbitrary shell commands without validation
2. Auto-approve file operations
3. Allow `fullAuto` execution mode
4. Accept all TLS certificates
5. Proxy arbitrary network requests
6. Log passwords/credentials
7. Store sensitive config in UserDefaults

### Intentionally Out of Scope (For Now)

- Cloud deployment (local-first design)
- Multi-user access control
- Enterprise compliance frameworks (SOC2, etc.)
- Real-time monitoring dashboard

---

## 9. OPEN QUESTIONS (FOR FOLLOW-UP)

### Questions That MUST Be Answered

1. **Audit gate behavior:** Should CI audits block PRs, add comments, or only upload artifacts?
2. **Accepted risk process:** Is formal sign-off required? Who is the authority?
3. **Audit frequency:** Every PR? Daily? Release-only?
4. **Trend tracking scope:** Which metrics? How far back?

### Questions That CAN Be Deferred

1. Should Python tooling be added to CI?
2. Should Docker be used for reproducible audits?
3. Dashboard technology choice (Grafana, custom, etc.)
4. Retention policy for audit artifacts

### Decisions That BLOCK Correct Design

1. **CRITICAL:** Is `fullAuto` mode removal a requirement or configurable?
2. **CRITICAL:** Should file operations require approval in all modes?
3. **HIGH:** What is the acceptable attack surface for MCP server?
4. **HIGH:** Is the remote server feature in scope or should it be disabled?

---

## 10. SUMMARY FOR EXTERNAL ARCHITECT

### What You're Designing For

**Thea** is a Swift 6.0 macOS/iOS application with embedded agentic AI capabilities that can:
- Execute arbitrary shell commands
- Read/write any file
- Make network requests
- Orchestrate multi-agent task execution
- Learn from interactions and persist knowledge

### Critical Security Facts

1. **15 documented vulnerabilities** (5 CRITICAL, 7 HIGH, 3 MEDIUM)
2. **No security scanning in CI** currently
3. **Approval gates bypass for file operations**
4. **Kill switches exist but are not enforced**
5. **Extensive surveillance capabilities** (keystrokes, location, browser history)

### What External System Must Integrate With

| System | Interface | Notes |
|--------|-----------|-------|
| GitHub Actions | YAML workflows | Existing CI infrastructure |
| Swift toolchain | SPM, xcodebuild | Primary build system |
| MCP Protocol | TypeScript server | Terminal/tool access |
| Keychain | SecureStorage wrapper | Secrets management |
| SwiftData | Persistence layer | Conversation/tracking storage |

### Audit Agent Design Constraints

1. Must run on macOS 14+ (Swift 6.0 requirement)
2. Should integrate with existing CodeCov/SonarCloud/DeepSource
3. Must not require secrets in command-line arguments
4. Should produce machine-readable (JSON/YAML) and human-readable (Markdown) output
5. Should respect existing `TerminalSecurityPolicy` patterns

---

*This brief extracted from Thea codebase analysis. All "unknown" markers represent genuine gaps requiring stakeholder input.*
