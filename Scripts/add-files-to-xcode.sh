#!/bin/bash

# Script to help add new files to Xcode project
# Run this to see which files need to be added

echo "═══════════════════════════════════════════════════════════"
echo "  Files to Add to Xcode Project"
echo "═══════════════════════════════════════════════════════════"
echo ""

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"

# Define all files to add
FILES=(
    # Prompt Engineering
    "Shared/AI/PromptEngineering/PromptOptimizer.swift"
    "Shared/AI/PromptEngineering/PromptTemplateLibrary.swift"
    "Shared/AI/PromptEngineering/UserPreferenceModel.swift"

    # Code Excellence
    "Shared/Code/ErrorKnowledgeBase.swift"
    "Shared/Code/SwiftBestPracticesLibrary.swift"
    "Shared/Code/SwiftValidator.swift"

    # Managers
    "Shared/Core/Managers/ErrorKnowledgeBaseManager.swift"
    "Shared/Core/Managers/TabManager.swift"
    "Shared/Core/Managers/WindowManager.swift"

    # Models
    "Shared/Core/Models/PromptEngineeringModels.swift"
    "Shared/Core/Models/TrackingModels.swift"

    # Tracking
    "Shared/Tracking/BrowserHistoryTracker.swift"
    "Shared/Tracking/HealthTrackingManager.swift"
    "Shared/Tracking/InputTrackingManager.swift"
    "Shared/Tracking/LocationTrackingManager.swift"
    "Shared/Tracking/ScreenTimeTracker.swift"

    # UI Views
    "Shared/UI/Views/Tracking/LifeTrackingView.swift"
    "Shared/UI/Views/Settings/LifeTrackingSettingsView.swift"
)

# Check each file exists
echo "Checking file existence..."
echo ""
MISSING=0
for file in "${FILES[@]}"; do
    FULL_PATH="$PROJECT_DIR/$file"
    if [ -f "$FULL_PATH" ]; then
        echo "✓ $file"
    else
        echo "✗ MISSING: $file"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Summary: ${#FILES[@]} files total, $MISSING missing"
echo "═══════════════════════════════════════════════════════════"
echo ""

if [ $MISSING -eq 0 ]; then
    echo "All files exist! Ready to add to Xcode."
    echo ""
    echo "To add these files to Xcode:"
    echo "  1. Open Thea.xcodeproj in Xcode"
    echo "  2. Right-click in Project Navigator"
    echo "  3. Select 'Add Files to Thea'"
    echo "  4. Navigate to each directory and select the files"
    echo "  5. Ensure BOTH targets are checked:"
    echo "     - Thea-iOS"
    echo "     - Thea-macOS"
    echo "  6. Uncheck 'Copy items if needed'"
    echo "  7. Click 'Add'"
    echo ""
    echo "Opening Xcode now..."
    open "$PROJECT_DIR/Thea.xcodeproj"
else
    echo "ERROR: $MISSING files are missing!"
    exit 1
fi
