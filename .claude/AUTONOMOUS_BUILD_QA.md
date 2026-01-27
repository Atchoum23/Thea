# Autonomous Build & QA

## MISSION CRITICAL: READ THIS FIRST

**This document is the COMPLETE GUIDE for autonomous QA execution. The mission is NOT complete until:**
1. **ALL 16 BUILDS PASS** (4 platforms × 2 configs × CLI + GUI methods) with **ZERO warnings**
2. **ALL GitHub Actions workflows are GREEN** (not red/failing)
3. **ALL Swift 6 concurrency issues are FIXED** (not just logged)
4. **ALL functional tests pass** on ALL platforms
5. **ALL security/accessibility audits complete**

**DO NOT DECLARE SUCCESS UNTIL EVERY CRITERION IS MET.**

---

## CRITICAL: Xcode GUI Interaction (WHY THIS DOCUMENT EXISTS)

### The Problem
CLI builds (`xcodebuild`) and Xcode GUI builds show **DIFFERENT warnings**. The Xcode GUI has:
- Indexer warnings not visible in CLI
- Project settings warnings
- Capability/entitlement warnings
- Additional static analysis

**YOU MUST USE BOTH CLI AND GUI BUILDS. CLI-ONLY IS NOT ACCEPTABLE.**

### How to Trigger GUI Builds via AppleScript

```bash
# Open project in Xcode
open "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"
sleep 3

# Function to build a scheme via GUI
build_gui_scheme() {
  local SCHEME="$1"
  echo "=== Building $SCHEME via Xcode GUI ==="

  osascript << EOF
tell application "Xcode"
    activate
end tell
delay 1
tell application "System Events"
    tell process "Xcode"
        -- Open scheme chooser (Ctrl+0)
        keystroke "0" using {control down}
        delay 0.5
        -- Type scheme name
        keystroke "$SCHEME"
        delay 0.3
        -- Select it
        keystroke return
        delay 0.5
        -- Clean build folder first (Cmd+Shift+K)
        keystroke "k" using {command down, shift down}
        delay 2
        -- Build (Cmd+B)
        keystroke "b" using {command down}
    end tell
end tell
EOF

  echo "Waiting for GUI build to complete..."
  sleep 120  # Wait 2 minutes for build
}

# Build ALL 4 schemes via GUI
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  build_gui_scheme "$scheme"
done
```

### How to Read GUI Build Results from xcactivitylog

**THIS IS CRITICAL. The Xcode GUI stores build logs in compressed xcactivitylog files.**

```bash
# Find the most recent build log
find_latest_xcactivitylog() {
  find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
    -name "*.xcactivitylog" -mmin -15 2>/dev/null | sort -r | head -1
}

# Extract warnings and errors from xcactivitylog
read_gui_build_log() {
  local LOG=$(find_latest_xcactivitylog)

  if [ -z "$LOG" ]; then
    echo "ERROR: No recent xcactivitylog found!"
    echo "Ensure you ran a GUI build within the last 15 minutes."
    return 1
  fi

  echo "=== Reading: $LOG ==="

  # Decompress and extract text
  local TEMP_LOG="/tmp/build_log_$(date +%s).txt"
  gunzip -c "$LOG" 2>/dev/null | strings > "$TEMP_LOG"

  # Count warnings
  local WARNING_COUNT=$(grep -cE '\.swift:[0-9]+:[0-9]+: warning:' "$TEMP_LOG" || echo "0")
  local ERROR_COUNT=$(grep -cE '\.swift:[0-9]+:[0-9]+: error:' "$TEMP_LOG" || echo "0")

  echo "Found: $ERROR_COUNT errors, $WARNING_COUNT warnings"

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

  # Project-level warnings
  echo ""
  echo "=== PROJECT WARNINGS ==="
  grep -E '\.xcodeproj: warning:' "$TEMP_LOG" | sort -u | head -20

  # Entitlement issues
  echo ""
  echo "=== ENTITLEMENT ISSUES ==="
  grep -iE 'entitlement|capability' "$TEMP_LOG" | grep -iE 'warning|error' | sort -u | head -20

  rm -f "$TEMP_LOG"

  # Return failure if any warnings/errors
  if [ "$WARNING_COUNT" -gt 0 ] || [ "$ERROR_COUNT" -gt 0 ]; then
    return 1
  fi
  return 0
}
```

### GUI Build Wait Times
- **Clean build**: Wait 120-180 seconds
- **Incremental build**: Wait 30-60 seconds
- **Verify completion**: Check log for "Build Succeeded" or count stops changing

---

## Project Details

- **Project Path**: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj`
- **Project Generator**: XcodeGen (`project.yml`) - run `xcodegen generate` after changes
- **Schemes (ALL 4 REQUIRED)**: `Thea-iOS`, `Thea-macOS`, `Thea-watchOS`, `Thea-tvOS`
- **Swift Version**: 6.0 with **STRICT CONCURRENCY** (all warnings are errors)
- **Derived Data**: `~/Library/Developer/Xcode/DerivedData/Thea-*/`
- **GitHub Repo**: `git@github.com:Atchoum23/Thea.git`

---

## Phase 0: Tool Installation (ALL REQUIRED)

**INSTALL ALL TOOLS FIRST. Do not proceed without them.**

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

echo "=== Installing ALL required tools ==="

# Core build tools
brew install xcodegen swiftlint swiftformat

# Security tools (REQUIRED - not optional)
brew install gitleaks osv-scanner snyk
pip3 install mobsfscan

# Testing tools (REQUIRED - not optional)
brew install openjdk@17
curl -Ls "https://get.maestro.mobile.dev" | bash

# Add to PATH
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH:$HOME/.maestro/bin"

# Verify ALL tools installed
echo ""
echo "=== Verifying tool installation ==="
MISSING=0
for tool in xcodebuild swiftlint swiftformat xcodegen gh gitleaks osv-scanner mobsfscan maestro; do
  if command -v $tool &>/dev/null; then
    echo "✓ $tool"
  else
    echo "✗ $tool MISSING - INSTALL BEFORE PROCEEDING"
    MISSING=1
  fi
done

if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "ERROR: Missing required tools. Install them and retry."
  exit 1
fi

echo ""
echo "✓ All tools installed"
```

### GitHub Setup
```bash
# Ensure SSH remote (not HTTPS)
git remote -v | grep -q "https://" && git remote set-url origin git@github.com:Atchoum23/Thea.git

# Verify GitHub CLI authenticated
gh auth status || { echo "Run: gh auth login"; exit 1; }
```

---

## Phase 1: Fix Test Target Configuration

**TheaTests module configuration MUST be fixed before running tests.**

### 1.1 Check Test Target Exists
```bash
# List all targets
xcodebuild -project Thea.xcodeproj -list 2>/dev/null

# Check if TheaTests is properly configured in project.yml
grep -A 20 "TheaTests:" project.yml
```

### 1.2 Fix TheaTests Module Configuration
If tests fail with "module not found" or similar:

```bash
# Ensure TheaTests depends on TheaCore
# Edit project.yml to add:
#
# TheaTests:
#   type: bundle.unit-test
#   platform: iOS
#   sources:
#     - Tests/TheaTests
#   dependencies:
#     - target: TheaCore
#     - target: Thea-iOS
#   settings:
#     INFOPLIST_FILE: Tests/TheaTests/Info.plist
#     TEST_HOST: $(BUILT_PRODUCTS_DIR)/Thea.app/Thea
#     BUNDLE_LOADER: $(TEST_HOST)

# Regenerate project after fixing
xcodegen generate
```

---

## Phase 2: Code Quality & Linting

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# SwiftFormat first
swiftformat . 2>&1

# SwiftLint with auto-fix
swiftlint lint --fix 2>&1

# Check remaining violations
VIOLATIONS=$(swiftlint lint 2>&1 | grep -cE "error:" || echo "0")
if [ "$VIOLATIONS" -gt 0 ]; then
  echo "=== SwiftLint ERRORS - MUST FIX ==="
  swiftlint lint 2>&1 | grep "error:" | head -30
  echo ""
  echo "FIX THESE ERRORS BEFORE PROCEEDING"
  exit 1
fi

echo "✓ SwiftLint: 0 errors"
```

---

## Phase 3: CLI Builds (All 4 Platforms, Debug + Release)

### 3.1 Debug CLI Builds
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
    -destination "$DEST" -configuration Debug ONLY_ACTIVE_ARCH=YES \
    -allowProvisioningUpdates build 2>&1 | tee "build_${PLATFORM}_debug.log"

  # Check for success and warnings
  if grep -q "BUILD SUCCEEDED" "build_${PLATFORM}_debug.log"; then
    WARNS=$(grep -c " warning:" "build_${PLATFORM}_debug.log" 2>/dev/null || echo "0")
    if [ "$WARNS" -gt 0 ]; then
      echo "⚠ $scheme Debug: SUCCEEDED but has $WARNS warnings - MUST FIX"
      grep " warning:" "build_${PLATFORM}_debug.log" | head -20
    else
      echo "✓ $scheme Debug: SUCCEEDED, 0 warnings"
    fi
  else
    echo "✗ $scheme Debug: FAILED - FIX ERRORS BEFORE PROCEEDING"
    grep " error:" "build_${PLATFORM}_debug.log" | head -20
    exit 1
  fi
done
```

### 3.2 Release CLI Builds
```bash
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  PLATFORM=$(echo $scheme | sed 's/Thea-//' | tr '[:upper:]' '[:lower:]')

  case $PLATFORM in
    ios) DEST="generic/platform=iOS" ;;
    macos) DEST="platform=macOS" ;;
    watchos) DEST="generic/platform=watchOS" ;;
    tvos) DEST="generic/platform=tvOS" ;;
  esac

  echo "=== Building $scheme (Release CLI) ==="
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "$DEST" -configuration Release ONLY_ACTIVE_ARCH=NO \
    -allowProvisioningUpdates build 2>&1 | tee "build_${PLATFORM}_release.log"

  if grep -q "BUILD SUCCEEDED" "build_${PLATFORM}_release.log"; then
    WARNS=$(grep -c " warning:" "build_${PLATFORM}_release.log" 2>/dev/null || echo "0")
    if [ "$WARNS" -gt 0 ]; then
      echo "⚠ $scheme Release: $WARNS warnings - MUST FIX"
    else
      echo "✓ $scheme Release: 0 warnings"
    fi
  else
    echo "✗ $scheme Release: FAILED"
    exit 1
  fi
done
```

---

## Phase 4: GUI Builds (All 4 Platforms)

**THIS PHASE IS MANDATORY - DO NOT SKIP**

### 4.1 Open Project in Xcode
```bash
open "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"
sleep 5
```

### 4.2 Build Each Scheme via GUI
```bash
build_gui_scheme() {
  local SCHEME="$1"
  echo "=== Building $SCHEME via Xcode GUI ==="

  osascript << EOF
tell application "Xcode"
    activate
end tell
delay 1
tell application "System Events"
    tell process "Xcode"
        keystroke "0" using {control down}
        delay 0.5
        keystroke "$SCHEME"
        delay 0.3
        keystroke return
        delay 0.5
        keystroke "b" using {command down}
    end tell
end tell
EOF

  sleep 120
}

for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  build_gui_scheme "$scheme"

  # Read and check GUI log
  if ! read_gui_build_log; then
    echo "✗ $scheme GUI build has warnings/errors - MUST FIX"
    echo "Fix the issues and rebuild this scheme via GUI"
  else
    echo "✓ $scheme GUI build: 0 warnings"
  fi
done
```

### 4.3 Read GUI Build Logs
```bash
read_gui_build_log() {
  LOG=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
    -name "*.xcactivitylog" -mmin -15 2>/dev/null | sort -r | head -1)

  [ -z "$LOG" ] && { echo "No recent log"; return 1; }

  TEMP="/tmp/gui_log.txt"
  gunzip -c "$LOG" 2>/dev/null | strings > "$TEMP"

  WARNS=$(grep -cE '\.swift:[0-9]+:[0-9]+: warning:' "$TEMP" || echo "0")
  ERRS=$(grep -cE '\.swift:[0-9]+:[0-9]+: error:' "$TEMP" || echo "0")

  echo "GUI Log: $ERRS errors, $WARNS warnings"

  if [ "$WARNS" -gt 0 ] || [ "$ERRS" -gt 0 ]; then
    grep -E '\.(swift|xcodeproj):[0-9]*:?[0-9]*: (warning|error):' "$TEMP" | sort -u | head -30
    return 1
  fi

  rm -f "$TEMP"
  return 0
}
```

---

## Phase 5: Fix ALL Swift 6 Concurrency Issues

**ALL concurrency warnings MUST be fixed. This is non-negotiable with Swift 6.**

### 5.1 Find All Concurrency Issues
```bash
echo "=== Finding Swift 6 Concurrency Issues ==="
grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe|implicitly asynchronous|cannot be sent)" build_*.log | sort -u | head -100

# Count them
CONCURRENCY_ISSUES=$(grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe)" build_*.log | wc -l)
echo ""
echo "Found $CONCURRENCY_ISSUES concurrency issues"

if [ "$CONCURRENCY_ISSUES" -gt 0 ]; then
  echo "MUST FIX ALL CONCURRENCY ISSUES BEFORE PROCEEDING"
fi
```

### 5.2 Fix Patterns

```swift
// Pattern 1: Static property not concurrency-safe
// WARNING: Static property 'shared' is not concurrency-safe
// FIX:
nonisolated(unsafe) static let shared = MyClass()

// Pattern 2: Capture of 'self' with non-Sendable type
// WARNING: Capture of 'self' with non-sendable type
// FIX:
Task { @MainActor in
    self.doSomething()
}

// Pattern 3: Call to main-actor-isolated method
// WARNING: Call to main-actor-isolated instance method 'foo()' in a synchronous nonisolated context
// FIX:
@MainActor func foo() { }
// Or call with:
await MainActor.run { foo() }

// Pattern 4: Non-sendable type crossing actor boundary
// WARNING: Non-sendable type 'X' cannot be sent
// FIX:
final class MyClass: @unchecked Sendable { }
// Or for value types:
struct MyStruct: Sendable { }

// Pattern 5: OSLog string interpolation with self
// WARNING: Reference to captured var 'self' in concurrently-executing code
// FIX: Use explicit self. and ensure the logger call is properly isolated
```

### 5.3 After Fixing, Rebuild and Verify
```bash
# Rebuild all platforms
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  # ... rebuild ...
done

# Verify no more concurrency warnings
REMAINING=$(grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe)" build_*.log | wc -l)
if [ "$REMAINING" -gt 0 ]; then
  echo "STILL $REMAINING concurrency issues - KEEP FIXING"
  exit 1
fi
echo "✓ All concurrency issues fixed"
```

---

## Phase 6: Unit & Functional Testing

### 6.1 Run Unit Tests
```bash
IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone 16" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

xcodebuild test -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$IPHONE_SIM" \
  -resultBundlePath TestResults/iOS.xcresult 2>&1 | tee test_ios.log

# Check for test failures
if grep -q "TEST FAILED" test_ios.log || grep -q "FAILED" test_ios.log; then
  echo "✗ Tests FAILED - FIX BEFORE PROCEEDING"
  grep -A5 "FAILED" test_ios.log | head -30
  exit 1
fi
```

### 6.2 Maestro E2E Testing (REQUIRED)
```bash
# Verify Maestro is installed
command -v maestro || { echo "INSTALL MAESTRO: curl -Ls 'https://get.maestro.mobile.dev' | bash"; exit 1; }

# Boot simulator and install app
xcrun simctl boot "$IPHONE_SIM" 2>/dev/null || true
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

### 6.3 macOS Functional Testing via AppleScript
```bash
MACOS_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug -name "Thea.app" -path "*macOS*" | head -1)

if [ -n "$MACOS_APP" ]; then
  open "$MACOS_APP"
  sleep 3

  osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "Thea"
        -- Verify app launched
        if not (exists window 1) then
            error "App window not found"
        end if

        -- Test all menu items
        set menuBar to menu bar 1
        repeat with menuBarItem in menu bar items of menuBar
            try
                click menuBarItem
                delay 0.2
                key code 53
            end try
        end repeat

        -- Test all buttons
        try
            repeat with btn in (every button of window 1)
                click btn
                delay 0.3
            end repeat
        end try

        log "macOS functional test complete"
    end tell
end tell
APPLESCRIPT

  echo "✓ macOS functional tests passed"
fi
```

---

## Phase 7: Security Audit (REQUIRED)

```bash
# Secrets detection
gitleaks detect --source . --verbose 2>&1 | tee security_secrets.log
if grep -q "leaks found" security_secrets.log; then
  echo "✗ SECRETS FOUND - MUST REMOVE"
  exit 1
fi

# Dependency vulnerabilities
osv-scanner --lockfile Package.resolved 2>&1 | tee security_deps.log

# MobSF source scan
mobsfscan --json -o mobsf_results.json . 2>&1 | tee mobsf_scan.log

# Snyk scan
snyk test --all-projects 2>&1 | tee snyk_report.log || true

echo "✓ Security audits complete"
```

---

## Phase 8: Performance & Accessibility

### 8.1 App Size Check
```bash
echo "=== App Sizes ==="
find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products -name "*.app" -exec du -sh {} \;
```

### 8.2 Accessibility Check
```bash
echo "=== Accessibility Labels ==="
grep -r "\.accessibilityLabel\|\.accessibilityHint" Shared/ iOS/ macOS/ | wc -l | xargs echo "Found:"

echo ""
echo "=== Images Missing Accessibility ==="
grep -rn "Image(" Shared/ iOS/ macOS/ | grep -v "accessibilityLabel" | head -10
```

---

## Phase 9: Commit, Push, and Verify GitHub Actions

### 9.1 Commit All Changes
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
- GitHub Actions CI passing

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"

git push origin main
```

### 9.2 Wait for and Verify GitHub Actions
```bash
echo "Waiting for GitHub Actions to start..."
sleep 10

# Check workflow status
gh run list --limit 5

# Wait for completion and check status
echo "Monitoring CI workflow..."
gh run watch --exit-status || {
  echo "✗ GitHub Actions FAILED"
  echo ""
  echo "=== Check failed workflow ==="
  gh run list --limit 1 --json conclusion,name,url

  echo ""
  echo "FIX THE FAILING WORKFLOW AND RE-RUN"
  exit 1
}

echo "✓ GitHub Actions CI passing"
```

### 9.3 If GitHub Actions Fail
```bash
# Get the failed run ID
FAILED_RUN=$(gh run list --status failure --limit 1 --json databaseId -q '.[0].databaseId')

if [ -n "$FAILED_RUN" ]; then
  echo "=== Downloading failure logs ==="
  gh run view $FAILED_RUN --log-failed

  echo ""
  echo "FIX the issues shown above, commit, push, and verify again"
fi
```

---

## Final Checklist (ALL MUST BE CHECKED)

### Builds
- [ ] Thea-iOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-iOS Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-iOS Debug GUI: 0 warnings in xcactivitylog
- [ ] Thea-iOS Release GUI: 0 warnings in xcactivitylog
- [ ] Thea-macOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-macOS Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-macOS Debug GUI: 0 warnings in xcactivitylog
- [ ] Thea-macOS Release GUI: 0 warnings in xcactivitylog
- [ ] Thea-watchOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-watchOS Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-watchOS Debug GUI: 0 warnings in xcactivitylog
- [ ] Thea-watchOS Release GUI: 0 warnings in xcactivitylog
- [ ] Thea-tvOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-tvOS Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] Thea-tvOS Debug GUI: 0 warnings in xcactivitylog
- [ ] Thea-tvOS Release GUI: 0 warnings in xcactivitylog

### Code Quality
- [ ] SwiftLint: 0 errors
- [ ] SwiftFormat: Applied
- [ ] ALL Swift 6 concurrency issues: FIXED

### Testing
- [ ] TheaTests module: Configured and working
- [ ] Unit tests: All pass
- [ ] Maestro E2E: All flows pass
- [ ] macOS AppleScript: Functional tests pass

### Security
- [ ] gitleaks: No secrets
- [ ] osv-scanner: Scanned
- [ ] MobSF: Scanned
- [ ] Snyk: Scanned

### CI/CD
- [ ] All changes committed
- [ ] Pushed to GitHub
- [ ] **ALL GitHub Actions workflows: GREEN/PASSING**

---

## Completion Criteria

**THE MISSION IS ONLY COMPLETE WHEN:**

1. All 16 builds (4 platforms × 2 configs × 2 methods) pass with 0 warnings
2. All Swift 6 concurrency issues are FIXED (not just logged)
3. All tests pass (unit + E2E)
4. All security scans complete
5. All changes pushed to GitHub
6. **ALL GitHub Actions workflows show GREEN checkmarks (not red X)**

If ANY GitHub Action is failing, the mission is NOT complete. Fix the issues and re-verify.

---

## Terminal Execution

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && claude --dangerously-skip-permissions
```

### Prompt
```
Read .claude/AUTONOMOUS_BUILD_QA.md and execute it completely. Do not stop until ALL completion criteria are met, including ALL GitHub Actions passing.
```
