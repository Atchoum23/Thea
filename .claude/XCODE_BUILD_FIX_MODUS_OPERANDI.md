# Xcode Build Fix Modus Operandi

## Objective
Autonomously build all Xcode schemes and fix ALL errors, issues, and warnings until counts reach zero.

## Project Details
- **Project Path**: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj`
- **Project Generator**: XcodeGen (`project.yml`)
- **Schemes**: `Thea-iOS`, `Thea-macOS`, `Thea-watchOS`, `Thea-tvOS`
- **Swift Version**: 6.0 with strict concurrency
- **Derived Data**: `~/Library/Developer/Xcode/DerivedData/Thea-*/`

## Phase 1: CLI Build Cycle

### Build Commands by Scheme

```bash
# iOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-iOS" \
  -destination "generic/platform=iOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -allowProvisioningUpdates build 2>&1

# macOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-macOS" \
  -destination "platform=macOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -allowProvisioningUpdates build 2>&1

# watchOS
xcodebuild -project Thea.xcodeproj -scheme "Thea-watchOS" \
  -destination "generic/platform=watchOS" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES \
  -allowProvisioningUpdates build 2>&1

# tvOS (use simulator - no device provisioning)
xcodebuild -project Thea.xcodeproj -scheme "Thea-tvOS" \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" \
  -configuration Debug ONLY_ACTIVE_ARCH=YES build 2>&1
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

## Phase 2: GUI Build Cycle

### Trigger GUI Build via AppleScript

```bash
osascript -e '
tell application "Xcode"
    activate
end tell
delay 0.5
tell application "System Events"
    tell process "Xcode"
        -- Switch scheme (Ctrl+0, type name, Enter)
        keystroke "0" using {control down}
        delay 0.5
        keystroke "Thea-iOS"
        delay 0.3
        keystroke return
        delay 0.5
        -- Build (Cmd+B)
        keystroke "b" using {command down}
    end tell
end tell
'
```

### Read GUI Build Results from Logs

```bash
# Find most recent build log
LOG=$(find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
  -name "*.xcactivitylog" -mmin -5 | head -1)

# Extract warnings and errors
gunzip -c "$LOG" 2>/dev/null | strings | \
  grep -E '\.swift:[0-9]+:[0-9]+: (warning|error):' | sort -u

# Extract project-level warnings
gunzip -c "$LOG" 2>/dev/null | strings | \
  grep -E '\.xcodeproj: warning:' | sort -u
```

### GUI Phase Loop
1. Switch to scheme via AppleScript
2. Trigger build (Cmd+B)
3. Wait for build completion (sleep 60-90s for full build, 10-30s for incremental)
4. Read xcactivitylog for warnings/errors
5. Fix issues in source code
6. Repeat for each scheme
7. Continue until all schemes show 0 warnings in logs

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
```

## Success Criteria

Phase is complete when ALL of the following are true:
- [ ] `Thea-iOS`: BUILD SUCCEEDED, 0 code warnings, 0 project warnings
- [ ] `Thea-macOS`: BUILD SUCCEEDED, 0 code warnings, 0 project warnings
- [ ] `Thea-watchOS`: BUILD SUCCEEDED, 0 code warnings, 0 project warnings
- [ ] `Thea-tvOS`: BUILD SUCCEEDED, 0 code warnings, 0 project warnings

## Notes

- Always use `ONLY_ACTIVE_ARCH=YES` for Debug builds to speed up compilation
- Use `-allowProvisioningUpdates` for iOS/macOS/watchOS to handle signing
- tvOS may fail device builds due to missing provisioning - use simulator instead
- The xcactivitylog files are gzip-compressed; use `gunzip -c` to read
- GUI builds may show "Perform Changes" dialogs for recommended settings - these require manual acceptance or pre-configuration in project.yml
