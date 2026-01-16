#!/bin/bash

# Phase 6.3-6.7 Build Verification Script
# Verifies all files are created and builds the project

set -e

PROJECT_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
SCHEME="Thea-macOS"
CONFIGURATION="Debug"

echo "=================================================="
echo "Phase 6.3-6.7 Build Verification"
echo "=================================================="
echo ""

# Change to project directory
cd "$PROJECT_DIR"

echo "✓ Changed to project directory: $PROJECT_DIR"
echo ""

# Verify created files exist
echo "Checking created files..."
echo ""

FILES=(
    "Shared/AI/MetaAI/WorkflowTemplates.swift"
    "Shared/AI/MetaAI/WorkflowPersistence.swift"
    "Shared/AI/MetaAI/MCPToolBridge.swift"
    "Shared/AI/MetaAI/SystemToolBridge.swift"
    "Shared/UI/Components/ToolCallView.swift"
    "Shared/Core/Models/ToolCall.swift"
    "Shared/UI/Views/MCPBrowserView.swift"
    "Shared/UI/Components/MCPServerRow.swift"
    "Shared/UI/Components/MCPToolList.swift"
    "Shared/UI/Components/ScreenshotPreview.swift"
)

MISSING_FILES=0

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ MISSING: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

echo ""

if [ $MISSING_FILES -gt 0 ]; then
    echo "❌ $MISSING_FILES files are missing!"
    echo ""
    echo "Please ensure all files are created in the correct locations."
    exit 1
else
    echo "✓ All files present"
fi

echo ""
echo "=================================================="
echo "Generating Xcode project..."
echo "=================================================="
echo ""

xcodegen generate

if [ $? -eq 0 ]; then
    echo "✓ Project generated successfully"
else
    echo "❌ Project generation failed"
    exit 1
fi

echo ""
echo "=================================================="
echo "Building project..."
echo "=================================================="
echo ""

xcodebuild -scheme "$SCHEME" -configuration "$CONFIGURATION" clean build 2>&1 | tee build.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "✓ BUILD SUCCESSFUL"
    echo "=================================================="
    echo ""
    
    # Show summary
    echo "Summary:"
    echo "  • 10 new files created"
    echo "  • 3 files modified"
    echo "  • All phases 6.3-6.7 complete"
    echo ""
    
    # Count warnings
    WARNINGS=$(grep -c "warning:" build.log || true)
    echo "  Warnings: $WARNINGS"
    
    echo ""
    echo "Next step: Create DMG"
    echo "  Run: ./create-dmg.sh \"Phase6.3-6.7-Complete\""
    echo ""
    
    exit 0
else
    echo ""
    echo "=================================================="
    echo "❌ BUILD FAILED"
    echo "=================================================="
    echo ""
    
    # Show errors
    echo "Errors:"
    grep "error:" build.log | head -10
    echo ""
    
    echo "Review build.log for full details"
    echo ""
    
    exit 1
fi
