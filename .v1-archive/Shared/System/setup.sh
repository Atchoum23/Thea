#!/bin/bash
# One-time setup script - makes everything executable and ready to use

echo "🚀 Setting up error detection system..."
echo ""

# Make all scripts executable
echo "📝 Making scripts executable..."
chmod +x Scripts/*.sh
chmod +x Scripts/pre-commit
echo "   ✅ Scripts are now executable"

# Check for Homebrew
echo ""
echo "🍺 Checking for Homebrew..."
if command -v brew >/dev/null 2>&1; then
    echo "   ✅ Homebrew found"
else
    echo "   ⚠️  Homebrew not found"
    echo "   Install from: https://brew.sh"
    echo "   Then run: make install"
fi

# Check for SwiftLint
echo ""
echo "🔍 Checking for SwiftLint..."
if command -v swiftlint >/dev/null 2>&1; then
    echo "   ✅ SwiftLint found ($(swiftlint version))"
else
    echo "   ℹ️  SwiftLint not installed"
    echo "   Install with: brew install swiftlint"
    echo "   Or run: make install"
fi

# Check for fswatch
echo ""
echo "👀 Checking for fswatch..."
if command -v fswatch >/dev/null 2>&1; then
    echo "   ✅ fswatch found"
else
    echo "   ℹ️  fswatch not installed (needed for watch mode)"
    echo "   Install with: brew install fswatch"
    echo "   Or run: make install"
fi

# Configure Xcode
echo ""
echo "⚙️  Configuring Xcode..."
./Scripts/configure-xcode.sh

# Setup Git hooks (optional)
echo ""
read -p "Install Git pre-commit hook? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d .git ]; then
        cp Scripts/pre-commit .git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit
        echo "   ✅ Pre-commit hook installed"
    else
        echo "   ⚠️  Not a git repository"
    fi
else
    echo "   ⏭️  Skipped Git hook installation"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: Restart Xcode for changes to take effect!"
echo ""
echo "📚 Quick start:"
echo ""
echo "   make check     # Check all errors"
echo "   make summary   # Quick overview"
echo "   make watch     # Continuous checking"
echo "   make lint      # Run SwiftLint"
echo ""
echo "📖 Full documentation:"
echo "   • ERROR-DETECTION-GUIDE.md   - Complete guide"
echo "   • SETUP-ERROR-DETECTION.md   - Setup instructions"
echo "   • Scripts/README.md          - Script details"
echo ""
echo "🚀 Happy coding!"
echo ""
