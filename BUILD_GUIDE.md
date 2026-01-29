# Thea Build Guide

## Critical Build Information for AI Assistants

**READ THIS FIRST** - This document contains essential build information that must be followed.

---

## MANDATORY: Two-Phase Build Validation

**CLI builds alone are NOT sufficient!** Always validate with BOTH:

1. **Phase 1: CLI builds** (`xcodebuild`) - Use `-derivedDataPath /tmp/TheaBuild`
2. **Phase 2: GUI builds** (Xcode.app) - Use AppleScript to trigger, read xcactivitylog for results

The Xcode GUI may show errors/warnings that CLI does not catch. **Never report success until BOTH phases pass with 0 errors and 0 warnings.**

### Trigger Xcode GUI Build via AppleScript

```bash
# Preferred method - uses Xcode's native scripting (no accessibility permissions needed)
osascript -e '
tell application "Xcode"
    activate
    set workspaceDoc to front workspace document
    build workspaceDoc
end tell
'
```

### Read Build Results from xcactivitylog

```bash
LOG=$(ls -t ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build/*.xcactivitylog | head -1)
echo "Log: $LOG"
gunzip -c "$LOG" | strings | grep -E '(Build succeeded|Build failed|error:)' | sort -u
```

See `.claude/XCODE_BUILD_FIX_MODUS_OPERANDI.md` for detailed Phase 2 instructions.

---

## Known Issues and Solutions

### 1. CodeSign Error: "resource fork, Finder information, or similar detritus not allowed"

**Cause:** The project is located in an iCloud-synced directory (`~/Documents`). When Xcode copies resources to the derived data path, macOS File Provider adds extended attributes (`com.apple.FinderInfo`, `com.apple.fileprovider.fpfs#P`) that codesign rejects.

**Solution:** Build with a derived data path OUTSIDE of iCloud-synced locations:

```bash
# For command-line builds:
xcodebuild build \
    -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -destination 'platform=macOS' \
    -configuration Release \
    -derivedDataPath /tmp/TheaBuild

# For Xcode GUI:
# 1. Xcode → Settings → Locations → Derived Data → Custom → /tmp/TheaBuild
# OR
# 2. Move the project outside ~/Documents to a non-iCloud location
```

**Reference:** [Apple Technical Q&A QA1940](https://developer.apple.com/library/archive/qa/qa1940/_index.html)

---

### 2. Missing Package Products (Highlightr, KeychainAccess, MarkdownUI, OpenAI)

**Cause:** Swift Package Manager cache corruption or unresolved dependencies.

**Solution:**

```bash
# 1. Clean ALL package caches
rm -rf ~/Library/Developer/Xcode/DerivedData/Thea-*
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -f Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# 2. Resolve dependencies fresh
xcodebuild -resolvePackageDependencies -project Thea.xcodeproj

# 3. If still failing, close Xcode completely, then:
killall Xcode 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/Thea-*
# Then reopen Xcode and let it resolve packages
```

---

### 3. Signing Certificate Invalid/Expired

**Cause:** Development certificates expire or get revoked.

**Solution:**
1. Xcode → Settings → Accounts
2. Select your Apple ID
3. Click "Manage Certificates..."
4. Delete old/expired certificates
5. Click "+" to create new Apple Development certificate
6. Clean build folder (Cmd+Shift+K) and rebuild

---

## Build Commands Reference

### Debug Build (macOS)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodebuild build \
    -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -destination 'platform=macOS' \
    -configuration Debug \
    -derivedDataPath /tmp/TheaBuild
```

### Release Build (macOS)
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodebuild build \
    -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -destination 'platform=macOS' \
    -configuration Release \
    -derivedDataPath /tmp/TheaBuild
```

### iOS Simulator Build
```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
xcodebuild build \
    -project Thea.xcodeproj \
    -scheme Thea-iOS \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -configuration Debug
```

### Resolve Package Dependencies
```bash
xcodebuild -resolvePackageDependencies -project Thea.xcodeproj
```

### Regenerate Xcode Project (after project.yml changes)
```bash
xcodegen generate
```

---

## Verification Commands

### Verify Code Signature
```bash
codesign --verify --deep --strict --verbose=2 /path/to/Thea.app
```

### Clear Extended Attributes (if needed)
```bash
xattr -cr /path/to/Thea.app
```

### Check for Extended Attributes
```bash
xattr -lr /path/to/Thea.app
```

---

## Project Structure Notes

- **XcodeGen**: Project uses `project.yml` for project generation
- **SPM Dependencies**: Defined in Thea.xcodeproj (not Package.swift for app targets)
- **Deployment Targets**: macOS 26.0, iOS 26.0, watchOS 12.0, tvOS 26.0
- **Swift Version**: 6.0 with strict concurrency

---

## Quick Troubleshooting Checklist

1. [ ] Package dependencies resolved? (`xcodebuild -resolvePackageDependencies`)
2. [ ] DerivedData clean? (`rm -rf ~/Library/Developer/Xcode/DerivedData/Thea-*`)
3. [ ] Building to non-iCloud path? (`-derivedDataPath /tmp/TheaBuild`)
4. [ ] Signing certificates valid? (Xcode → Settings → Accounts → Manage Certificates)
5. [ ] Project regenerated after project.yml changes? (`xcodegen generate`)

---

## UI Bug Fixes (January 28, 2026)

### Fixed Issues:
1. **Left side panel show/hide button** - Fixed `toggleSidebar()` to use `columnVisibility` binding instead of unreliable `NSSplitViewController.toggleSidebar`
2. **Settings Appearance section buttons** - Added `LabeledContent` wrapper and explicit frame constraints for segmented pickers
3. **Settings Browse button (Model Directories)** - Changed `NSOpenPanel.begin()` to `runModal()` for reliable panel display
4. **Privacy and Advanced tabs inaccessible** - Increased settings window width from 650 to 800 pixels
5. **Self-Execution tab** - Removed from settings (per user request)
6. **Persistent microphone OSD icon** - Fixed `VoiceActivationManager` to properly stop audio engine when disabled

### Microphone Icon Fix:
If the mic icon persists in the menu bar after toggling Voice settings:
1. Open Thea Settings → Voice → Disable "Enable Voice Activation"
2. If still showing: System Settings → Privacy & Security → Microphone → Toggle Thea OFF
3. Or run: `sudo killall coreaudiod` (restarts Core Audio daemon)

---

## Automated UI Testing Tools (2026)

For future reference, these tools can help detect UI bugs:

1. **[Applitools](https://applitools.com/)** - AI visual testing
2. **[testRigor](https://testrigor.com/)** - Vision AI for UI elements
3. **[mabl](https://www.mabl.com/)** - Self-healing visual AI tests
4. **[Claude Computer Use](https://docs.claude.com/en/docs/agents-and-tools/tool-use/computer-use-tool)** - AI-powered screen interaction
5. **XCUITest** - Apple's native UI testing framework

---

*Last updated: January 28, 2026*
*Document created to prevent recurring build issues*
