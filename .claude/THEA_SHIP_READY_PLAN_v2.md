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
#   2. OpenClaw: full depth integration — O_PRE (gateway setup), O0–O10 (protocol,
#      auth, Canvas, sessions, memory, multi-agent, voice, nodes, skills, UI)
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
| Phase O: OpenClaw         | ⏳ PENDING      | Protocol rewrite + all new features (O_PRE first) |
| Phase P: Components       | ⏳ PENDING      | 16 subsystem analyses + AI 2026 upgrades |
| Phase Q: Tests ≥80%       | ⏳ PENDING      | Baseline measurement first |
| Phase R: Periphery        | ⏳ PARTIAL      | ~2,667 items remain from v1 D3 |
| Phase S: CI Green         | ⏳ PENDING      | Blocked by O + P |
| Phase T: Notarization     | ⏳ PENDING      | Blocked by S |
| Phase W: V1 Re-verify     | ⏳ PENDING      | Run after O + P complete |
| Phase U: Final Report     | ⏳ PENDING      | Blocked by all above |
| Phase V: Manual Gate      | ⏳ MANUAL       | Alexis only — last step |
| **Overall ship-ready %**  | **~45%**        | N done; O/P/Q/R/W/S/T/U all pending |

*Last updated: 2026-02-19*

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
- [ ] Security audit integration: `openclaw security audit` from Thea

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
Wave 0 — PREREQUISITE (do first, unblocks everything):
  ntfy-setup — Subscribe to ntfy.sh/thea-msm3u on your iPhone (see NTFY SETUP below)
  O_PRE      — OpenClaw Gateway Install + Config on MSM3U  [~20 min]
               (npm install, oncboard, openclaw doctor, gateway start)

Wave 1 — PARALLEL (no dependencies between O, P):
  ✅ N — GitHub Workflows Overhaul   [DONE 2026-02-19 — all 6 YAML files written + committed]
  O — OpenClaw Deep Integration        [MSM3U, ~6h, largest new feature, needs O_PRE]
  P — Component Analysis + Fixes       [MSM3U, ~4h, P1–P16 including AI 2026 upgrades]

Wave 2 — AFTER WAVE 1 (parallel with each other):
  Q — Test Coverage to 80%+            [MSM3U, ~3h, after O complete for OpenClaw tests]
  R — Periphery Full Resolution        [MSM3U, ~4h, independent, can overlap with Q]

Wave 3 — AFTER WAVE 2:
  W — V1 Re-verification               [MSM3U, ~1h, verify O+P changes didn't break v1 state]
  S — CI/CD Green Verification         [MSM3U, ~2h, after W passes]
  T — Notarization Pipeline Setup      [MSM3U, ~1h, after S green]

Wave 4 — FINAL:
  U — Final Verification Report        [MSM3U, ~30min, after all above]
  V — Manual Ship Gate                 [Alexis only, last step]

Agent parallelism within waves:
  Wave 1: Spawn 2 Claude Code sessions simultaneously on MSM3U (N is already done):
    Session 1: "Execute Phase O — OpenClaw Deep Integration (O_PRE already done)"
    Session 2: "Execute Phase P — Component Analysis + Fixes (P1–P16)"
  Each session sends ntfy progress notifications on phase start/complete/failure.
  Monitor both and merge results via git pushsync when each session commits.
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

## PHASE W — V1 RE-VERIFICATION (Run after O+P complete)

**Goal**: Verify that all v1 ship-ready criteria still hold after Phase O and Phase P code changes.
**Why needed**: New code from O (OpenClaw protocol rewrite) and P (component upgrades) may inadvertently break v1 achievements — builds, tests, security files, schema migration, Liquid Glass.
**Estimated time**: ~1 hour
**Run after**: Phase O AND Phase P both complete

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

## PHASE O — OPENCLAW DEEP INTEGRATION (MSM3U)

**Goal**: Full OpenClaw capability — proper protocol, all channels, Canvas, sessions, memory,
         multi-agent routing, node capabilities, skills, tools, cron, config management,
         security audit, and comprehensive Thea settings UI.

**Why**: Current implementation uses wrong protocol framing (JSONRPC 2.0 vs OpenClaw's
         req/res/event framing), lacks authentication, and only implements 3 of ~20 capabilities.
         OpenClaw is listed as "ACTIVE all platforms" in CLAUDE.md — it must be fully functional.

### O_PRE: Install + Configure OpenClaw Gateway on MSM3U

**Must complete BEFORE O1–O10 — Thea's OpenClaw code requires a live Gateway to test against.**

```bash
# 1. Install OpenClaw (requires Node 22+)
node --version  # Must be ≥22
npm install -g openclaw@latest
openclaw --version

# 2. Run interactive onboarding (sets up auth + daemon)
openclaw onboard --install-daemon
# When prompted:
#   Provider: Anthropic
#   Model: claude-opus-4-6   ← Best for prompt injection resistance (per OpenClaw docs)
#   Channel: start with none (add channels via config after)
#   Persistence: yes

# 3. Create optimised openclaw.json for Thea integration
# File: ~/.openclaw/openclaw.json  (JSON5 format — comments + trailing commas OK)
cat > ~/.openclaw/openclaw.json << 'EOF'
{
  // Thea's OpenClaw identity
  identity: {
    name: "Thea",
    emoji: "🌿",
    theme: "dark",
  },

  // Primary agent — uses best model for security + tool use
  agent: {
    workspace: "~/.openclaw/workspace",
    model: {
      primary: "anthropic/claude-opus-4-6",   // Best prompt-injection resistance
      fallbacks: ["anthropic/claude-sonnet-4-6"],
    },
    heartbeat: true,
  },

  // Session isolation — CRITICAL for multi-sender safety
  session: {
    dmScope: "per-channel-peer",   // Each sender gets isolated context
    scope: "per-sender",
    reset: { mode: "daily", hour: 4 },  // Reset at 4am daily
  },

  // Channel defaults — start locked down, open per channel as needed
  channels: {
    // Enable channels one by one as you set them up:
    // whatsapp: { dmPolicy: "pairing", groups: { "*": { requireMention: true } } },
    // telegram: { dmPolicy: "pairing" },
    // discord: { dmPolicy: "pairing" },
    // signal: { dmPolicy: "pairing" },
  },

  // Tool permissions — allow core tools, deny dangerous ones
  tools: {
    allow: ["read", "web", "messaging"],
    deny: ["group:runtime", "sessions_spawn", "gateway"],
    elevated: { allowFrom: [] },  // No one gets elevated by default
  },

  // Sandbox — non-main sessions (groups) run in Docker for safety
  sandbox: {
    mode: "non-main",
    scope: "session",
    workspaceAccess: "ro",  // Read-only workspace in sandboxed sessions
  },

  // Gateway — loopback only (Tailscale for remote access)
  gateway: {
    bind: "loopback",
    auth: { mode: "token" },  // Token set during onboard
    mDNS: { mode: "minimal" },
  },

  // Logging — redact sensitive tool output
  logging: {
    level: "info",
    redactSensitive: "tools",
  },
}
EOF

# 4. Validate configuration
openclaw doctor
# Must show: ✅ Config valid, ✅ API key OK, ✅ Permissions OK

# 5. Start gateway and verify
openclaw gateway status
openclaw gateway start  # if not running

# 6. Verify WebSocket endpoint is live
curl -s http://127.0.0.1:18789/health && echo "Gateway healthy"

# 7. Open dashboard (optional but useful)
openclaw dashboard  # Opens http://127.0.0.1:18789/ in browser

# 8. Test from Thea
# Set OPENCLAW_GATEWAY_TOKEN env var for Thea to use:
GATEWAY_TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null || \
                grep -r '"token"' ~/.openclaw/openclaw.json | head -1)
echo "Token configured: ${GATEWAY_TOKEN:0:10}..."
```

**Canvas URL (for O4 WKWebView integration):**
- Canvas HTML served at: `http://127.0.0.1:18793/__openclaw__/canvas/`
- A2UI scripts at: `http://127.0.0.1:18793/__openclaw__/a2ui/`
- Canvas port configurable via `gateway.canvasPort` (default 18793)

**Cron jobs file location (for O3 integration):**
- `~/.openclaw/cron/jobs.json` — directly readable for debugging

**iOS node pairing (for O3/O8 — note: iOS app in internal preview as of Feb 2026):**
```bash
openclaw nodes pending    # Show pending node pairing requests
openclaw nodes list       # Show paired nodes
# iOS app: download from TestFlight when available, then scan QR from dashboard
```

### O0: Protocol Analysis — What Must Change

**Current (wrong) protocol:**
```json
{"jsonrpc": "2.0", "id": "uuid", "method": "channels.list", "params": {}}
```

**Correct OpenClaw protocol:**
```json
// Request:   {"type":"req", "id":"uuid", "method":"channels.list", "params":{}}
// Response:  {"type":"res", "id":"uuid", "ok":true, "payload":{...}}
// Error:     {"type":"res", "id":"uuid", "ok":false, "error":{"code":...,"message":"..."}}
// Event:     {"type":"event", "event":"message.received", "payload":{...}, "seq":42}
// Handshake challenge: {"type":"event", "event":"auth.challenge", "payload":{"nonce":"...","ts":...}}
// Handshake response:  {"type":"req", "id":"uuid", "method":"connect",
//                       "params":{"minProtocol":1,"maxProtocol":1,"meta":{...},
//                                 "role":"operator","scopes":["operator.read","operator.write"],
//                                 "deviceId":"thea-...", "token":"..."}}
// Auth success:        {"type":"res", "id":"uuid", "ok":true,
//                       "payload":{"protocol":1, "auth":{"deviceToken":"..."}}}
```

### O1: Update OpenClawTypes.swift — New Protocol Types

**Add to OpenClawTypes.swift:**
```swift
// Gateway wire protocol (OpenClaw native format)
struct OpenClawRequest: Codable, Sendable {
    let type: String   // always "req"
    let id: String     // UUID for correlation
    let method: String
    let params: OpenClawParams

    init(id: String = UUID().uuidString, method: String, params: OpenClawParams = .empty) {
        self.type = "req"; self.id = id; self.method = method; self.params = params
    }
}

struct OpenClawResponse: Codable, Sendable {
    let type: String   // always "res"
    let id: String
    let ok: Bool
    let payload: OpenClawPayload?
    let error: OpenClawResponseError?
}

struct OpenClawEvent: Codable, Sendable {
    let type: String   // always "event"
    let event: String
    let payload: OpenClawPayload
    let seq: Int?
    let stateVersion: Int?
}

struct OpenClawResponseError: Codable, Sendable {
    let code: Int
    let message: String
    let data: OpenClawPayload?
}

// Add new platforms:
extension OpenClawPlatform {
    case bluebubbles     // Recommended iMessage (BlueBubbles)
    case googleChat      // Google Chat
    case microsoftTeams  // Microsoft Teams
    case webchat         // OpenClaw WebChat
    case zalo
    var displayName: String {
        // Add new cases
        case .bluebubbles: "iMessage (BlueBubbles)"
        case .googleChat: "Google Chat"
        case .microsoftTeams: "Microsoft Teams"
        case .webchat: "WebChat"
        case .zalo: "Zalo"
    }
}

// OpenClaw Session (maps to agent:{agentId}:{provider}:{scope}:{identifier})
struct OpenClawSession: Identifiable, Codable, Sendable {
    let id: String          // session key e.g. "agent:main:whatsapp:dm:+15555550123"
    let agentId: String     // "main", "work", "personal", etc.
    let channelType: String // "whatsapp", "telegram", etc.
    let scope: String       // "dm", "group", "channel"
    let identifier: String  // "+15555550123", group ID, etc.
    let lastActivity: Date?
    var transcript: [OpenClawMessage]
}

// OpenClaw Agent (named agent in the gateway)
struct OpenClawAgent: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let model: String
    let isDefault: Bool
    var sessionCount: Int
}

// OpenClaw Canvas state
struct OpenClawCanvasState: Codable, Sendable {
    let html: String
    let a2uiVersion: Int
    let updatedAt: Date
}

// OpenClaw Node capability
enum OpenClawNodeCapability: String, Codable, Sendable {
    case cameraSnap = "node.camera.snap"
    case cameraClip = "node.camera.clip"
    case screenRecord = "node.screen.record"
    case locationGet = "node.location.get"
    case notificationSend = "node.notification.send"
    case systemRun = "node.system.run"          // macOS only
    case systemNotify = "node.system.notify"    // macOS only
}

// OpenClaw Cron job
struct OpenClawCronJob: Identifiable, Codable, Sendable {
    let id: String
    let expression: String    // cron expression e.g. "0 9 * * 1-5"
    let agentId: String
    let message: String       // injected task message
    let enabled: Bool
    let nextRun: Date?
}

// Gateway status
struct OpenClawGatewayStatus: Codable, Sendable {
    let version: String
    let protocol_: Int      // protocol version (using _ to avoid keyword clash)
    let uptime: TimeInterval
    let connectedNodes: Int
    let activeChannels: Int
    let memoryUsedMB: Double
}

// Add gateway event types:
extension OpenClawGatewayEvent {
    case authChallenge(nonce: String)
    case authSuccess(deviceToken: String?)
    case sessionCreated(OpenClawSession)
    case sessionUpdated(OpenClawSession)
    case canvasUpdated(OpenClawCanvasState)
    case nodeStatus(nodeId: String, capabilities: [OpenClawNodeCapability])
    case cronFired(OpenClawCronJob)
    case gatewayStatus(OpenClawGatewayStatus)
    case configUpdated
}

// Add gateway commands:
extension OpenClawGatewayCommand {
    // Sessions
    case listSessions(agentId: String?)
    case getSession(sessionKey: String)
    case resetSession(sessionKey: String)
    case getHistory(sessionKey: String, limit: Int, before: Date?)

    // Agents
    case listAgents
    case getAgentConfig(agentId: String)

    // Canvas
    case getCanvas(agentId: String)
    case setCanvas(agentId: String, html: String)

    // Nodes
    case listNodes
    case invokeNode(nodeId: String, capability: OpenClawNodeCapability, params: [String: Any])

    // Config
    case getConfig(path: String?)
    case setConfig(path: String, value: Any)
    case patchConfig(patches: [[String: Any]])

    // Cron
    case listCronJobs(agentId: String?)
    case createCronJob(expression: String, agentId: String, message: String)
    case deleteCronJob(id: String)
    case enableCronJob(id: String, enabled: Bool)

    // Memory
    case searchMemory(agentId: String, query: String, limit: Int)
    case addMemory(agentId: String, content: String, tags: [String])

    // Status
    case getGatewayStatus
    case runSecurityAudit
}
```

### O2: Rewrite OpenClawClient.swift — Proper Protocol

**Key changes:**
- Replace JSONRPC 2.0 framing with `{type, id, method, params}` framing
- Implement challenge-response handshake
- Store and use device token (Keychain)
- Add pending request map for correlation (id → continuation)
- Add event sequence number tracking
- Add proper error handling with OpenClawResponseError
- Add connection health monitoring (ping every 30s)
- Add request timeout (default 30s)

```swift
// Core changes to OpenClawClient:
actor OpenClawClient {
    // Pending requests: id → CheckedContinuation<OpenClawPayload, Error>
    private var pendingRequests: [String: CheckedContinuation<OpenClawPayload, Error>] = [:]
    private var lastSeq: Int = 0
    private var deviceToken: String?  // persisted in Keychain

    // Proper framing:
    func send(command: OpenClawGatewayCommand) async throws -> OpenClawPayload {
        let requestId = UUID().uuidString
        let message = OpenClawRequest(id: requestId, method: command.method, params: command.params)
        let data = try JSONEncoder().encode(message)
        let json = String(data: data, encoding: .utf8)!
        try await webSocket?.send(.string(json))
        // Await response via continuation:
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation
        }
    }

    // Handshake on connect:
    private func performHandshake() async throws {
        // 1. Receive auth.challenge event
        // 2. Send connect request with deviceId, role, scopes, token
        // 3. Receive hello-ok response
        // 4. Extract and store deviceToken
    }

    // Health check:
    private func startHeartbeat() {
        Task {
            while connectionState == .connected {
                try? await Task.sleep(for: .seconds(30))
                try? await send(command: .ping)
            }
        }
    }

    // Keychain helpers:
    private func loadDeviceToken() -> String? {
        // SecKeychainItemCopyContent / SecItemCopyMatching
    }
    private func saveDeviceToken(_ token: String) {
        // SecItemAdd / SecItemUpdate
    }
}
```

### O3: Expand OpenClawIntegration.swift — Full Lifecycle

**Add:**
```swift
// Session management
private(set) var sessions: [OpenClawSession] = []
private(set) var agents: [OpenClawAgent] = []
private(set) var cronJobs: [OpenClawCronJob] = []
private(set) var canvasState: OpenClawCanvasState?
private(set) var nodes: [String: [OpenClawNodeCapability]] = [:]
private(set) var gatewayStatus: OpenClawGatewayStatus?

// On connect: fetch all state
private func fetchInitialState() async {
    async let channels = try? client.send(.listChannels)
    async let sessions = try? client.send(.listSessions(agentId: nil))
    async let agents = try? client.send(.listAgents)
    async let cron = try? client.send(.listCronJobs(agentId: nil))
    async let status = try? client.send(.getGatewayStatus)
    // Populate local state
}

// Canvas update subscription
var onCanvasUpdate: (@Sendable (OpenClawCanvasState) async -> Void)?

// Node capability invocation
func invokeNode(nodeId: String, capability: OpenClawNodeCapability, params: [String: Any] = [:]) async throws -> OpenClawPayload {
    return try await client.send(.invokeNode(nodeId: nodeId, capability: capability, params: params))
}

// Memory search
func searchMemory(agentId: String = "main", query: String, limit: Int = 10) async throws -> [OpenClawMemoryResult] {
    let result = try await client.send(.searchMemory(agentId: agentId, query: query, limit: limit))
    return result.decode(as: [OpenClawMemoryResult].self)
}

// Cron management
func createCronJob(expression: String, message: String, agentId: String = "main") async throws -> OpenClawCronJob {
    let result = try await client.send(.createCronJob(expression: expression, agentId: agentId, message: message))
    return result.decode(as: OpenClawCronJob.self)
}

// Config management
func getGatewayConfig(path: String? = nil) async throws -> Data {
    let result = try await client.send(.getConfig(path: path))
    return result.rawJSON
}

// Security audit
func runSecurityAudit() async throws -> OpenClawSecurityAuditResult {
    let result = try await client.send(.runSecurityAudit)
    return result.decode(as: OpenClawSecurityAuditResult.self)
}
```

### O4: OpenClaw Canvas View (Thea UI)

**Create**: `Shared/UI/Views/OpenClaw/OpenClawCanvasView.swift`
```swift
// A WKWebView that renders OpenClaw's A2UI canvas HTML
// Updates in real-time when canvasState changes
// Handles A2UI interactions (button taps, form submissions) by:
//   1. Intercepting WKWebView navigation decisions
//   2. Sending canvas.action events to Gateway
// Shows loading state while canvas initializes
// Shows error state when Gateway is disconnected
```

**Create**: `Shared/UI/Views/OpenClaw/OpenClawChatView.swift`
```swift
// Combined chat + canvas view for OpenClaw messaging:
// - Channel selector (left sidebar: WhatsApp, Telegram, etc.)
// - Conversation thread (center)
// - Canvas panel (right, dismissible)
// - Agent selector (switch between main/work/personal agents)
// - Session reset button
```

### O5: OpenClaw Settings View (Thea UI)

**Create**: `Shared/UI/Views/Settings/OpenClawSettingsView.swift`

**Sections:**
```swift
// 1. CONNECTION
//    - Gateway URL (default: ws://127.0.0.1:18789)
//    - Auth token (stored in Keychain, shown as •••)
//    - Connect/Disconnect toggle
//    - Status indicator (connected/disconnected/error)
//    - Gateway version + uptime
//
// 2. CHANNELS (per channel: WhatsApp, Telegram, Discord, etc.)
//    - Enable/disable per channel
//    - DM policy: pairing / allowlist / open / disabled
//    - Allowlist management (add/remove contacts)
//    - Group mention requirement
//
// 3. AGENTS
//    - List configured agents (main, work, personal)
//    - Per agent: model selection, tool profile, sandbox mode
//    - Create new agent
//    - Per-agent session reset
//
// 4. CANVAS
//    - Enable/disable Canvas panel
//    - Canvas port (default 18793)
//    - Show/hide in chat view
//
// 5. SCHEDULED TASKS (Cron)
//    - List active cron jobs
//    - Create new cron job (expression + message)
//    - Enable/disable/delete existing jobs
//
// 6. MEMORY
//    - Enable/disable hybrid search memory
//    - Embedding provider selection
//    - Memory search test input
//    - Clear memory option (with confirmation)
//
// 7. SECURITY
//    - Run security audit button → shows OpenClawSecurityAuditResultView
//    - Prompt injection detection toggle
//    - Rate limiting config
//    - Blocked keywords management
//    - Sandboxing mode (off/non-main/all)
//
// 8. NODES (paired devices)
//    - List paired nodes (iOS, Android, macOS companion)
//    - Capability list per node
//    - Pair new node button
//    - Revoke node pairing
//
// 9. NOTIFICATIONS
//    - OpenClaw proactive notification settings
//    - Notify on new message toggle
//    - Notify on cron job completion
```

**Wire into**: `macOS/UI/Settings/MacSettingsView.swift` → add "OpenClaw" sidebar item
Also wire into iOS settings tab.

### O6: Multi-Agent Routing in OpenClawBridge.swift

**Upgrade routing logic:**
```swift
// Route based on channel + content:
func determineAgent(for message: OpenClawMessage) -> String {
    // Work channels → "work" agent
    if message.channelID.hasPrefix("work-") || message.platform == .slack {
        return "work"
    }
    // Moltbook → MoltbookAgent (existing)
    if message.channelID.hasPrefix("moltbook") { return "moltbook" }
    // Health/wellness topics → specialized health agent
    if let healthKeywords = ["workout", "sleep", "stress", "calories"],
       healthKeywords.contains(where: message.content.lowercased().contains) {
        return "health"
    }
    // Default: main agent
    return "main"
}

// Use session isolation (per-peer routing):
func buildSessionKey(for message: OpenClawMessage) -> String {
    let agent = determineAgent(for: message)
    return "agent:\(agent):\(message.platform.rawValue):dm:\(message.senderID)"
}
```

### O7: OpenClaw Memory → PersonalKnowledgeGraph Integration

**Connect OpenClaw's hybrid memory search to Thea's PersonalKnowledgeGraph:**
```swift
// In PersonalKnowledgeGraph.swift — add OpenClaw memory sync:
extension PersonalKnowledgeGraph {
    /// Sync relevant entities to OpenClaw memory for cross-session recall
    func syncToOpenClawMemory() async {
        guard OpenClawIntegration.shared.isEnabled else { return }
        let topEntities = getAllEntities().filter { $0.importance > 0.7 }
        for entity in topEntities {
            try? await OpenClawIntegration.shared.addMemory(
                agentId: "main",
                content: entity.description,
                tags: [entity.type.rawValue, "thea-kg"]
            )
        }
    }
}
```

### O8: Node Capability — Screen Context for AI

**Connect OpenClaw node screen capture to G1 Live Screen Monitoring:**
```swift
// In LiveScreenMonitor.swift or new OpenClawNodeBridge.swift:
// When agent requests screen context:
extension OpenClawIntegration {
    func captureScreenForAgent() async throws -> Data {
        // Use node.screen.record (if node paired) OR
        // Fall back to local CGWindowListCreateImage (macOS only)
        if nodes["local"] != nil {
            let result = try await invokeNode(
                nodeId: "local",
                capability: .systemRun,
                params: ["cmd": "screencapture -x -t png -"]
            )
            return result.binaryData ?? Data()
        }
        // Local fallback for macOS:
        return LiveScreenMonitor.shared.captureCurrentScreen() ?? Data()
    }
}
```

### O9: Tests for OpenClaw Components

**Add test files:**
- `Tests/IntegrationTests/OpenClawClientTests.swift`: Protocol framing, handshake mock
- `Tests/IntegrationTests/OpenClawBridgeTests.swift`: Agent routing, rate limiting, sanitization
- `Tests/IntegrationTests/OpenClawSecurityGuardTests.swift`: All 22 injection patterns
- `Tests/IntegrationTests/OpenClawIntegrationTests.swift`: Lifecycle, state management

**Mock Gateway for tests:**
```swift
// MockOpenClawGateway: URLSessionWebSocketTask mock that:
// 1. Responds to connect with challenge then hello-ok
// 2. Sends test events (message.received, channel.updated)
// 3. Responds to requests with realistic payloads
```

### O10: OpenClaw Moltbook Agent Integration

**Verify and enhance existing wiring:**
```bash
grep -n "moltbook\|MoltbookAgent" Shared/Integrations/OpenClaw/OpenClawBridge.swift
grep -n "processInboundMessage\|onMessageReceived" Shared/Agents/MoltbookAgent.swift
```
- Ensure MoltbookAgent.processInboundMessage handles OpenClawMessage protocol correctly
- Add reply-back: after MoltbookAgent processes, send acknowledgement via OpenClaw channel

---

## PHASE P — COMPONENT ANALYSIS + INDIVIDUAL IMPROVEMENTS (MSM3U)

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
- OpenClawBridge (incoming message routing)
- PersonalKnowledgeGraph (context retrieval)

**Improvements to investigate**:
- [ ] Does ChatManager stream responses to OpenClaw channels? If not, add streaming support
- [ ] Does ConfidenceSystem run on OpenClaw-sourced messages? Should it?
- [ ] Is there a unified conversation history for cross-channel sessions?
- [ ] Does BehavioralFingerprint track OpenClaw interactions?
- [ ] Add conversation context from PersonalKnowledgeGraph before sending to AI

### P2: ConfidenceSystem — Response Verification
**Analyze**: `Shared/Intelligence/Verification/ConfidenceSystem.swift`
**Current**: Runs async after every AI response, stores confidence in MessageMetadata.confidence
**Improvements**:
- [ ] Surface confidence score in OpenClaw responses (append low-confidence warning)
- [ ] Skip confidence verification for OpenClaw if latency > 2s (messaging users don't wait)
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
  (e.g., "openclaw gateway stop", "openclaw config set gateway.auth.mode=none")
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
  - Should be Thea's default for: OpenClaw auto-responses, AgentMode tasks, AutonomyController
- **Claude Sonnet 4.6** (Feb 17, 2026): Near-flagship at Sonnet 4.5 price, adaptive reasoning
  - Should be Thea's default for: daily chat, light tasks, iOS (cost-sensitive)
  - OpenClaw fallback model: `anthropic/claude-sonnet-4-6`

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
- [ ] Add speech-to-speech (STS) for OpenClaw voice pipeline
  (incoming voice note → direct STS response without intermediate text)
- [ ] Wire SpeechAnalyzer into OpenClaw voice note pipeline (O3 above)
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
- [ ] Wire OpenClaw image attachment → MLXVisionEngine pipeline:
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
- [ ] Wire progress updates → OpenClaw channel (users see subtask progress in real-time)
- [ ] Add per-teammate context isolation (each subtask gets clean context window)
- [ ] Add team result caching (prevent redundant subtask re-runs)
- [ ] Test: 3-task parallel team completes faster than sequential
- [ ] Test: team leader correctly synthesizes 3 subtask results

---

## PHASE Q — TEST COVERAGE TO 80%+ (MSM3U)

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

**Agent for OpenClaw tests** (O9 above):
All 4 OpenClaw test files

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

---

## PHASE T — NOTARIZATION PIPELINE SETUP (MSM3U)

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

**Goal**: Confirm ALL ship-ready criteria met. Generate comprehensive report.

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

# 6. OpenClaw protocol compliance
echo "" >> /tmp/ship-report.txt
echo "=== OPENCLAW PROTOCOL ===" >> /tmp/ship-report.txt
grep -n '"type":"req"' Shared/Integrations/OpenClaw/OpenClawClient.swift | \
  head -3 | tee -a /tmp/ship-report.txt || \
  echo "WARNING: Still using JSONRPC 2.0 (not upgraded to OpenClaw native protocol)" >> /tmp/ship-report.txt

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

---

## PHASE V — MANUAL SHIP GATE (Alexis required — do last)

**These steps CANNOT be automated. Alexis must be present.**

### V1: OpenClaw Integration Smoke Test
```
1. Start OpenClaw gateway: openclaw gateway start
2. Open Thea on macOS
3. Navigate to Settings → OpenClaw
4. Verify: connection state shows "Connected"
5. Verify: channels list populated
6. Send test message from any configured channel
7. Verify: message appears in Thea OpenClaw chat view
8. Verify: AI response sent back to channel
9. Test Canvas: verify A2UI renders correctly
```

### V2: Voice Synthesis Quality
- Launch Thea on macOS
- Test TTS via MLXAudioEngine (Soprano-80M)
- Test STT via GLM-ASR-Nano transcription accuracy
- Verify OpenClaw voice note → STT → AI → response pipeline

### V3: Screen Capture Accuracy
- Test screen capture feature on macOS
- Verify G1 Live Screen Monitoring detects foreground app correctly
- Test OpenClaw node screen capture if companion node is paired

### V4: Vision Analysis
- Test Qwen3-VL 8B visual analysis with a screenshot
- Verify response quality and latency

### V5: Cursor Handoff
- Test cursor handoff between macOS and iOS

### V6: MLX Model Loading on MSM3U
- Load Llama 3.3 70B via MLX
- Verify inference quality and response time
- Test via OpenClaw channel (WhatsApp/Telegram message → local LLM response)

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
├── Phase O: OpenClaw Deep Integration
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
| OpenClaw health check                | YES | checkAvailability() every 5 min |
| OpenClaw cron job management         | YES | createCronJob() in OpenClawIntegration |
| Coverage trend tracking              | YES | codecov upload in ci.yml |
| Maestro screenshot on failure        | YES | xcrun simctl screenshot in e2e-tests.yml |
| Voice synthesis quality test         | NO  | Manual — requires human ear |
| Screen capture accuracy test         | NO  | Manual — requires human eye |
| Vision analysis quality test         | NO  | Manual — requires human eye |
| MLX model loading test               | NO  | Manual — requires physical access |
| Final ship tag + pushsync            | NO  | Manual — Alexis decision |
| openclaw doctor config validation    | YES | O_PRE step — `openclaw doctor` |
| OpenClaw daemon startup              | YES | `openclaw onboard --install-daemon` |
| Agent Teams task delegation          | YES | AgentTeamOrchestrator (P16) |
| OpenClaw channel health check        | YES | `openclaw gateway status` in Phase S |
| SpeechAnalyzer API availability check| YES | `#available(macOS 26.0, *)` guard (P14) |
| Claude model catalog update          | YES | Automated via Phase P13 |

---

## OPENCLAW INTEGRATION GAPS — BEFORE vs AFTER

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
| Security audit                       | 22 patterns only     | + openclaw security audit |
| Settings UI                          | None                 | Full 9-section settings |
| OpenClaw test coverage               | 0%                   | 100% of all 5 files     |
| MoltbookAgent integration            | Basic routing        | Full reply-back wired   |
| Gateway config (openclaw.json)       | None                 | O_PRE: JSON5 config written |
| Daemon setup (launchd)               | None                 | O_PRE: `--install-daemon` |
| Doctor validation                    | None                 | O_PRE: `openclaw doctor` |
| dmScope per-peer isolation           | None                 | O_PRE config + O3 settings UI |
| Canvas URL integration               | None                 | O4: `/__openclaw__/canvas/` |
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
| N     | GitHub Workflows Overhaul (6 files)          | ⏳ PENDING  | —        | —         |
| O     | OpenClaw Deep Integration                    | ⏳ PENDING  | —        | —         |
| P     | Component Analysis + Individual Fixes        | ⏳ PENDING  | —        | —         |
| Q     | Test Coverage to 80%+                        | ⏳ PENDING  | —        | —         |
| R     | Periphery Full Resolution                    | ✅ PARTIAL  | afc0c7b  | 2026-02-18|
| S     | CI/CD Green Verification                     | ⏳ PENDING  | —        | —         |
| T     | Notarization Pipeline                        | ⏳ PENDING  | —        | —         |
| U     | Final Verification Report                    | ⏳ PENDING  | —        | —         |
| V     | Manual Ship Gate                             | ⏳ MANUAL   | Alexis   | —         |

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

### OpenClaw Gateway Protocol (2026)
```swift
// CORRECT — OpenClaw native protocol
let request = #"{"type":"req","id":"\#(uuid)","method":"channels.list","params":{}}"#

// WRONG — JSONRPC 2.0 (what v1 incorrectly used)
// let request = #"{"jsonrpc":"2.0","id":"\#(uuid)","method":"channels.list","params":{}}"#
```

### OpenClaw Handshake Sequence
```
1. Client connects WebSocket to ws://127.0.0.1:18789
2. Gateway sends: {type:"event", event:"auth.challenge", payload:{nonce:"...", ts:...}}
3. Client sends:  {type:"req", id:"...", method:"connect",
                   params:{minProtocol:1, maxProtocol:1,
                            meta:{name:"Thea", version:"1.0.0"},
                            role:"operator",
                            scopes:["operator.read","operator.write"],
                            deviceId:"thea-<uuid>",
                            token:"<OPENCLAW_GATEWAY_TOKEN>"}}
4. Gateway sends: {type:"res", id:"...", ok:true,
                   payload:{protocol:1, auth:{deviceToken:"<persistent-token>"}}}
5. Store deviceToken in Keychain for future reconnections
```

### OpenClaw Session Keys
```swift
// Session key format: "agent:{agentId}:{provider}:{scope}:{identifier}"
// Examples:
"agent:main:main"                          // Direct interaction
"agent:main:whatsapp:dm:+15555550123"      // WhatsApp DM
"agent:work:slack:channel:C12345678"       // Slack channel
"agent:health:telegram:group:-1234567890"  // Telegram group (health agent)
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

### OpenClaw Multi-Agent Routing (2026)
```swift
// Route channels to specialized agents:
// - main agent: general conversation
// - work agent: Slack, Teams, work Telegram
// - health agent: WHOOP data, HealthKit integrations
// - moltbook agent: developer insights (existing)
// Each agent has its own session isolation, model, tool policy
```

### Swift 6 Actor Isolation + OpenClaw (2026)
```swift
// OpenClawClient is an actor — all state changes are isolated
// OpenClawIntegration is @MainActor @Observable — UI state on main thread
// Bridge the two with:
actor OpenClawClient { ... }  // background I/O isolation

@MainActor @Observable
final class OpenClawIntegration {
    private let client = OpenClawClient()  // actor can be held by main-actor class

    func sendMessage(...) async throws {
        try await client.sendMessage(...)  // actor hop happens automatically
    }
}
```

---

### OpenClaw JSON5 Configuration (Thea, 2026)
```json5
// ~/.openclaw/openclaw.json — JSON5 format (comments + trailing commas OK)
{
  identity: { name: "Thea", emoji: "🌿", theme: "dark" },

  agent: {
    workspace: "~/.openclaw/workspace",
    model: {
      primary: "anthropic/claude-opus-4-6",      // Best injection resistance
      fallbacks: ["anthropic/claude-sonnet-4-6"],
    },
    heartbeat: true,  // Keep connection alive
  },

  // CRITICAL: Per-peer isolation prevents context leaks
  session: {
    dmScope: "per-channel-peer",
    scope: "per-sender",
    reset: { mode: "daily", hour: 4 },
  },

  tools: {
    allow: ["read", "web", "messaging"],
    deny: ["group:runtime", "sessions_spawn", "gateway"],
  },

  sandbox: { mode: "non-main", scope: "session", workspaceAccess: "ro" },
  gateway: { bind: "loopback", mDNS: { mode: "minimal" } },
  logging: { level: "info", redactSensitive: "tools" },
}
```

### OpenClaw Daemon Setup (macOS, 2026)
```bash
# Install as background daemon (survives reboots):
openclaw onboard --install-daemon

# Verify daemon is running:
openclaw gateway status

# Manual start/stop (if not using daemon):
openclaw gateway start
openclaw gateway stop

# Check gateway health endpoint:
curl http://127.0.0.1:18789/health

# Validate config before (re)starting:
openclaw doctor        # checks config, API keys, file permissions
openclaw doctor --fix  # auto-remediates where possible

# Update OpenClaw:
npm update -g openclaw
openclaw gateway restart
```

### OpenClaw Changelog 2026.2.18 — Key New APIs

```swift
// NEW FEATURES in OpenClaw 2026.2.18 — implement all in Phase O:

// 1. Slack streaming (new methods for Slack channel):
//    chat.startStream(channelID:) → streamID: String
//    chat.appendStream(streamID:token:)
//    chat.stopStream(streamID:)
// Implementation: OpenClawIntegration.streamMessage(to:via:) for Slack channel

// 2. 1M context window (Anthropic):
//    In openclaw.json: params.context1m: true
//    Context upgraded from 24K → 150K tokens for all sessions

// 3. Memory MMR re-ranking (replaces cosine similarity):
//    memory.search(query:topK:mmr:true) → diversified results with temporal decay
//    Old: memory.search(query:) with flat similarity

// 4. Discord Components v2 (interactive elements):
//    discord.sendComponent(buttons:selects:modals:) — new method
//    Enables interactive Thea responses in Discord (confirmations, forms, menus)

// 5. Subagent nesting:
//    agent.runSubagent(id:task:context:) → SubagentResult
//    Maps to TaskPlanDAG leaf node execution

// 6. Exec tool hardening:
//    In openclaw.json: tools.exec.safeBins: ["git","swift","xcodebuild","npm","python3"]
//    All other executables blocked by default in Phase O config

// 7. iOS companion app pairing:
//    gateway.getDeviceToken(deviceID:) for iOS app auth
//    Requires: gateway.enableMobileCompanion: true in config

// 8. BREAKING: Tool schema changes (no anyOf/oneOf/allOf):
//    Before: { "type": "string", "anyOf": [...] }
//    After:  { "type": "string", "enum": [...] }
//    Audit all Thea tool definitions sent to OpenClaw gateway
```

### Claude Opus 4.6 + Sonnet 4.6 — Model IDs (Feb 2026)
```swift
// Use these EXACT model IDs in AnthropicProvider + AIModel catalog:
"claude-opus-4-6"              // Best: planning, agents, computer use, injection resistance
"claude-sonnet-4-6"            // Balanced: near-flagship at lower cost, adaptive reasoning
"claude-haiku-4-5-20251001"    // Fast/cheap: iOS, low-latency responses

// OpenClaw config model IDs (include provider prefix):
"anthropic/claude-opus-4-6"
"anthropic/claude-sonnet-4-6"

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
// 5. Progress streamed to user via OpenClaw channel in real-time

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
- OpenClaw protocol upgrade is mandatory (wrong framing breaks all advanced features)
- Notarization must be automated (unsigned builds are NOT suitable for personal use on other Macs)
- SBOM + CodeQL added because security scanning is a core Thea value
- Canvas/A2UI support added because it unlocks agent-driven UI for all OpenClaw channels
- Multi-agent routing added to separate work/personal/health contexts
- dSYMs preserved for 1 year (needed for crash report symbolication)
- Periphery from v1 continues in Phase R — not done until ALL items addressed
- Phases N and O can run in parallel (no dependency between them)
- Phase Q (coverage) requires Phase O complete (OpenClaw tests are counted in coverage)

**2026-02-19 (v2 update #2)**: OpenClaw changelog 2026.2.18 + community risk research:

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
  → Phase O_PRE: Set SSRF protection level in openclaw.json config
- exec tool hardening: `tools.exec.safeBins` list (allowlisted executables only)
  → Phase O_PRE: Add safeBins allowlist in config
- Telegram token redaction: tokens now redacted in all gateway logs automatically
  → Phase O: Remove any custom Telegram token redaction (now handled by gateway)
- BREAKING: Model schema changed — no longer accepts anyOf/oneOf/allOf in tool schemas
  → Phase O: Audit all tool definitions, replace anyOf/oneOf/allOf with explicit types

COMMUNITY RISK WARNINGS (incorporate into OpenClaw setup):
1. COST RUNAWAY: Agent loops can easily spend $300-750/month. Mitigation:
   - Set `maxTokensPerHour` in openclaw.json
   - Enable `budgetAlert` with daily cost threshold
   - Monitor with: openclaw stats --period 24h
   - OpenClawBridge.maxResponsesPerMinute=5 already addresses this for Thea
2. MALICIOUS EXTENSION: "ClawdBot Agent" on VS Code marketplace is MALWARE (not official).
   - Install ONLY official: `npm install -g openclaw` from npmjs.com
   - Never install VS Code extensions claiming to be "OpenClaw" — no official extension exists
3. RELIABILITY: Gateway may silently report "success" for failed deliveries on some platforms.
   - Add delivery confirmation tracking in Phase O (use ACK events where available)
4. SETUP COMPLEXITY: First-time setup takes ~2 hours. Use `openclaw doctor` liberally.
   - `openclaw doctor --fix` auto-remediates most common config issues

PDF SECURITY KIT FINDINGS (Kit Sécurité OpenClaw, from ~/Downloads):
The PDF identified 5 critical risks that must be addressed in O_PRE config:
  Risk 1: Public gateway exposure → Fix: bind to loopback (127.0.0.1) only — NEVER 0.0.0.0
  Risk 2: Anyone can DM the bot → Fix: dmPolicy: "pairing" + dmScope: "per-channel-peer"
  Risk 3: Credentials in plain text → Fix: use keychain/environment vars; encrypt openclaw.json
  Risk 4: Prompt injection → Fix: OpenClawSecurityGuard already handles (22 patterns, NFD norm)
  Risk 5: Dangerous commands → Fix: tools.exec.safeBins allowlist + sandbox: "non-main" mode

**2026-02-19 (v2 update)**: OpenClaw + AI research incorporated:
- OpenClaw iOS app is in "internal preview" as of Feb 2026 — iOS node code should be ready but
  pairing cannot be fully tested until app is publicly available. Code must still be written.
- Canvas serves at `/__openclaw__/canvas/` (port 18793), A2UI at `/__openclaw__/a2ui/`
- dmScope: "per-channel-peer" is CRITICAL for any multi-sender scenario — enforce in O_PRE config
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
- [OpenClaw Gateway Protocol](https://docs.openclaw.ai/gateway/protocol)
- [OpenClaw Security Guide](https://docs.openclaw.ai/gateway/security)
- [OpenClaw Getting Started](https://docs.openclaw.ai/start/getting-started)
- [OpenClaw Configuration Reference](https://moltfounders.com/openclaw-configuration)
- [OpenClaw iOS App](https://docs.openclaw.ai/platforms/ios)
- [OpenClaw Architecture](https://deepwiki.com/openclaw/openclaw)
- [OpenClaw Features](https://openclaw.ai/)
- [OpenClaw npm package](https://www.npmjs.com/package/openclaw)
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
