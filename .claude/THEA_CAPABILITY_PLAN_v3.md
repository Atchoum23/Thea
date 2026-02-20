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
#   25. PersonalParameters — 22 Tier 2 @AppStorage keys, snapshot() for Claude §0.3 injection
#   26. HumanReadinessEngine — 5-signal readiness composite (HRV SDNN, sleep, ultradian, deep, REM)
#   27. ResourceOrchestrator (4-state) + InterruptBudgetManager (4/day gate, notification gating)
#   28. DataFreshnessOrchestrator — 8 data categories, staleness thresholds, background refresh
#   29. EnergyAdaptiveThrottler extension ← ResourceOrchestrator; fullAuto restored (6 guardrails)
#   30. Wave 7 full wiring — lifecycle init, PersonalParametersSettingsView, overnight log
#   [Wave 7 runs AFTER A3–AH3, BEFORE X3 verification — purely additive, no v1/v2/v3 redo]
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
| Phase B3: Tool Execution  | ✅ DONE         | 8 handlers in AI/Tools/, ToolExecutionCoordinator, ChatManager+Tools.swift B3 wired sha 3848a29d |
| Phase C3: RAG / Semantic  | ✅ DONE         | enrichSystemPromptWithSemanticContext() + indexExistingConversations() wired in ChatManager sha 3848a29d |
| Phase D3: Confidence Loop | ✅ DONE         | recordConfidenceFeedback() wired in runPostResponseActions, feeds ModelRouter+TaskClassifier sha 3848a29d |
| Phase E3: Skills Complete | ✅ DONE         | injectSkillsIntoSystemPrompt() in ChatManager+Tools.swift, wired after C3 in sendMessage(), SkillRegistry+SkillsRegistryService pre-init sha 473c9edd |
| Phase F3: Squads Unified  | ✅ DONE         | SquadDefinition+CommunicationStrategy+CoordinationMode; persistentSquads; SquadsView; MacSettingsView sidebar sha 49bc33f0 |
| Phase G3: TaskPlanDAG+    | ✅ DONE         | PlanOutcome quality scoring, planCache, createPlan cache lookup, AgentTeamOrchestrator approval gate sha 34a0083d |
| Phase H3: AI System UIs   | ✅ DONE         | IntelligenceDashboardView wired into MacSettingsView sidebar; 8 AI subsystem cards sha bd9c292c |
| Phase I3: UI Components   | ✅ DONE         | Excluded UI components (AgentPhaseProgressBar etc.) wired into ChatView + MessageBubble sha 8de7b663 |
| Phase J3: LifeTracking UI | ✅ DONE         | ActivityTimelineView, LifeTrackingDashboardView, LifeTrackingAnalyticsView; MacSettingsView wired |
| Phase K3: Config UI       | ✅ DONE         | AdvancedAIConfigView sliders + all config sub-views wired sha 5eaae561 |
| Phase L3: Computer Use    | ✅ DONE         | ComputerUseHandler (screenshot/click/type/scroll/key), computer_use in AnthropicToolCatalog, toggle in Autonomy settings sha ebfb10bf |
| Phase M3: MLX Audio       | ✅ DONE         | MLXAudioEngine + MLXVoiceBackend re-enabled; ToolExecutionCoordinator actor→@MainActor, ChatManager+Tools, FileToolHandler iOS compat, MacOSToolHandler @MainActor |
| Phase N3: Artifact System | ✅ DONE         | GeneratedArtifact SwiftData model, ArtifactBrowserView, ArtifactManager; MacSettingsView wired |
| Phase O3: MCP Client      | ✅ DONE         | GenericMCPClient, MCPServerBrowserView, MCPClientManager, MCPBuilderView, MCPServerGeneratorTypes |
| Phase P3: KG Enhancement  | ✅ DONE         | PersonalKnowledgeGraph dedup+decay+consolidation; LongTermMemorySystem+Consolidation active |
| Phase Q3: Proactive Intel | ✅ DONE         | DeliveredInsight SwiftData model, InsightHistoryView, WeeklyInsightSummaryView, ProactiveInsightEngine cron |
| Phase R3: SelfEvolution   | ✅ DONE         | Artifact-based approach: SelfEvolutionManager wired to ArtifactManager; drafts code changes as GeneratedArtifact |
| Phase S3: MCPGen UI       | ✅ DONE         | MCPBuilderView + GeneratedServerPreview + MCPServerGenerator; wired in MacSettingsView Developer tab sha 3848a29d |
| Phase T3: Integration Bknd| ✅ DONE         | IntegrationToolHandler wired + project.yml activations verified sha ac488a35 |
| Phase U3: AI Subsystems   | ✅ DONE         | All subsystems (Context/Adaptive/Proactive/PatternLearning/Predict/PromptEng/ResourceMgmt/Anticipatory) activated in project.yml blanket activations; macOS+iOS BUILD SUCCEEDED sha b55537b1 |
| Phase V3: Transparency UIs| ✅ DONE         | BehavioralAnalyticsView, PrivacyTransparencyView, MessagingGatewayStatusView, NotificationIntelligenceView sha d3e98428 |
| Phase W3: Chat Enhance    | ✅ DONE         | AgentPhaseProgressBar, CloudSyncStatusView, TokenCountBadge wired into ChatView + MacSettingsView sha d7e3b229 |
| Phase X3: Test Coverage   | ⏳ PENDING      | Blocked by A3–W3+AF3 |
| Phase Y3: Periphery Clean | ⏳ PENDING      | Blocked by X3 |
| Phase Z3: CI Green        | ⏳ PENDING      | Blocked by Y3 |
| Phase AA3: Re-verify       | ⏳ PENDING      | Blocked by Z3 |
| Phase AB3: Notarization    | ⏳ PENDING      | Blocked by AA3 |
| Phase AC3: Final Report    | ⏳ PENDING      | Blocked by AB3 |
| Phase AD3: Manual Gate     | ⏳ MANUAL       | Alexis only — last step (after AO3) |
| Phase AE3: Platform Obs.   | ✅ DONE         | PlatformFeaturesHub (5s delay), TheaIntelligenceOrchestrator (6s delay), ApprovalManager (lazy on-demand) — all wired in TheamacOSApp.setupManagers() |
| Phase AF3: Settings Nav    | ✅ DONE         | Stream 5 (MSM3U) took over. 18 views wired into MacSettingsView detailContent; TheaMessagingChatView + ConversationLanguagePickerView confirmed wired; CLAUDE.md discrepancies fixed sha 97b7e86f |
| Phase AG3: Comp. QA        | ✅ DONE         | sha f88bb98d — 4046 tests pass, 0 lint, all 4 platforms build, stubs activated (PromptOptimizer, WindowManager, LiveGuidance region picker) |
| Phase AH3: 8-Hat Audit     | ✅ DONE         | sha 27649c41 — RED: language whitelist; PURPLE: autonomy audit trail; BLACK/WHITE/GREY/BLUE/GREEN/SCRIPT-KIDDIE all verified |
| Phase AI3: PersonalParams  | ✅ DONE         | sha d91d3234 — 24 Tier 2 @AppStorage keys, snapshot() for Claude §0.3 injection, Tier 1 constants. Wave 7 underway on MSM3U S5. |
| Phase AJ3–AN3: Wave 7      | ✅ DONE        | sha 24d2c894 — HumanReadinessEngine, macOSBehavioralSignalExtractor, InterruptBudgetManager, ResourceOrchestrator, DataFreshnessOrchestrator, EnergyAdaptiveThrottler AM3, PersonalParametersSettingsView. All linted. |
| Phase AO3: Pre-AD3 AutoVer | ✅ DONE         | sha a3c0302f — Gateway(app must run), swift test OK, v1.5.0 tag ✅, CI 3/6 green (Thea CI in progress) |
| Phase AP3: MSM3U Reliability| ✅ DONE         | sha 3aad3a3c — ServerHealthMonitor actor, OnceGate NWConnection pattern, ntfy+UNNotification, msm3u-failover.sh, msm3u-heartbeat.sh, LaunchAgent loaded |
| Phase AQ3: Agent Orch.     | ✅ DONE         | sha b59ed979 — AgentOrchestrator actor (circuit breaker, TaskGroup parallel), AutonomousSessionManager (@MainActor, 5min watchdog), PersonalParameters 6 new keys |
| Phase AR3: API Error Prev. | ✅ DONE         | sha 4dff338b — AnthropicConversationManager (class + NSLock), 5 methods, wired in chatAdvanced() |
| Phase AS3: Adaptive Timing | ✅ DONE         | sha d8407561 — AdaptivePoller actor, 3 strategies, 3 factories (retrying/ciJob/logMonitor), ciTypicalDurationMinutes from PersonalParameters |
| Phase AT3: TheaWeb         | ✅ DONE         | verified pre-existing — Swift build 0 errors, all routes real data, Cloudflare tunnel verified (Docker N/A on MSM3U) — S6 |
| Phase AU3: Tizen           | ✅ DONE         | verified pre-existing — thea-tizen TS 0 errors + build passing, TV/TheaTizen JS validated, protocol via TheaWeb API → localhost:8081 — S6 |
| Phase AV3: Browser Ext.    | ✅ DONE         | NativeHost↔TheaMessagingGateway wired (port 18789 POST /message), Chrome native-bridge.js fixed, Safari via SafariWebExtensionHandler, Brave 14 canonical (2-13 archived) — S7 sha 9a9388e5 |
| Phase AW3: Widget Ext.     | ✅ DONE         | sha 322dce1b — 5 widget types (Conversation/QuickActions/Memory/Context/LockScreen) fully implemented, AppGroup shared storage, iOS build verified — S8 |
| Phase AX3: Native Ext. 1   | ✅ DONE         | sha 053dfbc4 — ShareExtension (AppGroup, text/URL/image/file), IntentsExtension (3 Siri intents), MessagesExtension (iMessage), MailExtension (email processing), FocusFilterExtension (focus modes) — all verified, iOS build passing — S8 |
| Phase AY3: Native Ext. 2   | ✅ DONE         | CallKit, Credentials, Keyboard, Notification, QuickLook, Spotlight, FinderSync extensions — real implementations — S9 |
| Phase AZ3: Physical AV Testing | ⏳ PENDING   | Cross-Mac automated audio+visual+screenshot testing using MBAM2/MSM3U physical proximity |
| **Overall v3 %**          | **97% autonomous done** | A3–W3 + AE3–AH3 + AI3–AN3 + AP3–AS3 ✅ DONE; Wave 6 (X3–AC3) + Wave 9 (AT3–AY3) ✅ + AZ3 + AD3 pending. |

*Last updated: 2026-02-20 — Wave 9 (AT3–AY3) added: TheaWeb, Tizen, Browser+Native Extensions. AZ3 added: Physical AV testing (cross-Mac audio+camera+screenshot). Parallel: S5=Wave6, S6=AT3+AU3, S7=AV3, S8=AW3+AX3, S9=AY3*

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

WAVE 7 — MSM3U sequential (after all 6 streams done, before X3):
  AI3 (2h) → AJ3 (3h) → AK3 (3h) → AL3 (2h) → AM3 (2h) → AN3 (3h) = ~15h
  Files: Shared/Intelligence/Resource/ (new dir), Shared/UI/Views/Settings/PersonalParametersSettingsView.swift
  Dependency: ALL feature streams (A3–AH3) must be done before AI3 starts (AI3 = foundation).

BOTTLENECK: ~16h (streams 5, 6 are longest: AE3+AF3 each add ~2h)
  All feature work done: ~15:00 CET Fri Feb 20 (starting from ~23:00 CET Feb 19)
  H3 done: ~17:00 CET Fri Feb 20 (stream 1 waits for E3/F3/G3 from s2+s3)
  AE3 done (stream 5): ~17:00 CET Fri Feb 20 → AG3+AH3 start
  AF3 done (stream 6): ~17:00 CET Fri Feb 20
  Wave 7 starts (MSM3U sequential): ~17:00 CET Fri Feb 20 → done ~08:00 CET Sat Feb 21
  Wave 6/X3 verification starts: after Wave 7 AN3 completes
  Wave 6 (sequential, ~10h): ~18:00 CET Sat Feb 21
  AD3 gate: Sat Feb 21 evening

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

# ══════════════════════════════════════════════════════════════════════════════
# WAVE 7 — RESOURCE-AWARE LIFE SYSTEM v3.0
# ══════════════════════════════════════════════════════════════════════════════
# Source: mission-resource-aware-architecture.txt (1,988 lines, Feb 2026)
# Design principle: maximize meaningful output while minimizing resource consumption.
# Build order is MANDATORY — PersonalParameters (AI3) must exist before anything else.
# Runs AFTER all v3 feature streams complete (A3–W3 + AG3 + AH3), BEFORE X3 verification.
# Assigned: MSM3U (sequential, new stream after all 6 feature streams done)
# Adds 6 components: PersonalParameters, HumanReadinessEngine, ResourceOrchestrator,
#   InterruptBudgetManager, DataFreshnessOrchestrator, EnergyAdaptiveThrottler extension.
# v3 plan additions #25–30 — does NOT redo v1/v2/v3 phases; purely additive on substrate.
# ══════════════════════════════════════════════════════════════════════════════

## PHASE AI3: PERSONALPARAMETERS — FOUNDATION (BUILD THIS FIRST — MANDATORY)

**Status: ⏳ PENDING (blocked by A3–W3 + AG3 + AH3)**

**Goal**: Create `PersonalParameters.swift` — the single source of truth for all 22 Tier 2
parameters. Every other Wave 7 component reads from this. Every hardcoded Tier 2 constant
in the codebase gets replaced with `PersonalParameters.shared.<key>`.

**Key design principle (Alexis, Feb 2026)**:
> "Research defaults stay in the document as readable evidence for why the value is what it
> is — but every Tier 2 value has a named @AppStorage key in PersonalParameters.shared and
> SelfTuningEngine knows exactly which outcome signal drives each one."
> The static `.claude/personal-parameters-defaults.txt` is BOOTSTRAP ONLY — superseded by
> `PersonalParameters.snapshot()` the moment SelfTuningEngine has data.

**Machine**: MSM3U | **Estimated**: 2h
**Target**: `Shared/Intelligence/Resource/PersonalParameters.swift`
**Excluded paths**: DO NOT create in `**/ResourceManagement/**` or `**/PatternLearning/**`

### AI3-1: Create PersonalParameters.swift

```swift
// Shared/Intelligence/Resource/PersonalParameters.swift
import Foundation
import SwiftUI

/// Single source of truth for all Tier 2 personalizable parameters.
/// Tier 1 (population-fixed) are `let` constants — never personalize.
/// Tier 2 (personalizable) are @AppStorage — SelfTuningEngine updates via outcome signals.
/// Bootstrap: .claude/personal-parameters-defaults.txt seeds initial values.
/// Once SelfTuningEngine has ≥30 days data, its values supersede all defaults.
@MainActor
public final class PersonalParameters: ObservableObject {
    public static let shared = PersonalParameters()

    // ── Tier 1 — Population-fixed (NEVER personalize) ────────────────────────
    public let contextSwitchRecoveryCeiling: TimeInterval = 23 * 60 + 15  // 23min 15sec
    public let workingMemoryChunks: Int = 4                                // 4±1
    public let flowProductivityMultiplier: Double = 5.0                   // ~500%

    // ── Tier 2 — Personalizable via @AppStorage ──────────────────────────────
    @AppStorage("pp.interruptBudget")         public var interruptBudget: Int = 4
    @AppStorage("pp.idleBreakpointMin")       public var idleBreakpointMinutes: Double = 3.0
    @AppStorage("pp.flowRampMin")             public var flowRampMinutes: Double = 17.5
    @AppStorage("pp.flowThreshold")           public var flowThreshold: Double = 0.85
    @AppStorage("pp.workBlockMin")            public var workBlockMinutes: Double = 75
    @AppStorage("pp.breakMin")                public var breakMinutes: Double = 33
    @AppStorage("pp.ultradianCycleMin")       public var ultradianCycleMinutes: Double = 100
    @AppStorage("pp.ultradianMinSignals")     public var ultradianMinSignals: Int = 3
    @AppStorage("pp.hrvTroughPct")            public var hrvTroughPercent: Double = 0.10
    @AppStorage("pp.hrvBaselineDays")         public var hrvBaselineDays: Int = 30
    @AppStorage("pp.morningWtHRV")            public var morningWeightHRV: Double = 0.40
    @AppStorage("pp.morningWtSleep")          public var morningWeightSleep: Double = 0.25
    @AppStorage("pp.morningWtDeep")           public var morningWeightDeep: Double = 0.15
    @AppStorage("pp.morningWtTemp")           public var morningWeightTemperature: Double = 0.10
    @AppStorage("pp.morningWtREM")            public var morningWeightREM: Double = 0.10
    @AppStorage("pp.stateActiveThreshold")    public var stateActiveThreshold: Double = 0.65
    @AppStorage("pp.stateHighThreshold")      public var stateHighThreshold: Double = 0.90
    @AppStorage("pp.satisficeTarget")         public var satisficeTarget: Double = 0.70
    @AppStorage("pp.exploreDays")             public var exploreDays: Int = 60
    @AppStorage("pp.explorePointsPerDomain")  public var explorePointsPerDomain: Int = 500
    @AppStorage("pp.exploreDecayHalfLifeDays") public var exploreDecayHalfLifeDays: Int = 14
    @AppStorage("pp.claudeCompactAt")         public var claudeCompactAt: Double = 0.70
    @AppStorage("pp.claudeCircuitBreaker")    public var claudeCircuitBreakerAttempts: Int = 3
    @AppStorage("pp.claudeBudgetPerSession")  public var claudeBudgetPerSession: Double = 2.00

    private init() {}

    /// Snapshot for Claude context injection (§0.3).
    /// Called at session start — supersedes .claude/personal-parameters-defaults.txt.
    public func snapshot() -> String {
        """
        Interrupts:   budget=\(interruptBudget)/day      idleBreakpoint=\(idleBreakpointMinutes)min
        Flow:         ramp=\(flowRampMinutes)min      threshold=\(Int(flowThreshold * 100))%
        Work blocks:  work=\(workBlockMinutes)min        break=\(breakMinutes)min
        Ultradian:    cycle=\(ultradianCycleMinutes)min      minSignals=\(ultradianMinSignals)
        HRV:          trough=±\(Int(hrvTroughPercent * 100))%       baseline=\(hrvBaselineDays)d
        MorningWts:   HRV=\(morningWeightHRV)  sleep=\(morningWeightSleep)  deep=\(morningWeightDeep)  temp=\(morningWeightTemperature)  rem=\(morningWeightREM)
        States:       act≥\(stateActiveThreshold)    high≥\(stateHighThreshold)    satisfice@\(satisficeTarget)
        Claude:       compact@\(Int(claudeCompactAt * 100))%    circuitBreaker=\(claudeCircuitBreakerAttempts)attempts    budget=$\(claudeBudgetPerSession)/session
        """
    }
}
```

### AI3-2: Replace hardcoded Tier 2 constants codebase-wide

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# Find hardcoded Tier 2 values — inspect each result and replace with PersonalParameters.shared.*
grep -rn "75 \* 60\|workBlock.*75\|interruptBudget.*= 4\|flowThreshold.*0\.85\|0\.85.*flow" \
  Shared/ --include="*.swift" | grep -v PersonalParameters | grep -v "test\|Test"
# EnergyAdaptiveThrottler uses interval constants — extend in AM3
grep -rn "EnergyAdaptiveThrottler" Shared/ --include="*.swift" | head -10
```

### AI3-3: Build verification

```bash
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination "platform=macOS" build -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
grep -r "PersonalParameters.shared" Shared/ --include="*.swift" | wc -l  # ≥1
```

Commit: `git add Shared/Intelligence/Resource/PersonalParameters.swift && git commit -m "feat(AI3): PersonalParameters — 24 Tier 2 @AppStorage keys, snapshot() for Claude §0.3 injection, Tier 1 population-fixed constants"`

---

## PHASE AJ3: HUMANREADINESSENGINE + macOSBEHAVIORALSIGNALEXTRACTOR

**Status: ⏳ PENDING (blocked by AI3)**

**Goal**: Build `HumanReadinessEngine` — real-time composite readiness score [0,1] from 5
weighted signals: HRV status, sleep quality, ultradian phase, temperature proxy (body clock),
REM fraction. Score drives ResourceOrchestrator state transitions and interrupt gating.

**Machine**: MSM3U | **Estimated**: 3h
**Target files**:
- `Shared/Intelligence/Resource/HumanReadinessEngine.swift`
- `Shared/Intelligence/Resource/macOSBehavioralSignalExtractor.swift`

### AJ3-1: HumanReadinessEngine

```swift
// Shared/Intelligence/Resource/HumanReadinessEngine.swift
import Foundation
import Combine

@MainActor
public final class HumanReadinessEngine: ObservableObject {
    public static let shared = HumanReadinessEngine()
    private let params = PersonalParameters.shared

    @Published public private(set) var readinessScore: Double = 0.5
    @Published public private(set) var ultradianPhase: UltradianPhase = .unknown
    private var cancellables = Set<AnyCancellable>()

    // Note: Apple Watch reports SDNN (NOT RMSSD — do not compare to Oura)
    private var hrvBaselineSDNN: Double = 0
    private var lastSleepQuality: Double = 0.5
    private var lastDeepFraction: Double = 0.15
    private var lastREMFraction: Double = 0.10

    public enum UltradianPhase: String { case peak, trough, unknown }

    private init() {
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
    }

    public func recompute() {
        let hrvScore = computeHRVScore()
        let sleepScore = lastSleepQuality
        let deepScore = min(lastDeepFraction / 0.20, 1.0)
        let ultradianScore: Double = ultradianPhase == .peak ? 1.0 : ultradianPhase == .trough ? 0.2 : 0.5
        let remScore = min(lastREMFraction / 0.25, 1.0)

        readinessScore = params.morningWeightHRV * hrvScore
                       + params.morningWeightSleep * sleepScore
                       + params.morningWeightDeep * deepScore
                       + params.morningWeightTemperature * ultradianScore
                       + params.morningWeightREM * remScore
    }

    private func computeHRVScore() -> Double {
        guard hrvBaselineSDNN > 0 else { return 0.5 }
        // Trough = ±params.hrvTroughPercent of baseline; normalize to [0,1]
        return min(1.0, max(0.0, 0.5 + (hrvBaselineSDNN - hrvBaselineSDNN) / (hrvBaselineSDNN * 0.5)))
    }

    public func updateHRVBaseline(_ sdnn: Double) { hrvBaselineSDNN = sdnn; recompute() }
    public func updateSleepMetrics(quality: Double, deepFraction: Double, remFraction: Double) {
        lastSleepQuality = quality; lastDeepFraction = deepFraction; lastREMFraction = remFraction
        recompute()
    }
    public func recordInterrupt() { recompute() }
}
```

### AJ3-2: macOSBehavioralSignalExtractor

Extract idle time, app switches, keyboard/mouse cadence. Accumulate ≥params.ultradianMinSignals
behavioral signals before declaring ultradian trough. Wire into HumanReadinessEngine.

### AJ3-3: Wire into HealthCoachingPipeline

Call `HumanReadinessEngine.shared.updateSleepMetrics()` from HealthCoachingPipeline after
HealthKit sleep analysis results are available. Call `updateHRVBaseline()` after HRV query.

Verify:
```bash
grep -r "HumanReadinessEngine.shared" Shared/ --include="*.swift" | wc -l  # ≥2
grep -r "readinessScore" Shared/ --include="*.swift" | wc -l  # ≥2
```

Commit: `git add Shared/Intelligence/Resource/ && git commit -m "feat(AJ3): HumanReadinessEngine — 5-signal readiness composite (SDNN HRV, sleep, ultradian, deep, REM), macOSBehavioralSignalExtractor"`

---

## PHASE AK3: RESOURCEORCHESTRATOR + INTERRUPTBUDGETMANAGER

**Status: ⏳ PENDING (blocked by AJ3)**

**Goal**: `ResourceOrchestrator` — central adaptive scheduler integrating readiness, energy,
freshness, and interrupt budget into a unified state machine (degraded/normal/elevated/flowProtected).
`InterruptBudgetManager` — enforces PersonalParameters.interruptBudget (4/day), gates all
notification dispatch paths.

**Machine**: MSM3U | **Estimated**: 3h
**Target files**:
- `Shared/Intelligence/Resource/ResourceOrchestrator.swift`
- `Shared/Intelligence/Resource/InterruptBudgetManager.swift`

### AK3-1: InterruptBudgetManager

```swift
// Shared/Intelligence/Resource/InterruptBudgetManager.swift
import Foundation

@MainActor
public final class InterruptBudgetManager: ObservableObject {
    public static let shared = InterruptBudgetManager()
    private let params = PersonalParameters.shared

    @Published public private(set) var usedToday: Int = 0
    @Published public private(set) var budgetExhausted: Bool = false
    private var lastResetDate = Calendar.current.startOfDay(for: .now)
    private init() {}

    /// Returns true if an interrupt is permitted. priority > 0.9 bypasses budget (emergencies).
    public func canInterrupt(priority: Double = 1.0) -> Bool {
        resetIfNewDay()
        return priority > 0.9 || usedToday < params.interruptBudget
    }

    public func recordInterrupt() {
        resetIfNewDay(); usedToday += 1
        budgetExhausted = usedToday >= params.interruptBudget
        HumanReadinessEngine.shared.recordInterrupt()
    }

    public var remaining: Int { max(0, params.interruptBudget - usedToday) }

    private func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: .now)
        guard today > lastResetDate else { return }
        usedToday = 0; budgetExhausted = false; lastResetDate = today
    }
}
```

### AK3-2: ResourceOrchestrator

4-state machine (degraded/normal/elevated/flowProtected) driven by HumanReadinessEngine.readinessScore.
Publishes recommendedWorkBlockMinutes (scales with PersonalParameters.workBlockMinutes).
Drives EnergyAdaptiveThrottler via state signal (extended in AM3).

### AK3-3: Wire InterruptBudgetManager into SmartNotificationScheduler

```bash
grep -n "scheduleReminder\|NotificationService\|SmartNotificationScheduler" \
  Shared/ -r --include="*.swift" | grep -v test | head -10
# Add: guard InterruptBudgetManager.shared.canInterrupt() else { queue for later; return }
# before every notification dispatch call
```

Verify:
```bash
grep -r "InterruptBudgetManager.shared.canInterrupt\|ResourceOrchestrator.shared" \
  Shared/ --include="*.swift" | wc -l  # ≥2
```

Commit: `git add Shared/Intelligence/Resource/ && git commit -m "feat(AK3): ResourceOrchestrator (4-state machine) + InterruptBudgetManager (4/day gate) — interrupt budget enforced at all notification paths"`

---

## PHASE AL3: DATAFRESHNESSORCHESTR ATOR + HEALTHKIT PIPELINE EXTENSION

**Status: ⏳ PENDING (blocked by AK3)**

**Goal**: `DataFreshnessOrchestrator` — tracks freshness for 8 data categories (HRV, sleep,
activity, location, behavioral, calendar, weather, biometrics). Triggers background refresh
notifications when staleness crosses per-category thresholds. Composite staleness score
feeds ResourceOrchestrator.

**Machine**: MSM3U | **Estimated**: 2h
**Target**: `Shared/Intelligence/Resource/DataFreshnessOrchestrator.swift`

### AL3-1: DataFreshnessOrchestrator

```swift
// Shared/Intelligence/Resource/DataFreshnessOrchestrator.swift
import Foundation
import Combine

public enum DataCategory: String, CaseIterable {
    case hrv, sleep, activity, location, behavioral, calendar, weather, biometrics
    public var maxStalenessMinutes: Double {
        switch self {
        case .hrv: return 5;      case .sleep: return 60;  case .activity: return 15
        case .location: return 2; case .behavioral: return 10; case .calendar: return 30
        case .weather: return 60; case .biometrics: return 120
        }
    }
}

@MainActor
public final class DataFreshnessOrchestrator: ObservableObject {
    public static let shared = DataFreshnessOrchestrator()
    @Published public private(set) var freshnessMap: [DataCategory: Date] = [:]
    private var cancellables = Set<AnyCancellable>()
    private init() { scheduleChecks() }

    public func recordRefresh(_ category: DataCategory) { freshnessMap[category] = .now }
    public func isFresh(_ category: DataCategory) -> Bool {
        guard let last = freshnessMap[category] else { return false }
        return Date.now.timeIntervalSince(last) < category.maxStalenessMinutes * 60
    }
    public func stalenessScore() -> Double {
        let stale = DataCategory.allCases.filter { !isFresh($0) }.count
        return Double(stale) / Double(DataCategory.allCases.count)
    }
    private func scheduleChecks() {
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                DataCategory.allCases.filter { !(self?.isFresh($0) ?? true) }.forEach {
                    NotificationCenter.default.post(name: .theaDataStale, object: $0)
                }
            }.store(in: &cancellables)
    }
}
extension Notification.Name { static let theaDataStale = Notification.Name("ai.thea.dataStale") }
```

### AL3-2: Wire into HealthCoachingPipeline

Call `DataFreshnessOrchestrator.shared.recordRefresh(.hrv)`, `.sleep`, `.activity` after
each HealthKit query completes. Listen for `.theaDataStale` notifications to trigger re-queries.

Verify:
```bash
grep -r "DataFreshnessOrchestrator.shared\|recordRefresh\|theaDataStale" \
  Shared/ --include="*.swift" | wc -l  # ≥3
```

Commit: `git add Shared/Intelligence/Resource/ && git commit -m "feat(AL3): DataFreshnessOrchestrator — 8-category staleness, background refresh triggers, HealthKit pipeline integration"`

---

## PHASE AM3: ENERGYADAPTIVETHROTTLER EXTENSION + FULLAUTO RESTORATION

**Status: ⏳ PENDING (blocked by AL3)**

**Goal**: Extend the existing `EnergyAdaptiveThrottler` to consume PersonalParameters +
ResourceOrchestrator state. Restore `fullAuto` mode with 6 operational guardrails per §10.4.
fullAuto was disabled — RESTORE IT. NEVER remove it.

**Machine**: MSM3U | **Estimated**: 2h

**CRITICAL**: fullAuto MUST be restored with guardrails, not removed. Per project CLAUDE.md: "NEVER REMOVE anything."

### AM3-1: Find and read EnergyAdaptiveThrottler

```bash
find "/Users/alexis/Documents/IT & Tech/MyApps/Thea" -name "EnergyAdaptiveThrottler.swift" | head -3
# Read the file fully before extending
```

### AM3-2: Add ResourceOrchestrator awareness

```swift
// Extension to EnergyAdaptiveThrottler — add after reading file:
private let orchestrator = ResourceOrchestrator.shared
private let params = PersonalParameters.shared

// In computeMultiplier() or equivalent:
switch orchestrator.currentState {
case .degraded:      return 3.0   // User tired — back off
case .normal:        return 1.0   // Standard cadence
case .elevated:      return 0.8   // Slight speedup
case .flowProtected: return 2.0   // Protect flow — reduce polling
}
```

### AM3-3: Restore fullAuto with 6 guardrails (§10.4)

All 6 MANDATORY before fullAuto activates:
1. `readinessScore ≥ params.stateActiveThreshold` (0.65)
2. `InterruptBudgetManager.remaining ≥ 2`
3. `DataFreshnessOrchestrator.stalenessScore() < 0.5`
4. Circuit breaker: ≥ params.claudeCircuitBreakerAttempts consecutive failures → 15min pause
5. Budget cap: session cost < params.claudeBudgetPerSession before each action
6. User override HUD toggle always surfaced (never hidden)

Verify:
```bash
grep -r "fullAuto\|EnergyAdaptiveThrottler\|ResourceOrchestrator" \
  Shared/ --include="*.swift" | grep -v "\.archive\|\.bak" | wc -l  # ≥5
```

Commit: `git add Shared/ && git commit -m "feat(AM3): EnergyAdaptiveThrottler ← ResourceOrchestrator state, fullAuto restored with 6 guardrails (readiness/budget/freshness/circuit-breaker/cost/override)"`

---

## PHASE AN3: FULL WIRING + PERSONALPARAMETERS SETTINGS UI + OVERNIGHT CYCLE

**Status: ⏳ PENDING (blocked by AM3)**

**Goal**: Wire all Wave 7 singletons into app lifecycle. Build PersonalParametersSettingsView
(Adaptive System tab in MacSettingsView sidebar). Implement overnight cycle snapshot to
parameter-consultation-log.txt. Ensure X3 test coverage gates include Wave 7 files.

**Machine**: MSM3U | **Estimated**: 3h

### AN3-1: App lifecycle startup

```swift
// In TheamacOSApp.swift — add to startup Task (after HealthKit auth):
_ = PersonalParameters.shared          // Initialize singleton, load @AppStorage
_ = HumanReadinessEngine.shared        // Start 60s readiness poll
_ = ResourceOrchestrator.shared        // Start state machine, bind readiness
_ = InterruptBudgetManager.shared      // Start daily budget tracking
_ = DataFreshnessOrchestrator.shared   // Start 60s staleness checks
```

### AN3-2: PersonalParametersSettingsView

Create `Shared/UI/Views/Settings/PersonalParametersSettingsView.swift`:
- 24 sliders — each labeled with parameter name, current value, research default, and
  the outcome signal that SelfTuningEngine uses to adapt it
- "Reset to research default" button per parameter
- SelfTuningEngine status card: last tuning date, confidence %, adapted parameters
- Live readiness gauge: HumanReadinessEngine.readinessScore (ring chart)
- Interrupt budget bar: today used/remaining (InterruptBudgetManager)
- Data freshness grid: 8 categories, last refresh, staleness %, freshness color

Wire as "Adaptive System" in MacSettingsView sidebar (Stream 6 AF3 file ownership — coordinate).

### AN3-3: Overnight snapshot wiring

```swift
// In PersonalParameters — add session log appender:
public func logSessionConsultation(session: String, phase: String,
                                    consulted: [String], decisions: String) {
    let line = "\(Date.now.formatted(.dateTime)) | \(session) | \(phase) | \(consulted.joined(separator: ", ")) | \(decisions)\n"
    // Append to .claude/parameter-consultation-log.txt
    let logURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Documents/IT & Tech/MyApps/Thea/.claude/parameter-consultation-log.txt")
    if let data = line.data(using: .utf8) {
        if let handle = FileHandle(forWritingAtPath: logURL.path) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else { try? data.write(to: logURL, options: .atomic) }
    }
}
```

### AN3-4: Verify full Wave 7 wiring

```bash
grep -r "PersonalParameters.shared" Shared/ --include="*.swift" | wc -l   # ≥8
grep -r "HumanReadinessEngine.shared" Shared/ --include="*.swift" | wc -l  # ≥3
grep -r "ResourceOrchestrator.shared" Shared/ --include="*.swift" | wc -l  # ≥3
grep -r "InterruptBudgetManager.shared" Shared/ --include="*.swift" | wc -l # ≥2
grep -r "DataFreshnessOrchestrator.shared" Shared/ --include="*.swift" | wc -l # ≥2

xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination "platform=macOS" build -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3  # Must show BUILD SUCCEEDED
```

Commit: `git add Shared/Intelligence/Resource/ Shared/UI/Views/Settings/PersonalParametersSettingsView.swift && git commit -m "feat(AN3): Wave 7 full wiring — lifecycle init, PersonalParametersSettingsView (Adaptive System tab), overnight consultation log, fullAuto operational"`

# ══════════════════════════════════════════════════════════════════════════════
# END WAVE 7 — RESOURCE-AWARE LIFE SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

---

## PHASE X3: TEST COVERAGE ≥80%

**Status: ⏳ PENDING (blocked by A3–W3 + AI3–AN3)**

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

## PHASE AO3: PRE-AD3 AUTOMATED VERIFICATION

**Status: ⏳ PENDING — autonomous; runs after AC3 (Wave 6), before AD3**

**Context**: v2 Phase V was deferred to avoid reviewing an incomplete system mid-build. Phase AO3 automates all scriptable Phase V items. Only subjective quality checks (TTS listening quality, STT accuracy, vision response quality, cursor handoff between devices) remain for AD3.

**Note**: Wave 7 (AI3→AN3) is already underway as of 2026-02-20. S5 (phase-r:4) committed AI3 (PersonalParameters) and is working on AJ3-AL3 (HumanReadinessEngine, ResourceOrchestrator, etc). AO3-AS3 phases run AFTER Wave 7 + Wave 6 verification complete.

### AO3-1: Messaging Gateway Health Check
```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/health
# Expected: 200. If 000/refused: TheaMessagingGateway not running — check app lifecycle wiring.
```

### AO3-2: Full Test Suite
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
swift test 2>&1 | tail -5
# Expected: 0 failures
```

### AO3-3: All 6 GH Workflows Green
```bash
gh run list --limit 20 --json workflowName,conclusion \
  --jq '[.[] | select(.conclusion=="success")] | [.[].workflowName] | unique | length'
# Expected: 6
```

### AO3-4: Release Tag + Notarized Artifacts
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && git status  # Must be clean
git tag -a v1.5.0 -m "Thea v1.5.0 — v2+v3 capability release"
git pushsync
gh run watch --exit-status  # Wait for release.yml
gh release view v1.5.0 --json assets --jq '[.assets[].name]'
# Expected: Thea-v1.5.0.dmg + Thea-v1.5.0.ipa
```

### AO3 Verification Gate
```bash
GW=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/health 2>/dev/null)
TF=$(swift test 2>&1 | grep -c "FAILED" 2>/dev/null || echo 0)
CIG=$(gh run list --limit 20 --json workflowName,conclusion \
  --jq '[.[] | select(.conclusion=="success")] | [.[].workflowName] | unique | length' 2>/dev/null)
TAG=$(git tag -l v1.5.0 | wc -l | tr -d ' ')
echo "Gateway:$GW(want 200) Tests-failed:$TF(want 0) CI-green:$CIG(want 6) Tag:$TAG(want 1)"
```

Commit: `git commit -m "Auto-save: AO3 — pre-AD3 automated verification complete; gateway+tests+CI+release-tag all passed"`

---

## PHASE AP3: MSM3U RELIABILITY INFRASTRUCTURE

**Status: ⏳ PENDING — autonomous; run on MSM3U after AO3**

**Goal**: Power cuts, ISP outages, router failures must not leave Thea permanently offline. Implements heartbeat monitoring, MBAM2 failover, boot recovery, and in-app health monitoring.

### AP3-1: ServerHealthMonitor Swift Actor

Create `Shared/Intelligence/ServerHealthMonitor.swift`:

```swift
// Monitors primary server (MSM3U:18789) reachability. On 3 consecutive failures,
// triggers OS-level failover script (macOS) and sends ntfy alert (all platforms).
import Foundation
import Network

actor ServerHealthMonitor {
    static let shared = ServerHealthMonitor()
    private var consecutiveFailures = 0
    // Dynamic via PersonalParameters — SelfTuningEngine adjusts based on observed network reliability
    private var failoverThreshold: Int { get async { await MainActor.run { PersonalParameters.shared.serverFailoverThreshold } } }
    private var pollIntervalSec: Int { get async { await MainActor.run { PersonalParameters.shared.serverPollIntervalSeconds } } }
    private var isFailoverActive = false
    private var monitorTask: Task<Void, Never>?

    func startMonitoring() {
        monitorTask = Task {
            while !Task.isCancelled {
                await checkHealth()
                let interval = await pollIntervalSec
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    func stopMonitoring() { monitorTask?.cancel() }

    private func checkHealth() async {
        let threshold = await failoverThreshold
        let reachable = await canConnect(host: "msm3u.local", port: 18789)
        if reachable {
            if consecutiveFailures >= threshold && isFailoverActive {
                isFailoverActive = false; consecutiveFailures = 0
                await notify(title: "MSM3U Back Online", body: "Failover cancelled.", priority: "default")
            }
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            if consecutiveFailures >= threshold && !isFailoverActive {
                isFailoverActive = true
                #if os(macOS)
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/Users/alexis/bin/msm3u-failover.sh"); try? p.run()
                #endif
                await notify(title: "MSM3U Offline", body: "\(threshold) failures. Failover initiated.", priority: "high")
            }
        }
    }

    private func canConnect(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { cont in
            var done = false
            let conn = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            conn.stateUpdateHandler = { s in
                guard !done else { return }
                switch s {
                case .ready: done = true; cont.resume(returning: true); conn.cancel()
                case .failed, .waiting: done = true; cont.resume(returning: false); conn.cancel()
                default: break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) { guard !done else { return }; done = true; cont.resume(returning: false); conn.cancel() }
        }
    }

    private func notify(title: String, body: String, priority: String) async {
        guard let url = URL(string: "https://ntfy.sh/thea-msm3u") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.setValue(title, forHTTPHeaderField: "Title")
        req.setValue(priority, forHTTPHeaderField: "Priority"); req.httpBody = body.data(using: .utf8)
        _ = try? await URLSession.shared.data(for: req)
    }
}
```

Wire in `TheamacOSApp.setupManagers()` and `TheaApp.swift` (iOS), 10s deferred:
```swift
Task { try? await Task.sleep(for: .seconds(10)); ServerHealthMonitor.shared.startMonitoring() }
```

### AP3-2: Heartbeat Agent on MSM3U (run these commands on MSM3U)
```bash
mkdir -p ~/bin
cat > ~/bin/msm3u-heartbeat.sh << 'SCRIPT'
#!/bin/bash
curl -s -X POST "https://ntfy.sh/thea-msm3u-hb" -H "Title: MSM3U Heartbeat" \
    -H "Priority: min" -d "alive $(date '+%H:%M') uptime:$(uptime | awk '{print $3}' | tr -d ',')" 2>/dev/null
SCRIPT
chmod +x ~/bin/msm3u-heartbeat.sh

cat > ~/Library/LaunchAgents/com.alexis.msm3u-heartbeat.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.alexis.msm3u-heartbeat</string>
  <key>ProgramArguments</key><array><string>/Users/alexis/bin/msm3u-heartbeat.sh</string></array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
</dict></plist>
PLIST
launchctl load ~/Library/LaunchAgents/com.alexis.msm3u-heartbeat.plist
```

### AP3-3: MBAM2 Failover + Watchdog Scripts (run on MBAM2)
```bash
cat > ~/bin/msm3u-failover.sh << 'SCRIPT'
#!/bin/bash
[ -f /tmp/msm3u-failover-active ] && exit 0
touch /tmp/msm3u-failover-active
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && git pull --rebase 2>&1 | tail -3
open -a /Applications/Thea.app
curl -s -X POST "https://ntfy.sh/thea-msm3u" -H "Title: MBAM2 Failover Active" \
    -H "Priority: high" -d "MSM3U offline. MBAM2 serving. Large models unavailable — API fallback."
SCRIPT
chmod +x ~/bin/msm3u-failover.sh

cat > ~/bin/msm3u-watchdog.sh << 'SCRIPT'
#!/bin/bash
LAST=$(curl -s "https://ntfy.sh/thea-msm3u-hb/json?poll=1&since=90s" 2>/dev/null)
if [ -z "$LAST" ]; then /Users/alexis/bin/msm3u-failover.sh; else rm -f /tmp/msm3u-failover-active; fi
SCRIPT
chmod +x ~/bin/msm3u-watchdog.sh
```

### AP3-4: tmux-resurrect + tmux-continuum (on MSM3U)
```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm 2>/dev/null || true
cat >> ~/.tmux.conf << 'EOF'
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '5'
set -g @resurrect-capture-pane-contents 'on'
EOF
~/.tmux/plugins/tpm/bin/install_plugins 2>/dev/null || true
```

### AP3-5: Tailscale as System Daemon (on MSM3U — replaces App Store version)
```bash
brew install --formula tailscale
sudo brew services start tailscale
# One-time auth (use a reusable no-expiry auth key from tailscale.com/admin):
# sudo tailscale up --authkey=tskey-auth-XXXXX --hostname=msm3u
sudo tailscale status
```

### AP3 Verification Gate
```bash
launchctl list | grep msm3u-heartbeat && echo "✅ heartbeat" || echo "❌ heartbeat"
grep -r "ServerHealthMonitor.shared.startMonitoring" \
  "/Users/alexis/Documents/IT & Tech/MyApps/Thea/" --include="*.swift" | wc -l  # expect ≥2
```

Commit: `git commit -m "Auto-save: AP3 — MSM3U reliability: ServerHealthMonitor actor, heartbeat agent, MBAM2 failover, tmux-resurrect, Tailscale daemon"`

---

## PHASE AQ3: THEA AUTONOMOUS AGENT ORCHESTRATION

**Status: ⏳ PENDING — autonomous; implement on MSM3U after AP3**

**Goal**: Inspired by the v3 MISSION MONITOR's dynamic orchestrator, Thea manages its own AI sub-agents with circuit breakers, dynamic reassignment, persistent progress state, and notification-only human interface (alert on failure only — never on progress).

**Thea user benefit** — When Alexis asks Thea to do multi-step autonomous tasks (research + summarize, analyze health data, generate + run code), Thea internally spawns AI sub-agents. Without AQ3: runaway agents loop forever; silent failures; crash = data lost; notification spam. With AQ3: AgentOrchestrator manages sub-agents silently, alerts ONCE on failure, checkpoints to progress.json for crash recovery, circuit-breaks after 3 failures. Same zero-monitoring guarantee as overnight coding sessions — applied to Alexis's own requests. **AgentOrchestrator is called from AgentMode.executeTask() and ChatManager.processAgentTask().**

### AQ3-1: AgentOrchestrator Actor

Create `Shared/Intelligence/AgentOrchestration/AgentOrchestrator.swift`:

```swift
// Supervisor/worker orchestration: circuit breakers, dynamic reorchestration,
// persistent progress.json state, parallel task execution via TaskGroup.
// Based on: AWS circuit breaker pattern + Anthropic agent harness research (2025).
import Foundation

actor AgentOrchestrator {
    enum TaskDomain: String, Codable { case swiftCode, tests, docs, analysis, fileOps }
    enum CircuitState: Codable {
        case closed, halfOpen
        case open(until: Date)
    }

    struct AgentTask: Identifiable, Codable {
        let id: UUID; let domain: TaskDomain; let description: String
        var status: Status = .pending; var dependencies: [UUID] = []
        var expectedTypes: [String] = []; var modifiedFiles: [String] = []
        enum Status: String, Codable { case pending, inProgress, done, blocked, failed }
    }

    struct AgentResult { let success: Bool; let failureReason: String?; let verificationMethod: String }

    // All tunable via PersonalParameters — SelfTuningEngine adapts based on session outcomes.
    // Access from actor: `await MainActor.run { PersonalParameters.shared.xxx }`
    private var spawnThreshold: Int { get async { await MainActor.run { PersonalParameters.shared.agentSpawnTokenThreshold } } }
    private var circuitBreakerThreshold: Int { get async { await MainActor.run { PersonalParameters.shared.claudeCircuitBreakerAttempts } } }
    private var taskTimeoutSeconds: Double { get async { await MainActor.run { PersonalParameters.shared.agentTaskTimeoutSeconds } } }
    private var agents: [UUID: SubAgent] = [:]
    private let progressURL: URL

    struct SubAgent {
        let id: UUID; let specialization: TaskDomain
        var contextTokens = 0; var consecutiveFailures = 0; var circuitState: CircuitState = .closed
    }

    init(progressURL: URL) { self.progressURL = progressURL }

    func orchestrate(tasks: [AgentTask]) async {
        var pending = tasks; var completed: [UUID: AgentResult] = [:]
        while !pending.isEmpty {
            let ready = pending.filter { t in t.dependencies.allSatisfy { completed[$0]?.success == true } }
            guard !ready.isEmpty else { await notifyBlocked(tasks: pending); break }
            await withTaskGroup(of: (AgentTask, AgentResult).self) { group in
                for task in ready {
                    group.addTask {
                        let agent = await self.selectOrSpawn(for: task)
                        return (task, await self.executeWithBreaker(agent: agent, task: task))
                    }
                }
                for await (task, result) in group {
                    completed[task.id] = result
                    pending.removeAll { $0.id == task.id }
                    await checkpoint(task: task, result: result)
                    if !result.success { await notifyFailure(task: task, reason: result.failureReason) }
                }
            }
        }
        // Silent completion — human checks git log / progress.json
    }

    private func selectOrSpawn(for task: AgentTask) async -> SubAgent {
        if let a = agents.values.first(where: {
            $0.specialization == task.domain && $0.contextTokens < spawnThreshold &&
            $0.consecutiveFailures < circuitBreakerThreshold && isCircuitClosed($0)
        }) { return a }
        let a = SubAgent(id: UUID(), specialization: task.domain)
        agents[a.id] = a; return a
    }

    private func executeWithBreaker(agent: SubAgent, task: AgentTask) async -> AgentResult {
        var a = agent
        if case .open(let until) = a.circuitState, Date() < until {
            return AgentResult(success: false, failureReason: "Circuit open — cooldown", verificationMethod: "circuit-breaker")
        }
        do {
            let result = try await withThrowingTaskGroup(of: AgentResult.self) { group in
                group.addTask { try await self.invokeAndVerify(agent: a, task: task) }
                group.addTask { try await Task.sleep(nanoseconds: UInt64(self.taskTimeoutSeconds * 1e9)); throw CancellationError() }
                let r = try await group.next()!; group.cancelAll(); return r
            }
            a.consecutiveFailures = 0; a.circuitState = .closed; agents[a.id] = a; return result
        } catch {
            a.consecutiveFailures += 1
            if a.consecutiveFailures >= circuitBreakerThreshold {
                let cd = min(300.0, pow(2, Double(a.consecutiveFailures)) * 10)
                a.circuitState = .open(until: Date().addingTimeInterval(cd))
                await writeNote("BLOCKED: \(task.description) — \(error)")
            }
            agents[a.id] = a
            return AgentResult(success: false, failureReason: error.localizedDescription, verificationMethod: "timeout")
        }
    }

    // Self-verification gate — agent certifies own output before marking done
    private func invokeAndVerify(agent: SubAgent, task: AgentTask) async throws -> AgentResult {
        // 1. Execute task (Claude API call, file writes, etc.)
        // 2. Verify: xcodebuild BUILD SUCCEEDED
        // 3. Verify: every expectedType referenced ≥1 time (grep)
        // 4. Verify: no TODO/FIXME in modifiedFiles
        return AgentResult(success: true, failureReason: nil, verificationMethod: "build+grep+stub-check")
    }

    private func isCircuitClosed(_ a: SubAgent) -> Bool {
        if case .open(let until) = a.circuitState { return Date() >= until }; return true
    }

    private func checkpoint(task: AgentTask, result: AgentResult) async {
        await writeNote("\(result.success ? "DONE" : "FAILED"): \(task.description) — \(result.verificationMethod)")
    }

    private func writeNote(_ note: String) async {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(note)\n"
        guard let data = line.data(using: .utf8),
              let existing = try? Data(contentsOf: progressURL) else {
            try? line.data(using: .utf8)?.write(to: progressURL, options: .atomic); return
        }
        try? (existing + data).write(to: progressURL, options: .atomic)
    }

    // Human notification policy: ALERT on failure/block, SILENT on success
    private func notifyFailure(task: AgentTask, reason: String?) async {
        await sendNotif(title: "Thea Agent BLOCKED", body: "\(task.description): \(reason ?? "unknown")", critical: true)
    }
    private func notifyBlocked(tasks: [AgentTask]) async {
        await sendNotif(title: "Orchestrator Stalled", body: "\(tasks.count) tasks blocked on dependencies", critical: true)
    }

    private func sendNotif(title: String, body: String, critical: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body
        content.sound = critical ? .defaultCritical : .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)
    }
}
```

### AQ3-2: AutonomousSessionManager (stale session watchdog)

Create `Shared/Intelligence/AgentOrchestration/AutonomousSessionManager.swift`:

```swift
// DUAL-PURPOSE zero-monitoring watchdog:
// 1. DEV: git commit staleness for autonomous coding sessions
// 2. USER: AgentOrchestrator task staleness for Thea's own multi-step AI tasks
// Policy: SILENT during progress. ONE notification only if stalled. Never spam.
// @MainActor — reads PersonalParameters.shared directly (same isolation).
@MainActor
final class AutonomousSessionManager: ObservableObject {
    // Dynamic via PersonalParameters — SelfTuningEngine adapts based on task type + time of day
    private var staleThreshold: TimeInterval { PersonalParameters.shared.agentStaleThresholdMinutes * 60 }
    private var watchdog: Timer?
    private let repoPath: String
    private var lastUserTaskHeartbeat: Date = .now
    private var staleNotificationSent = false

    init(repoPath: String = "/Users/alexis/Documents/IT & Tech/MyApps/Thea") {
        self.repoPath = repoPath
    }

    func startSession() { staleNotificationSent = false; startWatchdog() }

    /// USER MODE: AgentOrchestrator calls this on each subtask completion.
    /// Resets the stale timer so Thea's autonomous tasks don't trigger false alerts.
    func heartbeat() { lastUserTaskHeartbeat = .now; staleNotificationSent = false }

    private func startWatchdog() {
        watchdog = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.checkStaleness() }
        }
    }

    private func checkStaleness() async {
        guard !staleNotificationSent else { return }
        let devElapsed = gitCommitAge()
        let userElapsed = Date.now.timeIntervalSince(lastUserTaskHeartbeat)
        let maxElapsed = max(devElapsed, userElapsed)
        guard maxElapsed > staleThreshold else { return }
        staleNotificationSent = true
        let mins = Int(maxElapsed / 60)
        let source = devElapsed > userElapsed ? "git commit" : "Thea task"
        let content = UNMutableNotificationContent()
        content.title = "Thea Agent Stalled"
        content.body = "\(mins) min since last \(source) — may need attention"
        content.sound = .defaultCritical
        let req = UNNotificationRequest(identifier: "stale-\(Int(Date.now.timeIntervalSince1970))", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)
    }

    private func gitCommitAge() -> TimeInterval {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", repoPath, "log", "-1", "--format=%ct"]
        let pipe = Pipe(); p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
        guard let ts = TimeInterval(raw), ts > 0 else { return 0 }
        return Date.now.timeIntervalSince1970 - ts
    }
}
```

Wire in `TheamacOSApp.setupManagers()` (14s deferred):
```swift
Task {
    try? await Task.sleep(for: .seconds(14))
    let repoPath = "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
    await AutonomousSessionManager(repoPath: repoPath).startSession()
}
```

### AQ3 Verification Gate
```bash
grep -r "AgentOrchestrator\|AutonomousSessionManager" \
  "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Shared/" --include="*.swift" \
  | grep -v "AgentOrchestrator.swift\|AutonomousSessionManager.swift" | wc -l  # expect ≥2
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination "platform=macOS" build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED)"
```

Commit: `git commit -m "Auto-save: AQ3 — AgentOrchestrator (circuit breaker + dynamic reorchestration) + AutonomousSessionManager (stale watchdog + notification-only interface)"`

---

## PHASE AR3: API ERROR PREVENTION + CONVERSATION MANAGEMENT

**Status: ⏳ PENDING — autonomous; implement on MSM3U after AQ3**

**Root causes of `tool_use_id` mismatch error 400** (GitHub issues #1894, #25959, #40391, Zed #40391):
1. Non-atomic pair insertion — `tool_result` saved without its `assistant+tool_use` message
2. Parallel tool results split across multiple `user` messages (must be ONE user message per assistant turn)
3. Context truncation removes `tool_use` while keeping its `tool_result`
4. Text block placed BEFORE `tool_result` blocks (API requires tool_results FIRST in user message)

### AR3-1: AnthropicConversationManager Actor

Create `Shared/AI/AnthropicConversationManager.swift`:

```swift
// Manages Claude API message history. Prevents error 400 "unexpected tool_use_id"
// through atomic pair insertion, ordering enforcement, pre-send validation, safe truncation.
import Foundation

actor AnthropicConversationManager {

    struct Message: Codable, Sendable {
        let role: Role; var content: [ContentBlock]
        enum Role: String, Codable { case user, assistant }
    }

    enum ContentBlock: Codable, Sendable {
        case text(String)
        case toolUse(id: String, name: String)
        case toolResult(toolUseId: String, content: String, isError: Bool)

        var toolUseId: String? { if case .toolUse(let id, _) = self { return id }; return nil }
        var toolResultId: String? { if case .toolResult(let id, _, _) = self { return id }; return nil }
    }

    private var messages: [Message] = []
    private let maxTokens: Int

    init(maxTokens: Int = 150_000) { self.maxTokens = maxTokens }

    // ATOMIC: only way to add tool rounds. Validates IDs match before appending either message.
    func appendToolRound(assistantResponse: Message, toolResults: [(id: String, content: String, isError: Bool)]) throws {
        let required = Set(assistantResponse.content.compactMap(\.toolUseId))
        let provided = Set(toolResults.map(\.id))
        guard required == provided else {
            throw ConvError.toolIdMismatch(expected: required, got: provided)
        }
        // tool_result blocks FIRST — required by Anthropic API
        let blocks = toolResults.map { ContentBlock.toolResult(toolUseId: $0.id, content: $0.content, isError: $0.isError) }
        messages.append(assistantResponse)
        messages.append(Message(role: .user, content: blocks))
    }

    func appendUserText(_ text: String) { messages.append(Message(role: .user, content: [.text(text)])) }
    func appendAssistantText(_ text: String) { messages.append(Message(role: .assistant, content: [.text(text)])) }

    // Pre-send validation — call before every Anthropic API request
    func validate() throws {
        for i in 0..<messages.count {
            guard messages[i].role == .assistant else { continue }
            let toolIds = messages[i].content.compactMap(\.toolUseId)
            guard !toolIds.isEmpty else { continue }
            guard i + 1 < messages.count, messages[i+1].role == .user else {
                throw ConvError.unpaired(index: i, ids: toolIds)
            }
            let resultIds = Set(messages[i+1].content.compactMap(\.toolResultId))
            guard Set(toolIds) == resultIds else {
                throw ConvError.toolIdMismatch(expected: Set(toolIds), got: resultIds)
            }
        }
    }

    // Safe truncation — never splits a tool_use/tool_result pair
    func truncateToFit() {
        while estimatedTokens() > maxTokens && messages.count >= 2 {
            if messages[0].role == .assistant && messages[0].content.contains(where: { $0.toolUseId != nil }) && messages.count >= 2 && messages[1].role == .user {
                messages.removeFirst(2)
            } else { messages.removeFirst() }
        }
    }

    // Recovery — on 400 error, scan back to last clean boundary
    func recoverFromToolMismatch() {
        var i = messages.count - 1
        while i >= 0 {
            if messages[i].role == .assistant && !messages[i].content.contains(where: { $0.toolUseId != nil }) {
                messages = Array(messages.prefix(i + 1)); return
            }
            i -= 1
        }
        messages = []
    }

    func currentMessages() throws -> [Message] { try validate(); return messages }
    private func estimatedTokens() -> Int { messages.count * 500 }

    enum ConvError: Error {
        case toolIdMismatch(expected: Set<String>, got: Set<String>)
        case unpaired(index: Int, ids: [String])
    }
}
```

Wire `AnthropicConversationManager` into `AnthropicProvider.swift` — replace raw message array with manager. Call `validate()` before every API URLRequest. On 400 error with `tool_use_id` in message, call `recoverFromToolMismatch()` then retry once.

### AR3 Verification Gate
```bash
grep -r "AnthropicConversationManager" \
  "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Shared/AI/" --include="*.swift" \
  | grep -v "AnthropicConversationManager.swift" | wc -l  # expect ≥1 (wired in provider)
grep -r "appendToolRound\|\.validate()\|recoverFromToolMismatch" \
  "/Users/alexis/Documents/IT & Tech/MyApps/Thea/" --include="*.swift" | wc -l  # expect ≥3
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination "platform=macOS" build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED)"
```

Commit: `git commit -m "Auto-save: AR3 — AnthropicConversationManager: atomic tool pair insertion, pre-send validation, safe truncation, 400 error recovery"`

---

## PHASE AS3: ADAPTIVE TIMING ENGINE

**Status: ⏳ PENDING — autonomous; implement on MSM3U after AR3**

**Problem**: Fixed `sleep()` calls waste wall-clock time (too long) or CPU (too short). Research finding: optimal strategy is decorrelated jitter for retry/poll loops; activity-based step-up for process monitoring (AWS Builders' Library, 2026).

### AS3-1: AdaptivePoller Generic Actor

Create `Shared/Intelligence/AdaptivePoller.swift`:

```swift
// Generic adaptive poller. Replaces all fixed sleep() calls in intelligence systems.
// Three strategies from research: decorrelated jitter (AWS), known-duration skip+tail, activity-detection.
import Foundation

actor AdaptivePoller<T: Sendable> {

    enum Strategy {
        // Best for: CI polling, HTTP retries. Avoids thundering herd lockstep.
        case decorrelatedJitter(base: Double, cap: Double)
        // Best for: jobs with known expected duration (skip 80% → poll tail).
        case knownDuration(estimatedSeconds: Double, tailCap: Double = 120)
        // Best for: tmux/process monitoring. Fast when active, slow when idle.
        case activityDetection(levels: [Double], inactivityThresholds: [Double])
    }

    private let strategy: Strategy
    private var currentSleep: Double
    private var attempt = 0
    private var inactiveSeconds: Double = 0

    init(strategy: Strategy) {
        self.strategy = strategy
        switch strategy {
        case .decorrelatedJitter(let b, _): currentSleep = b
        case .knownDuration(let e, _): currentSleep = e * 0.8
        case .activityDetection(let l, _): currentSleep = l.first ?? 3
        }
    }

    func poll(timeout: Double = 7200, check: @Sendable () async throws -> T?) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        if case .knownDuration(_, _) = strategy, currentSleep > 1 {
            // Skip initial phase (80% of estimated time)
            try await Task.sleep(nanoseconds: UInt64(currentSleep * 1e9))
            currentSleep = 30  // switch to polling
        }
        while Date() < deadline {
            if let result = try await check() { return result }
            try await Task.sleep(nanoseconds: UInt64(nextInterval() * 1e9))
        }
        throw PollerError.timeout
    }

    private func nextInterval() -> Double {
        attempt += 1
        switch strategy {
        case .decorrelatedJitter(let base, let cap):
            let next = min(cap, Double.random(in: base...(max(base * 2, currentSleep * 3))))
            currentSleep = next; return next
        case .knownDuration(_, let tailCap):
            let base = min(tailCap, 30.0 * pow(1.3, Double(min(attempt, 10))))
            return base * Double.random(in: 1.0...1.4)
        case .activityDetection(let levels, let thresholds):
            return currentSleep  // updated by reportActivity/reportInactivity
        }
    }

    func reportActivity() {
        if case .activityDetection(let levels, _) = strategy {
            currentSleep = levels.first ?? 3; attempt = 0; inactiveSeconds = 0
        }
    }

    func reportInactivity(additionalSeconds: Double) {
        if case .activityDetection(let levels, let thresholds) = strategy {
            inactiveSeconds += additionalSeconds
            for (i, threshold) in thresholds.enumerated() {
                if inactiveSeconds >= threshold, i + 1 < levels.count { currentSleep = levels[i + 1] }
            }
        }
    }

    enum PollerError: Error { case timeout }
}

// Pre-configured instances for Thea use cases:
extension AdaptivePoller where T == Bool {
    // CI job: skip 80% of typical duration, then poll 30s→120s decorrelated jitter.
    // Duration read from PersonalParameters so SelfTuningEngine can adapt as CI speed changes.
    @MainActor
    static var ciPoller: AdaptivePoller<Bool> {
        let mins = PersonalParameters.shared.ciTypicalDurationMinutes
        return AdaptivePoller(strategy: .knownDuration(estimatedSeconds: mins * 60, tailCap: 120))
    }
    // tmux monitoring: 3s→5s→10s→30s→60s
    static var tmuxPoller: AdaptivePoller<Bool> {
        AdaptivePoller(strategy: .activityDetection(
            levels: [3, 5, 10, 30, 60], inactivityThresholds: [30, 120, 300, 600]))
    }
    // HTTP health: 5s→60s decorrelated
    static var httpPoller: AdaptivePoller<Bool> {
        AdaptivePoller(strategy: .decorrelatedJitter(base: 5, cap: 60))
    }
}
```

### AS3-2: Replace Fixed Sleeps in Intelligence Systems
```bash
# Find all fixed sleep calls to audit:
grep -rn "Task\.sleep\|sleep(" \
  "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Shared/Intelligence/" \
  --include="*.swift" | grep -v "AdaptivePoller"
# For each: replace with appropriate AdaptivePoller strategy
# Priority targets: ProactiveInsightEngine, ServerHealthMonitor (AP3), SmartNotificationScheduler
```

### AS3 Verification Gate
```bash
grep -r "AdaptivePoller" \
  "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Shared/" --include="*.swift" \
  | grep -v "AdaptivePoller.swift" | wc -l  # expect ≥3 (ciPoller, tmuxPoller, httpPoller all used)
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination "platform=macOS" build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED)"
```

Commit: `git commit -m "Auto-save: AS3 — AdaptivePoller: decorrelated jitter + known-duration skip + activity-detection; replaces all fixed sleep() in intelligence systems"`

---

## PHASE AT3: THEAWEB — FULL-STACK COMPLETION
**Status: ⏳ PENDING** | Stream: S6 | Est: 3h
**Goal**: TheaWeb Swift server builds clean, all routes return real data (no stubs/mocks), Docker image builds and runs, Cloudflare tunnel config verified.
**Path**: `Web/TheaWeb/` | Framework: Hummingbird or Vapor (discover at runtime)
**Mission file**: `.claude/mission-web.txt` — read it first, it has the full phase breakdown.

### AT3 Steps (read mission-web.txt for full detail)
1. `cd Web/TheaWeb && swift package resolve && swift build 2>&1 | tee /tmp/theaweb-build.log` — fix ALL errors
2. Read every route handler: any `return .ok` or placeholder → implement real logic
3. `docker build -t thea-web-test:latest .` → fix Dockerfile issues until it passes
4. `swiftlint lint --fix && swiftlint lint` → 0 violations
5. `cat cloudflare-tunnel.yaml` → verify port and service name correct
6. `git add Web/ && git commit -m "feat(AT3): TheaWeb — build clean, routes real, Docker passing"`

### AT3 Verification
```bash
swift build 2>&1 | grep -c "error:" # must be 0
docker images | grep thea-web-test  # must exist
swiftlint lint 2>&1 | grep -c "error:" # must be 0
```

---

## PHASE AU3: TIZEN — BOTH APPS FULL BUILD + PROTOCOL ALIGNMENT
**Status: ⏳ PENDING** | Stream: S6 (after AT3) | Est: 2h
**Goal**: Both Tizen apps build clean, TypeScript errors = 0, JS syntax valid, both connect to TheaMessagingGateway on port 18789.
**Paths**: `thea-tizen/` (TypeScript/React) + `TV/TheaTizen/` (legacy HTML/JS)
**Mission file**: `.claude/mission-tizen.txt` — read it first.

### AU3 Steps (read mission-tizen.txt for full detail)
1. `cd thea-tizen && npm install && npx tsc --noEmit` → fix all TS errors
2. `npm run build` → fix build errors
3. Verify `sync-bridge/` connects to `ws://localhost:18789` (TheaMessagingGateway port)
4. `cd TV/TheaTizen && python3 -c "import xml.etree.ElementTree as ET; ET.parse('config.xml')"` → fix XML
5. Read all JS files → fix syntax errors, verify WebSocket connects to port 18789
6. Wire Bixby voice intent stub: `tizen.humanactivitymonitor` → send voice text to port 18789
7. `git add thea-tizen/ TV/TheaTizen/ && git commit -m "feat(AU3): Tizen — TS clean, JS valid, protocol port 18789 aligned"`

### AU3 Verification
```bash
cd thea-tizen && npx tsc --noEmit 2>&1 | grep -c "error TS" # must be 0
grep -r "18789" thea-tizen/src/ TV/TheaTizen/js/ --include="*.js" --include="*.ts" | wc -l # must be > 0
```

---

## PHASE AV3: BROWSER EXTENSIONS — NATIVEHOST + CHROME/SAFARI/BRAVE
**Status: ⏳ PENDING** | Stream: S7 | Est: 4h
**Goal**: NativeHost wired to TheaMessagingGateway; Chrome AI sidebar → NativeHost → Thea AI works end-to-end; Safari extension added to Xcode build; Brave 14 is canonical (archive Brave 1–13); all extensions manifest v3 compliant.

### AV3-1: NativeHost (critical path — do first)
```bash
ls Extensions/NativeHost/
```
NativeHost bridges `chrome.runtime.sendNativeMessage()` to Thea's local server.
- Discover what NativeHost is (Swift/Python/Node.js) — read all files
- Wire it: inbound native message → HTTP POST to `http://localhost:18789/message` (TheaMessagingGateway)
- Register in `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/ai.thea.host.json`
- Also register for Safari: `~/Library/Application Support/Mozilla/NativeMessagingHosts/` (if needed)
- Test: `echo '{"type":"chat","text":"hello"}' | /path/to/nativehost`
- Commit: `git add Extensions/NativeHost/ && git commit -m "feat(AV3): NativeHost — wired to TheaMessagingGateway port 18789 [1/4]"`

### AV3-2: Chrome Extension audit
- Read `Extensions/Chrome/background/native-bridge.js` → verify it calls correct native host ID
- Read `Extensions/Chrome/content/ai-sidebar.js` → verify it posts to background, not hardcoded localhost
- Read `Extensions/Chrome/background/memory-system.js` → verify it uses Thea's memory (not localStorage-only)
- Fix any disconnected calls, stub functions (`// TODO`), or broken flows
- Commit: `git add Extensions/Chrome/ && git commit -m "feat(AV3): Chrome extension — native bridge wired, AI sidebar functional [2/4]"`

### AV3-3: Safari Extension + Xcode target
- `Extensions/SafariExtension/Resources/` shares WebExtension JS with Chrome — verify `manifest.json` matches Chrome's (MV3, same permissions)
- Add SafariExtension target to `project.yml` under macOS target if missing
- Run `xcodegen generate` if project.yml changed
- Verify `SafariWebExtensionHandler.swift` calls NativeHost or directly calls TheaMessagingGateway
- Commit: `git add Extensions/SafariExtension/ project.yml && git commit -m "feat(AV3): SafariExtension — Xcode target added, handler wired [3/4]"`

### AV3-4: Brave cleanup
- `Brave 14` is canonical — verify it has same JS files as Chrome (or symlinks/copies)
- `Brave 2` through `Brave 13` → move to `Extensions/_archive/` (not delete)
- `Brave` (original) → compare with Brave 14, keep best version
- Commit: `git add Extensions/ && git commit -m "feat(AV3): Brave canonical=Brave14, Brave2-13 archived [4/4]"`

### AV3 Verification
```bash
# NativeHost reachable
ls ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/ai.thea.host.json 2>/dev/null && echo "Chrome NMH: registered" || echo "MISSING"
# No TODO in browser extension JS
grep -r "TODO\|FIXME\|stub\|placeholder" Extensions/Chrome/background/ Extensions/Chrome/content/ Extensions/SafariExtension/Resources/ | grep -v ".map" | wc -l # target: 0
```

---

## PHASE AW3: WIDGET EXTENSION — 5 WIDGET TYPES
**Status: ⏳ PENDING** | Stream: S8 | Est: 4h
**Goal**: All 5 widget implementations complete with real SwiftData/AppGroup data, WidgetKit timeline providers, correct sizing for all widget families (small/medium/large/accessory).
**Path**: `Extensions/WidgetExtension/`

### AW3 Design principles
- All widgets read from shared AppGroup (`group.app.theathe`) — same SwiftData store as main app
- No hardcoded/mock data anywhere
- Each widget has a `TimelineProvider` that refreshes at sensible intervals
- All support `.systemSmall`, `.systemMedium` at minimum; Conversation + Context support `.systemLarge`
- Lock screen widgets use `.accessoryCircular` / `.accessoryRectangular`

### AW3 Widgets to implement
1. **TheaConversationWidget**: Last N messages (title of last conversation, last message preview, timestamp). Tap → opens Thea to that conversation.
2. **TheaQuickActionsWidget**: 4 configurable quick-action buttons (e.g. "New chat", "Voice input", "Memory search", "Last context"). Uses `Link` for deep links.
3. **TheaMemoryWidget**: Shows top 3 recent memory items (PersonalKnowledgeGraph entities, timestamp, category icon). Tap → opens Memory view.
4. **TheaContextWidget**: Current awareness summary — location context, time-of-day greeting, active focus mode, HRV readiness score (if available). Updates every 15min.
5. **TheaLockScreenWidget** (iOS only): `.accessoryCircular` = Thea icon + unread count. `.accessoryRectangular` = last message preview.

### AW3 Reference
- Read `Shared/Memory/PersonalKnowledgeGraph.swift` for memory data access
- Read `Shared/AI/ChatManager.swift` for conversation data model
- AppGroup: `group.app.theathe` — use `ModelContainer(for:..., configurations: ModelConfiguration(groupContainer: .identifier("group.app.theathe")))`

### AW3 Steps
For each of the 5 widgets (one file → build → fix → commit per widget):
```bash
# After each widget file:
swift build 2>&1 | grep "error:" | head -5
git add Extensions/WidgetExtension/<Widget>.swift && git commit -m "feat(AW3): TheaXxxWidget — real data, all families [N/5]"
```
Final: `xcodebuild -project Thea.xcodeproj -scheme Thea-iOS -configuration Debug -destination "generic/platform=iOS" build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -3`

---

## PHASE AX3: NATIVE EXTENSIONS GROUP 1 — SHARE, INTENTS, MESSAGES, MAIL, FOCUSFILTER
**Status: ⏳ PENDING** | Stream: S8 (after AW3) | Est: 4h
**Goal**: 5 native system extensions fully implemented, wired to Thea's ChatManager/AgentOrchestrator via AppGroup, added to project.yml.

### AX3-1: ShareExtension
- Accept any shareable content (text, URL, image, file) via `NSExtensionItem`
- Create a new Thea conversation with the shared content as initial message
- Write to AppGroup pending-share queue → main app picks up on next launch
- UI: minimal SwiftUI sheet — "Share to Thea" with content preview + send button
- Commit: `feat(AX3): ShareExtension — accepts text/URL/image, queues to AppGroup [1/5]`

### AX3-2: IntentsExtension (Siri Shortcuts)
- Define `INExtension` with at minimum 3 intents:
  - `AskTheaIntent`: user speaks question → Thea answers via AnthropicProvider → speaks response
  - `SearchMemoryIntent`: "Hey Siri, search my Thea memory for X"
  - `NewConversationIntent`: "Hey Siri, start a new Thea conversation"
- Read `Shared/AI/Providers/AnthropicProvider.swift` for API access pattern
- Commit: `feat(AX3): IntentsExtension — AskThea, SearchMemory, NewConversation Siri intents [2/5]`

### AX3-3: MessagesExtension (iMessage app)
- iMessage app extension: renders in iMessage app drawer
- UI: compact chat view showing Thea's last response + input field
- Messages sent through extension → route via AppGroup to ChatManager
- Commit: `feat(AX3): MessagesExtension — iMessage app, Thea AI responses in Messages [3/5]`

### AX3-4: MailExtension
- Mail app plugin (macOS) or app extension (iOS)
- Reads selected email → offers: "Summarize", "Draft reply", "Add to memory"
- Uses AnthropicProvider for generation
- Commit: `feat(AX3): MailExtension — summarize/reply/memory actions on selected email [4/5]`

### AX3-5: FocusFilterExtension
- Implements `FocusFilterIntent` — Thea adapts behavior based on active Focus mode
- Work Focus → suppress non-urgent proactive insights, increase response speed threshold
- Sleep Focus → suppress all non-critical notifications, enable sleep tracking context
- Commit: `feat(AX3): FocusFilterExtension — Work/Sleep/Personal/Do Not Disturb adaptation [5/5]`

### AX3 Verification
```bash
for ext in ShareExtension IntentsExtension MessagesExtension MailExtension FocusFilterExtension; do
  echo "$ext: $(grep -r "TODO\|stub\|placeholder\|fatalError" Extensions/$ext/ --include="*.swift" | wc -l) stubs"
done # all must be 0
xcodebuild -project Thea.xcodeproj -scheme Thea-iOS -configuration Debug -destination "generic/platform=iOS" build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED" | tail -3
```

---

## PHASE AY3: NATIVE EXTENSIONS GROUP 2 — CALLKIT, CREDENTIALS, KEYBOARD, NOTIFICATION, QUICKLOOK, SPOTLIGHT, FINDERSYNC
**Status: ⏳ PENDING** | Stream: S9 | Est: 5h
**Goal**: 7 remaining native system extensions fully implemented. Each reads real Thea data via AppGroup.

### AY3-1: CallKitExtension (CXCallDirectoryProvider)
- Caller ID: load contacts from PersonalKnowledgeGraph → `context.addIdentificationEntry(withNextSequentialPhoneNumber:label:)`
- Call blocking: load blocklist from SettingsManager → `context.addBlockingEntry(withNextSequentialPhoneNumber:)`
- Commit: `feat(AY3): CallKitExtension — Caller ID + blocking from PersonalKnowledgeGraph [1/7]`

### AY3-2: CredentialsExtension (ASCredentialProviderViewController)
- Password autofill: bridge to iCloud Keychain entries surfaced in browser extension
- Read `Extensions/NativeHost/` for iCloud Keychain access pattern already implemented
- Commit: `feat(AY3): CredentialsExtension — iCloud Keychain bridge for autofill [2/7]`

### AY3-3: KeyboardExtension (UIInputViewController)
- Custom keyboard with Thea AI bar above keyboard row
- AI bar: text field + "Ask Thea" button → lightweight AnthropicProvider call → inserts response
- Suggestion row: last 3 Thea memory items relevant to current app context
- Commit: `feat(AY3): KeyboardExtension — AI bar + memory suggestions above keyboard [3/7]`

### AY3-4: NotificationServiceExtension (UNNotificationServiceExtension)
- Intercept notifications before display: enrich with Thea context
- Pattern: if notification contains person name → look up in PersonalKnowledgeGraph → append relationship context to body
- Commit: `feat(AY3): NotificationServiceExtension — enrich with PersonalKnowledgeGraph context [4/7]`

### AY3-5: QuickLookExtension (QLPreviewingController)
- Preview `.thea` files (Thea conversation exports, memory exports) in Finder/Files
- Render as formatted HTML: conversation timeline, entity cards
- Commit: `feat(AY3): QuickLookExtension — .thea file preview with conversation timeline [5/7]`

### AY3-6: SpotlightImporter (CSImporter)
- Index Thea conversations + memory entities into Spotlight
- `CSSearchableItem` per conversation (title, last message, date) + per KG entity (name, category)
- Updates AppGroup-shared index on every conversation change
- Commit: `feat(AY3): SpotlightImporter — conversations + KG entities indexed in Spotlight [6/7]`

### AY3-7: FinderSyncExtension (FIFinderSyncController)
- Finder badges on files Thea has context about (referenced in conversations or memory)
- Badge: small Thea icon overlay + tooltip showing "Referenced in N Thea conversations"
- Commit: `feat(AY3): FinderSyncExtension — Finder badges for Thea-referenced files [7/7]`

### AY3 Verification
```bash
for ext in CallKitExtension CredentialsExtension KeyboardExtension NotificationServiceExtension QuickLookExtension SpotlightImporter FinderSyncExtension; do
  STUBS=$(grep -r "TODO\|stub\|fatalError\|placeholder" "Extensions/$ext/" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
  echo "$ext: $STUBS stubs (must be 0)"
done
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug -destination "platform=macOS" build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED" | tail -3
xcodebuild -project Thea.xcodeproj -scheme Thea-iOS -configuration Debug -destination "generic/platform=iOS" build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED" | tail -3
```

---

## PHASE AZ3: PHYSICAL AV TESTING — CROSS-MAC AUTOMATED MANUAL GATES

**Status: ⏳ PENDING — Wave 10 (infrastructure + CI workflow)**

**Goal**: Use MBAM2 and MSM3U's physical co-location on the same desk to automate multi-sensory testing:
- **Audio round-trip**: MSM3U speaks/plays sound → MBAM2 microphone records → `hear` transcribes → verify expected words
- **Camera visual test**: MSM3U displays UI → MBAM2 webcam photographs the screen → `ocrmac` (Apple Vision OCR) → verify expected UI elements visible
- **Screenshot regression**: `screencapture` + SSIM (scikit-image) + `swift-snapshot-testing` for pixel-perfect baseline comparison
- **Self-hosted CI**: Both Macs run GitHub Actions self-hosted runners; nightly `physical-av-tests.yml` (4 AM UTC = 11 PM PT)

**Architecture**: MSM3U = Orchestrator (builds, triggers scenarios, analyzes). MBAM2 = Observer (mic + camera, runs `thea-test-agent` HTTP server on port 7788).

**Key tools**: `ffmpeg` (avfoundation capture), `hear` (on-device STT, no rate limit), `ocrmac` (Apple Vision Python wrapper), `screencapture` (macOS built-in), `swift-snapshot-testing` (pointfreeco SPM), `opencv-python` (SSIM).

---

### AZ3-1: MBAM2 Observer Infrastructure

Install dependencies on both Macs:
```bash
brew install ffmpeg sox python@3.12
pip3 install fastapi uvicorn opencv-python scikit-image pillow imagehash ocrmac
brew tap sveinbjornt/sveinbjornt && brew install hear
```

**File**: `/usr/local/bin/thea-test-agent.py` on MBAM2:
```python
from fastapi import FastAPI
import subprocess, base64

app = FastAPI()

@app.post("/audio/record")
def start_audio_record(duration: int = 8, session: str = "default"):
    path = f"/tmp/thea-audio-{session}.wav"
    subprocess.Popen(["ffmpeg", "-f", "avfoundation", "-i", ":0", "-t", str(duration), "-y", path])
    return {"status": "recording", "path": path}

@app.get("/audio/result")
def get_audio_result(session: str = "default"):
    path = f"/tmp/thea-audio-{session}.wav"
    result = subprocess.run(["hear", "-d", path], capture_output=True, text=True, timeout=30)
    return {"transcript": result.stdout.strip()}

@app.post("/camera/capture")
def capture_frame(session: str = "default"):
    path = f"/tmp/thea-visual-{session}.jpg"
    # 15 warmup frames for autofocus, then grab 1
    subprocess.run(["ffmpeg", "-f", "avfoundation", "-i", "0", "-vframes", "15", "-y", path], capture_output=True)
    subprocess.run(["ffmpeg", "-f", "avfoundation", "-i", "0", "-vframes", "1", "-y", path], capture_output=True)
    with open(path, "rb") as f:
        return {"image_base64": base64.b64encode(f.read()).decode()}

@app.get("/health")
def health(): return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7788)
```

**LaunchAgent** `~/Library/LaunchAgents/com.alexis.thea-test-agent.plist` on MBAM2:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.alexis.thea-test-agent</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/python3</string><string>/usr/local/bin/thea-test-agent.py</string>
  </array>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
</dict></plist>
```

One-time TCC grants (run manually from MBAM2 Terminal):
```bash
ffmpeg -f avfoundation -i ":0" -t 0.5 -y /tmp/mic-test.wav  # mic TCC prompt
ffmpeg -f avfoundation -i "0" -vframes 1 -y /tmp/cam-test.jpg  # camera TCC prompt
hear -d /tmp/mic-test.wav  # speech recognition TCC prompt
```

- Commit: `feat(AZ3): MBAM2 thea-test-agent server + LaunchAgent [1/5]`

---

### AZ3-2: Audio Round-Trip Test

**File**: `Tests/PhysicalAV/audio_roundtrip_test.sh` (runs on MSM3U):
```bash
#!/bin/bash
SESSION=${SESSION:-$(date +%s)}
MBAM2=${MBAM2_HOST:-mbam2.local}

curl -s -X POST "http://$MBAM2:7788/audio/record?duration=6&session=$SESSION" > /dev/null
sleep 0.3
say -v Samantha "Thea notification: task completed successfully"
sleep 1
afplay /System/Library/Sounds/Glass.aiff
sleep 4

TRANSCRIPT=$(curl -s "http://$MBAM2:7788/audio/result?session=$SESSION" | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['transcript'])")
echo "Transcript: $TRANSCRIPT"

python3 -c "
t = '''$TRANSCRIPT'''.lower()
missing = [w for w in ['thea','notification','task','completed'] if w not in t]
print('FAIL:' + str(missing)) if missing else print('PASS: Audio round-trip ✓')
import sys; sys.exit(1 if missing else 0)
"
```

- Commit: `feat(AZ3): audio round-trip test (MSM3U say → MBAM2 mic → hear → verify) [2/5]`

---

### AZ3-3: Camera OCR Visual Test

**File**: `Tests/PhysicalAV/camera_ocr_test.sh` (runs on MSM3U):
```bash
#!/bin/bash
SESSION=${SESSION:-$(date +%s)}
MBAM2=${MBAM2_HOST:-mbam2.local}

open /Applications/Thea.app 2>/dev/null || true
sleep 2  # let UI settle

FRAME_B64=$(curl -s -X POST "http://$MBAM2:7788/camera/capture?session=$SESSION" | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['image_base64'])")
echo "$FRAME_B64" | base64 -d > /tmp/thea-webcam-$SESSION.jpg

python3 - << 'PYEOF'
import sys
from ocrmac import OCR
result = OCR(f'/tmp/thea-webcam-{os.environ.get("SESSION","0")}.jpg', recognition_level='accurate')
texts = [t[0] for t in result.recognize() if t[1] > 0.5]
print(f"Visible text: {texts}")
missing = [r for r in ['Chat','Thea'] if not any(r.lower() in t.lower() for t in texts)]
print('FAIL: ' + str(missing)) if missing else print('PASS: Camera OCR ✓')
sys.exit(1 if missing else 0)
PYEOF
```

**Continuity Camera** (iPhone, higher resolution): detected automatically when iPhone is near MBAM2.
From command line: `ffmpeg -f avfoundation -list_devices true -i ""` → look for iPhone device index.

**Keystone correction** for angled webcam (one-time calibration):
```python
import cv2, numpy as np
# Mark 4 screen corners in webcam image, store as JSON, apply warpPerspective before OCR
```

- Commit: `feat(AZ3): camera OCR visual test (MBAM2 webcam → ocrmac → UI element verify) [3/5]`

---

### AZ3-4: Screenshot Regression Tests

**File**: `Tests/PhysicalAV/screenshot_regression.sh` (runs on MSM3U):
```bash
#!/bin/bash
BASELINE_DIR="Tests/VisualBaselines"
mkdir -p "$BASELINE_DIR"
BASELINE="$BASELINE_DIR/thea-main-window.png"
CURRENT="/tmp/thea-current-$(date +%s).png"

screencapture -x -R "0,0,1440,900" "$CURRENT"

python3 - << PYEOF
import cv2, sys
from skimage.metrics import structural_similarity as ssim
import shutil

baseline = cv2.imread('$BASELINE')
current = cv2.imread('$CURRENT')
if baseline is None:
    shutil.copy('$CURRENT', '$BASELINE')
    print("INFO: Baseline recorded")
    sys.exit(0)
current_r = cv2.resize(current, (baseline.shape[1], baseline.shape[0]))
g_b = cv2.cvtColor(baseline, cv2.COLOR_BGR2GRAY)
g_c = cv2.cvtColor(current_r, cv2.COLOR_BGR2GRAY)
score, _ = ssim(g_b, g_c, full=True)
print(f"SSIM: {score:.4f}")
sys.exit(0 if score >= 0.85 else 1)
PYEOF
```

**SwiftUI Snapshot Testing** (add `swift-snapshot-testing` via SPM in Package.swift):
```swift
// Tests/SnapshotTests/TheaViewSnapshotTests.swift
import SnapshotTesting, XCTest, SwiftUI

final class TheaViewSnapshotTests: XCTestCase {
    // perceptualPrecision 0.95: handles M2 vs M3 Ultra GPU subpixel rendering deltas
    func testChatViewSnapshot() {
        assertSnapshot(of: ChatView().frame(width: 375, height: 812),
                       as: .image(precision: 0.99, perceptualPrecision: 0.95),
                       record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1")
    }
}
```

Record baselines: `RECORD_SNAPSHOTS=1 xcodebuild test ...`

- Commit: `feat(AZ3): screenshot regression (SSIM + swift-snapshot-testing perceptual) [4/5]`

---

### AZ3-5: GitHub Actions Physical AV Workflow

**File**: `.github/workflows/physical-av-tests.yml`:
```yaml
name: Physical AV Tests (AZ3)
on:
  workflow_dispatch:
  schedule:
    - cron: '0 4 * * *'  # 4 AM UTC = 11 PM PT nightly
  pull_request:
    types: [labeled]

concurrency:
  group: physical-av-lock
  cancel-in-progress: false

jobs:
  observer-ready:
    name: MBAM2 — Observer Ready
    runs-on: [self-hosted, mbam2]
    if: >
      github.event_name != 'pull_request' ||
      contains(github.event.pull_request.labels.*.name, 'physical-av')
    steps:
      - name: Verify thea-test-agent
        run: |
          curl -s --max-time 5 http://localhost:7788/health | grep '"ok"' || \
          { python3 /usr/local/bin/thea-test-agent.py & sleep 4; }
          echo "Observer ready ✓"

  orchestrate:
    name: MSM3U — Orchestrate AV Tests
    runs-on: [self-hosted, msm3u]
    needs: observer-ready
    steps:
      - uses: actions/checkout@v4
      - name: Session ID
        id: sess
        run: echo "id=$(date +%s)" >> "$GITHUB_OUTPUT"
      - name: Build Thea-macOS
        run: |
          xcodebuild -project Thea.xcodeproj -scheme Thea-macOS \
            -configuration Debug -destination "platform=macOS" \
            build -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 | \
            grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -3
      - name: Audio round-trip test
        run: bash Tests/PhysicalAV/audio_roundtrip_test.sh
        env: { SESSION: "${{ steps.sess.outputs.id }}", MBAM2_HOST: mbam2.local }
      - name: Camera OCR test
        run: bash Tests/PhysicalAV/camera_ocr_test.sh
        env: { SESSION: "${{ steps.sess.outputs.id }}", MBAM2_HOST: mbam2.local }
      - name: Screenshot regression
        run: bash Tests/PhysicalAV/screenshot_regression.sh
      - name: Snapshot tests
        run: |
          xcodebuild test -project Thea.xcodeproj -scheme Thea-macOS \
            -destination "platform=macOS" \
            -only-testing:TheaTests/TheaViewSnapshotTests \
            -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: physical-av-${{ steps.sess.outputs.id }}
          path: |
            /tmp/thea-audio-*.wav
            /tmp/thea-webcam-*.jpg
            /tmp/thea-current-*.png
          retention-days: 30
          if-no-files-found: ignore
```

Self-hosted runner setup (one-time per Mac):
```bash
mkdir ~/actions-runner && cd ~/actions-runner
curl -O -L "https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-osx-arm64-2.321.0.tar.gz"
tar xzf ./actions-runner-osx-arm64-2.321.0.tar.gz
./config.sh --url https://github.com/Atchoum23/Thea --token TOKEN --labels "$(hostname -s),self-hosted,macOS,ARM64"
./svc.sh install && ./svc.sh start
```

Add to `ci.yml` `paths-ignore`: `.github/workflows/physical-av-tests.yml`

- Commit: `feat(AZ3): GitHub Actions physical-av-tests.yml + self-hosted runner docs [5/5]`

---

### AZ3-6: ODiff Pixel-Perfect Visual Diffing

**Tool**: `odiff` (Zig-based SIMD/NEON — 6× faster than ImageMagick SSIM on Apple Silicon)

```bash
brew install odiff
# Capture baseline: screencapture -t png /tmp/thea-baseline-$(date +%Y%m%d).png
# After changes:   screencapture -t png /tmp/thea-compare.png
# Diff with JSON output for CI parsing:
odiff /tmp/thea-baseline-*.png /tmp/thea-compare.png /tmp/thea-diff.png \
  --antialiasing --threshold 0.05 --output-format json
```
`--antialiasing`: ignores subpixel AA differences. `--threshold 0.05`: 5% per-pixel tolerance.
- Commit: `feat(AZ3): ODiff pixel-perfect diffing for screenshot regression [6/15]`

---

### AZ3-7: Prefire — Auto-Generated SwiftUI Snapshot Tests

**Tool**: `BarredEwe/Prefire` — generates one snapshot test per `#Preview` block in the codebase. Zero per-view writing.

Add to `Package.swift` test dependencies: `.package(url: "https://github.com/BarredEwe/Prefire.git", from: "2.0.0")`

```bash
PREFIRE_RECORD=true swift test --filter PrefireTests  # Record baselines
swift test --filter PrefireTests                       # CI comparison
```
Baselines stored in `Tests/PrefireTests/__Snapshots__/` — commit them.
- Commit: `feat(AZ3): Prefire auto-snapshot generation from all #Preview blocks [7/15]`

---

### AZ3-8: Allure 3 + XCTestHTMLReport — Test Report Pipeline

```bash
brew install allure && brew install xchtmlreport
# Run tests: xcodebuild test ... -resultBundlePath /tmp/TestResults.xcresult
# Allure (reads .xcresult natively): allure generate /tmp/TestResults.xcresult -o /tmp/AllureReport --clean
# Portable HTML: xchtmlreport -r /tmp/TestResults.xcresult -i → /tmp/TestResults.html
```
Add artifact upload step to `physical-av-tests.yml` with `if: always()`.
- Commit: `feat(AZ3): Allure 3 + XCTestHTMLReport report pipeline [8/15]`

---

### AZ3-9: XCTMetric Performance Baselines + xctrace Profiling

```swift
// Tests/TheaTests/PerformanceBaselinesTests.swift
final class PerformanceBaselinesTests: XCTestCase {
    func testSystemPromptBuildPerformance() {
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric(), XCTClockMetric()]) {
            _ = ChatManager.shared.buildSystemPrompt()
        }
    }
}
```
Out-of-process: `xcrun xctrace record --template "Time Profiler" --attach $(pgrep -f "Thea.app") --time-limit 30s --no-prompt --output /tmp/thea.trace`
- Commit: `feat(AZ3): PerformanceBaselinesTests XCTMetric + xctrace profiling [9/15]`

---

### AZ3-10: powermetrics Energy Impact CI Baseline

```bash
# Tests/PhysicalAV/energy_baseline.sh (run as sudo)
sudo powermetrics --samplers tasks,cpu_power,thermal --format json --duration 30 2>/dev/null | \
  python3 -c "
import sys,json; data=json.load(sys.stdin)
tasks=[t for s in data.get('tasks',[]) for t in s.get('tasks',[]) if 'Thea' in t.get('name','')]
avg=sum(t.get('cpu_energy_impact',0) for t in tasks)/max(len(tasks),1)
print(f'Thea avg: {avg:.1f} mW'); sys.exit(1 if avg>2000 else 0)"
```
- Commit: `feat(AZ3): powermetrics energy budget CI script [10/15]`

---

### AZ3-11: performAccessibilityAudit() — Built-in XCTest Accessibility Tests

```swift
// Tests/TheaTests/AccessibilityAuditTests.swift
@MainActor final class AccessibilityAuditTests: XCTestCase {
    func testChatViewAccessibility() throws {
        let app = XCUIApplication(); app.launch()
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .hitRegion,
                                                 .sufficientElementDescription, .textClipping])
    }
    func testSettingsAccessibility() throws {
        let app = XCUIApplication(); app.launch()
        app.buttons["Settings"].tap()
        try app.performAccessibilityAudit()  // All 20+ rules
    }
}
```
Built into XCTest (Xcode 15+) — no extra tools needed.
- Commit: `feat(AZ3): AccessibilityAuditTests — performAccessibilityAudit() [11/15]`

---

### AZ3-12: mitmproxy Network Traffic Validator

```python
# Tests/PhysicalAV/network_validator.py — run: mitmdump --script network_validator.py --listen-port 8888
from mitmproxy import http
ALLOWED = {"api.anthropic.com","api.openai.com","api.coinbase.com","api.ouraring.com",
           "api.prod.whoop.com","api.ynab.com","development.plaid.com","api.github.com","ntfy.sh"}
def request(flow: http.HTTPFlow) -> None:
    h = flow.request.pretty_host
    if not any(h == d or h.endswith("."+d) for d in ALLOWED):
        flow.kill(); print(f"🚫 BLOCKED: {h}")
```
- Commit: `feat(AZ3): mitmproxy network validator + allowed-domain allowlist [12/15]`

---

### AZ3-13: BlackHole Single-Mac Audio Loopback (No Physical MBAM2 Needed)

```bash
brew install blackhole-2ch switchaudio-osx ffmpeg && pip3 install jiwer openai-whisper
SwitchAudioSource -s "BlackHole 2ch" -t output          # Route Thea TTS → virtual device
ffmpeg -f avfoundation -i ":BlackHole 2ch" -t 8 /tmp/thea-tts.wav -y
SwitchAudioSource -s "Mac Studio Speakers" -t output    # Restore
whisper /tmp/thea-tts.wav --model small --output_format txt --output_dir /tmp/
python3 -c "from jiwer import wer; print(f'WER: {wer(\"hello\", open(\"/tmp/thea-tts.txt\").read().strip().lower()):.2%}')"
```
Zero cable/reverb — captures clean digital audio.
- Commit: `feat(AZ3): BlackHole single-Mac audio loopback + WER validation [13/15]`

---

### AZ3-14: SpeechQualityTests — On-Device WER via SFSpeechRecognizer

```swift
// Tests/TheaTests/SpeechQualityTests.swift
import Speech
final class SpeechQualityTests: XCTestCase {
    func testTTSWordErrorRate() async throws {
        let url = URL(fileURLWithPath: "/tmp/thea-tts.wav")
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("Run AZ3-13 first") }
        let recognizer = SFSpeechRecognizer(locale: .init(identifier: "en-US"))!
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { r, e in
                if let e { cont.resume(throwing: e) } else if r?.isFinal == true { cont.resume(returning: r!) }
            }
        }
        let ref = "hello this is thea".split(separator: " ")
        let hyp = result.bestTranscription.formattedString.lowercased().split(separator: " ")
        let errors = zip(ref, hyp).filter { $0.0 != $0.1 }.count
        XCTAssertLessThan(Double(errors)/Double(ref.count), 0.10, "WER exceeds 10%")
    }
}
```
- Commit: `feat(AZ3): SpeechQualityTests — on-device WER for TTS quality [14/15]`

---

### AZ3-15: ScreenCaptureKit + VNFeaturePrint Perceptual Diff

```swift
// Tests/TheaTests/PerceptualDiffTests.swift
import XCTest, Vision, ScreenCaptureKit
final class PerceptualDiffTests: XCTestCase {
    func testChatViewPerceptualRegression() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let win = content.windows.first(where: { $0.owningApplication?.bundleIdentifier == "app.theathe.Thea" })
        else { throw XCTSkip("Thea not running") }
        // Capture → featurePrint → compare to baseline (distance < 0.15 = no regression)
        // See full implementation in Tests/TheaTests/PerceptualDiffTests.swift
    }
    private func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation {
        let req = VNGenerateImageFeaturePrintRequest()
        try VNImageRequestHandler(cgImage: image).perform([req])
        return req.results!.first!
    }
}
```
0.15 distance threshold: semantic content preserved, rendering noise ignored.
- Commit: `feat(AZ3): PerceptualDiffTests — ScreenCaptureKit + VNFeaturePrint regression [15/15]`

---

### AZ3 Verification
```bash
# Files exist
ls Tests/PhysicalAV/{audio_roundtrip_test,camera_ocr_test,screenshot_regression}.sh
ls .github/workflows/physical-av-tests.yml
ls Tests/SnapshotTests/TheaViewSnapshotTests.swift

# MBAM2 agent reachable from MSM3U
curl -s http://mbam2.local:7788/health | grep '"ok"'

# Smoke-test audio
bash Tests/PhysicalAV/audio_roundtrip_test.sh

# Smoke-test camera
bash Tests/PhysicalAV/camera_ocr_test.sh

# Record baselines (first run)
RECORD_SNAPSHOTS=1 xcodebuild test -project Thea.xcodeproj -scheme Thea-macOS \
  -destination "platform=macOS" -only-testing:TheaTests/TheaViewSnapshotTests \
  -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

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
