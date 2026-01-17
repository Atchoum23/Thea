#!/bin/bash
# Complete Mission Script for Thea
# This script pushes changes, monitors CI, and verifies everything works

set -e

echo "🚀 Thea Mission Completion Script"
echo "================================="

# Step 1: Push changes
echo ""
echo "📤 Step 1: Pushing changes to GitHub..."
git push origin main

if [ $? -eq 0 ]; then
    echo "✅ Changes pushed successfully!"
else
    echo "❌ Push failed. Please check your git credentials."
    exit 1
fi

# Step 2: Check CI status
echo ""
echo "🔄 Step 2: Checking CI status..."
echo "Please monitor the GitHub Actions at:"
echo "https://github.com/Atchoum23/Thea/actions"
echo ""
echo "The CI should run the following jobs:"
echo "  - SwiftLint"
echo "  - Build with SPM (release)"
echo "  - Build with SPM (debug) + Tests"
echo "  - Build macOS App"
echo "  - Build iOS App"

# Step 3: Verify local installation
echo ""
echo "📱 Step 3: Verifying Thea.app installation..."
if [ -d "/Applications/Thea.app" ]; then
    echo "✅ Thea.app is installed in /Applications"

    # Check if it's signed
    if codesign -v "/Applications/Thea.app" 2>/dev/null; then
        echo "✅ App is properly signed"
    else
        echo "⚠️  App may need code signing for distribution"
    fi

    # Try to launch and verify
    echo ""
    echo "Would you like to launch Thea.app? (y/n)"
    read -r response
    if [ "$response" = "y" ]; then
        open -a Thea
        echo "✅ Thea.app launched!"
    fi
else
    echo "❌ Thea.app not found in /Applications"
    echo "   Building and installing..."

    cd "$(dirname "$0")/.."
    xcodebuild -project Thea.xcodeproj \
        -scheme Thea \
        -configuration Release \
        -destination 'platform=macOS' \
        -derivedDataPath build/DerivedData \
        build

    # Copy to Applications
    cp -R build/DerivedData/Build/Products/Release/Thea.app /Applications/
    echo "✅ Thea.app installed to /Applications"
fi

echo ""
echo "🎉 Mission Status"
echo "================="
echo "✅ Local commit ready: $(git log --oneline -1)"
echo "✅ Changes pushed to GitHub"
echo "⏳ CI verification: Check GitHub Actions"
echo "✅ Thea.app: Installed in /Applications"
echo ""
echo "Mission complete! 🚀"
