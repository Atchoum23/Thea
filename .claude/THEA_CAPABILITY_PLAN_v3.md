# THEA CAPABILITY MAXIMIZATION PLAN v3.1
# ══════════════════════════════════════════════════════════════════════════════
# ⚠️  ABSOLUTE NON-NEGOTIABLE RULE — NEVER REMOVE ANYTHING. ONLY ADD AND FIX.
# ══════════════════════════════════════════════════════════════════════════════
#
# Created: 2026-02-19 | Updated: 2026-02-19 13:47 CET → v3.1
# v2→v3 auto-transition: executor starts A3 after v2 Phase U; v2 Phase V merged into AD3
# Owner: Autonomous agent system (MSM3U primary + MBAM2 secondary)
# Scope: All platforms — macOS, iOS, watchOS, tvOS, Tizen, TheaWeb
#
# STRATEGIC CONTEXT — WHY v3 IS NEEDED
# ══════════════════════════════════════
# v2 delivered a verified, tested, secure baseline. The comprehensive audit
# conducted on 2026-02-19 revealed that Thea is "backend-complete, UI-incomplete":
#   - ~45 major intelligence systems active
#   - ~30% have corresponding user-facing UI
#   - 50+ tool definitions in AnthropicToolCatalog — NONE execute
#   - ~73 MetaAI files archived due to type conflicts
#   - SemanticSearchService built but disconnected from pipeline
#   - ConfidenceSystem scores computed but never fed back to routing
#   - Computer Use: not attempted
#   - 14+ major active systems are completely invisible to the user
#   - SkillRegistry: loaded but not passed to sub-agents
#   - Squads: defined but never integrated
#   - MLXAudioEngine: temporarily excluded (Release build issue)
#
# v3 GOAL: Close every gap. Wire everything. Activate everything.
# Transform Thea from 30% to 100% realized capability.
#
# v3 ADDITIONS OVER v2:
#   1. Meta-AI Full Activation — cherry-pick ~45 unique files (skip 15 superseded), MetaAIDashboard UI, MetaAICoordinator, multi-agent/reasoning/autonomy/workflow/plugin suites all activated
#   2. AnthropicToolCatalog Execution — wire 50+ tools to actually execute
#   3. SemanticSearchService RAG — integrate into every request
#   4. ConfidenceSystem Feedback Loop — self-improving model selection
#   5. Skills Complete System — auto-discovery, sub-agent inheritance, marketplace UI
#   6. Squads ↔ AgentTeamOrchestrator Unification
#   7. Missing AI System UIs — dashboard for all 14+ silent systems
#   8. Excluded UI Components — StreamingTextView, MemoryContextView, ConfidenceIndicator
#   9. Life Tracking Visualization — heatmaps, patterns, recommendations
#   10. Computer Use — Claude API computer_use integration
#   11. MLX Audio Re-enable — fix Release build issue
#   12. Artifact System — structured artifact store + browser UI
#   13. MCP Client — connect to external MCP servers
#   14. PersonalKnowledgeGraph Enhancement — pruning, dedup, consolidation
#   15. Proactive Intelligence — insight history, feedback loop, weekly summaries
#   16. Config UI Completion — sliders, thresholds, weight distribution for all 200+ settings
#   17. TaskPlanDAG Enhancement — caching, quality feedback, user approval gate
#   18. SelfEvolution Wiring — practical within-sandbox implementation
#   19. MCPServerGenerator UI — build and test MCP servers from Thea
#   20. Full v2-equivalent verification (X3–AD3)
#   21. Integration Backend Re-enablement — Safari/Calendar/Shortcuts/Reminders/Notes/Finder/Mail
#   22. AI Subsystem Re-evaluation — Context/Adaptive/Proactive/PatternLearning/Prediction/PromptEng
#   23. Transparency & Analytics UIs — BehavioralFingerprint viz, Privacy, Messaging, Notifications
#   24. Chat Enhancement Features — FilesAPI UI, TokenCounter, MultiModelConsensus, AgentMode viz
# ══════════════════════════════════════════════════════════════════════════════

---

## STRATEGIC DECISION: COMPLETE v2 FIRST, THEN RUN v3

**DO NOT halt v2 to run v3. Let v2 complete fully, then start v3.**

Rationale:
1. Phase Q's test fixes are permanent value — v3 benefits from a clean test base
2. Adding 73+ MetaAI files + new features BEFORE Phase Q makes Q much harder
3. v3's Wave 6 verification re-runs ALL checks on ALL code (v2 + v3 together)
4. v3 does NOT re-run v2's implementation phases (N/O/P were cumulative improvements)
5. v2 delivers a notarized, CI-green baseline — safer to add v3 features on top

**v3 starts AUTOMATICALLY after v2 Phase U (Final Verification Report) completes.

The executor reads this plan after Phase U and starts Phase A3 without human intervention.
v2 Phase V (Manual Gate) is DEFERRED and MERGED into v3 Phase AD3 (combined final gate).**

---

## HOW TO CHECK PROGRESS (READ THIS FIRST, ALEXIS)

### From MSM3U:
```
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git pull
# Then start Claude Code and say:
"Read .claude/THEA_CAPABILITY_PLAN_v3.md and tell me the current status of all phases,
which are complete, which are in progress, and what is blocking full capability."
```

### To Execute Next Phase:
```
"Continue executing THEA_CAPABILITY_PLAN_v3.md — pick up from the first incomplete
phase and run all steps fully and autonomously, committing after each step."
```

### Prerequisite Check:
```
"Verify v2 is complete before starting v3: read THEA_SHIP_READY_PLAN_v2.md and
confirm Phase V (Manual Ship Gate) is ✅ DONE before proceeding with v3."
```

---

## QUICK STATUS SNAPSHOT (update this after each phase)

| Category                  | Status          | Notes |
|---------------------------|-----------------|-------|
| **v2→v3 AUTO-TRANSITION** | ⚠️ AUTO-LINK   | v2 Phase U ✅ → executor auto-starts A3. v2 Phase V DEFERRED to AD3. |
| Phase A3: Meta-AI         | ⏳ PENDING      | Blocked by v2→v3 auto-transition |
| Phase B3: Tool Execution  | ⏳ PENDING      | Blocked by v2→v3 auto-transition |
| Phase C3: RAG / Semantic  | ⏳ PENDING      | Blocked by v2→v3 auto-transition |
| Phase D3: Confidence Loop | ⏳ PENDING      | Blocked by v2→v3 auto-transition |
| Phase E3: Skills Complete | ⏳ PENDING      | Blocked by A3 |
| Phase F3: Squads Unified  | ⏳ PENDING      | Blocked by A3 |
| Phase G3: TaskPlanDAG+    | ⏳ PENDING      | Blocked by D3 |
| Phase H3: AI System UIs   | ⏳ PENDING      | Blocked by A3 |
| Phase I3: UI Components   | ⏳ PENDING      | Blocked by H3 |
| Phase J3: LifeTracking UI | ⏳ PENDING      | Blocked by I3 |
| Phase K3: Config UI       | ⏳ PENDING      | Blocked by H3 |
| Phase L3: Computer Use    | ⏳ PENDING      | Blocked by B3 |
| Phase M3: MLX Audio       | ⏳ PENDING      | Blocked by v2 |
| Phase N3: Artifact System | ⏳ PENDING      | Blocked by E3 |
| Phase O3: MCP Client      | ⏳ PENDING      | Blocked by B3 |
| Phase P3: KG Enhancement  | ⏳ PENDING      | Blocked by v2 |
| Phase Q3: Proactive Intel | ⏳ PENDING      | Blocked by P3 |
| Phase R3: SelfEvolution   | ⏳ PENDING      | Blocked by H3 |
| Phase S3: MCPGen UI       | ⏳ PENDING      | Blocked by O3 |
| Phase T3: Integration Bknd| ⏳ PENDING      | Blocked by B3; Safari/Cal/Shortcuts/Reminders/Notes/Finder/Mail |
| Phase U3: AI Subsystems   | ⏳ PENDING      | Blocked by A3; Context/Adaptive/Proactive/PatternLearning/Predict |
| Phase V3: Transparency UIs| ⏳ PENDING      | Blocked by H3; BehavioralFingerprint viz, Privacy, Messaging |
| Phase W3: Chat Enhance    | ⏳ PENDING      | Blocked by I3; FilesAPI UI, Tokens, MultiModel UI, AgentMode |
| Phase X3: Test Coverage   | ⏳ PENDING      | Blocked by A3–W3 |
| Phase Y3: Periphery Clean | ⏳ PENDING      | Blocked by X3 |
| Phase Z3: CI Green        | ⏳ PENDING      | Blocked by Y3 |
| Phase AA3: Re-verify       | ⏳ PENDING      | Blocked by Z3 |
| Phase AB3: Notarization    | ⏳ PENDING      | Blocked by AA3 |
| Phase AC3: Final Report    | ⏳ PENDING      | Blocked by AB3 |
| Phase AD3: Manual Gate     | ⏳ MANUAL       | Alexis only — last step |
| **Overall v3 %**          | **0%**          | v2 Phase U in progress (W running) — v3 starts after U |

*Last updated: 2026-02-19 13:47 CET v3.1 — added 4 new feature phases (T3-W3), renamed verification to X3-AD3, v2→v3 auto-transition after Phase U, Phase V merged into AD3, resilience mechanisms added.*

---

## END GOAL — v3 SHIP-READY CRITERIA

**Thea v3 is complete when ALL v2 criteria AND ALL of the following are true:**

### Meta-AI (Intelligence Layer UI)
- [ ] "Meta-AI" brand visible in MacSettingsView sidebar and iOS tab
- [ ] MetaAIDashboardView shows real-time decisions from all intelligence subsystems
- [ ] 6 cherry-picked unique MetaAI files active (ModelBenchmarkService, QueryDecomposer, LogicalInference, THEASelfAwareness, ToolCallView, WorkflowTemplates)
- [ ] Zero type conflicts — cherry-picked files use canonical Intelligence/ types where overlap exists
- [ ] Model benchmarking UI active and accessible under "Meta-AI" section

### Tool Execution
- [ ] All AnthropicToolCatalog tools (50+) have execution handlers
- [ ] Tool use steps visible in ChatView (not silent)
- [ ] Tool errors handled and surfaced to user
- [ ] Computer Use: screenshot + click + type actions work on macOS

### Intelligence Pipeline
- [ ] SemanticSearchService called on every ChatManager.sendMessage()
- [ ] Top-3 semantic matches injected into system context
- [ ] ConfidenceSystem scores fed back to SmartModelRouter (route smarter over time)
- [ ] ConfidenceSystem scores fed back to TaskClassifier (reclassify on low confidence)
- [ ] Zero silent AI decisions — all routing, confidence, tool use visible in UI

### Skills System
- [ ] SkillRegistry passed to all AgentTeamOrchestrator sub-agents
- [ ] SkillsMarketplaceView in app (browse, install, manage skills)
- [ ] Skill Auto-Discovery: AgentTeamOrchestrator creates new skills from repeated patterns
- [ ] Marketplace sync: real API calls to Smithery/Context7 (or demo mode)
- [ ] Per-workspace skills: drop a SKILL.md into .thea/skills/ → Thea picks it up

### Squads
- [ ] SquadOrchestrator wired into ChatManager (reachable from conversation UI)
- [ ] Squad creation/management UI in app
- [ ] Squads and AgentTeams: clear separation (Squads = persistent, Teams = ephemeral)
- [ ] Long-running squad goals tracked across sessions

### User Interface Completeness
- [ ] AI System Dashboard: shows real-time decisions from every major system
- [ ] BehavioralFingerprint visualized (heatmap, wake/sleep, activity patterns)
- [ ] SmartModelRouter decisions shown (why was this model chosen?)
- [ ] ConfidenceIndicatorViews wired into every response bubble
- [ ] StreamingTextView used in place of instant text rendering
- [ ] MemoryContextView shown when memory is injected into context
- [ ] Life Tracking: full dashboard with heatmap, correlations, recommendations
- [ ] LocalModels: governance, benchmarking, load balancing UI
- [ ] Config UI: sliders for all continuous values, no configuration hidden

### Artifacts
- [ ] Structured artifact store (generated code, plans, exports persist across sessions)
- [ ] Artifact browser UI: search, view, re-use past artifacts
- [ ] MCPServerGenerator accessible from UI (point-and-click MCP server creation)

### Audio
- [ ] MLXAudioEngine and MLXVoiceBackend back in all platform builds
- [ ] TTS (Soprano-80M) working in Release mode
- [ ] STT (GLM-ASR-Nano) working in Release mode

### MCP Client
- [ ] GenericMCPClient: connect to any MCP-compatible server
- [ ] MCP server browser: discover, connect, test external MCP servers
- [ ] MCP tool execution integrated with AnthropicToolCatalog

### Integration Backends (T3)
- [ ] SafariIntegration, CalendarIntegration, ShortcutsIntegration, RemindersIntegration re-enabled
- [ ] NotesIntegration, FinderIntegration, MailIntegration re-enabled  
- [ ] All integration backends wired as handlers in AnthropicToolCatalog (B3 tool execution)
- [ ] macOS-only guard (#if os(macOS)) on all integration files

### AI Subsystem Activation (U3)
- [ ] AI/Context/, AI/Adaptive/, AI/Proactive/ audited; unique capabilities re-enabled
- [ ] PatternLearning/, Prediction/ audited; unique capabilities re-enabled
- [ ] PromptEngineering/ active — prompt quality improvement active on all requests
- [ ] ResourceManagement/ / Anticipatory/ audited; valuable systems re-enabled
- [ ] Zero new type conflicts from re-enabled subsystems

### Transparency & Analytics UIs (V3)
- [ ] BehavioralAnalyticsView: 7×24 activity heatmap, sleep/wake patterns, app usage
- [ ] PrivacyTransparencyView: blocked outbound items log, masked PII log
- [ ] MessagingGatewayStatusView: 7 connector health + message throughput dashboard
- [ ] NotificationIntelligenceView: deferral history, delivery stats
- [ ] All wired into MacSettingsView sidebar + iOS views

### Chat Enhancement Features (W3)
- [ ] AnthropicFilesAPI UI: file attachment picker in ChatView, upload/reference files
- [ ] Token counter display: tokens in/out per message in MessageBubble footer
- [ ] MultiModelConsensus breakdown: which models agreed/disagreed in ConfidenceSystem detail
- [ ] AgentMode phase progress bar: gatherContext → takeAction → verifyResults → done
- [ ] Enhanced AutonomyController approval UI: risk level, action details, allow/deny/modify
- [ ] CloudKit sync indicator in toolbar (syncing / synced / error)
- [ ] MoltbookAgent activity log: message count, topics, last active

### Self-Improvement
- [ ] PersonalKnowledgeGraph: background consolidation, pruning, dedup running
- [ ] Proactive insights: history stored, feedback collected, weekly summaries delivered
- [ ] SelfEvolution: practical implementation (request → Thea drafts code changes as artifacts)
- [ ] TaskPlanDAG: plan caching, quality scoring, learning from outcomes

---

## PHASE EXECUTION ORDER (optimized for parallelism + dependencies)

```
Wave 0 — v2→v3 AUTO-TRANSITION (no human gate):
  After v2 Phase U completes → executor auto-reads v3 plan and starts Phase A3
  v2 Phase V DEFERRED → merged into v3 Phase AD3 (combined final gate at very end)

Wave 1 — FOUNDATION (sequential — A3 unblocks many others):
  A3 — Meta-AI Intelligence Layer      [MSM3U, ~3–4h — UI layer, cherry-pick unique files, brand preserved]
  B3 — Tool Execution Wiring           [MSM3U, ~3–4h — ChatManager tool_use handler]
  C3 — SemanticSearchService RAG       [MSM3U, ~2h — inject semantic context into pipeline]
  D3 — ConfidenceSystem Feedback Loop  [MSM3U, ~2h — scores → routing feedback]

Wave 2 — AGENTS & SKILLS (after A3):
  E3 — Skills Complete System          [MSM3U, ~4h — auto-discovery, sub-agents, UI]
  F3 — Squads Unified                  [MSM3U, ~3h — wire SquadOrchestrator, add UI]
  G3 — TaskPlanDAG Enhancement         [MSM3U, ~2h — caching, quality, approval gate]

Wave 3 — UI WAVE (after A3+B3; H3+J3 on MSM3U, I3+K3 on MBAM2 in parallel):
  H3 — AI System UIs Dashboard         [MSM3U, ~4h — master transparency dashboard]
  I3 — Excluded UI Components          [MBAM2, ~2h — StreamingTextView, MemoryContext, etc. — pure SwiftUI]
  J3 — Life Tracking Visualization     [MSM3U, ~3h — heatmap, patterns, recommendations]
  K3 — Config UI Completion            [MBAM2, ~3h — sliders, weights, thresholds — pure SwiftUI]

Wave 4 — ADVANCED CAPABILITIES (after Wave 2+3):
  L3 — Computer Use                    [MSM3U, ~4h — computer_use API integration]
  M3 — MLX Audio Re-enable             [MSM3U, ~3h — fix Release build issue — requires local MLX]
  N3 — Artifact System                 [MSM3U, ~3h — store, browser, persistence]
  O3 — MCP Client                      [MSM3U, ~4h — GenericMCPClient + browser UI]

Wave 5 — REMAINING FEATURES (after Waves 3+4; T3/V3/W3 can run on MBAM2 in parallel):
  P3 — KG Enhancement                  [MSM3U, ~2h — pruning, dedup, consolidation]
  Q3 — Proactive Intelligence          [MSM3U, ~2h — insight history, feedback, summaries]
  R3 — SelfEvolution Wiring           [MSM3U, ~2h — artifact-based code change requests]
  S3 — MCPServerGenerator UI           [MSM3U, ~2h — point-and-click MCP server creation]
  T3 — Integration Backends           [MBAM2, ~3h — Safari/Calendar/Shortcuts/Reminders/Notes/Finder/Mail — pure Swift]
  U3 — AI Subsystem Re-evaluation     [MSM3U, ~4h — Context/Adaptive/Proactive/PatternLearning/etc. — heavy audit]
  V3 — Transparency & Analytics UIs   [MBAM2, ~3h — BehavioralFingerprint heatmap, Privacy, Messaging — pure SwiftUI]
  W3 — Chat Enhancement Features      [MBAM2, ~3h — FilesAPI UI, TokenCounter, MultiModelConsensus UI — pure SwiftUI]

Wave 6 — VERIFICATION (after ALL feature phases complete — sequential):
  X3 — Test Coverage ≥80%             [MSM3U, ~4–8h — ALL code A3–W3 included]
  Y3 — Periphery Clean                [MSM3U, ~2–4h — zero new dead code]
  Z3 — CI Green                       [MSM3U, ~2–4h — all 6 workflows pass]
  AA3 — Re-verification               [MSM3U, ~1h — v1+v2+v3 criteria all pass]
  AB3 — Notarization                  [MSM3U, ~1–2h — new release build]
  AC3 — Final Report                  [MSM3U, ~30min — comprehensive capability report]
  AD3 — COMBINED FINAL GATE           [Alexis — v2 Phase V checklist + v3 sign-off]

─────────────────────────────────────────────────
PARALLEL SESSION RULES (same as v2)
─────────────────────────────────────────────────
Wave 2 (E3/F3/G3) can run in parallel with each other on MSM3U after A3 completes.
Wave 3: MSM3U runs H3+J3; MBAM2 runs I3+K3 simultaneously (no conflict — non-overlapping files).
Wave 4 (L3/M3/N3/O3) can run as 2 parallel sessions on MSM3U (L3+M3, N3+O3).
Wave 5: MSM3U runs P3+Q3 and R3+S3+U3; MBAM2 runs T3, V3, W3 in parallel with MSM3U.
  MBAM2 phases must pushsync after each phase so MSM3U picks up changes before Wave 6.
Wave 6 is SEQUENTIAL on MSM3U — X3→Y3→Z3→AA3→AB3→AC3→AD3 (each depends on previous).
Note: AD3 is the COMBINED final gate (includes v2 Phase V items + v3 sign-off).

MACHINE ASSIGNMENTS SUMMARY:
  MSM3U (primary): A3 B3 C3 D3 E3 F3 G3 H3 J3 L3 M3 N3 O3 P3 Q3 R3 S3 U3 + all Wave 6
  MBAM2 (secondary): I3 K3 T3 V3 W3 (lightweight pure-SwiftUI, no ML dependency)
  CPU temp monitoring: mandatory on MSM3U for all Wave 4+ phases (powermetrics, pause >90°C)

CURRENT STATUS:
  v2: 🔄 IN PROGRESS — Phase W running (V1 re-verify), Wave 3+4 executor active
  v3: ⏳ PENDING — auto-starts after v2 Phase U completes
```

---

## SESSION SAFETY PROTOCOL — MANDATORY FOR ALL v3 SESSIONS

### Core Rules (same as v2)
1. Suspend thea-sync at start: `launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist`
2. Pull latest plan before executing anything: `git pull`
3. Commit every file individually — never batch with `git add -A`
4. Verify plan state before starting a phase — never assume
5. Clean exit: commit, restore thea-sync, pushsync

### Rule 6 — MANDATORY PLAN FILE UPDATE
**Every phase start AND end MUST update this plan file's status table and commit the change.**

```bash
# At phase start: mark IN PROGRESS
sed -i '' 's/| X3  | Test Coverage.*⏳ PENDING/| X3  | Test Coverage...    | 🔄 IN PROGRESS | .../' \
  .claude/THEA_CAPABILITY_PLAN_v3.md
git add .claude/THEA_CAPABILITY_PLAN_v3.md && git commit -m "Auto-save: X3 — phase started"

# At phase end: mark DONE
sed -i '' 's/| X3  | Test Coverage.*🔄 IN PROGRESS/| X3  | Test Coverage... | ✅ DONE/' \
  .claude/THEA_CAPABILITY_PLAN_v3.md
git add .claude/THEA_CAPABILITY_PLAN_v3.md && git commit -m "Auto-save: X3 — phase complete"
```

Both v3 and v2 plan files must be updated — status tables must always reflect real state.
Do NOT skip this step for any phase, even quick ones.

### Rule 7 — RESILIENCE & AUTO-RECOVERY

**Heartbeat (every 30 min):**
```bash
# In tmux session, run alongside executor:
while true; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') — v3 executor alive, phase: $(cat /tmp/v3_phase.txt 2>/dev/null || echo 'unknown')" \
    >> /tmp/v3_heartbeat.log
  sleep 1800
done &
```

**State file (updated at every phase transition):**
```bash
# /tmp/v3_state.json — written by executor at each phase boundary
echo "{\"phase\": \"A3\", \"status\": \"in_progress\", \"started\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
  > /tmp/v3_state.json
```

**Auto-recovery on build failure (try once before stopping):**
```bash
if ! xcodebuild ... | grep -q "BUILD SUCCEEDED"; then
  echo "Build failed — attempting auto-recovery: clean DerivedData"
  find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Thea-*" -type d -exec rm -rf {} + 2>/dev/null
  xcodegen generate
  # Retry once
  if ! xcodebuild ... | grep -q "BUILD SUCCEEDED"; then
    echo "FATAL: Build failed after recovery — STOPPING. Check errors before resuming."
    exit 1
  fi
fi
```

**Git index check after multi-file operations:**
```bash
# Run after any phase that touches >3 files:
git status --short | grep "^D " && echo "WARNING: deletions detected — check git index" && \
  rm -f .git/index && git read-tree HEAD
```

**Build gate before EVERY phase:**
Every phase description below must start with a build gate check. Do not proceed with any
phase's steps if the build gate fails.

### Rule 8 — PARALLEL MACHINE ASSIGNMENT

v3 phases can run on BOTH MSM3U and MBAM2 in parallel. Assign based on capability:

**MSM3U (Mac Studio M3 Ultra, 256 GB RAM) — HEAVY PHASES:**
- All 4-platform builds (macOS + iOS + watchOS + tvOS)
- ML-heavy phases: A3 (Intelligence), B3 (Tool Execution), E3 (Skills), F3 (Squads)
- Phases requiring large models: L3 (Computer Use), M3 (MLX Audio)
- Wave 4 phases (L3, M3, N3, O3) — need local LLMs
- Wave 6 verification (X3–AD3) — full build + periphery + CI

**MBAM2 (MacBook Air M2, 24 GB RAM) — LIGHTWEIGHT PHASES:**
- UI-focused phases (no ML dependency): I3 (Excluded UI Components), K3 (Config UI)
- Integration phases: T3 (Integration Backends — pure Swift, no ML)
- Transparency UIs: V3 (no ML dependency, pure SwiftUI)
- Chat UI: W3 (no ML dependency)
- Plan file edits and coordination tasks
- Single-scheme macOS/iOS builds for UI verification

**Coordination rule:** MSM3U is PRIMARY. MBAM2 runs complementary lightweight phases.
Never run the same phase on both machines simultaneously.
After each MBAM2 phase: `git pushsync` immediately so MSM3U picks up changes.

**CPU temperature monitoring (mandatory for heavy MSM3U phases):**
```bash
# Monitor CPU temperature during builds (run in background tmux pane):
while true; do
  TEMP=$(sudo powermetrics --samplers smc -n1 -i 1 2>/dev/null | grep "CPU die temperature" | awk '{print $NF}')
  echo "$(date '+%H:%M:%S') CPU: ${TEMP}°C"
  # Auto-throttle: if >90°C, pause current build for 2 min
  if [[ -n "$TEMP" ]] && (( $(echo "$TEMP > 90" | bc -l) )); then
    echo "THERMAL ALERT: CPU ${TEMP}°C — pausing 2 min"
    sleep 120
  fi
  sleep 60
done
```

Threshold: >85°C = warning (log only). >90°C = pause 2 min. >95°C = stop executor, alert.

### Pre-flight Build Gate (BEFORE EVERY PHASE)
```bash
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination 'platform=macOS' build -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD" | tail -5
# Must be "BUILD SUCCEEDED" before proceeding.
```

---

## LESSONS LEARNED FROM v1 + v2

### Git Safety
- **CRITICAL: Never commit while concurrent sessions are active on the same repo.**
  Concurrent sessions corrupt the git index → massive "N files changed, YYYY deletions" commits.
  Recovery: `git stash && git revert HEAD --no-edit && git pushsync && git stash drop && rm -f .git/index && git read-tree HEAD`
- **Always use `git add <specific-file>` not `git add -A`** when other sessions may be running.
- **iCloud syncs .git objects** — MBAM2 and MSM3U share git objects via iCloud. Don't rely on this for coordination — always use origin as source of truth.

### thea-sync Daemon
- **Always suspend thea-sync at session start** — it runs `git stash` every ~5 min and silently reverts uncommitted work.
- If thea-sync ran while you had dirty files, check `git stash list` before starting phase work.
- `launchctl unload` is idempotent — safe to call if already unloaded.

### tmux on MSM3U
- Use full path `/opt/homebrew/bin/tmux` — not in SSH PATH.
- Long-running phases MUST use tmux — SSH disconnects kill plain sessions.
- Wave 3+4 executor pattern: loop polling for phase completion, then advance.

### Type Name Conflicts
- Before adding any new type, `grep -r "TypeName" Shared/ --include="*.swift"`.
- Common prefixes that prevent conflicts: `Behavioral`, `Coaching`, `Privacy`, `MetaAI`.
- MetaAI types that conflicted with canonical Intelligence/ types need the `MetaAI` prefix
  OR need to be replaced with imports of the canonical type.

### SwiftLint
- Function body length limit is 80 lines — wrap long registration/setup functions with
  `// swiftlint:disable function_body_length` / `// swiftlint:enable`.
- Modifier order: `nonisolated private func`, NOT `private nonisolated func`.
- Pre-commit hook reformats files — verify security-critical edits weren't reverted after commit.

### Build System
- Always run `xcodegen generate` after ANY change to project.yml.
- After adding files/directories: `xcodegen generate` before building.
- MLXAudioEngine exclusion: there is a Release build issue with the audio pipeline.
  Phase M3 must identify and fix the specific error before re-enabling.
- macOS-only files: use `#if os(macOS)` guards or `**/*macOS*` naming.

### Periphery
- Phase Y3 (Periphery) must run after ALL feature phases — new code introduces new items.
- Use `// periphery:ignore - Reserved: description` for intentionally unused future API.
- Parameters: `// periphery:ignore:parameters` on function declaration (not call site).

---

## PHASE A3: META-AI FULL ACTIVATION (UI LAYER + ~45 CHERRY-PICKED FILES)

**Status: ⏳ PENDING (starts after v2 Phase U auto-transition)**

**Goal**: Activate ALL ~45 MetaAI files with genuinely unique capabilities. Create
`MetaAIDashboardView` as the branded UI face. Skip only the ~15 files superseded by canonical
Intelligence/. This unlocks Thea's full multi-agent, reasoning, autonomous-build, workflow,
and plugin capabilities — all previously silenced by blanket exclusion.

**Run after**: v2 Phase U complete (executor auto-transitions to v3)

**Audited file classification (all 73 files reviewed 2026-02-19):**

SKIP — superseded by canonical Intelligence/ (15 files):
- `MetaAIModelRouter.swift` → SmartModelRouter supersedes (file header confirms this)
- `MetaAITaskClassifier.swift` → TaskClassifier supersedes (file header confirms this)
- `KnowledgeGraph.swift` → PersonalKnowledgeGraph supersedes
- `MemorySystem.swift` → Memory/ folder supersedes
- `TaskTypes.swift` → TaskType.swift supersedes (check for `TaskContext` type conflict first)
- Build docs: `BUILD_ISSUES_RESOLUTION.md`, `SESSION_SUMMARY.md`, `PHASE_*.md`, `verify-*.sh`

CHERRY-PICK — ~45 files with unique capabilities (grouped by category):

TIER 1 — HIGHEST VALUE (wire into IntelligenceOrchestrator + ChatManager):
  Multi-Agent: MultiAgentOrchestrator, SubAgentOrchestrator, AgentSwarm, AgentRegistry,
               AgentCommunication, AgentCommunicationHub, DeepAgentEngine
  Reasoning:   ReActExecutor, ReasoningEngine, ChainOfThought, LogicalInference,
               HypothesisTesting, ReflectionEngine
  Autonomy:    AutonomousBuildLoop, AICodeFixGenerator, CodeFixer, CodeSandbox, SwiftCodeAnalyzer
  Resilience:  ResilienceManager (circuit breakers + exponential backoff — wire into providers)

TIER 2 — HIGH VALUE (add to builds, wire into dashboard):
  Error AI:    ErrorKnowledgeBase, ErrorParser, KnownFixes, ImprovementSuggestions
  Workflow:    WorkflowBuilder, WorkflowPersistence, WorkflowTemplates
  Plugins:     PluginSystem
  Parallel:    ParallelQueryExecutor, QueryDecomposer, ResultAggregator
  Tools:       ToolCall (SwiftData model), ToolCallView, ToolFramework, SystemToolBridge
  Benchmarks:  ModelBenchmarkService, ModelCapabilityDatabase, ModelCapabilityView, PerformanceMetrics
  Self-Model:  THEASelfAwareness
  Directives:  UserDirectivesConfiguration, UserDirectivesView

TIER 3 — ADD TO BUILDS (wire in Phase B3/later):
  MCP:         MCPBrowserView, MCPServerLifecycleManager, MCPToolBridge, MCPToolList
  UI Views:    KnowledgeGraphViewer, MemoryInspectorView, PluginManagerView, WorkflowBuilderView
  Utility:     FileOperations, ExecutionPipeline, InteractionAnalyzer, MultiModalAI
  Coordinator: THEAOrchestrator → RENAME to `MetaAICoordinator` (conflicts with IntelligenceOrchestrator)
  Training:    ModelTraining (fine-tuning + few-shot)

**Meta-AI brand:** IntelligenceOrchestrator stays unchanged — `MetaAICoordinator` wraps it,
adding multi-agent dispatch, ReAct reasoning, and autonomous build capabilities on top.

### A3-0: Pre-flight — Confirm Archive Location + Conflict Check

```bash
ls .v1-archive/Shared/AI/MetaAI/ | wc -l   # should be ~65 Swift files
ls .v1-archive/Shared/UI/Views/MetaAI/      # should be 4 view files

# Check for known type conflicts before copying anything:
grep -rn "struct TaskContext\|class TaskContext" Shared/ --include="*.swift"
grep -rn "class THEAOrchestrator\|final class THEAOrchestrator" Shared/ --include="*.swift"
grep -rn "struct ModelCapabilityRecord" Shared/ --include="*.swift"
grep -rn "final class MultiAgentOrchestrator" Shared/ --include="*.swift"
```

### A3-1: Copy Tier 1 Files (Multi-Agent + Reasoning + Autonomy + Resilience)

```bash
mkdir -p Shared/Intelligence/MetaAI

# Tier 1 — Multi-Agent
for f in MultiAgentOrchestrator SubAgentOrchestrator AgentSwarm AgentRegistry \
          AgentCommunication AgentCommunicationHub DeepAgentEngine; do
  cp ".v1-archive/Shared/AI/MetaAI/${f}.swift" Shared/Intelligence/MetaAI/
done

# Tier 1 — Reasoning
for f in ReActExecutor ReasoningEngine ChainOfThought LogicalInference \
          HypothesisTesting ReflectionEngine; do
  cp ".v1-archive/Shared/AI/MetaAI/${f}.swift" Shared/Intelligence/MetaAI/
done

# Tier 1 — Autonomy
for f in AutonomousBuildLoop AICodeFixGenerator CodeFixer CodeSandbox SwiftCodeAnalyzer; do
  cp ".v1-archive/Shared/AI/MetaAI/${f}.swift" Shared/Intelligence/MetaAI/
done

# Tier 1 — Resilience
cp ".v1-archive/Shared/AI/MetaAI/ResilienceManager.swift" Shared/Intelligence/MetaAI/
```

For THEAOrchestrator: copy then rename class to `MetaAICoordinator`:
```bash
cp ".v1-archive/Shared/AI/MetaAI/THEAOrchestrator.swift" Shared/Intelligence/MetaAI/MetaAICoordinator.swift
sed -i '' 's/class THEAOrchestrator/class MetaAICoordinator/g; s/THEAOrchestrator\.shared/MetaAICoordinator.shared/g' \
  Shared/Intelligence/MetaAI/MetaAICoordinator.swift
```

Build after Tier 1 copy. Fix any type conflicts before proceeding to Tier 2.

### A3-2: Copy Tier 2 + Tier 3 Files

```bash
# Tier 2
for f in ErrorKnowledgeBase ErrorParser KnownFixes ImprovementSuggestions \
          WorkflowBuilder WorkflowPersistence WorkflowTemplates PluginSystem \
          ParallelQueryExecutor QueryDecomposer ResultAggregator \
          ToolCall ToolCallView ToolFramework SystemToolBridge \
          ModelBenchmarkService ModelCapabilityDatabase ModelCapabilityView PerformanceMetrics \
          THEASelfAwareness UserDirectivesConfiguration UserDirectivesView; do
  cp ".v1-archive/Shared/AI/MetaAI/${f}.swift" Shared/Intelligence/MetaAI/
done

# Tier 3
for f in MCPBrowserView MCPServerLifecycleManager MCPToolBridge MCPToolList \
          FileOperations ExecutionPipeline InteractionAnalyzer MultiModalAI ModelTraining; do
  cp ".v1-archive/Shared/AI/MetaAI/${f}.swift" Shared/Intelligence/MetaAI/
done

# UI Views (separate folder)
mkdir -p Shared/UI/Views/MetaAI
for f in KnowledgeGraphViewer MemoryInspectorView PluginManagerView WorkflowBuilderView; do
  cp ".v1-archive/Shared/UI/Views/MetaAI/${f}.swift" Shared/UI/Views/MetaAI/
done
```

Check for TaskContext conflict: if `TaskTypes.swift` conflicts, copy but rename `TaskContext`
to `MetaAITaskContext` in the MetaAI copy only.

### A3-3: Add to project.yml (Targeted)

```yaml
# Add these new paths to macOS + iOS targets:
# - Shared/Intelligence/MetaAI/**           (all cherry-picked files)
# - Shared/UI/Views/MetaAI/**               (4 view files)
# Do NOT touch the **/AI/MetaAI/** exclusion — archive stays excluded
# Use #if os(macOS) guards in files that use AppKit/IOKit (AutonomousBuildLoop, SystemToolBridge)
```

Run `xcodegen generate` after project.yml update.

### A3-4: Create MetaAIDashboardView

New file: `Shared/UI/Views/MetaAI/MetaAIDashboardView.swift`

Dashboard tabs: Overview · Routing · Confidence · Benchmarks · Reasoning ·
Agents · Workflows · Plugins · Self-Model · Directives

```swift
import SwiftUI

struct MetaAIDashboardView: View {
    @StateObject private var orchestrator = IntelligenceOrchestrator.shared
    @State private var selectedTab: MetaAITab = .overview

    enum MetaAITab: String, CaseIterable {
        case overview = "Overview", routing = "Routing", confidence = "Confidence"
        case benchmarks = "Benchmarks", reasoning = "Reasoning", agents = "Agents"
        case workflows = "Workflows", plugins = "Plugins"
        case selfModel = "Self-Model", directives = "Directives"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — Meta-AI brand
            HStack {
                Image(systemName: "brain.head.profile").foregroundStyle(.purple)
                Text("Meta-AI Intelligence Layer").font(.headline)
                Spacer()
                Circle().fill(orchestrator.isActive ? Color.green : Color.gray).frame(width: 8, height: 8)
                Text(orchestrator.isActive ? "Active" : "Idle").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(MetaAITab.allCases, id: \.self) { tab in
                    Button(tab.rawValue) { selectedTab = tab }
                        .buttonStyle(.bordered)
                        .tint(selectedTab == tab ? .purple : .secondary)
                } }
                .padding(.horizontal)
            }
            Divider()
            Group {
                switch selectedTab {
                case .overview:    MetaAIOverviewPanel(orchestrator: orchestrator)
                case .routing:     MetaAIRoutingPanel(orchestrator: orchestrator)
                case .confidence:  MetaAIConfidencePanel()
                case .benchmarks:  MetaAIBenchmarksPanel()
                case .reasoning:   MetaAIReasoningPanel()
                case .agents:      MetaAIAgentsPanel()
                case .workflows:   WorkflowBuilderView()
                case .plugins:     PluginManagerView()
                case .selfModel:   MetaAISelfModelPanel()
                case .directives:  UserDirectivesView()
                }
            }
        }
        .navigationTitle("Meta-AI")
    }
}
```

Each panel reads LIVE data — no mocked data. See individual panel files for implementations.

### A3-5: Wire MetaAICoordinator into IntelligenceOrchestrator

```swift
// In IntelligenceOrchestrator.swift, add MetaAI coordination:
extension IntelligenceOrchestrator {
    /// Route through MetaAI when multi-agent or deep reasoning is needed
    func processWithMetaAI(_ query: String, classification: TaskType) async -> String? {
        guard classification.requiresMetaAI else { return nil }
        return await MetaAICoordinator.shared.process(query: query, classification: classification)
    }
}
```

Wire ResilienceManager into AnthropicProvider:
```swift
// Wrap API calls with circuit breaker:
let result = try await ResilienceManager.shared.execute(provider: "anthropic") {
    try await self.callAPI(...)
}
```

### A3-6: Wire into MacSettingsView + iOS Navigation

```swift
// MacSettingsView sidebar:
NavigationLink(destination: MetaAIDashboardView()) {
    Label("Meta-AI", systemImage: "brain.head.profile")
}
```

### A3-7: Verify

```bash
for scheme in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" -configuration Debug \
    -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO build 2>&1 | \
    grep -E "error:|BUILD (SUCCEEDED|FAILED)" | tail -3
done
# All Tier 1 types accessible:
grep -r "MultiAgentOrchestrator\|ReActExecutor\|ResilienceManager" Shared/ --include="*.swift" | grep -v archive | wc -l
# Dashboard wired:
grep -r "MetaAIDashboardView" Shared/ macOS/ --include="*.swift" | wc -l  # ≥2
```

Commit after each sub-step: `git add <file> && git commit -m "Auto-save: A3-N — ..."`
```

Commit after each sub-step: `git add <file> && git commit -m "Auto-save: A3-N — ..."`

---

## PHASE B3: ANTHROPIC TOOL CATALOG EXECUTION

**Status: ⏳ PENDING (starts after v2 Phase U auto-transition)**

**Goal**: The AnthropicToolCatalog defines 50+ tools. NONE of them execute. This phase
wires every tool to its execution handler and adds tool use visualization to ChatView.

**Run after**: v2 Phase U (auto-transition to v3)

### B3-1: Audit AnthropicToolCatalog

```bash
cat Shared/AI/Providers/AnthropicToolCatalog.swift | grep "name:" | wc -l  # count tools
```

Group tools by category:
- **Memory**: search_memory, add_memory, update_memory, list_memories
- **Files**: read_file, write_file, list_directory, search_files
- **System**: run_command, get_system_info, open_application
- **Web**: web_search, fetch_url
- **Code**: run_code, analyze_code, get_test_results
- **Calendar/Reminders**: list_events, create_event, list_reminders
- **Knowledge**: search_knowledge_graph, add_knowledge

### B3-2: Implement Tool Execution Handler in AnthropicProvider

```swift
// In AnthropicProvider.swift, add tool_use response handler:
private func handleToolUse(_ toolCall: AnthropicToolCall) async throws -> String {
    switch toolCall.name {
    case "search_memory":
        return await MemoryToolHandler.search(toolCall.input)
    case "add_memory":
        return await MemoryToolHandler.add(toolCall.input)
    case "read_file":
        return await FileToolHandler.read(toolCall.input)
    case "web_search":
        return await WebToolHandler.search(toolCall.input)
    case "run_code":
        return await CodeToolHandler.execute(toolCall.input)
    case "computer_use":
        return await ComputerUseHandler.execute(toolCall.input)  // Phase L3
    default:
        return "Tool '\(toolCall.name)' not yet implemented."
    }
}
```

### B3-3: Implement Tool Handlers

Create `Shared/AI/Tools/` directory with handler files:

**MemoryToolHandler.swift** — wraps PersonalKnowledgeGraph + ActiveMemoryRetrieval
```swift
actor MemoryToolHandler {
    static func search(_ input: [String: Any]) async -> String {
        let query = input["query"] as? String ?? ""
        let results = await PersonalKnowledgeGraph.shared.search(query)
        return results.map { "\($0.name): \($0.description)" }.joined(separator: "\n")
    }
    static func add(_ input: [String: Any]) async -> String { ... }
}
```

**FileToolHandler.swift** — wraps FileManager with sandbox permission checks
```swift
actor FileToolHandler {
    static func read(_ input: [String: Any]) async -> String {
        let path = input["path"] as? String ?? ""
        // Validate path (no traversal attacks, within allowed dirs)
        guard isAllowedPath(path) else { return "Access denied: \(path)" }
        return (try? String(contentsOfFile: path)) ?? "File not found"
    }
}
```

**WebToolHandler.swift** — wraps existing WebSearchVerifier
```swift
actor WebToolHandler {
    static func search(_ input: [String: Any]) async -> String {
        let query = input["query"] as? String ?? ""
        return await WebSearchVerifier.shared.search(query)
    }
}
```

**CodeToolHandler.swift** — wraps existing CodeExecutionVerifier
```swift
actor CodeToolHandler {
    static func execute(_ input: [String: Any]) async -> String {
        let code = input["code"] as? String ?? ""
        let language = input["language"] as? String ?? "javascript"
        return await CodeExecutionVerifier.shared.execute(code, language: language)
    }
}
```

### B3-4: Wire Tool Use in ChatView

Tool use steps should be visible — not silent execution:

```swift
// In ChatView / MessageBubble, add tool use step rendering:
struct ToolUseStepView: View {
    let toolName: String
    let input: [String: Any]
    let result: String?
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toolIcon(for: toolName))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text("Tool: \(toolName)")
                    .font(.caption.bold())
                if isRunning {
                    ProgressView().scaleEffect(0.6)
                } else if let result {
                    Text(result.prefix(100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

Store tool use steps in `MessageMetadata.toolUseSteps: [ToolUseStep]` (SwiftData).

### B3-5: Verify

```bash
# Run a query that should trigger tool use:
# "Search my memory for our discussion about SwiftUI" → should call search_memory
# "What time is it?" → should call get_system_info
# "Find the file CLAUDE.md" → should call list_directory + read_file
```

Test tool execution end-to-end. Verify steps appear in chat.

---

## PHASE C3: SEMANTICSEARCHSERVICE RAG INTEGRATION

**Status: ⏳ PENDING (starts after v2 Phase U auto-transition)**

**Goal**: SemanticSearchService is fully implemented but completely disconnected from the
AI request pipeline. Every ChatManager.sendMessage() should enrich the context with
semantically similar past exchanges.

### C3-1: Wire Into ChatManager

```swift
// In ChatManager.sendMessage(), after context window prep:

// EXISTING: Keyword-based memory retrieval
let memoryContext = await activeMemoryRetrieval.retrieve(for: conversationID)

// ADD: Semantic similarity retrieval
let semanticContext = await semanticSearchService.searchMessages(
    query: userMessage,
    conversationID: conversationID,
    topK: 3,
    threshold: 0.65
)

// Inject into system prompt:
let semanticSnippet = semanticContext.map { result in
    "Past context (\(Int(result.score * 100))% relevant): \(result.content)"
}.joined(separator: "\n")

systemPrompt += "\n\n---\nRelevant past context:\n\(semanticSnippet)"
```

### C3-2: Background Indexing

Existing conversations need embeddings generated in the background:

```swift
// In AppDelegate / scene init, after a short delay:
Task(priority: .background) {
    await SemanticSearchService.shared.indexAllExistingConversations()
}

// SemanticSearchService extension:
func indexAllExistingConversations() async {
    let conversations = await conversationStore.allConversations()
    for conversation in conversations {
        for message in conversation.messages {
            await updateIndex(message: message)
        }
    }
}
```

### C3-3: Configuration Toggle

In AdvancedSettingsView, add:
```swift
Toggle("Semantic Context (RAG)", isOn: $config.enableSemanticRetrieval)
Slider(value: $config.semanticThreshold, in: 0.5...0.9, step: 0.05) {
    Text("Similarity Threshold: \(config.semanticThreshold, specifier: "%.2f")")
}
```

### C3-4: Verify

Test that queries referencing past topics correctly surface relevant past exchanges.

---

## PHASE D3: CONFIDENCE SYSTEM FEEDBACK LOOP

**Status: ⏳ PENDING (starts after v2 Phase U auto-transition)**

**Goal**: ConfidenceSystem computes response confidence scores on every response, but these
scores go nowhere useful. Wire them back to SmartModelRouter and TaskClassifier so Thea
gets smarter over time.

### D3-1: ConfidenceSystem → SmartModelRouter

```swift
// After ConfidenceSystem produces a score for a response:
extension ConfidenceSystem {
    func recordOutcomeForRouting(
        taskType: TaskType,
        modelId: String,
        confidenceScore: Double
    ) async {
        await SmartModelRouter.shared.recordOutcome(
            model: modelId,
            taskType: taskType,
            qualityScore: confidenceScore
        )
    }
}

// In SmartModelRouter, accumulate quality scores:
// qualityHistory[modelId][taskType] = EMA(qualityHistory..., newScore, alpha: 0.1)
// This adjusts qualityScore used in routing decisions
```

### D3-2: ConfidenceSystem → TaskClassifier

When confidence is low, re-classify the task:

```swift
// In ChatManager, after ConfidenceSystem scores a response:
if confidenceScore < 0.5 {
    let reClassification = await taskClassifier.reclassify(
        query: originalQuery,
        previousClassification: taskType,
        lowConfidenceResponse: response
    )
    // Log reclassification for learning
    taskClassifier.recordMisclassification(
        original: taskType,
        corrected: reClassification,
        query: originalQuery
    )
}
```

### D3-3: Learning Persistence

Store classification outcomes in SwiftData for learning:

```swift
@Model
class ClassificationOutcome: Sendable {
    var query: String
    var taskType: String
    var modelId: String
    var confidenceScore: Double
    var userFeedback: Int?  // +1/-1 thumbs up/down
    var timestamp: Date
}
```

### D3-4: Verify

After running 10+ queries with mixed task types, verify:
```
SmartModelRouter.routingHistory contains quality scores
TaskClassifier.classificationAccuracy improves over time
```

---

## PHASE E3: SKILLS COMPLETE SYSTEM

**Status: ⏳ PENDING (blocked by A3)**

**Goal**: The SkillRegistry and SkillsRegistryService are well-implemented but have three
critical gaps: (1) skills not passed to sub-agents, (2) no auto-discovery, (3) no UI.
This phase closes all three.

### E3-1: Skills → Sub-Agent Inheritance

```swift
// In AgentTeamOrchestrator.executeSubTask():
// BEFORE calling Claude API for sub-agent:
let activeSkills = await SkillRegistry.shared.getActiveSkillsForContext(
    taskType: subTask.type,
    query: subTask.description
)

// Inject into sub-agent system prompt:
let skillInstructions = activeSkills
    .map { "Skill [\($0.name)]: \($0.instructions)" }
    .joined(separator: "\n\n")

subAgentSystemPrompt += "\n\n---\nActive Skills:\n\(skillInstructions)"
```

### E3-2: Skill Auto-Discovery

After AgentTeamOrchestrator completes a task with high confidence:

```swift
extension AgentTeamOrchestrator {
    func checkForNewSkillOpportunity(
        goal: String,
        steps: [PlanStep],
        outcome: AgentTeamResult
    ) async {
        guard outcome.confidence > 0.85 else { return }

        // Check if similar goals have been seen before
        let similarGoals = await PatternDetector.findSimilarGoals(goal)
        guard similarGoals.count >= 3 else { return }  // Need 3 occurrences

        // Auto-generate a skill from the successful pattern
        let skillInstructions = await Claude.synthesizeSkill(
            fromExamples: similarGoals.map(\.successfulApproach)
        )

        let newSkill = SkillDefinition(
            name: PatternDetector.suggestName(for: goal),
            description: "Auto-discovered from repeated successful pattern",
            instructions: skillInstructions,
            scope: .global,
            triggers: [SkillTrigger(type: .keyword, pattern: PatternDetector.extractKeyword(goal))]
        )

        await SkillRegistry.shared.register(newSkill)
        // Show notification: "New skill auto-discovered: [name]"
    }
}
```

### E3-3: SkillsMarketplaceView

```swift
struct SkillsMarketplaceView: View {
    @ObservedObject private var registry = SkillsRegistryService.shared
    @State private var searchQuery = ""
    @State private var selectedCategory: MarketplaceSkillCategory? = nil
    @State private var selectedSkill: MarketplaceSkill? = nil

    var body: some View {
        NavigationSplitView {
            // Categories sidebar
            List(MarketplaceSkillCategory.allCases, id: \.self, selection: $selectedCategory) { cat in
                Label(cat.rawValue.capitalized, systemImage: cat.symbolName)
            }
        } detail: {
            NavigationStack {
                List(filteredSkills) { skill in
                    SkillMarketplaceRow(skill: skill)
                        .onTapGesture { selectedSkill = skill }
                }
                .searchable(text: $searchQuery)
                .toolbar {
                    Button("Sync") { Task { try? await registry.syncMarketplace() } }
                }
            }
        }
        .sheet(item: $selectedSkill) { skill in
            SkillDetailView(skill: skill)
        }
    }
}
```

Wire into MacSettingsView sidebar:
```
├─ Skills & Marketplace
│   ├─ Installed Skills (list + manage)
│   ├─ Discover (marketplace browse)
│   ├─ Workspace Skills (per-project)
│   └─ Auto-Discovered Skills
```

### E3-4: Real Marketplace Sync (or Demo)

If Smithery/Context7 APIs are unavailable:
```swift
// In SkillsRegistryService.syncMarketplace():
// Try real API first, fall back to extended built-in catalog
do {
    let response = try await URLSession.shared.data(from: smitheryAPIURL)
    marketplaceSkills = try JSONDecoder().decode([MarketplaceSkill].self, from: response.0)
} catch {
    // Use extended built-in catalog as fallback
    marketplaceSkills = getBuiltinMarketplaceSkills()
    logger.info("Using offline marketplace catalog")
}
```

---

## PHASE F3: SQUADS UNIFIED

**Status: ⏳ PENDING (blocked by A3)**

**Goal**: SquadOrchestrator exists but is never called. AgentTeamOrchestrator handles
ephemeral teams. This phase clarifies the distinction and wires both properly.

**Design Decision:**
- **AgentTeams** (AgentTeamOrchestrator): Ephemeral, single-task, auto-created by ChatManager
- **Squads** (SquadOrchestrator): Persistent, multi-session, user-created for ongoing goals

### F3-1: Wire SquadOrchestrator

```swift
// In ChatManager, detect squad-like requests:
// "Set up a research team to monitor Swift evolution proposals"
// → Create a Squad, not a one-time AgentTeam

if taskClassifier.isLongRunningGoal(query) {
    let squad = try await SquadOrchestrator.shared.createSquad(
        SquadDefinition(
            name: suggestedName,
            goal: query,
            communicationStrategy: .broadcast,
            coordinationMode: .leader
        )
    )
    // Assign initial members based on goal type
    await SquadOrchestrator.shared.assignOptimalMembers(to: squad.id, goal: query)
}
```

### F3-2: Squad Management UI

```swift
struct SquadsView: View {
    @StateObject private var orchestrator = SquadOrchestrator.shared

    var body: some View {
        List(orchestrator.activeSquads) { squad in
            SquadRow(squad: squad)
        }
        .toolbar {
            Button("New Squad") { showCreateSquad = true }
        }
        .sheet(isPresented: $showCreateSquad) {
            SquadCreationView()
        }
    }
}
```

Wire into app navigation (macOS sidebar → "Squads", iOS tab).

---

## PHASE G3: TASKPLANDAGE ENHANCEMENT

**Status: ⏳ PENDING (blocked by D3)**

**Goal**: TaskPlanDAG decomposes goals into execution plans but has no quality feedback,
no plan caching, and no learning. This phase adds all three.

### G3-1: Plan Quality Scoring

```swift
extension TaskPlanDAG {
    func recordPlanOutcome(
        planID: UUID,
        executionTime: TimeInterval,
        successRate: Double,
        confidenceScore: Double
    ) {
        // Store in SwiftData
        let outcome = PlanOutcome(
            planID: planID,
            patternHash: hashGoalPattern(activePlans[planID]?.goal ?? ""),
            executionTime: executionTime,
            successRate: successRate,
            confidence: confidenceScore,
            timestamp: Date()
        )
        modelContext.insert(outcome)
    }

    func findSimilarPlan(for goal: String) async -> TaskPlan? {
        let hash = hashGoalPattern(goal)
        // Return highest-quality similar plan from history
        return planCache[hash]
    }
}
```

### G3-2: Plan Caching

Cache successful plans and reuse for similar goals:
```swift
var planCache: [Int: TaskPlan] = [:]  // hash → successful plan

func createPlan(goal: String) async throws -> TaskPlan {
    let hash = hashGoalPattern(goal)
    if let cached = planCache[hash], cached.quality > 0.8 {
        logger.info("Reusing cached plan for similar goal")
        return cached.withNewGoal(goal)  // Adapt to current goal
    }
    // Otherwise, decompose fresh
    let newPlan = try await decompose(goal)
    return newPlan
}
```

### G3-3: User Approval Gate for High-Risk Plans

```swift
// In AgentTeamOrchestrator, before executing plan:
if plan.estimatedRisk > AutonomyController.shared.maxAllowedRisk {
    let approval = await AutonomyController.shared.requestApproval(
        action: .executePlan(plan),
        riskLevel: plan.estimatedRisk
    )
    guard approval == .approved else { throw PlanError.rejectedByUser }
}
```

---

## PHASE H3: AI SYSTEM UIs DASHBOARD

**Status: ⏳ PENDING (blocked by A3)**

**Goal**: Create a unified transparency dashboard showing real-time decisions from every
major AI subsystem. Users should understand WHY Thea made each decision.

**Key principle**: Thea should be a glass box, not a black box.

### H3-1: Intelligence Dashboard View

```swift
struct IntelligenceDashboardView: View {
    @ObservedObject private var orchestrator = IntelligenceOrchestrator.shared
    @ObservedObject private var router = SmartModelRouter.shared
    @ObservedObject private var confidenceSystem = ConfidenceSystem.shared
    @ObservedObject private var behaviorEngine = BehavioralFingerprint.shared
    @ObservedObject private var agentTeam = AgentTeamOrchestrator.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 16) {
                // 1. Last Request Card: classification, routing, confidence
                LastRequestCard()

                // 2. Model Router Card: which model, why, cost
                ModelRouterCard(router: router)

                // 3. Confidence Card: overall + per-verifier breakdown
                ConfidenceCard(system: confidenceSystem)

                // 4. Agent Team Card: active tasks, agent count, progress
                AgentTeamCard(orchestrator: agentTeam)

                // 5. BehavioralFingerprint Card: current receptivity, patterns
                BehaviorCard(fingerprint: behaviorEngine)

                // 6. Memory Card: KG stats, last retrieved entities
                MemoryCard()

                // 7. Skill Registry Card: active skills, last triggered
                SkillsCard()

                // 8. MetaAI Card: current hypothesis, reasoning step
                MetaAICard()
            }
            .padding()
        }
        .navigationTitle("AI Intelligence Dashboard")
    }
}
```

Wire into: MacSettingsView sidebar → "Intelligence Dashboard", iOS tab.

### H3-2: Per-Response Transparency Overlay

On each response bubble, add a ℹ️ button that shows:
```
Response Details:
  Task type: codeGeneration
  Model used: claude-sonnet-4-6 (why: high code quality score for Swift)
  Confidence: 0.87 (high) — 3/5 verifiers agreed
  Skills active: Swift Best Practices, Code Review
  Memory injected: 3 relevant past exchanges
  Tool calls: 0
  Tokens: 847 in / 312 out
  Cost: $0.0014
```

### H3-3: BehavioralFingerprint Visualization

```swift
struct BehavioralHeatmapView: View {
    @ObservedObject var fingerprint = BehavioralFingerprint.shared

    var body: some View {
        // 7-day × 24-hour heatmap
        // Color: intensity = activity level (from BehavioralFingerprint.hourlyActivity[day][hour])
        VStack {
            Text("Your Activity Patterns").font(.headline)

            HeatmapGrid(
                data: fingerprint.weeklyActivityMatrix,  // [7][24] Double array
                rowLabels: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"],
                columnLabels: (0..<24).map { String(format: "%02d:00", $0) }
            )
        }
    }
}
```

---

## PHASE I3: EXCLUDED UI COMPONENTS ACTIVATION

**Status: ⏳ PENDING (blocked by H3)**

**Goal**: Wire all excluded UI components into the app.

### I3-1: StreamingTextView

Replace standard `Text` rendering with `StreamingTextView` in response bubbles:

```swift
// In MessageBubble / ChatView response section:
// BEFORE: Text(message.content).markdownText()
// AFTER:
StreamingTextView(
    text: message.content,
    isStreaming: message.isStreaming,
    showCaret: message.isStreaming
)
```

Verify that streaming character animation works correctly.

### I3-2: MemoryContextView

Show when memory was injected into a request:

```swift
// If message has injected memory context, show below response:
if let memoryContext = message.metadata?.injectedMemory, !memoryContext.isEmpty {
    DisclosureGroup("Memory Context (\(memoryContext.count) items)") {
        MemoryContextView(items: memoryContext)
    }
}
```

### I3-3: ConfidenceIndicatorViews

Wire ConfidenceIndicator badge into every response bubble:

```swift
// In response MessageBubble, add confidence badge:
HStack {
    Spacer()
    if let confidence = message.metadata?.confidence {
        ConfidenceIndicator(score: confidence, compact: true)
            .help("Response confidence: \(Int(confidence * 100))%")
    }
}
```

### I3-4: QuerySuggestionOverlay

Wire into ChatView input area:

```swift
// In ChatView text input area:
.overlay(alignment: .top) {
    if !queryText.isEmpty, queryText.count > 3 {
        QuerySuggestionOverlay(
            query: queryText,
            onSelect: { suggestion in queryText = suggestion }
        )
    }
}
```

### I3-5: THEAThinkingView

Show while AI is generating (currently a spinner is used instead):

```swift
// Replace spinner with THEAThinkingView in response area:
if isGenerating {
    THEAThinkingView()
        .transition(.opacity)
}
```

---

## PHASE J3: LIFE TRACKING VISUALIZATION

**Status: ⏳ PENDING (blocked by I3)**

**Goal**: Life tracking backend is active and collecting data. The UI is minimal. Create
a full dashboard with heatmaps, pattern analysis, and actionable recommendations.

### J3-1: Activity Timeline

```swift
struct ActivityTimelineView: View {
    @ObservedObject private var coordinator = LifeMonitoringCoordinator.shared

    var body: some View {
        List(coordinator.todayActivities) { activity in
            ActivityTimelineRow(
                time: activity.startTime,
                duration: activity.duration,
                app: activity.foregroundApp,
                context: activity.context  // coding, browsing, messaging, etc.
            )
        }
    }
}
```

### J3-2: Behavioral Patterns Panel

Use BehavioralFingerprint data to show:
- When is the user most productive? (code commits, long focus sessions)
- When does the user tend to take breaks?
- Communication patterns (when do messages arrive vs. when responded to)
- Optimal times for different task types

### J3-3: Proactive Coaching Cards

Surface insights from HealthCoachingPipeline in the UI:

```swift
struct CoachingInsightCard: View {
    let insight: HealthCoachingInsight
    let dismissedAt: Date?

    var body: some View {
        VStack(alignment: .leading) {
            Label(insight.title, systemImage: insight.systemImage)
                .font(.headline)
            Text(insight.detail)
                .font(.body)
            if let action = insight.recommendedAction {
                Button(action.label) { action.execute() }
                    .buttonStyle(.bordered)
            }
        }
    }
}
```

### J3-4: Privacy Controls

Per-sensor enable/disable:
```swift
// In LifeTrackingSettingsView, add granular controls:
ForEach(TrackingDataType.allCases) { type in
    Toggle(type.displayName, isOn: binding(for: type))
    // Shows: data collected, retention period, how it's used
}
```

---

## PHASE K3: CONFIG UI COMPLETION

**Status: ⏳ PENDING (blocked by H3)**

**Goal**: TheaConfigSections defines 200+ configuration options. Only ~30% have UI.
This phase adds sliders, weight distributions, threshold visualizers, and expert controls.

### K3-1: AI Configuration Panel (Advanced)

```swift
struct AdvancedAIConfigView: View {
    @ObservedObject private var config = AppConfiguration.shared

    var body: some View {
        Form {
            Section("Model Routing") {
                Slider(value: $config.ai.qualityWeight, in: 0...1) {
                    Text("Quality Weight: \(config.ai.qualityWeight, specifier: "%.2f")")
                }
                Slider(value: $config.ai.costWeight, in: 0...1) {
                    Text("Cost Weight: \(config.ai.costWeight, specifier: "%.2f")")
                }
                Slider(value: $config.ai.latencyWeight, in: 0...1) {
                    Text("Latency Weight: \(config.ai.latencyWeight, specifier: "%.2f")")
                }
            }

            Section("Verification Thresholds") {
                Slider(value: $config.verification.minimumConfidence, in: 0...1) {
                    Text("Min Confidence to Accept: \(Int(config.verification.minimumConfidence * 100))%")
                }
                Slider(value: $config.verification.lowConfidenceThreshold, in: 0...1) {
                    Text("Low Confidence Warning: \(Int(config.verification.lowConfidenceThreshold * 100))%")
                }
            }

            Section("Learning") {
                Slider(value: $config.ai.learningRate, in: 0.01...0.5) {
                    Text("Learning Rate: \(config.ai.learningRate, specifier: "%.3f")")
                }
                Slider(value: $config.ai.feedbackDecayFactor, in: 0.1...1.0) {
                    Text("Feedback Decay: \(config.ai.feedbackDecayFactor, specifier: "%.2f")")
                }
            }
        }
    }
}
```

### K3-2: Config Export/Import

```swift
// Settings toolbar:
Button("Export Config") {
    let configData = try? AppConfiguration.shared.exportJSON()
    // Present save panel
}
Button("Import Config") {
    // Present open panel, import and validate
}
Button("Reset to Defaults") {
    AppConfiguration.shared.resetToDefaults()
}
```

---

## PHASE L3: COMPUTER USE

**Status: ⏳ PENDING (blocked by B3)**

**Goal**: Implement Claude API computer_use tool for macOS. Enables GUI automation,
screen interaction, and visual task execution.

**Note**: Computer Use is macOS-only. iOS sandboxing prevents this entirely.

### L3-1: Add computer_use to AnthropicToolCatalog

```swift
// In AnthropicToolCatalog.buildToolCatalog():
// Add computer_use tool (macOS only)
#if os(macOS)
tools.append(AnthropicTool(
    name: "computer_use",
    description: "Interact with the macOS GUI: take screenshots, click, type, scroll",
    inputSchema: .object(properties: [
        "action": .string(enum: ["screenshot", "click", "type", "scroll", "key"]),
        "coordinate": .array(items: .integer),  // [x, y] for click/scroll
        "text": .string,                          // for type action
        "key": .string                            // for key action
    ])
))
#endif
```

### L3-2: Implement ComputerUseHandler

```swift
#if os(macOS)
import CoreGraphics
import AppKit

actor ComputerUseHandler {
    static func execute(_ input: [String: Any]) async -> String {
        let action = input["action"] as? String ?? "screenshot"

        switch action {
        case "screenshot":
            return await takeScreenshot()
        case "click":
            guard let coords = input["coordinate"] as? [Int], coords.count == 2 else {
                return "Error: coordinate required for click"
            }
            return await performClick(x: coords[0], y: coords[1])
        case "type":
            let text = input["text"] as? String ?? ""
            return await typeText(text)
        case "scroll":
            guard let coords = input["coordinate"] as? [Int], coords.count == 2 else {
                return "Error: coordinate required for scroll"
            }
            let delta = input["delta"] as? Int ?? 3
            return await performScroll(x: coords[0], y: coords[1], delta: delta)
        case "key":
            let key = input["key"] as? String ?? ""
            return await pressKey(key)
        default:
            return "Unknown computer_use action: \(action)"
        }
    }

    private static func takeScreenshot() async -> String {
        guard let display = CGMainDisplayID() as CGDirectDisplayID?,
              let image = CGDisplayCreateImage(display) else {
            return "Error: could not capture screen"
        }
        // Convert to base64 for API response
        let nsImage = NSImage(cgImage: image, size: .zero)
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return "Error: could not encode screenshot"
        }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }

    private static func performClick(x: Int, y: Int) async -> String {
        let point = CGPoint(x: x, y: y)
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
        return "Clicked at (\(x), \(y))"
    }

    private static func typeText(_ text: String) async -> String {
        let source = CGEventSource(stateID: .hidSystemState)
        for character in text.unicodeScalars {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character.value])
            keyDown?.post(tap: .cghidEventTap)
        }
        return "Typed: \(text.prefix(50))..."
    }
}
#endif
```

**Security Note**: Computer Use requires explicit user permission in app Settings.
Add a "Computer Use" toggle in AutonomyController settings, default OFF.

---

## PHASE M3: MLX AUDIO RE-ENABLE

**Status: ⏳ PENDING (starts after v2 Phase U auto-transition)**

**Goal**: MLXAudioEngine and MLXVoiceBackend were temporarily excluded from builds
due to a Release configuration build error. Identify and fix the error.

### M3-1: Identify the Build Error

```bash
# Build with MLXAudioEngine included:
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Release \
  -destination 'platform=macOS' build -derivedDataPath /tmp/TheaBuildRelease \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep "error:" | head -20
```

Read the error carefully. Common Release-only errors:
- Missing `#if DEBUG` guards around debug-only code
- Optimization-level issues (Release uses -O2, Debug uses -Onone)
- Missing symbol visibility (public vs internal)

### M3-2: Fix the Error

Apply the minimum fix to make the file compile in Release mode.
Re-enable in project.yml by removing the exclusion comments:

```yaml
# REMOVE THESE LINES:
# - "**/AI/Audio/MLXAudioEngine.swift"
# - "**/Voice/MLXVoiceBackend.swift"
# - "**/AI/LiveGuidance/LocalVisionGuidance.swift"  (if also affected)
# - "**/Settings/LiveGuidanceSettingsView.swift"    (if also affected)
```

Run `xcodegen generate` after project.yml change.

### M3-3: Verify

```bash
# Must succeed in both Debug AND Release:
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug build
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Release build
```

Test TTS: generate a spoken response. Test STT: transcribe a test audio clip.

---

## PHASE N3: ARTIFACT SYSTEM

**Status: ⏳ PENDING (blocked by E3)**

**Goal**: Generated code, plans, MCP configs, and other structured outputs need to persist
beyond conversation history. Create an artifact store and browser UI.

### N3-1: ArtifactStore

```swift
@Model
class GeneratedArtifact: Sendable {
    @Attribute(.unique) var id: UUID
    var title: String
    var type: ArtifactType  // .code, .plan, .mcpServer, .apiSpec, .skillDefinition, .report
    var content: String
    var language: String?   // for .code artifacts: "swift", "python", etc.
    var metadata: [String: String]
    var conversationID: UUID?
    var createdAt: Date
    var lastAccessedAt: Date
    var tags: [String]
    var isFavorite: Bool
}

enum ArtifactType: String, Codable {
    case code, plan, mcpServer, apiSpec, skillDefinition, document, report
}
```

### N3-2: ArtifactBrowserView

```swift
struct ArtifactBrowserView: View {
    @Query(sort: \GeneratedArtifact.createdAt, order: .reverse) private var artifacts: [GeneratedArtifact]
    @State private var searchText = ""
    @State private var selectedType: ArtifactType? = nil
    @State private var selectedArtifact: GeneratedArtifact? = nil

    var body: some View {
        NavigationSplitView {
            // Type filter sidebar
            List {
                ForEach(ArtifactType.allCases) { type in
                    HStack {
                        Label(type.displayName, systemImage: type.symbolName)
                        Spacer()
                        Text("\(artifacts.filter { $0.type == type }.count)")
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture { selectedType = type }
                }
            }
        } detail: {
            List(filteredArtifacts, selection: $selectedArtifact) { artifact in
                ArtifactRow(artifact: artifact)
            }
            .searchable(text: $searchText)
        }
    }
}
```

### N3-3: Wire Artifact Creation

When generated code is produced by ChatManager or AgentTeamOrchestrator:
```swift
// After successful code generation:
let artifact = GeneratedArtifact(
    title: suggestTitle(from: code),
    type: .code,
    content: code,
    language: detectedLanguage,
    conversationID: currentConversation.id,
    tags: extractedTags
)
modelContext.insert(artifact)
```

---

## PHASE O3: MCP CLIENT

**Status: ⏳ PENDING (blocked by B3)**

**Goal**: Thea can generate MCP servers but cannot connect to them as a client.
Build a generic MCP client that connects to any MCP-compatible server.

### O3-1: GenericMCPClient

```swift
actor GenericMCPClient {
    let serverURL: URL
    var isConnected: Bool = false
    var serverInfo: MCPServerInfo?
    var availableTools: [MCPToolSpec] = []
    var availableResources: [MCPResourceSpec] = []

    func connect() async throws {
        // Send initialize request
        let response = try await sendRequest(MCPRequest(
            method: "initialize",
            params: ["protocolVersion": "2024-11-05", "clientInfo": ["name": "Thea", "version": "1.5.0"]]
        ))
        isConnected = true

        // Discover capabilities
        availableTools = try await listTools()
        availableResources = try await listResources()
    }

    func callTool(_ name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        let response = try await sendRequest(MCPRequest(
            method: "tools/call",
            params: ["name": name, "arguments": arguments]
        ))
        return try MCPToolResult(from: response)
    }

    func readResource(_ uri: String) async throws -> String {
        let response = try await sendRequest(MCPRequest(
            method: "resources/read",
            params: ["uri": uri]
        ))
        return (response.result?["contents"] as? [[String: Any]])?.first?["text"] as? String ?? ""
    }
}
```

### O3-2: MCP Server Browser UI

```swift
struct MCPServerBrowserView: View {
    @StateObject private var clientManager = MCPClientManager.shared

    var body: some View {
        List {
            Section("Connected Servers") {
                ForEach(clientManager.connectedServers) { server in
                    MCPServerRow(server: server)
                }
            }
            Section("Discovered Servers") {
                // Scan for local MCP servers (well-known ports, mDNS, config file)
                ForEach(clientManager.discoveredServers) { server in
                    ConnectButton(server: server)
                }
            }
        }
        .toolbar {
            Button("Add Server") { showAddServer = true }
        }
    }
}
```

### O3-3: Wire MCP Tools into AnthropicToolCatalog

For each connected MCP server, dynamically add its tools:
```swift
for server in MCPClientManager.shared.connectedServers {
    for tool in server.availableTools {
        AnthropicToolCatalog.shared.registerDynamicTool(
            name: "\(server.name)__\(tool.name)",
            description: tool.description,
            handler: { input in try await server.client.callTool(tool.name, arguments: input) }
        )
    }
}
```

---

## PHASE P3: PERSONAL KNOWLEDGE GRAPH ENHANCEMENT

**Status: ⏳ PENDING (starts after v2 Phase U auto-transition)**

**Goal**: PersonalKnowledgeGraph grows indefinitely without pruning or deduplication.
Add background consolidation, contradiction resolution, and importance decay.

### P3-1: Entity Deduplication

```swift
extension PersonalKnowledgeGraph {
    func deduplicateEntities() async {
        // Find entities with identical or near-identical names
        let entityGroups = Dictionary(grouping: entities.values) { entity -> String in
            entity.name.lowercased().trimmingCharacters(in: .punctuationCharacters)
        }

        for (_, group) in entityGroups where group.count > 1 {
            // Merge duplicates: keep highest-confidence version, merge relationships
            let canonical = group.max(by: { $0.confidence < $1.confidence })!
            let duplicates = group.filter { $0.id != canonical.id }

            for duplicate in duplicates {
                mergeEntity(duplicate, into: canonical)
                entities.removeValue(forKey: duplicate.id)
            }
        }
        saveGraph()
    }
}
```

### P3-2: Importance Decay

```swift
// Entities not accessed for 90 days have importance decayed:
func applyImportanceDecay() {
    let cutoff = Date().addingTimeInterval(-90 * 24 * 3600)
    for (id, entity) in entities where entity.lastAccessed < cutoff {
        entities[id]?.importance *= 0.9
        if entities[id]!.importance < 0.05 {
            entities.removeValue(forKey: id)  // Prune very stale entities
        }
    }
}
```

### P3-3: Background Consolidation

Schedule weekly consolidation:
```swift
// In AppDelegate / scene init:
Task(priority: .background) {
    while true {
        try await Task.sleep(for: .seconds(7 * 24 * 3600))
        await PersonalKnowledgeGraph.shared.deduplicateEntities()
        await PersonalKnowledgeGraph.shared.applyImportanceDecay()
        await PersonalKnowledgeGraph.shared.resolveContradictions()
    }
}
```

---

## PHASE Q3: PROACTIVE INTELLIGENCE COMPLETE

**Status: ⏳ PENDING (blocked by P3)**

**Goal**: Notifications are sent but insights are ephemeral. Add a persistent insight
repository, user feedback collection, and weekly coaching summaries.

### Q3-1: InsightRepository

```swift
@Model
class DeliveredInsight: Sendable {
    var id: UUID
    var title: String
    var body: String
    var category: InsightCategory  // .health, .productivity, .habits, .recommendations
    var deliveredAt: Date
    var userFeedback: InsightFeedback?  // .helpful, .notRelevant, .dismissed
    var actionTaken: Bool
    var source: InsightSource  // .healthCoaching, .behavioralFingerprint, .metaAI
}
```

### Q3-2: Insight History View

```swift
struct InsightHistoryView: View {
    @Query(sort: \DeliveredInsight.deliveredAt, order: .reverse) private var insights: [DeliveredInsight]

    var body: some View {
        List(insights) { insight in
            VStack(alignment: .leading) {
                Text(insight.title).font(.headline)
                Text(insight.body).font(.body).foregroundStyle(.secondary)
                HStack {
                    Text(insight.deliveredAt, style: .date).font(.caption2)
                    Spacer()
                    FeedbackButtons(insight: insight)
                }
            }
        }
    }
}
```

### Q3-3: Weekly Summary Notification

Every Sunday at the user's optimal time (from BehavioralFingerprint):
```swift
// In SmartNotificationScheduler:
func scheduleWeeklySummary() async {
    let summary = await HealthCoachingPipeline.shared.generateWeeklySummary()
    let deliveryTime = await BehavioralFingerprint.shared.optimalTimeForCategory(.summary)

    await NotificationService.shared.scheduleReminder(
        title: "Your Weekly Thea Summary",
        body: summary.headline,
        at: deliveryTime,
        repeats: false
    )
}
```

---

## PHASE R3: SELFEVOLUTION WIRING

**Status: ⏳ PENDING (blocked by H3)**

**Goal**: SelfEvolutionEngine has the right architecture but stub implementations.
Since Thea is sandboxed and can't rewrite its own binary, implement a practical version:
Thea drafts code change requests as artifacts, not live modifications.

### R3-1: Practical Implementation

```swift
// Replace stub implementations with artifact-based approach:
extension SelfEvolutionEngine {
    func processFeatureRequest(_ request: String) async throws -> EvolutionTask {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Step 1: Analyze request (this IS possible — just call Claude)
        let analysis = try await Claude.analyze(request: request, context: "Swift iOS/macOS app")

        // Step 2: Generate implementation as an artifact (not live code)
        isImplementing = true
        let implementation = try await Claude.generateImplementation(
            analysis: analysis,
            existingCode: readRelevantSourceFiles(for: analysis)
        )
        isImplementing = false

        // Step 3: Create a code artifact (not live modification)
        let artifact = GeneratedArtifact(
            title: "SelfEvolution: \(analysis.featureName)",
            type: .code,
            content: implementation.code,
            language: "swift",
            tags: ["self-evolution", "pending-review"]
        )
        modelContext.insert(artifact)

        // Step 4: Notify user to review
        return EvolutionTask(
            request: request,
            status: .awaitingReview,
            artifactID: artifact.id,
            summary: "Implementation ready for your review in Artifacts."
        )
    }
}
```

This means: Thea can PROPOSE code changes (as reviewable artifacts), but the user
applies them. Safe, useful, and architecturally sound.

---

## PHASE S3: MCPSERVERGENERATOR UI

**Status: ⏳ PENDING (blocked by O3)**

**Goal**: MCPServerGenerator can generate MCP server code but has no UI.
Create a visual MCP server builder.

### S3-1: MCPBuilderView

```swift
struct MCPBuilderView: View {
    @State private var serverName = ""
    @State private var tools: [MCPToolSpec] = []
    @State private var selectedTemplate: MCPTemplate?
    @State private var generatedServer: GeneratedMCPServer?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Info") {
                    TextField("Server Name", text: $serverName)
                    Picker("Template", selection: $selectedTemplate) {
                        Text("Custom").tag(nil as MCPTemplate?)
                        ForEach(MCPServerGenerator.shared.getAvailableTemplates()) { template in
                            Text(template.name).tag(template as MCPTemplate?)
                        }
                    }
                }
                Section("Tools") {
                    ForEach($tools, id: \.name) { $tool in
                        ToolSpecRow(tool: $tool)
                    }
                    Button("Add Tool") { tools.append(MCPToolSpec.empty) }
                }
                Section {
                    Button("Generate Server") {
                        Task {
                            generatedServer = try? await MCPServerGenerator.shared.generateServer(
                                from: MCPServerSpec(name: serverName, tools: tools)
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("MCP Server Builder")
            .sheet(item: $generatedServer) { server in
                GeneratedServerPreview(server: server)
            }
        }
    }
}
```

Wire into MacSettingsView → "Developer" → "MCP Server Builder".

---

## PHASE X3: TEST COVERAGE ≥80%

**Status: ⏳ PENDING (blocked by A3–S3)**

**Goal**: Run the same test coverage process as v2's Phase Q, but on ALL code
including all v3 additions. Every new file in A3–S3 needs tests.

### X3-1: Test All New Files

For each phase in A3–S3, write tests covering:
- Happy path
- Error paths
- Edge cases
- Security-critical paths (100% branch coverage)

Priority test files (new in v3):
- MetaAIOrchestrator tests
- ToolExecutionHandler tests (each tool handler)
- SemanticSearchService integration tests
- SkillAutoDiscovery tests
- ComputerUseHandler tests (macOS only)
- ArtifactStore tests
- GenericMCPClient tests

### X3-2: Coverage Gate

```bash
xcodebuild test -project Thea.xcodeproj -scheme Thea-macOS \
  -destination 'platform=macOS' -resultBundlePath /tmp/TheaTests.xcresult \
  CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/TheaBuild

xcrun xccov view --report --json /tmp/TheaTests.xcresult/1_Test/action.xccovreport \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
lines = data.get('lineCoverage', 0) * 100
print(f'Coverage: {lines:.1f}%')
if lines < 80:
    sys.exit(1)
"
```

---

## PHASE Y3: PERIPHERY CLEAN

**Status: ⏳ PENDING (blocked by X3)**

Same as v2's Phase R, but on the new v3 code:
```bash
periphery scan --project Thea.xcodeproj --schemes Thea-macOS Thea-iOS \
  --format xcode 2>&1 | grep "warning:" | wc -l
```
Goal: 0 unaddressed Periphery warnings.

---

## PHASE Z3: CI GREEN

**Status: ⏳ PENDING (blocked by Y3)**

Same as v2's Phase S. All 6 GitHub workflows must pass:
- Thea CI ✅
- Thea E2E Tests ✅
- Thea Security Audit ✅
- Thea Release ✅
- Thea Security Scanning ✅

Plus v3 additions:
- AnthropicToolCatalog tool execution tests pass in CI
- Computer Use tests pass on macOS runner
- MLX Audio builds pass in Release config

---

## PHASE AA3: RE-VERIFICATION

**Status: ⏳ PENDING (blocked by Z3)**

Same as v2's Phase W (V1 Re-verification), but for ALL criteria:

```bash
# Run Phase W from v2 first (all v1+v2 checks)

# Then add v3-specific checks:

# 1. MetaAI is active
grep -r "MetaAIOrchestrator" Shared/ --include="*.swift" | wc -l  # > 0

# 2. Tools are executing (not just defined)
grep -r "ToolExecutionHandler\|handleToolUse" Shared/ --include="*.swift" | wc -l  # > 0

# 3. SemanticSearchService is wired
grep -r "semanticSearchService.searchMessages\|SemanticSearchService.shared.search" \
  Shared/Core/Managers/ChatManager.swift  # must find a result

# 4. Skills auto-discovery is wired
grep -r "checkForNewSkillOpportunity\|SkillAutoDiscovery" Shared/ --include="*.swift" | wc -l

# 5. Squads wired
grep -r "SquadOrchestrator.shared" Shared/ --include="*.swift" | grep -v "SquadOrchestrator.swift" | wc -l

# 6. BehavioralFingerprint has visualization
ls Shared/UI/Views/ | grep -i "heatmap\|behavioral\|pattern"

# 7. ConfidenceIndicator wired in ChatView
grep -r "ConfidenceIndicator" Shared/UI/Views/Chat/ --include="*.swift" | wc -l
```

---

## PHASE AB3: NOTARIZATION

**Status: ⏳ PENDING (blocked by AA3)**

Same as v2's Phase T. Produce a notarized .dmg and IPA:

```bash
# Trigger release workflow via GitHub:
git tag v1.5.0
git pushsync
# → release.yml triggers → produces Thea-v1.5.0.dmg and Thea-v1.5.0.ipa
```

Verify notarization ticket from Apple.

---

## PHASE AC3: FINAL VERIFICATION REPORT

**Status: ⏳ PENDING (blocked by AB3)**

Generate a comprehensive report covering:

1. **v3 Capabilities Added** (list all 20 phases completed)
2. **Active Systems** (now ~65+ fully wired)
3. **Tool Execution Coverage** (% of AnthropicToolCatalog tools with handlers)
4. **UI Coverage** (% of active systems with UI, target: ≥85%)
5. **Test Coverage** (overall line coverage, security coverage)
6. **CI Status** (all 6 workflows green)
7. **Meta-AI Integration** (types resolved, files active, UI accessible)
8. **Skills Active** (built-in + auto-discovered + marketplace)
9. **Performance Benchmarks** (average response time, tool execution time)

---

## PHASE AD3: COMBINED FINAL GATE — ALEXIS ONLY

**Status: ⏳ MANUAL — includes v2 Phase V + v3 verification sign-off**

**This is the SINGLE manual gate for both v2 and v3. Nothing was reviewed between v2 and v3.**

Manual testing checklist:
- [ ] Meta-AI visible in app ("Meta-AI" label, benchmarking accessible)
- [ ] Ask: "Search my memory for [topic]" → verify search_memory tool executes
- [ ] Ask: "Take a screenshot and describe it" → verify computer_use works (macOS)
- [ ] Check AI System Dashboard — confirms real-time intelligence data visible
- [ ] Install a skill from marketplace → verify it affects subsequent queries
- [ ] Create a squad → verify squad is tracked across sessions
- [ ] Voice input → STT transcription works (after M3)
- [ ] Listen to a TTS response (after M3)
- [ ] Check BehavioralFingerprint heatmap in Life Tracking
- [ ] Generate a code artifact → verify it appears in Artifact Browser
- [ ] Connect to an MCP server → verify its tools appear in tool catalog
- [ ] `git tag v1.5.0 && git pushsync` → verify release workflow produces notarized .dmg
**v2 Phase V items (deferred from v2 completion):**
- [ ] Start Thea on macOS — verify TheaMessagingGateway starts (curl http://127.0.0.1:18789/health → 200)
- [ ] Send test message from Telegram/Discord → verify it routes through AI and responds
- [ ] Open Safari → start Thea → verify SafariIntegration responds to URL requests
- [ ] Check CI: github.com/Atchoum23/Thea/actions → all 6 workflows GREEN
- [ ] Run `swift test` → 0 failures
- [ ] Verify release .dmg installs and runs without Gatekeeper warnings

**v3 sign-off:**
- [ ] ✅ Sign off: "v2+v3 complete — Thea is fully wired and verified."

---

## PROGRESS TRACKING

Update this section after each phase completes:

| Phase | Description                              | Status      | Agent    | Completed |
|-------|------------------------------------------|-------------|----------|-----------|
| v2    | PREREQUISITE — v2 Phase V               | ⏳ PENDING  | Alexis   | —         |
| A3    | Meta-AI Reintegration                    | ⏳ PENDING  | —        | —         |
| B3    | AnthropicToolCatalog Execution           | ⏳ PENDING  | —        | —         |
| C3    | SemanticSearchService RAG                | ⏳ PENDING  | —        | —         |
| D3    | ConfidenceSystem Feedback Loop           | ⏳ PENDING  | —        | —         |
| E3    | Skills Complete System                   | ⏳ PENDING  | —        | —         |
| F3    | Squads Unified                           | ⏳ PENDING  | —        | —         |
| G3    | TaskPlanDAG Enhancement                  | ⏳ PENDING  | —        | —         |
| H3    | AI System UIs Dashboard                  | ⏳ PENDING  | —        | —         |
| I3    | Excluded UI Components                   | ⏳ PENDING  | —        | —         |
| J3    | Life Tracking Visualization              | ⏳ PENDING  | —        | —         |
| K3    | Config UI Completion                     | ⏳ PENDING  | —        | —         |
| L3    | Computer Use                             | ⏳ PENDING  | —        | —         |
| M3    | MLX Audio Re-enable                      | ⏳ PENDING  | —        | —         |
| N3    | Artifact System                          | ⏳ PENDING  | —        | —         |
| O3    | MCP Client                               | ⏳ PENDING  | —        | —         |
| P3    | PersonalKnowledgeGraph Enhancement       | ⏳ PENDING  | —        | —         |
| Q3    | Proactive Intelligence Complete          | ⏳ PENDING  | —        | —         |
| R3    | SelfEvolution Wiring                     | ⏳ PENDING  | —        | —         |
| S3    | MCPServerGenerator UI                    | ⏳ PENDING  | —        | —         |
| T3    | Integration Backends (7 integrations)    | ⏳ PENDING  | —        | —         |
| U3    | AI Subsystem Re-evaluation               | ⏳ PENDING  | —        | —         |
| V3    | Transparency & Analytics UIs             | ⏳ PENDING  | —        | —         |
| W3    | Chat Enhancement Features                | ⏳ PENDING  | —        | —         |
| X3    | Test Coverage ≥80% (A3–W3 code)          | ⏳ PENDING  | —        | —         |
| Y3    | Periphery Clean (A3–W3 code)             | ⏳ PENDING  | —        | —         |
| Z3    | CI Green (v3 code)                       | ⏳ PENDING  | —        | —         |
| AA3    | Re-verification (v1+v2+v3 criteria)      | ⏳ PENDING  | —        | —         |
| AB3    | Notarization                             | ⏳ PENDING  | —        | —         |
| AC3    | Final Verification Report                | ⏳ PENDING  | —        | —         |
| AD3    | Manual Gate                              | ⏳ MANUAL   | Alexis   | —         |

---

## HOW TO LAUNCH v3 AUTONOMOUSLY

After v2 Phase V is complete, send this prompt to a fresh Claude Code session on MSM3U:

```
Read /Users/alexis/Documents/IT & Tech/MyApps/Thea/.claude/THEA_CAPABILITY_PLAN_v3.md

Verify v2 Phase U is complete (check THEA_SHIP_READY_PLAN_v2.md for Phase U/W status).
If v2 Phase U is NOT complete, wait and poll until it completes.

If v2 IS complete, begin executing v3 starting from Phase A3.
Follow the SESSION SAFETY PROTOCOL at the top of this file.
Run phases in Wave order as specified.
For waves with parallel phases, launch 2 tmux sessions.
Commit after every file. Report progress via ntfy.sh/thea-msm3u.
Run autonomously until Phase AD3 (Manual Gate), then notify me.
```

**ntfy.sh notification tags for v3:**

| Event | Priority | Tag |
|---|---|---|
| Phase start | 2 | arrow_forward |
| Phase complete | 4 | white_check_mark |
| Build failure | 5 | rotating_light |
| Conflict found | 4 | warning |
| Type conflict resolved | 3 | wrench |
| v3 fully complete | 5 | tada |

---

*This plan was created 2026-02-19 based on a comprehensive 20-point audit of Thea's codebase.*
*It addresses every identified gap, wires every orphaned system, and delivers Thea as an*
*autonomous, self-improving, fully transparent AI assistant.*
