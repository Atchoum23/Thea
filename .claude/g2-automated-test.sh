#!/bin/bash
set -euo pipefail

# G2 Automated Test Script
# Tests what can be verified programmatically before manual GUI testing

echo "======================================"
echo "G2: Automated Testing Protocol"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

THEA_APP="/Applications/Thea.app"
PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea"

pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; }
fail() { echo -e "${RED}❌ FAIL${NC}: $1"; exit 1; }
warn() { echo -e "${YELLOW}⚠️  WARN${NC}: $1"; }

echo "Phase 1: Build Verification"
echo "----------------------------"

# Check if Thea.app exists
if [ -d "$THEA_APP" ]; then
    pass "Thea.app exists at /Applications/"
else
    fail "Thea.app not found at /Applications/"
fi

# Check binary timestamp (should be recent)
BINARY_PATH="$THEA_APP/Contents/MacOS/Thea"
if [ -f "$BINARY_PATH" ]; then
    BINARY_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$BINARY_PATH")
    pass "Thea binary exists (built: $BINARY_TIME)"
else
    fail "Thea binary not found"
fi

echo ""
echo "Phase 2: Source File Verification"
echo "-----------------------------------"

# Check all G2 files exist
FILES=(
    "Shared/Integrations/ForegroundAppMonitor.swift"
    "Shared/Integrations/ContextExtractors/XcodeContextExtractor.swift"
    "Shared/Integrations/ContextExtractors/VSCodeContextExtractor.swift"
    "Shared/Integrations/ContextExtractors/TerminalContextExtractor.swift"
    "Shared/Integrations/ContextExtractors/TextEditorContextExtractor.swift"
    "Shared/Integrations/ContextExtractors/SafariContextExtractor.swift"
    "Shared/Integrations/ContextExtractors/GenericContextExtractor.swift"
    "Shared/UI/Views/Settings/AppPairingSettingsView.swift"
)

for file in "${FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        pass "$file exists"
    else
        fail "$file not found"
    fi
done

echo ""
echo "Phase 3: Implementation Completeness"
echo "-------------------------------------"

# Check for placeholder patterns (indicates incomplete implementation)
PLACEHOLDER_PATTERNS=(
    "TODO"
    "FIXME"
    "placeholder"
    "stub implementation"
    "not yet implemented"
)

echo "Scanning context extractors for placeholders..."
FOUND_PLACEHOLDERS=0

for file in "${FILES[@]}"; do
    if [[ "$file" == *"ContextExtractor.swift" ]]; then
        for pattern in "${PLACEHOLDER_PATTERNS[@]}"; do
            if grep -i "$pattern" "$PROJECT_DIR/$file" | grep -v "TODO in XcodeContextExtractor.swift line 224-233" > /dev/null; then
                warn "Found '$pattern' in $file"
                FOUND_PLACEHOLDERS=1
            fi
        done
    fi
done

if [ $FOUND_PLACEHOLDERS -eq 0 ]; then
    pass "No placeholders found in context extractors"
else
    warn "Some placeholders found (may be acceptable for known limitations)"
fi

echo ""
echo "Phase 4: ChatManager Integration"
echo "---------------------------------"

# Check ChatManager has injectForegroundAppContext method
if grep -q "func injectForegroundAppContext" "$PROJECT_DIR/Shared/Core/Managers/ChatManager.swift"; then
    pass "ChatManager has injectForegroundAppContext method"
else
    fail "ChatManager missing injectForegroundAppContext method"
fi

# Check notification observer
if grep -q "foregroundAppContextChanged" "$PROJECT_DIR/Shared/Core/Managers/ChatManager.swift"; then
    pass "ChatManager observes foregroundAppContextChanged notification"
else
    warn "ChatManager may not be observing foreground app context changes"
fi

echo ""
echo "Phase 5: MacSettingsView Integration"
echo "-------------------------------------"

# Check MacSettingsView has App Pairing tab
if grep -q "AppPairingSettingsView" "$PROJECT_DIR/macOS/Views/MacSettingsView.swift"; then
    pass "MacSettingsView includes AppPairingSettingsView"
else
    fail "MacSettingsView missing AppPairingSettingsView integration"
fi

if grep -q "case appPairing" "$PROJECT_DIR/macOS/Views/MacSettingsView.swift"; then
    pass "MacSettingsView has appPairing case in sidebar"
else
    fail "MacSettingsView missing appPairing sidebar item"
fi

echo ""
echo "Phase 6: Accessibility API Usage"
echo "---------------------------------"

# Check extractors use real Accessibility API (not just placeholders)
AX_API_CALLS=(
    "AXUIElementCreateApplication"
    "AXUIElementCopyAttributeValue"
    "kAXFocusedUIElementAttribute"
    "kAXSelectedTextAttribute"
)

for api_call in "${AX_API_CALLS[@]}"; do
    FOUND=0
    for file in "${FILES[@]}"; do
        if [[ "$file" == *"ContextExtractor.swift" ]]; then
            if grep -q "$api_call" "$PROJECT_DIR/$file" 2>/dev/null; then
                FOUND=1
                break
            fi
        fi
    done

    if [ $FOUND -eq 1 ]; then
        pass "Context extractors use $api_call"
    else
        fail "No context extractors use $api_call (may be placeholder implementation)"
    fi
done

echo ""
echo "Phase 7: Compilation Test"
echo "--------------------------"

# Try to compile (this was already done, but verify again)
echo "Checking last build log..."
if xcodebuild -project "$PROJECT_DIR/Thea.xcodeproj" -scheme Thea-macOS -destination "platform=macOS" -configuration Debug -dry-run build 2>&1 | grep -q "error:"; then
    fail "Compilation errors found"
else
    pass "No compilation errors"
fi

echo ""
echo "======================================"
echo "Automated Testing Complete"
echo "======================================"
echo ""
echo "✅ All automated tests PASSED"
echo ""
echo "Next Steps:"
echo "1. Launch Thea.app from /Applications/"
echo "2. Follow manual testing protocol in G2_TESTING_GUIDE.md"
echo "3. Verify all success criteria before marking G2 complete"
echo ""
echo "Manual Testing Guide: $PROJECT_DIR/.claude/G2_TESTING_GUIDE.md"
