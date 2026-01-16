# Quick Reference - All Commands

Full path: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development`

## 🚀 Make Commands

| Command | What It Does | When to Use |
|---------|--------------|-------------|
| `make help` | Show all commands | First time setup |
| `make check` | Full error scan (SwiftLint + build) | Before commits |
| `make summary` | Quick error statistics | Daily status check |
| `make lint` | Run SwiftLint only | Quick code quality check |
| `make watch` | Start file watcher | Active development |
| `make install` | Run full installer | Initial setup |
| `make xcode` | Configure Xcode settings | One-time setup |
| `make hooks` | Install Git hooks | One-time setup |
| `make clean` | Clean build artifacts | Troubleshooting |

## 📜 Direct Script Commands

### Automatic Scripts
```bash
# These run automatically - no need to call directly

# Runs on every Xcode build
./Scripts/auto-build-check.sh

# Runs on every Git commit
# (installed at .git/hooks/pre-commit)
```

### Manual Scripts
```bash
# Full comprehensive scan
./Scripts/build-with-all-errors.sh

# Quick error summary
./Scripts/error-summary.sh

# Continuous file monitoring
./Scripts/watch-and-check.sh

# Configure Xcode (run once)
./Scripts/configure-xcode.sh
```

## 🔧 SwiftLint Commands

```bash
# Run on all files
swiftlint

# Run with config
swiftlint lint --config .swiftlint.yml

# Auto-fix issues
swiftlint --fix

# Check specific file
swiftlint lint --path Shared/SomeFile.swift

# Quiet mode (errors only)
swiftlint lint --quiet
```

## 📊 Verification Commands

```bash
# Check if SwiftLint is installed
which swiftlint
swiftlint version

# Check if fswatch is installed
which fswatch
fswatch --version

# Check Xcode settings
defaults read com.apple.dt.Xcode ShowLiveIssues
defaults read com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks

# Check Git hook
ls -la .git/hooks/pre-commit

# Count Swift files
find . -name "*.swift" | wc -l
```

## 🎯 Git Commands

```bash
# Commit with validation
git commit -m "message"
# → Runs pre-commit checks automatically

# Skip validation (not recommended)
git commit --no-verify -m "message"

# Check what will be validated
git diff --cached --name-only | grep ".swift$"
```

## 🛠️ Troubleshooting Commands

```bash
# Reinstall everything
./install-automatic-checks.sh

# Just check prerequisites
./setup.sh

# Reconfigure Xcode
./Scripts/configure-xcode.sh
killall Xcode
open Thea.xcodeproj

# Reinstall Git hook
make hooks

# Clean and rebuild
make clean
xcodebuild clean build -project Thea.xcodeproj -scheme Thea-macOS
```

## 📱 Xcode Settings Commands

```bash
# Enable live issues
defaults write com.apple.dt.Xcode ShowLiveIssues -bool YES

# Enable parallel builds
defaults write com.apple.dt.Xcode IDEBuildOperationMaxNumberOfConcurrentCompileTasks -int 8

# Show build times
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES

# Reset Xcode settings
defaults delete com.apple.dt.Xcode
```

## 🔄 File Watcher Commands

```bash
# Start watcher (foreground)
make watch

# Start with tmux (background, persistent)
tmux new-session -d -s thea-watcher "cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development' && make watch"

# Attach to watcher session
tmux attach -t thea-watcher

# Detach from tmux
# Press: Ctrl+B, then D

# Stop watcher
# Press: Ctrl+C (if in foreground)
# Or: tmux kill-session -t thea-watcher
```

## 📦 Installation Commands

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install SwiftLint
brew install swiftlint

# Install fswatch
brew install fswatch

# Install tmux (optional)
brew install tmux
```

## 🎨 Output Examples

### Success
```
🔍 Running automatic error detection...
Running SwiftLint...
✅ Automatic checks passed
```

### With Errors
```
🔍 Running automatic error detection...
Running SwiftLint...
❌ SwiftLint found issues
UserDirectivesView.swift:106:1: error: Editor placeholder
```

### Summary Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Code Quality Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📄 Swift Files: 127

Running SwiftLint analysis...

❌ Errors:   2
⚠️  Warnings: 15

⚠️  Code Quality: Fair (warnings present)
```

## 📝 Notes

- All commands assume you're in: `/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development`
- Scripts must be executable: `chmod +x Scripts/*.sh`
- Xcode must be restarted after configuration changes
- Git hooks only work in git repositories
- File watcher requires `fswatch` to be installed

## 🆘 Quick Help

```bash
# Forgot a command?
make help

# Need details on scripts?
cat Scripts/README.md

# Full documentation?
cat AUTO-ERROR-DETECTION-COMPLETE-GUIDE.md
```
