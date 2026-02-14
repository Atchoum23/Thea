#!/bin/bash

# Verification script to check if all new files are in Xcode project

echo "═══════════════════════════════════════════════════════════"
echo "  Verifying Files in Xcode Project"
echo "═══════════════════════════════════════════════════════════"
echo ""

PROJECT_FILE="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development/Thea.xcodeproj/project.pbxproj"

# Files to check
FILES=(
    "PromptOptimizer.swift"
    "PromptTemplateLibrary.swift"
    "UserPreferenceModel.swift"
    "ErrorKnowledgeBase.swift"
    "SwiftBestPracticesLibrary.swift"
    "SwiftValidator.swift"
    "ErrorKnowledgeBaseManager.swift"
    "TabManager.swift"
    "WindowManager.swift"
    "PromptEngineeringModels.swift"
    "TrackingModels.swift"
    "BrowserHistoryTracker.swift"
    "HealthTrackingManager.swift"
    "InputTrackingManager.swift"
    "LocationTrackingManager.swift"
    "ScreenTimeTracker.swift"
    "LifeTrackingView.swift"
    "LifeTrackingSettingsView.swift"
)

MISSING=0
FOUND=0

for file in "${FILES[@]}"; do
    if grep -q "$file" "$PROJECT_FILE"; then
        echo "✓ $file (in project)"
        FOUND=$((FOUND + 1))
    else
        echo "✗ $file (NOT in project)"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Results: $FOUND found, $MISSING missing"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ $MISSING -eq 0 ]; then
    echo "✓ SUCCESS: All files added to Xcode project!"
    echo ""
    echo "Now running clean build to verify..."
    echo ""
    cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
    xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -destination 'platform=macOS' clean build 2>&1 | tail -20
else
    echo "✗ INCOMPLETE: $MISSING files still need to be added"
    exit 1
fi
