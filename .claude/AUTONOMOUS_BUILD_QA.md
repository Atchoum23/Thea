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
6. **ALL FUNCTIONAL TESTS** must pass - every button, function, and feature verified
7. **ALL CHANGES PUSHED** to GitHub with CI passing

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
- **GitHub Repo**: `git@github.com:Atchoum23/Thea.git`

---

## Execution Order & Phase Priority

| Phase | Name | Priority | Description |
|-------|------|----------|-------------|
| **0** | Pre-Flight & Setup | REQUIRED | Tool verification, GitHub setup, duplicate detection |
| **1** | Code Quality & Linting | REQUIRED | SwiftLint, SwiftFormat - fix before building |
| **2** | Debug Builds (CLI + GUI) | REQUIRED | All 4 platforms, both methods |
| **3** | Release Builds (CLI + GUI) | REQUIRED | All 4 platforms, both methods |
| **4** | Swift 6 Concurrency Fixes | REQUIRED | Fix all strict concurrency warnings |
| **5** | Unit & Integration Testing | REQUIRED | XCTest - create tests if none exist |
| **6** | Comprehensive Functional Testing | REQUIRED | All buttons, views, features across ALL platforms |
| **7** | Security Audit | REQUIRED | MobSF, Snyk, gitleaks, codesign |
| **8** | Performance & Memory | REQUIRED | App size, memory analysis |
| **9** | Accessibility Audit | REQUIRED | VoiceOver, accessibility labels |
| **10** | CI/CD & Final Verification | REQUIRED | Commit, push, verify GitHub Actions |

**CRITICAL**: Execute ALL phases in order. Each phase must pass before proceeding. NO phases are optional.

---

## Policies & Rules

### Swift 6 Strict Concurrency Policy
Swift 6 enforces strict concurrency. **ALL concurrency warnings/errors MUST be fixed.**

| Issue | Fix |
|-------|-----|
| `Sending 'X' risks data races` | Add `@Sendable` or use `nonisolated(unsafe)` |
| `Capture of 'self' with non-Sendable type` | Use `Task { @MainActor in }` or make type `Sendable` |
| `Call to main-actor-isolated method in non-isolated context` | Add `@MainActor` or use `await MainActor.run {}` |
| `Static property 'X' is not concurrency-safe` | Use `nonisolated(unsafe) static` or computed property |
| `Non-sendable type 'X' in implicitly asynchronous access` | Conform to `Sendable` or `@unchecked Sendable` |

### SPM Build Fix Policy
| Issue | Cause | Fix |
|-------|-------|-----|
| `multiple producers` | Duplicate file names | Rename files or add to Package.swift `exclude` |
| `unhandled files` | Non-Swift in source | Add to `resources` or `exclude` |
| `module not found` | Missing dependency | Add to Package.swift |

### Warning Policy
- **Target**: 0 warnings in project code
- **Acceptable**: Warnings from 3rd-party SPM packages
- **Action**: Suppress with `// swiftlint:disable` ONLY if justified

### Git Push Policy
**ALL changes MUST be committed and pushed immediately after completion.** CI only runs on GitHub.

```bash
git add -A && git commit -m "<type>: <desc>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>" && git push origin main
```

---

## Phase 0: Pre-Flight & GitHub Setup

### 0.1 Tool Verification
```bash
echo "=== Required Tools ==="
for tool in xcodebuild swiftlint swiftformat xcodegen gh; do
  command -v $tool &>/dev/null && echo "✓ $tool" || echo "✗ $tool MISSING"
done

echo ""
echo "=== Optional Tools ==="
for tool in periphery gitleaks osv-scanner snyk mobsfscan maestro fastlane; do
  command -v $tool &>/dev/null && echo "✓ $tool" || echo "○ $tool (skip related)"
done

echo ""
echo "=== Java (Maestro) ==="
java -version 2>&1 | grep -q "17\|18\|19\|20\|21" && echo "✓ Java 17+" || echo "○ Java missing"

echo ""
echo "=== Docker (MobSF) ==="
command -v docker &>/dev/null && echo "✓ Docker" || echo "○ Docker missing"
```

### 0.2 Simulator Availability
```bash
echo "=== Available Simulators ==="
xcrun simctl list devices available | grep -E "(iPhone|Apple TV|Apple Watch)" | head -10

IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
echo "iPhone: $IPHONE_SIM"

TV_SIM=$(xcrun simctl list devices available | grep "Apple TV" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
echo "tvOS: $TV_SIM"
```

### 0.3 GitHub Setup
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Use SSH for push
git remote -v | grep -q "https://" && git remote set-url origin git@github.com:Atchoum23/Thea.git

# Verify authentication
gh auth status &>/dev/null && echo "✓ GitHub CLI authenticated" || echo "✗ Run: gh auth login"

# Check uncommitted changes
[ -n "$(git status --porcelain)" ] && { echo "⚠ Uncommitted:"; git status --short; } || echo "✓ Clean"

# Verify workflows
ls -la .github/workflows/*.yml 2>/dev/null || echo "✗ No workflows"
```

### 0.4 Duplicate File Detection
```bash
echo "=== Duplicate Swift Files ==="
DUPS=$(find Shared -name "*.swift" -exec basename {} \; | sort | uniq -d)
if [ -n "$DUPS" ]; then
  echo "⚠ DUPLICATES FOUND:"
  echo "$DUPS"
  for dup in $DUPS; do find Shared -name "$dup"; done
  echo "FIX: Rename or add to Package.swift exclude"
else
  echo "✓ No duplicates"
fi
```

### 0.5 Kill Stale Processes
```bash
pkill -9 xcodebuild 2>/dev/null || true
```

---

## Phase 1: Code Quality & Linting (BEFORE BUILDING)

**Run linting FIRST to avoid build failures from formatting issues.**

### 1.1 SwiftFormat (Auto-fix)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
swiftformat . 2>&1
echo "✓ SwiftFormat applied"
```

### 1.2 SwiftLint
```bash
swiftlint lint --reporter json > swiftlint_report.json 2>&1
VIOLATIONS=$(swiftlint lint 2>&1 | grep -cE "(warning|error):" || echo "0")
echo "Violations: $VIOLATIONS"

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "=== Top violations ==="
  swiftlint lint 2>&1 | grep -E "(warning|error):" | head -30
  echo "FIX violations before proceeding"
fi
```

### 1.3 Auto-fix SwiftLint Violations
```bash
# Fix auto-correctable violations
swiftlint lint --fix 2>&1
swiftlint lint 2>&1 | head -20
```

### Success Criteria
- [ ] SwiftFormat: Applied to all files
- [ ] SwiftLint: 0 errors (warnings acceptable if justified)

---

## Phase 2: Debug Builds (CLI + GUI)

### 2.1 CLI Debug Builds (All 4 Platforms)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  PLATFORM=$(echo $scheme | sed 's/Thea-//' | tr '[:upper:]' '[:lower:]')

  case $PLATFORM in
    ios) DEST="generic/platform=iOS" ;;
    macos) DEST="platform=macOS" ;;
    watchos) DEST="generic/platform=watchOS" ;;
    tvos) DEST="generic/platform=tvOS" ;;
  esac

  echo "=== Building $scheme (Debug CLI) ==="
  xcodebuild -project Thea.xcodeproj -scheme "$scheme" \
    -destination "$DEST" -configuration Debug ONLY_ACTIVE_ARCH=YES \
    -allowProvisioningUpdates build 2>&1 | tee "build_${PLATFORM}_debug.log"

  # Check result
  if grep -q "BUILD SUCCEEDED" "build_${PLATFORM}_debug.log"; then
    WARNS=$(grep -c " warning:" "build_${PLATFORM}_debug.log" || echo "0")
    echo "✓ $scheme Debug: SUCCEEDED ($WARNS warnings)"
  else
    echo "✗ $scheme Debug: FAILED"
    grep " error:" "build_${PLATFORM}_debug.log" | head -10
  fi
done
```

### 2.2 GUI Debug Builds (AppleScript)
```bash
build_gui() {
  local SCHEME="$1"
  osascript -e "
tell application \"Xcode\"
    activate
end tell
delay 1
tell application \"System Events\"
    tell process \"Xcode\"
        keystroke \"0\" using {control down}
        delay 0.5
        keystroke \"$SCHEME\"
        delay 0.3
        keystroke return
        delay 0.5
        keystroke \"b\" using {command down}
    end tell
end tell
"
  echo "Building $SCHEME in GUI..."
  sleep 90
}

for scheme in "Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS"; do
  build_gui "$scheme"
done
```

### 2.3 Read GUI Build Logs (xcactivitylog)
```bash
read_gui_log() {
  LOG=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
    -name "*.xcactivitylog" -mmin -10 2>/dev/null | sort -r | head -1)

  [ -z "$LOG" ] && { echo "No recent log"; return 1; }

  echo "=== GUI Warnings ==="
  gunzip -c "$LOG" 2>/dev/null | strings | grep -E '\.swift:[0-9]+:[0-9]+: warning:' | sort -u | head -20

  echo "=== GUI Errors ==="
  gunzip -c "$LOG" 2>/dev/null | strings | grep -E '\.swift:[0-9]+:[0-9]+: error:' | sort -u | head -10
}

read_gui_log
```

### Success Criteria
- [ ] All 4 CLI Debug: BUILD SUCCEEDED, 0 warnings
- [ ] All 4 GUI Debug: 0 warnings in xcactivitylog

---

## Phase 3: Release Builds (CLI + GUI)

### 3.1 CLI Release Builds
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

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
done
```

### 3.2 GUI Release Builds
Same process as Phase 2.2, after builds complete run `read_gui_log`.

### Success Criteria
- [ ] All 4 CLI Release: BUILD SUCCEEDED, 0 warnings
- [ ] All 4 GUI Release: 0 warnings in xcactivitylog

---

## Phase 4: Swift 6 Concurrency Fixes

### 4.1 Find Concurrency Issues
```bash
grep -rE "(Sending .* risks|non-Sendable|main-actor-isolated|concurrency-safe|implicitly asynchronous)" build_*.log | head -50
```

### 4.2 Common Fixes
```swift
// Static property not concurrency-safe
// BEFORE: static let shared = MyClass()
// AFTER:
nonisolated(unsafe) static let shared = MyClass()

// Capture of 'self' with non-Sendable type
// BEFORE: Task { self.doSomething() }
// AFTER:
Task { @MainActor in self.doSomething() }

// Call to main-actor-isolated method
// BEFORE: func process() { updateUI() }
// AFTER:
@MainActor func process() { updateUI() }

// Non-sendable type
// BEFORE: class MyClass { }
// AFTER:
final class MyClass: @unchecked Sendable { }
```

### Success Criteria
- [ ] All Swift 6 concurrency warnings fixed
- [ ] Rebuild after fixes shows 0 concurrency warnings

---

## Phase 5: Unit & Integration Testing (REQUIRED)

### 5.1 Check for Test Targets
```bash
TEST_TARGETS=$(xcodebuild -project Thea.xcodeproj -list 2>/dev/null | grep -i "test" || echo "")
if [ -z "$TEST_TARGETS" ]; then
  echo "⚠ No test targets found - CREATE test targets before proceeding"
  echo "Required: TheaTests (unit tests), TheaUITests (UI tests)"
fi
```

### 5.2 Run XCTest
```bash
IPHONE_SIM=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

# iOS Tests
xcodebuild test -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$IPHONE_SIM" \
  -resultBundlePath TestResults/iOS.xcresult 2>&1 | tee test_ios.log

# macOS Tests
xcodebuild test -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination "platform=macOS" \
  -resultBundlePath TestResults/macOS.xcresult 2>&1 | tee test_macos.log
```

### 5.3 Code Coverage
```bash
if [ -d "TestResults/iOS.xcresult" ]; then
  xcrun xccov view --report TestResults/iOS.xcresult --json > coverage.json
  xcrun xccov view --report TestResults/iOS.xcresult | head -20
fi
```

### Success Criteria
- [ ] Test targets exist (create if missing)
- [ ] All unit tests pass
- [ ] Coverage report generated (minimum 60% coverage)

---

## Phase 6: Comprehensive Functional Testing (REQUIRED)

**This phase tests ALL buttons, views, functions, and features on ALL platforms.**

### 6.1 Platform-Specific Test Strategies

| Platform | Primary Tool | Secondary Tool | Notes |
|----------|--------------|----------------|-------|
| **iOS** | XCUITest | Maestro | Simulator testing |
| **macOS** | XCUITest | AppleScript/Appium | Desktop automation |
| **watchOS** | XCUITest | Simulator inspection | Limited automation |
| **tvOS** | XCUITest | Simulator focus nav | Remote-based UI |

### 6.2 iOS Functional Testing (XCUITest + Maestro)

#### 6.2.1 XCUITest (Native)
```bash
# Run all UI tests
xcodebuild test -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$IPHONE_SIM" \
  -only-testing:TheaUITests 2>&1 | tee test_ui_ios.log
```

#### 6.2.2 Maestro E2E Flows
```bash
# Create comprehensive test flows
mkdir -p .maestro

# App Launch & Navigation Test
cat > .maestro/01_launch.yaml << 'YAML'
appId: app.theathe.ios
---
- launchApp:
    clearState: true
- assertVisible:
    text: ".*"
    timeout: 10000
- takeScreenshot: ios_launch
YAML

# Tab Bar Navigation Test
cat > .maestro/02_navigation.yaml << 'YAML'
appId: app.theathe.ios
---
- launchApp
# Test each tab bar item
- tapOn:
    id: "tab_home"
    optional: true
- assertVisible:
    text: "Home"
    optional: true
- takeScreenshot: nav_home

- tapOn:
    id: "tab_settings"
    optional: true
- assertVisible:
    text: "Settings"
    optional: true
- takeScreenshot: nav_settings
YAML

# Settings Screen Test
cat > .maestro/03_settings.yaml << 'YAML'
appId: app.theathe.ios
---
- launchApp
- tapOn: "Settings"
# Test all settings toggles
- tapOn:
    id: "toggle_notifications"
    optional: true
- tapOn:
    id: "toggle_dark_mode"
    optional: true
- scroll:
    direction: DOWN
- takeScreenshot: settings_scrolled
YAML

# Form Input Test
cat > .maestro/04_forms.yaml << 'YAML'
appId: app.theathe.ios
---
- launchApp
# Find any text field and test input
- tapOn:
    id: ".*TextField.*"
    optional: true
- inputText: "Test input"
- hideKeyboard
- takeScreenshot: form_input
YAML

# Button Interaction Test
cat > .maestro/05_buttons.yaml << 'YAML'
appId: app.theathe.ios
---
- launchApp
# Test primary action buttons
- tapOn:
    id: ".*Button.*"
    optional: true
- assertNotVisible:
    text: "Error"
    optional: true
- takeScreenshot: button_action
YAML

echo "Created 5 Maestro test flows"

# Run Maestro tests
if command -v maestro &>/dev/null; then
  # Boot simulator
  xcrun simctl boot "$IPHONE_SIM" 2>/dev/null || true

  # Install app
  APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug-iphonesimulator -name "Thea.app" | head -1)
  [ -n "$APP_PATH" ] && xcrun simctl install "$IPHONE_SIM" "$APP_PATH"

  # Run all flows
  maestro test .maestro/ 2>&1 | tee maestro_ios_results.log
else
  echo "SKIP: Maestro not installed"
fi
```

### 6.3 macOS Functional Testing (XCUITest + AppleScript)

#### 6.3.1 XCUITest for macOS
```bash
# macOS UI Tests
xcodebuild test -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination "platform=macOS" \
  -only-testing:TheaUITests 2>&1 | tee test_ui_macos.log
```

#### 6.3.2 AppleScript Automation (All Buttons & Menu Items)
```bash
# Find built macOS app
MACOS_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug -name "Thea.app" -path "*macOS*" | head -1)

if [ -n "$MACOS_APP" ]; then
  # Launch app
  open "$MACOS_APP"
  sleep 3

  # Test all menu items
  osascript << 'APPLESCRIPT'
tell application "System Events"
    tell process "Thea"
        -- Verify app launched
        if not (exists window 1) then
            error "App window not found"
        end if

        -- Test Menu Bar Items
        set menuBar to menu bar 1

        -- File Menu
        try
            click menu bar item "File" of menuBar
            delay 0.3
            -- Click each menu item (non-destructive ones)
            repeat with menuItem in menu items of menu "File" of menuBar
                set itemName to name of menuItem
                if itemName is not missing value and itemName is not "" then
                    log "Testing File > " & itemName
                end if
            end repeat
            key code 53 -- Escape to close menu
        end try

        -- Edit Menu
        try
            click menu bar item "Edit" of menuBar
            delay 0.3
            key code 53
        end try

        -- View Menu
        try
            click menu bar item "View" of menuBar
            delay 0.3
            key code 53
        end try

        -- Window Menu
        try
            click menu bar item "Window" of menuBar
            delay 0.3
            key code 53
        end try

        -- Help Menu
        try
            click menu bar item "Help" of menuBar
            delay 0.3
            key code 53
        end try

        -- Test all buttons in main window
        try
            set allButtons to every button of window 1
            repeat with btn in allButtons
                set btnName to description of btn
                log "Found button: " & btnName
                -- Click non-destructive buttons
                if btnName does not contain "Delete" and btnName does not contain "Remove" then
                    try
                        click btn
                        delay 0.5
                    end try
                end if
            end repeat
        end try

        -- Test all checkboxes
        try
            set allCheckboxes to every checkbox of window 1
            repeat with cb in allCheckboxes
                click cb
                delay 0.2
                click cb -- Reset
            end repeat
        end try

        -- Test all pop up buttons (dropdowns)
        try
            set allPopups to every pop up button of window 1
            repeat with popup in allPopups
                click popup
                delay 0.3
                key code 53 -- Close
            end repeat
        end try

        -- Test all text fields (verify editable)
        try
            set allTextFields to every text field of window 1
            repeat with tf in allTextFields
                click tf
                set value of tf to "Test"
                delay 0.2
                set value of tf to ""
            end repeat
        end try

        -- Test all tabs
        try
            set allTabs to every tab group of window 1
            repeat with tabGroup in allTabs
                set tabButtons to every radio button of tabGroup
                repeat with tab in tabButtons
                    click tab
                    delay 0.3
                end repeat
            end repeat
        end try

        -- Capture screenshot
        do shell script "screencapture -w ~/Desktop/thea_macos_test.png"

        log "macOS functional test complete"
    end tell
end tell
APPLESCRIPT

  echo "✓ macOS AppleScript automation complete"
else
  echo "⚠ macOS app not found - build first"
fi
```

#### 6.3.3 macOS Keyboard Shortcuts Test
```bash
osascript << 'APPLESCRIPT'
tell application "Thea"
    activate
end tell

tell application "System Events"
    tell process "Thea"
        -- Test common keyboard shortcuts
        keystroke "n" using command down -- New
        delay 0.3
        keystroke "w" using command down -- Close
        delay 0.3
        keystroke "," using command down -- Preferences
        delay 0.5
        key code 53 -- Escape
        delay 0.3
        keystroke "?" using {command down, shift down} -- Help
        delay 0.3
        key code 53
    end tell
end tell
APPLESCRIPT
```

### 6.4 watchOS Functional Testing

```bash
# watchOS has limited UI testing - use Simulator inspection
WATCH_SIM=$(xcrun simctl list devices available | grep "Apple Watch" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

if [ -n "$WATCH_SIM" ]; then
  # Boot watch simulator
  xcrun simctl boot "$WATCH_SIM" 2>/dev/null || true

  # Install watch app
  WATCH_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug-watchsimulator -name "*.app" | head -1)
  [ -n "$WATCH_APP" ] && xcrun simctl install "$WATCH_SIM" "$WATCH_APP"

  # Launch app
  xcrun simctl launch "$WATCH_SIM" app.theathe.watchos
  sleep 3

  # Take screenshot
  xcrun simctl io "$WATCH_SIM" screenshot watchos_test.png

  # Test basic interactions via simctl
  # Swipe up
  xcrun simctl io "$WATCH_SIM" swipe up
  sleep 1
  xcrun simctl io "$WATCH_SIM" screenshot watchos_scrolled.png

  # Tap crown
  xcrun simctl io "$WATCH_SIM" tap 50 50
  sleep 1

  echo "✓ watchOS simulator testing complete"
else
  echo "⚠ No watchOS simulator available"
fi
```

### 6.5 tvOS Functional Testing

```bash
# tvOS testing - focus-based navigation
TV_SIM=$(xcrun simctl list devices available | grep "Apple TV" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

if [ -n "$TV_SIM" ]; then
  # Boot TV simulator
  xcrun simctl boot "$TV_SIM" 2>/dev/null || true

  # Install TV app
  TV_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Debug-appletvsimulator -name "*.app" | head -1)
  [ -n "$TV_APP" ] && xcrun simctl install "$TV_SIM" "$TV_APP"

  # Launch app
  xcrun simctl launch "$TV_SIM" app.theathe.tvos
  sleep 3

  # Take screenshot
  xcrun simctl io "$TV_SIM" screenshot tvos_launch.png

  # Test remote navigation
  # Down arrow
  xcrun simctl io "$TV_SIM" sendkey down
  sleep 0.5
  xcrun simctl io "$TV_SIM" sendkey down
  sleep 0.5
  xcrun simctl io "$TV_SIM" sendkey right
  sleep 0.5
  xcrun simctl io "$TV_SIM" sendkey select
  sleep 1
  xcrun simctl io "$TV_SIM" screenshot tvos_selected.png

  # Menu button (back)
  xcrun simctl io "$TV_SIM" sendkey menu
  sleep 0.5

  echo "✓ tvOS simulator testing complete"
else
  echo "⚠ No tvOS simulator available"
fi
```

### 6.6 Cross-Platform View & Button Inventory

Create an inventory of all testable UI elements:

```bash
# Generate UI inventory for tracking
cat > ui_inventory.md << 'EOF'
# UI Element Inventory

## iOS Views
- [ ] Home View - all buttons functional
- [ ] Settings View - all toggles work
- [ ] Navigation - all tabs accessible
- [ ] Forms - all inputs accept text
- [ ] Sheets - present and dismiss correctly
- [ ] Alerts - display and respond to actions

## macOS Views
- [ ] Main Window - renders correctly
- [ ] Menu Bar - all items accessible
- [ ] Toolbar - all buttons work
- [ ] Preferences - all tabs function
- [ ] Keyboard shortcuts - all respond
- [ ] Context menus - appear on right-click

## watchOS Views
- [ ] Home complications work
- [ ] Scrolling functions
- [ ] Notifications display
- [ ] Digital Crown responds

## tvOS Views
- [ ] Focus navigation works
- [ ] Remote controls respond
- [ ] Content displays correctly
- [ ] Parallax effects render

## Shared Functionality
- [ ] Data syncs across platforms
- [ ] Notifications deliver
- [ ] Deep links resolve
- [ ] State persists
EOF

echo "✓ Created ui_inventory.md"
```

### Success Criteria
- [ ] iOS: All XCUITests pass, all Maestro flows pass
- [ ] macOS: All menu items accessible, all buttons clickable, keyboard shortcuts work
- [ ] watchOS: App launches, basic interactions work
- [ ] tvOS: Focus navigation works, remote responds
- [ ] No crashes during any functional test

---

## Phase 7: Security Audit (REQUIRED)

### 7.1 Secrets Detection
```bash
# Install gitleaks if not present
command -v gitleaks &>/dev/null || brew install gitleaks

gitleaks detect --source . --verbose 2>&1 | tee security_secrets.log
if grep -q "leaks found" security_secrets.log; then
  echo "⚠ SECRETS FOUND - MUST FIX before proceeding"
  exit 1
else
  echo "✓ No secrets"
fi
```

### 7.2 Dependency Vulnerabilities
```bash
# Install osv-scanner if not present
command -v osv-scanner &>/dev/null || brew install osv-scanner

osv-scanner --lockfile Package.resolved 2>&1 | tee security_deps.log
echo "✓ Dependency scan complete - review security_deps.log for vulnerabilities"
```

### 7.3 MobSF Source Scan
```bash
# Install mobsfscan if not present
command -v mobsfscan &>/dev/null || pip3 install mobsfscan

mobsfscan --json -o mobsf_source_scan.json . 2>&1 | tee mobsf_scan.log
echo "✓ MobSF scan complete - review mobsf_source_scan.json"
```

### 7.4 macOS Code Signing Verification
```bash
MACOS_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Release -name "Thea.app" -path "*macOS*" | head -1)

if [ -n "$MACOS_APP" ]; then
  echo "=== Code Signing ==="
  codesign -dv --verbose=4 "$MACOS_APP" 2>&1 | head -20

  echo ""
  echo "=== Entitlements ==="
  codesign --display --entitlements - "$MACOS_APP" 2>&1 | head -30

  echo ""
  echo "=== Sandbox Check ==="
  grep -l "app-sandbox" macOS/Thea.entitlements && echo "✓ Sandbox enabled" || echo "⚠ Sandbox not enabled"
fi
```

### 7.5 Snyk Scan
```bash
# Install snyk if not present
command -v snyk &>/dev/null || brew install snyk

if [ -n "$SNYK_TOKEN" ]; then
  snyk auth $SNYK_TOKEN
fi
snyk test --all-projects 2>&1 | tee snyk_report.log || echo "Snyk scan complete (review warnings)"
```

### Success Criteria
- [ ] gitleaks: No secrets in code
- [ ] osv-scanner: No critical vulnerabilities
- [ ] MobSF: Security scan complete
- [ ] Snyk: Dependency scan complete
- [ ] macOS code signing verified
- [ ] Hardened runtime enabled

---

## Phase 8: Performance & Memory (REQUIRED)

### 8.1 App Size Analysis
```bash
echo "=== App Sizes ==="
find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products -name "*.app" -exec du -sh {} \; 2>/dev/null | tee app_sizes.log

# Check for bloated apps
while IFS= read -r line; do
  SIZE=$(echo "$line" | awk '{print $1}')
  APP=$(echo "$line" | awk '{print $2}')
  if [[ "$SIZE" == *"G"* ]]; then
    echo "⚠ WARNING: $APP is over 1GB - investigate"
  fi
done < app_sizes.log
```

### 8.2 Binary Analysis
```bash
# Check for debug symbols in release builds (should be stripped)
RELEASE_APP=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Build/Products/Release -name "Thea.app" | head -1)
if [ -n "$RELEASE_APP" ]; then
  echo "=== Binary Size ==="
  ls -lh "$RELEASE_APP/Contents/MacOS/Thea" 2>/dev/null || ls -lh "$RELEASE_APP/Thea" 2>/dev/null
fi
```

### 8.3 Memory Baseline
```bash
# Log memory usage baseline (for future comparison)
echo "=== Memory Baseline ==="
echo "Note: Run Instruments for detailed memory profiling"
echo "Xcode → Product → Profile → Allocations"
```

### Success Criteria
- [ ] App sizes analyzed and logged
- [ ] No app exceeds 500MB (warn if > 100MB)
- [ ] Release builds have symbols stripped
- [ ] Memory baseline documented

---

## Phase 9: Accessibility Audit (REQUIRED)

### 9.1 Accessibility Audit via XCUITest
```bash
# Verify accessibility audit is in UI tests
if grep -r "performAccessibilityAudit" Tests/ 2>/dev/null; then
  echo "✓ Accessibility audit found in tests"
else
  echo "⚠ Add performAccessibilityAudit() to XCUITests"
  echo "Example:"
  echo "  try app.performAccessibilityAudit()"
fi

# Run accessibility-focused UI tests
xcodebuild test -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,id=$IPHONE_SIM" \
  -only-testing:TheaUITests/AccessibilityTests 2>&1 | tee accessibility_ios.log || true
```

### 9.2 VoiceOver Labels Check
```bash
# Search for missing accessibility labels in SwiftUI views
echo "=== Checking for accessibility labels ==="
grep -r "\.accessibilityLabel\|\.accessibilityHint\|\.accessibilityValue" Shared/ iOS/ macOS/ | wc -l | xargs echo "Accessibility modifiers found:"

# Check for images without accessibility
echo ""
echo "=== Images potentially missing accessibility ==="
grep -rn "Image(" Shared/ iOS/ macOS/ | grep -v "accessibilityLabel" | head -20
```

### 9.3 Dynamic Type Support
```bash
# Check for fixed font sizes (should use dynamic type)
echo "=== Checking for fixed font sizes ==="
grep -rn "\.font(.system(size:" Shared/ iOS/ | head -20
echo ""
echo "Prefer: .font(.body), .font(.headline), etc. for dynamic type support"
```

### 9.4 Color Contrast Check
```bash
# Check for potential color contrast issues
echo "=== Color usage in views ==="
grep -rn "\.foregroundColor\|\.background" Shared/ iOS/ | grep -v "Color.primary\|Color.secondary" | head -20
echo ""
echo "Ensure sufficient contrast for accessibility"
```

### Success Criteria
- [ ] performAccessibilityAudit() in UI tests
- [ ] All interactive elements have accessibility labels
- [ ] Images have accessibility descriptions
- [ ] Dynamic Type supported (no fixed font sizes)
- [ ] Color contrast verified

---

## Phase 10: CI/CD & Final Verification (REQUIRED)

### 10.1 Existing GitHub Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **CI** | `ci.yml` | Build all platforms, tests, SwiftLint |
| **Release** | `release.yml` | GitHub releases on tag |
| **Security Audit** | `thea-audit-*.yml` | Security scanning |
| **MobSF** | `security-mobsf.yml` | Source code security |
| **Maestro** | `maestro-e2e.yml` | E2E UI tests |

### 10.2 MANDATORY: Commit and Push ALL Changes

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"

# Check status
git status

# Stage all changes
git add -A

# Commit
git commit -m "$(cat <<'EOF'
fix: QA complete - zero warnings, all tests pass

- All 4 platforms build clean (iOS, macOS, watchOS, tvOS)
- All CLI and GUI builds: 0 warnings
- SwiftLint: 0 errors
- All functional tests pass
- Security scan complete

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"

# Push
git push origin main

# Verify CI started
sleep 5
gh run list --limit 3
echo "✓ Changes pushed. Verify: https://github.com/Atchoum23/Thea/actions"
```

### 10.3 Generate Final Summary
```bash
cat > QA_SUMMARY.md << EOF
# QA Summary Report
Generated: $(date)

## Build Status
| Platform | Debug CLI | Debug GUI | Release CLI | Release GUI |
|----------|-----------|-----------|-------------|-------------|
| iOS | $(grep -q "SUCCEEDED" build_ios_debug.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ | $(grep -q "SUCCEEDED" build_ios_release.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ |
| macOS | $(grep -q "SUCCEEDED" build_macos_debug.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ | $(grep -q "SUCCEEDED" build_macos_release.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ |
| watchOS | $(grep -q "SUCCEEDED" build_watchos_debug.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ | $(grep -q "SUCCEEDED" build_watchos_release.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ |
| tvOS | $(grep -q "SUCCEEDED" build_tvos_debug.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ | $(grep -q "SUCCEEDED" build_tvos_release.log 2>/dev/null && echo "✅" || echo "❌") | ⬜ |

## Functional Testing
| Platform | XCUITest | E2E (Maestro/AppleScript) |
|----------|----------|---------------------------|
| iOS | $([ -f test_ui_ios.log ] && echo "✅" || echo "⏭") | $([ -f maestro_ios_results.log ] && echo "✅" || echo "⏭") |
| macOS | $([ -f test_ui_macos.log ] && echo "✅" || echo "⏭") | ✅ AppleScript |
| watchOS | ⏭ Limited | ✅ Simulator |
| tvOS | ⏭ Limited | ✅ Simulator |

## Code Quality
- SwiftLint: $([ -f swiftlint_report.json ] && echo "✅" || echo "⏭")
- SwiftFormat: ✅ Applied

## Security
- gitleaks: $([ -f security_secrets.log ] && echo "✅" || echo "⏭")
- MobSF: $([ -f mobsf_source_scan.json ] && echo "✅" || echo "⏭")

## CI/CD
- GitHub Actions: $(gh run list --limit 1 --json status -q '.[0].status' 2>/dev/null || echo "⏭")
- Latest Run: $(gh run list --limit 1 --json conclusion -q '.[0].conclusion' 2>/dev/null || echo "pending")
EOF

cat QA_SUMMARY.md
```

### 10.4 Final Checklist (ALL REQUIRED)

#### Phase 0-1: Setup & Linting
- [ ] All tools installed and verified
- [ ] GitHub SSH configured
- [ ] No duplicate files
- [ ] SwiftFormat applied
- [ ] SwiftLint: 0 errors

#### Phase 2-4: Builds & Concurrency
- [ ] All 4 Debug CLI: BUILD SUCCEEDED, 0 warnings
- [ ] All 4 Release CLI: BUILD SUCCEEDED, 0 warnings
- [ ] All 4 Debug GUI: 0 warnings (xcactivitylog)
- [ ] All 4 Release GUI: 0 warnings (xcactivitylog)
- [ ] All Swift 6 concurrency issues fixed

#### Phase 5-6: Testing
- [ ] Unit tests exist and pass
- [ ] Code coverage ≥ 60%
- [ ] iOS functional tests pass (XCUITest + Maestro)
- [ ] macOS functional tests pass (buttons, menus, shortcuts)
- [ ] watchOS launches and basic nav works
- [ ] tvOS launches and focus nav works

#### Phase 7: Security
- [ ] gitleaks: No secrets found
- [ ] osv-scanner: Dependency scan complete
- [ ] MobSF: Source scan complete
- [ ] Snyk: Vulnerability scan complete
- [ ] macOS code signing verified
- [ ] Hardened runtime enabled

#### Phase 8: Performance
- [ ] App sizes analyzed (< 500MB each)
- [ ] Binary analysis complete
- [ ] Memory baseline documented

#### Phase 9: Accessibility
- [ ] performAccessibilityAudit() in UI tests
- [ ] Accessibility labels on interactive elements
- [ ] Dynamic Type supported
- [ ] Color contrast verified

#### Phase 10: CI/CD
- [ ] All changes committed and pushed
- [ ] GitHub Actions CI passing
- [ ] QA_SUMMARY.md generated

---

## Autonomous Execution Notes

### MANDATORY Behaviors
1. Execute phases 0→10 sequentially
2. Fix errors immediately before proceeding
3. Use TodoWrite to track progress
4. Log all fixes to `QA_FIXES_LOG.md`
5. ALL 4 PLATFORMS must pass
6. Run BOTH CLI and GUI builds
7. Test ALL buttons and functions (Phase 6)
8. COMMIT AND PUSH after completion

### Error Handling
- Build fails → Fix and rebuild that scheme only
- Warning appears → Fix unless from SPM package
- xcodegen needed → Run `xcodegen generate`
- Git push fails → `git remote set-url origin git@github.com:Atchoum23/Thea.git`
- Functional test fails → Fix UI issue, retest

### Completion Criteria
Mission ONLY complete when ALL phases pass:
- [ ] Phase 0: Pre-flight checks pass
- [ ] Phase 1: SwiftLint 0 errors, SwiftFormat applied
- [ ] Phase 2: All 8 Debug builds pass (4 CLI + 4 GUI), 0 warnings
- [ ] Phase 3: All 8 Release builds pass (4 CLI + 4 GUI), 0 warnings
- [ ] Phase 4: All Swift 6 concurrency issues fixed
- [ ] Phase 5: Unit tests pass, coverage ≥ 60%
- [ ] Phase 6: All functional tests pass (iOS, macOS, watchOS, tvOS)
- [ ] Phase 7: Security scans complete, no secrets, no critical vulns
- [ ] Phase 8: Performance analysis complete
- [ ] Phase 9: Accessibility audit complete
- [ ] Phase 10: All changes pushed, GitHub Actions CI passing

---

## Files Generated

| File | Purpose |
|------|---------|
| `build_*_debug.log` | Debug build outputs |
| `build_*_release.log` | Release build outputs |
| `swiftlint_report.json` | Linting results |
| `test_ui_*.log` | UI test results |
| `maestro_ios_results.log` | Maestro E2E results |
| `security_*.log` | Security scan results |
| `ui_inventory.md` | UI element checklist |
| `QA_SUMMARY.md` | Final summary |
| `QA_FIXES_LOG.md` | All fixes applied |

---

## Quick Install All Tools

```bash
# Required
brew install xcodegen swiftlint swiftformat

# Optional
brew install gitleaks osv-scanner snyk fastlane openjdk@17
pip3 install mobsfscan
curl -Ls "https://get.maestro.mobile.dev" | bash

# PATH
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH:$HOME/.maestro/bin"
```

---

## Terminal Execution

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea" && claude --dangerously-skip-permissions
```

### Prompt
```
Read .claude/AUTONOMOUS_BUILD_QA.md and execute it completely. Do not stop until all completion criteria are met.
```
