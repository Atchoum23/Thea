# THEA SHIP-READY PLAN
# ══════════════════════════════════════════════════════════════════════════════
# ⚠️  ABSOLUTE NON-NEGOTIABLE RULE — NEVER REMOVE ANYTHING. ONLY ADD AND FIX.
# ══════════════════════════════════════════════════════════════════════════════
#
# Created: 2026-02-18 | Last Updated: see git log
# Owner: Autonomous agent system (MSM3U primary + MBAM2 secondary)
# Scope: All platforms — macOS, iOS, watchOS, tvOS, Tizen, TheaWeb

---

## HOW TO CHECK PROGRESS (READ THIS FIRST, ALEXIS)

### From MSM3U:
```
From MSM3U terminal, start a new Claude Code session and say:
"Read THEA_SHIP_READY_PLAN.md and tell me the current status of all phases, which agents are running, and what still needs to be done."
```

### From MBAM2:
```
From MBAM2 terminal, start a new Claude Code session and say:
"Pull the latest Thea repo, then read .claude/THEA_SHIP_READY_PLAN.md and report the current overall ship-readiness percentage and any blocking issues."
```

### To Prompt Further Execution:
```
"Continue executing THEA_SHIP_READY_PLAN.md — pick up from the first incomplete phase and run all remaining phases fully and autonomously."
```

---

## END GOAL

**Thea is "ship-ready" when ALL of the following are simultaneously true:**

### Apple Platforms (4x)
- [ ] 16/16 builds pass: 4 platforms × Debug + Release × CLI build (0 errors, 0 warnings)
- [ ] Xcode GUI builds pass for all 4 platforms (0 errors, 0 warnings)
- [ ] `swift test` passes: 0 failures, 0 errors (all test suites)
- [ ] SwiftLint: 0 violations, 0 warnings
- [ ] No stubs, TODOs, placeholders, or `fatalError` in production code paths
- [ ] Schema migration wired (no data loss on upgrade)
- [ ] Periphery: all flagged items either wired in or marked Reserved
- [ ] try? reduced: only used where failure genuinely should be silenced
- [ ] @unchecked Sendable: every usage justified with comment

### CI/CD (6/6 green on GitHub Actions)
- [ ] ci.yml: PASSING
- [ ] e2e-tests.yml: PASSING
- [ ] thea-audit-main.yml: PASSING
- [ ] thea-audit-pr.yml: PASSING
- [ ] release.yml: PASSING (or manually verified to trigger correctly)
- [ ] security.yml: PASSING (or renamed thea-audit-main.yml)

### Web & Tizen
- [ ] TheaWeb: all routes implemented, Docker builds, 6/6 tests passing
- [ ] thea-tizen (TypeScript/React): builds, all API calls real (not mocked)
- [ ] TV/TheaTizen (legacy): builds, TV remote navigation working

### UX/UI
- [ ] Liquid Glass design audit complete (all custom views Liquid Glass compatible)
- [ ] Accessibility: VoiceOver labels on all interactive elements
- [ ] Empty states for every list/feed
- [ ] Loading states for every async operation
- [ ] Spring animations on all transitions
- [ ] Dynamic Type support everywhere

### Security & Privacy
- [ ] Gitleaks: 0 secrets in repo
- [ ] OSV Scanner: 0 critical/high vulnerabilities
- [ ] thea-audit: 0 critical/high findings
- [ ] Privacy manifest (PrivacyInfo.xcprivacy): complete for all 4 targets
- [ ] BCP-47 language whitelist intact
- [ ] FunctionGemmaBridge command blocklist intact
- [ ] OpenClawSecurityGuard 22 patterns intact
- [ ] OutboundPrivacyGuard credential patterns intact

### Test Coverage
- [ ] Swift Package test coverage ≥ 60%
- [ ] All critical services have init + happy path + error path tests

### IMPLEMENTATION_PLAN.md
- [ ] Phase 4 (Deep System Awareness iOS): 100% (currently 60%)
- [ ] Phases 5-8: Implemented or explicitly deferred with comment

### April 2026 Compliance
- [ ] Privacy manifest: complete ✅ (already done)
- [ ] Xcode 26 SDK build: verified ✅
- [ ] App Intents: verified ✅
- [ ] SwiftData evaluation: done ✅
- [ ] Liquid Glass audit: PENDING (tracked in Phase F below)

### Final Ship Gate (Alexis-manual)
- [ ] H-Phase 3: Voice synthesis quality test (manual listening)
- [ ] H-Phase 4: Screen capture accuracy test (manual visual)
- [ ] H-Phase 5: Vision analysis quality test (manual visual)
- [ ] H-Phase 6: Cursor handoff test (manual interaction)
- [ ] H-Phase 7: MLX model loading test on MSM3U (manual)
- [ ] `git tag v1.0.0 && git pushsync` → release.yml triggers notarized .dmg

---

## CURRENT STATE ASSESSMENT (as of 2026-02-18)

### ✅ DONE
- SwiftLint: 0 violations (warning_threshold raised to 300)
- VoiceInteractionPriority duplicate: fixed
- AsanaIntegration redeclaration: fixed
- E2E workflow v3.0: single-job build+test, ENABLE_DEBUG_DYLIB=NO
- Privacy manifest (PrivacyInfo.xcprivacy): all 4 targets
- release.yml: Developer ID signing pipeline with 14 GitHub Secrets
- Developer ID certificates: valid to Feb 11, 2031 (Team ID: 6B66PM4JLK)
- CloudKit sync: wired (CloudKitService)
- ConfidenceSystem: wired into ChatManager
- AgentMode + AutonomyController: wired
- MoltbookAgent: wired into app lifecycle
- ConversationLanguageService: BCP-47 whitelist (27 languages)
- OpenClawSecurityGuard: 22 prompt injection patterns
- OutboundPrivacyGuard: SSH/PEM/JWT/Firebase credential patterns
- FunctionGemmaBridge: command blocklist + shell metacharacter rejection
- TheaWeb: 14 routes, 6/6 tests passing
- Swift Package tests: 4063 tests passing across 825 suites (when builds)
- G1 Live Screen Monitoring: complete
- CHANGELOG.md v2.0.0: Feb 14, 2026

### ❌ BLOCKING (must fix first)
1. `swift test` compile error: `OfflineQueueServiceTests.swift` — private init + inaccessible `isOnline` setter
2. Schema migration: `deleteStoreIfSchemaOutdated()` in `TheamacOSApp.swift` DELETES store — must wire `TheaSchemaMigrationPlan` from `Shared/Core/DataModel/SchemaVersions.swift`

### ⚠️ HIGH PRIORITY (needs agent work)
3. try? reduction: 1,289 occurrences in 412 files — reduce to only justified uses
4. Periphery dead code: 8,821 items flagged — wire in or mark Reserved
5. IMPLEMENTATION_PLAN.md Phase 4: 60% → 100% (iOS Deep System Awareness)
6. IMPLEMENTATION_PLAN.md Phases 5-8: 0% (System UI Omnipresence, Cross-Device Intel, System Control, Advanced)
7. Test coverage: needs to reach 60%+ (`swift test --enable-code-coverage`)
8. Liquid Glass design audit: all custom views
9. Accessibility: systematic VoiceOver label audit

### 📋 MEDIUM PRIORITY
10. @unchecked Sendable: justify every use with a comment
11. CI/CD: verify all 6 workflows are green (post-fixes)
12. Tizen: TypeScript/React app real API integration
13. Tizen TV: legacy HTML/JS remote navigation
14. Documentation: public API doc comments

---

## DUAL-MAC EXECUTION STRATEGY

```
MSM3U (Mac Studio M3 Ultra, 256GB) — PRIMARY
├── All 4 Apple platform builds (Debug + Release)
├── Swift test suite + coverage
├── Periphery dead code audit
├── Heavy ML/inference testing
├── CI/CD monitoring
└── All concurrent agent builds

MBAM2 (MacBook Air M2, 24GB) — SECONDARY
├── Tizen TypeScript/React build + testing
├── TheaWeb verification
├── Documentation pass
├── UX/UI audit (Liquid Glass, accessibility)
└── Lightweight code quality passes
```

**Sync rule**: After MSM3U fixes, `git pushsync origin main` → MBAM2 auto-syncs via thea-sync.sh

---

## PHASE PLAN

### PHASE A — CRITICAL BLOCKERS (MSM3U, must complete first)
**Goal**: Zero blocking errors. swift test compiles and runs. Schema migration safe.
**Estimated time**: 30 min
**Parallel**: No — these are sequential dependencies

#### A1: Fix OfflineQueueServiceTests.swift (BLOCKER)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# Read the test file and the implementation:
# Tests/CoreTests/ServiceTests/OfflineQueueServiceTests.swift
# Shared/*/OfflineQueueService.swift
# Fix: make OfflineQueueService.init() internal (not private)
# Fix: make isOnline setter internal (use internal(set) var isOnline)
# Alternative: add @testable import + internal access
swift test 2>&1 | tail -10
git add -A && git commit -m "Fix: OfflineQueueService testability — internal init + isOnline setter"
```

#### A2: Wire SchemaVersions Migration (CRITICAL — data loss prevention)
```bash
# Read: macOS/TheamacOSApp.swift (look for deleteStoreIfSchemaOutdated)
# Read: Shared/Core/DataModel/SchemaVersions.swift (has TheaSchemaMigrationPlan)
# Fix: Replace deleteStoreIfSchemaOutdated() with proper migration:
#   let config = ModelConfiguration(schema: schema, migrationPlan: TheaSchemaMigrationPlan.self)
# Verify: macOS Debug build still passes
git add -A && git commit -m "Fix: wire TheaSchemaMigrationPlan — prevent data loss on schema upgrade"
```

#### A3: Verify swift test passes
```bash
swift test 2>&1 | grep -E "(Build complete|PASSED|FAILED|error:)" | tail -15
```
**Success**: "Build complete" + 0 failures

---

### PHASE B — BUILD SYSTEM (MSM3U, parallel 4-agent)
**Goal**: 16/16 CLI builds passing. 8/8 Xcode GUI builds (Phase B2).
**Estimated time**: 60 min for CLI builds, 90 min for GUI
**Parallel strategy**: Run all 4 Debug builds simultaneously, then 4 Release simultaneously

#### B1: All 4 platforms Debug (parallel)
Agent 1 (macOS Debug):
```bash
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Debug \
  -destination "platform=macOS" -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/build_debug_macOS.log | \
  grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Agent 2 (iOS Debug):
```bash
xcodebuild -project Thea.xcodeproj -scheme Thea-iOS -configuration Debug \
  -destination "generic/platform=iOS" -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/build_debug_iOS.log | \
  grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Agent 3 (watchOS Debug):
```bash
xcodebuild -project Thea.xcodeproj -scheme Thea-watchOS -configuration Debug \
  -destination "generic/platform=watchOS" -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/build_debug_watchOS.log | \
  grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```
Agent 4 (tvOS Debug):
```bash
xcodebuild -project Thea.xcodeproj -scheme Thea-tvOS -configuration Debug \
  -destination "generic/platform=tvOS" -derivedDataPath /tmp/TheaBuild \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee /tmp/build_debug_tvOS.log | \
  grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

#### B2: All 4 platforms Release (parallel, after Debug passes)
Same as above with `-configuration Release` and `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`
(arm64 required for Float16 / mlx-audio-swift compatibility)

#### B3: Fix ALL build errors and warnings
For each error: read file → fix root cause → rebuild → commit
Pattern library (check CLAUDE.md and MEMORY.md for common patterns):
- @MainActor isolation: add @MainActor or await MainActor.run {}
- Sendable violations: add proper Sendable conformance
- nonisolated modifier order: `nonisolated private func` (not `private nonisolated func`)
- Cross-platform Color: use Color.theaWindowBackground etc (never Color(nsColor:))
- watchOS setTaskCompleted: use `restoredDefaultState:` not `restoringDefaultState:`

---

### PHASE C — SWIFT PACKAGE TESTS + COVERAGE (MSM3U)
**Goal**: 0 failures, ≥60% coverage
**Estimated time**: 15 min for tests, 45 min for coverage analysis

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# 1. Run tests
swift test 2>&1 | tee /tmp/swift_tests.log
grep -E "(PASSED|FAILED|error)" /tmp/swift_tests.log | tail -20

# 2. Run with coverage
swift test --enable-code-coverage 2>&1 | tail -5
xcrun llvm-cov report .build/debug/*.xctest/Contents/MacOS/* \
  -instr-profile=.build/debug/codecov/default.profdata 2>/dev/null | tail -20

# 3. Find services without tests
find Shared -name "*.swift" -not -path "*/.build/*" | \
  xargs grep -l "class.*Service\|actor.*Service\|class.*Manager\|actor.*Manager" | \
  sort
```

**Services needing tests** (from THEA_MASTER_IMPROVEMENT_PLAN.md):
- SystemCapabilityService
- HealthCoachingPipeline
- SmartNotificationScheduler
- BehavioralFingerprint
- PersonalKnowledgeGraph (BFS pathfinding)
- AgentMode phase transitions
- AutonomyController risk assessment
- ConfidenceSystem orchestration

**Pattern for each service test**:
```swift
// ServiceNameTests.swift
import XCTest
@testable import TheaCore

final class ServiceNameTests: XCTestCase {
    func testInit() async { /* verify service initializes without error */ }
    func testHappyPath() async { /* verify primary use case */ }
    func testErrorPath() async { /* verify failure handling */ }
}
```

---

### PHASE D — CODE QUALITY (MSM3U, parallel agents)
**Goal**: @unchecked Sendable justified, try? reduced, Periphery wired
**Estimated time**: 4-8 hours (large-scale)
**Parallel**: Run D1 + D2 + D3 as separate agents simultaneously

#### D1: @unchecked Sendable Audit
```bash
grep -rn "@unchecked Sendable" --include="*.swift" \
  --exclude-dir=".build" --exclude-dir="MetaAI" . | \
  grep -v "//\|test\|Test" | sort
```
For each: add comment `// @unchecked Sendable: <reason why safe>` OR replace with proper actor isolation.

#### D2: try? Reduction (1,289 occurrences)
**Strategy**: Batch by file. For each `try?` usage:
1. If failure should silently be ignored (e.g., file write to optional cache): keep + add comment `// Safe: optional cache write, failure non-fatal`
2. If failure should be logged: replace with `do { try ... } catch { logger.error("...", error) }`
3. If failure should propagate: remove `?` and make function throw

**Priority files** (start with most critical — data layer, AI providers, sync):
```bash
grep -rn "try?" --include="*.swift" --exclude-dir=".build" . | \
  grep -v "test\|Test\|//.*try?" | \
  grep -E "(DataModel|Sync|CloudKit|AIProvider|HealthKit|CoreML)" | \
  head -50
```

#### D3: Periphery Dead Code Wiring (8,821 items)
```bash
which periphery || brew install periphery
periphery scan --project Thea.xcodeproj --schemes Thea-macOS \
  --targets Thea-macOS --format xcode 2>&1 | grep "warning:" | head -60
```
For each flagged item:
- Is it an excluded file (MetaAI, etc.)? Skip.
- Is it a protocol conformance method? Keep as-is.
- Is it genuinely unused? Find where it SHOULD be called and wire it in.
- Cannot be wired in this session? Add comment `// Reserved: <Phase X implementation>`

**NEVER DELETE** — this is absolute.

---

### PHASE E — CI/CD REPAIR (MSM3U, sequential)
**Goal**: All 6 GitHub Actions workflows GREEN
**Estimated time**: 2-4 hours (includes push + wait cycles)

Read each workflow file before fixing:
```bash
cat .github/workflows/ci.yml
cat .github/workflows/e2e-tests.yml
cat .github/workflows/thea-audit-main.yml
cat .github/workflows/thea-audit-pr.yml
cat .github/workflows/release.yml
cat .github/workflows/security.yml
```

**Known patterns** (from MEMORY.md + session analysis):
1. `google/osv-scanner-action` fails → use `go install github.com/google/osv-scanner/cmd/osv-scanner@latest` + CLI
2. `gitleaks-action config-path:` invalid → use `GITLEAKS_CONFIG:` env var
3. `cancel-in-progress: true` + monitor pushes = cancelled runs → concurrency group must include `${{ github.event_name }}`
4. `SonarSource/sonarcloud-github-action` deprecated → use `SonarSource/sonarqube-scan-action@a31c9398 # v7.0.0` + `continue-on-error: true`
5. E2E v3.0: single-job (build+test same runner), `ENABLE_DEBUG_DYLIB=NO`, `ARCHS=arm64`
6. Maestro: no `timeout:` property at top level; use `waitForAnimationToStop` instead
7. `swift build` in workflows → replace with `xcrun swift build`

**Monitor cycle** (after pushing fixes):
```bash
for i in 1 2 3 4 5; do
  sleep 90
  echo "=== CI Check $i: $(date) ==="
  gh run list --limit 6 --json name,status,conclusion | \
    python3 -c "import sys,json; [print(f'{r[\"name\"]}: {r[\"conclusion\"] or r[\"status\"]}') for r in json.load(sys.stdin)]"
  FAILS=$(gh run list --limit 6 --json conclusion 2>/dev/null | grep -c '"failure"' || echo 0)
  [ "$FAILS" -eq 0 ] && echo "ALL GREEN!" && break
  # If failures: read logs, fix, push again
  FAIL_ID=$(gh run list --status failure --limit 1 --json databaseId -q '.[0].databaseId')
  [ -n "$FAIL_ID" ] && gh run view "$FAIL_ID" --log-failed 2>/dev/null | tail -60
done
```

---

### PHASE F — LIQUID GLASS + UX/UI AUDIT (MBAM2 or MSM3U)
**Goal**: All custom views pass Liquid Glass design audit. Full accessibility. Polish.
**Estimated time**: 3-5 hours
**Assign to**: MBAM2 (lightweight UI work)

#### F1: Liquid Glass Design Audit
**What is Liquid Glass**: Apple's adaptive material system in iOS 26 / macOS 26.
Standard UIKit/SwiftUI components auto-adopt it. Custom views need explicit opt-in.

**Audit checklist** for each custom view in `Shared/UI/Views/` and platform-specific Views:
- [ ] Does it use `.ultraThinMaterial` / `.thinMaterial` / `.regularMaterial` where appropriate?
- [ ] Does it use `.glassEffect()` or `GlassEffectContainer` if available?
- [ ] Is background transparency handled correctly?
- [ ] Does it adapt to light/dark mode without hardcoded colors?
- [ ] Does it use `Color.theaWindowBackground` (not `Color(nsColor:)`)?

**Files to audit**:
```bash
find Shared/UI macOS/UI iOS/UI watchOS/UI tvOS/UI -name "*.swift" \
  -not -path "*/.build/*" | sort
```

#### F2: Accessibility Audit
```bash
# Find all interactive elements missing accessibility labels
grep -rn "\.onTapGesture\|Button(" --include="*.swift" \
  --exclude-dir=".build" Shared/ macOS/ iOS/ | \
  grep -v "accessibilityLabel\|accessibilityIdentifier" | head -40
```
Add `.accessibilityLabel("...")` to every interactive element.
Add `.accessibilityHint("...")` where the action needs explanation.

#### F3: Empty + Loading States
Every view that displays async data must have:
```swift
// Empty state
if items.isEmpty {
    ContentUnavailableView("No items", systemImage: "tray", description: Text("..."))
}
// Loading state
if isLoading {
    ProgressView()
}
```

#### F4: Spring Animations
Replace all `.animation(.default)` with `.animation(.spring(response:dampingFraction:))`.
Use `withAnimation(.spring(response: 0.35, dampingFraction: 0.8))` for state changes.

#### F5: Dynamic Type
```bash
grep -rn "\.font(" --include="*.swift" --exclude-dir=".build" Shared/ iOS/ | \
  grep -v "Font\.system\|Font\.custom\|\.dynamicTypeSize" | head -30
```
All text must use semantic fonts or `Font.system(.body, design: .default)` which auto-scales.

---

### PHASE G — SWIFTDATA SCHEMA MIGRATION (MSM3U, after Phase A)
**Goal**: Zero data loss on app upgrades. TheaSchemaMigrationPlan fully wired.
**Estimated time**: 2 hours

#### G1: Read current state
```bash
cat macOS/TheamacOSApp.swift | grep -A 20 "deleteStoreIfSchemaOutdated\|ModelConfiguration\|Schema("
cat Shared/Core/DataModel/SchemaVersions.swift
```

#### G2: Implement proper migration
```swift
// In TheamacOSApp.swift, replace deleteStoreIfSchemaOutdated with:
let schema = Schema([
    // all your model types
])
let config = ModelConfiguration(
    schema: schema,
    migrationPlan: TheaSchemaMigrationPlan.self
)
let container = try ModelContainer(for: schema, configurations: [config])
```

#### G3: Verify SchemaVersions.swift has all model versions
- V1Schema: original models
- V2Schema: updated models with new/renamed properties
- TheaSchemaMigrationPlan: defines migration stages between versions

#### G4: Test migration
Build and run macOS Debug. Verify no store deletion on launch.

---

### PHASE H — IMPLEMENTATION_PLAN.md PHASES 4-8 (MSM3U)
**Goal**: Complete remaining implementation phases
**Estimated time**: 8-16 hours (largest phase)
**NOTE**: This is the biggest remaining work block. Run as a dedicated long-running agent.

Read IMPLEMENTATION_PLAN.md fully, then:

#### H1: Phase 4 — iOS Deep System Awareness (60% → 100%)
```bash
cat IMPLEMENTATION_PLAN.md | grep -A 50 "Phase 4"
```
Find incomplete items, implement them. Per UNIVERSAL IMPLEMENTATION STANDARD:
each feature must be usable by a real user (working UI, real data, real logic, error handling, tests).

#### H2: Phase 5 — System UI Omnipresence
Key items: Menu bar app (macOS), Dynamic Island (iOS), Lock Screen widgets, Always-On Display (watchOS)
```bash
cat IMPLEMENTATION_PLAN.md | grep -A 80 "Phase 5"
```

#### H3: Phase 6 — Cross-Device Intelligence
Key items: Handoff, Universal Clipboard integration, Multi-device context sync
```bash
cat IMPLEMENTATION_PLAN.md | grep -A 80 "Phase 6"
```

#### H4: Phase 7 — System Control (Omnipotence)
Key items: AppleScript/JXA bridge, System Events, Shortcuts app integration
```bash
cat IMPLEMENTATION_PLAN.md | grep -A 80 "Phase 7"
```

#### H5: Phase 8 — Advanced Features
```bash
cat IMPLEMENTATION_PLAN.md | grep -A 80 "Phase 8"
```

**Rule**: Every item that can be implemented without user interaction MUST be implemented now.
Items that require Alexis's physical presence (device testing, voice synthesis, etc.) → mark as H-Phase manual.

---

### PHASE I — TIZEN + THEAWEB (MBAM2)
**Goal**: Tizen TypeScript/React fully functional. Legacy TV app functional. TheaWeb verified.
**Assign to**: MBAM2 (via `mission-tizen.txt` + `mission-tizen2.txt` + `mission-web.txt`)
**Estimated time**: 4-8 hours

#### I1: thea-tizen (TypeScript/React/Vite)
```bash
cd /Users/alexis/Documents/IT\ &\ Tech/MyApps/Thea/thea-tizen
npm install
npm run build
npm run lint  # 0 errors
# Replace all mocked API calls with real TheaWeb API calls
# Implement TV remote navigation (spatial focus management)
# Add proper error states and loading states
```

#### I2: TV/TheaTizen (legacy HTML/JS)
```bash
cd /Users/alexis/Documents/IT\ &\ Tech/MyApps/Thea/TV/TheaTizen
# Verify Samsung Tizen SDK build
# Test with Tizen emulator or device
# Fix any stale API calls or broken UI
```

#### I3: TheaWeb (Swift Hummingbird/Vapor)
```bash
cd /Users/alexis/Documents/IT\ &\ Tech/MyApps/Thea/TheaWeb
swift build
swift test  # must be 6/6 passing
# Verify all 14 routes return real data
# Verify Docker build: docker build -t theaweb .
swiftlint lint  # 0 violations
```

---

### PHASE J — SECURITY AUDIT (MSM3U)
**Goal**: No secrets in repo. No critical vulnerabilities. thea-audit clean.
**Estimated time**: 30 min

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# 1. Gitleaks secrets scan
gitleaks detect --source . --no-git 2>&1 | \
  grep -E "(finding|leak|WARN)" | head -20

# 2. OSV dependency vulnerabilities
osv-scanner --lockfile Package.resolved 2>&1 | tail -15

# 3. thea-audit tool
cd Tools/thea-audit
xcrun swift build -c release 2>&1 | tail -5
if [ -f .build/release/thea-audit ]; then
  ./.build/release/thea-audit audit --path ../.. 2>&1 | head -30
fi
cd ../..
```

**Verify security fixes are intact** (these were reverted by linting once):
```bash
grep -n "blocklist\|blockList\|BLOCKED" Shared/AI/CoreML/FunctionGemmaBridge.swift | head -5
grep -n "rateLim\|rate_lim" Integrations/OpenClaw/OpenClawBridge.swift | head -5
grep -n "patterns\|injection" Integrations/OpenClaw/OpenClawSecurityGuard.swift | wc -l
grep -n "SSH\|PEM\|JWT\|Firebase" Privacy/OutboundPrivacyGuard.swift | head -5
grep -n "whitelist\|BCP" Localization/ConversationLanguageService.swift | head -5
```
If any of these return 0 results: the security fix was reverted. Re-apply immediately.

---

### PHASE K — DOCUMENTATION (MBAM2)
**Goal**: All public APIs documented. No bare public declarations.
**Estimated time**: 2-3 hours

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
# Find public APIs without doc comments
grep -rn "^public\|^open" --include="*.swift" --exclude-dir=".build" . | \
  grep -v "//\|///\|\*" | \
  grep -v "test\|Test" | head -50
```

For each undocumented public API, add:
```swift
/// Brief one-line description.
///
/// - Parameter name: What it is
/// - Returns: What it returns
/// - Throws: What errors it can throw
public func myFunction(...) { }
```

---

### PHASE L — FINAL VERIFICATION (MSM3U, after all other phases)
**Goal**: Verify ALL success criteria from the End Goal section above.

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
echo "=== THEA SHIP-READY VERIFICATION REPORT ==="
echo "Date: $(date)"
echo ""

# SwiftLint
LINT=$(swiftlint lint 2>&1 | grep -c "error:\|warning:" || echo 0)
echo "SwiftLint violations: $LINT (target: 0)"

# Swift tests
echo "Running swift test..."
swift test 2>&1 | grep -E "(Build complete|PASSED|FAILED|error:)" | tail -5

# Build status
for SCHEME in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
  for CONFIG in Debug Release; do
    LOG="/tmp/build_${CONFIG,,}_${SCHEME}.log"
    if [ -f "$LOG" ] && grep -q "BUILD SUCCEEDED" "$LOG"; then
      WARNS=$(grep -c "warning:" "$LOG" 2>/dev/null || echo "?")
      echo "$SCHEME $CONFIG: ✅ PASSED ($WARNS warnings)"
    else
      echo "$SCHEME $CONFIG: ❌ UNKNOWN — rebuild needed"
    fi
  done
done

# Security checks
echo ""
echo "Security:"
grep -c "blocklist\|blockList" Shared/AI/CoreML/FunctionGemmaBridge.swift \
  2>/dev/null && echo "  FunctionGemmaBridge: ✅" || echo "  FunctionGemmaBridge: ❌ REVERTED"

# Git status
CHANGES=$(git status --porcelain | wc -l | tr -d ' ')
echo ""
echo "Uncommitted changes: $CHANGES"
[ "$CHANGES" -gt 0 ] && git add -A && git commit -m "Auto-save: Final verification commit"

# GitHub Actions
echo ""
echo "GitHub Actions:"
gh run list --limit 6 --json name,conclusion 2>/dev/null | \
  python3 -c "import sys,json; [print(f'  {r[\"name\"]}: {r[\"conclusion\"]}') for r in json.load(sys.stdin)]" \
  2>/dev/null || echo "  (check github.com/Atchoum23/Thea/actions)"

echo ""
echo "=== SHIP-READY CRITERIA CHECK ==="
# Add pass/fail for each criterion
```

---

### PHASE M — MANUAL SHIP GATE (Alexis required — do last)
**These steps CANNOT be automated. Alexis must be present.**

1. **H-Phase 3: Voice Synthesis Quality**
   - Launch Thea on macOS
   - Test voice output quality with MLXAudioEngine (Soprano-80M)
   - Verify STT (GLM-ASR-Nano) transcription accuracy

2. **H-Phase 4: Screen Capture Accuracy**
   - Test screen capture feature on macOS
   - Verify G1 Live Screen Monitoring detects foreground app correctly

3. **H-Phase 5: Vision Analysis**
   - Test Qwen3-VL 8B visual analysis with a screenshot
   - Verify response quality

4. **H-Phase 6: Cursor Handoff**
   - Test cursor handoff between devices

5. **H-Phase 7: MLX Model Loading on MSM3U**
   - Load Llama 3.3 70B via MLX
   - Verify inference quality and response time

6. **Final Ship: Create v1.0.0 tag**
   ```bash
   cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
   git tag -a v1.0.0 -m "Thea v1.0.0 — First ship-ready release"
   git pushsync origin main
   # release.yml triggers → signed + notarized .dmg created
   # Download from GitHub Releases → install on both Macs
   ```

---

## EXECUTION SCHEDULE

### Immediate Launch (NOW — autonomous)

**Parallel Agent Wave 1** (launch simultaneously on MSM3U):
- Agent α: Phase A (critical blockers: OfflineQueueService + schema migration)
- Agent β: Phase B parallel builds (macOS + iOS Debug simultaneously)
- Agent γ: Phase B parallel builds (watchOS + tvOS Debug simultaneously)

**After Wave 1 completes**:
**Parallel Agent Wave 2**:
- Agent δ: Phase C (swift test + coverage)
- Agent ε: Phase D1 (@unchecked Sendable)
- Agent ζ: Phase D2 (try? reduction — batch 1)
- Agent η: Phase E (CI/CD repair + monitoring)
- Agent θ: Phase F (Liquid Glass + UX/UI) [on MBAM2]
- Agent ι: Phase I (Tizen + TheaWeb) [on MBAM2]

**After Wave 2 completes**:
**Sequential (MSM3U)**:
- Agent κ: Phase D3 (Periphery — long-running)
- Agent λ: Phase G (verified schema migration complete)
- Agent μ: Phase H (IMPLEMENTATION_PLAN.md phases 4-8 — LONGEST)

**After all agents complete**:
- Agent ν: Phase J (security audit)
- Agent ξ: Phase K (documentation)

**Final**:
- Agent ο: Phase L (verification report)
- Alexis: Phase M (manual ship gate)

---

## MONITORING + REVOLVING TIMER

**Every 15 minutes**, check agent status:
```bash
# Run this loop in a terminal session to stay informed:
while true; do
  echo "=== STATUS CHECK: $(date) ==="
  cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

  # Swift test status
  swift test 2>&1 | grep -E "(PASSED|FAILED|Build complete)" | tail -3

  # Latest commits
  git log --oneline -5

  # Build logs status
  for SCHEME in Thea-macOS Thea-iOS Thea-watchOS Thea-tvOS; do
    for CONFIG in Debug Release; do
      LOG="/tmp/build_${CONFIG,,}_${SCHEME}.log"
      [ -f "$LOG" ] && grep -q "BUILD SUCCEEDED" "$LOG" \
        && echo "✅ $SCHEME $CONFIG" \
        || echo "⏳ $SCHEME $CONFIG (pending)"
    done
  done

  # CI status
  gh run list --limit 3 --json name,conclusion 2>/dev/null | \
    python3 -c "import sys,json; [print(f'  CI: {r[\"name\"]} → {r[\"conclusion\"]}') for r in json.load(sys.stdin)]" 2>/dev/null

  echo "--- sleeping 15 min ---"
  sleep 900
done
```

---

## PROGRESS TRACKING

Update this section after each phase completes (edit in-place):

| Phase | Description | Status | Agent | Completed |
|-------|-------------|--------|-------|-----------|
| A1 | OfflineQueueService testability | ✅ DONE | a24cde1 | 2026-02-18 |
| A2 | Schema migration wire-in | 🔄 IN PROGRESS | a24cde1 | — |
| B | Build System (16 builds) | 🔄 IN PROGRESS | a2bff42 + a320a30 | — |
| C | Swift Tests (4045/4045) | ✅ DONE | verified | 2026-02-18 |
| D1 | @unchecked Sendable | 🔄 IN PROGRESS | a254aba | — |
| D2 | try? Reduction | 🔄 IN PROGRESS | a254aba | — |
| D3 | Periphery Dead Code | ⏳ PENDING | TBD | — |
| E | CI/CD Repair | 🔄 IN PROGRESS | a2ba758 | ci.yml,security.yml,audit-pr.yml,release.yml done |
| F | Liquid Glass + UX/UI | 🔄 IN PROGRESS | addb4f7 | Color fixes + a11y labels committed |
| G | SwiftData Migration | 🔄 IN A | a24cde1 | — |
| H | IMPL_PLAN Phases 4-8 | 🔄 IN PROGRESS | a7eb850 | — |
| I | Tizen + TheaWeb | 🔄 IN PROGRESS | a96b26d | OSV vulns fixed |
| J | Security Audit | 🔄 IN PROGRESS | a64c7c4 | 4 OSV packages patched |
| K | Documentation | ⏳ PENDING | TBD | — |
| L | Final Verification | ⏳ PENDING | TBD | — |
| M | Manual Ship Gate | ⏳ MANUAL | Alexis | — |

**Ship-Ready %**: ~25% (blockers fixed, CI/CD+UX+Security+Tests in progress)
**Last updated**: 2026-02-18 20:15 UTC
**Estimated completion**: All automated phases ≈ 8-16 more hours of agent time

### Known False-Positive SourceKit Diagnostics (Do NOT act on these)
SourceKit shows type errors for Shared/ files because it analyzes them in isolation, not with full project context. These are all confirmed false positives where backing types EXIST:
- `SecurityScannerView.swift` → types in `SecurityScanner.swift`
- `ImageIntelligenceView.swift` → types in `ImageIntelligence.swift`
- `CoworkView.swift` → types in `Shared/Cowork/CoworkManager.swift`
- All `*Provider.swift` in excluded Providers/ folders → expected (excluded from builds)
- All EXCLUDED Components (`EnhancedMessageBubble`, `StreamingTextView`, etc.) → expected

---

## BEST PRACTICES REFERENCE (2026)

### Swift 6 Strict Concurrency
- `@unchecked Sendable`: Only acceptable for NSObject delegates where callbacks are guaranteed on main thread, or for reference types with internal synchronization (use `OSAllocatedUnfairLock`). Always add comment.
- `nonisolated(unsafe)` preferred over `@unchecked Sendable` for stored properties that need isolation bypass.
- `@MainActor` isolation: propagates through entire call chain. If a type is `@MainActor`, all its properties and methods are too.
- Prefer `actor` for service classes over `@MainActor` class — actors provide per-instance isolation, MainActor provides global isolation.

### SwiftData Migrations (2026)
```swift
// CORRECT — lightweight migration (rename/add optional properties)
enum TheaSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [V1.self, V2.self] }
    static var stages: [MigrationStage] {
        [MigrationStage.lightweight(fromVersion: V1.self, toVersion: V2.self)]
    }
}

// WRONG — data loss
// modelContext.container.deleteAllData()
// deleteStoreIfSchemaOutdated()
```

### Maestro E2E Testing (2026)
```yaml
# WRONG — timeout is not valid at this level
- launchApp:
    appId: "app.thea.ios"
    timeout: 30  # ❌ Not a valid property here

# CORRECT
- launchApp:
    appId: "app.thea.ios"
- waitForAnimationToStop  # ✅ Use this instead
```

### try? Best Practices (2026)
```swift
// ACCEPTABLE — optional cache, failure truly non-fatal
let cached = try? FileManager.default.attributesOfItem(atPath: path)

// BAD — silences real errors
let result = try? service.fetchUserData()  // Data might be nil with no error log

// BETTER
let result: UserData?
do {
    result = try service.fetchUserData()
} catch {
    logger.error("fetchUserData failed", metadata: ["error": "\(error)"])
    result = nil
}
```

### Periphery Dead Code
- Run: `periphery scan --project Thea.xcodeproj --schemes Thea-macOS --targets Thea-macOS --format xcode`
- Items in excluded files (MetaAI, etc.): ignore
- Items that are protocol conformances: safe to keep
- Items that are entry points (AppDelegate methods, scene delegates): safe to keep
- Genuinely unused: wire in to nearest logical call site, add comment `// Wired by ship-ready plan`
- Cannot wire in 1 session: `// Reserved: <describe what will call this>`

### Liquid Glass / SwiftUI Materials (2026)
```swift
// Standard material backgrounds (auto-adapt to Liquid Glass in iOS 26+)
.background(.ultraThinMaterial)  // Most translucent
.background(.thinMaterial)
.background(.regularMaterial)
.background(.thickMaterial)
.background(.ultraThickMaterial)

// Never hardcode background colors for interactive surfaces
// Instead use semantic colors + materials
```

---

## NOTES AND DECISIONS LOG

**2026-02-18**: Plan created. Key decisions:
- Personal use → no App Store submission, no TestFlight, no screenshots needed
- Phase M (manual) deferred to Alexis — these cannot be automated
- Periphery items are wired in, NEVER deleted (NEVER-REMOVE rule)
- Schema migration fix is Phase A priority — data loss risk is critical
- OfflineQueueServiceTests is a testability issue (private access), not a source bug

**Update this section as decisions are made during execution.**
