# XcodeBuildHelper

A standalone AppleScript application for triggering Xcode GUI builds programmatically.

## The Problem

When running AppleScript via `osascript` from a CLI tool (like Claude Code), the script inherits the Accessibility permissions of the parent process, not the terminal app itself. This causes "osascript is not allowed to send keystrokes" errors even when Terminal.app or Claude.app has Accessibility permissions.

## The Solution

This standalone AppleScript application can be granted its own Accessibility permissions, allowing it to control Xcode reliably regardless of how it's invoked.

## Setup

### 1. Compile the AppleScript (if not already done)

```bash
cd Tools/XcodeBuildHelper
osacompile -o XcodeBuildHelper.app XcodeBuildHelper.applescript
```

### 2. Grant Accessibility Permission

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Click the **+** button
3. Navigate to `Tools/XcodeBuildHelper/XcodeBuildHelper.app`
4. Add it and ensure the toggle is **ON**

### 3. Test It

```bash
./xcode-gui-build.sh Thea-macOS Debug
```

## Usage

### Single Build

```bash
# Build a specific scheme
./xcode-gui-build.sh Thea-iOS Debug

# With custom wait time (seconds)
./xcode-gui-build.sh Thea-macOS Debug 90
```

### All Platforms

```bash
# Build all 4 platforms via GUI
./build-all-gui.sh

# With custom wait time
./build-all-gui.sh 90
```

### Direct App Usage

```bash
# Open the app directly with arguments
open -a XcodeBuildHelper.app --args "Thea-iOS" "Debug"
```

## Files

| File | Description |
|------|-------------|
| `XcodeBuildHelper.applescript` | Source AppleScript code |
| `XcodeBuildHelper.app` | Compiled standalone app |
| `xcode-gui-build.sh` | CLI wrapper for single builds |
| `build-all-gui.sh` | CLI wrapper for all platforms |

## Troubleshooting

### "Not allowed to send keystrokes"

The app doesn't have Accessibility permission. Follow Setup step 2.

### Build log not found

The build may still be in progress. Increase the wait time:

```bash
./xcode-gui-build.sh Thea-iOS Debug 180  # 3 minutes
```

### Wrong scheme selected

Ensure Xcode has the project open and the scheme exists. The script types the scheme name, so it must match exactly.

## How It Works

1. The shell script calls `open -a XcodeBuildHelper.app --args <scheme> <config>`
2. XcodeBuildHelper.app activates Xcode and sends keystrokes:
   - `Ctrl+0` to open scheme chooser
   - Types the scheme name
   - `Return` to select
   - `Cmd+B` to build
3. The shell script waits and then parses the build log

## Integration with Claude Code

Add to your `.claude/AUTONOMOUS_BUILD_QA.md`:

```bash
# GUI builds using XcodeBuildHelper
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
./Tools/XcodeBuildHelper/build-all-gui.sh 120
```
