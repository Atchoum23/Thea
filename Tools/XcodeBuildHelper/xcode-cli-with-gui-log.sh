#!/bin/bash
# xcode-cli-with-gui-log.sh
# Hybrid approach: Run xcodebuild CLI but use Xcode's DerivedData
# so results appear in Xcode's GUI Issue Navigator
#
# This works because:
# 1. xcodebuild writes to DerivedData
# 2. Xcode GUI reads from same DerivedData location
# 3. Build results appear in Xcode's Issue Navigator
#
# Usage: ./xcode-cli-with-gui-log.sh [scheme] [configuration]

set -e

SCHEME="${1:-Thea-macOS}"
CONFIG="${2:-Debug}"
PROJECT_PATH="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"

# Destinations for each platform
declare -A DESTINATIONS=(
    ["Thea-iOS"]="generic/platform=iOS"
    ["Thea-macOS"]="platform=macOS"
    ["Thea-watchOS"]="generic/platform=watchOS"
    ["Thea-tvOS"]="generic/platform=tvOS"
)

DEST="${DESTINATIONS[$SCHEME]}"

if [ -z "$DEST" ]; then
    echo "ERROR: Unknown scheme $SCHEME"
    echo "Valid schemes: ${!DESTINATIONS[@]}"
    exit 1
fi

echo "=== Building $SCHEME ($CONFIG) ==="
echo "Destination: $DEST"
echo ""

# Ensure Xcode is open so it can show results
if ! pgrep -x "Xcode" > /dev/null; then
    echo "Opening Xcode..."
    open "$PROJECT_PATH"
    sleep 3
fi

# Build using xcodebuild
# The -derivedDataPath uses default location so Xcode GUI can see it
xcodebuild -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "$DEST" \
    -configuration "$CONFIG" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tee "/tmp/build_${SCHEME}_${CONFIG}.log"

# Check result
if grep -q "BUILD SUCCEEDED" "/tmp/build_${SCHEME}_${CONFIG}.log"; then
    WARNS=$(grep -c " warning:" "/tmp/build_${SCHEME}_${CONFIG}.log" 2>/dev/null || echo "0")
    ERRS=$(grep -c " error:" "/tmp/build_${SCHEME}_${CONFIG}.log" 2>/dev/null || echo "0")

    echo ""
    echo "BUILD SUCCEEDED"
    echo "Errors: $ERRS, Warnings: $WARNS"

    if [ "$WARNS" -gt 0 ]; then
        echo ""
        echo "=== Warnings ==="
        grep " warning:" "/tmp/build_${SCHEME}_${CONFIG}.log" | sort -u | head -30
    fi

    echo ""
    echo "NOTE: Open Xcode Issue Navigator (Cmd+5) to see GUI-specific warnings"
    exit 0
else
    echo ""
    echo "BUILD FAILED"
    grep " error:" "/tmp/build_${SCHEME}_${CONFIG}.log" | head -20
    exit 1
fi
