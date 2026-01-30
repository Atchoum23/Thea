#!/bin/bash
# build-all-gui.sh - Build all 4 platforms via Xcode GUI
# Runs XcodeBuildHelper.app for each scheme
#
# SETUP:
# 1. Ensure XcodeBuildHelper.app has Accessibility permission
# 2. Run: ./build-all-gui.sh
#
# Usage: ./build-all-gui.sh [wait_time_per_build]
# Example: ./build-all-gui.sh 90

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"
WAIT_TIME="${1:-120}"  # Seconds to wait per build

echo "=============================================="
echo "  Xcode GUI Build - All Platforms"
echo "=============================================="
echo ""
echo "Wait time per build: ${WAIT_TIME}s"
echo "Schemes: Thea-iOS Thea-macOS Thea-watchOS Thea-tvOS"
echo ""

# Ensure Xcode is open with the project
if ! pgrep -x "Xcode" > /dev/null; then
    echo "Opening Xcode project..."
    open "$PROJECT_PATH"
    sleep 5
fi

# Track results
FAILED=0

# Build each scheme
for SCHEME in Thea-iOS Thea-macOS Thea-watchOS Thea-tvOS; do
    echo ""
    echo "=============================================="
    echo "  Building: $SCHEME"
    echo "=============================================="
    echo ""

    if "$SCRIPT_DIR/xcode-gui-build.sh" "$SCHEME" "Debug" "$WAIT_TIME"; then
        echo "  [OK] $SCHEME: PASSED"
    else
        echo "  [X] $SCHEME: FAILED"
        FAILED=1
    fi

    # Small delay between builds
    sleep 2
done

# Summary
echo ""
echo "=============================================="
echo "  Build Summary"
echo "=============================================="
echo ""

if [ "$FAILED" -eq 1 ]; then
    echo "Some builds FAILED. Check Xcode for details."
    exit 1
else
    echo "All GUI builds PASSED!"
    exit 0
fi
