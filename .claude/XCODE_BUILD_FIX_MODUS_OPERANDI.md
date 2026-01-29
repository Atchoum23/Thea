# Xcode Build Fix Modus Operandi

## IMPORTANT: Research Best Practices First

**Carefully research online how to address every single issue following latest best practices** before implementing any fix. Don't rely on potentially outdated knowledge - always verify current solutions for:
- macOS version-specific issues (currently Tahoe 26)
- Xcode version-specific behaviors
- Swift version-specific patterns
- Apple's latest recommendations

---

## Objective
Autonomously build all Xcode schemes and fix ALL errors, issues, and warnings until counts reach zero.

---

## CRITICAL: Two-Phase Validation is MANDATORY

**CLI builds alone are NOT sufficient!** The Xcode GUI may show errors/warnings that CLI does not.

### Required Workflow:
1. **Phase 1**: Build via CLI (`xcodebuild`) - fix all errors/warnings
2. **Phase 2**: Build via Xcode GUI (AppleScript) - fix any ADDITIONAL errors/warnings
3. **ONLY when BOTH phases show 0 errors and 0 warnings is the build complete**

The GUI uses different code paths, caches, and validation that CLI may miss. Never skip Phase 2!

## Project Details
- **Project Path**: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj`
- **Project Generator**: XcodeGen (`project.yml`)
- **Schemes**: `Thea-iOS`, `Thea-macOS`, `Thea-watchOS`, `Thea-tvOS`
- **Swift Version**: 6.0 with strict concurrency
- **Derived Data**: `~/Library/Developer/Xcode/DerivedData/Thea-*/`

---

## CRITICAL: Known Issues That MUST Be Addressed First

### Issue 1: CodeSign "resource fork, Finder information, or similar detritus not allowed"

**Root Cause**: Project is in iCloud-synced `~/Documents`. File Provider adds extended attributes that codesign rejects.

**MANDATORY SOLUTION**: Use `-derivedDataPath /tmp/TheaBuild` for ALL command-line builds:

```bash
# CORRECT - Always use this pattern:
xcodebuild build -project Thea.xcodeproj -scheme Thea-macOS \
  -destination 'platform=macOS' -configuration Release \
  -derivedDataPath /tmp/TheaBuild

# WRONG - Will fail with codesign error:
xcodebuild build -project Thea.xcodeproj -scheme Thea-macOS \
  -destination 'platform=macOS' -configuration Release
```

### Issue 2: Missing Package Products (Highlightr, KeychainAccess, MarkdownUI, OpenAI)

**Root Cause**: SPM cache corruption or stale Package.resolved.

**MANDATORY FIX** - Run these commands BEFORE attempting any build:

```bash
# Step 1: Clean ALL package caches
rm -rf ~/Library/Developer/Xcode/DerivedData/Thea-*
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -f Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# Step 2: Resolve dependencies fresh
xcodebuild -resolvePackageDependencies -project Thea.xcodeproj

# Step 3: Verify packages resolved
# Should see: "Resolved source packages: OpenAI, swift-http-types, ..."
```

---

## Phase 1: CLI Build Cycle

### Build Commands by Scheme

**IMPORTANT**: Always use `-derivedDataPath /tmp/TheaBuild` to avoid iCloud codesign issues!

```bash
# iOS (Simulator - no signing required)
xcodebuild -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -derivedDataPath /tmp/TheaBuild build 2>&1

# iOS (Device - requires signing)
xcodebuild -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "generic/platform=iOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -derivedDataPath /tmp/TheaBuild \
  -allowProvisioningUpdates build 2>&1

# macOS (always requires signing)
xcodebuild -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination "platform=macOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -derivedDataPath /tmp/TheaBuild \
  -allowProvisioningUpdates build 2>&1

# watchOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-watchOS" \
  -destination "generic/platform=watchOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -derivedDataPath /tmp/TheaBuild \
  -allowProvisioningUpdates build 2>&1

# tvOS (use simulator - no device provisioning)
xcodebuild -project Thea.xcodeproj -scheme "Thea-tvOS" \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -derivedDataPath /tmp/TheaBuild build 2>&1
```

### Extract Warnings and Errors

```bash
# Code warnings (file:line:col format)
grep -oE '[A-Za-z]+\.swift:[0-9]+:[0-9]+: (warning|error):.*'

# Project warnings
grep -E '\.xcodeproj: warning:'

# Build result
grep -E 'BUILD (SUCCEEDED|FAILED)'
```

### CLI Phase Loop
1. Build each scheme sequentially
2. Collect all unique warnings/errors
3. Fix each issue in source code
4. If `project.yml` was modified, run `xcodegen generate`
5. Rebuild and verify fix
6. Repeat until all schemes show: `BUILD SUCCEEDED` with 0 warnings

## Phase 2: GUI Build Cycle (MANDATORY - DO NOT SKIP!)

**THIS PHASE IS CRITICAL!** CLI success does NOT guarantee GUI success. The Xcode GUI:
- Uses different package resolution paths
- Has additional validation checks
- May show errors that CLI silently ignores
- Reflects what the user actually sees

### Step 1: Trigger GUI Build via AppleScript

**PREFERRED METHOD - Use Xcode's Native Scripting (no accessibility permissions needed):**

```bash
# Build the currently active scheme in Xcode GUI
osascript -e '
tell application "Xcode"
    activate
    set workspaceDoc to front workspace document
    build workspaceDoc
end tell
'
```

**To switch schemes first, then build:**

```bash
# First, switch scheme using xcodebuild (this affects Xcode GUI too)
xcodebuild -project Thea.xcodeproj -scheme "Thea-iOS" -showBuildSettings > /dev/null 2>&1

# Then trigger the build in Xcode GUI
osascript -e '
tell application "Xcode"
    activate
    set workspaceDoc to front workspace document
    build workspaceDoc
end tell
'
```

**ALTERNATIVE - Using System Events keystrokes (requires Accessibility permissions):**

```bash
# This method requires Terminal/Claude to have Accessibility access in System Settings
osascript -e '
tell application "Xcode"
    activate
end tell
delay 1
tell application "System Events"
    tell process "Xcode"
        -- Switch scheme (Ctrl+0, type name, Enter)
        keystroke "0" using {control down}
        delay 0.8
        keystroke "Thea-iOS"
        delay 0.5
        keystroke return
        delay 1
        -- Build (Cmd+B)
        keystroke "b" using {command down}
    end tell
end tell
'
```

### Step 2: Wait for Build Completion

```bash
# Wait for build to complete (adjust time based on build size)
sleep 90  # Full build: 60-120s, Incremental: 10-30s
```

### Step 3: Read GUI Build Results from Logs (BY TIMESTAMP!)

```bash
# Find the MOST RECENT build log by modification time
LOG=$(ls -t ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build/*.xcactivitylog 2>/dev/null | head -1)

echo "Reading log: $LOG"
echo "Log timestamp: $(stat -f '%Sm' "$LOG")"

# Extract ALL errors
echo "=== ERRORS ==="
gunzip -c "$LOG" 2>/dev/null | strings | \
  grep -E 'error:' | sort -u

# Extract ALL warnings
echo "=== WARNINGS ==="
gunzip -c "$LOG" 2>/dev/null | strings | \
  grep -E 'warning:' | grep -v "^warning:" | sort -u

# Extract project-level issues
echo "=== PROJECT ISSUES ==="
gunzip -c "$LOG" 2>/dev/null | strings | \
  grep -E '\.xcodeproj:.*(error|warning):' | sort -u

# Check build result
echo "=== BUILD RESULT ==="
gunzip -c "$LOG" 2>/dev/null | strings | \
  grep -E 'Build (Succeeded|Failed)' | tail -1
```

### Step 4: GUI Phase Loop

1. Open Xcode with the project (if not already open)
2. Switch to scheme via AppleScript (Thea-iOS, Thea-macOS, etc.)
3. Trigger build (Cmd+B via AppleScript)
4. Wait for build completion (check process or use fixed delay)
5. Read the MOST RECENT xcactivitylog by timestamp
6. Parse errors and warnings from the log
7. Fix ALL issues found in source code
8. Repeat build and log check
9. Move to next scheme only when current scheme has 0 errors AND 0 warnings
10. **ONLY COMPLETE when ALL schemes pass in GUI with 0 issues**

### Important Notes for GUI Builds

- **Always check log timestamp** to ensure you're reading the correct build
- GUI may show "Missing package product" errors that CLI resolved - need to fix in GUI context
- GUI caches are in `~/Library/Developer/Xcode/DerivedData/Thea-*` (different from CLI's `/tmp/TheaBuild`)
- If GUI shows package errors, close Xcode completely, clear DerivedData, reopen and let it resolve

## Common Warning Categories and Fixes

### 1. Deprecated API Warnings
- **Pattern**: `'X' was deprecated in iOS/macOS Y.0`
- **Fix**: Use `if #available(iOS Y.0, *)` with new API, fallback for older

### 2. Swift 6 Concurrency Warnings
- **Pattern**: `capture of 'X' with non-Sendable type`
- **Fix**: Add `@Sendable` to closures, use `nonisolated(unsafe)`, or wrap in `Task { @MainActor in }`

### 3. Unused Variables
- **Pattern**: `variable 'X' was never used`
- **Fix**: Prefix with `_` or remove

### 4. Optional Unwrapping
- **Pattern**: `value of optional type 'X?' must be unwrapped`
- **Fix**: Add `?? defaultValue` or proper optional handling

### 5. Project/Capability Warnings
- **Pattern**: `Bundle identifier is using development only version`
- **Fix**: Remove capability from entitlements or request distribution access from Apple

### 6. Entitlement Warnings
- **Pattern**: `Entitlement X not found and could not be included`
- **Fix**: Remove the entitlement from the .entitlements file

## Files That May Need Updates

| File Type | Location Pattern | When to Modify |
|-----------|------------------|----------------|
| Swift source | `Shared/**/*.swift`, `iOS/*.swift`, `macOS/*.swift` | Code warnings |
| Entitlements | `*/Thea.entitlements`, `Extensions/*/*.entitlements` | Capability warnings |
| Project config | `project.yml` | Build settings, new targets |
| Info.plist | `*/Info.plist` | Deprecated keys |

## Regenerating Xcode Project

After modifying `project.yml`:
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodegen generate
```

## Clearing Build Cache (if needed)

```bash
# Clear derived data for fresh build
rm -rf ~/Library/Developer/Xcode/DerivedData/Thea-*
rm -rf /tmp/TheaBuild

# If package resolution fails, also clear:
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -f Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# Then re-resolve packages:
xcodebuild -resolvePackageDependencies -project Thea.xcodeproj
```

## Success Criteria

**BOTH CLI AND GUI must pass!** Phase is complete when ALL of the following are true:

### CLI Builds (Phase 1):
- [ ] `Thea-iOS`: BUILD SUCCEEDED, 0 errors, 0 warnings
- [ ] `Thea-macOS`: BUILD SUCCEEDED, 0 errors, 0 warnings
- [ ] `Thea-watchOS`: BUILD SUCCEEDED, 0 errors, 0 warnings
- [ ] `Thea-tvOS`: BUILD SUCCEEDED, 0 errors, 0 warnings

### GUI Builds (Phase 2 - MANDATORY):
- [ ] `Thea-iOS`: BUILD SUCCEEDED in Xcode GUI, 0 errors, 0 warnings in xcactivitylog
- [ ] `Thea-macOS`: BUILD SUCCEEDED in Xcode GUI, 0 errors, 0 warnings in xcactivitylog
- [ ] `Thea-watchOS`: BUILD SUCCEEDED in Xcode GUI, 0 errors, 0 warnings in xcactivitylog
- [ ] `Thea-tvOS`: BUILD SUCCEEDED in Xcode GUI, 0 errors, 0 warnings in xcactivitylog

**DO NOT report success until BOTH phases pass for ALL schemes!**

## Notes

- **CRITICAL**: CLI success alone is NOT enough - MUST also verify with Xcode GUI builds
- **CRITICAL**: Always use `-derivedDataPath /tmp/TheaBuild` for CLI to avoid iCloud codesign errors
- **CRITICAL**: Always read the MOST RECENT xcactivitylog by timestamp after GUI builds
- Always use `ONLY_ACTIVE_ARCH=YES` for Debug builds to speed up compilation
- Use `-allowProvisioningUpdates` for iOS/macOS/watchOS to handle signing
- tvOS may fail device builds due to missing provisioning - use simulator instead
- The xcactivitylog files are gzip-compressed; use `gunzip -c` to read
- GUI builds may show "Perform Changes" dialogs for recommended settings - these require manual acceptance or pre-configuration in project.yml
- If packages are missing, run `xcodebuild -resolvePackageDependencies` FIRST
- GUI and CLI use DIFFERENT DerivedData paths - issues in one may not appear in the other
- See `/BUILD_GUIDE.md` for detailed troubleshooting guide
