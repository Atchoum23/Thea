# Xcode Build Phase Setup Guide

Complete step-by-step instructions for adding automatic error detection to your Xcode build.

## 📋 Overview

Adding a Run Script build phase will make SwiftLint run **automatically on every build** (⌘+B), catching errors before compilation.

**Time Required**: 2 minutes
**Difficulty**: Easy
**One-time setup**: Yes

## 🎯 What You'll Achieve

After this setup:
- ✅ SwiftLint runs on every build
- ✅ Build fails if code quality issues found
- ✅ See colored output in build log
- ✅ ~95% error coverage automatically

## 📝 Step-by-Step Instructions

### Step 1: Copy the Script Snippet

The snippet is in `xcode-build-phase-snippet.txt`. Copy it:

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
cat xcode-build-phase-snippet.txt | pbcopy
```

**Or manually copy this:**
```bash
# Auto Error Detection
if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; then
    "${SRCROOT}/Scripts/auto-build-check.sh"
fi
```

### Step 2: Open Xcode Project

```bash
open "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/Thea.xcodeproj"
```

### Step 3: Navigate to Build Phases

1. In the **Project Navigator** (left sidebar), click on **"Thea"** at the top (the blue project icon)
2. In the main area, select **TARGETS → Thea-macOS** (not the PROJECT)
3. Click the **"Build Phases"** tab at the top

You should see existing phases like:
- Dependencies
- Compile Sources
- Link Binary With Libraries
- etc.

### Step 4: Add New Run Script Phase

1. Click the **"+"** button in the top-left of the Build Phases section
2. Select **"New Run Script Phase"**

A new phase appears at the bottom named "Run Script"

### Step 5: Position the Script Phase

**CRITICAL**: The script must run **BEFORE** compilation.

1. **Click and drag** the "Run Script" phase
2. Drop it **ABOVE** the "Compile Sources" phase

**Correct order:**
```
✅ Run Script (Auto Error Detection)
✅ Compile Sources
✅ Link Binary With Libraries
```

**Incorrect order:**
```
❌ Compile Sources
❌ Run Script (Auto Error Detection)  ← Too late!
```

### Step 6: Configure the Script

1. Click the **▶** triangle next to "Run Script" to expand it
2. In the large text box, **paste** the snippet (⌘+V)
3. **Optional but recommended**: Change the name
   - Double-click "Run Script" at the top
   - Rename to: **"Auto Error Detection"**

### Step 7: Configure Script Options

Make sure these settings are correct:

| Setting | Value | Why |
|---------|-------|-----|
| Shell | `/bin/sh` | Default shell |
| Show environment variables in build log | ☐ Unchecked | Cleaner output |
| Run script: Based on dependency analysis | ☐ Unchecked | Run every time |
| Input Files | (empty) | Not needed |
| Output Files | (empty) | Not needed |

### Step 8: Test the Setup

1. **Save** (⌘+S) - Xcode auto-saves but just in case
2. **Build** the project (⌘+B)
3. Check the **build log**

**To view build log:**
- View → Navigators → Report Navigator (⌘+9)
- Click the latest build
- Look for the "Auto Error Detection" phase

### Step 9: Verify Output

**Expected Success Output:**
```
▸ Running script 'Auto Error Detection'
🔍 Running automatic error detection...
Running SwiftLint...
✅ Automatic checks passed
```

**If there are errors:**
```
▸ Running script 'Auto Error Detection'
🔍 Running automatic error detection...
Running SwiftLint...
❌ SwiftLint found issues
UserDirectivesView.swift:106:1: error: Editor placeholder in source file
```

## ✅ Verification Checklist

- [ ] Script phase exists in Build Phases
- [ ] Script phase is ABOVE "Compile Sources"
- [ ] Build succeeds (⌘+B)
- [ ] Build log shows "🔍 Running automatic error detection..."
- [ ] Script output appears in build log

## 🐛 Troubleshooting

### Problem: Script doesn't run

**Check:**
1. Is the script phase ABOVE "Compile Sources"?
2. Is the script pasted correctly?
3. Is Scripts/auto-build-check.sh executable?
   ```bash
   chmod +x Scripts/auto-build-check.sh
   ```

### Problem: "Permission denied"

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
chmod +x Scripts/auto-build-check.sh
```

### Problem: "SwiftLint not found"

```bash
brew install swiftlint
```

### Problem: Build fails every time

The script is working! It's finding real issues. To see details:
```bash
make check    # See full report
```

To temporarily disable:
- In Xcode, uncheck the "Auto Error Detection" phase
- Or comment out the script content (add `#` before each line)

### Problem: Can't find the build log

1. Press ⌘+9 (Report Navigator)
2. Click the most recent build
3. Click "Auto Error Detection" in the list
4. Or click "All Issues" to see errors

## 🎨 Customization

### Change when it runs

By default, runs on every build. To run only on clean builds:

Check: ☑ "Run script: Based on dependency analysis"

(Not recommended - may miss errors)

### Add more checks

Edit `Scripts/auto-build-check.sh` to add custom checks:

```bash
# Add after SwiftLint
echo "Running custom checks..."
# Your custom validation here
```

### Change output verbosity

Edit the script and add/remove `--quiet` flag:
```bash
swiftlint lint --quiet --config .swiftlint.yml  # Less output
swiftlint lint --config .swiftlint.yml          # Full output
```

## 📊 Performance

- **Clean Build**: +2-3 seconds (SwiftLint scan)
- **Incremental Build**: +0.5-1 second (fast checks)
- **Zero code changes**: +0.2 seconds (script overhead)

SwiftLint is very fast and won't significantly slow down builds.

## 🔄 Multiple Targets

If you have multiple targets (macOS, iOS, etc.), add the same script to each:

1. Select target (e.g., "Thea-iOS")
2. Repeat steps 4-7
3. Same script works for all platforms

## 🎯 What's Next?

After Xcode build phase is set up:

1. **Test it**: Make a syntax error, build (⌘+B), see it caught
2. **Try manual scan**: `make check`
3. **View summary**: `make summary`
4. **Optional**: Start file watcher: `make watch`

## 📊 Phase 7.9: Programmatic QA Tools Integration

Phase 7.9 implements programmatic access to all third-party QA tools mentioned in this guide and `QA_SETUP_GUIDE.md`. This allows Thea to run QA tools directly from within the app and configure them through the Settings UI.

### QA Tools Available Programmatically

| Tool | Purpose | Programmatic API |
|------|---------|------------------|
| **SwiftLint** | Static code analysis | `QAToolsManager.shared.runSwiftLint()` |
| **CodeCov** | Coverage reporting | `QAToolsManager.shared.uploadCoverage()` |
| **SonarCloud** | Code quality analysis | `QAToolsManager.shared.runSonarAnalysis()` |
| **DeepSource** | Automated code review | `QAToolsManager.shared.runDeepSourceAnalysis()` |

### Settings Integration

Navigate to **Settings → QA Tools** to:
- Configure API tokens for each service
- Set project paths and configuration files
- Run individual tools or full QA suite
- View QA results and history
- Toggle auto-run on build

### Implementation Details

See `QA_SETUP_GUIDE.md` for token setup and configuration details.

**Files Modified:**
- `Shared/Core/Configuration/AppConfiguration.swift` - Added `QAToolsConfiguration`
- `Shared/Services/QAToolsManager.swift` - QA tools execution service
- `Shared/UI/Views/Settings/QASettingsView.swift` - Settings UI

---

## 📚 Related Documentation

- `START-HERE.md` - Quick start guide
- `QUICK-REFERENCE.md` - All commands
- `Scripts/README.md` - Script documentation
- `AUTO-ERROR-DETECTION-COMPLETE-GUIDE.md` - Full guide
- `QA_SETUP_GUIDE.md` - QA tools setup and token configuration

---

**Questions?** Run `make help` or see `QUICK-REFERENCE.md`
