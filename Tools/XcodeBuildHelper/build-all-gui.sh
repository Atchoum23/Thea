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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"
WAIT_TIME="${1:-120}"  # Seconds to wait per build

SCHEMES=("Thea-iOS" "Thea-macOS" "Thea-watchOS" "Thea-tvOS")
RESULTS=()

echo "=============================================="
echo "  Xcode GUI Build - All Platforms"
echo "=============================================="
echo ""
echo "Wait time per build: ${WAIT_TIME}s"
echo "Schemes: ${SCHEMES[*]}"
echo ""

# Ensure Xcode is open with the project
if ! pgrep -x "Xcode" > /dev/null; then
    echo "Opening Xcode project..."
    open "$PROJECT_PATH"
    sleep 5
fi

# Build each scheme
for SCHEME in "${SCHEMES[@]}"; do
    echo ""
    echo "=============================================="
    echo "  Building: $SCHEME"
    echo "=============================================="
    echo ""

    if "$SCRIPT_DIR/xcode-gui-build.sh" "$SCHEME" "Debug" "$WAIT_TIME"; then
        RESULTS+=("$SCHEME: PASSED")
    else
        RESULTS+=("$SCHEME: FAILED")
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

FAILED=0
for RESULT in "${RESULTS[@]}"; do
    if [[ "$RESULT" == *"FAILED"* ]]; then
        echo "  [X] $RESULT"
        FAILED=1
    else
        echo "  [OK] $RESULT"
    fi
done

echo ""

if [ "$FAILED" -eq 1 ]; then
    echo "Some builds FAILED. Check Xcode for details."
    exit 1
else
    echo "All GUI builds PASSED!"
    exit 0
fi
