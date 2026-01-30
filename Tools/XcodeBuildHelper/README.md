# XcodeBuildHelper

Scripts for Xcode GUI build automation from the command line.

## The Problem

When building Xcode projects, CLI builds (`xcodebuild`) and Xcode GUI builds can show **different warnings**:
- Indexer warnings not visible in CLI
- Project settings warnings
- Capability/entitlement warnings
- Additional static analysis

## The Solution

Use `xcode-cli-with-gui-log.sh` - a hybrid approach that:
1. Runs `xcodebuild` CLI (no Accessibility permissions needed)
2. Writes to default DerivedData (Xcode GUI reads this)
3. Parses build logs automatically
4. Allows you to verify in Xcode's Issue Navigator

## Usage

### Single Scheme Build

```bash
# Ensure Xcode is open with the project first
open "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"

# Build macOS Debug
./Tools/XcodeBuildHelper/xcode-cli-with-gui-log.sh Thea-macOS Debug

# Build iOS Release
./Tools/XcodeBuildHelper/xcode-cli-with-gui-log.sh Thea-iOS Release
```

### All Platforms Build

```bash
# Build all 4 platforms
for scheme in Thea-iOS Thea-macOS Thea-watchOS Thea-tvOS; do
    ./Tools/XcodeBuildHelper/xcode-cli-with-gui-log.sh "$scheme" Debug
done
```

### Verify in Xcode GUI

After builds complete, open Xcode and press `Cmd+5` to view the Issue Navigator.
This shows any GUI-specific warnings that CLI may have missed.

## Files

| File | Purpose |
|------|---------|
| `xcode-cli-with-gui-log.sh` | **Main tool** - CLI build with GUI log viewing |
| `run-build-via-script-editor.sh` | Alternative for manual AppleScript testing |

## Why Not AppleScript Automation?

AppleScript-based automation (osascript, AppleScript apps) fails when run from CLI tools
like Claude Code due to macOS Accessibility permission model:

- **Error 1002**: "osascript is not allowed to send keystrokes"
- The Accessibility permission must be on the **calling process**, not just Terminal.app
- Subprocesses don't inherit Accessibility permissions from parent apps

The CLI approach used here avoids these issues entirely.

## Supported Schemes

- `Thea-iOS` - iOS platform
- `Thea-macOS` - macOS platform
- `Thea-watchOS` - watchOS platform
- `Thea-tvOS` - tvOS platform

## Configurations

- `Debug` - Development build with debug symbols
- `Release` - Optimized release build
