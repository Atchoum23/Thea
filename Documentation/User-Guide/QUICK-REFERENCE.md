# 📋 Quick Reference - Complete Commands for Thea Project

## 📁 Project Directory
```bash
/Users/alexis/Documents/IT\ &\ Tech/MyApps/Thea
```

---

## 🚀 Initial Setup (Run Once)

### Navigate to Project
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
```

### Run Automatic Installer
```bash
chmod +x install-automatic-checks.sh
./install-automatic-checks.sh
```

Or using Make:
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
make setup-auto
```

---

## 📋 Xcode Build Phase Snippet

### Copy to Clipboard (macOS)
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
cat xcode-build-phase-snippet.txt | pbcopy
```

### Or Copy Manually
```bash
# Auto Error Detection
if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; then
    "${SRCROOT}/Scripts/auto-build-check.sh"
fi
```

### Where to Paste
1. Open Xcode
2. Select Project "Thea" → Target "Thea"
3. Build Phases tab
4. Click `+` → "New Run Script Phase"
5. Drag ABOVE "Compile Sources"
6. Paste the snippet above

---

## 🛠️ Daily Commands

All commands should be run from the project directory:

```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
```

### Check All Errors
```bash
make check
```

Or directly:
```bash
./Scripts/build-with-all-errors.sh
```

### Quick Error Summary
```bash
make summary
```

Or directly:
```bash
./Scripts/error-summary.sh
```

### Start Background Watcher
```bash
make watch
```

Or directly:
```bash
./Scripts/watch-and-check.sh
```

### Run SwiftLint Only
```bash
make lint
```

Or directly:
```bash
swiftlint
```

### Auto-fix SwiftLint Issues
```bash
make fix-lint
```

Or directly:
```bash
swiftlint --fix
```

---

## 🔧 Script Paths (Full Paths)

### Make Scripts Executable
```bash
chmod +x '/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts'/*.sh
chmod +x '/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts/pre-commit'
```

### Individual Scripts
```bash
# Configure Xcode
'/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts/configure-xcode.sh'

# Full error check
'/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts/build-with-all-errors.sh'

# Error summary
'/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts/error-summary.sh'

# Background watcher
'/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts/watch-and-check.sh'

# Auto build check (used by Xcode)
'/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts/auto-build-check.sh'
```

---

## 🪝 Git Hooks

### Install Pre-commit Hook
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
cp Scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Test Pre-commit Hook
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
git add .
git commit -m "test"
```

### Bypass Pre-commit Hook (if needed)
```bash
git commit --no-verify -m "your message"
```

---

## 📊 View Error Reports

### Latest Error Report
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
ls -lt build-errors-*.txt | head -1
```

### View Latest Report
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
cat "$(ls -t build-errors-*.txt | head -1)"
```

### Clean Old Reports
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
make clean
```

Or directly:
```bash
rm '/Users/alexis/Documents/IT & Tech/MyApps/Thea/build-errors-'*.txt
```

---

## 🎯 Background Watcher (Advanced)

### Start in tmux Session
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
tmux new-session -d -s thea-watcher "make watch"
```

### Attach to Watch Session
```bash
tmux attach -t thea-watcher
```

### Detach from Session
Press: `Ctrl+B` then `D`

### Kill Watch Session
```bash
tmux kill-session -t thea-watcher
```

### Start Without tmux (Background)
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
nohup make watch > /tmp/thea-watch.log 2>&1 &
```

### View Background Watcher Logs
```bash
tail -f /tmp/thea-watch.log
```

### Stop Background Watcher
```bash
pkill -f 'watch-and-check.sh'
```

---

## 🔍 Configuration Files

### SwiftLint Configuration
```bash
open -e '/Users/alexis/Documents/IT & Tech/MyApps/Thea/.swiftlint.yml'
```

### Makefile
```bash
open -e '/Users/alexis/Documents/IT & Tech/MyApps/Thea/Makefile'
```

### VS Code Tasks
```bash
open -e '/Users/alexis/Documents/IT & Tech/MyApps/Thea/.vscode/tasks.json'
```

---

## 🆘 Troubleshooting

### Reset Xcode Preferences
```bash
defaults delete com.apple.dt.Xcode
```

### Reconfigure Xcode
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
./Scripts/configure-xcode.sh
```

### Reinstall Everything
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
./install-automatic-checks.sh
```

### Check Script Permissions
```bash
ls -la '/Users/alexis/Documents/IT & Tech/MyApps/Thea/Scripts'
```

### Make All Scripts Executable
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
chmod +x Scripts/*.sh Scripts/pre-commit setup.sh install-automatic-checks.sh
```

---

## 📱 Xcode Commands

### Build from Terminal
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
xcodebuild -scheme Thea -configuration Debug build
```

### Clean Build
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
xcodebuild -scheme Thea clean
```

### Show Build Settings
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
xcodebuild -scheme Thea -showBuildSettings
```

---

## 🔗 Useful Aliases (Optional)

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# Thea project shortcuts
alias thea-cd="cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'"
alias thea-check="cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make check"
alias thea-watch="cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make watch"
alias thea-summary="cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make summary"
alias thea-lint="cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make lint"
```

After adding, reload:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

Then use:
```bash
thea-cd       # Navigate to project
thea-check    # Check all errors
thea-watch    # Start watcher
thea-summary  # Quick summary
thea-lint     # Run SwiftLint
```

---

## 📚 Documentation Files

### Open Documentation
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'

# Main guide
open AUTO-ERROR-DETECTION-COMPLETE-GUIDE.md

# Quick reference
open QUICK-REFERENCE.md

# Xcode guide
open XCODE-BUILD-PHASE-GUIDE.md

# Scripts documentation
open Scripts/README.md
```

---

## ✅ Verification Commands

### Check Everything is Installed
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'

# Check Homebrew tools
command -v swiftlint && echo "✅ SwiftLint installed" || echo "❌ SwiftLint missing"
command -v fswatch && echo "✅ fswatch installed" || echo "❌ fswatch missing"
command -v tmux && echo "✅ tmux installed" || echo "❌ tmux missing (optional)"

# Check scripts
[ -x Scripts/configure-xcode.sh ] && echo "✅ configure-xcode.sh executable" || echo "❌ Not executable"
[ -x Scripts/build-with-all-errors.sh ] && echo "✅ build-with-all-errors.sh executable" || echo "❌ Not executable"
[ -x Scripts/auto-build-check.sh ] && echo "✅ auto-build-check.sh executable" || echo "❌ Not executable"

# Check git hook
[ -x .git/hooks/pre-commit ] && echo "✅ Pre-commit hook installed" || echo "❌ Pre-commit hook missing"

# Check configuration files
[ -f .swiftlint.yml ] && echo "✅ SwiftLint config exists" || echo "❌ SwiftLint config missing"
[ -f Makefile ] && echo "✅ Makefile exists" || echo "❌ Makefile missing"
```

---

## 🎯 Most Common Commands

### Daily Workflow
```bash
# 1. Navigate to project
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'

# 2. Check for errors before starting work
make check

# 3. Start background watcher (optional)
make watch

# 4. Code in Xcode normally
# Live issues will show errors as you type

# 5. Before committing
make check
git add .
git commit -m "your message"
# Pre-commit hook runs automatically
```

---

**Save this file for quick reference!**

Location: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/QUICK-REFERENCE.md`
