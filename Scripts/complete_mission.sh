#!/bin/bash
# Complete Thea Mission Script
# Run this on your Mac to finish the setup

set -e

THEA_DIR="/Users/alexis/Documents/IT & Tech/MyApps/Thea"
cd "$THEA_DIR"

echo "🚀 Starting Thea Mission Completion..."

# Step 1: Remove git lock files
echo "📋 Step 1: Cleaning up git lock files..."
rm -f .git/index.lock .git/HEAD.lock .git/objects/maintenance.lock 2>/dev/null || true
echo "   ✅ Lock files removed"

# Step 2: Pull latest changes
echo "📋 Step 2: Pulling latest changes from GitHub..."
git pull origin main
echo "   ✅ Latest changes pulled"

# Step 3: Check for duplicate Info.plist references and fix if needed
echo "📋 Step 3: Checking Xcode project for duplicate Info.plist references..."
if grep -q "Info 2\.plist\|Info 3\.plist\|Info 4\.plist" Thea.xcodeproj/project.pbxproj 2>/dev/null; then
    echo "   Found duplicate references, removing..."
    grep -v "Info 2\.plist\|Info 3\.plist\|Info 4\.plist" Thea.xcodeproj/project.pbxproj > Thea.xcodeproj/project.pbxproj.tmp
    mv Thea.xcodeproj/project.pbxproj.tmp Thea.xcodeproj/project.pbxproj
    git add Thea.xcodeproj/project.pbxproj
    git commit -m "chore: Remove duplicate Info plist references from Xcode project

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
    git push origin main
    echo "   ✅ Duplicate references removed and pushed"
else
    echo "   ✅ No duplicate references found"
fi

# Step 4: Check CI status
echo "📋 Step 4: Checking latest CI status..."
gh run list --limit 1 --json status,conclusion,name 2>/dev/null || echo "   (Install gh CLI to check CI status: brew install gh)"

# Step 5: Build Thea.app
echo "📋 Step 5: Building Thea.app for macOS..."
xcodebuild -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | xcpretty || xcodebuild -project Thea.xcodeproj \
    -scheme Thea-macOS \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    build

# Step 6: Copy to Applications
echo "📋 Step 6: Installing Thea.app to /Applications..."
APP_PATH=$(find build -name "Thea.app" -type d | head -1)
if [ -n "$APP_PATH" ]; then
    # Kill existing Thea if running
    killall Thea 2>/dev/null || true

    # Remove old version
    rm -rf /Applications/Thea.app 2>/dev/null || true

    # Copy new version
    cp -R "$APP_PATH" /Applications/

    echo "   ✅ Thea.app installed to /Applications"
else
    echo "   ❌ Could not find Thea.app in build output"
    echo "   Looking for .app files:"
    find build -name "*.app" -type d
fi

# Step 7: Launch Thea
echo "📋 Step 7: Launching Thea.app..."
open /Applications/Thea.app

echo ""
echo "🎉 Mission Complete!"
echo "   Thea.app should now be running from /Applications"
echo ""
