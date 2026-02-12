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

### 🚫 FORBIDDEN Commands

**NEVER execute these commands under ANY circumstances:**

- `rm -rf` with wildcards (`*`) in ANY path
- `rm -rf ~/` or `rm -rf /`
- `rm -rf` on parent directories of the project
- `git clean -fdx` without explicit user confirmation
- `git reset --hard` without explicit user confirmation
- Any command that could delete the project directory

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

## Verification Pipeline (ACTIVE in macOS + iOS builds)

- **ConfidenceSystem** (`Intelligence/Verification/`): Orchestrates all 5 sub-verifiers for response confidence scoring
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

### OpenClaw Integration (ACTIVE all platforms)
- **OpenClawClient** (`Integrations/OpenClaw/OpenClawClient.swift`): WebSocket client to Gateway at `ws://127.0.0.1:18789`
- **OpenClawIntegration** (`Integrations/OpenClaw/OpenClawIntegration.swift`): Lifecycle management
- **OpenClawBridge** (`Integrations/OpenClaw/OpenClawBridge.swift`): AI message routing
- **OpenClawSecurityGuard** (`Integrations/OpenClaw/OpenClawSecurityGuard.swift`): Prompt injection detection

### Privacy System (ACTIVE all platforms)
- **OutboundPrivacyGuard** (`Privacy/OutboundPrivacyGuard.swift`): System-wide outbound data sanitization
- **PrivacyPolicy** (`Privacy/PrivacyPolicy.swift`): Policy protocol + strictness levels
- **PrivacyPolicies** (`Privacy/PrivacyPolicies.swift`): 6 built-in policies (CloudAPI, Messaging, MCP, WebAPI, Moltbook, Permissive)
- **PIISanitizer** (`Privacy/PIISanitizer.swift`): PII detection and masking (pre-existing)
- **PrivacyPreservingAIRouter** (`Intelligence/Privacy/`): Sensitivity-based routing (pre-existing)

### Moltbook Agent (ACTIVE all platforms)
- **MoltbookAgent** (`Agents/MoltbookAgent.swift`): Privacy-preserving dev discussion agent with kill switch + preview mode

### Intelligence Integration Layers (ACTIVE all platforms)
- **PersonalKnowledgeGraph** (`Memory/PersonalKnowledgeGraph.swift`): Entity-relationship graph with BFS pathfinding, JSON persistence
- **TaskPlanDAG** (`Intelligence/Planning/TaskPlanDAG.swift`): DAG-based task decomposition with parallel execution via TaskGroup
- **BehavioralFingerprint** (`Intelligence/UserModel/BehavioralFingerprint.swift`): 7x24 temporal behavioral model for user patterns
- **SmartNotificationScheduler** (`Intelligence/Scheduling/SmartNotificationScheduler.swift`): Optimal notification timing via BehavioralFingerprint
- **HealthCoachingPipeline** (`Intelligence/Health/HealthCoachingPipeline.swift`): HealthKit → rule-based analysis → coaching insights

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
| **Autonomy / Automation** | `**/Autonomy/**`, `**/Automation/**`, `**/Autonomous/**`, `**/AgentMode/**`, `**/SelfEvolution/**` | None active |
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
