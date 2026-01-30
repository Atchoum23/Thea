#!/bin/bash
# xcode-gui-build.sh - Wrapper script for XcodeBuildHelper.app
# This script triggers GUI builds in Xcode using a standalone AppleScript app
# that has its own Accessibility permissions.
#
# SETUP:
# 1. Run this script once, it will fail
# 2. Go to System Settings > Privacy & Security > Accessibility
# 3. Add XcodeBuildHelper.app (located in this directory)
# 4. Run this script again
#
# Usage: ./xcode-gui-build.sh [scheme] [configuration]
# Example: ./xcode-gui-build.sh Thea-iOS Debug

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer /Applications version if installed, fallback to local
if [ -d "/Applications/XcodeBuildHelper.app" ]; then
    APP_PATH="/Applications/XcodeBuildHelper.app"
else
    APP_PATH="$SCRIPT_DIR/XcodeBuildHelper.app"
fi
PROJECT_PATH="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"

SCHEME="${1:-Thea-macOS}"
CONFIG="${2:-Debug}"
WAIT_TIME="${3:-120}"  # Default wait time in seconds

echo "=== Xcode GUI Build ==="
echo "Scheme: $SCHEME"
echo "Configuration: $CONFIG"
echo "Wait time: ${WAIT_TIME}s"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: XcodeBuildHelper.app not found at $APP_PATH"
    echo "Run: osacompile -o XcodeBuildHelper.app XcodeBuildHelper.applescript"
    exit 1
fi

# Ensure Xcode project is open
if ! pgrep -x "Xcode" > /dev/null; then
    echo "Opening Xcode project..."
    open "$PROJECT_PATH"
    sleep 5
fi

# Run the AppleScript app with arguments
echo "Triggering build via XcodeBuildHelper.app..."
open -a "$APP_PATH" --args "$SCHEME" "$CONFIG" 2>&1 || {
    echo ""
    echo "==============================================="
    echo "PERMISSION ERROR: XcodeBuildHelper.app needs Accessibility permission"
    echo ""
    echo "To fix:"
    echo "1. Open System Settings > Privacy & Security > Accessibility"
    echo "2. Click the '+' button"
    echo "3. Navigate to: $APP_PATH"
    echo "4. Add it to the list and enable the toggle"
    echo "5. Run this script again"
    echo "==============================================="
    exit 1
}

echo "Build command sent. Waiting ${WAIT_TIME}s for completion..."
sleep "$WAIT_TIME"

echo ""
echo "=== Checking Build Results ==="

# Find latest build log
find_latest_xcactivitylog() {
    find ~/Library/Developer/Xcode/DerivedData/Thea-*/Logs/Build \
        -name "*.xcactivitylog" -mmin -5 2>/dev/null | sort -r | head -1
}

LOG_FILE=$(find_latest_xcactivitylog)

if [ -z "$LOG_FILE" ]; then
    echo "WARNING: No recent build log found. Build may still be in progress."
    echo "Check Xcode GUI manually."
    exit 0
fi

echo "Found log: $LOG_FILE"

# Try XCLogParser first
if command -v xclogparser &>/dev/null; then
    echo "Parsing with XCLogParser..."
    xclogparser parse --file "$LOG_FILE" --reporter issues --output /tmp/build_issues.json 2>/dev/null

    if [ -f /tmp/build_issues.json ]; then
        ERROR_COUNT=$(cat /tmp/build_issues.json | jq '.errors | length' 2>/dev/null || echo "0")
        WARNING_COUNT=$(cat /tmp/build_issues.json | jq '.warnings | length' 2>/dev/null || echo "0")

        echo ""
        echo "Results: $ERROR_COUNT errors, $WARNING_COUNT warnings"

        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo ""
            echo "=== ERRORS ==="
            cat /tmp/build_issues.json | jq -r '.errors[] | "\(.documentURL):\(.startingLineNumber): \(.title)"' 2>/dev/null | head -20
        fi

        if [ "$WARNING_COUNT" -gt 0 ]; then
            echo ""
            echo "=== WARNINGS ==="
            cat /tmp/build_issues.json | jq -r '.warnings[] | "\(.documentURL):\(.startingLineNumber): \(.title)"' 2>/dev/null | head -30
        fi

        rm -f /tmp/build_issues.json

        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo ""
            echo "BUILD FAILED with $ERROR_COUNT errors"
            exit 1
        elif [ "$WARNING_COUNT" -gt 0 ]; then
            echo ""
            echo "BUILD SUCCEEDED with $WARNING_COUNT warnings"
            exit 0
        else
            echo ""
            echo "BUILD SUCCEEDED with 0 warnings"
            exit 0
        fi
    fi
fi

# Fallback to gunzip parsing
echo "Parsing with gunzip (fallback)..."
TEMP_LOG="/tmp/build_log_$(date +%s).txt"
gunzip -c "$LOG_FILE" 2>/dev/null | strings > "$TEMP_LOG"

WARNING_COUNT=$(grep -cE '\.swift:[0-9]+:[0-9]+: warning:' "$TEMP_LOG" 2>/dev/null || echo "0")
ERROR_COUNT=$(grep -cE '\.swift:[0-9]+:[0-9]+: error:' "$TEMP_LOG" 2>/dev/null || echo "0")

echo ""
echo "Results: $ERROR_COUNT errors, $WARNING_COUNT warnings"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo ""
    echo "=== ERRORS ==="
    grep -E '\.swift:[0-9]+:[0-9]+: error:' "$TEMP_LOG" | sort -u | head -20
fi

if [ "$WARNING_COUNT" -gt 0 ]; then
    echo ""
    echo "=== WARNINGS ==="
    grep -E '\.swift:[0-9]+:[0-9]+: warning:' "$TEMP_LOG" | sort -u | head -30
fi

rm -f "$TEMP_LOG"

if [ "$ERROR_COUNT" -gt 0 ]; then
    exit 1
fi

echo ""
echo "BUILD COMPLETE"
