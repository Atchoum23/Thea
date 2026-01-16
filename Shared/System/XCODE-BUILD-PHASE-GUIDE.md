# 🎯 How to Add Automatic Error Detection to Xcode

## Quick Install (Automatic Everything!)

Run this ONE command:

```bash
chmod +x install-automatic-checks.sh
./install-automatic-checks.sh
```

Then follow the on-screen instructions.

---

## Manual Setup (If you prefer step-by-step)

### Step 1: Add Xcode Build Phase

#### Where to paste the snippet:

1. **Open your Xcode project**
   - Double-click your `.xcodeproj` file OR
   - Open Xcode and select your project

2. **Select your Target**
   - Click on your project name in the left sidebar (top item)
   - In the main area, look for "TARGETS" section
   - Click on your app target (probably named "Thea")

3. **Go to Build Phases**
   - Look for tabs at the top: General, Signing, Info, **Build Phases**, etc.
   - Click **Build Phases**

4. **Add New Run Script Phase**
   - Click the **`+`** button in the top-left
   - Select **"New Run Script Phase"**
   - A new phase appears at the bottom called "Run Script"

5. **Position it correctly**
   - **IMPORTANT:** Drag it to be **ABOVE** "Compile Sources"
   - This ensures it runs before compilation

6. **Expand the phase**
   - Click the disclosure triangle (▶) next to "Run Script"
   - You'll see a text box

7. **Paste this snippet:**

```bash
# Auto Error Detection
if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; then
    "${SRCROOT}/Scripts/auto-build-check.sh"
fi
```

8. **Rename the phase (optional)**
   - Double-click "Run Script" and rename to "Auto Error Detection"

9. **Save and test**
   - Press **⌘+B** to build
   - You should see "🔍 Running automatic error detection..." in build log

---

### Step 2: Verify Installation

After adding the build phase, build your project:

```bash
# In Xcode, press ⌘+B
# OR in terminal:
xcodebuild -scheme Thea -configuration Debug build
```

You should see in the build log:
```
🔍 Running automatic error detection...
Running SwiftLint...
✅ Automatic checks passed
```

---

## What Runs Automatically Now?

### ✅ On Every Build (in Xcode)
- SwiftLint code quality checks
- Editor placeholder detection
- Extra compiler warnings
- Stricter type checking

### ✅ On Every Commit (Git)
- Pre-commit hook runs
- Checks staged Swift files
- Prevents committing broken code
- Can bypass with `git commit --no-verify`

### ✅ As You Type (Xcode)
- Live issues enabled
- Errors appear immediately
- No build needed

### ✅ On File Save (Optional - Background Watcher)
- Continuous type checking
- Real-time error detection
- Runs in terminal background

---

## Visual Guide: Adding Build Phase

```
Xcode Project Navigator
├── 📁 YourProject
│   ├── 📄 Files...
│
└── 🎯 TARGETS
    └── Thea  ← Click here
        ├── General
        ├── Signing & Capabilities
        ├── Resource Tags
        ├── Info
        ├── Build Settings
        └── Build Phases  ← Then click here
            ├── Dependencies
            ├── [Auto Error Detection]  ← Add this (drag above Compile Sources)
            ├── Compile Sources
            ├── Link Binary With Libraries
            └── Copy Bundle Resources
```

### What the Build Phase looks like:

```
▼ Auto Error Detection                                    [−]
  Shell: /bin/sh
  
  ┌─────────────────────────────────────────────────────┐
  │ # Auto Error Detection                              │
  │ if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; │
  │     "${SRCROOT}/Scripts/auto-build-check.sh"       │
  │ fi                                                   │
  └─────────────────────────────────────────────────────┘
  
  ☐ Based on dependency analysis
  ☐ For install builds only
  ☑ Show environment variables in build log
  
  Input Files: (none)
  Output Files: (none)
```

---

## Testing Your Setup

### Test 1: Build Phase
```bash
# Build in Xcode (⌘+B)
# Check build log for:
# "🔍 Running automatic error detection..."
# "✅ Automatic checks passed"
```

### Test 2: Git Hook
```bash
# Make a change and commit
git add .
git commit -m "test"
# Should see: "🔍 Running pre-commit checks..."
```

### Test 3: Live Issues
```bash
# In Xcode, type something wrong
let x: String = 123
# Should see red error immediately (no build needed)
```

### Test 4: Background Watcher
```bash
# Start watcher
make watch
# Edit a Swift file and save
# Should see type-check output in terminal
```

---

## Troubleshooting

### Build phase doesn't run
- ✅ Check it's enabled (no checkmark to disable)
- ✅ Ensure it's above "Compile Sources"
- ✅ Verify path: `${SRCROOT}/Scripts/auto-build-check.sh` exists
- ✅ Make script executable: `chmod +x Scripts/auto-build-check.sh`

### "Permission denied" error
```bash
chmod +x Scripts/*.sh
```

### Git hook not running
```bash
# Reinstall
cp Scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Live issues not showing
- ✅ Xcode → Settings → General → Issues
- ✅ Enable "Show live issues"
- ✅ Restart Xcode

### SwiftLint not found
```bash
brew install swiftlint
```

---

## Advanced Configuration

### Disable Specific Checks

Edit `Scripts/auto-build-check.sh`:

```bash
# Comment out SwiftLint
# if command -v swiftlint >/dev/null 2>&1; then
#     swiftlint --quiet || true
# fi
```

### Add Custom Checks

Add to `Scripts/auto-build-check.sh`:

```bash
# Check for TODO comments
if grep -r "TODO:" --include="*.swift" .; then
    echo "warning: TODO comments found"
fi
```

### Adjust Strictness

Edit warnings in `Scripts/auto-build-check.sh`:

```bash
# Make warnings into errors
export GCC_TREAT_WARNINGS_AS_ERRORS="YES"
```

---

## Summary

### One-Time Setup:
1. Run `./install-automatic-checks.sh`
2. Add build phase to Xcode (see above)
3. Restart Xcode

### What Happens Automatically:
✅ Build checks (every build)
✅ Git pre-commit checks (every commit)  
✅ Live issues (as you type)  
✅ Background watcher (optional)  

### Manual Commands Still Available:
```bash
make check      # Full error scan
make summary    # Quick stats
make watch      # Start watcher
make lint       # Run SwiftLint
```

---

## Quick Reference Card

| When | What Runs | How to See |
|------|-----------|------------|
| **You type** | Live issues | Errors appear in editor |
| **You build** | Build phase | Build log, Issue Navigator |
| **You commit** | Pre-commit hook | Terminal output |
| **You save** | Watcher (optional) | Terminal window |
| **Manual** | `make check` | Terminal + saved report |

---

**Next:** Run `./install-automatic-checks.sh` and follow the prompts!
