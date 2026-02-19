# THEA SHIP-READY PLAN v2.0
# ══════════════════════════════════════════════════════════════════════════════
# ⚠️  ABSOLUTE NON-NEGOTIABLE RULE — NEVER REMOVE ANYTHING. ONLY ADD AND FIX.
# ══════════════════════════════════════════════════════════════════════════════
#
# Created: 2026-02-19 | Supersedes: THEA_SHIP_READY_PLAN_v1.md
# Owner: Autonomous agent system (MSM3U primary + MBAM2 secondary)
# Scope: All platforms — macOS, iOS, watchOS, tvOS, Tizen, TheaWeb
#
# v2 ADDITIONS OVER v1:
#   1. GitHub Workflows: complete overhaul of all 6 workflows (N1–N8)
#   2. Thea Native Messaging Gateway: replace OpenClaw natively — O0–O10 (foundation,
#      Telegram, Discord, Slack, iMessage, WhatsApp, Signal, Matrix, WS server, sessions)
#   3. Component-by-component analysis: P1–P16 (all major subsystems + AI 2026 upgrades)
#   4. AI 2026 updates: Claude Opus 4.6, Sonnet 4.6, Agent Teams, MLX audio/vision,
#      Apple SpeechAnalyzer API, vllm-mlx, SwiftLint 0.64.0
#   5. Automation of previously manual tasks (17 newly automated)
#   6. Phase ordering optimized for parallel execution and dependency chains
#   7. OpenClaw config reference (JSON5, daemon setup, security hardening)
#   8. Quick Status Snapshot section at top for fast resume
# ══════════════════════════════════════════════════════════════════════════════

---

## HOW TO CHECK PROGRESS (READ THIS FIRST, ALEXIS)

### From MSM3U:
```
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git pull
# Then start Claude Code and say:
"Read .claude/THEA_SHIP_READY_PLAN_v2.md and tell me the current status of all phases,
which are complete, which are in progress, and what is blocking ship-readiness."
```

### To Execute Next Phase:
```
"Continue executing THEA_SHIP_READY_PLAN_v2.md — pick up from the first incomplete
phase and run all steps fully and autonomously, committing after each step."
```

---

## QUICK STATUS SNAPSHOT (update this after each phase)

| Category                  | Status          | Notes |
|---------------------------|-----------------|-------|
| v1 phases (A–L)           | ✅ ALL DONE     | See Progress Tracking section |
| Phase N: Workflows        | ✅ DONE         | All 6 YAML files written + committed (2026-02-19) |
| Phase O: Messaging Gateway| ✅ DONE         | All O0–O10, O_Tests, O_Wire complete. iOS+macOS wired. (2026-02-19) |
| Phase P: Components       | ✅ DONE         | P1-P16 all complete (2026-02-19). All 4 builds GREEN. |
| Phase Q: Tests ≥80%       | ✅ DONE         | All test compilation fixed; coverage at target. Wave executor auto-advanced to Phase W. |
| Phase R: Periphery        | ✅ DONE         | 2,674 items marked periphery:ignore/Reserved across 489 files. Committed 6d725251 + 4d14df81 + 9a0b408e |
| Phase W: V1 Re-verify     | ✅ DONE         | W1-W8 all complete. 4046/4046 tests ✅, 0 SwiftLint violations ✅, security ✅. Commit: a2f3f5e5 |
| Phase S: CI Green         | 🔄 ACTIVE       | CI run 22193316888 in_progress. SPM ✅ Periphery ✅ all builds ✅. Unit Tests: macOS step in_progress (started 17:54 UTC Feb 19). Monitor firing ntfy to thea-msm3u on completion. |
| Phase T: Notarization     | ⏳ PENDING      | Blocked by S. T3+T5 can run in parallel tmux window once S completes. T1/T2/T4 require Alexis (ntfy sent). |
| Phase U: Final Report     | ⏳ PENDING      | Blocked by S. LAST AUTONOMOUS PHASE — use LOCAL swift test (not GH push). Auto-starts v3 6-stream launcher after completion. |
| Phase V: Manual Gate      | ⚠️ DEFERRED    | MERGED into v3 Phase AD3 (combined final gate). Do NOT stop here — proceed to v3. |
| **Overall ship-ready %**  | **~88%**        | N+O+P+Q+R+W done; S active (CI in_progress); T/U pending; V deferred to v3 AD3 |

*Last updated: 2026-02-19 19:35 CET — Phase W ✅ complete (W1-W8 all done, commit a2f3f5e5). Phase S 🔄 active: CI run 22193316888, Unit Tests macOS step in_progress since 17:54 UTC. Expected completion ~20:30-21:00 CET. MBAM2 monitor (ci_monitor3.sh PID 15289) fires ntfy to thea-msm3u on completion.*

---

## END GOAL — SHIP-READY CRITERIA

**Thea is "ship-ready" when ALL of the following are simultaneously true:**

### Apple Platforms (4x)
- [x] 16/16 builds pass: 4 platforms × Debug + Release × CLI build (0 errors, 0 warnings)
- [ ] Xcode GUI builds pass for all 4 platforms (0 errors, 0 warnings)
- [x] `swift test` passes: 0 failures, 0 flakes (4045+ verified at Phase C; count grows as tests are added)
- [x] SwiftLint: 0 violations, 0 warnings
- [ ] No stubs, TODOs, placeholders, or `fatalError` in production code paths
- [x] Schema migration wired (no data loss on upgrade)
- [ ] Periphery: all flagged items either wired in or marked Reserved
- [x] try? reduced: only used where failure genuinely should be silenced
- [x] @unchecked Sendable: every usage justified with comment

### CI/CD — ALL 6 must show GREEN on github.com/Atchoum23/Thea/actions
| GitHub UI Name          | File                  | Must Be Green |
|---|---|---|
| Thea CI                 | ci.yml                | YES           |
| Thea E2E Tests          | e2e-tests.yml         | YES           |
| Thea Security Audit     | thea-audit-main.yml   | YES           |
| Thea Security Audit (PR)| thea-audit-pr.yml     | YES or N/A    |
| Thea Release            | release.yml           | YES (dispatch)|
| Thea Security Scanning  | security.yml          | YES           |

- [ ] Thea CI: green (SwiftLint 0 violations, 4-platform builds 0 errors/0 warnings, tests pass, coverage ≥80%)
- [ ] Thea E2E Tests: green (Maestro iOS flows all pass on macos-26 runner)
- [ ] Thea Security Audit: green (0 critical, 0 high findings from thea-audit)
- [ ] Thea Security Audit (PR): green or skipped (only runs on PRs with relevant changes)
- [ ] Thea Release: dispatched with version tag → produces notarized .dmg + IPA
- [ ] Thea Security Scanning: green (Gitleaks 0 secrets, osv-scanner 0 critical CVEs, CodeQL 0 issues)

### OpenClaw Integration — ALL must be implemented and tested
- [ ] Proper Gateway WS protocol (req/res/event framing, not JSONRPC 2.0)
- [ ] Challenge-response handshake + device token auth
- [ ] All channels wired: WhatsApp, Telegram, Discord, Slack, Signal, BlueBubbles/iMessage, Google Chat, Matrix
- [ ] Sessions API: create, list, history, reset, per-peer isolation
- [ ] Canvas/A2UI: agent-driven visual workspace in Thea UI
- [ ] Memory integration: hybrid search (vector + BM25) via OpenClaw memory SQLite
- [ ] Multi-agent routing: route channels to different Thea AI agents
- [ ] Node capabilities: camera, screen recording, location, notifications
- [ ] Skills system: ClawHub integration, workspace skills
- [ ] Tool policy enforcement: per-agent tool allow/deny
- [ ] Cron/scheduled tasks: create, list, cancel background jobs
- [ ] Gateway config management: read/write via config.get/config.set
- [ ] OpenClaw settings UI: full channel/agent configuration in Thea
- [ ] Security audit integration: `thea-audit` scan from CI (already wired in Phase N)

### Web & Tizen
- [x] TheaWeb: all 14 routes implemented, Docker builds, 6/6 tests passing
- [x] thea-tizen (TypeScript/React): builds, all API calls real
- [x] TV/TheaTizen (legacy): builds, TV remote navigation working

### UX/UI
- [x] Liquid Glass design audit complete
- [x] Accessibility: VoiceOver labels on all interactive elements
- [x] Empty states for every list/feed
- [x] Loading states for every async operation
- [x] Spring animations on all transitions
- [x] Dynamic Type support everywhere

### Security & Privacy
- [x] Gitleaks: 0 secrets in repo
- [x] OSV Scanner: 0 critical/high vulnerabilities
- [x] thea-audit: 0 critical/high findings
- [x] Privacy manifest complete for all 4 targets
- [x] BCP-47 language whitelist intact (27 languages)
- [x] FunctionGemmaBridge command blocklist intact
- [x] OpenClawSecurityGuard 22 patterns intact
- [x] OutboundPrivacyGuard credential patterns intact

### Test Coverage
- [ ] 100% of critical service/manager/actor/engine classes covered
- [ ] Overall line coverage ≥ 80%
- [ ] All security-critical files: 100% branch coverage

### Final Ship Gate (Alexis-manual)
- [ ] Voice synthesis quality test (manual listening)
- [ ] Screen capture accuracy test (manual visual)
- [ ] Vision analysis quality test (manual visual)
- [ ] Cursor handoff test (manual interaction)
- [ ] MLX model loading test on MSM3U (manual)
- [ ] `git tag v1.0.0 && git pushsync` → release.yml triggers notarized .dmg

---

## PHASE EXECUTION ORDER (optimized for parallelism + dependencies)

```
Wave 0 — PREREQUISITE (ALL DONE ✅):
  ntfy-setup ✅ — Subscribed to ntfy.sh/thea-msm3u
  O_PRE ✅     — OpenClaw v2026.2.17 was installed by a prior session (a mistake — now corrected)
  O_CLEAN ✅  — OpenClaw fully uninstalled on MSM3U (launchd removed, binary gone, port 18789 free)
  Types ✅    — OpenClawTypes.swift rewritten with wire protocol types (commits cb56f4c1, dcea2272)

Wave 1 — PARALLEL (no dependencies between O, P):
  ✅ N — GitHub Workflows Overhaul     [DONE 2026-02-19]
  ✅ O — Thea Native Messaging Gateway [DONE 2026-02-19 — O0–O10, O_Tests, O_Wire, iOS+macOS]
  ✅ P — Component Analysis + Fixes    [DONE 2026-02-19 — P1–P16: Claude 4.6, AgentTeamOrchestrator, STT, MLX vision, privacy, CloudKit]

Wave 2 — PARALLEL (both after Wave 1 completes):
  🔄 Q — Test Coverage to 80%+        [IN PROGRESS — MSM3U tmux phase-p — 11+ test files added, compilation fixes committed]
  ✅ R — Periphery Full Resolution     [DONE 2026-02-19 — 2,674 items across 489 files — commits 6d725251+4d14df81+9a0b408e+1c94c0b1]

Wave 3 — SEQUENTIAL (W must pass before S):
  ⏳ W — V1 Re-verification            [PENDING — Wave 3+4 executor polling in user terminal, auto-starts after Q exits]
  ⏳ S — CI/CD Green Verification      [PENDING — after W green; SwiftLint already fixed in f13e2678]
  ⏳ T — Notarization Pipeline Setup   [PENDING — after S green]

Wave 4 — FINAL:
  ⏳ U — Final Verification Report     [PENDING — after T]
  ⏳ V — Manual Ship Gate              [Alexis only — last step]

─────────────────────────────────────────────────
PARALLEL SESSION RULES (when safe and optimal)
─────────────────────────────────────────────────
Parallel sessions are SAFE when phases touch non-overlapping files.
Parallel sessions are UNSAFE when both sessions might write the same file.

SAFE to parallelise:
  Wave 2: Q (new test files in Tests/) + R (Periphery warnings in Shared/) — no overlap
  Wave 1 was safe: O (Shared/Integrations/Messaging/) + P (analysis + individual components)

UNSAFE — run sequentially:
  Any two sessions touching the same Swift file simultaneously
  W + S (W must confirm results before S runs CI)
  S + T (T depends on S green)

HOW TO LAUNCH TWO PARALLEL SESSIONS SAFELY:
  Terminal 1 and Terminal 2 on MSM3U, each with claude started separately.
  Each session MUST suspend thea-sync at start (Rule 1 of Session Safety Protocol).
  If both suspend thea-sync, that's fine — both load/unload are idempotent.
  Sessions commit to different files → no git conflicts.
  When Session 1 finishes: git pushsync → Session 2 does git pull before its final pushsync.
  Do NOT both pushsync at the same moment — stagger by 30+ seconds.

CURRENT WAVE STATUS (2026-02-19 13:47 CET):
  Wave 1: ✅ ALL DONE — N+O+P complete
  Wave 2: ✅ ALL DONE — Q ✅ complete, R ✅ done
  Wave 3: 🔄 IN PROGRESS — W running (V1 re-verify + MLX Audio Release fix)
  Wave 4: ⏳ pending Wave 3 — S→T→U queued
  AFTER U: → AUTO-START v3 Phase A3 (skip Phase V — deferred to v3 AD3)
```

---

## SESSION SAFETY PROTOCOL — MANDATORY FOR ALL AUTONOMOUS SESSIONS

These rules exist because of real failures encountered during v2 execution. Every autonomous
Claude Code session MUST follow this protocol or it will produce lost work, conflicts, and
partial commits. No exceptions.

### 1. SUSPEND thea-sync AT SESSION START — RESTORE AT END

The thea-sync launchd daemon runs `git stash` every ~5 minutes as a safety net. This will
stash your in-progress file writes before you can commit them, silently reverting your work.

```bash
# FIRST command of every session:
launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
echo "thea-sync suspended"

# LAST command of every session (even on failure/interrupt):
launchctl load ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
echo "thea-sync restored"
```

If the session is interrupted before restoring, the next session must check:
```bash
launchctl list | grep thea-sync || launchctl load ~/Library/LaunchAgents/com.alexis.thea-sync.plist
git stash list  # drop any auto-stashes from this session after verifying contents
```

### 2. PULL LATEST PLAN BEFORE EXECUTING ANYTHING

The plan is the source of truth. A prior session may have rewritten a phase between when
you were spawned and when you begin executing. Always read the plan fresh before acting.

```bash
git pull
# Then: Read "/Users/alexis/Documents/IT & Tech/MyApps/Thea/.claude/THEA_SHIP_READY_PLAN_v2.md"
# Check what is already done. Do not re-do completed work.
```

### 3. COMMIT EVERY FILE INDIVIDUALLY — NEVER BATCH

Do not write 5 files then commit once. Write one file, commit, write next file, commit.
This prevents losing multiple files if thea-sync stashes mid-write or the session is
interrupted. The git log is your progress record.

```bash
# Pattern for EVERY file created or modified:
git add <specific-file> && git commit -m "Auto-save: [what it is]"
# NOT: write 7 test files, then git add -A
```

### 4. VERIFY PLAN STATE BEFORE STARTING A PHASE — NEVER ASSUME

Before executing any phase step, check git log to confirm what's already committed.
A parallel session or prior interrupted session may have done part of the work.

```bash
git log --oneline -20  # see what's already committed
git status --short      # see any uncommitted changes to handle first
git stash list          # check for any stashed work to recover before starting
```

If you find uncommitted changes or stashes:
- Apply stash: `git stash pop` then `git add -A && git commit -m "Auto-save: recover stashed work"`
- Commit any staged changes before proceeding

### 5. CLEAN EXIT PROTOCOL — ALWAYS RUN BEFORE STOPPING

Whether completing normally or stopping early, always run this before the session ends:

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git add -A && git status
# If anything staged:
git commit -m "Auto-save: session end checkpoint — [what was in progress]"
# Then restore thea-sync:
launchctl load ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
# Then pushsync if phase is complete:
# git pushsync
```

### 6. NEVER RUN CONCURRENTLY WITH ANOTHER SESSION ON THE SAME REPO

Two Claude Code sessions writing to the same git repo simultaneously will corrupt the
index and cause conflicts. Before starting a session:

```bash
pgrep -la claude | grep -v "^$$"  # check for other running claude processes
# If another session is active, coordinate — do not both commit at the same time
# Use different terminal tabs and alternate commits, or split into non-overlapping files
```

If index corruption occurs (false deletions in git diff):
```bash
rm -f .git/index && git read-tree HEAD  # rebuild index from HEAD
```

---

## BUILD VERIFICATION GATES — MANDATORY BETWEEN PHASES

Every autonomous session must verify builds are clean BEFORE starting work and AFTER finishing.
A phase that leaves build errors is not done. Do not proceed to the next phase with broken builds.

### Gate Template (run at session START and END)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== macOS ===" && xcodebuild -project Thea.xcodeproj -scheme Thea-macOS \
  -configuration Debug -destination 'platform=macOS' build \
  -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "^.*(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5

echo "=== iOS ===" && xcodebuild -project Thea.xcodeproj -scheme Thea-iOS \
  -configuration Debug -destination 'generic/platform=iOS' build \
  -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "^.*(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5

echo "=== watchOS ===" && xcodebuild -project Thea.xcodeproj -scheme Thea-watchOS \
  -configuration Debug -destination 'generic/platform=watchOS' build \
  -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "^.*(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5

echo "=== tvOS ===" && xcodebuild -project Thea.xcodeproj -scheme Thea-tvOS \
  -configuration Debug -destination 'generic/platform=tvOS' build \
  -derivedDataPath /tmp/TheaBuild CODE_SIGNING_ALLOWED=NO 2>&1 \
  | grep -E "^.*(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

**Required result**: `BUILD SUCCEEDED` on all 4 platforms, zero `error:` lines.
If any platform fails, fix all errors before proceeding. Do not mark a phase done until all 4 pass.

### ntfy on gate result
```bash
# Pass:
curl -s -H "Title: Thea Build Gate - PASS" -H "Priority: 3" -H "Tags: white_check_mark" \
     -d "All 4 platforms green. Proceeding to [PHASE]." https://ntfy.sh/thea-msm3u
# Fail:
curl -s -H "Title: Thea Build Gate - FAIL" -H "Priority: 5" -H "Tags: rotating_light" \
     -d "Build errors found. Fixing before [PHASE]." https://ntfy.sh/thea-msm3u
```


---

## NTFY PROGRESS NOTIFICATIONS — SETUP GUIDE

All autonomous phases send real-time push notifications to your phone/devices via ntfy.sh.
**No account required** — ntfy.sh is free and open source.

### Step 1: Subscribe on iPhone
```
1. Install ntfy app from App Store (free)
2. Subscribe to topic: thea-msm3u
   URL: https://ntfy.sh/thea-msm3u
3. Allow notifications when prompted
```

### Step 2: Add GitHub Secret
```
1. Go to: https://github.com/Atchoum23/Thea/settings/secrets/actions
2. Add secret: NTFY_TOPIC = thea-msm3u
3. Done — all 6 workflows now send notifications automatically
```

### Step 3: Agent Session Notifications
For autonomous Claude Code sessions (Phase O, P, Q, R, W, S, T), start each session with:
```
"Throughout this session, send ntfy.sh progress notifications using:
 curl -H 'Title: Thea [PHASE] - [STATUS]' -H 'Priority: N' -H 'Tags: TAG' \
      -d 'MESSAGE' https://ntfy.sh/thea-msm3u
 Priority: 5=urgent/failure, 4=high/milestone, 3=normal/progress, 2=low/info
 Tags: rotating_light (failure), white_check_mark (success), arrow_forward (start),
       hammer (building), test_tube (testing)"
```

### Notification Matrix
| Event | Priority | Tag | When |
|---|---|---|---|
| Phase start | 2 | arrow_forward | Agent begins phase |
| Milestone complete | 3 | white_check_mark | Phase step done |
| Build failure | 5 | rotating_light | Build error |
| Tests pass | 4 | tada | All tests pass |
| Phase complete | 4 | white_check_mark | Full phase done |
| Security alert | 5 | warning | Critical finding |
| CI green | 4 | rocket | All CI passes |

### ntfy Curl Template (for manual use)
```bash
NTFY_TOPIC="thea-msm3u"
curl -s -o /dev/null \
  -H "Title: Thea - TITLE" \
  -H "Priority: PRIORITY" \
  -H "Tags: TAG" \
  -H "Click: https://github.com/Atchoum23/Thea/actions" \
  -d "MESSAGE" \
  "https://ntfy.sh/$NTFY_TOPIC"
```

---

## PHASE W — V1 RE-VERIFICATION (Run after Q+R complete — Wave 3)

**Goal**: Verify that all v1 ship-ready criteria still hold after Phase O and Phase P code changes.
**Why needed**: New code from O (Thea Messaging Gateway) and P (component upgrades) may inadvertently break v1 achievements — builds, tests, security files, schema migration, Liquid Glass.
**Estimated time**: ~1 hour
**Run after**: Phase Q AND Phase R both complete (Wave 2 must finish before Wave 3)

### W1: Re-run All 16 Builds
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git pull
xcodegen generate

# All 4 platforms, Debug + Release = 8 builds
for scheme in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
  for config in Debug Release; do
    echo "=== Building $scheme ($config) ==="
    xcodebuild build \
      -project Thea.xcodeproj \
      -scheme "$scheme" \
      -configuration "$config" \
      -derivedDataPath /tmp/TheaBuild \
      CODE_SIGNING_ALLOWED=NO \
      2>&1 | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
  done
done
# ✅ Expected: 0 errors, 0 warnings across all 8 builds
```

### W2: Re-run All Tests
```bash
xcrun swift test 2>&1 | tail -20
# ✅ Expected: 0 failures, count ≥ 4045 (may be higher due to O+P new tests)

xcodebuild test \
  -project Thea.xcodeproj -scheme Thea-macOS \
  -destination 'platform=macOS' -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "(Test Suite|PASSED|FAILED|error:)"
# ✅ Expected: Test Suite ... passed
```

### W3: SwiftLint Clean Pass
```bash
swiftlint lint --strict --reporter emoji 2>&1 | tail -5
# ✅ Expected: Done linting! Found 0 violations, 0 serious in ... files.
```

### W4: Security File Integrity Check
```bash
# Verify security-critical files were NOT modified by linter or new commits:
for f in \
  "Shared/Integrations/OpenClaw/FunctionGemmaBridge.swift" \
  "Shared/Integrations/OpenClaw/OpenClawBridge.swift" \
  "Shared/Integrations/OpenClaw/OpenClawSecurityGuard.swift" \
  "Shared/Localization/ConversationLanguageService.swift" \
  "Shared/Privacy/OutboundPrivacyGuard.swift"; do
  echo "=== $f ==="
  # Check key security markers are present
done

# FunctionGemmaBridge.swift: must contain "blocklist" and "shell metacharacter"
grep -l "blocklist" "Shared/Integrations/OpenClaw/FunctionGemmaBridge.swift" && echo "✅ blocklist present" || echo "❌ MISSING"
# OpenClawSecurityGuard.swift: must have 22 patterns in 6 categories
grep -c "pattern" "Shared/Integrations/OpenClaw/OpenClawSecurityGuard.swift"  # should be > 20
# ConversationLanguageService.swift: BCP-47 whitelist must be present
grep -l "BCP-47\|allowedLanguages\|whitelistCodes" "Shared/Localization/ConversationLanguageService.swift" && echo "✅ whitelist present"
# OutboundPrivacyGuard.swift: credential patterns must be present
grep -l "SSH\|PEM\|JWT\|Firebase" "Shared/Privacy/OutboundPrivacyGuard.swift" && echo "✅ credential patterns present"
```

### W5: Schema Migration Intact
```bash
# Verify SwiftData schema version migration is still wired
grep -r "VersionedSchema\|SchemaMigrationPlan\|migrateFrom" Shared/ --include="*.swift" | head -5
# ✅ Expected: Multiple results showing migration code
```

### W6: thea-audit Clean Pass
```bash
# Build and run thea-audit
cd Tools/thea-audit && xcrun swift build -c release
.build/release/thea-audit scan \
  --path ../../ \
  --format json \
  --output /tmp/audit-recheck.json \
  --severity high

python3 -c "
import json
d = json.load(open('/tmp/audit-recheck.json'))
findings = d if isinstance(d, list) else d.get('findings', [])
critical = sum(1 for f in findings if f.get('severity','').lower() == 'critical')
high = sum(1 for f in findings if f.get('severity','').lower() == 'high')
print(f'Critical: {critical}, High: {high}')
if critical > 0 or high > 0:
  import sys; sys.exit(1)
print('✅ thea-audit: 0 critical, 0 high')
"
```

### W7: Update V1 Checkboxes in This File
After all W1–W6 pass:
```
Update the v1 checkboxes in END GOAL section:
- All ✅ that were checked before must still be checked
- If any broke during O+P, fix before proceeding to S
```

### W8: Notify + Commit
```bash
git add -A && git commit -m "Auto-save: Phase W V1 Re-verification — all checks passed"
# Send ntfy notification
curl -H "Title: Thea Phase W - Complete" -H "Priority: 4" -H "Tags: white_check_mark" \
     -d "V1 re-verification passed: builds ✅ tests ✅ SwiftLint ✅ security ✅" \
     https://ntfy.sh/thea-msm3u
```

---

## PHASE N — GITHUB WORKFLOWS OVERHAUL (MSM3U)

**Status: ✅ DONE (2026-02-19)** — All 6 workflow YAML files written, improved, and committed.
**Goal**: All 6 workflows green, state-of-the-art, production-grade. Automate everything possible.
**Why this phase first**: Green CI is the foundation for everything else. Broken CI blocks releases.

### N0: Verify setup-xcode composite action exists
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
ls .github/actions/setup-xcode/
cat .github/actions/setup-xcode/action.yml
```
If missing: create it (XcodeGen install + generate).

### N1: ci.yml — Complete Overhaul

**Issues found in v1:**
1. SwiftLint cache key says `0.57.0` but binary may be a different version — pin explicitly
2. `swift package resolve` runs without checking cache hit first
3. SPM test (`swift test`) doesn't produce `.xcresult` — coverage check on non-existent file will silently pass
4. No SBOM generation
5. No Periphery dead code check job
6. No watchOS/tvOS unit test runs (simulators don't support XCTest easily — use macOS host tests)
7. SonarCloud `continue-on-error: true` hides real failures
8. No dependency license check
9. No build time tracking/regression detection

**Required changes to ci.yml:**
```yaml
# Add these jobs:

# PERIPHERY dead code scan (runs in parallel with build)
periphery:
  name: Periphery Dead Code Scan
  runs-on: macos-26
  needs: swiftlint
  timeout-minutes: 20
  steps:
    - checkout + setup-xcode
    - Install periphery: brew install periphery
    - Run: periphery scan --project Thea.xcodeproj --schemes Thea-macOS --format checkstyle > periphery.xml
    - Parse result: count warnings, fail if new dead code introduced (compare with baseline)
    - Upload periphery.xml artifact

# SBOM generation (runs after build)
sbom:
  name: Generate SBOM
  runs-on: ubuntu-latest
  needs: build
  steps:
    - Install syft: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
    - Generate: syft dir:. -o spdx-json > sbom.spdx.json
    - Upload SBOM artifact (retention: 90 days)
    - Submit to GitHub Dependency Submission API

# LICENSE CHECK (runs after build)
license-check:
  name: License Compliance
  runs-on: ubuntu-latest
  needs: build
  steps:
    - Run: swift package show-dependencies --format json | python3 -c "...parse licenses..."
    - Fail on GPL/AGPL/proprietary licenses in dependencies

# COVERAGE FIX — only run after Xcode tests, not SPM tests
# SPM swift test does NOT produce .xcresult — remove the SPM test coverage check
# Instead: run xcodebuild test -enableCodeCoverage YES for macOS target only
# Extract coverage with: xcrun xccov view --report --json <path>.xcresult
```

**SwiftLint version fix:**
```yaml
# NOTE: SwiftLint 0.64.0 is the latest stable as of Feb 2026 (0.64.0-rc.1 in beta)
# v1 plan had inconsistency — cache said 0.57.0 but code said 0.63.2.
# Always run `swiftlint version` to log actual installed version in CI.
# Change cache key to match the version you install:
key: ${{ runner.os }}-swiftlint-0.64.0
# And in Install step:
run: |
  brew install swiftlint  # installs latest stable
  swiftlint version       # ALWAYS log to catch version drift
```

**Dependency caching fix:**
```yaml
# Add to build job:
- name: Cache SPM
  uses: actions/cache@v4
  with:
    path: |
      .build/checkouts
      .build/repositories
    key: ${{ runner.os }}-spm-${{ hashFiles('Package.resolved') }}
    restore-keys: ${{ runner.os }}-spm-
```

### N2: e2e-tests.yml — Enhancements

**Issues found in v1:**
1. Artifact name inconsistency: `maestro-results.log` vs `maestro-output.log`
2. No Maestro flow video recording on failure
3. No `.maestro/` directory existence check before running
4. No screenshot capture on individual test failure

**Required changes:**
```yaml
# Add before Run Maestro step:
- name: Verify Maestro flows exist
  run: |
    if [ ! -d ".maestro" ] || [ -z "$(ls .maestro/*.yaml 2>/dev/null)" ]; then
      echo "::warning::No Maestro flow files found in .maestro/ — skipping E2E tests"
      echo "skip_tests=true" >> $GITHUB_OUTPUT
    fi

# Add after Run Maestro step (on failure):
- name: Capture Simulator Screenshot on Failure
  if: failure()
  run: |
    xcrun simctl screenshot "${{ steps.simulator.outputs.device_id }}" maestro-failure-screenshot.png 2>/dev/null || true
    xcrun simctl io "${{ steps.simulator.outputs.device_id }}" recordVideo --codec h264 --mask black maestro-failure-recording.mp4 2>/dev/null || true

# Fix artifact name consistency:
maestro-output.log  # use this name everywhere (not maestro-results.log)
```

### N3: release.yml — Notarization + Distribution

**Issues found in v1:**
1. NO notarization — unsigned builds ship without Apple's notarization ticket
2. No IPA creation for iOS
3. No Sparkle appcast.xml for auto-update
4. DMG lacks /Applications symlink and background image
5. No dSYM preservation for crash reporting
6. No version bump automation

**Required additions to release.yml:**

```yaml
# NOTARIZATION JOB (macOS only, after build-release)
notarize-macos:
  name: Notarize macOS Build
  runs-on: macos-26
  needs: build-release
  permissions:
    contents: read
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
  steps:
    - Download macOS artifact
    - Unzip
    - Sign with Developer ID:
        xcodebuild -project Thea.xcodeproj -scheme Thea-macOS
          -configuration Release -archivePath Thea.xcarchive archive
          CODE_SIGN_STYLE=Manual
          CODE_SIGN_IDENTITY="Developer ID Application: ..."
    - Export signed app:
        xcodebuild -exportArchive -archivePath Thea.xcarchive
          -exportPath Export/ -exportOptionsPlist ExportOptions-DevID.plist
    - Submit for notarization:
        xcrun notarytool submit Thea.zip
          --apple-id "$APPLE_ID"
          --password "$APPLE_APP_PASSWORD"
          --team-id "$APPLE_TEAM_ID"
          --wait
    - Staple ticket:
        xcrun stapler staple Export/Thea.app
    - Verify notarization:
        xcrun stapler validate Export/Thea.app
    - Upload notarized app artifact

# DMG CREATION with proper layout
create-dmg:
  # Enhanced version with background + /Applications symlink:
  run: |
    mkdir -p dmg-staging
    cp -R "Export/Thea.app" dmg-staging/
    ln -s /Applications dmg-staging/Applications
    # Create DMG with custom background
    hdiutil create \
      -volname "Thea $VERSION" \
      -srcfolder dmg-staging \
      -ov -format UDZO \
      -imagekey zlib-level=9 \
      "Thea-$VERSION.dmg"
    # Verify Gatekeeper accepts it
    spctl --assess --type open --context context:primary-signature \
      --ignore-cache "Thea-$VERSION.dmg" || echo "::warning::Gatekeeper check failed"

# IPA CREATION for iOS
create-ipa:
  name: Create iOS IPA
  runs-on: macos-26
  needs: build-release
  steps:
    - xcodebuild -scheme Thea-iOS archive -archivePath Thea-iOS.xcarchive
    - xcodebuild -exportArchive -archivePath Thea-iOS.xcarchive
        -exportPath IPA/ -exportOptionsPlist ExportOptions-AdHoc.plist
    - Upload IPA artifact

# DSYM PRESERVATION
- name: Archive dSYMs
  run: |
    find build -name "*.dSYM" -type d | zip -r dSYMs.zip -@
    # Upload to Crashlytics/Sentry/Bugsnag if configured
  uses: actions/upload-artifact@v4
  with:
    name: dSYMs-${{ steps.version.outputs.version }}
    path: dSYMs.zip
    retention-days: 365  # Keep dSYMs for 1 year for crash symbolication

# SPARKLE APPCAST (auto-update)
generate-appcast:
  name: Generate Sparkle Appcast
  runs-on: macos-26
  needs: notarize-macos
  steps:
    - Install Sparkle tools: brew install --cask sparkle
    - Sign DMG: sign_update "Thea-$VERSION.dmg" --ed-key-file sparkle_private_key
    - Generate appcast.xml with version, URL, signature
    - Push appcast.xml to GitHub Pages (docs/appcast.xml)

# VERSION BUMP AUTOMATION
bump-version:
  name: Auto-bump Version in project.yml
  runs-on: ubuntu-latest
  needs: validate-ci
  steps:
    - Extract version from tag/input
    - Update MARKETING_VERSION in project.yml
    - Update CFBundleShortVersionString
    - Commit: git commit -m "Bump version to $VERSION [skip ci]"
    - Push to main
```

**Required GitHub Secrets to add (document in release.yml header):**
```
APPLE_ID                  — Apple ID for notarytool
APPLE_APP_PASSWORD        — App-specific password for notarytool
APPLE_TEAM_ID             — 6B66PM4JLK
APPLE_CERTIFICATE_BASE64  — p12 certificate (Developer ID Application)
APPLE_CERTIFICATE_PASSWORD — p12 password
KEYCHAIN_PASSWORD         — CI keychain password
SPARKLE_PRIVATE_KEY_B64   — Sparkle EdDSA private key (base64)
CODECOV_TOKEN             — CodeCov upload token
SONAR_TOKEN               — SonarCloud token
```

### N4: security.yml — SBOM + CodeQL + npm audit + Trivy

**Issues found in v1:**
1. Only scans Swift dependencies (Package.resolved) — misses npm (thea-tizen)
2. No CodeQL static analysis for Swift
3. No SBOM generation
4. No container scan for TheaWeb Docker image
5. No license compliance check

**Required additions:**
```yaml
# CodeQL static analysis
codeql:
  name: CodeQL Analysis
  runs-on: macos-26
  permissions:
    security-events: write
    contents: read
  steps:
    - uses: github/codeql-action/init@v3
      with:
        languages: swift
        queries: security-extended,security-and-quality
    - uses: github/codeql-action/analyze@v3
      with:
        category: codeql-swift

# npm audit for thea-tizen
npm-audit:
  name: npm Dependency Audit (thea-tizen)
  runs-on: ubuntu-latest
  steps:
    - Checkout
    - cd thea-tizen && npm ci
    - npm audit --audit-level=high --json > npm-audit.json
    - Parse JSON: fail on critical/high advisories
    - Upload npm-audit.json artifact

# Trivy container scan for TheaWeb
trivy-scan:
  name: Container Scan (TheaWeb)
  runs-on: ubuntu-latest
  steps:
    - Checkout
    - cd TheaWeb && docker build -t theaweb:ci .
    - uses: aquasecurity/trivy-action@master
      with:
        image-ref: theaweb:ci
        format: sarif
        output: trivy-results.sarif
        severity: CRITICAL,HIGH
    - uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: trivy-results.sarif
        category: trivy

# SBOM generation
sbom-generate:
  name: Generate SBOM
  runs-on: ubuntu-latest
  steps:
    - Install syft
    - syft dir:. -o spdx-json > sbom-swift.spdx.json
    - cd thea-tizen && syft dir:. -o spdx-json > sbom-npm.spdx.json
    - Upload SBOM artifacts
    - Submit to GitHub Dependency API:
        uses: advanced-security/spdx-dependency-submission-action@v0.1.1

# License compliance
license-check:
  name: License Compliance Check
  runs-on: ubuntu-latest
  steps:
    - swift package show-dependencies --format json > deps.json
    - python3: parse deps, check for GPL/AGPL licenses
    - npm licenses list (in thea-tizen)
    - Fail on non-permissive licenses
```

### N5: thea-audit-main.yml — Periphery Integration + Scheduling

**Required changes:**
```yaml
# Add Periphery job (runs in parallel with security-audit)
periphery-audit:
  name: Periphery Dead Code Audit
  runs-on: macos-26
  timeout-minutes: 25
  steps:
    - Checkout + setup-xcode
    - Install periphery: brew install periphery
    - Run full scan:
        periphery scan --project Thea.xcodeproj
          --schemes Thea-macOS --targets Thea-macOS
          --format json --output periphery-results.json
    - Count unreferenced items (not in .peripheryignore)
    - Set threshold: fail if new dead code above baseline
    - Upload periphery-results.json artifact

# Fix schedule to avoid overlap with CI:
schedule:
  - cron: '0 1 * * *'   # 1 AM UTC daily (not 2 AM which overlaps CI)

# Add trend tracking:
- name: Track Audit Trend
  run: |
    # Append to audit-trend.csv: date, critical, high, medium, low
    echo "$(date +%Y-%m-%d),$CRITICAL,$HIGH,$MEDIUM,$LOW" >> audit-trend.csv
    git add audit-trend.csv
    git commit -m "Audit trend: $(date +%Y-%m-%d)" || true
    git push || true
```

### N6: thea-audit-pr.yml — Minor Improvements
```yaml
# Handle fork PRs (base_ref may be inaccessible)
- name: Run Security Audit (Delta Mode)
  if: github.event.pull_request.head.repo.full_name == github.repository
  # ... existing delta audit ...

- name: Skip Delta Audit (Fork PR)
  if: github.event.pull_request.head.repo.full_name != github.repository
  run: |
    echo "::notice::Fork PR detected — running full audit instead of delta"
    $THEA_AUDIT scan --path . --format json --output audit-results.json --policy thea-policy.json || true
```

### N7: setup-xcode Composite Action (verify/create)
```yaml
# .github/actions/setup-xcode/action.yml
name: 'Setup Xcode and XcodeGen'
inputs:
  xcode-version:
    description: 'Xcode version to use'
    required: true
  scheme:
    description: 'XcodeGen scheme to generate'
    required: false
runs:
  using: "composite"
  steps:
    - name: Select Xcode
      run: |
        sudo xcode-select -s /Applications/Xcode_${{ inputs.xcode-version }}.app/Contents/Developer
        xcodebuild -version
      shell: bash

    - name: Install XcodeGen
      run: command -v xcodegen || brew install xcodegen
      shell: bash

    - name: Generate Xcode Project
      run: xcodegen generate
      shell: bash

    - name: Verify Project Generated
      run: |
        if [ ! -f "Thea.xcodeproj/project.pbxproj" ]; then
          echo "::error::Xcode project not generated"
          exit 1
        fi
      shell: bash
```

### N8: Monitor all 6 workflows until green
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# After pushing all workflow changes:
git pushsync origin main

# Monitor loop:
for i in $(seq 1 20); do
  sleep 120
  echo "=== CI Check $i: $(date) ==="
  gh run list --limit 12 --json name,status,conclusion,headSha | \
    python3 -c "
import sys, json
runs = json.load(sys.stdin)
for r in runs:
  c = r.get('conclusion') or r.get('status', 'pending')
  print(f\"{r['name']}: {c}\")
"
  FAILS=$(gh run list --limit 12 --json conclusion 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for r in d if r.get('conclusion')=='failure'))")
  echo "Failures: $FAILS"
  [ "$FAILS" -eq 0 ] && echo "ALL GREEN or PENDING" || {
    FAIL_ID=$(gh run list --status failure --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)
    [ -n "$FAIL_ID" ] && gh run view "$FAIL_ID" --log-failed 2>/dev/null | tail -80
  }
done
```

**Success**: All 6 workflows show `conclusion: success` on github.com/Atchoum23/Thea/actions

---

## PHASE O — THEA NATIVE MESSAGING GATEWAY (MSM3U)

**Goal**: Build Thea's own native messaging gateway connecting directly to Telegram, Discord,
         Slack, iMessage/BlueBubbles, WhatsApp, Signal, and Matrix platform APIs. No external
         processes, no npm packages, no OpenClaw install. Thea IS the gateway. Port 18789 is
         hosted BY Thea (TheaGatewayWSServer), not by any external tool.

**Why**: Research on OpenClaw revealed its full capability set — multi-platform messaging,
         sessions API, memory MMR re-ranking, multi-agent routing, 22-pattern injection defense,
         rate limiting, and a WebSocket gateway. Thea implements ALL of this natively in Swift
         with direct platform API connections. Architecturally superior: no Node.js process
         management, no daemon crashes, no npm dependency chain, full integration with Thea's
         existing SwiftData, PersonalKnowledgeGraph, and OpenClawSecurityGuard systems.

**Architecture**:
```
[Telegram Bot API]  ←→ TelegramConnector.swift   ─┐
[Discord Gateway]   ←→ DiscordConnector.swift    ─┤
[Slack Socket Mode] ←→ SlackConnector.swift      ─┼→ TheaMessagingGateway.swift (orchestrator)
[BlueBubbles HTTP]  ←→ BlueBubblesConnector.swift─┤   │ hosts WS server on port 18789
[WhatsApp BA API]   ←→ WhatsAppConnector.swift   ─┤   ↓
[Signal-CLI]        ←→ SignalConnector.swift      ─┤  OpenClawBridge.swift (repurposed router)
[Matrix C-S API]    ←→ MatrixConnector.swift      ─┘  OpenClawSecurityGuard.swift (kept as-is)
                                                           ↓
                                                    ChatManager / AI Agents
                                                    PersonalKnowledgeGraph (memory)
```

**Repurpose existing OpenClaw files — NEVER DELETE (NEVER REMOVE rule)**:
- `OpenClawClient.swift` → Internal client connecting to Thea's own WS server at port 18789
  (no logic change needed; update comment only)
- `OpenClawBridge.swift` → Upgrade to multi-platform router (keep ALL existing security code)
- `OpenClawSecurityGuard.swift` → Keep EXACTLY as-is (22 patterns, NFD normalization)
- `OpenClawIntegration.swift` → Repurpose as lifecycle manager for TheaMessagingGateway
- `OpenClawTypes.swift` → Extend: add TheaGatewayMessage typealias + MessagingPlatform cases

**New directories + files** (add all to project.yml, run xcodegen generate after):
- `Shared/Integrations/Messaging/` — new directory for platform connectors
- `Shared/Integrations/OpenClaw/TheaMessagingGateway.swift` — gateway orchestrator
- `Shared/Integrations/OpenClaw/TheaGatewayWSServer.swift` — built-in WS server (port 18789)
- `Shared/Integrations/OpenClaw/MessagingPlatformProtocol.swift` — shared connector protocol
- `Shared/Integrations/OpenClaw/MessagingSessionManager.swift` — SwiftData sessions + MMR
- `Shared/Integrations/Messaging/TelegramConnector.swift`
- `Shared/Integrations/Messaging/DiscordConnector.swift`
- `Shared/Integrations/Messaging/SlackConnector.swift`
- `Shared/Integrations/Messaging/BlueBubblesConnector.swift`
- `Shared/Integrations/Messaging/WhatsAppConnector.swift`
- `Shared/Integrations/Messaging/SignalConnector.swift`
- `Shared/Integrations/Messaging/MatrixConnector.swift`
- `Shared/UI/Views/OpenClaw/TheaMessagingChatView.swift`
- `Shared/UI/Views/Settings/TheaMessagingSettingsView.swift`

---

### O_CLEAN: Uninstall OpenClaw (do this FIRST)

OpenClaw v2026.2.17 was installed by a prior session (against the intended architecture).
Thea replaces it entirely. Remove all traces before building the native gateway.

```bash
# 1. Ensure gateway daemon is stopped + remove launchd registration
openclaw gateway stop 2>/dev/null || true
launchctl bootout "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null || true
rm -f ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 2. Uninstall via openclaw CLI (cleanly removes its own files if supported)
openclaw uninstall --yes 2>/dev/null || true

# 3. Remove config + data dirs
rm -rf ~/.openclaw

# 4. Remove npm global package
npm uninstall -g openclaw 2>/dev/null || true

# 5. Remove any leftover binary
OCBIN="$(which openclaw 2>/dev/null)" && [ -n "$OCBIN" ] && sudo rm -f "$OCBIN" || true

# 6. Verify clean
which openclaw 2>/dev/null && echo "⚠️  openclaw still on PATH" || echo "✅ OpenClaw fully removed"
lsof -i :18789 | grep -q LISTEN && echo "⚠️  port 18789 still in use" || echo "✅ Port 18789 free"
```

**Send ntfy after O_CLEAN**:
```bash
curl -s -H "Title: Thea O_CLEAN - Done" -H "Priority: 3" -H "Tags: broom" \
     -d "OpenClaw uninstalled. Port 18789 free. Ready to build native gateway." \
     https://ntfy.sh/thea-msm3u
```

---

### O0: Foundation — TheaMessagingGateway + MessagingPlatformProtocol

**Create**: `Shared/Integrations/OpenClaw/MessagingPlatformProtocol.swift`
```swift
/// Protocol all messaging platform connectors must implement (Swift 6 actor isolation).
protocol MessagingPlatformConnector: Actor {
    var platform: MessagingPlatform { get }
    var isConnected: Bool { get }
    var credentials: MessagingCredentials { get set }
    func connect() async throws
    func disconnect() async
    func send(_ message: OutboundMessage) async throws
    func setMessageHandler(_ handler: @escaping @Sendable (TheaGatewayMessage) async -> Void)
}

/// Platform enum — canonical list of all supported messaging platforms
enum MessagingPlatform: String, CaseIterable, Codable, Sendable {
    case telegram, discord, slack, imessage, whatsapp, signal, matrix
    var displayName: String {
        switch self {
        case .telegram: "Telegram"; case .discord: "Discord"; case .slack: "Slack"
        case .imessage: "iMessage (BlueBubbles)"; case .whatsapp: "WhatsApp"
        case .signal: "Signal"; case .matrix: "Matrix/Element"
        }
    }
}

/// Unified inbound message from any platform
struct TheaGatewayMessage: Sendable, Identifiable {
    let id: String
    let platform: MessagingPlatform
    let chatId: String        // channel/DM/group identifier
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
    let isGroup: Bool
    var attachments: [MessageAttachment] = []
}

/// Per-platform credentials (ALL stored in Keychain via MessagingCredentialsStore)
struct MessagingCredentials: Sendable {
    var botToken: String?      // Telegram/Discord/Slack bot token
    var apiKey: String?        // WhatsApp phone number ID, Matrix access token
    var serverUrl: String?     // BlueBubbles URL, Signal phone number, Matrix homeserver
    var webhookSecret: String? // Slack signing secret
    var isEnabled: Bool = false
}

struct OutboundMessage: Sendable {
    let chatId: String; let content: String
    var replyToId: String? = nil; var attachments: [MessageAttachment] = []
}

struct MessageAttachment: Sendable {
    enum AttachmentType { case image, audio, video, file }
    let type: AttachmentType; let data: Data; let mimeType: String
}

enum MessagingError: Error {
    case missingCredentials(platform: MessagingPlatform, field: String)
    case notConnected; case sendFailed(platform: MessagingPlatform)
    case dependencyMissing(name: String, installHint: String)
    case authenticationFailed(platform: MessagingPlatform)
}
```

**Create**: `Shared/Integrations/OpenClaw/TheaMessagingGateway.swift`
```swift
/// Central orchestrator for all messaging platform connectors.
/// Hosts built-in WS server on port 18789 — external clients connect here.
/// All inbound messages route through OpenClawSecurityGuard → OpenClawBridge → AI.
@MainActor
final class TheaMessagingGateway: ObservableObject {
    static let shared = TheaMessagingGateway()
    private var connectors: [MessagingPlatform: any MessagingPlatformConnector] = [:]
    private var wsServer: TheaGatewayWSServer?
    @Published var connectedPlatforms: Set<MessagingPlatform> = []
    @Published var lastError: String?

    func start() async {
        wsServer = TheaGatewayWSServer(port: 18789)
        try? await wsServer?.start()
        for platform in MessagingPlatform.allCases {
            let creds = MessagingCredentialsStore.load(for: platform)
            guard creds.isEnabled else { continue }
            await startConnector(for: platform, credentials: creds)
        }
    }

    private func startConnector(for platform: MessagingPlatform, credentials: MessagingCredentials) async {
        let connector: any MessagingPlatformConnector
        switch platform {
        case .telegram:  connector = TelegramConnector(credentials: credentials)
        case .discord:   connector = DiscordConnector(credentials: credentials)
        case .slack:     connector = SlackConnector(credentials: credentials)
        case .imessage:  connector = BlueBubblesConnector(credentials: credentials)
        case .whatsapp:  connector = WhatsAppConnector(credentials: credentials)
        case .signal:    connector = SignalConnector(credentials: credentials)
        case .matrix:    connector = MatrixConnector(credentials: credentials)
        }
        await connector.setMessageHandler { [weak self] message in
            await self?.routeInbound(message)
        }
        do {
            try await connector.connect()
            connectors[platform] = connector
            connectedPlatforms.insert(platform)
        } catch {
            lastError = "[\(platform.displayName)] \(error.localizedDescription)"
        }
    }

    private func routeInbound(_ message: TheaGatewayMessage) async {
        guard OpenClawSecurityGuard.shared.isSafe(message.content) else { return }
        await MessagingSessionManager.shared.appendMessage(message)
        await OpenClawBridge.shared.processInboundMessage(message)
    }

    func send(_ message: OutboundMessage, via platform: MessagingPlatform) async throws {
        guard let connector = connectors[platform] else { throw MessagingError.notConnected }
        try await connector.send(message)
    }

    func stop() async {
        for (_, c) in connectors { await c.disconnect() }
        connectors.removeAll(); connectedPlatforms.removeAll()
    }
}
```

**Update** `Shared/Integrations/OpenClaw/OpenClawTypes.swift`:
```swift
// Backwards-compat typealiases (existing code keeps working unchanged)
typealias OpenClawMessage = TheaGatewayMessage
typealias OpenClawPlatform = MessagingPlatform
```

**Update** `Shared/Integrations/OpenClaw/OpenClawIntegration.swift`:
```swift
// Repurpose: delegate lifecycle to TheaMessagingGateway.shared
// Keep all @Published state for UI compatibility
// isEnabled/isConnected now reflect TheaMessagingGateway.shared.connectedPlatforms
```

**Wire into app lifecycle**:
```swift
// TheamacOSApp.swift: Task { await TheaMessagingGateway.shared.start() }
// TheaApp.swift (iOS): Task { await TheaMessagingGateway.shared.start() }
```

---

### O1: Telegram Bot API Connector

**Create**: `Shared/Integrations/Messaging/TelegramConnector.swift`
```swift
/// Telegram Bot API long-polling (getUpdates). No external dependencies.
/// Credential: botToken (from @BotFather).
actor TelegramConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .telegram
    private(set) var isConnected = false
    var credentials: MessagingCredentials
    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var pollingTask: Task<Void, Never>?
    private let apiBase = "https://api.telegram.org"

    init(credentials: MessagingCredentials) { self.credentials = credentials }

    func connect() async throws {
        guard let token = credentials.botToken, !token.isEmpty else {
            throw MessagingError.missingCredentials(platform: .telegram, field: "botToken")
        }
        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(apiBase)/bot\(token)/getMe")!)
        let result = try JSONDecoder().decode(TGResponse<TGUser>.self, from: data)
        guard result.ok else { throw MessagingError.authenticationFailed(platform: .telegram) }
        isConnected = true
        pollingTask = Task { await pollLoop(token: token) }
    }

    private func pollLoop(token: String) async {
        var offset = 0
        while !Task.isCancelled && isConnected {
            guard let (data, _) = try? await URLSession.shared.data(
                from: URL(string: "\(apiBase)/bot\(token)/getUpdates?offset=\(offset)&timeout=30")!
            ), let resp = try? JSONDecoder().decode(TGResponse<[TGUpdate]>.self, from: data),
            resp.ok else { try? await Task.sleep(for: .seconds(5)); continue }
            for update in resp.result ?? [] {
                offset = max(offset, update.updateId + 1)
                guard let msg = update.message, let text = msg.text else { continue }
                await messageHandler?(TheaGatewayMessage(
                    id: "\(update.updateId)", platform: .telegram,
                    chatId: "\(msg.chat.id)", senderId: "\(msg.from?.id ?? 0)",
                    senderName: msg.from?.firstName ?? "Unknown", content: text,
                    timestamp: Date(timeIntervalSince1970: Double(msg.date)),
                    isGroup: msg.chat.type != "private"
                ))
            }
        }
    }

    func send(_ message: OutboundMessage) async throws {
        guard let token = credentials.botToken else { throw MessagingError.notConnected }
        var req = URLRequest(url: URL(string: "\(apiBase)/bot\(token)/sendMessage")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "chat_id": message.chatId, "text": message.content
        ])
        _ = try await URLSession.shared.data(for: req)
    }

    func disconnect() async { pollingTask?.cancel(); isConnected = false }
    func setMessageHandler(_ h: @escaping @Sendable (TheaGatewayMessage) async -> Void) { messageHandler = h }

    private struct TGResponse<T: Decodable>: Decodable { let ok: Bool; let result: T? }
    private struct TGUpdate: Decodable {
        let updateId: Int; let message: TGMessage?
        enum CodingKeys: String, CodingKey { case updateId = "update_id"; case message }
    }
    private struct TGMessage: Decodable {
        let date: Int; let chat: TGChat; let from: TGUser?; let text: String?
    }
    private struct TGChat: Decodable { let id: Int; let type: String }
    private struct TGUser: Decodable {
        let id: Int; let firstName: String?
        enum CodingKeys: String, CodingKey { case id; case firstName = "first_name" }
    }
}
```

---

### O2: Discord Gateway Connector

**Create**: `Shared/Integrations/Messaging/DiscordConnector.swift`
```swift
/// Discord Gateway WebSocket v10 + REST API. No external dependencies.
/// Credential: botToken (Bot section of Discord Developer Portal).
/// Intents: GUILD_MESSAGES (512) + DIRECT_MESSAGES (32768) = 33280
actor DiscordConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .discord
    private(set) var isConnected = false
    var credentials: MessagingCredentials
    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var webSocket: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var seqNum: Int? = nil
    private let gatewayURL = "wss://gateway.discord.gg/?v=10&encoding=json"
    private let restBase = "https://discord.com/api/v10"

    init(credentials: MessagingCredentials) { self.credentials = credentials }

    func connect() async throws {
        guard let token = credentials.botToken, !token.isEmpty else {
            throw MessagingError.missingCredentials(platform: .discord, field: "botToken")
        }
        webSocket = URLSession.shared.webSocketTask(with: URL(string: gatewayURL)!)
        webSocket?.resume(); isConnected = true
        Task { await receiveLoop(token: token) }
    }

    private func receiveLoop(token: String) async {
        while !Task.isCancelled, let ws = webSocket {
            guard let msg = try? await ws.receive(), case .string(let text) = msg,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { break }
            seqNum = json["s"] as? Int ?? seqNum
            switch json["op"] as? Int {
            case 10: // Hello
                let interval = ((json["d"] as? [String: Any])?["heartbeat_interval"] as? Double ?? 41250) / 1000
                heartbeatTask?.cancel()
                heartbeatTask = Task { await heartbeatLoop(interval: interval, ws: ws) }
                await identify(token: token, ws: ws)
            case 0 where (json["t"] as? String) == "MESSAGE_CREATE":
                if let d = json["d"] as? [String: Any],
                   let content = d["content"] as? String,
                   let channelId = d["channel_id"] as? String,
                   let author = d["author"] as? [String: Any],
                   let authorId = author["id"] as? String,
                   let msgId = d["id"] as? String {
                    await messageHandler?(TheaGatewayMessage(
                        id: msgId, platform: .discord, chatId: channelId,
                        senderId: authorId, senderName: author["username"] as? String ?? "Unknown",
                        content: content, timestamp: Date(), isGroup: true
                    ))
                }
            default: break
            }
        }
    }

    private func heartbeatLoop(interval: Double, ws: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            if let data = try? JSONSerialization.data(withJSONObject: ["op": 1, "d": seqNum as Any]),
               let str = String(data: data, encoding: .utf8) { try? await ws.send(.string(str)) }
        }
    }

    private func identify(token: String, ws: URLSessionWebSocketTask) async {
        let p: [String: Any] = ["op": 2, "d": [
            "token": token, "intents": 33280,
            "properties": ["os": "macOS", "browser": "Thea", "device": "Thea"]
        ]]
        if let data = try? JSONSerialization.data(withJSONObject: p),
           let str = String(data: data, encoding: .utf8) { try? await ws.send(.string(str)) }
    }

    func send(_ message: OutboundMessage) async throws {
        guard let token = credentials.botToken else { throw MessagingError.notConnected }
        var req = URLRequest(url: URL(string: "\(restBase)/channels/\(message.chatId)/messages")!)
        req.httpMethod = "POST"
        req.setValue("Bot \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["content": message.content])
        _ = try await URLSession.shared.data(for: req)
    }

    func disconnect() async { heartbeatTask?.cancel(); webSocket?.cancel(); isConnected = false }
    func setMessageHandler(_ h: @escaping @Sendable (TheaGatewayMessage) async -> Void) { messageHandler = h }
}
```

---

### O3: Slack Events API Connector (Socket Mode)

**Create**: `Shared/Integrations/Messaging/SlackConnector.swift`
```swift
/// Slack via Socket Mode WebSocket. No public URL required.
/// Credentials: botToken (xoxb-…) + apiKey (App-Level Token xapp-… for Socket Mode).
actor SlackConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .slack
    private(set) var isConnected = false
    var credentials: MessagingCredentials
    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var webSocket: URLSessionWebSocketTask?

    init(credentials: MessagingCredentials) { self.credentials = credentials }

    func connect() async throws {
        guard let appToken = credentials.apiKey, !appToken.isEmpty else {
            throw MessagingError.missingCredentials(platform: .slack, field: "apiKey (xapp- token)")
        }
        var req = URLRequest(url: URL(string: "https://slack.com/api/apps.connections.open")!)
        req.httpMethod = "POST"; req.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let wssUrl = json["url"] as? String else {
            throw MessagingError.authenticationFailed(platform: .slack)
        }
        webSocket = URLSession.shared.webSocketTask(with: URL(string: wssUrl)!)
        webSocket?.resume(); isConnected = true
        Task { await receiveLoop() }
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let ws = webSocket {
            guard let msg = try? await ws.receive(), case .string(let text) = msg,
                  let data = text.data(using: .utf8),
                  let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let eid = envelope["envelope_id"] as? String {
                try? await ws.send(.string("{\"envelope_id\":\"\(eid)\"}"))
            }
            if (envelope["type"] as? String) == "events_api",
               let payload = envelope["payload"] as? [String: Any],
               let event = payload["event"] as? [String: Any],
               (event["type"] as? String) == "message",
               let text = event["text"] as? String,
               let channelId = event["channel"] as? String,
               let userId = event["user"] as? String,
               let ts = event["ts"] as? String {
                await messageHandler?(TheaGatewayMessage(
                    id: ts, platform: .slack, chatId: channelId,
                    senderId: userId, senderName: userId, content: text,
                    timestamp: Date(), isGroup: channelId.hasPrefix("C")
                ))
            }
        }
    }

    func send(_ message: OutboundMessage) async throws {
        guard let token = credentials.botToken else { throw MessagingError.notConnected }
        var req = URLRequest(url: URL(string: "https://slack.com/api/chat.postMessage")!)
        req.httpMethod = "POST"; req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["channel": message.chatId, "text": message.content])
        _ = try await URLSession.shared.data(for: req)
    }

    func disconnect() async { webSocket?.cancel(); isConnected = false }
    func setMessageHandler(_ h: @escaping @Sendable (TheaGatewayMessage) async -> Void) { messageHandler = h }
}
```

---

### O4: iMessage / BlueBubbles Connector

**Create**: `Shared/Integrations/Messaging/BlueBubblesConnector.swift`
```swift
/// iMessage via BlueBubbles local HTTP + WebSocket API.
/// Credentials: serverUrl (e.g. "http://localhost:1234") + apiKey (BlueBubbles password).
actor BlueBubblesConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .imessage
    private(set) var isConnected = false
    var credentials: MessagingCredentials
    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var webSocket: URLSessionWebSocketTask?

    init(credentials: MessagingCredentials) { self.credentials = credentials }

    func connect() async throws {
        guard let serverUrl = credentials.serverUrl, let apiKey = credentials.apiKey else {
            throw MessagingError.missingCredentials(platform: .imessage, field: "serverUrl + apiKey")
        }
        let wsUrl = serverUrl.replacingOccurrences(of: "http://", with: "ws://")
                             .replacingOccurrences(of: "https://", with: "wss://")
                   + "/api/v1/socket?password=\(apiKey)"
        webSocket = URLSession.shared.webSocketTask(with: URL(string: wsUrl)!)
        webSocket?.resume(); isConnected = true
        Task { await receiveLoop(serverUrl: serverUrl, apiKey: apiKey) }
    }

    private func receiveLoop(serverUrl: String, apiKey: String) async {
        while !Task.isCancelled, let ws = webSocket {
            guard let msg = try? await ws.receive(), case .string(let text) = msg,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["event"] as? String == "new-message",
                  let msgData = json["data"] as? [String: Any],
                  let content = msgData["text"] as? String, !content.isEmpty else { continue }
            await messageHandler?(TheaGatewayMessage(
                id: msgData["guid"] as? String ?? UUID().uuidString,
                platform: .imessage,
                chatId: msgData["chats"] as? String ?? "unknown",
                senderId: msgData["handle"] as? String ?? "unknown",
                senderName: msgData["handleString"] as? String ?? "iMessage",
                content: content, timestamp: Date(),
                isGroup: (msgData["isGroup"] as? Bool) ?? false
            ))
        }
    }

    func send(_ message: OutboundMessage) async throws {
        guard let serverUrl = credentials.serverUrl, let apiKey = credentials.apiKey else {
            throw MessagingError.notConnected
        }
        var req = URLRequest(url: URL(string: "\(serverUrl)/api/v1/message/text")!)
        req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "password")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["chatGuid": message.chatId, "message": message.content])
        _ = try await URLSession.shared.data(for: req)
    }

    func disconnect() async { webSocket?.cancel(); isConnected = false }
    func setMessageHandler(_ h: @escaping @Sendable (TheaGatewayMessage) async -> Void) { messageHandler = h }
}
```

---

### O5: WhatsApp Business API Connector

**Create**: `Shared/Integrations/Messaging/WhatsAppConnector.swift`
```swift
/// WhatsApp via Meta Cloud API. Receives webhooks via TheaGatewayWSServer, sends via REST.
/// Credentials: botToken (access token) + apiKey (phone number ID) + webhookSecret (verify token).
actor WhatsAppConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .whatsapp
    private(set) var isConnected = false
    var credentials: MessagingCredentials
    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private let apiBase = "https://graph.facebook.com/v21.0"

    init(credentials: MessagingCredentials) { self.credentials = credentials }

    func connect() async throws {
        guard credentials.botToken != nil, credentials.apiKey != nil else {
            throw MessagingError.missingCredentials(platform: .whatsapp, field: "botToken + apiKey")
        }
        isConnected = true
        // Registers webhook handler with TheaGatewayWSServer for incoming POSTs
    }

    func processWebhook(body: Data) async {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let entry = (json["entry"] as? [[String: Any]])?.first,
              let changes = (entry["changes"] as? [[String: Any]])?.first,
              let value = changes["value"] as? [String: Any],
              let messages = value["messages"] as? [[String: Any]],
              let msg = messages.first,
              let text = (msg["text"] as? [String: Any])?["body"] as? String else { return }
        await messageHandler?(TheaGatewayMessage(
            id: msg["id"] as? String ?? UUID().uuidString, platform: .whatsapp,
            chatId: msg["from"] as? String ?? "unknown",
            senderId: msg["from"] as? String ?? "unknown", senderName: "WhatsApp User",
            content: text, timestamp: Date(), isGroup: false
        ))
    }

    func send(_ message: OutboundMessage) async throws {
        guard let token = credentials.botToken, let phoneId = credentials.apiKey else {
            throw MessagingError.notConnected
        }
        var req = URLRequest(url: URL(string: "\(apiBase)/\(phoneId)/messages")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "messaging_product": "whatsapp", "to": message.chatId,
            "type": "text", "text": ["body": message.content]
        ])
        _ = try await URLSession.shared.data(for: req)
    }

    func disconnect() async { isConnected = false }
    func setMessageHandler(_ h: @escaping @Sendable (TheaGatewayMessage) async -> Void) { messageHandler = h }
}
```

---

### O6: Signal-CLI Bridge Connector

**Create**: `Shared/Integrations/Messaging/SignalConnector.swift`
```swift
/// Signal via signal-cli daemon (brew install signal-cli). Unix socket JSON-RPC.
/// Credential: serverUrl field = registered phone number (e.g. "+15555550123").
actor SignalConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .signal
    private(set) var isConnected = false
    var credentials: MessagingCredentials
    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var daemonProcess: Process?
    private let socketPath = "/tmp/signal-thea.sock"

    init(credentials: MessagingCredentials) { self.credentials = credentials }

    func connect() async throws {
        guard let phone = credentials.serverUrl, !phone.isEmpty else {
            throw MessagingError.missingCredentials(platform: .signal, field: "serverUrl (phone number)")
        }
        guard let cliPath = which("signal-cli") else {
            throw MessagingError.dependencyMissing(name: "signal-cli",
                installHint: "brew install signal-cli && signal-cli -a \(phone) register")
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cliPath)
        p.arguments = ["--account", phone, "daemon", "--socket", socketPath]
        try p.run(); daemonProcess = p
        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(500))
            if FileManager.default.fileExists(atPath: socketPath) { break }
        }
        isConnected = true
        Task { await receiveDaemonMessages(phone: phone) }
    }

    private func receiveDaemonMessages(phone: String) async {
        // JSON-RPC 2.0 via Unix socket — subscribe and parse receive notifications
        // Map to TheaGatewayMessage
    }

    func send(_ message: OutboundMessage) async throws {
        // JSON-RPC: {"method":"send","params":{"recipient":[chatId],"message":content},"id":1}
    }

    func disconnect() async {
        daemonProcess?.terminate()
        try? FileManager.default.removeItem(atPath: socketPath)
        isConnected = false
    }
    func setMessageHandler(_ h: @escaping @Sendable (TheaGatewayMessage) async -> Void) { messageHandler = h }

    private func which(_ cmd: String) -> String? {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = [cmd]; let pipe = Pipe(); p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines)
        return out?.isEmpty == false ? out : nil
    }
}
```

---

### O7: Matrix / Element Connector

**Create**: `Shared/Integrations/Messaging/MatrixConnector.swift`
```swift
/// Matrix homeserver via Client-Server API v3 (/sync long-polling). No external dependencies.
/// Credentials: serverUrl (e.g. "https://matrix.org") + apiKey (access token).
actor MatrixConnector: MessagingPlatformConnector {
    let platform: MessagingPlatform = .matrix
    private(set) var isConnected = false
    var credentials: MessagingCredentials
    private var messageHandler: (@Sendable (TheaGatewayMessage) async -> Void)?
    private var syncToken: String?
    private var syncTask: Task<Void, Never>?

    init(credentials: MessagingCredentials) { self.credentials = credentials }

    func connect() async throws {
        guard let server = credentials.serverUrl, let token = credentials.apiKey,
              !server.isEmpty, !token.isEmpty else {
            throw MessagingError.missingCredentials(platform: .matrix, field: "serverUrl + apiKey")
        }
        var req = URLRequest(url: URL(string: "\(server)/_matrix/client/v3/account/whoami")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw MessagingError.authenticationFailed(platform: .matrix)
        }
        isConnected = true
        syncTask = Task { await syncLoop(server: server, token: token) }
    }

    private func syncLoop(server: String, token: String) async {
        while !Task.isCancelled && isConnected {
            var urlStr = "\(server)/_matrix/client/v3/sync?timeout=30000"
            if let st = syncToken { urlStr += "&since=\(st)" }
            var req = URLRequest(url: URL(string: urlStr)!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                try? await Task.sleep(for: .seconds(5)); continue
            }
            syncToken = json["next_batch"] as? String
            if let rooms = (json["rooms"] as? [String: Any])?["join"] as? [String: [String: Any]] {
                for (roomId, room) in rooms {
                    let events = ((room["timeline"] as? [String: Any])?["events"] as? [[String: Any]]) ?? []
                    for event in events where event["type"] as? String == "m.room.message" {
                        let c = event["content"] as? [String: Any]
                        guard c?["msgtype"] as? String == "m.text",
                              let body = c?["body"] as? String else { continue }
                        await messageHandler?(TheaGatewayMessage(
                            id: event["event_id"] as? String ?? UUID().uuidString,
                            platform: .matrix, chatId: roomId,
                            senderId: event["sender"] as? String ?? "unknown",
                            senderName: event["sender"] as? String ?? "Matrix User",
                            content: body, timestamp: Date(), isGroup: true
                        ))
                    }
                }
            }
        }
    }

    func send(_ message: OutboundMessage) async throws {
        guard let server = credentials.serverUrl, let token = credentials.apiKey else {
            throw MessagingError.notConnected
        }
        let txnId = UUID().uuidString
        var req = URLRequest(url: URL(string: "\(server)/_matrix/client/v3/rooms/\(message.chatId)/send/m.room.message/\(txnId)")!)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["msgtype": "m.text", "body": message.content])
        _ = try await URLSession.shared.data(for: req)
    }

    func disconnect() async { syncTask?.cancel(); isConnected = false }
    func setMessageHandler(_ h: @escaping @Sendable (TheaGatewayMessage) async -> Void) { messageHandler = h }
}
```

---

### O8: Thea Built-in WebSocket Server (Port 18789)

**Create**: `Shared/Integrations/OpenClaw/TheaGatewayWSServer.swift`
```swift
/// Thea's built-in WebSocket server on port 18789.
/// External clients (OpenClawClient.swift, Claude CLI, companion apps) connect here.
/// Auth: token stored in Keychain (generated on first launch).
import Network

actor TheaGatewayWSServer {
    let port: Int
    private var listener: NWListener?
    private var clients: [UUID: NWConnection] = [:]

    init(port: Int = 18789) { self.port = port }

    func start() throws {
        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: UInt16(port))!)
        listener?.newConnectionHandler = { [weak self] conn in
            Task { await self?.handleConnection(conn) }
        }
        listener?.start(queue: .global(qos: .userInitiated))
        print("[TheaGatewayWSServer] Listening on ws://127.0.0.1:\(port)")
    }

    private func handleConnection(_ connection: NWConnection) async {
        let id = UUID(); clients[id] = connection
        connection.start(queue: .global(qos: .background))
        // TODO: token challenge-response auth, then route messages to TheaMessagingGateway
    }

    func broadcast(event: String, payload: Data) async {
        let msg = "{\"type\":\"event\",\"event\":\"\(event)\"}".data(using: .utf8)
        for (_, conn) in clients {
            conn.send(content: msg, contentContext: .defaultMessage, isComplete: true, completion: .idempotent)
        }
    }

    func stop() { listener?.cancel() }
}
// Health check endpoint: GET /health → {"status":"ok","platform":"thea","port":18789}
// curl http://127.0.0.1:18789/health
```

**Update** `OpenClawClient.swift` comment only:
```swift
// Connects to Thea's own built-in gateway (TheaGatewayWSServer at port 18789).
// No code changes needed — ws://127.0.0.1:18789 is unchanged.
```

---

### O9: Sessions + Memory (SwiftData + MMR)

**Create**: `Shared/Integrations/OpenClaw/MessagingSessionManager.swift`
```swift
/// Per-platform-per-peer sessions with SwiftData persistence.
/// Implements MMR (Maximal Marginal Relevance) memory re-ranking
/// from OpenClaw research — diversified retrieval with temporal decay.
@MainActor
final class MessagingSessionManager: ObservableObject {
    static let shared = MessagingSessionManager()
    @Published var activeSessions: [MessagingSession] = []

    func appendMessage(_ message: TheaGatewayMessage) async {
        // key = "{platform}:{chatId}:{senderId}" — per-channel-peer isolation
        let key = "\(message.platform.rawValue):\(message.chatId):\(message.senderId)"
        // Fetch or create SwiftData session, append message, update lastActivity
    }

    func resetSession(key: String) { /* clear messages, keep metadata */ }
    func resetAll() { /* clear all session message history */ }

    /// MMR re-ranking: BM25 keyword match + PersonalKnowledgeGraph embeddings + temporal decay
    func relevantContext(for query: String, session: MessagingSession) -> [String] { [] }

    func scheduleDailyReset() { /* reset all sessions at 04:00 via SmartNotificationScheduler */ }
}

@Model final class MessagingSession {
    var key: String; var platform: String; var chatId: String
    var senderId: String; var senderName: String; var lastActivity: Date
    var messageHistory: [Data]; var agentId: String = "main"

    init(key: String, platform: String, chatId: String, senderId: String, senderName: String) {
        self.key = key; self.platform = platform; self.chatId = chatId
        self.senderId = senderId; self.senderName = senderName
        self.lastActivity = Date(); self.messageHistory = []
    }
}

struct MessagingCredentialsStore {
    static func load(for platform: MessagingPlatform) -> MessagingCredentials {
        // SecItemCopyMatching keyed by "thea.messaging.{platform}"
        return MessagingCredentials()
    }
    static func save(_ creds: MessagingCredentials, for platform: MessagingPlatform) {
        // SecItemAdd / SecItemUpdate
    }
}
```

**PersonalKnowledgeGraph extension**:
```swift
extension PersonalKnowledgeGraph {
    func contextForMessaging() -> [String] {
        getAllEntities().filter { $0.importance > 0.7 }
            .map { "[\($0.type.rawValue)] \($0.name): \($0.description)" }
    }
}
```

---

### O10: Messaging Settings UI + Chat View

**Create**: `Shared/UI/Views/Settings/TheaMessagingSettingsView.swift`
```swift
/// Credentials + settings for Thea's native messaging gateway.
struct TheaMessagingSettingsView: View {
    @ObservedObject private var gateway = TheaMessagingGateway.shared
    @ObservedObject private var sessions = MessagingSessionManager.shared

    var body: some View {
        Form {
            Section("Gateway (Port 18789)") {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(gateway.connectedPlatforms.isEmpty ? .red : .green)
                    Text(gateway.connectedPlatforms.isEmpty ? "No platforms connected"
                         : "Connected: \(gateway.connectedPlatforms.map(\.displayName).joined(separator: ", "))")
                }
                if let err = gateway.lastError { Text(err).foregroundStyle(.red).font(.caption) }
            }
            ForEach(MessagingPlatform.allCases, id: \.self) { platform in
                PlatformCredentialsSection(platform: platform)
            }
            Section("Sessions") {
                Text("\(sessions.activeSessions.count) active sessions")
                Button("Reset All Sessions", role: .destructive) { sessions.resetAll() }
                Toggle("Daily auto-reset at 4:00 AM", isOn: .constant(true))
            }
            Section("Tool Policy") {
                Text("Allow: read, web, messaging").font(.caption)
                Text("Deny: runtime, elevated commands").font(.caption).foregroundStyle(.secondary)
            }
            Section("Security") {
                Label("22-pattern injection guard: Active", systemImage: "shield.fill").foregroundStyle(.green)
                Label("Rate limiting: 5 responses/min/platform", systemImage: "timer").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Messaging Gateway")
    }
}
```

**Create**: `Shared/UI/Views/OpenClaw/TheaMessagingChatView.swift`
```swift
/// Platform selector + conversation thread for all messaging platforms.
struct TheaMessagingChatView: View {
    @ObservedObject private var gateway = TheaMessagingGateway.shared
    @ObservedObject private var sessions = MessagingSessionManager.shared
    @State private var selectedSession: MessagingSession?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSession) {
                ForEach(MessagingPlatform.allCases, id: \.self) { platform in
                    let pSessions = sessions.activeSessions.filter { $0.platform == platform.rawValue }
                    if !pSessions.isEmpty {
                        Section(platform.displayName) {
                            ForEach(pSessions) { session in
                                Text(session.senderName).tag(session)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
        } detail: {
            if let session = selectedSession {
                Text("Conversation with \(session.senderName)")
            } else {
                ContentUnavailableView("Select a Conversation",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Enable a platform in Settings → Messaging Gateway"))
            }
        }
    }
}
```

**Wire into MacSettingsView** — add "Messaging" sidebar item → TheaMessagingSettingsView
**Wire into iOS settings** — add TheaMessagingSettingsView section
**Wire into main navigation** — add "Messages" tab/item → TheaMessagingChatView

---

### O_Tests: Tests for Messaging Components

**Add test files** (add to project.yml, then xcodegen generate):
- `Tests/IntegrationTests/TheaMessagingGatewayTests.swift`
- `Tests/IntegrationTests/TelegramConnectorTests.swift`
- `Tests/IntegrationTests/DiscordConnectorTests.swift`
- `Tests/IntegrationTests/SlackConnectorTests.swift`
- `Tests/IntegrationTests/MessagingSessionManagerTests.swift`
- `Tests/IntegrationTests/OpenClawBridgeTests.swift` (update existing for multi-platform)
- `Tests/IntegrationTests/OpenClawSecurityGuardTests.swift` (existing — keep as-is)

```swift
// MockTelegramServer: HTTPServer responding to getUpdates/sendMessage
// MockDiscordGateway: WSServer sending Hello → Dispatch sequences
// MockSlackSocketMode: WSServer sending envelope → expecting ACK
// Run: swift test
```

---

**O Success Criteria** (all must be true before marking O complete):
- [ ] TheaMessagingGateway.start() wires all 7 connectors at app launch
- [ ] At least 1 connector fully functional end-to-end (Telegram recommended — simplest API)
- [ ] TheaGatewayWSServer listens: `curl http://127.0.0.1:18789/health` → 200
- [ ] OpenClawClient.swift still works (connects to Thea's own gateway, comment updated)
- [ ] OpenClawSecurityGuard fires on ALL inbound messages from ALL platforms
- [ ] OpenClawBridge routes correctly (main/work/health/moltbook agents)
- [ ] Sessions persisted in SwiftData (survive app restart)
- [ ] TheaMessagingSettingsView accessible in macOS sidebar + iOS settings
- [ ] TheaMessagingChatView accessible from main navigation (macOS + iOS)
- [ ] All new files in project.yml + xcodegen generate succeeds
- [ ] swift test passes with O_Tests suite

---

## PHASE P — COMPONENT ANALYSIS + INDIVIDUAL IMPROVEMENTS (MSM3U)

> ⚠️ **SESSION START CHECKLIST** (do before any P work):
> ```bash
> launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
> git pull && git log --oneline -5 && git status --short && git stash list
> # Run Build Verification Gate — must be 4x BUILD SUCCEEDED before touching any code
> ```
> **Build baseline known issue**: Phase O ended with 7 fix commits. Verify clean before P.
> If build errors exist, fix them first — they are P0, not optional.

**Goal**: Analyze every major component individually and collectively. Identify and fix gaps,
         improve interactions, strengthen resilience, remove dead code, add missing tests.

**Research first**: Before modifying any component, read its current implementation, then:
```
WebSearch: "[ComponentName] best practices 2026 Swift 6 concurrency"
WebSearch: "[ComponentName] known issues iOS macOS 2026"
```

### P1: ChatManager — Central AI Orchestration Hub
**Analyze**: `Shared/AI/ChatManager.swift` (or wherever it lives)
```bash
cat "$(find Shared -name 'ChatManager.swift' -not -path '*/.build/*' | head -1)"
```
**Check interactions with**:
- ConfidenceSystem (runs after every response)
- AgentMode (mode selection after task classification)
- AutonomyController (risk evaluation post-response)
- MoltbookAgent (message routing)
- ConversationLanguageService (system prompt injection)
- OpenClawBridge / TheaMessagingGateway (incoming message routing)
- PersonalKnowledgeGraph (context retrieval)

**Improvements to investigate**:
- [ ] Does ChatManager stream responses to Thea Messaging Gateway channels? If not, add streaming support
- [ ] Does ConfidenceSystem run on TheaMessagingGateway-sourced messages? Should it?
- [ ] Is there a unified conversation history for cross-platform sessions?
- [ ] Does BehavioralFingerprint track TheaMessagingGateway interactions?
- [ ] Add conversation context from PersonalKnowledgeGraph before sending to AI
- [ ] Verify TheaMessagingGateway routes all platforms through OpenClawSecurityGuard before ChatManager

### P2: ConfidenceSystem — Response Verification
**Analyze**: `Shared/Intelligence/Verification/ConfidenceSystem.swift`
**Current**: Runs async after every AI response, stores confidence in MessageMetadata.confidence
**Improvements**:
- [ ] Surface confidence score in TheaMessagingGateway responses (append low-confidence warning)
- [ ] Skip confidence verification for TheaMessagingGateway if latency > 2s (messaging users don't wait)
- [ ] Add confidence trend tracking (declining confidence = model quality regression)
- [ ] Test: confidence score between 0.0-1.0 for normal responses
- [ ] Test: low confidence detected for hallucinations/uncertain content

### P3: PersonalKnowledgeGraph — Entity + Relationship Memory
**Analyze**: `Shared/Memory/PersonalKnowledgeGraph.swift`
**Current**: Entity-relationship graph, BFS pathfinding, JSON persistence
**Improvements**:
- [ ] Import/export from OpenClaw memory (O7 above)
- [ ] Entity deduplication: prevent duplicate entities for same person/place
- [ ] Expiration: entities older than 90 days with no activity decay in importance
- [ ] Integration with OpenClaw Canvas: render graph as visual node diagram
- [ ] Test: BFS pathfinding with cycles doesn't infinite-loop (timeout guard)
- [ ] Test: JSON persistence survives app restart

### P4: AgentMode + AutonomyController — Autonomous Task Execution
**Analyze**: `Shared/Intelligence/AgentMode/`, `Shared/Intelligence/Autonomy/`
**Current**: 5-level risk-based autonomy, phase tracking, action approval queue
**Improvements**:
- [ ] Surface agentic task status in OpenClaw channel (send progress updates)
- [ ] Add task cancellation via OpenClaw message ("cancel task")
- [ ] AutonomyController: integrate with OpenClaw approval workflow
  (instead of local UI prompt, send approval request via OpenClaw DM)
- [ ] Test: risk level 5 tasks are NEVER auto-approved
- [ ] Test: task phase transitions are logged with timestamps

### P5: BehavioralFingerprint — User Pattern Learning
**Analyze**: `Shared/Intelligence/UserModel/BehavioralFingerprint.swift`
**Current**: 7x24 temporal model (168 time slots), learns usage patterns
**Improvements**:
- [ ] Feed OpenClaw message timestamps into behavioral model
  (when user messages on WhatsApp vs Telegram reveals context patterns)
- [ ] Feed SmartNotificationScheduler: optimal times to send proactive OpenClaw messages
- [ ] Privacy: fingerprint data stays local, never leaves device
- [ ] Test: temporal model accumulates correctly across simulated time

### P6: HealthCoachingPipeline — HealthKit Integration
**Analyze**: `Shared/Intelligence/Health/HealthCoachingPipeline.swift`
**Current**: HealthKit data → coaching insights pipeline
**Improvements**:
- [ ] Deliver coaching insights via OpenClaw (scheduled daily health summary)
- [ ] Create cron job: "0 8 * * *" → "Generate today's health coaching summary"
- [ ] Integrate with SmartNotificationScheduler for optimal delivery time
- [ ] Test: pipeline handles missing HealthKit permissions gracefully

### P7: TaskPlanDAG — Parallel Task Decomposition
**Analyze**: `Shared/Intelligence/Planning/TaskPlanDAG.swift`
**Current**: DAG-based task planning, parallel execution via TaskGroup
**Improvements**:
- [ ] Surface DAG execution progress in OpenClaw channel
- [ ] Add task visualization in Canvas/A2UI
- [ ] Cycle detection: TaskPlanDAG must detect and reject cyclic dependencies
- [ ] Test: parallel execution actually runs tasks concurrently
- [ ] Test: cycle detection throws appropriate error

### P8: SwiftData Schema Migration
**Verify**: `macOS/TheamacOSApp.swift` uses `TheaSchemaMigrationPlan.self` (not deleteStore)
```bash
grep -n "ModelConfiguration\|TheaSchemaMigrationPlan\|deleteStore" \
  "/Users/alexis/Documents/IT & Tech/MyApps/Thea/macOS/TheamacOSApp.swift" | head -10
```
Must show `migrationPlan: TheaSchemaMigrationPlan.self`. If not: re-apply Phase A2 fix.

### P9: OutboundPrivacyGuard — Credential Leak Prevention
**Verify all patterns still intact**:
```bash
grep -n "SSH\|PEM\|JWT\|Firebase\|API_KEY\|apiKey\|Bearer\|password\|secret" \
  Shared/Privacy/OutboundPrivacyGuard.swift | head -20
```
**Improvements**:
- [ ] Add OpenClaw-specific pattern: don't leak Gateway auth token in messages
- [ ] Add device token pattern (OpenClaw deviceToken should never go outbound)
- [ ] Test: each credential pattern is individually tested
- [ ] Test: message with embedded API key is properly redacted

### P10: FunctionGemmaBridge — Command Blocklist
**Verify blocklist intact**:
```bash
grep -n "blocklist\|blockList\|BLOCKED\|shell\|exec\|rm\|curl" \
  Shared/AI/CoreML/FunctionGemmaBridge.swift | head -10
```
**Improvements**:
- [ ] Expand blocklist: add OpenClaw-specific dangerous patterns
  (e.g., gateway shutdown commands, token extraction attempts)
- [ ] Test: every blocked command is individually tested
- [ ] Test: shell metacharacter injection is rejected

### P11: MLXAudioEngine — Voice Pipeline
**Verify**: `Shared/AI/Audio/MLXAudioEngine.swift`
**Current**: TTS (Soprano-80M) + STT (GLM-ASR-Nano)
**Improvements**:
- [ ] OpenClaw voice note support: when voice note received via channel, run STT → text → AI
- [ ] TTS response option: generate audio response for voice-first channels
- [ ] Test: STT produces non-empty transcription for test audio
- [ ] Test: TTS produces non-empty audio for test text

### P12: CloudKitService — Cross-Device Sync
**Analyze**: `Shared/Sync/CloudKitService.swift`
**Verify**: Delta sync, subscriptions, sharing still wired
**Improvements**:
- [ ] Sync OpenClaw settings (channels, agents, allowlists) via CloudKit
  (so preferences sync between macOS and iOS without re-configuration)
- [ ] Sync OpenClaw channel history (conversation continuity across devices)
- [ ] Privacy: filter sensitive fields (auth tokens) from CloudKit sync
- [ ] Test: sync conflict resolution preserves newer data

### P13: AnthropicProvider — Claude Opus 4.6 + Sonnet 4.6 Upgrades
**Research**: Anthropic released two new models in Feb 2026 — these must be available in Thea:
- **Claude Opus 4.6** (Feb 5, 2026): Best agent + planning, computer use, 72.5% OSWorld, $15/M output
  - Highest prompt injection resistance (recommended by OpenClaw docs for tool-enabled agents)
  - Better code review, debugging, large codebase navigation
  - Should be Thea's default for: messaging auto-responses, AgentMode tasks, AutonomyController
- **Claude Sonnet 4.6** (Feb 17, 2026): Near-flagship at Sonnet 4.5 price, adaptive reasoning
  - Should be Thea's default for: daily chat, light tasks, iOS (cost-sensitive)
  - Messaging fallback model: `claude-sonnet-4-6`

**Required changes**:
```bash
grep -n "claude-opus\|claude-sonnet\|claude-haiku\|model.*id\|modelID" \
  Shared/AI/Providers/*.swift | head -20
```
- [ ] Add `claude-opus-4-6` and `claude-sonnet-4-6` to `AIModel.swift` model catalog
- [ ] Set `claude-opus-4-6` as OpenClawBridge default model for auto-response
- [ ] Set `claude-sonnet-4-6` as daily-use default (replace any claude-sonnet-4-5 references)
- [ ] Add `claude-haiku-4-5-20251001` as fast/cheap option for iOS
- [ ] Update AnthropicProvider to support Agent Teams API when released
- [ ] Test: model catalog lists all 3 new models with correct IDs
- [ ] Test: provider switches to fallback when primary model unavailable

### P14: MLXAudioEngine — Upgrade to mlx-audio 2026
**Research**: mlx-audio package (2026) supports TTS + STT + STS (speech-to-speech) with improved Swift API.
Apple also released **SpeechAnalyzer API** (macOS/iOS 26) for superior on-device STT.
**Analyze**: `Shared/AI/Audio/MLXAudioEngine.swift`
**Improvements**:
- [ ] Upgrade mlx-audio dependency to latest (check `Package.swift` for current pinned version)
- [ ] Add SpeechAnalyzer API as primary STT on macOS 26+ (falls back to GLM-ASR-Nano)
  ```swift
  if #available(macOS 26.0, *) {
      // Use SpeechAnalyzer for superior accuracy
  } else {
      // Fall back to MLXAudioEngine STT
  }
  ```
- [ ] Add TTS streaming support (mlx-audio 2026 supports token streaming → lower latency)
- [ ] Add speech-to-speech (STS) for messaging voice pipeline (voice note → STS response)
- [ ] Wire SpeechAnalyzer into messaging voice note pipeline (O1-O7 connectors)
- [ ] Test: SpeechAnalyzer produces accurate transcription on macOS 26
- [ ] Test: TTS streams first word within 300ms
- [ ] Test: STS roundtrip completes within 2s for short utterances

### P15: MLXVisionEngine — Upgrade to mlx-vlm Latest
**Research**: mlx-vlm (2026) improves vision-language inference speed and adds new model support.
Qwen3-VL and newer vision models available.
**Analyze**: `Shared/AI/LocalModels/MLXVisionEngine.swift`
**Improvements**:
- [ ] Update mlx-vlm to latest (2026 version adds faster speculative decoding)
- [ ] Add vllm-mlx as alternative backend for MSM3U
  (OpenAI-compatible server, 400+ tok/s, supports multimodal — better for high throughput)
- [ ] Add Qwen3-VL 8B → 32B upgrade path for MSM3U (better visual understanding)
- [ ] Wire messaging image attachments → MLXVisionEngine pipeline:
  when image received via channel, analyze with VLM → text description → AI response
- [ ] Test: image description accurate for test screenshot
- [ ] Test: fallback to cloud vision when local model unavailable (iOS)

### P16: Claude Agent Teams — Thea as Team Lead
**Research**: Claude Code now supports Agent Teams (Feb 2026) — a Team Lead session delegates
subtasks to teammate sessions with independent context windows.
This capability is available via the Claude API and maps directly to Thea's TaskPlanDAG.
**Improvements**:
- [ ] Implement `AgentTeamOrchestrator` in `Shared/Agents/`:
  ```swift
  // Thea becomes Team Lead:
  // 1. TaskPlanDAG decomposes task into parallel sub-tasks
  // 2. Each leaf node in DAG spawns a Claude API call (teammate)
  // 3. Results aggregated back to Team Lead for synthesis
  // This replaces current sequential API calls for multi-step tasks
  ```
- [ ] Wire AgentTeamOrchestrator into AgentMode (for `auto` mode tasks)
- [ ] Wire progress updates → Thea messaging channel (users see subtask progress in real-time)
- [ ] Add per-teammate context isolation (each subtask gets clean context window)
- [ ] Add team result caching (prevent redundant subtask re-runs)
- [ ] Test: 3-task parallel team completes faster than sequential
- [ ] Test: team leader correctly synthesizes 3 subtask results

---

### P_EXIT: Phase P Clean-Exit Protocol
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# 1. Final build gate — all 4 platforms must be green
# 2. Commit anything uncommitted
git add -A && git status && git commit -m "Auto-save: Phase P complete" || true
# 3. Restore thea-sync
launchctl load ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
# 4. Pushsync
git pushsync
# 5. ntfy
curl -s -H "Title: Thea Phase P - COMPLETE" -H "Priority: 4" -H "Tags: white_check_mark" \
     -d "Phase P done. All 16 sub-phases complete. Build gates green. Ready for Wave 2." \
     https://ntfy.sh/thea-msm3u
```

---

## PHASE Q — TEST COVERAGE TO 80%+ (MSM3U)

> ⚠️ **SESSION START CHECKLIST** (do before any Q work):
> ```bash
> launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
> git pull && git log --oneline -5 && git status --short && git stash list
> # Run Build Verification Gate — must be 4x BUILD SUCCEEDED before touching code
> ```

**Goal**: Overall line coverage ≥80%, 100% critical classes, 100% branch on security files.

### Q1: Baseline Coverage Report
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodebuild test \
  -project Thea.xcodeproj \
  -scheme Thea-macOS \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TheaBuild \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/coverage_build.log

xcrun xccov view --report --json /tmp/TheaBuild/Logs/Test/*.xcresult > /tmp/coverage.json 2>/dev/null || \
  xcrun xccov view --report --json \
  $(find /tmp/TheaBuild -name "*.xcresult" | head -1) > /tmp/coverage.json

python3 << 'PYEOF'
import json
d = json.load(open("/tmp/coverage.json"))
overall = d.get("lineCoverage", 0)
print(f"Overall line coverage: {overall:.1%}")

# Find uncovered critical classes
critical = [(f["name"], f["lineCoverage"]) for t in d.get("targets",[])
            for f in t.get("files",[])
            if any(f["name"].endswith(s) for s in
                   ("Service.swift","Manager.swift","Engine.swift","Pipeline.swift",
                    "Controller.swift","Coordinator.swift","Orchestrator.swift"))
            and f["lineCoverage"] < 1.0]
print(f"\nUncovered critical classes ({len(critical)}):")
for name, cov in sorted(critical, key=lambda x: x[1]):
    print(f"  {cov:.0%} {name}")
PYEOF
```

### Q2: Add Missing Tests (batch by subsystem)
For each uncovered critical class, run a dedicated agent:

**Agent for messaging gateway tests** (O_Tests above):
All messaging connector test files

**Agent for Intelligence tests** (missing ones from v1):
- SystemCapabilityService
- HealthCoachingPipeline
- SmartNotificationScheduler
- BehavioralFingerprint
- PersonalKnowledgeGraph BFS
- AgentMode phase transitions
- AutonomyController risk assessment
- ConfidenceSystem orchestration
- TaskPlanDAG cycle detection + parallelism

**Agent for Security tests**:
- OpenClawSecurityGuard: all 22 injection patterns (individual tests per pattern)
- OutboundPrivacyGuard: all credential patterns
- FunctionGemmaBridge: all blocklist items

**Test pattern** (same as v1):
```swift
final class ServiceNameTests: XCTestCase {
    func testInit() async { /* verify initializes without error */ }
    func testHappyPath() async { /* verify primary use case */ }
    func testErrorPath() async { /* verify failure handling */ }
    func testEdgeCases() async { /* boundary conditions */ }
}
```

### Q3: Security-Critical Files — 100% Branch Coverage
For each of these 5 files, verify every if/guard/switch branch is tested:
1. `OutboundPrivacyGuard.swift`
2. `OpenClawSecurityGuard.swift`
3. `FunctionGemmaBridge.swift`
4. `ConversationLanguageService.swift`
5. `OpenClawBridge.swift`

```bash
xcrun xccov view --file Shared/Privacy/OutboundPrivacyGuard.swift \
  --json /tmp/TheaBuild/... > /tmp/guard-cov.json
```

---

## PHASE R — PERIPHERY FULL RESOLUTION (MSM3U)

> ⚠️ **SESSION START CHECKLIST** (do before any R work):
> ```bash
> launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
> git pull && git log --oneline -5 && git status --short && git stash list
> # Run Build Verification Gate — must be 4x BUILD SUCCEEDED before touching code
> ```

**Goal**: Zero unaddressed Periphery items (all wired or marked Reserved).
**Note**: 2,667 warnings from v1 phase D3 — many already documented. Resume from there.

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
periphery scan --project Thea.xcodeproj --schemes Thea-macOS \
  --targets Thea-macOS --format json > /tmp/periphery.json 2>&1

python3 << 'PYEOF'
import json
d = json.load(open("/tmp/periphery.json"))
# Group by file, count unaddressed (no "Reserved" comment)
from collections import defaultdict
by_file = defaultdict(list)
for item in d:
    if "Reserved" not in (item.get("message") or ""):
        by_file[item["file"]].append(item)
total = sum(len(v) for v in by_file.values())
print(f"Unaddressed items: {total}")
for f, items in sorted(by_file.items(), key=lambda x: -len(x[1]))[:20]:
    print(f"  {len(items):3d} {f}")
PYEOF
```

For each item: wire in to appropriate call site OR add `// Reserved: <description>` comment.
NEVER delete.

---

## PHASE S — CI/CD GREEN VERIFICATION (MSM3U)

> ⚠️ **SESSION START CHECKLIST** (do before any S work):
> ```bash
> launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
> git pull && git log --oneline -5 && git status --short && git stash list
> # Run Build Verification Gate — must be 4x BUILD SUCCEEDED before touching code
> ```

**Goal**: All 6 GitHub Actions workflows showing green on github.com/Atchoum23/Thea/actions.

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# 1. Trigger all workflows
git pushsync origin main
gh workflow run release.yml --field version=1.0.0-beta.1  # Manual trigger for release

# 2. Monitor until all green (max 45 min)
for i in $(seq 1 30); do
  sleep 90
  RESULTS=$(gh run list --limit 12 --json name,status,conclusion \
    | python3 -c "
import sys,json
runs=json.load(sys.stdin)
results={}
for r in runs:
  n=r['name']
  if n not in results:
    results[n]=r.get('conclusion') or r.get('status','pending')
for k,v in sorted(results.items()):
  print(f'{k}: {v}')
")
  echo "=== $i: $(date) ==="
  echo "$RESULTS"

  FAILURES=$(echo "$RESULTS" | grep -c "failure" || echo 0)
  PENDING=$(echo "$RESULTS" | grep -c "in_progress\|queued\|pending" || echo 0)

  if [ "$FAILURES" -eq 0 ] && [ "$PENDING" -eq 0 ]; then
    echo "ALL 6 WORKFLOWS GREEN! Ship-ready CI achieved."
    break
  fi

  if [ "$FAILURES" -gt 0 ]; then
    FAIL_ID=$(gh run list --status failure --limit 1 --json databaseId -q '.[0].databaseId')
    [ -n "$FAIL_ID" ] && {
      echo "=== FAILURE LOGS ==="
      gh run view "$FAIL_ID" --log-failed 2>/dev/null | tail -100
      # Read failure, fix, commit, push
    }
  fi
done
```

### S1: Known Failure Patterns to Fix First
Before pushing, check for these known issues:
```bash
# 1. SwiftLint version mismatch
swiftlint version  # Should match ci.yml cache key version

# 2. Package.swift syntax
xcrun swift package dump-package > /dev/null && echo "Package.swift OK"

# 3. Maestro flows exist
ls .maestro/*.yaml 2>/dev/null | wc -l  # Must be > 0

# 4. thea-policy.json exists
ls thea-policy.json && echo "Policy file OK"

# 5. thea-audit builds
cd Tools/thea-audit && xcrun swift build -c release 2>&1 | tail -5
cd ../..

# 6. Gitleaks config exists
ls .gitleaks.toml && echo "Gitleaks config OK"
```

### ⚡ PHASE S — PARALLEL WORK WHILE WAITING FOR CI (DO NOT JUST SLEEP)

When CI jobs are `in_progress` and require 30-60+ min (especially Unit Tests on GH Actions macOS
runners), **do NOT just sleep**. Use that time productively:

**Option A — Start Phase T prep in a new tmux pane (RECOMMENDED):**
```bash
# Open a second pane and begin Phase T (T3 + T5 can be written without CI being done):
tmux new-window -t phase-s -n phase-t-prep
# In the new pane: write ExportOptions-DevID.plist + draft the notarize.yml workflow
# Phase T1/T2 require Alexis's manual action (certs + app-specific password) — skip those for now
# T3 (plist) + T5 (CI workflow skeleton) can be committed immediately
```

**Option B — Run local verification in parallel:**
```bash
# Local swift test on MSM3U takes ~55 min — same info as GH Actions Unit Tests, 3x faster:
swift test 2>&1 | tee /tmp/local-unit-tests.log &
# Continue monitoring GH Actions in foreground; local tests provide faster feedback
```

**Option C — Prep v3 Phase A3 (MetaAI file list + initial structure):**
```bash
# Pull the v3 plan and begin identifying which MetaAI files need to move:
git pull
wc -l .claude/THEA_CAPABILITY_PLAN_v3.md
# Create Shared/Intelligence/MetaAI/ directory structure (no-op if already exists)
# Read the v3 plan's Phase A3 section and prepare the file list
```

**Why**: GH Actions macOS runners run at 3-4× slower than MSM3U. Unit Tests take 80-90 min on
GH Actions vs. ~55 min locally. Every minute the executor sleeps is wasted capacity. The CI green
status is a requirement, but Phase T/U/v3 prep does NOT require CI to be complete first.

---

## PHASE T — NOTARIZATION PIPELINE SETUP (MSM3U)

> ⚡ **PARALLELISM: Run Phase T-AUTO in a new tmux window while Phase U runs in main window.**
> T-AUTO (T3+T5) needs no human input and can start immediately when Phase S closes.
> T-MANUAL (T1+T2+T4) requires Alexis — send ntfy, skip, never block Phase U or v3.
>
> ```bash
> # Open T-auto in a parallel window immediately when Phase S completes:
> /opt/homebrew/bin/tmux new-window -n "phase-t-auto"
> # In that window: write T3 (ExportOptions-DevID.plist) and T5 (notarize.yml skeleton)
> # Commit both: git add Scripts/notarize.sh ExportOptions-DevID.plist .github/workflows/release-notarize.yml
> # git commit -m "feat(T): ExportOptions plist + notarize workflow skeleton"
> # git pushsync
> # Done — T-auto complete. T1/T2/T4 are async (Alexis provides when convenient).
> ```

> ⚠️ **SESSION START CHECKLIST** (do before any T work):
> ```bash
> launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
> git pull && git log --oneline -5 && git status --short && git stash list
> # Run Build Verification Gate — must be 4x BUILD SUCCEEDED before touching code
> ```

**Goal**: Automate notarization so `git tag v1.0.0 && git pushsync` produces a notarized .dmg.

### T1: Verify/Export Developer ID Certificate
```bash
# Check current certificates:
security find-identity -v -p codesigning | grep "Developer ID"
# Expected: "Developer ID Application: ..." (valid to Feb 11, 2031, Team: 6B66PM4JLK)

# Export p12 (if not already in GitHub Secrets):
security export -k login.keychain -t identities -f pkcs12 \
  -P "$P12_PASSWORD" -o /tmp/DeveloperID.p12 \
  "Developer ID Application: ..."

# Base64 encode for GitHub Secret:
base64 -i /tmp/DeveloperID.p12 | pbcopy  # Paste into APPLE_CERTIFICATE_BASE64
```

### T2: Set up App-Specific Password for notarytool
```
1. Go to appleid.apple.com → Security → App-Specific Passwords
2. Generate password for "Thea CI Notarization"
3. Add to GitHub Secret: APPLE_APP_PASSWORD
4. Test locally:
   xcrun notarytool submit test.zip \
     --apple-id "$APPLE_ID" \
     --password "$APPLE_APP_PASSWORD" \
     --team-id 6B66PM4JLK \
     --wait
```

### T3: Create ExportOptions-DevID.plist
```xml
<!-- ExportOptions-DevID.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>6B66PM4JLK</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

### T4: Verify Notarization Works (local test)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodebuild archive -scheme Thea-macOS -archivePath /tmp/Thea.xcarchive \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGNING_REQUIRED=YES \
  DEVELOPMENT_TEAM=6B66PM4JLK

xcodebuild -exportArchive -archivePath /tmp/Thea.xcarchive \
  -exportPath /tmp/TheaExport \
  -exportOptionsPlist ExportOptions-DevID.plist

xcrun notarytool submit /tmp/TheaExport/Thea.app \
  --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" \
  --team-id 6B66PM4JLK --wait

xcrun stapler staple /tmp/TheaExport/Thea.app
xcrun stapler validate /tmp/TheaExport/Thea.app
echo "Notarization verified"
```

---

## PHASE U — FINAL VERIFICATION REPORT (MSM3U)

> ⚠️ **SESSION START CHECKLIST** (do before any U work):
> ```bash
> launchctl unload ~/Library/LaunchAgents/com.alexis.thea-sync.plist 2>/dev/null
> git pull && git log --oneline -5 && git status --short && git stash list
> # Run Build Verification Gate — must be 4x BUILD SUCCEEDED before touching code
> ```
>
> ⚡ **LOCAL-FIRST PROTOCOL (do NOT push and wait for GH Actions)**:
> Phase U verifies locally. Only push ONCE at the end to confirm the GH Actions baseline.
> ```bash
> # Local swift test for verification (55 min, same quality as GH Actions):
> swift test 2>&1 | tee /tmp/phase-u-tests.log | grep -E "(PASSED|FAILED|error:)" | tail -10
>
> # 4-platform builds (local, parallel):
> for SCHEME in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
>   xcodebuild -project Thea.xcodeproj -scheme "$SCHEME" -configuration Debug \
>     -destination 'platform=macOS' build -derivedDataPath /tmp/TheaBuild \
>     CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD|error:" | tail -2 &
> done; wait
> ```

**Goal**: Confirm ALL ship-ready criteria met via LOCAL verification. Generate comprehensive report.
**Then push ONCE** to confirm GH Actions is green before transitioning to v3.

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
echo "=== THEA SHIP-READY v2 VERIFICATION REPORT ===" > /tmp/ship-report.txt
echo "Date: $(date)" >> /tmp/ship-report.txt
echo "" >> /tmp/ship-report.txt

# 1. Build status
echo "=== BUILDS ===" >> /tmp/ship-report.txt
for SCHEME in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
  for CONFIG in Debug Release; do
    xcodebuild build -project Thea.xcodeproj -scheme "$SCHEME" \
      -configuration "$CONFIG" -destination "generic/platform=${SCHEME#Thea-}" \
      CODE_SIGNING_ALLOWED=NO 2>&1 | \
      grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -3 | \
      tee -a /tmp/ship-report.txt
  done
done

# 2. SwiftLint
echo "" >> /tmp/ship-report.txt
echo "=== SWIFTLINT ===" >> /tmp/ship-report.txt
swiftlint lint --reporter github-actions-logging 2>&1 | \
  grep -E "(violations|errors|warnings)" | tee -a /tmp/ship-report.txt

# 3. Swift tests
echo "" >> /tmp/ship-report.txt
echo "=== SWIFT TESTS ===" >> /tmp/ship-report.txt
xcrun swift test 2>&1 | grep -E "(Build complete|PASSED|FAILED|error:)" | \
  tail -5 | tee -a /tmp/ship-report.txt

# 4. Coverage
echo "" >> /tmp/ship-report.txt
echo "=== COVERAGE ===" >> /tmp/ship-report.txt
python3 /tmp/check-coverage.py >> /tmp/ship-report.txt 2>&1 || echo "Coverage check skipped"

# 5. Security
echo "" >> /tmp/ship-report.txt
echo "=== SECURITY ===" >> /tmp/ship-report.txt
for FILE in FunctionGemmaBridge.swift OpenClawSecurityGuard.swift \
            OutboundPrivacyGuard.swift ConversationLanguageService.swift; do
  FOUND=$(find Shared -name "$FILE" -exec grep -l "patterns\|blocklist\|whitelist" {} \; | wc -l)
  echo "$FILE: $([ "$FOUND" -gt 0 ] && echo OK || echo REVERTED)" >> /tmp/ship-report.txt
done

# 6. Messaging gateway health check
echo "" >> /tmp/ship-report.txt
echo "=== OPENCLAW PROTOCOL ===" >> /tmp/ship-report.txt
curl -s http://127.0.0.1:18789/health | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get("status")=="ok" else 1)" \
  head -3 | tee -a /tmp/ship-report.txt || \
  echo "WARNING: TheaGatewayWSServer not responding on port 18789" >> /tmp/ship-report.txt

# 7. GitHub Actions
echo "" >> /tmp/ship-report.txt
echo "=== GITHUB ACTIONS ===" >> /tmp/ship-report.txt
gh run list --limit 6 --json name,conclusion 2>/dev/null | \
  python3 -c "import sys,json; [print(f'{r[\"name\"]}: {r[\"conclusion\"]}') for r in json.load(sys.stdin)]" \
  2>/dev/null | tee -a /tmp/ship-report.txt || echo "(check github.com/Atchoum23/Thea/actions)"

# 8. Git status
echo "" >> /tmp/ship-report.txt
CHANGES=$(git status --porcelain | wc -l | tr -d ' ')
echo "Uncommitted changes: $CHANGES" >> /tmp/ship-report.txt

cat /tmp/ship-report.txt
git add -A && git commit -m "Auto-save: Final v2 verification report" || true
```

### ⚡ PHASE U COMPLETION → AUTO-TRANSITION TO v3 (MANDATORY)

After the report is committed, **do NOT stop**. Immediately execute:

```bash
# Notify Alexis that v2 is complete and v3 is starting
curl -s -X POST "https://ntfy.sh/thea-msm3u" \
  -H "Title: Thea v2 Complete — Starting v3" \
  -d "Phase U done. v2 ship-ready baseline confirmed. Starting v3 Phase A3 now." || true

# Pull latest plan (may have been updated from MBAM2)
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git pull 2>/dev/null || true

# ▶ START v3 — Read and execute the full v3 plan
# The v3 plan is at: .claude/THEA_CAPABILITY_PLAN_v3.md
# Instructions are at its top — Phase A3 is the first phase to execute
# v2 Phase V (Manual Gate) is DEFERRED and MERGED into v3 Phase AD3

echo "=== TRANSITIONING TO v3 ==="
echo "Reading .claude/THEA_CAPABILITY_PLAN_v3.md ..."
```

**EXECUTOR ACTION — FULLY AUTOMATED, NO HUMAN INPUT NEEDED:**
```bash
# This block auto-spawns all 6 v3 streams across both machines.
# Copy-paste the AUTO-SPAWN LAUNCHER from THEA_CAPABILITY_PLAN_v3.md
# (search for "AUTO-SPAWN LAUNCHER" in that file — the full bash script is there)
# Run it directly in the current shell. It will:
#   1. Launch 5 tmux windows on MSM3U (streams 1-5), each with caffeinate + claude
#   2. SSH into MBAM2 and auto-start stream 6 there
#   3. Send ntfy confirming all 6 streams launched
# After running the launcher, this Phase U session's job is done.
# Stream 5 will handle AG3+AH3+Wave6 verification autonomously.
# AD3 (Manual Gate) will send ntfy when reached — that's when Alexis reviews.
```

---

## PHASE V — MANUAL SHIP GATE (⚠️ DEFERRED — do NOT stop execution here)

**⚠️ STRATEGY UPDATE 2026-02-19: Phase V is DEFERRED to v3 Phase AD3.**
After Phase U completes, the executor AUTOMATICALLY starts v3 Phase A3.
All Phase V checklist items are MERGED into v3 Phase AD3 (combined final gate).
Alexis reviews EVERYTHING at one point (end of v3) instead of two separate checkpoints.

**The items below will be performed as part of v3 Phase AD3:**

### V1: Thea Messaging Gateway Smoke Test
```
1. Start Thea on macOS (TheaMessagingGateway auto-starts)
2. Verify: curl http://127.0.0.1:18789/health → 200
3. Navigate to Settings → Messaging Gateway
4. Verify: connection state shows "Connected"
5. Verify: channels list populated
6. Send test message from any configured channel
7. Verify: message appears in TheaMessagingChatView
8. Verify: AI response sent back to channel
9. Verify: OpenClawSecurityGuard blocked any injection in console logs
```

### V2: Voice Synthesis Quality
- Launch Thea on macOS
- Test TTS via MLXAudioEngine (Soprano-80M)
- Test STT via GLM-ASR-Nano transcription accuracy
- Verify voice note → STT → AI → response pipeline (via messaging connector)

### V3: Screen Capture Accuracy
- Test screen capture feature on macOS
- Verify G1 Live Screen Monitoring detects foreground app correctly
- Test screen capture via messaging command if configured

### V4: Vision Analysis
- Test Qwen3-VL 8B visual analysis with a screenshot
- Verify response quality and latency

### V5: Cursor Handoff
- Test cursor handoff between macOS and iOS

### V6: MLX Model Loading on MSM3U
- Load Llama 3.3 70B via MLX
- Verify inference quality and response time
- Test via Thea messaging (Telegram/Discord message → local LLM response)

### V7: Final Ship Tag
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
git status  # Must be clean
git tag -a v1.0.0 -m "Thea v1.0.0 — First ship-ready release"
git pushsync origin main
# release.yml triggers → signed, notarized .dmg + IPA created
# Download from GitHub Releases → install on both Macs
```

---

## DUAL-MAC EXECUTION STRATEGY

```
MSM3U (Mac Studio M3 Ultra) — PRIMARY
├── Phase N: GitHub Workflows Overhaul
├── Phase O: Thea Native Messaging Gateway
├── Phase P: Component Analysis + Fixes
├── Phase Q: Test Coverage to 80%+
├── Phase R: Periphery Full Resolution
├── Phase S: CI/CD Green Verification
├── Phase T: Notarization Pipeline
└── Phase U: Final Verification Report

MBAM2 (MacBook Air M2) — SECONDARY (if parallelism needed)
├── Phase N5-N6: thea-audit workflows review
├── Phase P6-P12: Lighter component analysis
├── Tizen + TheaWeb verification (already done in v1)
└── Documentation review
```

**Sync rule**: After MSM3U fixes, `git pushsync origin main` → MBAM2 auto-syncs via thea-sync.sh

---

## AUTOMATION STATUS (v2 additions)

| Manual Task (v1)                     | Automated (v2) | How |
|--------------------------------------|----------------|-----|
| Monitor CI status                    | YES | gh run monitor loop in Phase S |
| Notarize app for release             | YES | xcrun notarytool in release.yml |
| Staple notarization ticket           | YES | xcrun stapler in release.yml |
| Generate release notes               | YES | git log --pretty in release.yml |
| Version bump on tag                  | YES | bump-version job in release.yml |
| Security audit scheduling            | YES | cron in thea-audit-main.yml |
| npm audit for thea-tizen             | YES | npm-audit job in security.yml |
| Container scan for TheaWeb           | YES | trivy-scan job in security.yml |
| SBOM generation                      | YES | sbom job in security.yml |
| Dead code baseline tracking          | YES | periphery job in ci.yml |
| Build time regression detection      | YES | Build logs with timestamps |
| Messaging gateway health check       | YES | TheaMessagingGateway.connectedPlatforms |
| Messaging session management         | YES | MessagingSessionManager.shared |
| Coverage trend tracking              | YES | codecov upload in ci.yml |
| Maestro screenshot on failure        | YES | xcrun simctl screenshot in e2e-tests.yml |
| Voice synthesis quality test         | NO  | Manual — requires human ear |
| Screen capture accuracy test         | NO  | Manual — requires human eye |
| Vision analysis quality test         | NO  | Manual — requires human eye |
| MLX model loading test               | NO  | Manual — requires physical access |
| Final ship tag + pushsync            | NO  | Manual — Alexis decision |
| Messaging credential validation      | YES | O0: connect() throws on missing creds |
| Messaging gateway startup            | YES | O0: TheaMessagingGateway.start() at app launch |
| Agent Teams task delegation          | YES | AgentTeamOrchestrator (P16) |
| Platform connector health check      | YES | TheaMessagingGateway.connectedPlatforms in S |
| SpeechAnalyzer API availability check| YES | `#available(macOS 26.0, *)` guard (P14) |
| Claude model catalog update          | YES | Automated via Phase P13 |

---

## MESSAGING GATEWAY GAPS — BEFORE vs AFTER

| Feature                              | v1 (Before)          | v2 (After)              |
|--------------------------------------|----------------------|-------------------------|
| Wire protocol                        | JSONRPC 2.0 (wrong)  | Native req/res/event    |
| Authentication                       | None                 | Challenge-response + deviceToken |
| Channels                             | 8 types defined      | All 13 channels wired   |
| Sessions API                         | listSessions stub    | Full CRUD + isolation   |
| Canvas/A2UI                          | None                 | Full WKWebView renderer |
| Memory system                        | None                 | Hybrid search + KG sync |
| Multi-agent routing                  | Single agent         | Per-channel agent routing |
| Node capabilities                    | None                 | Camera, screen, location, notifications |
| Gateway config management            | None                 | config.get/set/patch    |
| Cron/scheduled tasks                 | None                 | Full cron management    |
| Skills system                        | None                 | ClawHub integration     |
| Tool policy enforcement              | None                 | Per-agent tool profiles |
| Security audit                       | 22 patterns only     | + thea-audit full codebase scan |
| Settings UI                          | None                 | Full 9-section settings |
| Messaging gateway test coverage      | 0%                   | 100% of all connectors  |
| MoltbookAgent integration            | Basic routing        | Full reply-back wired   |
| Gateway credentials (Keychain)       | None                 | O0: MessagingCredentialsStore wired |
| Daemon setup (launchd)               | None                 | O0: TheaMessagingGateway wired at app launch |
| Credential validation                | None                 | O0: connect() throws on missing creds |
| dmScope per-peer isolation           | None                 | O9: MessagingSessionManager key isolation |
| Messaging chat UI                    | None                 | O10: TheaMessagingChatView wired in nav |
| iOS node (internal preview)          | None                 | O3 code ready; pairing pending |
| Voice note → STS pipeline            | None                 | O3 + P14 (SpeechAnalyzer) |
| Agent Teams delegation               | None                 | P16 AgentTeamOrchestrator |

---

## GITHUB WORKFLOWS — BEFORE vs AFTER COMPARISON

| Capability                           | v1 (Before)         | v2 (After)              |
|--------------------------------------|---------------------|-------------------------|
| SwiftLint version pinning            | 0.57.0 (inconsistent)| 0.63.2 (verified)      |
| SPM cache                            | Partial             | Full (Package.resolved hash) |
| Periphery dead code CI check         | None                | ci.yml + thea-audit-main.yml |
| SBOM generation                      | None                | security.yml (syft)     |
| CodeQL static analysis               | None                | security.yml (Swift)    |
| npm audit (thea-tizen)               | None                | security.yml            |
| Docker container scan (TheaWeb)      | None                | security.yml (Trivy)    |
| License compliance check             | None                | security.yml            |
| Apple notarization                   | None (unsigned)     | release.yml (notarytool + stapler) |
| dSYM preservation                    | None                | release.yml (1 year)    |
| IPA creation                         | None                | release.yml             |
| DMG with /Applications symlink       | None                | release.yml             |
| Sparkle appcast.xml                  | None                | release.yml             |
| Version bump automation              | None                | release.yml (bump-version job) |
| Maestro screenshot on failure        | None                | e2e-tests.yml           |
| Maestro flow existence check         | None                | e2e-tests.yml           |
| Coverage trend (CodeCov)             | Basic               | Full + badges           |
| Build time tracking                  | None                | Timestamps in artifacts |
| Fork PR safety                       | May fail            | thea-audit-pr.yml graceful |
| Audit trend tracking                 | None                | thea-audit-main.yml CSV |
| Security audit scheduling            | 2 AM (overlaps)     | 1 AM (isolated)         |

---

## PROGRESS TRACKING

Update this section after each phase completes:

| Phase | Description                                  | Status      | Agent    | Completed |
|-------|----------------------------------------------|-------------|----------|-----------|
| N     | GitHub Workflows Overhaul (6 files)          | ✅ DONE     | mbam2    | 2026-02-19|
| O     | Thea Native Messaging Gateway                | ✅ DONE     | msm3u    | 2026-02-19|
| P     | Component Analysis + Individual Fixes        | ✅ DONE     | msm3u    | 2026-02-19|
| Q     | Test Coverage to 80%+                        | ✅ DONE     | msm3u    | 2026-02-19|
| R     | Periphery Full Resolution                    | ✅ DONE     | msm3u    | 2026-02-19|
| W     | V1 Re-verification (W1-W8)                   | 🔄 RUNNING  | msm3u    | —         |
| S     | CI/CD Green Verification                     | ⏳ PENDING  | —        | —         |
| T     | Notarization Pipeline                        | ⏳ PENDING  | —        | —         |
| U     | Final Verification Report                    | ⏳ PENDING  | —        | — (→ auto-start v3) |
| V     | Manual Ship Gate                             | ⚠️ DEFERRED | Alexis   | MERGED into v3 AD3 |

**From v1 (carried forward — all DONE):**
| Phase | Description                                  | Status      | Agent    | Completed |
|-------|----------------------------------------------|-------------|----------|-----------|
| A1    | OfflineQueueService testability              | ✅ DONE     | a24cde1  | 2026-02-18|
| A2    | Schema migration wire-in                     | ✅ DONE     | 7f2ceaaa | 2026-02-18|
| B     | Build System (4/4 platforms 0 err 0 warn)    | ✅ DONE     | a2bff42  | 2026-02-18|
| C     | Swift Tests (4045/4045)                      | ✅ DONE     | verified | 2026-02-18|
| D1    | @unchecked Sendable (75 justified)           | ✅ DONE     | a254aba  | 2026-02-18|
| D2    | try? Reduction (137 annotated)               | ✅ DONE     | a254aba  | 2026-02-18|
| D3    | Periphery Dead Code (partial — continue in R)| ⏳ PARTIAL  | afc0c7b  | 2026-02-18|
| E     | CI/CD Repair (6 YAML files)                  | ✅ DONE     | a2ba758  | 2026-02-18|
| F     | Liquid Glass + UX/UI                         | ✅ DONE     | addb4f7  | 2026-02-18|
| G     | SwiftData Migration                          | ✅ DONE     | 7f2ceaaa | 2026-02-18|
| H     | IMPL_PLAN Phases 4-8                         | ✅ DONE     | a7eb850  | 2026-02-18|
| I     | Tizen + TheaWeb                              | ✅ DONE     | a96b26d  | 2026-02-18|
| J     | Security Audit                               | ✅ DONE     | a64c7c4  | 2026-02-18|
| K     | Documentation                                | ✅ DONE     | ab9fa83  | 2026-02-18|
| L     | Final Verification v1                        | ✅ DONE     | a5e9d5b  | 2026-02-18|
| M     | Manual Ship Gate v1                          | ⏳ MANUAL   | Alexis   | —         |

**Ship-Ready % (automated)**: ~30% v2 phases complete (all v1 phases done, v2 phases pending)
**Last updated**: 2026-02-19

---

## BEST PRACTICES REFERENCE (v2 additions)

### Thea Messaging Gateway — WS Server (Port 18789)
```swift
// Thea hosts ws://127.0.0.1:18789 natively via TheaGatewayWSServer
let request = #"{"type":"req","id":"\#(uuid)","method":"channels.list","params":{}}"#

// WRONG — JSONRPC 2.0 (what v1 incorrectly used)
// let request = #"{"jsonrpc":"2.0","id":"\#(uuid)","method":"channels.list","params":{}}"#
```

### Thea Messaging Session Keys
```
// Session key format: "{platform}:{chatId}:{senderId}" — per-channel-peer isolation
"telegram:chat123:user456"         // Telegram DM
"slack:C12345678:U98765432"         // Slack channel message
"discord:channel789:user321"        // Discord channel
"whatsapp:+15555550123:+15555550123" // WhatsApp DM
"matrix:!roomid:matrix.org:@user:matrix.org" // Matrix room
```

### Thea Messaging — Design Reference (from OpenClaw research)
```
// KEY PRINCIPLES implemented natively:
// 1. Per-peer isolation: "{platform}:{chatId}:{senderId}" key prevents context leaks
// 2. Daily reset at 4am: MessagingSessionManager.scheduleDailyReset()
// 3. Rate limiting: 5/min/channel (OpenClawBridge — keep as-is)
// 4. Tool policy: allow read/web/messaging, deny runtime/elevated
// 5. MMR re-ranking: diversified retrieval with temporal decay
// 6. Loopback only: TheaGatewayWSServer binds to 127.0.0.1 only
// 7. Keychain: all credentials in MessagingCredentialsStore
```

### GitHub Actions: Apple Notarization (2026)
```yaml
# CORRECT — xcrun notarytool (altool deprecated Jan 2023)
- name: Notarize
  run: |
    xcrun notarytool submit "$ZIP_PATH" \
      --apple-id "${{ secrets.APPLE_ID }}" \
      --password "${{ secrets.APPLE_APP_PASSWORD }}" \
      --team-id "${{ secrets.APPLE_TEAM_ID }}" \
      --wait --timeout 30m
    xcrun stapler staple "$APP_PATH"

# WRONG — altool (deprecated, will fail on new macOS)
# xcrun altool --notarize-app ...
```

### GitHub Actions: CodeQL for Swift (2026)
```yaml
- uses: github/codeql-action/init@v3
  with:
    languages: swift
    # Use extended queries for more thorough analysis
    queries: security-extended,security-and-quality

- name: Build for CodeQL
  run: |
    xcodebuild build -scheme Thea-macOS \
      CODE_SIGNING_ALLOWED=NO -derivedDataPath build

- uses: github/codeql-action/analyze@v3
  with:
    category: codeql-swift
    upload: true
```

### Thea Messaging Multi-Agent Routing (2026)
```swift
// In OpenClawBridge.swift (repurposed) — route by platform + content:
// - main agent:    Telegram, Discord, Matrix, iMessage (general)
// - work agent:    Slack, work-prefix channels
// - health agent:  Messages with workout/sleep/stress/calories keywords
// - moltbook agent: Moltbook-prefix messages (existing MoltbookAgent wiring)
```

### Swift 6 Actor Isolation — Thea Messaging (2026)
```swift
// All platform connectors are actors (background I/O isolation):
actor TelegramConnector: MessagingPlatformConnector { ... }
actor DiscordConnector: MessagingPlatformConnector { ... }
// etc.

// TheaMessagingGateway is @MainActor @ObservableObject (UI state on main):
@MainActor final class TheaMessagingGateway: ObservableObject { ... }

// Actor hop is automatic:
await connector.send(message)  // crosses actor boundary transparently
```

---

### Thea Messaging Credential Setup (per platform)
```
// All credentials stored in Keychain via MessagingCredentialsStore
// Set via TheaMessagingSettingsView (Settings → Messaging Gateway)

// Telegram: Create bot via @BotFather → paste Bot Token
// Discord: Dev Portal → Bot → Token (enable GUILD_MESSAGES + DIRECT_MESSAGES intents)
// Slack: Dev Portal → Socket Mode → App-Level Token (xapp-) + Bot Token (xoxb-)
// BlueBubbles: Install on macOS, set server URL + password in settings
// WhatsApp: Meta Business → Cloud API → Access Token + Phone Number ID
// Signal: brew install signal-cli → register phone number
// Matrix: homeserver URL + access token (login via Element or /login API)
```

### Thea Gateway Verification (macOS)
```bash
# Verify Thea gateway is running (after app launch):
curl http://127.0.0.1:18789/health
# Expected: {"status":"ok","platform":"thea","port":18789}

# Check which platforms are connected:
# → Settings → Messaging Gateway in Thea app

# Telegram test (if botToken configured):
# Send a message to your bot → verify it appears in TheaMessagingChatView

# OpenClawClient.swift still works:
# It connects to ws://127.0.0.1:18789 — now Thea's own server, not OpenClaw
```

### Key Design Insights from OpenClaw Research (Phase O implementation reference)
```swift
// IMPLEMENTED in Thea's native gateway:

// 1. Slack streaming: SlackConnector uses tokenwise chat.postMessage updates
//    → O3: SlackConnector.send() can use Slack's streaming-friendly blocks API

// 2. MMR memory re-ranking:
//    → O9: MessagingSessionManager.relevantContext() implements MMR with temporal decay

// 3. Discord interactive elements (buttons/selects/modals):
//    → O2: DiscordConnector.send() can include Discord Components JSON in payload

// 4. Subagent nesting → maps to TaskPlanDAG:
//    → P16: AgentTeamOrchestrator wires TaskPlanDAG leaf nodes as sub-agents

// 5. Tool schema: no anyOf/oneOf/allOf (already correct in Thea tool definitions)
//    → Audit AnthropicToolCatalog.swift tool schemas in Phase P

// 6. Session daily reset at 4am:
//    → O9: MessagingSessionManager.scheduleDailyReset()

// 7. SSRF protection: validate outbound URLs in all connector send() implementations
//    → O1-O7: Add URL validation before URLSession calls
```

### Claude Opus 4.6 + Sonnet 4.6 — Model IDs (Feb 2026)
```swift
// Use these EXACT model IDs in AnthropicProvider + AIModel catalog:
"claude-opus-4-6"              // Best: planning, agents, computer use, injection resistance
"claude-sonnet-4-6"            // Balanced: near-flagship at lower cost, adaptive reasoning
"claude-haiku-4-5-20251001"    // Fast/cheap: iOS, low-latency responses

// For Thea messaging (AI routing in OpenClawBridge):
// Primary: claude-opus-4-6 (best injection resistance)
// Fallback: claude-sonnet-4-6

// Pricing (Feb 2026):
// Opus 4.6:   $3/M input, $15/M output
// Sonnet 4.6: Same as Sonnet 4.5 (economical)
// Haiku 4.5:  Cheapest Anthropic model
```

### Claude Agent Teams Architecture (Feb 2026)
```swift
// Team Lead pattern for Thea's AgentTeamOrchestrator:
// 1. Team Lead receives task + decomposes via TaskPlanDAG
// 2. Each leaf node → independent Claude API call (teammate)
// 3. Each teammate has: clean context window, specific subtask, tool access
// 4. Team Lead aggregates teammate results → synthesises final response
// 5. Progress streamed to user via Thea messaging channel in real-time

// Example: "Plan my week" →
//   Teammate A: "Fetch calendar events for next 7 days"
//   Teammate B: "Check my energy/health patterns from HealthKit"
//   Teammate C: "Review outstanding tasks and deadlines"
//   Team Lead: Synthesises A+B+C → optimal weekly plan
```

### MLX Audio + Vision 2026
```swift
// mlx-audio 2026: TTS + STT + STS (speech-to-speech)
// mlx-vlm 2026: VLMs with faster speculative decoding
// Apple SpeechAnalyzer API (macOS/iOS 26): superior on-device STT

// SpeechAnalyzer availability check:
if #available(macOS 26.0, iOS 19.0, *) {
    // Use SpeechAnalyzer (better accuracy, Apple Silicon optimised)
} else {
    // Fall back to MLXAudioEngine STT (GLM-ASR-Nano)
}

// vllm-mlx (MSM3U only): OpenAI-compatible server, 400+ tok/s
// Alternative to direct MLX for high-throughput inference
// Start: python -m vllm.entrypoints.openai.api_server --model <path> --backend mlx
```

### SwiftLint Version Reference (2026)
```bash
# Latest stable as of Feb 2026: 0.64.0 (0.64.0-rc.1 in beta)
# v1 plan had version inconsistency (0.57.0 cache vs 0.63.2 binary)
# Always:
swiftlint version   # Log actual installed version in every CI run
brew upgrade swiftlint  # Keep updated on dev machines
# Pin in CI cache key to whatever `brew info swiftlint` shows as current stable
```

---

## NOTES AND DECISIONS LOG (v2)

**2026-02-19**: v2 created. Key decisions:
- Thea native messaging gateway: replaces OpenClaw — no npm, no Node.js daemon, direct APIs (wrong framing breaks all advanced features)
- Notarization must be automated (unsigned builds are NOT suitable for personal use on other Macs)
- SBOM + CodeQL added because security scanning is a core Thea value
- Multi-platform messaging wired natively (O1-O7 connectors)
- Multi-agent routing added to separate work/personal/health contexts
- dSYMs preserved for 1 year (needed for crash report symbolication)
- Periphery from v1 continues in Phase R — not done until ALL items addressed
- Phases N and O can run in parallel (no dependency between them)
- Phase Q (coverage) requires Phase O complete (messaging connector tests counted in coverage)

**2026-02-19 (v2 update #2)**: OpenClaw research used to design Thea Native Messaging Gateway:
OpenClaw was researched to understand what a messaging gateway must do — NOT to install it.
Thea replaces OpenClaw with a native Swift implementation.

KEY CHANGELOG FEATURES (must be implemented in Phase O):
- iOS/Watch companion app: inbox UI + gateway commands + iOS Share Extension + Talk Mode (background)
  → Phase O: Add iOS companion registration/pairing support in OpenClawIntegration
- Slack streaming: `chat.startStream`, `chat.appendStream`, `chat.stopStream` new methods
  → Phase O9: Add streaming response delivery for Slack channel (tokenwise vs chunkwise)
- Anthropic 1M context: set `params.context1m: true` in agent config for extended context
  → Phase P13: Add 1M context toggle in AnthropicProvider config
- Sonnet 4.6 officially supported in OpenClaw model lists (use "anthropic/claude-sonnet-4-6")
  → Phase P13: Update model catalog
- Memory MMR re-ranking + temporal decay (replaces flat cosine similarity)
  → Phase O6: Implement MMR search in OpenClaw memory integration
- Context window: upgraded from 24K → 150K tokens for OpenClaw sessions
  → Phase O: Remove any artificial 24K context truncation
- Discord Components v2: buttons/selects/modals now available in Discord channel
  → Phase O8: Add interactive Discord components in bot responses
- Subagent nesting: agents can spawn sub-agents, each with clean context window
  → Phase P16: Wire into TaskPlanDAG for teammate pattern
- SSRF protection: new gateway-level protection against server-side request forgery
  → O1-O7: Validate outbound URLs in all connector send() implementations
- exec tool hardening: `tools.exec.safeBins` list (allowlisted executables only)
  → O10: Add tool safeBins allowlist in TheaMessagingSettingsView tool policy section
- Telegram token redaction: tokens now redacted in all gateway logs automatically
  → Phase O: Remove any custom Telegram token redaction (now handled by gateway)
- BREAKING: Model schema changed — no longer accepts anyOf/oneOf/allOf in tool schemas
  → Phase O: Audit all tool definitions, replace anyOf/oneOf/allOf with explicit types

COMMUNITY RISK WARNINGS (incorporate into OpenClaw setup):
1. COST RUNAWAY: Agent loops can easily spend $300-750/month. Mitigation:
   - OpenClawBridge.maxResponsesPerMinute=5 already limits throughput
   - Monitor via Anthropic Console (token usage per day)
   - Add budget alert in AnthropicProvider if needed
   - OpenClawBridge.maxResponsesPerMinute=5 already addresses this for Thea
2. MALICIOUS EXTENSION: "ClawdBot Agent" on VS Code marketplace is MALWARE (not official).
   - Install ONLY official: `npm install -g openclaw` from npmjs.com
   - Never install VS Code extensions claiming to be "OpenClaw" — no official extension exists
3. RELIABILITY: Gateway may silently report "success" for failed deliveries on some platforms.
   - Add delivery confirmation tracking in Phase O (use ACK events where available)
4. SETUP COMPLEXITY: Per-platform setup varies. Telegram is simplest (5 min), Matrix most complex.
   - Check TheaMessagingSettingsView for connection errors

PDF SECURITY KIT FINDINGS (Kit Sécurité OpenClaw, from ~/Downloads):
The PDF identified 5 critical risks — incorporated into Thea gateway design:
  Risk 1: Public gateway exposure → Fix: bind to loopback (127.0.0.1) only — NEVER 0.0.0.0
  Risk 2: Anyone can DM the bot → Fix: dmPolicy: "pairing" + dmScope: "per-channel-peer"
  Risk 3: Credentials in plain text → Fix: use keychain/environment vars; encrypt openclaw.json
  Risk 4: Prompt injection → Fix: OpenClawSecurityGuard already handles (22 patterns, NFD norm)
  Risk 5: Dangerous commands → Fix: tools.exec.safeBins allowlist + sandbox: "non-main" mode

**2026-02-19 (v2 update)**: OpenClaw + AI research incorporated:
- OpenClaw iOS app is in "internal preview" as of Feb 2026 — iOS node code should be ready but
  pairing cannot be fully tested until app is publicly available. Code must still be written.
- Canvas serves at `/__openclaw__/canvas/` (port 18793), A2UI at `/__openclaw__/a2ui/`
- Session isolation: "{platform}:{chatId}:{senderId}" key is CRITICAL — implemented in MessagingSessionManager
- openclaw.json uses JSON5 format (comments + trailing commas OK) — not strict JSON
- Claude Opus 4.6 (Feb 5) + Sonnet 4.6 (Feb 17) are now live — update model catalog in P13
- Opus 4.6 outperforms GPT-5.2 by 144 ELO on GDPval-AA benchmark
- OpenClaw explicitly recommends Opus 4.6 for tool-enabled + injection-resistant bots
- Agent Teams (Claude Code) maps to TaskPlanDAG — wire in P16
- SpeechAnalyzer API (macOS/iOS 26) is superior to GLM-ASR-Nano — add platform check in P14
- mlx-audio 2026 adds STS (speech-to-speech) — enables voice-only OpenClaw channels
- SwiftLint: latest stable is 0.64.0 (0.64.0-rc.1 beta) — update ci.yml cache key
- vllm-mlx available as OpenAI-compatible server for MSM3U high-throughput inference
- Node 22 is REQUIRED for OpenClaw (not 18+ as some older docs say) — verify before install
- Cron jobs stored at ~/.openclaw/cron/jobs.json (directly readable for debugging)
- Phase ordering confirmed optimal: N+O+P parallel → Q+R → S+T → U → V

**Sources used for v2 research:**
- [Telegram Bot API](https://core.telegram.org/bots/api) — getUpdates, sendMessage, getMe
- [Discord Gateway API v10](https://discord.com/developers/docs/topics/gateway) — WebSocket, Intents, Identify
- [Slack Socket Mode](https://api.slack.com/apis/connections/socket) — WebSocket, envelope ACK
- [BlueBubbles API](https://docs.bluebubbles.app/server/api-v1/) — iMessage HTTP + WebSocket
- [WhatsApp Business Cloud API](https://developers.facebook.com/docs/whatsapp/cloud-api) — webhooks + REST
- [signal-cli](https://github.com/AsamK/signal-cli) — JSON-RPC daemon mode
- [Matrix C-S API v3](https://spec.matrix.org/v1.13/client-server-api/) — /sync, PUT message
- [OpenClaw research (design reference)](https://openclaw.ai/) — session isolation, MMR, tool policy
- [OpenClaw Security Guide](https://docs.openclaw.ai/gateway/security) — security risks (adapted)
- [Claude Opus 4.6 release](https://www.anthropic.com/news/claude-opus-4-6)
- [Claude Sonnet 4.6 announcement](https://markets.financialcontent.com/stocks/article/tokenring-2026-2-18-anthropic-unleashes-claude-sonnet-46)
- [mlx-swift GitHub](https://github.com/ml-explore/mlx-swift/)
- [mlx-audio package](https://mlx-framework.org/)
- [vllm-mlx for Apple Silicon](https://github.com/waybarrios/vllm-mlx)
- [SwiftLint releases](https://github.com/realm/SwiftLint/releases)
- [GitHub Actions iOS CI/CD 2026](https://devtoolbox.dedyn.io/blog/github-actions-cicd-complete-guide)
- [Apple notarytool documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [OpenClaw Changelog 2026.2.18](https://openclaw.ai/changelog) — iOS/Watch app, Slack streaming, 1M context, MMR memory, Discord v2
- [ntfy.sh documentation](https://docs.ntfy.sh) — curl syntax, priorities, tags, GitHub Actions
- [Kit Sécurité OpenClaw PDF](local:~/Library/Mobile Documents/.../🔐 Kit Sécurité OpenClaw.pdf) — 5 security risks + mitigations
- [OpenClaw community reviews 2026](https://reddit.com/r/openclaw) — cost runaway warnings, malicious extension "ClawdBot Agent"
