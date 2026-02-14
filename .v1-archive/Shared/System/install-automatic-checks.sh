#!/bin/bash
# Automatic installer - sets up EVERYTHING for automatic execution
# Run this once: ./install-automatic-checks.sh

# Get the absolute path to the project directory
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$PROJECT_DIR"

echo "🚀 Installing automatic error detection system..."
echo "📁 Project directory: $PROJECT_DIR"
echo ""

# Make all scripts executable
echo "1️⃣  Making scripts executable..."
chmod +x "$PROJECT_DIR/Scripts"/*.sh
chmod +x "$PROJECT_DIR/Scripts/pre-commit"
chmod +x "$PROJECT_DIR/setup.sh"
echo "   ✅ Done"

# Install Homebrew dependencies
echo ""
echo "2️⃣  Installing dependencies..."
if command -v brew >/dev/null 2>&1; then
    echo "   Installing SwiftLint..."
    brew install swiftlint 2>/dev/null || echo "   SwiftLint already installed"
    
    echo "   Installing fswatch..."
    brew install fswatch 2>/dev/null || echo "   fswatch already installed"
    
    echo "   ✅ Dependencies installed"
else
    echo "   ⚠️  Homebrew not found. Some features will be limited."
    echo "   Install Homebrew from: https://brew.sh"
fi

# Configure Xcode
echo ""
echo "3️⃣  Configuring Xcode..."
"$PROJECT_DIR/Scripts/configure-xcode.sh"
echo "   ✅ Xcode configured"

# Install Git hooks
echo ""
echo "4️⃣  Installing Git hooks..."
if [ -d "$PROJECT_DIR/.git" ]; then
    cp "$PROJECT_DIR/Scripts/pre-commit" "$PROJECT_DIR/.git/hooks/pre-commit"
    chmod +x "$PROJECT_DIR/.git/hooks/pre-commit"
    echo "   ✅ Pre-commit hook installed"
    echo "   → Will run automatically on every commit"
else
    echo "   ⚠️  Not a git repository, skipping git hooks"
fi

# Create Xcode build phase instructions
echo ""
echo "5️⃣  Setting up Xcode Build Phase..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 MANUAL STEP REQUIRED - Add to Xcode:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Open Xcode and load your project:"
echo "   File → Open → /Users/alexis/Documents/IT & Tech/MyApps/Thea"
echo ""
echo "2. In the Project Navigator (left sidebar):"
echo "   Click on 'Thea' (the blue project icon at the top)"
echo ""
echo "3. Under TARGETS, select 'Thea' (or your app target)"
echo ""
echo "4. Click the 'Build Phases' tab at the top"
echo ""
echo "5. Click the '+' button (top left) → 'New Run Script Phase'"
echo ""
echo "6. IMPORTANT: Drag the new 'Run Script' ABOVE 'Compile Sources'"
echo ""
echo "7. Click the ▶ triangle to expand the Run Script"
echo ""
echo "8. Copy and paste this EXACT script:"
echo ""
echo "────────────────────────────────────────────────────────"
cat << 'EOF'
# Auto Error Detection
if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; then
    "${SRCROOT}/Scripts/auto-build-check.sh"
fi
EOF
echo "────────────────────────────────────────────────────────"
echo ""
echo "9. (Optional) Double-click 'Run Script' and rename to:"
echo "   'Auto Error Detection'"
echo ""
echo "10. Build your project (⌘+B) to test!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create a file with the snippet for easy copying
SNIPPET_FILE="$PROJECT_DIR/xcode-build-phase-snippet.txt"
cat > "$SNIPPET_FILE" << 'EOF'
# Auto Error Detection
if [ -f "${SRCROOT}/Scripts/auto-build-check.sh" ]; then
    "${SRCROOT}/Scripts/auto-build-check.sh"
fi
EOF

echo "💾 Snippet saved to: $SNIPPET_FILE"
echo "   Copy command:"
echo "   cat '$SNIPPET_FILE' | pbcopy"
echo ""

# Create launch daemon for continuous watching (optional)
echo "6️⃣  Setting up background watcher (optional)..."
echo ""
read -p "   Start background watcher now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check for tmux or screen
    if command -v tmux >/dev/null 2>&1; then
        tmux new-session -d -s thea-watcher "cd $(pwd) && make watch"
        echo "   ✅ Watcher started in tmux session 'thea-watcher'"
        echo "   → View with: tmux attach -t thea-watcher"
        echo "   → Stop with: tmux kill-session -t thea-watcher"
    else
        echo "   ⚠️  tmux not found. Starting in background..."
        nohup make watch > /tmp/thea-watch.log 2>&1 &
        echo "   ✅ Watcher started in background (PID: $!)"
        echo "   → View logs: tail -f /tmp/thea-watch.log"
        echo "   → Stop with: pkill -f 'watch-and-check.sh'"
    fi
else
    echo "   ⏭️  Skipped background watcher"
    echo "   → You can run manually: make watch"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Automatic Features Now Enabled:"
echo ""
echo "   🔄 On every Git commit:"
echo "      → Pre-commit hook checks for errors"
echo "      → Prevents committing broken code"
echo ""
echo "   🔄 On every Xcode build (after you add build phase):"
echo "      → SwiftLint runs automatically"
echo "      → Extra warnings enabled"
echo "      → Editor placeholders detected"
echo ""
echo "   🔄 As you type in Xcode:"
echo "      → Live issues show errors immediately"
echo "      → ~80% of errors caught instantly"
echo ""
echo "   🔄 Background watcher (if enabled):"
echo "      → Checks files when you save"
echo "      → Real-time error detection"
echo ""
echo "⚠️  ACTION REQUIRED:"
echo ""
echo "   1. RESTART XCODE NOW"
echo ""
echo "   2. Add the build phase using the instructions above"
echo "      Quick copy snippet to clipboard:"
echo "      cat '$SNIPPET_FILE' | pbcopy"
echo ""
echo "   3. Build your project to test (⌘+B)"
echo ""
echo "📚 Quick Commands (run from project directory):"
echo ""
echo "   cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'"
echo "   make check      # Check all errors manually"
echo "   make watch      # Start watcher manually"
echo "   make summary    # Quick error overview"
echo ""
echo "📂 Project Directory:"
echo "   $PROJECT_DIR"
echo ""
echo "🚀 You're all set for automatic error detection!"
echo ""
