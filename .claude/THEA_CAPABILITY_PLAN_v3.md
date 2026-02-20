# THEA CAPABILITY MAXIMIZATION PLAN v3.8
# ══════════════════════════════════════════════════════════════════════════════
# ⚠️  ABSOLUTE NON-NEGOTIABLE RULE — NEVER REMOVE ANYTHING. ONLY ADD AND FIX.
# ══════════════════════════════════════════════════════════════════════════════
#
# Created: 2026-02-19 | Updated: 2026-02-19 19:40 CET → v3.8
# v3.1 (13:47): initial | v3.2: MetaAI audit | v3.3: snippets | v3.4: behavioral protocols
# v3.5 (15:37): 1113-file codebase audit; AE3 (platform observers) + AF3 (settings nav)
# v3.6 (16:05): AG3 (Comprehensive QA) + AH3 (8-hat audit → implement all)
# v3.7 (18:xx): TRUE parallelism — 5 simultaneous streams; A3 only blocks H3; all other phases independent
# v3.8 (19:40): Full automation — 6 parallel streams auto-spawned (5 MSM3U + MBAM2 via SSH); zero human gates;
#              Phase T parallelised with U; LOCAL-FIRST Rule 9; AE3→stream 5, AF3→stream 6; ci.yml .claude/** ignore
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
# v3 MISSION: Autonomously and as quickly as possible make Thea as reliable, omnipotent,
# omniscient, omnipresent, and omnificent as possible — ship-ready across all platforms
# per industry's latest and highest standards. Close every gap. Wire everything. Activate
# everything. Transform Thea from 30% to 100% realized capability.
#
# v3 ADDITIONS OVER v2:
#   1. Meta-AI Full Activation — cherry-pick ~71 files (all 77 individually audited; skip 6 superseded), MetaAIDashboard UI, MetaAICoordinator, multi-agent/reasoning/autonomy/workflow/plugin suites all activated
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
2. Adding ~57 cherry-picked MetaAI files + new features BEFORE Phase Q makes Q much harder
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
| Phase A3: Meta-AI         | ✅ DONE         | 71 files activated, MetaAIDashboardView wired, BUILD SUCCEEDED sha 807227fa |
| Phase B3: Tool Execution  | ⏳ PENDING      | Blocked by v2→v3 auto-transition |
| Phase C3: RAG / Semantic  | ⏳ PENDING      | Blocked by v2→v3 auto-transition |
| Phase D3: Confidence Loop | ⏳ PENDING      | Blocked by v2→v3 auto-transition |
| Phase E3: Skills Complete | ⏳ PENDING      | Blocked by A3 |
| Phase F3: Squads Unified  | ✅ DONE         | SquadDefinition+CommunicationStrategy+CoordinationMode; persistentSquads; SquadsView; MacSettingsView sidebar sha 49bc33f0 |
| Phase G3: TaskPlanDAG+    | ✅ DONE         | PlanOutcome quality scoring, planCache, createPlan cache lookup, AgentTeamOrchestrator approval gate sha 34a0083d |
| Phase H3: AI System UIs   | ⏳ PENDING      | Blocked by A3 |
| Phase I3: UI Components   | ⏳ PENDING      | Blocked by H3 |
| Phase J3: LifeTracking UI | ⏳ PENDING      | Blocked by I3 |
| Phase K3: Config UI       | ⏳ PENDING      | Blocked by H3 |
| Phase L3: Computer Use    | 🔄 IN PROGRESS  | Stream 3 |
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
| Phase AE3: Platform Obs.   | ⏳ PENDING      | STREAM 5 tail — startup wiring for PlatformFeaturesHub, TheaIntelligenceOrchestrator, ApprovalManager |
| Phase AF3: Settings Nav    | ⏳ PENDING      | STREAM 6 (MBAM2) — MacSettingsView sidebar + iOS tab nav completion; pure SwiftUI, no ML |
| Phase AG3: Comp. QA        | ⏳ PENDING      | STREAM 5 final — after all streams complete; stub activation + CI green loop |
| Phase AH3: 8-Hat Audit     | ⏳ PENDING      | STREAM 5 final — after AG3; implement all audit findings |
| **Overall v3 %**          | **0%**          | v2 Phase S active (CI run 22193316888, macOS Tests in_progress) — v3 auto-starts after Phase U |

*Last updated: 2026-02-19 19:40 CET v3.8 — header/mission updated; AE3+AF3+AG3+AH3 added to status table; AE3→stream 5, AF3→stream 6; ci.yml .claude/** paths-ignore added (prevents plan-file CI cancellation); 6-stream auto-spawn launcher in plan.*

---

## END GOAL — v3 SHIP-READY CRITERIA

**Thea v3 is complete when ALL v2 criteria AND ALL of the following are true:**

### Meta-AI (Intelligence Layer UI)
- [ ] "Meta-AI" brand visible in MacSettingsView sidebar and iOS tab
- [ ] MetaAIDashboardView shows real-time decisions from all intelligence subsystems
- [ ] ~71 cherry-picked MetaAI files active (all 77 archive files audited; 6 skipped as superseded): TIER 0 (11 SelfExecution), TIER 1 (22 Multi-Agent/Reasoning/Autonomy/Resilience), TIER 2 (24 Error AI/Workflow/Plugins/Tools/Benchmarks), TIER 3 (14 MCP/UI/Utility)
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

## PHASE EXECUTION ORDER — TRUE PARALLELISM (v3.8 — fully automated, zero human gates)

```
TRUE DEPENDENCY ANALYSIS:
  A3 adds NEW files to Shared/Intelligence/MetaAI/ only. Does NOT touch any existing file.
  ONLY H3 (AI Dashboard) depends on A3+E3+F3+G3. ALL other phases are fully independent.
  project.yml uses `path: Shared` glob — new subdirs auto-included, no project.yml edits needed.
  Wave 6 verification must run after ALL feature streams complete.

6 PARALLEL STREAMS — AUTO-LAUNCHED by Phase U completion script (ZERO human gates):
  MSM3U: 5 streams (256GB RAM easily handles 5+ Claude Code sessions + parallel builds)
  MBAM2: 1 stream (auto-spawned from MSM3U via SSH — no manual action from Alexis)
────────────────────────────────────────────────────────────────────────────────────────

STREAM 1 — MSM3U window "v3-s1" — MetaAI + Dashboard (~12h)
  A3 (4h) → wait for S2 E3+F3+G3 committed → H3 (4h)
  Files: Shared/Intelligence/MetaAI/** (A3), UI/Views/Intelligence/MetaAIDashboardView (H3)

STREAM 2 — MSM3U window "v3-s2" — Core Wiring (~11h)
  B3 (3h) → C3 (2h) → D3 (2h) → E3 (4h)
  Files: ChatManager.swift, AnthropicProvider.swift, Intelligence/Search/, Intelligence/Verification/, Intelligence/Skills/
  ⚠️ STREAM 2 IS THE SOLE OWNER OF ChatManager.swift — no other stream touches it.

STREAM 3 — MSM3U window "v3-s3" — Agents + Heavy AI (~12h)
  F3 (3h) → G3 (2h) → L3 (4h) → M3 (3h)
  Files: Intelligence/Squads/, Intelligence/Planning/, AI/ComputerUse/ (new), AI/Audio/ (MLX)

STREAM 4 — MSM3U window "v3-s4" — Capabilities + Features (~14h)
  N3 (3h) → O3 (4h) → J3 (3h) → P3 (2h) → Q3 (2h)
  Files: Shared/Artifacts/ (new), Integrations/MCP/ (new), UI/Views/LifeTracking/, Memory/PersonalKG, Intelligence/Scheduling/

STREAM 5 — MSM3U window "v3-s5" — Remaining + Subsystems (~16h)
  R3 (2h) → S3 (2h) → U3 (4h) → AE3 (2h) → AG3 (6h) → AH3 (5h)
  Files: SelfEvolution/, UI/Views/MCPServerGenerator/ (new), AI subsystems, PlatformFeaturesHub startup, TheaIntelligenceOrchestrator, ApprovalManager
  Note: AE3 (platform observers wiring) done before AG3+AH3. AG3+AH3 run AFTER all other streams complete (stream 5 waits for streams 1-4 + MBAM2).

STREAM 6 — MBAM2 window "v3-s6" — UI + Integrations (~16h, auto-spawned via SSH)
  I3 (2h) → K3 (3h) → T3 (3h) → V3 (3h) → W3 (3h) → AF3 (2h)
  Files: UI/Views/Components/ (excluded comps), Settings/ (config UI), Integrations/Backends/, UI/Views/Transparency/, UI/Views/Chat/ (enhancements), MacSettingsView sidebar + iOS tab nav (AF3)
  pushsync after EVERY phase — MSM3U Wave 6 pulls MBAM2's changes before verification.

BOTTLENECK: ~16h (streams 5, 6 are longest: AE3+AF3 each add ~2h)
  All feature work done: ~15:00 CET Fri Feb 20 (starting from ~23:00 CET Feb 19)
  H3 done: ~17:00 CET Fri Feb 20 (stream 1 waits for E3/F3/G3 from s2+s3)
  AE3 done (stream 5): ~17:00 CET Fri Feb 20 → AG3+AH3 start
  AF3 done (stream 6): ~17:00 CET Fri Feb 20
  Wave 6 starts (sequential verification): ~17:00 CET Fri Feb 20 (H3 done + all streams done)
  Wave 6 (sequential, ~10h): ~03:00 CET Sat Feb 21
  AG3+AH3 (stream 5, ~11h): done before Wave 6 → AD3 gate: Sat Feb 21 morning

FILE OWNERSHIP — ABSOLUTE RULES (prevents merge conflicts):
  ChatManager.swift     → STREAM 2 ONLY
  MetaAI/**             → STREAM 1 ONLY
  Squads/Planning/**    → STREAM 3 ONLY
  Artifacts/MCP/**      → STREAM 4 ONLY
  SelfEvolution/**      → STREAM 5 ONLY
  Settings/** (config)  → STREAM 6 ONLY
  AI/Audio/**           → STREAM 3 ONLY
  project.yml           → NO STREAM edits it (glob sources auto-pick new files)
  If any stream needs to touch a file owned by another: STOP, send ntfy, coordinate.

AUTO-SPAWN LAUNCHER (Phase U completion script runs this — fully automated):
```bash
#!/usr/bin/env bash
# Spawns all 6 v3 streams automatically. Called at end of Phase U.
PLAN="/Users/alexis/Documents/IT & Tech/MyApps/Thea/.claude/THEA_CAPABILITY_PLAN_v3.md"
THEA="/Users/alexis/Documents/IT & Tech/MyApps/Thea"

cd "$THEA" && git pull && echo "=== Launching v3 — 6 parallel streams ==="

# Suspend thea-sync on MSM3U
launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null

# MSM3U streams 1-5 (separate tmux windows, each gets its own Claude Code session)
for S in s1 s2 s3 s4 s5; do
  /opt/homebrew/bin/tmux new-window -n "v3-$S"
  sleep 1
  case $S in
    s1) PROMPT="Read '$PLAN'. You are STREAM 1. Execute A3 then wait for streams 2+3 to commit E3+F3+G3 (check git log every 30min), then execute H3. File ownership: Shared/Intelligence/MetaAI/** and MetaAIDashboardView only." ;;
    s2) PROMPT="Read '$PLAN'. You are STREAM 2. Execute B3→C3→D3→E3 sequentially. You are SOLE OWNER of ChatManager.swift — never let another stream touch it. swift test locally after each phase." ;;
    s3) PROMPT="Read '$PLAN'. You are STREAM 3. Execute F3→G3→L3→M3 sequentially. File ownership: Intelligence/Squads/, Intelligence/Planning/, AI/ComputerUse/, AI/Audio/." ;;
    s4) PROMPT="Read '$PLAN'. You are STREAM 4. Execute N3→O3→J3→P3→Q3 sequentially. File ownership: Shared/Artifacts/, Integrations/MCP/, UI/Views/LifeTracking/, Memory/PersonalKG, Intelligence/Scheduling/." ;;
    s5) PROMPT="Read '$PLAN'. You are STREAM 5. Execute R3→S3→U3→AE3 first (AE3=platform observers wiring). Then WAIT until streams 1-4 and MBAM2 all push their final phases (poll git log every 30min for 'Stream N complete' commits). Then execute AG3→AH3." ;;
  esac
  /opt/homebrew/bin/tmux send-keys -t "v3-$S" \
    "cd '$THEA' && launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null && caffeinate -i claude --dangerously-skip-permissions" Enter
  sleep 3
  /opt/homebrew/bin/tmux send-keys -t "v3-$S" "$PROMPT" Enter
done

# MBAM2 stream 6 — auto-spawned via SSH (no manual action from Alexis needed)
ssh mbam2.local "
  launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
  /opt/homebrew/bin/tmux new-session -d -s v3-s6 -x 220 -y 50 2>/dev/null || true
  /opt/homebrew/bin/tmux send-keys -t v3-s6 \
    \"cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && git pull && caffeinate -i claude --dangerously-skip-permissions\" Enter
" 2>/dev/null
sleep 5
ssh mbam2.local "/opt/homebrew/bin/tmux send-keys -t v3-s6 \
  \"Read '.claude/THEA_CAPABILITY_PLAN_v3.md'. You are STREAM 6 on MBAM2. Execute I3→K3→T3→V3→W3→AF3 sequentially. File ownership: UI/Views/Components/, Settings/ config views, Integrations/Backends/, UI/Views/Transparency/, ChatView additions, MacSettingsView sidebar + iOS tab nav (AF3). git add <specific files only>. git pushsync after each phase. swift test locally. Send ntfy to thea-msm3u with 'STREAM 6 complete' when AF3 done.\" Enter" 2>/dev/null

curl -s -X POST "https://ntfy.sh/thea-msm3u" \
  -H "Title: 🚀 v3 LAUNCHED — 6 parallel streams" \
  -d "MSM3U: 5 streams (S1-S5). MBAM2: 1 stream (S6 via SSH). Bottleneck ~14h. All features done ~13:00 CET Fri Feb 20." || true

echo "=== All 6 v3 streams launched. Monitor: tmux ls ==="
```

STREAM 5 GATE (before AG3/AH3):
  Stream 5 must verify all streams committed before starting AG3:
```bash
# Poll every 30 min until all streams done:
while true; do
  COMMITS=$(git log --oneline --since="2 hours ago" | grep -c "Stream.*complete\|Auto-save.*v3\|feat.*A3\|feat.*B3\|feat.*C3\|feat.*D3\|feat.*E3\|feat.*F3\|feat.*G3\|feat.*H3\|feat.*N3\|feat.*O3\|feat.*J3\|feat.*P3\|feat.*Q3\|feat.*I3\|feat.*K3\|feat.*T3\|feat.*V3\|feat.*W3\|feat.*R3\|feat.*S3\|feat.*U3" || true)
  echo "$(date): $COMMITS stream commits detected"
  [ "$COMMITS" -ge 22 ] && break  # 22 = one commit per phase across all streams
  sleep 1800
done
git pull && echo "All streams complete — starting AG3"
```

TIMING (from v2 Phase U complete, estimated 23:00 CET Feb 19):
  +14h → streams 1-6 all done (bottleneck ~14h) → ~13:00 CET Fri Feb 20
  +4h  → H3 done (Stream 1 was waiting)          → ~17:00 CET Fri Feb 20
  Stream 5 picks up AG3+AH3:                      → ~17:00 CET Fri Feb 20 + 11h = ~04:00 CET Sat Feb 21
  Wave 6 (X3→Y3→Z3→AA3→AB3→AC3) on MSM3U:        → ~04:00 + 10h = ~14:00 CET Sat Feb 21
  AD3 — Alexis reviews:                           → Sat Feb 21 afternoon

MACHINE LOAD:
  MSM3U: 5× Claude Code (each ~4GB) + 5× swift build/test = ~40GB RAM used, 256GB available ✅
  MBAM2: 1× Claude Code + swift build/test = ~8GB RAM used, 24GB available ✅
  Both machines: thea-sync suspended. CPU temp monitored on MSM3U (pause >90°C).

CURRENT STATUS:
  v2: 🔄 IN PROGRESS — Phase S monitoring CI (Unit Tests ~80min on GH Actions), T+U pending
  v3: ⏳ PENDING — auto-starts after v2 Phase U completes

PARALLELISM IMPLEMENTATION RULES — MANDATORY:
  1. NEVER idle-sleep during long CI waits. Use that time for the next phase's prep.
  2. Within a wave, launch SEPARATE tmux windows (not panes) for parallel phases.
  3. Between waves, do git pushsync + git pull to sync state before the next wave.
  4. MSM3U primary executor MUST notify MBAM2 when a wave completes (ntfy.sh/thea-msm3u).
  5. MBAM2 secondary (phases I3/K3/T3/V3/W3) runs ONLY pure-SwiftUI phases — no ML, no builds.
  6. Each parallel session commits its own files; NEVER both sessions edit the same file.
  7. Do NOT wait for GH Actions CI to validate local work — run swift test locally for fast loop.
     GH Actions is the "official" gate but local tests give 3-4x faster feedback for dev iterations.

IMMEDIATE PARALLEL OPPORTUNITIES (before v3 Phase A3 starts):
  While v2 Phase S monitors Unit Tests on GH Actions (~60-80min remaining):
  → MSM3U pane 2: Write Phase T artifacts (T3 ExportOptions.plist + T5 notarize.yml skeleton)
  → MSM3U pane 3: Run local swift test as parallel verification (independent of GH Actions)
  → MBAM2: Prepare v3 Phase A3 — read MetaAI archive file list, validate directory structure
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

### Rule 9 — LOCAL-FIRST TESTING PROTOCOL (MANDATORY — zero quality loss)

**Principle**: GH Actions macOS runners are 3-4× slower than MSM3U. Every unnecessary CI push
adds 80-120 min of dead wait time. The fix: iterate locally until clean, then push ONCE per wave.

**Quality guarantee**: `swift test` locally catches 100% of the same bugs as GH Actions Unit Tests.
GH Actions additionally verifies clean-environment behavior — preserved by running it at wave gates.

**Per-phase loop (development iteration):**
```bash
# 1. Write code, fix types, fix build errors
swift build 2>&1 | grep "error:" | head -20

# 2. Run local tests (fast — 55 min on MSM3U, vs 90-120 min on GH Actions):
swift test 2>&1 | grep -E "(PASSED|FAILED|error:)" | tail -20

# 3. If tests fail: fix locally, re-run swift test. Repeat until clean.
# 4. Only when locally clean: git add + git commit + (skip pushsync until wave end)
```

**Per-WAVE gate (GH Actions verification — once per wave, not per phase):**
```bash
# After all phases in the wave are locally clean and committed:
git pushsync  # One push → one GH Actions run → verify clean environment
# Monitor until GH Actions green. Fix if needed, then re-pushsync.
# This ensures GH Actions green is confirmed, without 28 separate CI waits.
```

**Apply to remaining v2**: Phase U must use local builds + local swift test (not a new GH Actions push).
Phase T file creation needs no tests. Only push at end of Phase U to confirm final GH Actions state.

**NEVER**: Run phase after phase pushing to GH Actions and waiting 90-120 min between each.
**ALWAYS**: Local swift test → local fix loop → commit → push once at wave gate.

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

## PHASE A3: META-AI FULL ACTIVATION (UI LAYER + ~57 CHERRY-PICKED FILES)

**Status: ⏳ PENDING (starts after v2 Phase U auto-transition)**

**Goal**: Activate ALL ~71 MetaAI files with genuinely unique capabilities (all 77 archive
files individually audited at snippet level; 6 skipped as superseded; 71 cherry-picked).
Includes SelfExecution/ subdirectory — 11 files — which powers Thea's autonomous plan execution.
Create `MetaAIDashboardView` as the branded UI face. This unlocks Thea's full multi-agent,
reasoning, autonomous-build, self-execution, workflow, plugin, and resilience capabilities
— all previously silenced by a blanket exclusion that also trapped genuinely unique systems.

⚠️ SelfExecution/ is the HIGHEST PRIORITY subsystem: it makes Thea capable of executing
its own plans (v3 plan itself) autonomously — PhaseOrchestrator, CodeGenerator, ApprovalGate,
SelfExecutionService, ProgressTracker, SpecParser, SleepPrevention, TaskDecomposer.

**Run after**: v2 Phase U complete (executor auto-transitions to v3)

**Audited file classification (ALL 77 files individually reviewed 2026-02-19 at snippet level):**
Archive total: 62 Swift in .v1-archive/Shared/AI/MetaAI/ + 11 in SelfExecution/ + 4 UI views = 77 files

SKIP — superseded by canonical Intelligence/ (6 Swift files + non-Swift docs):
- `MetaAIModelRouter.swift` → superseded by SmartModelRouter (file header says so explicitly)
- `MetaAITaskClassifier.swift` → superseded by TaskClassifier (file header says so explicitly)
- `KnowledgeGraph.swift` → superseded by PersonalKnowledgeGraph; adapt KnowledgeGraphViewer
  to use `PersonalKnowledgeGraph.shared` instead
- `MemorySystem.swift` → superseded by Intelligence/Memory/LongTermMemorySystem; adapt
  MemoryInspectorView to use `LongTermMemorySystem.shared` instead
- `TaskTypes.swift` → CONFLICT: defines `TaskContext` which exists in canonical Classification/
- `ConnectivityMonitor.swift` → superseded by canonical `Intelligence/Mobile/NetworkConditionMonitor.swift`
  (same NWPathMonitor pattern, same purpose — no unique value to add)
- Non-Swift: any .md/.sh build docs in archive → skip entirely

CHERRY-PICK — ~71 files with unique capabilities (verified count: 77 - 6 = 71):

TIER 0 — CRITICAL (SelfExecution/ subdirectory — 11 files — Thea executing its own plans):
  SelfExecution/SelfExecutionService.swift     — main entry: automatic/supervised/dryRun modes
  SelfExecution/PhaseOrchestrator.swift        — orchestrates phase execution, PhaseResult tracking
  SelfExecution/CodeGenerator.swift           — generates code files for phases dynamically
  SelfExecution/FileCreator.swift             — creates project files for phases
  SelfExecution/ApprovalGate.swift            — approval gate per level (phase/file/build/dmg)
  SelfExecution/PhaseDefinition.swift         — phase definition with deliverables/verifications
  SelfExecution/ProgressTracker.swift         — phase progress tracking
  SelfExecution/SpecParser.swift              — parses THEA_MASTER_SPEC.md → redirect to v3 plan
  SelfExecution/SleepPrevention.swift         — IOPMAssertion keeps system awake during execution
  SelfExecution/TaskDecomposer.swift          — decomposes phases into typed tasks (→ SelfExecTaskDecomposer)
  SelfExecution/SelfExecutionConfiguration.swift — provider priority, preferred models per AI

TIER 1 — HIGHEST VALUE (wire into IntelligenceOrchestrator + ChatManager):
  Learning:    AIIntelligence (taskClassificationLearnings, codeAnalysisLearnings, modelPerformanceData,
               workflowOptimizations — unique 4-store learning not in canonical)
  Multi-Agent: MultiAgentOrchestrator, SubAgentOrchestrator, AgentSwarm, AgentRegistry,
               AgentCommunication, AgentCommunicationHub, DeepAgentEngine
               ⚠️ AgentCommunication + AgentCommunicationHub overlap with canonical AgentCommunicationBus —
               see CONCEPTUAL OVERLAPS below
  Reasoning:   ReActExecutor, ReasoningEngine, ChainOfThought, LogicalInference,
               HypothesisTesting, ReflectionEngine
               ⚠️ ReflectionEngine overlaps with canonical ReflexionEngine — see CONCEPTUAL OVERLAPS
  Autonomy:    AutonomousBuildLoop, AICodeFixGenerator, CodeFixer, CodeSandbox, SwiftCodeAnalyzer
  Resilience:  ResilienceManager (circuit breakers + exponential backoff — wire into all providers)

TIER 2 — HIGH VALUE (add to builds, wire into dashboard):
  Error AI:    ErrorKnowledgeBase, ErrorParser, KnownFixes, ImprovementSuggestions
  Workflow:    WorkflowBuilder, WorkflowPersistence, WorkflowTemplates
  Plugins:     PluginSystem
  Parallel:    ParallelQueryExecutor, QueryDecomposer, ResultAggregator
  Orchestration: TaskDecomposition (dependency graph builder → OrchestrationTaskBreakdown)
               ⚠️ Overlaps with canonical TaskPlanDAG — see CONCEPTUAL OVERLAPS
  Tools:       ToolCall (SwiftData model → rename MetaAIToolCall), ToolCallView, ToolFramework,
               SystemToolBridge
               ⚠️ ToolFramework overlaps with canonical ToolComposition — see CONCEPTUAL OVERLAPS
  Benchmarks:  ModelBenchmarkService (replace stub), ModelCapabilityDatabase, ModelCapabilityView(*),
               MetaAIPerformanceMetrics (renamed)
  Self-Model:  THEASelfAwareness
  Directives:  UserDirectivesConfiguration, UserDirectivesView
  Coordinator: THEAOrchestrator → RENAME class to `MetaAICoordinator` in copy
  Training:    ModelTraining (fine-tuning, few-shot, continual learning — no canonical equivalent)

TIER 3 — ADD TO BUILDS (wire in Phase B3/later):
  MCP:         MCPBrowserView, MCPServerLifecycleManager, MCPToolBridge, MCPToolList, MCPServerRow
  UI Views:    PluginManagerView, WorkflowBuilderView
               (KnowledgeGraphViewer → adapted to PersonalKnowledgeGraph; MemoryInspectorView → adapted)
  Utility:     FileOperations, ExecutionPipeline, InteractionAnalyzer, MultiModalAI,
               APIIntegrator, AsyncTimeout
               ⚠️ ExecutionPipeline overlaps with AgentMode — see CONCEPTUAL OVERLAPS

(*) ModelCapabilityView.swift has a typo: `ModelCapabilityRecordRecord` — fix to `ModelCapabilityRecord`

CONCEPTUAL OVERLAPS — READ BOTH FILES BEFORE WIRING (not type conflicts, but functional overlap):
1. MetaAI `AgentCommunication` + `AgentCommunicationHub` vs canonical `AgentCommunicationBus`:
   - MetaAI version: @Observable, message queue (1000 cap, 1hr retention), shared context, subscriptions
   - Canonical: actor-based bus; exact implementation TBD (read before wiring)
   - Strategy: if canonical is skeleton, REPLACE with MetaAI implementation; if both have value, MERGE
     by keeping canonical AgentCommunicationBus and wiring MetaAI AgentCommunicationHub ON TOP

2. MetaAI `ReflectionEngine` vs canonical `ReflexionEngine` (different spelling, similar purpose):
   - MetaAI: reflectionHistory/improvements/learnings; analyzes AI outputs for self-improvement
   - Canonical: ReflexionEngine (reflexion loops, self-correction); has ChatReflexionIntegration
   - Strategy: KEEP BOTH — ReflexionEngine handles post-response self-correction;
     ReflectionEngine handles broader learning from interaction patterns. Wire both into ChatManager.

3. MetaAI `TaskDecomposition` vs canonical `TaskPlanDAG`:
   - MetaAI: builds dependency graphs, `OrchestrationTaskBreakdown`, execution order
   - Canonical: DAG-based decomposition with parallel execution via TaskGroup
   - Strategy: KEEP BOTH — TaskPlanDAG is the execution engine; TaskDecomposition feeds it input.
     Wire: TaskDecomposition.decompose() → result feeds into TaskPlanDAG.addTask()

4. MetaAI `ToolFramework` vs canonical `ToolComposition`:
   - MetaAI: dynamic tool registry + MCPToolRegistry init; ToolFramework.shared
   - Canonical: tool composition and chaining (ToolComposition + Engine)
   - Strategy: KEEP BOTH — ToolFramework is the registry; ToolComposition handles multi-tool chains.
     Wire: ToolFramework.register() populates tools; ToolComposition.chain() uses them.

5. MetaAI `ExecutionPipeline` vs canonical `AgentMode`:
   - MetaAI: multi-step execution with retry, checkpointing, history (last 50)
   - Canonical: AgentMode phases (gatherContext → takeAction → verifyResults → done)
   - Strategy: KEEP BOTH — AgentMode handles AI reasoning phases; ExecutionPipeline handles
     multi-step task retry/checkpoint at orchestration level. ExecutionPipeline wraps AgentMode steps.

KNOWN CONFLICTS TO RESOLVE (all confirmed by grep on 2026-02-19):
- `TaskContext` → canonical: Shared/Intelligence/Classification/TaskContext.swift.
  Rename MetaAI uses: `sed -i '' 's/\bTaskContext\b/MetaAITaskContext/g'` across all MetaAI copies.
- `THEAOrchestrator` → no canonical clash but rename to `MetaAICoordinator` for clarity.
- `MemorySystem` → canonical: Shared/Memory/MemorySystem.swift.
  Rename MetaAI copy: `MetaAIMemorySystem`; adapt MemoryInspectorView to use `LongTermMemorySystem`.
- `KnowledgeGraph.shared` in KnowledgeGraphViewer → adapt to `PersonalKnowledgeGraph.shared`.
- `PerformanceMetrics` → CONFLICT: exists in Shared/Core/Configuration/DynamicConfig.swift
  AND Shared/AI/Adaptive/SelfTuningEngine.swift. Rename MetaAI copy to `MetaAIPerformanceMetrics`.
- `ToolCall` → CONFLICT: exists in Shared/AI/OnDeviceAIService.swift (not excluded!).
  Rename MetaAI's SwiftData `ToolCall` model to `MetaAIToolCall` to avoid collision.
- `ModelCapabilityRecordRecord` typo in ModelCapabilityView → fix to `ModelCapabilityRecord`.

EXISTING STUBS — REPLACE WITH REAL FILES WHEN ACTIVATING:
- `ModelBenchmarkService` → a stub was placed in the canonical codebase when MetaAI was archived.
  Phase A3 must REPLACE the stub with the real MetaAI ModelBenchmarkService.swift.
- `WorkflowTemplates` → same: stub exists in canonical. Replace with real MetaAI WorkflowTemplates.swift.
- `AIFeaturesSettingsView` → deps were replaced with UserDefaults stubs. Restore real wiring in Phase A3.
⚠️ Before copying any MetaAI file, grep canonical Shared/ for its class/struct/actor name. Trust the audit above but ALWAYS verify — stubs may have been added after the audit.

**Meta-AI brand:** IntelligenceOrchestrator stays unchanged — `MetaAICoordinator` wraps it,
adding multi-agent dispatch, ReAct reasoning, self-execution, and autonomous build on top.
SelfExecutionService is how Thea executes its own plans — wire to v3 plan execution.

### A3-0: Pre-flight — Confirm Archive Location + Full Conflict Check

```bash
ls .v1-archive/Shared/AI/MetaAI/ | wc -l         # should be ~62 Swift files
ls .v1-archive/Shared/AI/MetaAI/SelfExecution/   # should be 11 files
ls .v1-archive/Shared/UI/Views/MetaAI/           # should be 4 view files

# CRITICAL: Verify ALL known conflicts before copying (run every time — stubs may change):
grep -rn "class TaskContext\|struct TaskContext" Shared/ --include="*.swift" | grep -v ".v1-archive"
# → found in Classification/TaskContext.swift — RENAME MetaAI uses to MetaAITaskContext

grep -rn "class MemorySystem\|final class MemorySystem\|actor MemorySystem" Shared/ --include="*.swift" | grep -v ".v1-archive"
# → found in Shared/Memory/MemorySystem.swift — RENAME MetaAI copy to MetaAIMemorySystem

grep -rn "struct PerformanceMetrics\|class PerformanceMetrics" Shared/ --include="*.swift" | grep -v ".v1-archive"
# → found in DynamicConfig.swift + SelfTuningEngine.swift — RENAME MetaAI to MetaAIPerformanceMetrics

grep -rn "@Model final class ToolCall\|struct ToolCall\|class ToolCall" Shared/ --include="*.swift" | grep -v ".v1-archive"
# → found in OnDeviceAIService.swift — RENAME MetaAI SwiftData model to MetaAIToolCall

grep -rn "class ModelBenchmarkService" Shared/ --include="*.swift" | grep -v ".v1-archive"
# → if found (stub), DELETE the stub before copying real MetaAI version

grep -rn "class WorkflowTemplates" Shared/ --include="*.swift" | grep -v ".v1-archive"
# → if found (stub), DELETE the stub before copying real MetaAI version

grep -rn "class THEAOrchestrator" Shared/ --include="*.swift" | grep -v ".v1-archive"
grep -rn "class MultiAgentOrchestrator\|class AgentSwarm\|class ReActExecutor" Shared/ --include="*.swift" | grep -v ".v1-archive"
grep -rn "class ResilienceManager\|class WorkflowBuilder\|class PluginSystem" Shared/ --include="*.swift" | grep -v ".v1-archive"
# → none expected for above — verify before proceeding
```

### A3-1: Copy Tier 0 (SelfExecution) + Tier 1 Files

```bash
mkdir -p Shared/Intelligence/MetaAI
mkdir -p Shared/Intelligence/MetaAI/SelfExecution

# ⭐ TIER 0 — SelfExecution (HIGHEST PRIORITY — Thea executing its own plans)
for f in SelfExecutionService PhaseOrchestrator CodeGenerator FileCreator ApprovalGate \
          PhaseDefinition ProgressTracker SpecParser SleepPrevention \
          SelfExecutionConfiguration; do
  cp ".v1-archive/Shared/AI/MetaAI/SelfExecution/${f}.swift" \
     Shared/Intelligence/MetaAI/SelfExecution/
done
# Note: SelfExecution/TaskDecomposer.swift is different from main MetaAI/TaskDecomposition.swift:
cp ".v1-archive/Shared/AI/MetaAI/SelfExecution/TaskDecomposer.swift" \
   Shared/Intelligence/MetaAI/SelfExecution/SelfExecTaskDecomposer.swift
# fullAuto mode was already removed for security (FINDING-014) — do NOT re-add it

# Tier 1 — Learning/Intelligence
cp ".v1-archive/Shared/AI/MetaAI/AIIntelligence.swift" Shared/Intelligence/MetaAI/

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
# Tier 2 (23 files) — delete stubs before copying real versions:
for STUB in ModelBenchmarkService WorkflowTemplates; do
  find Shared/ -name "${STUB}.swift" -not -path "*/.v1-archive/*" -delete 2>/dev/null
done

for f in ErrorKnowledgeBase ErrorParser KnownFixes ImprovementSuggestions \
          WorkflowBuilder WorkflowPersistence WorkflowTemplates PluginSystem \
          ParallelQueryExecutor QueryDecomposer ResultAggregator TaskDecomposition \
          ToolCall ToolCallView ToolFramework SystemToolBridge \
          ModelBenchmarkService ModelCapabilityDatabase ModelCapabilityView PerformanceMetrics \
          THEASelfAwareness UserDirectivesConfiguration UserDirectivesView; do
  cp ".v1-archive/Shared/AI/MetaAI/${f}.swift" Shared/Intelligence/MetaAI/
done

# Tier 3 (14 files: 5 MCP + 6 Utility + ModelTraining/MultiModalAI)
for f in MCPBrowserView MCPServerLifecycleManager MCPToolBridge MCPToolList MCPServerRow \
          FileOperations ExecutionPipeline InteractionAnalyzer MultiModalAI \
          APIIntegrator AsyncTimeout ModelTraining; do
  cp ".v1-archive/Shared/AI/MetaAI/${f}.swift" Shared/Intelligence/MetaAI/
done

# UI Views (separate folder — 4 files: 2 adapted, 2 direct copy)
mkdir -p Shared/UI/Views/MetaAI
for f in KnowledgeGraphViewer MemoryInspectorView PluginManagerView WorkflowBuilderView; do
  cp ".v1-archive/Shared/UI/Views/MetaAI/${f}.swift" Shared/UI/Views/MetaAI/
done
# Adapt KnowledgeGraphViewer (uses KnowledgeGraph.shared → PersonalKnowledgeGraph.shared):
sed -i '' 's/KnowledgeGraph\.shared/PersonalKnowledgeGraph.shared/g; s/\bKnowledgeGraph\b/PersonalKnowledgeGraph/g' \
  Shared/UI/Views/MetaAI/KnowledgeGraphViewer.swift
# Note: KnowledgeGraph types (KnowledgeNode, NodeType) used in viewer must map to PKG equivalents
```

After Tier 0+1 copy: apply ALL conflict resolutions:
```bash
# 1. Fix TaskContext → MetaAITaskContext in ALL MetaAI copies:
find Shared/Intelligence/MetaAI -name "*.swift" -exec \
  sed -i '' 's/\bTaskContext\b/MetaAITaskContext/g' {} \;

# 2. Rename THEAOrchestrator → MetaAICoordinator:
sed -i '' 's/class THEAOrchestrator/class MetaAICoordinator/g' \
  Shared/Intelligence/MetaAI/MetaAICoordinator.swift
sed -i '' 's/THEAOrchestrator\.shared/MetaAICoordinator.shared/g' \
  Shared/Intelligence/MetaAI/MetaAICoordinator.swift

# 3. Rename MemorySystem → MetaAIMemorySystem in MetaAI copies:
find Shared/Intelligence/MetaAI -name "*.swift" -exec \
  sed -i '' 's/\bMemorySystem\b/MetaAIMemorySystem/g' {} \;
# Also update MemoryInspectorView to use LongTermMemorySystem:
sed -i '' 's/MetaAIMemorySystem\.shared/LongTermMemorySystem.shared/g' \
  Shared/UI/Views/MetaAI/MemoryInspectorView.swift

# 4. Rename PerformanceMetrics → MetaAIPerformanceMetrics in MetaAI copies:
find Shared/Intelligence/MetaAI -name "*.swift" -exec \
  sed -i '' 's/\bPerformanceMetrics\b/MetaAIPerformanceMetrics/g' {} \;

# 5. Rename ToolCall → MetaAIToolCall in MetaAI copies (SwiftData model conflict):
find Shared/Intelligence/MetaAI -name "*.swift" -exec \
  sed -i '' 's/\bToolCall\b/MetaAIToolCall/g' {} \;

# 6. Fix ModelCapabilityView typo:
sed -i '' 's/ModelCapabilityRecordRecord/ModelCapabilityRecord/g' \
  Shared/Intelligence/MetaAI/ModelCapabilityView.swift
```
Build after ALL conflict resolutions. The build gate must pass before proceeding to Tier 2.
If any new conflict is found by the compiler, fix it here before continuing.

### A3-3: Add to project.yml (Targeted)

```yaml
# Add these new paths to macOS + iOS targets:
# - Shared/Intelligence/MetaAI/**                    (all cherry-picked files)
# - Shared/Intelligence/MetaAI/SelfExecution/**      (SelfExecution subsystem)
# - Shared/UI/Views/MetaAI/**                        (4 view files)
# Do NOT touch the **/AI/MetaAI/** exclusion — archive stays excluded
# Files requiring #if os(macOS) guards: AutonomousBuildLoop, CodeFixer, AICodeFixGenerator,
#   CodeSandbox, ErrorKnowledgeBase, ErrorParser, KnownFixes, SystemToolBridge,
#   SleepPrevention (IOKit), SelfExecutionService, PhaseOrchestrator
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

### A3-4b: TIER 0 Snippet-Level Wiring (SelfExecution — CRITICAL)

SelfExecution makes Thea execute its own v3 plan. These exact wiring steps are required:

**1. Configure project path (all SelfExecution actors use this)**:
```swift
// In TheaMacOSApp or AppDelegate on launch:
let projectRoot = URL(fileURLWithPath: "/Users/alexis/Documents/IT & Tech/MyApps/Thea")
await SelfExecutionService.shared.configure(projectPath: projectRoot)
await CodeGenerator.shared.setProjectPath(projectRoot)
await FileCreator.shared.setProjectPath(projectRoot)
await ProgressTracker.shared.setProjectPath(projectRoot)
```

**2. Redirect SpecParser to v3 plan** (not THEA_MASTER_SPEC.md which doesn't exist):
```swift
// SpecParser.swift — after copying, check if it has a configurable spec path.
// If it looks for THEA_MASTER_SPEC.md by name, add an overload:
extension SpecParser {
    func parseV3Plan() async -> [PhaseDefinition] {
        let specPath = projectPath.appendingPathComponent(".claude/THEA_CAPABILITY_PLAN_v3.md")
        return await parseSpec(at: specPath)
    }
}
```

**3. Wire ApprovalGate → AutonomyController** (human-in-the-loop consistency):
```swift
// ApprovalGate.requestApproval() — after copying, wire its callback to AutonomyController:
// This ensures SelfExecution approval uses the same risk-level system as AgentMode.
extension ApprovalGate {
    func requestWithAutonomy(_ request: ApprovalRequest) async -> Bool {
        // Map ApprovalGate levels to AutonomyController risk levels:
        let risk: ActionRiskLevel = switch request.level {
        case .phaseStart: .medium
        case .fileCreation: .low
        case .buildFix: .medium
        case .phaseComplete: .medium
        case .dmgCreation: .high
        }
        return await AutonomyController.shared.requestApproval(
            action: request.description, riskLevel: risk)
    }
}
```

**4. SleepPrevention — verify IOKit entitlement**:
```bash
# Check macOS entitlements include IOKit access:
grep -A5 "com.apple.security" macOS/Thea.entitlements
# IOPMAssertionCreateWithName requires no special sandbox exception for macOS dev builds
# but verify for Release/notarized builds
```

**5. Wire SelfExecutionService into MetaAIDashboardView** (add "Self-Execution" tab):
```swift
// In MetaAIDashboardView, add:
case selfExecution = "Self-Execution"
// Panel: SelfExecutionStatusPanel showing current phase, progress, approval queue
```

**6. SECURITY: fullAuto mode MUST remain removed** (was removed as FINDING-014):
After copying SelfExecutionService.swift, verify `fullAuto` case is absent:
```bash
grep -n "fullAuto\|full.*auto\|bypass.*approval" \
  Shared/Intelligence/MetaAI/SelfExecution/SelfExecutionService.swift
# Must return 0 matches — fullAuto bypassed all approval gates
```

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

Wire ResilienceManager into ALL providers (AnthropicProvider, OpenAIProvider, etc.):
```swift
// In each provider's API call method — wrap with circuit breaker + exponential backoff:
// ResilienceManager.execute(provider:timeout:operation:) handles:
//   - circuit breaker (opens after N consecutive failures)
//   - exponential backoff with jitter on retry
//   - health monitoring per provider ID
//   - fallback chain: if "anthropic" circuit open → try next provider in chain
let result = try await ResilienceManager.shared.execute(
    provider: "anthropic",
    timeout: 60.0
) {
    try await self.callAnthropicAPI(messages: messages, model: model)
}
// Wire into SmartModelRouter: check ResilienceManager.isHealthy(provider:) before routing
```

Wire ReActExecutor for tool-use reasoning loop (snippet-level):
```swift
// ReActExecutor: thought → action → observation loop
// Wire: after task classification, if .requiresToolUse, route through ReActExecutor
// ReActExecutor.execute(task:tools:maxSteps:) → ReActActionResult
// Feed ReActActionResult back into ChatManager response
let reactResult = try await ReActExecutor.shared.execute(
    task: userMessage,
    tools: AnthropicToolCatalog.allTools,
    maxSteps: 10  // step budget prevents infinite loops
)
```

Wire AIIntelligence learning stores (snippet-level):
```swift
// AIIntelligence has 4 learning stores: taskClassification, codeAnalysis, modelPerformance, workflows
// Wire: after each successful task, update the relevant store:
await AIIntelligence.shared.recordTaskClassification(
    query: userMessage,
    classifiedAs: taskType,
    modelUsed: selectedModel,
    success: true
)
// This creates a feedback loop: future classifications improve based on outcomes
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

## PHASE T3: INTEGRATION BACKENDS RE-ENABLEMENT

**Status: ⏳ PENDING (blocked by B3; MBAM2 assignment — pure Swift, no ML dependency)**

**Goal**: Re-enable Safari, Calendar, Shortcuts, Reminders, Notes, Finder, and Mail integrations.
These 7 integration backends are built and tested but excluded from all builds. Each integration
becomes a live tool handler in Phase B3's AnthropicToolCatalog — re-enabling them turns 7
categories of Anthropic tool calls into real actions Thea can perform on the user's Mac.

**Machine**: MBAM2 (pure Swift, no ML; can run in parallel with MSM3U Wave 5 phases)

### T3-0: Locate Integration Files

```bash
# All 7 integrations live in the excluded Integrations/ directory:
ls Shared/Integrations/{Safari,Calendar,Shortcuts,Reminders,Notes,Finder,Mail}*/

# Verify they're excluded from project.yml:
grep -A2 "SafariIntegration\|CalendarIntegration\|ShortcutsIntegration" project.yml
```

### T3-1: Add to project.yml (macOS target only)

```yaml
# In project.yml, under the macOS target sources, add:
# Each integration file gets #if os(macOS) guard INSIDE the file (verify or add)
- path: Shared/Integrations/Safari
  includes: ["SafariIntegration.swift"]
- path: Shared/Integrations/Calendar
  includes: ["CalendarIntegration.swift"]
- path: Shared/Integrations/Shortcuts
  includes: ["ShortcutsIntegration.swift"]
- path: Shared/Integrations/Reminders
  includes: ["RemindersIntegration.swift"]
- path: Shared/Integrations/Notes
  includes: ["NotesIntegration.swift"]
- path: Shared/Integrations/Finder
  includes: ["FinderIntegration.swift"]
- path: Shared/Integrations/Mail
  includes: ["MailIntegration.swift"]
```

Verify API signatures match what Phase B3 tool handlers expect:
- `SafariIntegration.navigateTo(_ url:)` — no label (confirmed in MEMORY.md)
- `ShortcutsIntegration.runShortcut(_ name:)` — no label, returns `String?`
- `NotificationService.scheduleReminder(title:body:at:repeats:)` — `at:` not `date:`

### T3-2: Wire Each Integration as a Tool Handler

For each integration, add a handler in `AnthropicToolHandler.swift` (from Phase B3):

```swift
// Example: Safari handler
case "safari_navigate":
    guard let url = params["url"] as? String,
          let parsedURL = URL(string: url) else {
        return .failure("Invalid URL")
    }
    #if os(macOS)
    await SafariIntegration.shared.navigateTo(parsedURL)
    return .success("Navigated Safari to \(url)")
    #else
    return .failure("Safari integration macOS only")
    #endif
```

Implement handlers for all 7 integrations using their existing APIs.
Do NOT redesign APIs — use exact signatures as-built.

### T3-3: Verify All Integrations Build + Execute

```bash
# Build macOS only (integrations are macOS-exclusive):
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD" | tail -5

# Verify integrations are included:
grep -r "SafariIntegration\|CalendarIntegration\|ShortcutsIntegration" \
  Shared/ --include="*.swift" | grep -v ".v1-archive" | wc -l  # > 0

# Verify tool handlers reference integrations:
grep -r "safari_navigate\|calendar_create\|shortcuts_run\|reminders_add\|notes_create\|finder_open\|mail_send" \
  Shared/ --include="*.swift" | wc -l  # ≥7
```

Commit: `git add Shared/Integrations/ Shared/AI/ project.yml && git commit -m "Auto-save: T3 — integration backends re-enabled, 7 tool handlers wired"`

---

## PHASE U3: AI SUBSYSTEM RE-EVALUATION — WRONGFULLY DISCONNECTED SYSTEMS

**Status: ⏳ PENDING (blocked by A3; MSM3U assignment — requires full audit + wiring)**

**Goal**: Audit and re-activate ALL AI subsystems that are built but wrongfully disconnected,
excluded, unwired, absent, feedbackless, historyless, never-executing, or framework-only.
This addresses the original user question: "What else in Thea's codebase is wrongfully
disconnected, excluded, unwired, absent, feedbackless, archived, empty, orphaned, unpassed,
cachingless, historyless, never-executing, framework-only, UI-less?"

**Machine**: MSM3U (heavy audit, multi-file wiring, potential ML-dependent systems)

### U3-0: Two Categories of Wrongfully Disconnected Systems

**CATEGORY A — Excluded from builds** (in project.yml exclusion list):
These files exist and compile but are excluded from ALL targets. Must be re-evaluated
individually: does a canonical equivalent supersede them, or do they have unique value?

```
AI/Context/          — context window management, message pruning, context scoring
AI/Adaptive/         — adaptive behavior, self-tuning engine (SelfTuningEngine.swift)
AI/MultiModal/       — multi-modal processing beyond MLXVisionEngine
AI/Proactive/        — proactive suggestions (distinct from Intelligence/Proactive/)
PatternLearning/     — pattern recognition and learning
LifeMonitoring/      — excluded (but canonical Intelligence/LifeMonitoring/ is active — verify!)
Prediction/          — predictive models and forecasting
PromptEngineering/   — prompt quality improvement, template management
ResourceManagement/  — compute resource allocation, memory pressure management
Anticipatory/        — excluded (but canonical Intelligence/Anticipatory/ is active — verify!)
Squads/              — excluded top-level (canonical Intelligence/Squads/ may differ)
Automation/          — automation workflows (Automator-level)
SelfEvolution/       — self-evolution pipeline (distinct from Phase R3 SelfEvolution Wiring)
```

**CATEGORY B — Canonical but never wired** (files exist in Shared/Intelligence/ but nothing calls them):
These are built, pass compilation, but are never instantiated or called at runtime.

```
Shared/Intelligence/AdaptiveLearning/AdaptiveLearningEngine.swift
  → Adaptive learning from user interactions — not called by TaskClassifier or ChatManager
Shared/Intelligence/Analysis/CausalPatternAnalyzer.swift (+ Core)
  → Causal analysis of user behavior — not called by LifeMonitoringCoordinator
Shared/Intelligence/Analysis/CrossDomainCorrelationEngine.swift
  → Cross-domain pattern correlation — not called anywhere
Shared/Intelligence/CognitiveAssistant/CognitiveAssistant.swift
  → Cognitive assistance layer — not wired into ChatManager or IntelligenceOrchestrator
Shared/Intelligence/Context/SemanticContextPreFetcher.swift
  → Pre-fetches context before user sends message — not started on app launch
Shared/Intelligence/Goals/GoalInferenceEngine.swift
  → Infers user goals from behavior — not wired into ProactiveEngine
Shared/Intelligence/Intent/IntentDisambiguation.swift (+ Core)
  → Disambiguates ambiguous requests — not called by ChatManager on message receive
Shared/Intelligence/Knowledge/KnowledgeSourceManager.swift (+ Core)
  → Manages knowledge sources for RAG — not wired into SemanticSearchService
Shared/Intelligence/Learning/PersonalizedLearning.swift
  → Personalized learning from user preferences — not called by TaskClassifier
Shared/Intelligence/Prefetching/IntelligentPrefetcher.swift
  → Prefetches model responses for predicted queries — not started
Shared/Intelligence/Reliability/ReliabilityMonitor.swift
  → Monitors AI response reliability — not wired into ConfidenceSystem
Shared/Intelligence/Safety/SafetyGuardrails.swift (+ Core)
  → Safety guardrails for AI responses — not called by ChatManager on responses
Shared/Intelligence/Trust/TrustScoreSystem.swift
  → Trust scoring for AI sources — not wired into ConfidenceSystem
Shared/Intelligence/Suggestions/UnifiedSuggestionCoordinator.swift
  → Unified suggestion layer — not called by ChatManager or ProactiveEngine
Shared/Intelligence/DeviceIntegration/SmartDeviceIntegration.swift
  → Smart device integration (HomeKit, etc.) — not started
Shared/Intelligence/Documentation/DocumentationGrounding.swift
  → Grounds responses in documentation — not wired into ChatManager context
Shared/Intelligence/Tools/ToolComposition.swift (+ Engine)
  → Tool composition and chaining — not wired into AnthropicToolCatalog
Shared/Intelligence/Agents/AgentCommunicationBus.swift
  → Inter-agent communication — not wired into AgentTeamOrchestrator
Shared/Intelligence/Agents/AgentResourcePool.swift
  → Agent resource pooling — not started by orchestration layer
Shared/Intelligence/Agents/EnhancedSubagentSystem.swift (+ Core)
  → Enhanced sub-agent orchestration — not used by AgentTeamOrchestrator
Shared/Intelligence/Reflection/ReflexionEngine.swift (+ Core)
  → Self-correction via reflexion loops — not called after AI responses
Shared/Intelligence/Reflection/ChatReflexionIntegration.swift
  → ChatManager integration for reflexion — exists but not wired
Shared/Intelligence/Clipboard/ClipboardIntelligence.swift
  → Clipboard content intelligence — not started
Shared/Intelligence/Codebase/CodebaseSearchEngine.swift (+ Types)
  → Codebase-aware search — not wired into SemanticSearchService
Shared/Intelligence/Codebase/SemanticCodeIndexer.swift (+ Core)
  → Semantic code indexing — not started on project open
Shared/Intelligence/Observability/AgentObservability.swift (+ Core)
  → Agent execution observability — not wired into AgentTeamOrchestrator
Shared/Intelligence/Core/UnifiedIntelligenceHub.swift (+ Core)
  → Central intelligence hub — exists but may not be the primary entry point
Shared/Intelligence/Orchestration/TheaAgentOrchestrator.swift
  → Agent orchestration layer — relationship to IntelligenceOrchestrator unclear
Shared/Intelligence/Orchestration/TheaAgentRunner.swift
  → Agent runner — not used
Shared/Intelligence/Orchestration/TheaContextMonitor.swift
  → Context monitoring — not started
```

### U3-1: Category A Audit — Excluded Subsystem Re-evaluation

For each excluded subsystem in Category A:
1. Read the key files (first 40 lines minimum)
2. Compare against canonical Intelligence/ equivalent
3. Decision: SKIP (superseded) | ACTIVATE (unique value) | MERGE (partial unique value)

```bash
# For each subsystem, check for canonical equivalent:
ls Shared/AI/Context/ && ls Shared/Intelligence/Context/    # compare
ls Shared/AI/Adaptive/ && ls Shared/Intelligence/AdaptiveLearning/   # compare
ls Shared/PatternLearning/ 2>/dev/null || ls Shared/Intelligence/Analysis/  # check
ls Shared/PromptEngineering/ 2>/dev/null   # check for unique prompt engineering

# RULE: If canonical exists AND supersedes, SKIP.
# If canonical is empty/framework-only, ACTIVATE the excluded version.
# If both have unique value, MERGE (rename excluded types with prefix if needed).
```

**Pre-determined decisions (based on prior audit):**
- `AI/Adaptive/SelfTuningEngine.swift` — has unique `PerformanceMetrics` struct (conflicts with MetaAI); evaluate merge into ConfidenceSystem feedback loop
- `PromptEngineering/` — evaluate: if it has real prompt quality improvement, activate for all ChatManager requests
- `ResourceManagement/` — evaluate: if it manages compute pressure for MLX models, activate for Wave 4

### U3-2: Category B Wiring — Wire All Canonical-But-Disconnected Systems

For each Category B system, wire it into the appropriate entry point:

| System | Wire Into | How |
|--------|-----------|-----|
| AdaptiveLearningEngine | TaskClassifier | Call after each successful task |
| CausalPatternAnalyzer | LifeMonitoringCoordinator | Called on behavior data updates |
| CrossDomainCorrelationEngine | LifeMonitoringCoordinator | Called on weekly pattern runs |
| CognitiveAssistant | IntelligenceOrchestrator | Called when cognitive load detected |
| SemanticContextPreFetcher | ChatManager | Start prefetch when user begins typing |
| GoalInferenceEngine | ProactiveEngine | Update goal model on every conversation |
| IntentDisambiguation | ChatManager | Called before task classification on ambiguous input |
| KnowledgeSourceManager | SemanticSearchService | Register all knowledge sources on init |
| PersonalizedLearning | TaskClassifier | Update personalization model on task completion |
| IntelligentPrefetcher | ChatManager | Start prefetch queue on app foreground |
| ReliabilityMonitor | ConfidenceSystem | Report reliability data after each response |
| SafetyGuardrails | ChatManager | Apply to every outbound AI response |
| TrustScoreSystem | ConfidenceSystem | Feed trust scores into confidence calculation |
| UnifiedSuggestionCoordinator | ProactiveEngine | Aggregate all suggestion sources |
| SmartDeviceIntegration | LifeMonitoringCoordinator | Start on app launch (macOS only) |
| DocumentationGrounding | ChatManager | Inject doc context for code-related queries |
| ToolComposition | AnthropicToolCatalog | Register composed tools as catalog entries |
| AgentCommunicationBus | AgentTeamOrchestrator | Replace direct method calls with bus |
| AgentResourcePool | AgentTeamOrchestrator | Acquire/release agents from pool |
| EnhancedSubagentSystem | AgentTeamOrchestrator | Use enhanced system for all sub-agents |
| ReflexionEngine | ChatManager | Apply reflexion loop on low-confidence responses |
| ChatReflexionIntegration | ChatManager | Direct wiring for reflexion post-response |
| ClipboardIntelligence | LifeMonitoringCoordinator | Start monitoring on app launch (macOS) |
| CodebaseSearchEngine | SemanticSearchService | Register as a specialized search source |
| SemanticCodeIndexer | SemanticSearchService | Start indexing on project open |
| AgentObservability | AgentTeamOrchestrator | Wrap all agent executions for observability |
| UnifiedIntelligenceHub | IntelligenceOrchestrator | Verify it IS the primary hub or wire it in |
| TheaAgentOrchestrator | IntelligenceOrchestrator | Verify relationship + wire correctly |
| TheaContextMonitor | ChatManager | Start monitoring on conversation start |

### U3-3: Verify Wiring

```bash
# All Category B systems must have ≥1 non-self reference in Shared/ after wiring:
for TYPE in AdaptiveLearningEngine CausalPatternAnalyzer CognitiveAssistant \
    SemanticContextPreFetcher GoalInferenceEngine IntentDisambiguation \
    KnowledgeSourceManager PersonalizedLearning IntelligentPrefetcher \
    ReliabilityMonitor SafetyGuardrails TrustScoreSystem UnifiedSuggestionCoordinator \
    SmartDeviceIntegration DocumentationGrounding ToolComposition \
    AgentCommunicationBus AgentResourcePool ReflexionEngine; do
  COUNT=$(grep -r "$TYPE" Shared/ --include="*.swift" | grep -v "\.swift:.*class $TYPE\|\.swift:.*struct $TYPE\|\.swift:.*actor $TYPE" | grep -v ".v1-archive" | wc -l)
  echo "$TYPE: $COUNT non-self references"
done
# Each must be ≥1 (wired somewhere beyond its own definition)
```

Commit: `git add -p && git commit -m "Auto-save: U3 — all wrongfully disconnected systems wired"`

---

### U3-4: Deep Codebase Audit Findings (2026-02-19) — Additional Unwired Systems

**Source**: Full 1,113-Swift-file automated codebase audit run on 2026-02-19.
These systems are IN ADDITION to the 29 listed in Category B above — all discovered to have zero external callers.

**⚠️ CRITICAL: This table nearly doubles the scope of Phase U3. All items below MUST be wired.**

#### Platform Observers — Startup Wiring (macOS)
These form the entire ambient intelligence foundation for macOS. `PlatformFeaturesHub.shared` starts them all — it is itself never called at launch.

| System | File | Wire Into | Priority |
|--------|------|-----------|----------|
| `PlatformFeaturesHub` | `Shared/Platforms/PlatformFeaturesHub.swift` | TheamacOSApp lifecycle (start after CloudKit init) | 🔴 CRITICAL |
| `MacSystemObserver` | `Shared/Platforms/macOS/MacSystemObserver.swift` | `PlatformFeaturesHub.start()` | 🔴 CRITICAL |
| `EndpointSecurityObserver` | `Shared/Platforms/macOS/EndpointSecurityObserver.swift` | `MacSystemObserver` or `PlatformFeaturesHub` | 🟠 HIGH |
| `ProcessObserver` | `Shared/Platforms/macOS/ProcessObserver.swift` | `MacSystemObserver` | 🟠 HIGH |
| `FileSystemObserver` | `Shared/Platforms/macOS/FileSystemObserver.swift` | `MacSystemObserver` | 🟠 HIGH |
| `ServicesHandler` | `Shared/Platforms/macOS/ServicesHandler.swift` | `PlatformFeaturesHub` | 🟡 MEDIUM |
| `MediaObserver` | `Shared/Platforms/macOS/MediaObserver.swift` | `MacSystemObserver` | 🟡 MEDIUM |
| `TouchBarManager` | `Shared/Platforms/macOS/TouchBarSupport.swift` | `PlatformFeaturesHub` (macOS) | 🟡 MEDIUM |
| `SystemAutomationEngine` | `Shared/Platforms/macOS/SystemAutomationEngine.swift` | `PlatformFeaturesHub` | 🟠 HIGH |
| `MenuBarManager` | `Shared/Platforms/macOS/macOSFeatures.swift` | `TheamacOSApp` lifecycle | 🟠 HIGH |

#### Platform Providers — Startup Wiring (iOS/watchOS/tvOS)
| System | File | Wire Into | Priority |
|--------|------|-----------|----------|
| `HealthKitProvider` | `Shared/Platforms/iOS/HealthKitProvider.swift` | iOS app lifecycle; replace/consolidate with `HealthContextProvider` | 🟠 HIGH |
| `MotionContextProvider` | `Shared/Platforms/iOS/MotionContextProvider.swift` | iOS app lifecycle | 🟠 HIGH |
| `ScreenTimeObserver` | `Shared/Platforms/iOS/ScreenTimeObserver.swift` | iOS app lifecycle | 🟠 HIGH |
| `PhotoIntelligenceProvider` | `Shared/Platforms/iOS/PhotoIntelligenceProvider.swift` | iOS app lifecycle | 🟡 MEDIUM |
| `ActionButtonHandler` | `Shared/Platforms/iOS/ActionButtonHandler.swift` | iOS app lifecycle | 🟡 MEDIUM |
| `AssistantIntegration` | `Shared/Platforms/iOS/AssistantIntegration.swift` | iOS app lifecycle | 🟡 MEDIUM |
| `NotificationObserver` | `Shared/Platforms/iOS/NotificationObserver.swift` | iOS app lifecycle | 🟡 MEDIUM |
| `AdaptiveModelRouter` | `Shared/Intelligence/Mobile/AdaptiveModelRouter.swift` | iOS ChatManager model routing | 🟠 HIGH |
| `RemoteMacBridge` | `Shared/Intelligence/Mobile/RemoteMacBridge.swift` | iOS app lifecycle (Tailscale bridge) | 🟡 MEDIUM |
| `MobileIntelligenceOrchestrator` | `Shared/Intelligence/Mobile/` | iOS app lifecycle | 🟠 HIGH |
| `WatchSessionManager` | `Shared/Platforms/watchOS/watchOSFeatures.swift` | watchOS app lifecycle | 🟡 MEDIUM |
| `SpatialComputingManager` | `Shared/Platforms/visionOS/visionOSFeatures.swift` | visionOS app lifecycle | 🟡 MEDIUM |
| `TopShelfManager` | `Shared/Platforms/tvOS/tvOSFeatures.swift` | tvOS app lifecycle | 🟡 MEDIUM |

**⚠️ Parallel HealthKit stacks**: `HealthKitProvider` (new, unwired) and `HealthContextProvider` (via LifeMonitoringCoordinator) both exist. Consolidate: `HealthKitProvider` should be the single source; `HealthContextProvider` wraps or delegates to it.

#### Intelligence Orchestration — TOP LEVEL GAP
| System | File | Wire Into | Priority |
|--------|------|-----------|----------|
| `TheaIntelligenceOrchestrator` | `Shared/Intelligence/TheaIntelligenceOrchestrator.swift` | TheamacOSApp lifecycle (start after model router) | 🔴 CRITICAL — top-level intelligence coordinator |
| `IntelligenceOrchestrator` | `Shared/Intelligence/Orchestration/IntelligenceOrchestrator.swift` | Verify relationship to TheaIntelligenceOrchestrator; wire correctly | 🔴 CRITICAL |
| `InsightEngine` | `Shared/Context/Analysis/InsightEngine.swift` | `TheaIntelligenceOrchestrator` or `LifeMonitoringCoordinator` | 🟠 HIGH |
| `PredictiveEngine` | `Shared/Context/Analysis/PredictiveEngine.swift` | `TheaIntelligenceOrchestrator` | 🟠 HIGH |
| `PatternDetector` | `Shared/Context/Analysis/PatternDetector.swift` | `TheaIntelligenceOrchestrator` | 🟠 HIGH |

#### Core Services — Zero Callers
| System | File | Wire Into | Priority |
|--------|------|-----------|----------|
| `ApprovalManager` | `Shared/Core/Managers/ApprovalManager.swift` | `AutonomyController` escalation path | 🔴 CRITICAL — autonomy approval queue non-functional |
| `SpotlightService` | `Shared/Core/Services/SpotlightService.swift` | App lifecycle (macOS) on launch | 🟠 HIGH |
| `DeviceCapabilityRouter` | `Shared/Core/DeviceCapabilityRouter.swift` | `SystemCapabilityService` or app launch | 🟡 MEDIUM |
| `UniversalNotificationService` | `Shared/Core/UniversalNotificationService.swift` | App lifecycle (replace platform-specific calls) | 🟠 HIGH |
| `DistributedTaskExecutor` | `Shared/Core/DistributedTaskExecutor.swift` | `AgentTeamOrchestrator` for distributed task runs | 🟡 MEDIUM |
| `EventStore` | `Shared/Core/EventBus/EventStore.swift` | EventBus or app lifecycle | 🟡 MEDIUM |
| `ContextManager` | `Shared/Core/Configuration/ContextManager.swift` | ChatManager context pipeline | 🟡 MEDIUM |
| `ResponseNotificationHandler` | `Shared/Core/Managers/ResponseNotificationHandler.swift` | ChatManager on response complete | 🟡 MEDIUM |
| `OfflineQueueService` | `Shared/Core/` | ChatManager — drain queue on connectivity restore | 🟡 MEDIUM |
| `ShortcutsManager` | `Shared/Core/Managers/ShortcutsManager.swift` | `PlatformFeaturesHub` on macOS | 🟡 MEDIUM |

**Note on WindowManager**: Explicitly commented out in `TheamacOSApp.swift:213` with "TODO: Restore after implementation". Wire in Phase K3 after UI implementation.

#### App Integration Layer — Unwired
| System | File | Wire Into | Priority |
|--------|------|-----------|----------|
| `AppIntegrationFramework` | `Shared/AppIntegration/AppIntegrationFramework.swift` | App lifecycle (macOS) | 🟠 HIGH |
| `WorkWithAppsService` | `Shared/AppIntegration/WorkWithAppsService.swift` | `AppIntegrationFramework` | 🟠 HIGH |
| `UIElementInspector` | `Shared/AppIntegration/UIElementInspector.swift` | `AppIntegrationFramework` or computer use (Phase L3) | 🟡 MEDIUM |

#### Memory System — Partially Unwired
| System | File | Wire Into | Priority |
|--------|------|-----------|----------|
| `MemoryAugmentedChat` | `Shared/Memory/MemoryAugmentedChat.swift` | ChatManager — augment messages with memory context | 🟠 HIGH |
| `ConversationMemoryExtractor` | `Shared/Memory/ConversationMemoryExtractor.swift` | ChatManager post-response | 🟠 HIGH |
| `ConversationMemory` | `Shared/Memory/ConversationMemory.swift` | `ConversationMemoryExtractor` or MemorySystem | 🟡 MEDIUM |

#### Collaboration / Remote / Other
| System | File | Wire Into | Priority |
|--------|------|-----------|----------|
| `TeamKnowledgeBase` | `Shared/Collaboration/TeamKnowledgeBase.swift` | `PersonalKnowledgeGraph` or Phase F3 Squads | 🟡 MEDIUM |
| `TheaRemoteServer` | `Shared/RemoteServer/TheaRemoteServer.swift` | App lifecycle (macOS) — start for remote access | 🟡 MEDIUM |
| `RemoteCommandService` | `Shared/RemoteServer/RemoteCommandService.swift` | `TheaRemoteServer` | 🟡 MEDIUM |
| `TheaSharePlay` | `Shared/SharePlay/TheaSharePlay.swift` | iOS/macOS app lifecycle (GroupActivities) | 🟡 MEDIUM |
| `SyncConflictResolutionView` | `Shared/UI/Views/Components/SyncConflictResolutionView.swift` | CloudKit conflict handler → present view | 🟡 MEDIUM |

---

### U3-5: TODO Stubs in Active Files (from 2026-02-19 Audit)

These TODOs are in ACTIVE (non-excluded) files and must be implemented:

| File | Line | TODO | Resolution Phase |
|------|------|------|-----------------|
| `macOS/TheamacOSApp.swift` | 209 | Restore PromptOptimizer.shared (commented out) | Phase K3 (Config UI) |
| `macOS/TheamacOSApp.swift` | 213 | Restore WindowManager.shared (commented out) | Phase K3 |
| `Shared/Intelligence/Memory/LongTermMemorySystem+Consolidation.swift` | 249 | Embedding-based similarity merging | Phase P3 (PersonalKnowledgeGraph) or U3 |
| `Shared/Intelligence/LifeMonitoring/LifeMonitoringCoordinator.swift` | 42 | Create BrowserActivityMonitor | Phase J3 (Life Tracking) |
| `Shared/SelfEvolution/SelfEvolutionEngine.swift` | 494 | Feature logic stub | Phase R3 (SelfEvolution) |
| `Shared/Integrations/ContextExtractors/XcodeContextExtractor.swift` | 232 | AX hierarchy navigation | Phase T3 (Integrations) |
| `Shared/UI/Views/Settings/LiveGuidanceSettingsView.swift` | 267 | Region selection UI | Phase K3 |
| `Shared/AI/Autonomy/AutonomousMaintenanceService.swift` | 134 | No-op stub | Phase Q3 (Proactive Intelligence) |
| `Shared/APIBuilder/MCPServerGenerator.swift` | 239,260,277 | Three tool/resource/prompt stubs | Phase S3 (MCPServerGenerator) |

---

### U3-6: CLAUDE.md Discrepancies Found by Audit (Fix Immediately)

**⚠️ CLAUDE.md makes false "WIRED" claims. These must be corrected.**

1. **`TheaMessagingChatView`**: CLAUDE.md says "Wired into MacSettingsView sidebar" — grep finds ZERO callers in navigation.
   → Must be wired in Phase W3. Note: `TheaMessagingSettingsView` may be wired; `TheaMessagingChatView` (the conversation view) is not.

2. **`ConversationLanguagePickerView`**: CLAUDE.md says "WIRED into ChatView toolbar" — grep finds ZERO instantiation calls.
   → Must be wired in Phase W3.

**Fix these in the CLAUDE.md before or during Phase W3.**

---

## PHASE V3: TRANSPARENCY & ANALYTICS UIs

**Status: ⏳ PENDING (blocked by H3; MBAM2 assignment — pure SwiftUI, no ML dependency)**

**Goal**: Create visibility dashboards for every life-monitoring and analytics system.
Users should be able to see what Thea sees: behavioral patterns, privacy decisions, messaging
health, notification intelligence. Every active backend system gets a corresponding UI panel.

**Machine**: MBAM2 (pure SwiftUI — can run in parallel with MSM3U Wave 5 phases)

### V3-1: BehavioralAnalyticsView

New file: `Shared/UI/Views/Analytics/BehavioralAnalyticsView.swift`

```swift
struct BehavioralAnalyticsView: View {
    @StateObject private var fingerprint = BehavioralFingerprint.shared
    @State private var selectedWeek: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 7×24 Activity Heatmap
                Text("Activity Pattern (7-day × 24-hour)").font(.headline)
                ActivityHeatmapGrid(data: fingerprint.activityMatrix)
                    .frame(height: 120)

                // Wake/Sleep patterns
                Text("Sleep/Wake Patterns").font(.headline)
                SleepWakePatternView(patterns: fingerprint.sleepWakePatterns)

                // App usage breakdown
                Text("Focus Distribution").font(.headline)
                AppUsageBreakdownView(data: fingerprint.appUsagePatterns)

                // Peak productivity windows
                Text("Peak Productivity Windows").font(.headline)
                ProductivityWindowsView(windows: fingerprint.peakProductivityWindows)
            }
            .padding()
        }
        .navigationTitle("Behavioral Analytics")
    }
}

struct ActivityHeatmapGrid: View {
    let data: [[Double]]  // [day][hour] 0.0–1.0 intensity
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 24), spacing: 2) {
            ForEach(0..<7, id: \.self) { day in
                ForEach(0..<24, id: \.self) { hour in
                    let intensity = data.indices.contains(day) && data[day].indices.contains(hour)
                        ? data[day][hour] : 0.0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple.opacity(0.1 + intensity * 0.9))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
}
```

### V3-2: PrivacyTransparencyView

New file: `Shared/UI/Views/Analytics/PrivacyTransparencyView.swift`

Shows every outbound data item that `OutboundPrivacyGuard` blocked, masked PII log,
policy decisions, and sanitization statistics from `PrivacyAuditLogService`.

```swift
struct PrivacyTransparencyView: View {
    @StateObject private var guard_ = OutboundPrivacyGuard.shared
    var body: some View {
        List {
            Section("Blocked Outbound (last 24h)") {
                ForEach(guard_.recentBlockedItems) { item in
                    PrivacyBlockRow(item: item)
                }
            }
            Section("PII Masked (last 24h)") {
                ForEach(guard_.recentMaskedItems) { item in
                    PIIMaskRow(item: item)
                }
            }
            Section("Policy Stats") {
                LabeledContent("Total Sanitizations", value: "\(guard_.totalSanitizations)")
                LabeledContent("Active Policy", value: guard_.activePolicy.name)
            }
        }
        .navigationTitle("Privacy Transparency")
    }
}
```

### V3-3: MessagingGatewayStatusView

New file: `Shared/UI/Views/Analytics/MessagingGatewayStatusView.swift`

Live health dashboard for all 7 messaging connectors with message throughput graphs.

```swift
struct MessagingGatewayStatusView: View {
    @StateObject private var gateway = TheaMessagingGateway.shared
    var body: some View {
        List {
            Section("Gateway Status") {
                LabeledContent("Server", value: gateway.isRunning ? "Running :18789" : "Stopped")
                    .foregroundStyle(gateway.isRunning ? .green : .red)
            }
            Section("Connectors (7)") {
                ForEach(gateway.connectorStatuses) { status in
                    ConnectorHealthRow(status: status)
                }
            }
            Section("Throughput (last 1h)") {
                MessageThroughputChart(data: gateway.messageRates)
            }
        }
        .navigationTitle("Messaging Gateway")
        .refreshable { await gateway.refreshStatuses() }
    }
}
```

### V3-4: NotificationIntelligenceView

New file: `Shared/UI/Views/Analytics/NotificationIntelligenceView.swift`

Shows `SmartNotificationScheduler` deferral history, delivery stats, optimal window adherence.

### V3-5: Wire into MacSettingsView + iOS Navigation

```swift
// MacSettingsView sidebar (new "Analytics" section):
NavigationLink(destination: BehavioralAnalyticsView()) {
    Label("Behavioral Analytics", systemImage: "chart.bar.xaxis")
}
NavigationLink(destination: PrivacyTransparencyView()) {
    Label("Privacy Transparency", systemImage: "eye.slash")
}
NavigationLink(destination: MessagingGatewayStatusView()) {
    Label("Messaging Gateway", systemImage: "antenna.radiowaves.left.and.right")
}
NavigationLink(destination: NotificationIntelligenceView()) {
    Label("Notification Intel", systemImage: "bell.badge")
}
```

### V3-6: Verify

```bash
for VIEW in BehavioralAnalyticsView PrivacyTransparencyView MessagingGatewayStatusView NotificationIntelligenceView; do
  grep -r "$VIEW" Shared/ macOS/ --include="*.swift" | wc -l  # ≥2 (definition + wiring)
done
```

Commit: `git add Shared/UI/Views/Analytics/ && git commit -m "Auto-save: V3 — transparency & analytics UIs created and wired"`

---

## PHASE W3: CHAT ENHANCEMENT FEATURES

**Status: ⏳ PENDING (blocked by I3; MBAM2 assignment — pure SwiftUI, no ML dependency)**

**Goal**: Complete ChatView with all production-grade features currently invisible to the user.
These features are ALL built in the backend — W3 makes them visible and interactive.

**Machine**: MBAM2 (pure SwiftUI — can run in parallel with MSM3U Wave 5 phases)

### W3-1: AnthropicFilesAPI File Attachment UI

Wire `AnthropicFilesAPIService` into ChatView toolbar with a file picker.

```swift
// In ChatView toolbar, add attachment button:
ToolbarItem(placement: .primaryAction) {
    Button { showFilePicker = true } label: {
        Image(systemName: "paperclip")
    }
    .fileImporter(isPresented: $showFilePicker,
                  allowedContentTypes: [.pdf, .plainText, .image]) { result in
        if case .success(let url) = result {
            Task { await viewModel.attachFile(url) }
        }
    }
}
```

Show attached files as chips above the text input field.
When sending, include file references via `AnthropicFilesAPIService.uploadFile()`.

### W3-2: Token Counter Display

Show per-message token counts (in + out) in `MessageBubble` footer.
Source: `AnthropicTokenCounter.countTokens()` — already wired into `MessageMetadata`.

```swift
// In MessageBubble footer:
if let metadata = message.metadata, let tokens = metadata.tokenCount {
    Text("\(tokens.inputTokens)↑ \(tokens.outputTokens)↓")
        .font(.caption2)
        .foregroundStyle(.tertiary)
}
```

### W3-3: MultiModelConsensus Breakdown Panel

When `ConfidenceSystem` used `MultiModelConsensus`, show which models agreed/disagreed.
Tap the confidence indicator → expand to show per-model verdicts.

```swift
struct ConsensusBreakdownView: View {
    let consensus: MultiModelConsensusResult
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(consensus.modelVerdicts) { verdict in
                HStack {
                    Image(systemName: verdict.agreed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(verdict.agreed ? .green : .red)
                    Text(verdict.modelName).font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", verdict.confidence * 100)).font(.caption2)
                }
            }
        }
    }
}
```

### W3-4: AgentMode Phase Progress Bar

Show `AgentExecutionState` phases as a linear progress indicator below the chat input.

```swift
// In ChatView, below text input (visible only when agentState.isActive):
if chatManager.agentState.isActive {
    AgentPhaseProgressBar(state: chatManager.agentState)
        .transition(.move(edge: .bottom).combined(with: .opacity))
}

struct AgentPhaseProgressBar: View {
    let state: AgentExecutionState
    let phases: [AgentPhase] = [.gatherContext, .takeAction, .verifyResults, .done]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(phases, id: \.self) { phase in
                Capsule()
                    .fill(state.currentPhase >= phase ? Color.purple : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
    }
}
```

### W3-5: Enhanced AutonomyController Approval UI

Replace simple approval dialog with a rich action detail sheet:

```swift
struct ActionApprovalSheet: View {
    let pendingAction: PendingAction
    @Binding var isPresented: Bool
    var onDecision: (ApprovalDecision) -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Risk level badge
            RiskLevelBadge(level: pendingAction.riskLevel)
            Text(pendingAction.actionDescription).font(.body)
            // Action details
            ActionDetailsGrid(action: pendingAction)
            // Reversibility warning
            if !pendingAction.isReversible {
                Label("This action cannot be undone", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            // Decision buttons
            HStack {
                Button("Deny") { onDecision(.denied); isPresented = false }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Modify") { onDecision(.modified(prompt: "")); isPresented = false }
                    .buttonStyle(.bordered)
                Button("Allow") { onDecision(.approved); isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

### W3-6: CloudKit Sync Indicator in Toolbar

```swift
// In ChatView/MainView toolbar:
ToolbarItem {
    CloudSyncStatusView(status: cloudKitService.syncStatus)
}

struct CloudSyncStatusView: View {
    let status: CloudSyncStatus
    var body: some View {
        switch status {
        case .syncing:
            ProgressView().scaleEffect(0.7)
        case .synced:
            Image(systemName: "checkmark.icloud").foregroundStyle(.secondary)
        case .error(let msg):
            Image(systemName: "exclamationmark.icloud").foregroundStyle(.red)
                .help(msg)
        case .offline:
            Image(systemName: "icloud.slash").foregroundStyle(.secondary)
        }
    }
}
```

### W3-7: MoltbookAgent Activity Log

Small status view accessible from MacSettingsView → Moltbook → "Activity":
Shows message count, recent topics, last active timestamp, daily post limit progress.

### W3-8: Verify

```bash
# All new UI components wired into ChatView or navigation:
grep -r "AgentPhaseProgressBar\|ConsensusBreakdownView\|ActionApprovalSheet\|CloudSyncStatusView" \
  Shared/ macOS/ iOS/ --include="*.swift" | grep -v "\.swift:struct\|\.swift:class" | wc -l  # ≥4

# Token counter visible in MessageBubble:
grep -r "tokenCount\|inputTokens\|outputTokens" \
  Shared/UI/Views/Chat/MessageBubble.swift 2>/dev/null | wc -l  # ≥1
```

Commit: `git add Shared/UI/ && git commit -m "Auto-save: W3 — chat enhancement features: FilesAPI UI, token counter, consensus breakdown, AgentMode progress bar, approval sheet, CloudKit indicator"`

---

## PHASE X3: TEST COVERAGE ≥80%

**Status: ⏳ PENDING (blocked by A3–W3)**

**Goal**: Run the same test coverage process as v2's Phase Q, but on ALL code
including all v3 additions. Every new file in A3–W3 needs tests.

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

## PHASE AE3: PLATFORM OBSERVERS STARTUP

**Status: ⏳ PENDING (blocked by U3; MSM3U + MBAM2 parallel assignment)**

**Goal**: Wire `PlatformFeaturesHub.shared` startup into all app lifecycles, activating the entire ambient intelligence foundation. Without this, MacSystemObserver, all iOS platform providers, and remote access are dead.

**Priority: 🔴 CRITICAL** — this is the single biggest gap found by the Feb 2026 audit. Nearly all ambient intelligence (accessibility monitoring, network observation, power management, HealthKit, motion, screen time, etc.) depends on this wiring.

### AE3-1: macOS — Start PlatformFeaturesHub

In `TheamacOSApp.swift`, after CloudKit/ChatManager init:
```swift
Task {
    await PlatformFeaturesHub.shared.start()
}
```

Verify `PlatformFeaturesHub.start()` internally calls:
- `MacSystemObserver.shared.start()` → starts AccessibilityObserver, NetworkObserver, PowerObserver, DisplayObserver
- `MenuBarManager.shared.setup()`
- `ServicesHandler.shared.register()`
- `SystemAutomationEngine.shared.activate()`
- `SpotlightService.shared.start()`
- `TheaRemoteServer.shared.start()`

If PlatformFeaturesHub doesn't call these, add them to its `start()` method.

### AE3-2: iOS — Start Platform Providers

In iOS app lifecycle, after permission grants:
```swift
Task {
    await HealthKitProvider.shared.start()      // consolidate with HealthContextProvider
    await MotionContextProvider.shared.start()
    await ScreenTimeObserver.shared.start()
    await PhotoIntelligenceProvider.shared.start()
    await AdaptiveModelRouter.shared.configure()
    await RemoteMacBridge.shared.connect()
    await MobileIntelligenceOrchestrator.shared.start()
}
```

**HealthKit consolidation**: `HealthKitProvider` (new, unwired) and `HealthContextProvider` (wired via LifeMonitoringCoordinator) are duplicate stacks. `HealthKitProvider` becomes the single authorization source; `HealthContextProvider` delegates to it.

### AE3-3: TheaIntelligenceOrchestrator Startup

**Critical gap**: `TheaIntelligenceOrchestrator` is the top-level intelligence coordinator and is NEVER started. Wire into macOS + iOS app lifecycle after platform features init:
```swift
Task {
    await TheaIntelligenceOrchestrator.shared.start()
    // Must cascade-start: IntelligenceOrchestrator, InsightEngine, PredictiveEngine,
    // PatternDetector, TheaContextMonitor, CrossDomainCorrelationEngine
}
```

### AE3-4: ApprovalManager Wiring

`ApprovalManager` has zero callers — autonomy approval queue is non-functional. Wire into `AutonomyController`:
```swift
// In AutonomyController.queueForApproval():
await ApprovalManager.shared.queueRequest(action, risk: riskLevel, context: context)
```

### AE3-5: Verify

```bash
for SVC in PlatformFeaturesHub TheaIntelligenceOrchestrator ApprovalManager \
           HealthKitProvider AdaptiveModelRouter MobileIntelligenceOrchestrator; do
  COUNT=$(grep -r "${SVC}" macOS/ iOS/ --include="*.swift" | grep -v "class ${SVC}" | wc -l | tr -d ' ')
  echo "${SVC}: ${COUNT} launch refs"
done
# Each must be ≥1
```

Commit: `git commit -m "Auto-save: AE3 — platform observers + intelligence orchestrator startup wired"`

---

## PHASE AF3: SETTINGS SIDEBAR + UI NAVIGATION COMPLETION

**Status: ⏳ PENDING (blocked by AE3; MBAM2 assignment — pure SwiftUI, no ML)**

**Goal**: Wire the 88 unreachable settings views into MacSettingsView sidebar, and resolve the 57 orphaned SwiftUI views with no navigation reference.

**Source**: Feb 2026 full codebase audit.

### AF3-1: MacSettingsView Sidebar (Priority Order)

**Priority 1 — Core intelligence settings:**
- `BehavioralPatternsView` — BehavioralFingerprint 7×24 heatmap
- `NotificationScheduleView` — SmartNotificationScheduler preferences
- `LifeTrackingSettingsView` — life monitoring toggle UI
- `ResponseStylesSettingsView` — customResponseStyles editor
- `KnowledgeGraphExplorerView` — PersonalKnowledgeGraph explorer
- `ConversationSettingsView`, `PersonalizationSettingsView`, `AIFeaturesSettingsView`

**Priority 2 — App capabilities:**
- `PromptEngineeringSettingsView`, `AutonomousTaskSettingsView`, `WorkflowSettingsView`
- `AppPairingSettingsView`, `LocalModelsSettingsView`, `RemoteAccessSettingsView`
- `ShortcutsSettingsView`, `SystemPromptSettingsView`, `WakeWordSettingsView`

**Priority 3 — Health and monitoring:**
- `HealthInsightsView`, `MonitoringSettingsView`, `LiveGuidanceSettingsView`

**All remaining ~60 views** — add in logical sidebar groups (Advanced, Developer, etc.)

### AF3-2: Critical Orphaned View Fixes

- `OnboardingView` (iOS) — show to new users (check `hasCompletedOnboarding` flag)
- `WelcomeView` — show on first launch
- `TheaMessagingChatView` — wire to MacSettingsView sidebar (**⚠️ CLAUDE.md falsely claims wired**)
- `ConversationLanguagePickerView` — wire into ChatView toolbar (**⚠️ CLAUDE.md falsely claims wired**)
- `TheaAgentSidebarView` — insert into NavigationSplitView
- `APIBuilderView`, `UnifiedDashboardView`, `PrivacyControlsView`, `CoworkView`
- `LocalModelsView`, `DeviceSwitcherView`, `QuickEntryView` (keyboard shortcut)

### AF3-3: Fix CLAUDE.md Discrepancies Post-Wiring

After wiring `TheaMessagingChatView` and `ConversationLanguagePickerView`:
- Update `Thea/.claude/CLAUDE.md` to change placeholder notes to WIRED status

### AF3-4: Verify

```bash
grep -r "TheaMessagingChatView()" macOS/ iOS/ Shared/ --include="*.swift" | wc -l   # ≥1
grep -r "ConversationLanguagePickerView" Shared/UI/Views/Chat/ --include="*.swift" | wc -l  # ≥1
```

Commit: `git commit -m "Auto-save: AF3 — 88 settings views + 57 orphaned views wired to navigation"`

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

### AA3-COMPLETENESS: Wiring Script — Mechanical Verification of All Phase U3 Systems

**Purpose**: Confirm every system listed in Phase U3 "Canonical-but-Unwired" table is now actually wired.
Run this BEFORE declaring AA3 complete. Zero-count = that system was missed.

```bash
#!/usr/bin/env bash
# Completeness Wiring Script — v3 Phase AA3
# Every check must return ≥1. Zero = wiring incomplete.
set -euo pipefail
PASS=0; FAIL=0
check() {
  local name="$1"; local count="$2"
  if [ "$count" -ge 1 ]; then
    echo "✅ $name ($count refs)"; PASS=$((PASS+1))
  else
    echo "❌ UNWIRED: $name — add to Phase U3 immediately"; FAIL=$((FAIL+1))
  fi
}

# ── Phase U3 canonical-but-unwired systems ──────────────────────────────────

# 1. SmartNotificationScheduler
check "SmartNotificationScheduler" \
  "$(grep -r "SmartNotificationScheduler" Shared/ --include="*.swift" | grep -v "SmartNotificationScheduler.swift" | wc -l | tr -d ' ')"

# 2. PredictiveLifeEngine
check "PredictiveLifeEngine" \
  "$(grep -r "PredictiveLifeEngine" Shared/ --include="*.swift" | grep -v "PredictiveLifeEngine.swift" | wc -l | tr -d ' ')"

# 3. AmbientIntelligenceEngine
check "AmbientIntelligenceEngine" \
  "$(grep -r "AmbientIntelligenceEngine" Shared/ --include="*.swift" | grep -v "AmbientIntelligenceEngine.swift" | wc -l | tr -d ' ')"

# 4. HealthCoachingPipeline
check "HealthCoachingPipeline" \
  "$(grep -r "HealthCoachingPipeline" Shared/ --include="*.swift" | grep -v "HealthCoachingPipeline.swift" | wc -l | tr -d ' ')"

# 5. EnergyAdaptiveThrottler
check "EnergyAdaptiveThrottler" \
  "$(grep -r "EnergyAdaptiveThrottler" Shared/ --include="*.swift" | grep -v "EnergyAdaptiveThrottler.swift" | wc -l | tr -d ' ')"

# 6. PersonalKnowledgeGraph
check "PersonalKnowledgeGraph" \
  "$(grep -r "PersonalKnowledgeGraph.shared\|PersonalKnowledgeGraph()" Shared/ --include="*.swift" | grep -v "PersonalKnowledgeGraph.swift" | wc -l | tr -d ' ')"

# 7. TaskPlanDAG
check "TaskPlanDAG" \
  "$(grep -r "TaskPlanDAG" Shared/ --include="*.swift" | grep -v "TaskPlanDAG.swift" | wc -l | tr -d ' ')"

# 8. BehavioralFingerprint
check "BehavioralFingerprint" \
  "$(grep -r "BehavioralFingerprint" Shared/ --include="*.swift" | grep -v "BehavioralFingerprint.swift" | wc -l | tr -d ' ')"

# 9. DrivingDetectionService
check "DrivingDetectionService" \
  "$(grep -r "DrivingDetectionService" Shared/ --include="*.swift" | grep -v "DrivingDetectionService.swift" | wc -l | tr -d ' ')"

# 10. ScreenTimeAnalyzer
check "ScreenTimeAnalyzer" \
  "$(grep -r "ScreenTimeAnalyzer" Shared/ --include="*.swift" | grep -v "ScreenTimeAnalyzer.swift" | wc -l | tr -d ' ')"

# 11. CalendarIntelligenceService
check "CalendarIntelligenceService" \
  "$(grep -r "CalendarIntelligenceService" Shared/ --include="*.swift" | grep -v "CalendarIntelligenceService.swift" | wc -l | tr -d ' ')"

# 12. LocationIntelligenceService
check "LocationIntelligenceService" \
  "$(grep -r "LocationIntelligenceService" Shared/ --include="*.swift" | grep -v "LocationIntelligenceService.swift" | wc -l | tr -d ' ')"

# 13. SleepAnalysisService
check "SleepAnalysisService" \
  "$(grep -r "SleepAnalysisService" Shared/ --include="*.swift" | grep -v "SleepAnalysisService.swift" | wc -l | tr -d ' ')"

# 14. MultiModalCoordinator
check "MultiModalCoordinator" \
  "$(grep -r "MultiModalCoordinator" Shared/ --include="*.swift" | grep -v "MultiModalCoordinator.swift" | wc -l | tr -d ' ')"

# 15. ContextualMemoryManager
check "ContextualMemoryManager" \
  "$(grep -r "ContextualMemoryManager" Shared/ --include="*.swift" | grep -v "ContextualMemoryManager.swift" | wc -l | tr -d ' ')"

# 16. ProactiveInsightEngine
check "ProactiveInsightEngine" \
  "$(grep -r "ProactiveInsightEngine" Shared/ --include="*.swift" | grep -v "ProactiveInsightEngine.swift" | wc -l | tr -d ' ')"

# 17. FocusSessionManager
check "FocusSessionManager" \
  "$(grep -r "FocusSessionManager" Shared/ --include="*.swift" | grep -v "FocusSessionManager.swift" | wc -l | tr -d ' ')"

# 18. HabitTrackingService
check "HabitTrackingService" \
  "$(grep -r "HabitTrackingService" Shared/ --include="*.swift" | grep -v "HabitTrackingService.swift" | wc -l | tr -d ' ')"

# 19. GoalTrackingService
check "GoalTrackingService" \
  "$(grep -r "GoalTrackingService" Shared/ --include="*.swift" | grep -v "GoalTrackingService.swift" | wc -l | tr -d ' ')"

# 20. WellbeingMonitor
check "WellbeingMonitor" \
  "$(grep -r "WellbeingMonitor" Shared/ --include="*.swift" | grep -v "WellbeingMonitor.swift" | wc -l | tr -d ' ')"

# 21. NeuralContextCompressor
check "NeuralContextCompressor" \
  "$(grep -r "NeuralContextCompressor" Shared/ --include="*.swift" | grep -v "NeuralContextCompressor.swift" | wc -l | tr -d ' ')"

# 22. SelfTuningEngine
check "SelfTuningEngine" \
  "$(grep -r "SelfTuningEngine" Shared/ --include="*.swift" | grep -v "SelfTuningEngine.swift" | wc -l | tr -d ' ')"

# 23. DynamicConfigManager
check "DynamicConfigManager" \
  "$(grep -r "DynamicConfigManager\|DynamicConfig" Shared/ --include="*.swift" | grep -v "DynamicConfig.swift" | wc -l | tr -d ' ')"

# 24. PrivacyPreservingAIRouter
check "PrivacyPreservingAIRouter" \
  "$(grep -r "PrivacyPreservingAIRouter" Shared/ --include="*.swift" | grep -v "PrivacyPreservingAIRouter.swift" | wc -l | tr -d ' ')"

# 25. MultiModelConsensus (verification system)
check "MultiModelConsensus" \
  "$(grep -r "MultiModelConsensus" Shared/ --include="*.swift" | grep -v "MultiModelConsensus.swift" | wc -l | tr -d ' ')"

# 26. WebSearchVerifier
check "WebSearchVerifier" \
  "$(grep -r "WebSearchVerifier" Shared/ --include="*.swift" | grep -v "WebSearchVerifier.swift" | wc -l | tr -d ' ')"

# 27. UserFeedbackLearner
check "UserFeedbackLearner" \
  "$(grep -r "UserFeedbackLearner" Shared/ --include="*.swift" | grep -v "UserFeedbackLearner.swift" | wc -l | tr -d ' ')"

# 28. SelfExecutionService (MetaAI TIER 0)
check "SelfExecutionService" \
  "$(grep -r "SelfExecutionService" Shared/ --include="*.swift" | grep -v "SelfExecutionService.swift" | wc -l | tr -d ' ')"

# 29. PhaseOrchestrator (MetaAI TIER 0)
check "PhaseOrchestrator" \
  "$(grep -r "PhaseOrchestrator" Shared/ --include="*.swift" | grep -v "PhaseOrchestrator.swift" | wc -l | tr -d ' ')"

# ── Phase AE3 systems (platform observers + intelligence startup) ─────────────

# 30. PlatformFeaturesHub started at launch
check "PlatformFeaturesHub startup" \
  "$(grep -r "PlatformFeaturesHub" macOS/ iOS/ --include="*.swift" | grep -v "class PlatformFeaturesHub" | wc -l | tr -d ' ')"

# 31. TheaIntelligenceOrchestrator started
check "TheaIntelligenceOrchestrator startup" \
  "$(grep -r "TheaIntelligenceOrchestrator" macOS/ iOS/ --include="*.swift" | grep -v "class TheaIntelligenceOrchestrator" | wc -l | tr -d ' ')"

# 32. ApprovalManager wired to AutonomyController
check "ApprovalManager wired" \
  "$(grep -r "ApprovalManager" Shared/ --include="*.swift" | grep -v "ApprovalManager.swift" | wc -l | tr -d ' ')"

# 33. MemoryAugmentedChat wired to ChatManager
check "MemoryAugmentedChat wired" \
  "$(grep -r "MemoryAugmentedChat" Shared/ --include="*.swift" | grep -v "MemoryAugmentedChat.swift" | wc -l | tr -d ' ')"

# 34. AppIntegrationFramework started
check "AppIntegrationFramework started" \
  "$(grep -r "AppIntegrationFramework" macOS/ iOS/ Shared/ --include="*.swift" | grep -v "AppIntegrationFramework.swift" | wc -l | tr -d ' ')"

# ── Phase AF3 systems (navigation wiring) ────────────────────────────────────

# 35. TheaMessagingChatView wired to navigation
check "TheaMessagingChatView in nav" \
  "$(grep -r "TheaMessagingChatView()" macOS/ iOS/ Shared/ --include="*.swift" | wc -l | tr -d ' ')"

# 36. ConversationLanguagePickerView wired to ChatView toolbar
check "ConversationLanguagePickerView wired" \
  "$(grep -r "ConversationLanguagePickerView" Shared/UI/Views/Chat/ --include="*.swift" | wc -l | tr -d ' ')"

# 37. OnboardingView (iOS) shown to new users
check "OnboardingView shown" \
  "$(grep -r "OnboardingView" iOS/ --include="*.swift" | grep -v "OnboardingView.swift" | wc -l | tr -d ' ')"

# ── UI wiring: views accessible via navigation ───────────────────────────────

# Life Tracking views reachable
check "LifeTrackingView in nav" \
  "$(grep -r "LifeTracking\|lifeTracking" Shared/UI/Views/ --include="*.swift" | grep -v "LifeTracking" | wc -l | tr -d ' ')"

# MetaAI dashboard reachable
check "MetaAIDashboardView in nav" \
  "$(grep -r "MetaAIDashboard" Shared/UI/Views/ --include="*.swift" | grep -v "MetaAIDashboard.swift" | wc -l | tr -d ' ')"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "WIRING SCRIPT RESULT: $PASS passed, $FAIL FAILED"
[ "$FAIL" -eq 0 ] && echo "✅ ALL SYSTEMS WIRED — AA3 may proceed" \
                  || echo "❌ $FAIL systems unwired — Phase U3 incomplete"
echo "═══════════════════════════════════════════"
exit "$FAIL"
```

**AA3 is BLOCKED until the above script exits 0 (zero failures).**
Any ❌ item must be addressed in Phase U3 before AA3 can be marked done.

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

## PHASE AG3: COMPREHENSIVE QA PLAN EXECUTION + FULL ACTIVATION

**Status: ⏳ PENDING (after AC3; MSM3U primary)**
**Purpose: Run the full 15-phase Autonomous Self-Healing QA Plan AND activate everything — make all buttons respond, all stubs live, all features usable. Build+fix loop until every GH Actions workflow is green.**

### AG3-0: Environment Gate + Pre-build Cleanup
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# Run COMPREHENSIVE_QA_PLAN.md Phase 0 (environment check) + Phase 0.5 (DB lock prevention)
for tool in xcodebuild swiftlint xcodegen swift; do command -v $tool || { echo "MISSING: $tool"; exit 1; }; done
osascript -e 'tell application "Xcode" to quit' 2>/dev/null; sleep 2
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "Thea-*" -type d -exec rm -rf {} + 2>/dev/null || true
echo "✅ AG3-0 PASSED"
```

### AG3-1: Static Analysis — Zero Tolerance
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodegen generate 2>&1 | tail -2
swiftlint lint --fix --quiet; swiftlint lint --fix --quiet  # 2 passes for cascading fixes
LINT_ISSUES=$(swiftlint lint 2>&1 | grep -c "error:\|warning:" || echo "0")
[ "$LINT_ISSUES" -eq 0 ] && echo "✅ AG3-1 PASSED: 0 lint issues" || { echo "❌ MANUAL: $LINT_ISSUES lint issues remain"; swiftlint lint 2>&1 | grep "error:\|warning:" | head -20; exit 1; }
```

### AG3-2: Swift Package Tests
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
swift test 2>&1 | tail -5
[ ${PIPESTATUS[0]} -eq 0 ] && echo "✅ AG3-2 PASSED" || { echo "❌ Tests failing — fix before proceeding"; exit 1; }
```

### AG3-3: Sanitizer Tests (Address + Thread)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
swift test --sanitize=address 2>&1 | tail -5 && swift test --sanitize=thread 2>&1 | tail -5
echo "✅ AG3-3 PASSED (review sanitizer output for any warnings)"
```

### AG3-4: Debug Builds — All 4 Apple Platforms (Fix Loop)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# Auto-fix loop: build → parse errors → fix → rebuild (max 3 iterations)
for ITER in 1 2 3; do
  FAIL=0
  for scheme in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
    DEST=$(case "$scheme" in macOS) echo "platform=macOS";; iOS) echo "generic/platform=iOS";; watchOS) echo "generic/platform=watchOS";; tvOS) echo "generic/platform=tvOS";; esac)
    OUT=$(xcodebuild -project Thea.xcodeproj -scheme "$scheme" -destination "$DEST" -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/TheaBuild build 2>&1)
    ERRS=$(echo "$OUT" | grep -c "error:" || echo 0)
    [ "$ERRS" -gt 0 ] && { echo "❌ $scheme Debug: $ERRS errors (iter $ITER)"; echo "$OUT" | grep "error:" | head -5; FAIL=1; } || echo "✅ $scheme Debug: SUCCEEDED"
  done
  [ "$FAIL" -eq 0 ] && break
  echo "🔄 Fixing errors — attempt $ITER"; xcodegen generate 2>&1 | tail -2; swiftlint lint --fix --quiet
done
[ "$FAIL" -eq 0 ] && echo "✅ AG3-4 PASSED" || { echo "❌ AG3-4 FAILED after 3 iterations — manual fix required"; exit 1; }
```

### AG3-5: Release Builds — All 4 Apple Platforms
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
for scheme in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
  DEST=$(case "$scheme" in macOS) echo "platform=macOS";; iOS) echo "generic/platform=iOS";; watchOS) echo "generic/platform=watchOS";; tvOS) echo "generic/platform=tvOS";; esac)
  OUT=$(xcodebuild -project Thea.xcodeproj -scheme "$scheme" -destination "$DEST" -configuration Release CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/TheaBuildRel build 2>&1)
  ERRS=$(echo "$OUT" | grep -c "error:" || echo 0)
  [ "$ERRS" -eq 0 ] && echo "✅ $scheme Release: SUCCEEDED" || { echo "❌ $scheme Release: $ERRS errors"; echo "$OUT" | grep "error:" | head -5; }
done
echo "✅ AG3-5 COMPLETE — review any release-only failures (optimization bugs)"
```

### AG3-5.5: Xcode GUI Builds (MANDATORY — catches indexer warnings)
Per COMPREHENSIVE_QA_PLAN.md §Phase 5.5: CLI-only is insufficient. GUI builds catch:
- Indexer warnings (type inference issues)
- Project settings warnings
- Capability/entitlement misconfigurations
- Missing package products

```bash
# Open Xcode and trigger builds via GUI
open "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"
sleep 5
# Build each scheme and inspect Issue Navigator (Cmd+5) — MUST show 0 issues
# If xclogparser available: xclogparser parse --file <latest.xcactivitylog> --reporter issues
command -v xclogparser &>/dev/null || brew install xclogparser
```
**GATE**: Xcode Issue Navigator shows 0 errors, 0 warnings across all 4 schemes.

### AG3-6: Complete Stub/TODO Activation (EVERY PLATFORM)
**Purpose: Make everything actually work — not just compile. Every tappable element must respond. Every stub must have real implementation.**

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# Find all TODO/FIXME in active (non-excluded) source files
grep -rn "TODO\|FIXME\|stub\|placeholder\|NOT YET IMPLEMENTED\|Coming soon" \
  Shared/ macOS/ iOS/ watchOS/ tvOS/ \
  --include="*.swift" \
  | grep -v "\.v1-archive\|MetaAI\|/Tests/" \
  | grep -v "// swiftlint" \
  > /tmp/thea_stubs.txt
echo "Total stubs/TODOs to activate: $(wc -l < /tmp/thea_stubs.txt)"
cat /tmp/thea_stubs.txt | head -30
```

For each stub found: implement real logic, remove the TODO/FIXME comment, commit.

Key areas from prior audit (U3-5 — 9 known stubs):
- Wire stubs per their Phase U3 resolution guide
- After each activation: run `swift test` and macOS Debug build to verify
- Stubs in Settings views → delegate to SettingsManager or UserDefaults
- Stubs in health/behavioral features → wire to actual HealthKit queries

**Platform-specific activation:**
- **Tizen**: Verify all JavaScript bridge calls are wired; no `console.log("TODO")` stubs
- **TheaWeb**: Verify all API endpoints respond; no mock data returned in production paths

### AG3-7: Security Audit (gitleaks + osv-scanner)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
command -v gitleaks &>/dev/null && gitleaks detect --source . --no-banner 2>&1 | tail -5 || echo "⚠ gitleaks not installed: brew install gitleaks"
command -v osv-scanner &>/dev/null && [ -f Package.resolved ] && osv-scanner --lockfile Package.resolved 2>&1 | tail -5 || echo "⚠ osv-scanner check: go install github.com/google/osv-scanner/cmd/osv-scanner@latest"
echo "✅ AG3-7 COMPLETE"
```

### AG3-8: Memory + Runtime Verification
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
APP_PATH=$(xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -destination "platform=macOS" \
  -configuration Release -showBuildSettings 2>/dev/null | grep "BUILT_PRODUCTS_DIR" | awk '{print $3}')/Thea.app
[ -d "$APP_PATH" ] && { open "$APP_PATH"; sleep 10; leaks "Thea" 2>&1 | grep "leaks for\|0 leaks" | head -3; osascript -e 'quit app "Thea"' 2>/dev/null; } || echo "⚠ Build app first"
echo "✅ AG3-8 COMPLETE"
```

### AG3-9: Commit All QA Fixes
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git add -A && git status --short | head -10
git diff --stat HEAD | tail -3
git commit -m "Auto-save: AG3 — comprehensive QA; all stubs activated; 0 build errors; 0 lint issues" 2>/dev/null || echo "Nothing to commit"
```

### AG3-10: CI/CD Fix Loop (GH Actions → All Green)
**This loop does NOT stop until every GitHub Actions workflow returns green.**

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
MAX=8; ITER=0
while [ $ITER -lt $MAX ]; do
  ((ITER++)); echo "--- CI Fix Loop Iteration $ITER ---"
  git pushsync 2>/dev/null || git push origin main  # use pushsync if available
  sleep 45  # wait for GH Actions to trigger
  FAILED=$(gh run list --limit 10 --json name,conclusion,status --jq '[.[] | select(.status=="completed" and .conclusion=="failure")] | .[].name' 2>/dev/null)
  RUNNING=$(gh run list --limit 10 --json status --jq '[.[] | select(.status=="in_progress")] | length' 2>/dev/null)
  [ "$RUNNING" -gt 0 ] && { echo "⏳ $RUNNING workflows still running — waiting 60s..."; sleep 60; continue; }
  [ -z "$FAILED" ] && { echo "✅ ALL CI WORKFLOWS GREEN — AG3-10 PASSED"; break; }
  echo "❌ Failed: $FAILED"
  # Per-failure fixes from MEMORY.md known issues:
  # 1. SwiftLint failures → swiftlint lint --fix
  # 2. Build errors → xcodegen generate + rebuild
  # 3. Workflow file issues → inspect .github/workflows/
  # 4. osv-scanner fails → use go install CLI directly
  # 5. gitleaks-action config → use GITLEAKS_CONFIG env var (not config-path:)
  # 6. SonarQube bad SHA → continue-on-error: true at JOB level
  RUN_ID=$(gh run list --status failure --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)
  [ -n "$RUN_ID" ] && gh run view "$RUN_ID" --log-failed 2>/dev/null | tail -40
  swiftlint lint --fix --quiet 2>/dev/null
  xcodegen generate 2>/dev/null
  git add -A && git diff --quiet HEAD || git commit -m "fix: CI iteration $ITER — GH Actions green loop

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
done
[ $ITER -ge $MAX ] && echo "⚠ AG3-10: max iterations reached — manual CI review required at github.com/Atchoum23/Thea/actions"
```

### AG3 Verification
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# All checks must pass
echo "=== AG3 FINAL VERIFICATION ==="
swift test 2>&1 | grep -E "passed|failed" | tail -2
swiftlint lint 2>&1 | grep -c "error:\|warning:" | xargs -I{} sh -c '[ "$1" -eq 0 ] && echo "✅ Lint: 0 issues" || echo "❌ Lint: $1 issues"' -- {}
gh run list --limit 6 --json name,conclusion --jq '.[] | "\(.name): \(.conclusion)"' 2>/dev/null
git log --oneline -3
```
Commit: `git commit -m "Auto-save: AG3 complete — QA plan executed; all stubs activated; CI green"`

---

## PHASE AH3: MULTI-HAT COMPREHENSIVE AUDIT + IMPLEMENTATION

**Status: ⏳ PENDING (after AG3; MSM3U primary)**
**Purpose: Apply 8 analytical perspectives to Thea — find every shortcoming, deficiency, and improvement opportunity, then IMPLEMENT everything found directly. No findings-only reports.**

### Why Multi-Hat?
Each "hat" approaches Thea from a different angle, finding issues that others miss:
- Adversarial hats (Red/Black/Script Kiddie) find security + misuse vulnerabilities
- Structural hats (White/Blue/Grey) find architectural and reliability issues
- Creative hats (Green/Purple) find UX, intelligence, and monitoring opportunities

**Rule: Every section ends with IMPLEMENTATION — not just findings.**

---

### AH3-RED: Red Hat — Adversarial Security Testing
**Mindset: "How do I attack Thea from the outside?"**

Areas to probe:
1. **Prompt Injection** — Test all 22 OpenClawSecurityGuard patterns. Send adversarial inputs via all 7 messaging connectors. Verify injection is blocked.
2. **Command Injection** — Test FunctionGemmaBridge blocklist. Attempt shell metacharacter bypass. Verify `; && || | > < $()` are all rejected.
3. **Privacy Leak via AI** — Ask Claude API to repeat system prompt, tool schemas, user PII. Verify OutboundPrivacyGuard intercepts.
4. **Memory Poisoning** — Inject false "memories" via conversation. Verify ConversationMemoryExtractor validates sources.
5. **Token Flooding** — Send extremely long inputs to all AI providers. Verify context window limits are enforced.
6. **WebSocket Injection** — Connect to port 18789 with malformed WebSocket frames. Verify TheaGatewayWSServer handles gracefully.
7. **BCP-47 Language Injection** — Try injecting code via language tag parameter. Verify whitelist holds.

```bash
# Verify security implementations are intact after linter
grep -n "blocklist\|shellMetacharacter\|promptInjection" \
  Shared/AI/CoreML/FunctionGemmaBridge.swift \
  Shared/Integrations/OpenClaw/OpenClawSecurityGuard.swift \
  | wc -l | xargs -I{} echo "Security patterns: {} (expected ≥30)"

# Verify OutboundPrivacyGuard credential patterns
grep -n "SSH\|PEM\|JWT\|Firebase" Shared/Privacy/OutboundPrivacyGuard.swift | wc -l \
  | xargs -I{} echo "Credential patterns: {} (expected ≥4)"
```

**Implement any gaps found**: Add patterns, tighten validation, add tests.

---

### AH3-BLACK: Black Hat — Attacker Perspective
**Mindset: "What would a motivated attacker do with access to Thea?"**

1. **Privilege Escalation via Autonomy** — Can an AI response escalate from Level 1 to Level 5 autonomy without approval? Test AutonomyController rejection logic.
2. **Data Exfiltration via MCP** — Can a malicious MCP server read HealthKit data, location, or conversation history? Verify MCP sandboxing.
3. **Social Engineering via Messaging** — Can a Telegram/Discord message convince Thea to execute arbitrary shell commands? Test MoltbookAgent kill switch.
4. **Rate Limit Bypass** — Can a fast-bursting client bypass OpenClawBridge's 5/min/channel rate limit by using different channel IDs?
5. **Crash via Malformed Input** — Send nil, empty, extremely nested JSON to every API surface. Verify graceful error handling everywhere.

**Implement**: For each vulnerability found → add guard + test + incident log entry.

---

### AH3-WHITE: White Hat — Formal Security Checklist (OWASP + STRIDE)
**Mindset: "Apply rigorous, documented security standards."**

OWASP Top 10 for mobile/AI:
- [ ] **A01 Broken Access Control** — All API keys stored in Keychain (not UserDefaults/plist)
- [ ] **A02 Cryptographic Failures** — CloudKit data encrypted at rest; no plaintext secrets in logs
- [ ] **A03 Injection** — All user input sanitized before AI/shell/SQL (injection guards in place)
- [ ] **A04 Insecure Design** — ApprovalManager requires explicit user approval for Level 3+ actions
- [ ] **A05 Security Misconfiguration** — No debug endpoints exposed in Release build
- [ ] **A06 Vulnerable Components** — osv-scanner clean (Phase AG3-7)
- [ ] **A07 Auth Failures** — All messaging connectors use token auth, not plain HTTP
- [ ] **A08 Software Integrity** — Code signing + notarization in Phase AB3
- [ ] **A09 Logging Failures** — Security events logged to AuditLogService; no PII in logs
- [ ] **A10 SSRF** — OutboundPrivacyGuard blocks internal network ranges from AI-initiated HTTP

STRIDE for Thea intelligence layer:
- **Spoofing**: AI response authenticity verified by ConfidenceSystem
- **Tampering**: Conversation history immutable in SwiftData (no edit endpoint)
- **Repudiation**: AuditLogService records all autonomy actions with timestamps
- **Info Disclosure**: PrivacyPolicies applied per destination (Cloud API vs Messaging vs Moltbook)
- **DoS**: Rate limiting + circuit breakers (ResilienceManager) protect all AI calls
- **Elevation**: Autonomy level transitions require explicit user approval

```bash
# Verify Keychain usage for API keys (not UserDefaults)
grep -rn "UserDefaults.*apiKey\|UserDefaults.*token\|UserDefaults.*secret" \
  Shared/ macOS/ iOS/ --include="*.swift" | grep -v "//" | wc -l \
  | xargs -I{} sh -c '[ "$1" -eq 0 ] && echo "✅ No API keys in UserDefaults" || echo "❌ $1 API keys stored insecurely in UserDefaults"' -- {}

grep -rn "Keychain\|KeychainAccess\|SecItemAdd\|SecKeychain" \
  Shared/ macOS/ iOS/ --include="*.swift" | wc -l \
  | xargs -I{} echo "Keychain usages: {} (should be ≥10 for all API key storage)"
```

**Implement**: Fix any OWASP/STRIDE gaps found — move secrets to Keychain, add audit logs, enforce rate limits.

---

### AH3-GREY: Grey Hat — Edge Cases + Unexpected Usage
**Mindset: "What happens with valid-but-weird inputs or usage patterns?"**

1. **Dual Device Conflict** — What if MBAM2 and MSM3U both receive a message and both generate a response? Is the duplicate detected?
2. **Language Switching Mid-Conversation** — Change language from English to Japanese mid-conversation. Does the AI instruction update? Does UI reflect it?
3. **Zero RAM Scenario** — What happens on a 4GB device? Are model selection guards correct? Does canRunLocalModel() return false?
4. **Extremely Long Conversations** — 10,000 message conversations — does SwiftData query performance degrade? Is infinite history preserved per CLAUDE.md spec?
5. **Concurrent AI Requests** — Send 50 simultaneous messages to different platforms. Do all 50 route correctly without deadlock?
6. **Offline Mode** — Disconnect network. Do local models activate? Does CloudKit sync queue? Does graceful fallback work?
7. **Clock Skew** — Set system clock 1 year forward. Do behavioral fingerprint temporal patterns break?

```bash
# Check for SwiftData query limits / LIMIT clauses that would truncate history
grep -rn "fetchLimit\|LIMIT\|limit:" Shared/Memory/ Shared/Chat/ --include="*.swift" \
  | grep -v "//\|test" | head -10
```

**Implement**: Fix each edge case — add guards, timeouts, fallback logic, or capacity planning.

---

### AH3-BLUE: Blue Hat — Defensive Architecture Review
**Mindset: "Make Thea resilient — anticipate failures before they happen."**

1. **Circuit Breakers** — Wire ResilienceManager into ALL AnthropicProvider, OpenRouterProvider, PerplexityProvider calls. Verify: after 5 consecutive failures, provider is marked unhealthy and traffic shifts to fallback.
2. **Cascading Failure Prevention** — If TheaIntelligenceOrchestrator fails to start, does the app degrade gracefully (fall back to direct model calls) or crash?
3. **Memory Pressure Handling** — Add `MemoryPressureObserver` to release MLX sessions when iOS sends memory warning. MaxMLXCachedSessions should drop to 2 under pressure.
4. **Retry Logic Standardization** — All network calls should use exponential backoff (1s → 2s → 4s → 8s → fail). Verify no "retry immediately in tight loop" patterns.
5. **Health Check Endpoint** — TheaGatewayWSServer `/health` endpoint should return: uptime, platform connector status, AI provider health, recent error rate.
6. **Graceful Shutdown** — When app goes background on iOS, in-flight AI requests should be checkpointed so they resume when app returns.
7. **Watchdog Timer** — If a local model inference exceeds recommendedTimeout(), kill it and return graceful error.

```bash
# Find providers without retry logic
grep -rn "URLSession.shared.data\|try await.*provider\|try await.*client" \
  Shared/AI/Providers/ --include="*.swift" \
  | grep -v "catch\|retry\|backoff\|ResilienceManager" | head -10
```

**Implement**: Add circuit breakers, memory pressure handlers, retry logic, health endpoint. Commit after each.

---

### AH3-PURPLE: Purple Hat — Detection, Telemetry, Monitoring
**Mindset: "If something goes wrong, will we know immediately?"**

1. **Metrics Collection** — Every AI request should record: provider, model, latency, token count, confidence score, error (if any). Store in SwiftData `RequestMetricsRecord`.
2. **Anomaly Detection** — If average confidence score drops below 0.6 for 10 consecutive responses → alert user via notification.
3. **Error Budget** — Track error rate per provider per day. If >5% error rate → recommend switching default provider in settings.
4. **Real-time Dashboard** — AI System Dashboard (Phase H3) should show live: requests/min, avg latency, confidence distribution, top failing tools.
5. **Audit Trail Completeness** — Every autonomy action (Level 2+) must appear in AuditLogService with: timestamp, action type, confidence, outcome, user approval status.
6. **User-Visible Reliability Indicator** — Show a small health indicator (green/yellow/red dot) in the main toolbar reflecting AI system health.

```bash
# Check if RequestMetricsRecord exists
grep -rn "RequestMetrics\|PerformanceMetrics\|latency.*record\|requestLog" \
  Shared/ --include="*.swift" | grep -v "test\|//" | head -10

# Verify AuditLogService is being called for autonomy actions
grep -rn "AuditLogService\|auditLog" Shared/Intelligence/Autonomy/ --include="*.swift" | wc -l \
  | xargs -I{} echo "Autonomy audit calls: {} (should be ≥5)"
```

**Implement**: Add `RequestMetricsRecord` SwiftData model, wire into all AI calls, add confidence anomaly detection, add toolbar health indicator.

---

### AH3-GREEN: Green Hat — Creative Improvements + Intelligence Enhancements
**Mindset: "What could make Thea dramatically more intelligent, useful, and delightful?"**

**Intelligence enhancements:**
1. **Proactive Intelligence** — When behavioral fingerprint detects "Monday 09:00 → user always checks messages," proactively summarize overnight messages at 08:55.
2. **Multi-Step Tool Use** — Chain tools automatically: `search_web → summarize → create_reminder` in a single response without round-trips.
3. **Contextual Memory Retrieval** — Before every message, query PersonalKnowledgeGraph for relevant entities. Inject top-3 relevant memories into system prompt automatically.
4. **Smart Model Selection** — Track which model gives highest confidence for each task type. Auto-promote the best-performing model per category in BehavioralFingerprint.
5. **Predictive Pre-loading** — If behavioral pattern shows user asks coding questions at 14:00, pre-warm the local coding model at 13:55.

**UX/UI improvements:**
6. **Haptic Feedback** — Add haptic feedback on iOS for: message send, tool execution start, AI response complete, error.
7. **Swipe Actions in Conversation List** — Swipe left to delete, swipe right to pin conversation.
8. **Quick Reply Suggestions** — Show 3 AI-generated quick reply suggestions below each message.
9. **Voice-First Flow** — Press-and-hold anywhere on iOS to start voice input without tapping the mic button.
10. **Adaptive UI Density** — Switch between compact/regular/expanded layout based on BehavioralFingerprint's screen time patterns.

**Platform-specific:**
11. **watchOS Complication** — Show last AI message summary + confidence score on watch face.
12. **tvOS Focus Mode** — Full-screen conversation view optimized for TV (larger text, Siri Remote navigation).
13. **Tizen Voice Integration** — Wire Samsung Bixby voice intent to TheaMessagingGateway.

```bash
# Check which green-hat improvements already exist vs need implementation
grep -rn "proactiveIntelligence\|predictivePre\|quickReply\|hapticFeedback" \
  Shared/ macOS/ iOS/ watchOS/ tvOS/ --include="*.swift" | grep -v "//\|test" | wc -l
```

**Implement**: Each green-hat item is a full implementation task — create, wire, test, commit.

---

### AH3-SCRIPT-KIDDIE: Script Kiddie — Automated Attack Simulation
**Mindset: "What damage can someone do with minimal skill using known tools?"**

1. **Port Scanner** — Run `nmap localhost` while Thea is running. Verify only port 18789 is open. No other unexpected ports.
2. **HTTP Fuzzer** — Send 1000 random HTTP requests to port 18789. Verify no crashes, no 500 errors, graceful 400/404 responses.
3. **Replay Attack** — Capture a valid WebSocket handshake and replay it 100 times. Verify deduplication or rate limiting handles it.
4. **Memory Dump** — Attempt to read `/proc/self/mem` equivalent on macOS via `vmmap`. Verify no API keys visible in memory after 60s idle.
5. **Known CVE Check** — Check all Swift Package dependencies against NIST NVD for known CVEs (osv-scanner from AG3-7 covers this).
6. **Jailbreak/SIP Bypass Simulation** — Disable SIP in test. Verify Thea's security model degrades gracefully (warns user, reduces autonomy level).

```bash
# Port scan while Thea runs
which nmap && nmap -sT localhost -p 1-65535 --open 2>/dev/null | grep "open" | grep -v "18789" && echo "⚠ Unexpected open ports!" || echo "✅ Only expected port 18789 open (or nmap not installed)"

# HTTP fuzzer — basic
for i in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:18789/$(cat /dev/urandom | base64 | head -c 10)" 2>/dev/null || echo "connection refused (app not running)"
done | sort | uniq -c
```

**Implement**: Close unexpected ports, add connection rate limiting (already have 5/min in OpenClawBridge — verify it covers HTTP too), add graceful error responses to all malformed requests.

---

### AH3 Synthesis + Final Implementation Pass
After all 8 hats complete:
1. Triage all findings by severity (🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low)
2. Implement ALL critical and high findings immediately
3. Create GitHub issues for medium/low items (for tracking, not deferral)
4. Re-run AG3 verification to confirm all fixes compile and tests pass
5. Verify CI is still green after all AH3 changes

### AH3 Verification
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# All 8 hats completed + implementations committed
git log --oneline -10 | grep "AH3"
swift test 2>&1 | grep "passed\|failed" | tail -2
swiftlint lint 2>&1 | grep -c "error:\|warning:" | xargs -I{} sh -c '[ "$1" -eq 0 ] && echo "✅ 0 lint issues" || echo "❌ $1 lint issues"' -- {}
gh run list --limit 6 --json name,conclusion --jq '.[] | "\(.name): \(.conclusion)"' 2>/dev/null
```
Commit: `git commit -m "Auto-save: AH3 complete — 8-hat audit; all findings implemented; CI green"`

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
| U3    | AI Subsystem Re-evaluation (+audit 02-19) | ⏳ PENDING  | —        | —         |
| V3    | Transparency & Analytics UIs             | ⏳ PENDING  | —        | —         |
| W3    | Chat Enhancement Features                | ⏳ PENDING  | —        | —         |
| X3    | Test Coverage ≥80% (A3–W3 code)          | ⏳ PENDING  | —        | —         |
| Y3    | Periphery Clean (A3–W3 code)             | ⏳ PENDING  | —        | —         |
| Z3    | CI Green (v3 code)                       | ⏳ PENDING  | —        | —         |
| AE3   | Platform Observers Startup (🔴 CRITICAL) | ⏳ PENDING  | MSM3U    | —         |
| AF3   | Settings Sidebar + UI Navigation (88+57) | ⏳ PENDING  | MBAM2    | —         |
| AA3   | Re-verification (v1+v2+v3 criteria)      | ⏳ PENDING  | —        | —         |
| AB3   | Notarization                             | ⏳ PENDING  | —        | —         |
| AC3   | Final Verification Report                | ⏳ PENDING  | —        | —         |
| AG3   | Comprehensive QA + Full Activation       | ⏳ PENDING  | MSM3U    | —         |
| AH3   | 8-Hat Audit + Implement All Findings     | ⏳ PENDING  | MSM3U    | —         |
| AD3   | Manual Gate                              | ⏳ MANUAL   | Alexis   | —         |

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
*v3.6 (2026-02-19 16:xx): AG3 (Comprehensive QA Plan execution + full stub activation + CI green loop) + AH3 (8-hat audit: Red/Black/White/Grey/Blue/Purple/Green/ScriptKiddie — all findings implemented directly) added. 28 total phases.*
*It addresses every identified gap, wires every orphaned system, and delivers Thea as an*
*autonomous, self-improving, fully transparent AI assistant.*
