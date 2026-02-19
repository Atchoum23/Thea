# THEA Project

## CRITICAL SAFETY RULES

### ⚠️ MANDATORY: Commit After Every Edit

**This rule is NON-NEGOTIABLE and must be followed WITHOUT EXCEPTION:**

1. **After EVERY file edit** (create, modify, delete), immediately run:
   ```bash
   cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
   git add -A && git commit -m "Auto-save: <brief description of change>"
   ```

2. **Before ANY destructive command** (rm, clean, reset), ALWAYS commit first:
   ```bash
   git add -A && git commit -m "Checkpoint before cleanup"
   ```

3. **Push to remote regularly** (at minimum every 5 commits):
   ```bash
   git pushsync origin main
   ```
   **IMPORTANT**: Always use `git pushsync` instead of `git push`. This pushes to origin AND triggers a sync build + install on the other Mac. A Claude Code hook enforces this — plain `git push` will be blocked.

### ⚠️ AUTONOMOUS SESSION START — MANDATORY FIRST STEPS

Every autonomous Claude Code session on MSM3U MUST begin with:
```bash
# 1. Suspend thea-sync (runs git stash every 5min — will silently revert your work)
launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null

# 2. Pull latest + check state (plan may have changed since you were spawned)
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git pull && git log --oneline -5 && git status --short && git stash list

# 3. Run build gate — fix any errors BEFORE touching new code
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination 'platform=macOS' build -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

And MUST end with:
```bash
git add -A && git commit -m "Auto-save: session end" || true
launchctl load ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
git pushsync
```

Full protocol: See `## SESSION SAFETY PROTOCOL` in THEA_SHIP_READY_PLAN_v2.md

### 🚫 FORBIDDEN Commands

**NEVER execute these commands under ANY circumstances:**

- `rm -rf` with wildcards (`*`) in ANY path
- `rm -rf ~/` or `rm -rf /`
- `rm -rf` on parent directories of the project
- `git clean -fdx` without explicit user confirmation
- `git reset --hard` without explicit user confirmation
- Any command that could delete the project directory
- `openclaw` anything — OpenClaw is uninstalled. Thea is the gateway. Do not reinstall.

### ✅ Safe DerivedData Cleanup

**When cleaning Xcode DerivedData, ONLY use this exact command:**
```bash
# First, commit current state
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && git add -A && git commit -m "Checkpoint before DerivedData cleanup" || true

# Then clean ONLY Thea-specific DerivedData (safe pattern)
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Thea-*" -type d -exec rm -rf {} + 2>/dev/null || true
```

**NEVER use:** `rm -rf ~/Library/Developer/Xcode/DerivedData/*`

---

## ⚠️ PROJECT CONTEXT — READ FIRST

**Thea is a personal-use app. It will NEVER be distributed on the App Store or any public marketplace.**

- Quality bar = App Store strict. Distribution = personal only.
- All life-monitoring features stay active: HealthKit, location, behavioral fingerprinting, driving detection, screen time, ambient intelligence — these are core capabilities, not App Store review concerns.
- **NEVER REMOVE anything.** Every class, feature, and capability must be kept and wired. If something seems unused, wire it — never delete it.
- This applies to ALL platforms: macOS, iOS, watchOS, tvOS, Tizen, TheaWeb.

---

## ⚠️ MANDATORY: COMPLETE EVERY POINT IN EVERY PROMPT (NON-NEGOTIABLE)

Every user message may contain multiple independent requests. **EVERY SINGLE ONE must be actioned.**

**Pre-work protocol (mandatory for any message with 2+ requests):**
1. Read the ENTIRE message before doing ANYTHING
2. Write out EVERY distinct request, task, or question as a numbered list — including parenthetical ones ("including claude.md?"), implicit ones ("edit all relevant files"), and meta ones ("how to resolve this?")
3. TaskCreate an entry for EACH item
4. Work through them all — in order of dependency, not order of "importance"
5. Before finalizing: re-read original message and confirm every item was actioned

**Forbidden failure modes:**
- Doing the "big" task and omitting smaller requests
- Treating parenthetical requests as optional (e.g. "including claude.md?" means YES, DO IT)
- Assuming one action "covers" another that wasn't explicitly done
- Leaving any request for a "follow-up session"

**Accountability**: If Alexis has to follow up with "you didn't address X", that is a process failure. Zero follow-up corrections is the goal.

---

## ⚠️ MANDATORY: NO-INTERRUPT — NEW PROMPTS QUEUE, NOT INTERRUPT

When Alexis sends a new message while work is in progress:
1. **Acknowledge briefly** (one line)
2. **TaskCreate for EACH new request** in the message
3. **FINISH current in-progress task completely** before switching
4. **THEN address all queued requests** in order

**Exception**: Explicit stop/override signals ("stop", "pause", "urgent:", "cancel that", "ignore") take immediate priority.

**Why**: Interrupting mid-task produces partial/incomplete work. For Thea specifically: the executor on MSM3U should continue running; new requests go into the plan file as queued phases.

---

## ⚠️ MANDATORY: SYSTEMATIC COMPLETENESS PROTOCOL

Root cause of missed items: starting work before fully parsing the prompt.

**Step 1 — PARSE FIRST, WORK SECOND:**
Before any edit, enumerate ALL requests:
```
User asked for:
1. [exact item 1]
2. [exact item 2]  ...
```
This list is the contract. Every item gets done or explicitly noted as blocked.

**Step 2 — TRACK EACH ITEM:** TaskCreate for every non-trivial item.

**Step 3 — FINAL CHECK before any commit/response:**
Re-read original message. For each sentence/clause that implies action: confirm it was done.

**Step 4 — WHEN IN DOUBT, DO IT:**
If unsure whether something was requested, do it. "Better done than debated."

**Step 5 — CROSS-FILE CONSISTENCY:**
Any rule that applies universally must be added to ALL relevant files simultaneously:
global CLAUDE.md + Thea CLAUDE.md + MEMORY.md. Not just "the obvious one."

---

## ⚠️ MANDATORY: RESEARCH-BEFORE-RECOMMEND (NON-NEGOTIABLE)

**NEVER make recommendations about code, files, or architecture without reading the actual source files first.**

- Before recommending which files to add, merge, activate, or cherry-pick: **READ THEM ALL**.
- Before recommending an integration strategy: **READ both the target files and source files**.
- Before recommending a fix: **READ the failing code first**.
- "I haven't read the files but I think..." is **FORBIDDEN** in this project.
- Sampling a few files is **INSUFFICIENT** when a decision affects an entire set of files.
- For MetaAI specifically: all ~71 cherry-pick candidates were individually reviewed at snippet level.
  Any future archive activation requires the same thoroughness.

**Enforcement**: If you catch yourself about to recommend without reading, STOP. Read first.

---

## ⚠️ MANDATORY: MECHANICAL VERIFICATION — NOT SELF-ASSESSMENT

**Rules and intentions are insufficient. Every deliverable must be mechanically verifiable.**

LLMs optimize for *apparent* completeness, not *actual* completeness. The fix is explicit, mechanical checking — not trusting self-assessment.

**For Thea code work:**
- "Wired" → `grep -r "ClassName" Shared/ --include="*.swift" | grep -v "own file" | wc -l` ≥ 1
- "View accessible" → NavigationLink/Tab reference found by grep
- "No stubs" → grep for TODO/FIXME/empty bodies returns 0 in changed files
- "Build passes" → actual xcodebuild BUILD SUCCEEDED (never assumed)

**For Thea plan work:**
- Every phase ends with its explicit verification bash script (already in each phase)
- A "wiring check" runs before any phase is marked ✅ DONE
- Every new file in Shared/ must map to a v3 phase — no file forgotten
- The Completeness Wiring Script (Phase AA3) must pass before Wave 6 ends

**Proactive gap discovery:**
When working on any phase, if you encounter a disconnected/stubbed class/service/view, **immediately** add it to Phase U3 — do not wait to be asked.

---

## ⚠️ MANDATORY: TASK COMPLETENESS GUARANTEE PROTOCOL

**Research finding (2025): only ~10% of complex multi-file AI agent workflows complete end-to-end with no errors. The fix is structural.**

Based on: RTM (Requirements Traceability Matrix) methodology, Meta's SCARF dead-code framework, AI agent evaluation research (Anthropic/Amazon/Patronus), Definition of Done best practices.

### GATE 1 — Pre-Task: Requirement Mapping (before first edit)
Write this out explicitly before any work starts:
```
Task: [title]
Requirements:
  REQ-001: [verbatim from prompt, including parentheticals]
  REQ-002: ...
Artifacts: [files to create/modify]
Scope IN: [what will be done]
Scope OUT: [what will NOT be done, and why]
```
**Do not begin work until this list exists.**

### GATE 2 — During Task: Execution Trace
- Log key decisions: "Why X over Y?"
- Mark each requirement as addressed: `[REQ-001 ✓]`
- Validate tool outputs — never assume a command succeeded without checking its result

### GATE 3 — Post-Task: Bidirectional RTM Verification
- **Forward**: For each REQ-xxx, grep codebase to confirm implementation exists
- **Backward**: For each file changed, confirm it traces back to a REQ-xxx
- **Unmapped change = missed requirement** — fix before declaring done
- **Inverse keyword search**: Search for requirement keywords you DIDN'T implement to catch gaps

### GATE 4 — Git Certification
- `git diff HEAD --stat` matches planned artifacts (no unexplained files)
- `git status` clean — all changes committed
- Commit message includes key decisions + requirement IDs addressed

### Definition of Done Checklist (Non-Negotiable)
Before marking ANY task complete:
- [ ] All REQ-xxx traced and implemented (Gates 1–3)
- [ ] Build passes — actual xcodebuild returned BUILD SUCCEEDED (never assumed)
- [ ] No unaddressed TODO/FIXME added to changed files
- [ ] Security-critical code verified not reverted by hooks
- [ ] Cross-file consistency — universal rules verified in ALL relevant files simultaneously

**The test**: Can Alexis reconstruct exactly what was done and why from `git log --stat`? If not, it's not done.

---

## UNIVERSAL IMPLEMENTATION STANDARD — Non-Negotiable

**This standard applies to ALL work: past, present, and future. Every feature, capability, phase, and deliverable must meet this bar.**

### What "Done" Means

"Done" means a **real user can USE the feature** — not compile it, not test its types, USE it. Every deliverable must have:

1. **Working UI** wired into app navigation (MacSettingsView sidebar, iOS tabs, toolbar items, etc.)
2. **Real data models** persisted via SwiftData, UserDefaults, or CloudKit — not in-memory throwaway
3. **Actual business logic** that processes, transforms, and presents data — not pass-throughs
4. **Error handling** with user-facing alerts/feedback — not silent failures
5. **Tests** covering actual behavior and logic — not just type conformance or Codable roundtrips

### What Is FORBIDDEN as a Deliverable

The following are NEVER acceptable as "completed" work:

- Protocol/interface definitions without concrete implementations
- Manager/Service classes with empty, stub, or TODO method bodies
- Views displaying placeholder text, "Coming soon", or static mock data
- "Infrastructure" or "foundation" commits without corresponding working features
- Types, enums, or models that nothing in the app actually uses at runtime
- Code that compiles and passes tests but does nothing when the user taps/clicks
- Boilerplate scaffolding intended for "future sessions" to fill in
- Shims, adapters, or compatibility layers that just forward calls without adding value
- Feature flags guarding empty code paths
- Draft APIs or unstable interfaces without implementations behind them

### If External API Keys or Entitlements Are Unavailable

- Implement EVERYTHING up to the API boundary with real code
- Use a clear protocol abstraction at the boundary (1 protocol, 1 live impl, 1 demo impl)
- The demo implementation must exercise the FULL pipeline with realistic synthetic data
- The user must only need to swap 1 line of config or provide 1 API key to go live
- Document what the owner needs to provide in a comment at the top of the file

### Conversation History — No Compaction

Thea must NEVER compact, summarize, or truncate conversation history. Users must be able to scroll through the ENTIRE history of ALL conversations, from the very first message to the latest. This differs from Claude Code in Terminal which compacts. Thea stores full history in SwiftData — no automatic cleanup, no summarization, no "load more" pagination that drops old messages.

### Sensitive Data Handling

When asked to remove secrets from session/log files, **surgically redact** the secret values (replace with `[REDACTED]`) while preserving all surrounding content. NEVER delete entire files unless explicitly asked to do so.

## AI Behavior Guidelines

**IMPORTANT: For every task or instruction:**
1. **Research First** - Before implementing, perform qualitative web research for:
   - Current year's best practices for the relevant technology/framework
   - Common pitfalls and recommended solutions
   - Performance optimizations and security considerations
2. **Suggest Improvements** - Proactively offer pertinent recommendations based on research
3. **Verify Approach** - Cross-reference with official documentation when available

## Quick Reference

| Command | Description |
|---------|-------------|
| `xcodegen generate` | Regenerate Xcode project from project.yml |
| `swift test` | Run all 47 tests (~1 second) |
| `swift build` | Build Swift packages |
| `swiftlint lint` | Check code style |

## Build Commands

```bash
# macOS
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -destination "platform=macOS" build

# iOS
xcodebuild -project Thea.xcodeproj -scheme Thea-iOS -destination "generic/platform=iOS" build

# All platforms (Debug)
for scheme in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" -configuration Debug build
done
```

## Project Facts

- **Swift 6.0** with strict concurrency (actors, async/await)
- **XcodeGen** generates project from `project.yml`
- **Schemes**: Thea-macOS, Thea-iOS, Thea-watchOS, Thea-tvOS
- **Local models**: `~/.cache/huggingface/hub/`
- **Architecture**: MVVM with SwiftUI + SwiftData
- **Remote**: `https://github.com/Atchoum23/Thea.git`

## Orchestrator System (ACTIVE in macOS build)

- **TaskClassifier** (`Intelligence/Classification/`): Classifies queries by type
- **TaskType** (`Intelligence/Classification/`): Task type enum used across codebase
- **ModelRouter** (`Intelligence/Routing/`): Routes to optimal model based on task
- **SmartModelRouter** (`Intelligence/Routing/`): Advanced routing with cost optimization
- **SemanticSearchService** (`Intelligence/Search/`): Embedding-based semantic search (macOS only)
- **ChatManager.selectProviderAndModel()**: Wired with `#if os(macOS)` to use TaskClassifier + ModelRouter; falls back to default provider on iOS/watchOS/tvOS

## Verification Pipeline (ACTIVE + WIRED in macOS + iOS builds)

- **ConfidenceSystem** (`Intelligence/Verification/`): Orchestrates all 5 sub-verifiers for response confidence scoring. **WIRED** into ChatManager — runs async after every AI response, stores confidence score in `MessageMetadata.confidence`
- **MultiModelConsensus** (`Intelligence/Verification/`): Cross-validates responses across multiple AI models
- **WebSearchVerifier** (`Intelligence/Verification/`): Fact-checks responses against web sources via Perplexity/OpenRouter
- **StaticAnalysisVerifier** (`Intelligence/Verification/`): Code analysis via patterns, SwiftLint, compiler checks, and AI
- **CodeExecutionVerifier** (`Intelligence/Verification/`): Executes code snippets via JavaScriptCore/Process for verification
- **UserFeedbackLearner** (`Intelligence/Verification/`): Learns from user feedback to improve confidence calibration

## CloudKit (ACTIVE)

- **CloudKitService** (`Shared/Sync/CloudKitService.swift`): Canonical CloudKit implementation (delta sync, subscriptions, sharing)
- **SyncSettingsView** (`Shared/UI/Views/Settings/SyncSettingsView.swift`): Comprehensive sync UI (macOS "Sync" tab)
- **CloudSyncManager was REMOVED** — it was dead code, never called

## AI Capabilities (Feb 2026 Upgrade)

### Local Models (ACTIVE in macOS build)
- **GPT-OSS 20B/120B** (`Core/Models/AIModel.swift`): OpenAI's Apache 2.0 open-weight models in model catalog
- **Qwen3-VL 8B** (`AI/LocalModels/MLXVisionEngine.swift`): Local vision-language model via MLXVLM (macOS only)
- **Gemma 3 1B/4B** (`AI/CoreML/CoreMLInferenceEngine.swift`): CoreML on-device inference for iOS
- **FunctionGemma** (`AI/CoreML/FunctionGemmaEngine.swift`, `FunctionGemmaBridge.swift`): NL → function calls for offline agentic actions (macOS only)

### MLX Audio (ACTIVE in macOS build)
- **MLXAudioEngine** (`AI/Audio/MLXAudioEngine.swift`): TTS via Soprano-80M, STT via GLM-ASR-Nano
- **MLXVoiceBackend** (`Voice/MLXVoiceBackend.swift`): Wraps MLXAudioEngine for voice pipeline
- **VoiceBackendProtocol** (`Voice/VoiceBackendProtocol.swift`): Shared protocol for voice backends

### Claude API Advanced (ACTIVE all platforms)
- **AnthropicToolCatalog** (`AI/Providers/AnthropicToolCatalog.swift`): 50+ tool definitions for tool_search
- **AnthropicProvider** enhanced: tool_search, compaction, 1M context, interleaved thinking + tool use

### Thea Native Messaging Gateway (ACTIVE all platforms) — Phase O complete 2026-02-19
Thea replaced OpenClaw entirely. No external daemon. Thea owns port 18789 natively.
- **TheaMessagingGateway** (`Integrations/OpenClaw/TheaMessagingGateway.swift`): @MainActor orchestrator. Starts/stops all connectors, routes inbound messages through security guard → bridge → ChatManager. Hosts WS server on port 18789.
- **TheaGatewayWSServer** (`Integrations/OpenClaw/TheaGatewayWSServer.swift`): NWListener/NWProtocolWebSocket server on port 18789. External clients connect here.
- **MessagingPlatformProtocol** (`Integrations/OpenClaw/MessagingPlatformProtocol.swift`): Swift actor protocol all 7 connectors implement.
- **MessagingSessionManager** (`Integrations/OpenClaw/MessagingSessionManager.swift`): SwiftData-backed per-platform-per-peer session isolation + MMR memory re-ranking. Session key: `"{platform}:{chatId}:{senderId}"`.
- **Platform connectors** (`Integrations/Messaging/`): TelegramConnector (Bot API long-poll), DiscordConnector (WS Gateway v10), SlackConnector (Socket Mode), BlueBubblesConnector (iMessage local HTTP/WS), WhatsAppConnector (Meta Cloud API v21.0), SignalConnector (signal-cli JSON-RPC), MatrixConnector (C-S API v3).
- **OpenClawClient** (`Integrations/OpenClaw/OpenClawClient.swift`): REPURPOSED — internal WS client connecting to Thea's own port 18789 server. No external dependency.
- **OpenClawIntegration** (`Integrations/OpenClaw/OpenClawIntegration.swift`): REPURPOSED — lifecycle manager that starts/stops TheaMessagingGateway. Wired into macOS + iOS app lifecycle.
- **OpenClawBridge** (`Integrations/OpenClaw/OpenClawBridge.swift`): REPURPOSED — multi-platform message router. Routes all inbound (Telegram/Discord/Slack/etc.) to correct AI agent. Keeps ALL injection mitigation. Routes Moltbook messages to MoltbookAgent.
- **OpenClawSecurityGuard** (`Integrations/OpenClaw/OpenClawSecurityGuard.swift`): UNCHANGED — 22-pattern prompt injection detection, Unicode NFD normalization, invisible character stripping. Applied to ALL inbound from ALL platforms.
- **TheaMessagingSettingsView** (`UI/Views/Settings/TheaMessagingSettingsView.swift`): Credentials UI for all 7 platforms. Wired into MacSettingsView sidebar → "Messaging Gateway".
- **TheaMessagingChatView** (`UI/Views/OpenClaw/TheaMessagingChatView.swift`): Platform selector + conversation thread. Wired into MacSettingsView sidebar.

⚠️ NEVER: delete any OpenClaw*.swift file. NEVER install the OpenClaw npm package. NEVER start the openclaw gateway daemon (it's uninstalled). Thea IS the gateway.

### Privacy System (ACTIVE all platforms)
- **OutboundPrivacyGuard** (`Privacy/OutboundPrivacyGuard.swift`): System-wide outbound data sanitization
- **PrivacyPolicy** (`Privacy/PrivacyPolicy.swift`): Policy protocol + strictness levels
- **PrivacyPolicies** (`Privacy/PrivacyPolicies.swift`): 6 built-in policies (CloudAPI, Messaging, MCP, WebAPI, Moltbook, Permissive)
- **PIISanitizer** (`Privacy/PIISanitizer.swift`): PII detection and masking (pre-existing)
- **PrivacyPreservingAIRouter** (`Intelligence/Privacy/`): Sensitivity-based routing (pre-existing)

### Moltbook Agent (ACTIVE + WIRED all platforms)
- **MoltbookAgent** (`Agents/MoltbookAgent.swift`): Privacy-preserving dev discussion agent with kill switch + preview mode. **WIRED** into TheamacOSApp lifecycle (deferred 2s init, guarded by `SettingsManager.moltbookAgentEnabled`), OpenClawBridge (now TheaMessagingGateway's multi-platform router) routes Moltbook messages to it
- **MoltbookSettingsView** (`UI/Views/Settings/MoltbookSettingsView.swift`): Settings UI (enable/disable, preview mode, daily post limit) in MacSettingsView sidebar

### AgentMode + Autonomy (ACTIVE + WIRED all platforms)
- **AgentMode** (`Intelligence/AgentMode/`): Task execution modes (planning/fast/auto) with phase tracking (gatherContext → takeAction → verifyResults → done). **WIRED** into ChatManager — mode selected after task classification, phase transitions tracked
- **AutonomyController** (`Intelligence/Autonomy/`): 5-level risk-based autonomy with action approval/rejection. **WIRED** into ChatManager — evaluates actionable task types post-response, queues for approval when needed
- **AgentExecutionState**: Published on ChatManager as `agentState` for UI observation

### Multilingual Conversations (ACTIVE all platforms)
- **ConversationLanguageService** (`Localization/ConversationLanguageService.swift`): Per-conversation language management (27 languages, BCP-47)
- **ConversationLanguagePickerView** (`UI/Views/Components/ConversationLanguagePickerView.swift`): Toolbar globe menu. **WIRED** into ChatView toolbar
- **ChatManager**: Injects language instruction into system prompt (validated against injection)

### Intelligence Integration Layers (ACTIVE all platforms)
- **PersonalKnowledgeGraph** (`Memory/PersonalKnowledgeGraph.swift`): Entity-relationship graph with BFS pathfinding, JSON persistence
- **TaskPlanDAG** (`Intelligence/Planning/TaskPlanDAG.swift`): DAG-based task decomposition with parallel execution via TaskGroup
- **BehavioralFingerprint** (`Intelligence/UserModel/BehavioralFingerprint.swift`): 7x24 temporal behavioral model for user patterns
- **SmartNotificationScheduler** (`Intelligence/Scheduling/SmartNotificationScheduler.swift`): Optimal notification timing via BehavioralFingerprint
- **HealthCoachingPipeline** (`Intelligence/Health/HealthCoachingPipeline.swift`): HealthKit data analysis to coaching insights

## Excluded From Builds — DO NOT IMPLEMENT

**CRITICAL RULE: Unless the user EXPLICITLY instructs you to work in an excluded folder/file, you MUST NOT create, modify, or implement code in any path listed below. These files are excluded from ALL build targets in `project.yml` and are dead code. Working in them is wasted effort.**

If a task seems to require changes in an excluded area, **STOP and ask the user** whether they want you to:
1. Implement in the canonical (included) location instead, or
2. Explicitly opt into working in the excluded area.

**When in doubt**, grep `project.yml` for the file/folder name before implementing.

### Excluded Areas (by category)

| Category | Excluded Pattern(s) | Use Instead |
|---|---|---|
| **MetaAI** (blanket, ~73 files) | `**/AI/MetaAI/**`, `**/Views/MetaAI/**`, `**/MetaAI/ModelBenchmarkService.swift` | `Shared/Intelligence/` |
| **Duplicate Providers** | `**/Providers/{Anthropic,DeepSeek,Google,Groq,OpenAI,OpenRouter,Perplexity,Helpers,Protocol,Registry}/**` | `Shared/AI/Providers/` (AnthropicFilesAPI + AnthropicTokenCounter now ACTIVE) |
| **Duplicate Terminal** | `**/Execution/Terminal/**` | `Shared/System/Terminal/` |
| **Duplicate Memory** | `**/AI/Memory/**` | `Shared/Memory/` |
| **AI Subsystems** | `**/AI/Context/**`, `**/AI/Adaptive/**`, `**/AI/MultiModal/**`, `**/AI/Proactive/**` | None active |
| **Automation / SelfEvolution** | `**/Automation/**`, `**/SelfEvolution/**` | Autonomy + AgentMode now ACTIVE (see above) |
| **Learning / Monitoring** | `**/PatternLearning/**`, `**/LifeMonitoring/**`, `**/LifeAssistant/**` | None active |
| **LocalModels** | Selective: `ProactiveModelManager`, `LocalModelRecommendation*`, `AIModelGovernor`, `ModelGovernanceEngine`, `UnifiedLocalModelOrchestrator`, `SupraModelSelector`, `OllamaAgentLoop`, `ModelQualityBenchmark`, `PredictivePreloader` | Core LocalModel files now active |
| **Integrations** | `**/Integrations/{Mail,Finder,Safari,Xcode,Shortcuts,Terminal,Music,Calendar,Messages,Notes,Reminders,MCP,System,IntegrationModule}*` | None active |
| **Verification** | _(now ACTIVE — all 6 files enabled in macOS + iOS builds)_ | `Intelligence/Verification/` |
| **Anticipatory** | `**/Anticipatory/**`, `**/Prediction/**` | None active |
| **PromptEngineering** | `**/PromptEngineering/**` | None active |
| **ResourceManagement** | `**/ResourceManagement/**` | None active |
| **Squads** | `**/Squads/**` | None active |
| **Settings Views** | `**/Settings/Orchestrator/**`, `**/Settings/LocalModels/**`, `**/Settings/Privacy/**`, `**/Settings/Advanced/**`, `**/Settings/AutonomousTasks/**`, plus ~15 individual Settings files | `PermissionsSettingsView` now ACTIVE (used by MacSettingsView) |
| **Views** | `**/Views/Code/**`, `**/Views/LocalModels/**`, `**/Views/LifeTracking/**`, plus individual view files | None active |
| **Components** | `EnhancedMessageBubble`, `ExecutableCodeBlock`, `THEAThinkingView`, `StreamingTextView`, `ConfidenceIndicatorViews`, `TheaTextInputField`, `MemoryContextView`, `QuerySuggestionOverlay` | None active |
| **Design (platform)** | `**/Theme/DesignTokens.swift` (macOS), `**/Design/DesignSystemStubs.swift`, `**/Theme/TheaAnimations.swift` | `TheaDesignSystem.swift` (macOS canonical) |
| **Widgets** | `**/Widgets/**` (macOS only) | WidgetKit not available on macOS main app |

### MetaAI Details

The MetaAI folder was excluded because it had duplicate type definitions conflicting with `Shared/Intelligence/`. Types already renamed with `MetaAI` prefix: `MetaAIMCPServerInfo`, `AIErrorContext`, `ModelCapabilityRecord`, `ReActActionResult`, `HypothesisEvidence`. **DO NOT remove the MetaAI blanket exclusion without resolving all type conflicts.**

## MLX Integration

- Use `mlx-swift` and `mlx-swift-lm` for on-device inference
- Use `ChatSession` for multi-turn conversations (has KV cache)
- IMPORTANT: Never use raw prompts - always apply chat templates via ChatSession

## Gotchas

- IMPORTANT: Run `xcodegen generate` after ANY change to `project.yml`
- IMPORTANT: All 4 platform schemes must build with 0 errors, 0 warnings
- Swift Package tests are 60x faster than Xcode tests - prefer `swift test`
- App groups must use `group.app.theathe` consistently across all targets

## QA After Major Changes

Execute: `Read .claude/COMPREHENSIVE_QA_PLAN.md and run all phases`

See @.claude/COMPREHENSIVE_QA_PLAN.md for the full checklist.

## After Every Session

**IMPORTANT: Always commit and sync before ending:**
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git add -A && git status
# If changes exist, commit with descriptive message
git pushsync origin main  # Only if user requests — triggers sync build on the other Mac
```

## Multi-Mac Auto-Sync

Thea uses `git pushsync` (a global git alias) to keep both Macs in sync:

- **`git pushsync origin main`** = `git push` + SSH trigger to rebuild on the other Mac
- Tries **Tailscale hostname** first (internet), then **`.local`** (LAN), falls back to **5-min polling**
- A **launchd agent** (`com.alexis.thea-sync`) polls every 5 minutes as a fallback
- The sync script (`~/bin/thea-sync.sh`) pulls, runs xcodegen, builds Release, and installs to `/Applications`
- A **Claude Code hook** (`.claude/hooks/enforce-pushsync.sh`) blocks plain `git push` and reminds you to use `git pushsync`
- **For internet sync**: Install Tailscale on both Macs (`brew install tailscale && tailscale up --ssh`)
