# 🤖 CLAUDE.APP PROMPT - Thea Error Detection Setup

Copy the entire prompt below and paste it into Claude.app (Claude Code mode):

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

I need help setting up an automatic error detection system for my Xcode Swift project located at:

**Project Path:** `/Users/alexis/Documents/IT & Tech/MyApps/Thea`

**Project Name:** Thea

**Platform:** macOS app (Swift + SwiftUI)

## Current Situation

I have the following files already created in my project directory:

### Documentation Files
- `START-HERE.md`
- `AUTO-ERROR-DETECTION-COMPLETE-GUIDE.md`
- `QUICK-REFERENCE.md`
- `DOCUMENTATION-INDEX.md`
- `ERROR-DETECTION-GUIDE.md`
- `IMPLEMENTATION-SUMMARY.md`
- `XCODE-BUILD-PHASE-GUIDE.md`

### Setup Scripts
- `install-automatic-checks.sh` (main installer)
- `setup.sh` (basic setup)
- `COPY-PASTE-COMMANDS.sh` (command reference)
- `Makefile` (quick commands)

### Configuration Files
- `.swiftlint.yml` (SwiftLint configuration)
- `.vscode/tasks.json` (VS Code integration)
- `xcode-build-phase-snippet.txt` (will be created by installer)

### Scripts Directory (`Scripts/`)
- `auto-build-check.sh` - Runs on every Xcode build
- `pre-commit` - Git pre-commit hook
- `configure-xcode.sh` - Configures Xcode settings
- `build-with-all-errors.sh` - Full error scanner
- `error-summary.sh` - Quick error statistics
- `watch-and-check.sh` - Background file watcher
- `README.md` - Script documentation

## What I Need You To Do

Please help me execute the complete setup by:

1. **Verifying all files exist** at the project path
2. **Making all scripts executable** 
3. **Running the automatic installer** (`install-automatic-checks.sh`)
4. **Installing dependencies** (SwiftLint, fswatch via Homebrew)
5. **Configuring Xcode** for automatic error detection
6. **Installing Git hooks** for pre-commit validation
7. **Providing the exact Xcode Build Phase snippet** to paste
8. **Testing the setup** to ensure everything works

## Specific Commands to Execute

Run these in order from the project directory:

```bash
# Navigate to project
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'

# Make installer executable
chmod +x install-automatic-checks.sh

# Make all scripts executable
chmod +x Scripts/*.sh Scripts/pre-commit setup.sh

# Verify files exist
ls -la | grep -E "(\.sh$|\.md$|Makefile)"
ls -la Scripts/

# Run the installer
./install-automatic-checks.sh

# After installer completes, copy snippet to clipboard
cat xcode-build-phase-snippet.txt | pbcopy
```

## Expected Output

After running the installer, I should see:
- ✅ Scripts made executable
- ✅ Dependencies installed (SwiftLint, fswatch)
- ✅ Xcode configured for live issues
- ✅ Git pre-commit hook installed
- ✅ Instructions for adding Xcode Build Phase
- ✅ Snippet copied to clipboard

## Xcode Build Phase Setup

I need clear instructions on:

1. **Where to add the Build Phase:**
   - Project: Thea
   - Target: Thea (under TARGETS)
   - Tab: Build Phases

2. **What to paste:** The snippet from `xcode-build-phase-snippet.txt`

3. **Where to position it:** ABOVE "Compile Sources"

4. **How to test it:** Build (⌘+B) and look for "🔍 Running automatic error detection..." in build log

## What This System Should Do Automatically

After setup, the following should happen automatically:

1. **As I type in Xcode:** Live errors appear (~80% coverage)
2. **On every build (⌘+B):** SwiftLint runs + extra checks (~95% coverage)
3. **On every commit:** Pre-commit hook validates code
4. **Optional background watcher:** Checks files when saved (~99% coverage)

## Manual Commands I Should Be Able to Run

```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'

make check      # Check all errors at once
make summary    # Quick error overview
make watch      # Start background watcher
make lint       # Run SwiftLint
make help       # Show all available commands
```

## Current Errors to Fix

I have these existing errors/warnings in my project that need fixing:

1. **ScreenCapture.swift** (3 warnings):
   - Line 128, 219, 285: `CGWindowListCreateImage` deprecated in macOS 14.0
   - Should use ScreenCaptureKit instead (already have modern implementation, just need to suppress legacy warnings)

2. **UserDirectivesView.swift**:
   - Editor placeholder issues (should be fixed now)

3. **WellnessViewModel.swift**:
   - Unreachable catch block (should be fixed now)

## Verification Steps

After setup, help me verify:

1. **Scripts are executable:**
   ```bash
   ls -la Scripts/*.sh | grep rwx
   ```

2. **Dependencies installed:**
   ```bash
   which swiftlint
   which fswatch
   ```

3. **Git hook installed:**
   ```bash
   ls -la .git/hooks/pre-commit
   ```

4. **Xcode configured:**
   ```bash
   defaults read com.apple.dt.Xcode ShowLiveIssues
   ```

5. **Can run make commands:**
   ```bash
   make help
   ```

## Troubleshooting Help Needed

If anything fails, please help me:

1. Check permissions on scripts
2. Verify Homebrew is installed
3. Ensure we're in the correct directory
4. Check if .git directory exists
5. Verify Xcode settings were applied

## Expected Final State

After your help, I should have:

✅ All scripts executable and tested
✅ SwiftLint and fswatch installed
✅ Xcode configured for live issues
✅ Git pre-commit hook active
✅ Build phase snippet ready to paste
✅ All make commands working
✅ Documentation accessible
✅ Setup verified and tested

## Additional Context

- I'm using **macOS** (latest version)
- I have **Xcode** installed
- I have **Homebrew** installed
- This is a **Swift + SwiftUI** project
- Project has both **iOS** and **macOS** targets
- I want **maximum error detection** to avoid build-fix-build cycles

## Questions to Answer

Please also answer these:

1. Are all the necessary files present in the directory?
2. What's the best order to run the commands?
3. Should I restart Xcode before or after adding the build phase?
4. How do I know if the automatic error detection is working?
5. What should I do if I encounter permission errors?

## Final Request

Please:
1. ✅ Execute all setup commands
2. ✅ Show me the output of each step
3. ✅ Verify everything is working
4. ✅ Provide the final Xcode Build Phase snippet
5. ✅ Give me a summary of what's now automatic
6. ✅ List any issues encountered and how they were resolved

Thank you! I'm ready to paste this into Claude.app and get started.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
