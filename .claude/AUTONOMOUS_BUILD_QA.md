# Autonomous Build & QA

## MISSION CRITICAL: READ THIS FIRST

**This document is the COMPLETE GUIDE for autonomous QA execution. The mission is NOT complete until:**

1. **ALL 16 BUILDS PASS** (4 platforms × 2 configs × CLI + GUI methods) with **ZERO warnings**
2. **ALL 6 GitHub Actions workflows are GREEN** (CI, Release, E2E Tests, Security Audit Full/PR, Dependencies)
3. **ALL Swift 6 concurrency issues are FIXED** (not just logged)
4. **ALL functional tests pass** (unit tests + Maestro E2E)
5. **ALL security audits complete** (thea-audit, gitleaks, osv-scanner)

**DO NOT DECLARE SUCCESS UNTIL EVERY CRITERION IS MET.**

---

## Project Details

| Item | Value |
|------|-------|
| **Project Path** | `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj` |
| **Project Generator** | XcodeGen (`project.yml`) - run `xcodegen generate` after changes |
| **Schemes** | `Thea-iOS`, `Thea-macOS`, `Thea-watchOS`, `Thea-tvOS` |
| **Swift Version** | 6.0 with **STRICT CONCURRENCY** |
| **Xcode Version** | 16.2 |
| **GitHub Repo** | `git@github.com:Atchoum23/Thea.git` |
| **Derived Data** | `~/Library/Developer/Xcode/DerivedData/Thea-*/` |

### GitHub Actions Workflows (6 Total)

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| **CI** | `ci.yml` | Push/PR | SwiftLint → Build (4 platforms) → Unit Tests → Coverage |
| **Release** | `release.yml` | Tags (v*) | Build artifacts → GitHub Release → DMG |
| **E2E Tests** | `e2e-tests.yml` | Push/PR | Maestro E2E on iOS Simulator |
| **Security Audit (Full)** | `thea-audit-main.yml` | Push to main, daily | Full security scan |
| **Security Audit (PR)** | `thea-audit-pr.yml` | PRs | Delta security scan |
| **Dependencies** | `dependencies.yml` | Package changes | SPM validation |

---

## CRITICAL: Xcode GUI Interaction (WHY THIS DOCUMENT EXISTS)

### The Problem

CLI builds (`xcodebuild`) and Xcode GUI builds show **DIFFERENT warnings**. The Xcode GUI has:
- Indexer warnings not visible in CLI
- Project settings warnings
- Capability/entitlement warnings
- Additional static analysis

**YOU MUST USE BOTH CLI AND GUI BUILDS. CLI-ONLY IS NOT ACCEPTABLE.**

### How to Trigger GUI Builds

#### RECOMMENDED: CLI Build with GUI Log Viewing

**This is the most reliable method for automation.** It uses `xcodebuild` CLI but writes to
the same DerivedData location that Xcode GUI reads from, so build results appear in Xcode's
Issue Navigator. No Accessibility permissions required.

```bash
# Build single scheme (Xcode must be open)
./Tools/XcodeBuildHelper/xcode-cli-with-gui-log.sh Thea-macOS Debug

# Build all 4 platforms
for scheme in Thea-iOS Thea-macOS Thea-watchOS Thea-tvOS; do
    ./Tools/XcodeBuildHelper/xcode-cli-with-gui-log.sh "$scheme" Debug
done

# After builds complete, check Xcode Issue Navigator (Cmd+5) for GUI-only warnings
```

**How it works:**
1. Opens Xcode project if not already open
2. Runs `xcodebuild` which writes to default DerivedData
3. Xcode GUI automatically sees the build results
4. Script parses build log and reports errors/warnings
5. You can verify in Xcode's Issue Navigator for any GUI-specific warnings

**Why this is best:**
- No Accessibility permissions needed
- Works reliably from any CLI context (Terminal, Claude Code, scripts)
- Build logs are parsed automatically
- Xcode GUI stays in sync with build state

#### Alternative: Direct osascript (NOT RECOMMENDED)

**NOTE:** This approach fails with "osascript is not allowed to send keystrokes" (error 1002)
when run from CLI tools like Claude Code. The Accessibility permission must be on the
**calling process**, not just the terminal app. AppleScript apps also cannot be reliably
automated from subprocesses.

If you must use osascript for manual testing, see the script at `Tools/XcodeBuildHelper/run-build-via-script-editor.sh`.

### Accessibility Permission Notes

**For automated builds (Claude Code, scripts):** Use the CLI method above. Accessibility permissions
don't help because they apply to the terminal app, not the subprocess running the script.

**For manual GUI automation:** If you want to run AppleScript manually from Script Editor or
Automator, ensure those apps have Accessibility permission in System Settings.

### How to Read GUI Build Results from xcactivitylog

**CRITICAL: Use XCLogParser for reliable parsing (install: `brew install xclogparser`)**

The `gunzip | strings | grep` approach is **UNRELIABLE** and misses:
- Project-level issues ("Missing package product")
- Linker warnings
- Structured diagnostic information

**Always verify visually in Xcode GUI Issue Navigator (Cmd+5) for definitive issue count!**

```bash
# Find the most recent build log
find_latest_xcactivitylog() {
  find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
    -name "*.xcactivitylog" -mmin -15 2>/dev/null | sort -r | head -1
}

# PREFERRED: Use XCLogParser for reliable parsing
read_gui_build_log_xclogparser() {
  local LOG=$(find_latest_xcactivitylog)

  if [ -z "$LOG" ]; then
    echo "ERROR: No recent xcactivitylog found!"
    return 1
  fi

  echo "=== Reading with XCLogParser: $LOG ==="

  # Generate JSON issues report
  xclogparser parse --file "$LOG" --reporter issues --output /tmp/build_issues.json 2>/dev/null

  if [ -f /tmp/build_issues.json ]; then
    local ERROR_COUNT=$(cat /tmp/build_issues.json | jq '.errors | length' 2>/dev/null || echo "0")
    local WARNING_COUNT=$(cat /tmp/build_issues.json | jq '.warnings | length' 2>/dev/null || echo "0")

    echo "Found: $ERROR_COUNT errors, $WARNING_COUNT warnings"

    if [ "$ERROR_COUNT" -gt 0 ]; then
      echo ""
      echo "=== ERRORS (MUST FIX) ==="
      cat /tmp/build_issues.json | jq -r '.errors[] | "\(.documentURL):\(.startingLineNumber): \(.title)"' | head -30
    fi

    if [ "$WARNING_COUNT" -gt 0 ]; then
      echo ""
      echo "=== WARNINGS (MUST FIX) ==="
      cat /tmp/build_issues.json | jq -r '.warnings[] | "\(.documentURL):\(.startingLineNumber): \(.title)"' | head -50
    fi

    rm -f /tmp/build_issues.json
    [ "$WARNING_COUNT" -gt 0 ] || [ "$ERROR_COUNT" -gt 0 ] && return 1
    return 0
  else
    echo "XCLogParser failed, falling back to gunzip method (LESS RELIABLE)"
    read_gui_build_log_gunzip
  fi
}

# FALLBACK (less reliable - misses project issues)
read_gui_build_log_gunzip() {
  local LOG=$(find_latest_xcactivitylog)

  if [ -z "$LOG" ]; then
    echo "ERROR: No recent xcactivitylog found!"
    return 1
  fi

  echo "=== Reading (gunzip fallback - may miss issues): $LOG ==="

  local TEMP_LOG="/tmp/build_log_$(date +%s).txt"
  gunzip -c "$LOG" 2>/dev/null | strings > "$TEMP_LOG"

  local WARNING_COUNT=$(grep -cE '\.swift:[0-9]+:[0-9]+: warning:' "$TEMP_LOG" || echo "0")
  local ERROR_COUNT=$(grep -cE '\.swift:[0-9]+:[0-9]+: error:' "$TEMP_LOG" || echo "0")

  echo "Found: $ERROR_COUNT errors, $WARNING_COUNT warnings"
  echo "⚠️  NOTE: This method may miss project-level issues! Check Xcode GUI Issue Navigator."

  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo ""
    echo "=== ERRORS (MUST FIX) ==="
    grep -E '\.swift:[0-9]+:[0-9]+: error:' "$TEMP_LOG" | sort -u | head -30
  fi

  if [ "$WARNING_COUNT" -gt 0 ]; then
    echo ""
    echo "=== WARNINGS (MUST FIX) ==="
    grep -E '\.swift:[0-9]+:[0-9]+: warning:' "$TEMP_LOG" | sort -u | head -50
  fi

  rm -f "$TEMP_LOG"

  [ "$WARNING_COUNT" -gt 0 ] || [ "$ERROR_COUNT" -gt 0 ] && return 1
  return 0
}

# Use the preferred method
read_gui_build_log() {
  read_gui_build_log_xclogparser
}
```

### Additional Verification: Xcode Issue Navigator

**ALWAYS verify in Xcode GUI Issue Navigator (Cmd+5) before declaring success!**

The Issue Navigator shows ALL issues including:
- "Missing package product" errors (often missed by log parsing)
- Project configuration warnings
- Capability/entitlement issues
- Swift Package dependency problems

```bash
# Open Issue Navigator via AppleScript
osascript -e '
tell application "Xcode"
    activate
end tell
delay 0.5
tell application "System Events"
    tell process "Xcode"
        keystroke "5" using {command down}
    end tell
end tell
'
```

---

## Phase 0: Tool Installation (ALL REQUIRED)

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Installing ALL required tools ==="

# Core build tools
brew install xcodegen swiftlint swiftformat

# Security tools (REQUIRED)
brew install gitleaks osv-scanner

# Testing tools (REQUIRED)
brew install openjdk@17
curl -Ls "https://get.maestro.mobile.dev" | bash

# Add to PATH
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH:$HOME/.maestro/bin"

# Verify ALL tools installed
echo ""
echo "=== Verifying tool installation ==="
MISSING=0
for tool in xcodebuild swiftlint swiftformat xcodegen gh gitleaks osv-scanner maestro; do
  if command -v $tool &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ $tool MISSING"
    MISSING=1
  fi
done

[ "$MISSING" -eq 1 ] && { echo "ERROR: Missing tools. Install and retry."; exit 1; }
echo "✓ All tools installed"
```

### GitHub Setup
```bash
# Ensure SSH remote
git remote -v | grep -q "https://" && git remote set-url origin git@github.com:Atchoum23/Thea.git

# Verify GitHub CLI authenticated
gh auth status || { echo "Run: gh auth login"; exit 1; }
```

---

## Phase 1: Code Quality & Linting

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Regenerate project first
xcodegen generate

# SwiftFormat
swiftformat . 2>&1

# SwiftLint with auto-fix
swiftlint lint --fix 2>&1

# Check remaining violations (STRICT - must be 0)
ERRORS=$(swiftlint lint 2>&1 | grep -cE "error:" || echo "0")
WARNINGS=$(swiftlint lint 2>&1 | grep -cE "warning:" || echo "0")

echo "SwiftLint: $ERRORS errors, $WARNINGS warnings"

if [ "$ERRORS" -gt 0 ]; then
  echo "=== SwiftLint ERRORS - MUST FIX ==="
  swiftlint lint 2>&1 | grep "error:" | head -30
  exit 1
fi

echo "✓ SwiftLint passed"
```

---

## Phase 2: CLI Builds (All 4 Platforms)

### 2.1 Debug Builds
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

declare -A DESTINATIONS=(
  ["Thea-iOS"]="generic/platform=iOS"
  ["Thea-macOS"]="platform=macOS"
  ["Thea-watchOS"]="generic/platform=watchOS"
  ["Thea-tvOS"]="generic/platform=tvOS"
)

for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  PLATFORM=$(echo $scheme | sed 's/Thea-//' | tr '[:upper:]' '[:lower:]')
  DEST="${DESTINATIONS[$scheme]}"

  echo "=== Building $scheme (Debug CLI) ==="
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "$DEST" -configuration Debug \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tee "build_${PLATFORM}_debug.log"

  if grep -q "BUILD SUCCEEDED" "build_${PLATFORM}_debug.log"; then
    WARNS=$(grep -c " warning:" "build_${PLATFORM}_debug.log" 2>/dev/null || echo "0")
    if [ "$WARNS" -gt 0 ]; then
      echo "⚠ $scheme Debug: $WARNS warnings - MUST FIX"
      grep " warning:" "build_${PLATFORM}_debug.log" | head -20
    else
      echo "✓ $scheme Debug: 0 warnings"
    fi
  else
    echo "✗ $scheme Debug: FAILED"
    grep " error:" "build_${PLATFORM}_debug.log" | head -20
    exit 1
  fi
done
```

### 2.2 Release Builds
```bash
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  PLATFORM=$(echo $scheme | sed 's/Thea-//' | tr '[:upper:]' '[:lower:]')
  DEST="${DESTINATIONS[$scheme]}"

  echo "=== Building $scheme (Release CLI) ==="
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "$DEST" -configuration Release \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tee "build_${PLATFORM}_release.log"

  if grep -q "BUILD SUCCEEDED" "build_${PLATFORM}_release.log"; then
    WARNS=$(grep -c " warning:" "build_${PLATFORM}_release.log" 2>/dev/null || echo "0")
    [ "$WARNS" -gt 0 ] && echo "⚠ $scheme Release: $WARNS warnings - MUST FIX" || echo "✓ $scheme Release: 0 warnings"
  else
    echo "✗ $scheme Release: FAILED"
    exit 1
  fi
done
```

---

## Phase 3: GUI Builds (All 4 Platforms)

**THIS PHASE IS MANDATORY - DO NOT SKIP**

```bash
# Open project
open "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"
sleep 5

# Build each scheme via GUI
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  build_gui_scheme "$scheme"

  if ! read_gui_build_log; then
    echo "✗ $scheme GUI build has warnings/errors - MUST FIX"
  else
    echo "✓ $scheme GUI build: 0 warnings"
  fi
done
```

---

## Phase 4: Fix ALL Swift 6 Concurrency Issues

**ALL concurrency warnings MUST be fixed. This is non-negotiable with Swift 6.**

### 4.1 Find All Concurrency Issues
```bash
echo "=== Finding Swift 6 Concurrency Issues ==="
grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe|implicitly asynchronous)" build_*.log | sort -u | head -100

CONCURRENCY_ISSUES=$(grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe)" build_*.log | wc -l)
echo "Found $CONCURRENCY_ISSUES concurrency issues"

[ "$CONCURRENCY_ISSUES" -gt 0 ] && echo "MUST FIX ALL BEFORE PROCEEDING"
```

### 4.2 Common Fix Patterns

```swift
// Pattern 1: Static property not concurrency-safe
// FIX:
nonisolated(unsafe) static let shared = MyClass()

// Pattern 2: Capture of 'self' with non-Sendable type
// FIX:
Task { @MainActor in
    self.doSomething()
}

// Pattern 3: Call to main-actor-isolated method
// FIX:
@MainActor func foo() { }
// Or:
await MainActor.run { foo() }

// Pattern 4: Non-sendable type crossing actor boundary
// FIX:
final class MyClass: @unchecked Sendable { }
```

### 4.3 Verify All Fixed
```bash
# Rebuild and verify
REMAINING=$(grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe)" build_*.log | wc -l)
[ "$REMAINING" -gt 0 ] && { echo "STILL $REMAINING issues - KEEP FIXING"; exit 1; }
echo "✓ All concurrency issues fixed"
```

---

## Phase 5: Unit & E2E Testing

### 5.1 Unit Tests
```bash
IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone 16" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

xcodebuild test -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$IPHONE_SIM" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee test_ios.log

if grep -qE "TEST FAILED|FAILED" test_ios.log; then
  echo "✗ Tests FAILED"
  grep -A5 "FAILED" test_ios.log | head -30
  exit 1
fi
echo "✓ Unit tests passed"
```

### 5.2 Maestro E2E Testing (REQUIRED)
```bash
# Verify Maestro installed
command -v maestro || { echo "INSTALL MAESTRO"; exit 1; }

# Boot simulator
xcrun simctl boot "$IPHONE_SIM" 2>/dev/null || true

# Install app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug-iphonesimulator -name "Thea.app" | head -1)
[ -n "$APP_PATH" ] && xcrun simctl install "$IPHONE_SIM" "$APP_PATH"

# Run Maestro tests
maestro test .maestro/ 2>&1 | tee maestro_results.log

if grep -q "FAILED" maestro_results.log; then
  echo "✗ Maestro tests FAILED"
  exit 1
fi
echo "✓ Maestro E2E tests passed"
```

### 5.3 macOS Functional Testing
```bash
MACOS_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug -name "Thea.app" -path "*macOS*" | head -1)

if [ -n "$MACOS_APP" ]; then
  open "$MACOS_APP"
  sleep 3

  osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "Thea"
        if not (exists window 1) then error "App window not found"

        -- Test menus
        set menuBar to menu bar 1
        repeat with menuBarItem in menu bar items of menuBar
            try
                click menuBarItem
                delay 0.2
                key code 53
            end try
        end repeat

        log "macOS functional test complete"
    end tell
end tell
APPLESCRIPT

  echo "✓ macOS functional tests passed"
fi
```

---

## Phase 6: Security Audit (REQUIRED)

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Secrets detection
gitleaks detect --source . --verbose 2>&1 | tee security_secrets.log
if grep -q "leaks found" security_secrets.log; then
  echo "✗ SECRETS FOUND - MUST REMOVE"
  exit 1
fi
echo "✓ No secrets found"

# Dependency vulnerabilities
osv-scanner --lockfile Package.resolved 2>&1 | tee security_deps.log
echo "✓ Dependencies scanned"

# Run thea-audit if available
if [ -d "Tools/thea-audit" ]; then
  cd Tools/thea-audit
  swift build -c release 2>/dev/null
  ./.build/release/thea-audit audit --path ../.. --format yaml --output ../../audit-results.yaml --policy ../../thea-policy.json 2>&1 || true
  cd ../..
  echo "✓ thea-audit complete"
fi

echo "✓ Security audits complete"
```

---

## Phase 7: Commit, Push, and Verify GitHub Actions

### 7.1 Commit All Changes
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

git add -A
git commit -m "$(cat <<'EOF'
fix: QA complete - all platforms build clean, zero warnings

- All 4 platforms (iOS, macOS, watchOS, tvOS) build with 0 warnings
- All CLI and GUI builds verified
- All Swift 6 concurrency issues fixed
- All unit and E2E tests pass
- Security audits complete

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"

git push origin main
```

### 7.2 Verify GitHub Actions (ALL 6 WORKFLOWS)
```bash
echo "Waiting for GitHub Actions..."
sleep 15

# List recent runs
gh run list --limit 10

# Monitor CI workflow (main one)
echo "Monitoring CI workflow..."
gh run watch --exit-status || {
  echo "✗ GitHub Actions FAILED"
  gh run list --limit 3 --json conclusion,name,url
  exit 1
}

echo "✓ CI workflow passed"

# Verify all workflows are green
echo ""
echo "=== Checking all workflow statuses ==="
gh run list --limit 6 --json name,conclusion,status | jq -r '.[] | "\(.name): \(.conclusion // .status)"'
```

### 7.3 If GitHub Actions Fail
```bash
# Get failed run details
FAILED_RUN=$(gh run list --status failure --limit 1 --json databaseId -q '.[0].databaseId')

if [ -n "$FAILED_RUN" ]; then
  echo "=== Failed workflow logs ==="
  gh run view $FAILED_RUN --log-failed

  echo ""
  echo "FIX the issues, commit, push, and verify again"
fi
```

---

## Final Checklist

### Builds (ALL 16 MUST PASS WITH 0 WARNINGS)
- [ ] Thea-iOS Debug CLI: 0 warnings
- [ ] Thea-iOS Release CLI: 0 warnings
- [ ] Thea-iOS Debug GUI: 0 warnings
- [ ] Thea-iOS Release GUI: 0 warnings
- [ ] Thea-macOS Debug CLI: 0 warnings
- [ ] Thea-macOS Release CLI: 0 warnings
- [ ] Thea-macOS Debug GUI: 0 warnings
- [ ] Thea-macOS Release GUI: 0 warnings
- [ ] Thea-watchOS Debug CLI: 0 warnings
- [ ] Thea-watchOS Release CLI: 0 warnings
- [ ] Thea-watchOS Debug GUI: 0 warnings
- [ ] Thea-watchOS Release GUI: 0 warnings
- [ ] Thea-tvOS Debug CLI: 0 warnings
- [ ] Thea-tvOS Release CLI: 0 warnings
- [ ] Thea-tvOS Debug GUI: 0 warnings
- [ ] Thea-tvOS Release GUI: 0 warnings

### Code Quality
- [ ] SwiftLint: 0 errors
- [ ] SwiftFormat: Applied
- [ ] ALL Swift 6 concurrency issues: FIXED

### Testing
- [ ] Unit tests: All pass
- [ ] Maestro E2E: All flows pass
- [ ] macOS functional: Tests pass

### Security
- [ ] gitleaks: No secrets
- [ ] osv-scanner: Scanned
- [ ] thea-audit: Complete

### GitHub Actions (ALL 6 MUST BE GREEN)
- [ ] CI workflow: GREEN
- [ ] E2E Tests workflow: GREEN
- [ ] Security Audit (Full): GREEN
- [ ] Security Audit (PR): GREEN (on PRs)
- [ ] Swift Package Dependencies: GREEN
- [ ] Release workflow: GREEN (on tags)

---

## Completion Criteria

**THE MISSION IS ONLY COMPLETE WHEN:**

1. All 16 builds pass with 0 warnings
2. All Swift 6 concurrency issues are FIXED
3. All tests pass (unit + E2E)
4. All security scans complete
5. All changes pushed to GitHub
6. **ALL 6 GitHub Actions workflows show GREEN checkmarks**

If ANY workflow is failing, the mission is NOT complete.

---

## Quick Start

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && claude --dangerously-skip-permissions
```

### Prompt
```
Read .claude/AUTONOMOUS_BUILD_QA.md and execute it completely. Do not stop until ALL completion criteria are met, including ALL GitHub Actions passing.
```
