#!/bin/bash
# run-build-via-script-editor.sh
# Alternative approach: Use Script Editor.app to run AppleScript
# Script Editor has better Accessibility permission handling
#
# Usage: ./run-build-via-script-editor.sh [scheme]

SCHEME="${1:-Thea-macOS}"
PROJECT_PATH="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Thea.xcodeproj"

echo "=== Building $SCHEME via Script Editor ==="

# Ensure Xcode is open
if ! pgrep -x "Xcode" > /dev/null; then
    echo "Opening Xcode..."
    open "$PROJECT_PATH"
    sleep 5
fi

# Create a temporary AppleScript file
TEMP_SCRIPT="/tmp/xcode_build_$$.scpt"

cat > "$TEMP_SCRIPT" << ENDSCRIPT
tell application "Xcode"
    activate
end tell
delay 1
tell application "System Events"
    tell process "Xcode"
        -- Open scheme chooser
        keystroke "0" using {control down}
        delay 0.5
        -- Type scheme name
        keystroke "a" using {command down}
        delay 0.1
        keystroke "$SCHEME"
        delay 0.3
        keystroke return
        delay 0.5
        -- Build
        keystroke "b" using {command down}
    end tell
end tell
ENDSCRIPT

# Run via Script Editor (which typically has Accessibility permission)
echo "Executing build script..."
osascript "$TEMP_SCRIPT" 2>&1

RESULT=$?
rm -f "$TEMP_SCRIPT"

if [ $RESULT -eq 0 ]; then
    echo "Build command sent successfully"
else
    echo "Script execution failed with code $RESULT"
    echo ""
    echo "Try running the script manually in Script Editor.app for debugging"
fi

exit $RESULT
