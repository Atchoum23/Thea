#!/bin/bash
# Copy-Paste Setup Commands for Thea Project
# Just copy and paste each section into Terminal

echo "═══════════════════════════════════════════════════════════"
echo "🚀 THEA PROJECT - AUTOMATIC ERROR DETECTION SETUP"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Copy and paste each command section below into Terminal"
echo ""

cat << 'COMMANDS'

# ═══════════════════════════════════════════════════════════
# STEP 1: Navigate to Project Directory
# ═══════════════════════════════════════════════════════════

cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'

# ═══════════════════════════════════════════════════════════
# STEP 2: Make Installer Executable and Run It
# ═══════════════════════════════════════════════════════════

Send me 

# ═══════════════════════════════════════════════════════════
# STEP 3: Copy Build Phase Snippet to Clipboard
# ═══════════════════════════════════════════════════════════

cat xcode-build-phase-snippet.txt | pbcopy
echo "✅ Snippet copied to clipboard!"
echo "Now paste it into Xcode Build Phase (see instructions)"

# ═══════════════════════════════════════════════════════════
# AFTER ADDING XCODE BUILD PHASE:
# Test Your Setup
# ═══════════════════════════════════════════════════════════

# Build in Xcode (⌘+B) and check for:
# "🔍 Running automatic error detection..."

# ═══════════════════════════════════════════════════════════
# DAILY USE COMMANDS
# ═══════════════════════════════════════════════════════════

# Check all errors at once
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make check

# Quick error summary
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make summary

# Start background watcher
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make watch

# Run SwiftLint
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea' && make lint

COMMANDS

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📋 XCODE BUILD PHASE INSTRUCTIONS"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "After running the installer above:"
echo ""
echo "1. Open Xcode:"
echo "   File → Open → /Users/alexis/Documents/IT & Tech/MyApps/Thea"
echo ""
echo "2. In Project Navigator (⌘+1):"
echo "   Click 'Thea' (blue project icon)"
echo ""
echo "3. Select your target:"
echo "   Under TARGETS, click 'Thea'"
echo ""
echo "4. Go to Build Phases tab"
echo ""
echo "5. Click '+' button → 'New Run Script Phase'"
echo ""
echo "6. Drag 'Run Script' to be ABOVE 'Compile Sources'"
echo ""
echo "7. Click ▶ to expand it"
echo ""
echo "8. Press ⌘+V to paste the snippet (already in clipboard!)"
echo ""
echo "9. Build (⌘+B) to test"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
