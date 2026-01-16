#!/bin/bash

################################################################################
# Copy-Paste Commands Reference
# Quick reference of all commonly used commands
# This file is for reference only - commands are shown below
################################################################################

cat << 'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  THEA - Automatic Error Detection Commands
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Project Directory:
/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  INSTALLATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Full automatic installation
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
./install-automatic-checks.sh

# Basic setup check
./setup.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DAILY COMMANDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Show all available commands
make help

# Full error scan
make check

# Quick error summary
make summary

# Run SwiftLint only
make lint

# Start file watcher
make watch

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VERIFICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check SwiftLint installed
swiftlint version

# Check fswatch installed
fswatch --version

# Check Git hook
ls -la .git/hooks/pre-commit

# Check Xcode settings
defaults read com.apple.dt.Xcode ShowLiveIssues

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  XCODE BUILD PHASE SNIPPET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Copy to clipboard
cat xcode-build-phase-snippet.txt | pbcopy

# Snippet content:
# Auto Error Detection
if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; then
    "${SRCROOT}/Scripts/auto-build-check.sh"
fi

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Reinstall everything
./install-automatic-checks.sh

# Reconfigure Xcode
./Scripts/configure-xcode.sh
killall Xcode

# Reinstall Git hooks
make hooks

# Clean build artifacts
make clean

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FILE WATCHER (OPTIONAL)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Start watcher (foreground)
make watch

# Start with tmux (background)
tmux new-session -d -s thea-watcher "cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development' && make watch"

# Attach to tmux session
tmux attach -t thea-watcher

# Detach: Ctrl+B, then D

# Stop watcher
tmux kill-session -t thea-watcher

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DIRECT SCRIPTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

./Scripts/auto-build-check.sh        # Build phase script
./Scripts/build-with-all-errors.sh   # Full scan
./Scripts/error-summary.sh           # Quick summary
./Scripts/watch-and-check.sh         # File watcher
./Scripts/configure-xcode.sh         # Xcode configuration

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 For more details, see:
   - START-HERE.md
   - QUICK-REFERENCE.md
   - XCODE-BUILD-PHASE-GUIDE.md
   - AUTO-ERROR-DETECTION-COMPLETE-GUIDE.md

EOF
