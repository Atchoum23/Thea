# Autonomous Build & QA

## Objective
Autonomously build, test, audit, and verify ALL Xcode schemes (iOS/iPadOS, macOS, watchOS, tvOS) until production-ready with zero errors, warnings, bugs, vulnerabilities, or issues.

> **Note**: iOS builds are universal and run on both iPhone and iPad. No separate iPadOS scheme is needed.

---

## CRITICAL: Mission Success Requirements

### Non-Negotiable Goals
1. **ALL 4 PLATFORMS** must build successfully: iOS, macOS, watchOS, tvOS
2. **ALL 16 BUILDS** must pass: 8 CLI + 8 GUI (4 platforms × 2 configs × 2 methods)
3. **ZERO project warnings** in final builds (SPM package warnings acceptable)
4. **ZERO build errors** across all schemes
5. **BOTH CLI AND GUI** builds are required - they show different warnings

### Failure Recovery Protocol
- If ANY build fails → FIX IMMEDIATELY before proceeding
- If fix requires code changes → Make changes, then rebuild ONLY failed scheme
- If fix requires `project.yml` changes → Run `xcodegen generate` before rebuilding
- NEVER skip a failing build - the mission fails if any platform fails

---

## Project Details
- **Project Path**: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj`
- **Project Generator**: XcodeGen (`project.yml`)
- **Schemes (ALL REQUIRED)**: `Thea-iOS`, `Thea-macOS`, `Thea-watchOS`, `Thea-tvOS`
- **Swift Version**: 6.0 with strict concurrency
- **Derived Data**: `~/Library/Developer/Xcode/DerivedData/Thea-*/`
- **Extensions**: 11 extension targets (built as dependencies of main schemes)

---

## Execution Rules

### Phase Priority
| Priority | Phases | Description |
|----------|--------|-------------|
| **REQUIRED** | 1, 2, 3 | Builds (CLI+GUI) & linting - must pass |
| **CONDITIONAL** | 4, 5 | Tests - skip if no test targets exist |
| **OPTIONAL** | 6, 7, 8 | Security/perf/a11y - run if tools available |
| **SETUP-ONLY** | 9 | CI/CD - create files, don't require external services |
| **VERIFICATION** | 10 | Final checklist |

**NOTE**: Phases 1 and 2 require BOTH CLI (xcodebuild) AND GUI (Xcode.app) builds. CLI-only is NOT acceptable.

### Skip Conditions
- **Skip SonarCloud**: If `$SONAR_TOKEN` not set
- **Skip Codecov**: If `$CODECOV_TOKEN` not set
- **Skip DeepSource**: Runs via GitHub integration (just needs .deepsource.toml)
- **Skip MobSF**: Requires Docker (skip if not installed)
- **Skip Maestro**: Requires device/simulator running
- **Skip tests**: If no `*Tests` targets exist in scheme

### GitHub Secrets Expected (all configured)
- `SONAR_TOKEN` - SonarCloud analysis
- `CODECOV_TOKEN` - Code coverage upload
- `DEEPSOURCE_DSN` - DeepSource (if using CLI upload)
- `MATCH_PASSWORD` - Fastlane match (code signing)
- `APP_STORE_CONNECT_API_KEY` - App Store deployment

### Error Recovery
1. If a phase fails, fix issues and re-run ONLY that phase
2. Do not re-run successful phases
3. Log all fixes to `QA_FIXES_LOG.md`
4. If a fix requires code changes, make them immediately

### Warning Policy
- **Target**: 0 warnings in project code
- **Acceptable**: Warnings from 3rd-party SPM packages (cannot fix)
- **Action**: Suppress with `// swiftlint:disable` ONLY if justified

### Swift 6 Strict Concurrency Policy
Swift 6 enforces strict concurrency. **ALL concurrency warnings/errors MUST be fixed.** Common patterns:

| Issue | Fix |
|-------|-----|
| `Sending 'X' risks data races` | Add `@Sendable` or use `nonisolated(unsafe)` |
| `Capture of 'self' with non-Sendable type` | Use `Task { @MainActor in }` or make type `Sendable` |
| `Call to main-actor-isolated method in non-isolated context` | Add `@MainActor` annotation or use `await MainActor.run {}` |
| `Static property 'X' is not concurrency-safe` | Use `nonisolated(unsafe) static` or make a computed property |
| `Non-sendable type 'X' in implicitly asynchronous access` | Conform to `Sendable` or use `@unchecked Sendable` |

**Test targets also require Swift 6 compliance.** If tests fail to build due to concurrency issues:
1. Fix the concurrency issues in test files (same patterns as above)
2. Add `@MainActor` to test classes that interact with UI
3. Use `@testable import` with proper isolation annotations

### CI/CD Workflow Requirement
**CRITICAL**: After modifying ANY file that should trigger CI (`.github/workflows/*.yml`, `Package.swift`, `project.yml`, source files), you MUST:

```bash
# Stage changes
git add -A

# Commit with descriptive message
git commit -m "$(cat <<'EOF'
<type>: <description>

<body if needed>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"

# Push to trigger CI
git push origin main

# Verify workflows started
gh run list --limit 3
```

**Types**: `feat`, `fix`, `ci`, `docs`, `refactor`, `test`, `chore`

Workflows only run on GitHub after being committed and pushed. Local changes have no effect until pushed.

### SPM Build Fix Policy
The project uses **both** XcodeGen (for Xcode builds) and Package.swift (for SPM/CI builds). SPM builds may fail due to:

| Issue | Cause | Fix |
|-------|-------|-----|
| `multiple producers` | Duplicate file names in different folders | Rename files to be unique OR exclude from SPM target |
| `unhandled files` | Non-Swift files in source folders | Add to `resources` or `exclude` in Package.swift |
| `module not found` | Missing dependency | Add to Package.swift dependencies |

**Fix duplicate file errors:**
```bash
# Find duplicate file names
find Shared -name "*.swift" -exec basename {} \; | sort | uniq -d

# If duplicates found, either:
# 1. Rename files to be unique
# 2. Exclude from Package.swift:
#    .target(name: "TheaCore", ..., exclude: ["Path/To/Duplicate.swift"])
```

---

## Phase 0: Pre-Flight Checks & GitHub Setup

### 0.1 Tool Availability
```bash
# Check required tools
echo "=== Pre-flight Tool Check ==="
for tool in xcodebuild swiftlint swiftformat xcodegen gh; do
  if command -v $tool &>/dev/null; then
    echo "✓ $tool installed"
  else
    echo "✗ $tool MISSING - will install"
  fi
done

# Check optional tools (security & quality)
echo ""
echo "=== Optional Tools (Security & Quality) ==="
for tool in periphery gitleaks osv-scanner snyk mobsfscan; do
  if command -v $tool &>/dev/null; then
    echo "✓ $tool installed"
  else
    echo "○ $tool not installed (will skip related checks)"
  fi
done

# Check optional tools (testing & CI)
echo ""
echo "=== Optional Tools (Testing & CI) ==="
for tool in fastlane maestro codecov; do
  if command -v $tool &>/dev/null; then
    echo "✓ $tool installed"
  else
    echo "○ $tool not installed (will skip related checks)"
  fi
done

# Check Java (required for Maestro)
echo ""
echo "=== Java (for Maestro) ==="
if java -version 2>&1 | grep -q "17\|18\|19\|20\|21"; then
  echo "✓ Java 17+ installed"
else
  echo "○ Java 17+ not installed (Maestro unavailable)"
fi

# Check Docker (for MobSF full)
echo ""
echo "=== Container Runtime ==="
if command -v docker &>/dev/null; then
  echo "✓ Docker installed (MobSF available)"
else
  echo "○ Docker not installed (MobSF unavailable)"
fi
```

### 0.2 Simulator Availability
```bash
# List available simulators
echo "=== Available Simulators ==="
xcrun simctl list devices available | grep -E "(iPhone|Apple TV|Apple Watch)" | head -10

# Get first available iPhone simulator
IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
echo "Using iPhone simulator: $IPHONE_SIM"

# Get first available tvOS simulator
TV_SIM=$(xcrun simctl list devices available | grep "Apple TV" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
echo "Using tvOS simulator: $TV_SIM"
```

### 0.3 GitHub Repository Verification
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Verify git remote (use SSH for pushing)
echo "=== Git Remote ==="
git remote -v
if git remote -v | grep -q "https://"; then
  echo "Switching to SSH for push access..."
  git remote set-url origin git@github.com:Atchoum23/Thea.git
fi

# Verify GitHub CLI authentication
echo ""
echo "=== GitHub CLI ==="
if gh auth status &>/dev/null; then
  echo "✓ GitHub CLI authenticated"
else
  echo "✗ GitHub CLI not authenticated - run: gh auth login"
fi

# Check for uncommitted changes
echo ""
echo "=== Uncommitted Changes ==="
if [ -n "$(git status --porcelain)" ]; then
  echo "⚠ Uncommitted changes detected:"
  git status --short
else
  echo "✓ Working directory clean"
fi

# Verify workflows exist
echo ""
echo "=== GitHub Workflows ==="
ls -la .github/workflows/*.yml 2>/dev/null || echo "✗ No workflows found"

# Check last CI run status
echo ""
echo "=== Recent CI Runs ==="
gh run list --limit 3 2>/dev/null || echo "✗ Cannot fetch CI runs (gh not authenticated?)"
```

### 0.4 Fix SPM Duplicate Files (if needed)
```bash
# Check for duplicate Swift file names that break SPM
echo "=== Checking for duplicate file names ==="
DUPLICATES=$(find Shared -name "*.swift" -exec basename {} \; | sort | uniq -d)
if [ -n "$DUPLICATES" ]; then
  echo "⚠ DUPLICATE FILES FOUND (will break SPM build):"
  echo "$DUPLICATES"
  echo ""
  echo "Full paths:"
  for dup in $DUPLICATES; do
    find Shared -name "$dup"
  done
  echo ""
  echo "ACTION REQUIRED: Rename duplicates or add to Package.swift exclude list"
else
  echo "✓ No duplicate file names found"
fi
```

### 0.5 Kill Stale Processes
```bash
# Kill any zombie xcodebuild processes
pkill -9 xcodebuild 2>/dev/null || true
pkill -9 Simulator 2>/dev/null || true
```

---

## CRITICAL: Xcode GUI Interaction Guide

### Why Both CLI and GUI?
- **CLI (xcodebuild)**: Fast, scriptable, good for automation
- **GUI (Xcode.app)**: Shows additional warnings (indexer, project settings, capabilities)
- **BOTH ARE REQUIRED** because they can show DIFFERENT issues

### How to Trigger GUI Builds via AppleScript

```bash
# Switch scheme and build
osascript -e '
tell application "Xcode"
    activate
end tell
delay 0.5
tell application "System Events"
    tell process "Xcode"
        keystroke "0" using {control down}  -- Open scheme switcher
        delay 0.5
        keystroke "SCHEME_NAME"              -- Type scheme name
        delay 0.3
        keystroke return                     -- Select it
        delay 0.5
        keystroke "b" using {command down}   -- Build (Cmd+B)
    end tell
end tell
'
```

### Where Xcode GUI Stores Build Logs

**Location**: `~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build/`

**File format**: `*.xcactivitylog` (gzip-compressed)

### How to Read xcactivitylog Files

```bash
# Find the most recent log (modified in last N minutes)
LOG=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
  -name "*.xcactivitylog" -mmin -10 2>/dev/null | sort -r | head -1)

# Decompress and extract readable text
gunzip -c "$LOG" 2>/dev/null | strings > /tmp/build_log.txt

# Search for warnings
grep -E '\.swift:[0-9]+:[0-9]+: warning:' /tmp/build_log.txt | sort -u

# Search for errors
grep -E '\.swift:[0-9]+:[0-9]+: error:' /tmp/build_log.txt | sort -u

# Search for project-level warnings
grep -E '\.xcodeproj: warning:' /tmp/build_log.txt | sort -u

# Search for entitlement issues
grep -iE 'entitlement' /tmp/build_log.txt | sort -u
```

### Warning Types to Look For

| Warning Type | Pattern in Log | Where to Fix |
|--------------|----------------|--------------|
| Code warning | `File.swift:123:45: warning:` | Edit the Swift file |
| Project warning | `Thea.xcodeproj: warning:` | Edit `project.yml` then `xcodegen generate` |
| Entitlement warning | `entitlement.*not found` | Edit `.entitlements` file |
| Capability warning | `capability.*development only` | Remove from entitlements or request from Apple |
| Deprecated API | `was deprecated in iOS/macOS` | Use `#available` checks |

### Build Wait Times

- **Full build**: Wait 60-120 seconds after triggering
- **Incremental build**: Wait 15-30 seconds
- **Check completion**: Look for `Build Succeeded` or `Build Failed` in log

---

## Phase 1: CLI Build Cycle (Debug) + GUI Verification

### Objective
Fix all compilation errors and warnings in Debug configuration using BOTH CLI and GUI builds.

**CRITICAL**: CLI and GUI builds can show DIFFERENT warnings. You MUST do BOTH.

### Step 1A: CLI Builds (all 4 platforms)

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# iOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "generic/platform=iOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -allowProvisioningUpdates build 2>&1 | tee build_ios_debug.log

# macOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination "platform=macOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -allowProvisioningUpdates build 2>&1 | tee build_macos_debug.log

# watchOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-watchOS" \
  -destination "generic/platform=watchOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -allowProvisioningUpdates build 2>&1 | tee build_watchos_debug.log

# tvOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-tvOS" \
  -destination "generic/platform=tvOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -allowProvisioningUpdates build 2>&1 | tee build_tvos_debug.log
```

### Step 1B: GUI Builds via AppleScript (all 4 platforms)

**WHY**: Xcode GUI may show additional warnings not visible in CLI (indexer warnings, project settings warnings).

```bash
# Function to build a scheme in Xcode GUI
build_gui_scheme() {
  local SCHEME="$1"
  osascript -e "
tell application \"Xcode\"
    activate
end tell
delay 1
tell application \"System Events\"
    tell process \"Xcode\"
        -- Switch scheme (Ctrl+0)
        keystroke \"0\" using {control down}
        delay 0.5
        keystroke \"$SCHEME\"
        delay 0.3
        keystroke return
        delay 0.5
        -- Build (Cmd+B)
        keystroke \"b\" using {command down}
    end tell
end tell
"
  echo "Building $SCHEME in GUI... waiting for completion"
  sleep 90  # Wait for build (adjust based on project size)
}

# Build all 4 schemes
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  build_gui_scheme "$scheme"
done
```

### Step 1C: Read GUI Build Results from xcactivitylog

**CRITICAL**: This is how you get warnings/errors from the Xcode GUI.

```bash
# Find the most recent build log (within last 10 minutes)
find_latest_log() {
  find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
    -name "*.xcactivitylog" -mmin -10 2>/dev/null | sort -r | head -1
}

# Extract warnings and errors from the log
read_gui_log() {
  local LOG=$(find_latest_log)
  if [ -z "$LOG" ]; then
    echo "ERROR: No recent xcactivitylog found"
    return 1
  fi

  echo "=== Reading: $LOG ==="

  # Code warnings (file:line:col format)
  echo "--- Code Warnings ---"
  gunzip -c "$LOG" 2>/dev/null | strings | \
    grep -E '\.swift:[0-9]+:[0-9]+: warning:' | sort -u

  # Code errors
  echo "--- Code Errors ---"
  gunzip -c "$LOG" 2>/dev/null | strings | \
    grep -E '\.swift:[0-9]+:[0-9]+: error:' | sort -u

  # Project-level warnings
  echo "--- Project Warnings ---"
  gunzip -c "$LOG" 2>/dev/null | strings | \
    grep -E '\.xcodeproj: warning:' | sort -u

  # Entitlement warnings
  echo "--- Entitlement Warnings ---"
  gunzip -c "$LOG" 2>/dev/null | strings | \
    grep -iE 'entitlement.*warning|warning.*entitlement' | sort -u
}

# Run after each GUI build
read_gui_log
```

### Step 1D: Fix-Build Loop

1. Run CLI builds → Fix any errors/warnings
2. Run GUI builds → Read xcactivitylog
3. If GUI shows additional warnings → Fix them
4. Repeat until BOTH CLI and GUI show 0 warnings

### Extract Errors/Warnings from CLI Logs
```bash
# Count errors and warnings from CLI build logs
for log in build_*_debug.log; do
  echo "=== $log ==="
  errors=$(grep -c " error:" "$log" 2>/dev/null || echo "0")
  warnings=$(grep -c " warning:" "$log" 2>/dev/null || echo "0")
  echo "Errors: $errors, Warnings: $warnings"
done
```

### Step 1D: Fix Swift 6 Concurrency Issues

**CRITICAL**: Swift 6 strict concurrency issues MUST be fixed, including in test targets.

```bash
# Find all Swift 6 concurrency warnings/errors
grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe|implicitly asynchronous)" build_*.log | head -50
```

**Common Fixes:**

```swift
// 1. Static property not concurrency-safe
// BEFORE:
static let shared = MyClass()
// AFTER:
nonisolated(unsafe) static let shared = MyClass()
// OR make it a computed property:
static var shared: MyClass { MyClass() }

// 2. Capture of 'self' with non-Sendable type
// BEFORE:
Task { self.doSomething() }
// AFTER:
Task { @MainActor in self.doSomething() }
// OR:
Task { [weak self] in await MainActor.run { self?.doSomething() } }

// 3. Call to main-actor-isolated method
// BEFORE:
func process() { updateUI() }
// AFTER:
@MainActor func process() { updateUI() }
// OR:
func process() async { await MainActor.run { updateUI() } }

// 4. Non-sendable type in async context
// BEFORE:
class MyClass { }
// AFTER:
final class MyClass: Sendable { }
// OR (if mutation needed):
final class MyClass: @unchecked Sendable { }

// 5. Test classes with UI interactions
// BEFORE:
class MyTests: XCTestCase { func testUI() { } }
// AFTER:
@MainActor class MyTests: XCTestCase { func testUI() { } }
```

**For test target concurrency issues:**
1. Add `@MainActor` to test classes that test UI components
2. Use `await` for async operations in tests
3. Ensure mock objects conform to `Sendable` when needed

### Success Criteria
- [ ] All 4 schemes CLI: BUILD SUCCEEDED, 0 errors, 0 warnings
- [ ] All 4 schemes GUI: 0 errors, 0 warnings in xcactivitylog
- [ ] **BOTH** CLI and GUI must pass - not just one
- [ ] **ALL Swift 6 concurrency issues fixed** (including test targets)

---

## Phase 2: Release Build Cycle (CLI + GUI)

### Objective
Verify Release builds catch all optimization-related warnings using BOTH CLI and GUI.

### Step 2A: CLI Release Builds

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# iOS Release
xcodebuild -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "generic/platform=iOS" \
  -configuration Release ONLY_ACTIVE_ARCH=NO \
  -allowProvisioningUpdates build 2>&1 | tee build_ios_release.log

# macOS Release
xcodebuild -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination "platform=macOS" \
  -configuration Release ONLY_ACTIVE_ARCH=NO \
  -allowProvisioningUpdates build 2>&1 | tee build_macos_release.log

# watchOS Release
xcodebuild -project Thea.xcodeproj -scheme "Thea-watchOS" \
  -destination "generic/platform=watchOS" \
  -configuration Release ONLY_ACTIVE_ARCH=NO \
  -allowProvisioningUpdates build 2>&1 | tee build_watchos_release.log

# tvOS Release
xcodebuild -project Thea.xcodeproj -scheme "Thea-tvOS" \
  -destination "generic/platform=tvOS" \
  -configuration Release ONLY_ACTIVE_ARCH=NO \
  -allowProvisioningUpdates build 2>&1 | tee build_tvos_release.log
```

### Step 2B: GUI Release Builds

**NOTE**: The schemes are already configured to use the appropriate build configuration. When you build via CLI with `-configuration Release`, the GUI will also build Release when you trigger Cmd+B (it uses the last selected configuration). Alternatively, use Product → Scheme → Edit Scheme to verify.

```bash
# Build each scheme in GUI (same as Debug - schemes handle configuration)
for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  build_gui_scheme "$scheme"
  sleep 90
  read_gui_log
done
```

**To manually verify/switch to Release in GUI**:
1. Product → Scheme → Edit Scheme (Cmd+Shift+,)
2. Select "Run" in left sidebar
3. Change "Build Configuration" dropdown to "Release"
4. Close and build (Cmd+B)

### Step 2C: Read Release Build Logs

Use the same `read_gui_log` function from Phase 1 to extract warnings from xcactivitylog.

### Success Criteria
- [ ] All 4 schemes CLI Release: BUILD SUCCEEDED, 0 warnings
- [ ] All 4 schemes GUI Release: 0 warnings in xcactivitylog
- [ ] No optimization-related warnings
- [ ] **BOTH** CLI and GUI Release builds must pass

---

## Phase 3: Static Analysis & Linting

### 3.1 SwiftLint

```bash
# Install if needed
command -v swiftlint &>/dev/null || brew install swiftlint

# Run analysis
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
swiftlint lint --reporter json > swiftlint_report.json 2>&1

# Count violations
VIOLATIONS=$(swiftlint lint 2>&1 | grep -cE "(warning|error):" || echo "0")
echo "SwiftLint violations: $VIOLATIONS"

# Show violations
swiftlint lint 2>&1 | grep -E "(warning|error):" | head -50
```

**Fix all violations** or add justified disable comments.

### 3.2 SwiftFormat

```bash
# Install if needed
command -v swiftformat &>/dev/null || brew install swiftformat

# Check formatting issues (dry run)
swiftformat --lint . 2>&1 | head -50

# Auto-fix formatting
swiftformat . 2>&1
```

### 3.3 Periphery (Dead Code Detection) - OPTIONAL

```bash
# Install if needed (skip if fails)
if ! command -v periphery &>/dev/null; then
  brew install peripheryapp/periphery/periphery 2>/dev/null || echo "Skipping Periphery (install failed)"
fi

# Run if available
if command -v periphery &>/dev/null; then
  periphery scan --project Thea.xcodeproj \
    --schemes "Thea-iOS,Thea-macOS" \
    --targets "Thea-iOS,Thea-macOS" 2>&1 | tee periphery_report.txt
fi
```

### 3.4 SonarCloud Analysis - OPTIONAL

```bash
# Only run if token is set
if [ -n "$SONAR_TOKEN" ]; then
  brew install sonar-scanner 2>/dev/null
  sonar-scanner \
    -Dsonar.projectKey=thea \
    -Dsonar.sources=. \
    -Dsonar.host.url=https://sonarcloud.io \
    -Dsonar.login=$SONAR_TOKEN
else
  echo "SKIP: SonarCloud (SONAR_TOKEN not set)"
fi
```

### 3.5 DeepSource Analysis - OPTIONAL

```bash
# DeepSource analyzes via GitHub integration - no CLI needed
# Ensure .deepsource.toml exists in repo root
if [ ! -f .deepsource.toml ]; then
  cat > .deepsource.toml << 'TOML'
version = 1

[[analyzers]]
name = "swift"
enabled = true

  [analyzers.meta]
  swift_version = "6.0"

[[transformers]]
name = "swiftformat"
enabled = true
TOML
  echo "Created .deepsource.toml - DeepSource will analyze on next push"
else
  echo "DeepSource configured (.deepsource.toml exists)"
fi
```

### 3.6 Codecov Integration - OPTIONAL

```bash
# Codecov uploads coverage from test results
if [ -n "$CODECOV_TOKEN" ]; then
  # Ensure coverage was generated from Phase 4
  if [ -f coverage.json ]; then
    # Install codecov CLI if needed
    command -v codecov &>/dev/null || brew install codecov

    # Upload coverage
    codecov --token $CODECOV_TOKEN \
      --file coverage.json \
      --flags unittests \
      --name "Thea-$(date +%Y%m%d)"
    echo "Codecov: Coverage uploaded"
  else
    echo "Codecov: No coverage.json found (run tests first)"
  fi
else
  echo "SKIP: Codecov (CODECOV_TOKEN not set)"
fi
```

### Success Criteria
- [ ] SwiftLint: 0 errors, minimal warnings (justified)
- [ ] SwiftFormat: All files formatted
- [ ] Periphery: Review dead code (optional)
- [ ] SonarCloud: Quality gate passed (if configured)
- [ ] DeepSource: .deepsource.toml configured
- [ ] Codecov: Coverage uploaded (if tests exist and token set)

---

## Phase 4: Unit & Integration Testing - CONDITIONAL

### Check if Tests Exist
```bash
# Check for test targets
TEST_TARGETS=$(xcodebuild -project Thea.xcodeproj -list 2>/dev/null | grep -i "test" || echo "")
if [ -z "$TEST_TARGETS" ]; then
  echo "SKIP: No test targets found"
  exit 0
fi
```

### 4.1 Run XCTest Suite

```bash
# Get available iPhone simulator
IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone" | grep -v unavailable | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

# iOS Tests
xcodebuild test \
  -project Thea.xcodeproj \
  -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$IPHONE_SIM" \
  -resultBundlePath TestResults/iOS.xcresult 2>&1 | tee test_ios.log

# macOS Tests
xcodebuild test \
  -project Thea.xcodeproj \
  -scheme "Thea-macOS" \
  -destination "platform=macOS" \
  -resultBundlePath TestResults/macOS.xcresult 2>&1 | tee test_macos.log
```

### 4.2 Code Coverage Report

```bash
# Generate coverage report (if tests ran)
if [ -d "TestResults/iOS.xcresult" ]; then
  xcrun xccov view --report TestResults/iOS.xcresult --json > coverage.json
  xcrun xccov view --report TestResults/iOS.xcresult | grep -E "^[A-Za-z]" | head -20
fi
```

### Success Criteria
- [ ] All unit tests pass (0 failures) OR no tests exist
- [ ] Code coverage reported (if tests exist)

---

## Phase 5: UI Automation Testing - CONDITIONAL

### Check Prerequisites
```bash
# Check if UI test target exists
UI_TEST_TARGET=$(xcodebuild -project Thea.xcodeproj -list 2>/dev/null | grep -i "uitest" || echo "")
if [ -z "$UI_TEST_TARGET" ]; then
  echo "SKIP: No UI test targets found"
  exit 0
fi
```

### 5.1 XCUITest

```bash
IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone" | grep -v unavailable | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

xcodebuild test \
  -project Thea.xcodeproj \
  -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$IPHONE_SIM" \
  -only-testing:TheaUITests 2>&1 | tee test_ui.log
```

### 5.2 Maestro E2E Testing - OPTIONAL

Maestro provides simple YAML-based UI testing for iOS/Android.

**Prerequisites:**
- Java 17+ (Maestro requires JVM)
- iOS Simulator running

**Setup Maestro:**
```bash
# Install Java 17 if not present
if ! java -version 2>&1 | grep -q "17\|18\|19\|20\|21"; then
  brew install openjdk@17
  export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
fi

# Install Maestro CLI
if ! command -v maestro &>/dev/null; then
  curl -Ls "https://get.maestro.mobile.dev" | bash
fi

# Add to PATH
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH:$HOME/.maestro/bin"

# Verify installation
maestro --version
```

**Create Test Flows Directory:**
```bash
mkdir -p .maestro

# Create sample flow
cat > .maestro/launch_flow.yaml << 'YAML'
appId: app.theathe.ios
---
- launchApp
- assertVisible: "Thea"
- takeScreenshot: launch_screen
YAML

cat > .maestro/navigation_flow.yaml << 'YAML'
appId: app.theathe.ios
---
- launchApp
- tapOn: "Settings"
- assertVisible: "Preferences"
- tapOn:
    id: "back_button"
- assertVisible: "Home"
YAML

echo "Created Maestro test flows in .maestro/"
```

**Run Maestro Tests (Simulator):**
```bash
if command -v maestro &>/dev/null; then
  # Boot simulator if not running
  IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone 16" | grep -v unavailable | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
  xcrun simctl boot "$IPHONE_SIM" 2>/dev/null || true

  # Install app on simulator (must be built first)
  APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug-iphonesimulator -name "Thea.app" | head -1)
  if [ -n "$APP_PATH" ]; then
    xcrun simctl install "$IPHONE_SIM" "$APP_PATH"

    # Run all Maestro flows
    maestro test .maestro/ 2>&1 | tee maestro_results.log
  else
    echo "Build iOS app first before running Maestro tests"
  fi
else
  echo "SKIP: Maestro not installed"
fi
```

**Maestro Cloud (CI/CD - Optional):**
```bash
# For CI/CD, use Maestro Cloud (requires account)
# maestro cloud --apiKey $MAESTRO_API_KEY .maestro/
echo "Maestro Cloud: https://cloud.maestro.mobile.dev"
```

> **Note**: Maestro on real iOS devices requires a Mac, Xcode, Apple Developer account, and proper provisioning. For CI/CD, use Maestro Cloud or iOS Simulators.

### Success Criteria
- [ ] All XCUITests pass OR no UI tests exist
- [ ] Maestro flows pass OR not configured

---

## Phase 6: Security Audit - OPTIONAL

### 6.1 Dependency Vulnerability Scan

```bash
# Check Swift Package dependencies
swift package show-dependencies 2>/dev/null || echo "No Package.swift found"

# Scan for vulnerabilities (if osv-scanner available)
if command -v osv-scanner &>/dev/null; then
  osv-scanner --lockfile Package.resolved 2>&1 | tee security_deps.log
else
  echo "SKIP: osv-scanner not installed"
fi
```

### 6.2 Secrets Detection

```bash
# Install if not present
command -v gitleaks &>/dev/null || brew install gitleaks 2>/dev/null

# Scan for secrets
if command -v gitleaks &>/dev/null; then
  gitleaks detect --source . --verbose 2>&1 | tee security_secrets.log

  # Check result
  if grep -q "leaks found" security_secrets.log; then
    echo "WARNING: Secrets detected! Review security_secrets.log"
  else
    echo "✓ No secrets found"
  fi
else
  echo "SKIP: gitleaks not installed"
fi
```

### 6.3 MobSF Security Scan - OPTIONAL

MobSF (Mobile Security Framework) performs comprehensive static and dynamic analysis of iOS/Android apps.

**Setup MobSF (Docker - Recommended):**
```bash
# Install Docker if not present
if ! command -v docker &>/dev/null; then
  echo "Docker not installed. Install from https://www.docker.com/products/docker-desktop/"
  echo "SKIP: MobSF requires Docker"
else
  # Pull and run MobSF
  docker pull opensecurity/mobile-security-framework-mobsf:latest

  # Start MobSF (runs on port 8000)
  docker run -d --name mobsf -p 8000:8000 \
    opensecurity/mobile-security-framework-mobsf:latest

  echo "MobSF running at http://localhost:8000"
  echo "Default credentials: mobsf/mobsf"

  # Wait for startup
  sleep 10
fi
```

**Upload IPA for Analysis:**
```bash
# Build IPA first (requires signing)
if [ -f "build/Thea.ipa" ]; then
  # Use MobSF REST API for automated scanning
  MOBSF_API_KEY=$(curl -s http://localhost:8000/api/v1/api_key | jq -r '.api_key')

  # Upload IPA
  curl -F "file=@build/Thea.ipa" \
    -H "Authorization: $MOBSF_API_KEY" \
    http://localhost:8000/api/v1/upload

  echo "IPA uploaded to MobSF. View analysis at http://localhost:8000"
else
  echo "No IPA found. Build with: xcodebuild archive -exportOptionsPlist..."
fi
```

**Alternative: mobsfscan for Source Code (No Docker):**
```bash
# Install mobsfscan (CLI tool for source code scanning)
pip3 install mobsfscan || pip install mobsfscan

# Scan Swift source code
if command -v mobsfscan &>/dev/null; then
  mobsfscan --json -o mobsf_source_scan.json . 2>&1 | tee mobsf_scan.log
  echo "Source scan complete. Results in mobsf_source_scan.json"
else
  echo "SKIP: mobsfscan not installed"
fi
```

### 6.4 Snyk Security Scan - OPTIONAL

Snyk provides dependency vulnerability scanning with Swift/CocoaPods support.

```bash
# Install Snyk CLI
if ! command -v snyk &>/dev/null; then
  npm install -g snyk 2>/dev/null || brew install snyk 2>/dev/null
fi

if command -v snyk &>/dev/null; then
  # Authenticate (requires SNYK_TOKEN env var or interactive login)
  if [ -n "$SNYK_TOKEN" ]; then
    snyk auth $SNYK_TOKEN
  fi

  # Test dependencies
  snyk test --all-projects 2>&1 | tee snyk_report.log

  # Monitor for ongoing alerts (optional)
  # snyk monitor --all-projects
else
  echo "SKIP: Snyk not installed"
fi
```

### 6.5 Codacy Integration - OPTIONAL

Codacy provides automated code reviews via GitHub integration.

```bash
# Codacy runs via GitHub App - no CLI needed
# Create configuration file
if [ ! -f .codacy.yml ]; then
  cat > .codacy.yml << 'YAML'
---
engines:
  swiftlint:
    enabled: true
  metrics:
    enabled: true
  duplication:
    enabled: true

exclude_paths:
  - "Pods/**"
  - "**/Generated/**"
  - "**/*.generated.swift"
  - "DerivedData/**"

languages:
  swift:
    extensions:
      - ".swift"
YAML
  echo "Created .codacy.yml - Enable Codacy at https://app.codacy.com"
else
  echo "Codacy already configured (.codacy.yml exists)"
fi
```

### 6.6 macOS-Specific Security Analysis

**Note**: MobSF primarily targets mobile apps. For macOS apps, use these complementary tools:

```bash
# 1. codesign verification
echo "=== Code Signing Verification ==="
codesign -dv --verbose=4 ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Release/Thea.app 2>&1 | head -20

# 2. Check for hardened runtime
echo ""
echo "=== Hardened Runtime Check ==="
codesign --display --entitlements - ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Release/Thea.app 2>&1 | head -30

# 3. Check sandbox entitlements
echo ""
echo "=== Sandbox Status ==="
grep -l "app-sandbox" macOS/Thea.entitlements && echo "✓ Sandbox enabled" || echo "⚠ Sandbox not enabled"

# 4. Binary analysis with otool
echo ""
echo "=== Binary Dependencies ==="
otool -L ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Release/Thea.app/Contents/MacOS/Thea 2>/dev/null | head -20
```

**For comprehensive macOS security:**
- Use **SonarQube/SonarCloud** for static analysis (already configured)
- Use **Snyk** for dependency vulnerabilities (Section 6.4)
- Use **gitleaks** for secrets detection (Section 6.2)
- Consider **Katalina** (open-source macOS-specific static analysis) for deep binary analysis

### 6.7 Cross-Platform Testing Note

| Platform | Security Tool | UI Testing Tool |
|----------|---------------|-----------------|
| **iOS** | MobSF, mobsfscan | XCUITest, Maestro |
| **macOS** | SonarCloud, Snyk, codesign | XCUITest, Appium |
| **watchOS** | Same as iOS (shared code) | XCUITest (limited) |
| **tvOS** | Same as iOS (shared code) | XCUITest |

**Appium for macOS** (alternative to Maestro for desktop):
```bash
# Install Appium (if not using Maestro)
npm install -g appium
appium driver install mac2

# Appium can automate macOS apps via XCUITest driver
# See: https://appium.io/docs/en/drivers/mac2/
```

### Success Criteria
- [ ] No hardcoded secrets
- [ ] No critical vulnerable dependencies
- [ ] MobSF scan: No critical/high severity issues (if Docker available)
- [ ] Snyk: No high/critical vulnerabilities (if token set)
- [ ] macOS code signing verified
- [ ] Hardened runtime enabled

---

## Phase 7: Performance & Memory Analysis - OPTIONAL

### 7.1 Build Size Analysis

```bash
# Check app size from build products
find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products -name "*.app" -exec du -sh {} \; 2>/dev/null | head -10
```

### Success Criteria
- [ ] App sizes reasonable (< 100MB each)

---

## Phase 8: Accessibility Audit - OPTIONAL

### 8.1 Basic Accessibility Check

```bash
# This phase requires running UI tests with accessibility audit
# Skip if no UI tests exist
echo "Accessibility audit requires UI test target with performAccessibilityAudit()"
```

### Success Criteria
- [ ] Accessibility audit integrated into UI tests (if they exist)

---

## Phase 9: CI/CD Pipeline Setup

**CRITICAL**: Workflow changes MUST be committed and pushed to take effect on GitHub.

### 9.1 Create GitHub Actions Workflow

```bash
mkdir -p .github/workflows

cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  DEVELOPER_DIR: /Applications/Xcode_16.app/Contents/Developer

jobs:
  build-and-test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for SonarCloud

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Install Tools
        run: |
          brew install xcodegen swiftlint swiftformat

      - name: Generate project
        run: xcodegen generate

      - name: SwiftLint
        run: swiftlint lint --strict --reporter json > swiftlint-report.json || true

      - name: Build iOS
        run: |
          xcodebuild build \
            -project Thea.xcodeproj \
            -scheme "Thea-iOS" \
            -destination "generic/platform=iOS" \
            -configuration Release \
            ONLY_ACTIVE_ARCH=NO

      - name: Build macOS
        run: |
          xcodebuild build \
            -project Thea.xcodeproj \
            -scheme "Thea-macOS" \
            -destination "platform=macOS" \
            -configuration Release \
            ONLY_ACTIVE_ARCH=NO

      - name: Build watchOS
        run: |
          xcodebuild build \
            -project Thea.xcodeproj \
            -scheme "Thea-watchOS" \
            -destination "generic/platform=watchOS" \
            -configuration Release \
            ONLY_ACTIVE_ARCH=NO

      - name: Build tvOS
        run: |
          xcodebuild build \
            -project Thea.xcodeproj \
            -scheme "Thea-tvOS" \
            -destination "generic/platform=tvOS" \
            -configuration Release \
            ONLY_ACTIVE_ARCH=NO

      - name: Run Tests (iOS)
        run: |
          xcodebuild test \
            -project Thea.xcodeproj \
            -scheme "Thea-iOS" \
            -destination "platform=iOS Simulator,name=iPhone 16" \
            -resultBundlePath TestResults/iOS.xcresult \
            -enableCodeCoverage YES || true

      - name: Generate Coverage Report
        run: |
          if [ -d "TestResults/iOS.xcresult" ]; then
            xcrun xccov view --report TestResults/iOS.xcresult --json > coverage.json
          fi

  # SonarCloud Analysis
  sonarcloud:
    runs-on: ubuntu-latest
    needs: build-and-test
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        with:
          args: >
            -Dsonar.projectKey=thea-app
            -Dsonar.organization=your-org
            -Dsonar.sources=.
            -Dsonar.swift.coverage.reportPaths=coverage.json

  # Codecov Upload
  codecov:
    runs-on: macos-14
    needs: build-and-test
    steps:
      - uses: actions/checkout@v4

      - name: Download Coverage
        uses: actions/download-artifact@v4
        with:
          name: coverage-report
        continue-on-error: true

      - name: Upload to Codecov
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: coverage.json
          flags: unittests
          fail_ci_if_error: false

  # DeepSource Analysis (runs automatically via GitHub integration)
  # Ensure .deepsource.toml exists in repo root
EOF

echo "✓ Created .github/workflows/ci.yml"
```

### 9.1.1 REQUIRED: Commit and Push ALL Changes

**Workflows do NOT run until pushed to GitHub.** Execute this after ANY changes:

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Check what changed
git status

# Stage ALL changes (workflows, source, config)
git add -A

# Commit with descriptive message
git commit -m "$(cat <<'EOF'
ci: update workflows and fix build issues

- Update GitHub Actions for all 4 platforms
- Fix any SPM/Xcode build issues
- Add security scanning integration

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"

# Push (use SSH remote)
git push origin main

# Verify workflows started
echo "=== Verifying CI Started ==="
sleep 5
gh run list --limit 3
```

**Verify workflows are running:**
1. `gh run list --limit 5` - Check CLI
2. Visit: https://github.com/Atchoum23/Thea/actions
3. If not visible, check Settings → Actions → General → Workflow permissions

### 9.2 Existing GitHub Workflows (Already Configured)

The repository has these workflows in `.github/workflows/`:

| Workflow | File | Purpose |
|----------|------|---------|
| **CI** | `ci.yml` | SwiftLint, build all 4 platforms, tests, coverage |
| **Release** | `release.yml` | Create GitHub releases on tag push |
| **Security Audit (Full)** | `thea-audit-main.yml` | Full security scan on main branch |
| **Security Audit (PR)** | `thea-audit-pr.yml` | Security scan on pull requests |
| **Dependencies** | `dependencies.yml` | Validate SPM dependencies |

**To verify all workflows exist:**
```bash
ls -la .github/workflows/
```

### 9.3 Add MobSF Security Scanning Workflow

```bash
cat > .github/workflows/security-mobsf.yml << 'EOF'
name: MobSF Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  mobsf-scan:
    name: MobSF Source Code Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install mobsfscan
        run: pip install mobsfscan

      - name: Run mobsfscan
        run: |
          mobsfscan --json -o mobsf-results.json . || true
          mobsfscan . || true

      - name: Upload MobSF Results
        uses: actions/upload-artifact@v4
        with:
          name: mobsf-security-report
          path: mobsf-results.json
          if-no-files-found: ignore
EOF
echo "✓ Created security-mobsf.yml"
```

### 9.4 Add Maestro E2E Testing Workflow

```bash
cat > .github/workflows/maestro-e2e.yml << 'EOF'
name: Maestro E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  maestro-ios:
    name: Maestro iOS E2E
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Setup Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.2.app

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Project
        run: xcodegen generate

      - name: Build iOS for Simulator
        run: |
          xcodebuild build \
            -project Thea.xcodeproj \
            -scheme "Thea-iOS" \
            -destination "platform=iOS Simulator,name=iPhone 16" \
            -configuration Debug \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO

      - name: Install Maestro
        run: |
          curl -Ls "https://get.maestro.mobile.dev" | bash
          echo "$HOME/.maestro/bin" >> $GITHUB_PATH

      - name: Boot Simulator
        run: |
          xcrun simctl boot "iPhone 16" || true
          xcrun simctl list devices booted

      - name: Install App on Simulator
        run: |
          APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Thea.app" -path "*/Debug-iphonesimulator/*" | head -1)
          xcrun simctl install booted "$APP_PATH"

      - name: Run Maestro Tests
        run: |
          export PATH="$PATH:$HOME/.maestro/bin"
          maestro test .maestro/ --format junit --output maestro-results.xml || true
        continue-on-error: true

      - name: Upload Maestro Results
        uses: actions/upload-artifact@v4
        with:
          name: maestro-test-results
          path: maestro-results.xml
          if-no-files-found: ignore
EOF
echo "✓ Created maestro-e2e.yml"
```

### 9.5 Create Fastlane Config (Optional)

```bash
if command -v fastlane &>/dev/null; then
  mkdir -p fastlane

  cat > fastlane/Fastfile << 'EOF'
default_platform(:ios)

platform :ios do
  desc "Build iOS app"
  lane :build do
    build_app(
      scheme: "Thea-iOS",
      configuration: "Release",
      skip_archive: true
    )
  end

  desc "Run SwiftLint"
  lane :lint do
    swiftlint(strict: true, raise_if_swiftlint_error: true)
  end
end
EOF

  echo "✓ Created fastlane/Fastfile"
else
  echo "SKIP: Fastlane not installed"
fi
```

### Success Criteria
- [ ] GitHub Actions workflow file created
- [ ] Fastlane configured (if installed)

---

## Phase 10: Final Verification Checklist

### Generate Summary Report

```bash
cat > QA_SUMMARY.md << EOF
# QA Summary Report
Generated: $(date)

## CLI Build Status
| Platform | Debug CLI | Release CLI |
|----------|-----------|-------------|
| iOS | $(grep -q "BUILD SUCCEEDED" build_ios_debug.log 2>/dev/null && echo "✅" || echo "❌") | $(grep -q "BUILD SUCCEEDED" build_ios_release.log 2>/dev/null && echo "✅" || echo "❌") |
| macOS | $(grep -q "BUILD SUCCEEDED" build_macos_debug.log 2>/dev/null && echo "✅" || echo "❌") | $(grep -q "BUILD SUCCEEDED" build_macos_release.log 2>/dev/null && echo "✅" || echo "❌") |
| watchOS | $(grep -q "BUILD SUCCEEDED" build_watchos_debug.log 2>/dev/null && echo "✅" || echo "❌") | $(grep -q "BUILD SUCCEEDED" build_watchos_release.log 2>/dev/null && echo "✅" || echo "❌") |
| tvOS | $(grep -q "BUILD SUCCEEDED" build_tvos_debug.log 2>/dev/null && echo "✅" || echo "❌") | $(grep -q "BUILD SUCCEEDED" build_tvos_release.log 2>/dev/null && echo "✅" || echo "❌") |

## GUI Build Status (from xcactivitylog)
| Platform | Debug GUI | Release GUI |
|----------|-----------|-------------|
| iOS | ⬜ Verify manually | ⬜ Verify manually |
| macOS | ⬜ Verify manually | ⬜ Verify manually |
| watchOS | ⬜ Verify manually | ⬜ Verify manually |
| tvOS | ⬜ Verify manually | ⬜ Verify manually |

**GUI verification**: Run \`read_gui_log\` after each GUI build to check for warnings in xcactivitylog.

## Code Quality
- SwiftLint: $([ -f swiftlint_report.json ] && echo "✅ Report generated" || echo "⏭ Skipped")
- SwiftFormat: ✅ Applied
- Periphery: $([ -f periphery_report.txt ] && echo "✅ Report generated" || echo "⏭ Skipped")

## Code Analysis Services
- SonarCloud: $([ -n "\$SONAR_TOKEN" ] && echo "✅ Configured" || echo "⏭ Token not set")
- DeepSource: $([ -f .deepsource.toml ] && echo "✅ Configured" || echo "⏭ Missing .deepsource.toml")
- Codecov: $([ -n "\$CODECOV_TOKEN" ] && echo "✅ Configured" || echo "⏭ Token not set")
- Codacy: $([ -f .codacy.yml ] && echo "✅ Configured" || echo "⏭ Missing .codacy.yml")

## Security
- Secrets scan (gitleaks): $([ -f security_secrets.log ] && echo "✅ Completed" || echo "⏭ Skipped")
- Dependency scan (osv-scanner): $([ -f security_deps.log ] && echo "✅ Completed" || echo "⏭ Skipped")
- MobSF scan: $([ -f mobsf_source_scan.json ] && echo "✅ Completed" || echo "⏭ Skipped (Docker required)")
- Snyk scan: $([ -f snyk_report.log ] && echo "✅ Completed" || echo "⏭ Skipped")

## Testing
- XCUITest: $([ -f test_ui.log ] && echo "✅ Completed" || echo "⏭ No UI tests")
- Maestro E2E: $([ -f maestro_results.log ] && echo "✅ Completed" || echo "⏭ Not configured")

## CI/CD
- GitHub Actions: $([ -f .github/workflows/ci.yml ] && echo "✅ Configured" || echo "❌ Missing")
- Fastlane: $([ -f fastlane/Fastfile ] && echo "✅ Configured" || echo "⏭ Not installed")
EOF

echo "✓ Generated QA_SUMMARY.md"
cat QA_SUMMARY.md
```

### Final Checklist

#### CLI Build Verification (REQUIRED)
- [ ] iOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] iOS Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] macOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] macOS Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] watchOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] watchOS Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] tvOS Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] tvOS Release CLI: BUILD SUCCEEDED, 0 warnings

#### GUI Build Verification (REQUIRED)
- [ ] iOS Debug GUI: 0 warnings in xcactivitylog
- [ ] iOS Release GUI: 0 warnings in xcactivitylog
- [ ] macOS Debug GUI: 0 warnings in xcactivitylog
- [ ] macOS Release GUI: 0 warnings in xcactivitylog
- [ ] watchOS Debug GUI: 0 warnings in xcactivitylog
- [ ] watchOS Release GUI: 0 warnings in xcactivitylog
- [ ] tvOS Debug GUI: 0 warnings in xcactivitylog
- [ ] tvOS Release GUI: 0 warnings in xcactivitylog

#### Code Quality (REQUIRED)
- [ ] SwiftLint: 0 errors
- [ ] SwiftFormat: Applied

#### Security (RECOMMENDED)
- [ ] No secrets in code
- [ ] No critical vulnerabilities

#### CI/CD (REQUIRED)
- [ ] GitHub Actions workflow created
- [ ] All changes committed to Git
- [ ] Changes pushed to remote repository
- [ ] GitHub Actions workflow triggered and passing

### 10.1 MANDATORY: Final Git Push

**All QA work is incomplete until changes are committed and pushed to GitHub.**

```bash
# Stage all changes
git add -A

# Commit with descriptive message
git commit -m "fix: QA build fixes - zero warnings across all platforms

- Fixed all Swift 6 concurrency warnings
- Resolved SwiftLint violations
- Applied SwiftFormat formatting
- All 4 platforms (iOS, macOS, watchOS, tvOS) build clean

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to remote (use SSH)
git push origin main

# Verify GitHub Actions triggered
echo "✓ Changes pushed. Verify CI at: https://github.com/Atchoum23/Thea/actions"
```

### 10.2 Verify GitHub Actions

```bash
# Check workflow status (requires gh CLI)
if command -v gh &> /dev/null; then
  echo "Checking GitHub Actions status..."
  gh run list --limit 3

  # Get latest run status
  LATEST_RUN=$(gh run list --limit 1 --json status,conclusion,name -q '.[0]')
  echo "Latest run: $LATEST_RUN"
else
  echo "Install gh CLI: brew install gh"
  echo "Or check manually: https://github.com/Atchoum23/Thea/actions"
fi
```

---

## Tool Installation Summary

```bash
# Required tools
brew install swiftlint swiftformat xcodegen

# Recommended tools
brew install gitleaks fastlane

# Optional tools (install as needed)
brew install peripheryapp/periphery/periphery
brew install osv-scanner
```

---

## Autonomous Execution Notes

### MANDATORY Behaviors
1. **Execute phases sequentially** (0→10) - Don't skip ahead
2. **Fix errors immediately** - Each phase must pass before proceeding
3. **Use TodoWrite** - Track progress after EVERY phase and sub-task
4. **Log all fixes** - Append to `QA_FIXES_LOG.md`
5. **ALL 4 PLATFORMS ARE REQUIRED** - iOS, macOS, watchOS, tvOS must ALL pass
6. **Generate reports** - Save all outputs for review
7. **COMMIT AND PUSH ALL CHANGES** - Work is not complete until pushed to GitHub
8. **VERIFY GITHUB ACTIONS** - Confirm CI workflows are triggered and passing

### CRITICAL: CLI + GUI Requirement
7. **MUST use BOTH CLI and GUI builds** - They show different warnings
8. **CLI build**: Use `xcodebuild` commands
9. **GUI build**: Use AppleScript to trigger Xcode.app builds
10. **Read GUI results**: Parse `xcactivitylog` files from DerivedData
11. **Fix ALL warnings from BOTH sources** - Mission fails if either has warnings

### Error Handling
12. **If a build fails** → Read the error, fix the code, rebuild that scheme only
13. **If a warning appears** → Fix it unless it's from an SPM package
14. **If xcodegen needed** → Run `xcodegen generate` after modifying `project.yml`
15. **If provisioning fails** → Use `-allowProvisioningUpdates` flag (already included)
16. **If GUI shows warnings CLI didn't** → Those are real warnings, fix them
17. **If git push fails** → Switch to SSH remote: `git remote set-url origin git@github.com:Atchoum23/Thea.git`
18. **If GitHub Actions not running** → Verify workflow was pushed and check `.github/workflows/` exists on remote

### Skip Conditions (OPTIONAL phases only)
17. **Skip gracefully** - If a tool is unavailable for optional phases, log and continue
18. **Don't block on optional phases** - Mark as skipped and proceed
19. **NEVER skip required phases (1, 2, 3)** - These MUST pass
20. **NEVER skip GUI builds** - CLI-only is NOT acceptable

### Completion Criteria
The mission is ONLY complete when:
- [ ] All 4 Debug CLI builds: BUILD SUCCEEDED, 0 warnings
- [ ] All 4 Debug GUI builds: 0 warnings in xcactivitylog
- [ ] All 4 Release CLI builds: BUILD SUCCEEDED, 0 warnings
- [ ] All 4 Release GUI builds: 0 warnings in xcactivitylog
- [ ] SwiftLint: 0 errors
- [ ] QA_SUMMARY.md generated with all ✅
- [ ] **All changes committed and pushed to GitHub**
- [ ] **GitHub Actions CI workflow triggered successfully**

---

## Files Generated

| File | Purpose |
|------|---------|
| `build_*_debug.log` | Debug build outputs |
| `build_*_release.log` | Release build outputs |
| `swiftlint_report.json` | Linting results |
| `periphery_report.txt` | Dead code analysis |
| `security_secrets.log` | Secrets scan results |
| `security_deps.log` | Dependency vulnerabilities |
| `QA_FIXES_LOG.md` | All fixes applied |
| `QA_SUMMARY.md` | Final summary report |
| `.github/workflows/ci.yml` | CI pipeline |
| `fastlane/Fastfile` | Automation lanes |
| `.deepsource.toml` | DeepSource config |
| `.codacy.yml` | Codacy config |
| `.maestro/*.yaml` | Maestro test flows |
| `mobsf_source_scan.json` | MobSF scan results |
| `snyk_report.log` | Snyk vulnerability report |
| `maestro_results.log` | Maestro test results |

---

## Appendix: Complete Tools Reference

### Build & Code Quality Tools

| Tool | Purpose | Install | Required |
|------|---------|---------|----------|
| **xcodebuild** | Build iOS/macOS/watchOS/tvOS | Xcode | ✅ Yes |
| **XcodeGen** | Generate Xcode project from YAML | `brew install xcodegen` | ✅ Yes |
| **SwiftLint** | Swift linting & style | `brew install swiftlint` | ✅ Yes |
| **SwiftFormat** | Code formatting | `brew install swiftformat` | ✅ Yes |
| **Periphery** | Dead code detection | `brew install peripheryapp/periphery/periphery` | Optional |

### Code Analysis Services (GitHub Integration)

| Service | Purpose | Setup | Token Required |
|---------|---------|-------|----------------|
| **SonarCloud** | Code quality & security | GitHub App + `SONAR_TOKEN` | Yes |
| **DeepSource** | AI code review | GitHub App + `.deepsource.toml` | No (GitHub App) |
| **Codecov** | Code coverage tracking | GitHub App + `CODECOV_TOKEN` | Yes |
| **Codacy** | Automated code review | GitHub App + `.codacy.yml` | No (GitHub App) |

### Security Tools

| Tool | Purpose | Install | Docker Required |
|------|---------|---------|-----------------|
| **MobSF** | Mobile app security (SAST/DAST) | `docker pull opensecurity/mobile-security-framework-mobsf` | Yes |
| **mobsfscan** | Source code security scan | `pip install mobsfscan` | No |
| **Snyk** | Dependency vulnerabilities | `brew install snyk` | No |
| **gitleaks** | Secrets detection | `brew install gitleaks` | No |
| **osv-scanner** | OSS vulnerability scanner | `brew install osv-scanner` | No |

### Testing Tools

| Tool | Purpose | Install | Notes |
|------|---------|---------|-------|
| **XCTest** | Unit testing | Xcode | Built-in |
| **XCUITest** | UI testing | Xcode | Built-in |
| **Maestro** | E2E UI testing (YAML) | `curl -Ls "https://get.maestro.mobile.dev" \| bash` | Simulator or Maestro Cloud for iOS |

### CI/CD Tools

| Tool | Purpose | Install | Notes |
|------|---------|---------|-------|
| **GitHub Actions** | CI/CD pipeline | N/A | `.github/workflows/ci.yml` |
| **Fastlane** | Build automation | `brew install fastlane` | `fastlane/Fastfile` |

### Performance & Monitoring (Production)

| Tool | Purpose | Notes |
|------|---------|-------|
| **Xcode Instruments** | Performance profiling | Built into Xcode |
| **Firebase Performance** | Production APM | Cloud-based |
| **New Relic Mobile** | Production monitoring | Cloud-based |

### Quick Install All Tools

```bash
# Required tools
brew install xcodegen swiftlint swiftformat

# Optional security tools
brew install gitleaks osv-scanner snyk
pip3 install mobsfscan

# Optional quality tools
brew install peripheryapp/periphery/periphery

# Optional testing/CI tools
brew install fastlane openjdk@17  # Java required for Maestro
curl -Ls "https://get.maestro.mobile.dev" | bash

# Add to PATH (add to ~/.zshrc for persistence)
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH:$HOME/.maestro/bin"

# MobSF (requires Docker Desktop)
# docker pull opensecurity/mobile-security-framework-mobsf:latest
```

---

## Terminal Execution

### Launch Command

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && claude --dangerously-skip-permissions
```

### Prompt

```
Read .claude/AUTONOMOUS_BUILD_QA.md and execute it completely. Do not stop until all completion criteria are met.
```
